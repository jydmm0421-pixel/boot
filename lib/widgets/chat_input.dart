import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// 聊天输入栏 — 支持文字和图片
class ChatInput extends StatefulWidget {
  final Function(String) onSend;
  final Function(File)? onSendImage;
  final bool enabled;

  const ChatInput({
    super.key,
    required this.onSend,
    this.onSendImage,
    this.enabled = true,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _picker = ImagePicker();

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file != null && widget.onSendImage != null) {
      widget.onSendImage!(File(file.path));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 8, top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 图片按钮
          IconButton(
            icon: Icon(Icons.image_outlined, color: Colors.grey[600]),
            onPressed: widget.enabled ? _pickImage : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          // Emoji 按钮
          IconButton(
            icon: Icon(Icons.emoji_emotions_outlined, color: Colors.grey[600]),
            onPressed: () => _controller.text += '😊',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          // 输入框
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              onSubmitted: (_) => _handleSend(),
              decoration: InputDecoration(
                hintText: widget.enabled ? '说点什么...' : '对方正在输入...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15),
                filled: true,
                fillColor: isDark ? Colors.grey[850] : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(fontSize: 15),
            ),
          ),
          const SizedBox(width: 4),
          // 发送按钮
          IconButton(
            icon: const Icon(Icons.send_rounded),
            color: const Color(0xFF07C160),
            onPressed: widget.enabled ? _handleSend : null,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }
}
