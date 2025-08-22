import 'package:flutter/material.dart';
import 'package:reframe/service/account_service.dart';

class AccountDetailPage extends StatefulWidget {
  final int accountId;

  const AccountDetailPage({super.key, required this.accountId});

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {

  @override
  void initState() {
    super.initState();
    
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
          future: fetchAccountDetail(widget.accountId),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('상세 데이터를 불러오지 못했습니다.'));
            }

            String? data = snapshot.data;

            return Container(
              padding: EdgeInsets.all(16),
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(data ?? "값이 없습니다.", style: const TextStyle(fontFamily: 'monospace'))),
            );
          }),
    );
  }
}
