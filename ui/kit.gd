extends RefCounted
## 터치 UI 공통 부품: 큰 글자, 손가락 크기 버튼(회색 박스 행동 버튼과 같은 크기대), 화면 가운데 패널.
const FONT := 30
const BUTTON_HEIGHT := 96.0

static func label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", FONT)
	return l

static func button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(180, BUTTON_HEIGHT)
	b.add_theme_font_size_override("font_size", FONT + 4)
	b.pressed.connect(on_press)
	return b

## panel을 화면 가운데(가로 폭 width, 세로는 화면의 top~0.95)에 놓고 안쪽 줄 상자를 돌려준다.
static func frame(panel: PanelContainer, width: float, top: float) -> VBoxContainer:
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = top
	panel.anchor_bottom = 0.95
	panel.offset_left = -width / 2.0
	panel.offset_right = width / 2.0
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)
	return box

static func clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
