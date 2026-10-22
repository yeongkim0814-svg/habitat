extends RefCounted
## Contaminated-zone hospital interior (D60, D61): first-floor corridor, exam room and stairwell, built in code (D88).
## Look test for an indoor scene lit by the sun through a roof hole, emergency lights and the player's flashlight (habitat Issue #42).
## Parts are merged per material and per chunk (corridor thirds, exam room, stairwell): Compatibility draws one extra pass per
## object for each omni/spot light that touches it, so small chunks keep a light's cost to the part of the building it reaches.
## Surfaces are drawn in the shader in metres on the building frame (tiles, paint, stains): no texture files.
const CORRIDOR_W := 3.0 # D53 module: corridor 3 m wide, ceiling 4 m
const CEILING := 4.0
const LENGTH := 24.0 # corridor runs along +z from 0 to LENGTH
const T := 0.25 # wall thickness
const STAIR_LENGTH := 6.0 # stairwell beyond the corridor end
const EXTENT := LENGTH + T + STAIR_LENGTH # farthest hospital geometry along z (30.25 m)
const ROOF := 4.4 # structural slab bottom, 0.3 m thick
const ROOF_TOP := 4.7
const STAIR_TOP := 8.0 # the stairwell spans both floors
const HOLE := Rect2(-1.2, 16.8, 2.4, 3.0) # collapsed roof section (x, z)
# The suspended ceiling lost tiles over a wider area: the sun comes in at 35 degrees at most (D43), so a ceiling hole only
# as big as the roof hole would cut the beam in half on its way down from the roof.
const CEILING_HOLE := Rect2(-1.5, 14.6, 3.0, 5.2)
const ROOM := Rect2(1.75, 7.0, 5.75, 7.0) # exam room interior (x, z)
const ROOM_DOOR := Rect2(9.8, 0.0, 1.4, 2.3) # opening in the corridor east wall (z, y)
const WINDOW := Rect2(9.5, 1.0, 3.0, 1.3) # boarded window in the room's outer wall (z, y)
const STAIR_DOOR := Rect2(-0.8, 0.0, 1.6, 2.4) # opening in the corridor end wall (x, y)
# The shaft box sits this far inside the floor and walls. On the surfaces themselves its faces z-fight with them, which drew
# dashed bands across the sunlit floor and walls that changed with the screen size (Issue #52).
const SHAFT_INSET := 0.03
const INDOOR_AMBIENT := 0.15 # sky light reaching the inside: walls and roof block most of it (D90 open point)
const INDOOR_EXPOSURE := 3.0 # eye adaptation indoors: the sun through the hole is this many times brighter than outdoors
# tint, mode (0 plain, 1 floor tiles, 2 painted wall, 3 ceiling tiles, 4 glow), roughness, metallic
const KINDS := {
	"floor": [Color(0.62, 0.60, 0.55), 1, 0.7, 0.0],
	"wall": [Color(0.80, 0.79, 0.72), 2, 0.9, 0.0],
	"ceiling": [Color(0.78, 0.77, 0.72), 3, 0.95, 0.0],
	"slab": [Color(0.45, 0.44, 0.42), 0, 1.0, 0.0],
	"trim": [Color(0.55, 0.60, 0.62), 0, 0.6, 0.2],
	"tbar": [Color(0.55, 0.60, 0.62), 0, 0.6, 0.2], # thin parts in the sunlight path: drawn, but cast no shadow (Issue #50)
	"door": [Color(0.42, 0.52, 0.55), 0, 0.7, 0.0],
	"glass": [Color(0.10, 0.13, 0.15), 0, 0.15, 0.0],
	"metal": [Color(0.60, 0.62, 0.62), 0, 0.45, 0.6],
	"fabric": [Color(0.55, 0.68, 0.66), 0, 0.95, 0.0],
	"wood": [Color(0.45, 0.36, 0.26), 0, 0.9, 0.0],
	"debris": [Color(0.52, 0.50, 0.47), 0, 1.0, 0.0],
	"paper": [Color(0.85, 0.84, 0.78), 0, 0.95, 0.0],
	"lamp": [Color(0.88, 0.90, 0.88), 0, 0.5, 0.0],
	"glow": [Color(1.0, 1.0, 1.0), 4, 0.5, 0.0],
}
const STRUCTURE: Array[String] = ["floor", "wall", "ceiling", "slab"]
const RED := Color(1.0, 0.16, 0.08)
const GREEN := Color(0.2, 1.0, 0.45)

