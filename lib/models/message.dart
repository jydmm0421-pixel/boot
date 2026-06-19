/// 消息模型
class Message {
  final int? id;
  final String sessionId;
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime createdAt;

  Message({
    this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'session_id': sessionId,
      'role': role,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as int?,
      sessionId: map['session_id'] as String,
      role: map['role'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Message copyWith({
    int? id,
    String? sessionId,
    String? role,
    String? content,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
