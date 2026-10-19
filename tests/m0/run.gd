extends SceneTree
## Headless checks for the M0 look-dev stage: structure only (the dummy renderer cannot compile shaders or draw).
const Looks = preload("res://spikes/m0_look/looks.gd")
const Stage = preload("res://spikes/m0_look/stage.gd")
const Sun = preload("res://spikes/m0_look/sun.gd")
const Tuning = preload("res://spikes/m0_look/tuning.gd")
const TuningPanel = preload("res://spikes/m0_look/tuning_panel.gd")
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
