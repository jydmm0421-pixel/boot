// 聊天记录解析工具：提取说话人、过滤消息

/// 解析结果
class ChatParseResult {
  final List<Speaker> speakers;
  final String rawText;

  const ChatParseResult({required this.speakers, required this.rawText});
}

/// 说话人信息
class Speaker {
  final String name;
  final int messageCount;
  final List<String> sampleMessages; // 前几条消息样本

  const Speaker({
    required this.name,
    required this.messageCount,
    this.sampleMessages = const [],
  });
}

/// 从聊天文本中提取所有说话人
ChatParseResult parseChat(String text) {
  if (text.trim().isEmpty) {
    return const ChatParseResult(speakers: [], rawText: '');
  }

  final lines = text.split('\n');
  final speakerMap = <String, _SpeakerData>{};

  // 匹配常见聊天格式:
  // - "名字: 消息" / "名字：消息"
  // - "名字 时间 消息" (如微信PC版导出)
  // - "yyyy-MM-dd HH:mm:ss 名字\n消息"
  final patterns = [
    RegExp(r'^(\S{1,20})[:：]\s*(.+)$'), // 名字: 消息
    RegExp(r'^\S{1,20}\s+\d{1,2}[:：]\d{2}'), // 名字 12:00 (忽略)
  ];

  String? currentSpeaker; // 追踪多行消息的说话人

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    // 尝试匹配 "名字: 消息" 格式
    final match = patterns[0].firstMatch(trimmed);
    if (match != null) {
      final name = match.group(1)!.trim();
      final msg = match.group(2)!.trim();
      if (name.isNotEmpty && msg.isNotEmpty && name.length <= 20) {
        currentSpeaker = name;
        final data = speakerMap.putIfAbsent(name, () => _SpeakerData(name));
        data.messageCount++;
        if (data.messages.length < 3) data.messages.add(msg);
        continue;
      }
    }

    // 如果当前行没有匹配到说话人但之前有currentSpeaker
    // 这行可能是多行消息的继续
    if (currentSpeaker != null && trimmed.isNotEmpty) {
      // 是上一个人的续行，不改变说话人
    }
  }

  // 按消息数排序
  final speakers = speakerMap.values
      .where((s) => s.messageCount > 0)
      .toList()
    ..sort((a, b) => b.messageCount.compareTo(a.messageCount));

  return ChatParseResult(
    speakers: speakers
        .map((s) => Speaker(
              name: s.name,
              messageCount: s.messageCount,
              sampleMessages: s.messages,
            ))
        .toList(),
    rawText: text,
  );
}

/// 只提取指定说话人的消息内容
String filterMessagesBySpeaker(String text, String speakerName) {
  final lines = text.split('\n');
  final buffer = StringBuffer();
  final pattern = RegExp(r'^(\S{1,20})[:：]\s*(.+)$');

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final match = pattern.firstMatch(trimmed);
    if (match != null) {
      final name = match.group(1)!.trim();
      final msg = match.group(2)!.trim();
      if (name == speakerName) {
        buffer.writeln(msg);
      }
    }
  }

  return buffer.toString();
}

class _SpeakerData {
  final String name;
  int messageCount = 0;
  final List<String> messages = [];

  _SpeakerData(this.name);
}
