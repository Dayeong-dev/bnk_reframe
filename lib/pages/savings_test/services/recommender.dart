String getRecommendationCode(List<String> answers) {
  String period = answers[0] == '단기간 목돈 마련' ? 'short' : 'long';
  String method = answers[1] == '한 번에 예치' ? 'deposit' : 'installment';
  String flex = answers[2] == '없다' ? '!flex' : 'flex';
  String habit = answers[3] == '네' ? 'habit' : '!habit';

  if (method == 'deposit') {
    if (period == 'short' && flex == '!flex') return 'A';
    if (period == 'short' && flex == 'flex') return 'B';
    if (period == 'long') return 'C';
  } else if (method == 'installment') {
    if (flex == 'flex') return 'F';
    if (period == 'short' && habit == '!habit') return 'D';
    if (period == 'short' && habit == 'habit') return 'E';
    if (period == 'long' && habit == '!habit') return 'G';
    if (period == 'long' && habit == 'habit') return 'H';
  }
  return 'Unknown';
}

String getRecommendationText(String code) {
  const recMap = {
    'A': '단기 고정금리 예금 추천',
    'B': '단기 유연한 예금 상품 추천',
    'C': '장기 안정형 예금 추천',
    'D': '단기 자유 적금 추천',
    'E': '단기 목표형 적금 (자동이체 추천)',
    'F': '유연한 적금 (해지해도 이율 손해 적은 상품)',
    'G': '장기 적금 추천',
    'H': '장기 목표형 적금 추천 (저축 챌린지 가능)',
  };
  return recMap[code] ?? '추천 결과 없음';
}
