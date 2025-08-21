import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'qna_model.dart';

class QnaApiService {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  // 예: https://api.example.com
  final String baseUrl;

  QnaApiService({
    required this.baseUrl,
    Dio? dio,
    FlutterSecureStorage? storage,
  })  : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage();

  Future<String?> _getToken() async {
    // 프로젝트에서 실제 저장 키를 사용해줘
    return await _storage.read(key: 'accessToken');
  }

  Future<List<Qna>> fetchMyQnaList() async {
    final token = await _getToken();
    final res = await _dio.get(
      '$baseUrl/mobile/qna',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    final data = (res.data as List).cast<Map<String, dynamic>>();
    return data.map((e) => Qna.fromJson(e)).toList();
  }

  Future<Qna> fetchDetail(int qnaId) async {
    final token = await _getToken();
    final res = await _dio.get(
      '$baseUrl/mobile/qna/$qnaId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Qna.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Qna> create({
    required String category,
    required String title,
    required String content,
  }) async {
    final token = await _getToken();
    final res = await _dio.post(
      '$baseUrl/mobile/qna',
      data: {
        'category': category,
        'title': title,
        'content': content,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Qna.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Qna> update({
    required int qnaId,
    required String category,
    required String title,
    required String content,
  }) async {
    final token = await _getToken();
    final res = await _dio.put(
      '$baseUrl/mobile/qna/$qnaId',
      data: {
        'category': category,
        'title': title,
        'content': content,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return Qna.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> delete(int qnaId) async {
    final token = await _getToken();
    await _dio.delete(
      '$baseUrl/mobile/qna/$qnaId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }
}
