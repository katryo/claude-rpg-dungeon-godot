extends Node3D
## Title screen (moonlit castle on the horizon) and ending (the same vista at dawn).

const Props := preload("res://scripts/world/props.gd")
const PixelArt := preload("res://scripts/gfx/pixel_art.gd")
const SelectList := preload("res://scripts/ui/select_list.gd")

signal chosen(choice: String)

var ending := false
var camera: Camera3D
var _t := 0.0
var _ui: Control
var _accept_wait := false


func _ready() -> void:
	_build_world()
	_build_ui()
	if ending:
		Sfx.play_music("title")
		_run_ending.call_deferred()
	else:
		Sfx.play_music("title")
		_run_title.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	Props.update_flicker(get_tree())
	camera.position = Vector3(sin(_t * 0.1) * 1.2, 2.2 + sin(_t * 0.17) * 0.2, 9.0)
	camera.look_at(Vector3(0, 3.5, -30), Vector3.UP)


func _build_world() -> void:
	var we := Props.make_environment(self, 9.0)
	var env := we.environment
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	if ending:
		sm.sky_top_color = Color(0.25, 0.35, 0.7)
		sm.sky_horizon_color = Color(1.0, 0.62, 0.38)
		sm.ground_horizon_color = Color(0.6, 0.4, 0.35)
		sm.ground_bottom_color = Color(0.1, 0.08, 0.12)
	else:
		sm.sky_top_color = Color(0.02, 0.02, 0.08)
		sm.sky_horizon_color = Color(0.18, 0.1, 0.3)
		sm.ground_horizon_color = Color(0.1, 0.06, 0.15)
		sm.ground_bottom_color = Color(0.0, 0.0, 0.02)
	sm.sun_angle_max = 1.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.75, 0.6) if ending else Color(0.3, 0.3, 0.55)
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(1.0, 0.75, 0.6) if ending else Color(0.5, 0.5, 0.8)
	env.fog_light_color = Color(0.7, 0.45, 0.4) if ending else Color(0.08, 0.06, 0.15)
	env.fog_density = 0.01
	we.camera_attributes.dof_blur_far_distance = 18.0
	we.camera_attributes.dof_blur_far_transition = 20.0
	we.camera_attributes.dof_blur_near_enabled = false

	var light := Props.make_moonlight(self, 1.2 if ending else 0.6)
	if ending:
		light.light_color = Color(1.0, 0.75, 0.55)
		light.rotation_degrees = Vector3(-12, 160, 0)

	# Ground
	var ground := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(200, 0.2, 200)
	ground.mesh = gm
	ground.material_override = Props.tex_material(PixelArt.stone_floor(), 0.5, Color(0.6, 0.6, 0.7))
	ground.position = Vector3(0, -0.1, -60)
	add_child(ground)

	# Heavenly body
	var orb := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 7.0
	sp.height = 14.0
	orb.mesh = sp
	var om := StandardMaterial3D.new()
	om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	om.albedo_color = Color(3.0, 1.8, 0.9) if ending else Color(1.6, 1.7, 2.2)
	orb.material_override = om
	orb.position = Vector3(-26, 8 if ending else 26, -110)
	add_child(orb)

	_build_castle_silhouette()

	# The party gazing at the castle.
	var ids := ["garrick", "arlen", "theia"]
	for i in 3:
		var h := Props.make_billboard(ids[i], 1.0)
		h.position = Vector3(-3.4 + i * 1.5, 0, 0.5 + (0.4 if i == 1 else 0.0))
		add_child(h)
	Props.make_brazier(self, Vector3(-5.0, 0, 1.5))
	Props.make_brazier(self, Vector3(5.0, 0, 1.5))
	Props.make_dust(self, Vector3(10, 4, 6), 140).position = Vector3(0, 3, 0)

	camera = Camera3D.new()
	camera.fov = 45.0
	camera.far = 300.0
	add_child(camera)
	camera.make_current()


