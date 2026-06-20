import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message.dart';
import '../models/personality.dart';
import '../services/config_service.dart';
import '../services/database_service.dart';
import '../services/llm_service.dart';
import '../services/memory_service.dart';
import '../services/personality_service.dart';
import '../services/humanizer_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/typing_indicator.dart';

/// 主聊天页
class ChatScreen extends StatefulWidget {
  final String exName;

  const ChatScreen({super.key, required this.exName});

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  final List<Message> _messages = [];
  bool _isLoading = false;
  bool _isStreaming = false;
  String _streamingText = '';
  String? _sessionId;
  Personality? _personality;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final config = context.read<ConfigService>();
    final personalityService = context.read<PersonalityService>();
    final db = context.read<DatabaseService>();

    final sessionId = await config.getCurrentSessionId();
    if (sessionId == null) return;

    final personality = await personalityService.getPersonality(sessionId);

    // 加载历史消息
    final messages = await db.getRecentMessages(sessionId, count: 60);

    setState(() {
      _sessionId = sessionId;
      _personality = personality;
      _messages.addAll(messages);
    });

    // 滚动到底部
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (_sessionId == null || _isLoading) return;

    final userMsg = Message(
      sessionId: _sessionId!,
      role: 'user',
      content: text,
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });
    _scrollToBottom();

    // 保存用户消息
    final db = context.read<DatabaseService>();
    final llm = context.read<LlmService>();
    final memoryService = context.read<MemoryService>();
    final humanizer = context.read<HumanizerService>();
    final personalityService = context.read<PersonalityService>();

    await db.insertMessage(userMsg);

    try {
      // 获取最新人格
      final p = _personality ??
          await personalityService.getPersonality(_sessionId!);
      if (p == null) throw Exception('人格未设置');

      // 获取相关记忆
      final relevantMemories =
          await memoryService.getRelevantMemories(_sessionId!,
              userInput: text, count: 10);

      // 获取最近历史
      final recentHistory = _messages.length > 30
          ? _messages.sublist(_messages.length - 30)
          : _messages;

      // 生成情绪参数
      final moodParams = humanizer.rollMoodParams();

      // 流式调用 LLM
      setState(() => _isStreaming = true);
      final fullResponse = StringBuffer();

      final stream = llm.chatStream(
        sessionId: _sessionId!,
        userMessage: text,
        personality: p,
        relevantMemories: relevantMemories,
        moodParams: moodParams,
        recentHistory:
            recentHistory.where((m) => m.id != userMsg.id).toList(),
      );

      await for (final chunk in stream) {
        fullResponse.write(chunk);
        if (mounted) {
          setState(() {
            _streamingText = fullResponse.toString();
          });
        }
      }

      setState(() => _isStreaming = false);

      // 后处理
      var response = fullResponse.toString();
      response = humanizer.postProcess(response);
      response = humanizer.addColloquialTouch(response);

      // 保存 AI 回复
      final assistantMsg = Message(
        sessionId: _sessionId!,
        role: 'assistant',
        content: response,
      );
      await db.insertMessage(assistantMsg);

      setState(() {
        _messages.add(assistantMsg);
        _streamingText = '';
        _isLoading = false;
      });
      _scrollToBottom();

      // 自动提取记忆
      memoryService.autoExtractMemories(_sessionId!).then((newMemories) {
        if (newMemories.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🧠 记住了 ${newMemories.length} 件事'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isStreaming = false;
          _streamingText = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发送失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
        // 移除失败的用户消息
        _messages.removeLast();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.exName),
        centerTitle: true,
        actions: [
          if (_personality != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showPersonalityInfo(),
              tooltip: '查看人格',
            ),
        ],
      ),
      body: Column(
        children: [
          // 聊天消息列表
          Expanded(
            child: _messages.isEmpty && !_isStreaming
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount:
                        _messages.length + (_isStreaming ? 1 : 0) + (_isLoading && !_isStreaming ? 1 : 0),
                    itemBuilder: (context, index) {
                      // 打字指示器
                      if (index == _messages.length && _isLoading && !_isStreaming) {
                        return const TypingIndicator();
                      }
                      // 流式输出
                      if (index == _messages.length && _isStreaming) {
                        return ChatBubble(
                          content: _streamingText,
                          isMe: false,
                        );
                      }
                      // 正常消息
                      final msg = _messages[index];
                      return ChatBubble(
                        content: msg.content,
                        isMe: msg.role == 'user',
                        time:
                            '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                      );
                    },
                  ),
          ),

          // 输入栏
          ChatInput(
            onSend: _sendMessage,
            enabled: !_isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '开始和 ${widget.exName} 聊天吧',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _showPersonalityInfo() {
    if (_personality == null) return;
    final p = _personality!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${p.exName} 的人格档案'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _infoRow('模式', p.mode == 'import' ? '导入聊天记录' : '性格养成'),
              _infoRow('性格', p.basePersonality),
              _infoRow('说话风格', p.speakingStyle),
              if (p.backstory.isNotEmpty) _infoRow('背景', p.backstory),
              if (p.traits.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('性格特征：',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                ...p.traits.entries.map((e) =>
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(e.key,
                                  style: const TextStyle(fontSize: 13))),
                          Text('${e.value.toStringAsFixed(0)}/10',
                              style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label：',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          Expanded(
              child:
                  Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
