extends RefCounted
## Touch-sized UI helpers shared by the M0 scene and its tuning panel.

static func bottom_row(parent: Node, top: float, bottom: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	parent.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = top
	row.offset_bottom = bottom
	row.offset_left = 30.0
	row.offset_right = -30.0
	return row

static func button(row: Control, text: String, action: Callable, height: float = 120.0, font: int = 30) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", font)
	b.pressed.connect(action)
	row.add_child(b)
	return b
