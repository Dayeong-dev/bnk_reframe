import 'package:dio/dio.dart';
import '../core/interceptors/http.dart';
import 'package:reframe/model/realname_verification.dart';

String commonUrl = "/mobile/verification";

Future<RealnameVerification?> checkStatus() async {
  try {
    final response = await dio.get(
      "$commonUrl/status",
      options: Options(validateStatus: (s) => s != null && s < 500),
    );

    if (response.statusCode == 200) {
      return RealnameVerification.fromJson(response.data);
    }
    if (response.statusCode != null && response.statusCode! >= 400 && response.statusCode! < 500) {
      return null;
    }

    return null;
  } on DioException {
    rethrow;
  }
}

Future<String> requestCode(RealnameVerification form) async {
  try {
    final response = await dio.post(
      "$commonUrl/request-code",
      data: form,
      options: Options(validateStatus: (s) => s != null && s < 500),
    );

    if (response.statusCode == 200) {
      return response.data as String;
    } else {
      throw Exception('서버 오류: ${response.statusCode}');
    }
  } catch(e) {
    throw Exception('연결 실패: $e');
  }
}

Future<bool> verifyCode(RealnameVerification form, String inputCode) async {
  try {
    final response = await dio.post(
      "$commonUrl/verify-code",
      queryParameters: {"inputCode": inputCode},
      data: form.toJson(),
      options: Options(validateStatus: (s) => s != null && s < 500),
    );

    if (response.statusCode == 200) {
      final str = (response.data as String).toUpperCase();
      return str == "VERIFIED";
    } else {
      throw Exception('서버 오류: ${response.statusCode}');
    }
  } catch(e) {
    throw Exception('연결 실패: $e');
  }
}