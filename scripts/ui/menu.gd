extends CanvasLayer
## The classic JRPG party menu: Items, Skills, Equipment, Status.

const DB := preload("res://scripts/data/db.gd")
const PixelArt := preload("res://scripts/gfx/pixel_art.gd")
const SelectList := preload("res://scripts/ui/select_list.gd")
const StatBar := preload("res://scripts/ui/stat_bar.gd")

signal _nav(action: String)

const GOLD := Color(1.0, 0.84, 0.45)
const DIM := Color(0.7, 0.72, 0.85)
const UP := Color(0.45, 1.0, 0.55)
const DOWN := Color(1.0, 0.45, 0.45)

var root: Control
var cmd_list: SelectList
var help_label: Label
var content: PanelContainer
var gold_label: Label
var time_label: Label
var popup: PanelContainer
var popup_list: SelectList
var _nav_active := false
var _cards: Array = []
var _card_index := 0


func _ready() -> void:
	layer = 10
	visible = false
	_build()


func _process(_delta: float) -> void:
	if visible:
		time_label.text = Game.format_time()


func _build() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.05, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var cmd_panel := _panel(Vector2(40, 40), Vector2(270, 330))
	var cv := VBoxContainer.new()
	cmd_panel.add_child(cv)
	var title := Label.new()
	title.text = "MENU"
	title.add_theme_color_override("font_color", GOLD)
	cv.add_child(title)
	cmd_list = SelectList.new()
	cv.add_child(cmd_list)
	cmd_list.set_items([
		{"text": "Items"}, {"text": "Skills"}, {"text": "Equipment"}, {"text": "Status"}, {"text": "Close"},
	])
	cmd_list.moved.connect(_on_cmd_moved)

	var info := _panel(Vector2(40, 390), Vector2(270, 290))
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 6)
	info.add_child(iv)
	_kv(iv, "Location", "")
	var loc := Label.new()
	loc.text = "Castle Nocturne"
	iv.add_child(loc)
	_kv(iv, "Play Time", "")
	time_label = Label.new()
	iv.add_child(time_label)
	_kv(iv, "Gold", "")
	gold_label = Label.new()
	iv.add_child(gold_label)

	var help := _panel(Vector2(330, 40), Vector2(910, 64))
	help_label = Label.new()
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_child(help_label)

	content = _panel(Vector2(330, 120), Vector2(910, 560))

	popup = _panel(Vector2(800, 200), Vector2(430, 200))
	var pv := VBoxContainer.new()
	popup.add_child(pv)
	var pl := Label.new()
	pl.text = "Use on whom?"
	pl.add_theme_color_override("font_color", GOLD)
	pv.add_child(pl)
	popup_list = SelectList.new()
	pv.add_child(popup_list)
	popup.visible = false


