extends PanelContainer
## 상점 화면(D36, D79): 사기·팔기·교환 탭. 명령은 core/shop.gd로 보내고, 성공하면 on_change(저장)를 부른다.
const Kit = preload("res://ui/kit.gd")
const Shop = preload("res://core/shop.gd")
const TABS := {"buy": "사기", "sell": "팔기", "barter": "교환"}

var game
var shop_id := ""
var on_change: Callable
var tab := "buy"
var title: Label
var rows: VBoxContainer
var note: Label

func _init() -> void:
	var box := Kit.frame(self, 1000, 0.1)
	title = Kit.label("")
	box.add_child(title)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 16)
	for key in TABS:
		tabs.add_child(Kit.button(TABS[key], show_tab.bind(key)))
	box.add_child(tabs)
	rows = VBoxContainer.new()
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(rows)
	note = Kit.label("")
	box.add_child(note)
	box.add_child(Kit.button("닫기", hide))
	hide()

func open(g, id: String, changed: Callable) -> void:
	game = g
	shop_id = id
	on_change = changed
	note.text = ""
	show_tab("buy")
	show()

func show_tab(key: String) -> void:
	tab = key
	refresh()

func item_name(item: String) -> String:
	return game.data["items"][item]["name"]

func refresh() -> void:
	title.text = "%s · %s   (돈 %d)" % [game.data["residents"][shop_id]["name"], TABS[tab], game.money]
	Kit.clear(rows)
	var shop: Dictionary = game.data["shops"][shop_id]
	match tab:
		"buy":
			for item in shop["sell"]:
				add_row("%s  %d원" % [item_name(item), shop["sell"][item]], "buy", item)
		"sell":
			for item in shop["buy"]:
				add_row("%s  %d원  (가진 것 %d)" % [item_name(item), shop["buy"][item], game.count(item)], "sell", item)
		"barter":
			for offer in Shop.offers(game, shop_id):
				var give: Array = offer["give"].keys().map(func(k): return "%s %d" % [item_name(k), offer["give"][k]])
				add_row("%s → %s  (오늘 %d번 남음)" % [", ".join(give), item_name(offer["get"]), offer["left"]], "barter", offer["id"])

func add_row(text: String, kind: String, arg: String) -> void:
	var row := HBoxContainer.new()
	var label := Kit.label(text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(Kit.button(TABS[kind], run.bind(kind, arg)))
	rows.add_child(row)

## 실패한 명령은 core가 상태를 바꾸지 않으므로 이유만 보여 준다.
func run(kind: String, arg: String) -> bool:
	var ok: bool
	match kind:
		"buy":
			ok = Shop.buy(game, shop_id, arg)
			note.text = "샀다." if ok else "돈이 모자란다."
		"sell":
			ok = Shop.sell(game, shop_id, arg)
			note.text = "팔았다." if ok else "가진 것이 없다."
		"barter":
			ok = Shop.barter(game, shop_id, arg)
			note.text = "교환했다." if ok else "재료가 모자라거나 오늘 수량이 끝났다."
	if ok:
		on_change.call()
	refresh()
	return ok
