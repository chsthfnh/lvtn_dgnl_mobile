import 'package:flutter/material.dart';
import '../../../services/hive_service.dart';
import 'offline_real_exam_screen.dart';

class OfflineExamsScreen extends StatefulWidget {
  const OfflineExamsScreen({super.key});

  @override
  State<OfflineExamsScreen> createState() => _OfflineExamsScreenState();
}

class _OfflineExamsScreenState extends State<OfflineExamsScreen> {
  final HiveService _hiveService = HiveService();
  List<Map<String, dynamic>> _offlineExams = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    try {
      await _hiveService.initialize();
      final exams = _hiveService.getDownloadedExams();
      if (!mounted) return;
      setState(() {
        _offlineExams = exams;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Không thể mở kho đề offline: $e';
      });
    }
  }

  Future<void> _deleteExam(String examId, String examName) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa đề khỏi thiết bị?'),
        content: Text('Đề “$examName” và tiến độ đang lưu sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (accepted != true) return;

    await _hiveService.deleteOfflineExam(examId);
    await _loadExams();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa đề khỏi thiết bị.')));
    }
  }

  String _dateLabel(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return 'Không rõ';
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kho đề offline',
          style: TextStyle(
            color: Color(0xFF002045),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF002045)),
      ),
      backgroundColor: const Color(0xFFF6F8FC),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.storage_outlined, size: 54, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadExams,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }
    if (_offlineExams.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_download_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 14),
              Text(
                'Chưa có đề thi offline',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 6),
              Text(
                'Mở chi tiết một đề và chọn “Tải về” khi đang có mạng.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadExams,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _offlineExams.length,
        itemBuilder: (context, index) {
          final exam = _offlineExams[index];
          final info = Map<String, dynamic>.from(exam['examInfo'] as Map);
          final progress = exam['progress'] is Map
              ? Map<String, dynamic>.from(exam['progress'] as Map)
              : null;
          final lastResult = exam['lastResult'] is Map
              ? Map<String, dynamic>.from(exam['lastResult'] as Map)
              : null;
          final answers = progress?['userAnswers'] is Map
              ? Map<dynamic, dynamic>.from(progress!['userAnswers'] as Map)
              : const <dynamic, dynamic>{};
          final total =
              (info['soCauHoi'] as num?)?.toInt() ??
              ((exam['questions'] as List?)?.length ?? 0);
          final ratio = total == 0 ? 0.0 : answers.length / total;
          final name = (info['tenDeThi'] ?? 'Đề thi').toString();

          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE4E7EC)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final safeQuestions = ((exam['questions'] as List?) ?? const [])
                    .map((item) => Map<String, dynamic>.from(item as Map))
                    .toList();
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OfflineRealExamScreen(
                      examId: exam['examId'].toString(),
                      examInfo: info,
                      questions: safeQuestions,
                    ),
                  ),
                );
                await _loadExams();
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFFE8F5E9),
                          child: Icon(Icons.download_done, color: Colors.green),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${info['thoiGian'] ?? 0} phút • $total câu • tải ${_dateLabel(exam['downloadedAt'])}',
                                style: const TextStyle(
                                  color: Color(0xFF667085),
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'delete') {
                              _deleteExam(exam['examId'].toString(), name);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Xóa khỏi máy'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: 14),
                      LinearProgressIndicator(
                        value: ratio.clamp(0.0, 1.0).toDouble(),
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'Đã lưu tiến độ: ${answers.length}/$total câu • Nhấn để tiếp tục',
                        style: const TextStyle(
                          color: Color(0xFF175CD3),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ] else if (lastResult != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Lần gần nhất: ${lastResult['correctAnswers']}/${lastResult['totalQuestions']} câu đúng',
                        style: const TextStyle(
                          color: Color(0xFF027A48),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
