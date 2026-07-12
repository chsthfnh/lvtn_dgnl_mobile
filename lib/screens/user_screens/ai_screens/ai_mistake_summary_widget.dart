import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../services/ai_tutor_service.dart'; // Đổi đường dẫn nếu cần

class AIMistakeSummaryButton extends StatelessWidget {
  final List<DocumentSnapshot> questions;
  final Map<int, int> userAnswers;

  const AIMistakeSummaryButton({
    super.key,
    required this.questions,
    required this.userAnswers,
  });

  void _showSummary(BuildContext context) {
    // 1. Lọc ra các câu làm sai (Chỉ lấy tối đa 15 câu để AI đọc nhanh)
    List<String> wrongQuestionsText = [];
    int count = 0;

    for (int i = 0; i < questions.length; i++) {
      if (count >= 15) break; // Giới hạn số lượng

      var data = questions[i].data() as Map<String, dynamic>;
      String correctLetter = data['correctAnswer']?.toString().trim() ?? 'A';
      if (correctLetter.isEmpty) correctLetter = 'A';
      int correctIdx = correctLetter.codeUnitAt(0) - 65;

      int? userAnsIdx = userAnswers[i];

      // Nếu chọn sai hoặc bỏ trống
      if (userAnsIdx != correctIdx) {
        String qText = data['noiDungCauHoi'] ?? '';
        wrongQuestionsText.add('- Câu hỏi: $qText');
        count++;
      }
    }

    // 2. Mở cửa sổ BottomSheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _AIMistakeSummarySheet(wrongQuestions: wrongQuestionsText),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      child: ElevatedButton.icon(
        onPressed: () => _showSummary(context),
        icon: const Icon(Icons.psychology_alt, color: Colors.white),
        label: const Text(
          '✨ AI Phân tích lỗi sai',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE65100), // Màu cam nổi bật
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          shadowColor: const Color(0xFFE65100).withOpacity(0.5),
        ),
      ),
    );
  }
}

// ==========================================
// CỬA SỔ HIỂN THỊ BẢN TỔNG HỢP CỦA AI
// ==========================================
class _AIMistakeSummarySheet extends StatefulWidget {
  final List<String> wrongQuestions;
  const _AIMistakeSummarySheet({required this.wrongQuestions});

  @override
  State<_AIMistakeSummarySheet> createState() => _AIMistakeSummarySheetState();
}

class _AIMistakeSummarySheetState extends State<_AIMistakeSummarySheet> {
  final AITutorService _aiService = AITutorService();
  bool _isLoading = true;
  String _aiResponse = '';

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    String response = await _aiService.summarizeMistakes(
      wrongQuestionsContext: widget.wrongQuestions,
    );
    if (mounted) {
      setState(() {
        _aiResponse = response;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0), // Cam nhạt
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border(bottom: BorderSide(color: Colors.orange.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.psychology_alt,
                      color: Colors.orange.shade800,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI Bắt Mạch Điểm Yếu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade900,
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
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          color: Color(0xFFE65100),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'AI đang đọc lại các câu bạn làm sai...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: MarkdownBody(
                      data: _aiResponse,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.black87,
                        ),
                        h1: const TextStyle(
                          color: Color(0xFFE65100),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: const TextStyle(
                          color: Color(0xFF002045),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        strong: const TextStyle(
                          color: Color(0xFF002045),
                          fontWeight: FontWeight.bold,
                        ),
                        listBullet: const TextStyle(color: Color(0xFFE65100)),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
