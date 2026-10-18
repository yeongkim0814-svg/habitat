extends RefCounted
const Surface = preload("res://spikes/s4_schedule/surface.gd")
const DAY := 86400.0
const SPEED := 3.0
var residents: Array = []
var routes: Dictionary = {}

func _init() -> void:
	residents = JSON.parse_string(FileAccess.get_file_as_string("res://spikes/s4_schedule/residents.json"))

func cell(event: Dictionary) -> Vector2i:
	return Vector2i(int(event["cell"][0]), int(event["cell"][1]))

func position_at(index: int, seconds: float) -> Vector3:
	var events: Array = residents[index]["events"]
	var t := fposmod(seconds, DAY)
	var current := events.size() - 1
	for i in events.size():
		if t >= float(events[i]["time"]):
			current = i
	var previous := posmod(current - 1, events.size())
	var elapsed := fposmod(t - float(events[current]["time"]), DAY)
	var key := Vector2i(index, current)
	if not routes.has(key):
		routes[key] = Surface.route(cell(events[previous]), cell(events[current]))
	var path: PackedVector3Array = routes[key]
	var travel := Surface.length(path) / SPEED
	return Surface.sample(path, 1.0 if travel == 0.0 else elapsed / travel)
