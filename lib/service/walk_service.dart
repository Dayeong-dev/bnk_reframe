import '../core/interceptors/http.dart';

String commonUrl = "/mobile/walk";

Future<WalkSyncResponse> fetchWalkSync(int appId, int steps) async {
  try {
    final response = await dio.post('$commonUrl/sync/$appId', data: {
      'stepsTodayTotal': steps,
    });

    if (response.statusCode == 200) {
      return WalkSyncResponse.fromJson(response.data);
    } else {
      throw Exception('서버 오류: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('연결 실패: $e');
  }
}

Future<WalkSyncResponse> fetchWalkSummary(int appId) async {
  try {
    final response = await dio.get('$commonUrl/summary/$appId'); // GET /mobile/walk/summary/{appId}

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      return WalkSyncResponse.fromJson(data);
    } else {
      throw Exception('서버 오류: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('연결 실패: $e');
  }
}

class WalkSyncResponse {
  final int stepsThisMonth;
  final int threshold;
  final bool confirmedThisMonth;
  final double preferentialRate;
  final double effectiveRate;
  final int todaySteps;
  final DateTime? lastSyncDate; // nullable 권장

  WalkSyncResponse({
    required this.stepsThisMonth,
    required this.threshold,
    required this.confirmedThisMonth,
    required this.preferentialRate,
    required this.effectiveRate,
    required this.todaySteps,
    required this.lastSyncDate,
  });

  factory WalkSyncResponse.fromJson(Map<String, dynamic> j) {
    num _num(dynamic v) =>
        (v is num) ? v : (v is String ? num.tryParse(v) ?? 0 : 0);
    DateTime? _date(dynamic v) =>
        (v is String && v.isNotEmpty) ? DateTime.tryParse(v) : null;

    return WalkSyncResponse(
      stepsThisMonth: _num(j['stepsThisMonth']).toInt(),
      threshold: _num(j['threshold']).toInt(),
      confirmedThisMonth: j['confirmedThisMonth'] as bool? ?? false,
      preferentialRate: _num(j['preferentialRate']).toDouble(),
      effectiveRate: _num(j['effectiveRate']).toDouble(),
      todaySteps: _num(j['todaySteps']).toInt(),
      lastSyncDate: _date(j['lastSyncDate']),
    );
  }
}
