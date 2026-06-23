import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DetailedAnswerScreen extends StatelessWidget {
  final List<DocumentSnapshot> questions;
  final Map<int, int> userAnswers;

  const DetailedAnswerScreen({
    super.key,
    required this.questions,
    required this.userAnswers,
  });

  final Color _primary = const Color(0xFF002045);
  final Color _correctGreen = const Color(0xFF006E2F);
  final Color _errorRed = const Color(0xFFBA1A1A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Đáp án chi tiết',
          style: TextStyle(
            color: _primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        itemBuilder: (context, index) {
          var data = questions[index].data() as Map<String, dynamic>;
          int? userAnsIdx = userAnswers[index];

          // Lớp khiên 1: Xử lý an toàn nếu không có đáp án đúng
          String correctLetter =
              data['correctAnswer']?.toString().trim() ?? 'A';
          if (correctLetter.isEmpty) correctLetter = 'A';
          int correctIdx = correctLetter.codeUnitAt(0) - 65; // A->0, B->1...

          bool isCorrect = userAnsIdx == correctIdx;

          // Lớp khiên 2: Xử lý an toàn nếu không có mảng options
          List<dynamic> options = data['options'] ?? [];

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCorrect
                    ? _correctGreen.withOpacity(0.3)
                    : _errorRed.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Câu số + Trạng thái
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Câu ${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? _correctGreen.withOpacity(0.1)
                            : _errorRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCorrect ? 'CHÍNH XÁC' : 'SAI RỒI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isCorrect ? _correctGreen : _errorRed,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Nội dung câu hỏi
                _buildMathText(
                  data['noiDungCauHoi'] ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (data['anhCauHoi'] != null &&
                    data['anhCauHoi'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildImage(data['anhCauHoi']),
                ],
                const SizedBox(height: 16),

                // Danh sách đáp án (Sử dụng options.length cực kỳ an toàn)
                Column(
                  children: List.generate(options.length, (optIdx) {
                    bool isUserChoice = userAnsIdx == optIdx;
                    bool isRightAns = correctIdx == optIdx;

                    Color itemColor = Colors.grey.shade100;
                    Color textColor = Colors.black87;
                    IconData? icon;

                    if (isRightAns) {
                      itemColor = _correctGreen.withOpacity(0.1);
                      textColor = _correctGreen;
                      icon = Icons.check_circle;
                    } else if (isUserChoice && !isCorrect) {
                      itemColor = _errorRed.withOpacity(0.1);
                      textColor = _errorRed;
                      icon = Icons.cancel;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: itemColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isRightAns
                              ? _correctGreen
                              : isUserChoice
                              ? _errorRed
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${String.fromCharCode(65 + optIdx)}.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMathText(
                              options[optIdx].toString(),
                              style: TextStyle(color: textColor),
                            ),
                          ),
                          if (icon != null)
                            Icon(icon, size: 18, color: textColor),
                        ],
                      ),
                    );
                  }),
                ),

                // LỜI GIẢI CHI TIẾT
                const Divider(height: 32),
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb, size: 16, color: _primary),
                          const SizedBox(width: 4),
                          Text(
                            'Lời giải chi tiết:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _primary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildMathText(
                        data['loiGiai'] ??
                            'Chưa có giải thích cho câu hỏi này.',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- THUẬT TOÁN RENDER TOÁN HỌC (TEXT.RICH + FITTEDBOX SIÊU BỀN BỈ) ---
  Widget _buildMathText(String text, {TextStyle? style}) {
    if (!text.contains('\$')) return Text(text, style: style);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Đề phòng lỗi constraint vô cực, lấy không gian an toàn của màn hình
        double maxWidth = constraints.maxWidth == double.infinity
            ? MediaQuery.of(context).size.width - 60
            : constraints.maxWidth;

        List<String> parts = text.split('\$');
        List<InlineSpan> spans = [];

        for (int i = 0; i < parts.length; i++) {
          if (i % 2 == 0) {
            // Phần chữ bình thường
            if (parts[i].isNotEmpty) spans.add(TextSpan(text: parts[i]));
          } else {
            // Phần công thức Toán học
            String mathCode = parts[i]
                .trim()
                .replaceAll('–', '-')
                .replaceAll('—', '-');
            if (mathCode.isEmpty) continue;

            spans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: FittedBox(
                    fit: BoxFit
                        .scaleDown, // Tự động thu nhỏ nếu công thức quá dài
                    alignment: Alignment.centerLeft,
                    child: Math.tex(
                      mathCode,
                      textStyle: style,
                      mathStyle: MathStyle.text,
                    ),
                  ),
                ),
              ),
            );
          }
        }

        // Trả về một khối văn bản duy nhất kết hợp cả chữ và Toán
        return Text.rich(TextSpan(children: spans), style: style);
      },
    );
  }

  Widget _buildImage(String imageName) {
    return FutureBuilder<String>(
      future: FirebaseStorage.instance
          .ref('QuestionImages/$imageName')
          .getDownloadURL(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          );
        if (snapshot.hasData)
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(snapshot.data!, fit: BoxFit.contain),
          );
        return const SizedBox.shrink();
      },
    );
  }
}
