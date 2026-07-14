import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final Color _primary = const Color(0xFF002045);
  final Color _bgLight = const Color(0xFFF8F9FF);

  bool _allNotif = true;
  bool _newExamNotif = true;
  bool _adminNotif = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _requestPermission(); // Xin quyền hiển thị thông báo từ hệ điều hành
  }

  // --- XIN QUYỀN HỆ ĐIỀU HÀNH ---
  Future<void> _requestPermission() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  // --- TẢI TRẠNG THÁI TỪ CACHE ---
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _newExamNotif = prefs.getBool('notif_new_exam') ?? true;
      _adminNotif = prefs.getBool('notif_admin') ?? true;
      // Nút tổng sẽ BẬT nếu cả 2 nút con đều BẬT
      _allNotif = _newExamNotif && _adminNotif;
    });
  }

  // --- LƯU TRẠNG THÁI VÀ GỌI FIREBASE ---
  Future<void> _applySettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Lưu vào bộ nhớ máy
    await prefs.setBool('notif_new_exam', _newExamNotif);
    await prefs.setBool('notif_admin', _adminNotif);

    // GỌI FIREBASE ĐỂ ÁP DỤNG THÔNG BÁO THẬT
    if (_newExamNotif) {
      await FirebaseMessaging.instance.subscribeToTopic('new_exam');
    } else {
      await FirebaseMessaging.instance.unsubscribeFromTopic('new_exam');
    }

    if (_adminNotif) {
      await FirebaseMessaging.instance.subscribeToTopic('admin_alerts');
    } else {
      await FirebaseMessaging.instance.unsubscribeFromTopic('admin_alerts');
    }
  }

  // --- LOGIC XỬ LÝ KHI BẤM NÚT TỔNG ---
  void _toggleAll(bool value) {
    setState(() {
      _allNotif = value;
      _newExamNotif = value;
      _adminNotif = value;
    });
    _applySettings();
  }

  // --- LOGIC XỬ LÝ KHI BẤM NÚT CON ---
  void _toggleSingle(String type, bool value) {
    setState(() {
      if (type == 'exam') _newExamNotif = value;
      if (type == 'admin') _adminNotif = value;

      // Tự động cập nhật nút Tổng
      _allNotif = _newExamNotif && _adminNotif;
    });
    _applySettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: const Text(
          'Cài đặt thông báo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Tùy chỉnh nhận thông báo hệ thống:',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 16),

          // NÚT TỔNG (BẬT TẤT CẢ)
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: _allNotif ? _primary : Colors.grey.shade200,
                width: _allNotif ? 1.5 : 1,
              ),
            ),
            child: SwitchListTile(
              activeColor: _primary,
              title: const Text(
                'Bật tất cả thông báo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              value: _allNotif,
              onChanged: _toggleAll,
            ),
          ),

          const SizedBox(height: 16),

          // CÁC NÚT CON
          Material(
            color: Colors.white,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  activeColor: _primary,
                  title: const Text(
                    'Thông báo Đề mới',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Nhận cảnh báo khi có đề thi thử ĐGNL mới',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _newExamNotif,
                  onChanged: (val) => _toggleSingle('exam', val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  activeColor: _primary,
                  title: const Text(
                    'Thông báo từ Quản trị viên',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Các cảnh báo quan trọng, bảo trì hệ thống',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _adminNotif,
                  onChanged: (val) => _toggleSingle('admin', val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
