extends RefCounted
## P1 게임 상태와 명령(D92~D95). 화면·노드 없음. 내용은 data/의 JSON에서 읽는다.

const Clock = preload("res://core/clock.gd")
const SAVE_VERSION := 2

var data: Dictionary
var clock: Clock
var items := {}
var money := 0
var favor := {}
var slots: Array = []
var quests := {}
var field := 0
var crate := {}
var barter_used := {}

static func load_data(dir := "res://data") -> Dictionary:
	var d := {}
	for key in ["items", "residents", "quests", "dialogues", "world", "shops", "layout"]:
		d[key] = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [dir, key]))
	return d

func _init(game_data: Dictionary) -> void:
	data = game_data
	var w: Dictionary = data["world"]
	clock = Clock.new(w["day_real_seconds"], w["sunrise_hour"], w["start"]["hour"])
	money = int(w["start"]["money"])
	slots = w["start"]["slots"].duplicate()
	refill()

## 데이터 참조 오류 목록. 비어 있어야 한다(퀘스트를 데이터로 추가할 때의 안전망).
func validate() -> Array:
	var errors := []
	var ids := {}
	for q in data["quests"]:
		ids[q["id"]] = true
	for q in data["quests"]:
		if not data["residents"].has(q["giver"]):
			errors.append("%s: 없는 주민 %s" % [q["id"], q["giver"]])
		if not data["items"].has(q["item"]):
			errors.append("%s: 없는 아이템 %s" % [q["id"], q["item"]])
		for key in ["start", "done"]:
			if not data["dialogues"].has(q[key]):
				errors.append("%s: 없는 대화 %s" % [q["id"], q[key]])
		for r in q["requires"]:
			if not ids.has(r):
				errors.append("%s: 없는 선행 퀘스트 %s" % [q["id"], r])
	for shop in data["shops"]:
		if not data["residents"].has(shop):
			errors.append("shops: 없는 주민 %s" % shop)
		var used: Array = data["shops"][shop]["sell"].keys() + data["shops"][shop]["buy"].keys()
		for offer in data["shops"][shop]["barter"]:
			used += offer["give"].keys() + [offer["get"]]
		for item in used:
			if not data["items"].has(item):
				errors.append("shops.%s: 없는 아이템 %s" % [shop, item])
	for item in [data["world"]["field"]["item"]] + data["world"]["crate"].keys():
		if not data["items"].has(item):
			errors.append("world: 없는 아이템 %s" % item)
	return errors

func quest(id: String) -> Dictionary:
	for q in data["quests"]:
		if q["id"] == id:
			return q
	return {}

func count(item: String) -> int:
	return items.get(item, 0)

func add(item: String, n: int) -> void:
	items[item] = count(item) + n
	if items[item] <= 0:
		items.erase(item)

## locked → available → active → ready(납품 가능) → done
func status(id: String) -> String:
	var q := quest(id)
	if q.is_empty():
		return "locked"
	var s: String = quests.get(id, "")
	if s == "done":
		return "done"
	if s == "active":
		return "ready" if count(q["item"]) >= int(q["count"]) else "active"
	for r in q["requires"]:
		if quests.get(r, "") != "done":
			return "locked"
	return "available"

## 퀘스트 화면(D95)에 보이는 목록: 받은 퀘스트의 목표와 현재 수량.
func journal() -> Array:
	var rows := []
	for q in data["quests"]:
		var s := status(q["id"])
		if s == "active" or s == "ready":
			rows.append({"id": q["id"], "giver": q["giver"], "item": q["item"],
				"have": mini(count(q["item"]), int(q["count"])), "need": int(q["count"]), "ready": s == "ready"})
	return rows

## 받을 수 있으면 받고 시작 대화를 돌려준다. 아니면 빈 배열.
func accept(id: String) -> Array:
	if status(id) != "available":
		return []
	quests[id] = "active"
	return data["dialogues"][quest(id)["start"]]

