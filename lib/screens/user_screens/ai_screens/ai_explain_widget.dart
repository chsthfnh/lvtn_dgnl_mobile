import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:markdown/markdown.dart' as md;
import '../../../services/ai_tutor_service.dart';

//Hiển thị lời giải chi tiết từng câu
class AITutorExplainButton extends StatelessWidget {
  final String questionContent;
  final String correctAnswer;
  final String userAnswer;

  const AITutorExplainButton({
    super.key,
    required this.questionContent,
    required this.correctAnswer,
    required this.userAnswer,
  });

  void _showExplanation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AIExplanationSheet(
        questionContent: questionContent,
        correctAnswer: correctAnswer,
        userAnswer: userAnswer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _showExplanation(context),
      icon: const Icon(Icons.auto_awesome, color: Color(0xFFE65100), size: 18),
      label: const Text(
        'Hỏi AI Tutor',
        style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold),
      ),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: const Color(0xFFE65100).withOpacity(0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}

// ==========================================
// CỬA SỔ HIỂN THỊ LỜI GIẢI CỦA AI
// ==========================================
class _AIExplanationSheet extends StatefulWidget {
  final String questionContent;
  final String correctAnswer;
  final String userAnswer;

  const _AIExplanationSheet({
    required this.questionContent,
    required this.correctAnswer,
    required this.userAnswer,
  });

  @override
  State<_AIExplanationSheet> createState() => _AIExplanationSheetState();
}

class _AIExplanationSheetState extends State<_AIExplanationSheet> {
  final AITutorService _aiService = AITutorService();
  bool _isLoading = true;
  String _aiResponse = '';

  @override
  void initState() {
    super.initState();
    _fetchExplanation();
  }

  Future<void> _fetchExplanation() async {
    String response = await _aiService.explainQuestion(
      questionContent: widget.questionContent,
      correctAnswer: widget.correctAnswer,
      userAnswer: widget.userAnswer,
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
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
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
                    Icon(Icons.auto_awesome, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Text(
                      'AI Tutor Giải Thích',
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

          // Body (Nội dung giải thích)
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
                          'AI đang phân tích lỗi sai của bạn...',
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
                      selectable: true,
                      data: _aiResponse,
                      builders: {
                        'latex': LatexElementBuilder(
                          textStyle: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: Colors.black87,
                          ),
                          textScaleFactor: 1,
                        ),
                      },
                      extensionSet: md.ExtensionSet(
                        [LatexBlockSyntax()],
                        [LatexInlineSyntax()],
                      ),
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Colors.black87,
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
