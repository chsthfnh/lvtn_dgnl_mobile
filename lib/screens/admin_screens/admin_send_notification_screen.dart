import 'package:flutter/material.dart';
import '../../../services/admin_notification_service.dart'; // Chỉnh lại đường dẫn nếu cần

class AdminSendNotificationScreen extends StatefulWidget {
  const AdminSendNotificationScreen({super.key});

  @override
  State<AdminSendNotificationScreen> createState() =>
      _AdminSendNotificationScreenState();
}

class _AdminSendNotificationScreenState
    extends State<AdminSendNotificationScreen> {
  final Color _primary = const Color(0xFF002045);
  final AdminNotificationService _notiService = AdminNotificationService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();

  String _selectedTopic = 'admin_alerts'; // Mặc định là thông báo hệ thống
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _handleSendNotification() async {
    // Kiểm tra dữ liệu rỗng
    if (_titleController.text.trim().isEmpty ||
        _bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đầy đủ Tiêu đề và Nội dung!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Gọi hàm Service ở Bước 4
    bool success = await _notiService.sendNotification(
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
      topic: _selectedTopic,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tạo thông báo thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      _titleController.clear();
      _bodyController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _notiService.lastError ??
                'Lỗi khi gửi thông báo. Vui lòng thử lại!',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        title: const Text(
          'Gửi Thông Báo (Admin)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CHỌN CHỦ ĐỀ GỬI
                const Text(
                  'Chọn nhóm nhận thông báo:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedTopic,
                      isExpanded: true,
                      icon: Icon(Icons.keyboard_arrow_down, color: _primary),
                      items: const [
                        DropdownMenuItem(
                          value: 'new_exam',
                          child: Text('Nhóm: Đề thi & Tài liệu mới'),
                        ),
                        DropdownMenuItem(
                          value: 'admin_alerts',
                          child: Text('Nhóm: Thông báo Hệ thống (Quản trị)'),
                        ),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedTopic = newValue);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // NHẬP TIÊU ĐỀ
                const Text(
                  'Tiêu đề thông báo:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'VD: Đã có đề thi ĐGNL mới...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // NHẬP NỘI DUNG
                const Text(
                  'Nội dung chi tiết:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bodyController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        'Nhập nội dung thông điệp bạn muốn gửi đến học viên...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // NÚT BẤM GỬI
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleSendNotification,
                    icon: const Icon(Icons.send),
                    label: const Text(
                      'PHÁT SÓNG THÔNG BÁO',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // HIỆN LOADING KHI ĐANG GỬI
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
