import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:reframe/core/interceptors/http.dart';
import 'package:reframe/model/enroll_form.dart';
import 'package:reframe/pages/enroll/success_enroll.dart';

String commonUrl = "/mobile/application";

Future<void> addApplication(
    int productId, EnrollForm enrollFormData, BuildContext context) async {
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
      throw Exception('서버 오류: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('연결 실패: $e');
  }
}

Future<EnrollForm> getDraft(int productId) async {
  try {
    final response = await dio.get(
      '$commonUrl/draft/$productId',
    );

    if (response.statusCode == 200) {
      return EnrollForm.fromJson(response.data);
    } else {
      throw Exception('서버 오류: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('연결 실패: $e');
  }
}

Future<void> saveDraft(int productId, EnrollForm enrollForm, BuildContext context) async {
  try {
    final response = await dio.post(
      '$commonUrl/draft/$productId',
      data: enrollForm.toJson(),
    );

    if(response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('입력하신 내용이 임시 저장 되었습니다.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('임시 저장에 실패하였습니다. '),
        ),
      );
    }
  } catch(e) {
    throw Exception('연결 실패: $e');
  }
}

Future<void> markSubmitted(int productId) async {
  try {
    final response = await dio.post(
      '$commonUrl/submit/$productId',
    );

    if(response.statusCode == 200) {
      log("Submit 완료");
      return;
    } else {
      throw Exception('서버 오류: ${response.statusCode}');
    }
  } catch(e) {
    throw Exception('연결 실패: $e');
  }
}