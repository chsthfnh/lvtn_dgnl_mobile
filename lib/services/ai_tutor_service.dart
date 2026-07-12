import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AITutorService {
  //API_KEY from Google AI Studio
  static const String _apiKey =
      'AQ.Ab8RN6K-y9ROOtzeufRnU_l1MkvaQ-hPczv-jWd75T5vkFDEkQ';
  late final GenerativeModel _model;
  late final ChatSession _chatSession;

  AITutorService() {
    // gemini-1.5-flash đã bị Google khai tử (trả lỗi 404 v1beta not found).
    // Dùng gemini-2.5-flash (ổn định, rẻ, nhanh) - hoặc gemini-flash-latest
    // nếu muốn tự động trỏ tới bản Flash mới nhất mà không cần sửa code sau này.
    _model = GenerativeModel(
      model: 'gemini-3.1-flash-lite',
      apiKey: _apiKey,
      systemInstruction: Content.system(
        'Bạn là AI Tutor, một gia sư thông minh hỗ trợ ôn thi Đánh giá năng lực. Bạn luôn xưng hô là "AI Tutor" và gọi người dùng là "Bạn". Hãy trả lời ngắn gọn, súc tích, giải thích dễ hiểu, luôn đưa ra mẹo làm bài và phân tích nguyên nhân sai nếu có.',
      ),
    );
    _chatSession = _model.startChat();
  }

  // Hàm tổng hợp ngữ cảnh (Context) dựa vào màn hình người dùng đang đứng
  Future<String> _buildContext(String screenName) async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return '';

    String contextData = 'Màn hình người dùng đang đứng: $screenName.\n';
    try {
      // 1. Lấy mục tiêu điểm
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        contextData +=
            'Mục tiêu điểm của học viên: ${data['targetScore'] ?? 900}.\n';
      }

      // 2. Lấy Level hiện tại
      DocumentSnapshot progressDoc = await FirebaseFirestore.instance
          .collection('UserProgress')
          .doc(uid)
          .get();
      if (progressDoc.exists && progressDoc.data() != null) {
        var pData = progressDoc.data() as Map<String, dynamic>;
        contextData += 'Tiến độ Cấp độ các môn học: $pData.\n';
      }

      // ==========================================================
      // 3. TÍNH NĂNG MỚI: PHÂN TÍCH HỌC LỰC TỪ LỊCH SỬ THI
      // ==========================================================
      QuerySnapshot historySnap = await FirebaseFirestore.instance
          .collection('ExamHistory')
          .where('userId', isEqualTo: uid)
          .get();

      if (historySnap.docs.isNotEmpty) {
        // Sắp xếp lấy 10 bài thi gần nhất (Xử lý bằng code Dart để tránh lỗi thiếu Index Firestore)
        var docs = historySnap.docs.toList();
        docs.sort((a, b) {
          var aData = a.data() as Map<String, dynamic>;
          var bData = b.data() as Map<String, dynamic>;
          Timestamp? aTime = aData['createdAt'] as Timestamp?;
          Timestamp? bTime = bData['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime); // Sắp xếp mới nhất lên đầu
        });

        var recentDocs = docs.take(10).toList(); // Lấy 10 bài gần nhất

        int nnCorrect = 0, nnTotal = 0;
        int toanCorrect = 0, toanTotal = 0;
        int logicCorrect = 0, logicTotal = 0;

        for (var doc in recentDocs) {
          var data = doc.data() as Map<String, dynamic>;
          int correct = data['correctAnswers'] ?? 0;
          int total = data['answeredCount'] ?? data['totalQuestions'] ?? 0;
          String name = (data['examName'] ?? '').toString().toLowerCase();

          // Phân loại giống logic ở Dashboard
          if (name.contains('ngôn ngữ') ||
              name.contains('tiếng') ||
              name.contains('văn')) {
            nnCorrect += correct;
            nnTotal += total;
          } else if (name.contains('toán') || name.contains('số liệu')) {
            toanCorrect += correct;
            toanTotal += total;
          } else if (name.contains('tư duy') ||
              name.contains('khoa học') ||
              name.contains('logic') ||
              name.contains('lô gic')) {
            logicCorrect += correct;
            logicTotal += total;
          }
        }

        contextData += '\nThống kê tỷ lệ làm đúng trong các bài gần đây:\n';
        if (nnTotal > 0)
          contextData +=
              '- Phần Ngôn ngữ: ${(nnCorrect / nnTotal * 100).toStringAsFixed(1)}%\n';
        if (toanTotal > 0)
          contextData +=
              '- Phần Toán học: ${(toanCorrect / toanTotal * 100).toStringAsFixed(1)}%\n';
        if (logicTotal > 0)
          contextData +=
              '- Phần Logic/Khoa học: ${(logicCorrect / logicTotal * 100).toStringAsFixed(1)}%\n';

        // MỚM LỆNH CHO AI:
        contextData +=
            '\nCHỈ THỊ CHO AI: Dựa vào số liệu trên, hãy đánh giá ngắn gọn năng lực của học viên. Môn nào có tỷ lệ % thấp nhất, hãy khuyên học viên ưu tiên ôn luyện môn đó trong hôm nay.\n';
      } else {
        contextData +=
            'Học viên chưa làm bài luyện tập nào. CHỈ THỊ CHO AI: Hãy khuyên họ bắt đầu làm 1 bài thi thử hoặc bài luyện tập để hệ thống có cơ sở đánh giá.\n';
      }
    } catch (e) {
      debugPrint('Lỗi tải context: $e');
    }
    return contextData;
  }

  // Hàm Gửi tin nhắn và Nhận phản hồi
  Future<String> sendMessage(String message, String currentScreen) async {
    try {
      String context = await _buildContext(currentScreen);
      String fullPrompt =
          "Thông tin hệ thống:\n$context\n\nCâu hỏi của người dùng: $message";

      final response = await _chatSession.sendMessage(Content.text(fullPrompt));
      String aiReply =
          response.text ?? 'Xin lỗi, tôi không thể xử lý câu hỏi này lúc này.';

      await _saveChatHistory(message, aiReply, currentScreen);
      return aiReply;
    } catch (e) {
      debugPrint('Lỗi Gemini: $e');
      return 'Lỗi kết nối đến máy chủ AI. Vui lòng thử lại sau.';
    }
  }

  // Lưu lịch sử hội thoại lên Firebase
  Future<void> _saveChatHistory(
    String userMsg,
    String aiReply,
    String screen,
  ) async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('Users')
        .doc(uid)
        .collection('AIChatHistory')
        .add({
          'userMessage': userMsg,
          'aiReply': aiReply,
          'screenContext': screen,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  // Thêm hàm này vào cuối class AITutorService
  Future<String> explainQuestion({
    required String questionContent,
    required String correctAnswer,
    required String userAnswer,
  }) async {
    try {
      String prompt =
          '''
        Học viên đang ôn thi Đánh giá năng lực và làm sai một câu hỏi. Hãy đóng vai AI Tutor, phân tích ngắn gọn, súc tích và giải thích thật dễ hiểu theo các ý sau:
        1. Vì sao đáp án đúng lại là đáp án đó?
        2. Lỗi tư duy hoặc kiến thức nào khiến học viên chọn sai?
        3. Đưa ra một mẹo (tip) nhỏ để ghi nhớ và không sai lại ở dạng bài này.

        - Câu hỏi: $questionContent
        - Đáp án đúng: $correctAnswer
        - Đáp án học viên đã chọn: $userAnswer
        ''';

      final response = await _chatSession.sendMessage(Content.text(prompt));
      return response.text ??
          'Xin lỗi, AI đang bận chút xíu, bạn thử lại sau nghen.';
    } catch (e) {
      debugPrint('Lỗi AI giải thích: $e');
      return 'Lỗi kết nối đến máy chủ AI. Vui lòng kiểm tra mạng và thử lại.';
    }
  }

  // Thêm hàm này vào cuối class AITutorService
  Future<String> summarizeMistakes({
    required List<String> wrongQuestionsContext,
  }) async {
    if (wrongQuestionsContext.isEmpty) {
      return 'Tuyệt vời! Bạn không làm sai câu nào trong bài thi này.';
    }

    try {
      String prompt =
          '''
            Đóng vai một gia sư AI phân tích kết quả bài thi Đánh giá năng lực. 
            Dưới đây là danh sách (tối đa 15 câu) mà học viên vừa làm sai:

            ${wrongQuestionsContext.join('\n---\n')}

            Dựa vào các câu sai ở trên, hãy phân tích ngắn gọn, súc tích và thân thiện:
            1. **Lỗ hổng kiến thức:** Học viên đang yếu ở mảng nào nhất? (Ví dụ: tính toán, logic suy luận, hay đọc hiểu).
            2. **Lỗi sai phổ biến:** Có điểm chung nào trong các câu sai này không? (Ví dụ: hay sai dạng mệnh đề kéo theo, hay tính toán sai bước cuối).
            3. **Chiến lược ôn tập:** Đưa ra 2-3 lời khuyên thực tế để khắc phục ngay lỗ hổng này.
            ''';

      final response = await _chatSession.sendMessage(Content.text(prompt));
      return response.text ?? 'Xin lỗi, AI đang bận, bạn thử lại sau nhé.';
    } catch (e) {
      debugPrint('Lỗi AI tổng hợp: $e');
      return 'Lỗi kết nối đến máy chủ AI. Vui lòng kiểm tra mạng.';
    }
  }
}
