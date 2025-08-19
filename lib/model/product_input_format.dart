class ProductInputFormat {
  final int? productId;
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

  const ProductInputFormat({
    this.productId,
    this.input1 = true,
    this.input2 = true,
    this.input3 = true,
    this.input4 = true,
    this.input5 = true,
    this.input6 = true,
    this.input7 = true,
    this.input8 = true,
    this.fromAccountReq = true,
    this.maturityAccountReq = true,
  });
}