func _build_castle_silhouette() -> void:
	var dark := Props.color_material(Color(0.07, 0.05, 0.1))
	var root := Node3D.new()
	root.position = Vector3(0, 0, -45)
	add_child(root)
	var towers := [
		[Vector3(0, 0, 0), Vector3(8, 20, 6)],
		[Vector3(-8, 0, 2), Vector3(4, 14, 4)],
		[Vector3(8, 0, 2), Vector3(4, 14, 4)],
		[Vector3(-14, 0, 4), Vector3(3, 10, 3)],
		[Vector3(14, 0, 4), Vector3(3, 10, 3)],
		[Vector3(0, 20, 0), Vector3(3, 8, 3)],
		[Vector3(-11, 0, 4), Vector3(18, 6, 2)],
	]
	for t in towers:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = t[1]
		mi.mesh = b
		mi.material_override = dark
		mi.position = t[0] + Vector3(0, t[1].y / 2.0, 0)
		root.add_child(mi)
		var roof := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(t[1].x * 1.1, t[1].x * 1.2, t[1].z * 1.1)
		roof.mesh = pm
		roof.material_override = dark
		roof.position = t[0] + Vector3(0, t[1].y + pm.size.y / 2.0, 0)
		if t[1].x < 10:
			root.add_child(roof)
	var win := Props.color_material(Color(1.0, 0.6, 0.2), Color(1.0, 0.55, 0.15), 4.0)
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for i in 22:
		var w := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.5, 0.9)
		w.mesh = q
		w.material_override = win
		var tw: Array = towers[r.randi_range(0, 5)]
		var p: Vector3 = tw[0] + Vector3(r.randf_range(-tw[1].x / 2.5, tw[1].x / 2.5), r.randf_range(2.0, tw[1].y - 1.0), tw[1].z / 2.0 + 0.02)
		w.position = p
		if not ending:
			root.add_child(w)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.theme = UI.theme
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)


func _title_label(text: String, size: int, y: float, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.1))
	l.add_theme_constant_override("outline_size", 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.offset_top = y
	_ui.add_child(l)
	return l


func _run_title() -> void:
	await UI.fade_in(1.0)
	var sub := _title_label("~ An HD-2D Tale ~", 22, 70, Color(0.85, 0.82, 1.0))
	var t1 := _title_label("SHARDS OF DAWN", 76, 100, Color(1.0, 0.85, 0.5))
	var t2 := _title_label("The Dark Castle", 34, 196, Color(0.95, 0.9, 1.0))
	for l in [sub, t1, t2]:
		l.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 1.2)
	await get_tree().create_timer(0.6).timeout
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -400
	panel.offset_right = -140
	panel.offset_top = -250
	panel.offset_bottom = -130
	panel.add_theme_stylebox_override("panel", UI.panel_style(0.75))
	_ui.add_child(panel)
	var list := SelectList.new()
	list.allow_cancel = false
	panel.add_child(list)
	list.set_items([{"text": "New Game"}, {"text": "Quit"}])
	var hint := _title_label("Arrows/WASD to move • Z/Enter to confirm • X/Esc to cancel", 16, 680, Color(0.8, 0.8, 0.9, 0.8))
	hint.modulate.a = 0.8
	var c := await list.choose()
	chosen.emit("new" if c == 0 else "quit")


func _run_ending() -> void:
	await UI.fade_in(2.0)
	var lines := [
		["", "With a final cry, Malzeth crumbled into ash,\nand the long night over the realm shattered like glass."],
		["Arlen", "It's over... The dawn is finally coming back.", "arlen"],
		["Garrick", "Heh. Told you I'd keep you two in one piece.", "garrick"],
		["Theia", "The oracle's vision was true. The age of shadow has ended.", "theia"],
		["Arlen", "Let's go home. Eldmoor has waited long enough.", "arlen"],
	]
	await UI.say(lines)
	var t1 := _title_label("THE END", 72, 200, Color(1.0, 0.9, 0.6))
	var t2 := _title_label("Thank you for playing  SHARDS OF DAWN", 26, 300, Color(1.0, 0.95, 0.9))
	var t3 := _title_label("Press Z / Enter", 18, 600, Color(1.0, 0.95, 0.9, 0.8))
	for l in [t1, t2, t3]:
		l.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 1.5)
	Sfx.play("levelup")
	await get_tree().create_timer(1.5).timeout
	_accept_wait = true


func _unhandled_input(event: InputEvent) -> void:
	if _accept_wait and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		_accept_wait = false
		chosen.emit("title")
