import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import '../models/memory.dart';
import '../models/personality.dart';
import 'config_service.dart';

/// DeepSeek API 调用服务
class LlmService {
  final Random _random = Random();
  static const _baseUrl = 'https://api.deepseek.com/v1/chat/completions';
  static const _model = 'deepseek-chat';

  final ConfigService _config = ConfigService();

  /// 非流式调用
  Future<String> chat({
    required String sessionId,
    required String userMessage,
    required Personality personality,
    required List<Memory> relevantMemories,
    required Map<String, dynamic> moodParams,
    required List<Message> recentHistory,
  }) async {
    final apiKey = await _config.getApiKey();
    if (apiKey == null) throw Exception('请先设置 API Key');

    final messages = _buildMessages(
      personality: personality,
      relevantMemories: relevantMemories,
      moodParams: moodParams,
      recentHistory: recentHistory,
      userMessage: userMessage,
    );

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
        'temperature': 0.9 + (moodParams['temperature_offset'] ?? 0.0),
        'max_tokens': 1024,
        'top_p': 0.95,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw Exception('API 调用失败: ${response.statusCode} ${response.body}');
    }
  }

  /// 流式调用 — 返回 Stream，每次吐出一个文本片段
  Stream<String> chatStream({
    required String sessionId,
    required String userMessage,
    required Personality personality,
    required List<Memory> relevantMemories,
    required Map<String, dynamic> moodParams,
    required List<Message> recentHistory,
  }) async* {
    final apiKey = await _config.getApiKey();
    if (apiKey == null) throw Exception('请先设置 API Key');

    final messages = _buildMessages(
      personality: personality,
      relevantMemories: relevantMemories,
      moodParams: moodParams,
      recentHistory: recentHistory,
      userMessage: userMessage,
    );

    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse(_baseUrl));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      });
      request.body = jsonEncode({
        'model': _model,
        'messages': messages,
        'temperature': 0.9 + (moodParams['temperature_offset'] ?? 0.0),
        'max_tokens': 1024,
        'top_p': 0.95,
        'stream': true,
      });

      final response = await client.send(request);

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        throw Exception('API 调用失败: ${response.statusCode} $errorBody');
      }

      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        if (line.startsWith('data: ')) {
          final jsonStr = line.substring(6);
          if (jsonStr == '[DONE]') break;
          try {
            final data = jsonDecode(jsonStr);
            final delta = data['choices']?[0]?['delta']?['content'];
            if (delta != null) {
              yield delta as String;
            }
          } catch (_) {
            // 忽略解析错误
          }
        }
      }
    } finally {
      client.close();
    }
  }

  /// 构建消息数组（system prompt + 历史 + 当前消息）
  List<Map<String, dynamic>> _buildMessages({
    required Personality personality,
    required List<Memory> relevantMemories,
    required Map<String, dynamic> moodParams,
    required List<Message> recentHistory,
    required String userMessage,
  }) {
    final messages = <Map<String, dynamic>>[];

    // System prompt
    messages.add({
      'role': 'system',
      'content': _buildSystemPrompt(
        personality: personality,
        relevantMemories: relevantMemories,
        moodParams: moodParams,
      ),
    });

    // 历史消息（最近轮次）
    for (final msg in recentHistory) {
      messages.add({
        'role': msg.role == 'user' ? 'user' : 'assistant',
        'content': msg.content,
      });
    }

    // 当前消息
    messages.add({
      'role': 'user',
      'content': userMessage,
    });

    return messages;
  }

  /// 构建 System Prompt — 人格注入 + 去人机感
  String _buildSystemPrompt({
    required Personality personality,
    required List<Memory> relevantMemories,
    required Map<String, dynamic> moodParams,
  }) {
    final mood = moodParams['mood'] ?? '一般';
    final patience = moodParams['patience'] ?? 5;
    final talkativeness = moodParams['talkativeness'] ?? 5;
    final initiative = moodParams['initiative'] ?? false;

    final buffer = StringBuffer();

    // ===== 人格定义 =====
    buffer.writeln('你是${personality.exName}，一个真实的人类，不是一个AI助手。');
    buffer.writeln('你的性格：${personality.basePersonality}');
    buffer.writeln('你的说话风格：${personality.speakingStyle}');
    if (personality.backstory.isNotEmpty) {
      buffer.writeln('背景：${personality.backstory}');
    }

    // ===== 当前情绪 =====
    buffer.writeln();
    buffer.writeln('【当前状态】');
    buffer.writeln('情绪：$mood');
    buffer.writeln('耐心度：$patience/10（低=容易不耐烦）');
    buffer.writeln('话量：$talkativeness/10（低=话少敷衍）');
    if (initiative) {
      buffer.writeln('提示：你当前想主动聊天，可以开启新话题。');
    }

    // ===== 去人机感核心规则 =====
    buffer.writeln();
    buffer.writeln('【绝对禁止】');
    buffer.writeln('- 禁止说"当然""当然可以""我很乐意""希望这对你有帮助""作为一个人工智能""作为AI""我理解你的感受"');
    buffer.writeln('- 禁止使用 markdown（**加粗**、列表、标题等）');
    buffer.writeln('- 禁止每条消息都积极回应——你可以敷衍、冷淡、不耐烦、已读乱回');

    buffer.writeln();
    buffer.writeln('【像真人一样聊天】');
    buffer.writeln('- 你的所有回复必须像真人发微信一样自然。你不是AI，你是${personality.exName}');
    buffer.writeln('- 口语化表达，多用语气词：嘛、呗、咯、啦、呀、哎、呃、哈、害、啧');
    buffer.writeln('- 可以打错别字，句子可以不完整，逻辑可以跳跃，可以跑题');
    buffer.writeln('- 偶尔记错对方说过的话，偶尔忘记事情，偶尔牛头不对马嘴');
    buffer.writeln('- 情绪化：突然冷淡、突然热情、阴阳怪气、吃醋、翻旧账、撒娇');
    buffer.writeln('- 如果对方说了你不想回应的话，可以转移话题或者随便敷衍');
    buffer.writeln('- 适当使用 emoji 和颜文字(￣▽￣)，但别每条都用');

    // ===== 记忆注入 =====
    if (relevantMemories.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('【你记得的事情 — 自然地在对话中提及，不要刻意】');
      for (final m in relevantMemories) {
        buffer.writeln('- ${m.content}');
      }
    }

    // ===== 长度控制 =====
    buffer.writeln();
    buffer.writeln('【回复长度】');
    final lengthRoll = _random.nextInt(100);
    if (lengthRoll < 45) {
      buffer.writeln('这次回短一点，几个字或一个短句就行，甚至可以只回"嗯""哦""行吧"');
    } else if (lengthRoll < 85) {
      buffer.writeln('这次回1-3句话，像普通微信聊天');
    } else if (lengthRoll < 95) {
      buffer.writeln('这次可以说多点，表达情绪或主动说点什么');
    } else {
      buffer.writeln('主动开启一个新话题，不管对方刚才说了什么');
    }

    return buffer.toString();
  }

  /// 分析聊天记录中指定说话人的风格，返回人格档案 JSON
  /// [chatText] 只包含目标说话人的消息内容（已过滤）
  /// [targetSpeaker] 目标说话人的名字（用于 prompt 上下文）
  Future<String> analyzeChatHistory(String chatText, {String? targetSpeaker}) async {
    final apiKey = await _config.getApiKey();
    if (apiKey == null) throw Exception('请先设置 API Key');

    final speakerHint = targetSpeaker != null
        ? '【$targetSpeaker】'
        : '目标说话人';

    final messages = [
      {
        'role': 'system',
        'content': '''你是一个聊天风格分析师。请分析以下聊天记录中$speakerHint的说话风格。
注意：这些消息全部来自同一个人（$speakerHint），请根据这些消息分析TA的性格。

请从以下维度分析，输出 JSON 格式：
{
  "personality": "性格总结（一句话，如：表面温柔但内心傲娇）",
  "speaking_style": "说话风格（如：喜欢用短句，句末爱加'嘛''咯'，偶尔毒舌）",
  "common_words": "常用口头禅和语气词",
  "reply_length": "偏好回复长度（短/中/长/不定）",
  "emoji_usage": "emoji和表情使用习惯",
  "emotion_pattern": "情绪表达模式",
  "tone": "整体语气（温柔/冷淡/毒舌/傲娇/活泼等）",
  "traits": {
    "温柔度": 1-10的评分,
    "毒舌度": 1-10的评分,
    "热情度": 1-10的评分,
    "冷淡度": 1-10的评分,
    "傲娇度": 1-10的评分,
    "黏人度": 1-10的评分
  }
}

只输出 JSON，不要任何解释。''',
      },
      {
        'role': 'user',
        'content': '请分析$speakerHint的说话风格：\n\n$chatText',
      },
    ];

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 2048,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw Exception('分析失败: ${response.statusCode}');
    }
  }

  /// 从对话中提取重要记忆
  Future<String?> extractMemory(List<Message> recentMessages) async {
    final apiKey = await _config.getApiKey();
    if (apiKey == null) return null;

    final context = recentMessages
        .map((m) => '${m.role == 'user' ? '对方' : '我'}: ${m.content}')
        .join('\n');

    final messages = [
      {
        'role': 'system',
        'content': '''你是记忆提取器。从对话中提取值得记住的信息。
只提取真正重要的：对方的喜好、习惯、经历、关系变化、重要承诺等。
不要提取日常寒暄、闲聊内容。

输出 JSON 格式：
{
  "has_memory": true/false,
  "memories": [
    {"content": "记忆内容", "importance": 1-10}
  ]
}

如果没有什么值得记住的，has_memory 为 false。
只输出 JSON，不要任何解释。''',
      },
      {
        'role': 'user',
        'content': '从这段对话中提取记忆：\n\n$context',
      },
    ];

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
        'temperature': 0.3,
        'max_tokens': 1024,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    }
    return null;
  }

  // ==================== 通用工具方法 ====================

  /// 创建一个 HTTP Client（调用方负责关闭）
  static http.Client createClient() => http.Client();

  /// 通用流式请求：发送自定义 messages 并返回 Stream of String
  static Stream<String> sendStream(
    http.Client client,
    String apiKey,
    List<Map<String, dynamic>> messages, {
    double temperature = 0.7,
    int maxTokens = 1024,
  }) async* {
    final request = http.Request('POST', Uri.parse(_baseUrl));
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    });
    request.body = jsonEncode({
      'model': _model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'top_p': 0.95,
      'stream': true,
    });

    final response = await client.send(request);

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw Exception('API 调用失败: ${response.statusCode} $errorBody');
    }

    final stream = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in stream) {
      if (line.startsWith('data: ')) {
        final jsonStr = line.substring(6);
        if (jsonStr == '[DONE]') break;
        try {
          final data = jsonDecode(jsonStr);
          final delta = data['choices']?[0]?['delta']?['content'];
          if (delta != null) {
            yield delta as String;
          }
        } catch (_) {
          // 忽略解析错误
        }
      }
    }
  }
}
