import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/ai_tutor_service.dart';

class AIDailySuggestionCard extends StatefulWidget {
  final double ngonNguProgress;
  final double toanHocProgress;
  final double logicProgress;

  const AIDailySuggestionCard({
    super.key,
    required this.ngonNguProgress,
    required this.toanHocProgress,
    required this.logicProgress,
  });

  @override
  State<AIDailySuggestionCard> createState() => _AIDailySuggestionCardState();
}

class _AIDailySuggestionCardState extends State<AIDailySuggestionCard> {
  final AITutorService _aiService = AITutorService();
  String _aiResponse = '';
  String _lastUpdatedTime = '';
  int _refreshCount = 0;
  bool _isLoading = true;
  bool _isRefreshing = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  String _key(String suffix) => 'ai_suggest_${_uid}_$suffix';
  String get _today {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  bool get _hasProgress =>
      widget.ngonNguProgress > 0 ||
      widget.toanHocProgress > 0 ||
      widget.logicProgress > 0;

  @override
  void initState() {
    super.initState();
    _loadCacheOrFetchAI();
  }

  @override
  void didUpdateWidget(covariant AIDailySuggestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldHadProgress =
        oldWidget.ngonNguProgress > 0 ||
        oldWidget.toanHocProgress > 0 ||
        oldWidget.logicProgress > 0;
    if (!oldHadProgress && _hasProgress) _loadCacheOrFetchAI();
  }

  Future<void> _loadCacheOrFetchAI() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedText = prefs.getString(_key('text')) ?? '';
    final cachedDate = prefs.getString(_key('date')) ?? '';
    if (mounted && cachedText.isNotEmpty) {
      setState(() {
        _aiResponse = cachedText;
        _lastUpdatedTime = prefs.getString(_key('time')) ?? '';
        _refreshCount = prefs.getInt(_key('count')) ?? 0;
        _isLoading = false;
      });
    }

    if (!_hasProgress) {
      if (mounted && cachedText.isEmpty) {
        setState(() {
          _aiResponse =
              'Hãy hoàn thành một bài luyện tập để AI đưa ra gợi ý phù hợp với năng lực của bạn.';
          _isLoading = false;
        });
      }
      return;
    }
    if (cachedDate == _today && cachedText.isNotEmpty) return;
    unawaited(_fetchNewSuggestion(prefs, 0, blockUi: cachedText.isEmpty));
  }

  Future<void> _fetchNewSuggestion(
    SharedPreferences prefs,
    int newRefreshCount, {
    bool blockUi = false,
  }) async {
    if (mounted) {
      setState(() {
        _isLoading = blockUi && _aiResponse.isEmpty;
        _isRefreshing = true;
      });
    }
    try {
      final response = await _aiService.getDailyRecommendation(
        ngonNguRate: widget.ngonNguProgress,
        toanHocRate: widget.toanHocProgress,
        logicRate: widget.logicProgress,
      );
      final now = DateTime.now();
      final time =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ngày ${now.day}/${now.month}';
      await prefs.setString(_key('date'), _today);
      await prefs.setString(_key('text'), response);
      await prefs.setString(_key('time'), time);
      await prefs.setInt(_key('count'), newRefreshCount);
      if (!mounted) return;
      setState(() {
        _aiResponse = response;
        _lastUpdatedTime = time;
        _refreshCount = newRefreshCount;
      });
    } catch (_) {
      if (mounted && _aiResponse.isEmpty) {
        setState(() {
          _aiResponse =
              'Hãy ưu tiên môn có tiến độ thấp nhất và hoàn thành một bài ngắn hôm nay.';
        });
      }
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
    }
  }

  Future<void> _handleRefreshClick() async {
    if (_refreshCount >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn đã hết 3 lượt tạo mới gợi ý hôm nay!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await _fetchNewSuggestion(prefs, _refreshCount + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI Gợi ý hôm nay',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
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
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(color: Colors.amber),
              ),
            )
          else
            MarkdownBody(
              data: _aiResponse,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  _lastUpdatedTime.isEmpty
                      ? 'Đang dùng dữ liệu hiện có'
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
                borderRadius: BorderRadius.circular(8),
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
                            : Colors.amber.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Làm mới (${3 - _refreshCount})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _refreshCount >= 3
                              ? Colors.grey
                              : Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
