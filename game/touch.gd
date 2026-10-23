extends Control
## 터치 조작(D32): 화면 왼쪽 절반은 가상 스틱(누른 곳이 중심), 오른쪽 절반은 드래그로 시점.
## 데스크톱 시험용으로 WASD와 방향키도 받는다.
const STICK_RADIUS := 110.0
var player: CharacterBody3D
var stick_finger := -1
var stick_origin := Vector2.ZERO
var stick := Vector2.ZERO
var look_finger := -1
## 화면 높이만큼 끌 때의 회전(rad, D102). 장면이 data/controls.json 값으로 정한다.
var look_turn := PI

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x < size.x * 0.5 and stick_finger < 0:
			stick_finger = event.index
			stick_origin = event.position
		elif event.pressed and look_finger < 0:
			look_finger = event.index
		elif not event.pressed and event.index == stick_finger:
			stick_finger = -1
			stick = Vector2.ZERO
		elif not event.pressed and event.index == look_finger:
			look_finger = -1
	elif event is InputEventScreenDrag:
		if event.index == stick_finger:
			stick = ((event.position - stick_origin) / STICK_RADIUS).limit_length()
		elif event.index == look_finger:
			player.look += -event.relative * look_turn / size.y

func _process(_dt: float) -> void:
	queue_redraw()
	var keys := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)))
	player.move = Vector2(stick.x, -stick.y) if keys == Vector2.ZERO else keys
	player.look.x += (float(Input.is_physical_key_pressed(KEY_LEFT)) - float(Input.is_physical_key_pressed(KEY_RIGHT))) * 0.03

func _draw() -> void:
	if stick_finger >= 0:
		draw_arc(stick_origin, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		draw_circle(stick_origin + stick * STICK_RADIUS, 36.0, Color(1, 1, 1, 0.35))
