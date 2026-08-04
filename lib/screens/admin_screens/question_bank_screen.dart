import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_math_fork/flutter_math.dart';

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
      (match) => '\$${match.group(1)}^{\\circ}\$',
    );
    parts[i] = plainText;
  }
  return parts.join(r'$');
}

Future<String> _resolveQuestionImageUrl(String imageValue) async {
  final value = imageValue.trim();
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  if (value.startsWith('gs://')) {
    return FirebaseStorage.instance.refFromURL(value).getDownloadURL();
  }

  final rawName = value.startsWith('QuestionImages/')
      ? value.substring('QuestionImages/'.length)
      : value;
  final candidateNames = <String>{rawName};
  final hasImageExtension = RegExp(
    r'\.(png|jpe?g|webp|gif)$',
    caseSensitive: false,
  ).hasMatch(rawName);

  if (!hasImageExtension) {
    candidateNames.addAll(['$rawName.png', '$rawName.jpg', '$rawName.jpeg']);
    final underscoreName = rawName.replaceAllMapped(
      RegExp(r'(\d)\.(\d)'),
      (match) => '${match.group(1)}_${match.group(2)}',
    );
    final dashName = rawName.replaceAllMapped(
      RegExp(r'(\d)\.(\d)'),
      (match) => '${match.group(1)}-${match.group(2)}',
    );
    candidateNames.addAll(['$underscoreName.png', '$dashName.png']);
  }

  Object? lastError;
  for (final candidate in candidateNames) {
    try {
      return await FirebaseStorage.instance
          .ref('QuestionImages/$candidate')
          .getDownloadURL();
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError ?? StateError('Tên ảnh không hợp lệ: $imageValue');
}

class QuestionBankScreen extends StatefulWidget {
  const QuestionBankScreen({super.key});

  @override
  State<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends State<QuestionBankScreen> {
  final Color _primaryDark = const Color(0xFF1A237E);
  final Color _bgLight = const Color(0xFFF8F9FA);

  // --- BIẾN TRẠNG THÁI LỌC DỮ LIỆU ---
  String _searchText = '';
  String _selectedPhanThi = 'Tất cả';
  String _selectedChuDe = 'Tất cả';
  String _selectedDoKho = 'Tất cả'; // MỚI: Biến lưu trữ độ khó đang lọc

  // --- BIẾN CHỨC NĂNG CHỌN NHIỀU ---
  bool _isSelectionMode = false;
  final Set<String> _selectedDocIds = {};

  final Map<String, List<String>> _filterMap = {
    'Tất cả': ['Tất cả'],
    'Sử dụng ngôn ngữ': ['Tất cả', 'Tiếng Việt', 'Tiếng Anh'],
    'Toán học': ['Tất cả'],
    'Tư duy khoa học': ['Tất cả', 'Logic', 'Suy luận'],
  };

  // MỚI: Danh sách các mức độ khó để hiển thị ở Dropdown
  final List<String> _doKhoList = ['Tất cả', 'Dễ', 'Trung bình', 'Khó'];

  void _onFilterChanged() {
    setState(() {
      _selectedDocIds.clear();
      _isSelectionMode = false;
    });
  }

  List<String> _getExamIds(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final value = data['maDeThi'];

    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final examId = value?.toString().trim() ?? '';
    return examId.isEmpty ? const [] : [examId];
  }

  String _getExamCode(DocumentSnapshot doc) {
    return _getExamIds(doc).join(', ');
  }

  List<DocumentSnapshot> _getQuestionsLinkedToExam(
    Iterable<DocumentSnapshot> docs,
  ) {
    return docs.where((doc) => _getExamCode(doc).isNotEmpty).toList();
  }

  Future<List<DocumentSnapshot>> _loadQuestionDocsByIds(
    Iterable<String> docIds,
  ) async {
    final ids = docIds.toList();
    final result = <DocumentSnapshot>[];

    // Firestore giới hạn số phần tử của whereIn, nên chia nhỏ để hỗ trợ
    // trường hợp quản trị viên chọn nhiều câu hỏi cùng lúc.
    const chunkSize = 10;
    for (int i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.skip(i).take(chunkSize).toList();
      final snapshot = await FirebaseFirestore.instance
          .collection('Questions')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      result.addAll(snapshot.docs);
    }

    return result;
  }

  Future<List<String>> _loadExamNames(Iterable<String> examIds) async {
    final ids = examIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const [];

    final namesById = <String, String>{};

    try {
      // Firestore không tự JOIN Questions với Exams. Tải danh sách đề rồi tự
      // đối chiếu maDeThi với cả document ID và trường maDe. Việc chuyển tất
      // cả về String giúp dữ liệu "3" và số 3 vẫn khớp nhau.
      final examsSnapshot = await FirebaseFirestore.instance
          .collection('Exams')
          .get();

      for (final doc in examsSnapshot.docs) {
        final data = doc.data();
        final examName = (data['tenDeThi'] ?? data['title'])?.toString().trim();
        if (examName == null || examName.isEmpty) continue;

        namesById[doc.id.trim()] = examName;

        final examCode = data['maDe']?.toString().trim() ?? '';
        if (examCode.isNotEmpty) {
          namesById[examCode] = examName;
        }

        final examId = data['examId']?.toString().trim() ?? '';
        if (examId.isNotEmpty) {
          namesById[examId] = examName;
        }
      }
    } catch (_) {
      // Nếu không tải được Exams, vẫn giữ nguyên việc chặn xóa và dùng mã
      // làm thông tin dự phòng thay vì cho phép xóa nhầm câu hỏi.
    }

    return ids.map((id) => namesById[id] ?? 'Đề thi $id').toSet().toList();
  }

  Future<void> _showCannotDeleteDialog(
    List<DocumentSnapshot> linkedDocs,
  ) async {
    final examIds = linkedDocs.expand(_getExamIds).toSet();
    final examNames = await _loadExamNames(examIds);
    if (!mounted) return;
    final displayedExamNames = examNames.join(', ');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange),
            SizedBox(width: 10),
            Expanded(child: Text('Không thể xóa câu hỏi')),
          ],
        ),
        content: Text(
          linkedDocs.length == 1
              ? 'Câu hỏi này đang được sử dụng trong đề thi: '
                    '$displayedExamNames. '
                    'Hãy gỡ câu hỏi khỏi đề thi trước khi xóa.'
              : 'Có ${linkedDocs.length} câu hỏi đang được sử dụng trong các '
                    'đề thi: $displayedExamNames. Hãy gỡ các câu hỏi khỏi đề '
                    'thi trước khi xóa.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  Future<bool> _canDeleteQuestions(List<DocumentSnapshot> docs) async {
    final linkedDocs = _getQuestionsLinkedToExam(docs);
    if (linkedDocs.isEmpty) return true;

    await _showCannotDeleteDialog(linkedDocs);
    return false;
  }

  Future<void> _executeBatchDelete(List<DocumentSnapshot> docsToProcess) async {
    int chunkSize = 400;
    for (int i = 0; i < docsToProcess.length; i += chunkSize) {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      var chunk = docsToProcess.skip(i).take(chunkSize);
      for (var doc in chunk) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteSelectedItems() async {
    if (_selectedDocIds.isEmpty) return;

    try {
      final selectedDocs = await _loadQuestionDocsByIds(_selectedDocIds);
      if (!mounted || !await _canDeleteQuestions(selectedDocs)) return;

      bool confirm = await _showConfirmDialog(
        'Xóa nhiều câu hỏi',
        'Bạn có chắc chắn muốn xóa ${_selectedDocIds.length} câu hỏi đã đánh dấu?',
      );

      if (confirm) {
        _showLoadingSnackBar(
          'Đang tiến hành xóa ${_selectedDocIds.length} câu hỏi...',
        );
        await _executeBatchDelete(selectedDocs);
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Đã xóa thành công!')));
          setState(() {
            _isSelectionMode = false;
            _selectedDocIds.clear();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi kiểm tra câu hỏi: $e')));
      }
    }
  }

  Future<void> _editGroupContent(
    String maNhom,
    String currentContent,
    String currentImage,
  ) async {
    TextEditingController contentCtrl = TextEditingController(
      text: currentContent,
    );
    TextEditingController imageCtrl = TextEditingController(text: currentImage);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa nội dung chung của cụm'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: contentCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Nội dung đoạn văn',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: imageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên file ảnh chung',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              var batch = FirebaseFirestore.instance.batch();
              var docs = await FirebaseFirestore.instance
                  .collection('Questions')
                  .where('maNhom', isEqualTo: maNhom)
                  .get();

              for (var doc in docs.docs) {
                batch.update(doc.reference, {
                  'noiDungChung': contentCtrl.text.trim(),
                  'anhChung': imageCtrl.text.trim(),
                });
              }
              await batch.commit();
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã cập nhật toàn bộ cụm!')),
                );
              }
            },
            child: const Text('Lưu thay đổi'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllFiltered(List<DocumentSnapshot> filteredDocs) async {
    if (filteredDocs.isEmpty) return;

    if (!await _canDeleteQuestions(filteredDocs)) return;

    String warningFilter = 'TOÀN BỘ ${filteredDocs.length} câu hỏi';
    if (_selectedPhanThi != 'Tất cả')
      warningFilter += ' thuộc $_selectedPhanThi';
    if (_selectedChuDe != 'Tất cả') warningFilter += ' - $_selectedChuDe';
    if (_selectedDoKho != 'Tất cả')
      warningFilter += ' (Độ khó: $_selectedDoKho)';

    bool confirm = await _showConfirmDialog(
      'CẢNH BÁO: XÓA TOÀN BỘ MỤC NÀY',
      'Bạn sắp XÓA VĨNH VIỄN $warningFilter đang hiển thị trên màn hình.\n\nHành động này sẽ xóa luôn cả các nội dung chung của chúng và KHÔNG THỂ HOÀN TÁC. Bạn có chắc chắn không?',
    );

    if (confirm) {
      _showLoadingSnackBar(
        'Đang xóa $warningFilter. Vui lòng không đóng ứng dụng...',
      );
      try {
        await _executeBatchDelete(filteredDocs);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã dọn dẹp toàn bộ dữ liệu thành công!'),
            ),
          );
          setState(() {
            _isSelectionMode = false;
            _selectedDocIds.clear();
          });
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _deleteSingleOrGroup(List<DocumentSnapshot> docs) async {
    if (!await _canDeleteQuestions(docs)) return;

    String title = docs.length == 1 ? 'Xóa câu hỏi' : 'Xóa cụm câu hỏi';
    String content = docs.length == 1
        ? 'Bạn có chắc chắn muốn xóa câu hỏi này?'
        : 'Bạn có muốn xóa CỤM ${docs.length} CÂU HỎI cùng nội dung chung này?';

    bool confirm = await _showConfirmDialog(title, content);
    if (confirm) {
      try {
        await _executeBatchDelete(docs);
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Đã xóa dữ liệu!')));
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Xóa', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showLoadingSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(text)),
          ],
        ),
        duration: const Duration(days: 1),
      ),
    );
  }

  void _openQuestionForm({DocumentSnapshot? doc}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuestionFormScreen(questionDoc: doc),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Questions')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        List<DocumentSnapshot> filteredDocs = [];

        if (snapshot.hasData) {
          filteredDocs = snapshot.data!.docs.where((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            String qText =
                data['noiDungCauHoi']?.toString().toLowerCase() ?? '';
            String pThi = data['phanThi']?.toString() ?? '';
            String cDe = data['chuDe']?.toString() ?? '';
            String nDungChung =
                data['noiDungChung']?.toString().toLowerCase() ?? '';
            String dKho = data['doKho']?.toString() ?? ''; // MỚI: Đọc độ khó

            if (_searchText.isNotEmpty &&
                !qText.contains(_searchText.toLowerCase()) &&
                !nDungChung.contains(_searchText.toLowerCase()))
              return false;
            if (_selectedPhanThi != 'Tất cả' &&
                !pThi.toLowerCase().contains(_selectedPhanThi.toLowerCase()))
              return false;
            if (_selectedChuDe != 'Tất cả' &&
                !cDe.toLowerCase().contains(_selectedChuDe.toLowerCase()))
              return false;

            // MỚI: Lọc theo độ khó
            if (_selectedDoKho != 'Tất cả' && dKho != _selectedDoKho)
              return false;

            return true;
          }).toList();
        }

        return Scaffold(
          backgroundColor: _bgLight,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Ngân hàng câu hỏi',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              if (filteredDocs.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = !_isSelectionMode;
                      if (!_isSelectionMode) _selectedDocIds.clear();
                    });
                  },
                  child: Text(
                    _isSelectionMode ? 'Hủy chọn' : 'Chọn nhiều',
                    style: TextStyle(
                      color: _isSelectionMode ? Colors.red : _primaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),

          floatingActionButton: !_isSelectionMode
              ? FloatingActionButton.extended(
                  backgroundColor: _primaryDark,
                  foregroundColor: Colors.white,
                  onPressed: () => _openQuestionForm(),
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Thêm câu hỏi',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                )
              : null,

          bottomNavigationBar: _isSelectionMode
              ? _buildSelectionBottomBar(filteredDocs)
              : null,

          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (value) {
                        _searchText = value;
                        _onFilterChanged();
                      },
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm nội dung câu hỏi...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown(
                            value: _selectedPhanThi,
                            items: _filterMap.keys.toList(),
                            onChanged: (v) {
                              _selectedPhanThi = v!;
                              _selectedChuDe = 'Tất cả';
                              _onFilterChanged();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDropdown(
                            value: _selectedChuDe,
                            items: _filterMap[_selectedPhanThi]!,
                            onChanged: (v) {
                              _selectedChuDe = v!;
                              _onFilterChanged();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // MỚI: Thêm hàng lọc theo Độ Khó
                    Row(
                      children: [
                        const Text(
                          'Độ khó:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDropdown(
                            value: _selectedDoKho,
                            items: _doKhoList,
                            onChanged: (v) {
                              _selectedDoKho = v!;
                              _onFilterChanged();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : snapshot.hasError
                    ? const Center(
                        child: Text('Đã xảy ra lỗi khi tải dữ liệu.'),
                      )
                    : filteredDocs.isEmpty
                    ? Center(
                        child: Text(
                          'Không có câu hỏi nào phù hợp.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : _buildDataList(filteredDocs),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // HÀM VẼ TOÁN HỌC - TỰ ĐỘNG SỬA LỖI GẠCH NGANG & BÁO LỖI ĐỎ KHI SAI CÚ PHÁP
  // =========================================================================
  Widget _buildMathText(String text, {TextStyle? style}) {
    text = _normalizeQuestionDisplayText(text);
    if (!text.contains('\$')) {
      return Text(text, style: style);
    }

    List<String> parts = text.split('\$');
    List<Widget> children = [];

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 0) {
        if (parts[i].isNotEmpty) {
          children.add(Text(parts[i], style: style));
        }
      } else {
        String mathCode = parts[i].trim();
        if (mathCode.isEmpty) continue;

        // Tự động sửa lỗi dấu gạch ngang từ PDF thành dấu trừ chuẩn
        mathCode = mathCode.replaceAll('–', '-').replaceAll('—', '-');

        children.add(
          Math.tex(
            mathCode,
            textStyle: style,
            mathStyle: MathStyle.text,
            onErrorFallback: (FlutterMathException e) {
              return Text(
                ' [LỖI TOÁN HỌC: ${e.message}] ',
                style: style?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        );
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }

  Widget _buildSelectionBottomBar(List<DocumentSnapshot> filteredDocs) {
    bool hasSelection = _selectedDocIds.isNotEmpty;
    bool isAllSelected = _selectedDocIds.length == filteredDocs.length;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        if (isAllSelected) {
                          _selectedDocIds.clear();
                        } else {
                          _selectedDocIds.addAll(filteredDocs.map((d) => d.id));
                        }
                      });
                    },
                    child: Text(
                      isAllSelected
                          ? 'Bỏ chọn tất cả'
                          : 'Chọn toàn bộ ${filteredDocs.length} câu',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasSelection
                          ? Colors.red
                          : Colors.grey.shade300,
                      foregroundColor: hasSelection
                          ? Colors.white
                          : Colors.grey.shade600,
                      elevation: 0,
                    ),
                    onPressed: hasSelection ? _deleteSelectedItems : null,
                    icon: const Icon(Icons.delete, size: 18),
                    label: Text(
                      'Xóa ${_selectedDocIds.length} mục',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade900,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _deleteAllFiltered(filteredDocs),
                icon: const Icon(Icons.warning_amber_rounded),
                label: Text(
                  'Xóa sạch TOÀN BỘ ${filteredDocs.length} câu đang lọc',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataList(List<DocumentSnapshot> filteredDocs) {
    List<Map<String, dynamic>> displayItems = [];
    Set<String> seenGroups = {};
    int questionCounter = 1;

    for (var doc in filteredDocs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String maNhom = data['maNhom']?.toString().trim() ?? '';
      String noiDungChung = data['noiDungChung']?.toString().trim() ?? '';
      String groupId = maNhom.isNotEmpty
          ? maNhom
          : (noiDungChung.isNotEmpty ? noiDungChung : '');

      if (groupId.isNotEmpty) {
        if (!seenGroups.contains(groupId)) {
          seenGroups.add(groupId);
          var groupDocs = filteredDocs.where((d) {
            var dData = d.data() as Map<String, dynamic>;
            String dMaNhom = dData['maNhom']?.toString().trim() ?? '';
            String dNoiDungChung =
                dData['noiDungChung']?.toString().trim() ?? '';
            String dGroupId = dMaNhom.isNotEmpty
                ? dMaNhom
                : (dNoiDungChung.isNotEmpty ? dNoiDungChung : '');
            return dGroupId == groupId;
          }).toList();

          displayItems.add({
            'type': 'group',
            'docs': groupDocs,
            'startIndex': questionCounter,
          });
          questionCounter += groupDocs.length;
        }
      } else {
        displayItems.add({
          'type': 'single',
          'doc': doc,
          'startIndex': questionCounter,
        });
        questionCounter++;
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: displayItems.length,
      itemBuilder: (context, index) {
        var item = displayItems[index];
        if (item['type'] == 'group') {
          return _buildGroupCard(item['docs'], item['startIndex']);
        } else {
          return _buildSingleQuestionCard(item['doc'], item['startIndex']);
        }
      },
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          style: const TextStyle(color: Colors.black87, fontSize: 14),
          onChanged: onChanged,
          items: items
              .map<DropdownMenuItem<String>>(
                (String item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildGroupCard(List<DocumentSnapshot> docs, int startIndex) {
    Map<String, dynamic> firstData = docs.first.data() as Map<String, dynamic>;
    String phanThi = firstData['phanThi'] ?? 'Chưa phân loại';
    String chuDe = firstData['chuDe'] ?? '';
    String noiDungChung = firstData['noiDungChung'] ?? '';
    String anhChung = firstData['anhChung'] ?? '';

    bool isGroupSelected = docs.every((d) => _selectedDocIds.contains(d.id));

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isGroupSelected ? Colors.blue.shade50 : const Color(0xFFF0F4FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGroupSelected ? _primaryDark : Colors.blue.shade200,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_isSelectionMode)
                      Checkbox(
                        value: isGroupSelected,
                        activeColor: _primaryDark,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedDocIds.addAll(docs.map((d) => d.id));
                            } else {
                              _selectedDocIds.removeAll(docs.map((d) => d.id));
                            }
                          });
                        },
                      ),
                    const Icon(
                      Icons.library_books,
                      color: Color(0xFF1A237E),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'CỤM CÂU HỎI CHUNG',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A237E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.blue,
                        size: 20,
                      ),
                      onPressed: () => _editGroupContent(
                        firstData['maNhom'],
                        noiDungChung,
                        anhChung,
                      ),
                    ),
                    if (!_isSelectionMode)
                      InkWell(
                        onTap: () => _deleteSingleOrGroup(docs),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.delete_forever,
                                size: 16,
                                color: Colors.red,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Xóa cụm',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTag(
                      phanThi,
                      Colors.blue.shade100,
                      Colors.blue.shade800,
                    ),
                    if (chuDe.isNotEmpty)
                      _buildTag(
                        chuDe,
                        Colors.purple.shade100,
                        Colors.purple.shade800,
                      ),
                  ],
                ),
              ],
            ),
          ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE3E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (noiDungChung.isNotEmpty)
                  _buildMathText(
                    noiDungChung,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade800,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                if (anhChung.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildImageFromStorage(anhChung),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: docs.asMap().entries.map((entry) {
                int index = entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildSubQuestionItem(entry.value, startIndex + index),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubQuestionItem(DocumentSnapshot doc, int displayIndex) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String doKho = data['doKho'] ?? 'N/A';
    String questionText = data['noiDungCauHoi'] ?? '';
    String anhCauHoi = data['anhCauHoi'] ?? '';
    String correctAnswer = data['correctAnswer'] ?? '';
    List<dynamic> options = data['options'] ?? [];

    bool isSelected = _selectedDocIds.contains(doc.id);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Checkbox(
                    value: isSelected,
                    activeColor: _primaryDark,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true)
                          _selectedDocIds.add(doc.id);
                        else
                          _selectedDocIds.remove(doc.id);
                      });
                    },
                  ),
                ),
              Expanded(
                child: _buildMathText(
                  'Câu $displayIndex: $questionText',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildTag(doKho, _getDifficultyColor(doKho), Colors.white),

              if (!_isSelectionMode) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _openQuestionForm(doc: doc),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (anhCauHoi.isNotEmpty) _buildImageFromStorage(anhCauHoi),
          if (options.isNotEmpty)
            ...List.generate(options.length, (i) {
              String optionLetter = String.fromCharCode(65 + i);
              bool isCorrect = optionLetter == correctAnswer;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isCorrect ? Colors.green.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCorrect
                        ? Colors.green.shade300
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '$optionLetter.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCorrect
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMathText(
                        options[i].toString(),
                        style: TextStyle(
                          color: isCorrect
                              ? Colors.green.shade800
                              : Colors.black87,
                        ),
                      ),
                    ),
                    if (isCorrect)
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 16,
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSingleQuestionCard(DocumentSnapshot doc, int displayIndex) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String phanThi = data['phanThi'] ?? 'Chưa phân loại';
    String chuDe = data['chuDe'] ?? '';
    String doKho = data['doKho'] ?? 'N/A';
    String questionText = data['noiDungCauHoi'] ?? '';
    String anhCauHoi = data['anhCauHoi'] ?? '';
    String correctAnswer = data['correctAnswer'] ?? '';
    List<dynamic> options = data['options'] ?? [];

    bool isSelected = _selectedDocIds.contains(doc.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? _primaryDark : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          if (!isSelected)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Checkbox(
                    value: isSelected,
                    activeColor: _primaryDark,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true)
                          _selectedDocIds.add(doc.id);
                        else
                          _selectedDocIds.remove(doc.id);
                      });
                    },
                  ),
                ),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildTag(
                      phanThi,
                      Colors.blue.shade100,
                      Colors.blue.shade800,
                    ),
                    if (chuDe.isNotEmpty)
                      _buildTag(
                        chuDe,
                        Colors.purple.shade100,
                        Colors.purple.shade800,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              if (!_isSelectionMode)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _openQuestionForm(doc: doc),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _deleteSingleOrGroup([doc]),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTag(doKho, _getDifficultyColor(doKho), Colors.white),
          const SizedBox(height: 16),
          _buildMathText(
            'Câu $displayIndex: $questionText',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (anhCauHoi.isNotEmpty) _buildImageFromStorage(anhCauHoi),
          if (options.isNotEmpty)
            ...List.generate(options.length, (i) {
              String optionLetter = String.fromCharCode(65 + i);
              bool isCorrect = optionLetter == correctAnswer;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isCorrect ? Colors.green.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCorrect
                        ? Colors.green.shade300
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '$optionLetter.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isCorrect
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMathText(
                        options[i].toString(),
                        style: TextStyle(
                          color: isCorrect
                              ? Colors.green.shade800
                              : Colors.black87,
                        ),
                      ),
                    ),
                    if (isCorrect)
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 20,
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildImageFromStorage(String imageName) {
    return FutureBuilder<String>(
      future: _resolveQuestionImageUrl(imageName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        if (snapshot.hasError)
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              '[Lỗi không tải được ảnh: $imageName]',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        if (snapshot.hasData)
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                snapshot.data!,
                width: double.infinity,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 150,
                    color: Colors.grey.shade100,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
            ),
          );
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildTag(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    if (difficulty.toLowerCase().contains('dễ')) return Colors.green.shade500;
    if (difficulty.toLowerCase().contains('khó')) return Colors.red.shade500;
    return Colors.orange.shade500;
  }
}

// =========================================================================
// WIDGET SCREEN MÀN HÌNH FORM THÊM / SỬA
// =========================================================================
class QuestionFormScreen extends StatefulWidget {
  final DocumentSnapshot? questionDoc;
  const QuestionFormScreen({super.key, this.questionDoc});
  @override
  State<QuestionFormScreen> createState() => _QuestionFormScreenState();
}

class _QuestionFormScreenState extends State<QuestionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final TextEditingController _maNhomCtrl = TextEditingController();
  final TextEditingController _noiDungChungCtrl = TextEditingController();
  final TextEditingController _anhChungCtrl = TextEditingController();
  final TextEditingController _noiDungCauHoiCtrl = TextEditingController();
  final TextEditingController _anhCauHoiCtrl = TextEditingController();
  final TextEditingController _ansACtrl = TextEditingController();
  final TextEditingController _ansBCtrl = TextEditingController();
  final TextEditingController _ansCCtrl = TextEditingController();
  final TextEditingController _ansDCtrl = TextEditingController();
  final TextEditingController _loiGiaiCtrl = TextEditingController();
  final TextEditingController _phanThiCtrl = TextEditingController();
  final TextEditingController _chuDeCtrl = TextEditingController();
  String _correctAnswer = 'A';
  String _doKho = 'Trung bình';

  @override
  void initState() {
    super.initState();
    if (widget.questionDoc != null) {
      Map<String, dynamic> data =
          widget.questionDoc!.data() as Map<String, dynamic>;
      _maNhomCtrl.text = data['maNhom'] ?? '';
      _noiDungChungCtrl.text = _normalizeQuestionDisplayText(
        (data['noiDungChung'] ?? '').toString(),
      );
      _anhChungCtrl.text = data['anhChung'] ?? '';
      _noiDungCauHoiCtrl.text = _normalizeQuestionDisplayText(
        (data['noiDungCauHoi'] ?? '').toString(),
      );
      _anhCauHoiCtrl.text = data['anhCauHoi'] ?? '';
      List<dynamic> options = data['options'] ?? ['', '', '', ''];
      if (options.isNotEmpty) {
        _ansACtrl.text = _normalizeQuestionDisplayText(options[0].toString());
      }
      if (options.length > 1) {
        _ansBCtrl.text = _normalizeQuestionDisplayText(options[1].toString());
      }
      if (options.length > 2) {
        _ansCCtrl.text = _normalizeQuestionDisplayText(options[2].toString());
      }
      if (options.length > 3) {
        _ansDCtrl.text = _normalizeQuestionDisplayText(options[3].toString());
      }
      _loiGiaiCtrl.text = _normalizeQuestionDisplayText(
        (data['loiGiai'] ?? '').toString(),
      );
      _phanThiCtrl.text = data['phanThi'] ?? '';
      _chuDeCtrl.text = data['chuDe'] ?? '';
      String ans = data['correctAnswer'] ?? 'A';
      if (['A', 'B', 'C', 'D'].contains(ans)) _correctAnswer = ans;
      String dk = data['doKho'] ?? 'Trung bình';
      if (['Dễ', 'Trung bình', 'Khó'].contains(dk)) _doKho = dk;
    }
  }

  @override
  void dispose() {
    _maNhomCtrl.dispose();
    _noiDungChungCtrl.dispose();
    _anhChungCtrl.dispose();
    _noiDungCauHoiCtrl.dispose();
    _anhCauHoiCtrl.dispose();
    _ansACtrl.dispose();
    _ansBCtrl.dispose();
    _ansCCtrl.dispose();
    _ansDCtrl.dispose();
    _loiGiaiCtrl.dispose();
    _phanThiCtrl.dispose();
    _chuDeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveQuestion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    Map<String, dynamic> questionData = {
      'maNhom': _maNhomCtrl.text.trim(),
      'noiDungChung': _normalizeQuestionDisplayText(
        _noiDungChungCtrl.text.trim(),
      ),
      'anhChung': _anhChungCtrl.text.trim(),
      'noiDungCauHoi': _normalizeQuestionDisplayText(
        _noiDungCauHoiCtrl.text.trim(),
      ),
      'anhCauHoi': _anhCauHoiCtrl.text.trim(),
      'options': [
        _normalizeQuestionDisplayText(_ansACtrl.text.trim()),
        _normalizeQuestionDisplayText(_ansBCtrl.text.trim()),
        _normalizeQuestionDisplayText(_ansCCtrl.text.trim()),
        _normalizeQuestionDisplayText(_ansDCtrl.text.trim()),
      ],
      'correctAnswer': _correctAnswer,
      'loiGiai': _normalizeQuestionDisplayText(_loiGiaiCtrl.text.trim()),
      'phanThi': _phanThiCtrl.text.trim(),
      'chuDe': _chuDeCtrl.text.trim(),
      'doKho': _doKho,
    };

    try {
      if (widget.questionDoc == null) {
        questionData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('Questions')
            .add(questionData);
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Đã thêm câu hỏi mới!')));
      } else {
        await widget.questionDoc!.reference.update(questionData);
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Cập nhật thành công!')));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.questionDoc != null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text(
          isEditing ? 'Sửa Câu Hỏi' : 'Thêm Câu Hỏi Mới',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveQuestion,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'LƯU',
                    style: TextStyle(
                      color: Color(0xFF1A237E),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionTitle('Phân loại & Cấu trúc'),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    'Phần thi',
                    _phanThiCtrl,
                    hint: 'VD: Toán học',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    'Chủ đề',
                    _chuDeCtrl,
                    hint: 'VD: Logic',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    'Mã Nhóm',
                    _maNhomCtrl,
                    hint: 'Tùy chọn',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _doKho,
                    decoration: const InputDecoration(
                      labelText: 'Độ khó',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Dễ', 'Trung bình', 'Khó']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => _doKho = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Nội dung chung (Dành cho câu hỏi chùm)'),
            _buildTextField(
              'Nội dung chung (Đoạn văn đọc hiểu)',
              _noiDungChungCtrl,
              maxLines: 3,
              hint: 'Để trống nếu không có',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'Tên file Ảnh Chung',
              _anhChungCtrl,
              hint: 'VD: doan_van_01.jpg',
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Chi tiết Câu hỏi (Bắt buộc)'),
            _buildTextField(
              'Nội dung Câu hỏi',
              _noiDungCauHoiCtrl,
              maxLines: 2,
              isRequired: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              'Tên file Ảnh Câu hỏi',
              _anhCauHoiCtrl,
              hint: 'VD: cau_hoi_01.jpg',
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Đáp án & Giải thích'),
            _buildTextField('Đáp án A', _ansACtrl, isRequired: true),
            const SizedBox(height: 8),
            _buildTextField('Đáp án B', _ansBCtrl, isRequired: true),
            const SizedBox(height: 8),
            _buildTextField('Đáp án C', _ansCCtrl, isRequired: true),
            const SizedBox(height: 8),
            _buildTextField('Đáp án D', _ansDCtrl, isRequired: true),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _correctAnswer,
              decoration: const InputDecoration(
                labelText: 'Chọn Đáp án đúng',
                border: OutlineInputBorder(),
              ),
              items: ['A', 'B', 'C', 'D']
                  .map(
                    (e) => DropdownMenuItem(value: e, child: Text('Đáp án $e')),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _correctAnswer = val!),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Lời giải chi tiết',
              _loiGiaiCtrl,
              maxLines: 3,
              hint: 'Giải thích tại sao chọn đáp án này...',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12.0),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.indigo.shade800,
      ),
    ),
  );

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? hint,
    bool isRequired = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: isRequired ? '$label (*)' : label,
        hintText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      validator: isRequired
          ? (value) {
              if (value == null || value.trim().isEmpty)
                return 'Vui lòng nhập $label';
              return null;
            }
          : null,
    );
  }
}
