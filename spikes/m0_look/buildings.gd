extends RefCounted
## M0 street buildings composed from unit boxes (one MultiMesh, D19). Four archetypes plus roof structures.
## Each box carries its own storey height, bay width, window width and a door flag in INSTANCE_CUSTOM,
## so the FLAT wall shader lays windows out per box. Boxes sit beside the street: x grows away from it.
const NEAR := 16.0
const TINTS: Array[Color] = [Color(1.0, 0.96, 0.9), Color(0.9, 0.95, 1.0), Color(1.0, 0.88, 0.82), Color(0.88, 0.96, 0.9)]
const STOREYS: Array[float] = [3.0, 3.2, 3.6]

static func part(c: Dictionary, x0: float, w: float, y0: float, h: float, z: float, d: float, doors: bool) -> Dictionary:
	var side: float = c.side
	return {
		"xf": Transform3D(Basis.from_scale(Vector3(w, h, d)), Vector3(side * (NEAR + x0 + w * 0.5), y0 + h * 0.5, z)),
		"color": c.tint,
		"custom": Color(c.storey, c.bay, c.win, 1.0 if doors else 0.0),
	}

static func roof_box(c: Dictionary, rng: RandomNumberGenerator, x0: float, w: float, top: float, zc: float, d: float) -> Dictionary:
	# Machine room or stair head: lower than one storey, so the wall shader draws no windows on it.
	var rw := rng.randf_range(2.5, 4.0)
	var rd := rng.randf_range(2.5, 4.0)
	var p := part(c, x0 + rng.randf_range(0.5, maxf(0.6, w - rw - 0.5)), rw, top, 2.4, zc + rng.randf_range(-d * 0.25, d * 0.25), rd, false)
	p.color = Color(c.tint).darkened(0.18)
	p.custom = Color(0, 0, 0, 0)
	return p

static func block(c: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var h: float = c.floors * c.storey
	var out: Array[Dictionary] = [part(c, 0.0, c.w, 0.0, h, c.zc, c.d, true)]
	if rng.randf() < 0.7:
		out.append(roof_box(c, rng, 0.0, c.w, h, c.zc, c.d))
	return out

static func podium_tower(c: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var ph: float = 2.0 * c.storey
	var th: float = (c.floors + 1) * c.storey
	return [
		part(c, 0.0, c.w, 0.0, ph, c.zc, c.d, true),
		part(c, 2.0, c.w - 4.0, ph, th, c.zc, c.d - 4.0, false),
		roof_box(c, rng, 2.0, c.w - 4.0, ph + th, c.zc, c.d - 4.0),
	]

static func l_shape(c: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var d1: float = c.d * 0.55
	var d2: float = c.d - d1
	var z1: float = c.z0 + d1 * 0.5
	var z2: float = c.z0 + d1 + d2 * 0.5
	return [
		part(c, 0.0, c.w, 0.0, c.floors * c.storey, z1, d1, true),
		part(c, 0.0, c.w * 0.55, 0.0, maxf(2.0, c.floors - 1.0) * c.storey, z2, d2, true),
		roof_box(c, rng, 0.0, c.w, c.floors * c.storey, z1, d1),
	]

static func stepped(c: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	# Each tier steps back from the street side and loses a storey.
	var out: Array[Dictionary] = []
	var y := 0.0
	for i in range(3):
		var f := maxf(1.0, c.floors - i)
		out.append(part(c, i * 2.5, c.w - i * 2.5, y, f * c.storey, c.zc, c.d - i * 2.0, i == 0))
		y += f * c.storey
	return out

static func lot(rng: RandomNumberGenerator, side: float, z0: float, d: float) -> Array[Dictionary]:
	var bay := rng.randf_range(2.6, 3.8)
	var c := {
		"side": side, "z0": z0, "d": d, "zc": z0 + d * 0.5,
		"w": rng.randf_range(10.0, 16.0), "floors": float(rng.randi_range(3, 6)),
		"tint": TINTS[rng.randi() % TINTS.size()].darkened(rng.randf_range(0.0, 0.22)),
		"storey": STOREYS[rng.randi() % STOREYS.size()], "bay": bay, "win": bay * rng.randf_range(0.42, 0.55),
	}
	match rng.randi() % 4:
		0: return block(c, rng)
		1: return podium_tower(c, rng)
		2: return l_shape(c, rng)
		_: return stepped(c, rng)
