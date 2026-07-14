import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminNotificationService {
  // Hàm này gắn vào nút "GỬI THÔNG BÁO" của Admin
  Future<bool> sendNotification({
    required String title,
    required String body,
    required String topic, // Truyền 'new_exam' hoặc 'admin_alerts'
  }) async {
    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid;

      // Admin chỉ việc lưu dữ liệu vào Firestore
      // Cloud Functions (Server) sẽ tự động làm phần còn lại
      await FirebaseFirestore.instance.collection('AdminNotifications').add({
        'title': title,
        'body': body,
        'topic': topic,
        'senderId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Đã đẩy yêu cầu gửi thông báo lên Server!');
      return true;
    } catch (e) {
      debugPrint('Lỗi khi gửi yêu cầu: $e');
      return false;
    }
  }
}
