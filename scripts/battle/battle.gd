extends Node3D
## Turn-based HD-2D battle: 3D arena, pixel billboards, spell effects and a
## classic command menu. Emits `finished("win" | "lose" | "flee")`.

const DB := preload("res://scripts/data/db.gd")
const Props := preload("res://scripts/world/props.gd")
const PixelArt := preload("res://scripts/gfx/pixel_art.gd")
const Battler := preload("res://scripts/battle/battler.gd")
const SelectList := preload("res://scripts/ui/select_list.gd")
const StatBar := preload("res://scripts/ui/stat_bar.gd")

signal finished(result: String)
signal _nav(action: String)

const SPRITE_SCALE := 1.25
const GOLD := Color(1.0, 0.84, 0.45)

var enemy_ids: Array = []
var boss := false
var auto_battle := false   # used by the headless balance test

var heroes: Array = []
var foes: Array = []
var camera: Camera3D
var _cam_base := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _shake := 0.0
var _cam_push := Vector3.ZERO
var _cursor_nodes: Array = []
var _targeting := false
var _fled := false
var _boss_turns := 0
var _boss_phase_shown := false

# UI
var ui_root: Control
var cmd_panel: PanelContainer
var cmd_list: SelectList
var sub_panel: PanelContainer
var sub_title: Label
var sub_list: SelectList
var party_rows: Array = []
var banner: PanelContainer
var banner_label: Label
var info_panel: PanelContainer
var info_label: Label
var turn_strip: HBoxContainer
var result_panel: PanelContainer
var result_label: RichTextLabel


func setup(ids: Array, is_boss: bool) -> void:
	enemy_ids = ids
	boss = is_boss


func _ready() -> void:
	Props.make_environment(self, 15.5 if boss else 14.0, boss)
	Props.make_moonlight(self, 0.35)
	_build_arena()
	_build_camera()
	_spawn_battlers()
	_build_ui()
	_refresh_party()
	Sfx.play_music("boss" if boss else "battle")
	_run.call_deferred()


func _process(delta: float) -> void:
	Props.update_flicker(get_tree())
	var t := Time.get_ticks_msec() / 1000.0
	var sway := Vector3(sin(t * 0.35) * 0.25, sin(t * 0.5) * 0.08, 0)
	var shake := Vector3.ZERO
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		shake = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.6
	camera.position = _cam_base + sway + shake + _cam_push
	camera.look_at(_cam_look + _cam_push * 0.6, Vector3.UP)
	# Idle breathing for everyone still standing.
	for b in heroes + foes:
		if b.alive() and b.sprite:
			var amp := 0.02 if not b.data.get("fly", false) else 0.15
			b.sprite.position.y = b.base_y + sin(t * 2.2 + b.home.z) * amp
	for i in _cursor_nodes.size():
		var c: Node3D = _cursor_nodes[i]
		c.position.y = c.get_meta("y") + absf(sin(t * 6.0)) * 0.15


# ----------------------------------------------------------------- Arena ---
func _build_arena() -> void:
	var floor_mi := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(40, 0.2, 30)
	floor_mi.mesh = fm
	floor_mi.material_override = Props.floor_material()
	floor_mi.position = Vector3(0, -0.1, 0)
	add_child(floor_mi)

	var wall := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(40, 10, 1)
	wall.mesh = wm
	wall.material_override = Props.wall_material()
	wall.position = Vector3(0, 5, -6.5)
	add_child(wall)

	var carpet := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(40, 0.04, 2.6)
	carpet.mesh = cm
	carpet.material_override = Props.carpet_material()
	carpet.position = Vector3(0, 0.02, -0.1)
	add_child(carpet)
	for side in [-1, 1]:
		var trim := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(40, 0.05, 0.16)
		trim.mesh = tm
		trim.material_override = Props.tex_material(PixelArt.carpet_border(), 2.0)
		trim.position = Vector3(0, 0.025, -0.1 + side * 1.3)
		add_child(trim)

	for x in [-9.0, -4.5, 4.5, 9.0]:
		Props.make_pillar(self, Vector3(x, 0, -5.2), 9.0)
	for x in [-6.75, 0.0, 6.75]:
		Props.make_window(self, Vector3(x, 4.2, -5.97))
		Props.make_banner(self, Vector3(x - 1.2, 3.0, -5.97))
		Props.make_banner(self, Vector3(x + 1.2, 3.0, -5.97))
	for x in [-7.0, 7.0]:
		Props.make_brazier(self, Vector3(x, 0, -3.0))
	Props.make_brazier(self, Vector3(-2.2, 0, -4.5))
	Props.make_brazier(self, Vector3(2.2, 0, -4.5))

	if boss:
		var dark := Props.color_material(Color(0.12, 0.06, 0.16))
		var back := MeshInstance3D.new()
		var bk := BoxMesh.new()
		bk.size = Vector3(2.4, 5.0, 0.4)
		back.mesh = bk
		back.material_override = dark
		back.position = Vector3(-4.0, 2.5, -5.6)
		add_child(back)
		var aura := OmniLight3D.new()
		aura.light_color = Color(0.7, 0.15, 1.0)
		aura.light_energy = 4.0
		aura.omni_range = 10.0
		aura.position = Vector3(-4.0, 3.0, -2.0)
		aura.light_volumetric_fog_energy = 3.0
		aura.set_meta("base_energy", 4.0)
		aura.set_meta("phase", 0.0)
		aura.add_to_group("flicker")
		add_child(aura)
		Props.make_dust(self, Vector3(3, 3, 2), 120, Color(0.7, 0.3, 1.0, 0.8)).position = Vector3(-4, 2, -1)

	Props.make_dust(self, Vector3(12, 4, 6), 160).position = Vector3(0, 2.5, 0)
	var fill := OmniLight3D.new()
	fill.light_color = Color(1.0, 0.85, 0.7)
	fill.light_energy = 1.2
	fill.omni_range = 12.0
	fill.position = Vector3(0, 4.5, 4.0)
	add_child(fill)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 36.0 if not boss else 40.0
	add_child(camera)
	_cam_base = Vector3(0.3, 3.9, 13.8) if not boss else Vector3(0.0, 4.6, 15.0)
	_cam_look = Vector3(0, 0.5, -0.6) if not boss else Vector3(0, 1.2, -0.9)
	camera.position = _cam_base
	camera.look_at(_cam_look, Vector3.UP)
	camera.make_current()


