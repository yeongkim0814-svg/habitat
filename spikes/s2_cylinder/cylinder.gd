extends RefCounted
## Cylinder axis is Z. GDScript scalar floats retain the double precision
## reference; Vector3 / mesh storage use the engine's real_t precision.
const R := 1000.0
const L := 200.0
const N := 32
const STEPS := 256

static func point(radius: float, angle: float, z: float) -> Vector3:
	return Vector3(radius * cos(angle), radius * sin(angle), z)

static func down(position: Vector3) -> Vector3:
	return Vector3(position.x, position.y, 0.0).normalized()

static func segment(radius: float, index: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for j in range(STEPS + 1):
		# Shared integer index, including the closing seam, avoids accumulated angles.
		var k := (index * STEPS + j) % (N * STEPS)
		var angle := TAU * k / (N * STEPS)
		for z in [-L / 2.0, L / 2.0]:
			var p := point(radius, angle, z)
			vertices.append(p)
			normals.append(-down(p))
		if j < STEPS:
			var a := j * 2
			# Godot uses clockwise front faces, facing the cylinder interior.
			indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func measure(radius: float) -> Dictionary:
	var global_error := 0.0
	var local_error := 0.0
	# Deterministic non-vertex samples around the full circumference and length.
	for i in range(10001):
		var angle := TAU * (i + 0.371) / 10001.0
		var z := L * (float(i) / 10000.0 - 0.5)
		var x := radius * cos(angle)
		var y := radius * sin(angle)
		var world := Vector3(x, y, z)
		global_error = maxf(global_error, sqrt(pow(float(world.x) - x, 2) + pow(float(world.y) - y, 2) + pow(float(world.z) - z, 2)))
		# Shift origin to the nearest module center using double scalar anchors.
		# Reconstruct in doubles: converting back to global Vector3 loses the benefit.
		var anchor_angle := floorf(angle / TAU * N) * TAU / N + PI / N
		var ax := radius * cos(anchor_angle)
		var ay := radius * sin(anchor_angle)
		var local := Vector3(x - ax, y - ay, z)
		local_error = maxf(local_error, sqrt(pow(ax + float(local.x) - x, 2) + pow(ay + float(local.y) - y, 2) + pow(float(local.z) - z, 2)))
	var sagitta := radius * (1.0 - cos(PI / (N * STEPS)))
	return {"global": global_error, "shifted": local_error, "sagitta": sagitta}
