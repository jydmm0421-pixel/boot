import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/config_service.dart';
import 'chat_screen.dart';
import 'fortune_screen.dart';
import 'memory_screen.dart';
import 'settings_screen.dart';

/// 主界面：底部导航切换聊天/记忆/设置
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _exName = 'TA';
  String? _userAvatar;
  String? _botAvatar;
  final _memoryKey = GlobalKey<MemoryScreenState>();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final config = context.read<ConfigService>();
    final name = await config.getExName();
    final userAvatar = await config.getUserAvatar();
    final botAvatar = await config.getBotAvatar();
    if (mounted) {
      setState(() {
        _exName = name;
        _userAvatar = userAvatar;
        _botAvatar = botAvatar;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      ChatScreen(exName: _exName, userAvatar: _userAvatar, botAvatar: _botAvatar),
      MemoryScreen(key: _memoryKey),
      const FortuneScreen(),
      SettingsScreen(
        onNameChanged: (name) => setState(() => _exName = name),
        onAvatarChanged: _loadSettings,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          // 切换到记忆 tab 时自动刷新
          if (index == 1) {
            _memoryKey.currentState?.refresh();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: '聊天',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology),
            label: '记忆',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: '命盘',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