func _spawn_battlers() -> void:
	var i := 0
	for m in Game.party:
		var b := Battler.hero(m)
		b.home = Vector3(3.0 + i * 0.9, 0, -2.0 + i * 1.7)
		_attach_sprite(b, DB.HEROES[m.id].sprite, SPRITE_SCALE)
		b.sprite.flip_h = true
		if not b.alive():
			_show_ko(b, true)
		heroes.append(b)
		i += 1
	var counts := {}
	for id in enemy_ids:
		counts[id] = counts.get(id, 0) + 1
	var seen := {}
	var n := enemy_ids.size()
	for j in n:
		var id: String = enemy_ids[j]
		var suffix := ""
		if counts[id] > 1:
			suffix = " " + "ABC"[seen.get(id, 0)]
			seen[id] = seen.get(id, 0) + 1
		var b := Battler.enemy(id, suffix)
		if b.is_boss:
			b.home = Vector3(-3.6, 0, -0.9)
		elif n == 1:
			b.home = Vector3(-3.4, 0, -0.1)
		elif n == 2:
			b.home = Vector3(-2.6 - j * 2.0, 0, -0.9 + j * 1.6)
		else:
			b.home = [Vector3(-3.6, 0, -2.0), Vector3(-2.3, 0, 0.9), Vector3(-5.4, 0, 0.3)][j]
		_attach_sprite(b, b.data.sprite, b.data.scale * SPRITE_SCALE * (0.75 if b.is_boss else 1.0))
		if b.data.get("fly", false):
			b.base_y += 0.6
		foes.append(b)


func _attach_sprite(b, sprite_name: String, scale: float) -> void:
	b.node = Props.make_billboard(sprite_name, scale)
	b.node.position = b.home
	add_child(b.node)
	b.sprite = b.node.get_node("Sprite")
	b.base_y = b.sprite.position.y


# -------------------------------------------------------------------- UI ---
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = UI.theme
	layer.add_child(ui_root)

	# Party status
	var pp := _panel(Vector2(560, 520), Vector2(680, 172))
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 2)
	pp.add_child(pv)
	for b in heroes:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.custom_minimum_size = Vector2(0, 46)
		var cur := Label.new()
		cur.custom_minimum_size = Vector2(18, 0)
		cur.add_theme_color_override("font_color", GOLD)
		row.add_child(cur)
		var nm := Label.new()
		nm.text = b.display_name
		nm.custom_minimum_size = Vector2(110, 0)
		row.add_child(nm)
		var hp_box := VBoxContainer.new()
		hp_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hp_box.add_theme_constant_override("separation", 0)
		var hp_l := Label.new()
		hp_l.add_theme_font_size_override("font_size", 18)
		hp_box.add_child(hp_l)
		var hp_bar := StatBar.new()
		hp_bar.color = Color(0.4, 0.95, 0.5)
		hp_box.add_child(hp_bar)
		row.add_child(hp_box)
		var mp_box := VBoxContainer.new()
		mp_box.custom_minimum_size = Vector2(170, 0)
		mp_box.add_theme_constant_override("separation", 0)
		var mp_l := Label.new()
		mp_l.add_theme_font_size_override("font_size", 18)
		mp_box.add_child(mp_l)
		var mp_bar := StatBar.new()
		mp_bar.color = Color(0.45, 0.7, 1.0)
		mp_box.add_child(mp_bar)
		row.add_child(mp_box)
		var st := Label.new()
		st.custom_minimum_size = Vector2(70, 0)
		st.add_theme_font_size_override("font_size", 15)
		row.add_child(st)
		pv.add_child(row)
		party_rows.append({"cur": cur, "name": nm, "hp": hp_l, "hpb": hp_bar, "mp": mp_l, "mpb": mp_bar, "st": st})

	cmd_panel = _panel(Vector2(40, 492), Vector2(250, 200))
	cmd_list = SelectList.new()
	cmd_list.allow_cancel = false
	cmd_panel.add_child(cmd_list)
	cmd_panel.visible = false

	sub_panel = _panel(Vector2(300, 300), Vector2(420, 392))
	var sv := VBoxContainer.new()
	sub_panel.add_child(sv)
	sub_title = Label.new()
	sub_title.add_theme_color_override("font_color", GOLD)
	sv.add_child(sub_title)
	sub_list = SelectList.new()
	sub_list.max_rows = 9
	sv.add_child(sub_list)
	sub_panel.visible = false

	banner = PanelContainer.new()
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_left = -330
	banner.offset_right = 330
	banner.offset_top = 100
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ui_root.add_child(banner)
	banner_label = Label.new()
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 24)
	banner.add_child(banner_label)
	banner.modulate.a = 0.0

	info_panel = _panel(Vector2(40, 28), Vector2(520, 60))
	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_panel.add_child(info_label)
	info_panel.visible = false

	var strip_panel := PanelContainer.new()
	strip_panel.anchor_left = 1.0
	strip_panel.anchor_right = 1.0
	strip_panel.offset_left = -40
	strip_panel.offset_right = -40
	strip_panel.offset_top = 28
	strip_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var sb := UI.panel_style(0.6)
	sb.set_content_margin_all(6)
	strip_panel.add_theme_stylebox_override("panel", sb)
	ui_root.add_child(strip_panel)
	var sh := HBoxContainer.new()
	strip_panel.add_child(sh)
	var tl := Label.new()
	tl.text = "TURN"
	tl.add_theme_font_size_override("font_size", 14)
	tl.add_theme_color_override("font_color", GOLD)
	sh.add_child(tl)
	turn_strip = HBoxContainer.new()
	sh.add_child(turn_strip)

	result_panel = _panel(Vector2(340, 170), Vector2(600, 300))
	result_label = RichTextLabel.new()
	result_label.bbcode_enabled = true
	result_label.fit_content = true
	result_panel.add_child(result_label)
	result_panel.visible = false