const SHADER_HOSPITAL := """
shader_type spatial;
// Hospital surfaces in metres on the building frame: plain, vinyl floor tiles with a way-finding stripe, painted wall with a
// wainscot and peeling paint, suspended ceiling tiles with gaps and water stains, glow. Vertex colour carries baked AO
// (or the glow colour). The sun inside the corridor is masked analytically (Issue #52): a surface point is sunlit when its ray
// toward the sun passes the ceiling hole and the roof hole, with a soft edge as wide as the sun's own penumbra. The shadow map
// then adds only the shadows of objects inside the sunlit patch, and is faded out near the patch edge, where its stair-step
// stripes would show. Outside the corridor (exam room, stairwell) the sun uses the shadow map as before.
uniform vec3 tint : source_color = vec3(1.0);
uniform int mode = 0;
uniform float rough = 0.9;
uniform float metal = 0.0;
varying vec3 lp;
varying vec3 ln;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}
// Anti-aliased grid lines (Issue #52): coverage of lines of half width hw around the cell edges of g (cells of size 1). As a
// pixel spans more of a cell (fwidth), the edge softens, and once a line is thinner than a pixel it melts into its average
// coverage instead of breaking into dashes that crawl as the view or the screen size changes.
float grid_lines(vec2 g, float hw) {
	vec2 fw = fwidth(g);
	vec2 f = abs(fract(g) - 0.5);
	vec2 e = smoothstep(vec2(0.5 - hw) - fw, vec2(0.5 - hw) + fw, f);
	float line = max(e.x, e.y);
	float avg = 1.0 - (1.0 - 2.0 * hw) * (1.0 - 2.0 * hw);
	return mix(line, avg, smoothstep(hw, 4.0 * hw, max(fw.x, fw.y)));
}
// Anti-aliased band |d| < hw for a coordinate d (metres): the share of the pixel's span [d - fw, d + fw] that falls inside the
// band (a box filter). Sharp up close, and once the band is thinner than a pixel its strength drops with hw / fw instead of
// staying a one-pixel line.
float band(float d, float hw) {
	float fw = max(fwidth(d), 1e-5);
	return clamp((min(d + fw, hw) - max(d - fw, -hw)) / (2.0 * fw), 0.0, 1.0);
}
void fragment() {
	vec3 c = tint;
	float n1 = vn(lp.xz * 0.8 + lp.y * 0.5);
	float n2 = vn(lp.xz * 5.0 + lp.y * 3.0);
	if (mode == 1) {
		vec2 g = lp.xz / 0.6;
		// Per-tile shade fades out with distance too, or far tiles flicker between light and dark.
		float far = smoothstep(0.05, 0.2, max(fwidth(g).x, fwidth(g).y));
		c *= mix(0.9, 1.06, mix(h(floor(g)), 0.5, far));
		c *= 1.0 - 0.4 * grid_lines(g, 0.03);
		float stripe = band(lp.x + 0.9, 0.06) * (1.0 - step(24.0, lp.z)) * mix(step(0.3, n2), 0.7, far);
		c = mix(c, vec3(0.22, 0.48, 0.40), stripe * 0.8);
		float stain = vn(lp.xz * 0.25 + 3.0);
		c *= 1.0 - 0.25 * smoothstep(0.62, 0.7, stain) - 0.15 * (1.0 - smoothstep(0.0, 0.02, abs(stain - 0.66)));
		c *= 0.72 + 0.36 * n1;
	} else if (mode == 2) {
		float u = abs(ln.x) > 0.5 ? lp.z : lp.x;
		float y = lp.y;
		float fy = fwidth(y);
		c = mix(vec3(0.36, 0.45, 0.42), tint, smoothstep(1.1 - fy, 1.1 + fy, y));
		c = mix(c, vec3(0.22, 0.30, 0.28), band(y - 1.12, 0.04));
		// Small flakes of peeled paint showing grey plaster, gathered in patches.
		float patch = smoothstep(0.55, 0.75, vn(vec2(u, y) * 0.6 + 9.0));
		float peel = smoothstep(0.5, 0.56, vn(vec2(u, y) * 7.0 + 3.0) * patch) * smoothstep(1.25 - fy, 1.25 + fy, y);
		peel *= 1.0 - 0.6 * smoothstep(0.03, 0.12, max(fwidth(u), fy) * 7.0); // flakes smaller than a pixel turn into a soft patch
		c = mix(c, vec3(0.66, 0.64, 0.6) * (0.85 + 0.2 * n2), peel);
		c *= 1.0 - 0.28 * smoothstep(0.55, 0.9, vn(vec2(u * 6.0, y * 0.25))) * smoothstep(1.2, 4.0, y);
		c *= mix(0.55, 1.0, smoothstep(0.0, 0.45, y + n1 * 0.2));
		c *= 0.88 + 0.16 * n1;
	} else if (mode == 3) {
		vec2 g = lp.xz / 0.6;
		float far = smoothstep(0.05, 0.2, max(fwidth(g).x, fwidth(g).y));
		c *= mix(0.88, 1.04, mix(h(floor(g) + 5.0), 0.5, far));
		c = mix(c, vec3(0.42, 0.44, 0.45), grid_lines(g, 0.04));
		c = mix(c, vec3(0.55, 0.44, 0.30), smoothstep(0.6, 0.75, vn(lp.xz * 0.4 + 7.0)) * 0.6);
		c = mix(c, vec3(0.03), step(h(floor(g) + 11.0), 0.07));
		c *= 0.85 + 0.2 * n2;
	} else if (mode == 0) {
		c *= 0.82 + 0.3 * n1;
		c *= 1.0 - 0.15 * smoothstep(0.6, 0.85, n2);
	}
	if (mode == 4) {
		ALBEDO = COLOR.rgb * 0.2;
		EMISSION = COLOR.rgb * 3.0;
	} else {
		ALBEDO = c * COLOR.rgb;
	}
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.3;
}
// Inside the corridor: x(y) = how far the point sits inside both holes along its sun ray (metres, negative = blocked),
// y = the penumbra width there. Outside the corridor: x = -100 (not handled).
vec2 sun_gap(vec3 p, vec3 s) {
	if (abs(p.x) > {HALF_W} + 0.02 || p.z < -0.02 || p.z > {LENGTH} + 0.02 || p.y > {CEILING} + 0.02 || s.y < 0.02) {
		return vec2(-100.0, 0.0);
	}
	float t_roof = ({ROOF_TOP} - p.y) / s.y;
	float t_ceil = ({CEILING} + 0.04 - p.y) / s.y;
	vec2 r = p.xz + s.xz * t_roof;
	vec2 c = p.xz + s.xz * t_ceil;
	float d_roof = min(min(r.x - {HOLE_X0}, {HOLE_X1} - r.x), min(r.y - {HOLE_Z0}, {HOLE_Z1} - r.y));
	float d_ceil = min(min(c.x - {CEIL_X0}, {CEIL_X1} - c.x), min(c.y - {CEIL_Z0}, {CEIL_Z1} - c.y));
	// The sun's disc is 0.53 degrees wide: the penumbra grows with the distance the light travelled past the hole edge.
	return vec2(min(d_roof, d_ceil), max(t_roof * 0.0093, 0.05));
}
void light() {
	float att = ATTENUATION;
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 s = transpose(mat3(MODEL_MATRIX)) * (mat3(INV_VIEW_MATRIX) * LIGHT);
		vec2 g = sun_gap(lp, normalize(s));
		if (g.x > -50.0) {
			float lit = smoothstep(-g.y, g.y, g.x);
			float inner = smoothstep(g.y, g.y + 0.25, g.x);
			att = lit * mix(1.0, ATTENUATION, inner);
		}
	}
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * att * LIGHT_COLOR / PI;
}
"""

