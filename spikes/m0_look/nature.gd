extends RefCounted
## Nature kit built in code (no asset files): conifer, broadleaf tree, grass tuft. Vertex colors carry a dark-to-light
## gradient (bottom to top) that every look multiplies into its base color; MultiMesh instances scale/rotate them.

static func shade(y01: float) -> Color:
	var v := lerpf(0.7, 1.0, clampf(y01, 0.0, 1.0))
	return Color(v, v, v)

static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, h: float) -> void:
	for p in [a, b, c]:
		st.set_color(shade(p.y / h))
		st.add_vertex(p)

static func cone(st: SurfaceTool, y0: float, height: float, radius: float, seg: int, total: float) -> void:
	var apex := Vector3(0, y0 + height, 0)
	for i in range(seg):
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p0 := Vector3(cos(a0) * radius, y0, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, y0, sin(a1) * radius)
		tri(st, p0, apex, p1, total)

static func conifer() -> ArrayMesh:
	# Three stacked cones on a short trunk; unit height 3.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	cone(st, 0.0, 0.5, 0.12, 5, 3.0)
	cone(st, 0.4, 1.3, 0.85, 8, 3.0)
	cone(st, 1.2, 1.2, 0.65, 8, 3.0)
	cone(st, 1.9, 1.1, 0.42, 8, 3.0)
	st.generate_normals()
	return st.commit()

static func blob(st: SurfaceTool, center: Vector3, radius: float, total: float) -> void:
	var rings := 4
	var seg := 7
	for r in range(rings):
		var t0 := PI * r / rings
		var t1 := PI * (r + 1) / rings
		for i in range(seg):
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var p := func(t: float, a: float) -> Vector3: return center + Vector3(sin(t) * cos(a), cos(t), sin(t) * sin(a)) * radius
			tri(st, p.call(t0, a0), p.call(t0, a1), p.call(t1, a0), total)
			tri(st, p.call(t0, a1), p.call(t1, a1), p.call(t1, a0), total)

static func crown() -> ArrayMesh:
	# Three overlapping blobs around crown_center (0, 2.3, 0); the paint shader rounds their normals.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	blob(st, Vector3(0, 2.3, 0), 1.0, 3.4)
	blob(st, Vector3(0.6, 2.0, 0.2), 0.7, 3.4)
	blob(st, Vector3(-0.5, 2.6, -0.3), 0.75, 3.4)
	st.generate_normals()
	return st.commit()

static func trunk() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	cone(st, 0.0, 2.2, 0.16, 5, 3.4)
	st.generate_normals()
	return st.commit()

static func tuft() -> ArrayMesh:
	# Five bent blades (one triangle each), unit height 1; double-sided in the material.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(5):
		var yaw := TAU * i / 5.0 + 0.3
		var dir := Vector3(cos(yaw), 0, sin(yaw))
		var side := Vector3(-dir.z, 0, dir.x)
		var h := 0.7 + 0.3 * float(i % 3) / 2.0
		var base := dir * 0.05
		var tip := base + dir * 0.18 + Vector3(0, h, 0)
		tri(st, base - side * 0.045, tip, base + side * 0.045, 1.0)
		tri(st, base - side * 0.045, base + side * 0.045, tip, 1.0)
	st.generate_normals()
	return st.commit()
