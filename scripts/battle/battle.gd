class_name Battle
extends Node3D
## Turn-based HD-2D battle. The arena, camera, slots and UI are authored in
## battle.tscn; effects are separate scenes assigned in the inspector.
## Emits `finished("win" | "lose" | "flee")`.

signal finished(result: String)
signal _nav(action: String)

const GOLD := Color(1.0, 0.84, 0.45)
const SPRITE_SCALE := 1.25
const KO_TINT := Color(0.55, 0.4, 0.5)

@export var character_scene: PackedScene
@export_group("Effects")
@export var burst_fx: PackedScene
@export var rise_fx: PackedScene
@export var implode_fx: PackedScene
@export var flames_fx: PackedScene
@export var slash_fx: PackedScene
@export var bolt_fx: PackedScene
@export var holy_pillar_fx: PackedScene
@export var ice_shards_fx: PackedScene
@export var meteor_fx: PackedScene
@export var cast_circle_fx: PackedScene
@export var damage_popup: PackedScene
@export var target_cursor: PackedScene
@export var flash_light: PackedScene
@export_group("Boss fight")
@export var boss_environment: Environment
@export var boss_camera_attributes: CameraAttributes
@export var boss_camera_offset := Vector3(0.0, 0.7, 1.2)

var enemies: Array[EnemyData] = []
var boss := false
var auto_battle := false   # used by the headless balance test

var heroes: Array[Battler] = []
var foes: Array[Battler] = []
var _cam_base := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _shake := 0.0
var _cam_push := Vector3.ZERO
var _cursors: Array[Node3D] = []
var _targeting := false
var _fled := false
var _boss_turns := 0
var _boss_phase_shown := false

@onready var camera: Camera3D = %Camera
@onready var cmd_list: SelectList = %CommandList
@onready var sub_panel: Control = %SkillPanel
@onready var _sub_list: SelectList = %SkillList
@onready var _banner: Control = %Banner
@onready var _banner_label: Label = %BannerLabel
@onready var _info_panel: Control = %InfoPanel
@onready var _info_label: Label = %InfoLabel
@onready var _rows: Array = %PartyRows.get_children()


func setup(enemy_list: Array[EnemyData], is_boss: bool) -> void:
	enemies = enemy_list
	boss = is_boss


func _ready() -> void:
	%CommandPanel.hide()
	sub_panel.hide()
	_info_panel.hide()
	%ResultPanel.hide()
	_banner.modulate.a = 0.0
	%BossDecor.visible = boss
	if boss:
		%WorldEnvironment.environment = boss_environment
		%WorldEnvironment.camera_attributes = boss_camera_attributes
		camera.position += boss_camera_offset
		camera.fov += 4.0
	_cam_base = camera.position
	_cam_look = %CameraTarget.global_position + (Vector3(0, 0.7, -0.3) if boss else Vector3.ZERO)
	_spawn_battlers()
	_refresh_party()
	Audio.play_music(&"boss" if boss else &"battle")
	_run.call_deferred()


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var sway := Vector3(sin(t * 0.35) * 0.25, sin(t * 0.5) * 0.08, 0)
	var shake := Vector3.ZERO
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		shake = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.6
	camera.position = _cam_base + sway + shake + _cam_push
	camera.look_at(_cam_look + _cam_push * 0.6, Vector3.UP)
	for b in heroes + foes:
		if b.alive():
			b.view.set_bob(sin(t * 2.2 + b.home.z) * (0.15 if b.flying else 0.02) + (0.6 if b.flying else 0.0))


func _spawn_battlers() -> void:
	var slots := %HeroSlots.get_children()
	for i in Game.party.size():
		var b := Battler.from_member(Game.party[i])
		b.home = slots[i].global_position
		_attach_view(b, b.member.hero.sprite_frames, SPRITE_SCALE)
		b.view.flipped = true
		if not b.alive():
			_show_ko(b, true)
		heroes.append(b)
	var layout: Node = %EnemyLayouts.get_node("Boss" if boss else ["One", "Two", "Three"][clampi(enemies.size(), 1, 3) - 1])
	var counts := {}
	for e in enemies:
		counts[e] = counts.get(e, 0) + 1
	var seen := {}
	for j in enemies.size():
		var e := enemies[j]
		var suffix := ""
		if counts[e] > 1:
			suffix = " " + "ABC"[seen.get(e, 0)]
			seen[e] = seen.get(e, 0) + 1
		var b := Battler.from_enemy(e, suffix)
		b.home = layout.get_child(j).global_position
		_attach_view(b, e.sprite_frames, e.sprite_scale * SPRITE_SCALE * (0.75 if e.is_boss else 1.0))
		foes.append(b)