func _panel(pos: Vector2, size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.custom_minimum_size = size
	p.size = size
	ui_root.add_child(p)
	return p


func _refresh_party(active = null) -> void:
	for i in heroes.size():
		var b = heroes[i]
		var r: Dictionary = party_rows[i]
		r.cur.text = "▶" if b == active else ""
		r.name.add_theme_color_override("font_color", GOLD if b == active else (Color(1, 0.4, 0.4) if not b.alive() else Color(0.95, 0.93, 0.88)))
		r.hp.text = "HP %d/%d" % [b.hp, b.max_hp()]
		r.hpb.max_value = b.max_hp()
		r.hpb.value = b.hp
		r.hpb.color = Color(0.4, 0.95, 0.5) if b.hp > b.max_hp() / 4 else Color(1.0, 0.6, 0.2)
		r.mp.text = "MP %d/%d" % [b.mp, b.max_mp()]
		r.mpb.max_value = b.max_mp()
		r.mpb.value = b.mp
		var tags: Array = []
		if not b.alive():
			tags.append("KO")
		else:
			if b.provoke > 0:
				tags.append("Taunt")
			for k in b.buffs:
				tags.append(("%s↑" if b.buffs[k].mult > 1.0 else "%s↓") % k.to_upper())
		r.st.text = " ".join(tags)


func _update_strip(order: Array) -> void:
	for c in turn_strip.get_children():
		c.queue_free()
	for b in order:
		if not b.alive():
			continue
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(40, 36)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.texture = PixelArt.portrait(DB.HEROES[b.member.id].sprite) if b.is_hero else PixelArt.sprite(b.data.sprite)
		if not b.is_hero:
			tr.modulate = Color(1.0, 0.75, 0.8)
		turn_strip.add_child(tr)


func _show_banner(text: String, color := Color(0.95, 0.93, 0.88)) -> void:
	banner_label.text = text
	banner_label.add_theme_color_override("font_color", color)
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.12)


func _hide_banner() -> void:
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 0.0, 0.2)


func _info(text: String) -> void:
	info_panel.visible = text != ""
	info_label.text = text


# ------------------------------------------------------------------ Flow ---
func _run() -> void:
	await get_tree().create_timer(0.2).timeout
	await UI.fade_in(0.4)
	var names := {}
	for f in foes:
		names[f.data.name] = true
	if boss:
		_show_banner("Dark Lord Malzeth", Color(1.0, 0.5, 0.9))
	else:
		_show_banner("%s appeared!" % " & ".join(names.keys()))
	await _wait(1.1)
	_hide_banner()
	while true:
		var order := _make_order()
		for idx in order.size():
			var b = order[idx]
			if not b.alive():
				continue
			_update_strip(order.slice(idx))
			b.defending = false
			if b.is_hero:
				await _hero_turn(b)
			else:
				await _enemy_turn(b)
			b.tick()
			_refresh_party()
			if _fled:
				await _end_flee()
				return
			if _all_dead(foes):
				await _victory()
				return
			if _all_dead(heroes):
				await _defeat()
				return


func _make_order() -> Array:
	var all: Array = []
	for b in heroes + foes:
		if b.alive():
			all.append([b.stat("spd") * randf_range(0.85, 1.15), b])
			if b.is_boss and b.phase >= 2:
				all.append([b.stat("spd") * randf_range(0.4, 0.7), b])
	all.sort_custom(func(a, c): return a[0] > c[0])
	return all.map(func(x): return x[1])


func _all_dead(list: Array) -> bool:
	for b in list:
		if b.alive():
			return false
	return true


func _alive(list: Array) -> Array:
	return list.filter(func(b): return b.alive())


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


# ------------------------------------------------------------ Hero turn ---
func _hero_turn(b) -> void:
	_refresh_party(b)
	var step := create_tween()
	step.tween_property(b.node, "position", b.home + Vector3(-0.6, 0, 0), 0.15)
	var action := {}
	if auto_battle:
		action = _auto_action(b)
	while action.is_empty():
		cmd_panel.visible = true
		cmd_list.set_items([
			{"text": "Attack"},
			{"text": "Skills"},
			{"text": "Items", "enabled": not Game.inventory.is_empty()},
			{"text": "Defend"},
			{"text": "Flee", "enabled": not boss},
		], true)
		_info("")
		var c := await cmd_list.choose()
		match c:
			0:
				var t := await _pick_targets(b, "enemy")
				if not t.is_empty():
					action = {"type": "attack", "targets": t}
			1:
				action = await _choose_skill(b)
			2:
				action = await _choose_item(b)
			3:
				action = {"type": "defend", "targets": [b]}
			4:
				action = {"type": "flee", "targets": []}
	cmd_panel.visible = false
	sub_panel.visible = false
	_info("")
	var back := create_tween()
	back.tween_property(b.node, "position", b.home, 0.12)
	await back.finished
	await _execute(b, action)
	_refresh_party()


func _choose_skill(b) -> Dictionary:
	sub_title.text = "%s's Skills" % b.display_name
	sub_panel.visible = true
	while true:
		var items: Array = []
		for s in b.skills():
			var sk: Dictionary = DB.SKILLS[s]
			items.append({"text": sk.name, "right": "%d MP" % sk.mp, "enabled": b.mp >= sk.mp})
		sub_list.set_items(items, true)
		var on_move := func(i: int): _info(DB.SKILLS[b.skills()[i]].desc)
		sub_list.moved.connect(on_move)
		on_move.call(sub_list.index)
		var si := await sub_list.choose()
		sub_list.moved.disconnect(on_move)
		if si < 0:
			sub_panel.visible = false
			return {}
		var sid: String = b.skills()[si]
		var t := await _pick_targets(b, DB.SKILLS[sid].target)
		if not t.is_empty():
			sub_panel.visible = false
			return {"type": "skill", "skill": sid, "targets": t}
	return {}


func _choose_item(b) -> Dictionary:
	sub_title.text = "Items"
	sub_panel.visible = true
	while true:
		var ids: Array = Game.item_list()
		if ids.is_empty():
			sub_panel.visible = false
			return {}
		var items: Array = []
		for id in ids:
			items.append({"text": DB.ITEMS[id].name, "right": "x%d" % Game.inventory[id]})
		sub_list.set_items(items, true)
		var on_move := func(i: int): _info(DB.ITEMS[ids[i]].desc)
		sub_list.moved.connect(on_move)
		on_move.call(sub_list.index)
		var ii := await sub_list.choose()
		sub_list.moved.disconnect(on_move)
		if ii < 0:
			sub_panel.visible = false
			return {}
		var id: String = ids[ii]
		var t := await _pick_targets(b, DB.ITEMS[id].target)
		if not t.is_empty():
			sub_panel.visible = false
			return {"type": "item", "item": id, "targets": t}
	return {}


