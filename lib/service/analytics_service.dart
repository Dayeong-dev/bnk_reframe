// analytics_service.dart
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._();
  static final FirebaseAnalytics _ga = FirebaseAnalytics.instance;

  /// 목록에서 항목 선택 -> 상세로 이동 직전
  static Future<void> logSelectProduct({
    required int productId,
    required String name,
    String? category,
    String listName = 'deposit_list',
    int? index,           // 리스트 내 위치(옵션)
    String? productType,  // 보조 분류(옵션, variant로)
  }) async {
    final item = AnalyticsEventItem(
      itemId: productId.toString(),
      itemName: name,
      itemCategory: category,
      itemVariant: productType,
      index: index,
    );

    // ✅ 전자상거래 전용 API: GA4가 요구하는 items 배열 형식으로 전송됨
    await _ga.logSelectItem(
      items: [item],
      itemListName: listName,
    );

    // (옵션) 디버그용 납작 이벤트도 함께 찍어 BigQuery에서 쉽게 확인
    await _ga.logEvent(name: 'bnk_select_item_debug', parameters: {
      'product_id': productId.toString(),
      'product_name': name,
      if (category != null) 'item_category': category,
      if (index != null) 'index': index,
      if (productType != null) 'item_variant': productType,
      'item_list_name': listName,
    });
  }

  /// 상세 화면 실제 노출 기록(원하면 붙이기)
  static Future<void> logViewProductDetail({
    required int productId,
    required String name,
    String? category,
    String? productType,
  }) async {
    final item = AnalyticsEventItem(
      itemId: productId.toString(),
      itemName: name,
      itemCategory: category,
      itemVariant: productType,
    );
    await _ga.logViewItem(items: [item]);
  }
}
