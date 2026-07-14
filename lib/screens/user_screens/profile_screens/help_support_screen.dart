import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Import thư viện

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  // --- HÀM XỬ LÝ GỬI EMAIL ---
  Future<void> _launchEmail(BuildContext context) async {
    // 1. Cấu hình nội dung Email
    String emailTo = 'lachithanh0011@gmail.com';
    String subject = 'Yêu cầu hỗ trợ từ App EduTest ĐGNL';
    String body = 'Chào đội ngũ hỗ trợ,\n\nTôi đang gặp vấn đề sau:\n\n';

    // 2. Tạo đường dẫn mailto (Mã hóa nội dung để tránh lỗi font chữ tiếng Việt)
    String? encodeQueryParameters(Map<String, String> params) {
      return params.entries
          .map(
            (MapEntry<String, String> e) =>
                '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
          )
          .join('&');
    }

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: emailTo,
      query: encodeQueryParameters(<String, String>{
        'subject': subject,
        'body': body,
      }),
    );

    // 3. Thực hiện gọi ứng dụng Email
    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Không tìm thấy ứng dụng Email nào trên máy của bạn.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể mở ứng dụng Email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primary = const Color(0xFF002045);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        title: const Text(
          'Trợ giúp & Hỗ trợ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: primary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.support_agent, color: Colors.white, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bạn cần giúp đỡ?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hãy xem các câu hỏi thường gặp bên dưới hoặc liên hệ trực tiếp với chúng tôi.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Câu hỏi thường gặp',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildFAQTile(
                  'Làm sao để làm bài thi khi không có mạng?',
                  'Bạn có thể tải đề thi về máy trước từ Trang chủ. Sau đó vào Kho Đề Offline để làm bài mà không cần kết nối internet.',
                  primary,
                ),
                _buildFAQTile(
                  'AI báo cáo năng lực hoạt động như thế nào?',
                  'Hệ thống AI sẽ thu thập điểm số và thời gian làm bài của bạn qua các bài kiểm tra, sau đó đưa ra phân tích chi tiết về điểm mạnh, điểm yếu.',
                  primary,
                ),
                _buildFAQTile(
                  'Tôi có thể reset tiến trình luyện tập không?',
                  'Có, trong phần Thiết lập luyện tập, bạn nhấn vào biểu tượng Tải lại (màu đỏ) ở bảng Vượt ải để reset tiến trình.',
                  primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // --- NÚT BẤM GỌI HÀM EMAIL VỪA TẠO ---
          OutlinedButton.icon(
            onPressed: () => _launchEmail(context),
            icon: const Icon(Icons.email_outlined),
            label: const Text('Gửi Email cho Hỗ trợ kỹ thuật'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: primary,
              side: BorderSide(color: primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQTile(String question, String answer, Color primary) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      iconColor: primary,
      collapsedIconColor: Colors.grey,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: Text(
            answer,
            style: TextStyle(color: Colors.grey.shade700, height: 1.5),
          ),
        ),
      ],
    );
  }
}
