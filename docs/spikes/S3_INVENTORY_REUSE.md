# S3 — 이전 격자 인벤토리 재사용 판정

조사·실행일: 2026-10-18 (UTC) · 작성: Codex · Issue: [#3](https://github.com/yeongkim0814-svg/habitat/issues/3)

## 판정: 부분 재사용

**격자·스택·원자적 이동·수색 로직과 회귀 테스트는 가져오고, 무기/탄창 결합과 게임 정책은 분리한다. 화면은 habitat에 맞게 새로 구성한다.** 이번 Issue는 판정 문서만 작성하며 코드나 에셋을 habitat으로 복사하지 않는다.

Godot **4.6.3.stable.official.7d41c59c4**, 헤드리스에서 기존 테스트 **12개 파일, 300개 통과 / 0개 실패**를 관측했다. 다만 GUT 로더에서 파싱 오류 2건이 출력되어, 이 결과를 오류 없는 전체 프로젝트 호환성으로 해석하면 안 된다. 실행 범위와 오류는 아래에 구분했다.

- 그대로 재사용하지 않는 이유: `ItemInstance`가 무기 조립·탄창 클래스를 직접 보유하고, 저장 형식과 장비 슬롯도 슈터 규칙에 묶여 있다.
- 전면 재작성하지 않는 이유: 점유맵·회전·스택·실패 시 상태 보존·숨겨진 아이템 접근 차단을 이미 구현했고, 해당 경로를 실제 테스트로 확인했다. `GameAuthority`는 `RefCounted`이며 인벤토리 명령을 실행하기 위해 사격·AI·씬 트리를 필요로 하지 않는다.
- 권장 경계: 범용 인벤토리 상태/명령/결과 + 선택적 수색 모듈 + habitat의 장비·레이드 정책. 무기 모딩과 재장전은 인벤토리 코어 밖의 선택적 확장으로 둔다.

## 대상·출처·변경 범위

| 항목 | 확인 내용 |
|---|---|
| 원본 접근 | GitHub 연결 도구로 `yeongkim0814-svg/extraction-shooter-` 접근 성공. 원본에는 쓰기 API·푸시를 실행하지 않았다. |
| 고정 원본 | 기본 브랜치 `ccr-f8990bc6-qr0dbr`, 커밋 [`4c88da9887bde38944281d4bc82e939c4b21c033`](https://github.com/yeongkim0814-svg/extraction-shooter-/commit/4c88da9887bde38944281d4bc82e939c4b21c033). 기존 감사와 같은 커밋이다. |
| habitat 기준 | `main`의 `f785ba78a63356c04e63e7d912e5729e1fe8ea20` 파일 트리에서 시작. |
| 코드 출처 선행 조건 | [소유자 댓글](https://github.com/yeongkim0814-svg/habitat/issues/3#issuecomment-6250318961): Claude Code 작성, 외부 코드 복사는 보고되지 않음. 사용자 확인 범위의 프로젝트 코드를 평가했다. 모든 이력·기여자에 대한 별도 출처 감사를 했다는 뜻은 아니다. |
| 서드파티 테스트 도구 | `addons/gut`는 별도 외부 코드이며 동봉 버전 9.7.1. [`LICENSE.md`](https://github.com/yeongkim0814-svg/extraction-shooter-/blob/4c88da9887bde38944281d4bc82e939c4b21c033/addons/gut/LICENSE.md)는 MIT, Tom “Butch” Wesley 저작권 고지 포함. 추후 도구 복사 시 해당 고지를 보존한다. |
| 이미지·기타 에셋 | 출처 미상 `.webp`는 확보·테스트·재사용 대상에서 제외. 프로젝트 에셋은 habitat에 커밋하지 않았다. 테스트 실행용 GUT 동봉 폰트·아이콘만 임시 디렉터리에 확보했다. |
| 허용 변경 | `docs/spikes/S3_INVENTORY_REUSE.md` 한 파일. 원본 코드 수정·인벤토리 구현 이식은 후속 Issue 범위다. |

일반 `git clone`은 아래 프록시 오류로 실패했다. 저장소 자체의 접근 실패가 아니라 실행 환경의 Git 전송 실패이며, 연결 도구의 파일 조회로 대체했다.

```text
$ git clone https://github.com/yeongkim0814-svg/habitat.git /workspace/habitat
Cloning into '/workspace/habitat'...
fatal: unable to access 'https://github.com/yeongkim0814-svg/habitat.git/': Failed to connect to proxy port 8080 after 0 ms: Could not connect to server
```

연결 도구로 커밋을 고정해 `scripts/core/`, `scripts/ui/inventory/`, `tests/unit/`, GUT, 프로젝트 설정과 관련 문서를 `/tmp/inventory-source`에 구성했다. 테스트 대상과 의존 코드의 내용을 바꾸지 않았고 엔진 버전 설정도 바꾸지 않았다. 확보 파일 269개의 Git blob SHA를 원격 트리와 대조하여 불일치 0개를 확인했다. Godot가 새로 생성한 `.uid`, `.import`, `.godot` 캐시는 비교 대상이 아니다. 로컬 habitat은 원격 기준 파일 15개가 일치하는 스냅샷에서 작업했으며, 원격 이력은 GitHub API로 게시한다.

## 코드별 재사용 경계와 결합 해소 비용

아래 경로·행은 모두 위 고정 원본 커밋 기준이다. 비용은 구현 실측이 아닌 **GDScript 개발자 1명의 엔지니어링 작업일 추정**이다. 기존 슈터 저장 파일의 호환 이관, 멀티플레이, 임의 깊이의 컨테이너 중첩은 요구하지 않는다고 가정한다.

| 대상 | 관측 근거 | 후속 처리 | 추정 |
|---|---|---|---|
| 격자 알고리즘 | `scripts/core/inventory/item_grid.gd` 204줄. `can_place`(54행), `move`(79행), 자동/근접 배치·병합·분할·`is_consistent` 보유. `ItemInstance`를 통해 간접적으로 무기 타입에 연결된다. | 알고리즘 보존. 경계 검사·회전·점유맵·롤백 테스트 유지. 아이템 크기 인터페이스만 무기와 분리한다. | 아래 아이템 분리 작업에 포함 |
| 아이템·정의 DB | `scripts/core/items/item_instance.gd:20–38`: `WeaponAssembly`, `Magazine`, `size_for()` → `weapon.compute_size()`. `scripts/core/content/content_database.gd:6–8`: 아이템/부품/탄종 DB가 한 클래스에 있다. `item_def.gd:6`의 카테고리도 슈터 전용이며 `icon`은 표시용 필드다. | 무기/탄창을 선택적 확장 데이터·크기 제공자로 이동. 기본 크기/스택/식별자는 유지. 코어 DB는 아이템 조회에 한정하고 이미지 없이 도형/기본 리소스로 표시한다. | 1–2일 |
| 인벤토리 정책·장비 | `inventory.gd` 503줄: `POCKET_COUNT=4`(15행), 스태시 잠금(20행), 중첩 금지(366행 이후), `try_reshape`(269행). `equipment_slots.gd:7–37`의 고정 12슬롯/허용 카테고리. | 루트 그리드·슬롯 허용 규칙을 habitat 설정으로 주입. 스태시 잠금·중첩 금지·수색 접근 규칙을 명시적 정책으로 보존/선택. `try_reshape`의 apply/revert는 범용 크기 변경에 유지할 수 있다. | 2–3일 |
| 명령·권한자 | `commands/` 18개 파일을 확인. `MoveItemCommand`는 `authority.inventory`에 위임하고 `SplitStackCommand`는 성공 시에만 ID 소비. `game_authority.gd:12`의 `ContentDatabase` 타입을 통해 무기 DB가 간접 유입된다. `attach_part_command.gd`, `detach_part_command.gd`, `reload_command.gd` 3개가 무기 전용. | 이동/장착/병합/분할/폐기/외부 컨테이너/수색 명령과 이벤트 전달은 보존. 무기 전용 3개 명령 및 `WEAPON_CHANGED`/`MAGAZINE_CHANGED` 이벤트·오류 코드는 확장으로 분리. 권한자는 아이템 생성·ID·명령 실행만 알게 한다. | 아이템 분리 및 아래 회귀 작업에 포함 |
| 저장·마이그레이션 | `save_serializer.gd` 369줄: 69–94행 무기/탄창 직렬화, 221–234행 복원 분기, 261–350행 부품 트리·탄약 복원. `to_dict`는 외부 월드 컨테이너를 제외하며 FIR/스태시 잠금도 저장한다. `save_migrations.gd`는 현재 버전 1, 실제 버전 간 변환 단계는 없다. | 순수 아이템/컨테이너 저장 형식으로 축소하고 확장별 직렬화 경계를 둔다. 슈터의 기존 enum 숫자·슬롯 키를 새 데이터에 그대로 강제하지 않는다. 월드 컨테이너 저장 여부는 habitat 정책으로 결정. 구형 슈터 세이브 이관은 별도 범위. | 1–2일 |
| 수색·외부 컨테이너 | `search/search_state.gd`, `search_time_calculator.gd`, `Open/Close/SearchContainerCommand`. 시간 진행은 `GameAuthority.tick_searches(delta)`이며 소음을 숫자로 반환하고 AI를 직접 호출하지 않는다. | 수색 공개 순서·중단·이동 차단과 외부 그리드 소유권은 보존. 시간/희귀도/소음 계수는 habitat 데이터로 주입. | 아래 회귀 작업에 포함 |
| 테스트 실행 기반 | 원본은 Godot 4.7 표기. 4.6.3에서는 동봉 GUT 로더에 파싱 오류 2건 발생(아래 참조). | 4.6.3과 호환되는 GUT 버전 고정 또는 도구의 호환 수정, CI에서 파싱 오류까지 실패 처리. 원본 테스트 기대값을 느슨하게 바꾸어 통과시키지 않는다. | 1–2일 |
| 이식 회귀·통합 | 이번 300개는 원본 결합 상태의 테스트. 분리 이후의 코드나 새 UI를 실행한 것이 아니다. | 무기 라이브러리 없이 로드 가능한 코어, 실패 시 상태 보존/ID 미소비, 무기 없는 저장 왕복, 설정 가능한 슬롯, 수색 비공개 아이템 차단, 기본 도형 UI 연결을 검증한다. | 1–2일 |

**코어 분리·통합 합계 6–11일, 불확실성 여유 1–2일을 더해 7–13일**로 추정한다. habitat용 화면 재구성은 별도 **3–5일**로 보며 합계는 **10–18일**이다. 새 UI 입력 방식·화면 요구가 확정되지 않았으므로 화면 추정의 확신도는 낮다. 멀티플레이나 범용 배포 패키지 제작 비용을 이 수치에 포함하지 않는다.

`scripts/ui/inventory/inventory_screen.gd`는 1,074줄이며 19행에서 모딩 씬을 preload하고 슬롯 명칭·배치·입력을 고정한다. 이 화면과 `mod_screen.gd`는 그대로 옮기지 않는다. `drop_resolver.gd`와 `inventory_actions.gd`는 순수 판정 부분을 재사용할 수 있지만 고정 장비 슬롯과 MOD 액션을 떼어야 한다. `container_layout.gd`는 별도로 보존할 후보이며 실제 테스트도 통과했다.

기존 감사의 두 표현을 좁혀 읽어야 한다. 사망 시 소실 처리는 `Inventory` 안이 아니라 **`scripts/core/raid/death_resolver.gd`**에 있어 이 모듈을 이식 대상에서 빼면 된다. 또한 저장 마이그레이션은 **틀만 있고 실제 v1→v2 변환은 아직 없다.** 무게도 `ItemDef.weight` 필드만으로 이동 속도 연동을 제공하지 않는다.

## Godot 4.6.3 헤드리스 실행 증거

### 범위와 준비

- Codex 관리형 클라우드 환경의 `/usr/local/bin/godot` 사용. `godot --version` 출력은 `4.6.3.stable.official.7d41c59c4`였다(기본 캐시 경로에는 `Fontconfig error: No writable cache directories`도 출력). 아래 실행에서는 쓰기 가능한 XDG 경로를 지정했다.
- 기존 감사의 3개 파일 135개를 먼저 실행하고, 인접 저장·명령·UI 판정·모딩 결합 9개 파일 165개를 추가 실행했다. 중복 없는 합계 300개다.
- 전체 슈터 테스트, 실제 게임 씬, UI 입력/외형, 내보내기, 멀티플레이, 분리한 새 코드 검증은 **미실행**이다. 이번은 인벤토리 코어 판정이며 씬·프로젝트 에셋 전체를 확보하지 않았다.
- 원본 `.gutconfig.json`의 전체 테스트 디렉터리 설정은 `-gdir=`로 비우고, `-gtest=`에 파일을 명시했다. 실패한 테스트를 제외한 목록이 아니라 판정에 필요한 인벤토리 경로로 실행 범위를 정한 것이다.

준비 때 실행한 명령(두 번 import: 최초 텍스트 확보 후, GUT 동봉 리소스 확보 후):

```bash
mkdir -p /tmp/inventory-runtime/cache /tmp/inventory-runtime/data /tmp/inventory-runtime/config
XDG_CACHE_HOME=/tmp/inventory-runtime/cache XDG_DATA_HOME=/tmp/inventory-runtime/data XDG_CONFIG_HOME=/tmp/inventory-runtime/config godot --headless --path /tmp/inventory-source --editor --import > /tmp/inventory-results/import.log 2>&1
```

Import는 클래스/리소스 캐시 생성용이며 게임 전체 정상 기동의 증거가 아니다. 원본 설정이 가리키는 미확보 `scenes/dev/dev_menu.tscn`, 프로젝트 폰트 관련 오류, 편집기 TCP listen 실패와 종료 시 ObjectDB 경고가 관측됐다. 아래 테스트 결과와 구분한다.

### 기본 3개 파일

실행 명령:

```bash
XDG_CACHE_HOME=/tmp/inventory-runtime/cache XDG_DATA_HOME=/tmp/inventory-runtime/data XDG_CONFIG_HOME=/tmp/inventory-runtime/config godot --headless --path /tmp/inventory-source -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_item_grid.gd,res://tests/unit/test_inventory.gd,res://tests/unit/test_search.gd -gdir= -gexit > /tmp/inventory-results/baseline.log 2>&1
result=$?; tail -55 /tmp/inventory-results/baseline.log; printf '\nEXIT_CODE=%s\n' "$result"
```

실제 출력 발췌(색상 이스케이프만 제거):

```text
Godot version:  4.6.3
GUT version:  9.7.1
res://tests/unit/test_item_grid.gd
28/28 passed.
res://tests/unit/test_inventory.gd
84/84 passed.
res://tests/unit/test_search.gd
23/23 passed.
Totals
------
Scripts               3
Tests               135
Passing Tests       135
Asserts            3147
Time              2.291s
---- All tests passed! ----
EXIT_CODE=0
```

### 추가 9개 파일

실행 명령:

```bash
XDG_CACHE_HOME=/tmp/inventory-runtime/cache XDG_DATA_HOME=/tmp/inventory-runtime/data XDG_CONFIG_HOME=/tmp/inventory-runtime/config godot --headless --path /tmp/inventory-source -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_authority.gd,res://tests/unit/test_save.gd,res://tests/unit/test_inventory_smoke.gd,res://tests/unit/test_inventory_actions.gd,res://tests/unit/test_drop_resolver.gd,res://tests/unit/test_container_layout.gd,res://tests/unit/test_world_containers.gd,res://tests/unit/test_loot.gd,res://tests/unit/test_modding.gd -gdir= -gexit > /tmp/inventory-results/extended.log 2>&1
result=$?; tail -28 /tmp/inventory-results/extended.log; printf '\nEXIT_CODE=%s\n' "$result"
```

실제 출력 발췌(색상 이스케이프만 제거):

```text
Godot version:  4.6.3
GUT version:  9.7.1
res://tests/unit/test_authority.gd
16/16 passed.
res://tests/unit/test_save.gd
54/54 passed.
res://tests/unit/test_inventory_smoke.gd
1/1 passed.
res://tests/unit/test_inventory_actions.gd
8/8 passed.
res://tests/unit/test_drop_resolver.gd
44/44 passed.
res://tests/unit/test_container_layout.gd
8/8 passed.
res://tests/unit/test_world_containers.gd
16/16 passed.
res://tests/unit/test_loot.gd
10/10 passed.
res://tests/unit/test_modding.gd
8/8 passed.
Totals
------
Scripts               9
Tests               165
Passing Tests       165
Asserts            3432
Time              0.625s
---- All tests passed! ----
EXIT_CODE=0
```

집계: **실행 300 / 통과 300 / 실패 0 / 미완료 0, assertion 6,579**. 함수 정의 개수가 아니라 위 GUT 실행 결과에 근거한다.

### 통과 수와 별도로 기록할 오류

두 실행 모두 시작 때 다음 메시지가 출력됐다(공통 실제 출력 발췌).

```text
ERROR: Resource file not found: res://assets/fonts/NotoSansKR.ttf (expected type: unknown)
ERROR: Error loading custom project font 'res://assets/fonts/NotoSansKR.ttf'
SCRIPT ERROR: Parse Error: Identifier "AccessibilityServer" not declared in the current scope.
          at: GDScript::reload (res://addons/gut/godot_singletons.gd:5)
ERROR: Failed to load script "res://addons/gut/godot_singletons.gd" with error "Parse error".
SCRIPT ERROR: Parse Error: Cannot return value of type "null" because the function return type is "StringName".
          at: GDScript::reload (res://addons/gut/stub_params.gd:16)
ERROR: Failed to load script "res://addons/gut/stub_params.gd" with error "Parse error".
```

- GUT 로더의 두 파일이 4.6.3에서 파싱에 실패했다. 선택한 테스트 스크립트 12개는 모두 로드·실행·통과했고 두 프로세스의 종료 코드는 0이었다. 따라서 테스트 실패 0개와 엔진/도구 오류가 없다는 주장은 구분해야 한다. 테스트 도구의 다른 경로까지 호환된다고 볼 수 없으며 이식 전에 해결해야 한다.
- 폰트 누락과 `invalid UID ... using text path instead` 경고는 부분 스냅샷/생성 캐시에서 발생했다. 코드 대체 스텁·테스트 수정·`.webp` 사용으로 우회하지 않았다.
- 오류를 포함한 전체 로그는 실행 환경의 `/tmp/inventory-results/{baseline,extended}.log`에 있다. 환경이 일시적이므로 영구 기록은 이 문서와 PR 본문의 명령·실제 출력 발췌로 남긴다.

## 후속 판단 기준과 미해결

1. 수정 허용 경로를 정한 후속 Issue에서 `ItemDef`/`ItemInstance`/`ItemGrid`가 무기 클래스 없이 로드되는 최소 코어를 추출한다. 이번에는 구현하지 않는다.
2. 같은 4.6.3에서 GUT 호환성을 정리하고 추출 전후 회귀 및 무기 없는 저장 왕복을 확인한다. 게임 전용 기대값은 변경 이유를 명시한 정책 테스트로 분리한다.
3. 슬롯·루트 그리드·저장 경계 분리가 위 추정을 초과하거나 분리 후 롤백·ID/소유권 불변식을 유지하기 어렵다면, 격자 알고리즘과 테스트만 재사용하고 `Inventory`/저장 계층은 재작성하는 쪽으로 판정을 좁힌다.
4. 새 UI의 화면 요구·입력 장치, 무게 제한, 구형 저장 이관, 임의 깊이의 컨테이너 중첩은 이번에 확정하지 않았다. 필요해지면 추정을 갱신한다. 게임 전체의 4.6.3 호환성이나 제품화 완료를 판정한 것은 아니다.

## 참고

- [Issue #3 및 소유자 출처 확인](https://github.com/yeongkim0814-svg/habitat/issues/3)
- [기존 PROTOTYPE_AUDIT.md](https://github.com/yeongkim0814-svg/My-1st-Ai-office/blob/main/projects/inventory/research/PROTOTYPE_AUDIT.md) — 미실행 상태의 135개 함수 집계를 이번 실행으로 보완했다.
- [고정 원본 core](https://github.com/yeongkim0814-svg/extraction-shooter-/tree/4c88da9887bde38944281d4bc82e939c4b21c033/scripts/core), [tests/unit](https://github.com/yeongkim0814-svg/extraction-shooter-/tree/4c88da9887bde38944281d4bc82e939c4b21c033/tests/unit), [UI](https://github.com/yeongkim0814-svg/extraction-shooter-/tree/4c88da9887bde38944281d4bc82e939c4b21c033/scripts/ui/inventory)
