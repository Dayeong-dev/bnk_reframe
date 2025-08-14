import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:reframe/pages/auth/auth_store.dart';
import 'package:http/http.dart' as http;

import '../../../constants/api_constants.dart';
import '../../../main.dart';

class ApiInterceptor extends Interceptor {
  final _secureStorage = FlutterSecureStorage();
  final retryDio = Dio(BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15)
  ));

  bool _refreshing = false;
  bool _dialogVisible = false;
  bool _navigatingToLogin = false;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    String? accessToken = getAccessToken();

    if(accessToken != null && accessToken.isNotEmpty) {
      options.headers['Authorization'] = accessToken;
    }

    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    response.requestOptions.extra.remove('__retried__');
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {

    if (err.response?.statusCode == 401 &&
        err.requestOptions.extra['__retried__'] == true) {
      return handler.next(err);
    }

    // 이미 네비 중이면 1회만
    if (_navigatingToLogin) {
      return handler.reject(DioException(
        requestOptions: err.requestOptions,
        type: DioExceptionType.cancel,
        error: 'session_expired',
      ));
    }

    if(err.response?.statusCode != 401) {
      return handler.next(err);
    }

    if(_refreshing) {
      while (_refreshing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      try {
        final req = err.requestOptions;
        final token = getAccessToken();
        if (token == null || token.isEmpty || _navigatingToLogin) {
          return handler.reject(err);
        }
        req.extra['__retried__'] = true;
        req.headers['Authorization'] = token;

        final res = await retryDio.fetch(req);
        return handler.resolve(res);
      } catch (e) {
        return handler.reject(e is DioException ? e : err);
      }
    }

    _refreshing = true;

    try {
      final refreshToken = await _secureStorage.read(key: "refreshToken");

      if (refreshToken == null || refreshToken.isEmpty) {
        String msg = "세션이 존재하지 않습니다. 다시 로그인을 진행해주세요. ";

        await failRefresh(msg);
        return handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            response: _noRefreshResponse(err, msg)
          )
        );
      }

      Uri url = Uri.parse("$apiBaseUrl/mobile/auth/refresh");

      final response = await http.post(url,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'refreshToken': refreshToken
          })
      );

      if(response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final accessToken = data['accessToken'];
        final refreshToken = data['refreshToken'];

        // Memory(전역 변수)에 Access Token 저장
        setAccessToken(accessToken);
        // Secure Storage에 Refresh Token 저장
        await _secureStorage.write(key: "refreshToken", value: refreshToken);

        // 원래 요청 재시도
        final req = err.requestOptions;
        req.extra['__retried__'] = true;
        req.headers['Authorization'] = accessToken;

        // 인터셉터 재귀 방지용
        final res = await retryDio.fetch(req);
        return handler.resolve(res);
      } else {
        String msg = "세션이 만료되었습니다. 다시 로그인을 진행해주세요. ";

        await failRefresh(msg);
        return handler.reject(
            DioException(
                requestOptions: err.requestOptions,
                response: _expiredResponse(err, msg)
            )
        );
      }
    } catch(e) {
      String msg = "네트워크 오류로 세션 갱신에 실패하였습니다. 다시 로그인을 진행해주세요. ";
      err.requestOptions.extra.remove('__retried__');

      await failRefresh(msg);
      return handler.reject(
          DioException(
              requestOptions: err.requestOptions,
              response: _networkFailResponse(err, msg)
          )
      );
    }
    finally {
      _refreshing = false;
    }
  }

  Response _noRefreshResponse(DioException err, String msg) => Response(
      requestOptions: err.requestOptions,
      statusCode: 401,
      data: {"error": msg}
  );

  Response _expiredResponse(DioException err, String msg) => Response(
      requestOptions: err.requestOptions,
      statusCode: 401,
      data: {"error": msg}
  );

  Response _networkFailResponse(DioException err, String msg) => Response(
      requestOptions: err.requestOptions,
      statusCode: 401,
      data: {"error": msg}
  );

  Future<void> failRefresh(String msg) async {
    await _secureStorage.delete(key: "refreshToken");
    clearAccessToken();

    if(_dialogVisible) {
      _navigatingToLogin = true;
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login', (route) => false, // 이전 화면 모두 제거
      );
      return;
    }

    final context = navigatorKey.currentState?.overlay?.context;

    if(context == null) {
      _navigatingToLogin = true;
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login', (route) => false, // 이전 화면 모두 제거
      );
      return;
    }

    _dialogVisible = true;
    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('세션 만료'),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(), // 닫기
                child: const Text('확인'),
              ),
            ],
          );
        }
      );
    } catch(e) {
      // 오류 처리 뭘로 하누
    } finally {
      _dialogVisible = false;
    }

    _navigatingToLogin = true;
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login', (route) => false, // 이전 화면 모두 제거
    );
  }
}