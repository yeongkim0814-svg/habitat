extends SceneTree
## Headless checks for the M0 look-dev stage: structure only (the dummy renderer cannot compile shaders or draw).
const Looks = preload("res://spikes/m0_look/looks.gd")
const Stage = preload("res://spikes/m0_look/stage.gd")
const Sun = preload("res://spikes/m0_look/sun.gd")
const Buildings = preload("res://spikes/m0_look/buildings.gd")
const Tuning = preload("res://spikes/m0_look/tuning.gd")
const TuningPanel = preload("res://spikes/m0_look/tuning_panel.gd")
const Tent = preload("res://spikes/m0_look/tent.gd")
const World = preload("res://spikes/m0_look/world.gd")
const ROLES: Array[String] = ["street", "wall", "lamp", "soil", "rock", "stalk", "frond", "bulb", "ceiling", "meadow", "grass", "leaf", "conifer", "trunk"]
var failures := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)

func count(node: Node, type: String) -> int:
	var n := 1 if node.get_class() == type else 0
	for child in node.get_children():
		n += count(child, type)
	return n

func instances(node: Node) -> int:
	var n := 0
	if node is MultiMeshInstance3D:
		n += (node as MultiMeshInstance3D).multimesh.instance_count
	for child in node.get_children():
		n += instances(child)
	return n

