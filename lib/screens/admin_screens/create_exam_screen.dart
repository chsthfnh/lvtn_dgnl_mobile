import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'exam_questions_screen.dart';

class CreateExamScreen extends StatefulWidget {
  final DocumentSnapshot? examDoc; // NHẬN DỮ LIỆU ĐỂ SỬA
  const CreateExamScreen({super.key, this.examDoc});

  @override
  State<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends State<CreateExamScreen> {
  final Color _primary = const Color(0xFF002045);
  final Color _bgLight = const Color(0xFFF8F9FF);
  final Color _outline = const Color(0xFFC4C6CF);
  final Color _surfaceContainerLow = const Color(0xFFEFF4FF);
  final Color _primaryFixed = const Color(0xFFD6E3FF);

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _durationCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  String _strategy = 'random';
  int _tiengVietCount = 30;
  int _tiengAnhCount = 30;
  int _toanHocCount = 30;
  int _logicCount = 12;
  int _suyLuanCount = 18;

  int get _totalQuestions =>
      _tiengVietCount +
      _tiengAnhCount +
      _toanHocCount +
      _logicCount +
      _suyLuanCount;

  bool _shuffleQuestions = true;
  bool _shuffleOptions = true;
  bool _isPublic = false;

  @override
  void initState() {
    super.initState();
    // ĐIỀN DỮ LIỆU CŨ NẾU LÀ CHẾ ĐỘ SỬA
    if (widget.examDoc != null) {
      Map<String, dynamic> data =
          widget.examDoc!.data() as Map<String, dynamic>;
      _nameCtrl.text = data['tenDeThi'] ?? '';
      _durationCtrl.text = data['thoiGian']?.toString() ?? '150';
      _codeCtrl.text = data['maDe'] ?? '';
      _descCtrl.text = data['moTa'] ?? '';
      _strategy = data['strategy'] ?? 'random';
      _isPublic = data['isPublic'] ?? false;
      _shuffleQuestions = data['shuffleQuestions'] ?? true;
      _shuffleOptions = data['shuffleOptions'] ?? true;

      if (data['config'] != null) {
        _tiengVietCount = data['config']['Tiếng Việt'] ?? 30;
        _tiengAnhCount = data['config']['Tiếng Anh'] ?? 30;
        _toanHocCount = data['config']['Toán học'] ?? 30;
        _logicCount = data['config']['Logic'] ?? 12;
        _suyLuanCount = data['config']['Suy luận'] ?? 18;
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _durationCtrl.dispose();
    _codeCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // --- HÀM XỬ LÝ CHUYỂN BƯỚC TIẾP THEO ---
  void _handleNextStep({bool saveAsDraft = false}) {
    if (_formKey.currentState!.validate()) {
      if (_strategy == 'random' && _totalQuestions != 120) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vui lòng phân bổ ĐÚNG 120 câu hỏi (Hiện tại đang là: $_totalQuestions câu)',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Nút Lưu Bản Nháp sẽ ép isPublic = false
      if (saveAsDraft) _isPublic = false;

      // Gom dữ liệu (Giữ lại số liệu thống kê sinh viên nếu có)
      Map<String, dynamic> examData = {
        'examId':
            widget.examDoc?.id, // Ném ID sang bước sau để biết là Đang Sửa
        'questions': widget.examDoc != null
            ? (widget.examDoc!.data() as Map)['questions']
            : null,
        'luotLamBai': widget.examDoc != null
            ? (widget.examDoc!.data() as Map)['luotLamBai']
            : 0,
        'dangLamBai': widget.examDoc != null
            ? (widget.examDoc!.data() as Map)['dangLamBai']
            : 0,
        'tenDeThi': _nameCtrl.text.trim(),
        'thoiGian': int.tryParse(_durationCtrl.text.trim()) ?? 150,
        'maDe': _codeCtrl.text.trim(),
        'moTa': _descCtrl.text.trim(),
        'strategy': _strategy,
        'shuffleQuestions': _shuffleQuestions,
        'shuffleOptions': _shuffleOptions,
        'isPublic': _isPublic,
      };

      Map<String, int> config = {
        'Tiếng Việt': _tiengVietCount,
        'Tiếng Anh': _tiengAnhCount,
        'Toán học': _toanHocCount,
        'Logic': _logicCount,
        'Suy luận': _suyLuanCount,
      };

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ExamQuestionsScreen(examData: examData, config: config),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.examDoc != null;
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: _buildAppBar(isEditing),
      body: Column(
        children: [
          _buildProgressStepper(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBasicInfoSection(),
                        const SizedBox(height: 40),
                        _buildStrategySection(),
                        const SizedBox(height: 40),
                        _buildConfigurationSection(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildStickyFooter(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isEditing) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: _outline.withValues(alpha: 0.3), height: 1),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: _primary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEditing ? 'Sửa đề thi' : 'Tạo đề thi mới',
            style: TextStyle(
              color: _primary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'HỆ THỐNG QUẢN LÝ HỌC THUẬT',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStepper() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 40,
                right: 40,
                top: 20,
                child: Container(height: 2, color: _primaryFixed),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStepItem(
                    icon: Icons.info,
                    label: 'Thông tin chung',
                    isActive: true,
                  ),
                  _buildStepItem(
                    icon: Icons.account_tree,
                    label: 'Soạn câu hỏi',
                    isActive: false,
                  ),
                  _buildStepItem(
                    icon: Icons.tune,
                    label: 'Hoàn tất',
                    isActive: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepItem({
    required IconData icon,
    required String label,
    required bool isActive,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? _primary : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? _primaryFixed : _outline,
                width: isActive ? 4 : 2,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : Colors.grey.shade600,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? _primary : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _primary),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.article,
          title: 'Thông tin cơ bản',
          subtitle: 'Nhập tiêu đề và các thông tin định danh cho kỳ thi.',
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _outline.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              _buildTextField(
                label: 'Tên đề thi',
                controller: _nameCtrl,
                hint: 'VD: Đề thi thử ĐGNL 2024 - Đợt 1',
                isRequired: true,
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTextField(
                      label: 'Thời gian làm bài',
                      controller: _durationCtrl,
                      hint: '150',
                      isRequired: true,
                      isNumber: true,
                      suffixText: 'phút',
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildTextField(
                      label: 'Mã đề (Tùy chọn)',
                      controller: _codeCtrl,
                      hint: 'Mã định danh nội bộ',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildTextField(
                label: 'Mô tả chi tiết',
                controller: _descCtrl,
                hint: 'Nhập ghi chú hoặc mô tả nội dung đề thi...',
                maxLines: 3,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStrategySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.psychology,
          title: 'Chiến lược xây dựng đề',
          subtitle: 'Lựa chọn cách thức hệ thống lấy câu hỏi từ ngân hàng.',
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _outline.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStrategyCard(
                      id: 'manual',
                      title: 'Tự chọn',
                      desc: 'Chọn thủ công từng câu.',
                      icon: Icons.edit_note,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStrategyCard(
                      id: 'random',
                      title: 'Ngẫu nhiên',
                      desc: 'Hệ thống tự động bốc.',
                      icon: Icons.shuffle,
                    ),
                  ),
                ],
              ),

              if (_strategy == 'random') ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _outline.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.settings_suggest,
                                  size: 18,
                                  color: _primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Phân bổ số lượng',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _primary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _outline),
                            ),
                            child: Text(
                              'Tổng: $_totalQuestions',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCountInput(
                              'Tiếng Việt',
                              Icons.menu_book,
                              _tiengVietCount,
                              (val) => setState(() => _tiengVietCount = val),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildCountInput(
                              'Tiếng Anh',
                              Icons.language,
                              _tiengAnhCount,
                              (val) => setState(() => _tiengAnhCount = val),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCountInput(
                              'Toán học',
                              Icons.calculate,
                              _toanHocCount,
                              (val) => setState(() => _toanHocCount = val),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildCountInput(
                              'Logic',
                              Icons.extension,
                              _logicCount,
                              (val) => setState(() => _logicCount = val),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildCountInput(
                              'Suy luận',
                              Icons.lightbulb,
                              _suyLuanCount,
                              (val) => setState(() => _suyLuanCount = val),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(child: SizedBox()),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStrategyCard({
    required String id,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    bool isSelected = _strategy == id;
    return GestureDetector(
      onTap: () => setState(() => _strategy = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? _primaryFixed.withValues(alpha: 0.3)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _primary : _outline.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected ? _primary : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      if (!isSelected)
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                        ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? _primary : _outline,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _primary,
                            ),
                          ),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: _primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountInput(
    String label,
    IconData icon,
    int value,
    Function(int) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outline.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: _primary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 35,
            child: TextFormField(
              initialValue: value.toString(),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _primary,
                fontSize: 13,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) {
                if (val.isNotEmpty) onChanged(int.parse(val));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.tune,
          title: 'Cấu hình & Hiển thị',
          subtitle: 'Tùy chỉnh trải nghiệm của thí sinh khi làm bài.',
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _outline.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              _buildConfigToggle(
                title: 'Xáo trộn câu hỏi',
                desc: 'Thứ tự câu hỏi thay đổi ngẫu nhiên.',
                icon: Icons.shuffle,
                value: _shuffleQuestions,
                onChanged: (v) => setState(() => _shuffleQuestions = v),
              ),
              const Divider(height: 1),
              _buildConfigToggle(
                title: 'Xáo trộn phương án',
                desc: 'Các đáp án A, B, C, D sẽ được hoán đổi.',
                icon: Icons.low_priority,
                value: _shuffleOptions,
                onChanged: (v) => setState(() => _shuffleOptions = v),
              ),
              const Divider(height: 1),
              _buildConfigToggle(
                title: 'Công khai đề thi',
                desc: 'Cho phép thí sinh tìm thấy và làm bài ngay.',
                icon: Icons.public,
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConfigToggle({
    required String title,
    required String desc,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.shuffle,
              color: Color(0xFF004D40),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeColor: _primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool isRequired = false,
    bool isNumber = false,
    int maxLines = 1,
    String? suffixText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            children: isRequired
                ? const [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(color: Colors.red),
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          maxLines: maxLines,
          validator: isRequired
              ? (value) => value == null || value.isEmpty
                    ? 'Vui lòng nhập thông tin này'
                    : null
              : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: _bgLight,
            suffixText: suffixText,
            suffixStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _outline.withValues(alpha: 0.5)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _outline.withValues(alpha: 0.5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _outline.withValues(alpha: 0.3))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _handleNextStep(saveAsDraft: true),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: _outline, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Lưu bản nháp',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _handleNextStep(saveAsDraft: false),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: _primary.withValues(alpha: 0.5),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Tiếp: Soạn câu hỏi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
