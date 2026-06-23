import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';
import '../screens/user_screens/dashboard_screen.dart';
import '../screens/admin_screens/admin_dashboard_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

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

        // 2. CHẶN BẢO MẬT: Nếu tài khoản chưa xác thực link email thì giữ nguyên ở LoginScreen
        // (Tài khoản Đăng nhập bằng Google mặc định trường emailVerified luôn luôn bằng true)
        if (!user.emailVerified) {
          return const LoginScreen();
        }

        // 3. Nếu đã xác thực thành công -> Tiến hành kiểm tra phân quyền quyền hạn
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('Users')
              .doc(user.uid)
              .get(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (roleSnapshot.hasError ||
                !roleSnapshot.hasData ||
                !roleSnapshot.data!.exists) {
              FirebaseAuth.instance.signOut();
              return const LoginScreen();
            }

            String role = 'student';
            final data = roleSnapshot.data!.data() as Map<String, dynamic>?;
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
