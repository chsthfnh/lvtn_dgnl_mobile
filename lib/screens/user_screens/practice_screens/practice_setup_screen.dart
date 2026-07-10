import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'practice_screen.dart';
import 'level_config.dart';

class PracticeSetupScreen extends StatefulWidget {
  final bool isTab;

  const PracticeSetupScreen({super.key, this.isTab = false});

  @override
  State<PracticeSetupScreen> createState() => _PracticeSetupScreenState();
}

class _PracticeSetupScreenState extends State<PracticeSetupScreen> {
  final Color _primary = const Color(0xFF002045);
  final Color _onPrimary = const Color(0xFFFFFFFF);
  final Color _surface = const Color(0xFFF8F9FF);
  final Color _surfaceContainerLow = const Color(0xFFEFF4FF);
  final Color _outline = const Color(0xFFC4C6CF);
  final Color _secondary = const Color(0xFF006E2F);

  // --- TRẠNG THÁI LỰA CHỌN MỚI ---
  bool _isLevelMode = true; // Mặc định là chế độ Vượt ải
  int _currentLevel = 1;

  String? _selectedPhanThi;
  String _selectedChuDe = 'Tất cả';
  int _questionCount = 20; // Dùng cho chế độ cũ
  int _duration = 30; // Dùng cho cả 2 chế độ

  bool _isLoading = false;

  final Map<String, Map<String, dynamic>> _subjects = {
    'Sử dụng ngôn ngữ': {
      'icon': Icons.menu_book_rounded,
      'subs': ['Tất cả', 'Tiếng Việt', 'Tiếng Anh'],
    },
    'Toán học': {
      'icon': Icons.calculate_rounded,
      'subs': ['Tất cả'],
    },
    'Tư duy khoa học': {
      'icon': Icons.science_rounded,
      'subs': ['Tất cả', 'Logic', 'Suy luận'],
    },
  };

  // Lấy "từ khóa" để lưu tiến trình (VD: "Tiếng Việt", hoặc "Toán học")
  String get _progressKey =>
      _selectedChuDe == 'Tất cả' ? _selectedPhanThi ?? '' : _selectedChuDe;

  @override
  void initState() {
    super.initState();
    // Khởi tạo mặc định
    _selectedPhanThi = 'Sử dụng ngôn ngữ';
    _selectedChuDe = 'Tiếng Việt';
    _fetchUserProgress();
  }

