extends RefCounted
## Shared builders for the HD-2D look: environment & post-processing, materials,
## billboard pixel sprites, fire, pillars, braziers and other castle props.

const PixelArt := preload("res://scripts/gfx/pixel_art.gd")

const PIXEL_SIZE := 0.058


# ------------------------------------------------------------ Environment ---
## Creates the WorldEnvironment with tilt-shift depth of field, bloom, fog and
## colour grading - the core ingredients of the HD-2D aesthetic.
static func make_environment(parent: Node, focus_distance: float, boss := false) -> WorldEnvironment:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.01, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.38, 0.58) if not boss else Color(0.42, 0.28, 0.52)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.05
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.4)
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.04, 0.12)
	env.fog_density = 0.018
	env.fog_sky_affect = 0.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.022 if not boss else 0.03
	env.volumetric_fog_albedo = Color(0.55, 0.5, 0.75)
	env.volumetric_fog_emission = Color(0.03, 0.01, 0.06)
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_anisotropy = 0.3
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 1.18
	env.adjustment_brightness = 1.0
	we.environment = env

	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = focus_distance + 4.0
	attrs.dof_blur_far_transition = 10.0
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_near_distance = maxf(1.0, focus_distance - 3.0)
	attrs.dof_blur_near_transition = 4.0
	attrs.dof_blur_amount = 0.1
	we.camera_attributes = attrs
	parent.add_child(we)
	return we


static func make_moonlight(parent: Node, energy := 0.45) -> DirectionalLight3D:
	var l := DirectionalLight3D.new()
	l.light_color = Color(0.6, 0.65, 1.0)
	l.light_energy = energy
	l.shadow_enabled = true
	l.shadow_blur = 1.5
	l.directional_shadow_max_distance = 60.0
	l.rotation_degrees = Vector3(-55, -30, 0)
	l.light_volumetric_fog_energy = 0.6
	parent.add_child(l)
	return l


