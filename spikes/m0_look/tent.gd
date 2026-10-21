extends RefCounted
## M0 field medical tent (safe-zone infirmary, D68): look test for textures + weathering + sag (habitat Issue #36).
## Parts are merged into one mesh per material, so the whole tent costs about 12 draw calls.
## Textures come from the private habitat-assets clone at res://assets (D14, D88); without it the tent is drawn in flat colors.
const W := 2.25 # half width (local x)
const L := 3.0 # half length (local z, door at +z)
const EAVE := 1.6
const RIDGE := 3.0
const TEXTURES := {
	"canvas": "res://assets/textures/ambientcg/Fabric030_1K_Color.jpg",
	"wood": "res://assets/textures/ambientcg/Wood049_1K_Color.jpg",
	"crate": "res://assets/textures/ambientcg/Planks037A_1K_Color.jpg",
}
# flat tint (no texture), texture key, tint with texture, texture gain, texture mix, repeats per metre, roughness
const KINDS := {
	"canvas": [Color(0.43, 0.43, 0.31), "canvas", Color(0.43, 0.43, 0.31), 2.6, 0.6, 0.35, 0.9],
	"roll": [Color(0.50, 0.49, 0.36), "canvas", Color(0.50, 0.49, 0.36), 2.6, 0.6, 0.35, 0.9],
	"cot": [Color(0.62, 0.60, 0.50), "canvas", Color(0.62, 0.60, 0.50), 2.6, 0.6, 0.6, 0.9],
	"pole": [Color(0.48, 0.39, 0.30), "wood", Color(1.0, 1.0, 1.0), 1.0, 1.0, 0.8, 0.9],
	"crate": [Color(0.37, 0.30, 0.22), "crate", Color(1.25, 1.3, 1.2), 1.0, 1.0, 0.9, 0.9],
	"metal": [Color(0.30, 0.36, 0.28), "", null, 1.0, 0.0, 1.0, 0.6],
	"dark": [Color(0.20, 0.23, 0.19), "", null, 1.0, 0.0, 1.0, 0.5],
	"rope": [Color(0.55, 0.50, 0.40), "", null, 1.0, 0.0, 1.0, 0.9],
	"sign": [Color(0.85, 0.84, 0.78), "", null, 1.0, 0.0, 1.0, 0.9],
	"cross": [Color(0.20, 0.45, 0.25), "", null, 1.0, 0.0, 1.0, 0.9],
	"mud": [Color(0.40, 0.35, 0.27), "", null, 1.0, 0.0, 1.0, 1.0],
}

const SHADER_TENT := """
shader_type spatial;
render_mode cull_disabled;
// Tint x triplanar texture (optional), then weathering: mud at the foot, blotches, rain streaks. Vertex colour carries baked AO.
uniform vec3 tint : source_color = vec3(1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float tex_on = 0.0;
uniform float tex_gain = 1.0;
uniform float tex_mix = 1.0;
uniform float tex_scale = 0.5;
uniform float rough = 0.9;
varying vec3 wp;
varying vec3 wn;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	// Local coordinates: the tent sits on the curved floor, so world space would tilt the 'up' used for weathering.
	wp = VERTEX;
	wn = NORMAL;
}
void fragment() {
	vec3 c = tint;
	if (tex_on > 0.5) {
		vec3 b = pow(abs(wn), vec3(4.0));
		b /= (b.x + b.y + b.z);
		vec3 t = texture(tex, wp.zy * tex_scale).rgb * b.x + texture(tex, wp.xz * tex_scale).rgb * b.y + texture(tex, wp.xy * tex_scale).rgb * b.z;
		c *= mix(vec3(1.0), t * tex_gain, tex_mix);
	}
	c *= COLOR.rgb;
	float n1 = vn(wp.xz * 1.3 + wp.y * 0.7);
	float n2 = vn(wp.xy * 4.0 + wp.z * 3.0);
	float n3 = vn(vec2(wp.x * 9.0 + wp.z * 9.0, wp.y * 1.2));
	c = mix(c, vec3(0.33, 0.27, 0.20), smoothstep(0.7, 0.0, wp.y) * (0.55 + 0.45 * n2) * 0.75);
	c *= 0.82 + 0.3 * n1;
	c *= 1.0 - 0.18 * smoothstep(0.55, 0.8, n3) * step(0.3, wp.y);
	c = mix(c, vec3(dot(c, vec3(0.33))), 0.15);
	ALBEDO = c;
	ROUGHNESS = rough;
}
"""

