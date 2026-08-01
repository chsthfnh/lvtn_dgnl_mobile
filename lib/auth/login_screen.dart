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
  // Web OAuth client (client_type: 3) lấy từ google-services.json.
  // Android dùng giá trị này làm serverClientId để nhận ID token cho Firebase.
  static const String _googleServerClientId =
      '39592049411-fn79he9ichcms0qsfqrl6q1p2aij84tv.apps.googleusercontent.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final GoogleSignIn _mobileGoogleSignIn = GoogleSignIn(
    scopes: const <String>['email'],
    serverClientId: _googleServerClientId,
  );

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGooglePopupOpen = false;
  int _googleSignInAttempt = 0;

  // --- HÀM 1: LƯU SESSION ID VÀ LỊCH SỬ THIẾT BỊ ---
  Future<void> _saveSessionAndHistory(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final userRef = FirebaseFirestore.instance.collection('Users').doc(uid);
    final sessionId = DateTime.now().microsecondsSinceEpoch.toString();

    try {
      String deviceName = 'Thiết bị không xác định';
      if (kIsWeb) {
        deviceName = 'Trình duyệt Web';
      } else {
        deviceName = Platform.isAndroid
            ? 'Điện thoại Android'
            : (Platform.isIOS ? 'Điện thoại iOS' : 'Thiết bị khác');
      }

      final userDoc = await userRef.get();
      if (!userDoc.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'user-profile-not-found',
          message: 'Tài khoản đã bị xóa khỏi hệ thống.',
        );
      }

      // Lưu mã phiên mới trên thiết bị hiện tại trước.
      await prefs.setString('current_session_id', sessionId);

      // Cập nhật sessionId và lịch sử trong cùng một batch. Khi sessionId
      // thay đổi, thiết bị cũ đang lắng nghe Users/{uid} sẽ tự đăng xuất.
      final historyRef = userRef.collection('LoginHistory').doc();
      final batch = FirebaseFirestore.instance.batch();

      batch.update(userRef, {
        'sessionId': sessionId,
        'lastActive': FieldValue.serverTimestamp(),
      });
      batch.set(historyRef, {
        'deviceInfo': deviceName,
        'sessionId': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    } catch (e) {
      // Không giữ session cục bộ nếu cập nhật Firestore thất bại.
      await prefs.remove('current_session_id');
      debugPrint('Lỗi lưu phiên đăng nhập: $e');
      rethrow;
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

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Không tìm thấy tài khoản.',
        );
      }

      // Kiểm tra hồ sơ ứng dụng còn tồn tại hay không
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        await _auth.signOut();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Tài khoản đã bị xóa hoặc không còn được phép truy cập!',
            ),
            backgroundColor: Colors.red.shade800,
          ),
        );

        return;
      }
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
    if (_isLoading) return;

    // Mỗi lần bấm là một yêu cầu mới. Nếu popup cũ phản hồi trễ,
    // nó không được phép thay đổi trạng thái của yêu cầu hiện tại.
    final int attemptId = ++_googleSignInAttempt;

    try {
      if (kIsWeb) {
        // Khóa ngay để tránh nhấn liên tục
        if (mounted) {
          setState(() => _isGooglePopupOpen = true);
        }

        final GoogleAuthProvider provider = GoogleAuthProvider();

        // Luôn hiện màn hình chọn tài khoản
        provider.setCustomParameters({'prompt': 'select_account'});

        // Quan trọng: gọi popup ngay, không await thao tác khác trước nó
        final UserCredential userCredential = await _auth.signInWithPopup(
          provider,
        );

        if (!mounted) return;

        setState(() {
          _isGooglePopupOpen = false;
          _isLoading = true;
        });

        final User? user = userCredential.user;

        if (user == null) {
          return;
        }

        // Chỉ xóa session cũ sau khi popup đăng nhập thành công
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('current_session_id');

        // Kiểm tra tài khoản theo UID
        final userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          try {
            await user.delete();
          } catch (_) {
            // Nếu không xóa được Auth thì vẫn phải đăng xuất
          }

          await _auth.signOut();
          _showUnregisteredError();
          return;
        }

        await _saveSessionAndHistory(user.uid);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng nhập thành công!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      } else {
        // --- MOBILE (ANDROID/IOS) - google_sign_in v6.3.0 ---
        if (mounted) {
          setState(() => _isLoading = true);
        }

        debugPrint('[GoogleLogin] 1. Đang mở màn hình chọn tài khoản...');

        // Xóa phiên Google được lưu trên thiết bị để luôn hiện chọn tài khoản.
        try {
          await _mobileGoogleSignIn.signOut();
        } catch (e) {
          debugPrint('[GoogleLogin] Không thể xóa phiên Google cũ: $e');
        }

        final GoogleSignInAccount? googleUser = await _mobileGoogleSignIn
            .signIn();

        // API v6 trả về null khi người dùng thực sự đóng hộp thoại.
        if (googleUser == null) {
          debugPrint('[GoogleLogin] Người dùng đã đóng cửa sổ Google.');
          return;
        }

        debugPrint(
          '[GoogleLogin] 2. Đã nhận tài khoản Google: ${googleUser.email}',
        );

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final String? idToken = googleAuth.idToken;
        if (idToken == null || idToken.isEmpty) {
          await _mobileGoogleSignIn.signOut();
          throw FirebaseAuthException(
            code: 'missing-google-id-token',
            message:
                'Google không trả về ID token. Hãy kiểm tra SHA-1 và google-services.json.',
          );
        }

        // Dùng cả accessToken và idToken theo API google_sign_in v6.
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: idToken,
        );

        debugPrint('[GoogleLogin] 3. Đang xác thực với Firebase...');

        final UserCredential userCredential = await _auth.signInWithCredential(
          credential,
        );
        final User? user = userCredential.user;

        if (user == null) {
          await _mobileGoogleSignIn.signOut();
          await _auth.signOut();
          return;
        }

        debugPrint(
          '[GoogleLogin] 4. Firebase đăng nhập thành công: ${user.uid}',
        );

        // Xóa session cũ trước khi ghi session mới để AuthWrapper không
        // nhầm phiên trước đó là phiên đang đăng nhập.
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('current_session_id');

        // Kiểm tra hồ sơ sau khi Firebase đã xác thực, sử dụng đúng UID.
        final userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          try {
            await user.delete();
          } catch (_) {
            // Nếu không xóa được Auth thì vẫn phải đăng xuất.
          }

          await _mobileGoogleSignIn.signOut();
          await _auth.signOut();
          _showUnregisteredError();
          return;
        }

        debugPrint('[GoogleLogin] 5. Đã tìm thấy hồ sơ Users/${user.uid}');

        // Ghi sessionId mới lên Firestore để đá phiên đang mở ở thiết bị khác.
        await _saveSessionAndHistory(user.uid);

        debugPrint('[GoogleLogin] 6. Đã lưu session đăng nhập mới');

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đăng nhập thành công!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[GoogleLogin] FirebaseAuthException code=${e.code}, message=${e.message}',
      );

      // Đóng popup là thao tác hủy bình thường, không hiển thị lỗi.
      const cancelledCodes = {
        'popup-closed-by-user',
        'cancelled-popup-request',
        'popup-request-cancelled',
        'web-context-cancelled',
        'web-context-canceled',
      };

      if (cancelledCodes.contains(e.code)) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đăng nhập: ${e.message ?? e.code}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      final error = e.toString().toLowerCase();
      debugPrint('[GoogleLogin] Google Sign-In exception: $e');

      final bool isAccountReauthConfigurationError =
          error.contains('account reauth failed') || error.contains('[16]');

      if (isAccountReauthConfigurationError) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'Không thể xác thực Google trên Android. '
                  'Hãy kiểm tra SHA-1, SHA-256, package name và '
                  'google-services.json của ứng dụng.',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 7),
              ),
            );
        }
      } else if (!error.contains('canceled') &&
          !error.contains('cancelled') &&
          !error.contains('cancel') &&
          !error.contains('popup-closed-by-user')) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi đăng nhập: $e')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'Đã đóng đăng nhập Google. Bạn có thể nhấn lại để thử tiếp.',
                ),
                duration: Duration(seconds: 3),
              ),
            );
        }
      }
    } finally {
      if (mounted && attemptId == _googleSignInAttempt) {
        setState(() {
          _isLoading = false;
          _isGooglePopupOpen = false;
        });
      }
    }
  }

  void _showUnregisteredError() {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'Tài khoản chưa đăng ký, vui lòng tạo tài khoản!',
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
                MaterialPageRoute(builder: (context) => const RegisterScreen()),
              );
            },
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
                      // Không khóa bằng _isGooglePopupOpen. Nếu popup cũ bị
                      // trình duyệt giữ trạng thái, lần bấm mới sẽ tự hủy yêu
                      // cầu cũ và mở lại cửa sổ chọn tài khoản.
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
