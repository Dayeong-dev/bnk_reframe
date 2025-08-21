import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/types.dart';
import '../../env/app_endpoints.dart';

class FortuneApiService {
  static Future<FortuneResponse> getFortune(FortuneRequest req) async {
    final uri = Uri.parse('${AppEndpoints.apiBase}/api/fortune');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(req.toJson()),
    );
    if (res.statusCode != 200) {
      throw Exception('fortune api error ${res.statusCode}');
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return FortuneResponse.fromJson(json);
  }
}
