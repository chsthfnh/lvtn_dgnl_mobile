import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String boxName = 'offline_exams';
  static Future<void>? _initialization;

  String? lastError;

  Future<void> initialize() {
    return _initialization ??= _initializeHive();
  }

  static Future<void> _initializeHive() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
  }

  Box<dynamic> get _box {
    if (!Hive.isBoxOpen(boxName)) {
      throw StateError('Kho đề offline chưa được khởi tạo.');
    }
    return Hive.box(boxName);
  }

  dynamic _sanitizeValue(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is DocumentReference) return value.path;
    if (value is GeoPoint) {
      return {'latitude': value.latitude, 'longitude': value.longitude};
    }
    if (value is List) return value.map(_sanitizeValue).toList();
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key.toString(), _sanitizeValue(item)),
      );
    }
    return value;
  }

  Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is! Map) return <String, dynamic>{};
    return value.map(
      (key, item) => MapEntry(key.toString(), _sanitizeValue(item)),
    );
  }

  Future<List<Map<String, dynamic>>> _loadQuestions(
    String examId,
    Map<String, dynamic> examData,
  ) async {
    final collection = FirebaseFirestore.instance.collection('Questions');
    final orderedIds = ((examData['questions'] as List?) ?? const [])
        .map(
          (value) => value is DocumentReference ? value.id : value.toString(),
        )
        .where((id) => id.isNotEmpty)
        .toList();

    final byId = <String, Map<String, dynamic>>{};

    // Exams.questions là nguồn thứ tự chính. Đọc theo ID giúp đề tải offline
    // giống hệt đề online, kể cả khi câu hỏi không có trường maDeThi.
    for (var start = 0; start < orderedIds.length; start += 20) {
      final end = (start + 20 < orderedIds.length)
          ? start + 20
          : orderedIds.length;
      final ids = orderedIds.sublist(start, end);
      final snapshots = await Future.wait(
        ids.map((id) => collection.doc(id).get()),
      );
      for (final doc in snapshots) {
        if (!doc.exists || doc.data() == null) continue;
        byId[doc.id] = {..._asStringMap(doc.data()), 'questionId': doc.id};
      }
    }

    // Tương thích dữ liệu cũ chỉ liên kết bằng maDeThi.
    if (byId.isEmpty) {
      final fallback = await collection
          .where('maDeThi', isEqualTo: examId)
          .get();
      for (final doc in fallback.docs) {
        byId.putIfAbsent(
          doc.id,
          () => {..._asStringMap(doc.data()), 'questionId': doc.id},
        );
      }
    }

    if (orderedIds.isEmpty) return byId.values.toList();

    final ordered = <Map<String, dynamic>>[];
    for (final id in orderedIds) {
      final question = byId.remove(id);
      if (question != null) ordered.add(question);
    }
    ordered.addAll(byId.values);
    return ordered;
  }

  Future<bool> downloadExamForOffline({
    required String examId,
    required Map<String, dynamic> examData,
  }) async {
    lastError = null;
    try {
      await initialize();
      final questions = await _loadQuestions(examId, examData);
      if (questions.isEmpty) {
        lastError = 'Không tìm thấy câu hỏi của đề thi này.';
        return false;
      }

      final safeExamData = _asStringMap(examData);
      safeExamData['soCauHoi'] = questions.length;
      await _box.put(examId, {
        'examId': examId,
        'examInfo': safeExamData,
        'questions': _sanitizeValue(questions),
        'downloadedAt': DateTime.now().toIso8601String(),
        'progress': null,
      });
      return true;
    } catch (e, stackTrace) {
      lastError = 'Không thể lưu đề vào thiết bị: $e';
      debugPrint('Lỗi tải đề offline: $e\n$stackTrace');
      return false;
    }
  }

  Future<bool> savePracticeForOffline({
    required String subjectName,
    required List<Map<String, dynamic>> questions,
  }) async {
    lastError = null;
    try {
      await initialize();
      final practiceId = 'practice_${DateTime.now().millisecondsSinceEpoch}';
      await _box.put(practiceId, {
        'examId': practiceId,
        'isPractice': true,
        'examInfo': {
          'tenDeThi': 'Luyện tập: $subjectName',
          'thoiGian': questions.length * 2,
          'soCauHoi': questions.length,
        },
        'questions': _sanitizeValue(questions),
        'downloadedAt': DateTime.now().toIso8601String(),
        'progress': null,
      });
      return true;
    } catch (e) {
      lastError = 'Không thể lưu bài luyện tập: $e';
      debugPrint(lastError);
      return false;
    }
  }

  List<Map<String, dynamic>> getDownloadedExams() {
    if (!Hive.isBoxOpen(boxName)) return [];
    final exams = <Map<String, dynamic>>[];
    for (final key in _box.keys) {
      final data = _box.get(key);
      if (data == null) continue;
      final exam = _asStringMap(data);
      exam['examId'] = key.toString();
      exams.add(exam);
    }
    exams.sort(
      (a, b) => (b['downloadedAt'] ?? '').toString().compareTo(
        (a['downloadedAt'] ?? '').toString(),
      ),
    );
    return exams;
  }

  Future<void> deleteOfflineExam(String examId) async {
    await initialize();
    await _box.delete(examId);
  }

  bool isExamDownloaded(String examId) {
    return Hive.isBoxOpen(boxName) && _box.containsKey(examId);
  }

  Future<void> saveOfflineProgress({
    required String examId,
    required int currentIndex,
    required Map<int, int> userAnswers,
    required int secondsRemaining,
  }) async {
    await initialize();
    final package = _asStringMap(_box.get(examId));
    if (package.isEmpty) return;
    package['progress'] = {
      'currentIndex': currentIndex,
      'userAnswers': userAnswers.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'secondsRemaining': secondsRemaining,
      'savedAt': DateTime.now().toIso8601String(),
    };
    await _box.put(examId, package);
  }

  Map<String, dynamic>? getOfflineProgress(String examId) {
    if (!Hive.isBoxOpen(boxName)) return null;
    final package = _asStringMap(_box.get(examId));
    final progress = package['progress'];
    if (progress is! Map) return null;
    return _asStringMap(progress);
  }

  Future<void> clearOfflineProgress(String examId) async {
    await initialize();
    final package = _asStringMap(_box.get(examId));
    if (package.isEmpty) return;
    package['progress'] = null;
    await _box.put(examId, package);
  }

  Future<void> saveOfflineResult({
    required String examId,
    required int correctAnswers,
    required int totalQuestions,
  }) async {
    await initialize();
    final package = _asStringMap(_box.get(examId));
    if (package.isEmpty) return;
    package['progress'] = null;
    package['lastResult'] = {
      'correctAnswers': correctAnswers,
      'totalQuestions': totalQuestions,
      'completedAt': DateTime.now().toIso8601String(),
    };
    await _box.put(examId, package);
  }

  Future<void> renameOfflineExam(String examId, String newName) async {
    await initialize();
    final package = _asStringMap(_box.get(examId));
    if (package.isEmpty) return;
    final examInfo = _asStringMap(package['examInfo']);
    examInfo['tenDeThi'] = newName.trim();
    package['examInfo'] = examInfo;
    await _box.put(examId, package);
  }
}
