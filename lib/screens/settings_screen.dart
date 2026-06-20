import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/config_service.dart';
import '../services/llm_service.dart';
import '../services/image_gen_service.dart';
import '../services/personality_service.dart';
import '../models/personality.dart';
import '../utils/chat_parser.dart';
import 'setup_screen.dart';

/// 设置页
class SettingsScreen extends StatefulWidget {
  final Function(String)? onNameChanged;

  const SettingsScreen({super.key, this.onNameChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _exName = 'TA';
  String _mode = '';
  bool _hasApiKey = false;
  bool _hasImageGenKey = false;
  Personality? _personality;
  String? _userAvatar;
  String? _botAvatar;
  bool _generatingAvatar = false;

  final _nameController = TextEditingController();
  final _imageGenKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final config = context.read<ConfigService>();
    final ps = context.read<PersonalityService>();

    final name = await config.getExName();
    final mode = await config.getMode();
    final apiKey = await config.getApiKey();
    final sessionId = await config.getCurrentSessionId();
    final userAvatar = await config.getUserAvatar();
    final botAvatar = await config.getBotAvatar();
    final imageGenKey = await config.getImageGenApiKey();

    Personality? p;
    if (sessionId != null) {
      p = await ps.getPersonality(sessionId);
    }

    setState(() {
      _exName = name;
      _mode = mode ?? '';
      _hasApiKey = apiKey != null && apiKey.isNotEmpty;
      _hasImageGenKey = imageGenKey != null && imageGenKey.isNotEmpty;
      _personality = p;
      _userAvatar = userAvatar;
      _botAvatar = botAvatar;
      _nameController.text = name;
      _imageGenKeyController.text = imageGenKey ?? '';
    });
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final config = context.read<ConfigService>();
    await config.setExName(name);
    widget.onNameChanged?.call(name);
    setState(() => _exName = name);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('名字已更新')),
      );
    }
  }

  Future<void> _importChatHistory() async {
    final config = context.read<ConfigService>();
    final ps = context.read<PersonalityService>();

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    var content = String.fromCharCodes(bytes);

    final sessionId = await config.getCurrentSessionId();
    if (sessionId == null) return;

    // 解析说话人并让用户选择
    final parsed = parseChat(content);
    String? targetSpeaker;
    if (parsed.speakers.isNotEmpty) {
      targetSpeaker = await _showSpeakerDialog(parsed);
      if (targetSpeaker != null) {
        content = filterMessagesBySpeaker(content, targetSpeaker);
      }
    }

    try {
      final p = await ps.analyzeAndCreatePersonality(
        sessionId: sessionId,
        exName: _exName,
        chatHistory: content,
        targetSpeaker: targetSpeaker,
      );
      setState(() => _personality = p);
      await config.setMode('import');
      setState(() => _mode = 'import');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('聊天记录分析完成，人格已更新')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分析失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<String?> _showSpeakerDialog(ChatParseResult parsed) async {
    String selected = parsed.speakers.first.name;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final speakers = parsed.speakers;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('选择模仿对象'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('检测到以下说话人，请选择你想让AI模仿的一方：',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 12),
                    ...speakers.map((s) => ListTile(
                          leading: Icon(
                            selected == s.name
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: selected == s.name
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                          ),
                          title: Text(s.name,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${s.messageCount} 条消息'),
                          onTap: () => setDialogState(() => selected = s.name),
                          dense: true,
                        )),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, selected),
                  child: Text('选择 $selected'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickUserAvatar() async {
    final config = context.read<ConfigService>();
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 256, maxHeight: 256, imageQuality: 80);
    if (file == null) return;

    final bytes = await File(file.path).readAsBytes();
    final base64 = base64Encode(bytes);
    await config.setUserAvatar(base64);
    if (mounted) setState(() => _userAvatar = base64);
  }

  Future<void> _generateBotAvatar() async {
    final config = context.read<ConfigService>();
    final messenger = ScaffoldMessenger.of(context);
    final apiKey = await config.getImageGenApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('请先设置生图 API Key'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    if (_personality == null) {
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('请先完成人格设置'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() => _generatingAvatar = true);

    try {
      // 用 LLM 生成头像 prompt
      final llm = LlmService();
      final promptResult = await llm.chat(
        sessionId: 'avatar_gen',
        userMessage: '请根据以下性格生成一个头像描述（30字以内，用于AI生图）：${_personality!.basePersonality}，${_personality!.speakingStyle}',
        personality: _personality!,
        relevantMemories: [],
        moodParams: {},
        recentHistory: [],
      );

      final prompt = '日系动漫头像，正面半身，$promptResult，简洁干净风格';

      final genService = ImageGenService();
      final imageBytes = await genService.generateImage(prompt, apiKey: apiKey);
      final base64 = base64Encode(imageBytes);

      await config.setBotAvatar(base64);
      if (mounted) {
        setState(() {
          _botAvatar = base64;
          _generatingAvatar = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('机器人头像已生成！')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generatingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveImageGenKey() async {
    final key = _imageGenKeyController.text.trim();
    await context.read<ConfigService>().setImageGenApiKey(key);
    setState(() => _hasImageGenKey = key.isNotEmpty);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('生图 API Key 已保存')),
      );
    }
  }

  Future<void> _resetApp() async {
    final config = context.read<ConfigService>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置应用'),
        content: const Text('这将清除所有聊天记录、记忆和设置。此操作不可撤销。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确定重置'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await config.setSetupComplete(false);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SetupScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _imageGenKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 名字
          _buildSection('机器人名字'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saveName,
                child: const Text('保存'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // API Key 状态
          _buildSection('API Key'),
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              _hasApiKey ? Icons.check_circle : Icons.error,
              color: _hasApiKey ? Colors.green : Colors.red,
            ),
            title: Text(_hasApiKey ? 'DeepSeek API Key 已设置' : '未设置 API Key'),
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),

          const SizedBox(height: 24),

          // 模式
          _buildSection('人设模式'),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: Text(_mode == 'import' ? '导入聊天记录模式' : '性格养成模式'),
            subtitle: _personality != null
                ? Text('性格：${_personality!.basePersonality}')
                : null,
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _importChatHistory,
            icon: const Icon(Icons.upload_file),
            label: const Text('重新导入聊天记录分析'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 人格档案
          if (_personality != null) ...[
            _buildSection('人格档案'),
            const SizedBox(height: 8),
            Card(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _traitBar(
                        '温柔度', _personality!.traits['温柔度'] ?? 5),
                    _traitBar(
                        '毒舌度', _personality!.traits['毒舌度'] ?? 5),
                    _traitBar(
                        '热情度', _personality!.traits['热情度'] ?? 5),
                    _traitBar(
                        '冷淡度', _personality!.traits['冷淡度'] ?? 5),
                    _traitBar(
                        '傲娇度', _personality!.traits['傲娇度'] ?? 5),
                    _traitBar(
                        '黏人度', _personality!.traits['黏人度'] ?? 5),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // 头像
          _buildSection('头像'),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // 用户头像
                  Column(
                    children: [
                      GestureDetector(
                        onTap: _pickUserAvatar,
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _userAvatar != null
                              ? MemoryImage(base64Decode(_userAvatar!))
                              : null,
                          child: _userAvatar == null
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('我的头像', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.swap_horiz, color: Colors.grey[400]),
                  const Spacer(),
                  // 机器人头像
                  Column(
                    children: [
                      GestureDetector(
                        onTap: _generateBotAvatar,
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          backgroundImage: _botAvatar != null
                              ? MemoryImage(base64Decode(_botAvatar!))
                              : null,
                          child: _generatingAvatar
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : _botAvatar == null
                                  ? const Icon(Icons.smart_toy, color: Colors.white)
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(_generatingAvatar ? '生成中...' : '机器人头像',
                          style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_botAvatar == null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text('点击右侧头像，AI 根据人格自动生成',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ),

          const SizedBox(height: 24),

          // 生图 API Key
          _buildSection('生图 API (Doubao-Seedance)'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _imageGenKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: '输入火山方舟 API Key',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.image),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _saveImageGenKey, child: const Text('保存')),
            ],
          ),
          ListTile(
            leading: Icon(
              _hasImageGenKey ? Icons.check_circle : Icons.info_outline,
              color: _hasImageGenKey ? Colors.green : Colors.grey,
              size: 20,
            ),
            title: Text(
              _hasImageGenKey ? '生图 API Key 已设置' : '未设置（无法使用生图功能）',
              style: const TextStyle(fontSize: 13),
            ),
            dense: true,
          ),

          const SizedBox(height: 32),

          // 危险区域
          _buildSection('危险操作'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _resetApp,
            icon: const Icon(Icons.warning_amber, color: Colors.red),
            label: const Text('重置应用（清除所有数据）',
                style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(12),
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.grey,
      ),
    );
  }

  Widget _traitBar(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / 10,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text(
              value.toStringAsFixed(0),
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
