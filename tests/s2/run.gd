extends SceneTree
const Cylinder = preload("res://spikes/s2_cylinder/cylinder.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	print("R(m) | global_max(m) | shifted_max(m) | mesh_sagitta(m)")
	for radius in [250.0, 500.0, 1000.0]:
		var modules: Array[ArrayMesh] = []
		for i in range(Cylinder.N):
			modules.append(Cylinder.segment(radius, i))
		check(modules.size() == Cylinder.N, "module count")
		for i in range(Cylinder.N):
			var arrays := modules[i].surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var next: PackedVector3Array = modules[(i + 1) % Cylinder.N].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			check(vertices.size() == 2 * (Cylinder.STEPS + 1), "vertex count")
			check(vertices[-2] == next[0] and vertices[-1] == next[1], "closed seam")
			for j in range(vertices.size()):
				check(normals[j].dot(Cylinder.down(vertices[j])) < -0.99999, "inward vertex normal")
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var a := vertices[indices[0]]
			var b := vertices[indices[1]]
			var c := vertices[indices[2]]
			check(-(b - a).cross(c - a).normalized().dot(Cylinder.down(a)) < -0.99, "clockwise inward face")
		for i in range(1001):
			var theta := TAU * (i + 0.123) / 1001.0
			var p := Cylinder.point(radius, theta, 73.0)
			check(Cylinder.down(p).dot(Vector3(cos(theta), sin(theta), 0)) > 0.99999, "arbitrary radial down")
		var result := Cylinder.measure(radius)
		print("%.0f | %.9f | %.9f | %.9f" % [radius, result.global, result.shifted, result.sagitta])
		check(result.global + result.sagitta < 0.001, "global surface error < 1mm")
		check(result.shifted + result.sagitta < 0.001, "shifted surface error < 1mm")
	print("PASS: module counts, closed seams, inward normals/winding, radial down, precision < 1mm" if failures == 0 else "FAIL: %d checks" % failures)
	quit(0 if failures == 0 else 1)
