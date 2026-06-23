import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle; // Thêm để đọc file từ assets
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart'; // Thêm để tìm thư mục lưu file
import 'package:open_file/open_file.dart'; // Thêm để kích hoạt mở file Excel

class ImportQuestionsScreen extends StatefulWidget {
  const ImportQuestionsScreen({super.key});

  @override
  State<ImportQuestionsScreen> createState() => _ImportQuestionsScreenState();
}

class _ImportQuestionsScreenState extends State<ImportQuestionsScreen> {
  final Color _primaryDark = const Color(0xFF1A237E);
  final Color _textLight = Colors.grey.shade600;

  final List<Map<String, dynamic>> _uploadedFiles = [];

  // Biến lưu tạm danh sách câu hỏi đã đọc hợp lệ, chờ bấm nút để đẩy lên Firebase
  List<Map<String, dynamic>> _pendingQuestions = [];
  bool _isUploading = false; // Trạng thái khóa nút khi đang upload

  // --- HÀM TẢI VÀ LƯU FILE RA THƯ MỤC DOWNLOADS CỦA MÁY ---
  Future<void> _downloadTemplate() async {
    try {
      // 1. Đọc dữ liệu từ assets
      final byteData = await rootBundle.load(
        'assets/templates/excel_template.xlsx',
      );

      // 2. Xác định thư mục Tải về (Downloads) công khai
      String savePath = '';
      if (Platform.isAndroid) {
        // Đường dẫn chuẩn xác nhất tới thư mục Downloads trên mọi máy Android
        savePath = '/storage/emulated/0/Download/excel_template.xlsx';
      } else {
        // Cho iOS (Apple bảo mật file khắt khe hơn nên lưu vào Documents của App)
        final directory = await getApplicationDocumentsDirectory();
        savePath = '${directory.path}/excel_template.xlsx';
      }

      final file = File(savePath);

      // 3. Ghi dữ liệu ra file vật lý
      await file.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );

      // Thông báo lưu thành công trước khi mở
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

      // 4. Mở file lên cho admin xem (nếu máy có cài app đọc Excel)
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

  Future<void> _pickAndParseFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData:
            true, // THÊM DÒNG NÀY: Bắt buộc để lấy dữ liệu (bytes) an toàn trên mọi thiết bị
      );

      if (result != null) {
        var pickedFile = result.files.single;
        String fileName = pickedFile.name;

        // --- CƠ CHẾ ĐỌC FILE AN TOÀN 100% ---
        List<int>? bytes = pickedFile.bytes;

        // Nếu bytes bị rỗng (xảy ra trên vài máy Android cũ), ta mới dùng đường dẫn dự phòng
        if (bytes == null && pickedFile.path != null) {
          bytes = File(pickedFile.path!).readAsBytesSync();
        }

        // Nếu vẫn không có dữ liệu thì báo lỗi ra màn hình
        if (bytes == null) {
          throw Exception("Hệ thống không thể trích xuất dữ liệu từ file này.");
        }

        // Reset dữ liệu tạm cũ nếu có
        _pendingQuestions.clear();

        setState(() {
          _uploadedFiles.insert(0, {
            'fileName': fileName,
            'status': 'processing',
            'subtitle': 'Đang đọc dữ liệu từ file...',
            'progress': null, // Chạy hiệu ứng load vô định
            'errors': <String>[],
          });
        });

        // Đọc dữ liệu từ biến bytes an toàn thay vì đọc từ File(path)
        var excel = Excel.decodeBytes(bytes);

        List<Map<String, dynamic>> questionsParsed = [];
        List<String> errorLogs = [];

        String firstSheet = excel.tables.keys.first;
        var table = excel.tables[firstSheet];

        if (table != null) {
          for (int i = 1; i < table.rows.length; i++) {
            var row = table.rows[i];

            // KIỂM TRA AN TOÀN: Bỏ qua ngay nếu dòng không đủ độ dài hoặc không có nội dung câu hỏi
            if (row.length <= 3 ||
                row[3] == null ||
                row[3]?.value == null ||
                row[3]!.value.toString().trim().isEmpty) {
              continue;
            }

            // Đọc chính xác 14 cột theo Index (từ 0 đến 13)
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

        // Cập nhật UI sau khi đọc xong
        if (errorLogs.isNotEmpty) {
          setState(() {
            _uploadedFiles[0]['status'] = 'error';
            _uploadedFiles[0]['subtitle'] = errorLogs.first;
            _uploadedFiles[0]['errors'] = errorLogs;
          });
        } else if (questionsParsed.isNotEmpty) {
          setState(() {
            _pendingQuestions = questionsParsed; // Đưa vào hàng chờ
            _uploadedFiles[0]['status'] = 'ready'; // Trạng thái sẵn sàng
            _uploadedFiles[0]['subtitle'] =
                'Sẵn sàng Import ${questionsParsed.length} câu hỏi';
            _uploadedFiles[0]['progress'] = 0.0;
          });
        } else {
          setState(() {
            _uploadedFiles[0]['status'] = 'error';
            _uploadedFiles[0]['subtitle'] = 'File không có dữ liệu hợp lệ.';
          });
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

  // --- BƯỚC 2: HÀM ĐẨY DỮ LIỆU LÊN FIREBASE (KHI BẤM NÚT) ---
  Future<void> _startImport() async {
    if (_pendingQuestions.isEmpty || _isUploading) return;

    setState(() {
      _isUploading = true;
      _uploadedFiles[0]['status'] = 'processing';
      _uploadedFiles[0]['subtitle'] = 'Đang đẩy lên hệ thống...';
      _uploadedFiles[0]['progress'] = null;
    });

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var question in _pendingQuestions) {
        DocumentReference docRef = FirebaseFirestore.instance
            .collection('Questions')
            .doc();
        batch.set(docRef, question);
      }
      await batch.commit();

      setState(() {
        _isUploading = false;
        _uploadedFiles[0]['status'] = 'success';
        _uploadedFiles[0]['subtitle'] =
            'Hoàn tất • Đã thêm ${_pendingQuestions.length} câu hỏi';
        _uploadedFiles[0]['progress'] = 1.0;
        _pendingQuestions.clear(); // Xóa dữ liệu chờ sau khi import thành công
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadedFiles[0]['status'] = 'error';
        _uploadedFiles[0]['subtitle'] = 'Lỗi kết nối máy chủ.';
        _uploadedFiles[0]['errors'] = [e.toString()];
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
    // Kích hoạt nút khi có dữ liệu chờ và không trong quá trình upload
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
            // --- 1. KHU VỰC TẢI TỆP MẪU ---
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
                    onPressed:
                        _downloadTemplate, // FIX: Đã kết nối hàm tải tệp vật lý ở đây
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

            // --- 2. KHU VỰC KÉO THẢ UPLOAD ---
            GestureDetector(
              onTap: _isUploading
                  ? null
                  : _pickAndParseFile, // Khóa nút chọn file khi đang upload
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
                      'Hỗ trợ định dạng .xlsx. Kích thước\ntối đa 10MB.',
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

            // --- 3. DANH SÁCH TỆP TẢI LÊN GẦN ĐÂY ---
            Text(
              'TỆP TẢI LÊN GẦN ĐÂY',
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
                        'Chưa có tệp nào được tải lên gần đây.',
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

      // --- 4. NÚT BẮT ĐẦU IMPORT ---
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
                _isUploading ? 'Đang Import...' : 'Bắt đầu Import',
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

  // --- WIDGET HELPER: Thẻ trạng thái từng tệp tin ---
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
