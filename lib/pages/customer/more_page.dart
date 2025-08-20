// lib/pages/more_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reframe/constants/api_constants.dart';

import 'package:reframe/service/faq_api.dart';
import 'package:reframe/store/faq_store.dart';
import 'package:reframe/pages/customer/faq/faq_list_page.dart';

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
        Provider<FaqApi>(create: (_) => FaqApi(baseUrl: apiBaseUrl)),
        ChangeNotifierProvider<FaqStore>(
          create: (ctx) => FaqStore(api: ctx.read<FaqApi>()),
        ),
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
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              children: [
                // ================ 화려한 그라디언트 챗봇 배너 ================
                _ChatBanner(
                  onTap: onStartChatbot ??
                      () => Navigator.of(ctx).pushNamed('/chat-debug'),
                ),
                const SizedBox(height: 22),

                // ======================= 나의 서비스 =======================
                const _SectionHeader('나의 서비스'),
                const SizedBox(height: 8),

                _ServiceTile(
                  iconData: Icons.show_chart,
                  iconBg: const Color(0xFFEFF3FF),
                  title: '자산추이',
                  trailingInfo: '계좌 · 포트폴리오 · 분석',
                  onTap: () {
                    // TODO: /assets/trend
                  },
                ),
                _ServiceTile(
                  iconData: Icons.card_giftcard,
                  iconBg: const Color(0xFFFDF2E9),
                  title: '내 쿠폰함',
                  trailingInfo: '다운로드 · 사용내역',
                  onTap: () {
                    // TODO: /benefit/coupons
                  },
                ),
                _ServiceTile(
                  iconData: Icons.support_agent,
                  iconBg: const Color(0xFFEAF7FF),
                  title: '내 문의보기',
                  trailingInfo: '1:1 문의 · 답변',
                  onTap: onOneToOne ??
                      () {
                        // TODO: /cs/my-inquiries
                      },
                ),
                _ServiceTile(
                  iconData: Icons.reviews,
                  iconBg: const Color(0xFFEFFAF1),
                  title: '내 리뷰보기',
                  trailingInfo: '작성 · 수정 · 삭제',
                  onTap: () {
                    // TODO: /review/my
                  },
                ),
                _ServiceTile(
                  iconData: Icons.assignment_turned_in,
                  iconBg: const Color(0xFFF1F5F9),
                  title: '내가 가입한 상품 보기',
                  trailingInfo: '계약 · 만기 · 혜택',
                  onTap: () {
                    // TODO: /product/my-contracts
                  },
                ),

                const SizedBox(height: 26),

                // ======================= 고객센터 =======================
                const _SectionHeader('고객센터'),
                const SizedBox(height: 8),

                _ServiceTile(
                  iconData: Icons.forum_outlined,
                  iconBg: const Color(0xFFEDEFF2),
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
                  iconData: Icons.mark_unread_chat_alt_outlined,
                  iconBg: const Color(0xFFF2F4F6),
                  title: '1대1 문의',
                  trailingInfo: '상담원 연결 · 기록',
                  onTap: onOneToOne ??
                      () {
                        // TODO: /cs/one-to-one
                      },
                ),
                _ServiceTile(
                  iconData: Icons.headset_mic_outlined,
                  iconBg: const Color(0xFFE8F5FF),
                  title: '상담원 연결',
                  trailingInfo: '전화 · 채팅',
                  onTap: onConnectAgent ??
                      () {
                        // TODO: /cs/connect-agent
                      },
                ),
                _ServiceTile(
                  iconData: Icons.person_outline,
                  iconBg: const Color(0xFFF1F5F9),
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
        fontSize: 20,
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
    required this.iconData,
    required this.title,
    this.trailingInfo,
    this.onTap,
    this.iconBg,
  });

  final IconData iconData;
  final String title;
  final String? trailingInfo;
  final VoidCallback? onTap;
  final Color? iconBg;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            // 리스트 타일과 동일 톤의 경계/그림자
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              _RoundedIcon(
                iconData: iconData,
                bg: iconBg ?? const Color(0xFFF1F5F9),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingInfo != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  flex: 0,
                  child: Text(
                    trailingInfo!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(width: 8),
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
  const _RoundedIcon({required this.iconData, this.bg});
  final IconData iconData;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg ?? const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(iconData, size: 26, color: const Color(0xFF111827)),
    );
  }
}

/// 화려한 그라디언트 챗봇 배너
class _ChatBanner extends StatelessWidget {
  const _ChatBanner({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Ink(
        height: 115,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          // 리스트 타일과 유사하지만 조금 더 강한 그림자
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 12, offset: Offset(0, 6)),
          ],
          // 화려한 배경 (메인 그라디언트)
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF7C4DFF), // deep purple
              Color(0xFF2962FF), // blue
            ],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 라디얼 글로우 1
            Positioned(
              left: -30,
              top: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),
            // 라디얼 글로우 2
            Positioned(
              right: -20,
              bottom: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)],
                  ),
                ),
              ),
            ),

            // 내용
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  // 마스코트(흰 원판 + 그림자)
                  Container(
                    width: 68,
                    height: 68,
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
                        'assets/images/mrb_desk.jpeg', // 없으면 임시 이모지로 대체 가능
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.85),
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text('🤖', style: TextStyle(fontSize: 28)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 텍스트
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        _WhitePill(text: '궁금하면 지금 바로'),
                        SizedBox(height: 6),
                        Text(
                          '상담챗봇 시작하기',
                          style: TextStyle(
                            fontSize: 22,
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
                            fontSize: 12.5,
                            color: Color(0xFFE6EEFF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: Colors.white, size: 28),
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
