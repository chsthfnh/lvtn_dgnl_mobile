import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'practice_screens/practice_setup_screen.dart';
import 'mock_exam_screens/mock_exam_screen.dart';
import 'profile_screen.dart';
import 'mock_exam_screens/exam_detail_screen.dart';
import 'statistics_screen/statistics_screen.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  String _fullName = 'Học viên';

  // Biến lưu trữ tiến độ thực tế
  double _overallProgress = 0.0;
  double _ngonNguProgress = 0.0;
  double _toanHocProgress = 0.0;
  double _logicProgress = 0.0;

  // ĐÃ THÊM: Biến này dùng để quản lý luồng lắng nghe dữ liệu
  StreamSubscription<QuerySnapshot>? _historySub;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _listenToRealProgress(); // ĐÃ SỬA: Gọi hàm lắng nghe Real-time
  }

  @override
  void dispose() {
    // ĐÃ THÊM: Hủy lắng nghe khi đóng màn hình để giải phóng RAM
    _historySub?.cancel();
    super.dispose();
  }

  // --- HÀM TẢI TÊN NGƯỜI DÙNG (Giữ nguyên) ---
  Future<void> _fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() => _fullName = data['fullName'] ?? 'Học viên');
          }
        }
      } catch (e) {
        debugPrint('Lỗi tải tên: $e');
      }
    }
  }

  // --- HÀM MỚI: LẮNG NGHE VÀ PHÂN LOẠI MÔN HỌC (REAL-TIME) ---
  void _listenToRealProgress() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _historySub = FirebaseFirestore.instance
        .collection('ExamHistory')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .listen(
          (history) {
            if (history.docs.isEmpty) return;

            int totalC = 0, totalQ = 0;
            int nnC = 0, nnQ = 0; // Ngôn ngữ
            int thC = 0, thQ = 0; // Toán học
            int tdC = 0, tdQ = 0; // Tư duy / Khoa học
            int genC = 0, genQ = 0; // Đề thi thử chung

            for (var doc in history.docs) {
              var data = doc.data() as Map<String, dynamic>;
              int c = data['correctAnswers'] ?? 0;
              int q = data['answeredCount'] ?? data['totalQuestions'] ?? 0;
              String name = (data['examName'] ?? '').toString().toLowerCase();

              totalC += c;
              totalQ += q;

              // Thuật toán phân loại theo từ khóa
              if (name.contains('ngôn ngữ') ||
                  name.contains('tiếng') ||
                  name.contains('văn')) {
                nnC += c;
                nnQ += q;
              } else if (name.contains('toán') || name.contains('số liệu')) {
                thC += c;
                thQ += q;
              } else if (name.contains('tư duy') ||
                  name.contains('khoa học') ||
                  name.contains('logic') ||
                  name.contains('lô gic')) {
                tdC += c;
                tdQ += q;
              } else {
                genC += c;
                genQ += q; // Tính vào điểm chung nếu là Đề thi thử
              }
            }

            if (totalQ > 0 && mounted) {
              setState(() {
                _overallProgress = totalC / totalQ;

                // Hàm tính điểm = (Điểm môn đó + Điểm đề thi chung)
                double calc(int specC, int specQ) {
                  int sumC = specC + genC;
                  int sumQ = specQ + genQ;
                  return sumQ > 0 ? sumC / sumQ : 0.0;
                }

                _ngonNguProgress = calc(nnC, nnQ);
                _toanHocProgress = calc(thC, thQ);
                _logicProgress = calc(tdC, tdQ);
              });
            }
          },
          onError: (e) {
            debugPrint('Lỗi tính tiến độ: $e');
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeBody(),
      const PracticeSetupScreen(isTab: true),
      const StatisticsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar:
          (_selectedIndex == 1 || _selectedIndex == 2 || _selectedIndex == 3)
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
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.school,
                      color: Color(0xFF002045),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'EduTest ĐGNL',
                    style: TextStyle(
                      color: Color(0xFF002045),
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
                    color: Color(0xFF002045),
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
          indicatorColor: Colors.greenAccent.withValues(alpha: 0.3),
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
          onDestinationSelected: (index) =>
              setState(() => _selectedIndex = index),
          backgroundColor: Colors.white,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: Colors.green),
              label: 'Trang chủ',
            ),
            NavigationDestination(
              icon: Icon(Icons.edit_note_outlined),
              selectedIcon: Icon(Icons.edit_note, color: Color(0xFF002045)),
              label: 'Luyện tập',
            ),
            NavigationDestination(
              icon: Icon(Icons.show_chart_outlined),
              selectedIcon: Icon(Icons.show_chart, color: Color(0xFF002045)),
              label: 'Thống kê',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: Color(0xFF002045)),
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
              color: Color(0xFF002045),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tiếp tục hành trình chinh phục kỳ thi ĐGNL nhé!',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // --- KHỐI TIẾN ĐỘ HỌC TẬP MỚI ---
          _buildProgressCard(),

          const SizedBox(height: 24),

          // KHÔI PHỤC LẠI 4 NÚT MENU NHANH ĐẸP MẮT
          Row(
            children: [
              Expanded(
                child: _buildMenuCard(
                  'Luyện tập\ntheo môn',
                  Icons.menu_book,
                  const Color(0xFF28355A),
                  Colors.white,
                  Colors.blue.withValues(alpha: 0.5),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PracticeSetupScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMenuCard(
                  'Thi thử ĐGNL\n',
                  Icons.quiz_outlined,
                  const Color(0xFFE8EAF6),
                  const Color(0xFF002045),
                  const Color(0xFF002045),
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MockExamScreen(),
                    ),
                  ),
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
                  borderColor: Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMenuCard(
                  'Thống kê\n',
                  Icons.bar_chart,
                  const Color(0xFFF3F4F6),
                  const Color(0xFF002045),
                  const Color(0xFF002045),
                  () => setState(() => _selectedIndex = 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // PHẦN ĐỀ THI ĐỀ XUẤT TỪ FIREBASE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Đề thi đề xuất',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF002045),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MockExamScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Xem tất cả >',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildExamStream(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- WIDGET VẼ CARD TIẾN ĐỘ ---
  Widget _buildProgressCard() {
    return InkWell(
      onTap: () => setState(() => _selectedIndex = 2),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
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
                    color: Color(0xFF002045),
                  ),
                ),
                Icon(
                  Icons.trending_up,
                  color: const Color(0xFF2E7D32),
                ), // Xanh lá
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                // Vòng tròn bên trái (Fix lỗi layout bằng cách fix cứng kích thước)
                SizedBox(
                  width: 90,
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 90,
                        height: 90,
                        child: CircularProgressIndicator(
                          value: _overallProgress,
                          strokeWidth: 10,
                          backgroundColor: const Color(0xFFE8F0FE), // Xanh nhạt
                          color: const Color(
                            0xFF2E7D32,
                          ), // Xanh lá đậm chuẩn thiết kế
                          strokeCap:
                              StrokeCap.round, // Bo tròn đầu vòng tiến độ
                        ),
                      ),
                      Text(
                        '${(_overallProgress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF002045),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Cột 3 thanh tiến độ bên phải
                Expanded(
                  child: Column(
                    children: [
                      _buildMiniProgress('Ngôn ngữ', _ngonNguProgress),
                      const SizedBox(height: 14),
                      _buildMiniProgress('Toán học', _toanHocProgress),
                      const SizedBox(height: 14),
                      _buildMiniProgress('Logic', _logicProgress),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniProgress(String label, double val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF43474E),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(val * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF002045),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: val,
          minHeight: 8,
          borderRadius: BorderRadius.circular(10),
          backgroundColor: const Color(0xFFE8F0FE),
          color: const Color(0xFF2E7D32),
        ),
      ],
    );
  }

  // --- KHÔI PHỤC WIDGET CÁC NÚT BẤM (ĐẸP NHƯ CŨ) ---
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
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
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

  // --- KHÔI PHỤC GIAO DIỆN THẺ ĐỀ THI ĐẸP ---
  Widget _buildExamStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Exams')
          .where('isPublic', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 30),
            alignment: Alignment.center,
            child: const Text(
              'Chưa có đề thi nào.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildExamCard(
                'MỚI NHẤT',
                data['tenDeThi'] ?? 'Đề thi ĐGNL',
                '${data['thoiGian'] ?? 150} phút',
                '${data['soCauHoi'] ?? 120} câu',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ExamDetailScreen(examDoc: doc),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildExamCard(
    String tag,
    String title,
    String duration,
    String questions,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D9FF).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002045),
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 14,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF002045),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}
