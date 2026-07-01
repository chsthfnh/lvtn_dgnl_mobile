import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../screens/user_screens/dashboard_screen.dart';
import '../screens/admin_screens/admin_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  // --- HÀM 1: ĐĂNG NHẬP BẰNG EMAIL & MẬT KHẨU ---
  Future<void> _loginWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đầy đủ Email và Mật khẩu')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;

      // CHẶN NGƯỜI DÙNG CHƯA NHẤN LINK XÁC THỰC EMAIL
      if (user != null && !user.emailVerified) {
        await _auth.signOut(); // Ép buộc đăng xuất trên hệ thống ngay lập tức
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Tài khoản chưa được kích hoạt! Vui lòng mở hộp thư email và nhấn vào liên kết xác thực.',
                style: TextStyle(fontSize: 15),
              ),
              backgroundColor: Colors.orange[800], // Màu cam cảnh báo
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return; // Dừng hàm tại đây, không cho chạy xuống lệnh chuyển trang
      }

      if (mounted) await _checkRoleAndNavigate();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = 'Lỗi đăng nhập';
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          message = 'Sai thông tin hoặc tài khoản chưa được đăng ký!';
        } else if (e.code == 'wrong-password') {
          message = 'Sai mật khẩu!';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- HÀM 2: ĐĂNG NHẬP BẰNG GOOGLE (LUỒNG CHUẨN: CHECK TRƯỚC KHI AUTH) ---
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // 1. KHÔI PHỤC CÚ PHÁP GỐC CỦA BẠN ĐỂ GỌI GOOGLE
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();

      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // Người dùng bấm hủy
      }

      // 2. Lấy email vừa chọn đi kiểm tra trong collection 'Users' của Firestore
      var userQuery = await FirebaseFirestore.instance
          .collection('Users')
          .where('email', isEqualTo: googleUser.email)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        // KHÔNG HỢP LỆ: Email chưa được đăng ký -> Ép xuất khỏi Google và báo lỗi
        await googleSignIn.signOut();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Tài khoản này chưa đăng ký. Vui lòng tạo tài khoản!',
                style: TextStyle(fontSize: 15),
              ),
              backgroundColor: Colors.red[800],
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'ĐĂNG KÝ NGAY',
                textColor: Colors.yellowAccent,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegisterScreen(),
                    ),
                  );
                },
              ),
            ),
          );
        }
        return; // Cắt luồng, tuyệt đối không tạo tài khoản Firebase Auth
      }

      // 3. HỢP LỆ: Tài khoản đã có trong Database -> Tiến hành cấp phép Firebase Auth
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken, // Chỉ dùng idToken như code gốc của bạn
      );

      // Đăng nhập chính thức vào Firebase
      await _auth.signInWithCredential(credential);

      // Chuyển hướng vào app
      if (mounted) await _checkRoleAndNavigate();
    } catch (e) {
      if (mounted) {
        if (!e.toString().contains('sign_in_canceled') &&
            !e.toString().contains('canceled')) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- HÀM 3: KIỂM TRA QUYỀN VÀ CHUYỂN TRANG ---
  Future<void> _checkRoleAndNavigate() async {
    if (!mounted) return;

    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('Users')
        .doc(_auth.currentUser!.uid)
        .get();

    String role = 'student';
    if (userDoc.exists && userDoc.data() != null) {
      final data = userDoc.data() as Map<String, dynamic>;
      role = data['role'] ?? 'student';
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đăng nhập thành công!'),
        backgroundColor: Colors.green,
      ),
    );

    if (role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE3F2FD),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school_outlined,
                    size: 60,
                    color: Color(0xFF1976D2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Tiêu đề
              const Text(
                'EduTest ĐGNL',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
                textAlign: TextAlign.center,
              ),
              const Text(
                'Hệ thống Đánh giá Năng lực',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Email Field
              const Text(
                'Email',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'nhap@email.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 16),

              // Password Field
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mật khẩu',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Quên mật khẩu?',
                      style: TextStyle(color: Color(0xFF1976D2)),
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 32),

              // Nút Đăng nhập
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: const Color(0xFF1A237E), // Xanh đậm
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _loginWithEmail, // Gắn logic Đăng nhập thường
                      child: const Text(
                        'Đăng nhập',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

              const SizedBox(height: 24),
              // Dòng chữ "HOẶC"
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('HOẶC', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),

              // Nút Google
              _isLoading
                  ? const SizedBox.shrink() // Ẩn nút Google khi đang tải
                  : OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      onPressed:
                          _signInWithGoogle, // Gắn logic Đăng nhập Google đã sửa
                      icon: Image.asset('assets/gg.png', height: 24),
                      label: const Text(
                        'Đăng nhập bằng Google',
                        style: TextStyle(color: Colors.black87, fontSize: 16),
                      ),
                    ),
              const SizedBox(height: 32),

              // Liên kết Đăng ký
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Chưa có tài khoản?'),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Đăng ký tài khoản',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
