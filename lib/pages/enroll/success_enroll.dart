import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:reframe/app/app_shell.dart';
import 'package:reframe/constants/color.dart';
import 'package:reframe/pages/home_page.dart';

class SuccessEnrollPage extends StatelessWidget {
  const SuccessEnrollPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("상품가입 성공"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: LottieBuilder.asset(
                  'assets/images/success.json',
                  width: 200,
                  fit: BoxFit.contain,
                  repeat: false,      // 반복 재생
                  animate: true,     // 자동 재생
                  key: ValueKey('succ-${primaryColor.value}-${subColor.value}'),
                  delegates: LottieDelegates(values: [
                    ValueDelegate.color(['Shape Layer 1','Ellipse 1','Fill 1'], value: subColor),
                    ValueDelegate.color(['Shape Layer 2','Ellipse 1','Fill 1'], value: primaryColor),
                    ValueDelegate.color(['check','Shape 1','Stroke 1'], value: Colors.white),
                  ]),
                ),
              ),
              Text("상품가입 완료!", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
              const SizedBox(height: 60),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomePage()));
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      backgroundColor: Colors.grey[900],
                    ),
                    child: Text(
                      "가입 내역 보러가기",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800
                      ),
                    )
                ),
              )
            ],
          ),
        ),
      )
    );
  }
}
