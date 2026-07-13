import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'detailed_answer_screen.dart';
import '../dashboard_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../ai_screens/ai_mistake_summary_widget.dart'; // Đổi lại đường dẫn cho đúng nha

class PracticeResultScreen extends StatelessWidget {
  final int totalQuestions;
  final int correctAnswers;
  final String timeSpent;
  final String subjectName;
  final List<dynamic> questions;
  final Map<int, int> userAnswers;
  final bool isTab;

  // BIẾN THÔNG TIN GAMIFICATION (TỪ BƯỚC CHẤM ĐIỂM TRUYỀN SANG)
  final bool isLevelMode;
  final int stars;
  final bool isPass;
  final bool didLevelUp;
  final int consecutivePasses;

  const PracticeResultScreen({
    super.key,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.timeSpent,
    required this.subjectName,
    required this.questions,
    required this.userAnswers,
    this.isTab = false,
    this.isLevelMode = false,
    this.stars = 0,
    this.isPass = false,
    this.didLevelUp = false,
    this.consecutivePasses = 0,
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
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) =>
                  const Center(child: CircularProgressIndicator()),
            );
            String? uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid != null) {
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
              Navigator.pop(context);
              if (role == 'admin') {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DashboardScreen(),
                  ),
                  (route) => route.isFirst,
                );
              } else {
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
                // HIỂN THỊ KHUNG THÔNG BÁO LEVEL NẾU Ở CHẾ ĐỘ VƯỢT ẢI
                if (isLevelMode) _buildLevelFeedbackCard(),

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
                    onPressed: () => Navigator.pop(context),
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

  // KHUNG ĐỘNG VIÊN GAMIFICATION
  Widget _buildLevelFeedbackCard() {
    Color bgColor = isPass ? Colors.green.shade50 : Colors.orange.shade50;
    Color textColor = isPass ? Colors.green.shade800 : Colors.orange.shade800;
    IconData icon = isPass ? Icons.emoji_events : Icons.info_outline;

    String title = '';
    String subtitle = '';

    if (didLevelUp) {
      title = '🎉 THĂNG CẤP THÀNH CÔNG! 🎉';
      subtitle =
          'Tuyệt vời! Bạn đã đạt >= 90% trong 2 lần liên tiếp. Level tiếp theo đã được mở khóa!';
    } else if (isPass) {
      title = '🔥 XUẤT SẮC! 🔥';
      subtitle =
          'Bạn đã vượt mốc 90%. Hãy giữ phong độ và đạt >= 90% ở lần tiếp theo để thăng cấp nhé! (Chuỗi hiện tại: $consecutivePasses/2)';
    } else {
      title = 'CỐ GẮNG HƠN NHÉ!';
      subtitle =
          'Bạn cần đạt tối thiểu 90% điểm số trong 2 lần liên tiếp để mở khóa Level tiếp theo. Đừng bỏ cuộc!';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: textColor, size: 44),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor.withOpacity(0.9),
              fontSize: 14,
              height: 1.4,
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
          const SizedBox(height: 20),

          // HÀNG SAO GAMIFICATION BÊN DƯỚI THANH TIẾN ĐỘ
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  index < stars
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: Colors.amber.shade500,
                  size: 36,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            stars == 5
                ? 'Tuyệt đỉnh!'
                : stars >= 3
                ? 'Khá tốt!'
                : 'Cần ôn tập thêm',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Nếu làm sai từ 1 câu trở lên thì mới cần AI phân tích
          if (correctAnswers < totalQuestions)
            AIMistakeSummaryButton(
              questions: questions,
              userAnswers: userAnswers,
            ),
        ],
      ),
    );
  }
}
