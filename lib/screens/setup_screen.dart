import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../services/config_service.dart';
import '../services/personality_service.dart';
import '../utils/chat_parser.dart';
import 'home_screen.dart';

/// 初始引导页：配置 API Key、选择模式、设置人设
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _apiKeyController = TextEditingController();
  final _nameController = TextEditingController(text: 'TA');
  final _backstoryController = TextEditingController();

  String _mode = 'cultivate'; // 'cultivate' | 'import'
  String _basePersonality = '温柔';
  String? _chatFilePath;
  String? _chatFileContent;
  String? _selectedSpeaker; // 用户选择的目标说话人
  bool _loading = false;
  String? _error;

  final _personalities = ['温柔', '傲娇', '毒舌', '冷淡'];

  @override
  void dispose() {
    _apiKeyController.dispose();
    _nameController.dispose();
    _backstoryController.dispose();
    super.dispose();
  }

  Future<void> _pickChatFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'csv', 'json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    final content = String.fromCharCodes(bytes);
    final parsed = parseChat(content);

    if (parsed.speakers.isEmpty) {
      setState(() {
        _chatFilePath = result.files.first.name;
        _chatFileContent = content;
        _selectedSpeaker = null;
      });
      return;
    }

    // 检测到说话人，弹出选择对话框
    if (mounted) {
      final speaker = await _showSpeakerDialog(parsed);
      if (speaker != null) {
        // 只保留目标说话人的消息
        final filtered = filterMessagesBySpeaker(content, speaker);
        setState(() {
          _chatFilePath = result.files.first.name;
          _chatFileContent = filtered;
          _selectedSpeaker = speaker;
        });
      } else {
        // 用户取消，保留原始内容
        setState(() {
          _chatFilePath = result.files.first.name;
          _chatFileContent = content;
          _selectedSpeaker = null;
        });
      }
    }
  }

  /// 显示说话人选择对话框
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
                    const Text(
                      '检测到以下说话人，请选择你想让AI模仿的一方：',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
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
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text('${s.messageCount} 条消息'),
                          onTap: () =>
                              setDialogState(() => selected = s.name),
                          dense: true,
                        )),
                    if (speakers.length > 2)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '（只显示消息最多的前${speakers.length}人）',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[400]),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
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

  Future<void> _completeSetup() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() => _error = '请输入 API Key');
      return;
    }

    if (_mode == 'import' && _chatFileContent == null) {
      setState(() => _error = '请导入聊天记录文件');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final config = context.read<ConfigService>();
      final personalityService = context.read<PersonalityService>();

      // 保存 API Key
      await config.setApiKey(apiKey);

      // 生成 session ID
      const uuid = Uuid();
      final sessionId = uuid.v4();
      await config.setCurrentSessionId(sessionId);
      await config.setMode(_mode);
      await config.setExName(_nameController.text.trim().isEmpty
          ? 'TA'
          : _nameController.text.trim());

      // 创建人格
      if (_mode == 'import' && _chatFileContent != null) {
        await personalityService.analyzeAndCreatePersonality(
          sessionId: sessionId,
          exName: _nameController.text.trim(),
          chatHistory: _chatFileContent!,
          targetSpeaker: _selectedSpeaker,
        );
      } else {
        await personalityService.createInitialPersonality(
          sessionId: sessionId,
          exName: _nameController.text.trim(),
          basePersonality: _basePersonality,
          backstory: _backstoryController.text.trim().isNotEmpty
              ? _backstoryController.text.trim()
              : null,
        );
      }

      await config.setSetupComplete(true);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _error = '设置失败: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('初始化 CyberEx'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在设置...'),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 标题
                    Text(
                      '欢迎来到 CyberEx',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '在开始之前，需要做一些简单设置',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Step 1: API Key
                    _buildSectionTitle('1. DeepSeek API Key'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: '输入你的 DeepSeek API Key',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.visibility_off),
                          onPressed: () {},
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Key 会加密存储在本地，不会上传到任何服务器',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 24),

                    // Step 2: 模式选择
                    _buildSectionTitle('2. 选择模式'),
                    const SizedBox(height: 8),
                    _buildModeCard(
                      'import',
                      '📂 导入聊天记录',
                      '导入你和前任的真实聊天记录，AI 分析后模仿前任的说话风格',
                    ),
                    const SizedBox(height: 8),
                    _buildModeCard(
                      'cultivate',
                      '🌱 从零养成',
                      '创造一个全新的机器人，性格在聊天中逐渐成型',
                    ),
                    const SizedBox(height: 24),

                    // Step 3: 具体设置
                    _buildSectionTitle('3. 机器人设置'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: '给 TA 起个名字',
                        labelText: '名字',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_mode == 'cultivate') ...[
                      _buildSectionTitle('性格底色'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _personalities.map((p) {
                          final selected = _basePersonality == p;
                          return ChoiceChip(
                            label: Text(p),
                            selected: selected,
                            onSelected: (v) {
                              if (v) setState(() => _basePersonality = p);
                            },
                            selectedColor:
                                Theme.of(context).colorScheme.primaryContainer,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _backstoryController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: '背景故事（可选），如：因为异地分手，心里还有对方...',
                          labelText: '背景故事',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],

                    if (_mode == 'import') ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _pickChatFile,
                        icon: const Icon(Icons.upload_file),
                        label: Text(_chatFilePath ?? '选择聊天记录文件 (.txt)'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (_chatFileContent != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '已加载 ${_chatFileContent!.length} 个字符${_selectedSpeaker != null ? "，分析对象：$_selectedSpeaker" : ""}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ],

                    const SizedBox(height: 32),

                    // 错误信息
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // 开始按钮
                    FilledButton.icon(
                      onPressed: _completeSetup,
                      icon: const Icon(Icons.rocket_launch),
                      label: const Text('开始使用'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
    );
  }

  Widget _buildModeCard(String value, String title, String subtitle) {
    final selected = _mode == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => _mode = value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer.withAlpha(80)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
