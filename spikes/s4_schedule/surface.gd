extends RefCounted
const Cylinder = preload("res://spikes/s2_cylinder/cylinder.gd")
const COLS := 32
const ROWS := 9
const DZ := 10.0
# Unwrapped periodic graph. One closed cell forces a detour across rows.
const BLOCKED := Vector2i(4, 4)

static func point(cell: Vector2i, height := 0.0) -> Vector3:
	return Cylinder.point(Cylinder.R - height, TAU * cell.x / COLS, (cell.y - 4) * DZ)

static func id(cell: Vector2i) -> int:
	return cell.y * COLS + posmod(cell.x, COLS)

static func route(start: Vector2i, goal: Vector2i) -> PackedVector3Array:
	var graph := AStar3D.new()
	for y in ROWS:
		for x in COLS:
			var c := Vector2i(x, y)
			if c != BLOCKED:
				graph.add_point(id(c), point(c, 0.9))
	for y in ROWS:
		for x in COLS:
			var c := Vector2i(x, y)
			if not graph.has_point(id(c)):
				continue
			for next in [Vector2i(posmod(x + 1, COLS), y), Vector2i(x, y + 1)]:
				if next.y < ROWS and graph.has_point(id(next)):
					graph.connect_points(id(c), id(next))
	if not graph.has_point(id(start)) or not graph.has_point(id(goal)):
		return PackedVector3Array()
	return graph.get_point_path(id(start), id(goal))

static func length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += distance(path[i - 1], path[i])
	return total

static func distance(a: Vector3, b: Vector3) -> float:
	var angle := wrapf(atan2(b.y, b.x) - atan2(a.y, a.x), -PI, PI)
	return Vector2(angle * (Cylinder.R - 0.9), b.z - a.z).length()

static func sample(path: PackedVector3Array, fraction: float) -> Vector3:
	if path.is_empty():
		return Vector3.ZERO
	var remaining := length(path) * clampf(fraction, 0.0, 1.0)
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		var segment_length := distance(a, b)
		if remaining <= segment_length:
			var t := remaining / segment_length
			var angle := atan2(a.y, a.x) + wrapf(atan2(b.y, b.x) - atan2(a.y, a.x), -PI, PI) * t
			return Cylinder.point(Cylinder.R - 0.9, angle, lerpf(a.z, b.z, t))
		remaining -= segment_length
	return path[-1]
