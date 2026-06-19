import 'dart:convert';
import '../models/personality.dart';
import 'database_service.dart';
import 'llm_service.dart';

/// 人格系统：聊天记录分析 / 性格养成
class PersonalityService {
  final DatabaseService _db = DatabaseService();
  final LlmService _llm = LlmService();

  /// 创建初始人格（模式B：养成模式）
  Future<Personality> createInitialPersonality({
    required String sessionId,
    required String exName,
    required String basePersonality,
    String? backstory,
  }) async {
    // 根据性格底色生成默认的说话风格和特征
    final defaultTraits = _defaultTraitsForPersonality(basePersonality);
    final defaultStyle = _defaultStyleForPersonality(basePersonality, exName);

    final personality = Personality(
      sessionId: sessionId,
      mode: 'cultivate',
      exName: exName,
      basePersonality: basePersonality,
      speakingStyle: defaultStyle,
      backstory: backstory ?? '',
      traits: defaultTraits,
      rawAnalysis: '',
    );

    await _db.insertOrUpdatePersonality(personality);
    return personality;
  }

  /// 模式A：分析聊天记录，创建人格
  Future<Personality> analyzeAndCreatePersonality({
    required String sessionId,
    required String exName,
    required String chatHistory,
  }) async {
    // 调用 AI 分析
    final analysis = await _llm.analyzeChatHistory(chatHistory);

    // 解析 AI 返回的 JSON
    try {
      final json = _cleanJson(analysis);
      final data = jsonDecode(json);

      final personality = data['personality'] as String? ?? '';
      final speakingStyle = data['speaking_style'] as String? ?? '';
      final tone = data['tone'] as String? ?? '';

      // 解析 traits
      final traitsJson = data['traits'] as Map<String, dynamic>? ?? {};
      final traits = <String, double>{};
      for (final entry in traitsJson.entries) {
        final value = (entry.value as num?)?.toDouble();
        if (value != null) traits[entry.key.toString()] = value;
      }

      final p = Personality(
        sessionId: sessionId,
        mode: 'import',
        exName: exName,
        basePersonality: '$tone - $personality',
        speakingStyle: speakingStyle,
        backstory: '通过分析真实聊天记录生成的性格',
        traits: traits,
        rawAnalysis: analysis,
      );

      await _db.insertOrUpdatePersonality(p);
      return p;
    } catch (e) {
      // 解析失败时用原始分析结果创建
      final p = Personality(
        sessionId: sessionId,
        mode: 'import',
        exName: exName,
        basePersonality: '根据聊天记录生成',
        speakingStyle: analysis,
        backstory: '通过分析真实聊天记录生成的性格',
        rawAnalysis: analysis,
      );

      await _db.insertOrUpdatePersonality(p);
      return p;
    }
  }

  /// 获取当前人格
  Future<Personality?> getPersonality(String sessionId) async {
    return await _db.getPersonality(sessionId);
  }

  /// 更新人格（性格演化）
  Future<void> updatePersonality(Personality p) async {
    await _db.insertOrUpdatePersonality(p);
  }

  /// 性格随时间演化（养成模式用）
  /// 根据最近的互动逐渐微调性格参数
  Future<Personality?> evolvePersonality(String sessionId) async {
    final current = await _db.getPersonality(sessionId);
    if (current == null || current.mode != 'cultivate') return null;

    // 获取最近的用户消息来评估互动模式
    // 简化：随机微调 0.1-0.3
    final newTraits = <String, double>{};
    for (final entry in current.traits.entries) {
      final delta = (DateTime.now().millisecond % 100 - 50) / 100.0;
      var newVal = (entry.value + delta).clamp(0.0, 10.0);
      newVal = double.parse(newVal.toStringAsFixed(1));
      newTraits[entry.key] = newVal;
    }

    final evolved = Personality(
      id: current.id,
      sessionId: current.sessionId,
      mode: current.mode,
      exName: current.exName,
      basePersonality: current.basePersonality,
      speakingStyle: current.speakingStyle,
      backstory: current.backstory,
      traits: newTraits,
      rawAnalysis: current.rawAnalysis,
    );

    await _db.insertOrUpdatePersonality(evolved);
    return evolved;
  }

  /// 默认性格特征映射
  Map<String, double> _defaultTraitsForPersonality(String base) {
    switch (base) {
      case '傲娇':
        return {'温柔度': 5.0, '毒舌度': 6.0, '热情度': 4.0, '冷淡度': 5.0, '傲娇度': 9.0, '黏人度': 4.0};
      case '温柔':
        return {'温柔度': 9.0, '毒舌度': 1.0, '热情度': 7.0, '冷淡度': 1.0, '傲娇度': 2.0, '黏人度': 8.0};
      case '毒舌':
        return {'温柔度': 2.0, '毒舌度': 9.0, '热情度': 5.0, '冷淡度': 6.0, '傲娇度': 5.0, '黏人度': 3.0};
      case '冷淡':
        return {'温柔度': 2.0, '毒舌度': 4.0, '热情度': 2.0, '冷淡度': 9.0, '傲娇度': 3.0, '黏人度': 1.0};
      default:
        return {'温柔度': 5.0, '毒舌度': 3.0, '热情度': 5.0, '冷淡度': 5.0, '傲娇度': 5.0, '黏人度': 5.0};
    }
  }

  /// 默认说话风格
  String _defaultStyleForPersonality(String base, String name) {
    switch (base) {
      case '傲娇':
        return '说话嘴上不饶人但其实心里很在乎，喜欢用"哼""随便你""才不是呢"，偶尔会不小心流露出关心';
      case '温柔':
        return '说话轻声细语，会关心人，喜欢用"好哦""嗯呢""乖"，偶尔也会委屈撒娇';
      case '毒舌':
        return '说话犀利直接，喜欢吐槽，用短句居多，但其实没有恶意，偶尔会补一句好话';
      case '冷淡':
        return '话很少，回复简短，有时候已读不回，但其实有在听，偶尔蹦出一句走心的话';
      default:
        return '像一个普通人在聊天，有情绪起伏，会开心也会不耐烦';
    }
  }

  String _cleanJson(String raw) {
    String s = raw.trim();
    if (s.startsWith('```')) {
      s = s.substring(s.indexOf('\n') + 1);
      if (s.endsWith('```')) {
        s = s.substring(0, s.lastIndexOf('```'));
      }
    }
    return s.trim();
  }
}