const SHADER_TUFT := """
shader_type spatial;
render_mode cull_disabled;
// Grass tufts on quads: blades are cut out procedurally (alpha scissor, no texture).
uniform vec3 base_col : source_color = vec3(0.30, 0.36, 0.18);
uniform vec3 tip_col : source_color = vec3(0.62, 0.60, 0.34);
float h(float x) { return fract(sin(x * 91.7) * 43758.5); }
void fragment() {
	float x = UV.x * 9.0;
	float i = floor(x);
	float hgt = 1.0 - UV.y;
	float f = fract(x) - 0.5 - hgt * (h(i) - 0.5) * 0.8;
	float top = 0.35 + 0.65 * h(i + 3.0);
	ALPHA = (abs(f) < 0.42 * (1.0 - hgt / top) && hgt < top) ? 1.0 : 0.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALBEDO = mix(base_col, tip_col, hgt / top) * (0.8 + 0.4 * h(i + 7.0));
	ROUGHNESS = 1.0;
}
"""

static var tent_shader := shader_of(SHADER_TENT)
static var tuft_shader := shader_of(SHADER_TUFT)
var rng := RandomNumberGenerator.new()
var tools := {}

static func shader_of(code: String) -> Shader:
	var s := Shader.new()
	s.code = code
	return s

static func textures_found() -> bool:
	for path in TEXTURES.values():
		if not ResourceLoader.exists(path):
			return false
	return true

static func material(kind: String) -> ShaderMaterial:
	var k: Array = KINDS[kind]
	var m := ShaderMaterial.new()
	m.shader = tent_shader
	var path: String = TEXTURES.get(k[1], "")
	var has_tex := path != "" and ResourceLoader.exists(path)
	m.set_shader_parameter("tint", k[2] if has_tex else k[0])
	if has_tex:
		m.set_shader_parameter("tex", load(path))
	m.set_shader_parameter("tex_on", 1.0 if has_tex else 0.0)
	m.set_shader_parameter("tex_gain", k[3])
	m.set_shader_parameter("tex_mix", k[4])
	m.set_shader_parameter("tex_scale", k[5])
	m.set_shader_parameter("rough", k[6])
	return m

static func build(seed_value: int = 7) -> Node3D:
	var t := new()
	t.rng.seed = seed_value
	return t.make()

# Baked AO: darker toward the ground; jit varies each piece slightly.
func ao(p: Vector3, jit: float) -> Color:
	var a := lerpf(0.55, 1.0, clampf(p.y / 0.6, 0.0, 1.0)) * jit
	return Color(a, a, a)

func tool(kind: String) -> SurfaceTool:
	if not tools.has(kind):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[kind] = st
	return tools[kind]

# Appends a primitive mesh (indexed arrays) to the kind's merged mesh, with a transform and AO colour.
func add(kind: String, mesh: Mesh, xf: Transform3D) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var st := tool(kind)
	var jit := 1.0 + rng.randf_range(-0.06, 0.06)
	var nb := xf.basis.inverse().transposed()
	for i in index:
		var p := xf * verts[i]
		st.set_normal((nb * normals[i]).normalized())
		st.set_color(ao(p, jit))
		st.add_vertex(p)

