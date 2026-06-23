import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // --- BẢNG MÀU DESIGN SYSTEM ---
  final Color _primary = const Color(0xFF002045);
  final Color _bgLight = const Color(0xFFF8F9FF);
  final Color _outline = const Color(0xFFE2E8F0);
  final Color _textPrimary = const Color(0xFF0B1C30);
  final Color _textSecondary = const Color(0xFF43474E);
  final Color _errorBg = const Color(0xFFFFDAD6);
  final Color _errorText = const Color(0xFFBA1A1A);

  // Biến tạm để giả lập dữ liệu (Sau này bạn có thể fetch từ Firestore)
  String _userName = "Nguyễn Văn A";
  String _userEmail = "user@email.com";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Hàm lấy thông tin user hiện tại từ Firebase Auth
  void _loadUserData() {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      setState(() {
        _userName = currentUser.displayName ?? "Học viên";
        _userEmail = currentUser.email ?? "";
      });
    }
  }

  // Hàm xử lý Đăng xuất
  Future<void> _handleLogout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã đăng xuất!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- 1. KHỐI THÔNG TIN CÁ NHÂN HEADER ---
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Avatar & Nút chỉnh sửa ảnh
                    Stack(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _bgLight,
                            image: const DecorationImage(
                              // Sửa lại link ảnh hoặc dùng asset của bạn
                              image: NetworkImage(
                                'https://cdn-icons-png.flaticon.com/512/3135/3135715.png',
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _userName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userEmail,
                      style: TextStyle(fontSize: 14, color: _textSecondary),
                    ),
                    const SizedBox(height: 16),
                    // Nút chỉnh sửa hồ sơ
                    ElevatedButton.icon(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      icon: const Icon(Icons.person_outline, size: 16),
                      label: const Text(
                        'Chỉnh sửa hồ sơ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // --- 2. CÁC NHÓM CÀI ĐẶT ---
              _buildSettingsGroup('TÀI KHOẢN', [
                _buildSettingsTile(Icons.lock_outline, 'Đổi mật khẩu'),
                _buildSettingsTile(
                  Icons.devices_outlined,
                  'Thiết bị đăng nhập',
                ),
                _buildSettingsTile(
                  Icons.notifications_none_outlined,
                  'Thông báo',
                  isLast: true,
                ),
              ]),

              _buildSettingsGroup('ỨNG DỤNG', [
                _buildSettingsTile(
                  Icons.palette_outlined,
                  'Giao diện',
                  trailingText: 'Sáng',
                ),
                _buildSettingsTile(
                  Icons.translate,
                  'Ngôn ngữ',
                  trailingText: 'Tiếng Việt',
                ),
                _buildSettingsTile(
                  Icons.cloud_download_outlined,
                  'Tải xuống ngoại tuyến',
                  isLast: true,
                ),
              ]),

              _buildSettingsGroup('THANH TOÁN', [
                _buildSettingsTile(
                  Icons.workspace_premium_outlined,
                  'Gói hiện tại',
                  trailingWidget: _buildBadge('STANDARD'),
                ),
                _buildSettingsTile(
                  Icons.history,
                  'Lịch sử thanh toán',
                  isLast: true,
                ),
              ]),

              _buildSettingsGroup('HỖ TRỢ', [
                _buildSettingsTile(Icons.help_outline, 'Trung tâm trợ giúp'),
                _buildSettingsTile(
                  Icons.chat_bubble_outline,
                  'Gửi phản hồi',
                  isLast: true,
                ),
              ]),

              _buildSettingsGroup('THÔNG TIN', [
                _buildSettingsTile(Icons.gavel_outlined, 'Điều khoản'),
                _buildSettingsTile(
                  Icons.shield_outlined,
                  'Chính sách riêng tư',
                ),
                _buildSettingsTile(
                  Icons.info_outline,
                  'Phiên bản ứng dụng',
                  trailingText: 'v1.0.0',
                  isLast: true,
                  showArrow: false,
                ),
              ]),

              const SizedBox(height: 12),

              // --- 3. NÚT ĐĂNG XUẤT ---
              ElevatedButton.icon(
                onPressed: _handleLogout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _errorBg,
                  foregroundColor: _errorText,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.logout, size: 20),
                label: const Text(
                  'Đăng xuất',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 40), // Spacing đáy
            ],
          ),
        ),
      ),
    );
  }

  // --- HÀM HỖ TRỢ XÂY DỰNG GIAO DIỆN ---

  // Xây dựng một nhóm các cài đặt (Ví dụ: TÀI KHOẢN, ỨNG DỤNG)
  Widget _buildSettingsGroup(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _primary,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _outline.withOpacity(0.5)),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  // Xây dựng từng dòng chức năng trong nhóm
  Widget _buildSettingsTile(
    IconData icon,
    String title, {
    String? trailingText,
    Widget? trailingWidget,
    bool isLast = false,
    bool showArrow = true,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Icon(icon, color: _textPrimary, size: 22),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              color: _textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailingText != null)
                Text(
                  trailingText,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              if (trailingWidget != null) trailingWidget,
              if (showArrow) ...[
                if (trailingText != null || trailingWidget != null)
                  const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
              ],
            ],
          ),
          onTap: () {
            // Xử lý sự kiện khi bấm vào từng mục
          },
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: _outline.withOpacity(0.5),
            indent: 50,
            endIndent: 16,
          ),
      ],
    );
  }

  // Xây dựng Badge (như nhãn STANDARD màu xanh)
  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF6BFF8F), // Màu xanh lá từ hệ thống
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Color(0xFF007432), // Màu chữ xanh lá đậm
        ),
      ),
    );
  }
}
