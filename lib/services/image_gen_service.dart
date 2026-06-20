import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// 火山方舟 Seedream 生图 API 服务
/// 需要在火山方舟控制台创建推理端点，获取端点 ID (ep-xxx)
class ImageGenService {
  static const _defaultEndpoint =
      'https://ark.cn-beijing.volces.com/api/v3/images/generations';

  /// 调用生图 API
  /// [prompt] 图片描述
  /// [apiKey] 火山方舟 API Key
  /// [model] 模型名称或推理端点 ID (如 ep-20250101-xxxxx)
  Future<Uint8List> generateImage(
    String prompt, {
    required String apiKey,
    required String model,
    String size = '2K',
  }) async {
    final response = await http.post(
      Uri.parse(_defaultEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'prompt': prompt,
        'size': size,
        'n': 1,
        'response_format': 'b64_json',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final b64 = data['data']?[0]?['b64_json'] as String?;
      if (b64 != null) {
        return base64Decode(b64);
      }
      throw Exception('API 返回格式异常: ${response.body}');
    }

    throw Exception('生图失败: ${response.statusCode} ${response.body}');
  }
}
