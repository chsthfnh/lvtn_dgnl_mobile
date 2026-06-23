import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  // --- HÀM XỬ LÝ GỬI EMAIL KHÔI PHỤC ---
  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập email của bạn!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Liên kết khôi phục đã được gửi. Vui lòng kiểm tra hộp thư email của bạn!',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        // Gửi thành công thì tự động quay về trang Đăng nhập
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = 'Đã xảy ra lỗi. Vui lòng thử lại sau.';
        if (e.code == 'invalid-email') {
          message = 'Định dạng email không hợp lệ!';
        } else if (e.code == 'user-not-found') {
          message = 'Không tìm thấy tài khoản với email này!';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 40),
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
              'Quên mật khẩu',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nhập email của bạn để nhận hướng dẫn khôi phục mật khẩu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5, fontSize: 16),
            ),
            const SizedBox(height: 40),

            // Email Field
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
            const SizedBox(height: 32),

            // Nút Gửi yêu cầu
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
                    onPressed: _resetPassword, // Gọi hàm gửi email
                    child: const Text(
                      'Gửi yêu cầu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Nút Quay lại
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text(
                'Quay lại Đăng nhập',
                style: TextStyle(fontSize: 16),
              ),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}
