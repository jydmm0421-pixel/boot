import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Doubao-Seedance-2.0 等生图 API 服务
class ImageGenService {
  static const _defaultEndpoint =
      'https://ark.cn-beijing.volces.com/api/v3/images/generations';
  static const _defaultModel = 'doubao-seedance-2.0';

  /// 调用生图 API
  /// [prompt] 图片描述
  /// [apiKey] 火山方舟 API Key
  /// [endpoint] API 端点（可选，默认火山方舟）
  /// [model] 模型名称（可选）
  Future<Uint8List> generateImage(
    String prompt, {
    required String apiKey,
    String? endpoint,
    String? model,
    String size = '1024x1024',
  }) async {
    final url = endpoint ?? _defaultEndpoint;

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model ?? _defaultModel,
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
      throw Exception('API 返回格式异常: 未找到 b64_json');
    }

    throw Exception('生图失败: ${response.statusCode} ${response.body}');
  }
}
