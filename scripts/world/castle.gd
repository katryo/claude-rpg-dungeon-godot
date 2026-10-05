extends Node3D
## Field exploration of the Dark Castle: builds the 3D level from DB.MAP,
## moves the party, handles chests, the save crystal, roaming enemies and the throne.

const DB := preload("res://scripts/data/db.gd")
const Props := preload("res://scripts/world/props.gd")
const PixelArt := preload("res://scripts/gfx/pixel_art.gd")

signal encounter(group_idx: int)
signal boss_triggered
signal menu_requested

const CELL := 2.0
const WALL_H := 4.2
const LEDGE_H := 0.5
const RADIUS := 0.35
const WALK_SPEED := 4.6
const DASH_SPEED := 7.5
const CAM_PITCH := 34.0
const CAM_DIST := 17.0
const CAM_FOV := 36.0
const FOLLOW_GAP := 9

var map: Array = []
var width := 0
var height := 0

var camera: Camera3D
var leader: Node3D
var followers: Array = []
var trail: Array = []
var facing_left := false
var walk_time := 0.0
var obstacles: Array = []        # [Vector3 pos, float radius]
var chests: Array = []           # {idx, node, lid, pos}
var enemies: Array = []          # {idx, node, home, pos, cooldown, target, wait, static}
var crystal_pos := Vector3.ZERO
var crystal_node: Node3D
var throne_pos := Vector3.ZERO
var boss_node: Node3D
var start_pos := Vector3.ZERO
var active := true
var _hud: CanvasLayer
var _location_label: Label
var _step_timer := 0.0


func _ready() -> void:
	map = DB.MAP
	height = map.size()
	width = map[0].length()
	Props.make_environment(self, CAM_DIST)
	Props.make_moonlight(self, 0.4)
	_build_level()
	_build_party()
	_build_camera()
	_build_hud()
	var p := start_pos
	if Game.has_field_position:
		p = Game.field_position
	place_party(p)


func _process(delta: float) -> void:
	Props.update_flicker(get_tree())
	_animate_props(delta)
	if active and not UI.busy():
		_handle_movement(delta)
		_update_enemies(delta)
		_check_boss_trigger()
	_update_followers()
	_update_camera(delta, false)


func _unhandled_input(event: InputEvent) -> void:
	if not active or UI.busy():
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_interact()
	elif event.is_action_pressed("menu") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		Sfx.play("confirm")
		menu_requested.emit()


# ------------------------------------------------------------------ Grid ---
func cell_at(x: int, y: int) -> String:
	if y < 0 or y >= height or x < 0 or x >= width:
		return "#"
	return map[y][x]


func cell_pos(x: int, y: int) -> Vector3:
	return Vector3(x * CELL, 0.0, y * CELL)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / CELL), roundi(p.z / CELL))


func is_wall_cell(x: int, y: int) -> bool:
	var c := cell_at(x, y)
	return c == "#" or c == "B"


func is_floor_char(c: String) -> bool:
	return c != "#"


func is_blocked(p: Vector3, radius: float = RADIUS) -> bool:
	for o in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var q := Vector3(p.x + o.x * radius, 0, p.z + o.y * radius)
		var c := world_to_cell(q)
		if is_wall_cell(c.x, c.y):
			return true
	for ob in obstacles:
		var op: Vector3 = ob[0]
		if Vector2(p.x - op.x, p.z - op.z).length() < radius + ob[1]:
			return true
	return false


