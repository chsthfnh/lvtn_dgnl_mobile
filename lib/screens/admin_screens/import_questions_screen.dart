import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ImportQuestionsScreen extends StatefulWidget {
  const ImportQuestionsScreen({super.key});

  @override
  State<ImportQuestionsScreen> createState() => _ImportQuestionsScreenState();
}

class _ImportQuestionsScreenState extends State<ImportQuestionsScreen> {
  final Color _primaryDark = const Color(0xFF1A237E);
  final Color _textLight = Colors.grey.shade600;

  final List<Map<String, dynamic>> _uploadedFiles = [];

  // Chứa TẤT CẢ câu hỏi từ các file hợp lệ
  List<Map<String, dynamic>> _pendingQuestions = [];
  bool _isUploading = false;

  // --- HÀM 1: TẢI TỆP MẪU ---
  Future<void> _downloadTemplate() async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tính năng tải file mẫu hiện chưa hỗ trợ trên Web. Vui lòng sử dụng App điện thoại.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    try {
      final byteData = await rootBundle.load(
        'assets/templates/excel_template.xlsx',
      );
      String savePath = '';
      if (Platform.isAndroid) {
        savePath = '/storage/emulated/0/Download/excel_template.xlsx';
      } else {
        final directory = await getApplicationDocumentsDirectory();
        savePath = '${directory.path}/excel_template.xlsx';
      }

      final file = File(savePath);
      await file.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã lưu file thành công vào thư mục Tải về (Downloads)!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      await OpenFile.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi lưu file: $e\n(Hãy kiểm tra quyền bộ nhớ)'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- HÀM 2: CHỌN VÀ ĐỌC NHIỀU FILE CÙNG LÚC ---
  Future<void> _pickAndParseFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
        allowMultiple: true, // ĐÃ BẬT: Cho phép chọn nhiều file
      );

