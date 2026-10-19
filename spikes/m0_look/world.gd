extends Node3D
## M0 look-dev scene: same stage in three render styles. Touch buttons switch look/view and run a frame-time benchmark.
const Looks = preload("res://spikes/m0_look/looks.gd")
const Stage = preload("res://spikes/m0_look/stage.gd")
const Sun = preload("res://spikes/m0_look/sun.gd")
const Kit = preload("res://spikes/m0_look/ui_kit.gd")
const TuningPanel = preload("res://spikes/m0_look/tuning_panel.gd")
const Cylinder = preload("res://spikes/s2_cylinder/cylinder.gd")
const VIEWS: Array[String] = ["street", "field", "meadow", "overhead"]
const VIEW_NAMES := {"street": "거리", "field": "들판", "meadow": "초원", "overhead": "머리 위"}
const ZONE_NAMES := {"safe": "안전구역", "danger": "오염구역"}
const BENCH_FRAMES := 90
const BENCH_SKIP := 12

var container := SubViewportContainer.new()
var viewport := SubViewport.new()
var scene := Node3D.new()
var content := Node3D.new()
var camera := Camera3D.new()
var env_node := WorldEnvironment.new()
var label := Label.new()
var ui := CanvasLayer.new()
var look := "flat"
var view := "street"
var hour := 12.0
var zone := "safe"
var sun := DirectionalLight3D.new()
var floor_root := Node3D.new()
var panel := TuningPanel.new()
var bench_queue: Array[String] = []
var bench_samples: Array[float] = []
var cpu_samples: Array[float] = []
var gpu_samples: Array[float] = []
var bench_lines: Array[String] = []
var bench_frame := 0
var shot_frames := -1
var shot_path := ""

func _ready() -> void:
	add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.add_child(viewport)
	viewport.add_child(scene)
	scene.add_child(env_node)
	scene.add_child(content)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 160.0
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 2.0
	scene.add_child(sun)
	camera.far = 3500.0
	camera.fov = 75.0
	scene.add_child(camera)
	camera.current = true
	build_ui()
	if not read_args():
		return
	rebuild()

func read_args() -> bool:
	# Returns false when the process is quitting because of a malformed --shot argument.
	var shot := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot = arg.substr(7)
		elif arg.begins_with("--hour="):
			var text := arg.substr(7)
			if not text.is_valid_float() or float(text) < 0.0 or float(text) > 24.0:
				return reject("--hour expects a number in 0-24, got '%s'" % text)
			hour = float(text)
		elif arg.begins_with("--zone="):
			if not arg.substr(7) in ZONE_NAMES:
				return reject("--zone expects one of %s, got '%s'" % [", ".join(ZONE_NAMES.keys()), arg.substr(7)])
			zone = arg.substr(7)
	if shot != "":
		# look:view:path, split at most twice so a path may contain ':' (e.g. C:/tmp/shot.png).
		var parts := shot.split(":", true, 2)
		if parts.size() != 3 or not parts[0] in Looks.IDS or not parts[1] in VIEWS or parts[2] == "":
			return reject("--shot expects <%s>:<%s>:<output.png>, got '%s'" % ["|".join(Looks.IDS), "|".join(VIEWS), shot])
		look = parts[0]
		view = parts[1]
		shot_path = parts[2]
		shot_frames = 8
		ui.visible = false
	return true

func reject(message: String) -> bool:
	push_error("M0: " + message)
	get_tree().quit(2)
	return false

func floor_xform() -> Transform3D:
	# Safe zone floor is at the bottom of the ring; the danger zone floor is at the top, so its stage is upside down.
	var lift := Vector3(0, Stage.FLOOR_LIFT, 0)
	if zone == "safe":
		return Transform3D(Basis(), Stage.origin() + lift)
	return Transform3D(Basis(Vector3.BACK, PI), Vector3(0, Cylinder.R, 0) - lift)

func rebuild() -> void:
	for child in content.get_children():
		child.free()
	Looks.live.clear()
	panel.load_look(look)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	floor_root = Node3D.new()
	floor_root.transform = floor_xform()
	content.add_child(floor_root)
	Stage.street(look, rng, floor_root)
	if view == "meadow":
		Stage.meadow(look, rng, floor_root)
	else:
		Stage.field(look, rng, floor_root)
	var ring := Node3D.new()
	content.add_child(ring)
	for i in range(Cylinder.N):
		var seg := MeshInstance3D.new()
		seg.mesh = Cylinder.segment(Cylinder.R, i)
		seg.material_override = Looks.material(look, "street")
		seg.scale.z = Stage.RING_HALF_LENGTH * 2.0 / Cylinder.L
		ring.add_child(seg)
	Stage.overhead(look, rng, ring, -PI / 2.0 if zone == "danger" else PI / 2.0)
	env_node.environment = Looks.environment(look)
	container.stretch_shrink = Looks.SHRINK[look]
	apply_time()
	place_camera()

func apply_time() -> void:
	var theta := Sun.SAFE_FLOOR_ANGLE if zone == "safe" else Sun.DANGER_FLOOR_ANGLE
	var elev := Sun.elevation_deg(hour, theta)
	sun.look_at_from_position(Sun.to_sun(hour) * 200.0, Vector3.ZERO)
	sun.light_energy = Sun.light_energy(elev) * panel.value("sun")
	sun.light_color = Sun.light_color(elev)
	sun.visible = sun.light_energy > 0.0
	var env := env_node.environment
	env.background_color = Sun.sky_color(elev)
	env.fog_light_color = env.background_color
	env.ambient_light_color = Sun.ambient_color(elev)
	env.ambient_light_energy = Looks.AMBIENT[look] * lerpf(0.5, 0.8, smoothstep(-6.0, 10.0, elev)) * panel.value("ambient")
	env.fog_density = panel.value("fog")
	label.text = "%s / %s / %s / %02d시 (태양 고도 %d°)" % [Looks.NAMES[look], VIEW_NAMES[view], ZONE_NAMES[zone], int(hour), int(elev)]

