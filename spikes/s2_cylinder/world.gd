extends Node3D
const Cylinder = preload("res://spikes/s2_cylinder/cylinder.gd")
var angle := -PI / 2.0
var axis_z := 0.0
var yaw := 0.0
var pitch := 0.0
var player := Node3D.new()
var camera := Camera3D.new()

func _ready() -> void:
	for i in range(Cylinder.N):
		var module := MeshInstance3D.new()
		module.mesh = Cylinder.segment(Cylinder.R, i)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.18 + 0.08 * (i % 2), 0.32, 0.4)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		module.material_override = material
		add_child(module)
	add_child(player)
	player.add_child(camera)
	camera.current = true
	camera.far = 4000.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var label := Label.new()
	label.text = "S2 R=1000m L=200m | WASD: walk | Mouse: look | Esc: release\nAnalytic surface constraint; no collision/gravity solver."
	add_child(label)
	for radius in [250.0, 500.0, 1000.0]:
		print("R=", radius, " ", Cylinder.measure(radius))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.002
		pitch = clampf(pitch - event.relative.y * 0.002, -1.4, 1.4)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	var forward := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	var side := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var walk := Vector2(side, forward).limit_length()
	var circumferential := walk.x * cos(yaw) - walk.y * sin(yaw)
	var axial := -walk.x * sin(yaw) - walk.y * cos(yaw)
	angle += circumferential * 8.0 * delta / Cylinder.R
	axis_z = clampf(axis_z + axial * 8.0 * delta, -Cylinder.L / 2.0 + 1.0, Cylinder.L / 2.0 - 1.0)
	player.position = Cylinder.point(Cylinder.R - 1.7, angle, axis_z)
	var up := -Cylinder.down(player.position)
	var right := Vector3(-sin(angle), cos(angle), 0)
	player.basis = Basis(right, up, Vector3.BACK) * Basis(Vector3.UP, yaw)
	camera.rotation.x = pitch