  // --- HÀM 1: LẤY TIẾN TRÌNH TỪ FIREBASE ---
  Future<void> _fetchUserProgress() async {
    if (_selectedPhanThi == null) return;

    String uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('UserProgress')
          .doc(uid)
          .get();
      if (doc.exists && doc.data() != null) {
        var data = doc.data() as Map<String, dynamic>;
        if (data.containsKey(_progressKey)) {
          setState(() {
            _currentLevel = data[_progressKey]['level'] ?? 1;
          });
          return;
        }
      }
      // Nếu chưa từng học môn này
      setState(() => _currentLevel = 1);
    } catch (e) {
      debugPrint('Lỗi tải tiến trình: $e');
    }
  }

  // --- HÀM 2: RESET TIẾN TRÌNH ---
  void _resetProgress() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Xác nhận Reset',
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa toàn bộ tiến trình của phần "$_progressKey" và bắt đầu lại từ Level 1 không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              String uid = FirebaseAuth.instance.currentUser!.uid;
              await FirebaseFirestore.instance
                  .collection('UserProgress')
                  .doc(uid)
                  .set({
                    _progressKey: {'level': 1, 'consecutivePasses': 0},
                  }, SetOptions(merge: true));

              setState(() {
                _currentLevel = 1;
                _isLoading = false;
              });
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã reset tiến trình thành công!'),
                  ),
                );
            },
            child: const Text(
              'Xác nhận Reset',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // --- HÀM 3: LUỒNG BỐC CÂU HỎI CHÍNH ---
  Future<void> _startPractice() async {
    if (_selectedPhanThi == null) {
      _showError('Vui lòng chọn một môn học để luyện tập!');
      return;
    }

    if (_isLevelMode) {
      await _startLevelPractice();
    } else {
      await _startFreePractice(); // Gọi lại hàm cũ của bạn
    }
  }

  // LUỒNG MỚI: BỐC CÂU HỎI THEO LEVEL
  // LUỒNG MỚI: BỐC CÂU HỎI THEO LEVEL
  Future<void> _startLevelPractice() async {
    setState(() => _isLoading = true);

    // 1. Tính toán số lượng cần thiết
    int totalNeeded = LevelConfig.questionCount[_progressKey] ?? 30;
    int easyNeeded =
        (totalNeeded * LevelConfig.difficultyRatio[_currentLevel]!['Dễ']!)
            .round();
    int medNeeded =
        (totalNeeded *
                LevelConfig.difficultyRatio[_currentLevel]!['Trung bình']!)
            .round();
    int hardNeeded = totalNeeded - easyNeeded - medNeeded;

    // --- ĐƯA BIẾN RA PHẠM VI HÀM CHA Ở ĐÂY ---
    List<DocumentSnapshot> finalQuestions = [];
    List<String> shortageMessages = [];

    // Hàm helper để bốc theo độ khó
    Future<void> fetchByDifficulty(String difficulty, int requiredCount) async {
      if (requiredCount <= 0) return;

      Query query = FirebaseFirestore.instance
          .collection('Questions')
          .where('phanThi', isEqualTo: _selectedPhanThi);

      if (_selectedChuDe != 'Tất cả') {
        query = query.where('chuDe', isEqualTo: _selectedChuDe);
      }

      var snap = await query.get();

      // LỌC: khớp độ khó KHÔNG phân biệt hoa/thường và khoảng trắng thừa
      // (tránh lỗi lệch chính tả kiểu "Trung Bình" vs "Trung bình" trong Firestore)
      String normalize(String s) => s.trim().toLowerCase();
      var availableDocs = snap.docs.where((doc) {
        var data = doc.data() as Map<String, dynamic>;
        String doKho = (data['doKho'] ?? '').toString();
        return normalize(doKho) == normalize(difficulty);
      }).toList();
      // GHI CHÚ: KHÔNG lọc theo maDeThi ở đây - luyện tập được phép dùng
      // mọi câu hỏi trong kho, kể cả câu đã được gán vào một đề thi thử.
      // Việc loại trừ theo maDeThi chỉ áp dụng khi ADMIN tạo đề thi khác
      // (tránh 1 câu bị trùng ở 2 đề thi), không áp dụng cho luyện tập.

      // --- DEBUG: xem thực tế Firestore trả về bao nhiêu câu ---
      debugPrint(
        '[DEBUG] phanThi=$_selectedPhanThi | chuDe=$_selectedChuDe | doKho=$difficulty '
        '=> tổng theo phanThi/chuDe: ${snap.docs.length} câu, khớp độ khó: ${availableDocs.length} câu, cần $requiredCount câu',
      );

      // Tách câu chùm (cụm) và câu lẻ
      Map<String, List<DocumentSnapshot>> grouped = {};
      List<DocumentSnapshot> singles = [];

      for (var doc in availableDocs) {
        var data = doc.data() as Map<String, dynamic>;
        String maNhom = data['maNhom']?.toString().trim() ?? '';
        if (maNhom.isNotEmpty) {
          grouped.putIfAbsent(maNhom, () => []).add(doc);
        } else {
          singles.add(doc);
        }
      }

      List<List<DocumentSnapshot>> allBlocks = [];
      allBlocks.addAll(grouped.values);
      allBlocks.addAll(singles.map((e) => [e]));
      allBlocks.shuffle();

      // THUẬT TOÁN MỚI - ĐƠN GIẢN & LUÔN ƯU TIÊN ĐỦ SỐ LƯỢNG:
      // Ưu tiên các block vừa khít trước để hạn chế dư thừa, nhưng nếu
      // không còn cách nào khác thì CỨ LẤY NGUYÊN CẢ CỤM dù bị lố một ít,
      // miễn sao đạt đủ requiredCount. Chỉ báo thiếu khi lấy HẾT SẠCH kho
      // (toàn bộ availableDocs) mà vẫn không đủ.
      int currentCount = 0;

      // 1. Lấy các block (cụm hoặc câu lẻ) nào vừa khít mà không làm lố, ưu tiên trước
      List<List<DocumentSnapshot>> remaining = [];
      for (var block in allBlocks) {
        if (currentCount + block.length <= requiredCount) {
          finalQuestions.addAll(block);
          currentCount += block.length;
        } else {
          remaining.add(block);
        }
      }

      // 2. Nếu vẫn còn thiếu, LẤY NGUYÊN CỤM còn lại (cho phép lố) cho đến khi đủ
      remaining.shuffle();
      for (var block in remaining) {
        if (currentCount >= requiredCount) break;
        finalQuestions.addAll(block);
        currentCount += block.length;
      }

      // 3. Chỉ báo thiếu khi đã lấy HẾT toàn bộ kho rảnh mà vẫn không đủ
      if (currentCount < requiredCount) {
        shortageMessages.add(
          '• Độ khó "$difficulty": Cần $requiredCount câu, kho rảnh chỉ ghép được tối đa $currentCount câu (có ${availableDocs.length} câu lẻ/cụm khả dụng)',
        );
      }
    }

    try {
      // 2. Thực thi bốc 3 loại độ khó
      await fetchByDifficulty('Dễ', easyNeeded);
      await fetchByDifficulty('Trung bình', medNeeded);
      await fetchByDifficulty('Khó', hardNeeded);

      // 3. Xử lý kết quả
      if (shortageMessages.isNotEmpty) {
        setState(() => _isLoading = false);
        _showDetailedShortageDialog(
          shortageMessages,
          _currentLevel,
          _progressKey,
        );
        return;
      }

      setState(() => _isLoading = false);
      finalQuestions.shuffle();
      _showSuccessDialog(finalQuestions, finalQuestions.length);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Lỗi hệ thống: $e');
    }
  }

  // LUỒNG CŨ: TỰ DO (Giữ nguyên logic của bạn)
  Future<void> _startFreePractice() async {
    setState(() => _isLoading = true);
    try {
      Query query = FirebaseFirestore.instance
          .collection('Questions')
          .where('phanThi', isEqualTo: _selectedPhanThi);
      if (_selectedChuDe != 'Tất cả')
        query = query.where('chuDe', isEqualTo: _selectedChuDe);

      var snap = await query.get();
      var docs = snap.docs;
      docs.shuffle();

      if (docs.length < _questionCount) {
        _showError('Ngân hàng hiện chỉ có ${docs.length} câu phù hợp.');
        return;
      }

      setState(() => _isLoading = false);
      _showSuccessDialog(docs.take(_questionCount).toList(), _questionCount);
    } catch (e) {
      _showError('Lỗi hệ thống: $e');
    }
  }

  void _showError(String msg) {
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  void _showDetailedShortageDialog(
    List<String> shortageMessages,
    int currentLevel,
    String progressKey,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Kho câu hỏi chưa đủ',
              style: TextStyle(color: _primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Không đủ câu hỏi để tạo đề cho "$progressKey" (Level $currentLevel):',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            ...shortageMessages.map(
              (msg) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(msg, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: _onPrimary,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(List<DocumentSnapshot> questions, int count) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: _secondary, size: 28),
            const SizedBox(width: 12),
            Text(
              'Sẵn sàng!',
              style: TextStyle(color: _primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Đã bốc thành công $count câu hỏi. Nhấn BẮT ĐẦU để tính giờ.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: _onPrimary,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PracticeScreen(
                    questions: questions,
                    timeInMinutes: _isLevelMode
                        ? (count * 1.5).round()
                        : _duration, // Level mode auto set thời gian = số câu * 1.5p
                    subjectName:
                        '$_progressKey ${_isLevelMode ? '(Level $_currentLevel)' : ''}',
                    isTab: widget.isTab,
                    isLevelMode: _isLevelMode,
                    currentLevel: _currentLevel,
                    progressKey: _progressKey,
                  ),
                ),
              );
            },
            child: const Text('BẮT ĐẦU THI'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: widget.isTab
            ? const SizedBox.shrink()
            : IconButton(
                icon: Icon(Icons.arrow_back, color: _primary),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          'Thiết lập Luyện tập',
          style: TextStyle(
            color: _primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // CHỌN CHẾ ĐỘ THI
              _buildModeSelector(),
              const SizedBox(height: 24),

              _buildSectionTitle('1. Chọn môn học mục tiêu'),
              const SizedBox(height: 16),
              ..._subjects.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildSubjectCard(entry.key, entry.value['icon']),
                ),
              ),

              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                child:
                    _selectedPhanThi != null &&
                        _subjects[_selectedPhanThi]!['subs'].length > 1
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          _buildSectionTitle('2. Chọn nội dung ôn tập'),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children:
                                (_subjects[_selectedPhanThi]!['subs']
                                        as List<String>)
                                    .map((sub) => _buildSubTopicChip(sub))
                                    .toList(),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),

              const SizedBox(height: 32),

              // HIỂN THỊ CẤU HÌNH DỰA THEO CHẾ ĐỘ
              if (_isLevelMode)
                _buildLevelInfoPanel()
              else
                _buildConfigurationPanel(),

              const SizedBox(height: 100),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: Center(child: CircularProgressIndicator(color: _primary)),
            ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isLoading ? null : _startPractice,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: _onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 54),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isLevelMode ? Icons.rocket_launch : Icons.play_circle_filled,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  _isLevelMode
                      ? 'VƯỢT ẢI LEVEL $_currentLevel'
                      : 'BẮT ĐẦU LUYỆN TẬP',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---
  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isLevelMode = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isLevelMode ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _isLevelMode
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    '🏆 Vượt ải cấp độ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isLevelMode ? _primary : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isLevelMode = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isLevelMode ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: !_isLevelMode
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    '⚙️ Luyện tập tự do',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: !_isLevelMode ? _primary : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelInfoPanel() {
    int totalQ = LevelConfig.questionCount[_progressKey] ?? 30;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primary.withOpacity(0.2)),
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
                    'Tiến trình: $_progressKey',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.orange, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        'Level $_currentLevel / 10',
                        style: TextStyle(
                          color: _primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.red),
                tooltip: 'Reset tiến trình',
                onPressed: _resetProgress,
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat('Số câu', '$totalQ câu', Icons.list_alt),
              _buildMiniStat(
                'Độ khó',
                'Chuẩn Lvl $_currentLevel',
                Icons.bar_chart,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String val, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            Text(
              val,
              style: TextStyle(fontWeight: FontWeight.bold, color: _primary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: _primary,
      ),
    );
  }

  Widget _buildSubjectCard(String title, IconData icon) {
    bool isSelected = _selectedPhanThi == title;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPhanThi = title;
          _selectedChuDe = 'Tất cả';
          _fetchUserProgress(); // Load lại level mỗi khi đổi môn
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? _surfaceContainerLow : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _primary : _outline,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? _primary : Colors.grey, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: _primary,
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: _primary, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTopicChip(String label) {
    bool isSelected = _selectedChuDe == label;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedChuDe = label;
          _fetchUserProgress(); // Load lại level mỗi khi đổi chủ đề
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? _primary : _outline),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? _onPrimary : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildConfigurationPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('3. Cấu hình tự do'),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Số lượng câu hỏi',
                style: TextStyle(color: _primary, fontWeight: FontWeight.w600),
              ),
              Text(
                '$_questionCount câu',
                style: TextStyle(color: _primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: _questionCount.toDouble(),
            min: 10,
            max: 60,
            divisions: 5,
            activeColor: _primary,
            onChanged: (val) => setState(() => _questionCount = val.toInt()),
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Thời gian làm bài',
                style: TextStyle(color: _primary, fontWeight: FontWeight.w600),
              ),
              Text(
                '$_duration phút',
                style: TextStyle(color: _primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: _duration.toDouble(),
            min: 15,
            max: 90,
            divisions: 5,
            activeColor: _primary,
            onChanged: (val) => setState(() => _duration = val.toInt()),
          ),
        ],
      ),
    );
  }
}
