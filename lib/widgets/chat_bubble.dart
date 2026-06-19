import 'package:flutter/material.dart';

/// 聊天气泡组件
class ChatBubble extends StatelessWidget {
  final String content;
  final bool isMe; // true = 我的消息（右对齐绿色），false = 对方消息（左对齐灰色）
  final String? time;

  const ChatBubble({
    super.key,
    required this.content,
    required this.isMe,
    this.time,
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
                  child: SelectableText(
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