func _attach_view(b: Battler, frames: SpriteFrames, scale_factor: float) -> void:
	var v: CharacterSprite = character_scene.instantiate()
	v.sprite_frames = frames
	v.sprite_scale = scale_factor
	%Battlers.add_child(v)
	v.global_position = b.home
	b.view = v


func _spawn(scene: PackedScene, pos: Vector3, tint := Color.WHITE, size := 1.0) -> Node3D:
	var fx: Node3D = scene.instantiate()
	if "tint" in fx:
		fx.tint = tint
	%Effects.add_child(fx)
	fx.global_position = pos
	fx.scale = Vector3.ONE * size
	return fx


# -------------------------------------------------------------------- UI ---
func _refresh_party(active: Battler = null) -> void:
	for i in _rows.size():
		_rows[i].visible = i < heroes.size()
		if i < heroes.size():
			_rows[i].show_battler(heroes[i], heroes[i] == active)


func _update_strip(order: Array) -> void:
	var strip: HBoxContainer = %TurnStrip
	for c in strip.get_children():
		c.queue_free()
	for b in order:
		if not b.alive():
			continue
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(40, 36)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = b.icon()
		if not b.is_hero:
			tr.modulate = Color(1.0, 0.75, 0.8)
		strip.add_child(tr)


func _show_banner(text: String, color := Color(0.95, 0.93, 0.88)) -> void:
	_banner_label.text = text
	_banner_label.add_theme_color_override("font_color", color)
	create_tween().tween_property(_banner, "modulate:a", 1.0, 0.12)


func _hide_banner() -> void:
	create_tween().tween_property(_banner, "modulate:a", 0.0, 0.2)


func _info(text: String) -> void:
	_info_panel.visible = text != ""
	_info_label.text = text


# ------------------------------------------------------------------ Flow ---
func _run() -> void:
	await _wait(0.2)
	await UI.fade_in(0.4)
	if boss:
		_show_banner(foes[0].display_name, Color(1.0, 0.5, 0.9))
	else:
		var names := {}
		for f in foes:
			names[f.enemy.display_name] = true
		_show_banner("%s appeared!" % " & ".join(names.keys()))
	await _wait(1.1)
	_hide_banner()
	while true:
		var order := _make_order()
		for idx in order.size():
			var b: Battler = order[idx]
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
			if _alive(foes).is_empty():
				await _victory()
				return
			if _alive(heroes).is_empty():
				await _wait(0.8)
				finished.emit("lose")
				return


func _make_order() -> Array:
	var all: Array = []
	for b in heroes + foes:
		if b.alive():
			all.append([b.stat("spd") * randf_range(0.85, 1.15), b])
			if b.is_boss and b.phase >= 2:
				all.append([b.stat("spd") * randf_range(0.4, 0.7), b])
	all.sort_custom(func(a, c): return a[0] > c[0])
	var out: Array = []
	for x in all:
		out.append(x[1])
	return out


func _alive(list: Array) -> Array:
	return list.filter(func(b: Battler): return b.alive())


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


# ------------------------------------------------------------ Hero turn ---
func _hero_turn(b: Battler) -> void:
	_refresh_party(b)
	create_tween().tween_property(b.view, "global_position", b.home + Vector3(-0.6, 0, 0), 0.15)
	var action := {}
	if auto_battle:
		action = _auto_action(b)
	while action.is_empty():
		%CommandPanel.show()
		cmd_list.set_items([
			{"text": "Attack"},
			{"text": "Skills"},
			{"text": "Items", "enabled": not Game.inventory.is_empty()},
			{"text": "Defend"},
			{"text": "Flee", "enabled": not boss},
		], true)
		_info("")
		match await cmd_list.choose():
			0:
				var t := await _pick_targets(b, SkillData.Target.ENEMY)
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
	%CommandPanel.hide()
	sub_panel.hide()
	_info("")
	var back := create_tween()
	back.tween_property(b.view, "global_position", b.home, 0.12)
	await back.finished
	await _execute(b, action)
	_refresh_party()