## Target selection with a bouncing cursor. Returns [] if cancelled.
func _pick_targets(b, ttype: String) -> Array:
	var pool: Array
	var multi := false
	match ttype:
		"self":
			return [b]
		"enemy":
			pool = _alive(foes)
		"all_enemies":
			pool = _alive(foes)
			multi = true
		"ally":
			pool = _alive(heroes)
		"all_allies":
			pool = _alive(heroes)
			multi = true
		"dead_ally":
			pool = heroes.filter(func(h): return not h.alive())
	if pool.is_empty():
		Sfx.play("buzz")
		return []
	pool.sort_custom(func(x, y): return x.home.z < y.home.z)
	var idx := 0
	if ttype == "ally" and pool.has(b):
		idx = pool.find(b)
	while true:
		var shown: Array = pool if multi else [pool[idx]]
		_show_cursors(shown)
		if multi:
			_info("Target: all %s" % ("enemies" if ttype == "all_enemies" else "allies"))
		else:
			var t = pool[idx]
			_info("%s   HP %d/%d" % [t.display_name, t.hp, t.max_hp()] if t.is_hero else "%s%s" % [t.display_name, _foe_hint(t)])
		_targeting = true
		var a: String = await _nav
		_targeting = false
		match a:
			"up", "left":
				idx = wrapi(idx - 1, 0, pool.size())
				Sfx.play("cursor")
			"down", "right":
				idx = wrapi(idx + 1, 0, pool.size())
				Sfx.play("cursor")
			"accept":
				Sfx.play("confirm")
				_show_cursors([])
				return pool.duplicate() if multi else [pool[idx]]
			"cancel":
				Sfx.play("cancel")
				_show_cursors([])
				_info("")
				return []
	return []


func _foe_hint(t) -> String:
	var k: float = float(t.hp) / t.max_hp()
	var state := "Unhurt" if k > 0.95 else ("Wounded" if k > 0.5 else ("Badly hurt" if k > 0.2 else "Near death"))
	return "   — %s" % state


func _show_cursors(targets: Array) -> void:
	for c in _cursor_nodes:
		c.queue_free()
	_cursor_nodes.clear()
	for t in targets:
		var l := Label3D.new()
		l.text = "▼"
		l.font_size = 72
		l.pixel_size = 0.008
		l.modulate = GOLD
		l.outline_size = 14
		l.outline_modulate = Color(0.1, 0.05, 0.0)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.render_priority = 10
		var h: float = t.sprite.texture.get_height() * t.sprite.pixel_size
		l.position = t.node.position + Vector3(0, h + 0.3 + (0.6 if t.data.get("fly", false) else 0.0), 0)
		l.set_meta("y", l.position.y)
		add_child(l)
		_cursor_nodes.append(l)


func _unhandled_input(event: InputEvent) -> void:
	if not _targeting:
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
	elif event.is_action_pressed("ui_cancel"):
		a = "cancel"
	elif event is InputEventMouseButton and event.pressed:
		a = "accept" if event.button_index == MOUSE_BUTTON_LEFT else ("cancel" if event.button_index == MOUSE_BUTTON_RIGHT else "")
	if a != "":
		get_viewport().set_input_as_handled()
		_nav.emit(a)


## Simple AI used for automated balance testing.
func _auto_action(b) -> Dictionary:
	var hurt: Array = _alive(heroes).filter(func(h): return h.hp < h.max_hp() * 0.45)
	var dead: Array = heroes.filter(func(h): return not h.alive())
	var foe = _alive(foes).pick_random()
	var sk: Array = b.skills()
	if not dead.is_empty() and sk.has("raise") and b.mp >= DB.SKILLS.raise.mp:
		return {"type": "skill", "skill": "raise", "targets": [dead[0]]}
	if not dead.is_empty() and Game.inventory.get("phoenix", 0) > 0:
		return {"type": "item", "item": "phoenix", "targets": [dead[0]]}
	if hurt.size() >= 2 and sk.has("heal_all") and b.mp >= DB.SKILLS.heal_all.mp:
		return {"type": "skill", "skill": "heal_all", "targets": _alive(heroes)}
	if not hurt.is_empty() and sk.has("cure") and b.mp >= DB.SKILLS.cure.mp:
		return {"type": "skill", "skill": "cure", "targets": [hurt[0]]}
	if not hurt.is_empty() and Game.inventory.get("hi_potion", 0) > 0:
		return {"type": "item", "item": "hi_potion", "targets": [hurt[0]]}
	if b.mp < 12 and Game.inventory.get("ether", 0) > 0:
		return {"type": "item", "item": "ether", "targets": [b]}
	if boss:
		if sk.has("iron_wall") and not b.buffs.has("def") and b.mp >= 8:
			return {"type": "skill", "skill": "iron_wall", "targets": _alive(heroes)}
		if sk.has("provoke") and b.provoke <= 0 and b.mp >= 3:
			return {"type": "skill", "skill": "provoke", "targets": [b]}
		if sk.has("focus") and not b.buffs.has("mag") and b.mp >= 30:
			return {"type": "skill", "skill": "focus", "targets": [b]}
	for s in ["lumina_blade", "holy", "meteor", "earthsplitter", "thunder_slash", "fire", "shield_bash"]:
		if sk.has(s) and b.mp >= DB.SKILLS[s].mp + 8:
			var tt: String = DB.SKILLS[s].target
			return {"type": "skill", "skill": s, "targets": _alive(foes) if tt == "all_enemies" else [foe]}
	return {"type": "attack", "targets": [foe]}


# ----------------------------------------------------------- Enemy turn ---
func _enemy_turn(b) -> void:
	await _wait(0.25)
	if b.is_boss:
		await _boss_turn(b)
		return
	var sid := _weighted(b.data.actions)
	await _execute(b, {"type": "skill", "skill": sid, "targets": _enemy_targets(sid)})


