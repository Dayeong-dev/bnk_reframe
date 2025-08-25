class Faq {
  final int faqId;
  final String? category;
  final String? question;
  final String? answer;
  final String? status;

  Faq({
    required this.faqId,
    this.category,
    this.question,
    this.answer,
    this.status,
  });

  factory Faq.fromJson(Map<String, dynamic> json) => Faq(
        faqId: json['faqId'] is int
            ? json['faqId']
            : int.parse(json['faqId'].toString()),
        category: json['category'],
        question: json['question'],
        answer: json['answer'],
        status: json['status'],
      );

  Map<String, dynamic> toJson() => {
        'faqId': faqId,
        'category': category,
        'question': question,
        'answer': answer,
        'status': status,
      };
}
