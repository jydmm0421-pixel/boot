import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/setup_screen.dart';
import 'screens/home_screen.dart';
import 'services/config_service.dart';

class CyberExApp extends StatelessWidget {
  const CyberExApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CyberEx',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF07C160), // 微信绿
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF07C160),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif',
      ),
      themeMode: ThemeMode.system,
      home: const StartupGate(),
    );
  }
}

/// 启动网关：检查是否已完成初始化
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool _loading = true;
  bool _isSetup = false;

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    final config = context.read<ConfigService>();
    final setup = await config.isSetupComplete();
    if (mounted) {
      setState(() {
        _isSetup = setup;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isSetup) {
      return const HomeScreen();
    }

    return const SetupScreen();
  }
}
