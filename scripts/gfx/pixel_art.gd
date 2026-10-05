extends RefCounted
## Builds textures at runtime: character sprites from ASCII art, plus procedural
## pixel tiles (stone, brick, carpet) and soft effect textures.

const SpriteData := preload("res://scripts/data/sprite_data.gd")
const OUTLINE := Color8(22, 14, 30)

static var _cache: Dictionary = {}


static func sprite(name: String) -> ImageTexture:
	var key := "spr_" + name
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(sprite_image(name))
	return _cache[key]


static func sprite_image(name: String) -> Image:
	var d: Dictionary = SpriteData.SPRITES[name]
	var rows: Array = d.rows
	var w := 0
	for r in rows:
		w = maxi(w, r.length())
	var h := rows.size()
	var img := Image.create(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var pal := {}
	for k in d.palette:
		pal[k] = Color.html(d.palette[k])
	for y in h:
		var row: String = rows[y]
		for x in row.length():
			var c := row[x]
			if c != "." and pal.has(c):
				img.set_pixel(x + 1, y + 1, pal[c])
	# Outline pass
	var out := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				continue
			for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + o
				if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height() and img.get_pixelv(q).a > 0.0:
					out.set_pixel(x, y, OUTLINE)
					break
	return out


## White silhouette of a sprite, used for hit flashes.
static func silhouette(name: String) -> ImageTexture:
	var key := "sil_" + name
	if not _cache.has(key):
		var img := sprite_image(name)
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					img.set_pixel(x, y, Color.WHITE)
		_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## Head-and-shoulders crop of a hero sprite for menus.
static func portrait(name: String) -> ImageTexture:
	var key := "por_" + name
	if not _cache.has(key):
		var img := sprite_image(name)
		var rect := Rect2i(1, 0, 22, 18)
		if name == "theia":
			rect = Rect2i(1, 1, 22, 18)
		_cache[key] = ImageTexture.create_from_image(img.get_region(rect))
	return _cache[key]


# ------------------------------------------------------- Procedural tiles ---
static func _rng(seed_val: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r


static func stone_floor() -> ImageTexture:
	if _cache.has("stone"):
		return _cache["stone"]
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var r := _rng(7)
	var base := Color8(64, 60, 78)
	for y in n:
		for x in n:
			var tile := Vector2i(x / 16, y / 16)
			var tone := 0.92 + 0.12 * float((tile.x * 7 + tile.y * 13) % 5) / 4.0
			var c := base * tone
			c = c.lerp(Color8(40, 38, 52), r.randf() * 0.25)
			if x % 16 == 0 or y % 16 == 0:
				c = Color8(30, 27, 38)
			elif x % 16 == 1 or y % 16 == 1:
				c = c.lightened(0.12)
			c.a = 1.0
			img.set_pixel(x, y, c)
	# A few cracks
	for i in 6:
		var p := Vector2i(r.randi_range(2, n - 3), r.randi_range(2, n - 3))
		for k in 4:
			p += Vector2i(r.randi_range(-1, 1), r.randi_range(0, 1))
			p = p.clamp(Vector2i.ZERO, Vector2i(n - 1, n - 1))
			img.set_pixelv(p, Color8(34, 30, 44))
	_cache["stone"] = ImageTexture.create_from_image(img)
	return _cache["stone"]


static func brick_wall() -> ImageTexture:
	if _cache.has("brick"):
		return _cache["brick"]
	var w := 32
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := _rng(11)
	for y in h:
		var row := y / 8
		var shift := 8 if row % 2 == 1 else 0
		for x in w:
			var bx := (x + shift) % 16
			var by := y % 8
			var brick_id := ((x + shift) / 16) * 31 + row * 17
			var tone := 0.85 + 0.25 * float(brick_id % 7) / 6.0
			var c := Color8(78, 72, 92) * tone
			c = c.lerp(Color8(50, 46, 62), r.randf() * 0.3)
			if bx == 0 or by == 0:
				c = Color8(28, 25, 36)
			elif by == 1:
				c = c.lightened(0.1)
			elif by == 7:
				c = c.darkened(0.15)
			c.a = 1.0
			img.set_pixel(x, y, c)
	_cache["brick"] = ImageTexture.create_from_image(img)
	return _cache["brick"]


static func carpet() -> ImageTexture:
	if _cache.has("carpet"):
		return _cache["carpet"]
	var n := 16
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var r := _rng(3)
	for y in n:
		for x in n:
			var c := Color8(128, 22, 38)
			c = c.lerp(Color8(96, 14, 28), r.randf() * 0.4)
			if (x + y) % 8 == 0 or (x - y + 16) % 8 == 0:
				c = Color8(150, 40, 50)
			img.set_pixel(x, y, c)
	_cache["carpet"] = ImageTexture.create_from_image(img)
	return _cache["carpet"]


static func carpet_border() -> ImageTexture:
	if _cache.has("carpet_b"):
		return _cache["carpet_b"]
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color8(206, 160, 64))
	img.set_pixel(1, 1, Color8(150, 110, 40))
	img.set_pixel(3, 3, Color8(150, 110, 40))
	_cache["carpet_b"] = ImageTexture.create_from_image(img)
	return _cache["carpet_b"]


static func banner() -> ImageTexture:
	if _cache.has("banner"):
		return _cache["banner"]
	var w := 12
	var h := 28
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var inside := y < h - 4 or absi(x - w / 2) < (h - y) * 1.5
			if not inside:
				continue
			var c := Color8(90, 16, 40)
			if x == 0 or x == w - 1:
				c = Color8(200, 150, 60)
			elif y < 2:
				c = Color8(60, 50, 40)
			img.set_pixel(x, y, c)
	# Emblem: a stylised horned crest
	var emblem := ["..g....g..", "..gg..gg..", "...gggg...", "...gppg...", "....gg....", "....gg...."]
	for ey in emblem.size():
		var row: String = emblem[ey]
		for ex in row.length():
			if row[ex] == "g":
				img.set_pixel(ex + 1, ey + 8, Color8(220, 180, 70))
			elif row[ex] == "p":
				img.set_pixel(ex + 1, ey + 8, Color8(180, 80, 255))
	_cache["banner"] = ImageTexture.create_from_image(img)
	return _cache["banner"]


static func window_tex() -> ImageTexture:
	if _cache.has("window"):
		return _cache["window"]
	var w := 12
	var h := 22
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var dx := float(x) - (w - 1) / 2.0
			var arch := y > 5 or (dx * dx + pow(y - 6.0, 2.0)) < 36.0
			if not arch:
				continue
			var c := Color8(70, 90, 170)
			if x == 0 or x == w - 1 or y == h - 1 or x == w / 2 or y == 12:
				c = Color8(30, 26, 40)
			else:
				c = c.lerp(Color8(160, 190, 255), float(h - y) / h * 0.6)
			img.set_pixel(x, y, c)
	_cache["window"] = ImageTexture.create_from_image(img)
	return _cache["window"]


## Soft radial blob (shadows, glows, particles).
static func soft_circle(size: int = 32, hardness: float = 1.5) -> ImageTexture:
	var key := "circle_%d_%f" % [size, hardness]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, pow(a, hardness)))
	_cache[key] = ImageTexture.create_from_image(img)
	return _cache[key]


## Pixel sparkle (4-point star) for magic effects.
static func sparkle() -> ImageTexture:
	if _cache.has("sparkle"):
		return _cache["sparkle"]
	var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in 7:
		var a := 1.0 - absf(i - 3) / 4.0
		img.set_pixel(3, i, Color(1, 1, 1, a))
		img.set_pixel(i, 3, Color(1, 1, 1, a))
	_cache["sparkle"] = ImageTexture.create_from_image(img)
	return _cache["sparkle"]


## Crescent slash arc.
static func slash_arc() -> ImageTexture:
	if _cache.has("slash"):
		return _cache["slash"]
	var n := 48
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(n / 2.0, n / 2.0)
	for y in n:
		for x in n:
			var v := Vector2(x, y) - c
			var d := v.length()
			var ang := atan2(v.y, v.x)
			if d > 15.0 and d < 22.0 and ang > -2.4 and ang < 0.9:
				var k := 1.0 - absf(d - 19.0) / 4.0
				var fade := clampf((ang + 2.4) / 3.3, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, clampf(k * fade * 1.4, 0.0, 1.0)))
	_cache["slash"] = ImageTexture.create_from_image(img)
	return _cache["slash"]
