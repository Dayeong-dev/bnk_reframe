import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:reframe/core/interceptors/http.dart';
import 'package:reframe/model/enroll_form.dart';
import 'package:reframe/pages/enroll/success_enroll.dart';

String commonUrl = "/mobile/application";

Future<void> addApplication(int productId, EnrollForm enrollFormData, BuildContext context) async {
  try {
    final response = await dio.post(
      '$commonUrl/add/$productId',
      data: enrollFormData.toJson(),

    );

    if (response.statusCode == 200) {
      int removed = 0;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SuccessEnrollPage()),
            (route) => removed++ >= 3,
      );
    } else {
      print(response.data.toString());
      throw Exception('서버 오류: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('연결 실패: $e');
  }
}