func _boss_turn(b) -> void:
	if b.phase == 1 and b.hp <= b.max_hp() / 2 and not _boss_phase_shown:
		_boss_phase_shown = true
		await _boss_transform(b)
	_boss_turns += 1
	var sid: String
	if b.charging:
		b.charging = false
		sid = "abyssal_ruin"
	elif b.phase >= 2 and _boss_turns % 4 == 0:
		b.charging = true
		sid = "abyss_charge"
	else:
		sid = _weighted(b.data.actions)
	await _execute(b, {"type": "skill", "skill": sid, "targets": _enemy_targets(sid)})


func _boss_transform(b) -> void:
	_show_banner("Malzeth: Enough! Witness my true form!", Color(1.0, 0.45, 0.8))
	Sfx.play("dark")
	_shake = 0.8
	var tw := create_tween()
	tw.tween_property(b.sprite, "modulate", Color(2.5, 0.6, 2.5), 0.4)
	tw.tween_property(b.sprite, "modulate", Color(1.3, 0.75, 1.3), 0.6)
	tw.parallel().tween_property(b.node, "scale", Vector3.ONE * 1.12, 0.6)
	_burst(b.node.position + Vector3(0, 2.5, 0), Color(0.7, 0.2, 1.0), 80, 3.0)
	await _wait(1.8)
	b.phase = 2
	_hide_banner()


func _weighted(list: Array) -> String:
	var total := 0
	for a in list:
		total += a[1]
	var r := randi() % total
	for a in list:
		r -= a[1]
		if r < 0:
			return a[0]
	return list[0][0]


func _enemy_targets(sid: String) -> Array:
	var sk: Dictionary = DB.SKILLS[sid]
	var alive := _alive(heroes)
	match sk.target:
		"all_enemies":
			return alive
		"self":
			return []
	var provokers := alive.filter(func(h): return h.provoke > 0)
	if not provokers.is_empty() and randf() < 0.85:
		return [provokers[0]]
	return [alive.pick_random()]


# ------------------------------------------------------------- Execute ---
func _execute(a, action: Dictionary) -> void:
	var targets: Array = action.get("targets", [])
	match action.type:
		"defend":
			a.defending = true
			_show_banner("%s defends." % a.display_name)
			Sfx.play("buff")
			_burst(a.node.position + Vector3(0, 1.2, 0), Color(0.6, 0.8, 1.0), 20, 1.0)
			await _wait(0.6)
			_hide_banner()
		"flee":
			_show_banner("The party tries to flee...")
			await _wait(0.6)
			if randf() < 0.7:
				Sfx.play("cancel")
				_fled = true
			else:
				_show_banner("Couldn't escape!")
				Sfx.play("buzz")
				await _wait(0.7)
			_hide_banner()
		"attack":
			await _do_skill(a, "e_attack", _retarget(a, targets, "enemy"), "Attack")
		"skill":
			var sk: Dictionary = DB.SKILLS[action.skill]
			if a.is_hero:
				a.mp -= sk.mp
			var tt: Array = targets
			if sk.target in ["enemy", "ally"]:
				tt = _retarget(a, targets, sk.target)
			elif sk.target == "all_enemies":
				tt = _alive(foes) if a.is_hero else _alive(heroes)
			await _do_skill(a, action.skill, tt, sk.name)
		"item":
			await _do_item(a, action.item, targets)


## If a single target died before the action resolved, pick another one.
func _retarget(a, targets: Array, ttype: String) -> Array:
	if not targets.is_empty() and targets[0].alive():
		return targets
	var side: Array
	if ttype == "enemy":
		side = foes if a.is_hero else heroes
	else:
		side = heroes if a.is_hero else foes
	var alive := _alive(side)
	return [alive.pick_random()] if not alive.is_empty() else []


func _do_skill(a, sid: String, targets: Array, label: String) -> void:
	var sk: Dictionary = DB.SKILLS[sid]
	if targets.is_empty() and sk.target != "self":
		return
	var el: String = sk.element
	var col: Color = DB.ELEMENT_COLORS.get(el, Color.WHITE)
	if sid != "e_attack":
		_show_banner(label, col.lerp(Color.WHITE, 0.4))
	match sk.kind:
		"phys":
			await _physical(a, sk, targets)
		"magic":
			await _cast_anim(a, col)
			await _magic_fx(sid, el, targets)
			for t in targets:
				_apply_damage(a, t, sk)
			if sk.get("drain", false):
				await _wait(0.3)
		"heal":
			await _cast_anim(a, col)
			Sfx.play("heal")
			for t in targets:
				_rise_fx(t, col)
				var amt := int(sk.power * (a.stat("mag") * 2.0 + 30.0) * randf_range(0.95, 1.05))
				t.hp += amt
				_popup(t, str(amt), Color(0.5, 1.0, 0.6))
		"revive":
			await _cast_anim(a, col)
			Sfx.play("heal")
			for t in targets:
				if not t.alive():
					t.hp = maxi(1, int(t.max_hp() * sk.power))
					_show_ko(t, false)
					_rise_fx(t, Color(1.0, 0.95, 0.6))
					_popup(t, "Revived!", Color(1.0, 0.95, 0.6))
		"buff":
			await _cast_anim(a, col)
			Sfx.play("buff")
			for t in targets:
				for key in ["buff", "buff2"]:
					if sk.has(key):
						t.add_buff(sk[key].stat, sk[key].mult, sk[key].turns + (1 if t == a else 0))
				_rise_fx(t, col)
				_popup(t, "%s Up" % DB.STAT_NAMES[sk.buff.stat], col)
		"provoke":
			Sfx.play("buff")
			a.provoke = 4
			a.add_buff("def", 1.3, 4)
			_rise_fx(a, Color(1.0, 0.4, 0.3))
			_popup(a, "Taunt!", Color(1.0, 0.5, 0.4))
		"debuff":
			await _cast_anim(a, col)
			Sfx.play("dark")
			for t in targets:
				t.add_buff(sk.debuff.stat, sk.debuff.mult, sk.debuff.turns)
				_implode_fx(t.node.position + Vector3(0, 1.2, 0), col)
				_popup(t, "%s Down" % DB.STAT_NAMES[sk.debuff.stat], Color(0.8, 0.5, 1.0))
		"charge":
			Sfx.play("dark")
			_shake = 0.4
			_implode_fx(a.node.position + Vector3(0, 2.5, 0), col, 3.0)
			_show_banner("Malzeth gathers the darkness of the abyss...", Color(0.85, 0.5, 1.0))
	await _wait(0.75)
	_hide_banner()
	_refresh_party()


