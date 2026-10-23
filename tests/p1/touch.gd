extends RefCounted
## 실제 터치 이벤트로 이동·시점을 확인한다(#62: 터치 영역 크기가 0이라 이동·시점이 안 되던 버그).
## t는 tests/p1/run.gd(SceneTree)이며 check, open_scene, SCENE_SAVE를 쓴다.

static func finger(t: SceneTree, index: int, at: Vector2, pressed := true) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = at
	e.pressed = pressed
	t.root.push_input(e)

static func drag(t: SceneTree, index: int, from: Vector2, by: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = from + by
	e.relative = by
	t.root.push_input(e)

static func run(t: SceneTree) -> void:
	DirAccess.remove_absolute(t.SCENE_SAVE)
	t.root.size = Vector2i(1920, 1200)
	var scene: Node3D = t.open_scene()
	for i in 10:
		await t.physics_frame
	var screen := t.root.get_visible_rect().size
	var pad: Control = scene.find_children("*", "Control", true, false).filter(
		func(c): return c.get_script() == preload("res://game/touch.gd"))[0]
	t.check(pad.get_global_rect().size == screen, "touch area covers the screen %s" % [pad.get_global_rect().size])
	var start: Vector3 = scene.player.position
	var yaw: float = scene.player.yaw
	var left := Vector2(screen.x * 0.2, screen.y * 0.8)
	var right := Vector2(screen.x * 0.8, screen.y * 0.5)
	finger(t, 0, left)
	drag(t, 0, left, Vector2(0, -30))
	finger(t, 1, right)
	drag(t, 1, right, Vector2(-10, 0))
	await t.process_frame
	await t.process_frame
	t.check(scene.player.move.y > 0.2, "left drag up walks forward (move=%s)" % [scene.player.move])
	for i in 30:
		await t.physics_frame
	t.check(start.distance_to(scene.player.position) > 0.3 and scene.player.yaw != yaw, "player moves and turns by touch")
	finger(t, 0, left, false)
	finger(t, 1, right, false)
	await t.process_frame
	await t.process_frame
	t.check(scene.player.move == Vector2.ZERO, "releasing the stick stops walking")
	scene.queue_free()
	DirAccess.remove_absolute(t.SCENE_SAVE)
