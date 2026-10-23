extends RefCounted
## 이동 단계(D73, D101): 스틱 기울기 → 0 정지, 1 조용히 걷기, 2 걷기, 3 달리기. 속도 단계와 소리 단계가 1:1.
## 경계 근처에서 깜빡이지 않게 여유 구간을 둔다: 올라갈 때는 경계 + h, 내려갈 때는 경계 - h를 넘어야 바뀐다(데드존 제외).

var config: Dictionary
var stage := 0

func _init(controls: Dictionary) -> void:
	config = controls

func update(tilt: float) -> int:
	var edges: Array = [config["deadzone"]] + config["edges"]
	var h: float = config["hysteresis"]
	while stage < edges.size() and tilt >= edges[stage] + (h if stage > 0 else 0.0):
		stage += 1
	while stage > 0 and tilt < edges[stage - 1] - (h if stage > 1 else 0.0):
		stage -= 1
	return stage

func speed() -> float:
	return 0.0 if stage == 0 else float(config["speeds"][stage - 1])

## 데이터 오류 목록(경계가 오름차순인지, 속도가 단계 수만큼인지).
static func validate(controls: Dictionary) -> Array:
	var errors := []
	var edges: Array = [controls["deadzone"]] + controls["edges"]
	for i in edges.size() - 1:
		if edges[i] >= edges[i + 1]:
			errors.append("controls: 경계가 오름차순이 아님 %s" % [edges])
			break
	if controls["speeds"].size() != edges.size():
		errors.append("controls: 속도 %d개, 단계 %d개" % [controls["speeds"].size(), edges.size()])
	return errors
