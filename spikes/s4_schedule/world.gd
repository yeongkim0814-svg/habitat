extends Node3D
const Cylinder = preload("res://spikes/s2_cylinder/cylinder.gd")
const Controller = preload("res://spikes/s4_schedule/controller.gd")
const Schedule = preload("res://spikes/s4_schedule/schedule.gd")
var player: CharacterBody3D
var clock := 28700.0
var schedule = Schedule.new()
var residents: Array[MeshInstance3D] = []
var label: Label
var draw_residents := true

func _ready() -> void:
	for i in Cylinder.N:
		var mesh := Cylinder.segment(Cylinder.R, i)
		var floor_mesh := MeshInstance3D.new()
		floor_mesh.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.2 + 0.02 * (i % 2), 0.28, 0.33)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		floor_mesh.material_override = material
		add_child(floor_mesh)
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		collision.shape = mesh.create_trimesh_shape()
		body.add_child(collision)
		add_child(body)
	player = Controller.new()
	player.position = Cylinder.point(Cylinder.R - 0.91, -PI / 2.0, 0)
	add_child(player)
	player.camera.current = true
	for i in 3:
		var resident := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.3
		capsule.height = 1.8
		resident.mesh = capsule
		var material := StandardMaterial3D.new()
		material.albedo_color = [Color.CORAL, Color.LIME_GREEN, Color.SKY_BLUE][i]
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		resident.material_override = material
		residents.append(resident)
		add_child(resident)
	var hud := CanvasLayer.new()
	label = Label.new()
	hud.add_child(label)
	add_child(hud)

func _process(dt: float) -> void:
	clock += dt
	for i in residents.size():
		# Same absolute-time evaluation for visible and offscreen residents;
		# no accumulated movement or catch-up teleport when becoming visible.
		var resident := residents[i]
		resident.position = schedule.position_at(i, clock)
		var up := -Cylinder.down(resident.position)
		resident.basis = Basis(Vector3.BACK.cross(up), up, Vector3.FORWARD).orthonormalized()
		resident.visible = draw_residents
	label.text = "S4 fixed world | t=%.1f s | 3 residents | move/look via set_input()" % clock

func set_input(move_value: Vector2, look_value: Vector2) -> void:
	player.move = move_value.limit_length()
	player.look += look_value
