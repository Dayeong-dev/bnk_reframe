class Document {
  final int documentId;
  final String title;
  final String filename;
  final String? productType;
  final String? documentType;
  final DateTime? regDate;
  final DateTime? modDate;

  Document({
    required this.documentId,
    required this.title,
    required this.filename,
    this.productType,
    this.documentType,
    this.regDate,
    this.modDate,
  });

  factory Document.fromJson(Map<String, dynamic> json) => Document(
    documentId: json['documentId'] as int,
    title: json['title'] as String,
    filename: json['filename'] as String,
    productType: json['productType'] as String,
    documentType: json['documentType'] as String?,
    regDate: DateTime.parse(json['regDate'] as String),
    modDate: DateTime.parse(json['modDate'] as String),
  );
}
