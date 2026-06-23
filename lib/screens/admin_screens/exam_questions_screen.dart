import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ExamQuestionsScreen extends StatefulWidget {
  final Map<String, dynamic> examData;
  final Map<String, int> config;

  const ExamQuestionsScreen({
    super.key,
    required this.examData,
    required this.config,
  });

  @override
  State<ExamQuestionsScreen> createState() => _ExamQuestionsScreenState();
}

class _ExamQuestionsScreenState extends State<ExamQuestionsScreen> {
  final Color _primary = const Color(0xFF002045);
  final Color _bgLight = const Color(0xFFF8F9FF);

  List<DocumentSnapshot> _selectedQuestions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // LOGIC THÔNG MINH CHO TÍNH NĂNG SỬA:
    if (widget.examData['examId'] != null &&
        widget.examData['questions'] != null) {
      // 1. Đang Sửa đề thi -> Tải câu hỏi cũ lên
      _loadExistingQuestions(List<String>.from(widget.examData['questions']));
    } else if (widget.examData['strategy'] == 'random') {
      // 2. Tạo đề mới (Random) -> Bốc ngẫu nhiên
      _generateRandomQuestions();
    }
  }

  // --- TẢI LẠI CÂU HỎI TỪ DATABASE KHI SỬA ĐỀ ---
  Future<void> _loadExistingQuestions(List<String> questionIds) async {
    setState(() => _isLoading = true);
    try {
      List<DocumentSnapshot> docs = [];
      // Firebase whereIn bị giới hạn 30 item/lần, nên ta duyệt lấy lẻ từng câu
      for (String id in questionIds) {
        var doc = await FirebaseFirestore.instance
            .collection('Questions')
            .doc(id)
            .get();
        if (doc.exists) docs.add(doc);
      }
      setState(() {
        _selectedQuestions = docs;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải câu hỏi: $e')));
      setState(() => _isLoading = false);
    }
  }

  // --- NGHIỆP VỤ BỐC NGẪU NHIÊN BẢO TOÀN CỤM ---
  Future<void> _generateRandomQuestions() async {
    setState(() => _isLoading = true);
    try {
      List<DocumentSnapshot> allFetched = [];
      Map<String, Map<String, String>> dbMapping = {
        'Tiếng Việt': {'phanThi': 'Sử dụng ngôn ngữ', 'chuDe': 'Tiếng Việt'},
        'Tiếng Anh': {'phanThi': 'Sử dụng ngôn ngữ', 'chuDe': 'Tiếng Anh'},
        'Toán học': {'phanThi': 'Toán học', 'chuDe': ''},
        'Logic': {'phanThi': 'Tư duy khoa học', 'chuDe': 'Logic'},
        'Suy luận': {'phanThi': 'Tư duy khoa học', 'chuDe': 'Suy luận'},
      };

      for (var entry in widget.config.entries) {
        int requiredCount = entry.value;
        if (requiredCount <= 0) continue;

        var mapping = dbMapping[entry.key];
        if (mapping == null) continue;

        Query query = FirebaseFirestore.instance
            .collection('Questions')
            .where('phanThi', isEqualTo: mapping['phanThi']);
        if (mapping['chuDe']!.isNotEmpty)
          query = query.where('chuDe', isEqualTo: mapping['chuDe']);

        var snap = await query.get();
        var docs = snap.docs;
        if (docs.isEmpty) continue;

        Map<String, List<DocumentSnapshot>> grouped = {};
        List<DocumentSnapshot> singles = [];

        for (var doc in docs) {
          var data = doc.data() as Map<String, dynamic>;
          String maNhom = data['maNhom']?.toString().trim() ?? '';
          if (maNhom.isNotEmpty)
            grouped.putIfAbsent(maNhom, () => []).add(doc);
          else
            singles.add(doc);
        }

        List<List<DocumentSnapshot>> allBlocks = [];
        allBlocks.addAll(grouped.values);
        allBlocks.addAll(singles.map((e) => [e]));

        allBlocks.shuffle();

        int currentCount = 0;
        List<DocumentSnapshot> categoryDocs = [];

        for (var block in allBlocks) {
          if (currentCount + block.length <= requiredCount) {
            categoryDocs.addAll(block);
            currentCount += block.length;
          }
          if (currentCount == requiredCount) break;
        }
        allFetched.addAll(categoryDocs);
      }

      setState(() {
        _selectedQuestions = allFetched;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi random: $e')));
      setState(() => _isLoading = false);
    }
  }

  void _openQuestionSelector() async {
    final List<DocumentSnapshot>? result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          QuestionSelectorDialog(alreadySelected: _selectedQuestions),
    );
    if (result != null) setState(() => _selectedQuestions = result);
  }

  // --- LƯU CHÍNH THỨC (CREATE / UPDATE) VÀ GÁN MÃ ĐỀ ---
  Future<void> _saveExam() async {
    if (_selectedQuestions.length < 120) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Bắt buộc chọn đủ 120 câu (Hiện có: ${_selectedQuestions.length})',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    List<String> questionIds = _selectedQuestions.map((d) => d.id).toList();

    Map<String, dynamic> finalData = {
      'tenDeThi': widget.examData['tenDeThi'],
      'thoiGian': widget.examData['thoiGian'],
      'maDe': widget.examData['maDe'],
      'moTa': widget.examData['moTa'],
      'strategy': widget.examData['strategy'],
      'shuffleQuestions': widget.examData['shuffleQuestions'],
      'shuffleOptions': widget.examData['shuffleOptions'],
      'isPublic': widget.examData['isPublic'],

      'questions': questionIds,
      'soCauHoi': questionIds.length,
      'config': widget.config,
      'luotLamBai': widget.examData['luotLamBai'],
      'dangLamBai': widget.examData['dangLamBai'],
    };

    try {
      String currentExamId; // Biến lưu mã đề thi

      if (widget.examData['examId'] != null) {
        // CẬP NHẬT ĐỀ THI (Lấy mã đề cũ)
        currentExamId = widget.examData['examId'];
        await FirebaseFirestore.instance
            .collection('Exams')
            .doc(currentExamId)
            .update(finalData);
      } else {
        // TẠO MỚI ĐỀ THI (Lấy mã đề tự sinh từ Firebase)
        finalData['createdAt'] = FieldValue.serverTimestamp();
        DocumentReference newExamRef = await FirebaseFirestore.instance
            .collection('Exams')
            .add(finalData);
        currentExamId = newExamRef.id;
      }

      // --- ĐOẠN MỚI NÂNG CẤP: DÙNG BATCH ĐỂ GÁN MÃ ĐỀ VÀO CÂU HỎI ---
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (String qId in questionIds) {
        DocumentReference qRef = FirebaseFirestore.instance
            .collection('Questions')
            .doc(qId);
        // Cập nhật thêm trường 'maDeThi' cho từng câu hỏi
        batch.update(qRef, {'maDeThi': currentExamId});
      }
      await batch.commit(); // Thực thi đồng loạt

      // Thông báo thành công
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.examData['examId'] != null
                  ? 'Đã cập nhật đề thi thành công!'
                  : 'Tạo đề thi mới thành công!',
            ),
          ),
        );
      }

      if (mounted) {
        // Lùi chính xác 2 bước (Từ Màn hình soạn -> Tạo đề -> Danh sách đề)
        int count = 0;
        Navigator.popUntil(context, (route) {
          return count++ == 2;
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi lưu đề: $e')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isManual = widget.examData['strategy'] == 'manual';
    bool isEditing = widget.examData['examId'] != null;

    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: const Text(
          'Soạn câu hỏi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatsBar(),
                Expanded(
                  child: _selectedQuestions.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _selectedQuestions.length,
                          itemBuilder: (context, index) =>
                              _buildQuestionItem(index),
                        ),
                ),
                _buildBottomAction(isManual, isEditing),
              ],
            ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn(
            'ĐÃ CHỌN',
            '${_selectedQuestions.length}/120',
            _primary,
          ),
          _buildStatColumn('TỔNG ĐIỂM', '1200', Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.quiz_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Chưa có câu hỏi nào',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionItem(int index) {
    var data = _selectedQuestions[index].data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _bgLight,
          child: Text(
            '${index + 1}',
            style: TextStyle(color: _primary, fontSize: 12),
          ),
        ),
        title: Text(
          data['noiDungCauHoi'] ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          data['phanThi'] ?? '',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
          onPressed: () => setState(() => _selectedQuestions.removeAt(index)),
        ),
      ),
    );
  }

  Widget _buildBottomAction(bool isManual, bool isEditing) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (isManual)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openQuestionSelector,
                icon: const Icon(Icons.add_to_photos),
                label: const Text('Thêm từ kho'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

          // HIỂN THỊ NÚT RE-RANDOM NẾU ĐANG SỬA ĐỀ NGẪU NHIÊN
          if (!isManual && isEditing)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _generateRandomQuestions(),
                icon: const Icon(Icons.refresh),
                label: const Text('Bốc lại ngẫu nhiên'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: Colors.orange.shade800,
                  side: BorderSide(color: Colors.orange.shade200),
                ),
              ),
            ),

          if (isManual || isEditing) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _saveExam,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                isEditing ? 'CẬP NHẬT ĐỀ THI' : 'HOÀN TẤT TẠO ĐỀ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// BẢNG CHỌN TỪ NGÂN HÀNG (GIỮ NGUYÊN)
