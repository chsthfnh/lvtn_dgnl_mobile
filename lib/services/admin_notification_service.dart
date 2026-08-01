import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminNotificationService {
  String? lastError;

  // Hàm này gắn vào nút "GỬI THÔNG BÁO" của Admin
  Future<bool> sendNotification({
    required String title,
    required String body,
    required String topic, // Truyền 'new_exam' hoặc 'admin_alerts'
  }) async {
    lastError = null;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        lastError = 'Phiên đăng nhập đã hết. Vui lòng đăng nhập lại.';
        return false;
      }

      final firestore = FirebaseFirestore.instance;
      final notificationRef = firestore.collection('Notifications').doc();
      final requestRef = firestore.collection('AdminNotifications').doc();
      final notificationType = topic == 'new_exam' ? 'new_exam' : 'admin_news';

      // Một batch tạo đồng thời thông báo trong ứng dụng và yêu cầu gửi FCM.
      // Vì Dashboard đọc Notifications nên thông báo sẽ xuất hiện ngay cả khi
      // Cloud Function chưa được triển khai hoặc đang chậm.
      final batch = firestore.batch();
      batch.set(notificationRef, {
        'title': title,
        'content': body,
        'body': body,
        'type': notificationType,
        'topic': topic,
        'senderId': uid,
        'readBy': <String>[],
        'deletedBy': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.set(requestRef, {
        'title': title,
        'content': body,
        'body': body,
        'topic': topic,
        'senderId': uid,
        'adminId': uid,
        'notificationId': notificationRef.id,
        'status': 'queued',
        'requestedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      debugPrint('Đã tạo thông báo và yêu cầu gửi FCM.');
      return true;
    } catch (e) {
      lastError = e.toString();
      debugPrint('Lỗi khi gửi yêu cầu: $e');
      return false;
    }
  }
}
