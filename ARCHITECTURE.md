# ARCHITECTURE

에이전트와 검토자가 코드 전체 대신 먼저 읽는 지도다. 결정 근거는 My-1st-Ai-office의 `projects/habitat/DECISIONS.md`(D17 회전 표현, D19 렌더링, D24 코드 규모)에 있다. **구조를 바꾸는 PR은 이 문서도 같이 고친다.**

## 1. 지금 있는 것 (스파이크, 버릴 수 있음)

| 모듈 | 종류 | 책임 | 의존 |
|---|---|---|---|
| `spikes/s2_cylinder/cylinder.gd` | 순수(RefCounted) | 원통 좌표·구간 메시 생성 (R, 구간 수 상수) | 없음 |
| `spikes/s1_rotation/motion.gd` | 순수 | 회전계 가속도 (원심 + 코리올리, `Motion.acceleration`) | 없음 |
| `spikes/s4_schedule/surface.gd` | 순수 | 원통 표면 격자 길찾기(AStar, 주기 경계) | cylinder |
| `spikes/s4_schedule/schedule.gd` | 순수 | 주민 시간표 | surface |
| `spikes/s4_schedule/controller.gd` | 장면 연결 | 1인칭 CharacterBody3D | cylinder, motion |
| `spikes/s1_rotation/world.gd` | 장면 연결 | S1 측정 장면(MultiMesh, 터치 버튼, FPS) | cylinder, motion |
| `spikes/s2_cylinder/world.gd`, `spikes/s4_schedule/world.gd` | 장면 연결 | 스파이크 장면 | 위 모듈 |
| `spikes/m0_look/looks.gd`, `nature.gd`, `sun.gd` | 순수 | M0 룩(셰이더 문자열·팔레트), 식생 메시, 태양 계산 (`Looks.tuned`/`live`는 조절 패널용 정적 상태) | 없음 |
| `spikes/m0_look/tuning.gd` | 순수 | 룩 조절 값 저장·읽기(JSON, 룩별), 깨진 파일은 조용히 무시 | 없음 |
| `spikes/m0_look/buildings.gd` | 순수 | 거리 건물을 단위 박스 여러 개로 조합(원형 4종, 옥상 구조물), 박스별 층 높이·창 간격·창 폭을 사용자 데이터로 | 없음 |
| `spikes/m0_look/stage.gd` | 장면 연결 | M0 테스트 장면(거리·들판·초원·머리 위, 모두 MultiMesh) | looks, nature |
| `spikes/m0_look/tuning_panel.gd`, `ui_kit.gd` | 장면 연결 | 태블릿 조절 패널(역할별 색, 안개·주변광·태양), 터치 크기 버튼 보조 | looks, tuning |
| `spikes/m0_look/world.gd` | 장면 연결 | M0 장면(룩·시점·구역·시각 버튼, 측정) | 위 모듈, cylinder |
| `core/cylinder.gd` | 순수 | 원통 좌표, 바닥 지점 (s, z), 바닥에 선 물체의 기저, 구간 메시 (spikes/s2에서 옮김) | 없음 |
| `core/motion.gd` | 순수 | 회전계 가속도(원심 + 코리올리, spikes/s1에서 옮김) | 없음 |
| `core/schedule.gd` | 순수 | 주민 시간표 위치(절대 시각, 직선 보행), 장소 spot, 시간표 검사 | `data/layout.json`, `data/residents.json` |
| `core/clock.gd` | 순수 | 세계 시계(D46): 압축한 하루, 지난 일출 횟수 | 없음 |
| `core/game.gd` | 순수 | P1 게임 상태와 명령: 소지품(개수), 돈(계정 잔액), 교환 사용량, 퀘스트 상태·납품·보상(D92~D95), 밭·대체 상자 일출 재충전, 저장·불러오기(JSON, 임시 파일 후 교체) | clock, `data/*.json` |
| `core/gait.gd` | 순수 | 이동 단계(D73, D101): 스틱 기울기 → 정지·조용히 걷기·걷기·달리기, 경계 여유 구간, 단계 속도, 데이터 검사 | `data/controls.json` |
| `core/shop.gd` | 순수 | 상점(D36, D79): 재화 구매·판매, 교환(일일 수량 = 호감도 단계, 일출 갱신) | game의 상태 |
| `game/greybox.gd` (`greybox.tscn`) | 장면 연결 | P1 회색 박스(D96): 원통 바닥, 장소 상자, 주민 캡슐, 밤낮 밝기, 상태 글, 행동·거래 버튼(오른쪽 아래 엄지 자리, D103)·퀘스트 버튼 → core 명령과 ui 화면, 상태 글에 이동 단계. 시작할 때 `user://p1_save.json`을 불러오고, 명령 뒤와 앱이 백그라운드로 가거나 닫힐 때 저장 | core 전부, ui |
| `ui/dialogue.gd` | 터치 UI | 대화 화면(D95): 대사를 한 줄씩, 마지막 줄에 선택 버튼(수락/나중에, 닫기) | kit |
| `ui/journal.gd` | 터치 UI | 퀘스트 화면(D95): `Game.journal()`의 현재/목표 수량, 두 번 눌러 처음부터 | kit, game의 상태 |
| `ui/shop.gd` | 터치 UI | 상점 화면(D36, D79): 사기·팔기·교환 탭 → `core/shop.gd` 명령, 성공하면 저장 콜백 | kit, shop |
| `ui/kit.gd` | 터치 UI | 공통 부품: 큰 글자, 손가락 크기 버튼, 화면 가운데 패널 | 없음 |
| `game/player.gd` | 장면 연결 | 1인칭 CharacterBody3D(회전계 가속도, 엔진 충돌, 속도는 gait 단계) | cylinder, motion, gait |
| `game/touch.gd` | 장면 연결 | 터치 조작(왼쪽 떠다니는 스틱, 오른쪽 드래그 시점: 화면 높이 비율 선형, D101·D102), WASD | 없음 |
| `data/` | 데이터 | 아이템, 주민(시간표), 퀘스트, 대화, 상점, 마을 배치, 세계 설정, 조작 값(JSON). 퀘스트 추가는 이 폴더만 고친다 | 없음 |
| `tests/s1`, `tests/s2`, `tests/s4`, `tests/m0`, `tests/p1` | 테스트 | 헤드리스 검증(`godot --headless --script tests/sN/run.gd`) | 대응 모듈 |