const SHADER_SHAFT := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_front, shadows_disabled;
// Light shaft under the roof hole. The lit air is the roof hole swept along the sunlight (a slanted prism) cut by the
// corridor (floor and walls), so it ends exactly where the sunlight lands. Drawn on the back faces of a box around it:
// each pixel intersects its view ray with the prism and with the corridor box (two slab tests) and glows with the
// length of air it crosses. Coordinates are the shaft node's (the hospital frame shifted to the box centre).
uniform vec3 col : source_color = vec3(1.0, 0.9, 0.7);
uniform float strength = 0.0;
uniform vec3 prism_o; // roof hole centre at the roof top
uniform mat3 prism_inv; // inverse of (hole width, light path to below the floor, hole depth): prism = [-0.5, 0.5] x [0, 1] x [-0.5, 0.5]
uniform vec3 clip_min;
uniform vec3 clip_max;
varying vec3 lp;
varying vec3 cam;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1.0, 0.0)), f.x), mix(h(i + vec2(0.0, 1.0)), h(i + vec2(1.0, 1.0)), f.x), f.y);
}
vec2 slab(vec3 ro, vec3 rd, vec3 lo, vec3 hi) {
	vec3 inv = 1.0 / (rd + vec3(1e-6));
	vec3 a = (lo - ro) * inv;
	vec3 b = (hi - ro) * inv;
	vec3 t0 = min(a, b);
	vec3 t1 = max(a, b);
	return vec2(max(max(t0.x, t0.y), t0.z), min(min(t1.x, t1.y), t1.z));
}
void vertex() {
	lp = VERTEX;
	cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}
