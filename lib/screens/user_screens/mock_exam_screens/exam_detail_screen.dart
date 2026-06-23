import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'real_exam_screen.dart';

class ExamDetailScreen extends StatelessWidget {
  final DocumentSnapshot examDoc;

  const ExamDetailScreen({super.key, required this.examDoc});

  // --- BẢNG MÀU DESIGN SYSTEM ---
  final Color _primary = const Color(0xFF002045);
  final Color _bgLight = const Color(0xFFF8F9FF);
  final Color _surfaceLow = const Color(0xFFEFF4FF);
  final Color _outline = const Color(0xFFC4C6CF);

  @override
  Widget build(BuildContext context) {
    // --- 1. TRÍCH XUẤT VÀ TÍNH TOÁN DỮ LIỆU ---
    Map<String, dynamic> data = examDoc.data() as Map<String, dynamic>;

    String title = data['tenDeThi'] ?? 'Đề thi ĐGNL';
    int timeInMinutes = data['thoiGian'] ?? 150;
    int totalQuestions = data['soCauHoi'] ?? 120;

    // Thuật toán tính thang điểm: Số câu hỏi * 10
    int totalScore = totalQuestions * 10;

    // Lấy cấu trúc đề thi (Nếu Admin chưa set, dùng mảng rỗng để không bị lỗi)
    // Giả định Admin lưu cấu trúc dạng List các Map:
    // [{'tenPhan': 'Sử dụng ngôn ngữ', 'soCau': 60, 'chiTiet': 'Tiếng Việt (30)...'}]
    List<dynamic> cauTruc =
        data['cauTruc'] ??
        [
          {
            'tenPhan': 'Sử dụng ngôn ngữ',
            'soCau': 60,
            'chiTiet': 'Tiếng Việt (30 câu) & Tiếng Anh (30 câu)',
          },
          {
            'tenPhan': 'Toán học',
            'soCau': 30,
            'chiTiet':
                'Toán học (10 câu), Tư duy logic (10 câu), Phân tích số liệu (10 câu)',
          },
          {
            'tenPhan': 'Tư duy khoa học',
            'soCau': 30,
            'chiTiet': 'Logic (12 Câu) & Suy Luận (18 Câu)',
          },
        ];

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _bgLight,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Chi tiết đề thi',
          style: TextStyle(
            color: _primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: _primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thông tin phiên bản đề thi: v1.0'),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // --- 2. BANNER ĐỀ THI ---
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF5D849A),
                        Color(0xFF1A365D),
                        Color(0xFF002045),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Hiệu ứng pattern mờ (Nếu có ảnh pattern, dùng DecorationImage)
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // --- 3. KHỐI THỐNG KÊ (GRID) ---
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        Icons.timer_outlined,
                        'Thời gian',
                        '$timeInMinutes Phút',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        Icons.format_list_bulleted,
                        'Số câu hỏi',
                        '$totalQuestions Câu',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildStatCard(
                  null,
                  'Thang điểm',
                  '$totalScore Điểm',
                  isFullWidth: true,
                ),
                const SizedBox(height: 32),

                // --- 4. CẤU TRÚC ĐỀ THI ---
                Row(
                  children: [
                    Icon(Icons.account_tree_outlined, color: _primary),
                    const SizedBox(width: 8),
                    Text(
                      'Cấu trúc đề thi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Render linh hoạt danh sách cấu trúc từ Firebase
                ...List.generate(cauTruc.length, (index) {
                  var item = cauTruc[index];
                  return _buildStructureItem(
                    _getRomanNumeral(index + 1),
                    item['tenPhan'] ?? 'Phần ${index + 1}',
                    '${item['soCau']} Câu',
                    item['chiTiet'] ?? '',
                  );
                }),
                const SizedBox(height: 32),

                // --- 5. QUY ĐỊNH & LƯU Ý ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _surfaceLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _outline.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.rule, color: _primary),
                          const SizedBox(width: 8),
                          Text(
                            'Quy định & Lưu ý',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildRuleItem(
                        Icons.check_circle_outline,
                        Colors.green,
                        'Thời gian làm bài liên tục:',
                        'Đồng hồ sẽ không dừng lại kể cả khi bạn thoát ứng dụng.',
                      ),
                      const SizedBox(height: 12),
                      _buildRuleItem(
                        Icons.warning_amber_rounded,
                        Colors.red,
                        'Môi trường tập trung:',
                        'Khuyến nghị làm bài ở nơi yên tĩnh, kết nối mạng ổn định để tránh gián đoạn.',
                      ),
                      const SizedBox(height: 12),
                      _buildRuleItem(
                        Icons.u_turn_left,
                        _primary,
                        'Điều hướng linh hoạt:',
                        'Bạn có thể quay lại các câu hỏi trước để sửa đáp án trước khi nộp bài.',
                      ),
                      const SizedBox(height: 12),
                      _buildRuleItem(
                        Icons.check_circle_outline,
                        Colors.green,
                        'Kết quả và phân tích chi tiết',
                        'sẽ được hiển thị ngay sau khi bạn xác nhận Nộp Bài.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- 6. NÚT BẮT ĐẦU LÀM BÀI (STICKY BOTTOM) ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RealExamScreen(examDoc: examDoc),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Bắt đầu làm bài',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HÀM HỖ TRỢ XÂY DỰNG GIAO DIỆN (WIDGET BUILDERS) ---

  Widget _buildStatCard(
    IconData? icon,
    String label,
    String value, {
    bool isFullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outline.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: _primary, size: 24),
            const SizedBox(height: 8),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStructureItem(
    String romanNum,
    String title,
    String badgeTxt,
    String subtitle,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outline.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE5EEFF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                romanNum,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _primary,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _primary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5EEFF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeTxt,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _primary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(
    IconData icon,
    Color iconColor,
    String boldText,
    String normalText,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.5,
              ),
              children: [
                TextSpan(
                  text: '$boldText ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: normalText),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Thuật toán chuyển số nguyên thành số La Mã (I, II, III...)
  String _getRomanNumeral(int number) {
    List<String> numerals = [
      "",
      "I",
      "II",
      "III",
      "IV",
      "V",
      "VI",
      "VII",
      "VIII",
      "IX",
      "X",
    ];
    if (number > 0 && number <= 10) return numerals[number];
    return number.toString();
  }
}
