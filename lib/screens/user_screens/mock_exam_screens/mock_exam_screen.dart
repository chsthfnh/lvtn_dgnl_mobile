import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'exam_detail_screen.dart';

class MockExamScreen extends StatefulWidget {
  const MockExamScreen({super.key});

  @override
  State<MockExamScreen> createState() => _MockExamScreenState();
}

class _MockExamScreenState extends State<MockExamScreen> {
  // --- BẢNG MÀU DESIGN SYSTEM ---
  final Color _primary = const Color(0xFF002045);
  final Color _bgLight = const Color(0xFFF8F9FF);
  final Color _outline = const Color(0xFFC4C6CF);

  String _searchQuery = '';
  int _selectedFilterIndex = 0; // 0: Tất cả, 1: Chưa làm, 2: Đã làm
  final List<String> _filters = ['Tất cả', 'Chưa làm', 'Đã làm'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        backgroundColor: _bgLight,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.arrow_back, color: _primary, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Thi thử ĐGNL',
          style: TextStyle(
            color: _primary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: Column(
        children: [
          // --- THANH TÌM KIẾM ---
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: TextField(
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm đề thi...',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _outline.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _primary),
                ),
              ),
            ),
          ),

          // --- BỘ LỌC TÌM KIẾM ---
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                bool isActive = _selectedFilterIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilterIndex = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? _primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive
                            ? _primary
                            : _outline.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _filters[index],
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.grey.shade700,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // --- PHẦN HIỂN THỊ DỮ LIỆU ĐỘNG TỪ FIREBASE ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Quét lấy danh sách đề thi đã được Public, sắp xếp mới nhất lên đầu
              stream: FirebaseFirestore.instance
                  .collection('Exams')
                  .where('isPublic', isEqualTo: true)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Đã xảy ra lỗi: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                var allDocs = snapshot.data?.docs ?? [];

                // Lọc theo thanh tìm kiếm
                if (_searchQuery.isNotEmpty) {
                  allDocs = allDocs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String title = (data['tenDeThi'] ?? '')
                        .toString()
                        .toLowerCase();
                    return title.contains(_searchQuery);
                  }).toList();
                }

                // TODO: Xử lý logic lọc "Chưa làm" / "Đã làm" ở đây khi có Collection lưu lịch sử làm bài của User.
                // Tạm thời hiển thị tất cả nếu chưa nối History.

                if (allDocs.isEmpty) {
                  return Center(
                    child: Text(
                      'Không tìm thấy đề thi nào phù hợp.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }

                // Bóc tách 3 đề thi mới nhất cho mục Nổi bật
                var featuredDocs = allDocs.take(3).toList();

                return ListView(
                  padding: const EdgeInsets.only(bottom: 40),
                  children: [
                    // --- MỤC: ĐỀ THI NỔI BẬT ---
                    if (_searchQuery.isEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: Text(
                          'Đề thi nổi bật',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: featuredDocs.length,
                          itemBuilder: (context, index) =>
                              _buildFeaturedCard(featuredDocs[index], index),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // --- MỤC: TẤT CẢ ĐỀ THI ---
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'Kết quả tìm kiếm'
                            : 'Tất cả đề thi',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(), // Không tự cuộn vì đã nằm trong ListView mẹ
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: allDocs.length,
                      itemBuilder: (context, index) =>
                          _buildExamCard(allDocs[index]),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- CARD: ĐỀ THI NỔI BẬT (Vuốt ngang) ---
  Widget _buildFeaturedCard(DocumentSnapshot doc, int index) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String title = data['tenDeThi'] ?? 'Đề thi ĐGNL';
    String time = data['thoiGian']?.toString() ?? '150';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExamDetailScreen(examDoc: doc),
          ),
        );
      },
      child: Container(
        width: 260,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          // Tạo màu nền gradient xanh dương sang trọng thay cho ảnh nền tĩnh
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: index % 2 == 0
                ? [const Color(0xFF002045), const Color(0xFF1a365d)]
                : [const Color(0xFF0F3E5A), const Color(0xFF002045)],
          ),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: index == 0 ? Colors.deepOrange : Colors.green,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                index == 0 ? 'HOT' : 'MỚI',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                Text(
                  '$time phút',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- CARD: TẤT CẢ ĐỀ THI (Danh sách dọc) ---
  Widget _buildExamCard(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String title = data['tenDeThi'] ?? 'Chưa cập nhật tên';
    String time = data['thoiGian']?.toString() ?? '150';
    String questions = data['soCauHoi']?.toString() ?? '120';
    String plays = data['luotLamBai']?.toString() ?? '0';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExamDetailScreen(examDoc: doc),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _outline.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF002045),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _bgLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Color(0xFF002045),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE5EEFF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'ĐGNL',
                style: TextStyle(
                  color: Color(0xFF1A365D),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildCardFooterIcon(Icons.schedule, '$time phút'),
                const SizedBox(width: 16),
                _buildCardFooterIcon(
                  Icons.assignment_outlined,
                  '$questions câu',
                ),
                const SizedBox(width: 16),
                _buildCardFooterIcon(
                  Icons.people_alt_outlined,
                  '$plays lượt thi',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFooterIcon(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
