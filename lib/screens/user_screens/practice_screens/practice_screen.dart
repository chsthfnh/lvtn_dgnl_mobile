import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'practice_result_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'level_config.dart';

String _normalizeQuestionDisplayText(String text) {
  final parts = text.split(r'$');
  for (int i = 0; i < parts.length; i += 2) {
    var plainText = parts[i]
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('\uF0CE', '∈')
        .replaceAll('\uF02D', '−')
        .replaceAll('\uF03D', '=')
        .replaceAll('\uF0C6', '∅')
        .replaceAll(r'\_', '_')
        .replaceAll(r'\%', '%')
        .replaceAll(r'\#', '#')
        .replaceAll(r'\&', '&');
    plainText = plainText.replaceAllMapped(
      RegExp(r'<sup>\s*0\s*</sup>\s*(\d+(?:[.,]\d+)?)', caseSensitive: false),
      (match) => '\$${match.group(1)}^{\\circ}\$',
    );
    parts[i] = plainText;
  }
  return parts.join(r'$');
}

const _primaryColor = Color(0xFF002045);
const _onPrimaryColor = Colors.white;
const _surfaceColor = Color(0xFFEFF4FF);
const _activeColor = Color(0xFF006E2F);
const _outlineColor = Color(0xFFC4C6CF);
const _backgroundColor = Colors.white;

class PracticeScreen extends StatefulWidget {
  final List<DocumentSnapshot> questions;
  final int timeInMinutes;
  final String subjectName;
  final bool isTab;

  final bool isLevelMode;
  final int currentLevel;
  final String progressKey;

