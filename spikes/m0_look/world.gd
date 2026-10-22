extends Node3D
## M0 look-dev scene: same stage in three render styles. Touch buttons switch look/view and run a frame-time benchmark.
const Looks = preload("res://spikes/m0_look/looks.gd")
const Stage = preload("res://spikes/m0_look/stage.gd")
const Sun = preload("res://spikes/m0_look/sun.gd")
const Kit = preload("res://spikes/m0_look/ui_kit.gd")
const TuningPanel = preload("res://spikes/m0_look/tuning_panel.gd")
const Cylinder = preload("res://spikes/s2_cylinder/cylinder.gd")
const Tent = preload("res://spikes/m0_look/tent.gd")
const Hospital = preload("res://spikes/m0_look/hospital.gd")
const VIEWS: Array[String] = ["street", "boundary", "field", "meadow", "overhead", "tent", "hospital"]
const VIEW_NAMES := {"street": "거리", "boundary": "경계", "field": "들판", "meadow": "초원", "overhead": "머리 위", "tent": "의무실", "hospital": "병원"}
const ZONE_NAMES := {"safe": "안전구역", "danger": "오염구역"}
const TORCH_NAMES := {"off": "손전등 끔", "lamp": "손전등", "shadow": "손전등+그림자"}
const TORCH_ORDER: Array[String] = ["off", "lamp", "shadow", "shadow", "lamp", "off"]
# Infirmary tent between the west lamp line (x = -6) and the buildings (x = -16), door facing the street.
const TENT_XFORM := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(-11.0, 0.2, -12.0))
# Hospital interior (D60, D61) beyond the street end (street ground ends at z = -95), corridor running toward the street.
const HOSPITAL_XFORM := Transform3D(Basis(), Vector3(0.0, 0.2, -140.0))
# Sun shadow map: one picture covers everything from the camera out to the shadow distance, so a long distance makes every texel
# big and the edge of a shadow shows as stair steps. Outdoors needs 160 m. Inside, the corridor is 24 m long, so 24 m keeps every
# sunlit patch in range and each texel is 6-7x smaller. A softer filter then blurs what is left of the steps (Issue #46). The
# biases are in metres and in texels, so they shrink with the texel. The filter is a global setting: it is only set when it changes.
const SHADOW_OUTDOOR := {"distance": 160.0, "bias": 0.05, "normal_bias": 2.0, "soft": RenderingServer.SHADOW_QUALITY_SOFT_LOW}
const SHADOW_HOSPITAL := {"distance": 24.0, "bias": 0.02, "normal_bias": 1.0, "soft": RenderingServer.SHADOW_QUALITY_SOFT_HIGH}
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
var bench_gpu := {} # "look:view:torch" -> GPU ms of each run, for the flashlight summary
var hemi := true # FLAT hemisphere ambient (Issue #40)
var soft_quality := RenderingServer.SHADOW_QUALITY_SOFT_LOW
var torch := "lamp" # player flashlight: off, lamp, or lamp with shadows (Issue #42)
var flashlight := SpotLight3D.new()
var hospital_node: Node3D
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
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY # no sun disk in the ambient sky
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	scene.add_child(sun)
	camera.far = 3500.0
	camera.fov = 75.0
	scene.add_child(camera)
	camera.current = true
	# Held at the right hand, not at the eye: a light at the eye hides every shadow it casts behind the objects it lights.
	camera.add_child(flashlight)
	flashlight.position = Vector3(0.25, -0.22, 0.0)
	flashlight.rotation = Vector3(0.027, 0.031, 0.0) # aimed to cross the view centre about 8 m ahead
	flashlight.spot_range = 22.0
	flashlight.spot_angle = 24.0
	flashlight.spot_angle_attenuation = 0.9
	flashlight.light_energy = 3.0
	flashlight.light_color = Color(1.0, 0.95, 0.85)
	flashlight.shadow_bias = 0.03
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
		elif arg.begins_with("--hemi="):
			if not arg.substr(7) in ["on", "off"]:
				return reject("--hemi expects on or off, got '%s'" % arg.substr(7))
			hemi = arg.substr(7) == "on"
		elif arg.begins_with("--torch="):
			if not arg.substr(8) in TORCH_NAMES:
				return reject("--torch expects one of %s, got '%s'" % [", ".join(TORCH_NAMES.keys()), arg.substr(8)])
			torch = arg.substr(8)
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
	var tent := Tent.build()
	tent.transform = TENT_XFORM
	floor_root.add_child(tent)
	hospital_node = Hospital.build()
	hospital_node.transform = HOSPITAL_XFORM
	floor_root.add_child(hospital_node)
	if uses_meadow(view):
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
	apply_torch()

