import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 桌面端：初始化 FFI databaseFactory
/// 仅在 Windows/Linux/macOS 上启用 FFI
/// Android/iOS 使用 sqflite 默认的 platform channel
void initDatabaseFactory() {
  if (Platform.isAndroid || Platform.isIOS) return;
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}