func _choose_skill(b: Battler) -> Dictionary:
	%SkillTitle.text = "%s's Skills" % b.display_name
	sub_panel.show()
	var skills := b.skills()
	while true:
		_sub_list.set_items(skills.map(func(s: SkillData): return {
			"text": s.display_name, "right": "%d MP" % s.mp_cost, "enabled": b.mp >= s.mp_cost}), true)
		var on_move := func(i: int): _info(skills[i].description)
		_sub_list.moved.connect(on_move)
		on_move.call(_sub_list.index)
		var si := await _sub_list.choose()
		_sub_list.moved.disconnect(on_move)
		if si < 0:
			sub_panel.hide()
			return {}
		var t := await _pick_targets(b, skills[si].target)
		if not t.is_empty():
			sub_panel.hide()
			return {"type": "skill", "skill": skills[si], "targets": t}
	return {}


func _choose_item(b: Battler) -> Dictionary:
	%SkillTitle.text = "Items"
	sub_panel.show()
	while true:
		var ids := Game.item_list()
		if ids.is_empty():
			sub_panel.hide()
			return {}
		_sub_list.set_items(ids.map(func(it: ItemData): return {"text": it.display_name, "right": "x%d" % Game.inventory[it]}), true)
		var on_move := func(i: int): _info(ids[i].description)
		_sub_list.moved.connect(on_move)
		on_move.call(_sub_list.index)
		var ii := await _sub_list.choose()
		_sub_list.moved.disconnect(on_move)
		if ii < 0:
			sub_panel.hide()
			return {}
		var t := await _pick_targets(b, ids[ii].target)
		if not t.is_empty():
			sub_panel.hide()
			return {"type": "item", "item": ids[ii], "targets": t}
	return {}


## Target selection with a bouncing cursor. Returns [] if cancelled.
func _pick_targets(b: Battler, ttype: SkillData.Target) -> Array:
	var pool: Array = []
	var multi := false
	match ttype:
		SkillData.Target.SELF:
			return [b]
		SkillData.Target.ENEMY:
			pool = _alive(foes)
		SkillData.Target.ALL_ENEMIES:
			pool = _alive(foes)
			multi = true
		SkillData.Target.ALLY:
			pool = _alive(heroes)
		SkillData.Target.ALL_ALLIES:
			pool = _alive(heroes)
			multi = true
		SkillData.Target.DEAD_ALLY:
			pool = heroes.filter(func(h: Battler): return not h.alive())
	if pool.is_empty():
		Audio.play_sfx(&"buzz")
		return []
	pool.sort_custom(func(x: Battler, y: Battler): return x.home.z < y.home.z)
	var idx := maxi(0, pool.find(b)) if ttype == SkillData.Target.ALLY else 0
	while true:
		_show_cursors(pool if multi else [pool[idx]])
		if multi:
			_info("Target: all %s" % ("enemies" if ttype == SkillData.Target.ALL_ENEMIES else "allies"))
		else:
			var t: Battler = pool[idx]
			_info("%s   HP %d/%d" % [t.display_name, t.hp, t.max_hp()] if t.is_hero else t.display_name + _foe_hint(t))
		_targeting = true
		var a: String = await _nav
		_targeting = false
		match a:
			"up", "left", "down", "right":
				idx = wrapi(idx + (-1 if a in ["up", "left"] else 1), 0, pool.size())
				Audio.play_sfx(&"cursor")
			"accept":
				Audio.play_sfx(&"confirm")
				_show_cursors([])
				return pool.duplicate() if multi else [pool[idx]]
			"cancel":
				Audio.play_sfx(&"cancel")
				_show_cursors([])
				_info("")
				return []
	return []


func _foe_hint(t: Battler) -> String:
	var k := float(t.hp) / t.max_hp()
	return "   — %s" % ("Unhurt" if k > 0.95 else ("Wounded" if k > 0.5 else ("Badly hurt" if k > 0.2 else "Near death")))


func _show_cursors(targets: Array) -> void:
	for c in _cursors:
		c.queue_free()
	_cursors.clear()
	for t in targets:
		var c: Node3D = target_cursor.instantiate()
		%Effects.add_child(c)
		c.global_position = t.view.global_position + Vector3(0, t.view.height() + 0.3 + (0.6 if t.flying else 0.0), 0)
		_cursors.append(c)