func place_camera() -> void:
	var xf := floor_xform()
	var up := xf.basis * Vector3.UP
	var amp := 1.0 if view == "meadow" else 1.8
	var eye := Vector3(0, 1.7, 4)
	var target := Vector3(0, 2.0, 60)
	match view:
		"street":
			eye = Vector3(0, 1.7, -92)
			target = Vector3(0, 3.0, -20)
		"overhead":
			eye = Vector3(0, 1.7, -30)
			target = Vector3(150, 900, 0)
		_:
			eye.y += Stage.ground_y(0.0, 4.0, amp)
	camera.position = xf * eye
	camera.look_at(xf * target, up)
	# The far side is 2 km away: ground fog would wash it out, so fog is only for ground-level views.
	env_node.environment.fog_enabled = view != "overhead"

func build_ui() -> void:
	add_child(ui)
	ui.add_child(label)
	label.position = Vector2(30, 20)
	label.add_theme_font_size_override("font_size", 28)
	# Dark backing so text stays readable over the 3D scene (benchmark results were lost in the background).
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0, 0, 0, 0.7)
	backing.set_content_margin_all(12.0)
	label.add_theme_stylebox_override("normal", backing)
	var top := Kit.bottom_row(ui, -290.0, -170.0)
	for id in Looks.IDS:
		Kit.button(top, Looks.NAMES[id], set_look.bind(id))
	for id in VIEWS:
		Kit.button(top, VIEW_NAMES[id], set_view.bind(id))
	var bottom := Kit.bottom_row(ui, -150.0, -30.0)
	Kit.button(bottom, "-3시", step_hour.bind(-3.0))
	Kit.button(bottom, "+3시", step_hour.bind(3.0))
	Kit.button(bottom, "구역", toggle_zone)
	Kit.button(bottom, "조절", toggle_panel)
	Kit.button(bottom, "측정", start_bench)
	ui.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -680.0
	panel.offset_top = 100.0
	panel.offset_bottom = -310.0
	panel.visible = false
	panel.tuned.connect(apply_time)

func toggle_panel() -> void:
	panel.visible = not panel.visible

func set_look(id: String) -> void:
	if bench_queue.is_empty():
		look = id
		rebuild()

func set_view(id: String) -> void:
	if bench_queue.is_empty():
		var rebuild_needed := (id == "meadow") != (view == "meadow")
		view = id
		if rebuild_needed:
			rebuild()
		else:
			apply_time()
			place_camera()

func step_hour(delta: float) -> void:
	if bench_queue.is_empty():
		hour = fposmod(hour + delta, 24.0)
		apply_time()

func toggle_zone() -> void:
	if bench_queue.is_empty():
		zone = "danger" if zone == "safe" else "safe"
		rebuild()

func start_bench() -> void:
	if not bench_queue.is_empty():
		return
	bench_lines.clear()
	# Compatibility cannot uncap VSync, so frame time alone is capped by the refresh interval: also record renderer CPU/GPU time.
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	for l in Looks.IDS:
		for v in VIEWS:
			bench_queue.append("%s:%s" % [l, v])
	next_bench()

func next_bench() -> void:
	var parts := bench_queue[0].split(":")
	look = parts[0]
	view = parts[1]
	rebuild()
	bench_samples.clear()
	cpu_samples.clear()
	gpu_samples.clear()
	bench_frame = 0

func finish_bench_item() -> void:
	var sorted := bench_samples.duplicate()
	sorted.sort()
	var p95: float = sorted[int(sorted.size() * 0.95)]
	var gpu := mean_of(gpu_samples)
	var line := "M0 look=%s view=%s mean_ms=%.3f p95_ms=%.3f render_cpu_mean_ms=%.3f render_gpu_mean_ms=%s samples=%d refresh_hz=%s vsync=%d" % [look, view, mean_of(bench_samples), p95, mean_of(cpu_samples), "%.3f" % gpu if gpu > 0.0 else "?", bench_samples.size(), refresh_text(), DisplayServer.window_get_vsync_mode()]
	print(line)
	bench_lines.append(line)
	bench_queue.remove_at(0)
	if bench_queue.is_empty():
		label.text = "\n".join(bench_lines)
		label.add_theme_font_size_override("font_size", 20)
	else:
		next_bench()

func _process(delta: float) -> void:
	if not bench_queue.is_empty():
		bench_frame += 1
		if bench_frame > BENCH_SKIP:
			bench_samples.append(delta * 1000.0)
			var rid := viewport.get_viewport_rid()
			cpu_samples.append(RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu())
			gpu_samples.append(RenderingServer.viewport_get_measured_render_time_gpu(rid))
		if bench_samples.size() >= BENCH_FRAMES:
			finish_bench_item()
	if shot_frames > 0:
		shot_frames -= 1
		if shot_frames == 0:
			get_viewport().get_texture().get_image().save_png(shot_path)
			print("M0 shot saved: ", shot_path)
			get_tree().quit()

func mean_of(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += v
	return total / values.size()

func refresh_text() -> String:
	# screen_get_refresh_rate() is unavailable (NaN/-1) on some displays; show '?' instead.
	var hz := DisplayServer.screen_get_refresh_rate()
	return "%.0f" % hz if hz > 0.0 else "?"
