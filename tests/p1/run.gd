extends SceneTree
const Game = preload("res://core/game.gd")
const Clock = preload("res://core/clock.gd")
const Shop = preload("res://core/shop.gd")
const Schedule = preload("res://core/schedule.gd")
const Cylinder = preload("res://core/cylinder.gd")
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
	test_shop()
	test_schedule()
	await test_greybox()
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
	d["shops"]["armor"]["sell"]["rock"] = 1
	check(Game.new(d).validate().size() == 6, "unknown shop item is reported")

func test_shop() -> void:
	var g := Game.new(Game.load_data())
	check(not Shop.buy(g, "armor", "filter_basic"), "no money, no purchase")
	g.money = 100
	check(Shop.buy(g, "armor", "filter_basic") and g.money == 60 and g.count("filter_basic") == 1, "buy filter for 40")
	check(not Shop.buy(g, "armor", "medkit"), "armor merchant does not sell medkits")
	check(Shop.sell(g, "armor", "filter_basic") and g.money == 75 and g.count("filter_basic") == 0, "sell filter back for 15")
	check(not Shop.sell(g, "armor", "filter_basic"), "cannot sell what you do not have")
	check(not Shop.sell(g, "doctor", "suit_parts"), "doctor does not buy suit parts")
	check(Shop.offers(g, "armor").map(func(o): return o["id"]) == ["armor_filter"], "favor 0 shows only the filter barter")
	for i in 6:
		g.harvest()
	check(not Shop.barter(g, "armor", "armor_plate"), "locked barter is refused")
	check(Shop.barter(g, "armor", "armor_filter") and g.count("crop") == 2 and g.count("filter_basic") == 1, "4 crops -> filter")
	g.add("crop", 10)
	check(not Shop.barter(g, "armor", "armor_filter") and Shop.offers(g, "armor")[0]["left"] == 0, "daily limit 1 at favor 0")
	g.favor["armor"] = 1
	check(Shop.offers(g, "armor").size() == 2 and Shop.offers(g, "armor")[0]["left"] == 1, "favor 1 raises stock and opens plate barter")
	check(not Shop.barter(g, "armor", "armor_plate"), "plate barter needs parts and supplies")
	g.open_crate()
	check(Shop.barter(g, "armor", "armor_plate") and g.count("plate_basic") == 1 and g.count("suit_parts") == 1, "parts + supplies -> plate")
	var path := "user://p1_shop_save.json"
	g.save(path)
	var h := Game.new(Game.load_data())
	check(h.load(path) and h.barter_used == g.barter_used, "barter use survives save")
	var cheat := g.to_dict()
	cheat["barter_used"] = {"armor_filter": -1}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(cheat))
	f.close()
	check(not h.load(path), "negative barter usage is rejected")
	DirAccess.remove_absolute(path)
	g.advance(7200.0)
	check(g.barter_used.is_empty() and Shop.offers(g, "armor")[0]["left"] == 2, "sunrise resets daily barter")

func test_schedule() -> void:
	var d := Game.load_data()
	check(Schedule.validate(d).is_empty(), "shipped schedules reference known places in order")
	var farmer: Dictionary = d["residents"]["farmer"]
	var lay: Dictionary = d["layout"]
	var field := Schedule.spot(lay, "field")
	var house := Schedule.spot(lay, "farmer_house")
	check(Schedule.position(lay, farmer, 12 * 3600.0, 12.0) == field, "farmer in the field at noon")
	check(Schedule.position(lay, farmer, 2 * 3600.0, 12.0) == house, "farmer at home at 02:00")
	var walk := field.distance_to(house) / 1.4 * 12.0
	var mid := Schedule.position(lay, farmer, 19 * 3600.0 + walk / 2.0, 12.0)
	check(mid.distance_to((field + house) / 2.0) < 0.01, "farmer halfway home after half the walk")
	check(Schedule.position(lay, farmer, 19 * 3600.0 + walk + 1.0, 12.0) == house, "farmer arrives home")
	check(Schedule.position(lay, d["residents"]["armor"], 3 * 3600.0, 12.0) == Schedule.spot(lay, "armor_shop"), "merchant stays at the shop")
	d["residents"]["farmer"]["schedule"].append({"hour": 3, "place": "moon"})
	check(Schedule.validate(d).size() == 2, "unknown place and out-of-order hour are reported")

const SCENE_SAVE := "user://p1_greybox_test.json"

func open_scene() -> Node3D:
	var scene: Node3D = load("res://game/greybox.tscn").instantiate()
	scene.save_path = SCENE_SAVE
	root.add_child(scene)
	return scene

## 대상 옆으로 옮기고 행동 버튼을 누른다.
func act_at(scene: Node3D, at: Vector3) -> void:
	scene.player.position = at
	await process_frame
	await process_frame
	scene.act()

