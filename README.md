# Notipop

일정 시간마다 데스크탑 최상단에 이미지를 띄워 주는 macOS 메뉴바 앱.
출근/퇴근 찍기 알림, 허리 펴기·자세·스트레칭 리마인더 같은 용도로 씁니다.

## 주요 기능

- **메뉴바 상주** — Dock 아이콘 없이 메뉴바 아이콘만. 거기서 전체 on/off, 항목별 on/off, 일시정지.
- **항상 최상단 오버레이** — 어떤 앱·전체화면 위에도, 어느 Space에서도 뜹니다. 포커스는 뺏지 않음.
  카드·테두리 없이 이미지만 표시(투명 PNG는 배경도 투명). 등장/퇴장 시 페이드(300ms)
  + 스케일 60→100%(500ms, ease-out-back) 애니메이션.
- **커스텀 알림 항목** — 설정에서 원하는 만큼 추가. 항목마다:
  - 이미지 / GIF / **Lottie(JSON)** 파일 업로드 — 썸네일 가로 캐러셀 (여러 개 등록 시 랜덤 선택)
  - 표시 시점: **고정 간격**(시간대 시작부터 N분마다 — 출퇴근 찍기용) 또는 **랜덤 간격**(min~max분)
  - 활성 시간대 + 요일 (여러 개 가능, 비우면 매일 24시간)
  - 위치: 랜덤(화면 중앙 60% 범위 안) 또는 고정(중앙/모서리)
  - 크기 슬라이더 + **실시간 크기 미리보기**
  - 사라지는 방식: **클릭 시 닫힘** / **노출 시간 설정**(초) / **한 번 재생**(애니메이션 1회 후 사라짐, 정지 이미지는 3초). 어떤 모드든 클릭하면 즉시 닫힘.
  - 항목 설정 맨 아래에서 **이 항목 삭제**
- **로그인 시 자동 실행** (`SMAppService`, macOS 13+)
- **잠자기 방해 안 함** — 일반 타이머만 사용. 잠자면 멈췄다가 깨어나면 재개(밀린 알림 몰아치기 없음).
- **화면 공유·녹화 감지 시 자동 숨김** (아래 한계 참고)

## 화면 공유·녹화 감지의 한계

macOS에는 "지금 화면이 녹화 중"인지 알려 주는 공식 API가 없습니다. Notipop은 감지 가능한 신호를 조합합니다:

| 감지됨 | 감지 안 됨 |
|---|---|
| **카메라 사용 중** (브라우저 영상통화 포함, 기본 켜짐) | 카메라 끄고 화면만 공유하는 경우 |
| 마이크 사용 중 (옵션, 기본 꺼짐 — 오탐 있음) | |
| 화면 미러링 / AirPlay, 세션 "화면 캡처 중" 힌트 | 목록에 없는 임의의 녹화 도구 |
| 설정에 등록된 회의/녹화 앱 실행 (Zoom·Teams·OBS·Loom 등, 편집 가능) | |

브라우저 웹 회의는 앱으로는 안 잡히지만 대부분 카메라를 켜므로 커버됩니다.
완벽 보장은 아니며, 각 항목을 설정에서 끌 수 있습니다.

## 설치 (받는 사람)

터미널 한 줄 — 다운로드·설치·실행까지. Gatekeeper 경고 없음:

```bash
curl -fsSL https://raw.githubusercontent.com/chammyee/DeskNudge/main/scripts/install.sh | bash
```

또는 [Releases](https://github.com/chammyee/DeskNudge/releases/latest)에서 zip 받아
압축 해제 → `Notipop.app` 을 응용 프로그램으로 드래그 (이 경우 첫 실행 시 우클릭 → 열기).

업데이트도 같은 한 줄 다시 실행하면 됨. 설정·이미지는 유지.
(Apple Silicon 전용 · Apple 공증 없음)

## 빌드 (개발)

요구: macOS 13+, Xcode Command Line Tools (`xcode-select --install`).

```bash
make app          # dist/Notipop.app 생성 (ad-hoc 서명 포함)
make install      # 빌드 후 /Applications 로 복사하고 실행
```

또는 개발용으로 바로 실행 (번들 아님 → 로그인 항목 등록 불가):

```bash
make run
```

## 사용법

1. 앱 실행 → 메뉴바에 아이콘.
2. 아이콘 클릭 → **설정…**.
3. 항목을 고르거나 **항목 추가** → 이미지/애니메이션 업로드, 시간대·간격·크기 지정.
4. 첫 실행 시 **일반 > 로그인 시 자동 실행** 켜기.
   → 시스템 설정 > 일반 > 로그인 항목에서 Notipop 허용이 필요할 수 있습니다.

설정과 업로드한 미디어는 `~/Library/Application Support/Notipop/` 에 저장됩니다.
업데이트(`git pull` + `make install`)해도 이 폴더는 그대로 유지됩니다.

### 배포용 기본값 굽기

신규 설치 시 `Sources/Notipop/Resources/seed/` 의 `DefaultSettings.json` + 이미지가
초기 상태로 쓰입니다. 현재 내 설정을 기본값으로 만들려면:

```bash
cp ~/Library/Application\ Support/Notipop/settings.json Sources/Notipop/Resources/seed/DefaultSettings.json
cp ~/Library/Application\ Support/Notipop/Media/* Sources/Notipop/Resources/seed/
make app
```

(기존 사용자의 설정은 덮어쓰지 않습니다 — seed는 `settings.json` 이 없을 때만 적용.)

## 배포

`make app` 으로 만든 `dist/Notipop.app` 은 ad-hoc 서명만 되어 있어, 받는 사람은 처음 한 번
우클릭 > 열기 (또는 시스템 설정 > 개인정보 보호 및 보안에서 "확인 없이 열기")가 필요합니다.
정식 배포하려면 Developer ID 서명 + 공증(notarization)이 필요합니다.

## 구조

```
Sources/Notipop/
├── main.swift                 진입점 (+ SIGTERM 저장 핸들러)
├── AppDelegate.swift          .accessory 정책, 부팅 시퀀스
├── Models/                    ReminderItem, AppSettings, Store(영속화·미디어 저장)
├── StatusBar/                 메뉴바 아이콘 + 메뉴
├── Scheduling/Scheduler.swift 언제 무엇을 띄울지 결정하는 틱 루프
├── Overlay/                   최상단 패널 + 미디어(이미지/GIF/Lottie) 렌더링
├── Detection/CaptureDetector  카메라·마이크·화면 공유 감지
├── Settings/                  SwiftUI 설정 화면
└── Support/                   LoginItem(SMAppService), DebugLog
```