func _panel(pos: Vector2, size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.size = size
	p.custom_minimum_size = size
	root.add_child(p)
	return p


func _kv(parent: Control, k: String, _v: String) -> void:
	var l := Label.new()
	l.text = k
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_font_size_override("font_size", 16)
	parent.add_child(l)


func _help(t: String) -> void:
	help_label.text = t


func _clear_content() -> Control:
	for c in content.get_children():
		c.queue_free()
	var holder := MarginContainer.new()
	content.add_child(holder)
	return holder


# ------------------------------------------------------------------ Main ---
func open() -> void:
	visible = true
	UI.menu_open = true
	gold_label.text = "%d G" % Game.gold
	cmd_list.index = 0
	_show_party()
	while true:
		_on_cmd_moved(cmd_list.index)
		var c := await cmd_list.choose()
		cmd_list.active = false
		match c:
			0:
				await _items_flow()
			1:
				var m := await _pick_member("Whose skills?")
				if m >= 0:
					await _skills_flow(m)
			2:
				var m := await _pick_member("Whose equipment?")
				if m >= 0:
					await _equip_flow(m)
			3:
				var m := await _pick_member("Whose status?")
				if m >= 0:
					await _status_flow(m)
			_:
				break
		_show_party()
	visible = false
	await get_tree().process_frame
	UI.menu_open = false


func _on_cmd_moved(i: int) -> void:
	var texts := [
		"Use items from the party's inventory.",
		"View and use skills.",
		"Change weapons and armor.",
		"View a member's detailed parameters.",
		"Close the menu.",
	]
	_help(texts[i])


# ---------------------------------------------------------- Party cards ---
func _show_party() -> void:
	var holder := _clear_content()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	holder.add_child(v)
	_cards.clear()
	for i in Game.party.size():
		var card := _make_card(Game.party[i])
		card.gui_input.connect(_on_card_input.bind(i))
		card.mouse_entered.connect(_on_card_hover.bind(i))
		v.add_child(card)
		_cards.append(card)
	_highlight_card(-1)


func _make_card(m: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 160)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 22)
	card.add_child(h)
	var cursor := Label.new()
	cursor.name = "Cursor"
	cursor.custom_minimum_size = Vector2(20, 0)
	cursor.add_theme_color_override("font_color", GOLD)
	cursor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(cursor)
	card.set_meta("cursor", cursor)
	var por := TextureRect.new()
	por.texture = PixelArt.portrait(DB.HEROES[m.id].sprite)
	por.custom_minimum_size = Vector2(132, 108)
	por.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	por.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	por.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not Game.is_alive(m):
		por.modulate = Color(0.5, 0.3, 0.3)
	h.add_child(por)
	var col1 := VBoxContainer.new()
	col1.custom_minimum_size = Vector2(250, 0)
	col1.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(col1)
	var name_l := Label.new()
	name_l.text = m.name
	name_l.add_theme_font_size_override("font_size", 26)
	col1.add_child(name_l)
	var job := Label.new()
	job.text = DB.HEROES[m.id].job
	job.add_theme_color_override("font_color", DIM)
	col1.add_child(job)
	var lv := Label.new()
	lv.text = "LV %d" % m.level
	lv.add_theme_color_override("font_color", GOLD)
	col1.add_child(lv)
	if not Game.is_alive(m):
		var ko := Label.new()
		ko.text = "KO"
		ko.add_theme_color_override("font_color", DOWN)
		col1.add_child(ko)
	var col2 := VBoxContainer.new()
	col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col2.alignment = BoxContainer.ALIGNMENT_CENTER
	col2.add_theme_constant_override("separation", 4)
	h.add_child(col2)
	_gauge(col2, "HP", m.hp, Game.max_hp(m), Color(0.4, 0.95, 0.5))
	_gauge(col2, "MP", m.mp, Game.max_mp(m), Color(0.45, 0.7, 1.0))
	var cur_exp: int = m.exp - Game.exp_for_level(m.level)
	var need: int = Game.exp_for_level(m.level + 1) - Game.exp_for_level(m.level)
	_gauge(col2, "EXP", cur_exp, need, Color(1.0, 0.8, 0.35), "Next %d" % Game.exp_to_next(m))
	return card


func _gauge(parent: Control, label: String, v: int, mx: int, color: Color, text := "") -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(56, 0)
	l.add_theme_color_override("font_color", GOLD)
	row.add_child(l)
	var num := Label.new()
	num.text = text if text != "" else "%d / %d" % [v, mx]
	num.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(num)
	parent.add_child(row)
	var bar := StatBar.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.max_value = mx
	bar.value = v
	bar.color = color
	parent.add_child(bar)


func _highlight_card(idx: int) -> void:
	for i in _cards.size():
		var card: PanelContainer = _cards[i]
		var sb := UI.panel_style(0.6)
		if i == idx:
			sb.bg_color = Color(0.16, 0.18, 0.4, 0.9)
			sb.border_color = Color(1.0, 0.9, 0.55)
		else:
			sb.border_color = Color(0.5, 0.45, 0.3)
		card.add_theme_stylebox_override("panel", sb)
		card.get_meta("cursor").text = "▶" if i == idx else ""


func _pick_member(prompt: String) -> int:
	_help(prompt)
	_card_index = clampi(_card_index, 0, Game.party.size() - 1)
	_highlight_card(_card_index)
	while true:
		var a: String = await _wait_nav()
		match a:
			"up":
				_card_index = wrapi(_card_index - 1, 0, _cards.size())
				Sfx.play("cursor")
				_highlight_card(_card_index)
			"down":
				_card_index = wrapi(_card_index + 1, 0, _cards.size())
				Sfx.play("cursor")
				_highlight_card(_card_index)
			"accept":
				Sfx.play("confirm")
				_highlight_card(-1)
				return _card_index
			"cancel":
				Sfx.play("cancel")
				_highlight_card(-1)
				return -1
	return -1


func _on_card_input(event: InputEvent, i: int) -> void:
	if _nav_active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_card_index = i
		_highlight_card(i)
		_nav.emit("accept")


func _on_card_hover(i: int) -> void:
	if _nav_active and i != _card_index:
		_card_index = i
		_highlight_card(i)


