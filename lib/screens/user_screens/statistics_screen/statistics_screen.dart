import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';
import '../ai_screens/ai_performance_analysis_widget.dart';
import 'package:fl_chart/fl_chart.dart';

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
  String? _loadError;
  StreamSubscription<DocumentSnapshot>? _userSub;
  StreamSubscription<QuerySnapshot>? _historySub;
  StreamSubscription<DocumentSnapshot>?
  _progressSub; // Thêm stream cho Gamification

  // --- DỮ LIỆU TỔNG QUAN ---
  int _totalQuestions = 0;
  int _totalTimeMinutes = 0;
  double _accuracy = 0.0;
  int _targetScore = 900;
  int _currentPredictedScore = 0;

  // --- DỮ LIỆU GAMIFICATION (TIẾN ĐỘ VƯỢT ẢI) ---
  Map<String, dynamic> _userProgress = {};

  // --- DỮ LIỆU SƠ ĐỒ ---
  List<int> _practiceQByWeekday = [0, 0, 0, 0, 0, 0, 0];
  List<int> _examQByWeekday = [0, 0, 0, 0, 0, 0, 0];
  List<int> _practiceTimeByWeekday = [0, 0, 0, 0, 0, 0, 0];
  List<int> _examTimeByWeekday = [0, 0, 0, 0, 0, 0, 0];
  Map<String, int> _dailyActivityMap = {};

  // --- DỮ LIỆU HOẠT ĐỘNG ---
  List<Map<String, dynamic>> _recentActivities = [];
  List<Map<String, dynamic>> _allRecentActivities = [];

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
    _progressSub?.cancel();
    super.dispose();
  }

  // --- HÀM TRUY VẤN VÀ TÍNH TOÁN DỮ LIỆU THẬT REAL-TIME ---
  void _listenToStatistics() {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _userSub?.cancel();
    _progressSub?.cancel();
    _historySub?.cancel();
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    // 1. Lắng nghe mục tiêu điểm
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

    // 2. Lắng nghe Tiến độ Gamification (Vượt ải Level)
    _progressSub = FirebaseFirestore.instance
        .collection('UserProgress')
        .doc(uid)
        .snapshots()
        .listen((progDoc) {
          if (progDoc.exists && progDoc.data() != null && mounted) {
            setState(() {
              _userProgress = progDoc.data() as Map<String, dynamic>;
            });
          }
        });

    // 3. Lắng nghe Lịch sử làm bài
    _historySub = FirebaseFirestore.instance
        .collection('ExamHistory')
        .where('userId', isEqualTo: uid)
        .orderBy('submittedAt', descending: true)
        .limit(200)
        .snapshots()
        .listen(
          (historySnap) {
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

                bool isLevelMode = data['examId'] == 'level_mode';
                bool isPractice =
                    isLevelMode ||
                    data['examId'] == 'practice_mode' ||
                    name.contains('luyện tập');
                int stars = data['stars'] ?? 0;
                int level = data['level'] ?? 1;

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

                // Lọc môn học
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

                // Xử lý lưu danh sách hoạt động gần đây
                if (tempActivities.length < 20) {
                  double currentAcc = totalQInExam > 0
                      ? (c / totalQInExam)
                      : 0.0;
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
                    'isLevelMode': isLevelMode, // Biến cờ Gamification
                    'stars': stars,
                    'level': level,
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

                _allRecentActivities = tempActivities;
                _recentActivities = tempActivities.take(3).toList();

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
          },
          onError: (error) {
            debugPrint('Lỗi tải thống kê: $error');
            if (mounted) {
              setState(() {
                _loadError =
                    'Không thể tải thống kê. Kiểm tra mạng rồi thử lại.';
                _isLoading = false;
              });
            }
          },
        );
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
    // Tính toán trục Y cao nhất để biểu đồ không bị kịch trần
    double maxY = 0;
    for (int i = 0; i < 7; i++) {
      double total = (practiceData[i] + examData[i]).toDouble();
      if (total > maxY) maxY = total;
    }
    if (maxY == 0) maxY = 10; // Mặc định nếu chưa có dữ liệu

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
            const SizedBox(height: 24),
            Row(
              children: [
                Container(width: 12, height: 12, color: _primary),
                const SizedBox(width: 6),
                const Text(
                  'Luyện tập',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(width: 20),
                Container(
                  width: 12,
                  height: 12,
                  color: const Color(0xFFE65100),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Thi thử',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // --- KHU VỰC VẼ BIỂU ĐỒ BẰNG FL_CHART ---
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY + (maxY * 0.2), // Thêm 20% khoảng trống phía trên
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => _primary,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          '${rod.toY.toInt()} $unit',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const days = [
                            'T2',
                            'T3',
                            'T4',
                            'T5',
                            'T6',
                            'T7',
                            'CN',
                          ];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              days[value.toInt()],
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY > 0
                        ? (maxY / 4 > 0 ? maxY / 4 : 1)
                        : 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.2),
                      strokeWidth: 1,
                      dashArray: [4, 4], // Kẻ vạch ngang đứt khúc cho đẹp
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(7, (index) {
                    double pVal = practiceData[index].toDouble();
                    double eVal = examData[index].toDouble();
                    double total = pVal + eVal;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: total,
                          width: 16, // Độ rộng của cột
                          borderRadius: BorderRadius.circular(4),
                          // Tính năng Stacked Bar (Chồng 2 màu)
                          rodStackItems: [
                            BarChartRodStackItem(0, pVal, _primary),
                            BarChartRodStackItem(
                              pVal,
                              total,
                              const Color(0xFFE65100),
                            ),
                          ],
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxY + (maxY * 0.2),
                            color: Colors.grey.shade100, // Cột bóng mờ làm nền
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                swapAnimationDuration: const Duration(
                  milliseconds: 600,
                ), // Thời gian chạy animation
                swapAnimationCurve: Curves.easeOutQuart,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllRecentActivities() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
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

    // --- BƯỚC 1: TẠO CHUỖI DỮ LIỆU ĐỘNG CHO AI PHÂN TÍCH ---
    String statsSummary =
        '''
- Tổng số câu đã làm: $_totalQuestions câu
- Độ chính xác tổng thể: ${(_accuracy * 100).toInt()}%
- Điểm dự kiến hiện tại: $_currentPredictedScore / 1200 (Mục tiêu: $_targetScore)
- Năng lực Ngôn ngữ: ${(_sectionSkills['Ngôn ngữ']! * 100).toInt()}%
- Năng lực Toán học: ${(_sectionSkills['Toán học']! * 100).toInt()}%
- Năng lực Tư duy Logic: ${(_sectionSkills['Tư duy Logic']! * 100).toInt()}%
''';

    return Scaffold(
      backgroundColor: _bgLight,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(_loadError!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _listenToStatistics,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            )
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

                    // --- BƯỚC 2: CHÈN CARD BÁO CÁO AI VÀO ĐÂY ---
                    AIPerformanceAnalysisCard(historyStatsText: statsSummary),
                    const SizedBox(height: 24),

                    // THẺ TIẾN ĐỘ GAMIFICATION NẰM NGAY TRÊN HOẠT ĐỘNG GẦN ĐÂY
                    _buildLevelProgressCard(),

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

  // --- THẺ MỚI: TIẾN ĐỘ VƯỢT ẢI GAMIFICATION ---
  Widget _buildLevelProgressCard() {
    final List<String> subjects = [
      'Tiếng Việt',
      'Tiếng Anh',
      'Toán học',
      'Logic',
      'Suy luận',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
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
              Icon(Icons.military_tech, color: Colors.amber.shade700, size: 24),
              const SizedBox(width: 8),
              Text(
                'Tiến độ Vượt ải (Gamification)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: subjects.map((sub) {
                var data = _userProgress[sub];
                int level = data != null ? (data['level'] ?? 1) : 1;
                int consecutive = data != null
                    ? (data['consecutivePasses'] ?? 0)
                    : 0;

                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  width: 140,
                  decoration: BoxDecoration(
                    color: _bgLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _outline.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _primary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: level == 10
                                  ? Colors.amber.shade100
                                  : Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Lvl $level',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: level == 10
                                    ? Colors.amber.shade900
                                    : Colors.blue.shade900,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.local_fire_department,
                            size: 14,
                            color: Colors.orange.shade700,
                          ),
                          Text(
                            '$consecutive/2',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: consecutive / 2,
                        backgroundColor: Colors.orange.shade100,
                        color: Colors.orange.shade700,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
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

  // --- CẬP NHẬT CƠ CHẾ HIỂN THỊ ITEM ĐỂ HỖ TRỢ GAMIFICATION ---
  Widget _buildActivityItem(Map<String, dynamic> activity) {
    bool isLevelMode = activity['isLevelMode'] ?? false;
    int stars = activity['stars'] ?? 0;
    int level = activity['level'] ?? 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isLevelMode
                  ? Colors.amber.shade100
                  : activity['color'].withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isLevelMode ? Icons.military_tech : Icons.assignment,
              color: isLevelMode ? Colors.amber.shade700 : activity['color'],
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        activity['title'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _primary,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isLevelMode)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Lvl $level',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  activity['subtitle'],
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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
              // Hiển thị 5 sao nếu là bài vượt ải, ngược lại hiện trạng thái chữ bình thường
              if (isLevelMode)
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 14,
                      color: Colors.amber.shade600,
                    ),
                  ),
                )
              else
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
                onTap: _showAllRecentActivities,
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
          ..._recentActivities.map((activity) => _buildActivityItem(activity)),
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
