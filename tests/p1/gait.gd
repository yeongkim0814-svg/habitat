extends RefCounted
## 이동 단계(D101): 기울기 → 정지 / 조용히 걷기 / 걷기 / 달리기, 경계의 여유 구간. t는 tests/p1/run.gd.
const Game = preload("res://core/game.gd")
const Gait = preload("res://core/gait.gd")

static func run(t: SceneTree) -> void:
	var c: Dictionary = Game.load_data()["controls"]
	var g := Gait.new(c)
	t.check([0.1, 0.3, 0.7, 1.0].map(func(x): return Gait.new(c).update(x)) == [0, 1, 2, 3], "tilt 0.1/0.3/0.7/1.0 -> stop/quiet/walk/run")
	g.update(0.3)
	t.check(g.update(0.52) == 1 and g.update(0.55) == 2, "going up needs edge + hysteresis (0.5 + 0.04)")
	t.check(g.update(0.48) == 2 and g.update(0.45) == 1, "going down needs edge - hysteresis")
	t.check(g.update(0.0) == 0 and g.speed() == 0.0, "letting go stops")
	g.update(1.0)
	t.check(g.speed() == 6.0, "full tilt runs at 6 m/s")
	t.check(Gait.validate(c).is_empty(), "shipped controls are valid")
	var bad := c.duplicate(true)
	bad["edges"] = [0.9, 0.5]
	bad["speeds"] = [1.0]
	t.check(Gait.validate(bad).size() == 2, "unsorted edges and wrong speed count are reported")
