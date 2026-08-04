import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

String _normalizeQuestionDisplayText(String text) {
  final parts = text.split(r'$');
  for (int i = 0; i < parts.length; i += 2) {
    var plainText = parts[i]
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('\uF0CE', '∈')
        .replaceAll('\uF02D', '−')
        .replaceAll('\uF03D', '=')
        .replaceAll('\uF0C6', '∅')
        .replaceAll(r'\_', '_')
        .replaceAll(r'\%', '%')
        .replaceAll(r'\#', '#')
        .replaceAll(r'\&', '&');
    plainText = plainText.replaceAllMapped(
      RegExp(r'<sup>\s*0\s*</sup>\s*(\d+(?:[.,]\d+)?)', caseSensitive: false),
      (match) => '${match.group(1)}°',
    );
    parts[i] = plainText;
  }
  return parts.join(r'$');
}

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
    if (widget.examData['examId'] != null &&
        widget.examData['questions'] != null) {
      _loadExistingQuestions(List<String>.from(widget.examData['questions']));
    } else if (widget.examData['strategy'] == 'random') {
      _generateRandomQuestions();
    }
  }

  Future<void> _loadExistingQuestions(List<String> questionIds) async {
    setState(() => _isLoading = true);
    try {
      List<DocumentSnapshot> docs = [];
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

  // --- NÂNG CẤP: BỐC NGẪU NHIÊN VÀ BÁO CÁO THIẾU CÂU HỎI ---
  Future<void> _generateRandomQuestions() async {
    setState(() => _isLoading = true);
    try {
      List<DocumentSnapshot> allFetched = [];
      List<String> shortageMessages = []; // Danh sách lưu các lỗi thiếu câu
      String currentExamId = widget.examData['examId'] ?? '';

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
        if (mapping['chuDe']!.isNotEmpty) {
          query = query.where('chuDe', isEqualTo: mapping['chuDe']);
        }

        var snap = await query.get();

        // 1. CHỈ LẤY CÂU HỎI CHƯA CÓ CHỦ HOẶC ĐANG THUỘC VỀ ĐỀ NÀY
        var availableDocs = snap.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String assignedTo = data['maDeThi'] ?? '';
          return assignedTo.isEmpty || assignedTo == currentExamId;
        }).toList();

        if (availableDocs.isEmpty) {
          shortageMessages.add(
            '• ${entry.key}: Thiếu $requiredCount câu (Không có câu nào trống)',
          );
          continue;
        }

        Map<String, List<DocumentSnapshot>> grouped = {};
        List<DocumentSnapshot> singles = [];

        for (var doc in availableDocs) {
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

        // THUẬT TOÁN: ưu tiên ghép các block vừa khít trước (giữ nguyên cụm).
        // Nếu ghép xong vẫn chưa đủ, lấy tiếp từ các block còn lại; nếu block
        // đó lớn hơn số còn thiếu thì CẮT BỚT đúng bằng số còn thiếu (chấp
        // nhận tách cụm ở bước cuối) để tổng luôn khớp CHÍNH XÁC requiredCount.
        int currentCount = 0;
        List<DocumentSnapshot> categoryDocs = [];
        List<List<DocumentSnapshot>> remainingBlocks = [];

        for (var block in allBlocks) {
          if (currentCount + block.length <= requiredCount) {
            categoryDocs.addAll(block);
            currentCount += block.length;
          } else {
            remainingBlocks.add(block);
          }
        }

        if (currentCount < requiredCount) {
          remainingBlocks.shuffle();
          for (var block in remainingBlocks) {
            if (currentCount >= requiredCount) break;
            int need = requiredCount - currentCount;
            if (block.length <= need) {
              categoryDocs.addAll(block);
              currentCount += block.length;
            } else {
              // Cắt bớt cụm để lấy đúng đủ số còn thiếu
              categoryDocs.addAll(block.sublist(0, need));
              currentCount += need;
            }
          }
        }

        // 2. NẾU ĐÃ LẤY HẾT TOÀN BỘ KHO RẢNH MÀ VẪN THIẾU -> GHI LỖI
        if (currentCount < requiredCount) {
          shortageMessages.add(
            '• ${entry.key}: Thiếu ${requiredCount - currentCount} câu (Chỉ có sẵn $currentCount câu)',
          );
        } else {
          allFetched.addAll(categoryDocs);
        }
      }

      // 3. NẾU CÓ BẤT KỲ LỖI THIẾU CÂU NÀO -> DỪNG VÀ BÁO CÁO ADMIN
      if (shortageMessages.isNotEmpty) {
        setState(() => _isLoading = false);
        _showShortageDialog(shortageMessages);
        return;
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

  void _showShortageDialog(List<String> messages) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text(
              'Ngân hàng thiếu câu hỏi',
              style: TextStyle(
                color: Colors.red,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hệ thống không đủ câu hỏi "chưa sử dụng" để tạo đề. Cụ thể:',
            ),
            const SizedBox(height: 12),
            ...messages.map(
              (msg) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  msg,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Vui lòng thêm câu hỏi mới vào Ngân hàng, hoặc giảm số lượng cấu hình của các mục trên!',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primary),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Quay về trang thiết lập
            },
            child: const Text(
              'Quay lại Cấu hình',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _openQuestionSelector() async {
    final List<DocumentSnapshot>? result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuestionSelectorDialog(
        alreadySelected: _selectedQuestions,
        currentExamId:
            widget.examData['examId'] ?? '', // TRUYỀN ID CỦA ĐỀ ĐANG SỬA
      ),
    );
    if (result != null) setState(() => _selectedQuestions = result);
  }

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

    List<String> newQuestionIds = _selectedQuestions.map((d) => d.id).toList();

    // NÂNG CẤP: TÌM NHỮNG CÂU HỎI BỊ ADMIN BỎ TICK (LOẠI KHỎI ĐỀ) ĐỂ XÓA MÃ ĐỀ
    List<String> oldQuestionIds = widget.examData['questions'] != null
        ? List<String>.from(widget.examData['questions'])
        : [];
    List<String> removedQuestionIds = oldQuestionIds
        .where((id) => !newQuestionIds.contains(id))
        .toList();

    Map<String, dynamic> finalData = {
      'tenDeThi': widget.examData['tenDeThi'],
      'thoiGian': widget.examData['thoiGian'],
      'maDe': widget.examData['maDe'],
      'moTa': widget.examData['moTa'],
      'strategy': widget.examData['strategy'],
      'shuffleQuestions': widget.examData['shuffleQuestions'],
      'shuffleOptions': widget.examData['shuffleOptions'],
      'isPublic': widget.examData['isPublic'],
      'questions': newQuestionIds,
      'soCauHoi': newQuestionIds.length,
      'config': widget.config,
      'luotLamBai': widget.examData['luotLamBai'],
      'dangLamBai': widget.examData['dangLamBai'],
    };

    try {
      String currentExamId;

      if (widget.examData['examId'] != null) {
        currentExamId = widget.examData['examId'];
        await FirebaseFirestore.instance
            .collection('Exams')
            .doc(currentExamId)
            .update(finalData);
      } else {
        finalData['createdAt'] = FieldValue.serverTimestamp();
        DocumentReference newExamRef = await FirebaseFirestore.instance
            .collection('Exams')
            .add(finalData);
        currentExamId = newExamRef.id;
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Gán mã đề cho các câu hỏi đang chọn
      for (String qId in newQuestionIds) {
        DocumentReference qRef = FirebaseFirestore.instance
            .collection('Questions')
            .doc(qId);
        batch.update(qRef, {'maDeThi': currentExamId});
      }

      // 2. Giải phóng mã đề cho các câu hỏi bị bỏ ra ngoài
      for (String qId in removedQuestionIds) {
        DocumentReference qRef = FirebaseFirestore.instance
            .collection('Questions')
            .doc(qId);
        batch.update(qRef, {
          'maDeThi': '',
        }); // Xóa mã đề để đưa về Ngân hàng chung
      }

      await batch.commit();

      bool oldPublic =
          widget.examData['isPublic'] == true ||
          widget.examData['isPublic'] == 'true';
      bool newPublic =
          finalData['isPublic'] == true || finalData['isPublic'] == 'true';
      bool shouldNotify =
          (widget.examData['examId'] == null && newPublic) ||
          (!oldPublic && newPublic);

      if (shouldNotify) {
        await FirebaseFirestore.instance.collection('Notifications').add({
          'title': 'Đề thi mới: ${finalData['tenDeThi']}',
          'content':
              'Đề thi mới (${finalData['thoiGian']} phút) đã sẵn sàng. Hãy vào thi thử ngay!',
          'createdAt': FieldValue.serverTimestamp(),
          'type': 'new_exam',
          'examId': currentExamId,
          'readBy': [],
          'deletedBy': [],
        });
      }

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
        int count = 0;
        Navigator.popUntil(context, (route) => count++ == 2);
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
          _normalizeQuestionDisplayText(
            (data['noiDungCauHoi'] ?? '').toString(),
          ),
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

class QuestionSelectorDialog extends StatefulWidget {
  final List<DocumentSnapshot> alreadySelected;
  final String currentExamId; // NHẬN ID CỦA ĐỀ ĐANG SỬA

  const QuestionSelectorDialog({
    super.key,
    required this.alreadySelected,
    required this.currentExamId,
  });

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

                // NÂNG CẤP: LỌC BỎ NHỮNG CÂU ĐÃ THUỘC ĐỀ THI KHÁC
                var docs = snapshot.data!.docs.where((d) {
                  var data = d.data() as Map<String, dynamic>;
                  if (_filterPhanThi != 'Tất cả' &&
                      data['phanThi'] != _filterPhanThi)
                    return false;

                  String assignedTo = data['maDeThi'] ?? '';
                  return assignedTo.isEmpty ||
                      assignedTo == widget.currentExamId;
                }).toList();

                _allDocs = docs;

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Không còn câu hỏi trống nào ở phần này!',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    bool isSelected = _tempSelectedIds.contains(docs[index].id);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(
                        _normalizeQuestionDisplayText(
                          (data['noiDungCauHoi'] ?? '').toString(),
                        ),
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
