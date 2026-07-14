import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/login_screen.dart';
import 'import_questions_screen.dart';
import 'import_images_screen.dart';
import 'media_library_screen.dart';
import 'question_bank_screen.dart';
import 'create_exam_screen.dart';
import 'exam_list_screen.dart';
import '../user_screens/dashboard_screen.dart';
import 'admin_send_notification_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final Color _primaryDark = const Color(0xFF28355A); // Xanh đen chủ đạo
  final Color _bgLight = const Color(0xFFF8F9FA); // Màu nền xám nhạt

  // 1. Popup quản lý toàn bộ thông báo của Admin
  void _showAdminNotificationPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Quản lý thông báo',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF002045),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () =>
                        _showNotificationFormDialog(), // Nút tạo mới
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tạo mới'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('Notifications')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Chưa có thông báo nào được gửi đi.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var doc = snapshot.data!.docs[index];
                      var data = doc.data() as Map<String, dynamic>;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(
                            data['title'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            data['content'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: Colors.blue,
                                ),
                                onPressed: () => _showNotificationFormDialog(
                                  doc: doc,
                                ), // Gọi form để Sửa
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  bool confirm =
                                      await showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Xóa thông báo?'),
                                          content: const Text(
                                            'Thông báo này sẽ bị xóa khỏi máy tất cả học viên.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Hủy'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Xóa'),
                                            ),
                                          ],
                                        ),
                                      ) ??
                                      false;
                                  if (confirm) await doc.reference.delete();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. Form Tạo / Sửa thông báo dùng chung
  void _showNotificationFormDialog({DocumentSnapshot? doc}) {
    TextEditingController titleCtrl = TextEditingController(
      text: doc != null ? doc['title'] : '',
    );
    TextEditingController contentCtrl = TextEditingController(
      text: doc != null ? doc['content'] : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(doc == null ? 'Soạn thông báo mới' : 'Sửa thông báo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Tiêu đề'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Nội dung',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF002045),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (titleCtrl.text.isEmpty || contentCtrl.text.isEmpty) return;

              if (doc == null) {
                // TẠO MỚI
                await FirebaseFirestore.instance
                    .collection('Notifications')
                    .add({
                      'title': titleCtrl.text,
                      'content': contentCtrl.text,
                      'createdAt': FieldValue.serverTimestamp(),
                      'type': 'admin_news',
                      'readBy': [],
                      'deletedBy': [], // Quan trọng để User có thể xóa cá nhân
                    });
              } else {
                // CẬP NHẬT
                await doc.reference.update({
                  'title': titleCtrl.text,
                  'content': contentCtrl.text,
                });
              }
              if (mounted) Navigator.pop(ctx);
            },
            child: Text(doc == null ? 'Gửi đi' : 'Lưu lại'),
          ),
        ],
      ),
    );
  }

  // --- HÀM ĐĂNG XUẤT CHO ADMIN ---
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
              Navigator.pop(dialogContext);
              try {
                await FirebaseAuth.instance.signOut();
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
                onPressed: _showAdminNotificationPanel,
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(width: 8, height: 8),
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
              decoration: const BoxDecoration(color: Color(0xFF1A237E)),
              accountName: const Text(
                'Quản trị viên',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
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
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: _primaryDark),
              title: const Text(
                'Thư viện hình ảnh',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
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
              ),
              title: const Text(
                'Ngân hàng câu hỏi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const QuestionBankScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.assignment_outlined, color: _primaryDark),
              title: const Text(
                'Danh sách đề thi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ExamListScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.remove_red_eye_outlined,
                color: Colors.blue,
              ),
              title: const Text('Trải nghiệm Học viên'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DashboardScreen(),
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
            _buildActionCard(
              title: 'Import Questions',
              subtitle: 'Excel / CSV',
              icon: Icons.upload_file,
              isPrimary: true,
              onTap: () {
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
            // --- NÚT MỚI THÊM: GỬI THÔNG BÁO PUSH ---
            const SizedBox(height: 12),
            _buildActionCard(
              title: 'Push Notification',
              subtitle: 'Bắn thông báo xuống điện thoại',
              icon: Icons.send_to_mobile,
              isPrimary: true, // Đổi thành true để nút có màu xanh nổi bật
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AdminSendNotificationScreen(),
                  ),
                );
              },
            ),
            // ----------------------------------------

            // --- ĐÃ THAY THẾ: GIAO DIỆN GIÁM SÁT HOẠT ĐỘNG THAY CHO TOTAL STUDENTS ---
            _buildUserActivitySection(),

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

  // =======================================================================
  // CÁC HÀM XÂY DỰNG GIAO DIỆN MỚI CHO TÍNH NĂNG GIÁM SÁT HOẠT ĐỘNG REAL-TIME
  // =======================================================================

  // 1. Giao diện khối giám sát ngoài trang chủ (Hiển thị 3 người)
  Widget _buildUserActivitySection() {
    return StreamBuilder<QuerySnapshot>(
      // Lắng nghe toàn bộ users (Trừ admin)
      stream: FirebaseFirestore.instance
          .collection('Users')
          .where('role', isNotEqualTo: 'admin')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        List<Map<String, dynamic>> allUsers = [];
        DateTime now = DateTime.now();

        // Xử lý và phân loại trạng thái từng user
        for (var doc in snapshot.data!.docs) {
          var data = doc.data() as Map<String, dynamic>;
          Timestamp? lastActiveTs = data['lastActive'];
          String action = data['currentAction'] ?? 'offline';

          // THÊM ĐIỀU KIỆN NÀY:
          // Chỉ đưa vào danh sách giám sát nếu học viên ĐÃ TỪNG HOẠT ĐỘNG
          // (Tức là đã xác thực email và đăng nhập thành công ít nhất 1 lần)
          if (lastActiveTs != null) {
            bool isOffline = true;
            if (now.difference(lastActiveTs.toDate()).inMinutes < 5) {
              isOffline = false;
            }

            allUsers.add({
              'name': data['fullName'] ?? 'Học viên ẩn danh',
              'email': data['email'] ?? '',
              'lastActive': lastActiveTs.toDate(),
              'status': isOffline ? 'offline' : action,
            });
          }
        }

        // Sắp xếp: Ai vừa hoạt động gần nhất đưa lên đầu
        allUsers.sort((a, b) {
          DateTime? dateA = a['lastActive'];
          DateTime? dateB = b['lastActive'];
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA);
        });

        // Chỉ lấy 3 người cho giao diện ngoài
        var top3Users = allUsers.take(3).toList();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Trạng thái hoạt động',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002045),
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        _showAllUsersActivity(), // Không truyền danh sách tĩnh nữa
                    child: const Text(
                      'Xem tất cả >',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tổng số học viên: ${allUsers.length}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),

              if (top3Users.isEmpty)
                const Text(
                  'Chưa có dữ liệu hoạt động',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                ...top3Users.map((u) => _buildActivityRow(u)),
            ],
          ),
        );
      },
    );
  }

  // 2. Giao diện 1 dòng User trong bảng giám sát
  Widget _buildActivityRow(Map<String, dynamic> user) {
    String status = user['status'];
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'idle':
        statusColor = const Color(0xFF00C853);
        statusText = 'Truy cập nhưng chưa làm gì';
        statusIcon = Icons.computer;
        break;
      case 'exam':
        statusColor = const Color(0xFFE65100);
        statusText = 'Đang làm bài thi thử';
        statusIcon = Icons.timer;
        break;
      case 'practice':
        statusColor = Colors.blue;
        statusText = 'Đang làm bài luyện tập';
        statusIcon = Icons.edit_note;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Ngoại tuyến';
        statusIcon = Icons.bedtime_outlined;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey.shade100,
                child: const Icon(Icons.person, color: Colors.grey),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3. Popup xem toàn bộ danh sách (Đã nâng cấp Real-time)
  void _showAllUsersActivity() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),

        // THÊM STREAM BUILDER VÀO THẲNG ĐÂY ĐỂ POPUP TỰ ĐỘNG LÀM MỚI
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Users')
              .where('role', isNotEqualTo: 'admin')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // Tính toán lại dữ liệu y hệt bên ngoài
            List<Map<String, dynamic>> allUsers = [];
            DateTime now = DateTime.now();

            for (var doc in snapshot.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              Timestamp? lastActiveTs = data['lastActive'];
              String action = data['currentAction'] ?? 'offline';

              // THÊM ĐIỀU KIỆN NÀY:
              // Chỉ đưa vào danh sách giám sát nếu học viên ĐÃ TỪNG HOẠT ĐỘNG
              // (Tức là đã xác thực email và đăng nhập thành công ít nhất 1 lần)
              if (lastActiveTs != null) {
                bool isOffline = true;
                if (now.difference(lastActiveTs.toDate()).inMinutes < 5) {
                  isOffline = false;
                }

                allUsers.add({
                  'name': data['fullName'] ?? 'Học viên ẩn danh',
                  'email': data['email'] ?? '',
                  'lastActive': lastActiveTs.toDate(),
                  'status': isOffline ? 'offline' : action,
                });
              }
            }

            int idle = allUsers.where((u) => u['status'] == 'idle').length;
            int exam = allUsers.where((u) => u['status'] == 'exam').length;
            int practice = allUsers
                .where((u) => u['status'] == 'practice')
                .length;
            int offline = allUsers
                .where((u) => u['status'] == 'offline')
                .length;

            allUsers.sort((a, b) {
              DateTime? dateA = a['lastActive'];
              DateTime? dateB = b['lastActive'];
              if (dateA == null && dateB == null) return 0;
              if (dateA == null) return 1;
              if (dateB == null) return -1;
              return dateB.compareTo(dateA);
            });

            // Vẽ giao diện bằng dữ liệu mới nhất
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tất cả học viên',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatChip(
                        'Chưa làm gì ($idle)',
                        const Color(0xFF00C853),
                      ),
                      const SizedBox(width: 8),
                      _buildStatChip(
                        'Thi thử ($exam)',
                        const Color(0xFFE65100),
                      ),
                      const SizedBox(width: 8),
                      _buildStatChip('Luyện tập ($practice)', Colors.blue),
                      const SizedBox(width: 8),
                      _buildStatChip('Ngoại tuyến ($offline)', Colors.grey),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: allUsers.length,
                    itemBuilder: (context, index) =>
                        _buildActivityRow(allUsers[index]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // 4. Widget Chip trạng thái màu sắc
  Widget _buildStatChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  // =======================================================================
  // CÁC HÀM HELPER CŨ CỦA BẠN (GIỮ NGUYÊN KHÔNG ĐỔI)
  // =======================================================================

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
