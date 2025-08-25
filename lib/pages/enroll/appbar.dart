import 'package:flutter/material.dart';

import '../../model/enroll_form.dart';
import '../../service/enroll_service.dart';

AppBar buildAppBar({required BuildContext context, EnrollForm? enrollForm, int? productId}) {
  return AppBar(
    title: const Text('상품 가입'),
    actions: [
      TextButton(
        onPressed: () async {
          if (enrollForm != null && productId != null) {
            final choice = await showDialog<_ExitAction>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('나가기'),
                content: const Text('작성한 내용을 저장하고 나가시겠습니까?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, _ExitAction.cancel),
                    child: const Text('취소'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, _ExitAction.exitOnly),
                    child: const Text('저장 안함'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, _ExitAction.saveAndExit),
                    child: const Text('저장 후 나가기'),
                  ),
                ],
              ),
            );

            if (choice == _ExitAction.saveAndExit) {
              await saveDraft(productId, enrollForm, context);
            } else if (choice == _ExitAction.cancel) {
              return; // 다이얼로그만 닫고 머무름
            }
          }
          Navigator.of(context).popUntil(ModalRoute.withName('/deposit/detail'));
        },
        child: const Text(
          '나가기',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
    ],
  );
}


enum _ExitAction { saveAndExit, exitOnly, cancel }