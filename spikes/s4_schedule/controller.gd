extends CharacterBody3D
const Cylinder = preload("res://spikes/s2_cylinder/cylinder.gd")
const Motion = preload("res://spikes/s1_rotation/motion.gd")
var move := Vector2.ZERO
var look := Vector2.ZERO
var speed := 6.0
var yaw := 0.0
var pitch := 0.0
var camera: Camera3D

func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	shape.shape = capsule
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 0.65
	camera.far = 3000.0
	add_child(camera)
	floor_snap_length = 0.5
	safe_margin = 0.005
	floor_stop_on_slope = true

func _physics_process(dt: float) -> void:
	up_direction = -Cylinder.down(position)
	yaw += look.x
	pitch = clampf(pitch + look.y, -1.4, 1.4)
	look = Vector2.ZERO
	var forward := Vector3.BACK.rotated(up_direction, yaw)
	var right := forward.cross(up_direction).normalized()
	# Capsule local +Y is inward, camera local -Z follows forward.
	basis = Basis(right, up_direction, -forward).orthonormalized()
	camera.rotation.x = pitch
	var desired := (right * move.x + forward * move.y).limit_length() * speed
	velocity = desired + up_direction * velocity.dot(up_direction)
	velocity += Motion.acceleration(position, velocity) * dt
	move_and_slide()
