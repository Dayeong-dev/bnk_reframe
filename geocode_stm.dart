// geocode_extended.dart
//
// 목적: assets/atm_extended.json에서 lat/lng이 null인 항목만 지오코딩으로 채워
//       assets/atm_extended_geocoded.json로 저장 (앱은 geocoded만 사용)
//
// 실행:
//   dart run geocode_extended.dart
//   (기본 입력: assets/atm_extended.json, 출력: assets/atm_extended_geocoded.json)
//
// 주의:
// - 지도 Geocoding은 "Maps API Gateway"용 키가 필요합니다.
// - 엔드포인트는 maps.apigw.ntruss.com 입니다 (중요!).
//
// 변경점(기존 형식 동일):
// - 엔드포인트: https://maps.apigw.ntruss.com/map-geocode/v2/geocode
// - 헤더에 Accept: application/json 추가
// - 프리플라이트(_preflight)로 200 확인 후 본 작업 시작
// - 실패 항목은 별도 파일로 저장

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

// ✅ 네이버 클라우드 Maps API Gateway 키 (공개 저장소 업로드 금지)
const String kNaverClientId = "1vyye633d9"; // Application Key ID
const String kNaverClientSecret =
    "0OZ7AiQ29O69UNPrfXXbIZqCKQfdbOVIDecn4NIE"; // Application Key

// 경로
const String kDefaultInput = 'assets/stm.json';
const String kDefaultOutput = 'assets/stm_geocoded.json';
const String kFailOutput = 'assets/stm_failed.json';
const String kCachePath = '.geocode_cache_stm.json';

// 엔드포인트
const String kGeocodeUrl =
    'https://maps.apigw.ntruss.com/map-geocode/v2/geocode';

typedef Coord = Map<String, double>; // {'lat': .., 'lng': ..}

