import 'common.dart';

class User {
  final int id;
  final String username;
  final String password;
  final String? name;
  final String? email;
  final String? phone;
  final String? usertype;
  final String? role;
  final String? gender;
  final DateTime? birth;

  User(
      {required this.id,
        required this.username,
        required this.password,
        this.name,
        this.email,
        this.phone,
        this.usertype,
        this.role,
        this.gender,
        this.birth});

  factory User.fromJson(Map<String, dynamic> json) => User(
      id: json['id'] as int,
      username: json['username'],
      password: json['password'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      usertype: json['usertype'],
      role: json['role'],
      gender: json['gender'],
      birth: json['birth'] != null ? DateTime.parse(json['birth']) : null,
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "username": username,
    "password": password,
    "name": name,
    "email": email,
    "phone": phone,
    "usertype": usertype,
    "role": role,
    "gender": gender,
    "birth": birth
  };
}
