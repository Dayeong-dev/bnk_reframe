// lib/main.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterNaverMap().init(
    clientId: '1vyye633d9', // TODO: 실제 발급 ID 사용
    onAuthFailed: (e) => debugPrint('❌ 지도 인증 실패: $e'),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '부산은행 근처 지점',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF304FFE),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      ),
      home: const MapPage(),
    );
  }
}

// =========================== 모델 ===========================
class Place {
  final String id;
  final String title;
  final String address;
  final double lat;
  final double lng;
  double distanceM;
  final String? tel;
  final String? link;
  final String? hoursHint;

  Place({
    required this.id,
    required this.title,
    required this.address,
    required this.lat,
    required this.lng,
    required this.distanceM,
    this.tel,
    this.link,
    this.hoursHint,
  });
}

// =========================== 페이지 ===========================
class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  NaverMapController? _mapController;

  // 상태
  bool _mapReady = false;
  bool _jumpedOnceToGps = false; // 첫 GPS 수신 시 1회 점프
  bool _mockBlocked = false; // 모의 위치 차단
  Position? _currentPosition;
  StreamSubscription<Position>? _posSub;

  final TextEditingController _searchController = TextEditingController(
    text: '부산은행',
  );
  int _tabIndex = 0; // 0: 영업점, 1: ATM
  bool _sortByDistance = true;
  double _radiusKm = 10; // 기본 반경 10km

  // 결과/마커
  final List<Place> _results = [];
  final List<NMarker> _markers = [];
  bool _isSearching = false;

  // 로컬 저장
  Set<String> _favorites = {};
  List<String> _recents = [];
  bool _savingFav = false; // 즐겨찾기 저장 동시 처리 방지

  // 네이버 Open API (Local/Geocode/Reverse)
  static const _naverHeaders = {
    'X-Naver-Client-Id': 'zIGFd_1H8Ox7UQqztIis',
    'X-Naver-Client-Secret': 'uybjS1Y2Sl',
  };
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 6),
    ),
  );

  // ====== 브랜드/정규식 & 키워드 ======
  static final RegExp _brandKo = RegExp(
    r'(^|[\s\(\[\-·])(?:BNK)?\s*부산은행($|[\s\)\]\/\-·]|지점|영업|본점|센터|WM|PB|ATM|365|코너)',
  );
  static final RegExp _brandEn = RegExp(r'busan\s*bank', caseSensitive: false);

  // 시설물 컷(주차장/출구 등만 강하게 차단)
  static const List<String> _denyFacilityTitleTokens = [
    '주차장',
    '출구',
    '입구',
    '출입구',
    '게이트',
    '플랫폼',
    '엘리베이터',
    '승강기',
    '램프',
    'IC',
    '교차로',
    '사거리',
    '횡단보도',
    '지하도',
    '육교',
    '환승',
    '정류장',
    '터미널',
  ];
  static const List<String> _denyFacilityCategoryTokens = [
    '주차',
    '교통시설',
    '철도',
    '지하철',
    '도로시설',
    '환승',
    '버스',
  ];

  // ATM 신호 키워드
  static const List<String> _atmSignals = [
    'ATM',
    'CD',
    'CD/ATM',
    '현금자동',
    '현금자동입출금기',
    '365',
    '365코너',
    '코너',
    '자동화코너',
    '무인',
    '셀프',
    '스마트',
    '디지털',
    '디지털존',
  ];

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadLocal();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  // ---------------- 위치/모의위치 ----------------
  Future<void> _blockIfMock(Position p) async {
    if (!p.isMocked || _mockBlocked) return;
    _mockBlocked = true;
    _currentPosition = null;
    _results.clear();
    await _clearMarkers();
    if (!mounted) return;
    _snack('모의 위치(가짜 GPS)가 감지되어 검색을 중단합니다.');
    setState(() {});
  }

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _snack('위치 서비스를 켜주세요.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _snack('위치 권한이 필요합니다.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 6),
      );
      if (pos.isMocked) {
        await _blockIfMock(pos);
        return;
      }
      setState(() => _currentPosition = pos);
    } catch (e) {
      debugPrint('위치 초기화 실패: $e');
      _snack('위치 정보를 가져오지 못했어요.');
    }
  }

  void _startPositionStream({bool jumpOnFirstFix = true}) {
    _posSub?.cancel();
    _posSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 8,
          ),
        ).listen((p) async {
          if (p.isMocked) {
            await _blockIfMock(p);
            return;
          }
          _currentPosition = p;

          // 첫 GPS 수신 시 지도로 점프 (한 번만)
          if (jumpOnFirstFix && !_jumpedOnceToGps && _mapController != null) {
            _jumpedOnceToGps = true;
            await _mapController!.updateCamera(
              NCameraUpdate.withParams(
                target: NLatLng(p.latitude, p.longitude),
                zoom: 15,
              ),
            );
            _searchNearby(fromCamera: true);
          }
        });
  }

  Future<void> _loadLocal() async {
    final sp = await SharedPreferences.getInstance();
    _favorites = (sp.getStringList('favorites') ?? []).toSet();
    _recents = sp.getStringList('recents') ?? [];
    setState(() {});
  }

  Future<void> _saveLocal() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList('favorites', _favorites.toList());
      await sp.setStringList('recents', _recents.take(10).toList());
    } catch (e) {
      debugPrint('❌ save local error: $e');
    }
  }

  void _addRecent(String keyword) {
    if (keyword.trim().isEmpty) return;
    _recents.remove(keyword);
    _recents.insert(0, keyword);
    _saveLocal();
  }

  Future<void> _toggleFavorite(Place p, {bool silent = false}) async {
    if (!mounted || _savingFav) return; // dispose/중복호출 가드
    _savingFav = true;

    final wasFav = _favorites.contains(p.id);
    setState(() {
      if (wasFav) {
        _favorites.remove(p.id);
      } else {
        _favorites.add(p.id);
      }
    });

    await _saveLocal();

    if (!silent && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _snack(wasFav ? '즐겨찾기에서 제거했습니다.' : '즐겨찾기에 추가했습니다.');
      });
    }

    _savingFav = false;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ======================= 길찾기/전화 =======================
  Future<void> _navigateTo(double lat, double lng, String name) async {
    final appUri = Uri.parse(
      'nmap://route/public?dlat=$lat&dlng=$lng&dname=${Uri.encodeComponent(name)}&appname=bnk-nearby',
    );
    final webUri = Uri.parse(
      'https://map.naver.com/v5/directions/-/-/-/car?destination=$lng,$lat,$name',
    );
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _call(String tel) async {
    final uri = Uri(
      scheme: 'tel',
      path: tel.replaceAll(RegExp(r'[^0-9+]'), ''),
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _snack('전화 앱을 열 수 없습니다.');
    }
  }

  // ======================== 역지오코딩 & 지역 바이어스 ========================
  Future<Map<String, String>> _reverseAdmin(NLatLng center) async {
    try {
      final resp = await _dio.get(
        'https://naveropenapi.apigw.ntruss.com/map-reversegeocode/v2/gc',
        queryParameters: {
          'coords': '${center.longitude},${center.latitude}', // lng,lat
          'orders': 'admcode,roadaddr,addr',
          'output': 'json',
        },
        options: Options(headers: _naverHeaders),
      );
      final results = (resp.data['results'] as List?) ?? const [];
      String si = '', gu = '', dong = '', landmark = '', road = '';
      for (final r in results) {
        final region = r['region'];
        if (region != null) {
          si = (region['area1']?['name'] ?? si).toString();
          gu = (region['area2']?['name'] ?? gu).toString();
          dong = (region['area3']?['name'] ?? dong).toString();
        }
        final land = r['land'];
        if (land != null) {
          final name = (land['name'] ?? '').toString();
          final number = (land['number1'] ?? '').toString();
          if (name.isNotEmpty)
            road = number.isNotEmpty ? '$name $number' : name;
          if (landmark.isEmpty && name.isNotEmpty) {
            landmark = name; // 캠퍼스/역/건물명이 들어오는 경우
          }
        }
      }
      return {
        'si': si,
        'gu': gu,
        'dong': dong,
        'landmark': landmark,
        'road': road,
      };
    } catch (_) {
      return {'si': '', 'gu': '', 'dong': '', 'landmark': '', 'road': ''};
    }
  }

  // “서면 부산은행” 입력 시 인접 상권(부전/전포 등) 보강 포함
  Future<List<String>> _queriesForCurrentTabWithBias(NLatLng center) async {
    final baseRaw = _searchController.text.trim().isEmpty
        ? '부산은행'
        : _searchController.text.trim();
    final base = baseRaw.replaceAll(RegExp(r'\s+'), ' ');

    final admin = await _reverseAdmin(center);
    final si = admin['si']!;
    final gu = admin['gu']!;
    final dong = admin['dong']!;
    final landmark = admin['landmark']!;
    final road = admin['road']!;

    final Set<String> areaBoost = {};
    if (base.contains('서면')) {
      areaBoost.addAll(['서면', '부전', '전포']);
      if (gu.contains('부산진')) {
        areaBoost.addAll(['부암', '범전', '범천', '가야', '당감', '양정']);
      }
    }

    final hints = <String>[
      if (dong.isNotEmpty) dong,
      if (gu.isNotEmpty) gu,
      if (si.isNotEmpty) si,
      if (landmark.isNotEmpty) landmark,
      if (road.isNotEmpty) road,
      ...areaBoost,
      'near me',
      '근처',
      '주변',
    ];

    final atmTokens = <String>{
      'ATM',
      'CD',
      'CD/ATM',
      '현금자동',
      '현금자동입출금기',
      '365',
      '365코너',
      '자동화코너',
      '코너',
      '무인',
      '무인점포',
      '셀프',
      '스마트',
      '스마트브랜치',
      '디지털',
      '디지털존',
    };
    final branchTokens = <String>{
      '지점',
      '영업점',
      '영업부',
      '금융센터',
      'PB센터',
      'WM센터',
      '자산관리센터',
      '본점',
      '본점영업부',
      '은행',
    };

    List<String> combos({
      required List<String> brands,
      required List<String> locs,
      required Set<String> types,
    }) {
      final out = <String>{};
      for (final b in brands) {
        out.add(b);
        for (final t in types) out.add('$b $t');
        for (final h in locs) {
          out.add('$b $h');
          out.add('$h $b');
          for (final t in types) {
            out.add('$b $h $t');
            out.add('$h $b $t');
          }
        }
      }
      return out.toList();
    }

    final brands = <String>{
      base,
      '부산은행',
      'BNK부산은행',
      'BNK 부산은행',
      'Busan Bank',
    }.toList();
    final pBranch = combos(brands: brands, locs: hints, types: branchTokens);
    final pAtm = combos(brands: brands, locs: hints, types: atmTokens);

    // 중복 제거 + 10개 제한
    final seen = <String>{};
    final pick = <String>[];
    final src = (_tabIndex == 1) ? pAtm : pBranch;
    for (final q in src) {
      final k = q.trim();
      if (k.isEmpty) continue;
      if (seen.add(k)) pick.add(k);
      if (pick.length >= 10) break; // ← 요구사항: 쿼리 10개로 제한
    }
    void ensureFront(String s) {
      if (!pick.contains(s)) pick.insert(0, s);
      if (pick.length > 10) pick.removeLast();
    }

    if (dong.isNotEmpty) {
      if (_tabIndex == 1) {
        ensureFront('$dong 부산은행 365코너');
        ensureFront('$dong 부산은행 ATM');
      } else {
        ensureFront('$dong 부산은행 지점');
        ensureFront('$dong 부산은행 영업점');
      }
    }
    if (base.contains('서면')) {
      if (_tabIndex == 1)
        ensureFront('서면 부산은행 ATM');
      else
        ensureFront('서면 부산은행 지점');
    }
    return pick;
  }

  // ======================== 검색/필터 ========================
  String _cleanTitle(String raw) =>
      raw.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('\u00A0', ' ').trim();
  String _normalize(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  bool _hasBrandOrBank(String title, String category) {
    final t = _normalize(title);
    return _brandKo.hasMatch(t) ||
        _brandEn.hasMatch(t) ||
        category.contains('은행') ||
        category.contains('금융');
  }

  bool _hasAtmSignal(String title, String category) {
    final t = _normalize(title);
    final up = t.toUpperCase();
    final catUp = category.toUpperCase();
    bool fromTitle = _atmSignals.any((w) => t.contains(w.toLowerCase()));
    bool fromUpper =
        up.contains('ATM') ||
        up.contains('CD/ATM') ||
        up.endsWith('CD') ||
        up.startsWith('CD ');
    bool fromCat =
        catUp.contains('ATM') ||
        category.contains('자동화') ||
        category.contains('코너');
    return fromTitle || fromUpper || fromCat;
  }

  bool _isBranchLikeTitle(String title) {
    final t = _normalize(title);
    return t.contains('지점') ||
        t.contains('영업점') ||
        t.contains('본점') ||
        t.contains('영업부') ||
        t.contains('금융센터') ||
        t.contains('pb센터') ||
        t.contains('wm센터') ||
        t.contains('자산관리센터') ||
        t.contains('센터');
  }

  bool _looksLikeFacility(String title, String category) {
    final t = _normalize(title);
    if (_denyFacilityTitleTokens.any((w) => t.contains(w))) return true;
    final c = _normalize(category);
    if (_denyFacilityCategoryTokens.any((w) => c.contains(w))) return true;
    return false;
  }

  // ★ 무제한 모드 + 시설물 컷 + ATM/영업점 분리 + 지점/본점/센터 허용
  bool _isPass(Map<String, dynamic> item, {required bool isAtm}) {
    final title = _cleanTitle((item['title'] ?? '').toString());
    final category = (item['category'] ?? '').toString();

    if (_looksLikeFacility(title, category)) return false;

    final hasBrandBank = _hasBrandOrBank(title, category);
    if (!hasBrandBank) return false;

    final atmSig = _hasAtmSignal(title, category);

    if (isAtm) {
      return atmSig;
    } else {
      if (atmSig) return false; // 영업점 탭에 ATM 섞임 방지
      final branchLike = _isBranchLikeTitle(title);
      final bankCategory = category.contains('은행') || category.contains('금융');
      return branchLike || bankCategory;
    }
  }

  // 429/네트워크 에러 대비 제한 병렬 실행
  Future<List<T>> _runLimited<T>(
    Iterable<Future<T> Function()> tasks, {
    int maxConcurrent = 4,
  }) async {
    final funcs = tasks.toList();
    final results = <T>[];
    for (int i = 0; i < funcs.length; i += maxConcurrent) {
      final slice = funcs.skip(i).take(maxConcurrent).toList();
      final futures = slice.map((fn) async {
        try {
          final v = await fn();
          return v as T?;
        } catch (_) {
          return null;
        }
      });
      final chunk = await Future.wait<T?>(futures);
      results.addAll(chunk.whereType<T>());
    }
    return results;
  }

  Future<NLatLng?> _cameraCenter() async {
    if (_mapController == null) return null;
    final pos = await _mapController!.getCameraPosition();
    return pos.target;
  }

  bool _isInKoreaBounds(double lat, double lng) =>
      lat >= 33 && lat <= 39 && lng >= 124 && lng <= 132;

  // 주소 지오코딩(좌표 보정)
  Future<NLatLng?> _geocodeAddress(String query) async {
    try {
      final resp = await _dio.get(
        'https://naveropenapi.apigw.ntruss.com/map-geocode/v2/geocode',
        queryParameters: {'query': query},
        options: Options(headers: _naverHeaders),
      );
      final list = (resp.data['addresses'] as List?) ?? const [];
      if (list.isEmpty) return null;
      final first = list.first;
      final lng = double.tryParse('${first['x']}');
      final lat = double.tryParse('${first['y']}');
      if (lat == null || lng == null) return null;
      return NLatLng(lat, lng);
    } catch (_) {
      return null;
    }
  }

  Future<void> _searchNearby({bool fromCamera = false}) async {
    if (_isSearching) return;
    if (_mockBlocked) {
      _snack('모의 위치 감지 중에는 검색할 수 없습니다.');
      return;
    }
    setState(() => _isSearching = true);

    try {
      final center = fromCamera
          ? await _cameraCenter()
          : (_currentPosition != null
                ? NLatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  )
                : null);
      if (center == null) {
        _snack('지도가 준비되지 않았어요.');
        return;
      }

      final queries = await _queriesForCurrentTabWithBias(center);

      // 재검색 전 마커 정리
      await _clearMarkers();

      final isAtmMode = (_tabIndex == 1);
      final displayCount = isAtmMode ? 30 : 20;

      // 호출 수를 제한 병렬로 처리
      final allItems = <Map<String, dynamic>>[];
      final fetchedLists = await _runLimited<List<Map<String, dynamic>>>(
        queries
            .take(10)
            .map(
              (q) =>
                  () => _callLocalApi(q, display: displayCount),
            ),
        maxConcurrent: 4,
      );
      for (final items in fetchedLists) {
        allItems.addAll(items);
      }

      // 필터링 + 거리 계산
      final allPlaces = <Place>[];

      for (final it in allItems) {
        if (!_isPass(it, isAtm: isAtmMode)) continue;

        final title = _cleanTitle(it['title'] ?? '');
        final addr = (it['roadAddress'] ?? it['address'] ?? '').toString();

        final mapx = double.tryParse('${it['mapx']}');
        final mapy = double.tryParse('${it['mapy']}');
        if (mapx == null || mapy == null) continue;

        double lng = mapx / 10000000.0;
        double lat = mapy / 10000000.0;

        // 좌표가 비정상 범위면 주소로 보정
        if (!_isInKoreaBounds(lat, lng)) {
          final query = addr.isNotEmpty ? addr : title;
          final geocoded = await _geocodeAddress(query);
          if (geocoded != null) {
            lat = geocoded.latitude;
            lng = geocoded.longitude;
          } else {
            continue;
          }
        }

        final dist = Geolocator.distanceBetween(
          center.latitude,
          center.longitude,
          lat,
          lng,
        );

        allPlaces.add(
          Place(
            id: '$title::${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}',
            title: title,
            address: addr,
            lat: lat,
            lng: lng,
            distanceM: dist,
            tel: (it['telephone']?.toString().trim().isNotEmpty ?? false)
                ? it['telephone']
                : null,
            link: (it['link']?.toString().trim().isNotEmpty ?? false)
                ? it['link']
                : null,
            hoursHint: isAtmMode ? null : '일반 영업시간: 평일 09:00–16:00',
          ),
        );
      }

      // 제목+주소 기준 중복 제거
      final seenKey = <String>{};
      allPlaces.removeWhere((p) {
        final key = '${p.title}::${p.address}'.toLowerCase().replaceAll(
          ' ',
          '',
        );
        if (seenKey.contains(key)) return true;
        seenKey.add(key);
        return false;
      });

      // 반경 필터링 (필요시 자동 확장)
      const minResults = 6;
      const stepKm = 2.0;
      const maxKm = 20.0;
      double radiusUsed = _radiusKm;
      List<Place> filtered = [];

      while (true) {
        filtered = allPlaces
            .where((p) => p.distanceM <= radiusUsed * 1000)
            .toList();
        if (filtered.length >= minResults || radiusUsed >= maxKm) break;
        radiusUsed = (radiusUsed + stepKm).clamp(1.0, maxKm);
      }

      // 정렬
      filtered.sort(
        _sortByDistance
            ? (a, b) => a.distanceM.compareTo(b.distanceM)
            : (a, b) => a.title.compareTo(b.title),
      );

      // 상태 반영
      _results
        ..clear()
        ..addAll(filtered);

      if ((_radiusKm - radiusUsed).abs() > 1e-6) {
        _radiusKm = radiusUsed; // UI 표시 업데이트
      }

      await _renderSimpleMarkers();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('검색 실패: $e');
      _snack('검색이 지연되고 있어요. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ---------- API 호출 ----------
  Future<List<Map<String, dynamic>>> _callLocalApi(
    String q, {
    int display = 20,
    int timeoutSec = 6,
  }) async {
    const maxRetry = 2;
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final resp = await _dio
            .get(
              'https://openapi.naver.com/v1/search/local.json',
              queryParameters: {
                'query': q,
                'display': display,
                'start': 1,
                'sort': 'random',
              },
              options: Options(headers: _naverHeaders),
            )
            .timeout(Duration(seconds: timeoutSec));
        return (resp.data['items'] as List).cast<Map<String, dynamic>>();
      } on DioException catch (e) {
        final code = e.response?.statusCode ?? 0;
        if (code == 429 && attempt <= maxRetry) {
          final wait =
              200 + (100 * attempt) + (DateTime.now().millisecond % 300);
          await Future.delayed(Duration(milliseconds: wait));
          continue;
        }
        return const [];
      } catch (_) {
        if (attempt <= maxRetry) {
          await Future.delayed(const Duration(milliseconds: 200));
          continue;
        }
        return const [];
      }
    }
  }

  // =============== 마커 렌더/정리 ===============
  Future<void> _clearMarkers() async {
    for (final m in _markers) {
      try {
        await Future.sync(() => _mapController?.deleteOverlay(m.info));
      } catch (_) {}
    }
    _markers.clear();
  }

  Future<void> _renderSimpleMarkers() async {
    if (_mapController == null) return;
    await _clearMarkers();
    for (final p in _results) {
      final marker = NMarker(
        id: 'mk_${p.title}_${p.lat.toStringAsFixed(6)}_${p.lng.toStringAsFixed(6)}',
        position: NLatLng(p.lat, p.lng),
        caption: NOverlayCaption(text: p.title, textSize: 12),
      );
      marker.setOnTapListener((_) async {
        final cam = await _mapController?.getCameraPosition();
        final zoom = cam?.zoom ?? 14;
        await _mapController?.updateCamera(
          NCameraUpdate.withParams(
            target: NLatLng(p.lat, p.lng),
            zoom: math.max(zoom, 15),
          ),
        );
        _showPlaceSheet(p);
      });
      await Future.sync(() => _mapController?.addOverlay(marker));
      _markers.add(marker);
    }
    if (mounted) setState(() {});
  }

  // ======================== UI ========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('부산은행 근처 지점'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: _buildTopSearchBar(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: NaverMap(
                    options: const NaverMapViewOptions(
                      mapType: NMapType.basic,
                      locationButtonEnable: true, // 기본 내 위치 버튼
                    ),
                    onMapReady: (controller) async {
                      _mapController = controller;
                      setState(() => _mapReady = true);

                      // 위치 오버레이 + 트래킹(face)
                      final overlayOrFuture = _mapController!
                          .getLocationOverlay();
                      final overlay = (overlayOrFuture is Future)
                          ? await overlayOrFuture
                          : overlayOrFuture as NLocationOverlay;
                      await Future.sync(() => overlay.setIsVisible(true));
                      await Future.sync(
                        () => _mapController!.setLocationTrackingMode(
                          NLocationTrackingMode.face,
                        ),
                      );

                      // 위치 스트림: 첫 GPS에서 점프
                      _startPositionStream(jumpOnFirstFix: true);

                      // 즉시 점프 시도: 보유값 → LastKnown → 4초 제한 현재값
                      Position? fix = _currentPosition;
                      fix ??= await Geolocator.getLastKnownPosition();
                      fix ??= await Geolocator.getCurrentPosition(
                        timeLimit: const Duration(seconds: 4),
                      ).catchError((_) => null);

                      if (fix != null && !_mockBlocked) {
                        _jumpedOnceToGps = true;
                        await _mapController!.updateCamera(
                          NCameraUpdate.withParams(
                            target: NLatLng(fix.latitude, fix.longitude),
                            zoom: 15,
                          ),
                        );
                        _searchNearby(fromCamera: true);
                      } else {
                        Future.delayed(const Duration(seconds: 5), () {
                          if (!_jumpedOnceToGps && mounted && !_mockBlocked) {
                            _snack('GPS 대기 중입니다. 잠시만요!');
                          }
                        });
                      }
                    },
                  ),
                ),
                if (_mockBlocked)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFFFFF3E0),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          '모의 위치(가짜 GPS)가 감지되어 기능이 제한됩니다. 모의 위치를 해제한 후 다시 시도하세요.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          _buildResultPanel(),
        ],
      ),
    );
  }

  // ---------- 상단 검색/필터 바 ----------
  Widget _buildTopSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchNearby(fromCamera: true),
                  decoration: const InputDecoration(
                    hintText: '지점명/키워드 (예: 부산은행 해운대점 / ATM)',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _isSearching
                    ? null
                    : () => _searchNearby(fromCamera: true),
                icon: _isSearching
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search, size: 18),
                label: const Text('검색'),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: '반경/옵션',
                onPressed: _openFilters,
                icon: const Icon(Icons.tune),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: const Text('영업점'),
                avatar: const Icon(Icons.store_mall_directory, size: 18),
                selected: _tabIndex == 0,
                onSelected: (v) {
                  if (_tabIndex != 0) {
                    setState(() => _tabIndex = 0);
                    _searchNearby(fromCamera: true);
                  }
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('ATM'),
                avatar: const Icon(Icons.atm, size: 18),
                selected: _tabIndex == 1,
                onSelected: (v) {
                  if (_tabIndex != 1) {
                    setState(() => _tabIndex = 1);
                    _searchNearby(fromCamera: true);
                  }
                },
              ),
              const Spacer(),
              Text(
                _sortByDistance ? '거리순' : '이름순',
                style: const TextStyle(color: Colors.grey),
              ),
              Switch(
                value: _sortByDistance,
                onChanged: (v) {
                  setState(() => _sortByDistance = v);
                  _results.sort(
                    _sortByDistance
                        ? (a, b) => a.distanceM.compareTo(b.distanceM)
                        : (a, b) => a.title.compareTo(b.title),
                  );
                  _renderSimpleMarkers();
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- 하단 결과 패널(고정) ----------
  Widget _buildResultPanel() {
    const panelHeight = 280.0; // 필요시 조절
    return SafeArea(
      top: false,
      child: Container(
        height: panelHeight,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // 헤더
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _results.isEmpty
                          ? '검색 결과 없음'
                          : '결과 ${_results.length}개 · 반경 ${_radiusKm.toStringAsFixed(0)}km',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: '이 위치에서 재검색',
                    onPressed: _isSearching
                        ? null
                        : () => _searchNearby(fromCamera: true),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 리스트
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text('검색 결과가 여기에 표시됩니다.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _placeCard(_results[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 카드 ----------
  Widget _placeCard(Place p) {
    final isFav = _favorites.contains(p.id);
    final hasTel = (p.tel != null && p.tel!.trim().isNotEmpty);

    return InkWell(
      onTap: () async {
        final cam = await _mapController?.getCameraPosition();
        final zoom = cam?.zoom ?? 14;
        await _mapController?.updateCamera(
          NCameraUpdate.withParams(
            target: NLatLng(p.lat, p.lng),
            zoom: math.max(zoom, 15),
          ),
        );
        _showPlaceSheet(p);
      },
      child: Card(
        elevation: 1.5,
        shadowColor: Colors.black12,
        color: const Color(0xFFF8F6FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 타이틀/거리·주소·전화
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EAF6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _tabIndex == 1 ? Icons.atm : Icons.store_mall_directory,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (p.address.isNotEmpty) p.address,
                            '${p.distanceM.toStringAsFixed(0)}m',
                            if (hasTel) '☎ ${p.tel}',
                          ].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // 액션 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: hasTel ? '전화하기' : '전화번호 없음',
                    onPressed: hasTel ? () => _call(p.tel!) : null,
                    icon: const Icon(Icons.call),
                  ),
                  IconButton(
                    tooltip: '길찾기',
                    onPressed: () => _navigateTo(p.lat, p.lng, p.title),
                    icon: const Icon(Icons.directions),
                  ),
                  IconButton(
                    tooltip: isFav ? '즐겨찾기 제거' : '즐겨찾기 추가',
                    onPressed: () async {
                      await _toggleFavorite(p);
                    },
                    icon: Icon(isFav ? Icons.star : Icons.star_border),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 상세 바텀시트 ----------
  void _showPlaceSheet(Place p) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: _favorites.contains(p.id) ? '즐겨찾기 제거' : '즐겨찾기 추가',
                  onPressed: () async {
                    await _toggleFavorite(p);
                    if (mounted) Navigator.pop(context);
                  },
                  icon: Icon(
                    _favorites.contains(p.id) ? Icons.star : Icons.star_border,
                  ),
                ),
              ],
            ),
            if (p.address.isNotEmpty) ...[
              Text(p.address, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 6),
            ],
            if (p.hoursHint != null) ...[
              Row(
                children: [
                  const Icon(Icons.access_time, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(p.hoursHint!, maxLines: 2)),
                ],
              ),
              const SizedBox(height: 6),
            ],
            if (p.tel != null) ...[
              InkWell(
                onTap: () => _call(p.tel!),
                child: Row(
                  children: [
                    const Icon(Icons.call, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      p.tel!,
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                const Icon(Icons.open_in_new, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse(
                        p.link ??
                            'https://map.naver.com/v5/search/${Uri.encodeComponent(p.title)}',
                      );
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    child: const Text(
                      '네이버에서 자세히 보기',
                      style: TextStyle(decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _navigateTo(p.lat, p.lng, p.title),
                    icon: const Icon(Icons.directions),
                    label: const Text('길찾기'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _mapController?.updateCamera(
                        NCameraUpdate.withParams(
                          target: NLatLng(p.lat, p.lng),
                          zoom: 16,
                        ),
                      );
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.map),
                    label: const Text('지도에서 보기'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ---------- 필터/설정 ----------
  void _openFilters() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '필터/설정',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('반경', style: TextStyle(fontWeight: FontWeight.w600)),
                Expanded(
                  child: Slider(
                    value: _radiusKm,
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: '${_radiusKm.toStringAsFixed(0)}km',
                    onChanged: (v) => setState(() => _radiusKm = v),
                    onChangeEnd: (_) => _searchNearby(fromCamera: true),
                  ),
                ),
                Text('${_radiusKm.toStringAsFixed(0)}km'),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _searchNearby(fromCamera: true);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('이 위치에서 재검색'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
