extends Node3D
## M0 look-dev scene: same stage in three render styles. Touch buttons switch look/view and run a frame-time benchmark.
const Looks = preload("res://spikes/m0_look/looks.gd")
const Stage = preload("res://spikes/m0_look/stage.gd")
const Cylinder = preload("res://spikes/s2_cylinder/cylinder.gd")
const VIEWS: Array[String] = ["street", "field", "overhead"]
const VIEW_NAMES := {"street": "거리", "field": "들판", "overhead": "머리 위"}
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
var look := "psx"
var view := "street"
var bench_queue: Array[String] = []
var bench_samples: Array[float] = []
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
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, 28, 0)
	sun.light_energy = 1.1
	scene.add_child(sun)
	camera.far = 3500.0
	camera.fov = 75.0
	scene.add_child(camera)
	camera.current = true
	build_ui()
	var shot := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot = arg.substr(7)
	if shot != "":
		var parts := shot.split(":")
		look = parts[0]
		view = parts[1]
		shot_path = parts[2]
		shot_frames = 8
		ui.visible = false
	rebuild()

func rebuild() -> void:
	for child in content.get_children():
		child.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var floor_root := Node3D.new()
	floor_root.position = Stage.origin() + Vector3(0, Stage.FLOOR_LIFT, 0)
	content.add_child(floor_root)
	Stage.street(look, rng, floor_root)
	Stage.field(look, rng, floor_root)
	var ring := Node3D.new()
	content.add_child(ring)
	for i in range(Cylinder.N):
		var seg := MeshInstance3D.new()
		seg.mesh = Cylinder.segment(Cylinder.R, i)
		seg.material_override = Looks.material(look, "street")
		seg.scale.z = Stage.RING_HALF_LENGTH * 2.0 / Cylinder.L
		ring.add_child(seg)
	Stage.overhead(look, rng, ring)
	env_node.environment = Looks.environment(look)
	container.stretch_shrink = Looks.SHRINK[look]
	place_camera()
	label.text = "%s / %s" % [Looks.NAMES[look], VIEW_NAMES[view]]

func place_camera() -> void:
	var base := Stage.origin() + Vector3(0, Stage.FLOOR_LIFT, 0)
	match view:
		"street":
			camera.position = base + Vector3(0, 1.7, -92)
			camera.look_at(base + Vector3(0, 3.0, -20))
		"field":
			camera.position = base + Vector3(0, 1.7, 4)
			camera.look_at(base + Vector3(0, 2.0, 60))
		_:
			camera.position = base + Vector3(0, 1.7, -30)
			camera.look_at(base + Vector3(150, 900, 0))
	# The far side is 2 km away: ground fog would wash it out, so fog is only for ground-level views.
	env_node.environment.fog_enabled = view != "overhead"

func build_ui() -> void:
	add_child(ui)
	ui.add_child(label)
	label.position = Vector2(30, 20)
	label.add_theme_font_size_override("font_size", 30)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	ui.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -150.0
	row.offset_bottom = -30.0
	row.offset_left = 30.0
	row.offset_right = -30.0
	for id in Looks.IDS:
		add_button(row, Looks.NAMES[id], set_look.bind(id))
	for id in VIEWS:
		add_button(row, VIEW_NAMES[id], set_view.bind(id))
	add_button(row, "측정", start_bench)

func add_button(row: HBoxContainer, text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 120)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(action)
	row.add_child(b)

func set_look(id: String) -> void:
	if bench_queue.is_empty():
		look = id
		rebuild()

func set_view(id: String) -> void:
	if bench_queue.is_empty():
		view = id
		place_camera()
		label.text = "%s / %s" % [Looks.NAMES[look], VIEW_NAMES[view]]

func start_bench() -> void:
	if not bench_queue.is_empty():
		return
	bench_lines.clear()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
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
	bench_frame = 0

func finish_bench_item() -> void:
	var sorted := bench_samples.duplicate()
	sorted.sort()
	var mean := 0.0
	for s in bench_samples:
		mean += s
	mean /= bench_samples.size()
	var p95: float = sorted[int(sorted.size() * 0.95)]
	var line := "M0 look=%s view=%s mean_ms=%.3f p95_ms=%.3f samples=%d refresh_hz=%s" % [look, view, mean, p95, bench_samples.size(), "%.0f" % DisplayServer.screen_get_refresh_rate()]
	print(line)
	bench_lines.append(line)
	bench_queue.remove_at(0)
	if bench_queue.is_empty():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		label.text = "\n".join(bench_lines)
		label.add_theme_font_size_override("font_size", 20)
	else:
		next_bench()

func _process(delta: float) -> void:
	if not bench_queue.is_empty():
		bench_frame += 1
		if bench_frame > BENCH_SKIP:
			bench_samples.append(delta * 1000.0)
		if bench_samples.size() >= BENCH_FRAMES:
			finish_bench_item()
	if shot_frames > 0:
		shot_frames -= 1
		if shot_frames == 0:
			get_viewport().get_texture().get_image().save_png(shot_path)
			print("M0 shot saved: ", shot_path)
			get_tree().quit()