  const PracticeScreen({
    super.key,
    required this.questions,
    required this.timeInMinutes,
    required this.subjectName,
    this.isTab = false,
    this.isLevelMode = false,
    this.currentLevel = 1,
    this.progressKey = '',
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  int _currentIndex = 0;
  Map<int, int> _userAnswers = {};
  late Timer _timer;
  int _secondsRemaining = 0;
  final Map<String, Future<String>> _imageFutures = {};

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.timeInMinutes * 60;
    _startTimer();
    updatePresence('practice');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_precacheQuestionImages(0));
    });
  }

  void _goToQuestion(int index) {
    if (index < 0 || index >= widget.questions.length) return;
    setState(() => _currentIndex = index);
    unawaited(_precacheQuestionImages(index));
  }

  Future<String> _resolveImageUrl(String imageValue) async {
    final value = imageValue.trim();

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    if (value.startsWith('gs://')) {
      return FirebaseStorage.instance.refFromURL(value).getDownloadURL();
    }

    final rawName = value.startsWith('QuestionImages/')
        ? value.substring('QuestionImages/'.length)
        : value;
    final candidateNames = <String>{rawName};
    final hasImageExtension = RegExp(
      r'\.(png|jpe?g|webp|gif)$',
      caseSensitive: false,
    ).hasMatch(rawName);

    if (!hasImageExtension) {
      candidateNames.addAll(['$rawName.png', '$rawName.jpg', '$rawName.jpeg']);
      final underscoreName = rawName.replaceAllMapped(
        RegExp(r'(\d)\.(\d)'),
        (match) => '${match.group(1)}_${match.group(2)}',
      );
      final dashName = rawName.replaceAllMapped(
        RegExp(r'(\d)\.(\d)'),
        (match) => '${match.group(1)}-${match.group(2)}',
      );
      candidateNames.addAll(['$underscoreName.png', '$dashName.png']);
    }

    Object? lastError;
    for (final candidate in candidateNames) {
      try {
        return await FirebaseStorage.instance
            .ref('QuestionImages/$candidate')
            .getDownloadURL();
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? StateError('Tên ảnh không hợp lệ: $imageValue');
  }

  Future<String> _getImageUrl(String imageValue) {
    return _imageFutures.putIfAbsent(
      imageValue,
      () => _resolveImageUrl(imageValue),
    );
  }

  ImageProvider _optimizedImageProvider(String url) {
    final networkImage = NetworkImage(url);
    return kIsWeb
        ? networkImage
        : ResizeImage.resizeIfNeeded(1600, null, networkImage);
  }

  Future<void> _precacheQuestionImages(int startIndex) async {
    if (!mounted || widget.questions.isEmpty) return;

    final lastIndex = startIndex + 1 < widget.questions.length
        ? startIndex + 1
        : startIndex;
    final values = <String>{};

    for (int index = startIndex; index <= lastIndex; index++) {
      final data =
          widget.questions[index].data() as Map<String, dynamic>? ?? {};
      for (final field in const ['anhChung', 'anhCauHoi']) {
        final value = data[field]?.toString().trim() ?? '';
        if (value.isNotEmpty) values.add(value);
      }
    }

    await Future.wait(
      values.map((value) async {
        try {
          final url = await _getImageUrl(value);
          if (mounted) {
            await precacheImage(_optimizedImageProvider(url), context);
          }
        } catch (e) {
          debugPrint('Không thể tải trước ảnh $value: $e');
        }
      }),
    );
  }

  void updatePresence(String action) {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('Users').doc(uid).update({
        'lastActive': FieldValue.serverTimestamp(),
        'currentAction': action,
      });
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
    _timer.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // --- HÀM THÊM MỚI: XÁC NHẬN TRƯỚC KHI THOÁT ---
  Future<bool> _onExitPressed() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                SizedBox(width: 8),
                Text(
                  'Cảnh báo',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: const Text(
              'Bạn chưa hoàn thành bài, kết quả sẽ bị hủy.\nBạn có chắc chắn muốn thoát?',
              style: TextStyle(fontSize: 15, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Làm tiếp',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Xác nhận'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _submitExam() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
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
          'Đã hết thời gian làm bài! Tự động nộp bài.',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red,
      ),
    );
    _processResults();
  }

  void _processResults() async {
    int correctCount = 0;
    int answeredCount = 0;

    for (int i = 0; i < widget.questions.length; i++) {
      var data = widget.questions[i].data() as Map<String, dynamic>;
      String correctAnsLetter = data['correctAnswer'] ?? 'A';
      int? userAnsIndex = _userAnswers[i];

      if (userAnsIndex != null) {
        answeredCount++;
        String userAnsLetter = String.fromCharCode(65 + userAnsIndex);
        if (userAnsLetter == correctAnsLetter) correctCount++;
      }
    }

    int timeSpentSeconds = (widget.timeInMinutes * 60) - _secondsRemaining;

    double accuracy = widget.questions.isEmpty
        ? 0
        : correctCount / widget.questions.length;
    int stars = LevelConfig.calculateStars(accuracy);
    bool isPass = accuracy >= 0.9;
    bool didLevelUp = false;
    int newConsecutive = 0;

    String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId != null) {
      await FirebaseFirestore.instance.collection('ExamHistory').add({
        'userId': currentUserId,
        'examId': widget.isLevelMode ? 'level_mode' : 'practice_mode',
        'examName': 'Luyện tập: ${widget.subjectName}',
        'timeSpentSeconds': timeSpentSeconds,
        'correctAnswers': correctCount,
        'answeredCount': answeredCount,
        'totalQuestions': widget.questions.length,
        'stars': stars,
        'level': widget.isLevelMode ? widget.currentLevel : null,
        'submittedAt': FieldValue.serverTimestamp(),
      });

      if (widget.isLevelMode) {
        DocumentReference progressRef = FirebaseFirestore.instance
            .collection('UserProgress')
            .doc(currentUserId);
        DocumentSnapshot snap = await progressRef.get();

        int currentConsecutive = 0;
        int savedLevel = widget.currentLevel;

        if (snap.exists && snap.data() != null) {
          var data = snap.data() as Map<String, dynamic>;
          if (data.containsKey(widget.progressKey)) {
            currentConsecutive =
                data[widget.progressKey]['consecutivePasses'] ?? 0;
            savedLevel = data[widget.progressKey]['level'] ?? 1;
          }
        }

        if (isPass) {
          newConsecutive = currentConsecutive + 1;
          if (newConsecutive >= 2 && savedLevel < 10) {
            savedLevel++;
            newConsecutive = 0;
            didLevelUp = true;
          }
        } else {
          newConsecutive = 0;
        }

        await progressRef.set({
          widget.progressKey: {
            'level': savedLevel,
            'consecutivePasses': newConsecutive,
          },
        }, SetOptions(merge: true));
      }
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PracticeResultScreen(
          totalQuestions: widget.questions.length,
          correctAnswers: correctCount,
          timeSpent: _formatTime(timeSpentSeconds),
          subjectName: widget.subjectName,
          questions: widget.questions,
          userAnswers: _userAnswers,
          isTab: widget.isTab,
          isLevelMode: widget.isLevelMode,
          stars: stars,
          isPass: isPass,
          didLevelUp: didLevelUp,
          consecutivePasses: newConsecutive,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const Scaffold(body: Center(child: Text('Lỗi: Không có câu hỏi')));
    }

    var currentData =
        widget.questions[_currentIndex].data() as Map<String, dynamic>;

    String qText = currentData['noiDungCauHoi'] ?? '';
    List<dynamic> options = currentData['options'] ?? [];
    String noiDungChung = currentData['noiDungChung'] ?? '';
    String anhChung = currentData['anhChung'] ?? '';
    String anhCauHoi = currentData['anhCauHoi'] ?? '';

    // Dùng PopScope để bẫy sự kiện nhấn nút Quay Lại vật lý của điện thoại
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        bool confirm = await _onExitPressed();
        if (confirm && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                height: 90,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: _surfaceColor,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: _primaryColor,
                        ),
                        onPressed: () async {
                          // Bẫy sự kiện nút Back trên góc AppBar
                          bool confirm = await _onExitPressed();
                          if (confirm && mounted) Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.subjectName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'THỜI GIAN: ',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatTime(_secondsRemaining),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _secondsRemaining < 300
                                  ? Colors.red
                                  : _primaryColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.hourglass_empty,
                            color: _secondsRemaining < 300
                                ? Colors.red
                                : _primaryColor,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
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
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: _buildMathText(
                              noiDungChung,
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (anhChung.isNotEmpty) _buildImage(anhChung),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.quiz_outlined,
                              color: Colors.grey,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMathText(
                                qText,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (anhCauHoi.isNotEmpty) _buildImage(anhCauHoi),
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
              Container(
                height: 90,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _currentIndex > 0
                            ? () => _goToQuestion(_currentIndex - 1)
                            : null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: _currentIndex > 0
                                ? _outlineColor
                                : Colors.grey.shade200,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          foregroundColor: _primaryColor,
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'QUAY LẠI',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // --- ĐÃ BỎ NÚT GỢI Ý Ở GIỮA ĐI ---
                    const SizedBox(
                      width: 12,
                    ), // Giữ một khoảng cách vừa phải giữa 2 nút

                    Expanded(
                      child: _currentIndex < widget.questions.length - 1
                          ? ElevatedButton(
                              onPressed: () => _goToQuestion(_currentIndex + 1),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: _primaryColor,
                                foregroundColor: _onPrimaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'TIẾP THEO',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                          : ElevatedButton(
                              onPressed: _submitExam,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: Colors.orange.shade800,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'NỘP BÀI',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(int optionIndex, String letter, String content) {
    bool isSelected = _userAnswers[_currentIndex] == optionIndex;
    return GestureDetector(
      onTap: () => setState(() => _userAnswers[_currentIndex] = optionIndex),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _activeColor : _backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _activeColor : _outlineColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _backgroundColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _activeColor : _outlineColor,
                ),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? _activeColor : _primaryColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMathText(
                content,
                style: TextStyle(
                  fontSize: 16,
                  color: isSelected ? _onPrimaryColor : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, color: _onPrimaryColor, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMathText(String text, {TextStyle? style}) {
    text = _normalizeQuestionDisplayText(text);
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

  Widget _buildImage(String imageName) {
    return FutureBuilder<String>(
      future: _getImageUrl(imageName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Text(
            '[Lỗi tải ảnh: $imageName]',
            style: const TextStyle(
              color: Colors.red,
              fontStyle: FontStyle.italic,
            ),
          );
        }
        if (snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image(
                image: _optimizedImageProvider(snapshot.data!),
                width: double.infinity,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  final expected = progress.expectedTotalBytes;
                  final value = expected == null
                      ? null
                      : progress.cumulativeBytesLoaded / expected;
                  return Container(
                    constraints: const BoxConstraints(minHeight: 140),
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(value: value),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Text(
                  '[Không tải được ảnh: $imageName]',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
