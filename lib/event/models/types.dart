/// 화면 전파용 경량 타입 (저장은 아님)
typedef FortuneFlowArgs = ({
bool isAgreed,
String? name,
String? birthDate, // yyyymmdd
String? gender,    // "남"/"여"
String? invitedBy, // 초대한 사람 uid
});