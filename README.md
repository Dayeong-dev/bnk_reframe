# BNK Reframe App
### Flutter 기반 은행상품 안내 및 가입 모바일 앱
A new Flutter project.

이 레포지토리는 **BNK Reframe 2차 프로젝트**의 사용자 모바일 애플리케이션입니다. <br>
예적금 상품 탐색, 본인인증 및 가입, 이벤트/리워드, 오늘의 운세, AI 챗봇 등 다양한 기능을 제공합니다. <br>

👉 전체 프로젝트 개요는 [허브 레포지토리](https://github.com/Dayeong-dev/bnk-project-2)에서 확인할 수 있습니다. 

## ✨ 주요 기능

### 👤 회원가입 & 로그인
- JWT 로그인 및 자동 로그인
- 생체인증(LocalAuth: 지문·Face ID)

### 💰 상품 탐색
- 예·적금 상품 검색/추천/자동완성
- 이자 계산기 제공

### 📝 상품 가입 프로세스
1. 본인인증(더미)  
2. 약관 열람(필수)  
3. 조건 입력  
4. 최종 확인  
5. 생체인증 완료

### 🎁 이벤트 & 리워드
- 오늘의 운세 제공 (AI 기반)
- 친구 초대 → 스탬프 적립 → 쿠폰 발급

### 📊 저축성향 테스트
- 간단한 문항을 통한 저축 성향 분석
- 맞춤 상품 추천 제공

### 📍 지도 서비스
- 현재 위치 기반 영업점·ATM 탐색
- 외부 지도 앱과 연동하여 길찾기 지원

### 🤖 AI 챗봇
- OpenAI 기반 대화형 상담
- **음성 입력/출력 지원** → 디지털 소외계층·고령층도 쉽게 접근 가능


## 🛠 기술 스택
- **Framework**: Flutter (Dart 3.x)
- **상태 관리 & 네트워킹**: Provider, Dio
- **보안 & 인증**: JWT 연동, LocalAuth(지문·Face ID), Flutter Secure Storage
- **클라우드 서비스**: Firebase (푸시 알림, Analytics, Firestore, Auth)
- **지도 & 위치**: Naver Map SDK, Geolocator, 외부 앱 길찾기 연동
- **실시간 & 접근성**: WebSocket, 음성 입출력(Speech-to-Text, TTS)
- **UI/UX**: Material 2 기반 커스텀 테마, Lottie 애니메이션
- **문서/데이터**: PDF 뷰어(pdfrx), JSON 기반 오프라인 지점/ATM 데이터
- **그 외**: 앱 딥링크(App Links), 공유(Share Plus)

## 📚 참고 문서
- [와이어프레임](https://github.com/Dayeong-dev/bnk-project-2/blob/main/docs/BNK_2차_프로젝트_와이어프레임.pdf)
- [플로우차트(로그인)](https://github.com/Dayeong-dev/bnk-project-2/blob/main/docs/BNK_2차_프로젝트_플로우차트_로그인.png)
- [플로우차트(상품 가입)](https://github.com/Dayeong-dev/bnk-project-2/blob/main/docs/BNK_2차_프로젝트_플로우차트_상품가입.png)
- [플로우차트(예적금 탐색)](https://github.com/Dayeong-dev/bnk-project-2/blob/main/docs/BNK_2차_프로젝트_플로우차트_예적금.png)

## ⚙️ 실행 방법
```bash
# 의존성 설치
flutter pub get

# 앱 실행 (에뮬레이터 또는 디바이스)
flutter run
```
