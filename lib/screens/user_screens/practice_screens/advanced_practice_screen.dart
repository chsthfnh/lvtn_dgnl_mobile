import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_practice_screen.dart';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';

class AdvancedPracticeScreen extends StatefulWidget {
  const AdvancedPracticeScreen({super.key});

  @override
  State<AdvancedPracticeScreen> createState() => _AdvancedPracticeScreenState();
}

class _AdvancedPracticeScreenState extends State<AdvancedPracticeScreen> {
  final Color _primaryColor = const Color(0xFF1A237E);

  final List<Map<String, dynamic>> _subjects = [
    {
      'id': 'AdvancedVietnamese',
      'name': 'Tiếng Việt',
      'icon': Icons.menu_book,
      'color': Colors.orange,
      'description': 'Đọc hiểu tác phẩm, phân tích nhân vật, biện pháp tu từ.',
      'topics': ['Truyện Kiều', 'Tuyên ngôn độc lập', 'Chí Phèo', 'Vợ nhặt'],
    },
    {
      'id': 'AdvancedEnglish',
      'name': 'Tiếng Anh',
      'icon': Icons.language,
      'color': Colors.blue,
      'description': 'Từ vựng, ngữ pháp, đọc hiểu theo chủ đề.',
      'topics': ['Environment', 'Education', 'Technology', 'Health'],
    },
    {
      'id': 'AdvancedMath',
      'name': 'Toán Học',
      'icon': Icons.calculate,
      'color': Colors.red,
      'description': 'Đại số, hình học, phương trình, biến đổi công thức.',
      'topics': [
        'Phương trình bậc hai',
        'Cấp số cộng, cấp số nhân',
        'Hàm số',
        'Hình học không gian',
      ],
    },
    {
      'id': 'AdvancedLogic',
      'name': 'Logic',
      'icon': Icons.psychology,
      'color': Colors.purple,
      'description': 'Tìm quy luật dãy số, quy luật hình ảnh.',
      'topics': [
        'Quy luật cấp số cộng',
        'Quy luật cấp số nhân',
        'Quy luật đan xen',
        'Quy luật hình học',
      ],
    },
    {
      'id': 'AdvancedReasoning',
      'name': 'Suy Luận',
      'icon': Icons.account_tree,
      'color': Colors.green,
      'description': 'Sắp xếp vị trí, điều kiện logic, suy luận mệnh đề.',
      'topics': [
        'Sắp xếp vị trí',
        'Điều kiện vòng tròn',
        'Suy luận mệnh đề',
        'Logic nhân quả',
      ],
    },
  ];

