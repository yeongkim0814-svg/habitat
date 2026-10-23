extends CharacterBody3D
## 1인칭 플레이어(D11, D32). spikes/s4_schedule/controller.gd 방식: 매 물리 프레임 up을 갱신하고
## 회전계 가속도(D17)를 더한 뒤 엔진 충돌로 걷는다.
const Cylinder = preload("res://core/cylinder.gd")
const Motion = preload("res://core/motion.gd")
const Gait = preload("res://core/gait.gd")
## 스틱 벡터. 길이(기울기)는 gait가 단계 속도로 바꾼다(D101).
var move := Vector2.ZERO
var gait: Gait
var look := Vector2.ZERO
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
	basis = Basis(right, up_direction, -forward).orthonormalized()
	camera.rotation.x = pitch
	gait.update(move.length())
	var desired := (right * move.x + forward * move.y).normalized() * gait.speed()
	velocity = desired + up_direction * velocity.dot(up_direction)
	velocity += Motion.acceleration(position, velocity) * dt
	move_and_slide()