## 납품 가능하면 아이템을 넘기고 보상을 받은 뒤 완료 대화를 돌려준다. 아니면 빈 배열.
func complete(id: String) -> Array:
	if status(id) != "ready":
		return []
	var q := quest(id)
	var reward: Dictionary = q["reward"]
	add(q["item"], -int(q["count"]))
	money += int(reward.get("money", 0))
	favor[q["giver"]] = int(favor.get(q["giver"], 0)) + int(reward.get("favor", 0))
	if reward.has("slot") and not slots.has(reward["slot"]):
		slots.append(reward["slot"])
	quests[id] = "done"
	return data["dialogues"][q["done"]]

## 주민이 지금 줄 수 있는 대화 대상 퀘스트(납품 가능 > 받을 수 있음 순). 없으면 "".
func offer(giver: String) -> String:
	for want in ["ready", "available"]:
		for q in data["quests"]:
			if q["giver"] == giver and status(q["id"]) == want:
				return q["id"]
	return ""

func harvest() -> bool:
	if field <= 0:
		return false
	field -= 1
	add(data["world"]["field"]["item"], 1)
	return true

## 레이드 대체 상자(D92): P2에서 진짜 레이드로 바꾼다.
func open_crate() -> Dictionary:
	var got := crate
	for item in got:
		add(item, got[item])
	crate = {}
	return got

## 거주구 특수 요청(D92): 밭과 대체 상자는 일출마다 다시 채워진다. 교환 일일 수량도 일출에 갱신한다(D47).
func refill() -> void:
	field = int(data["world"]["field"]["count"])
	barter_used = {}
	crate = {}
	for k in data["world"]["crate"]:
		crate[k] = int(data["world"]["crate"][k])

func advance(real_dt: float) -> void:
	if clock.advance(real_dt) > 0:
		refill()

func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "seconds": clock.seconds, "items": items, "money": money,
		"favor": favor, "slots": slots, "quests": quests, "field": field, "crate": crate, "barter_used": barter_used}

## 저장 dict를 검사해 정리한 사본을 돌려준다. 형식이 틀리거나 수량·돈이 음수면 {}.
static func clean(d) -> Dictionary:
	if not d is Dictionary or d.get("version") != SAVE_VERSION:
		return {}
	var out := {}
	for key in ["seconds", "money", "field"]:
		if not (d.get(key) is float or d.get(key) is int) or d[key] < 0:
			return {}
		out[key] = d[key]
	for key in ["items", "favor", "crate", "barter_used", "quests"]:
		if not d.get(key) is Dictionary:
			return {}
		out[key] = {}
		for k in d[key]:
			var v = d[key][k]
			if key == "quests":
				if not v is String:
					return {}
				out[key][k] = v
			elif (v is float or v is int) and v >= 0:
				out[key][k] = int(v)
			else:
				return {}
	if not d.get("slots") is Array:
		return {}
	for v in d["slots"]:
		if not v is String:
			return {}
	out["slots"] = d["slots"].duplicate()
	return out

func from_dict(d: Dictionary) -> void:
	clock.seconds = float(d["seconds"])
	items = d["items"]
	money = int(d["money"])
	favor = d["favor"]
	slots = d["slots"]
	quests = d["quests"]
	field = int(d["field"])
	crate = d["crate"]
	barter_used = d["barter_used"]

## 임시 파일에 다 쓴 것을 확인한 뒤 바꿔 넣어, 실패해도 이전 저장이 남는다.
func save(path: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	var ok := f.store_string(JSON.stringify(to_dict())) and f.get_error() == OK
	f.close()
	if not ok:
		DirAccess.remove_absolute(tmp)
		return false
	return DirAccess.rename_absolute(tmp, path) == OK

## 깨졌거나 버전·형식이 다른 파일은 거부하고 현재 상태를 하나도 바꾸지 않는다.
func load(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return false
	var d := clean(json.data)
	if d.is_empty():
		return false
	from_dict(d)
	return true