func _wait_nav() -> String:
	_nav_active = true
	var a: String = await _nav
	_nav_active = false
	return a


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _nav_active:
		return
	var a := ""
	if event.is_action_pressed("ui_up", true):
		a = "up"
	elif event.is_action_pressed("ui_down", true):
		a = "down"
	elif event.is_action_pressed("ui_left", true):
		a = "left"
	elif event.is_action_pressed("ui_right", true):
		a = "right"
	elif event.is_action_pressed("ui_accept"):
		a = "accept"
	elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		a = "cancel"
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		a = "cancel"
	if a != "":
		get_viewport().set_input_as_handled()
		_nav.emit(a)


# ---------------------------------------------------------------- Status ---
func _status_flow(idx: int) -> void:
	while true:
		_show_status(Game.party[idx])
		_help("◀ ▶ switch member    Cancel: back")
		var a: String = await _wait_nav()
		match a:
			"left", "up":
				idx = wrapi(idx - 1, 0, Game.party.size())
				Sfx.play("cursor")
			"right", "down":
				idx = wrapi(idx + 1, 0, Game.party.size())
				Sfx.play("cursor")
			"cancel", "accept":
				Sfx.play("cancel")
				return


func _show_status(m: Dictionary) -> void:
	var holder := _clear_content()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 28)
	holder.add_child(h)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(230, 0)
	h.add_child(left)
	var spr := TextureRect.new()
	spr.texture = PixelArt.sprite(DB.HEROES[m.id].sprite)
	spr.custom_minimum_size = Vector2(208, 256)
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	left.add_child(spr)
	var nm := Label.new()
	nm.text = m.name
	nm.add_theme_font_size_override("font_size", 30)
	left.add_child(nm)
	var job := Label.new()
	job.text = DB.HEROES[m.id].job
	job.add_theme_color_override("font_color", DIM)
	left.add_child(job)
	var bio := Label.new()
	bio.text = DB.HEROES[m.id].bio
	bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bio.add_theme_font_size_override("font_size", 15)
	bio.add_theme_color_override("font_color", DIM)
	bio.custom_minimum_size = Vector2(230, 0)
	left.add_child(bio)

	var mid := VBoxContainer.new()
	mid.custom_minimum_size = Vector2(300, 0)
	mid.add_theme_constant_override("separation", 3)
	h.add_child(mid)
	_row(mid, "Level", str(m.level), GOLD)
	_row(mid, "EXP", str(m.exp))
	_row(mid, "Next Level", str(Game.exp_to_next(m)))
	_spacer(mid, 8)
	_row(mid, "HP", "%d / %d" % [m.hp, Game.max_hp(m)])
	_row(mid, "MP", "%d / %d" % [m.mp, Game.max_mp(m)])
	_spacer(mid, 8)
	for k in ["atk", "def", "mag", "mdf", "spd"]:
		var b := Game.equip_bonus(m, k)
		var extra := "  (+%d)" % b if b > 0 else ""
		_row(mid, DB.STAT_NAMES[k], "%d%s" % [Game.stat(m, k), extra])

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 3)
	h.add_child(right)
	var eh := Label.new()
	eh.text = "Equipment"
	eh.add_theme_color_override("font_color", GOLD)
	right.add_child(eh)
	for slot in DB.SLOTS:
		var eid: String = m.equip.get(slot, "")
		_row(right, DB.SLOT_NAMES[slot], DB.EQUIPMENT[eid].name if eid != "" else "—", Color(0.95, 0.93, 0.88), 15)
	_spacer(right, 10)
	var sh := Label.new()
	sh.text = "Skills"
	sh.add_theme_color_override("font_color", GOLD)
	right.add_child(sh)
	for s in m.skills:
		_row(right, DB.SKILLS[s].name, "%d MP" % DB.SKILLS[s].mp, Color(0.95, 0.93, 0.88), 15)


func _row(parent: Control, k: String, v: String, kc: Color = GOLD, size := 18) -> void:
	var row := HBoxContainer.new()
	var a := Label.new()
	a.text = k
	a.add_theme_color_override("font_color", kc if kc != Color(0.95, 0.93, 0.88) else DIM)
	a.add_theme_font_size_override("font_size", size)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(a)
	var b := Label.new()
	b.text = v
	b.add_theme_font_size_override("font_size", size)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(b)
	parent.add_child(row)


func _spacer(parent: Control, h: int) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	parent.add_child(c)


