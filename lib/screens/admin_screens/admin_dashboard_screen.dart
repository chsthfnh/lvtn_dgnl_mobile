import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/login_screen.dart';
import 'import_questions_screen.dart';
import 'import_images_screen.dart';
import 'media_library_screen.dart';
import 'question_bank_screen.dart';
import 'create_exam_screen.dart';
import 'exam_list_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final Color _primaryDark = const Color(0xFF28355A); // Xanh đen chủ đạo
  final Color _bgLight = const Color(0xFFF8F9FA); // Màu nền xám nhạt

  // --- HÀM ĐĂNG XUẤT CHO ADMIN (ĐÃ LƯỢC BỎ GOOGLE SIGN IN ĐỂ CHỐNG LỖI) ---
  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi quyền Quản trị viên?',
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
                debugPrint('Lỗi đăng xuất: $e');
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
    return Scaffold(
      backgroundColor: _bgLight,
      // --- 1. THANH TIÊU ĐỀ (APP BAR) ---
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () {},
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none,
                  color: Colors.black87,
                ),
                onPressed: () {},
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),

      // --- 2. MENU TRƯỢT BÊN TRÁI (DRAWER) ---
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF1A237E), // Màu xanh đen chủ đạo của bạn
              ),
              // Tự động lấy Tên hiển thị từ Firebase (nếu có), nếu không có sẽ hiện 'Quản trị viên'
              accountName: Text(
                'Quản trị viên',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              // ĐÂY LÀ ĐOẠN ĐỔI TỪ GÁN CỨNG SANG EMAIL ĐĂNG NHẬP THỰC TẾ:
              accountEmail: Text(
                FirebaseAuth.instance.currentUser?.email ?? 'Chưa có email',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.admin_panel_settings,
                  size: 36,
                  color: Color(0xFF1A237E),
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.dashboard, color: _primaryDark),
              title: const Text(
                'Giao diện chính',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context); // Đóng menu
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: _primaryDark),
              title: const Text(
                'Thư viện hình ảnh',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context); // Đóng menu trượt
                // Mở màn hình Thư viện hình ảnh
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MediaLibraryScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.account_balance_outlined,
                color: _primaryDark,
              ), // Biểu tượng ngân hàng
              title: const Text(
                'Ngân hàng câu hỏi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context); // Đóng thanh menu trượt lại
                // Mở màn hình Ngân hàng câu hỏi
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QuestionBankScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons
                    .assignment_outlined, // Đổi sang biểu tượng Tập đề thi / Bài kiểm tra
                color: _primaryDark,
              ),
              title: const Text(
                'Danh sách đề thi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context); // Đóng Drawer trượt
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const ExamListScreen(), // Điều hướng chuẩn xác sang màn hình Danh sách Đề thi
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Đăng xuất',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: _handleLogout,
            ),
          ],
        ),
      ),

      // --- 3. NỘI DUNG CHÍNH (BODY) ---
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Các nút thao tác chức năng
            _buildActionCard(
              title: 'Import Questions',
              subtitle: 'Excel / CSV',
              icon: Icons.upload_file,
              isPrimary: true,
              onTap: () {
                // Chuyển hướng sang màn hình Import Câu hỏi
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ImportQuestionsScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActionCard(
              title: 'Import Images',
              subtitle: 'Media Library',
              icon: Icons.photo_library_outlined,
              isPrimary: false,
              onTap: () {
                // Thêm lệnh chuyển trang vào đây
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ImportImagesScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildActionCard(
              title: 'Create Exam',
              subtitle: 'From Question Bank',
              icon: Icons.post_add,
              isPrimary: false,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateExamScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Các thẻ Thống kê
            _buildStatCard(
              title: 'Total Students',
              value: '12,450',
              trendValue: '+ 12%',
              icon: Icons.people_outline,
              showChart: true,
            ),
            const SizedBox(height: 16),
            _buildStatCard(
              title: 'Total Exams',
              value: '342',
              trendValue: '+ 8%',
              icon: Icons.assignment_outlined,
              showChart: false,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPER: Thẻ chức năng (Action Card) ---
  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isPrimary ? _primaryDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? _primaryDark : Colors.grey.shade300,
          ),
          boxShadow: isPrimary
              // Đã dùng .withValues để tránh cảnh báo Deprecated
              ? [
                  BoxShadow(
                    color: _primaryDark.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isPrimary ? Colors.white : _primaryDark,
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isPrimary ? Colors.white : _primaryDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isPrimary ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPER: Thẻ Thống kê (Stat Card) ---
  Widget _buildStatCard({
    required String title,
    required String value,
    required String trendValue,
    required IconData icon,
    required bool showChart,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _primaryDark, size: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_upward,
                      size: 14,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trendValue,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _primaryDark,
            ),
          ),

          if (showChart) ...[
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBar(0.2, Colors.grey.shade300),
                _buildBar(0.4, Colors.blueGrey.shade300),
                _buildBar(0.3, Colors.blueGrey.shade400),
                _buildBar(0.6, Colors.blueGrey.shade500),
                _buildBar(0.9, _primaryDark),
                _buildBar(0.7, _primaryDark.withValues(alpha: 0.8)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- WIDGET HELPER: Cột biểu đồ giả lập ---
  Widget _buildBar(double heightFactor, Color color) {
    return Container(
      width: 40,
      height: 80 * heightFactor,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }
}
