import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'services/config_service.dart';
import 'services/database_service.dart';
import 'services/llm_service.dart';
import 'services/memory_service.dart';
import 'services/personality_service.dart';
import 'services/humanizer_service.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 桌面端需要用 FFI 初始化 databaseFactory，否则会报错：
  // "databaseFactory not initialized"
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final configService = ConfigService();
  final databaseService = DatabaseService();
  final llmService = LlmService();
  final memoryService = MemoryService();
  final personalityService = PersonalityService();
  final humanizerService = HumanizerService();

  runApp(
    MultiProvider(
      providers: [
        Provider<ConfigService>.value(value: configService),
        Provider<DatabaseService>.value(value: databaseService),
        Provider<LlmService>.value(value: llmService),
        Provider<MemoryService>.value(value: memoryService),
        Provider<PersonalityService>.value(value: personalityService),
        Provider<HumanizerService>.value(value: humanizerService),
      ],
      child: const CyberExApp(),
    ),
  );
}
