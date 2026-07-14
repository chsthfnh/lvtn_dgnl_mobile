import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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

  @override
  void initState() {
    super.initState();
    _loadCacheOrFetchAI();
  }

  // --- 1. KIỂM TRA CACHE TRƯỚC KHI GỌI AI ---
  Future<void> _loadCacheOrFetchAI() async {
    final prefs = await SharedPreferences.getInstance();

    // Lấy ngày hôm nay (VD: 2026-7-14)
    DateTime now = DateTime.now();
    String today = "${now.year}-${now.month}-${now.day}";

    String cachedDate = prefs.getString('ai_suggest_date') ?? '';

    // Nếu dữ liệu đã được cập nhật TRONG HÔM NAY -> Lấy từ Cache ra dùng luôn
    if (cachedDate == today) {
      setState(() {
        _aiResponse = prefs.getString('ai_suggest_text') ?? 'Không có dữ liệu.';
        _lastUpdatedTime = prefs.getString('ai_suggest_time') ?? '';
        _refreshCount = prefs.getInt('ai_suggest_count') ?? 0;
        _isLoading = false;
      });
    } else {
      // Nếu là qua ngày mới -> Tự động gọi AI và reset lượt refresh về 0
      await _fetchNewSuggestion(prefs, today, 0);
    }
  }

  // --- 2. GỌI AI VÀ LƯU VÀO CACHE ---
  Future<void> _fetchNewSuggestion(
    SharedPreferences prefs,
    String todayDate,
    int newRefreshCount,
  ) async {
    setState(() => _isLoading = true);

    // Chuẩn bị câu lệnh Prompt
    String prompt =
        '''
Dựa vào tiến độ học tập: Ngôn ngữ ${(widget.ngonNguProgress * 100).toInt()}%, Toán học ${(widget.toanHocProgress * 100).toInt()}%, Logic ${(widget.logicProgress * 100).toInt()}%.
Hãy cho tôi 1 lời khuyên ngắn gọn (khoảng 3-4 dòng) để cải thiện trong hôm nay.
''';

    try {
      String response = await _aiService.sendMessage(prompt, 'Gợi ý học tập');

      // Lấy giờ phút hiện tại để in ra dòng chữ mờ
      DateTime now = DateTime.now();
      String timeStr =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} ngày ${now.day}/${now.month}";

      // Lưu toàn bộ vào SharedPreferences
      await prefs.setString('ai_suggest_date', todayDate);
      await prefs.setString('ai_suggest_text', response);
      await prefs.setString('ai_suggest_time', timeStr);
      await prefs.setInt('ai_suggest_count', newRefreshCount);

      if (mounted) {
        setState(() {
          _aiResponse = response;
          _lastUpdatedTime = timeStr;
          _refreshCount = newRefreshCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiResponse = 'Có lỗi khi lấy gợi ý từ AI. Vui lòng thử lại sau.';
          _isLoading = false;
        });
      }
    }
  }

  // --- 3. XỬ LÝ NÚT RESTART ---
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
    DateTime now = DateTime.now();
    String today = "${now.year}-${now.month}-${now.day}";

    // Gọi hàm fetch và cộng thêm 1 lượt refresh
    await _fetchNewSuggestion(prefs, today, _refreshCount + 1);
  }

  // --- 4. GIAO DIỆN ---
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1), // Vàng nhạt
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
              Text(
                'AI Gợi ý hôm nay',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // NỘI DUNG AI
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  ),
                )
              : MarkdownBody(
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

          // FOOTER: CHỮ MỜ & NÚT RESTART
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Dòng chữ mờ nhỏ
              Text(
                'Cập nhật: $_lastUpdatedTime',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black38,
                  fontStyle: FontStyle.italic,
                ),
              ),

              // Nút Restart có đếm số lượt
              InkWell(
                onTap: _isLoading ? null : _handleRefreshClick,
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
