extends VBoxContainer
## Keyboard / gamepad / mouse driven cursor list. Items are dictionaries:
## {text, right?, enabled?, color?}. Emits `done(index)` (-1 when cancelled).

signal done(index: int)
signal moved(index: int)

var items: Array = []
var index := 0
var active := false:
	set(v):
		active = v
		_refresh()
var allow_cancel := true
var max_rows := 8
var row_height := 34.0

var _scroll := 0
var _rows: Array = []


func _init() -> void:
	add_theme_constant_override("separation", 2)


func set_items(new_items: Array, keep_index := false) -> void:
	items = new_items
	if not keep_index:
		index = 0
		_scroll = 0
	index = clampi(index, 0, maxi(0, items.size() - 1))
	_rebuild()


func current() -> Dictionary:
	if index < items.size():
		return items[index]
	return {}


## Activate the list and wait for a choice. Returns the index or -1 on cancel.
func choose() -> int:
	active = true
	var r: int = await done
	active = false
	return r


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_rows.clear()
	var count := mini(items.size(), max_rows)
	for i in count:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, row_height)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var cur := Label.new()
		cur.custom_minimum_size = Vector2(22, 0)
		cur.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		var txt := Label.new()
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.clip_text = true
		var right := Label.new()
		right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(cur)
		row.add_child(txt)
		row.add_child(right)
		row.gui_input.connect(_on_row_input.bind(i))
		row.mouse_entered.connect(_on_row_hover.bind(i))
		add_child(row)
		_rows.append([row, cur, txt, right])
	_refresh()


func _refresh() -> void:
	if index < _scroll:
		_scroll = index
	elif index >= _scroll + max_rows:
		_scroll = index - max_rows + 1
	for i in _rows.size():
		var item_idx := _scroll + i
		var r: Array = _rows[i]
		if item_idx >= items.size():
			r[0].visible = false
			continue
		r[0].visible = true
		var it: Dictionary = items[item_idx]
		var enabled: bool = it.get("enabled", true)
		r[2].text = it.get("text", "")
		r[3].text = it.get("right", "")
		var col: Color = it.get("color", Color(0.95, 0.93, 0.88))
		if not enabled:
			col = Color(0.5, 0.5, 0.55)
		r[2].add_theme_color_override("font_color", col)
		r[3].add_theme_color_override("font_color", col)
		var sel := item_idx == index
		r[1].text = "▶" if sel and active else ("▷" if sel else "")
		if i == 0 and _scroll > 0:
			r[1].text = "▲" if not sel else r[1].text
		if i == _rows.size() - 1 and _scroll + max_rows < items.size():
			r[1].text = "▼" if not sel else r[1].text


func _move(d: int) -> void:
	if items.is_empty():
		return
	index = wrapi(index + d, 0, items.size())
	Sfx.play("cursor")
	_refresh()
	moved.emit(index)


func _accept() -> void:
	if items.is_empty():
		return
	if not items[index].get("enabled", true):
		Sfx.play("buzz")
		return
	Sfx.play("confirm")
	done.emit(index)


func _unhandled_input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_up", true):
		_move(-1)
	elif event.is_action_pressed("ui_down", true):
		_move(1)
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_accept()
		return
	elif event.is_action_pressed("ui_cancel") and allow_cancel:
		get_viewport().set_input_as_handled()
		Sfx.play("cancel")
		done.emit(-1)
		return
	else:
		return
	get_viewport().set_input_as_handled()


func _on_row_input(event: InputEvent, row: int) -> void:
	if not active:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			index = _scroll + row
			_refresh()
			_accept()
		elif event.button_index == MOUSE_BUTTON_RIGHT and allow_cancel:
			Sfx.play("cancel")
			done.emit(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_move(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_move(-1)


func _on_row_hover(row: int) -> void:
	if not active or _scroll + row == index or _scroll + row >= items.size():
		return
	index = _scroll + row
	_refresh()
	moved.emit(index)
