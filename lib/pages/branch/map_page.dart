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
    clientId: '1vyye633d9', // TODO: 네이버 지도 SDK Client ID
    onAuthFailed: (e) => debugPrint('❌ 지도 인증 실패: $e'),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2962FF); // 🔵 은행 블루
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
            if (!_jumpedOnceToGps && _isFresh(p) && _map != null) {
              _jumpedOnceToGps = true;
              await _map!.updateCamera(
                NCameraUpdate.withParams(
                  target: NLatLng(p.latitude, p.longitude),
                  zoom: 13, // 내 위치는 13
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
      'https://map.naver.com/v5/direlctions/-/-/-/car?destination=$lng,$lat,$name',
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
        ..addAll(inRadius.take(150));

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
      endDrawer: _buildFavoritesDrawer(), // ⭐ 사이드탭
      appBar: AppBar(
        title: const Text('부산은행 근처 지점'),
        actions: [
          IconButton(
            tooltip: '즐겨찾기',
            icon: const Icon(Icons.star),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          IconButton(
            tooltip: '필터',
            icon: const Icon(Icons.tune),
            onPressed: _openFilters,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _buildCategoryRow(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: NaverMap(
              options: const NaverMapViewOptions(
                mapType: NMapType.basic,
                locationButtonEnable: true, // 네이버 기본 내 위치 버튼
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

                // 초기 카메라: 부산(줌 16)
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

  // 상단 카테고리
  Widget _buildCategoryRow() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          const SizedBox(width: 4),
          for (final t in DatasetType.values)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
              child: ChoiceChip(
                label: Text(t.label),
                avatar: Icon(switch (t) {
                  DatasetType.branches => Icons.store_mall_directory,
                  DatasetType.atm => Icons.atm,
                  DatasetType.atm365 => Icons.access_time,
                  DatasetType.stm => Icons.smart_toy_outlined,
                }, size: 18),
                selected: _dataset == t,
                onSelected: (v) async {
                  if (!v || _dataset == t) return;
                  setState(() => _dataset = t);
                  await _loadDataset(t);
                },
              ),
            ),
          const SizedBox(width: 4),
        ],
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
            const Divider(height: 1),
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text('검색 결과가 여기에 표시됩니다.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _placeCard(_results[i]),
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

  // ---------- 카드: 테두리/구분선 제거 + 플롯(Flat) 카드 ----------
  Widget _placeCard(Place p) {
    final isFav = _favorites.contains(p.id);
    final hasTel = (p.tel != null && p.tel!.trim().isNotEmpty);
    final distanceText = '${p.distanceM.toStringAsFixed(0)}m';

    final leadingIcon = Icon(
      switch (_dataset) {
        DatasetType.branches => Icons.store_mall_directory,
        DatasetType.atm => Icons.atm,
        DatasetType.atm365 => Icons.access_time,
        DatasetType.stm => Icons.smart_toy_outlined,
      },
      color: switch (_dataset) {
        DatasetType.branches => const Color(0xFF2962FF),
        DatasetType.atm => const Color(0xFF0B8043),
        DatasetType.atm365 => const Color(0xFFEA4335),
        DatasetType.stm => const Color(0xFF2962FF),
      },
    );

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
          // ✅ 선(테두리/Divider) 제거: 테두리는 0, 대신 은은한 그림자 + 바깥 여백으로 구분
          elevation: 3,
          margin: EdgeInsets.zero,
          color: Colors.white,
          surfaceTintColor: Colors.white, // M3 틴트 방지
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1) 상단: 아이콘 + 제목 + 거리칩 + ★
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        // 배경도 테두리도 없이 Flat
                        color: const Color(0xFFF1F4FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: leadingIcon,
                    ),
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
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 36,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 2) 주소/전화/운영시간 (모두 줄바꿈 없이 Flat하게)
                _infoRow(
                  icon: Icons.place_outlined,
                  text: p.address,
                  maxLines: 1,
                ),
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
                  _infoRow(
                    icon: Icons.access_time,
                    text: p.hours!,
                    maxLines: 1,
                  ),
                ],

                const SizedBox(height: 10),

                // 3) 액션: TextButton(외곽선/Divider 없음)
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: hasTel ? () => _call(p.tel!) : null,
                      icon: const Icon(Icons.call, size: 18),
                      label: const Text('전화'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
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

  Widget _distancePill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FF),
        borderRadius: BorderRadius.circular(999),
        // 테두리 제거(선 느낌 배제), 대신 아주 옅은 배경만
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ===== 모달(바텀시트): Flat + 섹션형 + 큰 버튼 =====
  void _showPlaceSheet(Place p) {
    final hasTel = (p.tel != null && p.tel!.trim().isNotEmpty);
    final km = (p.distanceM / 1000).toStringAsFixed(2);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white, // ✅ Flat 배경
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
              top: 8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F4FB),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        switch (_dataset) {
                          DatasetType.branches => Icons.store_mall_directory,
                          DatasetType.atm => Icons.atm,
                          DatasetType.atm365 => Icons.access_time,
                          DatasetType.stm => Icons.smart_toy_outlined,
                        },
                        color: switch (_dataset) {
                          DatasetType.branches => const Color(0xFF2962FF),
                          DatasetType.atm => const Color(0xFF0B8043),
                          DatasetType.atm365 => const Color(0xFFEA4335),
                          DatasetType.stm => const Color(0xFF2962FF),
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _chip(
                                icon: Icons.place_outlined,
                                label: '거리 $km km',
                              ),
                              if (p.hours != null && p.hours!.isNotEmpty)
                                _chip(icon: Icons.access_time, label: p.hours!),
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
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 주소 섹션
                _section(
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
                      IconButton(
                        tooltip: '네이버 지도에서 보기',
                        onPressed: () async {
                          final uri = Uri.parse(
                            'https://map.naver.com/v5/search/${Uri.encodeComponent(p.title)}',
                          );
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        icon: const Icon(Icons.open_in_new),
                      ),
                    ],
                  ),
                ),

                // 연락처 섹션
                if (hasTel)
                  _section(
                    title: '연락처',
                    child: InkWell(
                      onTap: () => _call(p.tel!),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          Text(
                            '☎ ${p.tel}',
                            style: const TextStyle(
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // 큰 액션 버튼
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _navigateTo(p.lat, p.lng, p.title),
                        icon: const Icon(Icons.directions),
                        label: const Text('길찾기'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        label: const Text('닫기'),
                        style: OutlinedButton.styleFrom(
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

  Widget _chip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FD),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA), // ✅ 섹션 배경만 살짝 회색, 선 없음
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
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
                        onChangeEnd: (_) => _searchNearby(fromCamera: true),
                      );
                    },
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
                      _searchNearby(fromCamera: false);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('현 위치에서 재검색'),
                  ),
                ),
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
              leading: Icon(Icons.star),
              title: Text(
                '즐겨찾기',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            if (favList.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.star_border,
                        size: 56,
                        color: Color(0xFF9EA6B3),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '즐겨찾기가 비어 있어요',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '목록 카드의 ★ 버튼을 눌러 추가하세요.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  itemBuilder: (_, i) {
                    final p = favList[i];
                    return ListTile(
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
                    );
                  },
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemCount: favList.length,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
