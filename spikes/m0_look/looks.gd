extends RefCounted
## M0 look-dev: three render styles for the same scene. Pure code (shaders as text), no asset files.
const IDS: Array[String] = ["psx", "toon", "flat"]
const NAMES := {"psx": "PSX", "toon": "TOON", "flat": "FLAT"}
# Role colors per look: street, wall, lamp, soil, rock, stalk, frond, bulb, ceiling.
const PALETTE := {
	"psx": {"street": Color(0.30, 0.29, 0.27), "wall": Color(0.46, 0.45, 0.42), "lamp": Color(1.0, 0.85, 0.5), "soil": Color(0.24, 0.20, 0.17), "rock": Color(0.36, 0.33, 0.30), "stalk": Color(0.22, 0.30, 0.20), "frond": Color(0.30, 0.42, 0.24), "bulb": Color(0.8, 0.9, 0.4), "ceiling": Color(0.38, 0.40, 0.44)},
	"toon": {"street": Color(0.40, 0.42, 0.50), "wall": Color(0.88, 0.80, 0.66), "lamp": Color(1.0, 0.92, 0.55), "soil": Color(0.36, 0.26, 0.34), "rock": Color(0.52, 0.48, 0.60), "stalk": Color(0.10, 0.62, 0.55), "frond": Color(0.20, 0.80, 0.60), "bulb": Color(1.0, 0.45, 0.80), "ceiling": Color(0.55, 0.62, 0.78)},
	"flat": {"street": Color(0.55, 0.57, 0.60), "wall": Color(0.82, 0.82, 0.80), "lamp": Color(1.0, 0.95, 0.80), "soil": Color(0.50, 0.44, 0.38), "rock": Color(0.62, 0.60, 0.58), "stalk": Color(0.35, 0.58, 0.42), "frond": Color(0.48, 0.72, 0.50), "bulb": Color(0.95, 0.75, 0.45), "ceiling": Color(0.70, 0.76, 0.84)},
}
# Screen shrink for the SubViewportContainer: PSX renders at 1/4 resolution and is upscaled with nearest filtering.
const SHRINK := {"psx": 4, "toon": 1, "flat": 1}
const FOG := {"psx": 0.0012, "toon": 0.0007, "flat": 0.0009}
const SKY := {"psx": Color(0.22, 0.27, 0.30), "toon": Color(0.45, 0.60, 0.85), "flat": Color(0.72, 0.80, 0.90)}
const AMBIENT := {"psx": 0.85, "toon": 0.65, "flat": 0.7}

const SHADER_PSX := """
shader_type spatial;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float emit = 0.0;
varying vec4 vcol;
void vertex() {
	vcol = COLOR;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grid = vec2(160.0, 90.0);
	clip.xy = round(clip.xy / clip.w * grid) / grid * clip.w;
	POSITION = clip;
}
void fragment() {
	vec3 c = base_color.rgb * vcol.rgb;
	ALBEDO = floor(c * 10.0 + 0.5) / 10.0;
	EMISSION = ALBEDO * emit;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
void light() {
	float n = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (floor(n * 4.0 + 0.5) / 4.0);
}
"""

const SHADER_TOON := """
shader_type spatial;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float emit = 0.0;
varying vec4 vcol;
void vertex() { vcol = COLOR; }
void fragment() {
	ALBEDO = base_color.rgb * vcol.rgb;
	EMISSION = ALBEDO * emit;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
void light() {
	float n = dot(NORMAL, LIGHT);
	float band = n > 0.55 ? 1.0 : (n > 0.15 ? 0.62 : 0.32);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * band;
}
"""

const SHADER_OUTLINE := """
shader_type spatial;
render_mode cull_front, unshaded;
uniform vec4 line_color : source_color = vec4(0.05, 0.04, 0.08, 1.0);
uniform float width = 0.07;
void vertex() { VERTEX += NORMAL * width; }
void fragment() { ALBEDO = line_color.rgb; }
"""

const SHADER_FLAT := """
shader_type spatial;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float emit = 0.0;
varying vec4 vcol;
void vertex() { vcol = COLOR; }
void fragment() {
	NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	ALBEDO = base_color.rgb * vcol.rgb;
	EMISSION = ALBEDO * emit;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""

static func material(look: String, role: String, outline: bool = false) -> ShaderMaterial:
	var shader := Shader.new()
	match look:
		"psx": shader.code = SHADER_PSX
		"toon": shader.code = SHADER_TOON
		_: shader.code = SHADER_FLAT
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("base_color", PALETTE[look][role])
	m.set_shader_parameter("emit", 0.9 if role == "lamp" or role == "bulb" else 0.0)
	if look == "toon" and outline:
		var line := Shader.new()
		line.code = SHADER_OUTLINE
		var lm := ShaderMaterial.new()
		lm.shader = line
		m.next_pass = lm
	return m

static func environment(look: String) -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = SKY[look]
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.88, 0.95)
	e.ambient_light_energy = AMBIENT[look]
	e.fog_enabled = true
	e.fog_light_color = SKY[look]
	e.fog_density = FOG[look]
	return e
