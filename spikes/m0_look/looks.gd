extends RefCounted
## M0 look-dev: three render styles for the same scene. Pure code (shaders as text), no asset files.
const IDS: Array[String] = ["psx", "toon", "flat", "paint"]
const NAMES := {"psx": "PSX", "toon": "TOON", "flat": "FLAT", "paint": "PAINT"}
# Role colors per look: street, wall, lamp, soil, rock, stalk, frond, bulb, ceiling, meadow, grass, leaf, conifer, trunk.
const PALETTE := {
	"psx": {"street": Color(0.30, 0.29, 0.27), "wall": Color(0.46, 0.45, 0.42), "lamp": Color(1.0, 0.85, 0.5), "soil": Color(0.24, 0.20, 0.17), "rock": Color(0.36, 0.33, 0.30), "stalk": Color(0.22, 0.30, 0.20), "frond": Color(0.30, 0.42, 0.24), "bulb": Color(0.8, 0.9, 0.4), "ceiling": Color(0.38, 0.40, 0.44), "meadow": Color(0.26, 0.34, 0.22), "grass": Color(0.40, 0.52, 0.30), "leaf": Color(0.30, 0.42, 0.24), "conifer": Color(0.18, 0.30, 0.22), "trunk": Color(0.30, 0.24, 0.18)},
	"toon": {"street": Color(0.40, 0.42, 0.50), "wall": Color(0.88, 0.80, 0.66), "lamp": Color(1.0, 0.92, 0.55), "soil": Color(0.36, 0.26, 0.34), "rock": Color(0.52, 0.48, 0.60), "stalk": Color(0.10, 0.62, 0.55), "frond": Color(0.20, 0.80, 0.60), "bulb": Color(1.0, 0.45, 0.80), "ceiling": Color(0.55, 0.62, 0.78), "meadow": Color(0.30, 0.72, 0.38), "grass": Color(0.45, 0.85, 0.40), "leaf": Color(0.25, 0.75, 0.45), "conifer": Color(0.10, 0.55, 0.45), "trunk": Color(0.62, 0.45, 0.32)},
	"flat": {"street": Color(0.60, 0.54, 0.45), "wall": Color(0.82, 0.82, 0.80), "lamp": Color(1.0, 0.95, 0.80), "soil": Color(0.50, 0.44, 0.38), "rock": Color(0.62, 0.60, 0.58), "stalk": Color(0.35, 0.58, 0.42), "frond": Color(0.48, 0.72, 0.50), "bulb": Color(0.95, 0.75, 0.45), "ceiling": Color(0.70, 0.76, 0.84), "meadow": Color(0.52, 0.66, 0.42), "grass": Color(0.62, 0.74, 0.46), "leaf": Color(0.48, 0.68, 0.46), "conifer": Color(0.30, 0.52, 0.42), "trunk": Color(0.58, 0.48, 0.40)},
	"paint": {"street": Color(0.50, 0.54, 0.62), "wall": Color(0.90, 0.84, 0.72), "lamp": Color(1.0, 0.92, 0.6), "soil": Color(0.42, 0.34, 0.40), "rock": Color(0.50, 0.53, 0.60), "stalk": Color(0.16, 0.62, 0.58), "frond": Color(0.28, 0.80, 0.62), "bulb": Color(1.0, 0.55, 0.82), "ceiling": Color(0.68, 0.74, 0.88), "meadow": Color(0.30, 0.56, 0.26), "grass": Color(0.46, 0.78, 0.32), "leaf": Color(0.32, 0.70, 0.36), "conifer": Color(0.16, 0.50, 0.36), "trunk": Color(0.72, 0.56, 0.38)},
}
# Screen shrink for the SubViewportContainer: PSX renders at 1/4 resolution and is upscaled with nearest filtering.
# Live tuning (dev tool): role color overrides on top of PALETTE, and every material handed out so sliders update the scene at once.
static var tuned: Dictionary = {}
static var live: Dictionary = {}

const SHRINK := {"psx": 4, "toon": 1, "flat": 1, "paint": 1}
const FOG := {"psx": 0.0012, "toon": 0.0007, "flat": 0.0009, "paint": 0.0011}
const SKY := {"psx": Color(0.22, 0.27, 0.30), "toon": Color(0.45, 0.60, 0.85), "flat": Color(0.72, 0.80, 0.90), "paint": Color(0.62, 0.78, 0.95)}
const AMBIENT := {"psx": 0.85, "toon": 0.65, "flat": 0.7, "paint": 0.8}

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


