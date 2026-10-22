extends Node3D
## P1 회색 박스 장면(D96). 화면은 얇게: 입력 → core 명령, core 상태 → 화면.
const Cylinder = preload("res://core/cylinder.gd")
const Game = preload("res://core/game.gd")
const Schedule = preload("res://core/schedule.gd")
const Player = preload("res://game/player.gd")
const Touch = preload("res://game/touch.gd")
const REACH := 3.0
const COLORS := {"field": Color(0.45, 0.36, 0.2), "gate": Color(0.35, 0.37, 0.4), "crate": Color(0.55, 0.4, 0.2)}

var game: Game
var player: CharacterBody3D
var residents := {}
var sun: DirectionalLight3D
var environment: Environment
var status: Label
var message: Label
var action: Button
var target := {}

func _ready() -> void:
	game = Game.new(Game.load_data())
	build_floor()
	for id in game.data["layout"]["places"]:
		build_place(id, game.data["layout"]["places"][id])
	for id in game.data["residents"]:
		residents[id] = build_resident(game.data["residents"][id]["name"])
	build_light()
	var at: Array = game.data["layout"]["spawn"]
	player = Player.new()
	player.position = Cylinder.surface(at[0], at[1], 0.91)
	add_child(player)
	player.camera.current = true
	build_hud()

func build_floor() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.36, 0.42, 0.3)
	for i in Cylinder.N:
		var mesh := Cylinder.segment(Cylinder.R, i)
		var floor_mesh := MeshInstance3D.new()
		floor_mesh.mesh = mesh
		floor_mesh.material_override = material
		add_child(floor_mesh)
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		collision.shape = mesh.create_trimesh_shape()
		body.add_child(collision)
		add_child(body)

## 장소 = 회색 상자 하나. 밭처럼 낮은 것은 밟고 지나갈 수 있게 충돌을 넣지 않는다.
func build_place(id: String, place: Dictionary) -> void:
	var size := Vector3(place["size"][0], place["size"][1], place["size"][2])
	var body := StaticBody3D.new()
	body.position = Cylinder.surface(place["at"][0], place["at"][1], size.y / 2.0)
	body.basis = Cylinder.upright(body.position)
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = COLORS.get(id, Color(0.62, 0.62, 0.6))
	mesh.material_override = material
	body.add_child(mesh)
	if size.y > 0.5:
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
	var label := Label3D.new()
	label.text = place["name"]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = size.y / 2.0 + 0.6
	label.font_size = 48
	label.pixel_size = 0.01
	body.add_child(label)
	add_child(body)

func build_resident(name_text: String) -> Node3D:
	var node := Node3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	var mesh := MeshInstance3D.new()
	mesh.mesh = capsule
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.55, 0.35)
	mesh.material_override = material
	node.add_child(mesh)
	var label := Label3D.new()
	label.text = name_text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 1.3
	label.font_size = 40
	label.pixel_size = 0.008
	node.add_child(label)
	add_child(node)
	return node

## shortcut: 밤낮은 태양 세기 곡선 하나. 태양 경로(D43, M0 sun.gd)는 회색 박스 이후에 붙인다.
func build_light() -> void:
	sun = DirectionalLight3D.new()
	# 빛이 +Z(게이트 쪽)로 가도록: 마을 입구(-Z)에서 보는 건물 앞면이 밝다.
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(200), 0)
	add_child(sun)
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

func build_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	var touch := Touch.new()
	touch.player = player
	hud.add_child(touch)
	status = Label.new()
	status.position = Vector2(24, 16)
	status.add_theme_font_size_override("font_size", 28)
	hud.add_child(status)
	message = Label.new()
	message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	message.offset_top = -330
	message.offset_bottom = -170
	message.offset_left = -600
	message.offset_right = 600
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 30)
	hud.add_child(message)
	action = Button.new()
	action.focus_mode = Control.FOCUS_NONE
	action.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	action.offset_top = -150
	action.offset_bottom = -40
	action.offset_left = -220
	action.offset_right = 220
	action.add_theme_font_size_override("font_size", 34)
	action.pressed.connect(act)
	hud.add_child(action)

func _process(dt: float) -> void:
	game.advance(dt)
	var hour := game.clock.hour()
	var day := clampf(sin((hour - 6.0) / 13.0 * PI), 0.0, 1.0)
	sun.light_energy = 1.2 * day
	environment.background_color = Color(0.05, 0.07, 0.12).lerp(Color(0.55, 0.7, 0.85), day)
	environment.ambient_light_color = Color(0.15, 0.17, 0.25).lerp(Color(0.62, 0.64, 0.68), day)
	for id in residents:
		var at := Schedule.position(game.data["layout"], game.data["residents"][id], game.clock.seconds, game.clock.scale)
		residents[id].position = Cylinder.surface(at.x, at.y, 0.9)
		residents[id].basis = Cylinder.upright(residents[id].position)
	target = nearest()
	action.visible = not target.is_empty()
	action.text = target.get("label", "")
	status.text = status_text()

## 손이 닿는 가장 가까운 대상: 주민 또는 쓸 수 있는 장소(밭, 상자). 장소는 use_at(없으면 spot)에서 reach(없으면 REACH) 안이면 쓴다.
func nearest() -> Dictionary:
	var best := {}
	var best_distance := REACH
	for id in residents:
		var d: float = residents[id].position.distance_to(player.position)
		if d < best_distance:
			best_distance = d
			best = {"kind": "talk", "id": id, "label": "대화: " + game.data["residents"][id]["name"]}
	var places: Dictionary = game.data["layout"]["places"]
	for id in places:
		if not places[id].has("use"):
			continue
		var at: Array = places[id].get("use_at", places[id]["spot"])
		var d := Cylinder.surface(at[0], at[1], 0.9).distance_to(player.position)
		if d < float(places[id].get("reach", REACH)) and (best.is_empty() or d < best_distance):
			best_distance = d
			best = {"kind": places[id]["use"], "id": id, "label": {"harvest": "수확", "crate": "상자 열기"}[places[id]["use"]]}
	return best

func act() -> void:
	match target.get("kind", ""):
		"harvest":
			message.text = "감자를 캤다." if game.harvest() else "아직 여문 것이 없다. 해가 뜨면 다시 여문다."
		"crate":
			var got := game.open_crate()
			message.text = "상자: %s" % [got] if not got.is_empty() else "상자가 비었다. 해가 뜨면 다시 찬다."
		"talk":
			message.text = talk(target["id"])

## 납품 가능하면 완료, 받을 수 있으면 수락. 대사는 4단계 대화 화면 전까지 글로 띄운다.
func talk(giver: String) -> String:
	var id := game.offer(giver)
	if id == "":
		return game.data["residents"][giver]["name"] + ": 지금은 부탁할 게 없어."
	var lines: Array = game.complete(id) if game.status(id) == "ready" else game.accept(id)
	return "\n".join(lines)

func status_text() -> String:
	var lines := ["%02d:%02d  %d일째  돈 %d" % [int(game.clock.hour()), int(fmod(game.clock.hour(), 1.0) * 60), game.clock.day() + 1, game.money]]
	for row in game.journal():
		lines.append("%s %s %d/%d%s" % [game.data["residents"][row["giver"]]["name"], game.data["items"][row["item"]]["name"],
			row["have"], row["need"], "  (납품 가능)" if row["ready"] else ""])
	if not game.items.is_empty():
		lines.append("소지품: " + ", ".join(game.items.keys().map(func(k): return "%s %d" % [game.data["items"][k]["name"], game.items[k]])))
	return "\n".join(lines)
