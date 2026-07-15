import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class AIPracticeResultScreen extends StatelessWidget {
  final List<Map<String, dynamic>> questions;
  final Map<int, int> userAnswers;
  final int correctAnswers;
  final String timeSpent;
  final String subjectName;
  final String topic;

  const AIPracticeResultScreen({
    super.key,
    required this.questions,
    required this.userAnswers,
    required this.correctAnswers,
    required this.timeSpent,
    required this.subjectName,
    required this.topic,
  });

  final Color _primaryColor = const Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Kết quả luyện tập AI',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _primaryColor,
        elevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.pop(context); // Trở về trang chủ
          },
        ),
      ),
      body: Column(
        children: [
          // KHỐI TỔNG QUAN KẾT QUẢ
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 60),
                const SizedBox(height: 8),
                Text(
                  'Hoàn thành chủ đề:\n$topic',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol(
                      'Số câu đúng',
                      '$correctAnswers / ${questions.length}',
                      Colors.green.shade700,
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.grey.shade300,
                    ),
                    _buildStatCol('Thời gian', timeSpent, _primaryColor),
                  ],
                ),
              ],
            ),
          ),

          // KHỐI CHI TIẾT ĐÚNG / SAI TỪNG CÂU
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: questions.length,
              itemBuilder: (context, index) {
                var data = questions[index];
                int? userAnsIndex = userAnswers[index];

                // Lấy đáp án đúng (A, B, C, D) và chuyển thành index (0, 1, 2, 3)
                String correctLetter = data['correctAnswer'] ?? 'A';
                int correctIndex = correctLetter.codeUnitAt(0) - 65;

                bool isCorrect = userAnsIndex == correctIndex;
                bool isSkipped = userAnsIndex == null;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isCorrect
                          ? Colors.green.shade300
                          : (isSkipped
                                ? Colors.orange.shade300
                                : Colors.red.shade300),
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header câu hỏi
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isCorrect
                                    ? Colors.green
                                    : (isSkipped ? Colors.orange : Colors.red),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Câu ${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isCorrect
                                  ? 'Tuyệt vời!'
                                  : (isSkipped ? 'Chưa làm' : 'Sai rồi!'),
                              style: TextStyle(
                                color: isCorrect
                                    ? Colors.green
                                    : (isSkipped ? Colors.orange : Colors.red),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Nội dung chung (Nếu có)
                        if (data['noiDungChung'] != null &&
                            data['noiDungChung'].toString().isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              data['noiDungChung'],
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Nội dung câu hỏi
                        _buildMathText(
                          data['noiDungCauHoi'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),

                        // Danh sách 4 đáp án
                        ...List.generate(4, (optIndex) {
                          List<dynamic> options = data['options'] ?? [];
                          if (optIndex >= options.length)
                            return const SizedBox.shrink();

                          bool isThisOptionCorrect = optIndex == correctIndex;
                          bool isThisOptionUserPicked =
                              optIndex == userAnsIndex;

                          Color bgColor = Colors.transparent;
                          Color borderColor = Colors.grey.shade300;
                          IconData? icon;
                          Color iconColor = Colors.transparent;

                          if (isThisOptionCorrect) {
                            bgColor = Colors.green.shade50;
                            borderColor = Colors.green;
                            icon = Icons.check_circle;
                            iconColor = Colors.green;
                          } else if (isThisOptionUserPicked && !isCorrect) {
                            bgColor = Colors.red.shade50;
                            borderColor = Colors.red;
                            icon = Icons.cancel;
                            iconColor = Colors.red;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${String.fromCharCode(65 + optIndex)}.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildMathText(
                                    options[optIndex].toString(),
                                  ),
                                ),
                                if (icon != null)
                                  Icon(icon, color: iconColor, size: 20),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Hàm render công thức Toán học
  Widget _buildMathText(String text, {TextStyle? style}) {
    if (!text.contains('\$')) return Text(text, style: style);
    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth = constraints.maxWidth == double.infinity
            ? MediaQuery.of(context).size.width - 60
            : constraints.maxWidth;
        List<String> parts = text.split('\$');
        List<InlineSpan> spans = [];
        for (int i = 0; i < parts.length; i++) {
          if (i % 2 == 0) {
            if (parts[i].isNotEmpty) spans.add(TextSpan(text: parts[i]));
          } else {
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
                    fit: BoxFit.scaleDown,
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
        return Text.rich(TextSpan(children: spans), style: style);
      },
    );
  }
}
