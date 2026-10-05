class_name DialogueBox
extends Control
## Bottom-of-screen message window with a typewriter effect.

signal _advance

var is_open := false
var _typing := false
var _tween: Tween

@onready var _panel: PanelContainer = %Panel
@onready var _portrait: TextureRect = %Portrait
@onready var _name: Label = %NameLabel
@onready var _text: RichTextLabel = %Text
@onready var _arrow: Label = %Arrow


func _ready() -> void:
	_panel.hide()
	_arrow.hide()


## Each line is [speaker, text] or [speaker, text, portrait_texture].
func say(lines: Array) -> void:
	is_open = true
	_panel.show()
	for line in lines:
		var speaker: String = line[0]
		_name.text = speaker
		_name.visible = speaker != ""
		var portrait: Texture2D = line[2] if line.size() > 2 else null
		_portrait.texture = portrait
		_portrait.visible = portrait != null
		_text.text = line[1]
		_text.visible_ratio = 0.0
		_typing = true
		_arrow.hide()
		_tween = create_tween()
		_tween.tween_property(_text, "visible_ratio", 1.0, maxf(0.15, _text.get_total_character_count() * 0.022))
		_tween.finished.connect(_on_typed)
		await _advance
	_panel.hide()
	_arrow.hide()
	# Let the closing key press finish before the world reacts to input again.
	await get_tree().process_frame
	is_open = false


func _on_typed() -> void:
	_typing = false
	_arrow.show()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not _panel.visible:
		return
	var pressed := event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_tween.kill()
		_text.visible_ratio = 1.0
		_on_typed()
	else:
		Audio.play_sfx(&"cursor")
		_advance.emit()
