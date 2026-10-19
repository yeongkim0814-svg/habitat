extends PanelContainer
## Live look tuning for the tablet: pick a role, drag hue/saturation/value, adjust fog, ambient and sun. Saves per look to user:// and prints the values as JSON.
const Looks = preload("res://spikes/m0_look/looks.gd")
const Tuning = preload("res://spikes/m0_look/tuning.gd")
const Kit = preload("res://spikes/m0_look/ui_kit.gd")
const FONT := 26
signal tuned

var look := "flat"
var values: Dictionary = {"colors": {}}
var role_index := 0
var role_label := Label.new()
var readout := Label.new()
var sliders: Dictionary = {}
var value_labels: Dictionary = {}

func _init() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.05, 0.06, 0.09, 0.9)
	backing.set_content_margin_all(14.0)
	add_theme_stylebox_override("panel", backing)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var picker := HBoxContainer.new()
	box.add_child(picker)
	Kit.button(picker, "◀", step_role.bind(-1), 70, FONT)
	role_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.add_theme_font_size_override("font_size", FONT + 4)
	picker.add_child(role_label)
	Kit.button(picker, "▶", step_role.bind(1), 70, FONT)
	add_slider(box, "h", "색상", 0.0, 1.0)
	add_slider(box, "s", "채도", 0.0, 1.0)
	add_slider(box, "v", "명도", 0.0, 1.0)
	box.add_child(HSeparator.new())
	add_slider(box, "fog", "안개", 0.0, 0.004)
	add_slider(box, "ambient", "주변광", 0.2, 1.6)
	add_slider(box, "sun", "태양", 0.2, 1.6)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	Kit.button(buttons, "초기화", reset, 80, FONT)
	Kit.button(buttons, "저장", save, 80, FONT)
	Kit.button(buttons, "값 표시", show_values, 80, FONT)
	readout.add_theme_font_size_override("font_size", 20)
	box.add_child(readout)

func add_slider(parent: Node, key: String, text: String, lo: float, hi: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var name_label := Label.new()
	name_label.text = text
	name_label.custom_minimum_size = Vector2(110, 0)
	name_label.add_theme_font_size_override("font_size", FONT)
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = (hi - lo) / 500.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 64)
	slider.value_changed.connect(on_slider.bind(key))
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(100, 0)
	value_label.add_theme_font_size_override("font_size", FONT - 4)
	row.add_child(value_label)
	sliders[key] = slider
	value_labels[key] = value_label

func value(key: String) -> float:
	return values.get(key, Looks.FOG[look] if key == "fog" else 1.0)

func role() -> String:
	return Tuning.ROLES[role_index]

func load_look(new_look: String) -> void:
	look = new_look
	values = Tuning.load_look(look)
	Looks.tuned = values.colors.duplicate()
	for key in Tuning.GLOBAL_KEYS:
		set_slider(key, value(key))
	show_role()

func show_role() -> void:
	role_label.text = "%s (%s)" % [Tuning.NAMES[role()], role()]
	var c := Looks.role_color(look, role())
	set_slider("h", c.h)
	set_slider("s", c.s)
	set_slider("v", c.v)

func set_slider(key: String, v: float) -> void:
	sliders[key].set_value_no_signal(v)
	value_labels[key].text = "%.3f" % v

func step_role(delta: int) -> void:
	role_index = posmod(role_index + delta, Tuning.ROLES.size())
	show_role()

func on_slider(v: float, key: String) -> void:
	value_labels[key].text = "%.3f" % v
	if key in Tuning.GLOBAL_KEYS:
		values[key] = v
	else:
		set_role_color(role(), Color.from_hsv(sliders.h.value, sliders.s.value, sliders.v.value))
	tuned.emit()

func set_role_color(role_id: String, color: Color) -> void:
	values.colors[role_id] = color
	Looks.tuned[role_id] = color
	Looks.refresh_live(look)

func reset() -> void:
	values = {"colors": {}}
	Looks.tuned.clear()
	Looks.refresh_live(look)
	for key in Tuning.GLOBAL_KEYS:
		set_slider(key, value(key))
	show_role()
	readout.text = ""
	tuned.emit()

func save() -> void:
	readout.text = "저장됨" if Tuning.save_look(look, values) else "저장 실패"

func show_values() -> void:
	readout.text = Tuning.encode(look, values)
	print("M0 tuning ", readout.text)