func test_greybox() -> void:
	DirAccess.remove_absolute(SCENE_SAVE)
	var scene := open_scene()
	for i in 30:
		await physics_frame
	var r := Vector2(scene.player.position.x, scene.player.position.y).length()
	check(absf(r - (Cylinder.R - 0.9)) < 0.05, "player stands on the cylinder floor (r=%.3f)" % r)
	var crate := Schedule.spot(scene.game.data["layout"], "crate")
	scene.player.position = Cylinder.surface(crate.x, crate.y, 0.9)
	await process_frame
	await process_frame
	check(scene.target.get("kind") == "crate" and scene.action.visible, "crate is the action target next to it")
	scene.act()
	check(scene.game.count("med_supplies") == 3, "action button opens the crate")
	var farmer: Node3D = scene.residents["farmer"]
	scene.player.position = farmer.position + Cylinder.upright(farmer.position).x * 1.0
	await process_frame
	await process_frame
	check(scene.target.get("id") == "farmer", "farmer is the action target next to him")
	await test_greybox_quest(scene, farmer)
	await test_greybox_shop(scene)
	await test_greybox_save(scene)

func test_greybox_quest(scene: Node3D, farmer: Node3D) -> void:
	scene.act()
	check(scene.dialogue.visible and scene.dialogue.text.text.contains("배급") and scene.game.status("farmer_harvest") == "available",
		"talking opens the start dialogue without accepting yet")
	await process_frame
	await process_frame
	check(not scene.action.visible and not scene.quests.visible, "world buttons hide while a screen is open")
	scene.dialogue.next()
	check(scene.dialogue.choices.keys() == ["수락", "나중에"] and scene.dialogue.buttons.get_child_count() == 2, "last line offers accept / later")
	scene.dialogue.choose("나중에")
	check(not scene.dialogue.visible and scene.game.status("farmer_harvest") == "available", "later keeps the quest open")
	scene.act()
	scene.dialogue.next()
	scene.dialogue.choose("수락")
	check(scene.game.status("farmer_harvest") == "active", "accept starts the quest")
	scene.journal.open(scene.game, scene.restart)
	check(scene.journal.rows.get_child(0).text.contains("감자 0/5"), "quest screen shows 0/5")
	for i in 5:
		scene.game.harvest()
	scene.journal.open(scene.game, scene.restart)
	check(scene.journal.rows.get_child(0).text.contains("5/5  (납품 가능)"), "quest screen marks ready")
	scene.journal.hide()
	await act_at(scene, farmer.position + Cylinder.upright(farmer.position).x * 1.0)
	check(scene.dialogue.visible and scene.game.status("farmer_harvest") == "done" and scene.game.money == 50, "delivery opens the done dialogue and pays")
	scene.dialogue.choose("닫기")

func test_greybox_save(scene: Node3D) -> void:
	scene.save()
	var saved: Dictionary = scene.game.to_dict()
	scene.queue_free()
	await process_frame
	scene = open_scene()
	check(JSON.stringify(scene.game.to_dict(), "", true) == JSON.stringify(saved, "", true), "reopened scene continues from the save")
	scene.journal.open(scene.game, scene.restart)
	scene.journal.ask_restart()
	check(scene.journal.visible and scene.game.money == saved["money"], "restart needs a second tap")
	scene.journal.ask_restart()
	check(scene.game.money == 0 and scene.game.status("farmer_harvest") == "available", "second tap restarts")
	scene.queue_free()
	var f := FileAccess.open(SCENE_SAVE, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	scene = open_scene()
	check(scene.game.money == 0 and scene.message.text.contains("새로"), "broken save starts a new game with a notice")
	scene.queue_free()
	DirAccess.remove_absolute(SCENE_SAVE)

func test_greybox_shop(scene: Node3D) -> void:
	var armor: Node3D = scene.residents["armor"]
	scene.player.position = armor.position + Cylinder.upright(armor.position).x * 1.0
	await process_frame
	await process_frame
	check(scene.trade.visible, "trade button next to the armor merchant")
	scene.open_shop()
	var shop = scene.shop
	check(shop.visible and shop.rows.get_child_count() == 2, "shop opens on the buy tab with 2 items")
	var before: int = scene.game.money
	check(not shop.run("buy", "plate_basic") and scene.game.money == before, "too expensive: refused, nothing changes")
	check(shop.run("buy", "filter_basic") and scene.game.money == before - 40 and scene.game.count("filter_basic") == 1, "buy filter")
	shop.show_tab("sell")
	scene.game.harvest()
	check(shop.run("sell", "crop") and scene.game.count("crop") == 0 and not shop.run("sell", "crop"), "sell the last crop, then refused")
	shop.show_tab("barter")
	check(shop.rows.get_child_count() == 1 and not shop.run("barter", "armor_filter"), "barter without crops is refused")
	var file := FileAccess.open(SCENE_SAVE, FileAccess.READ)
	check(JSON.parse_string(file.get_as_text())["items"].has("filter_basic"), "shop purchase is saved")
	file.close()
	shop.hide()
