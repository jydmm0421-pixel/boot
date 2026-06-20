import 'package:sqflite_common/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web 端：使用 WebAssembly 版本的 databaseFactory（无 Shared Worker）
/// 此文件仅在 dart.library.io 不可用时加载（即 Web 平台）
void initDatabaseFactory() {
  // 使用 noWebWorker 模式：不需要 sqflite_sw.js 文件
  // SQLite 在主线程运行，仅需 sqlite3.wasm 文件放在 web/ 目录
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
}
