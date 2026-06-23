import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'exam_detail_screen.dart'; // Import màn hình chi tiết

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
    String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

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
              color: _primary.withOpacity(0.05),
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
                  borderSide: BorderSide(color: _outline.withOpacity(0.5)),
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
                        color: isActive ? _primary : _outline.withOpacity(0.5),
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

          // --- PHẦN HIỂN THỊ DỮ LIỆU ĐỘNG TỪ FIREBASE LỒNG NHAU ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // 1. Quét lịch sử làm bài của User hiện tại
              stream: FirebaseFirestore.instance
                  .collection('ExamHistory')
                  .where('userId', isEqualTo: currentUserId)
                  .snapshots(),
              builder: (context, historySnapshot) {
                // Lấy ra danh sách các maDeThi mà user này đã nộp bài
                List<String> completedExamIds = [];
                if (historySnapshot.hasData) {
                  completedExamIds = historySnapshot.data!.docs
                      .map(
                        (doc) => (doc.data() as Map<String, dynamic>)['examId']
                            .toString(),
                      )
                      .toList();
                }

                return StreamBuilder<QuerySnapshot>(
                  // 2. Quét danh sách toàn bộ Đề thi
                  stream: FirebaseFirestore.instance
                      .collection('Exams')
                      .where('isPublic', isEqualTo: true)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, examSnapshot) {
                    if (examSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (examSnapshot.hasError) {
                      return Center(
                        child: Text(
                          'Đã xảy ra lỗi: ${examSnapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    var allDocs = examSnapshot.data?.docs ?? [];

                    // --- BỘ LỌC 1: THEO TỪ KHÓA TÌM KIẾM ---
                    if (_searchQuery.isNotEmpty) {
                      allDocs = allDocs.where((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        String title = (data['tenDeThi'] ?? '')
                            .toString()
                            .toLowerCase();
                        return title.contains(_searchQuery);
                      }).toList();
                    }

                    // --- BỘ LỌC 2: THEO TRẠNG THÁI (Tất cả / Chưa làm / Đã làm) ---
                    if (_selectedFilterIndex == 1) {
                      // Chưa làm -> Loại bỏ các đề có ID nằm trong completedExamIds
                      allDocs = allDocs
                          .where((doc) => !completedExamIds.contains(doc.id))
                          .toList();
                    } else if (_selectedFilterIndex == 2) {
                      // Đã làm -> Chỉ giữ lại các đề có ID nằm trong completedExamIds
                      allDocs = allDocs
                          .where((doc) => completedExamIds.contains(doc.id))
                          .toList();
                    }

                    if (allDocs.isEmpty) {
                      return Center(
                        child: Text(
                          'Không tìm thấy đề thi nào phù hợp.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      );
                    }

                    // Bóc tách 3 đề thi cho mục Nổi bật (Chỉ hiển thị khi đang ở tab "Tất cả" và không tìm kiếm)
                    var featuredDocs = allDocs.take(3).toList();

                    return ListView(
                      padding: const EdgeInsets.only(bottom: 40),
                      children: [
                        // --- MỤC: ĐỀ THI NỔI BẬT ---
                        if (_searchQuery.isEmpty &&
                            _selectedFilterIndex == 0) ...[
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: featuredDocs.length,
                              itemBuilder: (context, index) {
                                bool isCompleted = completedExamIds.contains(
                                  featuredDocs[index].id,
                                );
                                return _buildFeaturedCard(
                                  featuredDocs[index],
                                  index,
                                  isCompleted,
                                );
                              },
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
                                : (_selectedFilterIndex == 1
                                      ? 'Đề thi chưa làm'
                                      : (_selectedFilterIndex == 2
                                            ? 'Đề thi đã làm'
                                            : 'Tất cả đề thi')),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: allDocs.length,
                          itemBuilder: (context, index) {
                            bool isCompleted = completedExamIds.contains(
                              allDocs[index].id,
                            );
                            return _buildExamCard(allDocs[index], isCompleted);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- CARD: ĐỀ THI NỔI BẬT ---
  Widget _buildFeaturedCard(DocumentSnapshot doc, int index, bool isCompleted) {
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: index % 2 == 0
                ? [const Color(0xFF002045), const Color(0xFF1a365d)]
                : [const Color(0xFF0F3E5A), const Color(0xFF002045)],
          ),
          boxShadow: [
            BoxShadow(
              color: _primary.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: index == 0 ? Colors.deepOrange : Colors.blue,
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
                // THẺ TAG "ĐÃ LÀM" HOẶC "CHƯA LÀM"
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green.withOpacity(0.2)
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isCompleted ? Colors.greenAccent : Colors.white54,
                    ),
                  ),
                  child: Text(
                    isCompleted ? 'Đã làm' : 'Chưa làm',
                    style: TextStyle(
                      color: isCompleted ? Colors.greenAccent : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
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

  // --- CARD: TẤT CẢ ĐỀ THI ---
  Widget _buildExamCard(DocumentSnapshot doc, bool isCompleted) {
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
          border: Border.all(color: _outline.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
                const SizedBox(width: 8),
                // THẺ TAG "ĐÃ LÀM" HOẶC "CHƯA LÀM"
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCompleted
                          ? Colors.green.shade200
                          : Colors.orange.shade200,
                    ),
                  ),
                  child: Text(
                    isCompleted ? 'Đã làm' : 'Chưa làm',
                    style: TextStyle(
                      color: isCompleted
                          ? Colors.green.shade700
                          : Colors.orange.shade800,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
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