func _unhandled_input(event: InputEvent) -> void:
	if not _targeting:
		return
	var a := ""
	for action in ["up", "down", "left", "right", "accept", "cancel"]:
		if event.is_action_pressed("ui_" + action, action in ["up", "down", "left", "right"]):
			a = action
	if event is InputEventMouseButton and event.pressed:
		a = "accept" if event.button_index == MOUSE_BUTTON_LEFT else ("cancel" if event.button_index == MOUSE_BUTTON_RIGHT else "")
	if a != "":
		get_viewport().set_input_as_handled()
		_nav.emit(a)


## Simple AI used for automated balance testing.
func _auto_action(b: Battler) -> Dictionary:
	var hurt := _alive(heroes).filter(func(h: Battler): return h.hp < h.max_hp() * 0.45)
	var dead := heroes.filter(func(h: Battler): return not h.alive())
	var foe: Battler = _alive(foes).pick_random()
	var sk: Dictionary = {}
	for s in b.skills():
		sk[s.resource_path.get_file().get_basename()] = s
	var can := func(id: String) -> bool: return sk.has(id) and b.mp >= sk[id].mp_cost
	var phoenix := _item("phoenix_down")
	var hi_potion := _item("hi_potion")
	var ether := _item("ether")
	if not dead.is_empty() and can.call("anastasis"):
		return {"type": "skill", "skill": sk.anastasis, "targets": [dead[0]]}
	if not dead.is_empty() and phoenix:
		return {"type": "item", "item": phoenix, "targets": [dead[0]]}
	if hurt.size() >= 2 and can.call("asclepius_grace"):
		return {"type": "skill", "skill": sk.asclepius_grace, "targets": _alive(heroes)}
	if not hurt.is_empty() and can.call("cure"):
		return {"type": "skill", "skill": sk.cure, "targets": [hurt[0]]}
	if not hurt.is_empty() and hi_potion:
		return {"type": "item", "item": hi_potion, "targets": [hurt[0]]}
	if b.mp < 12 and ether:
		return {"type": "item", "item": ether, "targets": [b]}
	if boss:
		if can.call("iron_wall") and not b.buffs.has("def"):
			return {"type": "skill", "skill": sk.iron_wall, "targets": _alive(heroes)}
		if can.call("provoke") and b.provoke <= 0:
			return {"type": "skill", "skill": sk.provoke, "targets": [b]}
		if sk.has("athenas_insight") and not b.buffs.has("mag") and b.mp >= 30:
			return {"type": "skill", "skill": sk.athenas_insight, "targets": [b]}
	for id in ["lumina_blade", "holy", "meteor", "earthsplitter", "thunder_slash", "fira", "shield_bash"]:
		if sk.has(id) and b.mp >= sk[id].mp_cost + 8:
			var s: SkillData = sk[id]
			return {"type": "skill", "skill": s, "targets": _alive(foes) if s.target == SkillData.Target.ALL_ENEMIES else [foe]}
	return {"type": "attack", "targets": [foe]}


func _item(id: String) -> ItemData:
	for it in Game.inventory:
		if it.resource_path.get_file().get_basename() == id:
			return it
	return null


# ----------------------------------------------------------- Enemy turn ---
func _enemy_turn(b: Battler) -> void:
	await _wait(0.25)
	if b.is_boss:
		if b.phase == 1 and b.hp <= b.max_hp() / 2 and not _boss_phase_shown:
			_boss_phase_shown = true
			await _boss_transform(b)
		_boss_turns += 1
		var skill: SkillData
		if b.charging:
			b.charging = false
			skill = preload("res://data/skills/abyssal_ruin.tres")
		elif b.phase >= 2 and _boss_turns % 4 == 0:
			b.charging = true
			skill = preload("res://data/skills/gathering_darkness.tres")
		else:
			skill = b.enemy.pick_action()
		await _execute(b, {"type": "skill", "skill": skill, "targets": _enemy_targets(skill)})
		return
	var s := b.enemy.pick_action()
	await _execute(b, {"type": "skill", "skill": s, "targets": _enemy_targets(s)})


func _boss_transform(b: Battler) -> void:
	_show_banner("Malzeth: Enough! Witness my true form!", Color(1.0, 0.45, 0.8))
	Audio.play_sfx(&"dark")
	_shake = 0.8
	var tw := create_tween()
	tw.tween_property(b.view.sprite(), "modulate", Color(2.5, 0.6, 2.5), 0.4)
	tw.tween_property(b.view.sprite(), "modulate", Color(1.3, 0.75, 1.3), 0.6)
	tw.parallel().tween_property(b.view, "scale", Vector3.ONE * 1.12, 0.6)
	_spawn(burst_fx, b.view.global_position + Vector3(0, 2.5, 0), Color(0.7, 0.2, 1.0), 3.0)
	await _wait(1.8)
	b.phase = 2
	_hide_banner()


