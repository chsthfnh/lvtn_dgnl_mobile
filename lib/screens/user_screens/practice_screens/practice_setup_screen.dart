import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'practice_screen.dart';

class PracticeSetupScreen extends StatefulWidget {
  final bool isTab; // Kiểm tra xem có phải truy cập từ thanh Menu hay không

  const PracticeSetupScreen({super.key, this.isTab = false});

  @override
  State<PracticeSetupScreen> createState() => _PracticeSetupScreenState();
}

class _PracticeSetupScreenState extends State<PracticeSetupScreen> {
  // --- BẢNG MÀU TỪ DESIGN SYSTEM "COGNITIVE MASTERY" ---
  final Color _primary = const Color(0xFF002045);
  final Color _onPrimary = const Color(0xFFFFFFFF);
  final Color _surface = const Color(0xFFF8F9FF);
  final Color _surfaceContainerLow = const Color(0xFFEFF4FF);
  final Color _outline = const Color(0xFFC4C6CF);
  final Color _secondary = const Color(0xFF006E2F);

  // --- TRẠNG THÁI LỰA CHỌN ---
  String? _selectedPhanThi;
  String _selectedChuDe = 'Tất cả';
  int _questionCount = 20;
  int _duration = 30;

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

  // --- THUẬT TOÁN LẤY CÂU HỎI VÀ KIỂM TRA SỐ LƯỢNG ---
  Future<void> _startPractice() async {
    if (_selectedPhanThi == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn một môn học để luyện tập!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      Query query = FirebaseFirestore.instance
          .collection('Questions')
          .where('phanThi', isEqualTo: _selectedPhanThi);

      if (_selectedChuDe != 'Tất cả') {
        query = query.where('chuDe', isEqualTo: _selectedChuDe);
      }

      var snap = await query.get();
      var docs = snap.docs;

      // Chặn kiểm tra số lượng câu hỏi nghiêm ngặt
      if (docs.length < _questionCount) {
        _showError(
          'Vượt quá số lượng câu hỏi đang có! Ngân hàng hiện chỉ có ${docs.length} câu phù hợp với cấu hình này.',
        );
        return;
      }

      // Thuật toán xáo trộn bảo toàn cụm nhóm câu hỏi chùm
      Map<String, List<DocumentSnapshot>> grouped = {};
      List<DocumentSnapshot> singles = [];

      for (var doc in docs) {
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

      List<DocumentSnapshot> finalQuestions = [];
      int currentCount = 0;

      for (var block in allBlocks) {
        if (currentCount + block.length <= _questionCount) {
          finalQuestions.addAll(block);
          currentCount += block.length;
        }
        if (currentCount == _questionCount) break;
      }

      setState(() => _isLoading = false);

      if (finalQuestions.length < _questionCount) {
        _showError(
          'Không thể bốc chính xác số câu do ràng buộc câu hỏi chùm. Hãy thử lại hoặc đổi số lượng câu hỏi!',
        );
        return;
      }

      _showSuccessDialog(finalQuestions);
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

  void _showSuccessDialog(List<DocumentSnapshot> questions) {
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
          'Đã bốc thành công ${questions.length} câu hỏi. Nhấn OK để bắt đầu tính giờ làm bài.',
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
                    timeInMinutes: _duration,
                    subjectName: _selectedPhanThi ?? 'Tổng hợp',
                    isTab: widget.isTab, // Truyền tiếp flag trạng thái nguồn đi
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
      // --- CẤU HÌNH APPBAR XOÁ BỎ HOÀN TOÀN NÚT BACK KHI LÀ TAB ---
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading:
            false, // Tắt hoàn toàn nút mặc định của hệ thống
        // Nếu là Tab -> Dùng SizedBox.shrink() để xóa trắng chỗ đó.
        // Nếu không phải Tab -> Vẽ nút Mũi tên.
        leading: widget.isTab
            ? const SizedBox.shrink()
            : IconButton(
                icon: Icon(Icons.arrow_back, color: _primary),
                onPressed: () => Navigator.pop(context),
              ),

        title: Text(
          'Luyện tập chuyên đề',
          style: TextStyle(
            color: _primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _outline.withValues(alpha: 0.3), height: 1),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
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
                curve: Curves.easeInOut,
                child:
                    _selectedPhanThi != null &&
                        _subjects[_selectedPhanThi]!['subs'].length > 1
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
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
              _buildSectionTitle('3. Cấu hình bài luyện tập'),
              const SizedBox(height: 16),
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
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_filled, size: 22),
                SizedBox(width: 8),
                Text(
                  'BẮT ĐẦU LUYỆN TẬP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primary.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? _primary : _surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? _onPrimary : _primary,
                size: 24,
              ),
            ),
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
            if (isSelected)
              Icon(Icons.check_circle, color: _primary, size: 24)
            else
              Icon(Icons.radio_button_unchecked, color: _outline, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTopicChip(String label) {
    bool isSelected = _selectedChuDe == label;
    return InkWell(
      onTap: () => setState(() => _selectedChuDe = label),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.format_list_numbered, color: _primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Số lượng câu hỏi',
                    style: TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_questionCount câu',
                  style: TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _questionCount.toDouble(),
            min: 10,
            max: 60,
            divisions: 5,
            activeColor: _primary,
            inactiveColor: _surfaceContainerLow,
            onChanged: (val) => setState(() => _questionCount = val.toInt()),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.timer_outlined, color: _primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Thời gian làm bài',
                    style: TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_duration phút',
                  style: TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _duration.toDouble(),
            min: 15,
            max: 90,
            divisions: 5,
            activeColor: _primary,
            inactiveColor: _surfaceContainerLow,
            onChanged: (val) => setState(() => _duration = val.toInt()),
          ),
        ],
      ),
    );
  }
}
