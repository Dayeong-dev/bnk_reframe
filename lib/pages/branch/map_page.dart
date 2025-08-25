// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterNaverMap().init(
    clientId: '1vyye633d9',
    onAuthFailed: (e) => debugPrint('❌ 지도 인증 실패: $e'),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2962FF);
    return MaterialApp(
      title: '부산은행 근처 지점',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: seed,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      home: const MapPage(),
    );
  }
}

/// =========================== 모델/타입 ===========================
enum DatasetType { branches, atm, atm365, stm }

extension DatasetInfo on DatasetType {
  String get label => switch (this) {
        DatasetType.branches => '영업점',
        DatasetType.atm => 'ATM',
        DatasetType.atm365 => '365ATM',
        DatasetType.stm => 'STM',
      };
  String get assetPath => switch (this) {
        DatasetType.branches => 'assets/branches_geocoded.json',
        DatasetType.atm => 'assets/atm_geocoded.json',
        DatasetType.atm365 => 'assets/atm_365_geocoded.json',
        DatasetType.stm => 'assets/stm_geocoded.json',
      };
  IconData get icon => switch (this) {
        DatasetType.branches => Icons.store_mall_directory,
        DatasetType.atm => Icons.atm,
        DatasetType.atm365 => Icons.access_time,
        DatasetType.stm => Icons.smart_toy_outlined,
      };
  Color get tint => switch (this) {
        DatasetType.branches => const Color(0xFF2962FF),
        DatasetType.atm => const Color(0xFF0B8043),
        DatasetType.atm365 => const Color(0xFFEA4335),
        DatasetType.stm => const Color(0xFF2962FF),
      };
}

class Place {
  final String id;
  final String title;
  final String address;
  final double lat;
  final double lng;
  double distanceM;
  final String? tel;
  final String? hours;
  Place({
    required this.id,
    required this.title,
    required this.address,
    required this.lat,
    required this.lng,
    required this.distanceM,
    this.tel,
    this.hours,
  });
}

