import 'package:flutter/material.dart';
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
  String _suggestion = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSuggestion();
  }

  // Nếu điểm số thay đổi, AI sẽ tự nghĩ lại câu khác
  @override
  void didUpdateWidget(covariant AIDailySuggestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ngonNguProgress != widget.ngonNguProgress ||
        oldWidget.toanHocProgress != widget.toanHocProgress ||
        oldWidget.logicProgress != widget.logicProgress) {
      _fetchSuggestion();
    }
  }

  Future<void> _fetchSuggestion() async {
    setState(() => _isLoading = true);
    String result = await _aiService.getDailyRecommendation(
      ngonNguRate: widget.ngonNguProgress,
      toanHocRate: widget.toanHocProgress,
      logicRate: widget.logicProgress,
    );
    if (mounted) {
      setState(() {
        _suggestion = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, const Color(0xFF002045)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withOpacity(0.3),
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade400,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wb_sunny_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Gợi ý học hôm nay',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _isLoading
              ? Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Đang phân tích tiến độ của bạn...',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                )
              : Text(
                  _suggestion,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
        ],
      ),
    );
  }
}