func _enemy_targets(s: SkillData) -> Array:
	var alive := _alive(heroes)
	match s.target:
		SkillData.Target.ALL_ENEMIES:
			return alive
		SkillData.Target.SELF:
			return []
	var provokers := alive.filter(func(h: Battler): return h.provoke > 0)
	if not provokers.is_empty() and randf() < 0.85:
		return [provokers[0]]
	return [alive.pick_random()]


# ------------------------------------------------------------- Execute ---
func _execute(a: Battler, action: Dictionary) -> void:
	var targets: Array = []
	targets.assign(action.get("targets", []))
	match action.type:
		"defend":
			a.defending = true
			_show_banner("%s defends." % a.display_name)
			Audio.play_sfx(&"buff")
			_spawn(burst_fx, a.view.global_position + Vector3(0, 1.2, 0), Color(0.6, 0.8, 1.0), 0.8)
			await _wait(0.6)
			_hide_banner()
		"flee":
			_show_banner("The party tries to flee...")
			await _wait(0.6)
			if randf() < 0.7:
				Audio.play_sfx(&"cancel")
				_fled = true
			else:
				_show_banner("Couldn't escape!")
				Audio.play_sfx(&"buzz")
				await _wait(0.7)
			_hide_banner()
		"attack":
			await _do_skill(a, preload("res://data/skills/attack.tres"), _retarget(a, targets, true))
		"skill":
			var s: SkillData = action.skill
			if a.is_hero:
				a.mp -= s.mp_cost
			var tt := targets
			if s.target == SkillData.Target.ENEMY or s.target == SkillData.Target.ALLY:
				tt = _retarget(a, targets, s.target == SkillData.Target.ENEMY)
			elif s.target == SkillData.Target.ALL_ENEMIES:
				tt = _alive(foes) if a.is_hero else _alive(heroes)
			await _do_skill(a, s, tt)
		"item":
			await _do_item(action.item, targets)


## If a single target died before the action resolved, pick another one.
func _retarget(a: Battler, targets: Array, hostile: bool) -> Array:
	if not targets.is_empty() and targets[0].alive():
		return targets
	var side := (foes if a.is_hero else heroes) if hostile else (heroes if a.is_hero else foes)
	var alive := _alive(side)
	return [alive.pick_random()] if not alive.is_empty() else []


func _do_skill(a: Battler, s: SkillData, targets: Array) -> void:
	if targets.is_empty() and s.target != SkillData.Target.SELF:
		return
	var col := s.color()
	if s.resource_path.get_file() != "attack.tres":
		_show_banner(s.display_name, col.lerp(Color.WHITE, 0.4))
	match s.kind:
		SkillData.Kind.PHYSICAL:
			await _physical(a, s, targets)
		SkillData.Kind.MAGIC:
			await _cast_anim(a, col)
			await _magic_fx(s, targets)
			for t in targets:
				_apply_damage(a, t, s)
			if s.drain:
				await _wait(0.3)
		SkillData.Kind.HEAL:
			await _cast_anim(a, col)
			Audio.play_sfx(&"heal")
			for t in targets:
				_spawn(rise_fx, t.view.global_position, col)
				var amt := int(Game.heal_amount(a.stat("mag"), s) * randf_range(0.95, 1.05))
				t.hp += amt
				_popup(t, str(amt), Color(0.5, 1.0, 0.6))
		SkillData.Kind.REVIVE:
			await _cast_anim(a, col)
			Audio.play_sfx(&"heal")
			for t in targets:
				if not t.alive():
					t.hp = maxi(1, int(t.max_hp() * s.power))
					_show_ko(t, false)
					_spawn(rise_fx, t.view.global_position, Color(1.0, 0.95, 0.6))
					_popup(t, "Revived!", Color(1.0, 0.95, 0.6))
		SkillData.Kind.BUFF:
			await _cast_anim(a, col)
			Audio.play_sfx(&"buff")
			for t in targets:
				for mod in s.buffs:
					t.add_modifier(mod, 1 if t == a else 0)
				_spawn(rise_fx, t.view.global_position, col)
				_popup(t, "%s Up" % HeroData.STAT_NAMES[s.buffs[0].stat], col)
		SkillData.Kind.PROVOKE:
			Audio.play_sfx(&"buff")
			a.provoke = 4
			for mod in s.buffs:
				a.add_modifier(mod)
			_spawn(rise_fx, a.view.global_position, Color(1.0, 0.4, 0.3))
			_popup(a, "Taunt!", Color(1.0, 0.5, 0.4))
		SkillData.Kind.DEBUFF:
			await _cast_anim(a, col)
			Audio.play_sfx(&"dark")
			for t in targets:
				t.add_modifier(s.debuff)
				_spawn(implode_fx, t.view.global_position + Vector3(0, 1.2, 0), col)
				_popup(t, "%s Down" % HeroData.STAT_NAMES[s.debuff.stat], Color(0.8, 0.5, 1.0))
		SkillData.Kind.CHARGE:
			Audio.play_sfx(&"dark")
			_shake = 0.4
			_spawn(implode_fx, a.view.global_position + Vector3(0, 2.5, 0), col, 3.0)
			_show_banner("Malzeth gathers the darkness of the abyss...", Color(0.85, 0.5, 1.0))
	await _wait(0.75)
	_hide_banner()
	_refresh_party()


