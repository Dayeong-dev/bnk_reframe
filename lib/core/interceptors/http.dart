import 'package:dio/dio.dart';
import 'package:reframe/core/interceptors/api_Interceptor.dart';
import '../../../constants/api_constants.dart';

final Dio dio = Dio(BaseOptions(
    baseUrl: apiBaseUrl,
    contentType: Headers.jsonContentType,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 15)))
  ..interceptors.add(ApiInterceptor())
  ..interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
