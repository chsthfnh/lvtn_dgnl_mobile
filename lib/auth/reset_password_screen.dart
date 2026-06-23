import 'package:flutter/material.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  bool _obscureNewPassword = true;
  bool _obscureConfirmNewPassword = true;

  // Giả lập trạng thái yêu cầu mật khẩu
  bool _has8Chars = true;
  bool _hasUpperCase = false;
  bool _hasNumber = false;

  Widget _buildRequirementItem(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isMet ? Colors.green : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(color: isMet ? Colors.green[700] : Colors.grey[700]),
        ),
      ],
    );
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
            // Logo
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A237E),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.psychology_outlined,
                  size: 60,
                  color: Color(0xFFBBDEFB),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tiêu đề
            const Text(
              'Đặt lại mật khẩu',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Vui lòng nhập mật khẩu mới cho tài khoản của bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5, fontSize: 16),
            ),
            const SizedBox(height: 40),

            // New Password Field
            const Text(
              'Mật khẩu mới',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              obscureText: _obscureNewPassword,
              decoration: InputDecoration(
                hintText: 'Nhập mật khẩu mới',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () => setState(
                    () => _obscureNewPassword = !_obscureNewPassword,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),

            // Confirm New Password Field
            const Text(
              'Xác nhận mật khẩu mới',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              obscureText: _obscureConfirmNewPassword,
              decoration: InputDecoration(
                hintText: 'Nhập lại mật khẩu mới',
                prefixIcon: const Icon(Icons.lock_reset),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmNewPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () => setState(
                    () => _obscureConfirmNewPassword =
                        !_obscureConfirmNewPassword,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 24),

            // Password Requirements Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD), // Xanh nhạt
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Yêu cầu mật khẩu:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _buildRequirementItem('Ít nhất 8 ký tự', _has8Chars),
                  const SizedBox(height: 8),
                  _buildRequirementItem(
                    'Chứa ít nhất một chữ hoa',
                    _hasUpperCase,
                  ),
                  const SizedBox(height: 8),
                  _buildRequirementItem('Chứa ít nhất một chữ số', _hasNumber),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Nút Cập nhật
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
              ),
              onPressed: () {}, // Logic cập nhật mật khẩu mới
              child: const Text(
                'Cập nhật mật khẩu',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
