import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';
import '../screens/user_screens/dashboard_screen.dart';
import '../screens/admin_screens/admin_dashboard_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  static final Set<String> _sessionChecksInProgress = <String>{};

  // --- HÀM KIỂM TRA VÀ ĐÁ VĂNG THIẾT BỊ KHÁC ---
  Future<void> _checkAndKick(BuildContext context, String userId) async {
    // Tránh một snapshot tạo ra nhiều tiến trình kiểm tra giống nhau.
    if (!_sessionChecksInProgress.add(userId)) return;

    try {
      // Chờ thao tác đăng nhập hoàn tất việc lưu session local và Firestore.
      // Khoảng chờ này ngăn thiết bị mới tự đá chính nó do độ trễ đồng bộ.
      await Future<void>.delayed(const Duration(milliseconds: 800));

      final prefs = await SharedPreferences.getInstance();
      final String? localSessionId = prefs.getString('current_session_id');

      // Chưa lưu xong phiên đăng nhập thì chưa được kết luận là trùng phiên.
      if (localSessionId == null || localSessionId.isEmpty) return;

      // Đọc lại dữ liệu mới nhất, không sử dụng sessionId từ snapshot cũ.
      final latestUserDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();

      if (!latestUserDoc.exists) return;

      final data = latestUserDoc.data();
      final String? remoteSessionId = data?['sessionId']?.toString();

      if (remoteSessionId == null || remoteSessionId.isEmpty) return;

      if (localSessionId != remoteSessionId) {
        await prefs.remove('current_session_id');
        await FirebaseAuth.instance.signOut();

        if (!context.mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Tài khoản của bạn vừa được đăng nhập ở thiết bị khác!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
      }
    } catch (e) {
      debugPrint('Lỗi kiểm tra phiên đăng nhập: $e');
    } finally {
      _sessionChecksInProgress.remove(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 1. Nếu không có phiên đăng nhập tồn tại
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        final user = snapshot.data!;

        // 2. CHẶN BẢO MẬT: Chờ xác thực Email
        if (!user.emailVerified) {
          return const LoginScreen();
        }

        // 3. KIỂM TRA SESSION VÀ PHÂN QUYỀN TRONG THỜI GIAN THỰC (REAL-TIME)
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('Users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Lỗi đọc Firestore: không nên coi là tài khoản chưa đăng ký
            if (roleSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Không thể kiểm tra thông tin tài khoản.\n'
                      'Vui lòng kiểm tra kết nối mạng và thử lại.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              );
            }

            // Có tài khoản Firebase Auth nhưng chưa có hồ sơ trong Users
            if (!roleSnapshot.hasData || !roleSnapshot.data!.exists) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await FirebaseAuth.instance.signOut();

                if (!context.mounted) return;

                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Tài khoản Google này chưa được đăng ký. '
                        'Vui lòng tạo tài khoản trước!',
                      ),
                      backgroundColor: Colors.red[800],
                      duration: const Duration(seconds: 6),
                    ),
                  );
              });

              return const LoginScreen();
            }

            final data = roleSnapshot.data!.data() as Map<String, dynamic>?;

            // --- BẮT ĐẦU LOGIC ĐÁ VĂNG KHI TRÙNG TÀI KHOẢN ---
            if (data != null && data.containsKey('sessionId')) {
              // Hàm sẽ đợi ngắn rồi đọc lại sessionId mới nhất để tránh
              // thiết bị vừa đăng nhập tự đá chính nó.
              _checkAndKick(context, user.uid);
            }
            // --- KẾT THÚC LOGIC ---

            // Nếu mọi thứ bình thường, cho phép vào App
            String role = 'student';
            if (data != null && data.containsKey('role')) {
              role = data['role'];
            }

            if (role == 'admin') {
              return const AdminDashboardScreen();
            } else {
              return const DashboardScreen();
            }
          },
        );
      },
    );
  }
}