/// =========================== 페이지 ===========================
class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  NaverMapController? _map;

  // 위치
  bool _mockBlocked = false;
  bool _jumpedOnceToGps = false;
  Position? _currentPosition;
  StreamSubscription<Position>? _posSub;

  // 필터 & 카테고리
  double _radiusKm = 10; // 1~20
  DatasetType _dataset = DatasetType.branches;

  // 데이터/마커
  final Map<DatasetType, List<Place>> _datasetCache = {};
  List<Place> _all = [];
  final List<Place> _results = [];
  final List<NMarker> _markers = [];

  // 즐겨찾기
  Set<String> _favorites = {};
  bool _savingFav = false;

  bool _isSearching = false;

  static const NLatLng _busanDefault = NLatLng(35.1796, 129.0756);
  static const Duration _freshDuration = Duration(minutes: 2);
  static const double _maxAccuracyM = 100;

  bool _isFresh(Position? p) {
    if (p == null) return false;
    final now = DateTime.now();
    final t = p.timestamp ?? now;
    final fresh = now.difference(t).abs() <= _freshDuration;
    final goodAcc = (p.accuracy.isFinite) ? p.accuracy <= _maxAccuracyM : true;
    return fresh && goodAcc;
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadLocal();
    _loadDataset(_dataset);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  // ---------------- 위치 ----------------
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
      _currentPosition = pos;

      _posSub = Geolocator.getPositionStream(
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
        if (!_jumpedOnceToGps && _isFresh(p) && _map != null) {
          _jumpedOnceToGps = true;
          await _map!.updateCamera(
            NCameraUpdate.withParams(
              target: NLatLng(p.latitude, p.longitude),
              zoom: 13,
            ),
          );
          _searchNearby(fromCamera: true);
        }
      });
    } catch (e) {
      debugPrint('위치 초기화 실패: $e');
      _snack('위치 정보를 가져오지 못했어요.');
    }
  }

  // ---------------- 즐겨찾기 저장 ----------------
  Future<void> _loadLocal() async {
    final sp = await SharedPreferences.getInstance();
    _favorites = (sp.getStringList('favorites') ?? []).toSet();
    setState(() {});
  }

  Future<void> _saveLocal() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList('favorites', _favorites.toList());
    } catch (e) {
      debugPrint('❌ save local error: $e');
    }
  }

  Future<void> _toggleFavorite(Place p, {bool silent = false}) async {
    if (!mounted || _savingFav) return;
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
      _snack(wasFav ? '즐겨찾기에서 제거했습니다.' : '즐겨찾기에 추가했습니다.');
    }
    _savingFav = false;
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ======================== 길찾기/전화 ========================
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

  // ======================== 데이터 로드 ========================
  Future<void> _loadDataset(DatasetType type) async {
    try {
      if (_datasetCache.containsKey(type)) {
        _all = _datasetCache[type]!;
        _searchNearby(fromCamera: true);
        return;
      }
      final txt = await rootBundle.loadString(type.assetPath);
      final list = (json.decode(txt) as List).cast<Map<String, dynamic>>();

      final items = <Place>[];
      for (final m in list) {
        final lat = (m['lat'] as num?)?.toDouble();
        final lng = (m['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final title = (m['name'] ?? m['title'] ?? '').toString().trim();
        final addr = (m['address'] ?? m['addr'] ?? '').toString().trim();
        final tel = (m['tel'] ?? '').toString().trim();
        final hours = (m['hours'] ?? m['hoursHint'] ?? '').toString().trim();

        items.add(
          Place(
            id: (m['code']?.toString().isNotEmpty ?? false)
                ? m['code'].toString()
                : '$title::$addr',
            title: title,
            address: addr,
            lat: lat,
            lng: lng,
            distanceM: 0,
            tel: tel.isEmpty ? null : tel,
            hours: hours.isEmpty ? null : hours,
          ),
        );
      }
      _datasetCache[type] = items;
      _all = items;
      _searchNearby(fromCamera: true);
    } catch (e) {
      debugPrint('❌ ${type.assetPath} 로드 실패: $e');
      _snack('${type.label} 데이터를 불러오지 못했어요.');
    }
  }

  // ======================== 검색(항상 거리순) ========================
  Future<NLatLng?> _cameraCenter() async {
    if (_map == null) return null;
    final pos = await _map!.getCameraPosition();
    return pos.target;
  }

  Future<void> _searchNearby({required bool fromCamera}) async {
    if (_isSearching) return;
    if (_mockBlocked) {
      _snack('모의 위치 감지 중에는 검색할 수 없습니다.');
      return;
    }
    setState(() => _isSearching = true);

    try {
      NLatLng center = _busanDefault;
      if (fromCamera) {
        final c = await _cameraCenter();
        if (c != null) center = c;
      } else if (_isFresh(_currentPosition)) {
        center = NLatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
      }

      final radiusM = _radiusKm * 1000;
      final inRadius = <Place>[];
      for (final p in _all) {
        final d = Geolocator.distanceBetween(
          center.latitude,
          center.longitude,
          p.lat,
          p.lng,
        );
        if (d <= radiusM) {
          p.distanceM = d;
          inRadius.add(p);
        }
      }

      inRadius.sort((a, b) {
        final d = a.distanceM.compareTo(b.distanceM);
        return d != 0 ? d : a.title.compareTo(b.title);
      });

      _results
        ..clear()
        ..addAll(inRadius.take(20)); // 가까운 20개

      await _renderMarkers();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('검색 실패: $e');
      _snack('검색이 지연되고 있어요. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // =============== 마커 렌더/정리 ===============
  Future<void> _clearMarkers() async {
    for (final m in _markers) {
      try {
        await Future.sync(() => _map?.deleteOverlay(m.info));
      } catch (_) {}
    }
    _markers.clear();
  }

  Future<void> _renderMarkers() async {
    if (_map == null) return;
    await _clearMarkers();

    final captionColor = switch (_dataset) {
      DatasetType.branches => const Color(0xFF1A73E8),
      DatasetType.atm => const Color(0xFF0B8043),
      DatasetType.atm365 => const Color(0xFFEA4335),
      DatasetType.stm => const Color(0xFF2962FF),
    };

    for (final p in _results) {
      final marker = NMarker(
        id: 'mk_${p.id}',
        position: NLatLng(p.lat, p.lng),
        caption: NOverlayCaption(
          text: p.title,
          textSize: 11,
          color: captionColor,
        ),
      );
      marker.setOnTapListener((_) async {
        final cam = await _map?.getCameraPosition();
        final zoom = cam?.zoom ?? 13;
        await _map?.updateCamera(
          NCameraUpdate.withParams(
            target: NLatLng(p.lat, p.lng),
            zoom: math.max(zoom, 15),
          ),
        );
        _showPlaceSheet(p);
      });
      await Future.sync(() => _map?.addOverlay(marker));
      _markers.add(marker);
    }
  }

  // ======================== UI ========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildFavoritesDrawer(),
      appBar: AppBar(
        title: const Text('근처 지점 검색'),
        actions: [
          IconButton(
            tooltip: '즐겨찾기',
            icon: Icon(Icons.star,
                color: _favorites.isEmpty ? null : Colors.amber),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          IconButton(
            tooltip: '필터',
            icon: const Icon(Icons.tune),
            onPressed: () => _openFilters(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: _buildCategoryRow(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: NaverMap(
              options: const NaverMapViewOptions(
                mapType: NMapType.basic,
                locationButtonEnable: true,
              ),
              onMapReady: (controller) async {
                _map = controller;

                final overlayOrFuture = _map!.getLocationOverlay();
                final overlay = (overlayOrFuture is Future)
                    ? await overlayOrFuture
                    : overlayOrFuture as NLocationOverlay;
                await Future.sync(() => overlay.setIsVisible(true));
                await Future.sync(
                  () =>
                      _map!.setLocationTrackingMode(NLocationTrackingMode.face),
                );

                await _map!.updateCamera(
                  NCameraUpdate.withParams(target: _busanDefault, zoom: 16),
                );
                _searchNearby(fromCamera: true);
              },
            ),
          ),
          _buildResultPanel(),
        ],
      ),
    );
  }

  // ===== 카테고리(Pill) =====
  Widget _buildCategoryRow() {
    const selectedBg = Color(0xFF2962FF);
    const selectedFg = Colors.white;
    const unselectedBg = Color(0xFFEAF1FF);
    const unselectedFg = Color(0xFF1B3B8A);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in DatasetType.values) ...[
              _CategoryPill(
                icon: t.icon,
                label: t.label,
                selected: _dataset == t,
                selectedBg: selectedBg,
                selectedFg: selectedFg,
                unselectedBg: unselectedBg,
                unselectedFg: unselectedFg,
                onTap: () async {
                  if (_dataset == t) return;
                  setState(() => _dataset = t);
                  await _loadDataset(t);
                },
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  // 하단 결과 패널
  Widget _buildResultPanel() {
    const panelHeight = 300.0;
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
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _results.isEmpty
                          ? '${_dataset.label} 결과 없음'
                          : '${_dataset.label} ${_results.length}개 · 반경 ${_radiusKm.toStringAsFixed(0)}km (거리순)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    tooltip: '현 위치에서 재검색',
                    onPressed: _isSearching
                        ? null
                        : () => _searchNearby(fromCamera: false),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text('검색 결과가 여기에 표시됩니다.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                      itemCount: _results.length,
                      itemBuilder: (_, i) => Padding(
                        padding: EdgeInsets.only(
                            bottom: i == _results.length - 1 ? 0 : 10),
                        child: _placeCard(_results[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 공통: 아이콘 + 텍스트 한 줄 ----------
  Widget _infoRow({
    required IconData icon,
    required String text,
    int maxLines = 1,
  }) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: Colors.black54),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  // ---------- 카드 ----------
  Widget _placeCard(Place p) {
    final isFav = _favorites.contains(p.id);
    final hasTel = (p.tel != null && p.tel!.trim().isNotEmpty);
    final distanceText = '${p.distanceM.toStringAsFixed(0)}m';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final cam = await _map?.getCameraPosition();
          final zoom = cam?.zoom ?? 13;
          await _map?.updateCamera(
            NCameraUpdate.withParams(
              target: NLatLng(p.lat, p.lng),
              zoom: math.max(zoom, 15),
            ),
          );
          _showPlaceSheet(p);
        },
        borderRadius: BorderRadius.circular(16),
        child: Card(
          margin: EdgeInsets.zero,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1) 상단: 배경 없는 아이콘 + 제목 + 거리 + ★
                Row(
                  children: [
                    Icon(_dataset.icon, color: _dataset.tint, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _distancePill(distanceText),
                    IconButton(
                      tooltip: isFav ? '즐겨찾기 제거' : '즐겨찾기 추가',
                      onPressed: () async => _toggleFavorite(p),
                      icon: Icon(isFav ? Icons.star : Icons.star_border),
                      color: isFav ? Colors.amber : Colors.black38,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints.tightFor(width: 36, height: 36),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 2) 주소/전화/운영시간
                _infoRow(icon: Icons.place_outlined, text: p.address),
                if (hasTel) ...[
                  const SizedBox(height: 4),
                  Text(
                    '☎ ${p.tel}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                ],
                if (p.hours != null && p.hours!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _infoRow(icon: Icons.access_time, text: p.hours!),
                ],

                const SizedBox(height: 10),

                // 3) 액션
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: hasTel ? () => _call(p.tel!) : null,
                      icon: const Icon(Icons.call, size: 18),
                      label: const Text('전화'),
                    ),
                    const SizedBox(width: 6),
                    TextButton.icon(
                      onPressed: () => _navigateTo(p.lat, p.lng, p.title),
                      icon: const Icon(Icons.directions, size: 18),
                      label: const Text('길찾기'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----- pill helpers -----
  Widget _pillOutlined(String text, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x22000000)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.black54),
            const SizedBox(width: 6),
          ],
          Text(text, style: const TextStyle(fontSize: 12.5)),
        ],
      ),
    );
  }

  Widget _pillPlain(String text, {IconData? icon}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 4),
        ],
        Text(text,
            style: const TextStyle(fontSize: 12.5, color: Colors.black87)),
      ],
    );
  }

  Widget _distancePill(String text) => _pillOutlined(text);

  // ===== 모달(바텀시트)
  void _showPlaceSheet(Place p) {
    final hasTel = (p.tel != null && p.tel!.trim().isNotEmpty);
    final km = (p.distanceM / 1000).toStringAsFixed(2);

    showModalBottomSheet(
      context: context,
      // showDragHandle: false,
      isScrollControlled: true,

      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isFav = _favorites.contains(p.id);
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              top: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더: 지점명 + (아래) 거리/운영시간 pill
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_dataset.icon, color: _dataset.tint, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10, // 배경이 없으니 간격을 조금 더 넉넉히
                            runSpacing: 6,
                            children: [
                              _pillPlain('$km km', icon: Icons.place_outlined),
                              if (p.hours != null && p.hours!.isNotEmpty)
                                _pillPlain(p.hours!, icon: Icons.access_time),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isFav ? '즐겨찾기 제거' : '즐겨찾기 추가',
                      onPressed: () async {
                        await _toggleFavorite(p, silent: true);
                        setState(() {});
                        setModalState(() {});
                      },
                      icon: Icon(isFav ? Icons.star : Icons.star_border),
                      color: isFav ? Colors.amber : Colors.black38,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 주소 (화이트 카드) — 주소 옆 아이콘 제거
                _sectionWhite(
                  title: '주소',
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.place_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.address,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

                if (hasTel) ...[
                  const SizedBox(height: 10),
                  _sectionWhite(
                    title: '연락처',
                    child: InkWell(
                      onTap: () => _call(p.tel!),
                      child: Row(
                        children: [
                          const Icon(Icons.call, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            p.tel!,
                            style: const TextStyle(
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _navigateTo(p.lat, p.lng, p.title),
                        icon: const Icon(Icons.directions),
                        label: const Text('길찾기'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        label: const Text('닫기'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // 화이트 카드 섹션(얇은 테두리)
  Widget _sectionWhite({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  // ===== 필터/설정 =====
  void _openFilters() {
    setState(() => _radiusKm = _radiusKm.clamp(1, 20));
    showModalBottomSheet(
      context: context,
      // showDragHandle: false,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '필터/설정',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                // ✅ 완료 버튼(우측 정렬)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _searchNearby(fromCamera: true);
                  },
                  child: const Text('완료'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('반경', style: TextStyle(fontWeight: FontWeight.w600)),
                Expanded(
                  child: StatefulBuilder(
                    builder: (ctx, setSheetState) {
                      return Slider(
                        value: _radiusKm.clamp(1, 20),
                        min: 1,
                        max: 20,
                        divisions: 19,
                        label: '${_radiusKm.toStringAsFixed(0)}km',
                        onChanged: (v) {
                          setSheetState(() {});
                          setState(() => _radiusKm = v.clamp(1, 20));
                        },
                        onChangeEnd: (_) {
                          // 슬라이더 놓았을 때 미리 반영하고 싶다면 유지
                        },
                      );
                    },
                  ),
                ),
                Text('${_radiusKm.toStringAsFixed(0)}km'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===== 즐겨찾기 사이드 드로어 =====
  Widget _buildFavoritesDrawer() {
    Place? _findById(String id) {
      for (final list in _datasetCache.values) {
        final f = list.where((e) => e.id == id);
        if (f.isNotEmpty) return f.first;
      }
      final f2 = _all.where((e) => e.id == id);
      if (f2.isNotEmpty) return f2.first;
      return null;
    }

    final favList = _favorites.map(_findById).whereType<Place>().toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    return Drawer(
      width: 320,
      child: SafeArea(
        child: Column(
          children: [
            const ListTile(
              leading: Icon(Icons.star, color: Colors.amber),
              title: Text(
                '즐겨찾기',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (favList.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('즐겨찾기가 비어 있어요'),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  itemCount: favList.length,
                  itemBuilder: (_, i) {
                    final p = favList[i];
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: i == favList.length - 1 ? 0 : 8),
                      child: ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(
                          p.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          p.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: '즐겨찾기 해제',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await _toggleFavorite(p, silent: true);
                            setState(() {});
                          },
                        ),
                        onTap: () async {
                          _scaffoldKey.currentState?.closeEndDrawer();
                          await _map?.updateCamera(
                            NCameraUpdate.withParams(
                              target: NLatLng(p.lat, p.lng),
                              zoom: 16,
                            ),
                          );
                          _showPlaceSheet(p);
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ===== 파랑 계열 Pill 버튼 (테두리 없음)
class _CategoryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedBg, selectedFg, unselectedBg, unselectedFg;

  const _CategoryPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.selectedBg,
    required this.selectedFg,
    required this.unselectedBg,
    required this.unselectedFg,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? selectedBg : unselectedBg;
    final fg = selected ? selectedFg : unselectedFg;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
