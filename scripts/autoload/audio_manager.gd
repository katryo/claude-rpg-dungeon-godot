extends Node
## Plays sound effects and music. Streams are assigned in audio_manager.tscn.

@export var sounds: Dictionary[StringName, AudioStream] = {}
@export var music: Dictionary[StringName, AudioStream] = {}

var _current_music: StringName = &""

@onready var _music_player: AudioStreamPlayer = $MusicPlayer
@onready var _pool: Array[Node] = $SfxPlayers.get_children()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func play_sfx(sound: StringName, pitch: float = 1.0) -> void:
	if not sounds.has(sound):
		push_warning("Unknown sound: %s" % sound)
		return
	for p: AudioStreamPlayer in _pool:
		if not p.playing:
			p.stream = sounds[sound]
			p.pitch_scale = pitch
			p.play()
			return


func play_music(track: StringName) -> void:
	if track == _current_music:
		return
	_current_music = track
	_music_player.stream = music.get(track)
	_music_player.play()


func stop_music() -> void:
	_current_music = &""
	_music_player.stop()
