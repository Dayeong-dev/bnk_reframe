import 'package:cloud_firestore/cloud_firestore.dart';
import 'fortune_auth_service.dart';

class FortuneFirestoreService {
  static final _db = FirebaseFirestore.instance;

  // ===== 실시간 스트림 =====
  static Stream<DocumentSnapshot<Map<String, dynamic>>> streamUserDoc(
      String uid) {
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

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamLatestCoupon(
      String uid) {
    return _db
        .collection('coupons')
        .where('ownerUid', isEqualTo: uid)
        .orderBy('issuedAt', descending: true)
        .limit(1)
        .snapshots();
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
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'name': name,
        'birth': birth,
        'gender': gender,
        'stampCount': 0, // 기본값 0
        'lastDrawDate': null,
        'consent': {
          'isAgreed': true,
          'agreedAt': FieldValue.serverTimestamp(),
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
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
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final now = FieldValue.serverTimestamp();

      if (!snap.exists) {
        if (isAgreed) {
          tx.set(ref, {
            'name': name ?? '',
            'birth': birth ?? '',
            'gender': gender ?? '',
            'stampCount': 0, // 기본값 0
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
  static Future<void> rewardInviteOnce({
    required String inviterUid,
    required String inviteeUid,
    String? source,
    bool debugAllowSelf = false,
  }) async {
    if (!debugAllowSelf && inviterUid == inviteeUid) return;

    final visitorsCol =
        _db.collection('invites').doc(inviterUid).collection('visitors');

    await _db.runTransaction((tx) async {
      final newDoc = visitorsCol.doc();
      tx.set(newDoc, {
        'inviterUid': inviterUid,
        'inviteeUid': inviteeUid,
        'src': source,
        'createdAt': FieldValue.serverTimestamp(),
        'claimed': false,
      });
    });
  }

  static Future<int> claimPendingInvitesAndIssueRewards({
    required String inviterUid,
    int batchSize = 10,
  }) async {
    final q = await _db
        .collection('invites')
        .doc(inviterUid)
        .collection('visitors')
        .where('claimed', isEqualTo: false)
        .orderBy('createdAt', descending: false)
        .limit(batchSize)
        .get();

    if (q.docs.isEmpty) return 0;

    var claimedCount = 0;

    for (final doc in q.docs) {
      await _db.runTransaction((tx) async {
        final vRef = doc.reference;
        final fresh = await tx.get(vRef);
        if (!fresh.exists) return;

        final data = fresh.data() as Map<String, dynamic>;
        if (data['claimed'] == true) return;

        final inviterRef = _db.collection('users').doc(inviterUid);
        final inviterSnap = await tx.get(inviterRef);

        int current = 0;
        if (inviterSnap.exists) {
          final raw = inviterSnap.data()?['stampCount'];
          if (raw is int)
            current = raw;
          else if (raw is num)
            current = raw.toInt();
          else if (raw is String) current = int.tryParse(raw) ?? 0;
        } else {
          current = 0; // 기본값 0
          tx.set(
              inviterRef,
              {
                'stampCount': current,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true));
        }

        final next = current + 1;

        tx.set(
            vRef,
            {
              'claimed': true,
              'claimedBy': inviterUid,
              'claimedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));

        tx.update(inviterRef, {
          'stampCount': next,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (next % 2 == 0) {
          final couponRef = _db.collection('coupons').doc();
          tx.set(couponRef, {
            'ownerUid': inviterUid,
            'issuedAt': FieldValue.serverTimestamp(),
            'status': 'ISSUED',
          });
          tx.update(inviterRef, {'stampCount': 0});
        }

        claimedCount += 1;
      });
    }

    return claimedCount;
  }

  // ===== 운세 1일 1회 기록 =====
  static Future<void> setLastDrawDateToday() async {
    final uid = FortuneAuthService.getCurrentUid();
    if (uid == null) return;

    final now = DateTime.now();
    final ymd =
        "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}";

    final ref = _db.collection('users').doc(uid);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() as Map<String, dynamic>?;
      final hasStamp = data != null && data['stampCount'] != null;
      final update = <String, dynamic>{
        'lastDrawDate': ymd,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!hasStamp) update['stampCount'] = 0; // 기본값 0
      tx.set(ref, update, SetOptions(merge: true));
    });
  }
}
