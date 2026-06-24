import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  // --- BẢNG MÀU TỪ DESIGN SYSTEM ---
  final Color _primary = const Color(0xFF002045);
  final Color _bgLight = const Color(0xFFF8F9FF);
  final Color _outline = const Color(0xFFE2E8F0);
  final Color _success = const Color(0xFF006E2F);
  final Color _error = const Color(0xFFBA1A1A);
  final Color _errorBg = const Color(0xFFFFDAD6);

  bool _isLoading = true;
  StreamSubscription<DocumentSnapshot>? _userSub;
  StreamSubscription<QuerySnapshot>? _historySub;

  // --- DỮ LIỆU TỔNG QUAN ---
  int _totalQuestions = 0;
  int _totalTimeMinutes = 0;
  double _accuracy = 0.0;
  int _targetScore = 900;
  int _currentPredictedScore = 0;

  // --- DỮ LIỆU SƠ ĐỒ ---
  List<int> _practiceQByWeekday = [0, 0, 0, 0, 0, 0, 0];
  List<int> _examQByWeekday = [0, 0, 0, 0, 0, 0, 0];
  List<int> _practiceTimeByWeekday = [0, 0, 0, 0, 0, 0, 0];
  List<int> _examTimeByWeekday = [0, 0, 0, 0, 0, 0, 0];
  Map<String, int> _dailyActivityMap = {};

  // --- DỮ LIỆU HOẠT ĐỘNG ---
  List<Map<String, dynamic>> _recentActivities =
      []; // Lưu 3 bài gần nhất hiển thị ở thẻ
  List<Map<String, dynamic>> _allRecentActivities =
      []; // Lưu 20 bài gần nhất hiển thị trong popup

  Map<String, double> _sectionSkills = {
    'Ngôn ngữ': 0.0,
    'Toán học': 0.0,
    'Tư duy Logic': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _listenToStatistics();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _historySub?.cancel();
    super.dispose();
  }

  // --- HÀM TRUY VẤN VÀ TÍNH TOÁN DỮ LIỆU THẬT REAL-TIME ---
  void _listenToStatistics() {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _userSub = FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .snapshots()
        .listen((userDoc) {
          final userData = userDoc.data();
          if (userDoc.exists && userData != null && mounted) {
            setState(() => _targetScore = userData['targetScore'] ?? 900);
          }
        });

    _historySub = FirebaseFirestore.instance
        .collection('ExamHistory')
        .where('userId', isEqualTo: uid)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .listen((historySnap) {
          int totalC = 0, totalQ = 0, totalTime = 0;
          int nnC = 0,
              nnQ = 0,
              thC = 0,
              thQ = 0,
              tdC = 0,
              tdQ = 0,
              genC = 0,
              genQ = 0;

          List<int> tempPracticeQ = [0, 0, 0, 0, 0, 0, 0];
          List<int> tempExamQ = [0, 0, 0, 0, 0, 0, 0];
          List<int> tempPracticeTime = [0, 0, 0, 0, 0, 0, 0];
          List<int> tempExamTime = [0, 0, 0, 0, 0, 0, 0];
          Map<String, int> tempDailyActivityMap = {};

          List<Map<String, dynamic>> tempActivities = [];

          if (historySnap.docs.isNotEmpty) {
            for (var doc in historySnap.docs) {
              var data = doc.data();
              int totalQInExam = data['totalQuestions'] ?? 0;
              int q = data['answeredCount'] ?? totalQInExam;
              int c = data['correctAnswers'] ?? 0;
              int secs = data['timeSpentSeconds'] ?? 0;
              String name = (data['examName'] ?? '').toString().toLowerCase();
              bool isPractice =
                  data['examId'] == 'practice_mode' ||
                  name.contains('luyện tập');

              totalQ += q;
              totalC += c;
              totalTime += secs;

              if (data['submittedAt'] != null) {
                DateTime dt = data['submittedAt'].toDate();
                int weekdayIdx = dt.weekday - 1;

                if (weekdayIdx >= 0 && weekdayIdx < 7) {
                  if (isPractice) {
                    tempPracticeQ[weekdayIdx] += q;
                    tempPracticeTime[weekdayIdx] += secs;
                  } else {
                    tempExamQ[weekdayIdx] += q;
                    tempExamTime[weekdayIdx] += secs;
                  }
                }

                String dateKey = "${dt.year}-${dt.month}-${dt.day}";
                tempDailyActivityMap[dateKey] =
                    (tempDailyActivityMap[dateKey] ?? 0) + q;
              }

              if (name.contains('ngôn ngữ') ||
                  name.contains('tiếng') ||
                  name.contains('văn')) {
                nnC += c;
                nnQ += q;
              } else if (name.contains('toán') || name.contains('số liệu')) {
                thC += c;
                thQ += q;
              } else if (name.contains('tư duy') ||
                  name.contains('khoa học') ||
                  name.contains('logic') ||
                  name.contains('lô gic')) {
                tdC += c;
                tdQ += q;
              } else {
                genC += c;
                genQ += q;
              }

              // ĐÃ ĐỔI TẠI ĐÂY: Thay vì lấy 3 bài, lấy hẳn 20 bài
              if (tempActivities.length < 20) {
                double currentAcc = totalQInExam > 0 ? (c / totalQInExam) : 0.0;
                int estimatedScore = (currentAcc * 1200).toInt();

                String dateLabel = 'Vừa xong';
                if (data['submittedAt'] != null) {
                  DateTime dt = data['submittedAt'].toDate();
                  dateLabel =
                      "${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                }

                String scoreText;
                String status;
                Color statusColor;

                if (isPractice) {
                  int totalPracticeQ = data['answeredCount'] ?? totalQInExam;
                  scoreText = '${c * 10}/${totalPracticeQ * 10}';
                  double practiceAcc = totalPracticeQ > 0
                      ? (c / totalPracticeQ)
                      : 0.0;

                  if (practiceAcc >= 0.8) {
                    status = 'Rất tốt';
                    statusColor = _success;
                  } else if (practiceAcc >= 0.5) {
                    status = 'Ổn định';
                    statusColor = Colors.blue;
                  } else {
                    status = 'Cần cố gắng';
                    statusColor = _error;
                  }
                } else {
                  scoreText = '$estimatedScore/1200';
                  if (estimatedScore >= _targetScore) {
                    status = 'Vượt kỳ vọng';
                    statusColor = _success;
                  } else if (estimatedScore >= _targetScore * 0.75) {
                    status = 'Khá tốt';
                    statusColor = Colors.blue;
                  } else if (estimatedScore >= _targetScore * 0.5) {
                    status = 'Ổn định';
                    statusColor = Colors.blueGrey;
                  } else {
                    status = 'Cần cố gắng';
                    statusColor = _error;
                  }
                }

                tempActivities.add({
                  'title': data['examName'] ?? 'Đề thi thử ĐGNL',
                  'subtitle': 'Hoàn thành: $dateLabel',
                  'scoreText': scoreText,
                  'status': status,
                  'color': statusColor,
                });
              }
            }
          }

          if (mounted) {
            setState(() {
              _totalQuestions = totalQ;
              _totalTimeMinutes = totalTime ~/ 60;
              _accuracy = totalQ > 0 ? (totalC / totalQ) : 0.0;
              _currentPredictedScore = (_accuracy * 1200).toInt();

              // Phân tách 2 danh sách
              _allRecentActivities = tempActivities;
              _recentActivities = tempActivities
                  .take(3)
                  .toList(); // Chỉ cắt ra 3 bài đẩy ra thẻ ngoài

              _practiceQByWeekday = tempPracticeQ;
              _examQByWeekday = tempExamQ;
              _practiceTimeByWeekday = tempPracticeTime
                  .map((s) => s > 0 ? max(1, s ~/ 60) : 0)
                  .toList();
              _examTimeByWeekday = tempExamTime
                  .map((s) => s > 0 ? max(1, s ~/ 60) : 0)
                  .toList();
              _dailyActivityMap = tempDailyActivityMap;

              double calc(int specC, int specQ) {
                int sumC = specC + genC;
                int sumQ = specQ + genQ;
                return sumQ > 0 ? sumC / sumQ : 0.0;
              }

              _sectionSkills = {
                'Ngôn ngữ': calc(nnC, nnQ),
                'Toán học': calc(thC, thQ),
                'Tư duy Logic': calc(tdC, tdQ),
              };
              _isLoading = false;
            });
          }
        });
  }

  void _editTargetScore() {
    TextEditingController ctrl = TextEditingController(
      text: _targetScore.toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Thiết lập mục tiêu',
          style: TextStyle(color: _primary, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Mục tiêu điểm ĐGNL (Tối đa 1200)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              int? newScore = int.tryParse(ctrl.text);
              if (newScore != null && newScore <= 1200 && newScore > 0) {
                String? uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid != null) {
                  await FirebaseFirestore.instance
                      .collection('Users')
                      .doc(uid)
                      .update({'targetScore': newScore});
                }
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showChartBottomSheet(
    String title,
    String unit,
    List<int> practiceData,
    List<int> examData,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: 400,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Thống kê tuần này',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primary,
                  ),
                ),
                Text(
                  'Đơn vị: $unit',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Luyện tập',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 20),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE65100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Thi thử',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  int pVal = practiceData[index];
                  int eVal = examData[index];
                  int totalVal = pVal + eVal;

                  int maxTotal = 0;
                  for (int i = 0; i < 7; i++) {
                    if (practiceData[i] + examData[i] > maxTotal) {
                      maxTotal = practiceData[i] + examData[i];
                    }
                  }

                  double heightRatio = maxTotal == 0
                      ? 0.0
                      : totalVal / maxTotal;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '$totalVal',
                        style: TextStyle(
                          fontSize: 11,
                          color: _primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (totalVal == 0)
                        Container(
                          width: 26,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 26,
                            height: max(4.0, 150 * heightRatio),
                            child: Column(
                              children: [
                                if (eVal > 0)
                                  Expanded(
                                    flex: eVal,
                                    child: Container(
                                      color: const Color(0xFFE65100),
                                    ),
                                  ),
                                if (pVal > 0)
                                  Expanded(
                                    flex: pVal,
                                    child: Container(color: _primary),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        index == 6 ? 'CN' : 'T${index + 2}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HÀM MỚI: HIỂN THỊ DANH SÁCH 20 BÀI LÀM GẦN NHẤT ---
  void _showAllRecentActivities() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height:
            MediaQuery.of(context).size.height *
            0.75, // Trượt lên chiếm 75% màn hình
        padding: const EdgeInsets.only(top: 24, left: 20, right: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Lịch sử làm bài',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _primary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Cảnh báo người dùng đây là 20 bài gần nhất
            Text(
              'Đây là 20 bài làm gần nhất của bạn.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _allRecentActivities.isEmpty
                  ? const Center(
                      child: Text(
                        'Chưa có lịch sử làm bài.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _allRecentActivities.length,
                      itemBuilder: (context, index) {
                        return _buildActivityItem(_allRecentActivities[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double targetRatio = _targetScore / 1200;

    return Scaffold(
      backgroundColor: _bgLight,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildStatCard(
                      title: 'Tổng số câu đã làm',
                      value: _totalQuestions.toString(),
                      subtitle: _totalQuestions > 0
                          ? 'Cố gắng phát huy nhé!'
                          : 'Bắt đầu học ngay',
                      icon: Icons.check_circle_outline,
                      onTap: () => _showChartBottomSheet(
                        'Số câu hỏi hoàn thành theo ngày',
                        'Câu',
                        _practiceQByWeekday,
                        _examQByWeekday,
                      ),
                    ),
                    _buildHeatmapCard(),
                    _buildStatCard(
                      title: 'Thời gian học',
                      value: _totalTimeMinutes > 60
                          ? '${_totalTimeMinutes ~/ 60}h ${_totalTimeMinutes % 60}m'
                          : '${_totalTimeMinutes}m',
                      subtitle: _totalTimeMinutes > 0
                          ? 'Học tập tập trung'
                          : 'Chưa ghi nhận thời gian',
                      icon: Icons.schedule,
                      onTap: () => _showChartBottomSheet(
                        'Thời gian làm bài luyện tập & thi thử',
                        'Phút',
                        _practiceTimeByWeekday,
                        _examTimeByWeekday,
                      ),
                    ),
                    _buildAccuracyCard(),
                    const SizedBox(height: 24),
                    if (_recentActivities.isNotEmpty)
                      _buildRecentActivitySection(),
                    const SizedBox(height: 24),
                    _buildGoalCard(),
                    const SizedBox(height: 24),
                    _buildSkillSection(targetRatio),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    // ... Giữ nguyên như cũ ...
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _outline.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(icon, color: _primary, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapCard() {
    // ... Giữ nguyên như cũ ...
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Tiến độ học tập',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.info_outline, color: Colors.grey.shade400, size: 16),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Mức độ hoạt động trong 12 tuần qua',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(12, (colIndex) {
              return Column(
                children: List.generate(7, (rowIndex) {
                  int daysAgo = (11 - colIndex) * 7 + (6 - rowIndex);
                  DateTime targetDay = DateTime.now().subtract(
                    Duration(days: daysAgo),
                  );
                  String dateKey =
                      "${targetDay.year}-${targetDay.month}-${targetDay.day}";

                  int count = _dailyActivityMap[dateKey] ?? 0;
                  Color boxColor = Colors.grey.shade100;
                  if (count > 0 && count <= 10)
                    boxColor = const Color(0xFFC6E48B);
                  if (count > 10 && count <= 30)
                    boxColor = const Color(0xFF7BC96F);
                  if (count > 30) boxColor = const Color(0xFF239A3B);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: boxColor,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAccuracyCard() {
    // ... Giữ nguyên như cũ ...
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Độ chính xác',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(Icons.analytics_outlined, color: _primary, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${(_accuracy * 100).toInt()}%',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _primary,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _accuracy,
              backgroundColor: _bgLight,
              color: _primary,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  // --- COMPONENT TÁCH RỜI ĐỂ TÁI SỬ DỤNG CHO 1 ITEM BÀI LÀM ---
  Widget _buildActivityItem(Map<String, dynamic> activity) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: activity['color'].withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.assignment, color: activity['color'], size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['title'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _primary,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  activity['subtitle'],
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                activity['scoreText'],
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _primary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                activity['status'],
                style: TextStyle(
                  fontSize: 11,
                  color: activity['color'],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ĐÃ THÊM: Nút "Xem tất cả >" kế bên tiêu đề
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hoạt động gần đây',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _primary,
                ),
              ),
              GestureDetector(
                onTap:
                    _showAllRecentActivities, // Bấm vào sẽ bật Popup danh sách 20 bài
                child: const Text(
                  'Xem tất cả >',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Chỉ lấy danh sách _recentActivities (3 bài) hiển thị ra ngoài
          ..._recentActivities.map((activity) => _buildActivityItem(activity)),
        ],
      ),
    );
  }

  Widget _buildGoalCard() {
    // ... Giữ nguyên như cũ ...
    double progress = _targetScore > 0
        ? (_currentPredictedScore / _targetScore)
        : 0.0;
    progress = min(1.0, max(0.0, progress));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mục tiêu: $_targetScore điểm',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Hệ thống ĐGNL Quốc gia',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white54, size: 20),
                onPressed: _editTargetScore,
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  color: const Color(0xFF6BFF8F),
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Hoàn thành',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            progress >= 1.0
                ? 'Đã đạt mục tiêu đề ra!'
                : 'Dự kiến đạt mục tiêu trong 3 tuần',
            style: const TextStyle(
              color: Color(0xFF6BFF8F),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillSection(double targetRatio) {
    // ... Giữ nguyên như cũ ...
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outline.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Năng lực từng phần',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _primary,
            ),
          ),
          const SizedBox(height: 24),
          ..._sectionSkills.entries.map((entry) {
            bool isWarning = _totalQuestions > 0 && entry.value < targetRatio;
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: _buildSkillBar(entry.key, entry.value, isWarning),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSkillBar(String title, double ratio, bool isWarning) {
    // ... Giữ nguyên như cũ ...
    return Container(
      padding: isWarning ? const EdgeInsets.all(12) : EdgeInsets.zero,
      decoration: isWarning
          ? BoxDecoration(
              color: _errorBg,
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isWarning ? Icons.warning_amber_rounded : Icons.menu_book,
                    size: 16,
                    color: isWarning ? _error : _primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isWarning ? _error : _primary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Text(
                '${(ratio * 100).toInt()}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isWarning ? _error : _primary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: isWarning ? Colors.white : _bgLight,
              color: isWarning ? _error : _success,
              minHeight: 8,
            ),
          ),
          if (isWarning) ...[
            const SizedBox(height: 8),
            Text(
              'Cần tập trung cải thiện phần này',
              style: TextStyle(color: _error, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