func _init() -> void:
	for look in Looks.IDS:
		for role in ROLES:
			check(Looks.PALETTE[look].has(role), "%s palette has %s" % [look, role])
			var m := Looks.material(look, role, true)
			check(m.shader != null and m.shader.code.length() > 50, "%s/%s has shader code" % [look, role])
		check(Looks.environment(look).fog_enabled, "%s environment has fog" % look)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var root := Node3D.new()
		Stage.street(look, rng, root)
		Stage.field(look, rng, root)
		Stage.overhead(look, rng, root)
		# D19: repeated structures are MultiMeshes; only the two ground meshes are plain MeshInstance3D.
		check(count(root, "MeshInstance3D") == 2, "%s has only the 2 ground MeshInstance3D" % look)
		check(count(root, "MultiMeshInstance3D") >= 8, "%s uses MultiMeshes for repeats" % look)
		check(instances(root) > 2000, "%s has >2000 instances (got %d)" % [look, instances(root)])
		root.free()
		var meadow := Node3D.new()
		Stage.meadow(look, rng, meadow)
		check(count(meadow, "MeshInstance3D") == 1, "%s meadow has only the ground MeshInstance3D" % look)
		check(count(meadow, "MultiMeshInstance3D") == 5, "%s meadow has 5 MultiMeshes (rocks, 3 tree parts, grass)" % look)
		check(instances(meadow) > 2200 + 26 + 14 + 14, "%s meadow instance count (got %d)" % [look, instances(meadow)])
		meadow.free()
	check(load("res://spikes/m0_look/world.gd") != null, "world.gd parses")
	test_sun()
	test_tuning()
	test_flat_wall()
	test_buildings()
	test_flat_ground()
	test_tent()
	test_hemi()
	print("M0 tests: %s" % ("OK" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)

func test_sun() -> void:
	var peak := Sun.elevation_deg(12.0, Sun.SAFE_FLOOR_ANGLE)
	check(absf(peak - Sun.ALPHA_DEG) < 0.001, "safe zone noon elevation equals alpha (got %.3f)" % peak)
	check(absf(Sun.elevation_deg(6.0, Sun.SAFE_FLOOR_ANGLE)) < 0.001, "sunrise elevation is 0")
	check(absf(Sun.elevation_deg(18.0, Sun.SAFE_FLOOR_ANGLE)) < 0.001, "sunset elevation is 0")
	var day := 0
	for i in range(240):
		var h := i * 0.1
		var safe := Sun.elevation_deg(h, Sun.SAFE_FLOOR_ANGLE)
		var danger := Sun.elevation_deg(h, Sun.DANGER_FLOOR_ANGLE)
		check(absf(safe + danger) < 0.0001, "zones are in opposite phase at %.1f h" % h)
		if safe > 0.0:
			day += 1
	check(day == 120, "each zone is lit exactly half the day (got %d of 240 steps)" % day)
	check(Sun.to_sun(9.0).is_equal_approx(Sun.to_sun(9.0).normalized()), "sun direction is a unit vector")
	check(Sun.light_energy(-10.0) == 0.0 and Sun.light_energy(30.0) > 0.5, "light energy is 0 at night and positive by day")

func test_tuning() -> void:
	var values := {"colors": {"rock": Color("336699"), "grass": Color("aabbcc")}, "fog": 0.0021, "sun": 1.25}
	var back := Tuning.decode("flat", Tuning.encode("flat", values))
	check(back.colors.size() == 2 and back.colors.rock.to_html(false) == "336699", "tuning roundtrip keeps role colors")
	check(absf(back.fog - 0.0021) < 0.00001 and absf(back.sun - 1.25) < 0.0001 and not back.has("ambient"), "tuning roundtrip keeps globals, omits unset")
	check(Tuning.decode("psx", Tuning.encode("flat", values)).colors.is_empty(), "values belong to their own look")
	check(Tuning.decode("flat", "not json").colors.is_empty(), "garbage file gives empty tuning")
	var messy := Tuning.decode("flat", '{"flat": {"colors": {"rock": "zzz", "nothing": "#ffffff", "wall": "#102030"}, "fog": "x"}}')
	check(messy.colors.size() == 1 and messy.colors.has("wall") and not messy.has("fog"), "bad roles, colors and globals are dropped")
	var wild := Tuning.decode("flat", '{"flat": {"sun": -1, "ambient": 100, "fog": 5}}')
	check(wild.sun == Tuning.GLOBAL_RANGES.sun.x and wild.ambient == Tuning.GLOBAL_RANGES.ambient.y and wild.fog == Tuning.GLOBAL_RANGES.fog.y, "out-of-range globals are clamped to the slider ranges")
	for role in Tuning.ROLES:
		check(Tuning.NAMES.has(role) and Looks.PALETTE["flat"].has(role), "tunable role %s has a name and a palette color" % role)
	Looks.live.clear()
	var m := Looks.material("flat", "rock")
	Looks.tuned = {"rock": Color.RED}
	Looks.refresh_live("flat")
	check((m.get_shader_parameter("base_color") as Color).is_equal_approx(Color.RED), "refresh_live recolors existing materials")
	Looks.tuned = {}
	var panel := TuningPanel.new()
	panel.load_look("flat")
	panel.set_role_color("leaf", Color.BLUE)
	check(panel.values.colors.leaf == Color.BLUE and Looks.tuned.leaf == Color.BLUE, "panel color change lands in values and Looks.tuned")
	check(is_equal_approx(panel.value("fog"), Looks.FOG["flat"]) and panel.value("sun") == 1.0, "unset globals fall back to look defaults")
	panel.load_look("flat")
	check(panel.values.colors.has("leaf") and Looks.tuned.has("leaf"), "reloading the same look keeps unsaved edits")
	panel.reset()
	check(Looks.tuned.is_empty() and panel.values.colors.is_empty(), "reset clears tuning")
	panel.load_look("flat")
	check(panel.values.colors.is_empty(), "a reset stays reset across rebuilds")
	panel.free()
	Looks.live.clear()

func test_flat_wall() -> void:
	Looks.live.clear()
	var wall := Looks.material("flat", "wall")
	var other := Looks.material("flat", "street")
	check(wall.shader.code.contains("storey") and not other.shader.code.contains("storey"), "only the FLAT wall role draws windows")
	check(Looks.material("psx", "wall").shader.code.contains("storey") == false, "other looks keep their own wall shader")
	Looks.set_night(1.0)
	check(is_equal_approx(wall.get_shader_parameter("night"), 1.0), "set_night reaches live wall materials")
	Looks.set_night(0.0)
	check(is_equal_approx(wall.get_shader_parameter("night"), 0.0), "set_night(0) turns lit windows off")
	Looks.live.clear()

func test_buildings() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var kinds := {}
	for i in range(200):
		var parts := Buildings.lot(rng, -1.0 if i % 2 == 0 else 1.0, -90.0, 12.0)
		kinds[parts.size()] = true
		check(parts.size() >= 1 and parts.size() <= 4, "a lot is 1-4 boxes (got %d)" % parts.size())
		for p in parts:
			var scale: Vector3 = p.xf.basis.get_scale()
			check(scale.x > 0.0 and scale.y > 0.0 and scale.z > 0.0, "box has a size")
			check(p.xf.origin.y - scale.y * 0.5 > -0.001, "box does not sink below the street")
			check(absf(p.xf.origin.x) >= Buildings.NEAR, "box stays behind the street edge")
			var top: float = p.xf.origin.y + scale.y * 0.5
			check(top <= Buildings.MAX_FLOORS * 3.6 + 2.4 + 0.001, "building stays within 3 storeys plus roof structure (top %.1f)" % top)
	check(kinds.size() >= 3, "archetypes differ in box count (got %d kinds)" % kinds.size())
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 9
	b.seed = 9
	check(Buildings.lot(a, 1.0, 0.0, 12.0).size() == Buildings.lot(b, 1.0, 0.0, 12.0).size(), "lots are deterministic per seed")
	var root := Node3D.new()
	Stage.street("flat", rng, root)
	var found := false
	for child in root.get_children():
		if child is MultiMeshInstance3D and (child as MultiMeshInstance3D).multimesh.use_custom_data:
			found = true
	check(found, "street walls carry per-box custom data")
	root.free()

func test_flat_ground() -> void:
	Looks.live.clear()
	for role in ["street", "soil", "meadow"]:
		var g := Looks.material("flat", role, false, true)
		check(g.shader.code.contains("uniform int kind") and g.get_shader_parameter("kind") == Looks.GROUND_KIND[role], "FLAT %s ground uses the ground shader with its kind" % role)
		check(not Looks.material("paint", role, false, true).shader.code.contains("uniform int kind"), "other looks keep their ground shader (%s)" % role)
	check(not Looks.material("flat", "street").shader.code.contains("uniform int kind"), "the ring (street role without ground flag) keeps SHADER_FLAT")
	check(Looks.SHADER_FLAT_GROUND.contains("vec4(%.1f, %.1f, %.1f, %.1f)" % [Stage.PLOT.position.x, Stage.PLOT.position.y, Stage.PLOT.end.x, Stage.PLOT.end.y]), "shader farm plot matches Stage.PLOT")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var clear := true
	for i in range(2000):
		var p := Stage.spot(rng)
		if Stage.PLOT.has_point(Vector2(p.x, p.z)):
			clear = false
	check(clear, "trees and grass stay off the farm plot")
	Looks.live.clear()

func test_tent() -> void:
	var tent := Tent.build()
	var meshes := tent.find_children("*", "MeshInstance3D", false, false)
	check(meshes.size() <= 13 and count(tent, "MultiMeshInstance3D") == 0, "tent parts are merged per material (got %d meshes)" % meshes.size())
	var tris := 0
	var box := AABB()
	for node in meshes:
		var mi := node as MeshInstance3D
		check(mi.material_override != null, "tent mesh %s has a material" % mi.name)
		tris += mi.mesh.get_faces().size() / 3
		box = box.merge(World.TENT_XFORM * mi.get_aabb()) if box.size != Vector3.ZERO else World.TENT_XFORM * mi.get_aabb()
	check(tris > 1000 and tris < 30000, "tent triangle count is in budget (got %d)" % tris)
	# Footprint stays between the west lamp line (x = -6) and the buildings (x = -16), on the street ground (z < 3).
	check(box.position.x > -Buildings.NEAR and box.end.x < -6.0 and box.end.z < 3.0, "tent footprint clears lamps and buildings (%s)" % box)
	var found := Tent.textures_found()
	for kind in ["canvas", "pole", "crate"]:
		var m := Tent.material(kind)
		check(m.get_shader_parameter("tex_on") == (1.0 if found else 0.0), "%s texture flag matches assets presence (%s)" % [kind, found])
	check(Tent.material("metal").get_shader_parameter("tex_on") == 0.0, "untextured kinds stay flat")
	check("tent" in World.VIEWS and World.VIEW_NAMES.has("tent"), "infirmary view is listed for the benchmark")
	var items := World.bench_items()
	check(items.size() == Looks.IDS.size() * World.VIEWS.size() * 4, "benchmark measures every look x view twice with the tent on and twice off (got %d)" % items.size())
	var abba := true
	for i in range(0, items.size(), 4):
		var head := items[i].split(":")
		for k in range(4):
			var p := items[i + k].split(":")
			abba = abba and p[0] == head[0] and p[1] == head[1] and p[2] == ["on", "off", "off", "on"][k]
	check(abba, "each look x view is measured on, off, off, on back to back (drift cancels within the row)")
	check(is_equal_approx(World.mean_gpu([3.0, 3.5]), 3.25) and World.mean_gpu([3.0, 0.0]) == 0.0, "GPU mean is 0 (unavailable) if any run had no GPU timing")
	check(World.cost_line("flat", "tent", 3.5, 0.0).contains("GPU 시간 없음"), "summary says GPU timing is unavailable instead of showing 0")
	check(World.cost_line("flat", "tent", 3.5, 3.25).ends_with("+0.25 ms"), "cost line shows on - off")
	tent.free()

func test_hemi() -> void:
	# Derivative normals flip when the image is drawn upside down (SubViewport): every FLAT shader turns them toward the camera.
	for code in [Looks.SHADER_FLAT, Looks.SHADER_FLAT_WALL, Looks.SHADER_FLAT_GROUND]:
		check(code.contains("NORMAL = dot(NORMAL, VERTEX) > 0.0 ? -NORMAL : NORMAL;"), "FLAT shader turns its derivative normal toward the camera")
	var e := Looks.environment("flat")
	check(e.sky != null and e.sky.sky_material is ProceduralSkyMaterial, "FLAT has a sky for hemisphere ambient")
	check(e.reflected_light_source == Environment.REFLECTION_SOURCE_DISABLED, "the ambient sky adds no reflections")
	for look in ["psx", "toon", "paint"]:
		check(Looks.environment(look).sky == null, "%s keeps its flat-color ambient" % look)
	var noon := World.ground_bounce(60.0, Looks.PALETTE["flat"]["street"])
	var night := World.ground_bounce(-20.0, Looks.PALETTE["flat"]["street"])
	check(noon.r > noon.b and noon.get_luminance() > night.get_luminance() * 2.0, "ground bounce is warm by day and dim at night")
