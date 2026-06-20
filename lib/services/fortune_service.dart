import 'package:dart_iztro/dart_iztro.dart' hide Palace;
import 'package:get/get.dart';
import '../models/fortune_result.dart';
import 'config_service.dart';
import 'llm_service.dart';

/// 算命服务：封装 dart_iztro 的排盘 + LLM 解读
class FortuneService {
  final DartIztro _iztro = DartIztro();
  final ConfigService _config = ConfigService();

  /// 计算八字
  Future<BaZiResult> calculateBaZi({required BirthInput input}) async {
    final data = await _iztro.calculateBaZi(
      year: input.year, month: input.month, day: input.day,
      hour: input.hour, minute: input.minute,
      isLunar: input.isLunar, isLeap: input.isLeap, gender: input.gender,
    );
    return _parseBaZiResult(data);
  }

  /// 计算紫微斗数命盘
  Future<ChartResult> calculateChart({required BirthInput input}) async {
    final data = await _iztro.calculateChart(
      year: input.year, month: input.month, day: input.day,
      hour: input.hour, minute: input.minute,
      isLunar: input.isLunar, isLeap: input.isLeap, gender: input.gender,
    );
    return _parseChartResult(data);
  }

  /// 一次性计算八字+紫微+流运（推荐）
  Future<FortuneResult> calculateBoth({required BirthInput input}) async {
    final results = await Future.wait([
      _iztro.calculateBaZi(
        year: input.year, month: input.month, day: input.day,
        hour: input.hour, minute: input.minute,
        isLunar: input.isLunar, isLeap: input.isLeap, gender: input.gender,
      ),
      _iztro.calculateChart(
        year: input.year, month: input.month, day: input.day,
        hour: input.hour, minute: input.minute,
        isLunar: input.isLunar, isLeap: input.isLeap, gender: input.gender,
      ),
    ]);

    return FortuneResult(
      birthInput: input,
      baZi: _parseBaZiResult(results[0]),
      chart: _parseChartResult(results[1]),
      horoscope: _parseHoroscope(results[1]),
    );
  }

  // ==================== LLM 解读 ====================

  /// 单人：AI 流式解读运势
  Stream<String> interpretSingleStream({
    required FortuneResult fortune,
    required String topic,
  }) async* {
    final apiKey = await _config.getApiKey();
    if (apiKey == null) throw Exception('请先设置 API Key');

    final content = _buildSinglePrompt(fortune, topic);

    final messages = [
      {'role': 'system', 'content': content},
      {'role': 'user', 'content': '请开始解读'},
    ];

    final client = LlmService.createClient();
    try {
      yield* LlmService.sendStream(client, apiKey, messages, temperature: 0.7,
          maxTokens: 1024);
    } finally {
      client.close();
    }
  }

  /// 双人：AI 流式合盘分析
  Stream<String> interpretCoupleStream({
    required FortuneResult me,
    required FortuneResult ta,
  }) async* {
    final apiKey = await _config.getApiKey();
    if (apiKey == null) throw Exception('请先设置 API Key');

    final content = _buildCouplePrompt(me, ta);

    final messages = [
      {'role': 'system', 'content': content},
      {'role': 'user', 'content': '请开始分析两人的配对情况'},
    ];

    final client = LlmService.createClient();
    try {
      yield* LlmService.sendStream(client, apiKey, messages, temperature: 0.7,
          maxTokens: 1024);
    } finally {
      client.close();
    }
  }

  // ==================== Prompt 构建 ====================

