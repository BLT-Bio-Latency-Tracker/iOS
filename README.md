# Bryki

Bryki는 Apple HealthKit 수면 데이터와 PVT 검사를 기반으로 사용자의 당일 뇌 컨디션을 분석하는 iOS 앱입니다.

사용자는 수면 데이터와 30초 PVT 테스트를 통해 Brain ROI 점수를 확인할 수 있으며, 앱은 해당 점수를 기반으로 오늘의 컨디션과 업무 우선순위를 제안합니다.

## 주요 기능

- Apple 로그인
- HealthKit 수면 데이터 및 HRV 연동
- 30초 PVT 반응속도 테스트
- Brain ROI 점수 확인
- ROI 점수 기반 투두 추천
- 수면 상세 분석
- 날짜별 히스토리 조회
- PVT 기록 상세 조회 및 삭제
- FCM 기반 푸시 알림
- 일간 보고서 미리보기 및 PDF 공유

## 기술 스택(iOS)

- Swift
- SwiftUI
- UIKit
- Combine
- HealthKit
- AuthenticationServices
- UserNotifications
- Firebase Cloud Messaging
- URLSession 기반 REST API 통신
- MVVM Architecture

## 아키텍처

Bryki는 Feature-based MVVM 구조로 구성되어 있습니다.

각 기능은 `Features` 하위에 독립적으로 분리되어 있으며, 화면 상태와 비즈니스 로직은 `ViewModel`에서 관리합니다.  
서버 통신, 인증, HealthKit, 푸시 알림처럼 여러 화면에서 공통으로 사용하는 기능은 `Services` 계층으로 분리했습니다.

```text
BLT/
├── App
│   ├── BrykiApp.swift          # 앱 진입점, NetworkClient 초기 설정
│   ├── AppDelegate.swift       # Firebase, APNs, FCM, 알림 delegate 처리
│   └── ContentView.swift       # Splash/Login/MainTab 등 전역 라우팅
│
├── Features
│   ├── Auth
│   │   ├── ViewModels          # Apple 로그인 및 회원가입 플로우 상태 관리
│   │   └── Views               # 로그인, 약관 동의 화면
│   │
│   ├── Today
│   │   ├── Models              # Today 화면 상태 모델
│   │   ├── ViewModels          # 오늘의 수면/PVT/ROI 데이터 로딩
│   │   └── Views               # Today, 수면 상세 화면
│   │
│   ├── Home
│   │   ├── Models              # 투두, ROI 표시 상태 모델
│   │   ├── Support             # 로컬 투두 저장소
│   │   ├── ViewModels          # Home 화면 상태 관리
│   │   └── Views               # Home, 투두 등록 UI
│   │
│   ├── History
│   │   ├── Models              # 히스토리 월/일 상세 상태 모델
│   │   ├── Services            # 히스토리 API 조회
│   │   ├── ViewModels          # 월별/일별 히스토리 상태 관리
│   │   └── Views               # 히스토리, 날짜 상세, 보고서 미리보기
│   │
│   ├── PVT
│   │   ├── Models              # PVT Trial, Summary, 상세 상태 모델
│   │   ├── Services            # 평가 제출/조회/삭제 API
│   │   ├── Support             # PVT 결과 캐시, 평가 동기화 Store
│   │   ├── ViewModels          # PVT 테스트 및 상세 상태 관리
│   │   └── Views               # PVT 측정, 결과, 상세 화면
│   │
│   ├── MyPage
│   │   ├── Models
│   │   ├── Services            # 사용자 정보/알림 설정 API
│   │   ├── Support             # 로컬 프로필 캐시
│   │   ├── ViewModels
│   │   └── Views
│   │
│   └── Notifications
│       ├── Models
│       ├── Services            # 알림 목록/읽음 처리 API
│       ├── Support             # 앱 전역 알림 Store
│       ├── ViewModels
│       └── Views
│
├── Services
│   ├── Network                 # 공통 URLSession API Client
│   ├── Auth                    # Apple 로그인, JWT 세션, Keychain 저장
│   ├── HealthKit               # 수면/HRV 조회 및 수면 정책 계산
│   └── Push                    # FCM 토큰 등록 및 디바이스 등록
│
├── Models
│   ├── DTOs                    # 서버 Request/Response DTO
│   └── Domain                  # 앱 내부 도메인 상태 모델
│
└── Shared
    └── Extensions              # 공통 SwiftUI/UIKit 확장
```

## 핵심 구현

### HealthKit 연동

HealthKit에서 수면 단계 데이터와 HRV 데이터를 가져와 수면 시간, 수면 효율, 단계별 수면 분포를 분석합니다.

### PVT 테스트

앱 내에서 30초 반응속도 테스트를 진행하고, 평균 반응속도, Lapse, False Start 등의 결과를 기록합니다.

### Brain ROI

수면 데이터와 PVT 결과를 서버에 제출하고, 서버에서 계산된 Brain ROI 점수를 받아 Today, Home, History 화면에 반영합니다.

### 히스토리

날짜별 Brain ROI, 수면 데이터, PVT 기록을 확인할 수 있으며, 개별 PVT 기록 상세 조회와 삭제를 지원합니다.

### 푸시 알림

Firebase Cloud Messaging을 사용해 서버 푸시 알림을 수신하고, 앱 내 알림 목록과 뱃지 상태를 동기화합니다.

## 서버 연동

Bryki는 별도 백엔드 서버와 REST API로 연동됩니다.

앱에서는 인증, 사용자 정보, 알림, Brain ROI 평가, PVT 기록, 히스토리 데이터를 서버 API를 통해 조회하고 저장합니다.

주요 연동 API:

- Apple 로그인 및 회원가입
- 사용자 정보 조회 및 수정
- 알림 설정 및 알림 목록 조회
- FCM 디바이스 등록
- Brain ROI 평가 제출 및 조회
- PVT 기록 조회 및 삭제
- 히스토리 조회