  // // --- HÀM TỰ ĐỘNG TẠO 5 BẢNG TRÊN FIREBASE ---
  // Future<void> _seedDatabase() async {
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) => const Center(child: CircularProgressIndicator()),
  //   );

  //   try {
  //     final firestore = FirebaseFirestore.instance;

  //     // 1. BẢNG TOÁN HỌC
  //     await firestore.collection('AdvancedMath').add({
  //       'topic': 'Phương trình bậc hai',
  //       'level': 'Medium',
  //       'formula': 'ax² + bx + c = 0',
  //       'variables': ['a', 'b', 'c'],
  //       'constraints': ['a != 0', 'Δ > 0'],
  //       'answerFormula': '(-b±√Δ)/2a',
  //       'status': 'Active',
  //     });

  //     // 2. BẢNG TIẾNG VIỆT
  //     await firestore.collection('AdvancedVietnamese').add({
  //       'topic': 'Truyện Kiều',
  //       'title': 'Đoạn trích Kiều ở lầu Ngưng Bích',
  //       'author': 'Nguyễn Du',
  //       'content':
  //           'Bẽ bàng mây sớm đèn khuya\nNửa tình nửa cảnh như chia tấm lòng\nTưởng người dưới nguyệt chén đồng\nTin sương luống những rày trông mai chờ.',
  //       'questionTypes': [
  //         'Ý nghĩa',
  //         'Nhân vật',
  //         'Biện pháp tu từ',
  //         'Nội dung',
  //         'Thông điệp',
  //       ],
  //       'level': 'Hard',
  //     });

  //     // 3. BẢNG TIẾNG ANH
  //     await firestore.collection('AdvancedEnglish').add({
  //       'topic': 'Environment',
  //       'passage':
  //           'Global warming is the long-term heating of Earth\'s surface observed since the pre-industrial period due to human activities, primarily fossil fuel burning, which increases heat-trapping greenhouse gas levels in Earth\'s atmosphere.',
  //       'vocabulary': [
  //         'Global warming',
  //         'Fossil fuel',
  //         'Atmosphere',
  //         'Greenhouse gas',
  //       ],
  //       'grammar': ['Passive voice', 'Present perfect'],
  //       'questionTypes': [
  //         'Main idea',
  //         'Vocabulary',
  //         'True/False',
  //         'Inference',
  //         'Synonym',
  //       ],
  //       'difficulty': 'Medium',
  //     });

  //     // 4. BẢNG LOGIC
  //     await firestore.collection('AdvancedLogic').add({
  //       'topic': 'Quy luật cấp số cộng',
  //       'patternType': 'Arithmetic',
  //       'rule': '+2',
  //       'parameters': ['startNumber', 'length'],
  //       'answerRule': 'Số tiếp theo bằng số trước cộng 2',
  //       'distractorRule': 'Sinh ngẫu nhiên các số xung quanh đáp án đúng',
  //     });

  //     // 5. BẢNG SUY LUẬN
  //     await firestore.collection('AdvancedReasoning').add({
  //       'topic': 'Sắp xếp vị trí',
  //       'scenario': '4 người ngồi quanh một chiếc bàn tròn',
  //       'entities': ['A', 'B', 'C', 'D'],
  //       'conditions': ['A không ngồi cạnh B', 'B đối diện C'],
  //       'reasoningType': 'Positioning',
  //       'answerRule': 'Phân tích các trường hợp hợp lệ theo điều kiện',
  //     });

  //     if (mounted) Navigator.pop(context); // Đóng loading

  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('Đã tạo 5 bảng thành công!'),
  //           backgroundColor: Colors.green,
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     if (mounted) Navigator.pop(context);
  //     debugPrint('Lỗi tạo database: $e');
  //   }
  // }

  void _showTopicsBottomSheet(Map<String, dynamic> subject) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        List<String> topics = subject['topics'];
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(subject['icon'], color: subject['color'], size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Chủ đề ${subject['name']}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'AI sẽ tự động sinh bộ câu hỏi mới dựa trên chủ đề bạn chọn.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: topics.length,
                  itemBuilder: (context, index) {
                    return Card(
                      elevation: 0,
                      color: Colors.grey.shade50,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        title: Text(
                          topics[index],
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: _primaryColor,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _startAIPractice(subject['id'], topics[index]);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- HÀM 3: GỌI GEMINI AI ĐỂ SINH CÂU HỎI TỪ TEMPLATE ---
  Future<void> _startAIPractice(String tableId, String topic) async {
    // 1. Hiện thông báo đang suy nghĩ
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: const [
            CircularProgressIndicator(color: Color(0xFF1A237E)),
            SizedBox(width: 20),
            Expanded(
              child: Text(
                'AI đang đọc dữ liệu và sinh đề...\n(Có thể mất 5-10 giây)',
                style: TextStyle(height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      // 2. Kéo Template mẫu từ Firestore xuống
      final querySnapshot = await FirebaseFirestore.instance
          .collection(tableId)
          .where('topic', isEqualTo: topic)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chức năng này đang thử nghiệm,coming soon.'),
          ),
        );
        return;
      }

      final templateData = querySnapshot.docs.first.data();

      // 3. Khởi tạo Google Gemini 1.5 Flash (Nhanh và thông minh nhất hiện nay)
      // TODO: Dán API Key thật của bạn vào trong cặp ngoặc nháy này
      const apiKey = 'AQ.Ab8RN6KMss2SBMtfMxJv1NZ4k_WmbQKbJyNGzINjrA2jkmhhZw';

      final model = GenerativeModel(
        model: 'gemini-3.1-flash-lite',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          responseMimeType:
              'application/json', // Ép AI trả về chuẩn JSON cho App đọc
        ),
      );

      // 4. Viết "Bùa chú" (Prompt) ra lệnh cho AI
      final prompt =
          '''
      Bạn là một chuyên gia giáo dục và ra đề thi Đánh Giá Năng Lực. 
      Dựa vào Template gốc dưới đây, hãy sinh ra 5 câu hỏi trắc nghiệm hoàn toàn mới, không trùng lặp.
      - Môn học/Bảng dữ liệu: $tableId
      - Chủ đề: $topic
      - Dữ liệu Template gốc: $templateData

      YÊU CẦU:
      1. Tự phân tích quy luật của template (VD: Toán thì thay số, Logic thì thay quy luật tiến lùi, Văn/Anh thì đọc đoạn văn để hỏi).
      2. Tự tính toán đáp án đúng và sinh ra 3 đáp án nhiễu logic.
      3. Mỗi câu hỏi phải có chính xác 4 đáp án và 1 đáp án đúng.
      4. TRẢ VỀ DUY NHẤT MỘT MẢNG JSON (Array of Objects), tuyệt đối không kèm chữ nào khác.
      
      Cấu trúc mỗi Object JSON bắt buộc như sau:
      {
        "noiDungCauHoi": "Nội dung câu hỏi...",
        "noiDungChung": "Nội dung đoạn văn / tình huống (nếu không có thì để trống rỗng)",
        "options": ["Đáp án A", "Đáp án B", "Đáp án C", "Đáp án D"],
        "correctAnswer": "A" // Hoặc B, C, D (Trả về chữ cái viết hoa)
      }
      ''';

      // 5. Gửi yêu cầu cho AI và đợi kết quả
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      // 6. Dịch dữ liệu AI trả về sang danh sách câu hỏi của Flutter
      final String rawJson = response.text ?? '[]';
      final List<dynamic> jsonList = jsonDecode(rawJson);
      final List<Map<String, dynamic>> aiQuestions = jsonList
          .map((item) => item as Map<String, dynamic>)
          .toList();

      // 7. Đóng hộp thoại chờ và Tốc biến sang trang làm bài
      if (mounted) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AIPracticeScreen(
              questions: aiQuestions,
              subjectName: _getSubjectNameVN(tableId),
              topic: topic,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi sinh đề: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Hàm phụ: Đổi mã bảng thành tên môn học cho đẹp
  String _getSubjectNameVN(String tableId) {
    switch (tableId) {
      case 'AdvancedVietnamese':
        return 'Tiếng Việt';
      case 'AdvancedEnglish':
        return 'Tiếng Anh';
      case 'AdvancedMath':
        return 'Toán Học';
      case 'AdvancedLogic':
        return 'Logic';
      case 'AdvancedReasoning':
        return 'Suy Luận';
      default:
        return 'Luyện Tập AI';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Luyện tập nâng cao',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Powered by AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Sinh đề thông minh',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Hệ thống tự động thay đổi thông số và cấu trúc câu hỏi, giúp bạn không bao giờ làm lại đề cũ.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // GẮN HÀM VÀO ĐÂY ĐỂ BẤM ĐƯỢC
                const Icon(Icons.auto_awesome, color: Colors.amber, size: 60),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Chọn môn học',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _subjects.length,
              itemBuilder: (context, index) {
                final subject = _subjects[index];
                return GestureDetector(
                  onTap: () => _showTopicsBottomSheet(subject),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: subject['color'].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            subject['icon'],
                            color: subject['color'],
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subject['name'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subject['description'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