func apply_torch() -> void:
	flashlight.visible = torch != "off"
	flashlight.shadow_enabled = torch == "shadow"

static func shadow_settings(v: String) -> Dictionary:
	return SHADOW_HOSPITAL if v == "hospital" else SHADOW_OUTDOOR

func apply_time() -> void:
	var theta := Sun.SAFE_FLOOR_ANGLE if zone == "safe" else Sun.DANGER_FLOOR_ANGLE
	var elev := Sun.elevation_deg(hour, theta)
	sun.look_at_from_position(Sun.to_sun(hour) * 200.0, Vector3.ZERO)
	var shadow := shadow_settings(view)
	sun.directional_shadow_max_distance = shadow.distance
	sun.shadow_bias = shadow.bias
	sun.shadow_normal_bias = shadow.normal_bias
	if soft_quality != shadow.soft:
		soft_quality = shadow.soft
		RenderingServer.directional_soft_shadow_filter_set_quality(soft_quality)
	sun.light_energy = Sun.light_energy(elev) * panel.value("sun")
	if view == "hospital":
		# Eyes adapt to the dark interior, so sunlight through the roof hole looks several times brighter than outdoors.
		# Scaling the sun here equals raising the exposure with the indoor lights tuned for it (outside is not visible).
		sun.light_energy *= Hospital.INDOOR_EXPOSURE
	sun.light_color = Sun.light_color(elev)
	sun.visible = sun.light_energy > 0.0
	Looks.set_night(1.0 - smoothstep(-4.0, 6.0, elev))
	var env := env_node.environment
	env.background_color = Sun.sky_color(elev)
	env.fog_light_color = env.background_color
	env.ambient_light_color = Sun.ambient_color(elev)
	# One environment for the whole scene: inside the hospital, walls and roof block most of the sky light (D90 open point).
	var indoor := Hospital.INDOOR_AMBIENT if view == "hospital" else 1.0
	if env.sky != null:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY if hemi else Environment.AMBIENT_SOURCE_COLOR
		# Up is the habitat axis: the danger zone stage is upside down, so turn the sky with it.
		env.sky_rotation = Vector3(0, 0, PI) if zone == "danger" else Vector3.ZERO
		var m := env.sky.sky_material as ProceduralSkyMaterial
		var ground := ground_bounce(elev, Looks.PALETTE["flat"]["street"])
		m.sky_top_color = Sun.ambient_color(elev)
		m.sky_horizon_color = Sun.ambient_color(elev).lerp(ground, 0.35)
		m.ground_horizon_color = ground.lerp(Sun.ambient_color(elev), 0.35)
		m.ground_bottom_color = ground
		# ambient_light_energy does not scale sky ambient (only the color part), so the slider and the indoor factor
		# scale the sky itself. At slider 1 outdoors this is the look approved in #41 (sky energy 1).
		m.energy_multiplier = panel.value("ambient") * indoor
	env.ambient_light_energy = Looks.AMBIENT[look] * lerpf(0.5, 0.8, smoothstep(-6.0, 10.0, elev)) * panel.value("ambient") * indoor
	env.fog_density = panel.value("fog")
	if hospital_node != null and hospital_node.is_inside_tree():
		var to_sun := hospital_node.global_transform.basis.inverse() * Sun.to_sun(hour)
		Hospital.aim(hospital_node, to_sun, sun.light_energy if sun.visible else 0.0, sun.light_color)
	label.text = "%s / %s / %s / %02d시 (태양 고도 %d°) / %s" % [Looks.NAMES[look], VIEW_NAMES[view], ZONE_NAMES[zone], int(hour), int(elev), TORCH_NAMES[torch]]
	if view == "tent" and not Tent.textures_found():
		label.text += " / 텍스처 없음(assets 폴더 확인)"

# Light the ground sends back up: its color times direct sun on the ground (grows with elevation) plus a little sky.
static func ground_bounce(elev: float, albedo: Color) -> Color:
	var direct := Sun.light_color(elev) * (Sun.light_energy(elev) * maxf(sin(deg_to_rad(elev)), 0.0) * 1.6)
	var c := albedo * (direct + Sun.ambient_color(elev) * 0.35)
	return Color(c.r, c.g, c.b, 1.0)

func uses_meadow(v: String) -> bool:
	return v == "meadow" or v == "boundary"

