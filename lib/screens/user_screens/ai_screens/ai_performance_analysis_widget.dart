import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../services/ai_tutor_service.dart';

class AIPerformanceAnalysisCard extends StatefulWidget {
  // Biến này sẽ nhận chuỗi tóm tắt dữ liệu từ màn hình Thống Kê truyền sang
  final String historyStatsText;

  const AIPerformanceAnalysisCard({super.key, required this.historyStatsText});

  @override
  State<AIPerformanceAnalysisCard> createState() =>
      _AIPerformanceAnalysisCardState();
}

class _AIPerformanceAnalysisCardState extends State<AIPerformanceAnalysisCard> {
  final AITutorService _aiService = AITutorService();
  String _analysisReport = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAnalysis();
  }

  // Cập nhật lại báo cáo nếu dữ liệu thống kê thay đổi
  @override
  void didUpdateWidget(covariant AIPerformanceAnalysisCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.historyStatsText != widget.historyStatsText) {
      _fetchAnalysis();
    }
  }

  Future<void> _fetchAnalysis() async {
    setState(() => _isLoading = true);
    String result = await _aiService.analyzePerformance(
      historyStatsText: widget.historyStatsText,
    );
    if (mounted) {
      setState(() {
        _analysisReport = result;
        _isLoading = false;
      });
    }
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
                  color: const Color(0xFFE8EAF6), // Xanh nhạt
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
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Color(0xFF002045)),
                        SizedBox(height: 12),
                        Text(
                          'AI đang tổng hợp và đánh giá dữ liệu...',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : MarkdownBody(
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
                    listBullet: const TextStyle(color: Color(0xFF002045)),
                  ),
                ),
        ],
      ),
    );
  }
}
