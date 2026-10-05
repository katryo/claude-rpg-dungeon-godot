extends Node
## Tiny procedural synthesizer: sound effects and looping music generated at runtime,
## so the project needs no audio assets.

const RATE := 22050

var _sounds: Dictionary = {}
var _music: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _current_music := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_pool.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -14.0
	add_child(_music_player)
	_build_sounds()


func play(name: String, pitch: float = 1.0) -> void:
	if not _sounds.has(name):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _sounds[name]
			p.pitch_scale = pitch
			p.play()
			return


func play_music(name: String) -> void:
	if name == _current_music:
		return
	_current_music = name
	if not _music.has(name):
		_music[name] = _build_music(name)
	_music_player.stream = _music[name]
	_music_player.play()


func stop_music() -> void:
	_current_music = ""
	_music_player.stop()


# ------------------------------------------------------------------- SFX ---
func _build_sounds() -> void:
	_sounds["cursor"] = _tone([[1320.0, 0.035]], "square", 0.25)
	_sounds["confirm"] = _tone([[880.0, 0.05], [1320.0, 0.08]], "square", 0.25)
	_sounds["cancel"] = _tone([[660.0, 0.05], [440.0, 0.07]], "square", 0.25)
	_sounds["buzz"] = _tone([[110.0, 0.15]], "square", 0.3)
	_sounds["hit"] = _noise(0.16, 0.7, 900.0)
	_sounds["slash"] = _noise(0.22, 0.55, 2400.0)
	_sounds["crit"] = _noise(0.3, 0.8, 600.0)
	_sounds["magic"] = _sweep(400.0, 1600.0, 0.45, 0.35)
	_sounds["dark"] = _sweep(300.0, 60.0, 0.7, 0.45)
	_sounds["heal"] = _tone([[523.25, 0.08], [659.25, 0.08], [783.99, 0.08], [1046.5, 0.25]], "sine", 0.4)
	_sounds["chest"] = _tone([[587.33, 0.07], [739.99, 0.07], [880.0, 0.07], [1174.66, 0.3]], "triangle", 0.4)
	_sounds["levelup"] = _tone([[523.25, 0.1], [523.25, 0.1], [523.25, 0.1], [698.46, 0.45]], "square", 0.25)
	_sounds["encounter"] = _sweep(1800.0, 200.0, 0.5, 0.4)
	_sounds["save"] = _tone([[783.99, 0.1], [1046.5, 0.1], [1567.98, 0.4]], "sine", 0.4)
	_sounds["death"] = _sweep(500.0, 80.0, 0.6, 0.35)
	_sounds["buff"] = _sweep(300.0, 900.0, 0.35, 0.3)
	_sounds["step"] = _noise(0.04, 0.12, 300.0)


func _osc(kind: String, phase: float) -> float:
	var p := fposmod(phase, 1.0)
	match kind:
		"square":
			return 1.0 if p < 0.5 else -1.0
		"triangle":
			return 4.0 * absf(p - 0.5) - 1.0
		"saw":
			return 2.0 * p - 1.0
		_:
			return sin(TAU * p)


func _make_wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _tone(notes: Array, kind: String, vol: float) -> AudioStreamWAV:
	var s := PackedFloat32Array()
	for n in notes:
		var freq: float = n[0]
		var count := int(n[1] * RATE)
		for i in count:
			var t := float(i) / RATE
			var env := minf(1.0, t * 200.0) * (1.0 - float(i) / count)
			s.append(_osc(kind, freq * t) * env * vol)
	return _make_wav(s)


