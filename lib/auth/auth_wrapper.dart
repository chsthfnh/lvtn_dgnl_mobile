import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';
import '../screens/user_screens/dashboard_screen.dart';
import '../screens/admin_screens/admin_dashboard_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  // --- HÀM KIỂM TRA VÀ ĐÁ VĂNG THIẾT BỊ KHÁC ---
  void _checkAndKick(BuildContext context, String remoteSessionId) async {
    final prefs = await SharedPreferences.getInstance();
    String? localSessionId = prefs.getString('current_session_id');

    // Chỉ đá văng nếu máy này đã có Session (đăng nhập xong) và mã Session không khớp với Server
    if (localSessionId != null && localSessionId != remoteSessionId) {
      await FirebaseAuth.instance.signOut();
      await prefs.remove('current_session_id');

      if (context.mounted) {
        // Đẩy thẳng về màn hình đăng nhập, xóa sạch lịch sử trang
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
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

            // Nếu tài khoản bị xóa trên Firebase
            if (roleSnapshot.hasError ||
                !roleSnapshot.hasData ||
                !roleSnapshot.data!.exists) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                FirebaseAuth.instance.signOut();
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final data = roleSnapshot.data!.data() as Map<String, dynamic>?;

            // --- BẮT ĐẦU LOGIC ĐÁ VĂNG KHI TRÙNG TÀI KHOẢN ---
            if (data != null && data.containsKey('sessionId')) {
              String remoteSessionId = data['sessionId'];
              // Gọi hàm kiểm tra ngầm, không block giao diện
              _checkAndKick(context, remoteSessionId);
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
