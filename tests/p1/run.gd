extends SceneTree
const Game = preload("res://core/game.gd")
const Clock = preload("res://core/clock.gd")
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
	test_clock()
	test_playthrough()
	test_save()
	test_data_only_quest()
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func test_clock() -> void:
	var c := Clock.new(7200.0, 6.0, 8.0)
	check(is_equal_approx(c.hour(), 8.0), "clock starts at 08:00")
	check(c.advance(3600.0) == 0, "half a real hour = 12 game hours, no sunrise (08 -> 20)")
	check(is_equal_approx(c.hour(), 20.0), "clock at 20:00")
	check(c.advance(3000.0) == 1 and c.day() == 1, "20:00 + 15 h crosses 06:00, counts one sunrise")
	check(c.advance(7200.0 * 3) == 3, "three days = three sunrises")

func test_playthrough() -> void:
	var g := Game.new(Game.load_data())
	check(g.validate().is_empty(), "shipped data has no broken references %s" % [g.validate()])
	check(g.status("farmer_harvest") == "available" and g.status("doctor_supplies") == "locked", "only the farmer quest is open")
	check(g.offer("farmer") == "farmer_harvest" and g.offer("doctor") == "", "farmer offers, doctor waits")
	check(g.complete("farmer_harvest").is_empty(), "cannot complete before accepting")
	var start := g.accept("farmer_harvest")
	check(start.size() > 0 and g.accept("farmer_harvest").is_empty(), "accept returns start dialogue once")
	for i in 4:
		g.harvest()
	check(g.journal() == [{"id": "farmer_harvest", "giver": "farmer", "item": "crop", "have": 4, "need": 5, "ready": false}],
		"journal shows 4/5")
	g.harvest()
	check(g.status("farmer_harvest") == "ready" and g.offer("farmer") == "farmer_harvest", "5/5 is ready to deliver")
	g.harvest()
	check(not g.harvest() and g.count("crop") == 6, "field holds 6 crops")
	check(g.complete("farmer_harvest").size() > 0, "complete returns done dialogue")
	check(g.count("crop") == 1 and g.money == 50 and g.status("farmer_harvest") == "done", "5 crops paid for 50")
	check(g.status("doctor_supplies") == "available", "doctor quest unlocks")
	g.accept("doctor_supplies")
	var got := g.open_crate()
	check(got == {"med_supplies": 3, "suit_parts": 3} and g.open_crate().is_empty(), "crate gives once")
	g.complete("doctor_supplies")
	check(g.favor.get("doctor") == 1 and g.money == 150, "doctor favor +1")
	g.accept("armor_parts")
	check(g.status("armor_parts") == "ready", "parts already carried make it ready")
	g.complete("armor_parts")
	check(g.slots == ["filter", "plate", "storage", "plate_2"] and g.favor.get("armor") == 1, "armor quest unlocks plate_2 (D94)")
	check(g.journal().is_empty() and g.offer("armor") == "", "nothing left")
	g.advance(7200.0)
	check(g.field == 6 and g.crate.size() == 2, "sunrise refills field and crate")

func test_save() -> void:
	var path := "user://p1_test_save.json"
	var g := Game.new(Game.load_data())
	g.accept("farmer_harvest")
	g.harvest()
	g.harvest()
	g.advance(100.0)
	check(g.save(path), "save writes")
	var h := Game.new(Game.load_data())
	check(h.load(path), "load reads")
	check(h.to_dict() == g.to_dict(), "round trip keeps state")
	check(h.journal()[0]["have"] == 2 and h.harvest() and h.status("farmer_harvest") == "active", "loaded game continues")
	var before := h.to_dict()
	var wrong := h.to_dict()
	wrong["items"] = null
	var wrong_slots := h.to_dict()
	wrong_slots["slots"] = {"a": 1}
	var wrong_quest := h.to_dict()
	wrong_quest["quests"] = {"farmer_harvest": 3}
	var bads := ["{broken", JSON.stringify({"version": 99}), JSON.stringify({"version": 1, "money": 5}),
		JSON.stringify(wrong), JSON.stringify(wrong_slots), JSON.stringify(wrong_quest)]
	for bad in bads:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(bad)
		f.close()
		check(not h.load(path) and h.to_dict() == before, "rejects bad save %s" % bad.left(20))
	check(h.save(path) and h.load(path) and h.to_dict() == before, "good save still loads after rejections")
	check(not h.load("user://missing.json"), "missing file is rejected")
	DirAccess.remove_absolute(path)

## ROADMAP P1 중단 조건: 퀘스트 하나를 데이터만으로 추가할 수 있어야 한다.
func test_data_only_quest() -> void:
	var d := Game.load_data()
	d["quests"].append({"id": "farmer_more", "giver": "farmer", "item": "crop", "count": 2, "requires": ["farmer_harvest"],
		"start": "more_start", "done": "more_done", "reward": {"money": 10, "favor": 2}})
	d["dialogues"]["more_start"] = ["두 개만 더."]
	d["dialogues"]["more_done"] = ["고마워."]
	var g := Game.new(d)
	check(g.validate().is_empty(), "added quest validates")
	g.accept("farmer_harvest")
	for i in 6:
		g.harvest()
	g.complete("farmer_harvest")
	check(g.offer("farmer") == "farmer_more" and g.accept("farmer_more") == ["두 개만 더."], "added quest is offered")
	g.advance(7200.0)
	g.harvest()
	check(g.complete("farmer_more") == ["고마워."] and g.favor["farmer"] == 2 and g.money == 60, "added quest completes")
	d["quests"].append({"id": "bad", "giver": "nobody", "item": "rock", "count": 1, "requires": ["nope"],
		"start": "x", "done": "y", "reward": {}})
	check(Game.new(d).validate().size() == 5, "broken quest reports 5 errors")
