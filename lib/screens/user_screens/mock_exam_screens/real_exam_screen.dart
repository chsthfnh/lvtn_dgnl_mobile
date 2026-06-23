import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../practice_screens/practice_result_screen.dart';

class RealExamScreen extends StatefulWidget {
  final DocumentSnapshot examDoc;

  const RealExamScreen({super.key, required this.examDoc});

  @override
  State<RealExamScreen> createState() => _RealExamScreenState();
}

class _RealExamScreenState extends State<RealExamScreen> {
  // --- BẢNG MÀU DESIGN SYSTEM ---
  final Color _primary = const Color(0xFF002045);
  final Color _bgLight = const Color(0xFFF8F9FF);
  final Color _surfaceLow = const Color(0xFFEFF4FF);
  final Color _outline = const Color(0xFFC4C6CF);
  final Color _error = const Color(0xFFBA1A1A);
  final Color _errorContainer = const Color(0xFFFFDAD6);

  List<DocumentSnapshot> _questions = [];
  bool _isLoading = true;

  int _currentIndex = 0;
  final Map<int, int> _userAnswers = {};
  late Timer _timer;
  int _secondsRemaining = 0;
  final Map<String, Future<String>> _imageFutures = {};

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  // --- 1. TẢI DỮ LIỆU CÂU HỎI TỪ FIREBASE ---
  Future<void> _loadQuestions() async {
    try {
      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection('Questions')
          .where('maDeThi', isEqualTo: widget.examDoc.id)
          .get();

      Map<String, dynamic> examData =
          widget.examDoc.data() as Map<String, dynamic>;

      // Lấy mảng ID câu hỏi gốc đã được Admin xếp đúng thứ tự từng phần
      List<dynamic> orderedIds = examData['questions'] ?? [];

      List<DocumentSnapshot> fetchedDocs = snap.docs;

      // THUẬT TOÁN QUAN TRỌNG: Ép các câu hỏi xếp hàng lại đúng thứ tự gốc của Admin
      // Giúp bảo toàn tuyệt đối ranh giới giữa các Phần thi và các Câu hỏi chùm
      if (orderedIds.isNotEmpty) {
        fetchedDocs.sort((a, b) {
          int indexA = orderedIds.indexOf(a.id);
          int indexB = orderedIds.indexOf(b.id);

          // Đẩy các câu bất thường (nếu có) xuống cuối cùng
          if (indexA == -1) return 1;
          if (indexB == -1) return -1;

          return indexA.compareTo(indexB);
        });
      }

      setState(() {
        _questions = fetchedDocs;
        _isLoading = false;

        // Lấy thời gian từ đề thi
        int minutes = examData['thoiGian'] ?? 150;
        _secondsRemaining = minutes * 60;
      });

      _startTimer();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải đề thi: $e')));
    }
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
    if (_timer.isActive) _timer.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // --- 2. XỬ LÝ NỘP BÀI ---
  void _submitExam() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Xác nhận nộp bài',
          style: TextStyle(color: _primary, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Bạn đã hoàn thành ${_userAnswers.length}/${_questions.length} câu.\nThời gian vẫn còn, bạn có chắc chắn muốn nộp bài sớm?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Làm tiếp', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              _processResults();
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
        content: Text(
          'Đã hết thời gian! Tự động nộp bài.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red,
      ),
    );
    _processResults();
  }

