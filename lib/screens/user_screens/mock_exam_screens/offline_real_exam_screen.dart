import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class OfflineRealExamScreen extends StatefulWidget {
  final Map<String, dynamic> examInfo;
  final List<Map<String, dynamic>> questions;

  const OfflineRealExamScreen({
    super.key,
    required this.examInfo,
    required this.questions,
  });

  @override
  State<OfflineRealExamScreen> createState() => _OfflineRealExamScreenState();
}

class _OfflineRealExamScreenState extends State<OfflineRealExamScreen> {
  final Color _primaryColor = const Color(0xFF002045);
  final Color _activeColor = const Color(0xFF006E2F);

  int _currentIndex = 0;
  Map<int, int> _userAnswers = {};
  late Timer _timer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    // Lấy thời gian từ data offline
    int minutes = widget.examInfo['thoiGian'] ?? 150;
    _secondsRemaining = minutes * 60;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer.cancel();
        _autoSubmitExam();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // --- HÀM NỘP BÀI VÀ CHẤM ĐIỂM OFFLINE ---
  void _submitExam() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Xác nhận nộp bài',
          style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Bạn đã làm ${_userAnswers.length}/${widget.questions.length} câu.\nBạn chắc chắn muốn nộp bài?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Làm tiếp', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _activeColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context); // Đóng dialog xác nhận
              _calculateAndShowResults();
            },
            child: const Text('NỘP BÀI'),
          ),
        ],
      ),
    );
  }

  void _autoSubmitExam() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã hết thời gian làm bài! Tự động nộp bài.'),
        backgroundColor: Colors.red,
      ),
    );
    _calculateAndShowResults();
  }

  void _calculateAndShowResults() {
    _timer.cancel();
    int correctCount = 0;

    for (int i = 0; i < widget.questions.length; i++) {
      String correctAnsLetter = widget.questions[i]['correctAnswer'] ?? 'A';
      int? userAnsIndex = _userAnswers[i];
      if (userAnsIndex != null) {
        String userAnsLetter = String.fromCharCode(65 + userAnsIndex);
        if (userAnsLetter == correctAnsLetter) correctCount++;
      }
    }

    // Hiển thị Dialog kết quả thay vì chuyển màn hình để tránh phức tạp hóa
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            Text(
              'Kết quả bài thi',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bạn đã trả lời đúng $correctCount / ${widget.questions.length} câu.',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              '(Lưu ý: Để đảm bảo tính công bằng, kết quả làm bài Offline sẽ không được ghi nhận vào Bảng xếp hạng hay Thống kê trực tuyến).',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx); // Đóng Dialog Kết quả
              Navigator.pop(
                context,
              ); // Thoát khỏi màn hình thi, về lại list Offline
            },
            child: const Text('Hoàn tất'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty)
      return const Scaffold(
        body: Center(child: Text('Đề thi không có dữ liệu')),
      );

    Map<String, dynamic> currentData = widget.questions[_currentIndex];
    String qText = currentData['noiDungCauHoi'] ?? '';
    List<dynamic> options = currentData['options'] ?? [];
    String noiDungChung = currentData['noiDungChung'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: _primaryColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.examInfo['tenDeThi'] ?? 'Đề thi Offline',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatTime(_secondsRemaining),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // BODY CÂU HỎI
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Câu ${_currentIndex + 1} / ${widget.questions.length}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (noiDungChung.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _buildMathText(
                            noiDungChung,
                            style: const TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildMathText(
                        qText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 24),
                      for (int i = 0; i < options.length; i++)
                        _buildOptionTile(
                          i,
                          String.fromCharCode(65 + i),
                          options[i].toString(),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // BOTTOM NAVIGATION
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _currentIndex > 0
                          ? () => setState(() => _currentIndex--)
                          : null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('QUAY LẠI'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _currentIndex < widget.questions.length - 1
                        ? ElevatedButton(
                            onPressed: () => setState(() => _currentIndex++),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('TIẾP THEO'),
                          )
                        : ElevatedButton(
                            onPressed: _submitExam,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade800,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('NỘP BÀI'),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(int optionIndex, String letter, String content) {
    bool isSelected = _userAnswers[_currentIndex] == optionIndex;
    return GestureDetector(
      onTap: () => setState(() => _userAnswers[_currentIndex] = optionIndex),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _activeColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _activeColor : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : _primaryColor,
                ),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : _primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMathText(
                content,
                style: TextStyle(
                  fontSize: 16,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
