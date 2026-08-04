import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../ai_screens/ai_explain_widget.dart';

String _normalizeQuestionDisplayText(String text) {
  final parts = text.split(r'$');
  for (int i = 0; i < parts.length; i += 2) {
    var plainText = parts[i]
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('\uF0CE', '∈')
        .replaceAll('\uF02D', '−')
        .replaceAll('\uF03D', '=')
        .replaceAll('\uF0C6', '∅')
        .replaceAll(r'\_', '_')
        .replaceAll(r'\%', '%')
        .replaceAll(r'\#', '#')
        .replaceAll(r'\&', '&');
    plainText = plainText.replaceAllMapped(
      RegExp(r'<sup>\s*0\s*</sup>\s*(\d+(?:[.,]\d+)?)', caseSensitive: false),
      (match) => '\$${match.group(1)}^{\\circ}\$',
    );
    parts[i] = plainText;
  }
  return parts.join(r'$');
}

class DetailedAnswerScreen extends StatelessWidget {
  final List<dynamic> questions;
  final Map<int, int> userAnswers;

  const DetailedAnswerScreen({
    super.key,
    required this.questions,
    required this.userAnswers,
  });

  final Color _primary = const Color(0xFF002045);
  final Color _correctGreen = const Color(0xFF006E2F);
  final Color _errorRed = const Color(0xFFBA1A1A);
  static final Map<String, Future<String>> _imageFutures = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Đáp án chi tiết',
          style: TextStyle(
            color: _primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: questions.length,
        itemBuilder: (context, index) {
          var question = questions[index];
          Map<String, dynamic> data = question is DocumentSnapshot
              ? question.data() as Map<String, dynamic>
              : question as Map<String, dynamic>;
          int? userAnsIdx = userAnswers[index];

          // Lớp khiên 1: Xử lý an toàn nếu không có đáp án đúng
          String correctLetter =
              data['correctAnswer']?.toString().trim() ?? 'A';
          if (correctLetter.isEmpty) correctLetter = 'A';
          int correctIdx = correctLetter.codeUnitAt(0) - 65; // A->0, B->1...

          bool isCorrect = userAnsIdx == correctIdx;

          // Lớp khiên 2: Xử lý an toàn nếu không có mảng options
          List<dynamic> options = data['options'] ?? [];

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCorrect
                    ? _correctGreen.withOpacity(0.3)
                    : _errorRed.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Câu số + Trạng thái
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Câu ${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? _correctGreen.withOpacity(0.1)
                            : _errorRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCorrect ? 'CHÍNH XÁC' : 'SAI RỒI',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isCorrect ? _correctGreen : _errorRed,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Nội dung câu hỏi
                _buildMathText(
                  data['noiDungCauHoi'] ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (data['anhCauHoi'] != null &&
                    data['anhCauHoi'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildImage(data['anhCauHoi']),
                ],
                const SizedBox(height: 16),

                // Danh sách đáp án (Sử dụng options.length cực kỳ an toàn)
                Column(
                  children: List.generate(options.length, (optIdx) {
                    bool isUserChoice = userAnsIdx == optIdx;
                    bool isRightAns = correctIdx == optIdx;

                    Color itemColor = Colors.grey.shade100;
                    Color textColor = Colors.black87;
                    IconData? icon;

                    if (isRightAns) {
                      itemColor = _correctGreen.withOpacity(0.1);
                      textColor = _correctGreen;
                      icon = Icons.check_circle;
                    } else if (isUserChoice && !isCorrect) {
                      itemColor = _errorRed.withOpacity(0.1);
                      textColor = _errorRed;
                      icon = Icons.cancel;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: itemColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isRightAns
                              ? _correctGreen
                              : isUserChoice
                              ? _errorRed
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${String.fromCharCode(65 + optIdx)}.',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMathText(
                              options[optIdx].toString(),
                              style: TextStyle(color: textColor),
                            ),
                          ),
                          if (icon != null)
                            Icon(icon, size: 18, color: textColor),
                        ],
                      ),
                    );
                  }),
                ),

                // ĐÂY LÀ PHẦN THÊM MỚI: RÁP NÚT AI TUTOR VÀO NẾU LÀM SAI
                if (!isCorrect) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AITutorExplainButton(
                      // Truyền nội dung câu hỏi
                      questionContent: data['noiDungCauHoi'] ?? '',

                      // Trích xuất đáp án đúng dạng Text (thay vì index)
                      correctAnswer:
                          options.isNotEmpty &&
                              correctIdx >= 0 &&
                              correctIdx < options.length
                          ? options[correctIdx].toString()
                          : 'Chưa cập nhật',

                      // Trích xuất đáp án người dùng dạng Text
                      userAnswer:
                          userAnsIdx != null &&
                              userAnsIdx >= 0 &&
                              userAnsIdx < options.length
                          ? options[userAnsIdx].toString()
                          : 'Bạn chưa chọn đáp án',
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // --- THUẬT TOÁN RENDER TOÁN HỌC (TEXT.RICH + FITTEDBOX SIÊU BỀN BỈ) ---
  Widget _buildMathText(String text, {TextStyle? style}) {
    text = _normalizeQuestionDisplayText(text);
    if (!text.contains('\$')) return Text(text, style: style);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Đề phòng lỗi constraint vô cực, lấy không gian an toàn của màn hình
        double maxWidth = constraints.maxWidth == double.infinity
            ? MediaQuery.of(context).size.width - 60
            : constraints.maxWidth;

        List<String> parts = text.split('\$');
        List<InlineSpan> spans = [];

        for (int i = 0; i < parts.length; i++) {
          if (i % 2 == 0) {
            // Phần chữ bình thường
            if (parts[i].isNotEmpty) spans.add(TextSpan(text: parts[i]));
          } else {
            // Phần công thức Toán học
            String mathCode = parts[i]
                .trim()
                .replaceAll('–', '-')
                .replaceAll('—', '-');
            if (mathCode.isEmpty) continue;

            spans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: FittedBox(
                    fit: BoxFit
                        .scaleDown, // Tự động thu nhỏ nếu công thức quá dài
                    alignment: Alignment.centerLeft,
                    child: Math.tex(
                      mathCode,
                      textStyle: style,
                      mathStyle: MathStyle.text,
                    ),
                  ),
                ),
              ),
            );
          }
        }

