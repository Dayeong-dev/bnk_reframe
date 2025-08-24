import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:reframe/model/account.dart';

import '../core/interceptors/http.dart';
import '../model/account_transaction.dart';
import '../model/product_account_detail.dart';

String commonUrl = "/mobile/account";

Future<List<Account>> fetchAccounts(AccountType? type) async {
  try {
    final response = await dio.get(
      '$commonUrl/my',
      queryParameters: type == null ? null : {"type": type.name.toUpperCase()}
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = response.data; // JSON 배열

      return data.map((json) => Account.fromJson(json)).toList();
    } else {
      throw Exception('서버 오류: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('연결 실패: $e');
  }
}

Future<ProductAccountDetail> fetchAccountDetail(int accountId) async {
  try {
    final response = await dio.get(
        '$commonUrl/detail/$accountId'
    );

    if (response.statusCode == 200) {
      final data = response.data is String ? jsonDecode(response.data) : response.data;

      return ProductAccountDetail.fromJson(data as Map<String, dynamic>);
    } else {
      throw Exception('서버 오류: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('연결 실패: $e');
  }
}

Future<ProductAccountDetail> fetchAccountDetailModel(int accountId) async {
  final res = await dio.get('$commonUrl/detail/$accountId');
  if (res.statusCode == 200) {
    final data = res.data is String ? jsonDecode(res.data) : res.data;
    return ProductAccountDetail.fromJson(data as Map<String, dynamic>);
  }
  throw Exception('서버 오류: ${res.statusCode}');
}

Future<PagedTx> fetchAccountTransactions(int accountId, {int page = 0, int size = 30}) async {
    try {
        final res = await dio.get('/mobile/account/$accountId/transactions',
            queryParameters: {'page': page, 'size': size});
        if (res.statusCode == 200) {
          final body = res.data;
          // Spring Page 응답 가정: content, last, number
          final List list = (body['content'] as List? ?? const []);
          final items = list.map((e) => AccountTransaction.fromJson(e as Map<String, dynamic>)).toList();
          final last = (body['last'] as bool?) ?? true;
          final number = (body['number'] as num?)?.toInt() ?? page;
          return PagedTx(items: items, hasMore: !last, nextPage: number + 1);
        }
        throw Exception('거래내역 불러오기 실패: ${res.statusCode}');

    } catch (e) {
        throw Exception('연결 실패: $e');
    }
}

Future<void> payMonthlySaving(int applicationId) async {
  final res = await dio.post(
    '/mobile/account/pay',
    data: {'applicationId': applicationId},
    // 선택) 멱등키 헤더를 함께 보내 중복 클릭을 안전하게 막고 싶다면:
    // options: Options(headers: {'X-Idempotency-Key': const Uuid().v4()}),
  );
  // 서버가 204 No Content로 줄 수도 있으니 200/204 모두 성공으로 처리
  if (res.statusCode != 200 && res.statusCode != 204) {
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      error: '서버 오류',
    );
  }
}

Future<void> depositToGroup(int accountId, {required int fromAccountId, required int amount}) async {
  final res = await dio.post('/mobile/account/$accountId/deposit', data: {
    'fromAccountId': fromAccountId,
    'amount': amount,
  });
  if (res.statusCode != 200 && res.statusCode != 204) {
    throw DioException(
      requestOptions: res.requestOptions,
      response: res,
      error: '입금 실패',
      type: DioExceptionType.badResponse,
    );
  }
}