# A grid sheet f(u, v) -> point, normals generated, then merged into the kind's mesh.
func sheet(kind: String, f: Callable, nu: int, nv: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for j in range(nv + 1):
		for i in range(nu + 1):
			pts.append(f.call(float(i) / nu, float(j) / nv))
	for j in range(nv):
		for i in range(nu):
			var a := j * (nu + 1) + i
			for q in [a, a + 1, a + nu + 2, a, a + nu + 2, a + nu + 1]:
				st.add_vertex(pts[q])
	st.generate_normals()
	st.index()
	add(kind, st.commit(), Transform3D())

func cyl(r: float, length: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = length
	c.radial_segments = 10
	c.rings = 1
	return c

func box(kind: String, size: Vector3, pos: Vector3, yaw: float = 0.0, wobble: float = 0.12) -> void:
	var b := BoxMesh.new()
	b.size = size
	var basis := Basis.from_euler(Vector3(rng.randf_range(-0.02, 0.02), yaw + rng.randf_range(-wobble, wobble), rng.randf_range(-0.02, 0.02)))
	add(kind, b, Transform3D(basis, pos + Vector3(0, size.y * 0.5, 0)))

func line(kind: String, a: Vector3, b: Vector3, r: float) -> void:
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.FORWARD if absf(dir.z) < 0.99 else Vector3.RIGHT).normalized()
	var basis := Basis(side, dir, side.cross(dir))
	add(kind, cyl(r, a.distance_to(b)), Transform3D(basis, (a + b) * 0.5))

# Canvas droops between the poles (z = -L, 0, L) and across each panel, with small wrinkles.
func sag(u: float, z: float) -> float:
	return 0.13 * sin(PI * u) * absf(sin(PI * (z + L) / L)) + 0.025 * sin(z * 7.0 + u * 11.0) * sin(PI * u)

func canvas() -> void:
	for s in [-1.0, 1.0]:
		var n := Vector3(s * (RIDGE - EAVE), W, 0).normalized()
		sheet("canvas", func(u: float, v: float) -> Vector3:
			var z := lerpf(-L - 0.25, L + 0.25, v)
			return Vector3(s * lerpf(0.0, W + 0.2, u), lerpf(RIDGE, EAVE - 0.08, u), z) - n * sag(u, clampf(z, -L, L)), 10, 24)
		sheet("canvas", func(u: float, v: float) -> Vector3:
			var z := lerpf(-L, L, v)
			var bulge := 0.05 * sin(PI * u) * absf(sin(PI * (z + L) / L))
			return Vector3(s * (lerpf(W, W + 0.12, u) - bulge), lerpf(EAVE, 0.02 + 0.05 * sin(z * 5.0), u), z), 6, 24)
	for zf in [-L, L]:
		sheet("canvas", func(u: float, v: float) -> Vector3:
			var hw := W * (1.0 - v)
			return Vector3(lerpf(-hw, hw, u), lerpf(EAVE, RIDGE, v), zf), 8, 6)
	sheet("canvas", func(u: float, v: float) -> Vector3:
		return Vector3(lerpf(-W, W, u), lerpf(0.02, EAVE, v), -L + 0.04 * sin(PI * u) * sin(PI * v)), 8, 6)
	for s in [-1.0, 1.0]:
		# Door side panels and the rolled-up flaps.
		sheet("canvas", func(u: float, v: float) -> Vector3:
			return Vector3(s * lerpf(W, 1.0, u), lerpf(0.02, EAVE, v), L), 4, 6)
		add("roll", cyl(0.13, EAVE - 0.1), Transform3D(Basis(Vector3.BACK, rng.randf_range(-0.05, 0.05)), Vector3(s * 1.05, EAVE * 0.5 + 0.05, L + 0.12)))

func frame() -> void:
	for z in [-L, 0.0, L + 0.05]:
		add("pole", cyl(0.06, RIDGE), Transform3D(Basis(), Vector3(0, RIDGE * 0.5, z)))
	line("pole", Vector3(0, RIDGE - 0.02, -L - 0.3), Vector3(0, RIDGE - 0.02, L + 0.3), 0.05)
	for s in [-1.0, 1.0]:
		for z in [-L, -L / 2.0, 0.0, L / 2.0, L]:
			var stake := Vector3(s * (W + 1.3), 0.15, z + rng.randf_range(-0.1, 0.1))
			line("rope", Vector3(s * (W + 0.2), EAVE - 0.08, z), stake, 0.012)
			add("pole", cyl(0.025, 0.3), Transform3D(Basis(Vector3.BACK, s * 0.35), stake))

func props() -> void:
	# Sign with a green cross (not the protected red cross emblem).
	add("pole", cyl(0.04, 1.4), Transform3D(Basis(), Vector3(1.9, 0.7, L + 1.4)))
	box("sign", Vector3(0.7, 0.5, 0.03), Vector3(1.9, 1.15, L + 1.42), 0.0, 0.0)
	box("cross", Vector3(0.36, 0.1, 0.02), Vector3(1.9, 1.35, L + 1.44), 0.0, 0.0)
	box("cross", Vector3(0.1, 0.36, 0.02), Vector3(1.9, 1.22, L + 1.44), 0.0, 0.0)
	for fy in [1.13, 1.63]:
		box("pole", Vector3(0.76, 0.05, 0.05), Vector3(1.9, fy, L + 1.43), 0.0, 0.0)
	for fx in [1.535, 2.265]:
		box("pole", Vector3(0.05, 0.55, 0.05), Vector3(fx, 1.13, L + 1.43), 0.0, 0.0)
	crate(Vector3(-2.6, 0, L + 0.9), 0.6, 0.2)
	crate(Vector3(-3.3, 0, L + 0.5), 0.6, -0.15)
	crate(Vector3(-2.7, 0.48, L + 0.75), 0.45, 0.6)
	crate(Vector3(0.0, 0, -1.8), 0.55, 0.1)
	box("sign", Vector3(0.5, 0.06, 0.35), Vector3(0.0, 0.44, -1.8), 0.3)
	box("cot", Vector3(0.75, 0.45, 1.9), Vector3(-1.2, 0, 0.6))
	box("cot", Vector3(0.75, 0.45, 1.9), Vector3(1.2, 0, 0.3))
	for at in [Vector3(2.9, 0, L + 0.3), Vector3(3.3, 0, L - 0.4)]:
		add("metal", cyl(0.29, 0.88), Transform3D(Basis(), at + Vector3(0, 0.44, 0)))
		for y in [0.02, 0.3, 0.58, 0.86]:
			add("dark", cyl(0.305, 0.035), Transform3D(Basis(), at + Vector3(0, y, 0)))
		add("dark", cyl(0.06, 0.02), Transform3D(Basis(), at + Vector3(0.14, 0.89, 0.05)))
	for k in range(7):
		box("cot", Vector3(0.55, 0.16, 0.32), Vector3(-W - 0.15, 0.16 * (k / 4), -L - 0.25 + (k % 4) * 0.5), PI / 2.0)

func crate(pos: Vector3, s: float, yaw: float) -> void:
	box("crate", Vector3(s, s * 0.8, s), pos, yaw)
	for y in [0.0, s * 0.8 - 0.07]:
		box("pole", Vector3(s + 0.03, 0.07, s + 0.03), pos + Vector3(0, y, 0), yaw, 0.0)

# Low mud berm along the canvas foot, so walls do not meet the ground on a hard line.
func berm() -> void:
	for s in [-1.0, 1.0]:
		sheet("mud", func(u: float, v: float) -> Vector3:
			var z := lerpf(-L - 0.1, L + 0.1, v)
			return Vector3(s * (W + 0.12 + lerpf(-0.12, 0.35, u)), 0.07 * sin(PI * u) * (0.7 + 0.3 * sin(z * 3.0)), z), 4, 24)
	sheet("mud", func(u: float, v: float) -> Vector3:
		return Vector3(lerpf(-W - 0.1, W + 0.1, u), 0.07 * sin(PI * v), -L - lerpf(-0.1, 0.35, v)), 16, 4)

func tufts() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in range(55):
		var s := -1.0 if rng.randf() < 0.5 else 1.0
		var pos := Vector3(s * (W + rng.randf_range(0.3, 1.6)), 0, rng.randf_range(-L - 1.0, L + 1.0))
		var hgt := rng.randf_range(0.18, 0.4)
		var half := rng.randf_range(0.15, 0.3)
		var yaw := rng.randf() * PI
		for q in range(2):
			var d := Vector3(cos(yaw + q * PI / 2.0), 0, sin(yaw + q * PI / 2.0)) * half
			var c := [pos - d, pos + d, pos + d + Vector3(0, hgt, 0), pos - d + Vector3(0, hgt, 0)]
			var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
			for i in [0, 1, 2, 0, 2, 3]:
				st.set_normal(Vector3.UP)
				st.set_uv(uv[i])
				st.add_vertex(c[i])
	var m := ShaderMaterial.new()
	m.shader = tuft_shader
	var node := MeshInstance3D.new()
	node.name = "tufts"
	node.mesh = st.commit()
	node.material_override = m
	return node

func make() -> Node3D:
	canvas()
	frame()
	props()
	berm()
	var root := Node3D.new()
	root.name = "tent"
	for kind in tools:
		var node := MeshInstance3D.new()
		node.name = kind
		node.mesh = (tools[kind] as SurfaceTool).commit()
		node.material_override = material(kind)
		root.add_child(node)
	root.add_child(tufts())
	return root
