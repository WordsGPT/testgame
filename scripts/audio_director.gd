class_name AudioDirector
extends Node

## Manages French Neural Radio Comms, Slow Replays, and Procedural Sci-Fi SFX.
## Provides live waveform bar values for the HUD Oscilloscope Visualizer.

var voice_player: AudioStreamPlayer
var companion_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
var stream_cache: Dictionary = {}
var _wave_phase: float = 0.0
var master_muted: bool = false


func _ready() -> void:
	if OS.has_feature("web"):
		AudioServer.set("driver/output_latency", 50)

	voice_player = AudioStreamPlayer.new()
	voice_player.volume_db = 4.5
	add_child(voice_player)

	companion_player = AudioStreamPlayer.new()
	companion_player.volume_db = 3.5
	add_child(companion_player)

	for i in range(6):
		var sp := AudioStreamPlayer.new()
		sp.volume_db = -7.0
		add_child(sp)
		sfx_pool.append(sp)


func _process(delta: float) -> void:
	if (voice_player and voice_player.playing) or (companion_player and companion_player.playing):
		_wave_phase += delta * 18.0


func _get_stream(rel_path: String) -> AudioStream:
	if stream_cache.has(rel_path):
		return stream_cache[rel_path]
	if ResourceLoader.exists(rel_path):
		var st := load(rel_path) as AudioStream
		if st:
			stream_cache[rel_path] = st
			return st
	return null


func play_voice(filename: String, volume_db_offset: float = 4.5, pitch: float = 1.0) -> void:
	if master_muted or filename == "":
		return
	var st := _get_stream("res://assets/audio/voice/" + filename)
	if st:
		if companion_player and companion_player.playing:
			companion_player.stop()
		voice_player.stop()
		voice_player.stream = st
		voice_player.pitch_scale = pitch
		voice_player.volume_db = maxf(volume_db_offset, 3.5)
		voice_player.play()


func play_companion(filename: String, volume_db_offset: float = 3.5) -> void:
	if master_muted or filename == "":
		return
	if voice_player and voice_player.playing:
		return
	var st := _get_stream("res://assets/audio/voice/" + filename)
	if st and companion_player:
		companion_player.stop()
		companion_player.stream = st
		companion_player.volume_db = volume_db_offset
		companion_player.play()


func play_sfx(sfx_name: String, pitch_jitter: float = 0.04, vol_db: float = -7.0) -> void:
	if master_muted:
		return
	var st := _get_stream("res://assets/audio/sfx/" + sfx_name + ".ogg")
	if not st:
		return
	# Crisp, clearly audible SFX (-6.5 dB to -9.5 dB) that sit cleanly below the +4.5 dB TTS voice!
	var final_db := clampf(vol_db if vol_db < -1.0 else (vol_db - 7.0), -10.5, -5.5)
	if is_voice_playing():
		final_db -= 1.5
	for sp in sfx_pool:
		if not sp.playing:
			sp.stream = st
			sp.volume_db = final_db
			sp.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
			sp.play()
			return
	sfx_pool[0].stream = st
	sfx_pool[0].volume_db = final_db
	sfx_pool[0].pitch_scale = 1.0
	sfx_pool[0].play()


func is_voice_playing() -> bool:
	return (voice_player != null and voice_player.playing) or (companion_player != null and companion_player.playing)


## Returns 12 normalized [0.08..1.0] bar heights for the HUD Radio Oscilloscope
func get_waveform_bars(count: int = 12) -> Array[float]:
	var bars: Array[float] = []
	var active := is_voice_playing()
	for i in range(count):
		if not active:
			bars.append(0.10)
		else:
			var center_weight := 1.0 - absf(float(i) - float(count - 1) * 0.5) / (float(count) * 0.55)
			var w1 := sin(_wave_phase + float(i) * 0.85) * 0.5 + 0.5
			var w2 := cos(_wave_phase * 1.63 - float(i) * 1.3) * 0.5 + 0.5
			var h := clampf(0.16 + (0.45 * w1 + 0.39 * w2) * center_weight, 0.12, 1.0)
			bars.append(h)
	return bars
