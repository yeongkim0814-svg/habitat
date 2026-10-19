extends SceneTree
## Headless checks for the M0 look-dev stage: structure only (the dummy renderer cannot compile shaders or draw).
const Looks = preload("res://spikes/m0_look/looks.gd")
const Stage = preload("res://spikes/m0_look/stage.gd")
const ROLES: Array[String] = ["street", "wall", "lamp", "soil", "rock", "stalk", "frond", "bulb", "ceiling"]
var failures := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)

func count(node: Node, type: String) -> int:
	var n := 1 if node.get_class() == type else 0
	for child in node.get_children():
		n += count(child, type)
	return n

func instances(node: Node) -> int:
	var n := 0
	if node is MultiMeshInstance3D:
		n += (node as MultiMeshInstance3D).multimesh.instance_count
	for child in node.get_children():
		n += instances(child)
	return n

func _init() -> void:
	for look in Looks.IDS:
		for role in ROLES:
			check(Looks.PALETTE[look].has(role), "%s palette has %s" % [look, role])
			var m := Looks.material(look, role, true)
			check(m.shader != null and m.shader.code.length() > 50, "%s/%s has shader code" % [look, role])
		check(Looks.environment(look).fog_enabled, "%s environment has fog" % look)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var root := Node3D.new()
		Stage.street(look, rng, root)
		Stage.field(look, rng, root)
		Stage.overhead(look, rng, root)
		# D19: repeated structures are MultiMeshes; only the two ground meshes are plain MeshInstance3D.
		check(count(root, "MeshInstance3D") == 2, "%s has only the 2 ground MeshInstance3D" % look)
		check(count(root, "MultiMeshInstance3D") >= 8, "%s uses MultiMeshes for repeats" % look)
		check(instances(root) > 2000, "%s has >2000 instances (got %d)" % [look, instances(root)])
		root.free()
	print("M0 tests: %s" % ("OK" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
