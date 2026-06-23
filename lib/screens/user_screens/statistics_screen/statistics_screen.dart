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

  // --- DỮ LIỆU ĐỔ VÀO SƠ ĐỒ THẬT ---
  List<int> _questionsByWeekday = [
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ]; // Lưu số câu từ Thứ 2 -> Chủ Nhật
  List<int> _timeByWeekday = [
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ]; // Lưu số phút học từ Thứ 2 -> Chủ Nhật
  Map<String, int> _dailyActivityMap =
      {}; // Lưu hoạt động theo ngày định dạng "yyyy-MM-dd" để vẽ Heatmap

  List<Map<String, dynamic>> _recentActivities = [];
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

  void _listenToStatistics() {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _userSub = FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .snapshots()
        .listen((userDoc) {
          if (userDoc.exists && userDoc.data() != null && mounted) {
            var userData = userDoc.data() as Map<String, dynamic>;
            setState(() {
              _targetScore = userData['targetScore'] ?? 900;
            });
          }
        });

    // 2. Lắng nghe lịch sử làm bài để tính toán sơ đồ (Giữ nguyên toàn bộ phần code bên dưới của bạn)
    _historySub = FirebaseFirestore.instance
        .collection('ExamHistory')
        .where('userId', isEqualTo: uid)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .listen((historySnap) {
          if (historySnap.docs.isNotEmpty) {
            int totalC = 0, totalQ = 0, totalTime = 0;
            int nnC = 0, nnQ = 0;
            int thC = 0, thQ = 0;
            int tdC = 0, tdQ = 0;
            int genC = 0, genQ = 0;

            List<Map<String, dynamic>> tempActivities = [];

            for (var doc in historySnap.docs) {
              var data = doc.data() as Map<String, dynamic>;
              int totalQInExam =
                  data['totalQuestions'] ??
                  0; // Dùng để tính toán chính xác điểm thi thử /1200

              // ĐÃ SỬA: q ở đây là số câu thực tế chọn đáp án để cộng dồn vào biểu đồ thống kê tổng số câu
              int q = data['answeredCount'] ?? totalQInExam;
              int c = data['correctAnswers'] ?? 0;
              int secs = data['timeSpentSeconds'] ?? 0;
              String name = (data['examName'] ?? '').toString().toLowerCase();

              totalQ += q;
              totalC += c;
              totalTime += secs;

              // Xử lý nạp dữ liệu vào biểu đồ 7 ngày và heatmap theo số câu thực tế
              if (data['submittedAt'] != null) {
                DateTime dt = data['submittedAt'].toDate();
                int weekdayIdx = dt.weekday - 1;
                if (weekdayIdx >= 0 && weekdayIdx < 7) {
                  _questionsByWeekday[weekdayIdx] += q;
                  _timeByWeekday[weekdayIdx] += (secs ~/ 60);
                }
                String dateKey = "${dt.year}-${dt.month}-${dt.day}";
                _dailyActivityMap[dateKey] =
                    (_dailyActivityMap[dateKey] ?? 0) + q;
              }

              // Phân loại môn học
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

              if (tempActivities.length < 3) {
                double currentAcc = totalQInExam > 0 ? (c / totalQInExam) : 0.0;
                int estimatedScore = (currentAcc * 1200).toInt();

                String dateLabel = 'Vừa xong';
                if (data['submittedAt'] != null) {
                  DateTime dt = data['submittedAt'].toDate();
                  dateLabel =
                      "${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                }

                bool isPractice =
                    data['examId'] == 'practice_mode' ||
                    name.contains('luyện tập');

                String scoreText;
                String status;
                Color statusColor;

                if (isPractice) {
                  // Khối luyện tập: dùng tổng số câu thực tế làm làm mẫu số
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
                  // Khối thi thử ĐGNL: Giữ nguyên thang điểm /1200 thực tế của đề thi
                  scoreText = '$estimatedScore/1200';

                  // ĐÃ SỬA LOGIC TRẠNG THÁI THI THỬ THỰC TẾ:
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
                    statusColor =
                        _error; // Điểm quá thấp so với mục tiêu sẽ báo đỏ rực rỡ
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

            if (mounted) {
              setState(() {
                _totalQuestions = totalQ;
                _totalTimeMinutes = totalTime ~/ 60;
                _accuracy = totalQ > 0 ? (totalC / totalQ) : 0.0;
                _currentPredictedScore = (_accuracy * 1200).toInt();
                _recentActivities = tempActivities;

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
          } else {
            if (mounted) setState(() => _isLoading = false);
          }
        });
  }

  // --- HÀM CẬP NHẬT MỤC TIÊU ---
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

  // --- HÀM HIỂN THỊ BIỂU ĐỒ CỘT THẬT KHI NHẤN VÀO CARD ---
  void _showChartBottomSheet(String title, String unit, List<int> dataPoints) {
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
            const SizedBox(height: 32),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  int val = dataPoints[index];
                  int maxVal = dataPoints.reduce(max);
                  double heightRatio = maxVal == 0 ? 0.0 : val / maxVal;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '$val',
                        style: TextStyle(
                          fontSize: 11,
                          color: _primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        width: 26,
                        height: max(
                          4.0,
                          150 * heightRatio,
                        ), // Chiều cao cột tỉ lệ thuận với dữ liệu thật
                        decoration: BoxDecoration(
                          color: val > 0
                              ? _primary
                              : Colors.grey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
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
                    // --- 1. SƠ ĐỒ SỐ CÂU ĐÃ LÀM (Gắn dữ liệu thật) ---
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
                        _questionsByWeekday,
                      ),
                    ),

                    // --- 2. SƠ ĐỒ Ô VUÔNG TIẾN ĐỘ HỌC TẬP (HEATMAP THẬT) ---
                    _buildHeatmapCard(),

                    // --- 3. SƠ ĐỒ THỜI GIAN HỌC (Gắn dữ liệu thật) ---
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
                        _timeByWeekday,
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

  // --- WIDGET LƯỚI Ô VUÔNG TIẾN ĐỘ THẬT ---
  Widget _buildHeatmapCard() {
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
          // Vẽ lưới Grid đồng bộ dữ liệu thật theo ngày tháng
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(12, (colIndex) {
              return Column(
                children: List.generate(7, (rowIndex) {
                  // Thuật toán tính ngược số ngày từ hôm nay về quá khứ để quét toàn bộ ma trận lưới
                  int daysAgo = (11 - colIndex) * 7 + (6 - rowIndex);
                  DateTime targetDay = DateTime.now().subtract(
                    Duration(days: daysAgo),
                  );
                  String dateKey =
                      "${targetDay.year}-${targetDay.month}-${targetDay.day}";

                  int count = _dailyActivityMap[dateKey] ?? 0;

                  // Đổi màu rực rỡ dựa trên số câu thật sinh viên làm trong ngày đó
                  Color boxColor = Colors.grey.shade100;
                  if (count > 0 && count <= 10)
                    boxColor = const Color(0xFFC6E48B); // Nhạt (1-10 câu)
                  if (count > 10 && count <= 30)
                    boxColor = const Color(0xFF7BC96F); // Vừa (11-30 câu)
                  if (count > 30)
                    boxColor = const Color(0xFF239A3B); // Đậm (>30 câu)

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
          Text(
            'Hoạt động gần đây',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _primary,
            ),
          ),
          const SizedBox(height: 16),
          ..._recentActivities.map(
            (activity) => Padding(
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
                    child: Icon(
                      Icons.assignment,
                      color: activity['color'],
                      size: 20,
                    ),
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
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard() {
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
