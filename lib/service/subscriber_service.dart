// lib/service/subscriber_service.dart
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../core/interceptors/http.dart'; // 기존 dio 그대로 사용

class SubscriberService {
  /// 단일 상품 가입자 수 조회
  static Future<int> fetchDistinctUsers(int productId) async {
    final res = await dio.get(
      '/api/enroll/products/$productId/subscribers/distinct-count',
      options: Options(
        // 4xx라도 예외 안 던지고 우리가 처리
        validateStatus: (s) => s != null && s >= 200 && s < 500,
      ),
    );

    if (res.statusCode == 200) {
      final data = res.data;
      // { distinctUsers: 123 } 형태 가정
      if (data is Map && data['distinctUsers'] != null) {
        return (data['distinctUsers'] as num).toInt();
      }
      // 숫자만 오는 경우 허용
      if (data is num) return data.toInt();
    }

    // 200이 아니거나 파싱 실패 → 0으로 폴백
    return 0;
  }

  /// 대량 조회 (견고 버전)
  /// - 1) bulk 엔드포인트 호출
  /// - 2) 실패(404/비정상) 시 자동으로 개별 호출 배치 폴백
  static Future<Map<int, int>> fetchDistinctUsersBulk(List<int> ids) async {
    if (ids.isEmpty) return {};

    try {
      final res = await dio.post(
        '/api/enroll/subscribers/distinct-count/bulk',
        data: {'productIds': ids},
        options: Options(
          // 4xx도 예외 던지지 말고 여기서 판단
          validateStatus: (s) => s != null && s >= 200 && s < 500,
        ),
      );

      // 200 OK → 응답 파싱 시도
      if (res.statusCode == 200) {
        final data = res.data;
        final Map<int, int> out = {};

        // 응답이 {"1": 10, "2": 3} 형태
        if (data is Map) {
          data.forEach((k, v) {
            final id = int.tryParse(k.toString());
            final cnt = (v is num) ? v.toInt() : int.tryParse(v.toString());
            if (id != null && cnt != null) out[id] = cnt;
          });
          return out;
        }

        // 응답이 [{"productId":1,"distinctUsers":10}, ...] 형태
        if (data is List) {
          for (final e in data) {
            if (e is Map) {
              final id = (e['productId'] as num?)?.toInt() ??
                  int.tryParse(e['productId']?.toString() ?? '');
              final cnt = (e['distinctUsers'] as num?)?.toInt() ??
                  int.tryParse(e['distinctUsers']?.toString() ?? '');
              if (id != null && cnt != null) out[id] = cnt;
            }
          }
          return out;
        }

        // 예상 외 포맷 → 폴백
        debugPrint('[RECO] bulk 200 but unknown format → fallback to per-item');
        return _fallbackChunked(ids);
      }

      // 200 이외(예: 404) → 폴백
      debugPrint(
          '[RECO] bulk non-200 (${res.statusCode}) → fallback to per-item');
      return _fallbackChunked(ids);
    } on DioException catch (e) {
      // 네트워크/파싱 오류 → 폴백
      debugPrint('[RECO] bulk DioException: $e → fallback to per-item');
      return _fallbackChunked(ids);
    } catch (e) {
      debugPrint('[RECO] bulk unexpected error: $e → fallback to per-item');
      return _fallbackChunked(ids);
    }
  }

  /// 개별 조회 폴백: 배치+동시성 제한으로 과도한 동시 요청 방지
  static Future<Map<int, int>> _fallbackChunked(
    List<int> ids, {
    int batchSize = 10, // 배치당 개수
  }) async {
    final out = <int, int>{};

    for (int i = 0; i < ids.length; i += batchSize) {
      final end = math.min(i + batchSize, ids.length);
      final batch = ids.sublist(i, end);

      await Future.wait(batch.map((pid) async {
        try {
          final cnt = await fetchDistinctUsers(pid);
          out[pid] = cnt;
          debugPrint('[RECO] per-item OK pid=$pid cnt=$cnt');
        } catch (e) {
          // 실패는 0으로 폴백 (정렬에서 뒤로 밀리도록)
          out[pid] = 0;
          debugPrint('[RECO] per-item FAIL pid=$pid err=$e');
        }
      }));
    }

    return out;
  }
}