# ------------------------------------------------------------- Equipment ---
func _equip_flow(idx: int) -> void:
	var m: Dictionary = Game.party[idx]
	var holder := _clear_content()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	holder.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	var por := TextureRect.new()
	por.texture = PixelArt.portrait(DB.HEROES[m.id].sprite)
	por.custom_minimum_size = Vector2(88, 72)
	por.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	por.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	por.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	head.add_child(por)
	var nm := Label.new()
	nm.text = "%s  —  %s" % [m.name, DB.HEROES[m.id].job]
	nm.add_theme_font_size_override("font_size", 24)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(nm)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	v.add_child(body)
	var lv := VBoxContainer.new()
	lv.custom_minimum_size = Vector2(420, 0)
	body.add_child(lv)
	var sl := Label.new()
	sl.text = "Slots"
	sl.add_theme_color_override("font_color", GOLD)
	lv.add_child(sl)
	var slot_list := SelectList.new()
	lv.add_child(slot_list)
	var cl := Label.new()
	cl.text = "Available"
	cl.add_theme_color_override("font_color", GOLD)
	lv.add_child(cl)
	var cand_list := SelectList.new()
	cand_list.max_rows = 6
	lv.add_child(cand_list)

	var stats_box := VBoxContainer.new()
	stats_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(stats_box)

	var refresh_slots := func():
		var items: Array = []
		for slot in DB.SLOTS:
			var eid: String = m.equip.get(slot, "")
			items.append({"text": DB.SLOT_NAMES[slot], "right": DB.EQUIPMENT[eid].name if eid != "" else "—"})
		slot_list.set_items(items, true)

	refresh_slots.call()
	_show_compare(stats_box, m, "", "")
	while true:
		_help("Choose a slot to change.")
		cand_list.set_items([])
		_show_compare(stats_box, m, "", "")
		var si := await slot_list.choose()
		if si < 0:
			return
		var slot: String = DB.SLOTS[si]
		var cands: Array = Game.equip_candidates(m, slot)
		var items: Array = []
		for eid in cands:
			items.append({"text": DB.EQUIPMENT[eid].name, "right": "x%d" % Game.equip_bag[eid]})
		if m.equip.get(slot, "") != "" and slot != "weapon":
			cands.append("")
			items.append({"text": "(Remove)", "color": DIM})
		if cands.is_empty():
			Sfx.play("buzz")
			_help("Nothing else can be equipped in this slot.")
			await get_tree().create_timer(0.8).timeout
			continue
		cand_list.set_items(items)
		var on_move := func(i: int):
			var eid: String = cands[i]
			_show_compare(stats_box, m, slot, eid)
			_help(DB.EQUIPMENT[eid].desc if eid != "" else "Remove the equipped item.")
		cand_list.moved.connect(on_move)
		on_move.call(0)
		var ci := await cand_list.choose()
		cand_list.moved.disconnect(on_move)
		if ci >= 0:
			Game.equip(m, slot, cands[ci])
			refresh_slots.call()


func _show_compare(box: VBoxContainer, m: Dictionary, slot: String, eid: String) -> void:
	for c in box.get_children():
		c.queue_free()
	var t := Label.new()
	t.text = "Parameters"
	t.add_theme_color_override("font_color", GOLD)
	box.add_child(t)
	var preview := {}
	if slot != "":
		preview = Game.preview_stats(m, slot, eid)
	for k in DB.STAT_KEYS:
		var row := HBoxContainer.new()
		var a := Label.new()
		a.text = DB.STAT_NAMES[k]
		a.add_theme_color_override("font_color", DIM)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(a)
		var cur := Game.stat(m, k)
		var b := Label.new()
		b.text = str(cur)
		b.custom_minimum_size = Vector2(60, 0)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(b)
		var arrow := Label.new()
		arrow.custom_minimum_size = Vector2(90, 0)
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if not preview.is_empty():
			var nv: int = preview[k]
			arrow.text = "→ %d" % nv
			if nv > cur:
				arrow.add_theme_color_override("font_color", UP)
			elif nv < cur:
				arrow.add_theme_color_override("font_color", DOWN)
		row.add_child(arrow)
		box.add_child(row)


