/// 人格模型 — 机器人的性格档案
class Personality {
  final int? id;
  final String sessionId;
  final String mode; // 'import' | 'cultivate'
  final String exName; // 前任/机器人名字
  final String basePersonality; // 基础性格描述
  final String speakingStyle; // 说话风格
  final String backstory; // 背景故事
  final Map<String, double> traits; // 性格特征评分，如 {'温柔度': 7.0, '毒舌度': 3.0}
  final String rawAnalysis; // AI 分析原始结果（模式A使用）
  final DateTime updatedAt;

  Personality({
    this.id,
    required this.sessionId,
    required this.mode,
    this.exName = 'TA',
    this.basePersonality = '',
    this.speakingStyle = '',
    this.backstory = '',
    Map<String, double>? traits,
    this.rawAnalysis = '',
    DateTime? updatedAt,
  })  : traits = traits ?? {},
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'session_id': sessionId,
      'mode': mode,
      'ex_name': exName,
      'base_personality': basePersonality,
      'speaking_style': speakingStyle,
      'backstory': backstory,
      'traits_json': _traitsToJson(),
      'raw_analysis': rawAnalysis,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String _traitsToJson() {
    final buffer = StringBuffer('{');
    final entries = traits.entries.toList();
    for (int i = 0; i < entries.length; i++) {
      buffer.write('"${entries[i].key}":${entries[i].value}');
      if (i < entries.length - 1) buffer.write(',');
    }
    buffer.write('}');
    return buffer.toString();
  }

  static Map<String, double> _traitsFromJson(String json) {
    final map = <String, double>{};
    if (json.isEmpty || json == '{}') return map;
    final content = json.substring(1, json.length - 1);
    for (final part in content.split(',')) {
      final kv = part.split(':');
      if (kv.length == 2) {
        map[kv[0].trim().replaceAll('"', '')] = double.tryParse(kv[1].trim()) ?? 5.0;
      }
    }
    return map;
  }

  factory Personality.fromMap(Map<String, dynamic> map) {
    return Personality(
      id: map['id'] as int?,
      sessionId: map['session_id'] as String,
      mode: map['mode'] as String,
      exName: map['ex_name'] as String? ?? 'TA',
      basePersonality: map['base_personality'] as String? ?? '',
      speakingStyle: map['speaking_style'] as String? ?? '',
      backstory: map['backstory'] as String? ?? '',
      traits: _traitsFromJson(map['traits_json'] as String? ?? '{}'),
      rawAnalysis: map['raw_analysis'] as String? ?? '',
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
