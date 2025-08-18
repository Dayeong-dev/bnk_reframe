import 'package:flutter/material.dart';

AppBar buildAppBar(BuildContext context) {
  return AppBar(
    centerTitle: true,
    title: const Text('상품 가입'),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).popUntil(ModalRoute.withName('/deposit/detail')),
        child: const Text('나가기', style: TextStyle(color: Colors.red)),
      ),
    ],
  );
}