func _noise(dur: float, vol: float, cutoff: float) -> AudioStreamWAV:
	var s := PackedFloat32Array()
	var count := int(dur * RATE)
	var lp := 0.0
	var a := clampf(cutoff / RATE * TAU, 0.0, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in count:
		var env := pow(1.0 - float(i) / count, 2.0)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * a
		s.append(lp * env * vol * 2.5)
	return _make_wav(s)


func _sweep(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	var s := PackedFloat32Array()
	var count := int(dur * RATE)
	var phase := 0.0
	for i in count:
		var k := float(i) / count
		var f := lerpf(f0, f1, k)
		phase += f / RATE
		var env := minf(1.0, k * 30.0) * (1.0 - k)
		s.append((sin(TAU * phase) * 0.7 + _osc("triangle", phase * 2.01) * 0.3) * env * vol)
	return _make_wav(s)


# ----------------------------------------------------------------- Music ---
static func _midi(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


func _build_music(name: String) -> AudioStreamWAV:
	match name:
		"battle":
			return _battle_theme(140.0, 50, [0, -2, 0, -4], false)
		"boss":
			return _battle_theme(152.0, 47, [0, 1, -2, -1], true)
		"victory":
			return _victory_theme()
		"title":
			return _castle_theme(60.0, 57, 0.8)
		_:
			return _castle_theme(70.0, 57, 1.0)


## Slow minor-key ambience: low drone pad plus a bell arpeggio (Am - F - Dm - E).
func _castle_theme(bpm: float, root: int, bell_vol: float) -> AudioStreamWAV:
	var beat := 60.0 / bpm
	var chords := [[0, 3, 7, 12], [-4, 0, 3, 8], [-7, -4, 0, 5], [-5, -1, 2, 7]]
	var bars := chords.size() * 2
	var total := int(bars * 4 * beat * RATE)
	var s := PackedFloat32Array()
	s.resize(total)
	var step := beat / 2.0
	for bar in bars:
		var chord: Array = chords[(bar / 2) % chords.size()]
		var bar_start := bar * 4 * beat
		# Pad
		var n0 := int(bar_start * RATE)
		var n1 := int((bar_start + 4 * beat) * RATE)
		for i in range(n0, mini(n1, total)):
			var t := float(i) / RATE
			var lt := t - bar_start
			var env := minf(1.0, lt * 2.0) * minf(1.0, (4 * beat - lt) * 3.0)
			var v := 0.0
			for off in [chord[0] - 12, chord[1], chord[2]]:
				var f := _midi(root + off - 12)
				v += sin(TAU * f * t) * 0.5 + sin(TAU * f * 1.003 * t) * 0.5
			s[i] += v * 0.05 * env * (0.8 + 0.2 * sin(t * 3.0))
		# Bells
		var pattern := [0, 1, 2, 3, 2, 1, 2, 3]
		for k in 8:
			var note: int = root + 12 + chord[pattern[k]]
			_add_bell(s, bar_start + k * step, _midi(note), 0.11 * bell_vol, 1.6)
	return _make_wav(s, true)


func _battle_theme(bpm: float, root: int, prog: Array, boss: bool) -> AudioStreamWAV:
	var beat := 60.0 / bpm
	var bars := prog.size() * 2
	var total := int(bars * 4 * beat * RATE)
	var s := PackedFloat32Array()
	s.resize(total)
	var eighth := beat / 2.0
	var bass_pat := [0, 0, 12, 0, 7, 0, 10, 12]
	var lead_a := [12, 15, 19, 17, 15, 14, 15, 10]
	var lead_b := [19, 17, 15, 14, 12, 14, 15, 17]
	for bar in bars:
		var r: int = root + prog[(bar / 2) % prog.size()]
		var bar_start := bar * 4 * beat
		for k in 8:
			var t0 := bar_start + k * eighth
			_add_note(s, t0, eighth * 0.9, _midi(r - 12 + bass_pat[k]), "saw", 0.10, 0.6)
			var lead: Array = lead_a if bar % 2 == 0 else lead_b
			_add_note(s, t0, eighth * 0.8, _midi(r + 12 + lead[k]), "square", 0.045, 0.3)
			# Kick + hat
			if k % 4 == 0:
				_add_kick(s, t0, 0.35 if not boss else 0.42)
			_add_hat(s, t0 + eighth * 0.5, 0.05)
		if boss:
			_add_note(s, bar_start, 4 * beat, _midi(r - 24), "sine", 0.12, 0.0)
	return _make_wav(s, true)


func _victory_theme() -> AudioStreamWAV:
	var beat := 60.0 / 130.0
	var notes := [[72, 0.5], [72, 0.5], [72, 0.5], [72, 1.5], [68, 1.5], [70, 1.5], [72, 1.0], [70, 0.5], [72, 4.0]]
	var total := int(14.0 * beat * RATE)
	var s := PackedFloat32Array()
	s.resize(total)
	var t := 0.0
	for n in notes:
		_add_note(s, t, n[1] * beat * 0.95, _midi(n[0]), "square", 0.08, 0.2)
		_add_note(s, t, n[1] * beat * 0.95, _midi(n[0] - 12), "triangle", 0.1, 0.2)
		t += n[1] * beat
	return _make_wav(s, false)


func _add_note(s: PackedFloat32Array, start: float, dur: float, f: float, kind: String, vol: float, decay: float) -> void:
	var n0 := int(start * RATE)
	var n := int(dur * RATE)
	for i in n:
		var idx := n0 + i
		if idx >= s.size():
			return
		var t := float(i) / RATE
		var env := minf(1.0, t * 300.0) * (1.0 - decay * float(i) / n) * minf(1.0, float(n - i) / 200.0)
		s[idx] += _osc(kind, f * t) * env * vol


func _add_bell(s: PackedFloat32Array, start: float, f: float, vol: float, dur: float) -> void:
	var n0 := int(start * RATE)
	var n := int(dur * RATE)
	for i in n:
		var idx := (n0 + i) % s.size()
		var t := float(i) / RATE
		var env := exp(-t * 3.0) * minf(1.0, t * 400.0)
		s[idx] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.76 * t) * exp(-t * 6.0)) * env * vol


func _add_kick(s: PackedFloat32Array, start: float, vol: float) -> void:
	var n0 := int(start * RATE)
	var n := int(0.18 * RATE)
	var phase := 0.0
	for i in n:
		var idx := n0 + i
		if idx >= s.size():
			return
		var k := float(i) / n
		phase += lerpf(140.0, 40.0, k) / RATE
		s[idx] += sin(TAU * phase) * (1.0 - k) * vol


func _add_hat(s: PackedFloat32Array, start: float, vol: float) -> void:
	var n0 := int(start * RATE)
	var n := int(0.03 * RATE)
	for i in n:
		var idx := n0 + i
		if idx >= s.size():
			return
		s[idx] += randf_range(-1.0, 1.0) * (1.0 - float(i) / n) * vol
