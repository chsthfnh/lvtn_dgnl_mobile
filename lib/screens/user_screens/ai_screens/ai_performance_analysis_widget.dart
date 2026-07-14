import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String _lastUpdatedTime = '';
  int _refreshCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCacheOrFetchAI();
  }

  // ĐÃ XÓA: Hàm didUpdateWidget cũ để tránh việc API bị gọi lại liên tục
  // mỗi khi dữ liệu thống kê bên ngoài thay đổi. Việc làm mới giờ do User quyết định.

  // --- 1. KIỂM TRA CACHE TRƯỚC KHI GỌI AI ---
  Future<void> _loadCacheOrFetchAI() async {
    final prefs = await SharedPreferences.getInstance();

    // Lấy ngày hôm nay
    DateTime now = DateTime.now();
    String today = "${now.year}-${now.month}-${now.day}";

    String cachedDate = prefs.getString('ai_report_date') ?? '';

    // Nếu đã cập nhật trong hôm nay -> Lấy từ Cache
    if (cachedDate == today) {
      setState(() {
        _analysisReport =
            prefs.getString('ai_report_text') ?? 'Không có dữ liệu.';
        _lastUpdatedTime = prefs.getString('ai_report_time') ?? '';
        _refreshCount = prefs.getInt('ai_report_count') ?? 0;
        _isLoading = false;
      });
    } else {
      // Sang ngày mới -> Tự động gọi API
      await _fetchNewAnalysis(prefs, today, 0);
    }
  }

  // --- 2. GỌI AI VÀ LƯU VÀO CACHE ---
  Future<void> _fetchNewAnalysis(
    SharedPreferences prefs,
    String todayDate,
    int newRefreshCount,
  ) async {
    setState(() => _isLoading = true);

    try {
      String result = await _aiService.analyzePerformance(
        historyStatsText: widget.historyStatsText,
      );

      DateTime now = DateTime.now();
      String timeStr =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ngày ${now.day}/${now.month}";

      // Dùng Key khác ('ai_report_...') để không bị đè lên Key của Gợi ý học tập
      await prefs.setString('ai_report_date', todayDate);
      await prefs.setString('ai_report_text', result);
      await prefs.setString('ai_report_time', timeStr);
      await prefs.setInt('ai_report_count', newRefreshCount);

      if (mounted) {
        setState(() {
          _analysisReport = result;
          _lastUpdatedTime = timeStr;
          _refreshCount = newRefreshCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _analysisReport =
              'Có lỗi khi phân tích dữ liệu. Vui lòng thử lại sau.';
          _isLoading = false;
        });
      }
    }
  }

  // --- 3. XỬ LÝ NÚT LÀM MỚI ---
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

    final prefs = await SharedPreferences.getInstance();
    DateTime now = DateTime.now();
    String today = "${now.year}-${now.month}-${now.day}";

    await _fetchNewAnalysis(prefs, today, _refreshCount + 1);
  }

  // --- 4. GIAO DIỆN ---
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

          // --- FOOTER: CHỮ MỜ & NÚT RESTART ---
          if (!_isLoading) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: Colors.black12),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cập nhật: $_lastUpdatedTime',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black38,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                InkWell(
                  onTap: _handleRefreshClick,
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
