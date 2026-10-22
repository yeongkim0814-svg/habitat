extends PanelContainer
## 대화 화면(D95): 대사를 한 줄씩 넘기고, 마지막 줄에서 choices(버튼 글 → 호출)를 보여 준다. 고르면 닫힌다.
const Kit = preload("res://ui/kit.gd")

var lines: Array = []
var choices := {}
var at := 0
var speaker: Label
var text: Label
var buttons: HBoxContainer

func _init() -> void:
	var box := Kit.frame(self, 1100, 0.55)
	speaker = Kit.label("")
	text = Kit.label("")
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buttons = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 24)
	for node in [speaker, text, buttons]:
		box.add_child(node)
	hide()

func open(who: String, dialogue: Array, options: Dictionary) -> void:
	speaker.text = who
	lines = dialogue
	choices = options
	at = 0
	show_line()
	show()

func show_line() -> void:
	text.text = lines[at]
	Kit.clear(buttons)
	if at < lines.size() - 1:
		buttons.add_child(Kit.button("다음", next))
		return
	for label in choices:
		buttons.add_child(Kit.button(label, choose.bind(label)))

func next() -> void:
	at += 1
	show_line()

func choose(label: String) -> void:
	hide()
	choices[label].call()
