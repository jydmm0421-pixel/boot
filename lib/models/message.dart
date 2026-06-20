/// 消息模型 — 支持文字和图片
class Message {
  final int? id;
  final String sessionId;
  final String role; // 'user' | 'assistant'
  final String messageType; // 'text' | 'image'
  final String content;
  final String? imageBase64; // 图片 base64 数据
  final DateTime createdAt;

  Message({
    this.id,
    required this.sessionId,
    required this.role,
    this.messageType = 'text',
    this.content = '',
    this.imageBase64,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isImage => messageType == 'image';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'session_id': sessionId,
      'role': role,
      'message_type': messageType,
      'content': content,
      'image_base64': imageBase64,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as int?,
      sessionId: map['session_id'] as String,
      role: map['role'] as String,
      messageType: map['message_type'] as String? ?? 'text',
      content: map['content'] as String? ?? '',
      imageBase64: map['image_base64'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Message copyWith({
    int? id,
    String? sessionId,
    String? role,
    String? messageType,
    String? content,
    String? imageBase64,
    DateTime? createdAt,
  }) {
    return Message(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      imageBase64: imageBase64 ?? this.imageBase64,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
