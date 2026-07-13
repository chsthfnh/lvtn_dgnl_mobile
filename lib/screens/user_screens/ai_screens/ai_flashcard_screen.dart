import 'package:flutter/material.dart';
import 'dart:math';
import '../../../services/ai_tutor_service.dart';

class AIFlashcardScreen extends StatefulWidget {
  const AIFlashcardScreen({super.key});

  @override
  State<AIFlashcardScreen> createState() => _AIFlashcardScreenState();
}

class _AIFlashcardScreenState extends State<AIFlashcardScreen> {
  final TextEditingController _topicCtrl = TextEditingController();
  final AITutorService _aiService = AITutorService();

  bool _isLoading = false;
  List<Map<String, String>> _flashcards = [];
  final PageController _pageController = PageController(viewportFraction: 0.85);

  Future<void> _generateCards() async {
    if (_topicCtrl.text.trim().isEmpty) return;

    // Thu gọn bàn phím
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _flashcards.clear();
    });

    List<Map<String, String>> results = await _aiService.generateFlashcards(
      topicContent: _topicCtrl.text.trim(),
    );

    if (mounted) {
      setState(() {
        _flashcards = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF002045)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'AI Flashcard Maker',
          style: TextStyle(
            color: Color(0xFF002045),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // KHU VỰC NHẬP LIỆU
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nhập chủ đề hoặc dán đoạn văn vào đây:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF002045),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _topicCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText:
                        'Ví dụ: Tóm tắt các công thức Động học chất điểm, hoặc dán một đoạn văn lịch sử...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE65100)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _generateCards,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      _isLoading
                          ? 'AI đang tạo thẻ...'
                          : 'Tự động tạo Flashcard',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // KHU VỰC HIỂN THỊ THẺ (PAGE VIEW)
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Text(
                      'Đang trích xuất từ khóa quan trọng...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : _flashcards.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.style,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Chưa có thẻ nào được tạo',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Chạm vào thẻ để lật • Vuốt ngang để chuyển',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 350,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _flashcards.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: _FlipCardWidget(
                                frontText: _flashcards[index]['front'] ?? '',
                                backText: _flashcards[index]['back'] ?? '',
                                cardNumber:
                                    '${index + 1}/${_flashcards.length}',
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// WIDGET XỬ LÝ HIỆU ỨNG LẬT THẺ 3D
// ==========================================
class _FlipCardWidget extends StatefulWidget {
  final String frontText;
  final String backText;
  final String cardNumber;

  const _FlipCardWidget({
    required this.frontText,
    required this.backText,
    required this.cardNumber,
  });

  @override
  State<_FlipCardWidget> createState() => _FlipCardWidgetState();
}

class _FlipCardWidgetState extends State<_FlipCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _isFront = !_isFront;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flipCard,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          // Xác định xem đang ở mặt trước hay mặt sau dựa vào góc lật
          final isUnder = angle > pi / 2;

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Thêm phối cảnh 3D
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isUnder
                ? Transform(
                    // Lật ngược lại text ở mặt sau để không bị ngược chữ
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: _buildCardFace(isFront: false),
                  )
                : _buildCardFace(isFront: true),
          );
        },
      ),
    );
  }

  Widget _buildCardFace({required bool isFront}) {
    return Container(
      decoration: BoxDecoration(
        color: isFront ? const Color(0xFF002045) : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(24),
        border: isFront
            ? null
            : Border.all(color: Colors.orange.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 20,
            right: 20,
            child: Text(
              widget.cardNumber,
              style: TextStyle(
                color: isFront ? Colors.white54 : Colors.orange.shade400,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isFront ? Icons.help_outline : Icons.lightbulb,
                    color: isFront ? Colors.white30 : Colors.orange.shade300,
                    size: 48,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isFront ? widget.frontText : widget.backText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isFront ? Colors.white : const Color(0xFF002045),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
