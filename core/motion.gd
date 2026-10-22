extends RefCounted
## 회전계 가속도(D17): 월드는 고정하고 원심 + 코리올리 가속도를 가한다. spikes/s1_rotation에서 옮김.
const G := 9.81
const OMEGA := sqrt(G / 1000.0)

static func spin(v: Vector3) -> Vector3:
	return Vector3(-OMEGA * v.y, OMEGA * v.x, 0)

static func acceleration(p: Vector3, v: Vector3) -> Vector3:
	return -spin(spin(p)) - 2.0 * spin(v)
