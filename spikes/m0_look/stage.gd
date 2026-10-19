extends RefCounted
## M0 test stage on the habitat floor: a safe street (z < 0) and an alien field (z > 0), plus the far side overhead.
## Every repeated element is a MultiMesh (D19). Positions are relative to the floor point returned by `origin()`.
const Looks = preload("res://spikes/m0_look/looks.gd")
const Cylinder = preload("res://spikes/s2_cylinder/cylinder.gd")
const HALF_X := 25.0
const RING_HALF_LENGTH := 2500.0 # look-dev only: the real habitat is long; S2's 200 m ring would show sky past its ends.
const FLOOR_LIFT := 0.45 # floor curves up 0.31 m at x = 25 (R = 1000); the stage ground sits above it.

static func origin() -> Vector3:
	return Vector3(0, -Cylinder.R, 0)

static func multimesh(mesh: Mesh, material: Material, xforms: Array[Transform3D], colors: Array[Color] = []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material
	return node

static func ground(look: String, role: String, z0: float, z1: float, bumpy: bool) -> MeshInstance3D:
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.06
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := 2.0
	var nx := int(2.0 * HALF_X / step)
	var nz := int((z1 - z0) / step)
	for i in range(nx):
		for j in range(nz):
			var q: Array[Vector3] = []
			for d in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var x: float = -HALF_X + (i + d.x) * step
				var z: float = z0 + (j + d.y) * step
				q.append(Vector3(x, 0.2 + absf(noise.get_noise_2d(x, z)) * 1.8 if bumpy else 0.0, z))
			for k in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(q[k])
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = Looks.material(look, role)
	return node

static func street(look: String, rng: RandomNumberGenerator, root: Node3D) -> void:
	root.add_child(ground(look, "street", -95.0, -3.0, false))
	var box := BoxMesh.new()
	var walls: Array[Transform3D] = []
	var wall_colors: Array[Color] = []
	var lamps: Array[Transform3D] = []
	var bulbs: Array[Transform3D] = []
	for row in range(2):
		var side := -1.0 if row == 0 else 1.0
		var z := -92.0
		while z < -8.0:
			var w := rng.randf_range(8.0, 14.0)
			var h := rng.randf_range(6.0, 16.0)
			var d := rng.randf_range(8.0, 12.0)
			walls.append(Transform3D(Basis.from_scale(Vector3(w, h, d)), Vector3(side * (16.0 + w * 0.5), h * 0.5, z + d * 0.5)))
			wall_colors.append(Color.WHITE.darkened(rng.randf_range(0.0, 0.25)))
			lamps.append(Transform3D(Basis.from_scale(Vector3(0.12, 4.0, 0.12)), Vector3(side * 6.0, 2.0, z + 3.0)))
			bulbs.append(Transform3D(Basis.from_scale(Vector3(0.5, 0.5, 0.5)), Vector3(side * 6.0, 4.1, z + 3.0)))
			z += d + rng.randf_range(1.0, 3.0)
	root.add_child(multimesh(box, Looks.material(look, "wall", true), walls, wall_colors))
	root.add_child(multimesh(box, Looks.material(look, "lamp"), lamps))
	var sphere := SphereMesh.new()
	sphere.radial_segments = 6
	sphere.rings = 3
	root.add_child(multimesh(sphere, Looks.material(look, "lamp"), bulbs))

static func field(look: String, rng: RandomNumberGenerator, root: Node3D) -> void:
	root.add_child(ground(look, "soil", 3.0, 95.0, true))
	rocks(look, rng, root)
	plants(look, rng, root)

static func rocks(look: String, rng: RandomNumberGenerator, root: Node3D) -> void:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 7
	mesh.rings = 4
	var xforms: Array[Transform3D] = []
	for i in range(110):
		var p := Vector3(rng.randf_range(-HALF_X, HALF_X), 0.0, rng.randf_range(8.0, 92.0))
		var s := rng.randf_range(0.8, 3.2)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s * rng.randf_range(0.8, 1.6), s * rng.randf_range(0.5, 1.0), s * rng.randf_range(0.8, 1.4)))
		xforms.append(Transform3D(b, p + Vector3(0, s * 0.25, 0)))
	root.add_child(multimesh(mesh, Looks.material(look, "rock", true), xforms))

static func plants(look: String, rng: RandomNumberGenerator, root: Node3D) -> void:
	var stalk_mesh := CylinderMesh.new()
	stalk_mesh.top_radius = 0.02
	stalk_mesh.bottom_radius = 0.11
	stalk_mesh.height = 1.0
	stalk_mesh.radial_segments = 5
	stalk_mesh.rings = 1
	var frond_mesh := PrismMesh.new()
	frond_mesh.size = Vector3(0.7, 1.1, 0.05)
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.16
	bulb_mesh.height = 0.32
	bulb_mesh.radial_segments = 6
	bulb_mesh.rings = 3
	var stalks: Array[Transform3D] = []
	var fronds: Array[Transform3D] = []
	var frond_colors: Array[Color] = []
	var bulbs: Array[Transform3D] = []
	for i in range(420):
		var p := Vector3(rng.randf_range(-HALF_X, HALF_X), 0.0, rng.randf_range(6.0, 94.0))
		var h := rng.randf_range(1.0, 4.2)
		var yaw := rng.randf() * TAU
		stalks.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(1.0, h, 1.0)), p + Vector3(0, h * 0.5, 0)))
		bulbs.append(Transform3D(Basis(), p + Vector3(0, h + 0.1, 0)))
		for k in range(3):
			var tilt := Basis(Vector3.UP, yaw + k * 2.1) * Basis(Vector3.RIGHT, -0.6)
			fronds.append(Transform3D(tilt, p + Vector3(0, h * (0.35 + 0.2 * k), 0)))
			frond_colors.append(Color.WHITE.darkened(rng.randf_range(0.0, 0.3)))
	root.add_child(multimesh(stalk_mesh, Looks.material(look, "stalk", true), stalks))
	root.add_child(multimesh(frond_mesh, Looks.material(look, "frond", true), fronds, frond_colors))
	root.add_child(multimesh(bulb_mesh, Looks.material(look, "bulb"), bulbs))

static func overhead(look: String, rng: RandomNumberGenerator, root: Node3D) -> void:
	# Far side of the habitat (D2): district on the opposite floor, 2R above, hanging toward the axis.
	var box := BoxMesh.new()
	var xforms: Array[Transform3D] = []
	for i in range(1200):
		var theta := PI / 2.0 + rng.randf_range(-0.35, 0.35)
		var z := rng.randf_range(-RING_HALF_LENGTH, RING_HALF_LENGTH)
		var h := rng.randf_range(30.0, 120.0)
		var radial := Vector3(cos(theta), sin(theta), 0.0)
		var up := -radial
		var right := up.cross(Vector3.BACK).normalized()
		var b := Basis(right * rng.randf_range(30.0, 70.0), up * h, Vector3.BACK * rng.randf_range(30.0, 60.0))
		xforms.append(Transform3D(b, radial * (Cylinder.R - h * 0.5) + Vector3(0, 0, z)))
	root.add_child(multimesh(box, Looks.material(look, "ceiling"), xforms))
