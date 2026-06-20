/// 清理 LLM 返回的 JSON 字符串（有时会包裹在 markdown 代码块中）
String cleanJson(String raw) {
  String s = raw.trim();
  // 移除 markdown 代码块标记
  if (s.startsWith('```')) {
    s = s.substring(s.indexOf('\n') + 1);
    if (s.endsWith('```')) {
      s = s.substring(0, s.lastIndexOf('```'));
    }
  }
  return s.trim();
}
