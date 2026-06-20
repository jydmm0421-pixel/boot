import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:dart_iztro/dart_iztro.dart';
import 'services/config_service.dart';
import 'services/database_service.dart';
import 'services/llm_service.dart';
import 'services/memory_service.dart';
import 'services/personality_service.dart';
import 'services/fortune_service.dart';
import 'services/humanizer_service.dart';
import 'services/sticker_service.dart';
import 'app.dart';
import 'database_init_stub.dart'
    if (dart.library.io) 'database_init_io.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 dart_iztro 的 GetX 翻译服务（必须在使用算命功能前调用）
  IztroTranslationService.init(initialLocale: 'zh_CN');
  Get.addTranslations(IztroTranslationService().keys);

  // 桌面端需要用 FFI 初始化 databaseFactory
  initDatabaseFactory();

  final configService = ConfigService();
  final databaseService = DatabaseService();
  final llmService = LlmService();
  final memoryService = MemoryService();
  final personalityService = PersonalityService();
  final fortuneService = FortuneService();
  final stickerService = StickerService();
  final humanizerService = HumanizerService();

  runApp(
    MultiProvider(
      providers: [
        Provider<ConfigService>.value(value: configService),
        Provider<DatabaseService>.value(value: databaseService),
        Provider<LlmService>.value(value: llmService),
        Provider<MemoryService>.value(value: memoryService),
        Provider<PersonalityService>.value(value: personalityService),
        Provider<FortuneService>.value(value: fortuneService),
        Provider<StickerService>.value(value: stickerService),
        Provider<HumanizerService>.value(value: humanizerService),
      ],
      child: const CyberExApp(),
    ),
  );
}