func _physical(a, sk: Dictionary, targets: Array) -> void:
	var col: Color = DB.ELEMENT_COLORS.get(sk.element, Color.WHITE)
	var t0 = targets[0]
	var dir := -1.0 if a.is_hero else 1.0
	var dest: Vector3 = t0.node.position + Vector3(-dir * 1.3, 0, 0.05) if targets.size() == 1 else Vector3(0.0, 0, -0.1)
	if a.is_boss:
		dest = a.home + Vector3(1.0, 0, 0)
	if sk.element != "none":
		a.sprite.modulate = col.lerp(Color.WHITE, 0.3) * 1.8
	var tw := create_tween()
	tw.tween_property(a.node, "position", dest, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cam_push = Vector3(dir * -0.3, -0.1, -0.6)
	await tw.finished
	for t in targets:
		_slash_fx(t, col)
		if sk.element != "none":
			_burst(t.node.position + Vector3(0, 1.2, 0), col, 24, 1.2)
		_apply_damage(a, t, sk)
	await _wait(0.3)
	a.sprite.modulate = _base_modulate(a)
	var back := create_tween()
	back.tween_property(a.node, "position", a.home, 0.25).set_trans(Tween.TRANS_QUAD)
	_cam_push = Vector3.ZERO
	await back.finished


func _cast_anim(a, col: Color) -> void:
	Sfx.play("magic")
	var circle := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 2.2
	circle.mesh = q
	circle.rotation_degrees.x = -90
	circle.position = a.node.position + Vector3(0, 0.06, 0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _ring_texture()
	m.albedo_color = col * 2.0
	circle.material_override = m
	add_child(circle)
	var orig: Color = _base_modulate(a)
	var tw := create_tween()
	tw.tween_property(a.sprite, "modulate", col.lerp(Color.WHITE, 0.5) * 2.2, 0.25)
	tw.parallel().tween_property(circle, "rotation_degrees:y", 180.0, 0.6)
	tw.tween_property(a.sprite, "modulate", orig, 0.25)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.25)
	_rise_fx(a, col, 14)
	await tw.finished
	circle.queue_free()


func _base_modulate(b) -> Color:
	if b.is_boss and b.phase >= 2:
		return Color(1.3, 0.75, 1.3)
	return Color.WHITE


# --------------------------------------------------------------- Damage ---
func _apply_damage(a, t, sk: Dictionary) -> void:
	if not t.alive():
		return
	var phys: bool = sk.kind == "phys"
	var A: float = a.stat("atk" if phys else "mag")
	var D: float = t.stat("def" if phys else "mdf")
	var dmg: float = sk.power * 2.5 * A * A / (A + D)
	dmg *= randf_range(0.92, 1.08)
	var crit := phys and randf() < 0.08
	if crit:
		dmg *= 1.6
	var el: String = sk.element
	var weak: bool = t.weak.has(el)
	var resist: bool = t.resist.has(el)
	if weak:
		dmg *= 1.5
	if resist:
		dmg *= 0.5
	if t.defending:
		dmg *= 0.5
	var amount := maxi(1, int(dmg))
	t.hp -= amount
	if sk.has("debuff") and t.alive() and sk.kind == "phys":
		t.add_buff(sk.debuff.stat, sk.debuff.mult, sk.debuff.turns)
	if sk.get("drain", false):
		a.hp += amount / 2
		_popup(a, str(amount / 2), Color(0.5, 1.0, 0.6))
	Sfx.play("crit" if crit else ("slash" if phys else "hit"))
	_hit_flash(t)
	_shake = maxf(_shake, 0.35 if crit or weak else 0.18)
	var col := Color.WHITE
	if crit:
		col = Color(1.0, 0.9, 0.3)
	elif not t.is_hero and weak:
		col = Color(1.0, 0.65, 0.25)
	elif t.is_hero:
		col = Color(1.0, 0.75, 0.75)
	_popup(t, str(amount), col, 1.0 if not crit else 1.35)
	if crit:
		_popup(t, "CRITICAL", Color(1.0, 0.9, 0.3), 0.6, 0.6)
	elif weak:
		_popup(t, "WEAK!", Color(1.0, 0.6, 0.2), 0.6, 0.6)
	elif resist:
		_popup(t, "Resist", Color(0.7, 0.7, 0.8), 0.6, 0.6)
	if not t.alive():
		_on_down(t)


func _on_down(t) -> void:
	t.buffs.clear()
	t.provoke = 0
	if t.is_hero:
		Sfx.play("death")
		_show_ko(t, true)
		return
	Sfx.play("death")
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(t.sprite, "modulate", Color(2.0, 0.4, 2.5, 1.0), 0.15)
	tw.tween_property(t.sprite, "modulate", Color(0.6, 0.1, 0.8, 0.0), 0.6)
	tw.parallel().tween_property(t.sprite, "scale", Vector3(1.3, 0.2, 1.0), 0.6)
	tw.tween_callback(t.node.hide)
	_burst(t.node.position + Vector3(0, 1.0, 0), Color(0.6, 0.2, 1.0), 40, 1.6)


func _show_ko(b, ko: bool) -> void:
	if ko:
		b.sprite.modulate = Color(0.55, 0.4, 0.5)
		b.sprite.scale = Vector3(1.0, 0.7, 1.0)
		b.sprite.position.y = b.base_y * 0.7
	else:
		b.sprite.modulate = Color.WHITE
		b.sprite.scale = Vector3.ONE


func _hit_flash(t) -> void:
	var orig: Color = Color(0.55, 0.4, 0.5) if not t.alive() and t.is_hero else _base_modulate(t)
	t.sprite.modulate = Color(4.0, 4.0, 4.0)
	var tw := create_tween()
	var k := 1.0 if t.is_hero else -1.0
	tw.tween_property(t.node, "position", t.home + Vector3(k * 0.25, 0, 0), 0.06)
	tw.tween_property(t.sprite, "modulate", orig, 0.15)
	tw.parallel().tween_property(t.node, "position", t.home, 0.2)


# ------------------------------------------------------------------ Items ---
func _do_item(a, id: String, targets: Array) -> void:
	var it: Dictionary = DB.ITEMS[id]
	Game.remove_item(id)
	_show_banner(it.name, Color(0.6, 0.9, 1.0))
	Sfx.play("heal")
	if it.target == "all_allies":
		targets = _alive(heroes)
	for t in targets:
		match it.kind:
			"heal", "heal_all":
				if t.alive():
					t.hp += it.amount
					_popup(t, str(it.amount), Color(0.5, 1.0, 0.6))
			"mp":
				if t.alive():
					t.mp += it.amount
					_popup(t, str(it.amount), Color(0.5, 0.75, 1.0))
			"full":
				if t.alive():
					t.hp = t.max_hp()
					t.mp = t.max_mp()
					_popup(t, "Full Restore", Color(0.5, 1.0, 0.6))
			"revive":
				if not t.alive():
					t.hp = maxi(1, int(t.max_hp() * it.amount))
					_show_ko(t, false)
					_popup(t, "Revived!", Color(1.0, 0.95, 0.6))
		_rise_fx(t, Color(0.5, 1.0, 0.7))
	await _wait(0.9)
	_hide_banner()


# ---------------------------------------------------------------- Effects ---
func _popup(t, text: String, color: Color, scale := 1.0, delay := 0.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = int(64 * scale)
	l.pixel_size = 0.009
	l.modulate = color
	l.outline_size = 16
	l.outline_modulate = Color(0.05, 0.02, 0.08)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 20
	var h: float = t.sprite.texture.get_height() * t.sprite.pixel_size
	l.position = t.node.position + Vector3(randf_range(-0.2, 0.2), h * 0.7 + delay, 0.5)
	add_child(l)
	l.visible = delay <= 0.0
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(0.05)
		tw.tween_callback(l.show)
	tw.tween_property(l, "position:y", l.position.y + 0.9, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.6)
	tw.tween_callback(l.queue_free)


func _slash_fx(t, col: Color) -> void:
	var s := Sprite3D.new()
	s.texture = PixelArt.slash_arc()
	s.pixel_size = 0.05
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.modulate = col * 3.0
	s.flip_h = randf() < 0.5
	s.flip_v = randf() < 0.5
	s.no_depth_test = true
	s.render_priority = 5
	s.shaded = false
	s.position = t.node.position + Vector3(0, 1.3, 0.4)
	add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * 1.4, 0.18).from(Vector3.ONE * 0.5)
	tw.parallel().tween_property(s, "modulate:a", 0.0, 0.25).set_delay(0.08)
	tw.tween_callback(s.queue_free)


func _burst(pos: Vector3, col: Color, amount := 30, size := 1.0) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2 * size
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.5 * size
	p.initial_velocity_max = 3.5 * size
	p.gravity = Vector3(0, -2.0, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var grad := Gradient.new()
	grad.set_color(0, Color(col.r * 2.5, col.g * 2.5, col.b * 2.5, 1.0))
	grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = grad
	p.mesh = _spark_mesh(0.16 * size)
	add_child(p)
	p.emitting = true
	_flash_light(pos, col, 4.0 * size)
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


func _rise_fx(t, col: Color, amount := 24) -> void:
	var p := CPUParticles3D.new()
	p.position = t.node.position + Vector3(0, 0.2, 0)
	p.one_shot = true
	p.explosiveness = 0.3
	p.amount = amount
	p.lifetime = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.7
	p.emission_ring_inner_radius = 0.5
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 5.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 2.5
	p.gravity = Vector3.ZERO
	var grad := Gradient.new()
	grad.set_color(0, Color(col.r * 2.0, col.g * 2.0, col.b * 2.0, 1.0))
	grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = grad
	p.mesh = _spark_mesh(0.18)
	add_child(p)
	p.emitting = true
	_flash_light(t.node.position + Vector3(0, 1.0, 0), col, 2.5)
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)


func _implode_fx(pos: Vector3, col: Color, size := 1.0) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.6
	p.amount = int(40 * size)
	p.lifetime = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 1.5 * size
	p.gravity = Vector3.ZERO
	p.radial_accel_min = -6.0 * size
	p.radial_accel_max = -4.0 * size
	var grad := Gradient.new()
	grad.set_color(0, Color(col.r, col.g, col.b, 0.0))
	grad.set_color(1, Color(col.r * 2.0, col.g * 2.0, col.b * 2.0, 1.0))
	p.color_ramp = grad
	p.mesh = _spark_mesh(0.16)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


func _flash_light(pos: Vector3, col: Color, energy: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = 0.0
	l.omni_range = 6.0
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", energy, 0.06)
	tw.tween_property(l, "light_energy", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func _spark_mesh(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = PixelArt.sparkle()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	q.material = m
	return q


var _ring: ImageTexture
func _ring_texture() -> ImageTexture:
	if _ring:
		return _ring
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(n / 2.0, n / 2.0)
	for y in n:
		for x in n:
			var v := Vector2(x, y) - c
			var d := v.length()
			var a := 0.0
			if absf(d - 29.0) < 1.5 or absf(d - 22.0) < 1.0:
				a = 1.0
			elif d < 22.0:
				# Hexagram lines
				var ang := atan2(v.y, v.x)
				for k in 6:
					var la := k * PI / 3.0
					var dist := absf(sin(ang - la)) * d
					if dist < 0.8 and cos(ang - la) > 0.0:
						a = 0.8
			if a > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, a))
	_ring = ImageTexture.create_from_image(img)
	return _ring


## Element-specific spell visuals.
func _magic_fx(sid: String, el: String, targets: Array) -> void:
	var col: Color = DB.ELEMENT_COLORS.get(el, Color.WHITE)
	match el:
		"thunder":
			for t in targets:
				_bolt(t.node.position)
			Sfx.play("crit")
			_shake = 0.3
			await _wait(0.25)
		"holy":
			for t in targets:
				_pillar(t.node.position, col)
			await _wait(0.5)
			for t in targets:
				_burst(t.node.position + Vector3(0, 1.4, 0), col, 50, 1.6)
		"dark":
			for t in targets:
				_implode_fx(t.node.position + Vector3(0, 1.2, 0), col)
			Sfx.play("dark")
			await _wait(0.55)
			for t in targets:
				_burst(t.node.position + Vector3(0, 1.2, 0), col, 30, 1.2)
			if sid == "abyssal_ruin":
				_shake = 1.0
		"ice":
			for t in targets:
				_shards(t.node.position, col)
			await _wait(0.4)
			for t in targets:
				_burst(t.node.position + Vector3(0, 1.2, 0), col, 30, 1.0)
		"fire":
			for t in targets:
				_flames(t.node.position, col)
			await _wait(0.35)
			for t in targets:
				_burst(t.node.position + Vector3(0, 1.0, 0), Color(1.0, 0.8, 0.3), 30, 1.2)
		_:
			if sid == "meteor":
				await _meteors(targets)
			else:
				for t in targets:
					_burst(t.node.position + Vector3(0, 1.2, 0), col, 30, 1.2)
				await _wait(0.3)


func _bolt(pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.1, 9.0, 0.1)
	mi.mesh = b
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(2.2, 2.0, 1.0)
	mi.material_override = m
	mi.position = pos + Vector3(0, 4.5, 0)
	add_child(mi)
	_flash_light(pos + Vector3(0, 2, 0), Color(1.0, 0.95, 0.5), 8.0)
	_burst(pos + Vector3(0, 0.4, 0), Color(1.0, 0.92, 0.3), 30, 1.2)
	var tw := create_tween()
	tw.tween_callback(mi.hide).set_delay(0.06)
	tw.tween_callback(mi.show).set_delay(0.06)
	tw.tween_property(mi, "scale:x", 0.1, 0.2)
	tw.tween_callback(mi.queue_free)


## A roaring column of fire that licks up around the target.
func _flames(pos: Vector3, col: Color) -> void:
	var p := CPUParticles3D.new()
	p.position = pos + Vector3(0, 0.1, 0.2)
	p.one_shot = true
	p.explosiveness = 0.2
	p.amount = 70
	p.lifetime = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.7
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 4.0, 0)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.5
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.15))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(2.5, 2.2, 1.2, 1.0))
	grad.set_color(1, Color(0.6, 0.1, 0.05, 0.0))
	grad.add_point(0.35, Color(col.r * 2.0, col.g * 1.5, col.b, 0.9))
	p.color_ramp = grad
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 0.45
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = PixelArt.soft_circle(16, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	q.material = m
	p.mesh = q
	add_child(p)
	p.emitting = true
	_flash_light(pos + Vector3(0, 1.2, 0.5), col, 6.0)
	_shake = 0.25
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


func _pillar(pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.8
	c.bottom_radius = 0.8
	c.height = 10.0
	mi.mesh = c
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col.r * 1.5, col.g * 1.5, col.b * 1.5, 0.0)
	mi.material_override = m
	mi.position = pos + Vector3(0, 5, 0)
	add_child(mi)
	_flash_light(pos + Vector3(0, 1.5, 0), col, 6.0)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.8, 0.2)
	tw.parallel().tween_property(mi, "scale", Vector3(0.4, 1, 0.4), 0.6).from(Vector3(1.4, 1, 1.4))
	tw.tween_property(m, "albedo_color:a", 0.0, 0.3)
	tw.tween_callback(mi.queue_free)


