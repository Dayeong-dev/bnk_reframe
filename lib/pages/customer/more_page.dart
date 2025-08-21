// lib/pages/more_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reframe/constants/api_constants.dart';

// FAQ
import 'package:reframe/service/faq_api.dart';
import 'package:reframe/store/faq_store.dart';
import 'package:reframe/pages/customer/faq/faq_list_page.dart';

// QNA
import 'package:reframe/pages/customer/qna/qna_api_service.dart';
import 'package:reframe/pages/customer/qna/qna_list_page.dart';

/* 섹션 타입: 섹션별 팔레트 분리용 */
enum _SectionKind { myServices, customer }

class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    this.onStartChatbot,
    this.onOneToOne,
    this.onConnectAgent,
    this.onMyProfile,
    this.onMySettings,
  });

  final VoidCallback? onStartChatbot;
  final VoidCallback? onOneToOne;
  final VoidCallback? onConnectAgent;
  final VoidCallback? onMyProfile;
  final VoidCallback? onMySettings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // FAQ DI
        Provider<FaqApi>(create: (_) => FaqApi(baseUrl: apiBaseUrl)),
        ChangeNotifierProvider<FaqStore>(
          create: (ctx) => FaqStore(api: ctx.read<FaqApi>()),
        ),
        // QNA DI
        Provider<QnaApiService>(
            create: (_) => QnaApiService(baseUrl: apiBaseUrl)),
      ],
      builder: (ctx, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFFFFFFF),
          appBar: AppBar(
            scrolledUnderElevation: 0,
            backgroundColor: Colors.white,
            elevation: 0.6,
            centerTitle: false,
            titleSpacing: 20,
            title: const Text(
              '모든 서비스',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.2,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search, color: Colors.black87),
                onPressed: () {
                  // TODO: 서비스 검색 화면 이동
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.black87),
                onPressed: onMySettings ??
                    () {
                      // TODO: 설정 화면 라우트 연결
                    },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
              children: [
                // ================ 그라디언트 챗봇 배너 ================
                _ChatBanner(
                  onTap: onStartChatbot ??
                      () => Navigator.of(ctx, rootNavigator: true)
                          .pushNamed('/chat-debug'),
                ),

                const SizedBox(height: 14),

                // ======================= 나의 서비스 =======================
                const _SectionHeader('나의 서비스'),
                const SizedBox(height: 0),

                _ServiceTile(
                  section: _SectionKind.myServices,
                  iconData: Icons.show_chart,
                  title: '자산추이',
                  trailingInfo: '계좌 · 포트폴리오 · 분석',
                  onTap: () {
                    // TODO: /assets/trend
                  },
                ),
                _ServiceTile(
                  section: _SectionKind.myServices,
                  iconData: Icons.card_giftcard,
                  title: '내 쿠폰함',
                  trailingInfo: '다운로드 · 사용내역',
                  onTap: () {
                    // TODO: /benefit/coupons
                  },
                ),
                _ServiceTile(
                  section: _SectionKind.myServices,
                  iconData: Icons.support_agent,
                  title: '내 문의보기',
                  trailingInfo: '1:1 문의 · 답변',
                  onTap: onOneToOne ??
                      () {
                        final qnaApi = ctx.read<QnaApiService>();
                        Navigator.of(ctx).push(
                          MaterialPageRoute(
                            builder: (_) => QnaListPage(api: qnaApi),
                          ),
                        );
                      },
                ),
                _ServiceTile(
                  section: _SectionKind.myServices,
                  iconData: Icons.reviews,
                  title: '내 리뷰보기',
                  trailingInfo: '작성 · 수정 · 삭제',
                  onTap: () {
                    // TODO: /review/my
                  },
                ),
                _ServiceTile(
                  section: _SectionKind.myServices,
                  iconData: Icons.assignment_turned_in,
                  title: '내가 가입한 상품 보기',
                  trailingInfo: '계약 · 만기 · 혜택',
                  onTap: () {
                    // TODO: /product/my-contracts
                  },
                ),

                const SizedBox(height: 24),

                // ======================= 고객센터 =======================
                const _SectionHeader('고객센터'),
                const SizedBox(height: 0),

                _ServiceTile(
                  section: _SectionKind.customer,
                  iconData: Icons.forum_outlined,
                  title: '자주 묻는 질문',
                  trailingInfo: '계좌 · 카드 · 인증',
                  onTap: () {
                    final api = ctx.read<FaqApi>();
                    final store = ctx.read<FaqStore>();
                    Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) => MultiProvider(
                          providers: [
                            Provider<FaqApi>.value(value: api),
                            ChangeNotifierProvider<FaqStore>.value(
                                value: store),
                          ],
                          child: const FaqListPage(),
                        ),
                      ),
                    );
                  },
                ),
                _ServiceTile(
                  section: _SectionKind.customer,
                  iconData: Icons.mark_unread_chat_alt_outlined,
                  title: '1대1 문의',
                  trailingInfo: '상담원 연결 · 기록',
                  onTap: () {
                    final qnaApi = ctx.read<QnaApiService>();
                    Navigator.of(ctx).push(
                      MaterialPageRoute(
                        builder: (_) => QnaListPage(
                          api: qnaApi,
                          openComposerOnStart: true, // ← 바로 문의쓰기 열기
                        ),
                      ),
                    );
                  },
                ),
                _ServiceTile(
                  section: _SectionKind.customer,
                  iconData: Icons.person_outline,
                  title: '프로필 관리',
                  trailingInfo: '개인정보 · 알림',
                  onTap: onMyProfile ??
                      () {
                        // TODO: /profile
                      },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/* =========================== UI 컴포넌트 =========================== */

/// 섹션 제목
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18, //섹션 제목
        fontWeight: FontWeight.w800,
        color: Colors.black87,
        letterSpacing: -0.1,
      ),
    );
  }
}

