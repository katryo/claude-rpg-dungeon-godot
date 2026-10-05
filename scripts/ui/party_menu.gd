class_name PartyMenu
extends CanvasLayer
## The classic JRPG party menu: Items, Skills, Equipment, Status.

signal _nav(action: String)

const GOLD := Color(1.0, 0.84, 0.45)
const DIM := Color(0.7, 0.72, 0.85)
const TEXT := Color(0.95, 0.93, 0.88)
const UP := Color(0.45, 1.0, 0.55)
const DOWN := Color(1.0, 0.45, 0.45)
const COMMAND_HELP := [
	"Use items from the party's inventory.",
	"View and use skills.",
	"Change weapons and armor.",
	"View a member's detailed parameters.",
	"Close the menu.",
]

var _nav_active := false
var _card_index := 0

@onready var _commands: SelectList = %CommandList
@onready var _help: Label = %HelpLabel
@onready var _gold: Label = %GoldLabel
@onready var _time: Label = %TimeLabel
@onready var _views: Array[Control] = [%PartyView, %StatusView, %EquipView, %SkillsView, %ItemsView]
@onready var _cards: Array = %PartyView.get_children()
@onready var _target_popup: Control = %TargetPopup
@onready var _target_list: SelectList = %TargetList


func _ready() -> void:
	hide()
	_target_popup.hide()
	_commands.set_items([
		{"text": "Items"}, {"text": "Skills"}, {"text": "Equipment"}, {"text": "Status"}, {"text": "Close"},
	])
	_commands.moved.connect(func(i: int): _help.text = COMMAND_HELP[i])
	for i in _cards.size():
		_cards[i].clicked.connect(_on_card_clicked.bind(i))
		_cards[i].hovered.connect(_on_card_hovered.bind(i))


func _process(_delta: float) -> void:
	if visible:
		_time.text = Game.format_time()


func _show_view(v: Control) -> void:
	for view in _views:
		view.visible = view == v


func open() -> void:
	show()
	UI.menu_open = true
	_gold.text = "%d G" % Game.gold
	_commands.index = 0
	_show_party()
	while true:
		_help.text = COMMAND_HELP[_commands.index]
		var c := await _commands.choose()
		match c:
			0:
				await _items_flow()
			1:
				var m := await _pick_member("Whose skills?")
				if m >= 0:
					await _skills_flow(Game.party[m])
			2:
				var m := await _pick_member("Whose equipment?")
				if m >= 0:
					await _equip_flow(Game.party[m])
			3:
				var m := await _pick_member("Whose status?")
				if m >= 0:
					await _status_flow(m)
			_:
				break
		_show_party()
	hide()
	await get_tree().process_frame
	UI.menu_open = false


# ---------------------------------------------------------- Party cards ---
func _show_party() -> void:
	_show_view(%PartyView)
	for i in _cards.size():
		_cards[i].visible = i < Game.party.size()
		if i < Game.party.size():
			_cards[i].show_member(Game.party[i])
	_highlight_card(-1)


func _highlight_card(idx: int) -> void:
	for i in _cards.size():
		_cards[i].set_selected(i == idx)


func _pick_member(prompt: String) -> int:
	_help.text = prompt
	_card_index = clampi(_card_index, 0, Game.party.size() - 1)
	_highlight_card(_card_index)
	while true:
		var a := await _wait_nav()
		match a:
			"up", "down":
				_card_index = wrapi(_card_index + (1 if a == "down" else -1), 0, Game.party.size())
				Audio.play_sfx(&"cursor")
				_highlight_card(_card_index)
			"accept":
				Audio.play_sfx(&"confirm")
				_highlight_card(-1)
				return _card_index
			"cancel":
				Audio.play_sfx(&"cancel")
				_highlight_card(-1)
				return -1
	return -1


func _on_card_clicked(i: int) -> void:
	if _nav_active:
		_card_index = i
		_highlight_card(i)
		_nav.emit("accept")


func _on_card_hovered(i: int) -> void:
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
	elif event.is_action_pressed("ui_cancel"):
		a = "cancel"
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		a = "cancel"
	if a != "":
		get_viewport().set_input_as_handled()
		_nav.emit(a)


