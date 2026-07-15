import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // --- BẢNG MÀU DESIGN SYSTEM ---
  final Color _primary = const Color(0xFF002045);
  final Color _outline = const Color(0xFFC4C6CF);

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  // --- HÀM: ĐĂNG KÝ BẰNG EMAIL & GỬI LINK XÁC THỰC ---
  Future<void> _signUpWithEmail() async {
    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String pass = _passwordController.text.trim();
    String confirmPass = _confirmPasswordController.text.trim();

    // 1. Kiểm tra các ô bị bỏ trống
    List<String> missingFields = [];
    if (name.isEmpty) missingFields.add('Họ và tên');
    if (email.isEmpty) missingFields.add('Email');
    if (pass.isEmpty) missingFields.add('Mật khẩu');
    if (confirmPass.isEmpty) missingFields.add('Xác nhận mật khẩu');

    if (missingFields.isNotEmpty) {
      // Nếu thiếu cả 4 ô thì báo "thiếu tất cả", ngược lại báo tên các ô bị thiếu
      String errorMessage = missingFields.length == 4
          ? 'Vui lòng điền đầy đủ tất cả thông tin!'
          : 'Vui lòng nhập thiếu sót: ${missingFields.join(', ')}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
      return;
    }

    // 2. Kiểm tra định dạng Email hợp lệ
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

    // 3. Kiểm tra xác nhận mật khẩu
    if (pass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mật khẩu xác nhận không khớp!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 4. Tạo tài khoản trên Firebase Auth
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: pass);

      User? user = userCredential.user;

      if (user != null) {
        // 5. Lưu hồ sơ lên Firestore
        await FirebaseFirestore.instance.collection('Users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'fullName': name,
          'role': 'student',
          'targetScore': 900,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 6. Gửi Link Xác Thực vào Email
        await user.sendEmailVerification();

        // 7. Đăng xuất ngay lập tức để ép xác thực
        await _auth.signOut();

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    color: Colors.green,
                    size: 28,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đăng ký thành công',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: const Text(
                'Hệ thống đã gửi một liên kết xác nhận vào email của bạn.\n\nVui lòng kiểm tra hộp thư (hoặc thư rác) và nhấn vào liên kết để kích hoạt tài khoản trước khi đăng nhập.',
                style: TextStyle(fontSize: 15, height: 1.4),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Đã hiểu và Đăng nhập',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = 'Lỗi đăng ký. Vui lòng thử lại sau.';
        if (e.code == 'weak-password') {
          message = 'Mật khẩu quá yếu (cần ít nhất 6 ký tự).';
        } else if (e.code == 'email-already-in-use') {
          message = 'Email này đã được đăng ký cho một tài khoản khác!';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            // --- LOGO TRÒN TRÊN CÙNG ---
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school, size: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),

            // --- TIÊU ĐỀ ---
            const Text(
              'Đăng ký tài khoản',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF002045), // _primary
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Bắt đầu hành trình chinh phục kỳ thi\nĐGNL',
              style: TextStyle(
                color: Color(0xFF43474E),
                fontSize: 15,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // --- CÁC TRƯỜNG NHẬP LIỆU ---
            _buildInputField(
              label: 'Họ và tên',
              hint: 'Họ và tên',
              icon: Icons.person_outline,
              controller: _nameController,
            ),
            const SizedBox(height: 20),

            _buildInputField(
              label: 'Email',
              hint: 'nhap@email.com',
              icon: Icons.email_outlined,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20),

            _buildInputField(
              label: 'Mật khẩu',
              hint: 'Mật khẩu',
              icon: Icons.lock_outline,
              controller: _passwordController,
              isPassword: true,
              obscureText: _obscurePassword,
              onToggleVisibility: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            const SizedBox(height: 20),

            _buildInputField(
              label: 'Xác nhận mật khẩu',
              hint: 'Xác nhận mật khẩu',
              icon: Icons.lock_outline,
              controller: _confirmPasswordController,
              isPassword: true,
              obscureText: _obscureConfirmPassword,
              onToggleVisibility: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
            ),
            const SizedBox(height: 40),

            // --- NÚT ĐĂNG KÝ ---
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                    onPressed: _signUpWithEmail,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Đăng ký ngay',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),

            const SizedBox(height: 32),

            // --- CHUYỂN SANG ĐĂNG NHẬP ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Đã có tài khoản?',
                  style: TextStyle(color: Color(0xFF43474E), fontSize: 14),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Đăng nhập',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF002045),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // --- HÀM HỖ TRỢ XÂY DỰNG TRƯỜNG NHẬP LIỆU ---
  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF43474E),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFC4C6CF), fontSize: 15),
            prefixIcon: Icon(icon, color: const Color(0xFF74777F), size: 22),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFF74777F),
                      size: 22,
                    ),
                    onPressed: onToggleVisibility,
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _outline, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