# -------------------------------------------------------------- Materials ---
static func tex_material(tex: Texture2D, scale: float, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.roughness = 0.9
	return m


static func color_material(c: Color, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m


static func floor_material() -> StandardMaterial3D:
	return tex_material(PixelArt.stone_floor(), 0.5)


static func wall_material() -> StandardMaterial3D:
	return tex_material(PixelArt.brick_wall(), 0.5)


static func carpet_material() -> StandardMaterial3D:
	var m := tex_material(PixelArt.carpet(), 1.0)
	m.roughness = 1.0
	return m


static func gold_material() -> StandardMaterial3D:
	var m := color_material(Color(0.85, 0.65, 0.25))
	m.metallic = 0.8
	m.roughness = 0.35
	return m


# ---------------------------------------------------------------- Sprites ---
## A pixel-art billboard standing on the ground at the node origin.
static func make_billboard(sprite_name: String, scale := 1.0, shadow := true) -> Node3D:
	var root := Node3D.new()
	var spr := Sprite3D.new()
	spr.name = "Sprite"
	var tex := PixelArt.sprite(sprite_name)
	spr.texture = tex
	spr.pixel_size = PIXEL_SIZE * scale
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.shaded = false
	spr.double_sided = true
	spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spr.position.y = tex.get_height() * spr.pixel_size * 0.5 - spr.pixel_size
	root.add_child(spr)
	if shadow:
		var blob := MeshInstance3D.new()
		blob.name = "Shadow"
		var q := QuadMesh.new()
		var w := tex.get_width() * spr.pixel_size * 0.75
		q.size = Vector2(w, w * 0.45)
		blob.mesh = q
		blob.rotation_degrees.x = -90
		blob.position.y = 0.03
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = PixelArt.soft_circle(32, 1.2)
		m.albedo_color = Color(0, 0, 0, 0.6)
		blob.material_override = m
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(blob)
	return root


# ------------------------------------------------------------------- Fire ---
static func make_fire(parent: Node3D, pos: Vector3, size := 1.0, color := Color(1.0, 0.55, 0.2), light_energy := 2.6, light_range := 7.0) -> OmniLight3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = int(22 * size)
	p.lifetime = 0.7
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.1 * size
	p.direction = Vector3.UP
	p.spread = 15.0
	p.gravity = Vector3(0, 1.8, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.1))
	p.scale_amount_curve = curve
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	grad.set_color(1, Color(color.r, color.g * 0.3, color.b * 0.3, 0.0))
	grad.add_point(0.35, Color(color.r, color.g, color.b, 0.9))
	p.color_ramp = grad
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 0.28 * size
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
	parent.add_child(p)

	var l := OmniLight3D.new()
	l.position = pos + Vector3(0, 0.35, 0)
	l.light_color = color
	l.light_energy = light_energy
	l.omni_range = light_range
	l.omni_attenuation = 1.4
	l.light_volumetric_fog_energy = 1.5
	l.set_meta("base_energy", light_energy)
	l.set_meta("phase", randf() * 10.0)
	l.add_to_group("flicker")
	parent.add_child(l)
	return l


## Call every frame from scenes containing fires.
static func update_flicker(tree: SceneTree) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for l in tree.get_nodes_in_group("flicker"):
		var ph: float = l.get_meta("phase")
		var k := 0.82 + 0.1 * sin(t * 9.0 + ph) + 0.08 * sin(t * 23.0 + ph * 2.0)
		l.light_energy = l.get_meta("base_energy") * k


# ------------------------------------------------------------------ Props ---
static func make_pillar(parent: Node3D, pos: Vector3, height := 4.5) -> void:
	var stone := wall_material()
	var shaft := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.38
	c.bottom_radius = 0.42
	c.height = height
	c.radial_segments = 12
	shaft.mesh = c
	shaft.material_override = stone
	shaft.position = pos + Vector3(0, height / 2.0, 0)
	parent.add_child(shaft)
	for y in [0.15, height - 0.15]:
		var cap := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(1.05, 0.3, 1.05)
		cap.mesh = b
		cap.material_override = stone
		cap.position = pos + Vector3(0, y, 0)
		parent.add_child(cap)


static func make_brazier(parent: Node3D, pos: Vector3, color := Color(1.0, 0.55, 0.2)) -> void:
	var gold := gold_material()
	var stand := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.08
	c.bottom_radius = 0.18
	c.height = 1.0
	stand.mesh = c
	stand.material_override = color_material(Color(0.2, 0.18, 0.22))
	stand.position = pos + Vector3(0, 0.5, 0)
	parent.add_child(stand)
	var bowl := MeshInstance3D.new()
	var b := CylinderMesh.new()
	b.top_radius = 0.42
	b.bottom_radius = 0.2
	b.height = 0.3
	bowl.mesh = b
	bowl.material_override = gold
	bowl.position = pos + Vector3(0, 1.1, 0)
	parent.add_child(bowl)
	var coals := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.36
	cm.bottom_radius = 0.36
	cm.height = 0.05
	coals.mesh = cm
	coals.material_override = color_material(Color(0.3, 0.05, 0.0), Color(1.0, 0.35, 0.05), 3.0)
	coals.position = pos + Vector3(0, 1.25, 0)
	parent.add_child(coals)
	make_fire(parent, pos + Vector3(0, 1.3, 0), 1.6, color, 3.2, 8.0)


static func make_wall_torch(parent: Node3D, pos: Vector3) -> void:
	var holder := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.12, 0.5, 0.25)
	holder.mesh = b
	holder.material_override = color_material(Color(0.25, 0.2, 0.18))
	holder.position = pos
	parent.add_child(holder)
	make_fire(parent, pos + Vector3(0, 0.35, 0.05), 0.9, Color(1.0, 0.55, 0.2), 1.8, 6.0)


static func make_banner(parent: Node3D, pos: Vector3, facing_z := 1.0) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 2.4)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = PixelArt.banner()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = pos
	if facing_z < 0.0:
		mi.rotation_degrees.y = 180
	parent.add_child(mi)


static func make_window(parent: Node3D, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 2.0)
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = PixelArt.window_tex()
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.emission_enabled = true
	m.emission_texture = PixelArt.window_tex()
	m.emission = Color.WHITE
	m.emission_energy_multiplier = 1.6
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)


## Drifting embers / dust motes that catch the light.
static func make_dust(parent: Node3D, extents: Vector3, amount := 90, color := Color(1.0, 0.75, 0.45, 0.7)) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3(0.3, 1, 0)
	p.spread = 60.0
	p.gravity = Vector3(0, 0.05, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	var grad := Gradient.new()
	grad.set_color(0, Color(color.r, color.g, color.b, 0.0))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	grad.add_point(0.5, color)
	p.color_ramp = grad
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 0.07
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = m
	p.mesh = q
	parent.add_child(p)
	return p