Future<void> main(List<String> args) async {
  // 0) 프리플라이트
  final ok = await _preflight();
  if (!ok) {
    stderr.writeln('❌ 프리플라이트 실패: 키/상품/엔드포인트를 다시 확인하세요.');
    exit(1);
  }

  // 1) 경로
  final inputPath = args.isNotEmpty ? args[0] : kDefaultInput;
  final outputPath = args.length > 1 ? args[1] : kDefaultOutput;

  // 2) 입력 로드
  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('❌ 입력 파일이 없습니다: $inputPath');
    exit(1);
  }
  late final List<dynamic> list;
  try {
    list = jsonDecode(await inputFile.readAsString()) as List<dynamic>;
  } catch (e) {
    stderr.writeln('❌ JSON 파싱 실패: $e');
    exit(1);
  }

  // 3) 캐시 로드
  final Map<String, Coord> cache = await _loadCache();

  // 4) Dio
  final dio = Dio(
    BaseOptions(
      headers: {
        'X-NCP-APIGW-API-KEY-ID': kNaverClientId,
        'X-NCP-APIGW-API-KEY': kNaverClientSecret,
        'Accept': 'application/json',
      },
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 10),
    ),
  );

  int total = list.length, need = 0, success = 0, fail = 0, skip = 0;
  final failures = <Map<String, dynamic>>[];

  // 5) 루프
  for (int i = 0; i < list.length; i++) {
    final item = list[i];
    if (item is! Map<String, dynamic>) continue;

    final name = _asStr(item['name'] ?? item['title']);
    final addressRaw = _asStr(
      item['address'] ?? item['addr'] ?? item['roadAddress'],
    );
    final lat = item['lat'];
    final lng = item['lng'];

    if (lat != null && lng != null) {
      skip++;
      continue;
    }
    if (addressRaw.isEmpty) {
      fail++;
      failures.add({'name': name, 'reason': '주소 없음', 'src': item});
      stderr.writeln('⚠️  [주소 없음] $name');
      continue;
    }
    need++;

    final address = _normalizeAddress(addressRaw);

    // 캐시
    if (cache.containsKey(address)) {
      final c = cache[address]!;
      item['lat'] = c['lat'];
      item['lng'] = c['lng'];
      success++;
      stdout.writeln('✅ [캐시] $name ← (${c['lat']}, ${c['lng']})');
      continue;
    }

    // 호출
    try {
      final res = await dio.get(
        kGeocodeUrl,
        queryParameters: {'query': address},
      );
      if (res.statusCode == 200 &&
          res.data is Map &&
          res.data['addresses'] is List &&
          (res.data['addresses'] as List).isNotEmpty) {
        final a = res.data['addresses'][0];
        final latParsed = double.tryParse('${a['y']}');
        final lngParsed = double.tryParse('${a['x']}');

        if (latParsed != null && lngParsed != null) {
          item['lat'] = latParsed;
          item['lng'] = lngParsed;
          cache[address] = {'lat': latParsed, 'lng': lngParsed};
          success++;
          stdout.writeln('✅ [지오코딩] $name ← ($latParsed, $lngParsed)');
        } else {
          fail++;
          failures.add({
            'name': name,
            'address': address,
            'reason': '좌표 파싱 실패',
          });
          stderr.writeln('⚠️  [좌표 파싱 실패] $name | $address');
        }
      } else {
        fail++;
        failures.add({
          'name': name,
          'address': address,
          'reason': '결과 없음/비정상',
          'status': res.statusCode,
        });
        stderr.writeln('⚠️  [결과 없음/비정상] $name | status=${res.statusCode}');
      }
    } on DioException catch (e) {
      fail++;
      failures.add({'name': name, 'address': address, 'reason': e.message});
      stderr.writeln('❌ [요청 실패] $name | ${e.message}');
    } catch (e) {
      fail++;
      failures.add({'name': name, 'address': address, 'reason': e.toString()});
      stderr.writeln('❌ [예외] $name | $e');
    }

    // QPS 완화
    await Future.delayed(const Duration(milliseconds: 150));
  }

  // 6) 저장
  final pretty = const JsonEncoder.withIndent('  ').convert(list);
  await File(outputPath).writeAsString(pretty);
  stdout.writeln('📦 결과 저장 → $outputPath');

  // 7) 실패 저장
  if (failures.isNotEmpty) {
    final failPretty = const JsonEncoder.withIndent('  ').convert(failures);
    await File(kFailOutput).writeAsString(failPretty);
    stdout.writeln('🧾 실패 목록 → $kFailOutput (${failures.length}건)');
  }

  // 8) 캐시 저장
  await _saveCache(cache);
  stdout.writeln('🗂️  캐시 저장 → $kCachePath');

  // 9) 요약
  stdout.writeln('\n==== 변환 요약 ====');
  stdout.writeln('총 항목: $total');
  stdout.writeln('좌표 필요: $need');
  stdout.writeln('성공: $success');
  stdout.writeln('이미 보유(스킵): $skip');
  stdout.writeln('실패: $fail');
}

// ───────── 유틸 ─────────

String _asStr(Object? v) => v?.toString().trim() ?? '';

String _normalizeAddress(String addr) {
  var s = addr.replaceAll(RegExp(r'\s+'), ' ').trim();
  s = s.replaceAll('( ', '(').replaceAll(' )', ')');
  return s;
}

Future<Map<String, Coord>> _loadCache() async {
  final f = File(kCachePath);
  if (!f.existsSync()) return {};
  try {
    final j = jsonDecode(await f.readAsString());
    if (j is Map<String, dynamic>) {
      return j.map((k, v) {
        final m = Map<String, dynamic>.from(v as Map);
        return MapEntry(k, {
          'lat': (m['lat'] as num).toDouble(),
          'lng': (m['lng'] as num).toDouble(),
        });
      });
    }
  } catch (_) {}
  return {};
}

Future<void> _saveCache(Map<String, Coord> cache) async {
  final m = cache.map(
    (k, v) => MapEntry(k, {'lat': v['lat'], 'lng': v['lng']}),
  );
  final pretty = const JsonEncoder.withIndent('  ').convert(m);
  await File(kCachePath).writeAsString(pretty);
}

Future<bool> _preflight() async {
  final dio = Dio(
    BaseOptions(
      headers: {
        'X-NCP-APIGW-API-KEY-ID': kNaverClientId,
        'X-NCP-APIGW-API-KEY': kNaverClientSecret,
        'Accept': 'application/json',
      },
      validateStatus: (_) => true,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );
  final res = await dio.get(kGeocodeUrl, queryParameters: {'query': '부산 부산진구'});
  stdout.writeln('🔎 Preflight status: ${res.statusCode}');
  stdout.writeln('🔎 Preflight body: ${res.data}');
  return res.statusCode == 200;
}
