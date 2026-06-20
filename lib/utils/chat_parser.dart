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
  // 1. "名字: 消息" / "名字：消息"
  // 2. "yyyy-MM-dd HH:mm:ss 名字: 消息" (微信PC导出)
  // 3. "yyyy-MM-dd HH:mm:ss 名字\n消息" (微信多行导出)
  final nameMsgPattern = RegExp(r'^(\S{1,20})[:：]\s*(.+)$');
  final timeNameMsgPattern = RegExp(r'^\d{2,4}[\/-]\d{1,2}[\/-]\d{1,2}\s+\d{1,2}[:：]\d{2}(?:[:：]\d{2})?\s+(\S{1,20})[:：]\s*(.+)$');
  final timeNamePattern = RegExp(r'^\d{2,4}[\/-]\d{1,2}[\/-]\d{1,2}\s+\d{1,2}[:：]\d{2}(?:[:：]\d{2})?\s+(\S{1,20})\s*$');

  String? currentSpeaker;

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    // 格式2: "yyyy-MM-dd HH:mm:ss 名字: 消息"
    final match2 = timeNameMsgPattern.firstMatch(trimmed);
    if (match2 != null) {
      final name = match2.group(1)!.trim();
      final msg = match2.group(2)!.trim();
      if (name.isNotEmpty && msg.isNotEmpty && _isValidSpeaker(name)) {
        currentSpeaker = name;
        _addMessage(speakerMap, name, msg);
        continue;
      }
    }

    // 格式3: "yyyy-MM-dd HH:mm:ss 名字" (单独一行，消息在下一行)
    final match3 = timeNamePattern.firstMatch(trimmed);
    if (match3 != null) {
      final name = match3.group(1)!.trim();
      if (_isValidSpeaker(name)) {
        currentSpeaker = name;
        speakerMap.putIfAbsent(name, () => _SpeakerData(name));
        continue;
      }
    }

    // 格式1: "名字: 消息"
    final match1 = nameMsgPattern.firstMatch(trimmed);
    if (match1 != null) {
      final name = match1.group(1)!.trim();
      final msg = match1.group(2)!.trim();
      if (name.isNotEmpty && msg.isNotEmpty && _isValidSpeaker(name)) {
        currentSpeaker = name;
        _addMessage(speakerMap, name, msg);
        continue;
      }
    }

    // 多行消息的续行：属于 currentSpeaker
    if (currentSpeaker != null && trimmed.isNotEmpty && !_isSystemLine(trimmed)) {
      final data = speakerMap[currentSpeaker];
      if (data != null) {
        data.messageCount++;
        if (data.messages.length < 3) {
          data.messages.add(trimmed);
        }
      }
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

  // 格式1: "名字: 消息"
  final nameMsgPattern = RegExp(r'^(\S{1,20})[:：]\s*(.+)$');
  // 格式2: "yyyy-MM-dd HH:mm:ss 名字: 消息"
  final timeNameMsgPattern = RegExp(r'^\d{2,4}[\/-]\d{1,2}[\/-]\d{1,2}\s+\d{1,2}[:：]\d{2}(?:[:：]\d{2})?\s+(\S{1,20})[:：]\s*(.+)$');
  // 格式3: "yyyy-MM-dd HH:mm:ss 名字" (消息在下一行)
  final timeNamePattern = RegExp(r'^\d{2,4}[\/-]\d{1,2}[\/-]\d{1,2}\s+\d{1,2}[:：]\d{2}(?:[:：]\d{2})?\s+(\S{1,20})\s*$');

  String? currentSpeaker;

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (_isSystemLine(trimmed)) continue;

    // 格式2: 时间戳+名字+消息
    final m2 = timeNameMsgPattern.firstMatch(trimmed);
    if (m2 != null) {
      final name = m2.group(1)!.trim();
      final msg = m2.group(2)!.trim();
      currentSpeaker = name;
      if (name == speakerName) buffer.writeln(msg);
      continue;
    }

    // 格式3: 时间戳+名字
    final m3 = timeNamePattern.firstMatch(trimmed);
    if (m3 != null) {
      currentSpeaker = m3.group(1)!.trim();
      continue;
    }

    // 格式1: 名字: 消息
    final m1 = nameMsgPattern.firstMatch(trimmed);
    if (m1 != null) {
      final name = m1.group(1)!.trim();
      final msg = m1.group(2)!.trim();
      currentSpeaker = name;
      if (name == speakerName) buffer.writeln(msg);
      continue;
    }

    // 多行续行：属于 currentSpeaker
    if (currentSpeaker == speakerName) {
      buffer.writeln(trimmed);
    }
  }

  return buffer.toString();
}

void _addMessage(Map<String, _SpeakerData> map, String name, String msg) {
  final data = map.putIfAbsent(name, () => _SpeakerData(name));
  data.messageCount++;
  if (data.messages.length < 3) data.messages.add(msg);
}

class _SpeakerData {
  final String name;
  int messageCount = 0;
  final List<String> messages = [];

  _SpeakerData(this.name);
}

/// 判断是否为系统消息行（日期分隔符、系统提示等）
bool _isSystemLine(String line) {
  if (line.startsWith('【') && line.endsWith('】')) return true; // 【表情包】
  if (RegExp(r'^\d{2,4}[\/-]\d{1,2}[\/-]\d{1,2}').hasMatch(line)) return true; // 日期行
  return false;
}

/// 校验是否为有效的说话人名称
bool _isValidSpeaker(String name) {
  // 过滤掉明显不是人名的内容
  if (name.contains('://')) return false;    // URL
  if (name.contains('@')) return false;       // 邮箱
  if (name.contains('.com')) return false;    // 域名
  if (name.contains('.cn')) return false;     // 域名
  if (name.contains('http')) return false;    // URL
  if (name.contains('www.')) return false;    // URL
  if (name.contains('ftp')) return false;     // FTP

  // 过滤纯数字/日期格式
  if (RegExp(r'^\d{2,4}[-/年]\d{1,2}[-/月]\d{1,2}').hasMatch(name)) return false;
  if (RegExp(r'^\d{1,2}[:：]\d{2}').hasMatch(name)) return false;

  // 名称中至少包含一个中文或字母
  if (!RegExp(r'[一-鿿\w]').hasMatch(name)) return false;

  return true;
}
