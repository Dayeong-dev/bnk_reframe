import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import '../service/fortune_auth_service.dart';
import '../config/share_links.dart';
import 'my_coupons_page.dart';

/// 쿠폰 스탬프 페이지 (컨텐츠 전용)
class CouponsPage extends StatefulWidget {
  final int stampCount; // 현재 스탬프 개수
  final VoidCallback? onFull; // 가득 찼을 때 호출

  const CouponsPage({
    super.key,
    required this.stampCount,
    this.onFull,
  });

  @override
  State<CouponsPage> createState() => _CouponsPageState();
}

class _CouponsPageState extends State<CouponsPage>
    with TickerProviderStateMixin {
  static const int total = 10;

  late final AnimationController _popCtrl;

  late final Animation<double> _scale;        // 팝(확대→안정)
  late final Animation<double> _fade;         // 도장 페이드 인
  late final Animation<double> _rotate;       // 미세 회전(스윙 후 0°)
  late final Animation<double> _flashOpacity; // 라디얼 플래시 투명도
  late final Animation<double> _flashScale;   // 라디얼 플래시 크기
  late final Animation<double> _nudgeY;       // 순간 하강→복귀

  @override
  void initState() {
    super.initState();

    _popCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.10, end: 1.22)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 58,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.22, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 42,
      ),
    ]).animate(_popCtrl);

    _fade = CurvedAnimation(
      parent: _popCtrl,
      curve: const Interval(0.00, 0.55, curve: Curves.easeOut),
    );

    _rotate = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: -0.12, end: 0.06)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.06, end: -0.02)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.02, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
    ]).animate(_popCtrl);

    _flashOpacity = CurvedAnimation(
      parent: _popCtrl,
      curve: const Interval(0.00, 0.42, curve: Curves.easeOut),
      reverseCurve: const Interval(0.30, 1.0, curve: Curves.easeIn),
    );
    _flashScale = Tween<double>(begin: 0.55, end: 1.60).animate(
      CurvedAnimation(
        parent: _popCtrl,
        curve: const Interval(0.00, 0.42, curve: Curves.easeOutCubic),
      ),
    );

    _nudgeY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: -2.0, end: 6.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 36,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 6.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 64,
      ),
    ]).animate(_popCtrl);

    if (widget.stampCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _popCtrl.forward(from: 0);
      });
    }

    if (widget.stampCount >= total) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onFull?.call();
        _showCongrats();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/stamp_on.png'), context);
    precacheImage(const AssetImage('assets/images/stamp_base.png'), context);
  }

  @override
  void didUpdateWidget(covariant CouponsPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.stampCount > oldWidget.stampCount) {
      Future(() => HapticFeedback.mediumImpact())
          .then((_) => Future.delayed(const Duration(milliseconds: 35)))
          .then((_) => HapticFeedback.heavyImpact());

      _popCtrl.forward(from: 0);

      if (widget.stampCount >= total) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onFull?.call();
          _showCongrats();
        });
      }
    }
  }

  void _showCongrats() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('축하합니다! 쿠폰이 발급되었습니다.')),
    );
  }

  @override
  void dispose() {
    _popCtrl.dispose();
    super.dispose();
  }

  // 공유 (옵션)
  Future<void> _share() async {
    await FortuneAuthService.ensureSignedIn();
    final myUid = FortuneAuthService.getCurrentUid();
    if (myUid == null) return;

    final appLink = ShareLinks.shareUrl(inviteCode: myUid, src: 'coupons');
    final playStore = ShareLinks.playStoreUrl;

    final text = StringBuffer()
      ..writeln('🎁 내 쿠폰함 공유')
      ..writeln('스탬프 모으고 혜택 받아요!')
      ..writeln()
      ..writeln(appLink)
      ..writeln()
      ..writeln('설치가 필요하면 ➜ $playStore');

    await Share.share(text.toString(), subject: '친구에게 공유하기');
  }

  @override
  Widget build(BuildContext context) {
    final int stamped = widget.stampCount.clamp(0, total).toInt();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 스탬프 2행 5열
          AspectRatio(
            aspectRatio: 5 / 2,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              itemCount: total,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final isStamped = index < stamped;
                final isJustStamped = isStamped && (index == stamped - 1);

                return _StampSlot(
                  isStamped: isStamped,
                  scale: isJustStamped ? _scale : null,
                  fade: isJustStamped ? _fade : null,
                  rotate: isJustStamped ? _rotate : null,
                  flashOpacity: isJustStamped ? _flashOpacity : null,
                  flashScale: isJustStamped ? _flashScale : null,
                  nudgeY: isJustStamped ? _nudgeY : null,
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // 내 쿠폰함 보기
          SizedBox(
            height: 56,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyCouponsPage()),
                );
              },
              child: const Text('내 쿠폰함 보기'),
            ),
          ),

          const SizedBox(height: 12),

          // 공유 버튼(옵션)
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _share,
              child: const Text(
                '친구에게 공유하기',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 40),

          // 🔶 하단 CTA 카드 2개 (텍스트 + 하단 이미지)
          Row(
            children: [
              Expanded(
                child: _CTAImageCard(
                  title: '나에게 딱 맞는\n예·적금 상품\n추천받기',
                  imagePath: 'assets/images/pig.png',
                  onTap: () {
                    // ✅ Savings 테스트: StartScreen
                    Navigator.pushNamed(context, '/savings/start');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CTAImageCard(
                  title: '오늘의 운세\n확인하고\n커피까지!',
                  imagePath: 'assets/images/coffee.png',
                  onTap: () {
                    // ✅ 운세 시작 페이지
                    Navigator.pushNamed(context, '/event/fortune');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 단일 스탬프 슬롯
class _StampSlot extends StatelessWidget {
  final bool isStamped;

  final Animation<double>? scale;        // 팝 스케일
  final Animation<double>? fade;         // 도장 페이드
  final Animation<double>? rotate;       // 미세 회전
  final Animation<double>? flashOpacity; // 라디얼 플래시 투명도
  final Animation<double>? flashScale;   // 라디얼 플래시 크기
  final Animation<double>? nudgeY;       // 순간 하강

  const _StampSlot({
    required this.isStamped,
    this.scale,
    this.fade,
    this.rotate,
    this.flashOpacity,
    this.flashScale,
    this.nudgeY,
  });

  @override
  Widget build(BuildContext context) {
    final base = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/stamp_base.png', fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
          ),
        ],
      ),
    );

    if (!isStamped) return base;

    final stamp = Image.asset('assets/images/stamp_on.png', fit: BoxFit.cover);

    if (scale == null || fade == null || rotate == null) {
      return Stack(fit: StackFit.expand, children: [base, stamp]);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        base,

        if (flashOpacity != null && flashScale != null)
          AnimatedBuilder(
            animation: Listenable.merge([flashOpacity!, flashScale!]),
            builder: (context, _) {
              return Opacity(
                opacity: flashOpacity!.value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: flashScale!.value,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Color.fromARGB(170, 255, 255, 255),
                          Color.fromARGB(0, 255, 255, 255),
                        ],
                        stops: [0.0, 1.0],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

        FadeTransition(
          opacity: fade!,
          child: AnimatedBuilder(
            animation:
            Listenable.merge([scale!, rotate!, if (nudgeY != null) nudgeY!]),
            builder: (context, _) {
              return Transform.translate(
                offset: Offset(0, nudgeY?.value ?? 0.0),
                child: Transform.rotate(
                  angle: rotate!.value,
                  child: Transform.scale(
                    scale: scale!.value,
                    child: stamp,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 하단 CTA 카드 (텍스트 + 하단 이미지)
class _CTAImageCard extends StatelessWidget {
  final String title;
  final String imagePath;
  final VoidCallback onTap;

  const _CTAImageCard({
    required this.title,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 120,
          padding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Image.asset(
                  imagePath,
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
