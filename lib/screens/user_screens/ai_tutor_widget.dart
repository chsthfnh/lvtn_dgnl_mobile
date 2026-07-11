import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/ai_tutor_service.dart';
import '../globals.dart';

// WIDGET BONG BÓNG CHAT KÉO THẢ ĐƯỢC
class DraggableAITutorWidget extends StatefulWidget {
  final String currentScreen;
  final VoidCallback onClose;

  const DraggableAITutorWidget({
    super.key,
    required this.currentScreen,
    required this.onClose,
  });

  @override
  State<DraggableAITutorWidget> createState() => _DraggableAITutorWidgetState();
}

class _DraggableAITutorWidgetState extends State<DraggableAITutorWidget>
    with SingleTickerProviderStateMixin {
  Offset _position = const Offset(20, 100);
  bool _isDragging = false;
  bool _isOverCloseTarget = false;
  late AITutorService _aiService;

  final double _bubbleSize = 64.0;
  final double _closeTargetSize = 70.0;

  @override
  void initState() {
    super.initState();
    _aiService = AITutorService();
    // Vị trí mặc định ban đầu: Góc dưới bên phải
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      setState(() {
        _position = Offset(size.width - _bubbleSize - 16, size.height - 200);
      });
    });
  }

  void _onPanStart(DragStartDetails details) {
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final size = MediaQuery.of(context).size;
    setState(() {
      _position += details.delta;
      // Khóa không cho bong bóng văng ra ngoài màn hình
      _position = Offset(
        _position.dx.clamp(0.0, size.width - _bubbleSize),
        _position.dy.clamp(0.0, size.height - _bubbleSize),
      );

      // Tính toán vùng va chạm với nút X đỏ
      final closeTargetRect = Rect.fromLTWH(
        (size.width - _closeTargetSize) / 2,
        size.height - 140, // Vị trí nút X ở dưới đáy
        _closeTargetSize,
        _closeTargetSize,
      );
      final bubbleRect = Rect.fromLTWH(
        _position.dx,
        _position.dy,
        _bubbleSize,
        _bubbleSize,
      );

      _isOverCloseTarget = closeTargetRect.overlaps(bubbleRect);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _isDragging = false);

    // Kéo vào X -> Gọi hàm tắt AI
    if (_isOverCloseTarget) {
      widget.onClose();
      return;
    }

    // Hiệu ứng hít vào 2 cạnh màn hình
    final size = MediaQuery.of(context).size;
    final isLeft = _position.dx < size.width / 2;
    setState(() {
      _position = Offset(
        isLeft ? 8.0 : size.width - _bubbleSize - 8.0,
        _position.dy,
      );
    });
  }

  void _openChatBottomSheet() {
    final validContext = navigatorKey.currentContext;
    if (validContext == null) return;

    showModalBottomSheet(
      context: validContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChatInterface(
        aiService: _aiService,
        currentScreen: widget.currentScreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // 1. NÚT X (VÙNG ĐỂ TẮT AI) - CHỈ HIỆN KHI ĐANG KÉO BONG BÓNG
        if (_isDragging)
          Positioned(
            bottom: 70,
            left: (size.width - _closeTargetSize) / 2,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isOverCloseTarget
                  ? _closeTargetSize + 10
                  : _closeTargetSize,
              height: _isOverCloseTarget
                  ? _closeTargetSize + 10
                  : _closeTargetSize,
              decoration: BoxDecoration(
                color: _isOverCloseTarget
                    ? Colors.red
                    : Colors.black.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: _isOverCloseTarget ? 40 : 28,
                ),
              ),
            ),
          ),

        // 2. BONG BÓNG CHAT AI NỔI
        Positioned(
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onTap: _openChatBottomSheet,
            child: AnimatedContainer(
              // Tắt animation khi đang kéo để không bị giật, bật lại khi hít cạnh
              duration: _isDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              width: _bubbleSize,
              height: _bubbleSize,
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 32),
            ),
          ),
        ),
      ],
    );
  }
}

// =========================================================
// GIAO DIỆN CHAT BÊN TRONG BONG BÓNG (Nằm dưới màn hình đẩy lên)
class _ChatInterface extends StatefulWidget {
  final AITutorService aiService;
  final String currentScreen;
  const _ChatInterface({required this.aiService, required this.currentScreen});

  @override
  State<_ChatInterface> createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends State<_ChatInterface> {
  final Color _primary = const Color(0xFF002045);
  final TextEditingController _textCtrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _messages.add({
      'isUser': false,
      'text':
          'Chào bạn! Mình là AI Tutor. Mình thấy bạn đang ở màn hình **${widget.currentScreen}**. Mình có thể giúp gì cho bạn hôm nay?',
    });
  }

  void _handleSend() async {
    String text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'isUser': true, 'text': text});
      _isTyping = true;
      _textCtrl.clear();
    });
    _scrollToBottom();

    String reply = await widget.aiService.sendMessage(
      text,
      widget.currentScreen,
    );

    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add({'isUser': false, 'text': reply});
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.smart_toy,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'AI Tutor',
                      style: TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Danh sách tin nhắn
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                bool isUser = _messages[index]['isUser'];
                return _buildMessageBubble(isUser, _messages[index]['text']);
              },
            ),
          ),

          if (_isTyping)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'AI Tutor đang phân tích...',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

          // Ô nhập liệu
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    decoration: InputDecoration(
                      hintText: 'Nhập câu hỏi hoặc yêu cầu...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _primary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _handleSend,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(bool isUser, String text) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? _primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: isUser
            ? Text(text, style: const TextStyle(color: Colors.white))
            : MarkdownBody(
                data: text,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(color: Colors.black87, height: 1.5),
                ),
              ),
      ),
    );
  }
}
