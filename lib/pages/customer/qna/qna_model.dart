class Qna {
  final int qnaId;
  final String category;
  final String title;
  final String content;
  final String? answer;
  final String status;
  final DateTime? regdate;
  final DateTime? moddate;

  Qna({
    required this.qnaId,
    required this.category,
    required this.title,
    required this.content,
    this.answer,
    required this.status,
    this.regdate,
    this.moddate,
  });

  factory Qna.fromJson(Map<String, dynamic> j) => Qna(
        qnaId: j['qnaId'],
        category: j['category'],
        title: j['title'],
        content: j['content'],
        answer: j['answer'],
        status: j['status'],
        regdate: j['regdate'] != null ? DateTime.parse(j['regdate']) : null,
        moddate: j['moddate'] != null ? DateTime.parse(j['moddate']) : null,
      );
}
