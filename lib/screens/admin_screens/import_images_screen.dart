import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ImportImagesScreen extends StatefulWidget {
  const ImportImagesScreen({super.key});

  @override
  State<ImportImagesScreen> createState() => _ImportImagesScreenState();
}

class _ImportImagesScreenState extends State<ImportImagesScreen> {
  final Color _primaryDark = const Color(0xFF1A237E);
  final Color _textLight = Colors.grey.shade600;

  // Danh sách các file ảnh đang chờ upload
  List<PlatformFile> _pendingImages = [];

  // Trạng thái upload
  bool _isUploading = false;

  // Danh sách kết quả để hiển thị trên UI
  final List<Map<String, dynamic>> _uploadResults = [];

  SettableMetadata _metadataForImage(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';

    return SettableMetadata(
      contentType: contentType,
      // Cho phép mobile và trình duyệt dùng lại ảnh trong 7 ngày.
      cacheControl: 'public,max-age=604800',
    );
  }

  // --- HÀM 1: CHỌN NHIỀU ẢNH TỪ MÁY ---
  Future<void> _pickImages() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        // Chuyển từ FileType.image sang FileType.custom
        type: FileType.custom,
        // Bắt buộc chỉ định các đuôi file được phép chọn
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null) {
        setState(() {
          _pendingImages = result.files;
          _uploadResults.clear();

          // Tạo UI hiển thị các ảnh đang chờ
          for (var file in _pendingImages) {
            _uploadResults.add({
              // Lúc này file.name sẽ giữ nguyên 100% tên gốc (VD: cau_1.png)
              'fileName': file.name,
              'status': 'ready',
              'subtitle':
                  'Đang chờ upload ( ${(file.size / 1024 / 1024).toStringAsFixed(2)} MB )',
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi chọn ảnh: $e')));
      }
    }
  }

  // --- HÀM 2: UPLOAD ẢNH LÊN FIREBASE STORAGE (CÓ CHẶN TRÙNG TÊN) ---
  Future<void> _startImport() async {
    if (_pendingImages.isEmpty || _isUploading) return;

    setState(() {
      _isUploading = true;
    });

    for (int i = 0; i < _pendingImages.length; i++) {
      var file = _pendingImages[i];

      setState(() {
        _uploadResults[i]['status'] = 'processing';
        _uploadResults[i]['subtitle'] = 'Đang kiểm tra dữ liệu...';
      });

      try {
        String fileName = file.name;

        // Đường dẫn trên Firebase
        Reference ref = FirebaseStorage.instance.ref().child(
          'QuestionImages/$fileName',
        );

        // KIỂM TRA ẢNH TRÙNG TÊN
        bool isExist = false;
        try {
          await ref.getDownloadURL();
          isExist = true; // Nếu hàm này chạy thành công nghĩa là ảnh ĐÃ TỒN TẠI
        } catch (_) {
          isExist = false; // Báo lỗi nghĩa là ảnh chưa có -> An toàn để upload
        }

        if (isExist) {
          setState(() {
            _uploadResults[i]['status'] = 'error';
            _uploadResults[i]['subtitle'] = 'Ảnh đã tồn tại';
            _uploadResults[i]['errors'] = [
              'Tên ảnh "$fileName" đã có trên hệ thống.',
              'Vui lòng đổi tên tệp tin trên máy của bạn hoặc xóa ảnh cũ trên hệ thống trước khi tải lên lại.',
            ];
          });
          continue; // BỎ QUA tấm ảnh này, chạy tiếp vòng lặp sang ảnh sau
        }

        // Bắt đầu Upload nếu chưa tồn tại
        setState(() {
          _uploadResults[i]['subtitle'] = 'Đang đẩy lên server...';
        });

        // --- SỬA ĐOẠN NÀY ĐỂ HỖ TRỢ WEB ---
        final metadata = _metadataForImage(fileName);
        if (kIsWeb) {
          // Xử lý kiểu Web (Dùng mảng byte)
          await ref.putData(file.bytes!, metadata);
        } else {
          // Xử lý kiểu App (Dùng đường dẫn file)
          File imageFile = File(file.path!);
          await ref.putFile(imageFile, metadata);
        }
        // -----------------------------------

        // Upload thành công
        setState(() {
          _uploadResults[i]['status'] = 'success';
          _uploadResults[i]['subtitle'] = 'Hoàn tất';
        });
      } catch (e) {
        // Lỗi sự cố mạng
        setState(() {
          _uploadResults[i]['status'] = 'error';
          _uploadResults[i]['subtitle'] = 'Lỗi kết nối';
          _uploadResults[i]['errors'] = [e.toString()];
        });
      }
    }

    setState(() {
      _isUploading = false;
      _pendingImages.clear(); // Xóa danh sách chờ
    });
  }

  // Hàm hiển thị Popup chi tiết lỗi
  void _showErrorDetails(List<String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Chi tiết lỗi',
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
    bool isButtonEnabled = _pendingImages.isNotEmpty && !_isUploading;

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
          'Import Hình ảnh',
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
            // --- 1. KHU VỰC KÉO THẢ UPLOAD ---
            GestureDetector(
              onTap: _isUploading ? null : _pickImages,
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
                      'Kéo thả hình ảnh vào đây hoặc\nnhấn để duyệt',
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
                      'Hỗ trợ định dạng .jpg, .png. Chọn nhiều ảnh cùng lúc.',
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

            // --- 2. DANH SÁCH HÌNH ẢNH ĐÃ TẢI LÊN ---
            Text(
              'DANH SÁCH HÌNH ẢNH',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),

            _uploadResults.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30.0),
                      child: Text(
                        'Chưa có ảnh nào được chọn.',
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
                    itemCount: _uploadResults.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _buildImageStatusItem(_uploadResults[index]),
                    ),
                  ),
            const SizedBox(height: 40),
          ],
        ),
      ),

      // --- 3. NÚT BẮT ĐẦU IMPORT ---
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
                _isUploading ? 'Đang Upload...' : 'Bắt đầu Upload',
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

  // --- WIDGET HELPER: Thẻ trạng thái từng hình ảnh ---
  Widget _buildImageStatusItem(Map<String, dynamic> file) {
    String status = file['status'];
    String fileName = file['fileName'];
    String subtitle = file['subtitle'];
    List<String> errors = file['errors'] ?? [];

    Color borderColor;
    Widget leadingIcon;
    Widget trailingWidget;
    Color subtitleColor = Colors.grey.shade600;

    switch (status) {
      case 'ready':
        borderColor = Colors.blue.shade300;
        leadingIcon = _buildThumbnailBox(
          Icons.image_outlined,
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
      case 'processing':
        borderColor = Colors.grey.shade300;
        leadingIcon = _buildThumbnailBox(
          Icons.cloud_upload_outlined,
          Colors.grey.shade600,
          const Color(0xFFF0F4FA),
        );
        trailingWidget = const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        break;
      case 'success':
        borderColor = Colors.green.shade300;
        leadingIcon = _buildThumbnailBox(
          Icons.image_outlined,
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
        leadingIcon = _buildThumbnailBox(
          Icons.broken_image_outlined,
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
        leadingIcon = _buildThumbnailBox(
          Icons.image_outlined,
          Colors.grey.shade600,
          const Color(0xFFF0F4FA),
        );
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
                    const SizedBox(width: 8),
                    trailingWidget,
                  ],
                ),
                const SizedBox(height: 6),
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

  Widget _buildThumbnailBox(IconData icon, Color iconColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: iconColor, size: 24),
    );
  }
}
