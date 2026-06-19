import 'dart:convert';
import '../models/message.dart';
import '../models/memory.dart';
import 'database_service.dart';
import 'llm_service.dart';

/// 记忆系统：自动存储、智能提取、上下文召回
class MemoryService {
  final DatabaseService _db = DatabaseService();
  final LlmService _llm = LlmService();

  /// 存储一条消息
  Future<void> saveMessage(Message msg) async {
    await _db.insertMessage(msg);
  }

  /// 获取最近的对话历史
  Future<List<Message>> getRecentHistory(String sessionId, {int count = 40}) async {
    return await _db.getRecentMessages(sessionId, count: count);
  }

  /// 获取所有消息数量
  Future<int> getMessageCount(String sessionId) async {
    return await _db.getMessageCount(sessionId);
  }

  /// 获取所有记忆
  Future<List<Memory>> getAllMemories(String sessionId) async {
    return await _db.getMemories(sessionId);
  }

  /// 删除某条记忆
  Future<void> deleteMemory(int id) async {
    await _db.deleteMemory(id);
  }

  /// 获取记忆数量
  Future<int> getMemoryCount(String sessionId) async {
    return await _db.getMemoryCount(sessionId);
  }

  /// 检查最近对话，自动提取新记忆
  /// 每 N 轮对话触发一次
  Future<List<Memory>> autoExtractMemories(
    String sessionId, {
    int checkInterval = 8,
  }) async {
    final msgCount = await _db.getMessageCount(sessionId);

    // 每 checkInterval 条消息检查一次
    if (msgCount % checkInterval != 0) return [];

    // 获取最近的对话
    final recent = await _db.getRecentMessages(sessionId, count: 20);
    if (recent.length < 4) return [];

    // 调用 LLM 提取记忆
    final result = await _llm.extractMemory(recent);
    if (result == null) return [];

    try {
      final data = jsonDecode(_cleanJson(result));
      if (data['has_memory'] != true) return [];

      final newMemories = <Memory>[];
      for (final mem in data['memories'] ?? []) {
        final content = mem['content'] as String?;
        final importance = mem['importance'] as int? ?? 5;
        if (content != null && content.isNotEmpty) {
          final memory = Memory(
            sessionId: sessionId,
            content: content,
            importance: importance,
            sourceMsgIds: recent.map((m) => m.id?.toString()).join(','),
          );
          await _db.insertMemory(memory);
          newMemories.add(memory);
        }
      }
      return newMemories;
    } catch (_) {
      return [];
    }
  }

  /// 获取与当前话题相关的记忆（简单关键词匹配 + 重要性排序）
  Future<List<Memory>> getRelevantMemories(
    String sessionId, {
    String? userInput,
    int count = 10,
  }) async {
    final allMemories = await _db.getTopMemories(sessionId, 100);
    if (allMemories.isEmpty) return [];

    // 如果没有用户输入，返回最重要的记忆
    if (userInput == null || userInput.isEmpty) {
      return allMemories.take(count).toList();
    }

    // 简单关键词匹配
    final keywords = userInput.split('').toSet().toList();
    final scored = <Memory, int>{};

    for (final mem in allMemories) {
      int score = mem.importance;
      final content = mem.content;
      for (final kw in keywords) {
        if (content.contains(kw)) score += 1;
      }
      scored[mem] = score;
    }

    // 按分数排序取前 count
    final sorted = scored.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(count).map((e) => e.key).toList();
  }

  /// 构建记忆上下文文本（用于注入 system prompt）
  String buildMemoryContext(List<Memory> memories) {
    if (memories.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('【你记得的关于对方的事情】');
    for (final m in memories) {
      buffer.writeln('- ${m.content}');
    }
    return buffer.toString();
  }

  /// 获取统计信息
  Future<Map<String, int>> getStats(String sessionId) async {
    return await _db.getStats(sessionId);
  }

  /// 清理 JSON 字符串（LLM 有时会在 JSON 外加注释）
  String _cleanJson(String raw) {
    String s = raw.trim();
    // 移除 markdown 代码块标记
    if (s.startsWith('```')) {
      s = s.substring(s.indexOf('\n') + 1);
      if (s.endsWith('```')) {
        s = s.substring(0, s.lastIndexOf('```'));
      }
    }
    return s.trim();
  }
}
