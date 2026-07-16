import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'auth_wrapper.dart';

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

  // --- HÀM 1: LƯU SESSION ID VÀ LỊCH SỬ THIẾT BỊ ---
  Future<void> _saveSessionAndHistory(String uid) async {
    try {
      String deviceName = 'Thiết bị không xác định';
      if (kIsWeb) {
        deviceName = 'Trình duyệt Web';
      } else {
        deviceName = Platform.isAndroid
            ? 'Điện thoại Android'
            : (Platform.isIOS ? 'Điện thoại iOS' : 'Thiết bị khác');
      }

      String sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_session_id', sessionId);

      await FirebaseFirestore.instance.collection('Users').doc(uid).set({
        'sessionId': sessionId,
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .collection('LoginHistory')
          .add({
            'deviceInfo': deviceName,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Lỗi lưu thiết bị: $e');
    }
  }

  // --- HÀM 2: ĐĂNG NHẬP BẰNG EMAIL & MẬT KHẨU ---
  Future<void> _loginWithEmail() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập Email!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập Mật khẩu!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Định dạng email không hợp lệ! (VD: name@email.com)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // DỌN SẠCH SESSION CŨ TRƯỚC KHI ĐĂNG NHẬP ĐỂ KHÔNG BỊ ĐÁ VĂNG NHẦM
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_session_id');

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = userCredential.user;

      if (user != null && !user.emailVerified) {
        await _auth.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Tài khoản chưa được kích hoạt! Vui lòng mở hộp thư email và nhấn vào liên kết xác thực.',
                style: TextStyle(fontSize: 15),
              ),
              backgroundColor: Colors.orange[800],
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      await _saveSessionAndHistory(user!.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng nhập thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        // KẾT THÚC ĐĂNG NHẬP: Trở về AuthWrapper để nó tự điều hướng và lắng nghe thiết bị khác
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = 'Lỗi đăng nhập. Vui lòng thử lại!';
        if (e.code == 'user-not-found')
          message = 'Tài khoản không tồn tại hoặc chưa được đăng ký!';
        else if (e.code == 'wrong-password')
          message = 'Sai mật khẩu!';
        else if (e.code == 'invalid-credential')
          message = 'Sai tài khoản hoặc mật khẩu!';
        else if (e.code == 'too-many-requests')
          message =
              'Đăng nhập sai quá nhiều lần. Tài khoản bị tạm khóa, vui lòng thử lại sau!';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- HÀM 3: ĐĂNG NHẬP BẰNG GOOGLE ---
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // 1. DỌN SẠCH SESSION CŨ DƯỚI MÁY TRƯỚC KHI ĐĂNG NHẬP
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_session_id');

      if (kIsWeb) {
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        UserCredential userCredential = await _auth.signInWithPopup(
          authProvider,
        );
        User? user = userCredential.user;

        if (user == null) {
          setState(() => _isLoading = false);
          return;
        }

        var userQuery = await FirebaseFirestore.instance
            .collection('Users')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();

        if (userQuery.docs.isEmpty) {
          await user.delete();
          await _auth.signOut();
          _showUnregisteredError();
          return;
        }

        // 2. TẠO SESSION ID MỚI & LƯU LỊCH SỬ THIẾT BỊ (QUAN TRỌNG ĐỂ ĐÁ MÁY KHÁC)
        await _saveSessionAndHistory(user.uid);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đăng nhập thành công!'),
              backgroundColor: Colors.green,
            ),
          );

          // 3. ÉP TRỞ VỀ TRẠM GÁC AUTH WRAPPER (KHÔNG NHẢY THẲNG VÀO DASHBOARD)
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AuthWrapper()),
            (route) => false,
          );
        }
      } else {
        // DÀNH CHO NỀN TẢNG MOBILE (ANDROID/IOS) - google_sign_in v7.x API
        // Từ v7, GoogleSignIn không còn constructor mặc định, phải dùng singleton
        final GoogleSignIn googleSignIn = GoogleSignIn.instance;

        // Bắt buộc initialize() trước khi dùng (an toàn khi gọi lại nhiều lần)
        await googleSignIn.initialize();

        // signIn() đã bị thay bằng authenticate(). Nếu người dùng huỷ,
        // hàm này sẽ throw GoogleSignInException (được bắt ở catch bên ngoài,
        // vốn đã lọc bỏ các lỗi chứa từ 'canceled').
        final GoogleSignInAccount googleUser = await googleSignIn
            .authenticate();

        var userQuery = await FirebaseFirestore.instance
            .collection('Users')
            .where('email', isEqualTo: googleUser.email)
            .limit(1)
            .get();

        if (userQuery.docs.isEmpty) {
          await googleSignIn.signOut();
          _showUnregisteredError();
          return;
        }

        // accessToken không còn nằm trong GoogleSignInAuthentication nữa.
        // Phải xin quyền (authorization) riêng để lấy accessToken.
        const List<String> scopes = <String>['email', 'profile'];
        final authorization =
            await googleUser.authorizationClient.authorizationForScopes(
              scopes,
            ) ??
            await googleUser.authorizationClient.authorizeScopes(scopes);

        final AuthCredential credential = GoogleAuthProvider.credential(
          idToken: googleUser.authentication.idToken,
          accessToken: authorization.accessToken,
        );

        await _auth.signInWithCredential(credential);

        // 2. TẠO SESSION ID MỚI & LƯU LỊCH SỬ THIẾT BỊ
        await _saveSessionAndHistory(_auth.currentUser!.uid);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đăng nhập thành công!'),
              backgroundColor: Colors.green,
            ),
          );

          // 3. ÉP TRỞ VỀ TRẠM GÁC AUTH WRAPPER
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AuthWrapper()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted &&
          !e.toString().contains('canceled') &&
          !e.toString().contains('popup-closed-by-user')) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi đăng nhập: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showUnregisteredError() {
    if (!mounted) return;
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
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RegisterScreen()),
          ),
        ),
      ),
    );
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

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mật khẩu',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    ),
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

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: const Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _loginWithEmail,
                      child: const Text(
                        'Đăng nhập',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

              const SizedBox(height: 24),
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

              _isLoading
                  ? const SizedBox.shrink()
                  : OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      onPressed: _signInWithGoogle,
                      icon: Image.asset('assets/gg.png', height: 24),
                      label: const Text(
                        'Đăng nhập bằng Google',
                        style: TextStyle(color: Colors.black87, fontSize: 16),
                      ),
                    ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Chưa có tài khoản?'),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RegisterScreen(),
                      ),
                    ),
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
