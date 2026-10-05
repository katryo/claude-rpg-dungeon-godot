class_name PartyCard
extends PanelContainer
## One hero's summary card in the party menu.

signal clicked
signal hovered

const KO_TINT := Color(0.5, 0.3, 0.3)

@onready var _cursor: Label = %Cursor
@onready var _portrait: TextureRect = %Portrait
@onready var _name: Label = %NameLabel
@onready var _job: Label = %JobLabel
@onready var _level: Label = %LevelLabel
@onready var _ko: Label = %KOLabel
@onready var _hp: Label = %HPValue
@onready var _hp_bar: StatBar = %HPBar
@onready var _mp: Label = %MPValue
@onready var _mp_bar: StatBar = %MPBar
@onready var _exp: Label = %EXPValue
@onready var _exp_bar: StatBar = %EXPBar


func _ready() -> void:
	gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit())
	mouse_entered.connect(hovered.emit)
	set_selected(false)


func show_member(m: PartyMember) -> void:
	_portrait.texture = m.hero.portrait
	_portrait.modulate = Color.WHITE if m.is_alive() else KO_TINT
	_name.text = m.display_name
	_job.text = m.hero.job
	_level.text = "LV %d" % m.level
	_ko.visible = not m.is_alive()
	_hp.text = "%d / %d" % [m.hp, m.max_hp()]
	_hp_bar.max_value = m.max_hp()
	_hp_bar.value = m.hp
	_mp.text = "%d / %d" % [m.mp, m.max_mp()]
	_mp_bar.max_value = m.max_mp()
	_mp_bar.value = m.mp
	var floor_exp := Game.exp_for_level(m.level)
	_exp.text = "Next %d" % Game.exp_to_next(m)
	_exp_bar.max_value = Game.exp_for_level(m.level + 1) - floor_exp
	_exp_bar.value = m.experience - floor_exp


func set_selected(on: bool) -> void:
	theme_type_variation = &"CardPanelSelected" if on else &"CardPanel"
	_cursor.text = "▶" if on else ""