/// 서비스 타일(아이콘 + 제목 + 오른쪽 설명)
class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.section,
    required this.iconData,
    required this.title,
    this.trailingInfo,
    this.onTap,
    this.iconBg, // 수동 오버라이드 (선택)
    this.iconColor, // 수동 오버라이드 (선택)
  });

  final _SectionKind section;
  final IconData iconData;
  final String title;
  final String? trailingInfo;
  final VoidCallback? onTap;
  final Color? iconBg;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final _IconColorPair pair = _AutoColor.pickPairForSection(section, title);
    final Color resolvedIconColor = iconColor ?? pair.fg;
    final Color resolvedIconBg = iconBg ?? pair.bg;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const SizedBox(width: 10),
              _RoundedIcon(
                iconData: iconData,
                bg: resolvedIconBg,
                iconColor: resolvedIconColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingInfo != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  flex: 0,
                  child: Text(
                    trailingInfo!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}

/// 둥근 사각형 아이콘 컨테이너
class _RoundedIcon extends StatelessWidget {
  const _RoundedIcon({required this.iconData, this.bg, this.iconColor});
  final IconData iconData;
  final Color? bg;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg ?? const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        iconData,
        size: 22,
        color: iconColor ?? const Color(0xFF111827),
      ),
    );
  }
}

/// 화려한 그라디언트 챗봇 배너 (유지)
class _ChatBanner extends StatelessWidget {
  const _ChatBanner({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7C4DFF), Color(0xFF2962FF)],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: -30,
              top: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -20,
              bottom: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/mrb_desk.jpeg',
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.85),
                        errorBuilder: (_, __, ___) => const Center(
                            child: Text('🤖', style: TextStyle(fontSize: 26))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _WhitePill(text: '궁금하면 지금 바로'),
                        SizedBox(height: 4),
                        Text(
                          '상담챗봇 시작하기',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '실시간 답변 · 지점안내 · 상품추천',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFE6EEFF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: Colors.white, size: 26),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 화이트 캡션 Pill (배너 전용)
class _WhitePill extends StatelessWidget {
  const _WhitePill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.32)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/* ====================== SECTIONED PASTEL PALETTE ====================== */

/// 아이콘 색(fg)과 파스텔 배경(bg) 쌍
class _IconColorPair {
  final Color fg;
  final Color bg;
  const _IconColorPair(this.fg, this.bg);
}

/// 섹션별 톤다운 파스텔 팔레트 & 선택 로직
class _AutoColor {
  static const List<_IconColorPair> _servicesPairs = <_IconColorPair>[
    _IconColorPair(Color(0xFF47A9E6), Color(0xFFE9F6FC)),
    _IconColorPair(Color(0xFF2EBAA0), Color(0xFFE8FAF5)),
    _IconColorPair(Color(0xFF6D88D9), Color(0xFFEEF2FB)),
    _IconColorPair(Color(0xFF48A889), Color(0xFFE7F7F1)),
    _IconColorPair(Color(0xFF4B92C6), Color(0xFFEAF3FA)),
  ];

  static const List<_IconColorPair> _customerPairs = <_IconColorPair>[
    _IconColorPair(Color(0xFFE97A6F), Color(0xFFFFF0ED)),
    _IconColorPair(Color(0xFFCE7DB8), Color(0xFFF9EEF6)),
    _IconColorPair(Color(0xFF9D7BE5), Color(0xFFF2EEFB)),
    _IconColorPair(Color(0xFFCC9C4B), Color(0xFFFFF8EC)),
    _IconColorPair(Color(0xFF7C8DA3), Color(0xFFF0F4F8)),
  ];

  static _IconColorPair pickPairForSection(_SectionKind s, String key) {
    final h = (key.hashCode & 0x7fffffff);

    // 특정 key에 대해 직접 색상 지정
    if (key.contains('자산추이')) {
      return const _IconColorPair(Color(0xFF8A5CE7), Color(0xFFF3EEFB));
    }

    return s == _SectionKind.myServices
        ? _servicesPairs[h % _servicesPairs.length]
        : _customerPairs[h % _customerPairs.length];
  }
}