        // Trả về một khối văn bản duy nhất kết hợp cả chữ và Toán
        return Text.rich(TextSpan(children: spans), style: style);
      },
    );
  }

  Future<String> _resolveImageUrl(String imageValue) async {
    final value = imageValue.trim();

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }

    if (value.startsWith('gs://')) {
      return FirebaseStorage.instance.refFromURL(value).getDownloadURL();
    }

    final rawName = value.startsWith('QuestionImages/')
        ? value.substring('QuestionImages/'.length)
        : value;
    final candidateNames = <String>{rawName};
    final hasImageExtension = RegExp(
      r'\.(png|jpe?g|webp|gif)$',
      caseSensitive: false,
    ).hasMatch(rawName);

    if (!hasImageExtension) {
      candidateNames.addAll(['$rawName.png', '$rawName.jpg', '$rawName.jpeg']);
      final underscoreName = rawName.replaceAllMapped(
        RegExp(r'(\d)\.(\d)'),
        (match) => '${match.group(1)}_${match.group(2)}',
      );
      final dashName = rawName.replaceAllMapped(
        RegExp(r'(\d)\.(\d)'),
        (match) => '${match.group(1)}-${match.group(2)}',
      );
      candidateNames.addAll(['$underscoreName.png', '$dashName.png']);
    }

    Object? lastError;
    for (final candidate in candidateNames) {
      try {
        return await FirebaseStorage.instance
            .ref('QuestionImages/$candidate')
            .getDownloadURL();
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? StateError('Tên ảnh không hợp lệ: $imageValue');
  }

  Future<String> _getImageUrl(String imageValue) {
    return _imageFutures.putIfAbsent(
      imageValue,
      () => _resolveImageUrl(imageValue),
    );
  }

  ImageProvider _optimizedImageProvider(String url) {
    final networkImage = NetworkImage(url);
    return kIsWeb
        ? networkImage
        : ResizeImage.resizeIfNeeded(1600, null, networkImage);
  }

  Widget _buildImage(String imageName) {
    return FutureBuilder<String>(
      future: _getImageUrl(imageName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image(
              image: _optimizedImageProvider(snapshot.data!),
              width: double.infinity,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                final expected = progress.expectedTotalBytes;
                final value = expected == null
                    ? null
                    : progress.cumulativeBytesLoaded / expected;
                return Container(
                  constraints: const BoxConstraints(minHeight: 140),
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(value: value),
                );
              },
              errorBuilder: (context, error, stackTrace) => Text(
                '[Không tải được ảnh: $imageName]',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Text(
            '[Lỗi lấy URL ảnh: $imageName]',
            style: const TextStyle(color: Colors.red),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
