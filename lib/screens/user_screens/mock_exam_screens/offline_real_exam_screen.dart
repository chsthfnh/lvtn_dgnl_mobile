import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../services/hive_service.dart';

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

class OfflineRealExamScreen extends StatefulWidget {
  final String examId;
  final Map<String, dynamic> examInfo;
  final List<Map<String, dynamic>> questions;

  const OfflineRealExamScreen({
    super.key,
    required this.examId,
    required this.examInfo,
    required this.questions,
  });

  @override
  State<OfflineRealExamScreen> createState() => _OfflineRealExamScreenState();
}

class _OfflineRealExamScreenState extends State<OfflineRealExamScreen> {
  final HiveService _hiveService = HiveService();
  final Color _primaryColor = const Color(0xFF002045);
  final Color _activeColor = const Color(0xFF006E2F);

  int _currentIndex = 0;
  Map<int, int> _userAnswers = {};
  Timer? _timer;
  int _secondsRemaining = 0;
  bool _isRestoring = true;
  bool _submitted = false;
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    final minutes = (widget.examInfo['thoiGian'] as num?)?.toInt() ?? 150;
    _secondsRemaining = minutes * 60;
    _restoreProgress();
  }

  Future<void> _restoreProgress() async {
    await _hiveService.initialize();
    final progress = _hiveService.getOfflineProgress(widget.examId);
    if (progress != null) {
      final rawAnswers = <dynamic, dynamic>{};
      final storedAnswers = progress['userAnswers'];
      if (storedAnswers is Map) {
        rawAnswers.addAll(storedAnswers);
      }
      _userAnswers = {
        for (final entry in rawAnswers.entries)
          if (int.tryParse(entry.key.toString()) != null && entry.value is num)
            int.parse(entry.key.toString()): (entry.value as num).toInt(),
      };
      final restoredIndex = (progress['currentIndex'] as num?)?.toInt() ?? 0;
      _currentIndex = restoredIndex
          .clamp(0, widget.questions.isEmpty ? 0 : widget.questions.length - 1)
          .toInt();
      _secondsRemaining =
          (progress['secondsRemaining'] as num?)?.toInt() ?? _secondsRemaining;
    }
    if (!mounted) return;
    setState(() => _isRestoring = false);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining <= 0) {
        timer.cancel();
        _autoSubmitExam();
        return;
      }
      setState(() => _secondsRemaining--);
      if (_secondsRemaining % 10 == 0) unawaited(_saveProgress());
    });
  }

  Future<void> _saveProgress() {
    if (_submitted) return Future<void>.value();
    final index = _currentIndex;
    final answers = Map<int, int>.from(_userAnswers);
    final seconds = _secondsRemaining;
    _saveQueue = _saveQueue.then((_) {
      if (_submitted) return Future<void>.value();
      return _hiveService.saveOfflineProgress(
        examId: widget.examId,
        currentIndex: index,
        userAnswers: answers,
        secondsRemaining: seconds,
      );
    });
    return _saveQueue;
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (!_submitted) unawaited(_saveProgress());
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainSeconds.toString().padLeft(2, '0')}';
  }

  Future<bool> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạm dừng làm bài?'),
        content: const Text(
          'Đáp án, câu hiện tại và thời gian còn lại sẽ được lưu trên thiết bị.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lưu và thoát'),
          ),
        ],
      ),
    );
    if (leave == true) await _saveProgress();
    return leave == true;
  }

  Future<void> _submitExam() async {
    final accepted = await showDialog<bool>(
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
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Làm tiếp'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _activeColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Nộp bài'),
          ),
        ],
      ),
    );
    if (accepted == true) await _calculateAndShowResults();
  }

  Future<void> _autoSubmitExam() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã hết thời gian. Hệ thống tự động nộp bài.'),
        backgroundColor: Colors.red,
      ),
    );
    await _calculateAndShowResults();
  }

  Future<void> _calculateAndShowResults() async {
    _timer?.cancel();
    await _saveQueue;
    _submitted = true;
    var correctCount = 0;
    for (var index = 0; index < widget.questions.length; index++) {
      final correct = (widget.questions[index]['correctAnswer'] ?? 'A')
          .toString()
          .trim()
          .toUpperCase();
      final selected = _userAnswers[index];
      if (selected != null && String.fromCharCode(65 + selected) == correct) {
        correctCount++;
      }
    }

    await _hiveService.saveOfflineResult(
      examId: widget.examId,
      correctAnswers: correctCount,
      totalQuestions: widget.questions.length,
    );
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.emoji_events, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Kết quả', style: TextStyle(color: _primaryColor)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$correctCount/${widget.questions.length} câu đúng',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Kết quả đã lưu trên thiết bị. Khi làm offline, kết quả không đồng bộ lên bảng xếp hạng trực tuyến.',
              style: TextStyle(color: Color(0xFF667085), height: 1.4),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hoàn tất'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  void _goToQuestion(int index) {
    setState(() => _currentIndex = index);
    unawaited(_saveProgress());
  }

  void _showQuestionPalette() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Danh sách câu hỏi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: widget.questions.length,
                  itemBuilder: (_, index) {
                    final answered = _userAnswers.containsKey(index);
                    final current = index == _currentIndex;
                    return OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: current
                            ? _primaryColor
                            : answered
                            ? const Color(0xFFE8F5E9)
                            : Colors.white,
                        foregroundColor: current
                            ? Colors.white
                            : answered
                            ? _activeColor
                            : _primaryColor,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _goToQuestion(index);
                      },
                      child: Text('${index + 1}'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (widget.questions.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Đề thi không có dữ liệu.')),
      );
    }

    final currentData = widget.questions[_currentIndex];
    final questionText = (currentData['noiDungCauHoi'] ?? '').toString();
    final options = (currentData['options'] as List?) ?? const [];
    final commonContent = (currentData['noiDungChung'] ?? '').toString();
    final progress = (_currentIndex + 1) / widget.questions.length;

    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FC),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.close, color: _primaryColor),
                          onPressed: () async {
                            if (await _confirmExit() && mounted) {
                              Navigator.pop(context);
                            }
                          },
                        ),
                        Expanded(
                          child: Text(
                            (widget.examInfo['tenDeThi'] ?? 'Đề thi offline')
                                .toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Danh sách câu',
                          onPressed: _showQuestionPalette,
                          icon: const Icon(Icons.grid_view_rounded),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _formatTime(_secondsRemaining),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    LinearProgressIndicator(value: progress, minHeight: 5),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE4E7EC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Câu ${_currentIndex + 1}/${widget.questions.length}',
                              style: TextStyle(
                                color: _primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Đã làm ${_userAnswers.length} câu',
                              style: const TextStyle(color: Color(0xFF667085)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (commonContent.isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFAEB),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: _buildMathText(commonContent),
                          ),
                          const SizedBox(height: 14),
                        ],
                        _buildMathText(
                          questionText,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 22),
                        for (var index = 0; index < options.length; index++)
                          _buildOptionTile(
                            index,
                            String.fromCharCode(65 + index),
                            options[index].toString(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _currentIndex > 0
                            ? () => _goToQuestion(_currentIndex - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                        label: const Text('Quay lại'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              _currentIndex < widget.questions.length - 1
                              ? _primaryColor
                              : Colors.orange.shade800,
                        ),
                        onPressed: _currentIndex < widget.questions.length - 1
                            ? () => _goToQuestion(_currentIndex + 1)
                            : _submitExam,
                        icon: Icon(
                          _currentIndex < widget.questions.length - 1
                              ? Icons.chevron_right
                              : Icons.send,
                        ),
                        label: Text(
                          _currentIndex < widget.questions.length - 1
                              ? 'Tiếp theo'
                              : 'Nộp bài',
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
    final selected = _userAnswers[_currentIndex] == optionIndex;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Đáp án $letter',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() => _userAnswers[_currentIndex] = optionIndex);
          unawaited(_saveProgress());
        },
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE8F5E9) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _activeColor : const Color(0xFFD0D5DD),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: selected ? _activeColor : Colors.transparent,
                child: Text(
                  letter,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.white : _primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildMathText(content)),
              if (selected)
                const Icon(Icons.check_circle, color: Color(0xFF006E2F)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMathText(String text, {TextStyle? style}) {
    text = _normalizeQuestionDisplayText(text);
    if (!text.contains(r'$')) return Text(text, style: style);
    final parts = text.split(r'$');
    final spans = <InlineSpan>[];
    for (var index = 0; index < parts.length; index++) {
      if (index.isEven) {
        if (parts[index].isNotEmpty) spans.add(TextSpan(text: parts[index]));
      } else if (parts[index].trim().isNotEmpty) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Math.tex(
              parts[index].trim().replaceAll('–', '-').replaceAll('—', '-'),
              textStyle: style,
              mathStyle: MathStyle.text,
            ),
          ),
        );
      }
    }
    return Text.rich(TextSpan(children: spans), style: style);
  }
}