      if (result != null) {
        // VÒNG LẶP: Xử lý từng file được chọn
        for (var pickedFile in result.files) {
          String fileName = pickedFile.name;

          // 1. Tạo trạng thái file và đẩy lên đầu danh sách UI
          Map<String, dynamic> fileStatus = {
            'fileName': fileName,
            'status': 'processing',
            'subtitle': 'Đang đọc dữ liệu...',
            'progress': null,
            'errors': <String>[],
          };

          setState(() {
            _uploadedFiles.insert(0, fileStatus);
          });

          // 2. Trích xuất Bytes an toàn
          List<int>? bytes = pickedFile.bytes;
          if (bytes == null && !kIsWeb && pickedFile.path != null) {
            bytes = File(pickedFile.path!).readAsBytesSync();
          }

          if (bytes == null) {
            setState(() {
              fileStatus['status'] = 'error';
              fileStatus['subtitle'] = 'Không thể trích xuất dữ liệu.';
            });
            continue; // Bỏ qua file này, tiếp tục file khác
          }

          // 3. Phân tích Excel
          var excel = Excel.decodeBytes(bytes);
          List<Map<String, dynamic>> questionsParsed = [];
          List<String> errorLogs = [];

          String firstSheet = excel.tables.keys.first;
          var table = excel.tables[firstSheet];

          if (table != null) {
            for (int i = 1; i < table.rows.length; i++) {
              var row = table.rows[i];

              if (row.length <= 3 ||
                  row[3] == null ||
                  row[3]?.value == null ||
                  row[3]!.value.toString().trim().isEmpty) {
                continue;
              }

              String maNhom = row[0]?.value?.toString() ?? "";
              String noiDungChung = row.length > 1
                  ? (row[1]?.value?.toString() ?? "")
                  : "";
              String anhChung = row.length > 2
                  ? (row[2]?.value?.toString() ?? "")
                  : "";
              String questionText = row.length > 3
                  ? (row[3]?.value?.toString() ?? "")
                  : "";
              String anhCauHoi = row.length > 4
                  ? (row[4]?.value?.toString() ?? "")
                  : "";
              String ansA = row.length > 5
                  ? (row[5]?.value?.toString() ?? "")
                  : "";
              String ansB = row.length > 6
                  ? (row[6]?.value?.toString() ?? "")
                  : "";
              String ansC = row.length > 7
                  ? (row[7]?.value?.toString() ?? "")
                  : "";
              String ansD = row.length > 8
                  ? (row[8]?.value?.toString() ?? "")
                  : "";
              String correctAns = row.length > 9
                  ? (row[9]?.value?.toString() ?? "")
                  : "";
              String explanation = row.length > 10
                  ? (row[10]?.value?.toString() ?? "")
                  : "";
              String phanThi = row.length > 11
                  ? (row[11]?.value?.toString() ?? "")
                  : "";
              String subject = row.length > 12
                  ? (row[12]?.value?.toString() ?? "")
                  : "";
              String difficulty = row.length > 13
                  ? (row[13]?.value?.toString() ?? "")
                  : "";

              if (questionText.isEmpty || correctAns.isEmpty) {
                errorLogs.add("Dòng ${i + 1}: Thiếu câu hỏi hoặc đáp án đúng.");
                continue;
              }

              questionsParsed.add({
                'maNhom': maNhom,
                'noiDungChung': noiDungChung,
                'anhChung': anhChung,
                'noiDungCauHoi': questionText,
                'anhCauHoi': anhCauHoi,
                'options': [ansA, ansB, ansC, ansD],
                'correctAnswer': correctAns,
                'loiGiai': explanation,
                'phanThi': phanThi,
                'chuDe': subject,
                'doKho': difficulty,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
          }

          // 4. Cập nhật UI riêng cho từng file sau khi đọc xong
          if (errorLogs.isNotEmpty) {
            setState(() {
              fileStatus['status'] = 'error';
              fileStatus['subtitle'] = errorLogs.first;
              fileStatus['errors'] = errorLogs;
            });
          } else if (questionsParsed.isNotEmpty) {
            setState(() {
              _pendingQuestions.addAll(
                questionsParsed,
              ); // NỘI CỘNG dồn câu hỏi của file này vào danh sách tổng
              fileStatus['status'] = 'ready';
              fileStatus['subtitle'] =
                  'Sẵn sàng Import ${questionsParsed.length} câu hỏi';
              fileStatus['progress'] = 0.0;
            });
          } else {
            setState(() {
              fileStatus['status'] = 'error';
              fileStatus['subtitle'] = 'File không có dữ liệu hợp lệ.';
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi đọc file: $e')));
      }
    }
  }

  // --- HÀM 3: ĐẨY TOÀN BỘ CÂU HỎI LÊN FIREBASE (CÓ CHIA NHỎ ĐỂ TRÁNH LỖI OVERLOAD) ---
  Future<void> _startImport() async {
    if (_pendingQuestions.isEmpty || _isUploading) return;

    setState(() {
      _isUploading = true;
      // Chuyển trạng thái các file "Đang chờ" thành "Đang xử lý"
      for (var file in _uploadedFiles) {
        if (file['status'] == 'ready') {
          file['status'] = 'processing';
          file['subtitle'] = 'Đang đẩy lên hệ thống...';
          file['progress'] = null;
        }
      }
    });

    try {
      // THUẬT TOÁN CHUNKING: Firebase chỉ cho phép WriteBatch tối đa 500 Docs.
      // Cắt mảng _pendingQuestions ra từng cục 400 câu hỏi để gửi từ từ
      int total = _pendingQuestions.length;
      int chunkSize = 400;

      for (int i = 0; i < total; i += chunkSize) {
        WriteBatch batch = FirebaseFirestore.instance.batch();
        int end = (i + chunkSize < total) ? i + chunkSize : total;
        List<Map<String, dynamic>> chunk = _pendingQuestions.sublist(i, end);

        for (var question in chunk) {
          DocumentReference docRef = FirebaseFirestore.instance
              .collection('Questions')
              .doc();
          batch.set(docRef, question);
        }
        await batch.commit(); // Đẩy cục dữ liệu lên
      }

      setState(() {
        _isUploading = false;
        // Báo thành công cho các file đang xử lý
        for (var file in _uploadedFiles) {
          if (file['status'] == 'processing') {
            file['status'] = 'success';
            file['subtitle'] = 'Hoàn tất';
            file['progress'] = 1.0;
          }
        }
        _pendingQuestions
            .clear(); // Xóa sạch bộ nhớ tạm sau khi upload xong toàn bộ
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
        // Báo lỗi cho các file đang xử lý
        for (var file in _uploadedFiles) {
          if (file['status'] == 'processing') {
            file['status'] = 'error';
            file['subtitle'] = 'Lỗi kết nối máy chủ.';
            file['errors'] = [e.toString()];
          }
        }
      });
    }
  }

  void _showErrorDetails(List<String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Chi tiết lỗi định dạng',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: errors.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                "• ${errors[index]}",
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isButtonEnabled = _pendingQuestions.isNotEmpty && !_isUploading;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A237E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Import Câu hỏi',
          style: TextStyle(
            color: Color(0xFF1A237E),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.description_outlined, color: _primaryDark),
                      const SizedBox(width: 10),
                      Text(
                        'Tải tệp mẫu chuẩn',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _primaryDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sử dụng định dạng này để đảm bảo hệ thống đọc dữ liệu chính xác.',
                    style: TextStyle(
                      fontSize: 14,
                      color: _textLight,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(color: Colors.grey.shade300),
                      foregroundColor: _primaryDark,
                    ),
                    onPressed: _downloadTemplate,
                    icon: const Icon(Icons.download_outlined, size: 20),
                    label: const Text(
                      'Tải Excel Template',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            GestureDetector(
              onTap: _isUploading ? null : _pickAndParseFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200, width: 1.5),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF0F4FA),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cloud_upload_outlined,
                        size: 32,
                        color: _primaryDark,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Kéo thả tệp vào đây hoặc\nnhấn để duyệt',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _primaryDark,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hỗ trợ .xlsx. Có thể chọn nhiều file cùng lúc.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: _textLight,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            Text(
              'TỆP TẢI LÊN',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),

            _uploadedFiles.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30.0),
                      child: Text(
                        'Chưa có tệp nào được tải lên.',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _uploadedFiles.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _buildFileStatusItem(_uploadedFiles[index]),
                    ),
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Color(0xFFF8F9FA)),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: isButtonEnabled
                ? _primaryDark
                : const Color(0xFFE8EAF6),
            foregroundColor: isButtonEnabled
                ? Colors.white
                : Colors.grey.shade600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          onPressed: isButtonEnabled ? _startImport : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isUploading
                    ? 'Đang Import...'
                    : 'Bắt đầu Import ${_pendingQuestions.length > 0 ? "(${_pendingQuestions.length} câu)" : ""}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              if (!_isUploading) const Icon(Icons.arrow_forward, size: 20),
              if (_isUploading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileStatusItem(Map<String, dynamic> file) {
    String status = file['status'];
    String fileName = file['fileName'];
    String subtitle = file['subtitle'];
    double? progress = file['progress'];
    List<String> errors = file['errors'] ?? [];

    Color borderColor;
    Widget leadingIcon;
    Widget trailingWidget;
    Color subtitleColor = Colors.grey.shade600;

    switch (status) {
      case 'processing':
        borderColor = Colors.grey.shade300;
        leadingIcon = _buildIconBox(
          Icons.insert_drive_file_outlined,
          Colors.grey.shade600,
          const Color(0xFFF0F4FA),
        );
        trailingWidget = progress != null
            ? Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              )
            : const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              );
        break;
      case 'ready':
        borderColor = Colors.blue.shade300;
        leadingIcon = _buildIconBox(
          Icons.grading_rounded,
          Colors.blue.shade700,
          Colors.blue.shade50,
        );
        trailingWidget = const Text(
          'Đang chờ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        );
        break;
      case 'success':
        borderColor = Colors.green.shade300;
        leadingIcon = _buildIconBox(
          Icons.check_circle_outline,
          Colors.green.shade700,
          Colors.green.shade50,
        );
        trailingWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.greenAccent.shade400,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'THÀNH CÔNG',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
        break;
      case 'error':
        borderColor = Colors.red.shade300;
        leadingIcon = _buildIconBox(
          Icons.error_outline,
          Colors.red.shade700,
          Colors.red.shade50,
        );
        subtitleColor = Colors.red.shade700;
        trailingWidget = InkWell(
          onTap: () => _showErrorDetails(errors),
          child: const Text(
            'Xem chi tiết',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
        );
        break;
      default:
        borderColor = Colors.grey.shade300;
        leadingIcon = const Icon(Icons.insert_drive_file);
        trailingWidget = const SizedBox();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leadingIcon,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        fileName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _primaryDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    trailingWidget,
                  ],
                ),
                const SizedBox(height: 6),
                if (status == 'processing' && progress != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey.shade200,
                          color: _primaryDark,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: subtitleColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBox(IconData icon, Color iconColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: iconColor, size: 24),
    );
  }
}
