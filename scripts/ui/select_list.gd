class_name SelectList
extends VBoxContainer
## Keyboard / gamepad / mouse driven cursor list. Rows are instances of
## `row_scene` (which must have Cursor, Text and Right labels).
## Items are dictionaries: {text, right?, enabled?, color?}.

signal done(index: int)   ## -1 when cancelled
signal moved(index: int)

const TEXT_COLOR := Color(0.95, 0.93, 0.88)
const DISABLED_COLOR := Color(0.5, 0.5, 0.55)

@export var row_scene: PackedScene = preload("res://scenes/ui/select_row.tscn")
@export var max_rows := 8
@export var allow_cancel := true

var items: Array = []
var index := 0
var active := false:
	set(v):
		active = v
		_refresh()

var _scroll := 0
var _rows: Array[Control] = []


func set_items(new_items: Array, keep_index := false) -> void:
	items = new_items
	if not keep_index:
		index = 0
		_scroll = 0
	index = clampi(index, 0, maxi(0, items.size() - 1))
	_rebuild()


## Activate the list and wait for a choice. Returns the index, or -1 on cancel.
func choose() -> int:
	active = true
	var r: int = await done
	active = false
	return r


func _rebuild() -> void:
	for c in _rows:
		c.queue_free()
	_rows.clear()
	for i in mini(items.size(), max_rows):
		var row: Control = row_scene.instantiate()
		row.gui_input.connect(_on_row_input.bind(i))
		row.mouse_entered.connect(_on_row_hover.bind(i))
		add_child(row)
		_rows.append(row)
	_refresh()


func _refresh() -> void:
	if index < _scroll:
		_scroll = index
	elif index >= _scroll + max_rows:
		_scroll = index - max_rows + 1
	for i in _rows.size():
		var row := _rows[i]
		var item_idx := _scroll + i
		if item_idx >= items.size():
			row.hide()
			continue
		row.show()
		var it: Dictionary = items[item_idx]
		var col: Color = it.get("color", TEXT_COLOR) if it.get("enabled", true) else DISABLED_COLOR
		var text: Label = row.get_node("Text")
		var right: Label = row.get_node("Right")
		text.text = it.get("text", "")
		right.text = it.get("right", "")
		text.add_theme_color_override("font_color", col)
		right.add_theme_color_override("font_color", col)
		var cursor := ""
		if item_idx == index:
			cursor = "▶" if active else "▷"
		elif i == 0 and _scroll > 0:
			cursor = "▲"
		elif i == _rows.size() - 1 and _scroll + max_rows < items.size():
			cursor = "▼"
		row.get_node("Cursor").text = cursor


func _move(d: int) -> void:
	if items.is_empty():
		return
	index = wrapi(index + d, 0, items.size())
	Audio.play_sfx(&"cursor")
	_refresh()
	moved.emit(index)


func _accept() -> void:
	if items.is_empty():
		return
	if not items[index].get("enabled", true):
		Audio.play_sfx(&"buzz")
		return
	Audio.play_sfx(&"confirm")
	done.emit(index)


func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_up", true):
		get_viewport().set_input_as_handled()
		_move(-1)
	elif event.is_action_pressed("ui_down", true):
		get_viewport().set_input_as_handled()
		_move(1)
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_accept()
	elif event.is_action_pressed("ui_cancel") and allow_cancel:
		get_viewport().set_input_as_handled()
		Audio.play_sfx(&"cancel")
		done.emit(-1)


func _on_row_input(event: InputEvent, row: int) -> void:
	if not active or not event is InputEventMouseButton or not event.pressed:
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			index = _scroll + row
			_refresh()
			_accept()
		MOUSE_BUTTON_RIGHT:
			if allow_cancel:
				Audio.play_sfx(&"cancel")
				done.emit(-1)
		MOUSE_BUTTON_WHEEL_DOWN:
			_move(1)
		MOUSE_BUTTON_WHEEL_UP:
			_move(-1)


func _on_row_hover(row: int) -> void:
	if not active or _scroll + row == index or _scroll + row >= items.size():
		return
	index = _scroll + row
	_refresh()
	moved.emit(index)
