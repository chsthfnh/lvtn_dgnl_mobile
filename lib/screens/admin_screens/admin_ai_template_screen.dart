import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAITemplateScreen extends StatefulWidget {
  const AdminAITemplateScreen({super.key});

  @override
  State<AdminAITemplateScreen> createState() => _AdminAITemplateScreenState();
}

class _AdminAITemplateScreenState extends State<AdminAITemplateScreen> {
  final Color _primaryColor = const Color(0xFF1A237E);
  String _selectedCollection = 'AdvancedMath';

  // Lược đồ cấu trúc (Schema) của 5 môn học
  final Map<String, List<Map<String, dynamic>>> _schema = {
    'AdvancedMath': [
      {'key': 'topic', 'label': 'Chủ đề (VD: Phương trình bậc hai)'},
      {'key': 'level', 'label': 'Độ khó (Easy/Medium/Hard)'},
      {'key': 'formula', 'label': 'Công thức gốc (VD: ax² + bx + c = 0)'},
      {
        'key': 'variables',
        'label': 'Các biến (Cách nhau bằng dấu phẩy)',
        'isList': true,
      },
      {
        'key': 'constraints',
        'label': 'Điều kiện (Cách nhau bằng phẩy)',
        'isList': true,
      },
      {'key': 'answerFormula', 'label': 'Công thức tính đáp án đúng'},
    ],
    'AdvancedVietnamese': [
      {'key': 'topic', 'label': 'Chủ đề (VD: Truyện Kiều)'},
      {'key': 'title', 'label': 'Tên đoạn trích'},
      {'key': 'author', 'label': 'Tác giả'},
      {'key': 'content', 'label': 'Nội dung văn bản gốc', 'maxLines': 5},
      {
        'key': 'questionTypes',
        'label': 'Dạng câu hỏi (Cách nhau bằng dấu phẩy)',
        'isList': true,
      },
      {'key': 'level', 'label': 'Độ khó'},
    ],
    'AdvancedEnglish': [
      {'key': 'topic', 'label': 'Chủ đề (VD: Environment)'},
      {'key': 'passage', 'label': 'Đoạn văn tiếng Anh', 'maxLines': 5},
      {
        'key': 'vocabulary',
        'label': 'Từ vựng trọng tâm (Cách nhau bằng phẩy)',
        'isList': true,
      },
      {
        'key': 'grammar',
        'label': 'Ngữ pháp (Cách nhau bằng phẩy)',
        'isList': true,
      },
      {
        'key': 'questionTypes',
        'label': 'Dạng câu hỏi (Cách nhau bằng phẩy)',
        'isList': true,
      },
      {'key': 'difficulty', 'label': 'Độ khó'},
    ],
    'AdvancedLogic': [
      {'key': 'topic', 'label': 'Chủ đề (VD: Cấp số cộng)'},
      {'key': 'patternType', 'label': 'Loại quy luật (VD: Arithmetic)'},
      {'key': 'rule', 'label': 'Quy luật (VD: +2 hoặc x3)'},
      {
        'key': 'parameters',
        'label': 'Tham số (Cách nhau bằng phẩy)',
        'isList': true,
      },
      {'key': 'answerRule', 'label': 'Quy tắc đáp án'},
      {'key': 'distractorRule', 'label': 'Quy tắc sinh đáp án nhiễu'},
    ],
    'AdvancedReasoning': [
      {'key': 'topic', 'label': 'Chủ đề (VD: Sắp xếp vị trí)'},
      {'key': 'scenario', 'label': 'Tình huống gốc', 'maxLines': 3},
      {
        'key': 'entities',
        'label': 'Nhân vật (Cách nhau bằng phẩy)',
        'isList': true,
      },
      {
        'key': 'conditions',
        'label': 'Điều kiện (Cách nhau bằng phẩy)',
        'isList': true,
      },
      {'key': 'reasoningType', 'label': 'Loại suy luận (VD: Positioning)'},
      {'key': 'answerRule', 'label': 'Quy tắc đáp án'},
    ],
  };

