String? _access;  // 전역 메모리
String? getAccessToken() => _access;
void setAccessToken(String token) => _access = token;
void clearAccessToken() => _access = null;