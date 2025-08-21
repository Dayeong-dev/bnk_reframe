import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:reframe/pages/enroll/enroll_first.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

// 모델/서비스
import 'package:reframe/model/deposit_product.dart';
import 'package:reframe/service/deposit_service.dart';

// 리뷰 페이지
import 'package:reframe/pages/review/review_page.dart';

// Netty WebSocket
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/io.dart' as ws_io;

// 엔드포인트
import 'package:reframe/env/app_endpoints.dart';

/// =======================================================
///  DepositDetailPage (심플 센터 정렬 버전)
/// =======================================================

const _brand = Color(0xFF304FFE);
const _bg = Colors.white;

class DepositDetailPage extends StatefulWidget {
  final int productId;
  const DepositDetailPage({super.key, required this.productId});

  @override
  State<DepositDetailPage> createState() => _DepositDetailPageState();
}

/// 화면에 들어오면 1회만 페이드+슬라이드 인
class FadeSlideInOnVisible extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Offset beginOffset;
  const FadeSlideInOnVisible({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 380),
    this.beginOffset = const Offset(0, .06),
  });

  @override
  State<FadeSlideInOnVisible> createState() => _FadeSlideInOnVisibleState();
}

class _FadeSlideInOnVisibleState extends State<FadeSlideInOnVisible>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _ac,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slide = Tween(
    begin: widget.beginOffset,
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
  bool _played = false;

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: widget.key ?? UniqueKey(),
      onVisibilityChanged: (info) {
        if (!_played && info.visibleFraction > 0.15) {
          _played = true;
          _ac.forward();
        }
      },
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      ),
    );
  }
}

class _DepositDetailPageState extends State<DepositDetailPage> {
  DepositProduct? product;

  // Analytics
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  bool _pvLogged = false;

  // 실시간(WebSocket)
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;

  // 프레즌스(동시 시청자) 표시용
  int _presenceOthers = 0; // 본인 제외 후 표시

  String _productTypeOf(DepositProduct p) {
    final c = (p.category ?? '').trim();
    if (c == '입출금자유') return '입출금';
    if (c.isEmpty) return '기타';
    return c;
  }

  Future<void> _logProductViewOnce(DepositProduct p) async {
    if (_pvLogged) return;
    _pvLogged = true;
    await _analytics.logEvent(name: 'product_view', parameters: {
      'product_id': '${p.productId}',
      'product_type': _productTypeOf(p),
      'category': p.category ?? '',
    });
    await _analytics.logScreenView(
      screenName: 'DepositDetail',
      screenClass: 'DepositDetailPage',
    );
  }

  Future<void> _logDetailCta(String action) async {
    final p = product;
    if (p == null) return;
    await _analytics.logEvent(name: 'detail_cta_click', parameters: {
      'product_id': '${p.productId}',
      'product_type': _productTypeOf(p),
      'action': action,
    });
  }

  @override
  void initState() {
    super.initState();
    loadProduct();
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _ws?.sink.close(ws_status.goingAway);
    super.dispose();
  }

  Future<void> loadProduct() async {
    try {
      final result = await fetchProduct(widget.productId);
      if (!mounted) return;
      setState(() => product = result);
      await _logProductViewOnce(result);
      _connectAndSubscribe(result.productId);
    } catch (e) {
      debugPrint("❌ 상품 불러오기 실패: $e");
    }
  }

  /// 하나의 소켓으로 리뷰/프레즌스 두 토픽 구독
  void _connectAndSubscribe(int productId) {
    final wsUrl = Uri.parse('${AppEndpoints.wsBase}?topic=product.$productId.reviews');
    debugPrint('🔌 WS connect → $wsUrl');
    try {
      _ws = ws_io.IOWebSocketChannel.connect(wsUrl.toString());

      // 연결되자마자 안전빵 수동 구독 프레임(리뷰 + 프레즌스)
      _ws!.sink.add(jsonEncode({
        "op": "subscribe",
        "topics": ["product.$productId.reviews", "product.$productId.presence"]
      }));

      _wsSub = _ws!.stream.listen((raw) {
        try {
          final String text = raw is String ? raw : raw.toString();
          debugPrint('📩 WS recv: $text');
          final Map<String, dynamic> msg = jsonDecode(text);

          final type = msg['type'];
          if (type == 'review_created' && mounted) {
            final author = (msg['authorMasked'] as String?) ?? '고객';
            final rating = (msg['rating'] as num?)?.toInt() ?? 0;
            final snippet = (msg['contentSnippet'] as String?) ?? '';
            _showReviewBannerDetailed(
              authorMasked: author,
              rating: rating,
              snippet: snippet,
            );
          } else if (type == 'presence' && mounted) {
            final count = (msg['count'] as num?)?.toInt() ?? 0;
            // 본인 제외하고 표시
            final others = (count - 1).clamp(0, 9999);
            setState(() => _presenceOthers = others);
          }
        } catch (e) {
          debugPrint('WS parse error: $e'); // ping 등 문자열이면 무시
        }
      }, onError: (e) {
        debugPrint('WS error: $e');
      }, onDone: () {
        debugPrint('WS closed.');
      });
    } catch (e) {
      debugPrint('WebSocket connect fail: $e');
    }
  }

