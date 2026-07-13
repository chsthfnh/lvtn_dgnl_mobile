import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/ai_tutor_service.dart';

class AIOcrScannerSheet extends StatefulWidget {
  const AIOcrScannerSheet({super.key});

  // Hàm tĩnh để gọi BottomSheet dễ dàng từ màn hình chính
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const AIOcrScannerSheet(),
    );
  }

  @override
  State<AIOcrScannerSheet> createState() => _AIOcrScannerSheetState();
}

class _AIOcrScannerSheetState extends State<AIOcrScannerSheet> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _textCtrl = TextEditingController();
  final AITutorService _aiService = AITutorService();

  bool _isProcessingImage = false;
  bool _isWaitingForAI = false;
  String _aiResponse = '';
  File? _selectedImage;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  // --- 1. HÀM CHỤP/CHỌN ẢNH VÀ QUÉT CHỮ ---
  Future<void> _processImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() {
      _selectedImage = File(pickedFile.path);
      _isProcessingImage = true;
      _aiResponse = ''; // Xóa kết quả cũ nếu có
    });

    try {
      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      textRecognizer.close();

      setState(() {
        _textCtrl.text = recognizedText.text;
        _isProcessingImage = false;
      });
    } catch (e) {
      setState(() {
        _isProcessingImage = false;
        _textCtrl.text = 'Lỗi khi quét ảnh: $e';
      });
    }
  }

  // --- 2. HÀM KIỂM TRA LƯỢT DÙNG & NHỜ AI GIẢI ---
  Future<void> _askAITutor() async {
    if (_textCtrl.text.trim().isEmpty) return;

    FocusScope.of(context).unfocus(); // Đóng bàn phím

    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isWaitingForAI = true);

    try {
      DocumentReference userRef = FirebaseFirestore.instance
          .collection('Users')
          .doc(uid);
      DocumentSnapshot userDoc = await userRef.get();

      // Lấy ngày hôm nay (VD: 2026-7-14)
      DateTime now = DateTime.now();
      String today = "${now.year}-${now.month}-${now.day}";
      int currentCount = 0;

      // Kiểm tra xem hôm nay đã dùng mấy lần rồi
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        String lastUsageDate = data['ocrUsageDate'] ?? '';
        if (lastUsageDate == today) {
          currentCount = data['ocrUsageCount'] ?? 0;
        }
      }

      // NẾU ĐÃ DÙNG 3 LẦN -> CHẶN LẠI NGAY
      if (currentCount >= 3) {
        setState(() => _isWaitingForAI = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bạn đã hết 3 lượt giải bài bằng AI hôm nay. Hãy quay lại vào ngày mai nhé!',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // NẾU CÒN LƯỢT -> GỌI AI GEMINI
      String prompt =
          '''
Dưới đây là một câu hỏi trắc nghiệm tôi vừa chụp được. Hãy đóng vai AI Tutor, giải thích từng bước cực kỳ chi tiết và chọn ra đáp án đúng nhất.
Nội dung câu hỏi:
"${_textCtrl.text}"
''';
      String response = await _aiService.sendMessage(
        prompt,
        'Quét ảnh bằng AI',
      );

      // LƯU LẠI LƯỢT DÙNG MỚI VÀO FIREBASE
      await userRef.set({
        'ocrUsageDate': today,
        'ocrUsageCount': currentCount + 1,
      }, SetOptions(merge: true));

      // CẬP NHẬT GIAO DIỆN VÀ BÁO SỐ LƯỢT CÒN LẠI
      if (mounted) {
        setState(() {
          _aiResponse = response;
          _isWaitingForAI = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Giải thành công! Bạn còn ${2 - currentCount} lượt hôm nay.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isWaitingForAI = false;
        _aiResponse =
            'Có lỗi xảy ra khi kết nối máy chủ. Vui lòng thử lại sau.';
      });
    }
  }

  // --- 3. GIAO DIỆN CHÍNH CỦA MÀN HÌNH QUÉT ẢNH ---
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFE8EAF6),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.document_scanner, color: Color(0xFF002045)),
                    SizedBox(width: 8),
                    Text(
                      'AI Quét Câu Hỏi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF002045),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _processImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Chụp ảnh'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF002045),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _processImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Thư viện'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF002045),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_isProcessingImage)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text(
                              'Đang bóc tách văn bản...',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (!_isProcessingImage) ...[
                    const Text(
                      'Văn bản nhận diện (Có thể chỉnh sửa nếu sai):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _textCtrl,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Chữ trong ảnh sẽ hiện ở đây...',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    ElevatedButton.icon(
                      onPressed: _isWaitingForAI ? null : _askAITutor,
                      icon: _isWaitingForAI
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        _isWaitingForAI
                            ? 'AI đang giải bài...'
                            : 'Nhờ AI giải ngay (Max 3 lần/ngày)',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE65100),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],

                  if (_aiResponse.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      'Lời giải từ AI Tutor:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE65100),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: MarkdownBody(data: _aiResponse),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
