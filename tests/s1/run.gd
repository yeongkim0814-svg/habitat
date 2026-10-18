extends SceneTree
const Motion = preload("res://spikes/s1_rotation/motion.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)

func _initialize() -> void:
	print("R=1000m omega=%.9f rad/s; throw=(12,20,3)m/s; duration=3s" % Motion.OMEGA)
	check(absf(Motion.acceleration(Vector3(1000, 0, 0), Vector3.ZERO).x - 9.81) < 0.00001, "outward gravity")
	check(Motion.spin(Vector3(1, 0, 0)).y > 0, "rotation sign")
	print("Hz | max_A_vs_B(m) | no_coriolis_at_3s(m)")
	for hz in [60, 120, 240]:
		var dt: float = 1.0 / hz
		var p := Motion.START
		var v := Motion.THROW
		var no_p := p
		var no_v := v
		var worst := 0.0
		for i in range(3 * hz):
			var state := Motion.step(p, v, dt)
			p = state[0]
			v = state[1]
			var no_state := Motion.step(no_p, no_v, dt, false)
			no_p = no_state[0]
			no_v = no_state[1]
			worst = maxf(worst, p.distance_to(Motion.rotating_position((i + 1) * dt)))
			if hz == 60 and (i + 1) % hz == 0:
				print("t=%ds A=%s B=%s" % [(i + 1) / hz, Motion.rotating_position((i + 1) * dt), p])
		print("%d | %.9f | %.6f" % [hz, worst, no_p.distance_to(Motion.rotating_position(3.0))])
		check(worst < 0.01, "frame equivalence < 1cm")
		check(no_p.distance_to(Motion.rotating_position(3.0)) > 1.0, "Coriolis must matter")
		check(Vector2(p.x, p.y).length() < Motion.R, "throw still inside cylinder")
	print("PASS: radial gravity, rotation sign, A/B equivalence, Coriolis sensitivity, free-flight bounds" if failures == 0 else "FAIL: %d" % failures)
	quit(0 if failures == 0 else 1)
