extends Node
## Loads every script, resource and scene (instantiating scenes) so parse,
## compile and missing-reference errors surface in headless runs.
## Run: godot --headless --path . res://tests/check_scripts.tscn

func _ready() -> void:
	var failed := 0
	for path in _scan("res://scripts", ".gd"):
		var s := load(path) as GDScript
		if s == null or not s.can_instantiate():
			push_error("FAILED script: " + path)
			failed += 1
	for path in _scan("res://data", ".tres") + _scan("res://resources", ".tres"):
		if load(path) == null:
			push_error("FAILED resource: " + path)
			failed += 1
	for path in _scan("res://scenes", ".tscn"):
		var ps := load(path) as PackedScene
		var n: Node = ps.instantiate() if ps else null
		if n == null:
			push_error("FAILED scene: " + path)
			failed += 1
		else:
			n.free()
	print("CHECK DONE, failures: %d" % failed)
	get_tree().quit(1 if failed > 0 else 0)


func _scan(dir: String, ext: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out += _scan(dir + "/" + sub, ext)
	return out
