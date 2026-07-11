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

    String contextData = 'Màn hình hiện tại: $screenName.\n';
    try {
      // Ví dụ: Lấy tổng quan điểm số để AI biết năng lực của user
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        contextData += 'Mục tiêu điểm: ${data['targetScore'] ?? 900}.\n';
      }

      // Lấy Level hiện tại
      DocumentSnapshot progressDoc = await FirebaseFirestore.instance
          .collection('UserProgress')
          .doc(uid)
          .get();
      if (progressDoc.exists && progressDoc.data() != null) {
        var pData = progressDoc.data() as Map<String, dynamic>;
        contextData += 'Tiến độ Cấp độ (Gamification): $pData.\n';
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
}
