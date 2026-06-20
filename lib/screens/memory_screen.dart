import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/memory.dart';
import '../services/config_service.dart';
import '../services/memory_service.dart';

/// 记忆查看页 — 展示 AI 记住的所有事情
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  List<Memory> _memories = [];
  int _messageCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    final config = context.read<ConfigService>();
    final memoryService = context.read<MemoryService>();

    final sessionId = await config.getCurrentSessionId();
    if (sessionId == null) return;

    final memories = await memoryService.getAllMemories(sessionId);
    final stats = await memoryService.getStats(sessionId);

    if (mounted) {
      setState(() {
        _memories = memories;
        _messageCount = stats['messages'] ?? 0;
        _loading = false;
      });
    }
  }

  Future<void> _deleteMemory(int id) async {
    final memoryService = context.read<MemoryService>();
    await memoryService.deleteMemory(id);
    _loadMemories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('记忆'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _memories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.psychology_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        '还没有记忆',
                        style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '多聊聊天，AI 会自动提取重要的记忆',
                        style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // 统计卡片
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withAlpha(80),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statItem('总消息', _messageCount.toString()),
                          _statItem('记忆', _memories.length.toString()),
                          _statItem(
                            '平均重要性',
                            _memories.isEmpty
                                ? '-'
                                : (_memories
                                            .map((m) => m.importance)
                                            .reduce((a, b) => a + b) /
                                        _memories.length)
                                    .toStringAsFixed(1),
                          ),
                        ],
                      ),
                    ),

                    // 记忆列表
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _memories.length,
                        itemBuilder: (context, index) {
                          final mem = _memories[index];
                          return _buildMemoryCard(mem);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildMemoryCard(Memory mem) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          _importanceIcon(mem.importance),
          color: _importanceColor(mem.importance),
        ),
        title: Text(
          mem.content,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Text(
          '重要性: ${mem.importance}/10  ·  ${_formatDate(mem.createdAt)}',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('删除记忆'),
                content: Text('确定要忘记"${mem.content}"吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteMemory(mem.id!);
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('删除'),
                  ),
                ],
              ),
            );
          },
          tooltip: '删除',
        ),
      ),
    );
  }

  IconData _importanceIcon(int importance) {
    if (importance >= 8) return Icons.star;
    if (importance >= 5) return Icons.bookmark;
    return Icons.circle_outlined;
  }

  Color _importanceColor(int importance) {
    if (importance >= 8) return Colors.amber;
    if (importance >= 5) return Colors.blue;
    return Colors.grey;
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
