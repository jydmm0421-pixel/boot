import 'package:flutter/material.dart';

/// 对方正在输入动画
class TypingIndicator extends StatefulWidget {
  final String text;

  const TypingIndicator({
    super.key,
    this.text = '对方正在输入',
  });

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 4),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
              child: Icon(Icons.person, size: 20, color: Colors.grey[600]),
            ),
          ),
          FadeTransition(
            opacity: _animation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.text,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(width: 4),
                  _buildDot(0),
                  _buildDot(200),
                  _buildDot(400),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Opacity(
          opacity: 0.3 + 0.7 * ((value + delayMs / 1000) % 1.0).clamp(0.0, 0.7),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey[500],
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