# ---------------------------------------------------------------- Status ---
func _status_flow(idx: int) -> void:
	_show_view(%StatusView)
	while true:
		_show_status(Game.party[idx])
		_help.text = "◀ ▶ switch member    Cancel: back"
		var a := await _wait_nav()
		match a:
			"left", "up":
				idx = wrapi(idx - 1, 0, Game.party.size())
				Audio.play_sfx(&"cursor")
			"right", "down":
				idx = wrapi(idx + 1, 0, Game.party.size())
				Audio.play_sfx(&"cursor")
			_:
				Audio.play_sfx(&"cancel")
				return


func _show_status(m: PartyMember) -> void:
	%StatusSprite.texture = m.hero.sprite_frames.get_frame_texture(&"idle", 0)
	%StatusName.text = m.display_name
	%StatusJob.text = m.hero.job
	%StatusBio.text = m.hero.bio
	var stats: GridContainer = %StatusStats
	_clear(stats)
	_pair(stats, "Level", str(m.level), GOLD)
	_pair(stats, "EXP", str(m.experience))
	_pair(stats, "Next Level", str(Game.exp_to_next(m)))
	_pair(stats, "HP", "%d / %d" % [m.hp, m.max_hp()])
	_pair(stats, "MP", "%d / %d" % [m.mp, m.max_mp()])
	for k in ["atk", "def", "mag", "mdf", "spd"]:
		var b := m.equip_bonus(k)
		_pair(stats, HeroData.STAT_NAMES[k], "%d%s" % [m.stat(k), "  (+%d)" % b if b > 0 else ""])
	var equip: GridContainer = %StatusEquipment
	_clear(equip)
	for slot in EquipmentData.Slot.values():
		var e := m.get_equipment(slot)
		_pair(equip, EquipmentData.SLOT_NAMES[slot], e.display_name if e else "—", DIM, 15)
	var skills: GridContainer = %StatusSkills
	_clear(skills)
	for s in m.skills:
		_pair(skills, s.display_name, "%d MP" % s.mp_cost, DIM, 15)


