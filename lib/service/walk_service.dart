import '../core/interceptors/http.dart';

String commonUrl = "/mobile/walk";

Future<void> fetchWalkSync(int appId, int steps) async {
  try {
    final response = await dio.post('$commonUrl/sync', data: {
      'appId': appId,
      'stepsTodayTotal': steps, // "오늘 누적" 그대로 보냄(서버가 증분 계산)
    });

    if (response.statusCode == 200) {
      return;
    } else {
      throw Exception('서버 오류: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('연결 실패: $e');
  }
}
