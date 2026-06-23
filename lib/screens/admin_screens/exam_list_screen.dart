import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_exam_screen.dart';

class ExamListScreen extends StatefulWidget {
  const ExamListScreen({super.key});

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  final Color _primaryDark = const Color(0xFF002045);
  final Color _bgLight = const Color(0xFFF8F9FA);

  String _searchText = '';
  String _selectedTrangThai = 'Tất cả';
  final List<String> _trangThaiList = ['Tất cả', 'Công khai', 'Bản nháp'];

  // --- HÀM XÓA ĐỀ THI ---
  Future<void> _deleteExam(DocumentSnapshot doc) async {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    int dangLamBai = data['dangLamBai'] ?? 0;
    int luotLamBai = data['luotLamBai'] ?? 0;

    if (dangLamBai > 0) {
      _showErrorSnackBar(
        'CẢNH BÁO: Đang có $dangLamBai sinh viên làm bài thi này. Tuyệt đối không được xóa!',
      );
      return;
    }

    String warningText = 'Bạn có chắc chắn muốn xóa đề thi này không?';
    if (luotLamBai > 0) {
      warningText =
          'Đã có $luotLamBai lượt sinh viên hoàn thành đề thi này.\n\nHệ thống sẽ xóa đề và [Gửi thông báo] đến tài khoản của các sinh viên này. Bạn vẫn muốn tiếp tục?';
    }

    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              'Xóa đề thi',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            content: Text(warningText),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Xóa Đề',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance
            .collection('Exams')
            .doc(doc.id)
            .delete();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa đề thi thành công!')),
          );
      } catch (e) {
        if (mounted) _showErrorSnackBar('Lỗi: $e');
      }
    }
  }

  // --- HÀM SỬA ĐỀ THI ---
  void _editExam(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    int dangLamBai = data['dangLamBai'] ?? 0;
    int luotLamBai = data['luotLamBai'] ?? 0;

    if (dangLamBai > 0) {
      _showErrorSnackBar(
        'CẢNH BÁO: Đang có sinh viên làm bài. Không thể sửa đề lúc này!',
      );
      return;
    }

    if (luotLamBai > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lưu ý: Sửa đề thi sẽ gửi thông báo cập nhật đến các sinh viên đã làm bài.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateExamScreen(examDoc: doc)),
    );
  }

  // --- HÀM ĐỔI TRẠNG THÁI NHANH (QUICK TOGGLE) ---
  Future<void> _togglePublicStatus(
    DocumentSnapshot doc,
    bool currentStatus,
  ) async {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    int dangLamBai = data['dangLamBai'] ?? 0;

    // Chặn nếu đang có người làm bài mà Admin lại định khóa đề lại thành Bản nháp
    if (dangLamBai > 0 && currentStatus == true) {
      _showErrorSnackBar(
        'CẢNH BÁO: Đang có sinh viên làm bài. Không thể chuyển về Bản nháp!',
      );
      return;
    }

    String nextStatus = currentStatus ? 'BẢN NHÁP' : 'CÔNG KHAI';
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              'Đổi trạng thái',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Bạn có chắc chắn muốn chuyển đề thi này thành $nextStatus?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Xác nhận',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance.collection('Exams').doc(doc.id).update(
          {'isPublic': !currentStatus},
        );
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã cập nhật trạng thái thành công!')),
          );
      } catch (e) {
        if (mounted) _showErrorSnackBar('Lỗi cập nhật: $e');
      }
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          'Danh sách Đề thi',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primaryDark,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateExamScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text(
          'Tạo đề thi mới',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
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
                  onChanged: (value) => setState(() => _searchText = value),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm tên đề thi, mã đề...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
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
                    const Text(
                      'Trạng thái: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDropdown(
                        value: _selectedTrangThai,
                        items: _trangThaiList,
                        onChanged: (v) =>
                            setState(() => _selectedTrangThai = v!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Exams')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError)
                  return const Center(child: Text('Đã xảy ra lỗi.'));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                  return Center(
                    child: Text(
                      'Chưa có đề thi nào.',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  );

                var filteredDocs = snapshot.data!.docs.where((doc) {
                  Map<String, dynamic> data =
                      doc.data() as Map<String, dynamic>;
                  String title =
                      data['tenDeThi']?.toString().toLowerCase() ?? '';
                  String code = data['maDe']?.toString().toLowerCase() ?? '';
                  bool isPublic = data['isPublic'] ?? false;
                  String statusStr = isPublic ? 'Công khai' : 'Bản nháp';

                  if (_searchText.isNotEmpty &&
                      !title.contains(_searchText.toLowerCase()) &&
                      !code.contains(_searchText.toLowerCase()))
                    return false;
                  if (_selectedTrangThai != 'Tất cả' &&
                      statusStr != _selectedTrangThai)
                    return false;
                  return true;
                }).toList();

                if (filteredDocs.isEmpty)
                  return Center(
                    child: Text(
                      'Không tìm thấy đề thi phù hợp.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) =>
                      _buildExamCard(filteredDocs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String tenDeThi = data['tenDeThi'] ?? 'Chưa có tên';
    String maDe = data['maDe']?.toString() ?? 'N/A';
    String thoiGian = data['thoiGian']?.toString() ?? '150';
    int soCauHoi = data['soCauHoi'] ?? 120;
    bool isPublic = data['isPublic'] ?? false;

    int dangLamBai = data['dangLamBai'] ?? 0;
    int luotLamBai = data['luotLamBai'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.assignment,
                  color: Colors.indigo.shade600,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenDeThi,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildBadge(
                          Icons.timer,
                          '$thoiGian phút',
                          Colors.orange.shade50,
                          Colors.orange.shade800,
                        ),
                        _buildBadge(
                          Icons.format_list_numbered,
                          '$soCauHoi câu',
                          Colors.blue.shade50,
                          Colors.blue.shade800,
                        ),
                        if (maDe.isNotEmpty && maDe != 'N/A')
                          _buildBadge(
                            Icons.qr_code,
                            maDe,
                            Colors.purple.shade50,
                            Colors.purple.shade800,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.people_alt,
                      size: 16,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$luotLamBai đã thi',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(
                      Icons.play_circle_fill,
                      size: 16,
                      color: dangLamBai > 0 ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$dangLamBai đang thi',
                      style: TextStyle(
                        fontSize: 12,
                        color: dangLamBai > 0 ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // BỌC NÚT TRẠNG THÁI BẰNG INKWELL ĐỂ CÓ THỂ CLICK ĐƯỢC
              InkWell(
                onTap: () => _togglePublicStatus(doc, isPublic),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isPublic
                        ? Colors.green.shade50
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isPublic
                          ? Colors.green.shade200
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPublic ? Icons.public : Icons.visibility_off,
                        size: 14,
                        color: isPublic
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPublic ? 'Công khai' : 'Bản nháp',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isPublic
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.sync,
                        size: 12,
                        color: Colors.grey.shade500,
                      ), // Thêm icon xoay nhỏ báo hiệu có thể click
                    ],
                  ),
                ),
              ),

              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _editExam(doc),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      side: BorderSide(color: Colors.blue.shade200),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: Icon(
                      Icons.edit,
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                    label: Text(
                      'Sửa',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _deleteExam(doc),
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red.shade600,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(
    IconData icon,
    String text,
    Color bgColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      height: 40,
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
}
