extends Node
## Заготовка под звук. Клади файлы в audio/sfx/ и audio/music/ (ogg/wav/mp3) —
## подхватятся по имени: SFX.play("swing") ищет audio/sfx/swing.ogg и т.п.
## Отсутствующий файл молча пропускается, игра не ломается.

const SFX_DIR := "res://audio/sfx/"
const MUSIC_DIR := "res://audio/music/"
const EXTENSIONS := ["ogg", "wav", "mp3"]
const POOL_SIZE := 12

var _cache := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _music_player: AudioStreamPlayer
var _current_music := ""

func _ready() -> void:
	# Звук не должен замирать во время паузы (сюжетные вставки).
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -6.0
	add_child(_music_player)

func play(sfx_name: String, volume_db := 0.0, pitch_jitter := 0.0) -> void:
	var stream := _load_stream(SFX_DIR, sfx_name)
	if stream == null:
		return
	var player := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()

func play_music(track: String) -> void:
	if track == _current_music:
		return
	var stream := _load_stream(MUSIC_DIR, track)
	_current_music = track
	if stream == null:
		_music_player.stop()
		return
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	_music_player.stream = stream
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()
	_current_music = ""

func _load_stream(dir: String, stream_name: String) -> AudioStream:
	if stream_name.is_empty():
		return null
	var key := dir + stream_name
	if _cache.has(key):
		return _cache[key]
	for ext: String in EXTENSIONS:
		var path := key + "." + ext
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			_cache[key] = stream
			return stream
	_cache[key] = null
	return null
