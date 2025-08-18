// lib/recommender.dart

// 1) 로직의 타입(문구와 분리)
enum Term { short, long }                 // 단기/장기
enum SavingMode { deposit, installment }  // 예금/적금
enum Flex { rigid, flexible }             // 중도해지 없음/있음
enum Habit { no, yes }                    // 습관형 아님/맞음

class SavingAnswers {
  final Term term;
  final SavingMode mode;
  final Flex flex;
  final Habit habit;
  const SavingAnswers({
    required this.term,
    required this.mode,
    required this.flex,
    required this.habit,
  });
}

// 2) 결과코드(A~H) 산출
String resultCode(SavingAnswers a) {
  if (a.mode == SavingMode.deposit) {
    if (a.term == Term.short && a.flex == Flex.rigid) return 'A';
    if (a.term == Term.short && a.flex == Flex.flexible) return 'B';
    return 'C'; // long + deposit
  } else {
    if (a.flex == Flex.flexible) return 'F';
    if (a.term == Term.short && a.habit == Habit.no) return 'D';
    if (a.term == Term.short && a.habit == Habit.yes) return 'E';
    if (a.term == Term.long && a.habit == Habit.no) return 'G';
    return 'H';
  }
}

// 3) 결과코드 → productId
const Map<String, int> kResultCodeToProductId = {
  'A': 20,  // 더(The) 특판 정기예금
  'B': 21,  // LIVE 정기예금
  'C': 18,  // bnk내맘대로예금
  'D': 2,   // BNK내맘대로적금
  'E': 73,  // 매일출석적금
  'F': 2,   // BNK내맘대로적금
  'G': 2,   // BNK내맘대로적금
  'H': 73,  // 매일적금(= 매일출석적금)
  // RESULT_* 형태로 넘겨도 동작하게 허용
  'RESULT_A': 20,
  'RESULT_B': 21,
  'RESULT_C': 18,
  'RESULT_D': 2,
  'RESULT_E': 73,
  'RESULT_F': 2,
  'RESULT_G': 2,
  'RESULT_H': 73,
};

int? productIdForResult(String code) => kResultCodeToProductId[code];

// 4) 결과 텍스트
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

// 5) (호환용) 현재 문자열 리스트 답변 → enum으로 변환
//    질문 문구가 바뀌면 이 함수만 수정하면 됨.
SavingAnswers mapStringsToAnswers(List<String> answers) {
  // Q1: '단기간 목돈 마련' | '안정적인 이자 수익'
  final term = (answers[0].contains('단기간')) ? Term.short : Term.long;

  // Q2: '한 번에 예치'/'한 번에 크게 저축' | '매달 조금씩 저축'
  final mode = (answers[1].contains('한 번에')) ? SavingMode.deposit : SavingMode.installment;

  // Q3: '없다' | '상황에 따라 필요할 수도'
  final flex = (answers[2] == '없다') ? Flex.rigid : Flex.flexible;

  // Q4: '네' | '아니오'
  final habit = (answers[3] == '네') ? Habit.yes : Habit.no;

  return SavingAnswers(term: term, mode: mode, flex: flex, habit: habit);
}

// 6) (호출 호환) 기존 함수 시그니처 유지하고 내부는 enum 로직 사용
String getRecommendationCode(List<String> answers) => resultCode(mapStringsToAnswers(answers));