class QuestionSelectorDialog extends StatefulWidget {
  final List<DocumentSnapshot> alreadySelected;
  const QuestionSelectorDialog({super.key, required this.alreadySelected});

  @override
  State<QuestionSelectorDialog> createState() => _QuestionSelectorDialogState();
}

class _QuestionSelectorDialogState extends State<QuestionSelectorDialog> {
  List<String> _tempSelectedIds = [];
  List<DocumentSnapshot> _allDocs = [];
  String _filterPhanThi = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _tempSelectedIds = widget.alreadySelected.map((e) => e.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ngân hàng câu hỏi (${_tempSelectedIds.length}/120)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children:
                  ['Tất cả', 'Sử dụng ngôn ngữ', 'Toán học', 'Tư duy khoa học']
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(e),
                            selected: _filterPhanThi == e,
                            onSelected: (val) =>
                                setState(() => _filterPhanThi = e),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Questions')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                var docs = snapshot.data!.docs;
                if (_filterPhanThi != 'Tất cả')
                  docs = docs
                      .where(
                        (d) => (d.data() as Map)['phanThi'] == _filterPhanThi,
                      )
                      .toList();
                _allDocs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    bool isSelected = _tempSelectedIds.contains(docs[index].id);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(
                        data['noiDungCauHoi'] ?? '',
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        '${data['phanThi']} - ${data['doKho']}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      onChanged: (val) {
                        setState(() {
                          if (val!)
                            _tempSelectedIds.add(docs[index].id);
                          else
                            _tempSelectedIds.remove(docs[index].id);
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: () {
                var result = _allDocs
                    .where((d) => _tempSelectedIds.contains(d.id))
                    .toList();
                Navigator.pop(context, result);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF002045),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('XÁC NHẬN CHỌN'),
            ),
          ),
        ],
      ),
    );
  }
}