func place_camera() -> void:
	var xf := floor_xform()
	var up := xf.basis * Vector3.UP
	var amp := 1.0 if uses_meadow(view) else 1.8
	var eye := Vector3(0, 1.7, 4)
	var target := Vector3(0, 2.0, 60)
	match view:
		"street":
			eye = Vector3(0, 1.7, -92)
			target = Vector3(0, 3.0, -20)
		"boundary":
			# Street buildings on both sides, the meadow beyond the street end: one frame to judge how they fit.
			eye = Vector3(0, 1.7, -50)
			target = Vector3(0, 5.0, 40)
		"overhead":
			eye = Vector3(0, 1.7, -30)
			target = Vector3(150, 900, 0)
		"tent":
			eye = Vector3(-4.0, 1.7, -6.5)
			target = Vector3(-11.0, 1.3, -12.0)
		"hospital":
			# From the chained doors down the corridor: exam room door, roof hole, exit sign at the stairwell.
			eye = HOSPITAL_XFORM * Vector3(-0.5, 1.7, 1.2)
			target = HOSPITAL_XFORM * Vector3(0.3, 1.3, 14.0)
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
	Kit.button(bottom, "손전등", cycle_torch)
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
		var rebuild_needed := uses_meadow(id) != uses_meadow(view)
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

func cycle_torch() -> void:
	if bench_queue.is_empty():
		var order: Array[String] = ["off", "lamp", "shadow"]
		torch = order[(order.find(torch) + 1) % order.size()]
		apply_torch()
		apply_time()

func start_bench() -> void:
	if not bench_queue.is_empty():
		return
	bench_lines.clear()
	# Compatibility cannot uncap VSync, so frame time alone is capped by the refresh interval: also record renderer CPU/GPU time.
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	bench_gpu.clear()
	bench_queue = bench_items()
	next_bench()

# Each look x view is measured with the flashlight off, on, on with shadows, then back (ABCCBA) (Issue #42).
# The order is symmetric in time, so drift that is linear in time (temperature, clocks) cancels in every pairwise
# difference of the averaged states (Issue #38).
static func bench_items() -> Array[String]:
	var items: Array[String] = []
	for l in Looks.IDS:
		for v in VIEWS:
			for state in TORCH_ORDER:
				items.append("%s:%s:%s" % [l, v, state])
	return items

static func cost_line(l: String, v: String, off: float, lamp: float, shadow: float) -> String:
	# The renderer reports 0 when GPU timing is unavailable: say so instead of showing a zero difference.
	if off <= 0.0 or lamp <= 0.0 or shadow <= 0.0:
		return "%s %s: GPU 시간 없음(로그의 mean_ms 참고)" % [l, v]
	return "%s %s: 손전등 끔 %.2f / 켬 %+.2f / 그림자 %+.2f ms" % [l, v, off, lamp - off, shadow - lamp]

static func mean_gpu(runs: Array) -> float:
	# A run without GPU timing (0) makes the whole condition unavailable.
	var total := 0.0
	for g in runs:
		if g <= 0.0:
			return 0.0
		total += g
	return total / runs.size()

func next_bench() -> void:
	var parts := bench_queue[0].split(":")
	look = parts[0]
	view = parts[1]
	torch = parts[2]
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
	var torch_state := bench_queue[0].split(":")[2]
	bench_gpu.get_or_add(bench_queue[0], []).append(gpu)
	var line := "M0 look=%s view=%s torch=%s mean_ms=%.3f p95_ms=%.3f render_cpu_mean_ms=%.3f render_gpu_mean_ms=%s samples=%d refresh_hz=%s vsync=%d" % [look, view, torch_state, mean_of(bench_samples), p95, mean_of(cpu_samples), "%.3f" % gpu if gpu > 0.0 else "?", bench_samples.size(), refresh_text(), DisplayServer.window_get_vsync_mode()]
	print(line)
	bench_queue.remove_at(0)
	if bench_queue.is_empty():
		# Full lines go to the log; the screen shows one GPU line per look x view so all 28 fit.
		for l in Looks.IDS:
			for v in VIEWS:
				var g := func(state: String) -> float: return mean_gpu(bench_gpu["%s:%s:%s" % [l, v, state]])
				bench_lines.append(cost_line(l, v, g.call("off"), g.call("lamp"), g.call("shadow")))
		bench_lines.append("GPU ms, %s Hz, vsync=%d" % [refresh_text(), DisplayServer.window_get_vsync_mode()])
		print("\n".join(bench_lines))
		torch = "lamp"
		apply_torch()
		apply_time()
		label.text = "\n".join(bench_lines)
		label.add_theme_font_size_override("font_size", 20)
	else:
		next_bench()

func _process(delta: float) -> void:
	if view == "hospital" and hospital_node != null:
		Hospital.flicker(hospital_node, Time.get_ticks_msec() / 1000.0)
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
