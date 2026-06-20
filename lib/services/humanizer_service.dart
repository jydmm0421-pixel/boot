import 'dart:math';

/// 去人机感引擎：后处理、延迟、语气参数
class HumanizerService {
  final Random _random = Random();

  /// AI 常用禁用词列表
  static const _forbiddenPhrases = [
    '当然可以',
    '当然！',
    '我很乐意',
    '希望这对你有帮助',
    '希望这能帮到你',
    '作为一个AI',
    '作为一个人工智能',
    '我理解你的感受',
    '我明白你的心情',
    '让我来帮你',
    '很高兴为你',
    '请问还有什么需要',
    '还有什么我可以帮你的',
    '随时告诉我',
    '乐意效劳',
    '我很理解',
  ];

  /// Markdown 模式
  static final _markdownPatterns = [
    RegExp(r'\*\*(.+?)\*\*'), // **加粗**
    RegExp(r'\*(.+?)\*'), // *斜体*
    RegExp(r'#{1,6}\s'), // # 标题
    RegExp(r'^\s*[-*+]\s', multiLine: true), // - 列表
    RegExp(r'^\s*\d+\.\s', multiLine: true), // 1. 编号
    RegExp(r'`(.+?)`'), // `代码`
  ];

  /// 后处理：去除 AI 味
  String postProcess(String text) {
    String result = text;

    // 1. 删除禁用短语
    for (final phrase in _forbiddenPhrases) {
      result = result.replaceAll(phrase, _getReplacement());
    }

    // 2. 去除 markdown 格式
    for (final pattern in _markdownPatterns) {
      result = result.replaceAllMapped(pattern, (match) {
        if (match.groupCount >= 1 && match.group(1) != null) {
          return match.group(1)!; // 保留内容，去掉格式符号
        }
        return '';
      });
    }

    // 3. 检测并打断过于完美的长句
    result = _breakPerfectSentences(result);

    // 4. 如果回复以问好结尾，偶尔加上情绪
    result = _addEmotionalTouch(result);

    return result.trim();
  }

  /// 替换禁用短语（去除空字符串选项，避免破坏句子结构）
  String _getReplacement() {
    final options = ['呃', 'emmm', '行吧', '嗯', '...', '害', '啧'];
    return options[_random.nextInt(options.length)];
  }

  /// 打断过于完美的句子
  String _breakPerfectSentences(String text) {
    final sentences = text.split(RegExp(r'(?<=[。！？.!?])'));
    if (sentences.length >= 2 && _random.nextDouble() < 0.3) {
      final idx = _random.nextInt(sentences.length);
      if (sentences[idx].isNotEmpty) {
        // 只替换句尾第一个标点
        sentences[idx] = sentences[idx].replaceFirst(RegExp(r'[。！？.!?]$'), '');
      }
    }
    return sentences.join();
  }

  /// 加上情绪痕迹
  String _addEmotionalTouch(String text) {
    if (_random.nextDouble() < 0.15) {
      final touches = [
        '...',
        ' 算了',
        ' 随便',
        ' 烦',
        ' 🤐',
        ' 😒',
        ' 呵',
        '',
        '',
        '', // 更多概率不加
      ];
      return text + touches[_random.nextInt(touches.length)];
    }
    return text;
  }

  /// 计算打字延迟（毫秒）
  /// 按 60-120 字/分钟计算，加上随机波动
  int calculateTypingDelay(String text) {
    final charCount = text.length;
    // 人类打字速度：60-120 字/分钟 = 1-2 字/秒
    // 加上"思考时间"
    final typingSpeed = 80 + _random.nextInt(60); // 80-140 chars/min
    final baseDelay = (charCount / typingSpeed) * 60000; // 毫秒

    // 短回复: 1-4 秒基础延迟
    if (charCount <= 5) {
      return 1000 + _random.nextInt(3000);
    }

    // 随机化延迟
    final randomFactor = 0.5 + _random.nextDouble(); // 0.5-1.5
    final delay = (baseDelay * randomFactor).round();

    // 5% 概率大幅延迟（模拟在忙）
    if (_random.nextDouble() < 0.05) {
      return delay + 15000 + _random.nextInt(20000);
    }

    // 限制范围
    return delay.clamp(1500, 20000);
  }

  /// 生成随机情绪参数
  Map<String, dynamic> rollMoodParams() {
    final moods = ['开心', '一般', '有点烦', '冷淡', '想你', '无聊', '累', '吃醋了'];
    final mood = moods[_random.nextInt(moods.length)];
    final patience = 3 + _random.nextInt(8); // 3-10
    final talkativeness = 2 + _random.nextInt(9); // 2-10
    final initiative = _random.nextDouble() < 0.1; // 10% 概率主动开话题
    final temperatureOffset = (_random.nextDouble() - 0.5) * 0.3; // -0.15 ~ +0.15

    return {
      'mood': mood,
      'patience': patience,
      'talkativeness': talkativeness,
      'initiative': initiative,
      'temperature_offset': temperatureOffset,
    };
  }

  /// 添加口语化润色（可选，用于后处理微调）
  String addColloquialTouch(String text) {
    String result = text;

    // 如果完全没有语气词，以一定概率在句尾加一个
    final hasModalParticle = RegExp(r'[嘛呗咯啦呀哎呃哈哦哟呢吧]').hasMatch(result);
    if (!hasModalParticle && result.length > 5 && _random.nextDouble() < 0.3) {
      final particles = ['嘛', '呗', '咯', '啦', '呀', '呢', '吧', '哈'];
      result = result.replaceAll(RegExp(r'[。！？.!?]$'), '');
      result += particles[_random.nextInt(particles.length)];
    }

    return result;
  }
}