  void _processResults() {
    int correctCount = 0;
    for (int i = 0; i < _questions.length; i++) {
      var data = _questions[i].data() as Map<String, dynamic>;
      String correctAnsLetter = data['correctAnswer'] ?? 'A';
      int? userAnsIndex = _userAnswers[i];
      if (userAnsIndex != null) {
        String userAnsLetter = String.fromCharCode(65 + userAnsIndex);
        if (userAnsLetter == correctAnsLetter) correctCount++;
      }
    }

    int totalMinutes =
        (widget.examDoc.data() as Map<String, dynamic>)['thoiGian'] ?? 150;
    int timeSpentSeconds = (totalMinutes * 60) - _secondsRemaining;
    String examName =
        (widget.examDoc.data() as Map<String, dynamic>)['tenDeThi'] ??
        'Đề thi ĐGNL';

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PracticeResultScreen(
          totalQuestions: _questions.length,
          correctAnswers: correctCount,
          timeSpent: _formatTime(timeSpentSeconds),
          subjectName: examName,
          questions: _questions,
          userAnswers: _userAnswers,
          isTab: false,
        ),
      ),
    );
  }

  // --- 3. POPUP SƠ ĐỒ CÂU HỎI (MAP) ---
  void _showQuestionMap() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Cho phép Popup kéo cao lên
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7, // Chiếm 70% màn hình
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Thanh nắm kéo (Drag handle)
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sơ đồ câu hỏi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _primary,
                    ),
                  ),
                  Text(
                    '${_userAnswers.length}/${_questions.length} Đã làm',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Chú giải màu sắc
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLegendItem(Colors.white, _outline, 'Chưa làm'),
                  _buildLegendItem(_surfaceLow, _primary, 'Đã làm'),
                  _buildLegendItem(_primary, _primary, 'Hiện tại'),
                ],
              ),
            ),
            // Lưới câu hỏi
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  bool isAnswered = _userAnswers.containsKey(index);
                  bool isCurrent = _currentIndex == index;

                  Color bgColor = isCurrent
                      ? _primary
                      : (isAnswered ? _surfaceLow : Colors.white);
                  Color textColor = isCurrent
                      ? Colors.white
                      : (isAnswered ? _primary : Colors.black87);
                  Color borderColor = isCurrent
                      ? _primary
                      : (isAnswered ? _primary : _outline.withOpacity(0.5));

                  return GestureDetector(
                    onTap: () {
                      setState(() => _currentIndex = index);
                      Navigator.pop(context); // Đóng popup và chuyển đến câu đó
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: borderColor,
                          width: isCurrent || isAnswered ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color bg, Color border, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_questions.isEmpty)
      return Scaffold(
        appBar: AppBar(title: const Text('Lỗi')),
        body: const Center(child: Text('Đề thi này chưa có câu hỏi!')),
      );

    var currentData = _questions[_currentIndex].data() as Map<String, dynamic>;
    String qText = currentData['noiDungCauHoi'] ?? '';
    List<dynamic> options = currentData['options'] ?? [];
    String noiDungChung = currentData['noiDungChung'] ?? '';

    return Scaffold(
      backgroundColor: _bgLight,
      // --- APP BAR ĐƯỢC THIẾT KẾ THEO ẢNH ---
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            // Đồng hồ đếm ngược (Nền đỏ nhạt)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _errorContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, color: _error, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(_secondsRemaining),
                    style: TextStyle(
                      color: _error,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Nút mở Sơ đồ câu hỏi
            IconButton(
              onPressed: _showQuestionMap,
              icon: Icon(Icons.grid_view_rounded, color: _primary),
              tooltip: 'Sơ đồ câu hỏi',
            ),
            const SizedBox(width: 8),
            // Nút Nộp bài
            ElevatedButton.icon(
              onPressed: _submitExam,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text(
                'Nộp bài',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Gạch ngang phân cách
          Container(
            height: 1,
            width: double.infinity,
            color: _outline.withOpacity(0.2),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- BOX DỮ KIỆN CHUNG ---
                  if (noiDungChung.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _outline.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.menu_book_rounded,
                                color: _primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Dữ kiện chung',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _primary,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildMathText(
                            noiDungChung,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // --- BOX CÂU HỎI ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _outline.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _primary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${_currentIndex + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Câu hỏi',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: _primary,
                                  ),
                                ),
                              ),
                            ),
                            // Biểu tượng đánh dấu (Chỉ để trang trí theo thiết kế)
                            Column(
                              children: [
                                Icon(
                                  Icons.flag_outlined,
                                  color: Colors.grey.shade500,
                                  size: 20,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'ĐÁNH DẤU',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildMathText(
                          qText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Các phương án trắc nghiệm
                        for (int i = 0; i < options.length; i++)
                          _buildOptionTile(
                            i,
                            String.fromCharCode(65 + i),
                            options[i].toString(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- THANH ĐIỀU HƯỚNG DƯỚI CÙNG ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _outline.withOpacity(0.2))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: _currentIndex > 0
                      ? () => setState(() => _currentIndex--)
                      : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: BorderSide(
                      color: _currentIndex > 0
                          ? _outline
                          : Colors.grey.shade200,
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text(
                    'Quay lại',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: _currentIndex < _questions.length - 1
                      ? () => setState(() => _currentIndex++)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _surfaceLow,
                    foregroundColor: _primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'Tiếp theo',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET PHƯƠNG ÁN TRẢ LỜI ---
  Widget _buildOptionTile(int optionIndex, String letter, String content) {
    bool isSelected = _userAnswers[_currentIndex] == optionIndex;
    return GestureDetector(
      onTap: () {
        setState(() => _userAnswers[_currentIndex] = optionIndex);
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _surfaceLow : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _primary : _outline.withOpacity(0.5),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? _primary : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? _primary : _outline),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMathText(
                content,
                style: TextStyle(
                  fontSize: 15,
                  color: isSelected ? _primary : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- THUẬT TOÁN RENDER TOÁN HỌC (ĐÃ CHỐNG TRÀN VIỀN) ---
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
