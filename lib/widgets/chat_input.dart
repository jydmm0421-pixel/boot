import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// 聊天输入栏 — 支持文字、图片、表情、自定义表情包
class ChatInput extends StatefulWidget {
  final Function(String) onSend;
  final Function(XFile)? onSendImage;
  final bool enabled;

  const ChatInput({
    super.key,
    required this.onSend,
    this.onSendImage,
    this.enabled = true,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _picker = ImagePicker();
  bool _showEmoji = false;
  bool _showStickers = false;

  // 用户自定义表情包
  final List<StickerItem> _customStickers = [];

  static const _emojiList = [
    ['😀','😃','😄','😁','😆','😅','🤣','😂','🙂','😊','😇','🥰','😍','🤩','😘','😗','😚','😋','😛','😜','🤪','😝','🤑','🤗','🤭','🤫','🤔','🤐','🤨','😐','😑','😶','😏','😒','🙄','😬'],
    ['❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔','💕','💞','💓','💗','💖','💝','💘','💌','💟','♥️','💋','💯','💥','💫','💦','💨','💢','💤','💬','🌸','💐','🌹','🌺','🌻','🌼','🌷','🌱','🌿','🍀'],
    ['🐶','🐱','🐭','🐹','🐰','🦊','🐻','🐼','🐨','🐯','🦁','🐮','🐷','🐸','🐵','🐔','🐧','🐦','🐤','🐣','🐥','🦆','🦅','🦉','🦇','🐺','🐗','🐴','🦄','🐝','🐛','🦋','🐌','🐞','🐜','🦋','🐙','🦑','🐬','🐳'],
    ['👍','👎','👌','✌️','🤞','🤟','🤘','🤙','👈','👉','👆','👇','☝️','✋','🤚','🖐️','🖖','👋','🤏','✍️','👏','🙌','🤲','🙏','🤝','💪','👀','👁️','👅','👄','🎉','🎊','🎂','🍰','🎈','🎁','🏆','🔥','⭐','🌟','✨','⚡','💧','🌊','💎','💰'],
    ['(￣▽￣)','(╯︵╰)','(◕‿◕)','(｡•́︿•̀｡)','(◔‿◔)','(╥﹏╥)','(≧∇≦)','(´･ω･`)','(╯°□°）╯','(¬‿¬)','(´▽｀)','(・∀・)','(゜-゜)','(✿◠‿◠)','(๑•̀ㅂ•́)و','(╹ڡ╹ )','(つ≧▽≦)つ','(☞ﾟヮﾟ)☞'],
  ];
  static const _tabLabels = ['😀', '💖', '🐾', '👋', '≧∇≦'];

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    _showEmoji = false;
    _showStickers = false;
    _focusNode.requestFocus();
  }

  void _insertEmoji(String emoji) {
    final text = _controller.text;
    final sel = _controller.selection;
    if (sel.start < 0) {
      _controller.text += emoji;
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    } else {
      final newText = text.replaceRange(sel.start, sel.end, emoji);
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(offset: sel.start + emoji.length);
    }
  }

  // Enter 发送，Shift+Enter 换行
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
      if (HardwareKeyboard.instance.isShiftPressed ||
          HardwareKeyboard.instance.isControlPressed) {
        return KeyEventResult.ignored; // Shift/Ctrl+Enter = 换行
      }
      _handleSend();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024, maxHeight: 1024, imageQuality: 85,
    );
    if (file != null && widget.onSendImage != null) {
      widget.onSendImage!(file);
    }
  }

  /// 添加自定义表情包
  Future<void> _addSticker() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512, maxHeight: 512, imageQuality: 80,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final base64 = base64Encode(bytes);
    setState(() {
      _customStickers.add(StickerItem(base64: base64));
      _showStickers = true;
      _showEmoji = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 表情/贴图面板
        if (_showEmoji || _showStickers)
          Container(
            height: 260,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[100],
              border: Border(top: BorderSide(color: Colors.grey[300]!, width: 0.5)),
            ),
            child: _showStickers
                ? _buildStickerPanel(isDark)
                : _EmojiGrid(onSelect: _insertEmoji, emojiList: _emojiList, tabLabels: _tabLabels),
          ),

        Container(
          padding: EdgeInsets.only(
            left: 12, right: 8, top: 8,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[100],
            border: Border(top: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[300]!, width: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 表情按钮
              IconButton(
                icon: Icon(_showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined, color: Colors.grey[600]),
                onPressed: () => setState(() { _showEmoji = !_showEmoji; _showStickers = false; }),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              // 贴图按钮
              IconButton(
                icon: Icon(_showStickers ? Icons.keyboard : Icons.sticky_note_2_outlined, color: Colors.grey[600]),
                onPressed: () {
                  if (_customStickers.isEmpty) {
                    _addSticker();
                  } else {
                    setState(() { _showStickers = !_showStickers; _showEmoji = false; });
                  }
                },
                onLongPress: _addSticker,
                padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              // 图片按钮
              IconButton(
                icon: Icon(Icons.image_outlined, color: Colors.grey[600]),
                onPressed: widget.enabled ? _pickImage : null,
                padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              // 输入框
              Expanded(
                child: Focus(
                  onKeyEvent: _onKey,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSend(),
                    decoration: InputDecoration(
                      hintText: 'Enter发送 / Shift+Enter换行',
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                      filled: true,
                      fillColor: isDark ? Colors.grey[850] : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                    ),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.send_rounded),
                color: const Color(0xFF07C160),
                onPressed: widget.enabled ? _handleSend : null,
                padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStickerPanel(bool isDark) {
    if (_customStickers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text('点击 + 添加表情包', style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addSticker,
              icon: const Icon(Icons.add),
              label: const Text('添加表情包'),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8),
      itemCount: _customStickers.length,
      itemBuilder: (ctx, i) => GestureDetector(
        onTap: () {
          if (widget.onSendImage != null) {
            // 直接发图
            _showStickers = false;
            _showEmoji = false;
          }
        },
        onLongPress: () => setState(() => _customStickers.removeAt(i)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(base64Decode(_customStickers[i].base64), fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class StickerItem {
  final String base64;
  StickerItem({required this.base64});
}

/// 表情选择网格
class _EmojiGrid extends StatefulWidget {
  final Function(String) onSelect;
  final List<List<String>> emojiList;
  final List<String> tabLabels;
  const _EmojiGrid({required this.onSelect, required this.emojiList, required this.tabLabels});
  @override
  State<_EmojiGrid> createState() => _EmojiGridState();
}

class _EmojiGridState extends State<_EmojiGrid> {
  int _tabIndex = 0;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: GridView.count(
          crossAxisCount: 8, padding: const EdgeInsets.all(8),
          children: widget.emojiList[_tabIndex].map((e) =>
            GestureDetector(
              onTap: () => widget.onSelect(e),
              child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
            )).toList(),
        ),
      ),
      Container(height: 36, decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[300]!, width: 0.5))),
        child: Row(
          children: List.generate(widget.tabLabels.length, (i) => Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tabIndex = i),
              child: Container(
                color: _tabIndex == i ? Colors.grey[300] : null,
                child: Center(child: Text(widget.tabLabels[i], style: const TextStyle(fontSize: 18))),
              ),
            ),
          )),
        ),
      ),
    ]);
  }
}
