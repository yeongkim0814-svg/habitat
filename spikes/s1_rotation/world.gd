extends Node3D
const Cylinder = preload("res://spikes/s2_cylinder/cylinder.gd")
const Motion = preload("res://spikes/s1_rotation/motion.gd")
const BASE_BUILDINGS := 512
const LOADS: Array[int] = [1, 4, 16]
const DETAIL_RANGE := 500.0
var habitat := Node3D.new()
var rig := Node3D.new()
var camera := Camera3D.new()
var exact_ball: MeshInstance3D
var fixed_ball: MeshInstance3D
var load_index := 0
var box_mesh := BoxMesh.new()
var tower_mesh := BoxMesh.new()
var detail_state := []
var buildings: Array[Node3D] = []
var details: Array[MeshInstance3D] = []
var label := Label.new()
var time := 0.0
var p := Motion.START
var v := Motion.THROW
var rotating := false
var simplified := false
var overhead := false
var benchmark := false
var cmdline_benchmark := false
var bench_lines: Array[String] = []
var buttons: Dictionary = {}
var frame := 0
var samples: Array[float] = []

func mesh_node(mesh: Mesh, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = material
	return node

func _ready() -> void:
	add_child(habitat)
	add_child(rig)
	rig.add_child(camera)
	camera.current = true
	camera.far = 3000.0
	for i in range(Cylinder.N):
		habitat.add_child(mesh_node(Cylinder.segment(Motion.R, i), Color(0.14 + 0.04 * (i % 2), 0.2, 0.25)))
	box_mesh.size = Vector3(8, 20, 8)
	tower_mesh.size = Vector3(3, 12, 3)
	build_buildings()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	exact_ball = mesh_node(sphere, Color(1, 0.3, 0.2))
	fixed_ball = mesh_node(sphere, Color(0.2, 1, 0.4))
	add_child(exact_ball)
	add_child(fixed_ball)
	add_child(label)
	label.add_theme_font_size_override("font_size", 26)
	build_touch_ui()
	benchmark = "--benchmark" in OS.get_cmdline_user_args()
	cmdline_benchmark = benchmark
	if benchmark and DisplayServer.get_name() == "headless":
		print("RENDER BENCHMARK: 미실행 — headless uses dummy renderer; run with a display/GPU.")
		get_tree().quit()
		return
	if benchmark:
		overhead = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("S1 ready: 32 reused cylinder modules, %d buildings + %d detail meshes" % [buildings.size(), details.size()])

func build_buildings() -> void:
	# Load x1/x4/x16 keeps 16 rows and widens each row (more columns), so every building stays in the opposite district.
	for root in buildings:
		root.free()
	buildings.clear()
	details.clear()
	var columns: int = 32 * LOADS[load_index]
	for i in range(columns * 16):
		var root := Node3D.new()
		var theta := PI / 2.0 + (float(i % columns) / float(columns - 1) - 0.5) * 0.8
		root.position = Cylinder.point(Motion.R - 10.0, theta, (float(i / columns) - 7.5) * 11.0)
		root.basis = Basis(Vector3.BACK, theta + PI / 2.0)
		habitat.add_child(root)
		root.add_child(mesh_node(box_mesh, Color(0.5, 0.6, 0.7)))
		var detail := mesh_node(tower_mesh, Color(0.8, 0.65, 0.3))
		detail.position.y = 16.0
		root.add_child(detail)
		buildings.append(root)
		details.append(detail)
	detail_state = []

func refresh_text() -> String:
	# screen_get_refresh_rate() is unavailable (NaN/-1) on some displays; show '?' instead.
	var hz := DisplayServer.screen_get_refresh_rate()
	return "%.0f" % hz if hz > 0.0 else "?"

func update_detail() -> void:
	# Distance simplification only changes with camera/mode/load, so it is not recomputed every frame (keeps it out of frame timings).
	var cam := camera.global_position
	for i in range(buildings.size()):
		details[i].visible = not simplified or cam.distance_to(buildings[i].global_position) < DETAIL_RANGE

func build_touch_ui() -> void:
	# Touch buttons mirror the R/O/L keys and add an on-screen benchmark (tablet check, no keyboard).
	var layer := CanvasLayer.new()
	add_child(layer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	layer.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -170.0
	row.offset_bottom = -30.0
	row.offset_left = 30.0
	row.offset_right = -30.0
	for entry in [["R", "R 회전/고정"], ["O", "O 머리 위/던지기"], ["L", "L 단순화"], ["P", "부하 x1"], ["B", "측정"]]:
		var button := Button.new()
		button.text = entry[1]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(0, 130)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 30)
		button.pressed.connect(press.bind(entry[0]))
		row.add_child(button)
		buttons[entry[0]] = button

func press(key: String) -> void:
	if benchmark:
		return
	match key:
		"R":
			rotating = not rotating
		"L":
			simplified = not simplified
		"O":
			overhead = not overhead
		"P":
			load_index = (load_index + 1) % LOADS.size()
			buttons["P"].text = "부하 x%d" % LOADS[load_index]
			build_buildings()
		"B":
			start_screen_benchmark()

func start_screen_benchmark() -> void:
	# Same sequence as `-- --benchmark`, but results are shown on screen and the scene keeps running.
	bench_lines.clear()
	samples.clear()
	frame = 0
	overhead = true
	simplified = false
	benchmark = true
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func finish_benchmark() -> void:
	if cmdline_benchmark:
		get_tree().quit()
		return
	benchmark = false
	simplified = false

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or benchmark:
		return
	if event.keycode == KEY_R:
		press("R")
	if event.keycode == KEY_L:
		press("L")
	if event.keycode == KEY_O:
		press("O")

func _physics_process(dt: float) -> void:
	if benchmark:
		return
	# Repeat the same free-flight throw before a floor impact would occur.
	time += dt
	if time > 3.0:
		time = 0.0
		p = Motion.START
		v = Motion.THROW
	else:
		var state := Motion.step(p, v, dt)
		p = state[0]
		v = state[1]

func _process(dt: float) -> void:
	var rotation_angle := Motion.OMEGA * time if rotating else 0.0
	habitat.rotation.z = rotation_angle
	rig.rotation.z = rotation_angle
	camera.position = Vector3(0, -998.3, 0) if overhead else Vector3(0, -998.3, -40)
	# Overhead camera looks along +Y; throw view looks forward/up from the floor.
	camera.basis = Basis(Vector3.RIGHT, PI / 2.0) if overhead else Basis.looking_at(Vector3(25, 25, 45).normalized(), Vector3.UP)
	exact_ball.position = Motion.inertial(time) if rotating else Motion.rotating_position(time)
	fixed_ball.position = p.rotated(Vector3.BACK, rotation_angle)
	var state := [simplified, overhead, load_index]
	if state != detail_state:
		detail_state = state
		update_detail()
	label.text = "R: actual rotation/fixed | L: distance detail | O: overhead/throw | 측정: on-screen benchmark\nmode=%s detail=%s error=%.6fm (red=A green=B)\nFPS=%d frame=%.1fms buildings=%d refresh=%sHz vsync=%d%s" % ["A rotating" if rotating else "B fixed", simplified, p.distance_to(Motion.rotating_position(time)), Engine.get_frames_per_second(), dt * 1000.0, buildings.size(), refresh_text(), DisplayServer.window_get_vsync_mode(), "  [측정 중...]" if benchmark else ""]
	if not bench_lines.is_empty():
		label.text += "\n" + "\n".join(bench_lines)
	if benchmark:
		frame += 1
		# Two fixed-camera phases: 120 warm-up + 600 measured frames each.
		var phase_frame := (frame - 1) % 720
		if phase_frame >= 120:
			samples.append(dt * 1000.0)
		if phase_frame == 719:
			samples.sort()
			var total := 0.0
			for value in samples:
				total += value
			var line := "FRAME buildings=%d detail_simplified=%s mean_ms=%.3f p95_ms=%.3f samples=%d draw_calls=%d refresh_hz=%s vsync=%d" % [buildings.size(), simplified, total / samples.size(), samples[int(samples.size() * 0.95)], samples.size(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), refresh_text(), DisplayServer.window_get_vsync_mode()]
			print(line)
			bench_lines.append(line)
			samples.clear()
			if simplified:
				finish_benchmark()
			else:
				simplified = true