  String _buildSinglePrompt(FortuneResult f, String topic) {
    final b = StringBuffer();
    b.writeln('你是精通紫微斗数和八字命理的AI命理师。请用口语化的中文解读命主的【$topic】。');
    b.writeln();
    b.writeln('【命主信息】${f.birthInput}');
    b.writeln();

    // 八字
    if (f.baZi != null) {
      b.writeln('【八字四柱】');
      b.write('年柱${f.baZi!.yearPillar.fullName} ');
      b.write('月柱${f.baZi!.monthPillar.fullName} ');
      b.write('日柱${f.baZi!.dayPillar.fullName} ');
      b.write('时柱${f.baZi!.hourPillar.fullName}');
      b.writeln();
    }

    // 紫微关键宫位
    if (f.chart != null) {
      b.writeln('【紫微命盘】');
      _writePalace(b, f.soulPalace, '命宫');
      _writePalace(b, f.getPalace('身宫'), '身宫');
      _writePalace(b, f.spousePalace, '夫妻宫');
      _writePalace(b, f.wealthPalace, '财帛宫');
      _writePalace(b, f.careerPalace, '官禄宫');
      _writePalace(b, f.spiritPalace, '福德宫');
    }

    // 流运
    if (f.horoscope != null) {
      b.writeln('【当前运势】');
      b.writeln('大限：${f.horoscope!.decadalGanZhi}');
      b.writeln('流年：${f.horoscope!.yearlyGanZhi}');
      b.writeln('流月：${f.horoscope!.monthlyGanZhi}');
      if (f.horoscope!.yearlyMutagen.isNotEmpty) {
        b.writeln('流年四化：${f.horoscope!.yearlyMutagen.join('、')}');
      }
      if (f.horoscope!.fiveElementClass.isNotEmpty) {
        b.writeln('五行局：$f.horoscope!.fiveElementClass');
      }
    }

    b.writeln();
    b.writeln('【要求】');
    b.writeln('1. 重点解读$topic相关内容，给出实际分析和建议');
    b.writeln('2. 口语化中文，像朋友聊天，不要说套话空话');
    b.writeln('3. 300-500字，有干货，具体针对命盘特征说');
    b.writeln('4. 禁止markdown，禁止编号列表，禁止"当然""作为AI"');
    b.writeln('5. 如果问到姻缘，重点看夫妻宫和流年桃花；事业看官禄宫；财运看财帛宫');

    return b.toString();
  }

  String _buildCouplePrompt(FortuneResult me, FortuneResult ta) {
    final b = StringBuffer();
    b.writeln('你是精通八字合婚和紫微斗数的命理师。请分析以下两人的姻缘配对情况。');
    b.writeln();

    // 甲方
    b.writeln('【甲方】${me.birthInput}');
    if (me.baZi != null) {
      b.write('八字：${me.baZi!.yearPillar.fullName} ');
      b.write('${me.baZi!.monthPillar.fullName} ');
      b.write('${me.baZi!.dayPillar.fullName} ');
      b.writeln(me.baZi!.hourPillar.fullName);
    }
    _writePalace(b, me.soulPalace, '命宫');
    _writePalace(b, me.spousePalace, '夫妻宫');
    _writePalace(b, me.spiritPalace, '福德宫');
    b.writeln();

    // 乙方
    b.writeln('【乙方】${ta.birthInput}');
    if (ta.baZi != null) {
      b.write('八字：${ta.baZi!.yearPillar.fullName} ');
      b.write('${ta.baZi!.monthPillar.fullName} ');
      b.write('${ta.baZi!.dayPillar.fullName} ');
      b.writeln(ta.baZi!.hourPillar.fullName);
    }
    _writePalace(b, ta.soulPalace, '命宫');
    _writePalace(b, ta.spousePalace, '夫妻宫');
    _writePalace(b, ta.spiritPalace, '福德宫');
    b.writeln();

    b.writeln('【分析要点】');
    b.writeln('1. 八字五行互补程度，干支是否相合相冲');
    b.writeln('2. 命宫主星性格匹配度，相处模式');
    b.writeln('3. 夫妻宫互动情况（桃花星、煞星影响）');
    b.writeln('4. 给出具体相处建议');
    b.writeln('5. 最后给出配对评分（60-95分）和一句话总结');
    b.writeln();
    b.writeln('【要求】口语化分析，客观不浮夸，250-400字，禁止markdown和编号列表');

    return b.toString();
  }

