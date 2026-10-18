extends SceneTree
const World = preload("res://spikes/s4_schedule/world.gd")
const Surface = preload("res://spikes/s4_schedule/surface.gd")
const Schedule = preload("res://spikes/s4_schedule/schedule.gd")
const Cylinder = preload("res://spikes/s2_cylinder/cylinder.gd")
var passed := 0
var failed := 0

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS ", message)
	else:
		failed += 1
		printerr("FAIL ", message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var schedule := Schedule.new()
	for i in 3:
		var events: Array = schedule.residents[i]["events"]
		for j in events.size():
			var t := float(events[j]["time"])
			var previous := posmod(j - 1, events.size())
			check(schedule.position_at(i, t).distance_to(Surface.point(schedule.cell(events[previous]), 0.9)) < 0.001,
				"resident %d departure at %.0f" % [i, t])
			check(schedule.position_at(i, t + 3600).distance_to(Surface.point(schedule.cell(events[j]), 0.9)) < 0.001,
				"resident %d destination at %.0f" % [i, t + 3600])
			check(schedule.position_at(i, t + 100).distance_to(schedule.position_at(i, t + 86500)) < 0.001,
				"resident %d daily wrap" % i)
	var seam := Surface.route(Vector2i(31, 2), Vector2i(1, 2))
	check(seam.size() == 3, "periodic seam takes two edges")
	var detour := Surface.route(Vector2i(3, 4), Vector2i(5, 4))
	check(detour.size() == 5, "blocked cell takes four-edge detour")
	var avoids := true
	for p in detour:
		avoids = avoids and p.distance_to(Surface.point(Surface.BLOCKED, 0.9)) > 1.0
	check(avoids, "route excludes blocked cell")
	var midpoint := Surface.sample(seam, 0.25)
	check(absf(Vector2(midpoint.x, midpoint.y).length() - 999.1) < 0.001,
		"path interpolation follows surface rather than interior chord")
	check(schedule.position_at(1, 28900).distance_to(Surface.sample(seam, 300.0 / Surface.length(seam))) < 0.001,
		"in-transit position uses distance and speed")
	var world := World.new()
	root.add_child(world)
	await physics_frame
	var player: CharacterBody3D = world.player
	for i in 120:
		await physics_frame
	var standing_origin := player.position
	for i in 300:
		await physics_frame
	check(player.is_on_floor() and player.position.distance_to(standing_origin) < 0.02,
		"standing contact and drift <2cm over 5s")
	for walk_speed in [80.0, 6.0]:
		# High-speed traversal covers every triangle and all 32 module boundaries.
		player.speed = walk_speed
		world.set_input(Vector2(-1 if walk_speed == 80.0 else 1, 0), Vector2.ZERO)
		var previous := atan2(player.position.y, player.position.x)
		var angle := 0.0
		var max_gap := 0.0
		var min_alignment := 1.0
		var lost_contact := 0
		var frames := 0
		while angle < TAU and frames < 80000:
			await physics_frame
			var current := atan2(player.position.y, player.position.x)
			angle += absf(wrapf(current - previous, -PI, PI))
			previous = current
			frames += 1
			max_gap = maxf(max_gap, absf(Vector2(player.position.x, player.position.y).length() - 999.1))
			if not player.is_on_floor():
				lost_contact += 1
			else:
				min_alignment = minf(min_alignment, player.get_floor_normal().dot(-Cylinder.down(player.position)))
		check(angle >= TAU, "walk completes 360 degrees")
		check(lost_contact == 0, "floor contact on every walking frame")
		check(max_gap < 0.03, "radial floor gap <3cm")
		check(min_alignment > 0.999, "inward floor normal opposes outward down")
		world.set_input(Vector2.ZERO, Vector2.ZERO)
		var end := player.position
		for i in 300:
			await physics_frame
		check(player.is_on_floor() and player.position.distance_to(end) < 0.05,
			"stops without sliding >5cm")
		print("orbit speed=%.1f frames=%d angle=%.6f lost_contact=%d max_gap=%.6f normal_dot=%.6f" % [walk_speed, frames, angle, lost_contact, max_gap, min_alignment])
	world.clock = 28900.0
	world.draw_residents = false
	world._process(0.0)
	var hidden := world.residents[1].position
	world.draw_residents = true
	world._process(0.0)
	check(hidden.distance_to(world.residents[1].position) < 0.001,
		"offscreen and visible positions agree at same time")
	print("S4: %d passed, %d failed" % [passed, failed])
	world.queue_free()
	quit(0 if failed == 0 else 1)
