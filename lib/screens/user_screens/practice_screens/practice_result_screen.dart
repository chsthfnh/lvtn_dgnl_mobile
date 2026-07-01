import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'detailed_answer_screen.dart';
import '../dashboard_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PracticeResultScreen extends StatelessWidget {
  final int totalQuestions;
  final int correctAnswers;
  final String timeSpent;
  final String subjectName;
  final List<DocumentSnapshot> questions;
  final Map<int, int> userAnswers;
  final bool isTab; // THÊM KHAI BÁO BIẾN TRẠNG THÁI NGUỒN VÀO

  const PracticeResultScreen({
    super.key,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.timeSpent,
    required this.subjectName,
    required this.questions,
    required this.userAnswers,
    this.isTab = false, // THÊM VÀO CONSTRUCTOR
  });

  @override
  Widget build(BuildContext context) {
    int displayScore = correctAnswers * 10;
    int maxScore = totalQuestions * 10;
    double accuracyRate = totalQuestions > 0
        ? correctAnswers / totalQuestions
        : 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.home_rounded,
            color: Color(0xFF002045),
            size: 28,
          ),
          onPressed: () async {
            // 1. Hiện vòng quay loading siêu tốc để chặn bấm đúp (Tùy chọn, giúp app mượt hơn)
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) =>
                  const Center(child: CircularProgressIndicator()),
            );

            String? uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
              // 2. Soi nhanh xem ai đang làm bài
              DocumentSnapshot userDoc = await FirebaseFirestore.instance
                  .collection('Users')
                  .doc(uid)
                  .get();
              String role = 'student';

              if (userDoc.exists && userDoc.data() != null) {
                role =
                    (userDoc.data() as Map<String, dynamic>)['role'] ??
                    'student';
              }

              if (!context.mounted) return;
              Navigator.pop(context); // Tắt vòng loading

              // 3. ĐIỀU HƯỚNG THÔNG MINH
              if (role == 'admin') {
                // Dành cho Admin đang test:
                // Xóa các màn hình thi, giữ lại trang gốc Quản trị, và đẩy trang User lên cho Admin test tiếp
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DashboardScreen(),
                  ),
                  (route) => route.isFirst,
                );
              } else {
                // Dành cho Học viên thật: Lùi thẳng về trang gốc của họ (chính là DashboardScreen)
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            }
          },
        ),
        title: const Text(
          'Kết quả luyện tập',
          style: TextStyle(
            color: Color(0xFF002045),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFC4C6CF).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'TỔNG ĐIỂM ĐẠT ĐƯỢC',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$displayScore',
                        style: const TextStyle(
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF002045),
                        ),
                      ),
                      Text(
                        'trên $maxScore điểm',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat(
                            Icons.check_circle,
                            '$correctAnswers Câu',
                            'Chính xác',
                            Colors.green,
                          ),
                          _buildStat(
                            Icons.cancel,
                            '${totalQuestions - correctAnswers} Câu',
                            'Sai/Chưa làm',
                            Colors.red,
                          ),
                          _buildStat(
                            Icons.timer,
                            timeSpent,
                            'Thời gian',
                            Colors.blue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Phân tích năng lực chuyên đề',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                _buildProgressCard(accuracyRate),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // ĐÃ SỬA: Chỉ cần Pop (lùi 1 bước) là lòi ra màn hình Chọn môn ngay bên dưới
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Làm bài khác',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailedAnswerScreen(
                            questions: questions,
                            userAnswers: userAnswers,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF002045),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.menu_book),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'XEM ĐÁP ÁN CHI TIẾT',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String val, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildProgressCard(double rate) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                subjectName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${(rate * 100).toInt()}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: rate,
            backgroundColor: Colors.grey.shade200,
            color: Colors.green,
            minHeight: 8,
          ),
        ],
      ),
    );
  }
}