  // Hàm hiển thị Form (Dùng chung cho cả Thêm và Sửa)
  void _showForm({DocumentSnapshot? doc}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TemplateFormSheet(
        collectionName: _selectedCollection,
        schema: _schema[_selectedCollection]!,
        doc: doc,
      ),
    );
  }

  // Hàm xác nhận Xóa
  Future<void> _deleteTemplate(DocumentSnapshot doc) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Xác nhận xóa'),
            content: const Text(
              'Bạn có chắc chắn muốn xóa Template này? AI sẽ không thể sinh đề cho chủ đề này nữa.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Xóa', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await doc.reference.delete();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã xóa thành công!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Quản lý Template AI',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _primaryColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // KHU VỰC CHỌN MÔN HỌC
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.folder_special, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCollection,
                      isExpanded: true,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor,
                      ),
                      items: _schema.keys.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() => _selectedCollection = newValue!);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // KHU VỰC DANH SÁCH TEMPLATE
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection(_selectedCollection)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Chưa có dữ liệu. Hãy bấm dấu + để thêm mới.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: _primaryColor.withOpacity(0.1),
                          child: Icon(Icons.psychology, color: _primaryColor),
                        ),
                        title: Text(
                          data['topic'] ?? 'Chưa có tên chủ đề',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Độ khó: ${data['level'] ?? data['difficulty'] ?? 'Không rõ'}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.blue,
                              ),
                              onPressed: () => _showForm(doc: doc),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => _deleteTemplate(doc),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(), // Bấm nút này là tạo mới
        backgroundColor: _primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Thêm mới',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET CON: FORM NHẬP LIỆU THÔNG MINH (CHO CẢ THÊM & SỬA)
// ============================================================================
class _TemplateFormSheet extends StatefulWidget {
  final String collectionName;
  final List<Map<String, dynamic>> schema;
  final DocumentSnapshot?
  doc; // Nếu có truyền doc vào tức là Sửa, nếu null là Thêm

  const _TemplateFormSheet({
    required this.collectionName,
    required this.schema,
    this.doc,
  });

  @override
  State<_TemplateFormSheet> createState() => _TemplateFormSheetState();
}

class _TemplateFormSheetState extends State<_TemplateFormSheet> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Khởi tạo các ô nhập liệu và đổ dữ liệu cũ vào (nếu đang Sửa)
    Map<String, dynamic> existingData = widget.doc != null
        ? widget.doc!.data() as Map<String, dynamic>
        : {};

    for (var field in widget.schema) {
      String key = field['key'];
      String initialValue = '';

      if (existingData.containsKey(key)) {
        if (field['isList'] == true && existingData[key] is List) {
          // Nếu dữ liệu dạng mảng thì chuyển thành chuỗi cách nhau bằng dấu phẩy
          initialValue = (existingData[key] as List).join(', ');
        } else {
          initialValue = existingData[key].toString();
        }
      }
      _controllers[key] = TextEditingController(text: initialValue);
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _saveData() async {
    // 1. Kiểm tra đã nhập đủ chưa
    bool isValid = true;
    for (var field in widget.schema) {
      if (_controllers[field['key']]!.text.trim().isEmpty) {
        isValid = false;
        break;
      }
    }

    if (!isValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng nhập đủ các ô!')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Gom dữ liệu
      Map<String, dynamic> dataToSave = {};
      for (var field in widget.schema) {
        String key = field['key'];
        String rawValue = _controllers[key]!.text.trim();

        if (field['isList'] == true) {
          dataToSave[key] = rawValue
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        } else {
          dataToSave[key] = rawValue;
        }
      }

      // 3. Quyết định Thêm mới hay Cập nhật
      if (widget.doc == null) {
        dataToSave['status'] = 'Active';
        dataToSave['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection(widget.collectionName)
            .add(dataToSave);
      } else {
        await widget.doc!.reference.update(dataToSave);
      }

      if (mounted) {
        Navigator.pop(context); // Đóng form
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lưu thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9, // Cao bằng 90% màn hình
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            24, // Chống khuất bàn phím
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.doc == null ? 'Thêm Template mới' : 'Sửa Template',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: widget.schema.map((field) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: _controllers[field['key']],
                    maxLines: field['maxLines'] ?? 1,
                    decoration: InputDecoration(
                      labelText: field['label'],
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF1A237E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isLoading ? null : _saveData,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'LƯU DỮ LIỆU',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