func _physical(a: Battler, s: SkillData, targets: Array) -> void:
	var col := s.color()
	var dir := -1.0 if a.is_hero else 1.0
	var dest: Vector3 = targets[0].view.global_position + Vector3(-dir * 1.3, 0, 0.05) if targets.size() == 1 else Vector3(0, 0, -0.1)
	if a.is_boss:
		dest = a.home + Vector3(1.0, 0, 0)
	if s.element != SkillData.Element.NONE:
		a.view.set_tint(col.lerp(Color.WHITE, 0.3) * 1.8)
	a.view.play_once(&"attack")
	var tw := create_tween()
	tw.tween_property(a.view, "global_position", dest, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_cam_push = Vector3(dir * -0.3, -0.1, -0.6)
	await tw.finished
	for t in targets:
		_spawn(slash_fx, t.view.global_position + Vector3(0, 1.3, 0.4), col)
		if s.element != SkillData.Element.NONE:
			_spawn(burst_fx, t.view.global_position + Vector3(0, 1.2, 0), col, 1.2)
		_apply_damage(a, t, s)
	await _wait(0.3)
	a.view.set_tint(_base_tint(a))
	var back := create_tween()
	back.tween_property(a.view, "global_position", a.home, 0.25).set_trans(Tween.TRANS_QUAD)
	_cam_push = Vector3.ZERO
	await back.finished


func _cast_anim(a: Battler, col: Color) -> void:
	Audio.play_sfx(&"magic")
	a.view.play_once(&"cast")
	_spawn(cast_circle_fx, a.view.global_position + Vector3(0, 0.06, 0), col)
	_spawn(rise_fx, a.view.global_position, col, 0.7)
	var tw := create_tween()
	tw.tween_property(a.view.sprite(), "modulate", col.lerp(Color.WHITE, 0.5) * 2.2, 0.25)
	tw.tween_property(a.view.sprite(), "modulate", _base_tint(a), 0.25)
	await tw.finished


func _base_tint(b: Battler) -> Color:
	return Color(1.3, 0.75, 1.3) if b.is_boss and b.phase >= 2 else Color.WHITE


# --------------------------------------------------------------- Damage ---
func _apply_damage(a: Battler, t: Battler, s: SkillData) -> void:
	if not t.alive():
		return
	var phys := s.is_physical()
	var atk := a.stat("atk" if phys else "mag")
	var def := t.stat("def" if phys else "mdf")
	var dmg := s.power * 2.5 * atk * atk / (atk + def) * randf_range(0.92, 1.08)
	var crit := phys and randf() < 0.08
	if crit:
		dmg *= 1.6
	var weak := t.is_weak_to(s.element)
	var resist := t.resists(s.element)
	if weak:
		dmg *= 1.5
	if resist:
		dmg *= 0.5
	if t.defending:
		dmg *= 0.5
	var amount := maxi(1, int(dmg))
	t.hp -= amount
	if s.debuff and t.alive() and phys:
		t.add_modifier(s.debuff)
	if s.drain:
		a.hp += amount / 2
		_popup(a, str(amount / 2), Color(0.5, 1.0, 0.6))
	Audio.play_sfx(&"crit" if crit else (&"slash" if phys else &"hit"))
	_hit_flash(t)
	_shake = maxf(_shake, 0.35 if crit or weak else 0.18)
	var col := Color.WHITE
	if crit:
		col = Color(1.0, 0.9, 0.3)
	elif weak:
		col = Color(1.0, 0.65, 0.25)
	elif t.is_hero:
		col = Color(1.0, 0.75, 0.75)
	_popup(t, str(amount), col, 1.35 if crit else 1.0)
	if crit:
		_popup(t, "CRITICAL", Color(1.0, 0.9, 0.3), 0.6, 0.6)
	elif weak:
		_popup(t, "WEAK!", Color(1.0, 0.6, 0.2), 0.6, 0.6)
	elif resist:
		_popup(t, "Resist", Color(0.7, 0.7, 0.8), 0.6, 0.6)
	if not t.alive():
		_on_down(t)


func _on_down(t: Battler) -> void:
	t.buffs.clear()
	t.provoke = 0
	Audio.play_sfx(&"death")
	if t.is_hero:
		_show_ko(t, true)
		return
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(t.view.sprite(), "modulate", Color(2.0, 0.4, 2.5, 1.0), 0.15)
	tw.tween_property(t.view.sprite(), "modulate", Color(0.6, 0.1, 0.8, 0.0), 0.6)
	tw.parallel().tween_property(t.view.sprite(), "scale", Vector3(1.3, 0.2, 1.0), 0.6)
	tw.tween_callback(t.view.hide)
	_spawn(burst_fx, t.view.global_position + Vector3(0, 1.0, 0), Color(0.6, 0.2, 1.0), 1.6)


func _show_ko(b: Battler, ko: bool) -> void:
	b.view.play(&"ko" if ko else &"idle")
	b.view.set_tint(KO_TINT if ko else Color.WHITE)


func _hit_flash(t: Battler) -> void:
	var orig := KO_TINT if not t.alive() and t.is_hero else _base_tint(t)
	if t.alive():
		t.view.play_once(&"hurt")
	t.view.set_tint(Color(4.0, 4.0, 4.0))
	var k := 1.0 if t.is_hero else -1.0
	var tw := create_tween()
	tw.tween_property(t.view, "global_position", t.home + Vector3(k * 0.25, 0, 0), 0.06)
	tw.tween_property(t.view.sprite(), "modulate", orig, 0.15)
	tw.parallel().tween_property(t.view, "global_position", t.home, 0.2)


func _popup(t: Battler, text: String, color: Color, text_scale := 1.0, height_offset := 0.0) -> void:
	var p: DamagePopup = damage_popup.instantiate()
	p.text = text
	p.color = color
	p.text_scale = text_scale
	%Effects.add_child(p)
	p.global_position = t.view.global_position + Vector3(randf_range(-0.2, 0.2), t.view.height() * 0.7 + height_offset, 0.5)


# ------------------------------------------------------------------ Items ---
func _do_item(item: ItemData, targets: Array) -> void:
	Game.remove_item(item)
	_show_banner(item.display_name, Color(0.6, 0.9, 1.0))
	Audio.play_sfx(&"heal")
	if item.target == SkillData.Target.ALL_ALLIES:
		targets = _alive(heroes)
	for t in targets:
		match item.kind:
			ItemData.Kind.HEAL, ItemData.Kind.HEAL_PARTY:
				if t.alive():
					t.hp += int(item.amount)
					_popup(t, str(int(item.amount)), Color(0.5, 1.0, 0.6))
			ItemData.Kind.RESTORE_MP:
				if t.alive():
					t.mp += int(item.amount)
					_popup(t, str(int(item.amount)), Color(0.5, 0.75, 1.0))
			ItemData.Kind.FULL_RESTORE:
				if t.alive():
					t.hp = t.max_hp()
					t.mp = t.max_mp()
					_popup(t, "Full Restore", Color(0.5, 1.0, 0.6))
			ItemData.Kind.REVIVE:
				if not t.alive():
					t.hp = maxi(1, int(t.max_hp() * item.amount))
					_show_ko(t, false)
					_popup(t, "Revived!", Color(1.0, 0.95, 0.6))
		_spawn(rise_fx, t.view.global_position, Color(0.5, 1.0, 0.7))
	await _wait(0.9)
	_hide_banner()


# ---------------------------------------------------------------- Effects ---
## Element-specific spell visuals.
func _magic_fx(s: SkillData, targets: Array) -> void:
	var col := s.color()
	match s.element:
		SkillData.Element.THUNDER:
			for t in targets:
				_spawn(bolt_fx, t.view.global_position)
				_spawn(burst_fx, t.view.global_position + Vector3(0, 0.4, 0), col, 1.2)
			Audio.play_sfx(&"crit")
			_shake = 0.3
			await _wait(0.25)
		SkillData.Element.HOLY:
			for t in targets:
				_spawn(holy_pillar_fx, t.view.global_position, col)
			await _wait(0.5)
			for t in targets:
				_spawn(burst_fx, t.view.global_position + Vector3(0, 1.4, 0), col, 1.6)
		SkillData.Element.DARK:
			for t in targets:
				_spawn(implode_fx, t.view.global_position + Vector3(0, 1.2, 0), col)
			Audio.play_sfx(&"dark")
			await _wait(0.55)
			for t in targets:
				_spawn(burst_fx, t.view.global_position + Vector3(0, 1.2, 0), col, 1.2)
			if s.power >= 1.8:
				_shake = 1.0
		SkillData.Element.ICE:
			for t in targets:
				_spawn(ice_shards_fx, t.view.global_position, col)
			await _wait(0.4)
			for t in targets:
				_spawn(burst_fx, t.view.global_position + Vector3(0, 1.2, 0), col)
		SkillData.Element.FIRE:
			for t in targets:
				_spawn(flames_fx, t.view.global_position + Vector3(0, 0.1, 0.2), col)
				_spawn(flash_light, t.view.global_position + Vector3(0, 1.2, 0.5), col)
			_shake = 0.25
			await _wait(0.35)
			for t in targets:
				_spawn(burst_fx, t.view.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.8, 0.3), 1.2)
		_:
			if targets.size() > 1 and s.power >= 1.5:
				await _meteors(targets)
			else:
				for t in targets:
					_spawn(burst_fx, t.view.global_position + Vector3(0, 1.2, 0), col, 1.2)
				await _wait(0.3)


