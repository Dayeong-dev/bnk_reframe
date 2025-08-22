import 'dart:convert';

import 'package:reframe/model/account.dart';

import '../core/interceptors/http.dart';

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

Future<String> fetchAccountDetail(int accountId) async {
  try {
    final response = await dio.get(
        '$commonUrl/detail/$accountId'
    );

    if (response.statusCode == 200) {
      return const JsonEncoder.withIndent('  ').convert(response.data);
    } else {
      throw Exception('서버 오류: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('연결 실패: $e');
  }
}
