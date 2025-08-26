class GlobalAvgResponse {
  final int avgUserTotal;
  final int usersCount;

  GlobalAvgResponse({
    required this.avgUserTotal,
    required this.usersCount,
  });

  factory GlobalAvgResponse.fromJson(Map<String, dynamic> json) => GlobalAvgResponse(
    avgUserTotal: json['avgUserTotal'] as int,
    usersCount: json['usersCount'] as int,
  );
}
