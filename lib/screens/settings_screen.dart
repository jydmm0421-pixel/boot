import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/config_service.dart';
import '../services/personality_service.dart';
import '../models/personality.dart';
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
  Personality? _personality;

  final _nameController = TextEditingController();

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

    Personality? p;
    if (sessionId != null) {
      p = await ps.getPersonality(sessionId);
    }

    setState(() {
      _exName = name;
      _mode = mode ?? '';
      _hasApiKey = apiKey != null && apiKey.isNotEmpty;
      _personality = p;
      _nameController.text = name;
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
    final content = String.fromCharCodes(bytes);

    final sessionId = await config.getCurrentSessionId();
    if (sessionId == null) return;

    try {
      final p = await ps.analyzeAndCreatePersonality(
        sessionId: sessionId,
        exName: _exName,
        chatHistory: content,
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
