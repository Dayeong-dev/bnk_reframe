import 'package:flutter/material.dart';
import 'package:reframe/pages/account/product/deposit_page.dart';
import 'package:reframe/pages/account/product/group_demand_page.dart';
import 'package:reframe/pages/account/product/walk_saving_page.dart';
import 'package:reframe/service/account_service.dart';

import '../../model/product_account_detail.dart';

class AccountDetailPage extends StatefulWidget {
  final int accountId;
  const AccountDetailPage({super.key, required this.accountId});

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  late final Future<ProductAccountDetail> _detailFuture;

  @override
  void initState() {
    super.initState();
    // ✅ 한 번만 호출하도록 Future 캐싱
    _detailFuture = fetchAccountDetail(widget.accountId);
    // fetchAccountDetail가 ProductAccountDetail을 반환하도록 타입 맞추세요.
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProductAccountDetail>(
      future: _detailFuture,
      builder: (context, snapshot) {
        // 로딩
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // 에러
        if (snapshot.hasError || !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: Text('상세 데이터를 불러오지 못했습니다.')),
          );
        }

        final detail = snapshot.data!;
        final app = detail.application;
        final product = app.product;
        final accountId = detail.account?.id;

        if (accountId == null) {
          return const Scaffold(
            body: Center(child: Text('계좌 정보가 없습니다.')),
          );
        }

        // 내용 위젯 분기
        Widget body;
        switch (product.productId) {
          case 69:
            body = GroupDemandPage(accountId: accountId);
            break;
          case 74:
            body = WalkSavingPage(accountId: accountId);
            break;
          default:
            body = DepositPage(accountId: accountId);
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(product.name),
          ),
          body: body,
        );
      },
    );
  }
}
