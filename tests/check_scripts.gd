extends Node
## Loads every script in the project so parse/compile errors surface in headless runs.
## Run: godot --headless --path . res://tests/check_scripts.tscn

func _ready() -> void:
	var failed := 0
	for path in _scan("res://scripts"):
		var s := load(path) as GDScript
		if s == null or not s.can_instantiate():
			push_error("FAILED: " + path)
			failed += 1
	print("CHECK DONE, failures: %d" % failed)
	get_tree().quit(1 if failed > 0 else 0)


func _scan(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out += _scan(dir + "/" + sub)
	return out
