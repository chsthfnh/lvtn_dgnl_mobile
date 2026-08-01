import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/ai_tutor_service.dart';

class AIPerformanceAnalysisCard extends StatefulWidget {
  final String historyStatsText;
  const AIPerformanceAnalysisCard({super.key, required this.historyStatsText});

  @override
  State<AIPerformanceAnalysisCard> createState() =>
      _AIPerformanceAnalysisCardState();
}

class _AIPerformanceAnalysisCardState extends State<AIPerformanceAnalysisCard> {
  final AITutorService _aiService = AITutorService();
  String _analysisReport = '';
  String _lastUpdatedTime = '';
  int _refreshCount = 0;
  bool _isLoading = true;
  bool _isRefreshing = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  String _key(String suffix) => 'ai_report_${_uid}_$suffix';
  String get _today {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  bool get _hasData => !RegExp(
    r'Tổng số câu đã làm:\s*0\s*câu',
  ).hasMatch(widget.historyStatsText);

  @override
  void initState() {
    super.initState();
    _loadCacheOrFetchAI();
  }

  @override
  void didUpdateWidget(covariant AIPerformanceAnalysisCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.historyStatsText != widget.historyStatsText) {
      _loadCacheOrFetchAI();
    }
  }

  Future<void> _loadCacheOrFetchAI() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedText = prefs.getString(_key('text')) ?? '';
    final cachedStats = prefs.getString(_key('stats')) ?? '';
    final cachedDate = prefs.getString(_key('date')) ?? '';
    if (mounted && cachedText.isNotEmpty) {
      setState(() {
        _analysisReport = cachedText;
        _lastUpdatedTime = prefs.getString(_key('time')) ?? '';
        _refreshCount = prefs.getInt(_key('count')) ?? 0;
        _isLoading = false;
      });
    }

    if (!_hasData) {
      if (mounted && cachedText.isEmpty) {
        setState(() {
          _analysisReport =
              'Chưa có đủ dữ liệu để phân tích. Hãy hoàn thành ít nhất một bài luyện tập hoặc đề thi.';
          _isLoading = false;
        });
      }
      return;
    }
    if (cachedDate == _today &&
        cachedStats == widget.historyStatsText &&
        cachedText.isNotEmpty) {
      return;
    }
    unawaited(_fetchNewAnalysis(prefs, 0, blockUi: cachedText.isEmpty));
  }

  Future<void> _fetchNewAnalysis(
    SharedPreferences prefs,
    int newRefreshCount, {
    bool blockUi = false,
  }) async {
    if (mounted) {
      setState(() {
        _isLoading = blockUi && _analysisReport.isEmpty;
        _isRefreshing = true;
      });
    }
    try {
      final result = await _aiService.analyzePerformance(
        historyStatsText: widget.historyStatsText,
      );
      final now = DateTime.now();
      final time =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ngày ${now.day}/${now.month}';
      await prefs.setString(_key('date'), _today);
      await prefs.setString(_key('stats'), widget.historyStatsText);
      await prefs.setString(_key('text'), result);
      await prefs.setString(_key('time'), time);
      await prefs.setInt(_key('count'), newRefreshCount);
      if (!mounted) return;
      setState(() {
        _analysisReport = result;
        _lastUpdatedTime = time;
        _refreshCount = newRefreshCount;
      });
    } catch (_) {
      if (mounted && _analysisReport.isEmpty) {
        setState(
          () => _analysisReport =
              'Chưa thể kết nối AI. Dữ liệu thống kê vẫn được hiển thị bình thường.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _handleRefreshClick() async {
    if (_refreshCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn đã hết 3 lượt tạo báo cáo mới hôm nay!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!_hasData) return;
    final prefs = await SharedPreferences.getInstance();
    await _fetchNewAnalysis(prefs, _refreshCount + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF002045).withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EAF6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: Color(0xFF002045),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Báo cáo năng lực từ AI',
                  style: TextStyle(
                    color: Color(0xFF002045),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              if (_isRefreshing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(color: Color(0xFF002045)),
              ),
            )
          else
            MarkdownBody(
              data: _analysisReport,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: Colors.black87,
                ),
                h1: const TextStyle(
                  color: Color(0xFF002045),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                h2: const TextStyle(
                  color: Color(0xFF002045),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                strong: const TextStyle(
                  color: Color(0xFFE65100),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (!_isLoading) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.black12),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    _lastUpdatedTime.isEmpty
                        ? 'Chưa có bản phân tích AI'
                        : 'Cập nhật: $_lastUpdatedTime',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black38,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _isRefreshing ? null : _handleRefreshClick,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 14,
                          color: _refreshCount >= 3
                              ? Colors.grey
                              : const Color(0xFF002045),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Làm mới (${3 - _refreshCount})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _refreshCount >= 3
                                ? Colors.grey
                                : const Color(0xFF002045),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
