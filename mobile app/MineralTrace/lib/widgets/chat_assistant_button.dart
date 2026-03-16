import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/chat_service.dart';
import 'chat_dialog.dart';

class ChatAssistantButton extends StatefulWidget {
  final String currentContext;

  const ChatAssistantButton({
    super.key,
    this.currentContext = 'general',
  });

  @override
  State<ChatAssistantButton> createState() => _ChatAssistantButtonState();
}

class _ChatAssistantButtonState extends State<ChatAssistantButton> {
  final ChatService _chatService = ChatService();
  int _unreadCount = 0;

  void _openChatDialog() {
    showDialog(
      context: context,
      builder: (context) => ChatDialog(
        chatService: _chatService,
        context: widget.currentContext,
        onClose: () => setState(() => _unreadCount = 0),
      ),
      barrierDismissible: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FloatingActionButton.extended(
          onPressed: _openChatDialog,
          backgroundColor: AppTheme.primaryColor,
          elevation: 6,
          icon: const Icon(Icons.smart_toy_rounded, color: Colors.white),
          label: const Text(
            'AI Help',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (_unreadCount > 0)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                _unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
