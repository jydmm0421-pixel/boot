import 'dart:math';

/// 表情包数据
class Sticker {
  final String base64;
  final String description;
  final DateTime addedAt;

  Sticker({
    required this.base64,
    required this.description,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();
}

/// 表情包管理：保存用户发的表情包，机器人合适场合复用
class StickerService {
  final Random _random = Random();
  final List<Sticker> _stickers = [];

  /// 添加用户发的表情包
  void addSticker(String base64, String description) {
    if (_stickers.length >= 50) _stickers.removeAt(0); // 最多存50个
    _stickers.add(Sticker(base64: base64, description: description));
  }

  /// 根据描述匹配表情包
  Sticker? findSticker(String context) {
    if (_stickers.isEmpty) return null;

    // 简单关键词匹配
    final keywords = context.split(RegExp(r'[，。！？\s]+'));
    for (final kw in keywords) {
      if (kw.length < 2) continue;
      for (final sticker in _stickers.reversed) {
        if (sticker.description.contains(kw)) {
          return sticker;
        }
      }
    }
    return null;
  }

  /// 随机获取一个表情包
  Sticker? getRandom() {
    if (_stickers.isEmpty) return null;
    return _stickers[_random.nextInt(_stickers.length)];
  }

  /// 获取表情包描述列表（用于 system prompt）
  String get descriptions {
    if (_stickers.isEmpty) return '';
    final recent = _stickers.length > 10
        ? _stickers.sublist(_stickers.length - 10)
        : _stickers;
    return recent.map((s) => s.description).join('、');
  }

  int get count => _stickers.length;
}
