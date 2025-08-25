// analytics_service.dart
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics _ga = FirebaseAnalytics.instance;

  /// 목록에서 어떤 상품을 "선택"했는지 기록 (선택 -> 상세로 이동 직전)
  static Future<void> logSelectProduct({
    required int productId,
    required String name,
    String? category,
    String listName = 'deposit_list',
  }) async {
    // GA4 권장 전자상거래: select_item + items[]
    await _ga.logEvent(
      name: 'select_item',
      parameters: {
        'item_list_name': listName,
        'items': [
          {
            'item_id': productId.toString(), // GA4 관례상 string 권장
            'item_name': name,
            if (category != null) 'item_category': category,
          }
        ],
      },
    );
  }

  /// 상세 화면 "노출" 기록 (상세 페이지가 화면에 보일 때 1회)
  static Future<void> logViewProductDetail({
    required int productId,
    required String name,
    String? category,
    String? purpose,
    double? minRate,
    double? maxRate,
    int? period,
  }) async {
    // 1) 우리만의 커스텀 이벤트(간결, 분석용)
    await _ga.logEvent(
      name: 'view_product_detail',
      parameters: {
        'product_id': productId,
        'product_name': name,
        if (category != null) 'item_category': category,
        if (purpose  != null) 'purpose': purpose,
        if (minRate  != null) 'min_rate': minRate,
        if (maxRate  != null) 'max_rate': maxRate,
        if (period   != null) 'period': period,
      },
    );

    // 2) GA4 권장 전자상거래 이벤트(확장성 좋음)
    await _ga.logEvent(
      name: 'view_item',
      parameters: {
        'items': [
          {
            'item_id': productId.toString(),
            'item_name': name,
            if (category != null) 'item_category': category,
            if (purpose  != null) 'item_variant': purpose, // 카테고리/용도 등 보조 분류
          }
        ],
      },
    );
  }
}
