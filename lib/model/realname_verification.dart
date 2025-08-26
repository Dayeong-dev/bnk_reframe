import 'package:reframe/model/user.dart';

class RealnameVerification {
  final int? id;
  final User? user;
  final String name;
  final String phone;
  final String carrier;
  final String rrnFront;
  final String? gender;
  final String? ci;
  final DateTime? verifiedAt;
  final DateTime? expiresAt;

  RealnameVerification({
    this.id,
    this.user,
    required this.name,
    required this.phone,
    required this.carrier,
    required this.rrnFront,
    this.gender,
    this.ci,
    this.verifiedAt,
    this.expiresAt,
  });

  factory RealnameVerification.fromJson(Map<String, dynamic> json) {
    return RealnameVerification(
      id: json['id'],
      user: User.fromJson(json['user']),
      name: json['name'],
      phone: json['phone'],
      ci: json['ci'],
      verifiedAt: DateTime.parse(json['verifiedAt']),
      expiresAt: DateTime.parse(json['expiresAt']),
      carrier: json['carrier'],
      rrnFront: json['rrnFront'],
      gender: json['gender'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user': user,
    'name': name,
    'phone': phone,
    'ci': ci,
    'verifiedAt': verifiedAt,
    'expiresAt': expiresAt,
    'carrier': carrier,
    'rrnFront': rrnFront,
    'gender': gender,
  };
}
