import 'package:reframe/model/product_input_format.dart';

import '../model/deposit_product.dart';
import '../core/interceptors/http.dart';

String commonUrl = "/mobile/deposit";

Future<DepositProduct> fetchProduct(int id) async {
  try {
    final response = await dio.get('$commonUrl/detail/$id');

    if (response.statusCode == 200) {
      return DepositProduct.fromJson(response.data);
    } else {
      throw Exception('서버 오류: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('연결 실패: $e');
  }
}

// ✅ 2. 전체 상품 조회
Future<List<DepositProduct>> fetchAllProducts() async {
  final response = await dio.get('$commonUrl/list');

  if (response.statusCode == 200) {
    List<dynamic> list = response.data;
    return list.map((e) => DepositProduct.fromJson(e)).toList();
  } else {
    throw Exception('상품 전체 목록 조회 실패');
  }
}

// ✅ 3. 카테고리별 3개 미리보기
Future<Map<String, List<DepositProduct>>> fetchPreviewByCategory() async {
  final response = await dio.get('$commonUrl/preview');

  if (response.statusCode == 200) {
    final Map<String, dynamic> data = response.data;
    return data.map((key, value) {
      List<dynamic> list = value;
      return MapEntry(
        key,
        list.map((e) => DepositProduct.fromJson(e)).toList(),
      );
    });
  } else {
    throw Exception('미리보기 목록 조회 실패');
  }
}

// ✅ 4. 카테고리별 전체 상품 조회 (예금, 적금 등)
Future<List<DepositProduct>> fetchProductsByCategory(String category) async {
  final response = await dio.get(
    '$commonUrl/category',
    queryParameters: {'category': category},
  );

  if (response.statusCode == 200) {
    List<dynamic> list = response.data;
    return list.map((e) => DepositProduct.fromJson(e)).toList();
  } else {
    throw Exception('카테고리별 상품 조회 실패');
  }
}

// ✅ 5. 검색어 자동완성
Future<List<String>> fetchAutocomplete(String keyword) async {
  final response = await dio.get(
    '$commonUrl/autocomplete',
    queryParameters: {'keyword': keyword},
  );

  if (response.statusCode == 200) {
    List<dynamic> suggestions = response.data;
    return suggestions.map((e) => e.toString()).toList();
  } else {
    throw Exception('자동완성 실패');
  }
}

// ✅ 6. 검색어 + 정렬 검색
Future<List<DepositProduct>> searchProducts({
  required String keyword,
  String sort = 'recommend',
}) async {
  final response = await dio.get(
    '$commonUrl/search',
    queryParameters: {'keyword': keyword, 'sort': sort},
  );

  if (response.statusCode == 200) {
    List<dynamic> list = response.data;
    return list.map((e) => DepositProduct.fromJson(e)).toList();
  } else {
    throw Exception('상품 검색 실패');
  }
}

Future<ProductInputFormat> getProductInputFormat(int productId) async {
  final response = await dio.get('$commonUrl/format/$productId');

  if (response.statusCode == 200) {
    return ProductInputFormat.fromJson(response.data);
  } else {
    throw Exception('서버 오류: ${response.statusCode}');
  }
}
