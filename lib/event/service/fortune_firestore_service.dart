import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fortune_auth_service.dart';

class FortuneFirestoreService {
  static final _db = FirebaseFirestore.instance;

  // 쿠폰 임계값(테스트 2, 운영 10로 변경)
  static const int kCouponThreshold = 10;

  // ===== 공용 재시도 유틸 =====

  /// 지수 백오프 + 지터
  static Future<void> _backoff(int attempt) async {
    if (attempt <= 0) return;
    final base = 300 * pow(2, attempt - 1); // ms: 300, 600, 1200 ...
    final jitter = Random().nextInt(120); // 0~119ms
    final delayMs = base.toInt() + jitter;
    await Future.delayed(Duration(milliseconds: delayMs));
  }

  /// 일반 비트랜잭션 쓰기/읽기 재시도
  static Future<T> _retry<T>(Future<T> Function() fn, {int maxAttempts = 4}) async {
    Exception? lastErr;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) await _backoff(attempt);
      try {
        return await fn();
      } catch (e) {
        lastErr = e is Exception ? e : Exception(e.toString());
      }
    }
    throw lastErr ?? Exception('Unknown Firestore error');
  }

  /// 트랜잭션 재시도
  static Future<T> _retryTx<T>(Future<T> Function(Transaction tx) body, {int maxAttempts = 4}) async {
    Exception? lastErr;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) await _backoff(attempt);
      try {
        return await _db.runTransaction((tx) => body(tx));
      } catch (e) {
        lastErr = e is Exception ? e : Exception(e.toString());
      }
    }
    throw lastErr ?? Exception('Unknown Firestore transaction error');
  }

  // ===== 실시간 스트림 =====
  static Stream<DocumentSnapshot<Map<String, dynamic>>> streamUserDoc(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  static Stream<int> streamStampCount(String uid) {
    return streamUserDoc(uid).map((snap) {
      final data = snap.data();
      if (data == null) return 0;
      final raw = data['stampCount'];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw) ?? 0;
      return 0;
    }).distinct();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamLatestCoupon(String uid) {
    return _db
        .collection('coupons')
        .where('ownerUid', isEqualTo: uid)
        .orderBy('issuedAt', descending: true)
        .limit(1)
        .snapshots();
  }

  // ✅ 내 쿠폰 목록 스트림(최근순)
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamCoupons(String uid) {
    return _db
        .collection('coupons')
        .where('ownerUid', isEqualTo: uid)
        .orderBy('issuedAt', descending: true)
        .snapshots();
  }

  // ✅ 쿠폰 사용 처리
  static Future<void> redeemCoupon(String couponId) {
    final ref = _db.collection('coupons').doc(couponId);
    return _retry(() async {
      await ref.set({
        'status': 'REDEEMED',
        'redeemedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  // ✅ (신규) 쿠폰 코드가 없으면 생성해서 저장하고 반환
  static Future<String> ensureCouponCode(String couponId) {
    final ref = _db.collection('coupons').doc(couponId);
    return _retryTx<String>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        final code = _genHyphenatedCouponCode();
        tx.set(
          ref,
          {
            'title': '[스타벅스] 아이스 아메리카노',
            'ownerUid': FortuneAuthService.getCurrentUid(),
            'issuedAt': FieldValue.serverTimestamp(),
            'status': 'ISSUED',
            'code': code,
          },
          SetOptions(merge: true),
        );
        return code;
      }
      final data = snap.data() as Map<String, dynamic>;
      final current = (data['code'] ?? '').toString();
      if (current.isNotEmpty) return current;
      final newCode = _genHyphenatedCouponCode();
      tx.set(ref, {'code': newCode}, SetOptions(merge: true));
      return newCode;
    });
  }

  // ===== 유저 생성/동의 =====
  static Future<void> saveUserIfNew({
    required String name,
    required String birth, // yyyymmdd 권장
    required String gender,
  }) async {
    final uid = FortuneAuthService.getCurrentUid();
    if (uid == null) return;

    final ref = _db.collection('users').doc(uid);
    await _retry(() async {
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'name': name,
          'birth': birth,
          'gender': gender,
          'stampCount': 0,
          'lastDrawDate': null,
          'consent': {
            'isAgreed': true,
            'agreedAt': FieldValue.serverTimestamp(),
          },
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  static Future<void> saveOrUpdateUserConsent({
    required bool isAgreed,
    String? name,
    String? birth,
    String? gender,
  }) async {
    final uid = FortuneAuthService.getCurrentUid();
    if (uid == null) return;

    final ref = _db.collection('users').doc(uid);

    await _retryTx((tx) async {
      final snap = await tx.get(ref);
      final now = FieldValue.serverTimestamp();

      if (!snap.exists) {
        if (isAgreed) {
          tx.set(ref, {
            'name': name ?? '',
            'birth': birth ?? '',
            'gender': gender ?? '',
            'stampCount': 0,
            'lastDrawDate': null,
            'consent': {'isAgreed': true, 'agreedAt': now},
            'createdAt': now,
            'updatedAt': now,
          });
        }
        return;
      }

      final data = <String, dynamic>{
        'consent': {'isAgreed': isAgreed, if (isAgreed) 'agreedAt': now},
        'updatedAt': now,
      };

      if (isAgreed) {
        if (name != null) data['name'] = name;
        if (birth != null) data['birth'] = birth;
        if (gender != null) data['gender'] = gender;
      }

      tx.set(ref, data, SetOptions(merge: true));
    });
  }

  // ===== 초대 리워드 =====
  // 테스트용: 동일 친구의 중복 방문 문서 생성 허용(랜덤 문서 ID)
  static Future<void> rewardInviteOnce({
    required String inviterUid,
    required String inviteeUid,
    String? source,
    bool debugAllowSelf = false,
  }) async {
    if (!debugAllowSelf && inviterUid == inviteeUid) return;

    final visitorsCol = _db.collection('invites').doc(inviterUid).collection('visitors');

    await _retryTx((tx) async {
      final newDoc = visitorsCol.doc(); // 중복 허용
      tx.set(
        newDoc,
        {
          'inviterUid': inviterUid,
          'inviteeUid': inviteeUid, // 중복 판정 키
          'src': source,
          'createdAt': FieldValue.serverTimestamp(),
          'claimed': false,
        },
        SetOptions(merge: true),
      );
    });
  }

  // 내부: 사람이 읽기 쉬운 하이픈 코드 4-4-4-4-2 (총 18자 + 하이픈 4개)
  static String _genHyphenatedCouponCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 0,O,1,I 제거
    Random r;
    try {
      r = Random.secure();
    } catch (_) {
      r = Random();
    }
    String seg(int len) => List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
    return '${seg(4)}-${seg(4)}-${seg(4)}-${seg(4)}-${seg(2)}';
  }

  /// 정산: 배치 내에서 같은 inviteeUid는 1회만 스탬프 증가.
  /// (중복 방문 문서는 모두 claimed 처리하되, 증가 카운트는 1로 제한)
  static Future<int> claimPendingInvitesAndIssueRewards({
    required String inviterUid,
    int batchSize = 10, // 한 번에 처리할 문서 수(이건 바꾸지 마세요)
  }) async {
    // 미정산 방문 목록
    final q = await _retry(() => _db
        .collection('invites')
        .doc(inviterUid)
        .collection('visitors')
        .where('claimed', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .limit(batchSize)
        .get());

    if (q.docs.isEmpty) return 0;

    // 배치 중복 방지: 같은 친구(inviteeUid)당 1회만 증가
    final processedKeys = <String>{}; // key = inviteeUid가 있으면 그 값, 없으면 문서 ID
    var appliedCount = 0;

    for (final doc in q.docs) {
      await _retryTx((tx) async {
        final vRef = doc.reference;
        final fresh = await tx.get(vRef);
        if (!fresh.exists) return;

        final data = fresh.data() as Map<String, dynamic>;
        if (data['claimed'] == true) return;

        final inviteeUid = (data['inviteeUid'] ?? '').toString().trim();
        final key = inviteeUid.isNotEmpty ? inviteeUid : vRef.id;

        final inviterRef = _db.collection('users').doc(inviterUid);
        final inviterSnap = await tx.get(inviterRef);

        int current = 0;
        if (inviterSnap.exists) {
          final raw = inviterSnap.data()?['stampCount'];
          if (raw is int) current = raw;
          else if (raw is num) current = raw.toInt();
          else if (raw is String) current = int.tryParse(raw) ?? 0;
        } else {
          tx.set(
            inviterRef,
            {
              'stampCount': 0,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        // 방문 문서 정산 처리(공통)
        tx.set(
          vRef,
          {
            'claimed': true,
            'claimedBy': inviterUid,
            'claimedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        // 이미 같은 key(= 같은 친구)를 이번 배치에서 처리했다면 스탬프 증가 없이 종료
        if (processedKeys.contains(key)) {
          return;
        }

        // 이번 배치에서 최초 처리 → 스탬프 +1
        processedKeys.add(key);

        final next = current + 1;
        tx.set(
          inviterRef,
          {
            'stampCount': next,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        appliedCount += 1;

        // 임계값마다 쿠폰 발급 후 리셋
        if (next % kCouponThreshold == 0) {
          final couponRef = _db.collection('coupons').doc();
          tx.set(
            couponRef,
            {
              'ownerUid': inviterUid,
              'issuedAt': FieldValue.serverTimestamp(),
              'status': 'ISSUED',
              'title': '[스타벅스] 아이스 아메리카노',
              'code': _genHyphenatedCouponCode(),
            },
            SetOptions(merge: true),
          );

          // 정책: 발급 후 도장 리셋
          tx.set(inviterRef, {'stampCount': 0}, SetOptions(merge: true));
        }
      });
    }

    return appliedCount;
  }

  // ===== 운세 1일 1회 기록 =====
  static Future<void> setLastDrawDateToday() async {
    final uid = FortuneAuthService.getCurrentUid();
    if (uid == null) return;

    final now = DateTime.now();
    final ymd = "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";

    final ref = _db.collection('users').doc(uid);

    await _retryTx((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() as Map<String, dynamic>?;

      final hasStamp = data != null && data['stampCount'] != null;
      final update = <String, dynamic>{
        'lastDrawDate': ymd,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!hasStamp) update['stampCount'] = 0;

      tx.set(ref, update, SetOptions(merge: true));
    });
  }
}
