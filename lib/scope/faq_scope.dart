import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../service/faq_api.dart';
import '../store/faq_store.dart';

class FaqScope extends StatelessWidget {
  const FaqScope({
    super.key,
    required this.child,
    this.baseUrl = 'http://192.168.100.135:8090', // ← 너 주소
  });

  final Widget child;
  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FaqApi>(create: (_) => FaqApi(baseUrl: baseUrl)),
        ChangeNotifierProvider<FaqStore>(create: (ctx) => FaqStore(api: ctx.read<FaqApi>())),
      ],
      child: child,
    );
  }
}
