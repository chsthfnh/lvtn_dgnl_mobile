import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';

class HiveService {
  final String boxName = 'offline_exams';

  Map<String, dynamic> _sanitizeData(Map<String, dynamic> data) {
    Map<String, dynamic> safeData = {};
    data.forEach((key, value) {
      if (value is Timestamp) {
        safeData[key] = value
            .toDate()
            .toIso8601String(); // Ép Timestamp thành Chuỗi
      } else {
        safeData[key] = value;
      }
    });
    return safeData;
  }

  // --- 1. LƯU ĐỀ THI VÀ CÂU HỎI VÀO HIVE (DOWNLOAD) ---
  Future<bool> downloadExamForOffline({
    required String examId,
    required Map<String, dynamic> examData,
  }) async {
    try {
      var box = Hive.box(boxName);

      // BƯỚC 1: Làm sạch dữ liệu thông tin Đề thi (thường có trường createdAt)
      Map<String, dynamic> safeExamData = _sanitizeData(examData);

      QuerySnapshot qSnapshot = await FirebaseFirestore.instance
          .collection('Questions')
          .where('examId', isEqualTo: examId)
          .get();

      List<Map<String, dynamic>> questions = [];
      for (var doc in qSnapshot.docs) {
        var qData = doc.data() as Map<String, dynamic>;
        qData['questionId'] = doc.id;

        // BƯỚC 2: Làm sạch dữ liệu từng câu hỏi
        questions.add(_sanitizeData(qData));
      }

      Map<String, dynamic> offlinePackage = {
        'examInfo': safeExamData,
        'questions': questions,
        'downloadedAt': DateTime.now().toIso8601String(),
      };

      await box.put(examId, offlinePackage);
      return true;
    } catch (e) {
      debugPrint('Lỗi tải đề offline: $e');
      return false;
    }
  }

  // 1.5 LƯU BỘ LUYỆN TẬP VÀO HIVE (OFFLINE PRACTICE)
  Future<bool> savePracticeForOffline({
    required String subjectName,
    required List<Map<String, dynamic>> questions,
  }) async {
    try {
      var box = Hive.box(boxName);

      // Tạo một ID độc nhất dựa trên thời gian hiện tại
      String practiceId = 'practice_${DateTime.now().millisecondsSinceEpoch}';

      // Đóng gói dữ liệu (Giả lập cấu trúc giống Đề thi để dùng chung 1 màn hình hiển thị)
      Map<String, dynamic> offlinePackage = {
        'isPractice': true,
        'examInfo': {
          'tenDeThi': 'Luyện tập: $subjectName',
          'thoiGian': questions.length * 2, // Giả sử 2 phút 1 câu
          'soCauHoi': questions.length,
        },
        'questions': questions,
        'downloadedAt': DateTime.now().toIso8601String(),
      };

      await box.put(practiceId, offlinePackage);
      return true;
    } catch (e) {
      debugPrint('Lỗi lưu luyện tập offline: $e');
      return false;
    }
  }

  // 2. LẤY DANH SÁCH CÁC ĐỀ ĐÃ TẢI
  List<Map<String, dynamic>> getDownloadedExams() {
    var box = Hive.box(boxName);
    List<Map<String, dynamic>> exams = [];

    for (var key in box.keys) {
      var data = box.get(key);
      if (data != null) {
        // Gắn thêm key vào để lúc sau biết ID mà mở
        Map<String, dynamic> examMap = Map<String, dynamic>.from(data);
        examMap['examId'] = key;
        exams.add(examMap);
      }
    }
    return exams;
  }

  // 3. XÓA ĐỀ THI KHỎI MÁY ĐỂ GIẢI PHÓNG DUNG LƯỢNG
  Future<void> deleteOfflineExam(String examId) async {
    var box = Hive.box(boxName);
    await box.delete(examId);
  }

  // 4. KIỂM TRA ĐỀ NÀY ĐÃ TẢI CHƯA (Để đổi màu nút Tải về)
  bool isExamDownloaded(String examId) {
    var box = Hive.box(boxName);
    return box.containsKey(examId);
  }

  // --- THÊM HÀM NÀY ĐỂ ĐỔI TÊN BÀI LUYỆN TẬP ---
  Future<void> renameOfflineExam(String examId, String newName) async {
    var box = Hive.box(boxName);
    var data = box.get(examId);

    if (data != null) {
      // Ép kiểu dữ liệu để chỉnh sửa
      Map<String, dynamic> offlinePackage = Map<String, dynamic>.from(data);
      // Cập nhật lại tên
      offlinePackage['examInfo']['tenDeThi'] = newName;
      // Lưu đè lại vào Hive
      await box.put(examId, offlinePackage);
    }
  }
}