  void _writePalace(StringBuffer b, Palace? p, String label) {
    if (p == null) return;
    final stars = [...p.majorStars, ...p.minorStars].where((s) => s != '?').join('、');
    final branch = p.earthlyBranch ?? '';
    b.writeln('$label：${branch.isNotEmpty ? "($branch) " : ""}主星：${stars.isNotEmpty ? stars : "无"}');
  }

  // ==================== 解析方法 ====================

  BaZiResult _parseBaZiResult(Map<String, dynamic> data) {
    final yearly = _asStringList(data['yearly']);
    final monthly = _asStringList(data['monthly']);
    final daily = _asStringList(data['daily']);
    final hourly = _asStringList(data['hourly']);

    return BaZiResult(
      yearPillar: _buildPillar(yearly),
      monthPillar: _buildPillar(monthly),
      dayPillar: _buildPillar(daily),
      hourPillar: _buildPillar(hourly),
      rawJson: data.toString(),
    );
  }

  Pillar _buildPillar(List<String> parts) {
    return Pillar(
      heavenlyStem: parts.isNotEmpty ? parts[0] : '?',
      earthlyBranch: parts.length > 1 ? parts[1] : '?',
      hiddenStems: parts.length > 2 ? parts.sublist(2).join() : null,
    );
  }

  ChartResult _parseChartResult(Map<String, dynamic> data) {
    final palacesRaw = data['palaces'] as List<dynamic>? ?? [];
    final palaces = <Palace>[];

    for (final p in palacesRaw) {
      if (p is Map<String, dynamic>) {
        palaces.add(Palace(
          name: _tr(p['name']?.toString()),
          earthlyBranch: _tr(p['earthlyBranch']?.toString()),
          index: p['index'] as int? ?? 0,
          majorStars: _asStringList(p['majorStars']).map(_tr).toList(),
          minorStars: _asStringList(p['minorStars']).map(_tr).toList(),
          adjectiveStars: _asStringList(p['adjectiveStars']).map(_tr).toList(),
        ));
      }
    }

    return ChartResult(palaces: palaces, rawJson: data.toString());
  }

  /// 解析 horoscope 流运数据
  HoroscopeData? _parseHoroscope(Map<String, dynamic> data) {
    try {
      final horoscope = data['horoscope'] as Map<String, dynamic>?;
      if (horoscope == null) return null;

      return HoroscopeData(
        decadalGanZhi: _extractGanZhi(horoscope['decadal']),
        yearlyGanZhi: _extractGanZhi(horoscope['yearly']),
        monthlyGanZhi: _extractGanZhi(horoscope['monthly']),
        dailyGanZhi: _extractGanZhi(horoscope['daily']),
        yearlyMutagen: _parseMutagen(horoscope['yearly']),
        fiveElementClass: _tr(data['info']?['fiveElementClass']?.toString()),
      );
    } catch (_) {
      return null;
    }
  }

  String _extractGanZhi(dynamic item) {
    if (item == null) return '未知';
    final s = item.toString();
    // dart_iztro HoroscopeItem.toString() 格式类似 "甲子" 或 "EarthlyBranch.ziEarthly"
    if (s.contains('.')) {
      // 枚举格式，尝试翻译
      final parts = s.split('.');
      if (parts.length >= 2) {
        final key = parts.last.trim();
        return _tr(key);
      }
    }
    return _tr(s);
  }

  List<String> _parseMutagen(dynamic yearly) {
    // yearly 可能是 String 或包含 mutagen 属性的对象
    final s = yearly?.toString() ?? '';
    if (s.isEmpty) return [];
    // 简单提取中文字符（四化星通常是单字：禄权科忌）
    final chars = RegExp(r'[一-鿿]').allMatches(s).map((m) => m.group(0)!).toList();
    return chars.where((c) => c.isNotEmpty).toList();
  }

  String _tr(String? key) {
    if (key == null || key.isEmpty) return '?';
    final translated = key.tr;
    if (translated == key) {
      // 翻译未命中，尝试作为枚举 key 处理
      if (key.contains('.')) {
        return key.split('.').last.tr;
      }
    }
    return translated;
  }

  List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
}
