import 'package:reframe/core/interceptors/http.dart';
import 'package:reframe/model/product_application.dart';

String applicationUrl = "/mobile/application";

Future<List<ProductApplication>> getMyApplications() async {
  try {
    final response = await dio.get('$applicationUrl/my');

    if (response.statusCode == 200) {
      final List<dynamic> data = response.data; // JSON 배열

      return data.map((json) => ProductApplication.fromJson(json)).toList();
    } else {
      throw Exception('서버 오류: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('연결 실패: $e');
  }
}