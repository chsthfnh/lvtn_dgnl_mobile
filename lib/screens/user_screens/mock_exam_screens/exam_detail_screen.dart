import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'real_exam_screen.dart';
import '../../../services/hive_service.dart';

class ExamDetailScreen extends StatefulWidget {
  final DocumentSnapshot examDoc;

  const ExamDetailScreen({super.key, required this.examDoc});

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  // Khởi tạo Hive Service
  final HiveService _hiveService = HiveService();
  bool _isDownloading = false;

  // --- BẢNG MÀU DESIGN SYSTEM ---
  final Color _primary = const Color(0xFF002045);
  final Color _bgLight = const Color(0xFFF8F9FF);
  final Color _surfaceLow = const Color(0xFFEFF4FF);
  final Color _outline = const Color(0xFFC4C6CF);

  // Hàm xử lý tải đề
  void _handleDownload() async {
    setState(() => _isDownloading = true);

    Map<String, dynamic> examData =
        widget.examDoc.data() as Map<String, dynamic>;

    bool success = await _hiveService.downloadExamForOffline(
      examId: widget.examDoc.id,
      examData: examData,
    );

    if (mounted) {
      setState(() => _isDownloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Đã tải đề thi thành công! Bạn có thể làm khi không có mạng.'
                : 'Lỗi khi tải đề thi.',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> data = widget.examDoc.data() as Map<String, dynamic>;
    String title = data['tenDeThi'] ?? 'Đề thi ĐGNL';
    int timeInMinutes = data['thoiGian'] ?? 150;
    int totalQuestions = data['soCauHoi'] ?? 120;
    int totalScore = totalQuestions * 10;

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

    // Kiểm tra xem đề này đã tải chưa
    bool isDownloaded = _hiveService.isExamDownloaded(widget.examDoc.id);

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
                      colors: [
                        Color(0xFF5D849A),
                        Color(0xFF1A365D),
                        Color(0xFF002045),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
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
                          ),
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
                ...List.generate(cauTruc.length, (index) {
                  var item = cauTruc[index];
                  return _buildStructureItem(
                    _getRomanNumeral(index + 1),
                    item['tenPhan'] ?? 'Phần ${index + 1}',
                    '${item['soCau']} Câu',
                    item['chiTiet'] ?? '',
                  );
                }),
              ],
            ),
          ),

          // --- 6. NÚT TẢI VỀ & BẮT ĐẦU (STICKY BOTTOM) ---
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
              child: Column(
                mainAxisSize: MainAxisSize.min, // Để column ôm sát 2 nút
                children: [
                  // NÚT TẢI VỀ
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: (isDownloaded || _isDownloading)
                          ? null
                          : _handleDownload,
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              isDownloaded
                                  ? Icons.cloud_done
                                  : Icons.cloud_download,
                            ),
                      label: Text(
                        isDownloaded
                            ? 'Đã lưu trên máy (Offline)'
                            : 'Tải về máy (Học Offline)',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: isDownloaded ? Colors.green : _primary,
                        side: BorderSide(
                          color: isDownloaded ? Colors.green : _primary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // NÚT BẮT ĐẦU LÀM BÀI
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                RealExamScreen(examDoc: widget.examDoc),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward, size: 20),
                      label: const Text(
                        'Bắt đầu làm bài',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CÁC HÀM XÂY DỰNG UI BÊN DƯỚI GIỮ NGUYÊN ---
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
