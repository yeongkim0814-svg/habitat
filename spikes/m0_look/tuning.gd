extends RefCounted
## Look tuning values (dev tool): per-role color overrides plus fog density and ambient/sun multipliers, kept per look in one JSON file.
const FILE := "user://m0_tuning.json"
const ROLES: Array[String] = ["street", "wall", "lamp", "soil", "rock", "stalk", "frond", "bulb", "ceiling", "meadow", "grass", "leaf", "conifer", "trunk"]
const NAMES := {"street": "도로", "wall": "건물 벽", "lamp": "가로등", "soil": "흙", "rock": "바위", "stalk": "외계 줄기", "frond": "외계 잎", "bulb": "외계 열매", "ceiling": "머리 위 건물", "meadow": "초원 바닥", "grass": "풀", "leaf": "활엽수 잎", "conifer": "침엽수", "trunk": "나무 줄기"}
const GLOBAL_KEYS: Array[String] = ["fog", "ambient", "sun"]
# Slider ranges double as the valid range of saved values, so a hand-edited file cannot turn lighting off or blow it out.
const GLOBAL_RANGES := {"fog": Vector2(0.0, 0.004), "ambient": Vector2(0.2, 1.6), "sun": Vector2(0.2, 1.6)}

static func parse(text: String) -> Variant:
	# JSON.parse_string logs an engine error on bad input; a damaged tuning file should fail quietly.
	var json := JSON.new()
	return json.data if json.parse(text) == OK else null

static func entry(values: Dictionary) -> Dictionary:
	var colors := {}
	for role in values.get("colors", {}):
		colors[role] = (values.colors[role] as Color).to_html(false)
	var out := {"colors": colors}
	for key in GLOBAL_KEYS:
		if values.has(key):
			out[key] = snappedf(values[key], 0.0001)
	return out

static func encode(look: String, values: Dictionary) -> String:
	return JSON.stringify({look: entry(values)}, "\t")

static func decode(look: String, text: String) -> Dictionary:
	# Unknown roles and malformed entries are dropped, so a bad file never breaks the scene.
	var out := {"colors": {}}
	var parsed: Variant = parse(text)
	if not parsed is Dictionary or not parsed.get(look) is Dictionary:
		return out
	var colors: Variant = parsed[look].get("colors", {})
	if colors is Dictionary:
		for role in colors:
			if role in ROLES and colors[role] is String and (colors[role] as String).is_valid_html_color():
				out.colors[role] = Color.html(colors[role])
	for key in GLOBAL_KEYS:
		var value: Variant = parsed[look].get(key)
		if value is float or value is int:
			out[key] = clampf(float(value), GLOBAL_RANGES[key].x, GLOBAL_RANGES[key].y)
	return out

static func load_look(look: String) -> Dictionary:
	if not FileAccess.file_exists(FILE):
		return {"colors": {}}
	return decode(look, FileAccess.get_file_as_string(FILE))

static func save_look(look: String, values: Dictionary) -> bool:
	var all: Variant = {}
	if FileAccess.file_exists(FILE):
		var parsed: Variant = parse(FileAccess.get_file_as_string(FILE))
		if parsed is Dictionary:
			all = parsed
	all[look] = entry(values)
	var file := FileAccess.open(FILE, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(all, "\t"))
	return true
