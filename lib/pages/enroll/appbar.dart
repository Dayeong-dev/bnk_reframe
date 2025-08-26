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
              builder: (ctx) => Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 제목은 중앙 정렬
                          const Align(
                            alignment: Alignment.center,
                            child: Text(
                              '나가기',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '작성한 내용을 저장하고 나가시겠습니까?',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15, height: 1.4),
                          ),
                          const SizedBox(height: 24),
                          // 버튼 2개 가로 배치
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx, _ExitAction.exitOnly),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.redAccent),
                                    foregroundColor: Colors.redAccent,
                                    minimumSize: const Size(0, 48), // 높이 통일
                                  ),
                                  child: const Text('저장 안함'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, _ExitAction.saveAndExit),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(0, 48), // 높이 통일
                                  ),
                                  child: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('저장 후 나가기'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 오른쪽 상단 X 버튼 (absolute 배치 느낌)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx, _ExitAction.cancel),
                      ),
                    ),
                  ],
                ),
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