const SHADER_FLAT_WALL := """
shader_type spatial;
// FLAT wall with windows, doors and floor lines drawn in metres on the building's own frame. Instances are unit boxes
// scaled per building, so VERTEX * scale gives metres without UVs or extra meshes (MultiMesh stays, D19).
// INSTANCE_CUSTOM = (storey height, bay width, window width, door flag); zero falls back to the uniforms.
uniform vec4 base_color : source_color = vec4(1.0);
uniform float emit = 0.0;
uniform float night = 0.0;
uniform float storey_default = 3.2;
uniform float bay_default = 3.0;
uniform vec4 glass_color : source_color = vec4(0.14, 0.2, 0.3, 1.0);
uniform vec4 lit_color : source_color = vec4(1.0, 0.82, 0.5, 1.0);
varying vec4 vcol;
varying vec3 vloc;
varying vec3 vsize;
varying vec3 nloc;
varying vec4 vcust;
void vertex() {
	vcol = COLOR;
	vcust = INSTANCE_CUSTOM;
	vsize = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	vloc = VERTEX * vsize + vec3(0.0, vsize.y * 0.5, 0.0);
	nloc = NORMAL;
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	vec3 col = base_color.rgb * vcol.rgb;
	vec3 emis = vec3(0.0);
	// Interpolated varyings carry ~1e-7 noise; rounding keeps floor() and the hash below stable per box.
	vec3 sz = floor(vsize * 64.0 + 0.5) / 64.0;
	vec4 cu = floor(vcust * 64.0 + 0.5) / 64.0;
	float storey = cu.x > 0.5 ? cu.x : storey_default;
	float bay = cu.y > 0.5 ? cu.y : bay_default;
	vec2 win_size = vec2(cu.z > 0.2 ? cu.z : 1.5, storey * 0.53);
	if (abs(nloc.y) < 0.5) {
		bool along_z = abs(nloc.x) > 0.5;
		float len = along_z ? sz.z : sz.x;
		float u = (along_z ? vloc.z : vloc.x) + len * 0.5;
		float nb = floor(len / bay);
		float nf = floor(sz.y / storey);
		float pu = (u - (len - nb * bay) * 0.5) / bay;
		float pv = vloc.y / storey;
		col *= 1.0 - 0.14 * step(sz.y - 0.35, vloc.y);
		if (pu >= 0.0 && pu < nb && pv < nf) {
			vec2 cell = vec2(floor(pu), floor(pv));
			vec2 f = vec2(fract(pu) * bay, fract(pv) * storey);
			vec2 lo = vec2((bay - win_size.x) * 0.5, storey * 0.28);
			vec2 hi = lo + win_size;
			float seed = hash(sz.xz + vec2(along_z ? 1.0 : 0.0, cu.x + cu.y));
			float fade = 1.0 - smoothstep(70.0, 150.0, length(VERTEX));
			bool door = cu.w > 0.5 && cell.y < 0.5 && mod(cell.x + floor(seed * 3.0), 3.0) < 0.5;
			if (door) {
				lo = vec2((bay - 1.1) * 0.5, 0.0);
				hi = lo + vec2(1.1, 2.2);
			}
			float in_rect = step(lo.x, f.x) * step(f.x, hi.x) * step(lo.y, f.y) * step(f.y, hi.y);
			vec3 glass = door ? vec3(0.32, 0.2, 0.14) : glass_color.rgb;
			col = mix(col, glass, in_rect * fade * 0.85);
			col *= 1.0 - 0.16 * step(f.y, 0.18) * (1.0 - in_rect) * fade;
			col *= 1.0 - 0.25 * in_rect * step(hi.y - 0.2, f.y) * fade;
			float lit = step(hash(cell + vec2(seed * 17.0, seed * 31.0)), 0.4);
			emis = lit_color.rgb * lit * in_rect * night * (door ? 0.0 : 1.0) * fade;
		}
	} else if (nloc.y > 0.5) {
		col *= 0.78;
	}
	ALBEDO = col;
	EMISSION = col * emit + emis;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""

const SHADER_FLAT_GROUND := """
shader_type spatial;
// FLAT stage ground drawn in metres on the stage frame (VERTEX.xz), without UVs or textures. kind: 0 village street
// (packed-earth road, wheel ruts, grass verge, yards), 1 danger-zone soil (stains, cracks), 2 meadow (grass, bare
// earth, one farm plot). Fine detail fades with distance so far ground does not shimmer.
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 alt_color : source_color = vec4(1.0);
uniform float emit = 0.0;
uniform int kind = 0;
uniform vec4 plot = vec4(-22.0, 12.0, -9.0, 42.0); // farm plot (x0, z0, x1, z1), matches Stage.PLOT
varying vec3 vloc;
void vertex() { vloc = VERTEX; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vnoise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	NORMAL = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	vec2 p = vloc.xz;
	float fade = 1.0 - smoothstep(40.0, 120.0, length(VERTEX));
	float big = vnoise(p * 0.07);
	float mid = vnoise(p * 0.35 + 17.0);
	float fine = vnoise(p * 2.5 + 3.0);
	vec3 col = base_color.rgb;
	if (kind == 0) {
		float ax = abs(p.x);
		col *= 1.0 - 0.14 * (1.0 - smoothstep(0.2, 0.45, abs(ax - 1.1)));
		col *= 1.0 - 0.12 * smoothstep(0.6, 0.85, fine) * fade;
		float verge = smoothstep(3.0, 4.0 + mid * 2.0, ax);
		col = mix(col, alt_color.rgb, verge * mix(1.0, 0.45, smoothstep(0.45, 0.7, big)));
		col *= mix(0.9, 1.08, big);
	} else if (kind == 1) {
		col *= mix(0.78, 1.12, big);
		col = mix(col, alt_color.rgb, smoothstep(0.6, 0.8, mid) * 0.6);
		col *= 1.0 - 0.3 * (1.0 - smoothstep(0.0, 0.035, abs(vnoise(p * 0.6 + 5.0) - 0.5))) * fade;
	} else {
		col *= mix(0.86, 1.1, big) * mix(0.95, 1.05, mid);
		col = mix(col, alt_color.rgb, smoothstep(0.72, 0.85, vnoise(p * 0.12 + 40.0)) * 0.8);
		float inside = step(plot.x, p.x) * step(p.x, plot.z) * step(plot.y, p.y) * step(p.y, plot.w);
		float row = fract(p.x / 1.2);
		float crop = smoothstep(0.3, 0.42, row) * (1.0 - smoothstep(0.58, 0.7, row));
		vec3 furrow = alt_color.rgb * (0.8 + 0.1 * (1.0 - smoothstep(0.0, 0.2, abs(row - 0.0))));
		col = mix(col, mix(furrow, base_color.rgb * vec3(0.85, 1.12, 0.7), crop), inside);
	}
	col *= mix(1.0, 0.94 + 0.12 * fine, fade * 0.5);
	ALBEDO = col;
	EMISSION = col * emit;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""
# Second colour of the FLAT ground per role: road verge grass, alien stains on soil, bare earth and furrows in the meadow.
const GROUND_KIND := {"street": 0, "soil": 1, "meadow": 2}
const GROUND_ALT := {"street": Color(0.50, 0.62, 0.40), "soil": Color(0.40, 0.46, 0.46), "meadow": Color(0.56, 0.47, 0.36)}

const SHADER_PAINT := """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color = vec4(1.0);
uniform float emit = 0.0;
uniform float sway = 0.0;
uniform float round_crown = 0.0;
uniform vec3 crown_center = vec3(0.0, 2.3, 0.0);
varying vec4 vcol;
varying vec3 lpos;
varying vec3 wpos;
varying vec3 crown_n;
float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() {
	vcol = COLOR;
	lpos = VERTEX;
	if (sway > 0.0) {
		float k = max(VERTEX.y, 0.0);
		VERTEX.x += sin(TIME * 1.6 + MODEL_MATRIX[3].x * 0.5 + MODEL_MATRIX[3].z * 0.3) * 0.12 * k * sway;
	}
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	crown_n = normalize(MODELVIEW_NORMAL_MATRIX * normalize(VERTEX - crown_center));
}
void fragment() {
	float n = vnoise(vec3(wpos.x, wpos.y * 0.2, wpos.z) * 0.08);
	float m = vnoise(vec3(wpos.x, wpos.y * 0.2, wpos.z) * 0.9);
	vec3 c = base_color.rgb * vcol.rgb * mix(0.82, 1.18, n) * mix(0.94, 1.06, m);
	ALBEDO = c;
	EMISSION = ALBEDO * emit;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	if (round_crown > 0.5) {
		NORMAL = normalize(mix(NORMAL, crown_n, 0.8));
	}
}
void light() {
	float wrap = clamp(dot(NORMAL, LIGHT) * 0.5 + 0.5, 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * wrap * wrap;
}
"""

static func role_color(look: String, role: String) -> Color:
	return tuned.get(role, PALETTE[look][role])

static func refresh_live(look: String) -> void:
	for role in live:
		for m in live[role]:
			m.set_shader_parameter("base_color", role_color(look, role))

static func set_night(amount: float) -> void:
	# 0 = day, 1 = night: lit windows of the FLAT wall shader (other materials have no such uniform and ignore it).
	for m in live.get("wall", []):
		m.set_shader_parameter("night", amount)

static func material(look: String, role: String, outline: bool = false, ground: bool = false) -> ShaderMaterial:
	# ground = the stage ground mesh (street, soil, meadow); FLAT draws it with SHADER_FLAT_GROUND, the ring keeps SHADER_FLAT.
	var shader := Shader.new()
	var flat_ground := look == "flat" and ground and GROUND_KIND.has(role)
	match look:
		"psx": shader.code = SHADER_PSX
		"toon": shader.code = SHADER_TOON
		"paint": shader.code = SHADER_PAINT
		_: shader.code = SHADER_FLAT_GROUND if flat_ground else (SHADER_FLAT_WALL if role == "wall" else SHADER_FLAT)
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("base_color", role_color(look, role))
	live.get_or_add(role, []).append(m)
	m.set_shader_parameter("emit", 0.9 if role == "lamp" or role == "bulb" else 0.0)
	if flat_ground:
		m.set_shader_parameter("kind", GROUND_KIND[role])
		m.set_shader_parameter("alt_color", GROUND_ALT[role])
	if look == "paint":
		m.set_shader_parameter("sway", 1.0 if role == "grass" else 0.0)
		m.set_shader_parameter("round_crown", 1.0 if role == "leaf" else 0.0)
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
