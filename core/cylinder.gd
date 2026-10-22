extends RefCounted
## 원통 좌표(D2, D17). 축은 Z, 바닥은 반지름 R의 안쪽 면. spikes/s2_cylinder에서 옮김.
const R := 1000.0
const L := 200.0
const N := 32
const STEPS := 256
## 마을 기준선의 각도. 이 각도에서 바닥의 위(up)가 +Y다.
const BASE := -PI / 2.0

static func point(radius: float, angle: float, z: float) -> Vector3:
	return Vector3(radius * cos(angle), radius * sin(angle), z)

static func down(position: Vector3) -> Vector3:
	return Vector3(position.x, position.y, 0.0).normalized()

## 바닥 위 지점: s는 기준선에서 둘레 방향 거리(m), z는 축 방향 거리(m), height는 바닥에서 높이.
static func surface(s: float, z: float, height := 0.0) -> Vector3:
	return point(R - height, BASE + s / R, z)

## 바닥에 선 물체의 기저: up은 축 쪽, -Z(앞)는 원통 축 방향.
static func upright(position: Vector3) -> Basis:
	var up := -down(position)
	return Basis(Vector3.BACK.cross(up), up, Vector3.FORWARD).orthonormalized()

static func segment(radius: float, index: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for j in range(STEPS + 1):
		var k := (index * STEPS + j) % (N * STEPS)
		var angle := TAU * k / (N * STEPS)
		for z in [-L / 2.0, L / 2.0]:
			var p := point(radius, angle, z)
			vertices.append(p)
			normals.append(-down(p))
		if j < STEPS:
			var a := j * 2
			indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
