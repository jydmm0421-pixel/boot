/// 记忆模型 — AI 从对话中提取的重要记忆点
class Memory {
  final int? id;
  final String sessionId;
  final String content; // 记忆内容，如"用户讨厌下雨天"
  final int importance; // 重要程度 1-10
  final String? sourceMsgIds; // 从哪些消息中提取的，逗号分隔的id列表
  final DateTime createdAt;

  Memory({
    this.id,
    required this.sessionId,
    required this.content,
    this.importance = 5,
    this.sourceMsgIds,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'session_id': sessionId,
      'content': content,
      'importance': importance,
      'source_msg_ids': sourceMsgIds,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Memory.fromMap(Map<String, dynamic> map) {
    return Memory(
      id: map['id'] as int?,
      sessionId: map['session_id'] as String,
      content: map['content'] as String,
      importance: map['importance'] as int? ?? 5,
      sourceMsgIds: map['source_msg_ids'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
