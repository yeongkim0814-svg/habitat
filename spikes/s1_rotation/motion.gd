extends RefCounted
## Constant angular velocity about +Z; no external force in inertial space.
const R := 1000.0
const G := 9.81
const OMEGA := sqrt(G / R)
const START := Vector3(0, -998.0, 0)
const THROW := Vector3(12, 20, 3)

static func spin(v: Vector3) -> Vector3:
	return Vector3(-OMEGA * v.y, OMEGA * v.x, 0)

static func inertial(t: float) -> Vector3:
	return START + (THROW + spin(START)) * t

static func rotating_position(t: float) -> Vector3:
	return inertial(t).rotated(Vector3.BACK, -OMEGA * t)

static func acceleration(p: Vector3, v: Vector3, coriolis := true) -> Vector3:
	return -spin(spin(p)) - (2.0 * spin(v) if coriolis else Vector3.ZERO)

static func step(p: Vector3, v: Vector3, dt: float, coriolis := true) -> Array[Vector3]:
	# RK4 integrates position and velocity in the rotating frame.
	var a1 := acceleration(p, v, coriolis)
	var v2 := v + a1 * dt * 0.5
	var a2 := acceleration(p + v * dt * 0.5, v2, coriolis)
	var v3 := v + a2 * dt * 0.5
	var a3 := acceleration(p + v2 * dt * 0.5, v3, coriolis)
	var v4 := v + a3 * dt
	var a4 := acceleration(p + v3 * dt, v4, coriolis)
	return [p + (v + 2.0 * v2 + 2.0 * v3 + v4) * dt / 6.0, v + (a1 + 2.0 * a2 + 2.0 * a3 + a4) * dt / 6.0]
