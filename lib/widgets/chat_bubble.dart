import 'dart:convert';
import 'package:flutter/material.dart';

/// 聊天气泡组件 — 支持文字和图片
class ChatBubble extends StatelessWidget {
  final String content;
  final bool isMe;
  final String? time;
  final String? imageBase64;
  final bool isImage;

  const ChatBubble({
    super.key,
    required this.content,
    required this.isMe,
    this.time,
    this.imageBase64,
    this.isImage = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 对方头像（左侧）
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                child: Icon(
                  Icons.person,
                  size: 20,
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ),

          // 气泡
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? (isDark
                            ? const Color(0xFF1AAD19)
                            : const Color(0xFF95EC69))
                        : (isDark
                            ? Colors.grey[800]
                            : Colors.grey[200]),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                  ),
                  child: isImage && imageBase64 != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(imageBase64!),
                            fit: BoxFit.cover,
                            width: MediaQuery.of(context).size.width * 0.5,
                            errorBuilder: (_, e, s) => const Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : SelectableText(
                          content,
                          style: TextStyle(
                            fontSize: 15,
                            color: isMe
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white : Colors.black87),
                            height: 1.5,
                          ),
                        ),
                ),
                if (time != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                    child: Text(
                      time!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 我的头像（右侧）
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF07C160).withAlpha(200),
                child: const Icon(Icons.person, size: 20, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
