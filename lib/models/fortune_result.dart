// 算命模块数据模型：出生输入、八字结果、紫微斗数结果

/// 生辰数据输入参数
class BirthInput {
  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final bool isLunar;
  final bool isLeap;
  final String gender; // 'male' | 'female'

  const BirthInput({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    this.isLunar = false,
    this.isLeap = false,
    this.gender = 'male',
  });

  String get genderLabel => gender == 'male' ? '男' : '女';
  String get calendarLabel => isLunar ? '农历' : '阳历';

  @override
  String toString() =>
      '$year年$month月$day日 $hour:${minute.toString().padLeft(2, '0')} $calendarLabel $genderLabel';
}

/// 八字四柱 — 单柱信息
class Pillar {
  final String heavenlyStem; // 天干, e.g. "甲"
  final String earthlyBranch; // 地支, e.g. "子"
  final String? hiddenStems; // 藏干, e.g. "癸"

  const Pillar({
    required this.heavenlyStem,
    required this.earthlyBranch,
    this.hiddenStems,
  });

  /// 完整的干支表示，如 "甲子"
  String get fullName => '$heavenlyStem$earthlyBranch';

  @override
  String toString() => fullName;
}

/// 八字结果
class BaZiResult {
  final Pillar yearPillar;
  final Pillar monthPillar;
  final Pillar dayPillar;
  final Pillar hourPillar;
  final String? rawJson;

  const BaZiResult({
    required this.yearPillar,
    required this.monthPillar,
    required this.dayPillar,
    required this.hourPillar,
    this.rawJson,
  });

  List<Pillar> get pillars => [yearPillar, monthPillar, dayPillar, hourPillar];
}

/// 紫微斗数 — 单个宫位信息
class Palace {
  final String name; // 宫位名
  final String? earthlyBranch; // 地支
  final String? heavenlyStem; // 天干
  final List<String> majorStars; // 主星列表
  final List<String> minorStars; // 辅星/杂曜
  final List<String> adjectiveStars; // 杂曜/辅助星
  final String? bodyPalace; // "身宫"标记
  final int index; // 宫位序号 0-11

  const Palace({
    required this.name,
    this.earthlyBranch,
    this.heavenlyStem,
    this.majorStars = const [],
    this.minorStars = const [],
    this.adjectiveStars = const [],
    this.bodyPalace,
    required this.index,
  });

  bool get isBodyPalace => bodyPalace == '身宫';
}

/// 紫微斗数结果
class ChartResult {
  final List<Palace> palaces;
  final String? rawJson;

  const ChartResult({
    required this.palaces,
    this.rawJson,
  });

  /// 十二宫位标准名称
  static const palaceNames = [
    '命宫', '兄弟宫', '夫妻宫', '子女宫',
    '财帛宫', '疾厄宫', '迁移宫', '交友宫',
    '官禄宫', '田宅宫', '福德宫', '父母宫',
  ];
}

/// 流运数据（大限/流年/流月/流日）
class HoroscopeData {
  final String decadalGanZhi; // 大限干支, e.g. "甲子"
  final String yearlyGanZhi; // 流年干支
  final String monthlyGanZhi; // 流月干支
  final String dailyGanZhi; // 流日干支
  final List<String> yearlyMutagen; // 流年四化星
  final String fiveElementClass; // 五行局

  const HoroscopeData({
    required this.decadalGanZhi,
    required this.yearlyGanZhi,
    required this.monthlyGanZhi,
    required this.dailyGanZhi,
    this.yearlyMutagen = const [],
    this.fiveElementClass = '',
  });
}

/// 算命完整结果
class FortuneResult {
  final BirthInput birthInput;
  final BaZiResult? baZi;
  final ChartResult? chart;
  final HoroscopeData? horoscope;
  final DateTime calculatedAt;

  FortuneResult({
    required this.birthInput,
    this.baZi,
    this.chart,
    this.horoscope,
    DateTime? calculatedAt,
  }) : calculatedAt = calculatedAt ?? DateTime.now();

  /// 获取指定名称的宫位
  Palace? getPalace(String name) {
    if (chart == null) return null;
    try {
      return chart!.palaces.firstWhere(
        (p) => p.name == name,
      );
    } catch (_) {
      return null;
    }
  }

  /// 命宫
  Palace? get soulPalace => getPalace('命宫');
  /// 夫妻宫
  Palace? get spousePalace => getPalace('夫妻宫');
  /// 财帛宫
  Palace? get wealthPalace => getPalace('财帛宫');
  /// 官禄宫
  Palace? get careerPalace => getPalace('官禄宫');
  /// 福德宫
  Palace? get spiritPalace => getPalace('福德宫');
}
