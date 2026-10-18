# S4 — 고정 원통, 1인칭 컨트롤러와 주민 시간표

## 결론: 통과 (헤드리스 검증 범위)

S2의 `spikes/s2_cylinder/cylinder.gd`를 수정 없이 preload하여 반지름
1,000m, Z축 원통의 32개 메시와 실제 삼각형 충돌면을 생성한다.
S1의 `spikes/s1_rotation/motion.gd`도 수정 없이 preload하며,
`Motion.acceleration(position, velocity)`의 원심·코리올리 항을 적용한다.
월드는 고정한다. 내부 바닥의 down은 축에서 바깥쪽이고,
캐릭터 up과 바닥 법선은 축을 향한다. 중력과 법선은 서로 반대 방향이다.

`CharacterBody3D`의 캡슐 중심은 바닥에서 0.9m 안쪽에 놓는다.
매 물리 프레임 up과 기저를 갱신하고 접선 이동 속도를 입력으로 정한 뒤
가속도와 `move_and_slide()`를 적용한다. 바닥 스냅은 0.5m이다.
위치의 반지름을 강제로 맞추거나 순간이동시키지 않고 엔진 충돌로 서고 걷는다.

## 데이터와 길찾기

`residents.json`에 주민 3명의 하루 시간표를 정의했다. `time`은 자정 이후
초이며, 해당 시각에 직전 목적지에서 새 `cell` 목적지로 출발한다.
이동 속도는 3m/s이고 도착 후 다음 출발까지 머문다. 시계는 실제 경과 1초당
시뮬레이션 1초로 흐른다. 하루는 86,400초로 반복한다. 첫 이벤트는 자정이다.
이 스파이크의 데이터는 정렬되어 있고 각 구간에 충분한 이동 시간이 있다.
런타임 데이터 편집·검증·이동 중 일정 교체는 범위 밖이다.

전역 up을 전제로 하는 평면 navmesh 대신, 원통을 펼친 32×9 주기 격자에서
`AStar3D`로 길을 찾는다. 둘레 경계는 연결하고 `(4,4)`는 통행 금지 셀로
제외한다. 경로 보간은 직선 현이 아니라 각도·축 좌표를 보간하여 곡면에
유지한다. 이 방식의 곡면 길찾기는 경계 연결과 우회 테스트를 통과한다.
일반 Godot navmesh 자체가 불가능하다고 단정하지 않는다. 그 방식의 곡면
베이크는 미실행이며 이 결과는 명시적 그래프 대안의 가능성을 확인한 것이다.

주민은 누적 속도 적분 대신 절대 시각과 캐시된 경로 길이로 위치를 계산한다.
따라서 화면 밖에서도 같은 시각에는 같은 위치이며, 다시 표시할 때 별도
따라잡기가 없다. 표시는 단순 캡슐이다. 막힌 셀은 길찾기 규칙이며 실제
벽 충돌체를 뜻하지 않는다. 주민 간 동적 회피·물리 보행 애니메이션은 구현하지
않았다. 문·건물 추가 시 통행 그래프를 실제 장애물과 일치시키는 작업이 필요하다.

## 실행

저장소 루트에서 Godot 4.6.3으로 실행한다. 프로젝트 기본 장면은 바꾸지 않았다.

```sh
godot --path . res://spikes/s4_schedule/main.tscn
```

입력 인터페이스는 장면 루트의 `set_input(move: Vector2, look: Vector2)`이다.
move의 x는 좌우, y는 전후, look은 프레임당 yaw/pitch 라디안 변화량이다.
move는 다음 입력까지 유지하고 look은 물리 프레임에 소비한다.
카메라는 캐릭터의 국소 up을 따른다. 자동 키보드·마우스 바인딩이나 터치 UI는
포함하지 않는다. 디버거의 원격 호출 또는 외부 입력 어댑터로 값을 공급한다.

```sh
XDG_DATA_HOME=/tmp/s4-data XDG_CACHE_HOME=/tmp/s4-cache XDG_CONFIG_HOME=/tmp/s4-config godot --headless --fixed-fps 60 --path . --script tests/s4/run.gd
XDG_DATA_HOME=/tmp/s4-data XDG_CACHE_HOME=/tmp/s4-cache XDG_CONFIG_HOME=/tmp/s4-config godot --headless --path . res://spikes/s4_schedule/main.tscn --quit-after 180
```

테스트는 각 주민의 출발·도착·날짜 반복, 이동 중 기대 위치, 둘레 이음새,
우회, 곡면 보간, 화면 밖/안 위치 일치를 확인한다. 실제 메시 충돌면에서
5초 정지, 80m/s 정방향 및 6m/s 역방향 각각 360° 보행, 멈춘 뒤 정지를 검사한다.
허용치는 반지름 편차 3cm, 바닥 법선과 inward 방향 내적 >0.999이며,
보행 중 접촉 손실은 한 프레임도 허용하지 않는다.

## 미실행

- 화면에서의 1인칭 시점·회전 체감·주민 색/가시성: 디스플레이 수동 확인을
  하지 않았다. 헤드리스 장면 로드는 시각 품질을 검증하지 않는다.
- GPU 성능·실기기 프레임 시간: 헤드리스 더미 렌더러로 측정할 수 없다.
- 기본 navmesh의 전 원통 베이크: 주기 격자 대안으로 구현했다.

## 실제 실행 결과 (2026-10-18, Codex)

엔진: `4.6.3.stable.official.7d41c59c4`, 60Hz 물리, 위 명령 두 개 모두 종료 코드 0.

```text
orbit speed=80.0 frames=4717 angle=6.283969 lost_contact=0 max_gap=0.009546 normal_dot=0.999557
orbit speed=6.0 frames=62421 angle=6.283244 lost_contact=0 max_gap=0.007776 normal_dot=0.999453
S4: 44 passed, 0 failed
```

장면 180프레임 smoke 출력:

```text
Godot Engine v4.6.3.stable.official.7d41c59c4 - https://godotengine.org
```