# ----------------------------------------------------------------- Level ---
func _build_level() -> void:
	var level := Node3D.new()
	level.name = "Level"
	add_child(level)

	# One big floor slab under the whole map.
	var fl := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(width * CELL, 0.2, height * CELL)
	fl.mesh = fm
	fl.material_override = Props.floor_material()
	fl.position = Vector3((width - 1) * CELL / 2.0, -0.1, (height - 1) * CELL / 2.0)
	level.add_child(fl)

	var full_walls: Array = []
	var ledges: Array = []
	var carpet_mat := Props.carpet_material()
	var trim_mat := Props.tex_material(PixelArt.carpet_border(), 2.0)
	var e_idx := 0
	var c_idx := 0
	for y in height:
		for x in width:
			var c := cell_at(x, y)
			var p := cell_pos(x, y)
			match c:
				"#":
					if not _near_floor(x, y):
						continue
					if is_floor_char(cell_at(x, y - 1)) and cell_at(x, y - 1) != "B":
						ledges.append(p)
					else:
						full_walls.append(p)
				"r", "P":
					_add_carpet(level, x, y, carpet_mat, trim_mat)
				"i":
					Props.make_pillar(level, p, WALL_H + 0.3)
					obstacles.append([p, 0.5])
				"b":
					Props.make_brazier(level, p)
					obstacles.append([p, 0.4])
				"C":
					_add_chest(level, p, c_idx)
					c_idx += 1
				"E":
					_add_enemy(p, e_idx)
					e_idx += 1
				"S":
					_add_crystal(level, p)
					_add_carpet(level, x, y, carpet_mat, trim_mat)
				"B":
					_add_throne(level, p)
					_add_carpet(level, x, y, carpet_mat, trim_mat)
			if c == "P":
				start_pos = p

	_add_wall_multimesh(level, full_walls, WALL_H, Props.wall_material())
	_add_wall_multimesh(level, ledges, LEDGE_H, Props.wall_material())
	var cap := Props.color_material(Color(0.09, 0.08, 0.12))
	_add_caps(level, full_walls, WALL_H, cap)
	_add_caps(level, ledges, LEDGE_H, Props.tex_material(PixelArt.stone_floor(), 0.5, Color(0.8, 0.78, 0.9)))
	_decorate_back_walls(level)
	Props.make_dust(level, Vector3(width * CELL / 2.0, 3.0, height * CELL / 2.0), 400).position = Vector3(width * CELL / 2.0, 2.5, height * CELL / 2.0)


