import 'dart:async';
import 'package:flutter/material.dart';
import '../models/fortune_result.dart';

/// 话题选择 + AI 流式解读展示
class FortuneInterpreter extends StatefulWidget {
  final FortuneResult? result;
  final Stream<String> Function(String topic)? onInterpret;
  final VoidCallback? onReset;

  const FortuneInterpreter({
    super.key,
    this.result,
    this.onInterpret,
    this.onReset,
  });

  @override
  State<FortuneInterpreter> createState() => _FortuneInterpreterState();
}

class _FortuneInterpreterState extends State<FortuneInterpreter> {
  static const _topics = ['综合运势', '姻缘感情', '事业财运', '近期运势'];

  String _selectedTopic = '综合运势';
  bool _isStreaming = false;
  String _fullResponse = '';
  final _scrollController = ScrollController();
  StreamSubscription<String>? _subscription;

  void _startInterpret() {
    if (widget.onInterpret == null || widget.result == null) return;

    setState(() {
      _isStreaming = true;
      _fullResponse = '';
    });

    final stream = widget.onInterpret!(_selectedTopic);
    _subscription = stream.listen(
      (chunk) {
        _fullResponse += chunk;
        if (mounted) {
          setState(() {});
          _scrollToBottom();
        }
      },
      onDone: () {
        if (mounted) setState(() => _isStreaming = false);
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _isStreaming = false;
            _fullResponse = '解读出错: $e';
          });
        }
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasContent = _isStreaming || _fullResponse.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 话题选择
        if (!hasContent) ...[
          const Text('想了解什么？',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _topics.map((t) {
              final selected = _selectedTopic == t;
              return ChoiceChip(
                label: Text(t),
                selected: selected,
                onSelected: (v) {
                  if (v) setState(() => _selectedTopic = t);
                },
                selectedColor:
                    Theme.of(context).colorScheme.primaryContainer,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _startInterpret,
            icon: const Icon(Icons.auto_awesome),
            label: Text('AI 解读$_selectedTopic'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.all(14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 解读输出
        if (hasContent) ...[
          const Text('AI 解读结果',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 450),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.result != null) ...[
                          _buildSummaryRow(widget.result!),
                          const Divider(),
                        ],
                        SelectableText(
                          _fullResponse.isEmpty && _isStreaming
                              ? '正在解读中...'
                              : _fullResponse,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (_isStreaming) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!_isStreaming && _fullResponse.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color:
                              isDark ? Colors.grey[800]! : Colors.grey[200]!,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: _startInterpret,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('换话题'),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            _fullResponse = '';
                            _isStreaming = false;
                          }),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text('选话题'),
                        ),
                        if (widget.onReset != null)
                          TextButton.icon(
                            onPressed: widget.onReset,
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('重新排盘'),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryRow(FortuneResult f) {
    final parts = <String>[];
    if (f.baZi != null) {
      parts.add(
        '${f.baZi!.yearPillar.fullName} ${f.baZi!.monthPillar.fullName} '
        '${f.baZi!.dayPillar.fullName} ${f.baZi!.hourPillar.fullName}',
      );
    }
    if (f.soulPalace != null && f.soulPalace!.majorStars.isNotEmpty) {
      parts.add('命宫${f.soulPalace!.majorStars.take(2).join("、")}');
    }
    return Text(
      parts.join('  ·  '),
      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
    );
  }
}
