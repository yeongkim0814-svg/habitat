extends PanelContainer
## 퀘스트 화면(D95): 받은 퀘스트의 주민, 목표 아이템, 현재/목표 수량. "처음부터"는 두 번 눌러야 한다.
const Kit = preload("res://ui/kit.gd")

var game
var on_restart: Callable
var rows: VBoxContainer
var restart: Button

func _init() -> void:
	var box := Kit.frame(self, 900, 0.15)
	box.add_child(Kit.label("퀘스트"))
	rows = VBoxContainer.new()
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(rows)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 24)
	restart = Kit.button("", ask_restart)
	buttons.add_child(restart)
	buttons.add_child(Kit.button("닫기", hide))
	box.add_child(buttons)
	hide()

func open(g, restart_game: Callable) -> void:
	game = g
	on_restart = restart_game
	restart.text = "처음부터"
	Kit.clear(rows)
	for row in game.journal():
		rows.add_child(Kit.label("%s · %s %d/%d%s" % [game.data["residents"][row["giver"]]["name"],
			game.data["items"][row["item"]]["name"], row["have"], row["need"], "  (납품 가능)" if row["ready"] else ""]))
	if rows.get_child_count() == 0:
		rows.add_child(Kit.label("받은 퀘스트가 없다. 주민과 대화해 보자."))
	show()

## 저장을 지우는 버튼이라 한 번 더 눌러야 실행한다.
func ask_restart() -> void:
	if restart.text == "처음부터":
		restart.text = "한 번 더 누르면 처음부터"
		return
	hide()
	on_restart.call()
