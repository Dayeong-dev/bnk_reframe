class ProductInputFormat {
  final int productId;
  final bool input1;
  final bool input2;
  final bool input3;
  final bool input4;
  final bool input5;
  final bool input6;
  final bool input7;
  final bool input8;

  final bool fromAccountReq;
  final bool maturityAccountReq;

  ProductInputFormat({
    required this.productId,
    required this.input1,
    required this.input2,
    required this.input3,
    required this.input4,
    required this.input5,
    required this.input6,
    required this.input7,
    required this.input8,
    required this.fromAccountReq,
    required this.maturityAccountReq,
  });

  factory ProductInputFormat.fromJson(Map<String, dynamic> json) {
    return ProductInputFormat(
      productId: json['productId'] as int,
      input1: json['input1'] == 1,
      input2: json['input2'] == 1,
      input3: json['input3'] == 1,
      input4: json['input4'] == 1,
      input5: json['input5'] == 1,
      input6: json['input6'] == 1,
      input7: json['input7'] == 1,
      input8: json['input8'] == 1,
      fromAccountReq: json['fromAccountReq'] == 1,
      maturityAccountReq: json['maturityAccountReq'] == 1,
    );
  }
}
