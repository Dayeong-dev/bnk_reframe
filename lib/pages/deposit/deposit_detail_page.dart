import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:reframe/model/deposit_product.dart';
import 'package:reframe/service/deposit_service.dart';

/// =======================================================
///  DepositDetailPage (통합본)
///  - 은행앱 톤 통일 (_brand / _bg)
///  - 금리/이율 안내: 상단 공백 제거 + 표 여백 정리
///  - 섹션 이미지: 이미지 자체 높이 고정 + 비율 유지(contain)
///  - 애니메이션: 화면 진입 시 페이드+슬라이드 1회
/// =======================================================

const _brand = Color(0xFF304FFE);
const _bg = Color(0xFFF5F7FA);

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

  bool _uiReady = false;

  @override
  void initState() {
    super.initState();
    loadProduct();
  }

  Future<void> loadProduct() async {
    try {
      final result = await fetchProduct(widget.productId);
      if (!mounted) return;
      setState(() => product = result);

      // ✅ 렌더 한 프레임 후 + 160ms 지연 → 애니메이션 확실히 보이게
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() => _uiReady = true);
    } catch (e) {
      debugPrint("❌ 상품 불러오기 실패: $e");
    }
  }

  // 줄바꿈 보정: <br>* → \n, "\\n" → \n
  String fixLineBreaks(String text) {
    return text
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<br />', '\n')
        .replaceAll('\\n', '\n')
        .trim();
  }

  // HtmlWidget용: \n → <br />
  String toHtmlBreaks(String text) =>
      fixLineBreaks(text).replaceAll('\n', '<br />');

  // ✅ HTML 앞뒤 공백/빈 블록 제거 + <br> 연속 축약
  // 기존 normalizeHtml 대체 (반복으로 앞머리 비운다)
  String normalizeHtml(String html, {String? titleToStrip}) {
    var h = html.replaceAll('\uFEFF', '').trim(); // BOM 제거

    // 0) &nbsp; 통일
    h = h.replaceAll('&nbsp;', ' ').replaceAll('\u00A0', ' ');

    // 1) 내용 없는 블록(p/div/span…) + <br>를 문서 맨 앞에서 반복 제거
    final leadingEmpty = RegExp(
      r'^('
      r'(?:\s|<br\s*/?>)+|' // BR/공백
      r'<(?:p|div|section|article|span)[^>]*>\s*</(?:p|div|section|article|span)>' // 빈 블록
      r')+',
      caseSensitive: false,
    );
    while (leadingEmpty.hasMatch(h)) {
      h = h.replaceFirst(leadingEmpty, '');
    }

    // 2) 중복 제목 제거 (예: "금리/이율 안내"가 콘텐츠에 한 번 더 있을 때)
    if (titleToStrip != null && titleToStrip.trim().isNotEmpty) {
      final t = RegExp.escape(titleToStrip.trim());
      final dupTitle = RegExp(
        r'^(?:<(?:h[1-6]|p|div)[^>]*>\s*' + t + r'\s*</(?:h[1-6]|p|div)>\s*)+',
        caseSensitive: false,
      );
      h = h.replaceFirst(dupTitle, '');
      // 제목 뒤에 또 이어지는 빈 블록/BR 있으면 한번 더 청소
      while (leadingEmpty.hasMatch(h)) {
        h = h.replaceFirst(leadingEmpty, '');
      }
    }

    // 3) 연속 <br> 압축 + 끝쪽 공백 제거
    h = h.replaceAll(
      RegExp(r'(<br\s*/?>\s*){2,}', caseSensitive: false),
      '<br />',
    );
    h = h.replaceFirst(RegExp(r'(\s|<br\s*/?>)+$', caseSensitive: false), '');

    return h;
  }

  // 금리/이율 안내 전용: 앞머리 빈 p/div/br 날리고 <table>부터 시작
  String squeezeHeadForRates(String html) {
    var h = html.replaceAll('\uFEFF', '').replaceAll('&nbsp;', ' ').trimLeft();

    final leadingEmpty = RegExp(
      r'^(?:\s|<br\s*/?>|<(?:p|div|span)[^>]*>\s*</(?:p|div|span)>)',
      caseSensitive: false,
    );
    while (leadingEmpty.hasMatch(h)) {
      h = h.replaceFirst(leadingEmpty, '');
    }

    final lower = h.toLowerCase();
    final markers = ['<table', '<h1', '<h2', '<h3', '<h4', '<h5', '<h6', '<p'];
    int cut = -1;
    for (final m in markers) {
      final i = lower.indexOf(m);
      if (i >= 0) cut = (cut == -1 || i < cut) ? i : cut;
    }
    if (cut > 0) h = h.substring(cut);

    h = h.replaceAll(
      RegExp(r'(<br\s*/?>\s*){2,}', caseSensitive: false),
      '<br />',
    );
    return h.trimLeft();
  }

  /// 금리/이율 안내 전용: 첫 번째 <table>이 나오기 전까지 몽땅 제거
  String cutHeadBeforeFirstTable(String html, {String? titleToStrip}) {
    if (html.isEmpty) return html;

    // 0) 기본 정리
    var h = html.replaceAll('\uFEFF', '').replaceAll('&nbsp;', ' ').trimLeft();

    // 1) 제목이 앞에 텍스트로 들어온 경우 잘라내기 (예: "금리/이율 안내")
    if (titleToStrip != null && titleToStrip.isNotEmpty) {
      final t = RegExp.escape(titleToStrip.trim());
      h = h.replaceFirst(
        RegExp(r'^\s*' + t + r'\s*(<br\s*/?>|\s)*', caseSensitive: false),
        '',
      );
    }

    // 2) 첫 <table> 위치 찾기 (wrapper div가 있어도 <table>부터 렌더)
    final lower = h.toLowerCase();
    final idx = lower.indexOf('<table');
    if (idx > 0) {
      h = h.substring(idx);
    }

    // 3) 연속 <br> 압축
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

  /// 하단 고정 액션 바 (브랜드 컬러 통일)
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
                onPressed: () {
                  // TODO: 리뷰 목록/작성
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
                onPressed: () {
                  // TODO: 가입 플로우
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

  /// 헤더: 브랜드 블루 그라데 + 간결한 지표
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
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.3)),
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
              RateHighlight(rate: product.maxRate), // ✅ 숫자만 카운트업+그라데이션
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

  /// 지표 카드 (헤더 안: 반투명 화이트)
  Widget _metricCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
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

  /// 섹션 타이틀
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

  /// DETAIL 본문
  Widget _buildDetailBody(DepositProduct product) {
    final detail = product.detail.trim();

    // HTML로 시작하면 바로 렌더
    if (detail.startsWith("<")) {
      return FadeSlideInOnVisible(
        child: HtmlWidget(
          toHtmlBreaks(normalizeHtml(detail)),
          customStylesBuilder: _htmlStyleFixer,
        ),
      );
    }

    // JSON 포맷 지원
    try {
      final decodedOnce = jsonDecode(detail);
      final decoded = decodedOnce is String
          ? jsonDecode(decodedOnce)
          : decodedOnce;

      if (decoded is List &&
          decoded.isNotEmpty &&
          decoded.first is Map<String, dynamic>) {
        return Column(
          children: decoded.asMap().entries.map((entry) {
            return FadeSlideInOnVisible(
              key: ValueKey("sec_${entry.key}"),
              beginOffset: const Offset(0, .06),
              child: _buildDetailSection(
                Map<String, dynamic>.from(entry.value),
              ),
            );
          }).toList(),
        );
      }
    } catch (_) {}

    // 기타 텍스트는 HTML로 변환
    return FadeSlideInOnVisible(
      child: HtmlWidget(
        toHtmlBreaks(normalizeHtml(detail)),
        customStylesBuilder: _htmlStyleFixer,
      ),
    );
  }

  /// HtmlWidget 기본 여백/표 스타일 정리
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

  /// 섹션 카드: 흰색 + 좌측 포인트 바
  ///  - 이미지: 이미지 자체 높이 고정(140) + 비율 유지(contain)
  Widget _buildDetailSection(Map<String, dynamic> e) {
    final String title = e['title'] ?? '제목 없음';
    final String content = fixLineBreaks(e['content'] ?? '');
    final String rawImageUrl = e['imageURL'] ?? '';
    final String imageUrl = rawImageUrl.startsWith('/')
        ? 'assets$rawImageUrl'
        : rawImageUrl;

    return Container(
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
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 80,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: _brand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(content, style: const TextStyle(height: 1.55)),
                const SizedBox(height: 12),

                // ✅ 이미지 자체 크기/비율 제어
                if (imageUrl.trim().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 140, // 120~160 사이 조절 가능
                      width: double.infinity,
                      child: imageUrl.startsWith("http")
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.contain, // 비율 유지 (크롭/늘어남 방지)
                              alignment: Alignment.center,
                              filterQuality: FilterQuality.medium,
                              loadingBuilder: (c, child, p) => p == null
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
        ],
      ),
    );
  }

  /// 하단 안내 (ExpansionTile + HTML 정리)
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
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12), // top=0
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
                  "❗ 정보가 없습니다.",
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              HtmlWidget(
                toHtmlBreaks(
                  title == '금리/이율 안내'
                      ? cutHeadBeforeFirstTable(
                          content,
                          titleToStrip: title,
                        ) // ← 전용 처리
                      : normalizeHtml(
                          content,
                          titleToStrip: title,
                        ), // ← 기존 처리 유지
                ),
                customStylesBuilder: _htmlStyleFixer, // 표/여백 스타일러 그대로
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
              fontSize: 20, // 평소보다 살짝 큼
              fontWeight: FontWeight.w900,
              color: Colors.white, // ShaderMask로 덮임
              letterSpacing: .2,
            ),
          ),
        );
      },
    );
  }
}