  /// 상단 프레즌스 배너
  Widget _presenceBanner() {
    if (_presenceOthers <= 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility, color: Color(0xFF1565C0)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '현재 $_presenceOthers명이 이 상품을 보고 있습니다.',
              style: const TextStyle(
                color: Color(0xFF0D47A1),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 상세 배너 (박**님이 ★★★★★ 리뷰 등록: ‘…’)
  void _showReviewBannerDetailed({
    required String authorMasked,
    required int rating,
    required String snippet,
  }) {
    final stars = '★★★★★'.substring(0, rating.clamp(0, 5));
    final msg = "$authorMasked님이 $stars 리뷰 등록: ‘$snippet’";

    final snack = SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(12),
      backgroundColor: const Color(0xFF1565C0), // 파란 말풍선
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: Row(
        children: [
          const Icon(Icons.chat_bubble, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              msg,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              final p = product;
              if (p != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReviewPage(
                      productId: p.productId,
                      productName: p.name,
                    ),
                  ),
                );
              }
            },
            child: const Text('보기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      duration: const Duration(seconds: 4),
    );

    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(snack); // 하단에 표시
  }

  // --------- 내용 렌더링 유틸 ----------
  String fixLineBreaks(String text) {
    return text
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<br />', '\n')
        .replaceAll('\\n', '\n')
        .trim();
  }

  String toHtmlBreaks(String text) =>
      fixLineBreaks(text).replaceAll('\n', '<br />');

  String normalizeHtml(String html, {String? titleToStrip}) {
    var h = html.replaceAll('\uFEFF', '').trim();
    h = h.replaceAll('&nbsp;', ' ').replaceAll('\u00A0', ' ');

    final leadingEmpty = RegExp(
      r'^((?:\s|<br\s*/?>)+|<(?:p|div|section|article|span)[^>]*>\s*</(?:p|div|section|article|span)>)+',
      caseSensitive: false,
    );
    while (leadingEmpty.hasMatch(h)) {
      h = h.replaceFirst(leadingEmpty, '');
    }

    if (titleToStrip != null && titleToStrip.trim().isNotEmpty) {
      final t = RegExp.escape(titleToStrip.trim());
      final dupTitle = RegExp(
        r'^(?:<(?:h[1-6]|p|div)[^>]*>\s*' + t + r'\s*</(?:h[1-6]|p|div)>\s*)+',
        caseSensitive: false,
      );
      h = h.replaceFirst(dupTitle, '');
      while (leadingEmpty.hasMatch(h)) {
        h = h.replaceFirst(leadingEmpty, '');
      }
    }

    h = h.replaceAll(
      RegExp(r'(<br\s*/?>\s*){2,}', caseSensitive: false),
      '<br />',
    );
    h = h.replaceFirst(RegExp(r'(\s|<br\s*/?>)+$', caseSensitive: false), '');
    return h;
  }

  String cutHeadBeforeFirstTable(String html, {String? titleToStrip}) {
    if (html.isEmpty) return html;
    var h = html.replaceAll('\uFEFF', '').replaceAll('&nbsp;', ' ').trimLeft();
    if (titleToStrip != null && titleToStrip.isNotEmpty) {
      final t = RegExp.escape(titleToStrip.trim());
      h = h.replaceFirst(
        RegExp(r'^\s*' + t + r'\s*(<br\s*/?>|\s)*', caseSensitive: false),
        '',
      );
    }
    final lower = h.toLowerCase();
    final idx = lower.indexOf('<table');
    if (idx > 0) h = h.substring(idx);
    h = h.replaceAll(
      RegExp(r'(<br\s*/?>\s*){2,}', caseSensitive: false),
      '<br />',
    );
    return h.trimLeft();
  }

  @override
  Widget build(BuildContext context) {
    if (product == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text(
          product!.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      bottomNavigationBar: _bottomActionBar(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ✅ 동시 시청자 배너 (필요할 때만 노출)
          _presenceBanner(),

          FadeSlideInOnVisible(child: _buildHeader(product!)),
          const SizedBox(height: 18),
          _sectionDivider("상품 상세"),
          const SizedBox(height: 10),
          _buildDetailBody(product!),
          const SizedBox(height: 22),
          _sectionDivider("추가 안내"),
          const SizedBox(height: 10),
          FadeSlideInOnVisible(child: _buildFooterSection(product!)),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _bottomActionBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  await _logDetailCta('review');
                  if (!mounted) return;
                  final p = product;
                  if (p != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReviewPage(
                          productId: p.productId,
                          productName: p.name,
                        ),
                      ),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: _brand, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "리뷰",
                  style: TextStyle(color: _brand, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await _logDetailCta('apply');
                  if (!mounted) return;
                  Navigator.push(context, MaterialPageRoute(builder: (context) => FirstStepPage(product: product!)));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "가입하기",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(DepositProduct product) {
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "[BNK 부산은행]",
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(
          product.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          fixLineBreaks(product.summary),
          style: const TextStyle(color: Colors.white, height: 1.45),
        ),
      ],
    );

    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.trending_up, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              const Text(
                "최고금리",
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              RateHighlight(rate: product.maxRate),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _metricCard(Icons.insights, "기본금리", "${product.minRate}%"),
        const SizedBox(height: 8),
        _metricCard(Icons.schedule, "가입기간", "${product.period}개월"),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), _brand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final isNarrow = c.maxWidth < 360;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [left, const SizedBox(height: 14), right],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              SizedBox(width: 140, child: right),
            ],
          );
        },
      ),
    );
  }

  Widget _metricCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionDivider(String title) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 18,
          decoration: BoxDecoration(
            color: _brand,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(height: 1, color: Color(0x22000000))),
      ],
    );
  }

  Widget _buildDetailBody(DepositProduct product) {
    final detail = product.detail.trim();

    if (detail.startsWith("<")) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: FadeSlideInOnVisible(
            child: HtmlWidget(
              toHtmlBreaks(normalizeHtml(detail)),
              customStylesBuilder: _htmlStyleFixer,
            ),
          ),
        ),
      );
    }

    try {
      final decodedOnce = jsonDecode(detail);
      final decoded =
      decodedOnce is String ? jsonDecode(decodedOnce) : decodedOnce;

      if (decoded is List &&
          decoded.isNotEmpty &&
          decoded.first is Map<String, dynamic>) {
        return Column(
          children: decoded.asMap().entries.map((entry) {
            final i = entry.key;
            final section = Map<String, dynamic>.from(entry.value);

            return FadeSlideInOnVisible(
              key: ValueKey("sec_$i"),
              child: _buildDetailSectionCentered(section),
            );
          }).toList(),
        );
      }
    } catch (_) {}

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: FadeSlideInOnVisible(
          child: HtmlWidget(
            toHtmlBreaks(normalizeHtml(detail)),
            customStylesBuilder: _htmlStyleFixer,
          ),
        ),
      ),
    );
  }

  Map<String, String>? _htmlStyleFixer(element) {
    switch (element.localName) {
      case 'p':
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return {'margin': '0 0 8px'};
      case 'ul':
      case 'ol':
        return {'margin': '0 0 8px', 'padding-left': '18px'};
      case 'table':
        return {'width': '100%', 'border-collapse': 'collapse', 'margin': '0'};
      case 'th':
      case 'td':
        return {
          'padding': '6px',
          'border': '1px solid #eeeeee',
          'vertical-align': 'top',
        };
    }
    return null;
  }

  Widget _buildDetailSectionCentered(Map<String, dynamic> e) {
    final String title = e['title'] ?? '제목 없음';
    final String content = fixLineBreaks(e['content'] ?? '');
    final String rawImageUrl = e['imageURL'] ?? '';
    final String imageUrl =
    rawImageUrl.startsWith('/') ? 'assets$rawImageUrl' : rawImageUrl;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                content,
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.55),
              ),
              const SizedBox(height: 12),
              if (imageUrl.trim().isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: imageUrl.startsWith("http")
                        ? Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.medium,
                      loadingBuilder: (c, child, p) =>
                      p == null
                          ? child
                          : const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      errorBuilder: (c, e, s) => const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 42,
                          color: Colors.black26,
                        ),
                      ),
                    )
                        : Image.asset(
                      imageUrl,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (c, e, s) => const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 42,
                          color: Colors.black26,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterSection(DepositProduct product) {
    return Column(
      children: [
        _footerCard("상품안내", product.modalDetail),
        _footerCard("금리/이율 안내", product.modalRate),
      ],
    );
  }

  Widget _footerCard(String title, String content) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          iconColor: _brand,
          collapsedIconColor: Colors.black45,
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          children: [
            if (content.trim().isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "정보가 없습니다.",
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              HtmlWidget(
                toHtmlBreaks(
                  title == '금리/이율 안내'
                      ? cutHeadBeforeFirstTable(content, titleToStrip: title)
                      : normalizeHtml(content, titleToStrip: title),
                ),
                customStylesBuilder: _htmlStyleFixer,
              ),
          ],
        ),
      ),
    );
  }
}

class RateHighlight extends StatelessWidget {
  final double rate;
  final Duration duration;
  const RateHighlight({
    super.key,
    required this.rate,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: rate),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final text = "${value.toStringAsFixed(2)}%";
        return ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFE1ECFF)],
          ).createShader(rect),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: .2,
            ),
          ),
        );
      },
    );
  }
}
