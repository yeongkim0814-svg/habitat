extends SceneTree
## Headless checks for the M0 look-dev stage: structure only (the dummy renderer cannot compile shaders or draw).
const Looks = preload("res://spikes/m0_look/looks.gd")
const Stage = preload("res://spikes/m0_look/stage.gd")
const Sun = preload("res://spikes/m0_look/sun.gd")
const Buildings = preload("res://spikes/m0_look/buildings.gd")
const Tuning = preload("res://spikes/m0_look/tuning.gd")
const TuningPanel = preload("res://spikes/m0_look/tuning_panel.gd")
const Tent = preload("res://spikes/m0_look/tent.gd")
const Hospital = preload("res://spikes/m0_look/hospital.gd")
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
	test_hospital()
	test_scale()
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

func test_hospital() -> void:
	var h := Hospital.build()
	var meshes := h.find_children("*", "MeshInstance3D", false, false)
	var tris := 0
	var box := AABB()
	var chunks := {}
	for node in meshes:
		var mi := node as MeshInstance3D
		if mi.name == "shaft":
			continue
		check(mi.material_override != null, "hospital mesh %s has a material" % mi.name)
		chunks[String(mi.name).split("_")[0]] = true
		tris += mi.mesh.get_faces().size() / 3
		box = box.merge(World.HOSPITAL_XFORM * mi.get_aabb()) if box.size != Vector3.ZERO else World.HOSPITAL_XFORM * mi.get_aabb()
	check(meshes.size() <= 90 and count(h, "MultiMeshInstance3D") == 0, "hospital parts are merged per chunk and material (got %d meshes)" % meshes.size())
	check(chunks.keys().size() == 5 and chunks.has("room") and chunks.has("stair"), "hospital has 5 chunks: corridor thirds, room, stairwell (%s)" % [chunks.keys()])
	check(tris > 2000 and tris < 60000, "hospital triangle count is in budget (got %d)" % tris)
	# Beyond the street end (its ground stops at z = -95) and inside the stage width.
	check(box.end.z < -100.0 and box.position.x > -Stage.HALF_X and box.end.x < Stage.HALF_X, "hospital clears the street (%s)" % box)
	check(Hospital.CORRIDOR_W == 3.0 and Hospital.CEILING == 4.0, "corridor follows the D53 module (3 m wide, 4 m ceiling)")
	var omni := h.find_children("*", "OmniLight3D", false, false)
	check(omni.size() == 4, "3 emergency lights and the sun bounce light (got %d)" % omni.size())
	for light in omni:
		check(not (light as OmniLight3D).shadow_enabled, "%s casts no shadows" % light.name)
	check(Hospital.chunk_of(Vector3(0, 1, 2)) == "c0" and Hospital.chunk_of(Vector3(0, 1, 23)) == "c2" and Hospital.chunk_of(Vector3(4, 1, 10)) == "room" and Hospital.chunk_of(Vector3(0, 1, 27)) == "stair", "parts are filed under the right chunk")
	# Sun high along the axis: the shaft lands down the corridor, on the floor or a wall, inside the corridor.
	var to_sun := Vector3(0.0, sin(deg_to_rad(35.0)), cos(deg_to_rad(35.0)))
	var end := Hospital.landing(to_sun)
	check(end.z < Hospital.HOLE.position.y and absf(end.x) <= Hospital.CORRIDOR_W * 0.5 + 0.001 and end.y >= -0.001, "sunlight through the hole lands in the corridor (%s)" % end)
	check(is_equal_approx(end.y, 0.0), "steep sun lands on the floor (%s)" % end)
	# The lit air is the roof hole swept along the light: hole corners sit on the prism's top face, and the path
	# reaches below the floor, so the shaft ends where the corridor (floor, walls) cuts it, like the sunlight itself.
	for ts in [to_sun, Vector3(0.41, 0.41, 0.82), Vector3(-0.41, 0.41, 0.82)]:
		var b := Hospital.beam(ts)
		var inv: Basis = (b.axes as Basis).inverse()
		var corner := Vector3(Hospital.HOLE.end.x, Hospital.ROOF_TOP, Hospital.HOLE.end.y)
		var c := inv * (corner - (b.origin as Vector3))
		check(c.is_equal_approx(Vector3(0.5, 0.0, 0.5)), "hole corner is a corner of the beam prism (%s)" % c)
		var floor_hit := (b.origin as Vector3) + (b.axes as Basis).y * (Hospital.ROOF_TOP / -(b.axes as Basis).y.y)
		check(is_equal_approx(floor_hit.y, 0.0) and (inv * (floor_hit - (b.origin as Vector3))).y < 1.0, "the prism reaches the floor (%s)" % floor_hit)
		var clip: AABB = b.clip
		check(clip.position.y == 0.0 and is_equal_approx(clip.end.y, Hospital.ROOF_TOP) and is_equal_approx(clip.size.x, Hospital.CORRIDOR_W) and clip.position.z >= 0.0, "beam is cut by the corridor box (%s)" % clip)
	Hospital.aim(h, to_sun, 0.8, Color.WHITE)
	check((h.get_node("shaft") as Node3D).visible and (h.get_node("bounce") as Node3D).visible, "shaft and bounce are on in daylight")
	# The shaft box must not share a plane with the floor or walls (z-fighting bands, Issue #52).
	var clip: AABB = Hospital.beam(to_sun).clip
	var shaft_box := (h.get_node("shaft") as MeshInstance3D).mesh as BoxMesh
	check(shaft_box.size.x < clip.size.x - 0.02 and shaft_box.size.y < clip.size.y - 0.02, "shaft box sits inside the floor and walls (%s vs %s)" % [shaft_box.size, clip.size])
	# Analytic sun (Issue #52): under the hole the floor sees the sun, far down the corridor it does not; the edge is soft.
	var under := Hospital.landing(to_sun)
	check(Hospital.sun_gap(under, to_sun).x > 0.3, "the floor where the centre ray lands is sunlit (%s)" % Hospital.sun_gap(under, to_sun))
	check(Hospital.sun_gap(Vector3(0, 0, 2.0), to_sun).x < 0.0, "the floor near the corridor start is in shade")
	check(Hospital.sun_gap(Vector3(4.0, 0, 10.0), to_sun).x < -50.0, "the exam room is left to the shadow map")
	check(Hospital.sun_gap(under, to_sun).y >= 0.05, "the sun's edge has a penumbra")
	check(not Hospital.SHADER_HOSPITAL.format(Hospital.shader_constants()).contains("{"+"HOLE"), "all building sizes are written into the shader")
	Hospital.aim(h, Vector3(0.0, -0.3, 0.95), 0.8, Color.WHITE)
	check(not (h.get_node("shaft") as Node3D).visible and not (h.get_node("bounce") as Node3D).visible, "shaft and bounce are off with the sun below the roof")
	check("hospital" in World.VIEWS and World.VIEW_NAMES.has("hospital"), "hospital view is listed for the benchmark")
	# Benchmark: flashlight off, on, shadow, shadow, on, off per look x view.
	# Benchmark (Issue #48): FLAT only, each view at 100, 75, 50, 50, 75, 100 % render scale.
	var items := World.bench_items()
	check(items.size() == World.VIEWS.size() * 6, "benchmark measures FLAT in 6 runs per view (got %d)" % items.size())
	var sym := true
	for i in range(0, items.size(), 6):
		var head := items[i].split(":")
		for k in range(6):
			var p := items[i + k].split(":")
			sym = sym and p[0] == "flat" and p[1] == head[1] and int(p[2]) == World.SCALE_ORDER[k] and int(p[2]) == World.SCALE_ORDER[5 - k]
	check(sym, "each view is measured at 100, 75, 50, 50, 75, 100 % back to back (symmetric, drift cancels)")
	for pct in World.SCALE_ORDER:
		check(pct / 100.0 in World.SCALES, "bench scale %d is a selectable scale" % pct)
	check(is_equal_approx(World.mean_gpu([3.0, 3.5]), 3.25) and World.mean_gpu([3.0, 0.0]) == 0.0, "GPU mean is 0 (unavailable) if any run had no GPU timing")
	check(World.cost_line("flat", "hospital", 6.0, 0.0, 3.0).contains("GPU 시간 없음"), "summary says GPU timing is unavailable instead of showing 0")
	# 1 ms fixed + 4 ms per full screen: 100 % = 5, 50 % = 1 + 4 x 0.25 = 2, 75 % = 1 + 4 x 0.5625 = 3.25.
	var c := World.split_cost(5.0, 2.0)
	check(c.is_equal_approx(Vector2(1.0, 4.0)), "two scales split GPU time into fixed and per-pixel parts (%s)" % c)
	var line := World.cost_line("flat", "hospital", 5.0, 3.25, 2.0)
	check(line.contains("고정 1.00 픽셀 4.00") and line.contains("75% 예측 3.25"), "cost line shows the split and the 75 %% check (%s)" % line)
	# Thin parts in the sunlight path (ceiling grid, rebar) are drawn but cast no shadow: their fine stripes alias into broad
	# bands on small screens (Issue #50). Everything else still casts shadows.
	var tbars := 0
	for node in h.find_children("*", "MeshInstance3D", false, false):
		var mi := node as MeshInstance3D
		if String(mi.name).ends_with("_tbar"):
			tbars += 1
			check(mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s casts no shadow" % mi.name)
		elif mi.name != "shaft":
			check(mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s still casts shadows" % mi.name)
	check(tbars >= 1, "ceiling grid and rebar are in their own no-shadow mesh (got %d)" % tbars)
	# Sun shadow map (Issue #46): the hospital needs a short shadow distance and a softer filter; outdoors keeps 160 m.
	var indoor := World.shadow_settings("hospital")
	var outdoor := World.shadow_settings("street")
	check(outdoor.distance == 160.0 and World.shadow_settings("tent") == outdoor, "outdoor views keep the 160 m sun shadow")
	check(indoor.distance >= Hospital.EXTENT and indoor.distance < outdoor.distance / 4.0, "hospital shadow distance reaches the stairwell end and is much shorter than outdoors (%s)" % indoor.distance)
	check(indoor.soft > outdoor.soft and indoor.bias < outdoor.bias and indoor.normal_bias < outdoor.normal_bias, "hospital uses a softer filter and smaller biases")
	h.free()

func test_scale() -> void:
	# Issue #48: render resolution per axis; PSX keeps its own 1/4.
	check(World.SCALES == [1.0, 0.75, 0.5], "render scales are 100, 75, 50 %")
	for s in World.SCALES:
		check(World.effective_scale("flat", s) == s and World.effective_scale("paint", s) == s, "FLAT and PAINT follow the chosen scale (%s)" % s)
		check(is_equal_approx(World.effective_scale("psx", s), 1.0 / Looks.SHRINK["psx"]), "PSX keeps its own resolution (%s)" % s)