func _clear(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()


func _pair(grid: GridContainer, k: String, v: String, kc: Color = GOLD, font_size := 18) -> void:
	var a := Label.new()
	a.text = k
	a.add_theme_color_override("font_color", kc)
	a.add_theme_font_size_override("font_size", font_size)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(a)
	var b := Label.new()
	b.text = v
	b.add_theme_font_size_override("font_size", font_size)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(b)


# ------------------------------------------------------------- Equipment ---
func _equip_flow(m: PartyMember) -> void:
	_show_view(%EquipView)
	%EquipPortrait.texture = m.hero.portrait
	%EquipName.text = "%s  —  %s" % [m.display_name, m.hero.job]
	var slot_list: SelectList = %SlotList
	var cand_list: SelectList = %CandidateList
	_refresh_slots(m, slot_list)
	while true:
		_help.text = "Choose a slot to change."
		cand_list.set_items([])
		_show_compare(m, -1, null)
		var si := await slot_list.choose()
		if si < 0:
			return
		var slot := si as EquipmentData.Slot
		var cands: Array = Game.equip_candidates(m, slot)
		var items: Array = cands.map(func(e: EquipmentData): return {"text": e.display_name, "right": "x%d" % Game.equip_bag[e]})
		if m.get_equipment(slot) and slot != EquipmentData.Slot.WEAPON:
			cands.append(null)
			items.append({"text": "(Remove)", "color": DIM})
		if cands.is_empty():
			Audio.play_sfx(&"buzz")
			_help.text = "Nothing else can be equipped in this slot."
			await get_tree().create_timer(0.8).timeout
			continue
		cand_list.set_items(items)
		var on_move := func(i: int):
			var e: EquipmentData = cands[i]
			_show_compare(m, slot, e)
			_help.text = e.description if e else "Remove the equipped item."
		cand_list.moved.connect(on_move)
		on_move.call(0)
		var ci := await cand_list.choose()
		cand_list.moved.disconnect(on_move)
		if ci >= 0:
			Game.equip(m, slot, cands[ci])
			_refresh_slots(m, slot_list)


func _refresh_slots(m: PartyMember, list: SelectList) -> void:
	var items: Array = []
	for slot in EquipmentData.Slot.values():
		var e := m.get_equipment(slot)
		items.append({"text": EquipmentData.SLOT_NAMES[slot], "right": e.display_name if e else "—"})
	list.set_items(items, true)


func _show_compare(m: PartyMember, slot: int, e: EquipmentData) -> void:
	var grid: GridContainer = %CompareGrid
	_clear(grid)
	var preview := {} if slot < 0 else Game.preview_stats(m, slot, e)
	for k in HeroData.STAT_KEYS:
		var a := Label.new()
		a.text = HeroData.STAT_NAMES[k]
		a.add_theme_color_override("font_color", DIM)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(a)
		var cur := m.stat(k)
		var b := Label.new()
		b.text = str(cur)
		b.custom_minimum_size = Vector2(60, 0)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(b)
		var arrow := Label.new()
		arrow.custom_minimum_size = Vector2(90, 0)
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if not preview.is_empty():
			var nv: int = preview[k]
			arrow.text = "→ %d" % nv
			if nv != cur:
				arrow.add_theme_color_override("font_color", UP if nv > cur else DOWN)
		grid.add_child(arrow)


# ---------------------------------------------------------------- Skills ---
func _skills_flow(m: PartyMember) -> void:
	_show_view(%SkillsView)
	var list: SelectList = %SkillList
	list.index = 0
	while true:
		%SkillsHeader.text = "%s's Skills      MP %d / %d" % [m.display_name, m.mp, m.max_mp()]
		list.set_items(m.skills.map(func(s: SkillData): return {
			"text": s.display_name, "right": "%d MP" % s.mp_cost,
			"enabled": s.usable_in_field and m.mp >= s.mp_cost and m.is_alive()}), true)
		var on_move := func(i: int):
			var s: SkillData = m.skills[i]
			_help.text = s.description + ("" if s.usable_in_field else "   (Battle only)")
		list.moved.connect(on_move)
		on_move.call(list.index)
		var si := await list.choose()
		list.moved.disconnect(on_move)
		if si < 0:
			return
		var skill: SkillData = m.skills[si]
		var targets: Array[PartyMember] = []
		if skill.target == SkillData.Target.ALL_ALLIES:
			targets.assign(Game.party.filter(func(x: PartyMember): return x.is_alive()))
		else:
			var t := await _pick_target(skill.target == SkillData.Target.DEAD_ALLY)
			if t < 0:
				continue
			targets = [Game.party[t]]
		m.mp -= skill.mp_cost
		for t in targets:
			if skill.kind == SkillData.Kind.HEAL:
				t.hp = mini(t.max_hp(), t.hp + Game.heal_amount(m.stat("mag"), skill))
			elif skill.kind == SkillData.Kind.REVIVE:
				t.hp = maxi(1, int(t.max_hp() * skill.power))
		Audio.play_sfx(&"heal")


# ----------------------------------------------------------------- Items ---
func _items_flow() -> void:
	_show_view(%ItemsView)
	var list: SelectList = %ItemList
	list.index = 0
	while true:
		var ids := Game.item_list()
		if ids.is_empty():
			_help.text = "You have no items."
			list.set_items([{"text": "(empty)", "enabled": false}])
			await get_tree().create_timer(0.6).timeout
			return
		list.set_items(ids.map(func(it: ItemData): return {"text": it.display_name, "right": "x%d" % Game.inventory[it]}), true)
		var on_move := func(i: int): _help.text = ids[i].description
		list.moved.connect(on_move)
		on_move.call(list.index)
		var ii := await list.choose()
		list.moved.disconnect(on_move)
		if ii < 0:
			return
		var item := ids[ii]
		if item.target == SkillData.Target.ALL_ALLIES:
			var used := false
			for m in Game.party:
				used = Game.use_item_on(item, m) or used
			if used:
				Game.remove_item(item)
				Audio.play_sfx(&"heal")
			else:
				Audio.play_sfx(&"buzz")
			continue
		var t := await _pick_target(item.target == SkillData.Target.DEAD_ALLY)
		if t < 0:
			continue
		if Game.use_item_on(item, Game.party[t]):
			Game.remove_item(item)
			Audio.play_sfx(&"heal")
		else:
			Audio.play_sfx(&"buzz")


## Member picker popup. Returns a party index or -1.
func _pick_target(dead_only: bool) -> int:
	_target_list.set_items(Game.party.map(func(m: PartyMember): return {
		"text": m.display_name,
		"right": "HP %d/%d  MP %d/%d" % [m.hp, m.max_hp(), m.mp, m.max_mp()],
		"enabled": (not m.is_alive()) if dead_only else m.is_alive(),
	}))
	_target_popup.show()
	var r := await _target_list.choose()
	_target_popup.hide()
	return r
