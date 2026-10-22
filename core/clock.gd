extends RefCounted
## 세계 시계(D46): 압축한 하루. seconds는 게임 시간(하루 86400초)의 누적값이다.

const DAY := 86400.0
var seconds := 0.0
var scale := 1.0
var sunrise := 6.0 * 3600.0

func _init(day_real_seconds: float, sunrise_hour: float, start_hour: float) -> void:
	scale = DAY / day_real_seconds
	sunrise = sunrise_hour * 3600.0
	seconds = start_hour * 3600.0

func hour() -> float:
	return fposmod(seconds, DAY) / 3600.0

func day() -> int:
	return int(floor(seconds / DAY))

## 현실 시간 dt만큼 진행하고, 그 사이 지난 일출 횟수를 돌려준다.
func advance(real_dt: float) -> int:
	var before := floori((seconds - sunrise) / DAY)
	seconds += real_dt * scale
	return floori((seconds - sunrise) / DAY) - before
