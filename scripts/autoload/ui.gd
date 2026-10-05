extends Node
## Global UI services: theme, dialogue window, screen transitions, vignette overlay.

const PixelArt := preload("res://scripts/gfx/pixel_art.gd")

signal _advance

var theme: Theme
var menu_open := false
var dialogue_open := false
var transitioning := false

var _vignette_layer: CanvasLayer
var _dialog_layer: CanvasLayer
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _fade_mat: ShaderMaterial
var _dialog_panel: PanelContainer
var _dialog_name: Label
var _dialog_text: RichTextLabel
var _dialog_portrait: TextureRect
var _dialog_arrow: Label
var _typing := false
var _type_tween: Tween
var _toast_layer: CanvasLayer
var _toast: PanelContainer
var _toast_label: Label

const FADE_SHADER := """
shader_type canvas_item;
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float wipe : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
void fragment() {
	vec2 cell = FRAGCOORD.xy / 48.0;
	vec2 f = abs(fract(cell) - 0.5);
	float d = f.x + f.y;
	float w = wipe * 2.2 - (SCREEN_UV.x + SCREEN_UV.y) * 0.6;
	float a = max(fade, step(d, w));
	COLOR = vec4(tint.rgb, a * tint.a);
}
"""

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float strength = 0.6;
void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= 1.25;
	float v = smoothstep(0.32, 0.9, length(uv));
	COLOR = vec4(0.02, 0.0, 0.05, v * strength);
}
"""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = _build_theme()
	_build_vignette()
	_build_dialogue()
	_build_fade()
	_build_toast()


func busy() -> bool:
	return menu_open or dialogue_open or transitioning


# ------------------------------------------------------------------ Theme ---
func panel_style(alpha: float = 0.92) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.17, alpha)
	sb.border_color = Color(0.86, 0.74, 0.42)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	sb.set_content_margin_all(14)
	return sb


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("panel", "Panel", panel_style())
	t.set_color("font_color", "Label", Color(0.95, 0.93, 0.88))
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.75))
	t.set_constant("shadow_offset_x", "Label", 2)
	t.set_constant("shadow_offset_y", "Label", 2)
	t.set_color("default_color", "RichTextLabel", Color(0.95, 0.93, 0.88))
	t.set_color("font_shadow_color", "RichTextLabel", Color(0, 0, 0, 0.75))
	t.set_constant("shadow_offset_x", "RichTextLabel", 2)
	t.set_constant("shadow_offset_y", "RichTextLabel", 2)
	t.set_font_size("normal_font_size", "RichTextLabel", 22)
	t.set_font_size("bold_font_size", "RichTextLabel", 22)
	return t


# -------------------------------------------------------------- Vignette ---
func _build_vignette() -> void:
	_vignette_layer = CanvasLayer.new()
	_vignette_layer.layer = 1
	add_child(_vignette_layer)
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = VIGNETTE_SHADER
	mat.shader = sh
	r.material = mat
	_vignette_layer.add_child(r)


func set_vignette(on: bool) -> void:
	_vignette_layer.visible = on


# -------------------------------------------------------------- Dialogue ---
func _build_dialogue() -> void:
	_dialog_layer = CanvasLayer.new()
	_dialog_layer.layer = 50
	add_child(_dialog_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	_dialog_layer.add_child(root)

	_dialog_panel = PanelContainer.new()
	_dialog_panel.anchor_left = 0.0
	_dialog_panel.anchor_right = 1.0
	_dialog_panel.anchor_top = 1.0
	_dialog_panel.anchor_bottom = 1.0
	_dialog_panel.offset_left = 80
	_dialog_panel.offset_right = -80
	_dialog_panel.offset_top = -200
	_dialog_panel.offset_bottom = -28
	root.add_child(_dialog_panel)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	_dialog_panel.add_child(h)

	_dialog_portrait = TextureRect.new()
	_dialog_portrait.custom_minimum_size = Vector2(120, 120)
	_dialog_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_dialog_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_dialog_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(_dialog_portrait)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_dialog_name = Label.new()
	_dialog_name.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
	v.add_child(_dialog_name)
	_dialog_text = RichTextLabel.new()
	_dialog_text.bbcode_enabled = true
	_dialog_text.fit_content = true
	_dialog_text.scroll_active = false
	_dialog_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialog_text.custom_minimum_size = Vector2(600, 90)
	v.add_child(_dialog_text)

	_dialog_arrow = Label.new()
	_dialog_arrow.text = "▼"
	_dialog_arrow.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
	_dialog_arrow.anchor_left = 1.0
	_dialog_arrow.anchor_right = 1.0
	_dialog_arrow.anchor_top = 1.0
	_dialog_arrow.anchor_bottom = 1.0
	_dialog_arrow.offset_left = -112
	_dialog_arrow.offset_top = -64
	root.add_child(_dialog_arrow)
	_dialog_panel.visible = false
	_dialog_arrow.visible = false


## Shows a sequence of lines. Each line is [speaker, text] or [speaker, text, portrait_sprite].
func say(lines: Array) -> void:
	dialogue_open = true
	_dialog_panel.visible = true
	for line in lines:
		var speaker: String = line[0]
		_dialog_name.text = speaker
		_dialog_name.visible = speaker != ""
		var por := ""
		if line.size() > 2:
			por = line[2]
		_dialog_portrait.visible = por != ""
		if por != "":
			_dialog_portrait.texture = PixelArt.portrait(por) if por in ["arlen", "garrick", "theia"] else PixelArt.sprite(por)
		_dialog_text.text = line[1]
		_dialog_text.visible_ratio = 0.0
		_typing = true
		_dialog_arrow.visible = false
		var chars := _dialog_text.get_total_character_count()
		_type_tween = create_tween()
		_type_tween.tween_property(_dialog_text, "visible_ratio", 1.0, maxf(0.15, chars * 0.022))
		_type_tween.finished.connect(_on_type_done)
		await _advance
	_dialog_panel.visible = false
	_dialog_arrow.visible = false
	# Let the closing key press finish before the world reacts to input again.
	await get_tree().process_frame
	dialogue_open = false


func _on_type_done() -> void:
	_typing = false
	_dialog_arrow.visible = true


func _process(_delta: float) -> void:
	if _dialog_arrow.visible:
		_dialog_arrow.modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)


func _unhandled_input(event: InputEvent) -> void:
	if not dialogue_open or not _dialog_panel.visible:
		return
	var pressed := event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if _typing:
		_type_tween.kill()
		_dialog_text.visible_ratio = 1.0
		_on_type_done()
	else:
		Sfx.play("cursor")
		_advance.emit()


# ----------------------------------------------------------- Transitions ---
func _build_fade() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = FADE_SHADER
	_fade_mat.shader = sh
	_fade_rect.material = _fade_mat
	_fade_layer.add_child(_fade_rect)


func _set_fade(v: float) -> void:
	_fade_mat.set_shader_parameter("fade", v)


func _set_wipe(v: float) -> void:
	_fade_mat.set_shader_parameter("wipe", v)


func fade_out(t: float = 0.5, color: Color = Color.BLACK) -> void:
	transitioning = true
	_fade_mat.set_shader_parameter("tint", color)
	var tw := create_tween()
	tw.tween_method(_set_fade, 0.0, 1.0, t)
	await tw.finished


func fade_in(t: float = 0.5) -> void:
	_set_wipe(0.0)
	var tw := create_tween()
	tw.tween_method(_set_fade, 1.0, 0.0, t)
	await tw.finished
	transitioning = false


## Classic JRPG encounter transition: two white flashes then a diamond wipe.
func battle_transition() -> void:
	transitioning = true
	Sfx.play("encounter")
	for i in 2:
		_fade_mat.set_shader_parameter("tint", Color(1, 1, 1, 0.85))
		var tw := create_tween()
		tw.tween_method(_set_fade, 0.0, 1.0, 0.08)
		tw.tween_method(_set_fade, 1.0, 0.0, 0.12)
		await tw.finished
	_fade_mat.set_shader_parameter("tint", Color.BLACK)
	var tw2 := create_tween()
	tw2.tween_method(_set_wipe, 0.0, 1.0, 0.6)
	await tw2.finished
	_set_fade(1.0)
	_set_wipe(0.0)


func set_black() -> void:
	transitioning = true
	_fade_mat.set_shader_parameter("tint", Color.BLACK)
	_set_fade(1.0)


# ----------------------------------------------------------------- Toast ---
func _build_toast() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 60
	add_child(_toast_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	_toast_layer.add_child(root)
	_toast = PanelContainer.new()
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_top = 24
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.add_child(_toast)
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)
	_toast.modulate.a = 0.0


func notify(text: String) -> void:
	_toast_label.text = text
	_toast.reset_size()
	_toast.offset_left = -_toast.size.x / 2.0
	_toast.offset_right = _toast.size.x / 2.0
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.6)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