func _shards(pos: Vector3, col: Color) -> void:
	for i in 6:
		var mi := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.3, 1.0, 0.3)
		mi.mesh = pm
		var m := Props.color_material(Color(0.7, 0.9, 1.0, 0.85), col, 2.5)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = m
		var ang := i * TAU / 6.0
		var target := pos + Vector3(cos(ang) * 0.5, 0.4, sin(ang) * 0.4)
		mi.position = target + Vector3(0, 4.0, 0)
		mi.rotation_degrees = Vector3(180, 0, randf_range(-20, 20))
		add_child(mi)
		var tw := create_tween()
		tw.tween_interval(i * 0.03)
		tw.tween_property(mi, "position", target, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_interval(0.25)
		tw.tween_property(mi, "scale", Vector3.ZERO, 0.2)
		tw.tween_callback(mi.queue_free)


func _meteors(targets: Array) -> void:
	for t in targets:
		for k in 3:
			var mi := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.35
			s.height = 0.7
			mi.mesh = s
			var m := Props.color_material(Color(1.0, 0.6, 0.3), Color(1.0, 0.5, 0.2), 5.0)
			mi.material_override = m
			var dest: Vector3 = t.node.position + Vector3(randf_range(-0.6, 0.6), 0.6, randf_range(-0.4, 0.4))
			mi.position = dest + Vector3(-4.0, 9.0, -2.0)
			add_child(mi)
			var tw := create_tween()
			tw.tween_interval(k * 0.15 + randf() * 0.1)
			tw.tween_property(mi, "position", dest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.tween_callback(func():
				_burst(dest, Color(1.0, 0.55, 0.2), 30, 1.3)
				_shake = 0.4
				Sfx.play("hit")
				mi.queue_free())
	await _wait(0.9)


# ------------------------------------------------------------------- End ---
func _victory() -> void:
	await _wait(0.6)
	_update_strip([])
	if boss:
		finished.emit("win")
		return
	Sfx.play_music("victory")
	for h in _alive(heroes):
		var tw := create_tween()
		tw.tween_property(h.node, "position:y", 0.6, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(h.node, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_show_banner("VICTORY!", GOLD)
	var total_exp := 0
	var gold := 0
	for f in foes:
		total_exp += int(f.data.exp)
		gold += int(f.data.gold)
	Game.gold += gold
	var text := "[center][color=#ffd36a]Victory![/color][/center]\n\nGained [b]%d EXP[/b] and [b]%d Gold[/b].\n" % [total_exp, gold]
	var lvl := false
	for h in heroes:
		for msg in Game.gain_exp(h.member, total_exp):
			text += "\n[color=#9fe3ff]%s[/color]" % msg
			lvl = true
	result_label.text = text
	result_panel.visible = true
	if lvl:
		Sfx.play("levelup")
	_refresh_party()
	await _wait(0.5)
	await _wait_accept()
	finished.emit("win")


func _defeat() -> void:
	await _wait(0.8)
	finished.emit("lose")


func _end_flee() -> void:
	for h in _alive(heroes):
		var tw := create_tween()
		tw.tween_property(h.node, "position:x", h.home.x + 8.0, 0.5)
	await _wait(0.6)
	finished.emit("flee")


func _wait_accept() -> void:
	if auto_battle:
		return
	_targeting = true
	while true:
		var a: String = await _nav
		if a == "accept" or a == "cancel":
			break
	_targeting = false