void fragment() {
	// Ray from the camera (t = 0) to this back face (t = 1); anything in front of the face hides it by depth test.
	vec3 rd = lp - cam;
	vec2 room = slab(cam, rd, clip_min, clip_max);
	vec2 beam = slab(prism_inv * (cam - prism_o), prism_inv * rd, vec3(-0.5, 0.0, -0.5), vec3(0.5, 1.0, 0.5));
	float t0 = max(max(room.x, beam.x), 0.0);
	float t1 = min(min(room.y, beam.y), 1.0);
	float metres = max(t1 - t0, 0.0) * length(rd);
	vec3 mid = cam + rd * (t0 + t1) * 0.5;
	float dust = 0.75 + 0.5 * vn(vec2(mid.x * 3.0 + mid.z * 2.0, mid.y * 4.0 - TIME * 0.3));
	ALBEDO = col;
	ALPHA = clamp(strength * (1.0 - exp(-metres * 0.4)) * dust * 0.45, 0.0, 1.0);
}
"""

static var hospital_shader := shader_of(SHADER_HOSPITAL.format(shader_constants()))
static var shaft_shader := shader_of(SHADER_SHAFT)
var rng := RandomNumberGenerator.new()
var tools := {}

# Building sizes the hospital shader needs for the analytic sun (Issue #52), written into the code as constants.
static func shader_constants() -> Dictionary:
	return {
		"HALF_W": "%.3f" % (CORRIDOR_W * 0.5), "LENGTH": "%.3f" % LENGTH, "CEILING": "%.3f" % CEILING, "ROOF_TOP": "%.3f" % ROOF_TOP,
		"HOLE_X0": "%.3f" % HOLE.position.x, "HOLE_X1": "%.3f" % HOLE.end.x, "HOLE_Z0": "%.3f" % HOLE.position.y, "HOLE_Z1": "%.3f" % HOLE.end.y,
		"CEIL_X0": "%.3f" % CEILING_HOLE.position.x, "CEIL_X1": "%.3f" % CEILING_HOLE.end.x,
		"CEIL_Z0": "%.3f" % CEILING_HOLE.position.y, "CEIL_Z1": "%.3f" % CEILING_HOLE.end.y,
	}

# Same rule as sun_gap() in the shader (for tests): how far inside both holes the sun ray from p passes (m), and the penumbra.
static func sun_gap(p: Vector3, to_sun: Vector3) -> Vector2:
	var s := to_sun.normalized()
	if absf(p.x) > CORRIDOR_W * 0.5 + 0.02 or p.z < -0.02 or p.z > LENGTH + 0.02 or p.y > CEILING + 0.02 or s.y < 0.02:
		return Vector2(-100.0, 0.0)
	var t_roof := (ROOF_TOP - p.y) / s.y
	var t_ceil := (CEILING + 0.04 - p.y) / s.y
	var r := Vector2(p.x, p.z) + Vector2(s.x, s.z) * t_roof
	var c := Vector2(p.x, p.z) + Vector2(s.x, s.z) * t_ceil
	var d_roof := minf(minf(r.x - HOLE.position.x, HOLE.end.x - r.x), minf(r.y - HOLE.position.y, HOLE.end.y - r.y))
	var d_ceil := minf(minf(c.x - CEILING_HOLE.position.x, CEILING_HOLE.end.x - c.x), minf(c.y - CEILING_HOLE.position.y, CEILING_HOLE.end.y - c.y))
	return Vector2(minf(d_roof, d_ceil), maxf(t_roof * 0.0093, 0.05))

static func shader_of(code: String) -> Shader:
	var s := Shader.new()
	s.code = code
	return s

static func material(kind: String) -> ShaderMaterial:
	var k: Array = KINDS[kind]
	var m := ShaderMaterial.new()
	m.shader = hospital_shader
	m.set_shader_parameter("tint", k[0])
	m.set_shader_parameter("mode", k[1])
	m.set_shader_parameter("rough", k[2])
	m.set_shader_parameter("metal", k[3])
	return m

static func build(seed_value: int = 5) -> Node3D:
	var b := new()
	b.rng.seed = seed_value
	return b.make()

# Chunk of a part by its centre: corridor thirds, exam room, stairwell.
static func chunk_of(p: Vector3) -> String:
	if p.z > LENGTH + T * 0.5:
		return "stair"
	if p.x > CORRIDOR_W * 0.5 + T and p.z > ROOM.position.y - T - 0.01 and p.z < ROOM.end.y + T + 0.01:
		return "room"
	return "c%d" % clampi(int(p.z / 8.0), 0, 2)

func tool(chunk: String, kind: String) -> SurfaceTool:
	var key := chunk + "/" + kind
	if not tools.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[key] = st
	return tools[key]

# Appends a primitive mesh to its chunk's merged mesh. Props get baked AO toward the floor; structure only a small jitter
# (its boxes are metres tall, and per-vertex AO would shade whole walls). glow passes its colour instead of AO.
func add(kind: String, mesh: Mesh, xf: Transform3D, glow := Color.BLACK) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var st := tool(chunk_of(xf.origin), kind)
	var jit := 1.0 + rng.randf_range(-0.05, 0.05)
	var nb := xf.basis.inverse().transposed()
	for i in index:
		var p := xf * verts[i]
		var a := jit if kind in STRUCTURE else jit * lerpf(0.6, 1.0, clampf(p.y / 0.5, 0.0, 1.0))
		st.set_normal((nb * normals[i]).normalized())
		st.set_color(glow if kind == "glow" else Color(a, a, a))
		st.add_vertex(p)

func block(kind: String, a: Vector3, b: Vector3, glow := Color.BLACK) -> void:
	var bm := BoxMesh.new()
	bm.size = (b - a).abs()
	add(kind, bm, Transform3D(Basis(), (a + b) * 0.5), glow)

func box(kind: String, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	add(kind, bm, Transform3D(Basis.from_euler(rot), pos + Vector3(0, size.y * 0.5, 0)))

func line(kind: String, a: Vector3, b: Vector3, r: float) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = a.distance_to(b)
	c.radial_segments = 8
	c.rings = 1
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.FORWARD if absf(dir.z) < 0.99 else Vector3.RIGHT).normalized()
	add(kind, c, Transform3D(Basis(side, dir, side.cross(dir)), (a + b) * 0.5))

# A grid sheet f(u, v) -> point (curtains, sheets), merged into the kind's mesh.
func sheet(kind: String, f: Callable, nu: int, nv: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	var center := Vector3.ZERO
	for j in range(nv + 1):
		for i in range(nu + 1):
			pts.append(f.call(float(i) / nu, float(j) / nv))
			center += pts[-1]
	# Built around its centre so add() files the sheet under the right chunk.
	center /= pts.size()
	for i in range(pts.size()):
		pts[i] -= center
	for j in range(nv):
		for i in range(nu):
			var q := j * (nu + 1) + i
			for k in [q, q + 1, q + nu + 2, q, q + nu + 2, q + nu + 1]:
				st.add_vertex(pts[k])
	st.generate_normals()
	st.index()
	add(kind, st.commit(), Transform3D(Basis(), center))

# Wall along z (at x) or along x (at z) from s0 to s1, from below the floor to top, with openings Rect2(s, y, width, height).
func wall(along_z: bool, at: float, s0: float, s1: float, holes: Array[Rect2] = [], top := ROOF_TOP) -> void:
	var cuts: Array[float] = [s0, s1]
	for r in holes:
		cuts.append(clampf(r.position.x, s0, s1))
		cuts.append(clampf(r.end.x, s0, s1))
	cuts.sort()
	for i in range(cuts.size() - 1):
		var a := cuts[i]
		var b := cuts[i + 1]
		if b - a < 0.001:
			continue
		var spans: Array[Vector2] = [Vector2(-0.6, top)]
		for r in holes:
			if (a + b) * 0.5 > r.position.x and (a + b) * 0.5 < r.end.x:
				spans = [Vector2(-0.6, r.position.y), Vector2(r.end.y, top)]
		for sp in spans:
			if sp.y - sp.x < 0.001:
				continue
			if along_z:
				block("wall", Vector3(at - T * 0.5, sp.x, a), Vector3(at + T * 0.5, sp.y, b))
			else:
				block("wall", Vector3(a, sp.x, at - T * 0.5), Vector3(b, sp.y, at + T * 0.5))

# Horizontal plate over x0..x1, z0..z1 with an optional rectangular hole (x, z).
func plate(kind: String, y0: float, y1: float, x0: float, x1: float, z0: float, z1: float, hole := Rect2()) -> void:
	var hz0 := clampf(hole.position.y, z0, z1)
	var hz1 := clampf(hole.end.y, z0, z1)
	if hole.size == Vector2.ZERO or hz1 - hz0 < 0.001:
		block(kind, Vector3(x0, y0, z0), Vector3(x1, y1, z1))
		return
	for zs in [Vector2(z0, hz0), Vector2(hz1, z1)]:
		if zs.y - zs.x > 0.001:
			block(kind, Vector3(x0, y0, zs.x), Vector3(x1, y1, zs.y))
	if hole.position.x - x0 > 0.001:
		block(kind, Vector3(x0, y0, hz0), Vector3(hole.position.x, y1, hz1))
	if x1 - hole.end.x > 0.001:
		block(kind, Vector3(hole.end.x, y0, hz0), Vector3(x1, y1, hz1))

func shell() -> void:
	var w := CORRIDOR_W * 0.5
	for i in range(3):
		var z0 := i * 8.0
		var z1 := z0 + 8.0
		block("floor", Vector3(-w, -0.6, z0), Vector3(w, 0.0, z1))
		wall(true, -w - T * 0.5, z0, z1)
		wall(true, w + T * 0.5, z0, z1, [ROOM_DOOR])
		plate("ceiling", CEILING, CEILING + 0.04, -w, w, z0, z1, CEILING_HOLE)
		plate("slab", ROOF, ROOF_TOP, -w, w, z0, z1, HOLE)
	wall(false, -T * 0.5, -w - T, w + T)
	wall(false, LENGTH + T * 0.5, -w - T, w + T, [STAIR_DOOR])
	# Exam room east of the corridor.
	block("floor", Vector3(ROOM.position.x, -0.6, ROOM.position.y), Vector3(ROOM.end.x, 0.0, ROOM.end.y))
	wall(false, ROOM.position.y - T * 0.5, w + T, ROOM.end.x + T)
	wall(false, ROOM.end.y + T * 0.5, w + T, ROOM.end.x + T)
	wall(true, ROOM.end.x + T * 0.5, ROOM.position.y - T, ROOM.end.y + T, [WINDOW])
	plate("ceiling", CEILING, CEILING + 0.04, ROOM.position.x, ROOM.end.x, ROOM.position.y, ROOM.end.y)
	plate("slab", ROOF, ROOF_TOP, ROOM.position.x, ROOM.end.x, ROOM.position.y, ROOM.end.y)
	# Stairwell beyond the corridor end, two floors tall.
	var s0 := LENGTH + T
	var s1 := s0 + STAIR_LENGTH
	block("floor", Vector3(-w, -0.6, s0), Vector3(w, 0.0, s1))
	wall(true, -w - T * 0.5, s0, s1, [], STAIR_TOP)
	wall(true, w + T * 0.5, s0, s1, [], STAIR_TOP)
	wall(false, s1 + T * 0.5, -w - T, w + T, [], STAIR_TOP)
	block("wall", Vector3(-w - T, ROOF_TOP, LENGTH), Vector3(w + T, STAIR_TOP, LENGTH + T))
	plate("slab", STAIR_TOP - 0.3, STAIR_TOP, -w, w, s0, s1)

func stairs() -> void:
	var w := CORRIDOR_W * 0.5
	var s0 := LENGTH + T + 0.5
	var run := 0.3
	var rise := ROOF_TOP / 24.0
	for k in range(12):
		var z := s0 + k * run
		block("slab", Vector3(-w, 0.0, z), Vector3(0.0, (k + 1) * rise, z + run))
		block("trim", Vector3(-w, (k + 1) * rise, z - 0.02), Vector3(0.0, (k + 1) * rise + 0.02, z + 0.03))
	var landing := s0 + 12 * run
	block("slab", Vector3(-w, 0.0, landing), Vector3(w, 12 * rise, EXTENT))
	for k in range(12):
		var z := landing - (k + 1) * run
		var top := (13 + k) * rise
		block("slab", Vector3(0.0, top - 0.35, z), Vector3(w, top, z + run))
		block("trim", Vector3(0.0, top, z + run - 0.03), Vector3(w, top + 0.02, z + run + 0.02))
	block("slab", Vector3(0.0, ROOF_TOP - 0.35, LENGTH + T), Vector3(w, ROOF_TOP, s0))
	block("door", Vector3(-0.7, ROOF_TOP, LENGTH + T), Vector3(0.7, ROOF_TOP + 2.2, LENGTH + T + 0.05))
	# Balustrade between the flights: posts and a sloped rail.
	for k in range(0, 13, 3):
		var z := s0 + k * run
		line("metal", Vector3(0.0, k * rise, z), Vector3(0.0, k * rise + 1.0, z), 0.025)
	line("metal", Vector3(0.0, 1.0, s0), Vector3(0.0, 12 * rise + 1.0, landing), 0.03)

func trims() -> void:
	var w := CORRIDOR_W * 0.5
	for i in range(3):
		var z0 := i * 8.0 + 0.05
		var z1 := z0 + 7.9
		for s in [-1.0, 1.0]:
			block("trim", Vector3(s * w - s * 0.02, 0.0, z0), Vector3(s * w - s * 0.04, 0.12, z1))
			if s < 0.0 or z1 < ROOM_DOOR.position.x or z0 > ROOM_DOOR.end.x:
				line("trim", Vector3(s * (w - 0.07), 0.9, z0 + 0.2), Vector3(s * (w - 0.07), 0.9, z1 - 0.2), 0.03)
			else:
				line("trim", Vector3(w - 0.07, 0.9, z0 + 0.2), Vector3(w - 0.07, 0.9, ROOM_DOOR.position.x - 0.3), 0.03)
				line("trim", Vector3(w - 0.07, 0.9, ROOM_DOOR.end.x + 0.3), Vector3(w - 0.07, 0.9, z1 - 0.2), 0.03)
		# Two pipes under the ceiling along the west wall, with brackets.
		for px in [-1.22, -1.05]:
			line("metal", Vector3(px, 3.72, z0), Vector3(px, 3.72, z1), 0.05)
		for z in [z0 + 1.0, z0 + 5.0]:
			block("metal", Vector3(-w, 3.64, z), Vector3(-0.98, 3.68, z + 0.06))
	# Dead fluorescent fittings along the ceiling (not under the hole).
	for k in range(8):
		var z := 1.5 + k * 3.0
		if z + 0.6 > CEILING_HOLE.position.y and z - 0.6 < CEILING_HOLE.end.y:
			continue
		block("trim", Vector3(-0.35, CEILING - 0.08, z - 0.6), Vector3(0.35, CEILING, z + 0.6))
		block("lamp", Vector3(-0.3, CEILING - 0.1, z - 0.55), Vector3(0.3, CEILING - 0.08, z + 0.55))
	for z in [9.0, 12.0]:
		block("trim", Vector3(4.3, CEILING - 0.08, z - 0.6), Vector3(5.0, CEILING, z + 0.6))
		block("lamp", Vector3(4.35, CEILING - 0.1, z - 0.55), Vector3(4.95, CEILING - 0.08, z + 0.55))

# A closed door set into a wall (side -1 = west wall), with frame, kick plate, vision panel and handle.
func door(z: float, side: float) -> void:
	var x := side * CORRIDOR_W * 0.5
	var d := -side * 0.04
	block("door", Vector3(x, 0.0, z - 0.55), Vector3(x + d, 2.2, z + 0.55))
	block("trim", Vector3(x, 2.2, z - 0.65), Vector3(x + d * 1.5, 2.3, z + 0.65))
	for s in [-1.0, 1.0]:
		block("trim", Vector3(x, 0.0, z + s * 0.55), Vector3(x + d * 1.5, 2.3, z + s * 0.65))
	block("metal", Vector3(x + d, 0.0, z - 0.5), Vector3(x + d * 1.3, 0.3, z + 0.5))
	block("glass", Vector3(x + d, 1.3, z - 0.15), Vector3(x + d * 1.2, 1.8, z + 0.15))
	block("metal", Vector3(x + d, 1.0, z + 0.3), Vector3(x + d * 2.5, 1.05, z + 0.42))

func doors() -> void:
	var w := CORRIDOR_W * 0.5
	door(4.1, -1.0)
	door(16.1, -1.0)
	# Chained double door at the corridor start.
	for s in [-1.0, 1.0]:
		block("door", Vector3(s * 0.05, 0.0, 0.0), Vector3(s * 0.8, 2.3, 0.05))
		block("glass", Vector3(s * 0.3, 1.3, 0.05), Vector3(s * 0.6, 1.8, 0.06))
		block("metal", Vector3(s * 0.08, 0.95, 0.05), Vector3(s * 0.12, 1.25, 0.1))
	for k in range(6):
		var a := Vector3(-0.12 + k * 0.05, 1.1 - absf(k - 2.5) * 0.03, 0.1)
		line("metal", a, a + Vector3(0.05, 0.0, 0.0), 0.015)
	block("trim", Vector3(-0.9, 2.3, 0.0), Vector3(0.9, 2.4, 0.07))
	# Exam room door frame and the leaf swung open into the room.
	var z0 := ROOM_DOOR.position.x
	var z1 := ROOM_DOOR.end.x
	block("trim", Vector3(w - 0.03, ROOM_DOOR.end.y, z0 - 0.1), Vector3(w + T + 0.03, ROOM_DOOR.end.y + 0.1, z1 + 0.1))
	for z in [z0 - 0.1, z1]:
		block("trim", Vector3(w - 0.03, 0.0, z), Vector3(w + T + 0.03, ROOM_DOOR.end.y, z + 0.1))
	var leaf := BoxMesh.new()
	leaf.size = Vector3(0.05, 2.2, 1.3)
	add("door", leaf, Transform3D(Basis(Vector3.UP, deg_to_rad(75.0)), Vector3(w + T, 1.1, z0)) * Transform3D(Basis(), Vector3(0, 0, 0.65)))
	# Stairwell door frame.
	block("trim", Vector3(STAIR_DOOR.position.x - 0.1, STAIR_DOOR.end.y, LENGTH - 0.03), Vector3(STAIR_DOOR.end.x + 0.1, STAIR_DOOR.end.y + 0.1, LENGTH + T + 0.03))
	for x in [STAIR_DOOR.position.x - 0.1, STAIR_DOOR.end.x]:
		block("trim", Vector3(x, 0.0, LENGTH - 0.03), Vector3(x + 0.1, STAIR_DOOR.end.y, LENGTH + T + 0.03))

func props() -> void:
	var w := CORRIDOR_W * 0.5
	# Gurney against the east wall: frame, wheels, mattress and a crumpled sheet.
	gurney(Vector3(1.0, 0.0, 5.5), 0.08)
	# Metal cabinet on the west wall with one drawer pulled out.
	box("metal", Vector3(0.45, 1.9, 1.0), Vector3(-w + 0.25, 0.0, 12.5))
	for k in range(4):
		var y := 0.15 + k * 0.42
		block("trim", Vector3(-w + 0.47, y, 12.05), Vector3(-w + 0.49, y + 0.02, 12.95))
	box("metal", Vector3(0.4, 0.3, 0.8), Vector3(-w + 0.6, 0.6, 12.5))
	# Overturned chair and a wheelchair-sized cart.
	box("metal", Vector3(0.45, 0.06, 0.45), Vector3(-0.5, 0.25, 7.6), Vector3(1.2, 0.4, 0.0))
	for s in [-1.0, 1.0]:
		line("metal", Vector3(-0.5 + s * 0.2, 0.02, 7.3), Vector3(-0.5 + s * 0.2, 0.45, 7.95), 0.015)
	box("metal", Vector3(0.5, 0.8, 0.7), Vector3(0.9, 0.0, 20.8), Vector3(0.0, 0.3, 0.0))
	box("paper", Vector3(0.4, 0.15, 0.3), Vector3(0.9, 0.8, 20.8), Vector3(0.0, 0.5, 0.0))
	debris(Vector3(HOLE.get_center().x, 0.0, HOLE.get_center().y))
	# Loose papers along the corridor.
	for k in range(30):
		var p := Vector3(rng.randf_range(-w + 0.2, w - 0.2), 0.005, rng.randf_range(0.5, LENGTH - 0.5))
		box("paper", Vector3(0.21, 0.003, 0.3), p, Vector3(0.0, rng.randf() * TAU, 0.0))
	# Exam room: bed, tall cabinet, desk with chair, IV stand, curtain on a rail, sink.
	var r0 := ROOM.position
	var r1 := ROOM.end
	gurney(Vector3(r1.x - 0.6, 0.0, 12.4), 0.0)
	box("metal", Vector3(0.5, 2.0, 1.1), Vector3(r1.x - 0.3, 0.0, r0.y + 0.8))
	box("glass", Vector3(0.02, 1.0, 0.9), Vector3(r1.x - 0.56, 0.9, r0.y + 0.8))
	box("wood", Vector3(1.4, 0.05, 0.7), Vector3(r0.x + 1.6, 0.74, r1.y - 0.4))
	for s in [-1.0, 1.0]:
		box("wood", Vector3(0.05, 0.74, 0.65), Vector3(r0.x + 1.6 + s * 0.65, 0.0, r1.y - 0.4))
	box("metal", Vector3(0.45, 0.05, 0.45), Vector3(r0.x + 1.5, 0.45, r1.y - 1.0), Vector3(0.0, 0.4, 0.0))
	box("paper", Vector3(0.3, 0.06, 0.22), Vector3(r0.x + 1.3, 0.79, r1.y - 0.4), Vector3(0.0, 0.3, 0.0))
	line("metal", Vector3(r1.x - 1.6, 0.0, 11.4), Vector3(r1.x - 1.6, 1.9, 11.4), 0.015)
	line("metal", Vector3(r1.x - 1.85, 1.9, 11.4), Vector3(r1.x - 1.35, 1.9, 11.4), 0.012)
	box("fabric", Vector3(0.12, 0.2, 0.05), Vector3(r1.x - 1.75, 1.6, 11.4))
	var rail_x := r0.x + 2.6
	line("metal", Vector3(rail_x, 2.6, 8.6), Vector3(rail_x, 2.6, 13.2), 0.015)
	sheet("fabric", func(u: float, v: float) -> Vector3:
		return Vector3(rail_x + 0.12 * sin(u * 22.0) * (0.4 + 0.6 * v), lerpf(2.58, 0.35 + 0.1 * sin(u * 9.0), v), lerpf(8.6, 11.0, u)), 32, 6)
	box("trim", Vector3(0.5, 0.2, 0.4), Vector3(r0.x + 0.3, 0.85, r0.y + 0.4))
	box("metal", Vector3(0.06, 0.85, 0.06), Vector3(r0.x + 0.3, 0.0, r0.y + 0.4))
	debris(Vector3(r0.x + 3.5, 0.0, r0.y + 1.5), 0.4)
	# Window boarded with planks; gaps let sunlight in when the sun is on that side.
	var wx := r1.x + T + 0.03
	for k in range(4):
		var y := WINDOW.position.y + 0.12 + k * 0.33
		box("wood", Vector3(0.03, 0.2, 3.4), Vector3(wx, y, WINDOW.get_center().x), Vector3(rng.randf_range(-0.06, 0.06), 0.0, 0.0))

func gurney(at: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	for sx in [-0.3, 0.3]:
		for sz in [-0.9, 0.9]:
			var foot := at + b * Vector3(sx, 0.0, sz)
			line("metal", foot + Vector3(0, 0.08, 0), foot + Vector3(0, 0.62, 0), 0.02)
			add("trim", cyl_mesh(0.06, 0.04), Transform3D(Basis(Vector3.BACK, PI / 2.0), foot + Vector3(0, 0.06, 0)))
	add("metal", box_mesh(Vector3(0.66, 0.05, 1.9)), Transform3D(b, at + Vector3(0, 0.62, 0)))
	add("fabric", box_mesh(Vector3(0.62, 0.12, 1.85)), Transform3D(b, at + Vector3(0, 0.71, 0)))
	sheet("paper", func(u: float, v: float) -> Vector3:
		var lx := lerpf(-0.36, 0.36, u)
		var lz := lerpf(-0.5, 0.92, v)
		var drop := 0.0 if absf(lx) < 0.31 else (absf(lx) - 0.31) * 3.0
		var y := 0.78 + 0.05 * sin(u * 13.0 + v * 7.0) * sin(PI * v) - drop
		return at + b * Vector3(lx, y, lz), 10, 10)

func debris(at: Vector3, amount := 1.0) -> void:
	# Fallen slab chunks and ceiling tiles in a pile, larger near the middle.
	for k in range(int(26 * amount)):
		var r := rng.randf() * 1.2 * sqrt(amount)
		var a := rng.randf() * TAU
		var p := at + Vector3(cos(a) * r, 0.0, sin(a) * r * 1.3)
		var s := rng.randf_range(0.08, 0.35) * (1.4 - r * 0.6)
		box("debris", Vector3(s, s * rng.randf_range(0.4, 0.9), s * rng.randf_range(0.7, 1.3)), p, Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)))
	for k in range(int(6 * amount)):
		var p := at + Vector3(rng.randf_range(-1.0, 1.0), 0.02, rng.randf_range(-1.4, 1.4))
		box("ceiling", Vector3(0.6, 0.02, 0.6), p, Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, 0.0))
	if amount >= 1.0:
		# A tile hanging from the hole edge, and rebar sticking out of the roof slab.
		var tile := box_mesh(Vector3(0.6, 0.02, 0.6))
		add("ceiling", tile, Transform3D(Basis(Vector3.RIGHT, 1.1), Vector3(-0.6, CEILING - 0.27, CEILING_HOLE.position.y + 0.05)))
		# Bare T-bar grid left where the tiles fell.
		for k in range(1, int(CEILING_HOLE.size.y / 0.6)):
			var z := CEILING_HOLE.position.y + k * 0.6
			block("tbar", Vector3(-CORRIDOR_W * 0.5, CEILING, z - 0.015), Vector3(CORRIDOR_W * 0.5 - 0.6 * float(k % 3 == 0), CEILING + 0.03, z + 0.015))
		for k in range(5):
			var x := lerpf(HOLE.position.x, HOLE.end.x, (k + 0.5) / 5.0)
			line("tbar", Vector3(x, ROOF + 0.1, HOLE.end.y - 0.05), Vector3(x + 0.05, ROOF - 0.25 - rng.randf() * 0.2, HOLE.end.y - 0.3), 0.01)

func box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func cyl_mesh(r: float, length: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = length
	c.radial_segments = 8
	c.rings = 1
	return c

# Emergency lights: red lamps over doors (one flickers) and a green exit sign over the stairwell door, no shadows.
func lights(root: Node3D) -> void:
	var w := CORRIDOR_W * 0.5
	var spots := [
		["emergency_a", Vector3(w - 0.12, 3.15, ROOM_DOOR.get_center().x), RED, 1.2, 6.0],
		["emergency_b", Vector3(-w + 0.12, 3.15, 16.1), RED, 1.2, 6.0],
		["exit", Vector3(0.0, 2.75, LENGTH - 0.2), GREEN, 0.5, 4.5],
	]
	for s in spots:
		var p: Vector3 = s[1]
		var wall_n := Vector3(0, 0, -1) if s[0] == "exit" else Vector3(-signf(p.x), 0, 0)
		block("trim", p - Vector3(0.12, 0.08, 0.12) + wall_n * -0.08, p + Vector3(0.12, 0.08, 0.12) + wall_n * -0.08)
		var lens := p + wall_n * 0.05
		if s[0] == "exit":
			block("glow", lens - Vector3(0.3, 0.1, 0.02), lens + Vector3(0.3, 0.1, 0.02), s[2])
		else:
			block("glow", lens - Vector3(0.06, 0.05, 0.06), lens + Vector3(0.06, 0.05, 0.06), s[2])
		var light := OmniLight3D.new()
		light.name = s[0]
		light.position = p + wall_n * 0.3
		light.light_color = s[2]
		light.light_energy = s[3]
		light.omni_range = s[4]
		light.omni_attenuation = 1.4
		light.shadow_enabled = false
		light.set_meta("energy", s[3])
		root.add_child(light)
	# Warm light bounced from where the sunlight lands; placed by aim().
	var bounce := OmniLight3D.new()
	bounce.name = "bounce"
	bounce.omni_range = 7.0
	bounce.shadow_enabled = false
	bounce.visible = false
	root.add_child(bounce)
	var shaft := MeshInstance3D.new()
	shaft.name = "shaft"
	shaft.mesh = box_mesh(Vector3.ONE)
	var m := ShaderMaterial.new()
	m.shader = shaft_shader
	shaft.material_override = m
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft.visible = false
	root.add_child(shaft)

func make() -> Node3D:
	shell()
	stairs()
	trims()
	doors()
	props()
	var root := Node3D.new()
	root.name = "hospital"
	lights(root)
	var keys := tools.keys()
	keys.sort()
	for key in keys:
		var node := MeshInstance3D.new()
		node.name = key.replace("/", "_")
		node.mesh = (tools[key] as SurfaceTool).commit()
		node.material_override = material(key.split("/")[1])
		if key.ends_with("/tbar"):
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(node)
	return root

# Where the sunlight through the roof hole lands: the first of floor or corridor walls along the ray (local frame).
static func landing(to_sun: Vector3) -> Vector3:
	var top := Vector3(HOLE.get_center().x, ROOF_TOP, HOLE.get_center().y)
	var d := -to_sun.normalized()
	var t := top.y / -d.y
	var w := CORRIDOR_W * 0.5
	if absf(d.x) > 1e-4:
		t = minf(t, (signf(d.x) * w - top.x) / d.x)
	if d.z < -1e-4:
		t = minf(t, -top.z / d.z)
	elif d.z > 1e-4:
		t = minf(t, (LENGTH - top.z) / d.z)
	return top + d * t

# The air lit through the roof hole, in the hospital frame: the prism (origin at the hole centre on the roof top, axes =
# hole width, light path from the roof top to below the floor, hole depth) and the corridor box that cuts it.
static func beam(to_sun: Vector3) -> Dictionary:
	var d := -to_sun.normalized()
	var w := CORRIDOR_W * 0.5
	var path := d * (ROOF_TOP / -d.y + 0.5)
	var z_low := clampf(HOLE.position.y + path.z, 0.0, HOLE.position.y)
	return {
		"origin": Vector3(HOLE.get_center().x, ROOF_TOP, HOLE.get_center().y),
		"axes": Basis(Vector3(HOLE.size.x, 0, 0), path, Vector3(0, 0, HOLE.size.y)),
		"clip": AABB(Vector3(-w, 0.0, z_low), Vector3(2.0 * w, ROOF_TOP, HOLE.end.y - z_low)),
	}

# Sun through the roof hole: the lit air (see beam()) and a warm bounce light where the centre of the light lands.
# to_sun is the direction toward the sun in the hospital's frame; energy is the sun's light energy.
static func aim(root: Node3D, to_sun: Vector3, energy: float, color: Color) -> void:
	var shaft := root.get_node("shaft") as MeshInstance3D
	var bounce := root.get_node("bounce") as OmniLight3D
	var lit := to_sun.normalized().y > 0.05 and energy > 0.0
	shaft.visible = lit
	bounce.visible = lit
	if not lit:
		return
	var end := landing(to_sun)
	var b := beam(to_sun)
	var clip: AABB = b.clip
	var center := clip.get_center()
	# The box mesh covers the clip box; the shader works in the shaft node's frame (hospital frame minus center).
	(shaft.mesh as BoxMesh).size = clip.size - Vector3.ONE * 2.0 * SHAFT_INSET
	shaft.transform = Transform3D(Basis(), center)
	var m := shaft.material_override as ShaderMaterial
	m.set_shader_parameter("prism_o", (b.origin as Vector3) - center)
	m.set_shader_parameter("prism_inv", (b.axes as Basis).inverse())
	m.set_shader_parameter("clip_min", clip.position - center)
	m.set_shader_parameter("clip_max", clip.end - center)
	m.set_shader_parameter("col", color)
	m.set_shader_parameter("strength", energy * to_sun.normalized().y)
	var inward := Vector3(-end.x, 0.0, 0.0).limit_length(0.5)
	bounce.position = end + inward + Vector3(0, 0.4, 0)
	bounce.light_color = color * Color(0.95, 0.85, 0.72)
	bounce.light_energy = energy * 0.6

# Flicker of the emergency_b lamp: mostly on, short drops (t in seconds).
static func flicker(root: Node3D, t: float) -> void:
	var light := root.get_node_or_null("emergency_b") as OmniLight3D
	if light == null:
		return
	var n := sin(t * 23.0) + sin(t * 7.1 + 1.3) + sin(t * 2.3)
	light.light_energy = float(light.get_meta("energy")) * (0.15 if n > 2.2 else 1.0)
