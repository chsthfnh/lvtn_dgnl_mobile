import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/login_screen.dart';
import 'practice_screens/practice_setup_screen.dart';
import 'mock_exam_screens/mock_exam_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  String _fullName = 'La Chí Thành';
  String _email = 'hocvien@gmail.com';
  String _role = 'student';
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // --- HÀM TẢI DỮ LIỆU TỪ FIRESTORE ---
  Future<void> _fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => _isLoadingProfile = true);
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _fullName = data['fullName'] ?? 'La Chí Thành';
            _email = data['email'] ?? user.email ?? '';
            _role = data['role'] ?? 'student';
          });
        }
      } catch (e) {
        debugPrint('Lỗi tải thông tin: $e');
      } finally {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  // --- HÀM ĐĂNG XUẤT AN TOÀN ---
  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi hệ thống không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              // 1. Đóng hộp thoại
              Navigator.pop(dialogContext);

              try {
                // 2. Chỉ cần đăng xuất Firebase Auth là đủ bảo mật phiên đăng nhập
                await FirebaseAuth.instance.signOut();

                // 3. Chuyển trang an toàn
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lỗi đăng xuất: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text(
              'Đăng xuất',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeBody(),
      const PracticeSetupScreen(isTab: true),
      _buildPlaceholderBody('Giao diện Thống kê chi tiết lịch sử'),
      _buildProfileBody(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      // FIX: Ẩn thanh AppBar chính của Dashboard nếu đang ở Tab Luyện tập (index 1) hoặc Tab Hồ sơ (index 3)
      appBar: (_selectedIndex == 1 || _selectedIndex == 3)
          ? null
          : AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.assignment,
                      color: Color(0xFF1976D2),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'EduTest ĐGNL',
                    style: TextStyle(
                      color: Color(0xFF1A237E),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_none_outlined,
                    color: Color(0xFF1A237E),
                    size: 28,
                  ),
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: pages[_selectedIndex],

      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: Colors.greenAccent.shade100,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              );
            }
            return const TextStyle(fontSize: 12, color: Colors.grey);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          backgroundColor: Colors.white,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: Colors.green),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: Icon(Icons.edit_note_outlined),
              selectedIcon: Icon(Icons.edit_note, color: Color(0xFF1A237E)),
              label: 'Luyện tập',
            ),
            NavigationDestination(
              icon: Icon(Icons.show_chart_outlined),
              selectedIcon: Icon(Icons.show_chart, color: Color(0xFF1A237E)),
              label: 'Thống kê',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: Color(0xFF1A237E)),
              label: 'Hồ sơ',
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: GIAO DIỆN TRANG CHỦ ---
  Widget _buildHomeBody() {
    String shortName = _fullName.split(' ').last;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chào bạn, $shortName',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tiếp tục hành trình chinh phục kỳ thi ĐGNL nhé!',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                // ignore: deprecated_member_use
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tiến độ học tập',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                    Icon(Icons.trending_up, color: Colors.green[700]),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: 0.75,
                            strokeWidth: 8,
                            backgroundColor: Colors.grey[200],
                            color: Colors.green[700],
                          ),
                          Center(
                            child: Text(
                              '75%',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        children: [
                          _buildLinearProgress('Toán học', 0.80),
                          const SizedBox(height: 12),
                          _buildLinearProgress('Văn học', 0.65),
                          const SizedBox(height: 12),
                          _buildLinearProgress('Tiếng Anh', 0.90),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              // Thay thế dòng cũ bằng dòng này:
              Expanded(
                child: _buildMenuCard(
                  'Luyện tập\ntheo môn',
                  Icons.menu_book,
                  const Color(0xFF28355A),
                  Colors.white,
                  Colors.blue[200]!,
                  () {
                    // Hàm chuyển trang
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PracticeSetupScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMenuCard(
                  'Thi thử ĐGNL\n',
                  Icons.quiz_outlined,
                  const Color(0xFFE8EAF6),
                  const Color(0xFF1A237E),
                  const Color(0xFF1A237E),
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MockExamScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMenuCard(
                  'AI Tutor\n',
                  Icons.smart_toy_outlined,
                  Colors.white,
                  const Color(0xFFE65100),
                  const Color(0xFFE65100),
                  () {},
                  borderColor: Colors.grey.shade200,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMenuCard(
                  'Thống kê\n',
                  Icons.bar_chart,
                  const Color(0xFFF3F4F6),
                  const Color(0xFF1A237E),
                  const Color(0xFF1A237E),
                  () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Đề thi đề xuất',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Xem tất cả >',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          _buildExamCard(
            'ĐHQG HCM',
            'Đề thi thử nghiệm ĐGNL ĐHQG-HCM Năm 2024 (Đề 1)',
            '150 phút',
            '120 câu',
          ),
          const SizedBox(height: 16),
          _buildExamCard(
            'LUYỆN TẬP',
            'Chuyên đề: Tư duy Logic & Phân tích số liệu (Mức Khó)',
            '45 phút',
            '40 câu',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- TAB 4: GIAO DIỆN HỒ SƠ TÀI KHOẢN ---
  Widget _buildProfileBody() {
    return SafeArea(
      child: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 30.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A237E),
                            shape: BoxShape.circle,
                            boxShadow: [
                              // ignore: deprecated_member_use
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 65,
                            color: Colors.white,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    _fullName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    alignment: Alignment.center,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 80,
                    ), // Thu hẹp chiều ngang của tag
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      _role == 'admin' ? 'Quản trị viên' : 'Tài khoản Học viên',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 35),

                  const Text(
                    'Thông tin cá nhân',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildProfileItem(
                          Icons.badge_outlined,
                          'Mã số học viên',
                          'DH52201455',
                        ),
                        const Divider(height: 1, indent: 55),
                        _buildProfileItem(
                          Icons.email_outlined,
                          'Địa chỉ Email',
                          _email,
                        ),
                        const Divider(height: 1, indent: 55),
                        _buildProfileItem(
                          Icons.account_balance_outlined,
                          'Cơ sở đào tạo',
                          'Đại học Công nghệ Sài Gòn (STU)',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.red[50],
                      foregroundColor: Colors.red[700],
                      elevation: 0,
                      side: BorderSide(color: Colors.red.shade100),
                    ),
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout_rounded, size: 22),
                    label: const Text(
                      'ĐĂNG XUẤT TÀI KHOẢN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // --- WIDGET HELPER ---
  Widget _buildProfileItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1A237E), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderBody(String message) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  Widget _buildLinearProgress(String title, double percent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            Text(
              '${(percent * 100).toInt()}%',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: percent,
          backgroundColor: Colors.grey[200],
          color: Colors.green[700],
          minHeight: 6,
          borderRadius: BorderRadius.circular(10),
        ),
      ],
    );
  }

  Widget _buildMenuCard(
    String title,
    IconData icon,
    Color bgColor,
    Color textColor,
    Color iconColor,
    VoidCallback onTap, {
    Color? borderColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: borderColor != null ? Border.all(color: borderColor) : null,
          boxShadow: [
            if (bgColor == Colors.white)
              // ignore: deprecated_member_use
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamCard(
    String tag,
    String title,
    String duration,
    String questions,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                // ignore: deprecated_member_use
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D9FF).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                ),
              ),
              const Icon(Icons.more_vert, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                duration,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(width: 24),
              const Icon(
                Icons.format_list_bulleted,
                size: 16,
                color: Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                questions,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