func _meteors(targets: Array) -> void:
	for t in targets:
		for k in 3:
			var dest: Vector3 = t.view.global_position + Vector3(randf_range(-0.6, 0.6), 0.6, randf_range(-0.4, 0.4))
			var delay := k * 0.15 + randf() * 0.1
			get_tree().create_timer(delay).timeout.connect(func():
				_spawn(meteor_fx, dest)
				get_tree().create_timer(0.35).timeout.connect(func():
					_spawn(burst_fx, dest, Color(1.0, 0.55, 0.2), 1.3)
					_shake = 0.4
					Audio.play_sfx(&"hit")))
	await _wait(0.9)


# ------------------------------------------------------------------- End ---
func _victory() -> void:
	await _wait(0.6)
	_update_strip([])
	if boss:
		finished.emit("win")
		return
	Audio.play_music(&"victory")
	for h in _alive(heroes):
		var tw := create_tween()
		tw.tween_property(h.view, "position:y", 0.6, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(h.view, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_show_banner("VICTORY!", GOLD)
	var total_exp := 0
	var gold := 0
	for f in foes:
		total_exp += f.enemy.exp_reward
		gold += f.enemy.gold_reward
	Game.gold += gold
	var text := "[center][color=#ffd36a]Victory![/color][/center]\n\nGained [b]%d EXP[/b] and [b]%d Gold[/b].\n" % [total_exp, gold]
	var leveled := false
	for h in heroes:
		for msg in Game.gain_exp(h.member, total_exp):
			text += "\n[color=#9fe3ff]%s[/color]" % msg
			leveled = true
	%ResultText.text = text
	%ResultPanel.show()
	if leveled:
		Audio.play_sfx(&"levelup")
	_refresh_party()
	await _wait(0.5)
	if not auto_battle:
		_targeting = true
		while true:
			var a: String = await _nav
			if a == "accept" or a == "cancel":
				break
		_targeting = false
	finished.emit("win")


func _end_flee() -> void:
	for h in _alive(heroes):
		create_tween().tween_property(h.view, "global_position:x", h.home.x + 8.0, 0.5)
	await _wait(0.6)
	finished.emit("flee")
