import 'package:cloud_firestore/cloud_firestore.dart';

class ConsentInfo {
  final bool isAgreed; // 동의 여부
  final DateTime? agreedAt; // 동의한 시각(서버 기준)

  const ConsentInfo({
    required this.isAgreed,
    this.agreedAt,
  });

  factory ConsentInfo.fromJson(Map<String, dynamic> json) {
    final ts = json['agreedAt'];
    return ConsentInfo(
      isAgreed: json['isAgreed'] ?? false,
      agreedAt: ts is Timestamp
          ? ts.toDate()
          : (ts is String ? DateTime.tryParse(ts) : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isAgreed': isAgreed,
      if (agreedAt != null) 'agreedAt': Timestamp.fromDate(agreedAt!),
    };
  }
}

class UserData {
  final String name; // 저장: 동의 O일 때만
  final String birth; // yyyymmdd
  final String gender; // "남"/"여"
  final int stampCount; // 초대한 사람만 +1 누적
  final String? lastDrawDate; // yyyymmdd
  final ConsentInfo? consent; // 동의 정보

  const UserData({
    required this.name,
    required this.birth,
    required this.gender,
    required this.stampCount,
    this.lastDrawDate,
    this.consent,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      name: json['name'] ?? '',
      birth: json['birth'] ?? '',
      gender: json['gender'] ?? '',
      stampCount: (json['stampCount'] ?? 0) as int,
      lastDrawDate: json['lastDrawDate'],
      consent: json['consent'] != null
          ? ConsentInfo.fromJson(Map<String, dynamic>.from(json['consent']))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'birth': birth,
      'gender': gender,
      'stampCount': stampCount,
      if (lastDrawDate != null) 'lastDrawDate': lastDrawDate,
      if (consent != null) 'consent': consent!.toJson(),
    };
  }
}