# ---------------------------------------------------------------- Skills ---
func _skills_flow(idx: int) -> void:
	var m: Dictionary = Game.party[idx]
	var holder := _clear_content()
	var v := VBoxContainer.new()
	holder.add_child(v)
	var hdr := Label.new()
	hdr.add_theme_font_size_override("font_size", 24)
	v.add_child(hdr)
	var list := SelectList.new()
	list.max_rows = 12
	v.add_child(list)
	while true:
		hdr.text = "%s's Skills      MP %d / %d" % [m.name, m.mp, Game.max_mp(m)]
		var items: Array = []
		for s in m.skills:
			var sk: Dictionary = DB.SKILLS[s]
			var usable: bool = sk.get("field", false) and m.mp >= sk.mp and Game.is_alive(m)
			items.append({"text": sk.name, "right": "%d MP" % sk.mp, "enabled": usable,
				"color": Color(0.95, 0.93, 0.88)})
		list.set_items(items, true)
		var on_move := func(i: int):
			var sk: Dictionary = DB.SKILLS[m.skills[i]]
			_help(sk.desc + ("" if sk.get("field", false) else "   (Battle only)"))
		list.moved.connect(on_move)
		on_move.call(list.index)
		var si := await list.choose()
		list.moved.disconnect(on_move)
		if si < 0:
			return
		var skill: Dictionary = DB.SKILLS[m.skills[si]]
		var targets: Array = []
		if skill.target == "all_allies":
			targets = Game.party.filter(func(x): return Game.is_alive(x))
		else:
			var t := await _pick_target(skill.target == "dead_ally")
			if t < 0:
				continue
			targets = [Game.party[t]]
		m.mp -= skill.mp
		for t in targets:
			_field_skill(m, skill, t)
		Sfx.play("heal")


func _field_skill(caster: Dictionary, skill: Dictionary, t: Dictionary) -> void:
	match skill.kind:
		"heal":
			var amount := int(skill.power * (Game.stat(caster, "mag") * 2.0 + 30.0))
			t.hp = mini(Game.max_hp(t), t.hp + amount)
		"revive":
			t.hp = maxi(1, int(Game.max_hp(t) * skill.power))


# ----------------------------------------------------------------- Items ---
func _items_flow() -> void:
	var holder := _clear_content()
	var v := VBoxContainer.new()
	holder.add_child(v)
	var hdr := Label.new()
	hdr.text = "Items"
	hdr.add_theme_font_size_override("font_size", 24)
	v.add_child(hdr)
	var list := SelectList.new()
	list.max_rows = 12
	v.add_child(list)
	while true:
		var ids: Array = Game.item_list()
		if ids.is_empty():
			_help("You have no items.")
			list.set_items([{"text": "(empty)", "enabled": false}])
			await get_tree().create_timer(0.6).timeout
			return
		var items: Array = []
		for id in ids:
			items.append({"text": DB.ITEMS[id].name, "right": "x%d" % Game.inventory[id]})
		list.set_items(items, true)
		var on_move := func(i: int):
			_help(DB.ITEMS[ids[i]].desc)
		list.moved.connect(on_move)
		on_move.call(list.index)
		var ii := await list.choose()
		list.moved.disconnect(on_move)
		if ii < 0:
			return
		var id: String = ids[ii]
		var it: Dictionary = DB.ITEMS[id]
		if it.target == "all_allies":
			for m in Game.party:
				if Game.is_alive(m):
					m.hp = mini(Game.max_hp(m), m.hp + it.amount)
			Game.remove_item(id)
			Sfx.play("heal")
			continue
		var t := await _pick_target(it.target == "dead_ally")
		if t < 0:
			continue
		var m: Dictionary = Game.party[t]
		if apply_item(id, m):
			Game.remove_item(id)
			Sfx.play("heal")
		else:
			Sfx.play("buzz")


## Applies an item outside battle. Returns false if it would have no effect.
func apply_item(id: String, m: Dictionary) -> bool:
	var it: Dictionary = DB.ITEMS[id]
	var alive := Game.is_alive(m)
	match it.kind:
		"heal":
			if not alive or m.hp >= Game.max_hp(m):
				return false
			m.hp = mini(Game.max_hp(m), m.hp + it.amount)
		"mp":
			if not alive or m.mp >= Game.max_mp(m):
				return false
			m.mp = mini(Game.max_mp(m), m.mp + it.amount)
		"full":
			if not alive:
				return false
			m.hp = Game.max_hp(m)
			m.mp = Game.max_mp(m)
		"revive":
			if alive:
				return false
			m.hp = maxi(1, int(Game.max_hp(m) * it.amount))
	return true


## Member picker popup. Returns party index or -1.
func _pick_target(dead_only: bool) -> int:
	var items: Array = []
	for m in Game.party:
		var alive := Game.is_alive(m)
		items.append({
			"text": m.name, "right": "HP %d/%d  MP %d/%d" % [m.hp, Game.max_hp(m), m.mp, Game.max_mp(m)],
			"enabled": (not alive) if dead_only else alive,
		})
	popup_list.set_items(items)
	popup.visible = true
	var r := await popup_list.choose()
	popup.visible = false
	return r