func _near_floor(x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if is_floor_char(cell_at(x + dx, y + dy)):
				return true
	return false


func _add_wall_multimesh(parent: Node3D, cells: Array, h: float, mat: Material) -> void:
	if cells.is_empty():
		return
	var box := BoxMesh.new()
	box.size = Vector3(CELL, h, CELL)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = cells.size()
	for i in cells.size():
		mm.set_instance_transform(i, Transform3D(Basis(), cells[i] + Vector3(0, h / 2.0, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	parent.add_child(mmi)


func _add_caps(parent: Node3D, cells: Array, h: float, mat: Material) -> void:
	if cells.is_empty():
		return
	var box := BoxMesh.new()
	box.size = Vector3(CELL + 0.02, 0.12, CELL + 0.02)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = box
	mm.instance_count = cells.size()
	for i in cells.size():
		mm.set_instance_transform(i, Transform3D(Basis(), cells[i] + Vector3(0, h + 0.06, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	parent.add_child(mmi)


func _add_carpet(parent: Node3D, x: int, y: int, mat: Material, trim: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(CELL, 0.04, CELL)
	mi.mesh = b
	mi.material_override = mat
	mi.position = cell_pos(x, y) + Vector3(0, 0.02, 0)
	parent.add_child(mi)
	# Gold trim along carpet edges.
	for side in [-1, 1]:
		var n := cell_at(x + side, y)
		if n != "r" and n != "P" and n != "S" and n != "B":
			var t := MeshInstance3D.new()
			var tb := BoxMesh.new()
			tb.size = Vector3(0.16, 0.05, CELL)
			t.mesh = tb
			t.material_override = trim
			t.position = cell_pos(x, y) + Vector3(side * (CELL / 2.0 - 0.08), 0.025, 0)
			parent.add_child(t)


## Torches, banners and windows on walls that face the camera.
func _decorate_back_walls(parent: Node3D) -> void:
	for y in height:
		for x in width:
			if cell_at(x, y) != "#":
				continue
			var below := cell_at(x, y + 1)
			if not is_floor_char(below) or is_floor_char(cell_at(x, y - 1)):
				continue
			var face := cell_pos(x, y) + Vector3(0, 0, CELL / 2.0 + 0.03)
			var k := (x * 7 + y * 3) % 6
			if k == 0 or k == 3:
				Props.make_wall_torch(parent, face + Vector3(0, 2.3, 0.08))
			elif k == 1:
				Props.make_banner(parent, face + Vector3(0, 2.4, 0))
			elif k == 4:
				Props.make_window(parent, face + Vector3(0, 2.6, 0))


func _add_chest(parent: Node3D, p: Vector3, idx: int) -> void:
	var root := Node3D.new()
	root.position = p
	parent.add_child(root)
	var wood := Props.color_material(Color(0.45, 0.22, 0.1))
	var gold := Props.gold_material()
	var body := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(1.1, 0.6, 0.75)
	body.mesh = bb
	body.material_override = wood
	body.position.y = 0.3
	root.add_child(body)
	var band := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.14, 0.08, 0.79)
	band.mesh = bm
	band.material_override = gold
	band.position.y = 0.45
	root.add_child(band)
	var hinge := Node3D.new()
	hinge.position = Vector3(0, 0.6, -0.375)
	root.add_child(hinge)
	var lid := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(1.12, 0.25, 0.77)
	lid.mesh = lm
	lid.material_override = wood
	lid.position = Vector3(0, 0.125, 0.385)
	hinge.add_child(lid)
	var lock := MeshInstance3D.new()
	var lk := BoxMesh.new()
	lk.size = Vector3(0.18, 0.2, 0.05)
	lock.mesh = lk
	lock.material_override = gold
	lock.position = Vector3(0, 0.05, 0.78)
	hinge.add_child(lock)
	obstacles.append([p, 0.6])
	var opened: bool = Game.opened_chests.has(idx)
	if opened:
		hinge.rotation_degrees.x = -110
	chests.append({"idx": idx, "node": root, "lid": hinge, "pos": p})


func _add_crystal(parent: Node3D, p: Vector3) -> void:
	crystal_pos = p
	var root := Node3D.new()
	root.position = p
	parent.add_child(root)
	var gem := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.45
	s.height = 1.4
	s.radial_segments = 6
	s.rings = 2
	gem.mesh = s
	var m := Props.color_material(Color(0.4, 0.85, 1.0, 0.8), Color(0.3, 0.8, 1.0), 2.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.3
	m.roughness = 0.1
	gem.mesh.material = m
	gem.position.y = 1.4
	root.add_child(gem)
	crystal_node = gem
	var base := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.5
	c.bottom_radius = 0.7
	c.height = 0.3
	base.mesh = c
	base.material_override = Props.tex_material(PixelArt.brick_wall(), 1.0)
	base.position.y = 0.15
	root.add_child(base)
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 0.85, 1.0)
	l.light_energy = 2.2
	l.omni_range = 6.0
	l.position.y = 1.5
	l.light_volumetric_fog_energy = 2.0
	root.add_child(l)
	Props.make_dust(root, Vector3(0.6, 0.8, 0.6), 24, Color(0.6, 0.95, 1.0, 0.9)).position.y = 1.2
	obstacles.append([p, 0.6])


func _add_throne(parent: Node3D, p: Vector3) -> void:
	throne_pos = p
	var dais := MeshInstance3D.new()
	var d := BoxMesh.new()
	d.size = Vector3(CELL * 3, 0.4, CELL * 1.6)
	dais.mesh = d
	dais.material_override = Props.tex_material(PixelArt.stone_floor(), 0.5, Color(0.7, 0.6, 0.8))
	dais.position = p + Vector3(0, 0.2, -0.3)
	parent.add_child(dais)
	var seat := MeshInstance3D.new()
	var sb := BoxMesh.new()
	sb.size = Vector3(1.6, 0.8, 1.2)
	seat.mesh = sb
	var dark := Props.color_material(Color(0.12, 0.06, 0.16))
	seat.material_override = dark
	seat.position = p + Vector3(0, 0.8, -0.5)
	parent.add_child(seat)
	var back := MeshInstance3D.new()
	var bk := BoxMesh.new()
	bk.size = Vector3(1.8, 3.6, 0.3)
	back.mesh = bk
	back.material_override = dark
	back.position = p + Vector3(0, 2.2, -1.0)
	parent.add_child(back)
	for sx in [-1, 1]:
		var spike := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.5, 1.2, 0.3)
		spike.mesh = pm
		spike.material_override = Props.gold_material()
		spike.position = p + Vector3(sx * 0.7, 4.5, -1.0)
		parent.add_child(spike)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.7, 0.2, 1.0)
	glow.light_energy = 3.0
	glow.omni_range = 9.0
	glow.position = p + Vector3(0, 2.5, 0.5)
	glow.light_volumetric_fog_energy = 2.5
	parent.add_child(glow)
	if not Game.boss_defeated:
		boss_node = Props.make_billboard("dark_lord", 1.6)
		boss_node.position = p + Vector3(0, 0.4, 0.2)
		add_child(boss_node)


func _add_enemy(p: Vector3, idx: int) -> void:
	if Game.defeated_groups.has(idx):
		return
	var leader_id := DB.encounter_leader(idx)
	var e: Dictionary = DB.ENEMIES[leader_id]
	var node := Props.make_billboard(e.sprite, e.scale * 0.9)
	node.position = p
	add_child(node)
	# Ominous aura under field enemies.
	var aura := OmniLight3D.new()
	aura.light_color = Color(0.8, 0.2, 0.6)
	aura.light_energy = 0.8
	aura.omni_range = 2.5
	aura.position.y = 0.6
	node.add_child(aura)
	enemies.append({
		"idx": idx, "node": node, "home": p, "pos": p, "cooldown": 0.0,
		"target": p, "wait": randf_range(0.5, 2.0), "static": idx == 0,
		"phase": randf() * TAU,
	})


# ----------------------------------------------------------------- Party ---
func _build_party() -> void:
	for i in Game.party.size():
		var m: Dictionary = Game.party[i]
		var node := Props.make_billboard(DB.HEROES[m.id].sprite)
		add_child(node)
		if i == 0:
			leader = node
			var lantern := OmniLight3D.new()
			lantern.light_color = Color(1.0, 0.8, 0.55)
			lantern.light_energy = 2.2
			lantern.omni_range = 8.0
			lantern.position = Vector3(0, 2.2, 0.8)
			lantern.shadow_enabled = true
			node.add_child(lantern)
		else:
			followers.append(node)


func place_party(p: Vector3) -> void:
	leader.position = p
	trail.clear()
	# Line the followers up behind the leader (south), as far as the walls allow.
	var back := p
	for i in 40:
		var nxt := back + Vector3(0, 0, 0.16)
		if not is_blocked(nxt):
			back = nxt
		trail.append(back)
	for i in followers.size():
		followers[i].position = trail[mini((i + 1) * FOLLOW_GAP, trail.size() - 1)]
	_update_camera(0.0, true)


func _handle_movement(delta: float) -> void:
	var dir := Vector3(
		Input.get_axis("ui_left", "ui_right"), 0, Input.get_axis("ui_up", "ui_down"))
	var moving := dir.length() > 0.1
	var spr: Sprite3D = leader.get_node("Sprite")
	if moving:
		dir = dir.normalized()
		var speed := DASH_SPEED if Input.is_action_pressed("dash") else WALK_SPEED
		var step := dir * speed * delta
		var p := leader.position
		if not is_blocked(p + Vector3(step.x, 0, 0)):
			p.x += step.x
		if not is_blocked(p + Vector3(0, 0, step.z)):
			p.z += step.z
		if p.distance_to(leader.position) > 0.0001:
			leader.position = p
			if p.distance_to(trail[0]) > 0.16:
				trail.push_front(p)
				if trail.size() > 60:
					trail.pop_back()
		if absf(dir.x) > 0.1:
			facing_left = dir.x < 0
		walk_time += delta * (14.0 if speed > WALK_SPEED else 10.0)
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.32 if speed <= WALK_SPEED else 0.22
			Sfx.play("step", randf_range(0.8, 1.2))
	else:
		walk_time = 0.0
	spr.flip_h = facing_left
	_bob(leader, walk_time, moving)
	Game.field_position = leader.position
	Game.has_field_position = true


func _bob(node: Node3D, t: float, moving: bool) -> void:
	var spr: Sprite3D = node.get_node("Sprite")
	var base_y: float = spr.texture.get_height() * spr.pixel_size * 0.5 - spr.pixel_size
	if moving:
		spr.position.y = base_y + absf(sin(t)) * 0.12
	else:
		spr.position.y = base_y + sin(Time.get_ticks_msec() / 400.0) * 0.015


func _update_followers() -> void:
	for i in followers.size():
		var f: Node3D = followers[i]
		var target: Vector3 = trail[mini((i + 1) * FOLLOW_GAP, trail.size() - 1)]
		var prev := f.position
		f.position = f.position.lerp(target, 0.35)
		var moved := f.position.distance_to(prev)
		var spr: Sprite3D = f.get_node("Sprite")
		if absf(f.position.x - prev.x) > 0.005:
			spr.flip_h = f.position.x < prev.x
		_bob(f, Time.get_ticks_msec() / 100.0 + i, moved > 0.01)


# ---------------------------------------------------------------- Camera ---
func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = CAM_FOV
	camera.far = 120.0
	add_child(camera)
	camera.make_current()


func _update_camera(delta: float, snap: bool) -> void:
	if camera == null or leader == null:
		return
	var pitch := deg_to_rad(CAM_PITCH)
	var focus := leader.position + Vector3(0, 0.8, 0)
	var target := focus + Vector3(0, sin(pitch) * CAM_DIST, cos(pitch) * CAM_DIST)
	if snap:
		camera.position = target
	else:
		camera.position = camera.position.lerp(target, clampf(delta * 5.0, 0.0, 1.0))
	camera.look_at(camera.position - Vector3(0, sin(pitch), cos(pitch)), Vector3.UP)


func resume() -> void:
	active = true
	camera.make_current()
	_hud.visible = true


func suspend() -> void:
	active = false
	_hud.visible = false


# ------------------------------------------------------------------- HUD ---
func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 5
	add_child(_hud)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme
	_hud.add_child(root)
	_location_label = Label.new()
	_location_label.text = "Castle Nocturne"
	_location_label.add_theme_font_size_override("font_size", 28)
	_location_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	_location_label.position = Vector2(36, 24)
	root.add_child(_location_label)
	var hint := Label.new()
	hint.text = "Move: Arrows/WASD   Dash: Shift   Check: Z/Enter   Menu: X/Tab"
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate.a = 0.7
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.offset_left = -560
	hint.offset_top = -34
	root.add_child(hint)
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(_location_label, "modulate:a", 0.0, 1.5)


# ----------------------------------------------------------- Interaction ---
func _interact() -> void:
	var p := leader.position
	for ch in chests:
		if p.distance_to(ch.pos) < 1.9 and not Game.opened_chests.has(ch.idx):
			active = false
			await _open_chest(ch)
			active = true
			return
	if p.distance_to(crystal_pos) < 2.0:
		active = false
		await _use_crystal()
		active = true


func _open_chest(ch: Dictionary) -> void:
	Game.opened_chests[ch.idx] = true
	Sfx.play("chest")
	var tw := create_tween()
	tw.tween_property(ch.lid, "rotation_degrees:x", -110.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var burst := Props.make_dust(ch.node, Vector3(0.4, 0.3, 0.3), 30, Color(1.0, 0.9, 0.5, 1.0))
	burst.position.y = 0.8
	burst.preprocess = 0.0
	burst.one_shot = true
	burst.lifetime = 1.5
	var content: Dictionary = DB.CHESTS[ch.idx]
	var lines: Array = []
	for eid in content.get("equip", []):
		Game.add_equipment(eid)
		lines.append(["", "Found [color=#ffd36a]%s[/color]!" % DB.EQUIPMENT[eid].name])
	var items: Dictionary = content.get("items", {})
	for iid in items:
		Game.add_item(iid, items[iid])
		lines.append(["", "Found [color=#9fe3ff]%s[/color] x%d!" % [DB.ITEMS[iid].name, items[iid]]])
	await get_tree().create_timer(0.3).timeout
	await UI.say(lines)


func _use_crystal() -> void:
	Sfx.play("save")
	Game.full_restore()
	Game.field_position = leader.position
	Game.save_checkpoint()
	var tw := create_tween()
	tw.tween_property(crystal_node, "scale", Vector3.ONE * 1.4, 0.15)
	tw.tween_property(crystal_node, "scale", Vector3.ONE, 0.3)
	await UI.say([["", "A warm light pours from the crystal.\nThe party's HP and MP are fully restored.\n[color=#9fe3ff]Your progress has been recorded.[/color]"]])


func _check_boss_trigger() -> void:
	if boss_node == null or Game.boss_defeated:
		return
	if leader.position.z < throne_pos.z + CELL * 2.6 and absf(leader.position.x - throne_pos.x) < CELL * 2.5:
		active = false
		boss_triggered.emit()


# --------------------------------------------------------------- Enemies ---
func _update_enemies(delta: float) -> void:
	var lp := leader.position
	for e in enemies:
		var node: Node3D = e.node
		e.cooldown = maxf(0.0, e.cooldown - delta)
		node.visible = e.cooldown <= 0.0 or int(e.cooldown * 10.0) % 2 == 0
		var pos: Vector3 = e.pos
		var dist := pos.distance_to(lp)
		var speed := 0.0
		var target: Vector3 = e.target
		if not e.static:
			if dist < 5.5 and e.cooldown <= 0.0:
				target = lp
				speed = 3.0
			else:
				e.wait -= delta
				if e.wait <= 0.0:
					e.wait = randf_range(1.5, 3.5)
					e.target = e.home + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
				target = e.target
				speed = 1.2
			var d := target - pos
			d.y = 0
			if d.length() > 0.1:
				var step := d.normalized() * speed * delta
				if not is_blocked(pos + Vector3(step.x, 0, 0), 0.4):
					pos.x += step.x
				if not is_blocked(pos + Vector3(0, 0, step.z), 0.4):
					pos.z += step.z
				node.get_node("Sprite").flip_h = d.x < 0
			e.pos = pos
		node.position = pos
		var spr: Sprite3D = node.get_node("Sprite")
		var base_y: float = spr.texture.get_height() * spr.pixel_size * 0.5 - spr.pixel_size
		spr.position.y = base_y + absf(sin(Time.get_ticks_msec() / 160.0 + e.phase)) * 0.1
		if dist < 1.1 and e.cooldown <= 0.0:
			active = false
			encounter.emit(e.idx)
			return


func remove_enemy(idx: int) -> void:
	for e in enemies:
		if e.idx == idx:
			e.node.queue_free()
			enemies.erase(e)
			return


func enemy_cooldown(idx: int) -> void:
	for e in enemies:
		if e.idx == idx:
			e.cooldown = 3.0


func remove_boss() -> void:
	if boss_node:
		boss_node.queue_free()
		boss_node = null


func _animate_props(_delta: float) -> void:
	if crystal_node:
		var t := Time.get_ticks_msec() / 1000.0
		crystal_node.rotation.y = t * 0.8
		crystal_node.position.y = 1.4 + sin(t * 2.0) * 0.12
	if boss_node:
		var spr: Sprite3D = boss_node.get_node("Sprite")
		spr.modulate = Color(1, 1, 1).lerp(Color(1.0, 0.6, 1.0), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 300.0))
