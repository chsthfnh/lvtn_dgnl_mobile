import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:markdown/markdown.dart' as md;
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
  bool _isNormalizingLatex = false;
  bool _isWaitingForAI = false;
  bool _isLoadingUsage = true;
  int _remainingUses = 3;
  String _aiResponse = '';
  Uint8List? _selectedImageBytes;
  String _selectedImageMimeType = 'image/jpeg';

  @override
  void initState() {
    super.initState();
    _loadRemainingUsage();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<void> _loadRemainingUsage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoadingUsage = false);
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .get();
      var used = 0;
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data()!;
        if ((data['ocrUsageDate'] ?? '') == _todayKey()) {
          used = (data['ocrUsageCount'] as num?)?.toInt() ?? 0;
        }
      }
      if (!mounted) return;
      setState(() {
        _remainingUses = (3 - used).clamp(0, 3).toInt();
        _isLoadingUsage = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingUsage = false);
    }
  }

  Future<void> _showUsageMessage(String message, {bool isError = false}) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          isError ? Icons.error_outline : Icons.check_circle_outline,
          color: isError ? Colors.red : Colors.green,
        ),
        title: Text(isError ? 'Không thể tiếp tục' : 'Đã giải xong'),
        content: Text(message, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  // --- 1. HÀM CHỤP/CHỌN ẢNH VÀ QUÉT CHỮ ---
  Future<void> _processImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 1800,
      imageQuality: 88,
    );
    if (pickedFile == null) return;

    setState(() {
      _isProcessingImage = true;
      _aiResponse = ''; // Xóa kết quả cũ nếu có
    });

    TextRecognizer? textRecognizer;
    try {
      _selectedImageBytes = await pickedFile.readAsBytes();
      final lowerName = pickedFile.name.toLowerCase();
      _selectedImageMimeType = lowerName.endsWith('.png')
          ? 'image/png'
          : lowerName.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';

      // Google ML Kit Text Recognition không hỗ trợ Flutter Web.
      // Trên web dùng trực tiếp bytes ảnh và Gemini Vision để nhận diện.
      if (kIsWeb) {
        final recognizedForWeb = await _aiService
            .extractQuestionFromImageToLatex(
              imageBytes: _selectedImageBytes!,
              imageMimeType: _selectedImageMimeType,
            );
        if (!mounted) return;
        setState(() {
          _textCtrl.text = recognizedForWeb;
          _textCtrl.selection = TextSelection.collapsed(
            offset: _textCtrl.text.length,
          );
          _isProcessingImage = false;
        });
        return;
      }

      final inputImage = InputImage.fromFilePath(pickedFile.path);
      textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );
      if (!mounted) return;
      final cleanedText = recognizedText.text
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .join('\n');
      setState(() {
        _textCtrl.text = cleanedText;
        _isProcessingImage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingImage = false;
      });
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.image_not_supported, color: Colors.red),
          title: const Text('Không thể quét ảnh'),
          content: Text(
            kIsWeb
                ? 'Không thể gửi ảnh đến AI. Hãy kiểm tra mạng, chọn ảnh rõ hơn '
                      'và thử lại.\n\nChi tiết: $e'
                : 'Hãy kiểm tra quyền truy cập ảnh/camera và thử lại.\n\n'
                      'Chi tiết: $e',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } finally {
      await textRecognizer?.close();
    }
  }

  Future<void> _normalizeLatex() async {
    final sourceText = _textCtrl.text.trim();
    if (sourceText.length < 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hãy quét câu hỏi trước.')));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isNormalizingLatex = true);
    try {
      final normalized = await _aiService.normalizeScannedTextToLatex(
        ocrText: sourceText,
        imageBytes: _selectedImageBytes,
        imageMimeType: _selectedImageMimeType,
      );
      if (!mounted) return;
      setState(() {
        _textCtrl.text = normalized;
        _textCtrl.selection = TextSelection.collapsed(
          offset: _textCtrl.text.length,
        );
        _isNormalizingLatex = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã chuẩn hóa công thức. Hãy kiểm tra bản xem trước.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isNormalizingLatex = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể chuẩn hóa công thức. Kiểm tra mạng và thử lại.',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // --- 2. HÀM KIỂM TRA LƯỢT DÙNG & NHỜ AI GIẢI ---
  Future<void> _askAITutor() async {
    final recognizedText = _textCtrl.text.trim();
    if (recognizedText.length < 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nội dung quá ngắn. Hãy chụp rõ cả đề và các đáp án.'),
        ),
      );
      return;
    }

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
      String today = _todayKey();
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
        setState(() {
          _isWaitingForAI = false;
          _remainingUses = 0;
        });
        if (mounted) {
          await _showUsageMessage(
            'Bạn đã dùng hết 3/3 lượt giải bài bằng AI hôm nay. '
            'Lượt sử dụng sẽ được làm mới vào ngày mai.',
            isError: true,
          );
        }
        return;
      }

      // Dùng phiên AI độc lập, không lẫn lịch sử chat/học lực của người dùng.
      final response = await _aiService.solveScannedQuestion(
        recognizedText: recognizedText,
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
          _remainingUses = (2 - currentCount).clamp(0, 3).toInt();
        });
        await _showUsageMessage(
          'Lời giải và đáp án đã được chuẩn hóa LaTeX. '
          'Bạn còn $_remainingUses/3 lượt giải AI hôm nay.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isWaitingForAI = false;
        _aiResponse = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is FormatException
                ? e.message.toString()
                : 'Không thể kết nối AI. Kiểm tra mạng rồi thử lại.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- 3. GIAO DIỆN CHÍNH CỦA MÀN HÌNH QUÉT ẢNH ---
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
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
                      'Văn bản/LaTeX nhận diện (có thể chỉnh sửa):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _textCtrl,
                      onChanged: (_) => setState(() {}),
                      minLines: 6,
                      maxLines: 12,
                      decoration: InputDecoration(
                        hintText: 'Chữ trong ảnh sẽ hiện ở đây...',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed:
                          _isNormalizingLatex || _textCtrl.text.trim().isEmpty
                          ? null
                          : _normalizeLatex,
                      icon: _isNormalizingLatex
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.functions),
                      label: Text(
                        _isNormalizingLatex
                            ? 'Đang chuẩn hóa công thức...'
                            : 'Chuẩn hóa công thức LaTeX',
                      ),
                    ),
                    if (_textCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blueGrey.shade100),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bản xem trước công thức:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF002045),
                              ),
                            ),
                            const SizedBox(height: 8),
                            MarkdownBody(
                              data: _textCtrl.text,
                              selectable: true,
                              extensionSet: md.ExtensionSet(
                                [LatexBlockSyntax()],
                                [LatexInlineSyntax()],
                              ),
                              builders: {
                                'latex': LatexElementBuilder(
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF1D2939),
                                  ),
                                  textScaleFactor: 1.05,
                                ),
                              },
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(fontSize: 15, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _remainingUses > 0
                            ? Colors.orange.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _remainingUses > 0
                              ? Colors.orange.shade200
                              : Colors.red.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.bolt,
                            color: _remainingUses > 0
                                ? Colors.orange.shade800
                                : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isLoadingUsage
                                  ? 'Đang kiểm tra lượt giải AI hôm nay...'
                                  : 'Lượt giải AI còn lại hôm nay: '
                                        '$_remainingUses/3 lượt',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    ElevatedButton.icon(
                      onPressed:
                          _isWaitingForAI ||
                              _isNormalizingLatex ||
                              _isLoadingUsage ||
                              _remainingUses <= 0
                          ? null
                          : _askAITutor,
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
                            : _remainingUses <= 0
                            ? 'Đã hết 3/3 lượt hôm nay'
                            : 'Giải bằng AI • Còn $_remainingUses/3 lượt',
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
                      child: MarkdownBody(
                        data: _aiResponse,
                        selectable: true,
                        extensionSet: md.ExtensionSet(
                          [LatexBlockSyntax()],
                          [LatexInlineSyntax()],
                        ),
                        builders: {
                          'latex': LatexElementBuilder(
                            textStyle: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF1D2939),
                            ),
                            textScaleFactor: 1.05,
                          ),
                        },
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(fontSize: 16, height: 1.55),
                          listBullet: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),
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
