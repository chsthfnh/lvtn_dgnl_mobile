import 'package:flutter/material.dart';
import '../../../services/hive_service.dart';
import 'real_exam_screen.dart';
import 'offline_real_exam_screen.dart';

class OfflineExamsScreen extends StatefulWidget {
  const OfflineExamsScreen({super.key});

  @override
  State<OfflineExamsScreen> createState() => _OfflineExamsScreenState();
}

class _OfflineExamsScreenState extends State<OfflineExamsScreen> {
  final HiveService _hiveService = HiveService();
  List<Map<String, dynamic>> _offlineExams = [];

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  void _loadExams() {
    setState(() {
      _offlineExams = _hiveService.getDownloadedExams();
    });
  }

  void _deleteExam(String examId) async {
    await _hiveService.deleteOfflineExam(examId);
    _loadExams();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa khỏi máy')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kho Đề Offline',
          style: TextStyle(
            color: Color(0xFF002045),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF002045)),
      ),
      backgroundColor: const Color(0xFFF8F9FF),
      body: _offlineExams.isEmpty
          ? const Center(
              child: Text(
                'Bạn chưa tải đề thi nào.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _offlineExams.length,
              itemBuilder: (context, index) {
                var exam = _offlineExams[index];
                var info = exam['examInfo'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade50,
                      child: const Icon(Icons.quiz, color: Colors.green),
                    ),
                    title: Text(
                      info['tenDeThi'] ?? 'Đề thi',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '${info['thoiGian']} phút • ${info['soCauHoi']} câu\nLưu ngày: ${exam['downloadedAt'].toString().substring(0, 10)}',
                        style: const TextStyle(height: 1.4),
                      ),
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Xóa khỏi máy',
                      onPressed: () => _deleteExam(exam['examId']),
                    ),
                    onTap: () {
                      // 1. Ép kiểu dữ liệu questions từ Hive sang List<Map>
                      List<Map<String, dynamic>> safeQuestions =
                          (exam['questions'] as List)
                              .map((e) => Map<String, dynamic>.from(e as Map))
                              .toList();

                      // 2. Chuyển sang màn hình thi Offline
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OfflineRealExamScreen(
                            examInfo: Map<String, dynamic>.from(info),
                            questions: safeQuestions,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