## 2. 목표 구조 (P1부터 적용 중: core/, data/, game/, ui/ 생김)

```
core/        순수 스크립트(RefCounted). 화면·노드 없음. 규칙 계산: 인벤토리, 사망·가방, 소리 전파, 요청 판정, 시간표
data/        JSON. 아이템, 요청, 주민, 생명체. 내용이 늘면 이 폴더가 늘고 코드는 늘지 않는다
game/        장면 연결. 얇게: 입력 → core 명령 호출, core 상태 → 화면 표시
ui/          터치 UI. core를 직접 바꾸지 않고 명령만 보낸다
tests/       core와 data를 헤드리스로 검증. 새 규칙에는 테스트가 먼저 또는 함께
spikes/      스파이크 보관. 새 코드가 의존하지 않는다
```

## 3. 의존 방향 (어기면 구조 변경 PR)

`game`, `ui` → `core` → (없음). `core`는 `game`·`ui`·`Node`를 참조하지 않는다. `data`는 `core`가 읽고, 코드가 내용을 하드코딩하지 않는다. 한 방향이므로 `core` 변경의 영향은 `core`와 그 테스트 안에서 확인된다.

## 4. 읽는 법과 갱신 규칙

- 수정할 때: 이 문서에서 대상 모듈, 그 의존, 그리고 **대상을 쓰는 모듈(역의존)**과 그 테스트를 연다. 역의존은 표의 의존 열과 `grep -rn "대상파일명"`으로 찾고, 공유 모듈(예: `cylinder.gd`)을 바꿀 때는 모든 사용처를 확인한다. 그 밖의 모듈은 열지 않는다.
- 새 모듈·폴더를 만들거나 의존 방향을 바꾸는 PR은 1~3절을 같이 고친다.
- 크기 경고: `bash scripts/check-size.sh` (파일 300줄, 함수 40줄 초과 알림, 임시 기준, 알림용이며 종료 코드 0). 경고가 난 파일은 그 PR과 **별도 PR**로 동작 변경 없이 정리하고 기존 테스트를 그대로 통과시킨다.
- 헤드리스로 검증되지 않는 터치·연출 코드는 에이전트가 임의로 정리하지 않는다.
