extends RefCounted
## 주민 시간표와 마을 배치(D96). 위치는 바닥 좌표 (s, z) m: s는 둘레 방향, z는 축 방향.
## 주민은 시각마다 목적지(장소의 spot)로 걸어간다. 절대 시각으로 계산하므로 화면 밖에서도
## 같은 시각에는 같은 위치다(S4 방식). 길은 직선이다(건물을 피하지 않음).

const DAY := 86400.0

static func spot(layout: Dictionary, place: String) -> Vector2:
	var p: Array = layout["places"][place]["spot"]
	return Vector2(p[0], p[1])

## seconds는 게임 시각, scale은 게임 초 / 현실 초(Clock.scale). 걷는 속도는 현실 기준.
static func position(layout: Dictionary, resident: Dictionary, seconds: float, scale: float) -> Vector2:
	var events: Array = resident["schedule"]
	var t := fposmod(seconds, DAY)
	var current := events.size() - 1
	for i in events.size():
		if t >= float(events[i]["hour"]) * 3600.0:
			current = i
	var from := spot(layout, events[current - 1]["place"])
	var to := spot(layout, events[current]["place"])
	var elapsed := fposmod(t - float(events[current]["hour"]) * 3600.0, DAY)
	var travel := from.distance_to(to) / float(layout["walk_speed"]) * scale
	return to if elapsed >= travel else from.lerp(to, elapsed / travel)

static func validate(data: Dictionary) -> Array:
	var errors := []
	var places: Dictionary = data["layout"]["places"]
	for id in data["residents"]:
		var events: Array = data["residents"][id]["schedule"]
		for i in events.size():
			if not places.has(events[i]["place"]):
				errors.append("%s: 없는 장소 %s" % [id, events[i]["place"]])
			if i > 0 and float(events[i]["hour"]) <= float(events[i - 1]["hour"]):
				errors.append("%s: 시간표가 시각 순서가 아님" % id)
	return errors
