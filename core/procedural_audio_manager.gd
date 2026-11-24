class_name ProceduralAudioManager
extends Node
## Zero-Asset Procedural Maritime Audio Synthesizer for Project "Blue Planet"
## Uses Godot 4 `AudioStreamPlayer` + `AudioStreamGenerator` (`AudioStreamGeneratorPlayback`).
##
## Features:
## - Continuous filtered-noise ocean surf & wind ambience (automatically drops wind to silence
##   inside Calm Belts and swells into roaring hydraulic rapids near Reverse Mountain!).
## - Synthesized one-shot SFX hooks:
##   - `play_beli_chime()`
##   - `play_log_pose_lock()`
##   - `play_coup_de_burst_boom()`
##   - `play_haki_pulse()`
##   - `play_cannon_fire()`
## - Headless / Dummy audio driver safe guard so `Godot --headless` runs with ZERO audio errors.

const SAMPLE_RATE_HZ: float = 22_050.0
const BUFFER_LENGTH_SEC: float = 0.25

@export var master_gain: float = 0.45
@export var ambience_enabled: bool = true

var _audio_driver_active: bool = false
var _ambience_player: AudioStreamPlayer = null
var _ambience_playback: AudioStreamGeneratorPlayback = null
var _sfx_player: AudioStreamPlayer = null
var _sfx_playback: AudioStreamGeneratorPlayback = null

# Continuous Ambience State
var _surf_lp_state: float = 0.0
var _wind_lp_state: float = 0.0
var _surf_lfo_phase: float = 0.0
var _wind_target_gain: float = 0.35
var _wind_current_gain: float = 0.35
var _rapids_target_gain: float = 0.0
var _rapids_current_gain: float = 0.0
var _zone_poll_accum_sec: float = 0.0

# Active One-Shot Procedural Voices (array of Dictionaries mixed additively into `_sfx_playback`)
var _active_sfx_voices: Array[Dictionary] = []

# ==============================================================================
# 1. INITIALIZATION & HEADLESS / DUMMY AUDIO SAFETY GUARD
# ==============================================================================
func _ready() -> void:
	name = "ProceduralAudioManager"
	_audio_driver_active = _detect_real_audio_driver()
	if not _audio_driver_active:
		return

	_setup_generator_players()
	_connect_gameplay_signals()

func _detect_real_audio_driver() -> bool:
	if OS.has_feature("headless"):
		return false
	if OS.get_cmdline_args().has("--headless"):
		return false
	if DisplayServer.get_name().to_lower() == "headless":
		return false
	if AudioServer.has_method("get_driver_name"):
		var drv: String = str(AudioServer.call("get_driver_name")).to_lower()
		if drv.is_empty() or drv == "dummy":
			return false
	if AudioServer.get_output_device().to_lower() == "dummy":
		return false
	return true

func _setup_generator_players() -> void:
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "MaritimeAmbiencePlayer"
	var amb_gen := AudioStreamGenerator.new()
	amb_gen.mix_rate = SAMPLE_RATE_HZ
	amb_gen.buffer_length = BUFFER_LENGTH_SEC
	_ambience_player.stream = amb_gen
	add_child(_ambience_player)
	_ambience_player.play()
	var amb_pb: Variant = _ambience_player.get_stream_playback()
	if amb_pb is AudioStreamGeneratorPlayback:
		_ambience_playback = amb_pb

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "ProceduralSFXPlayer"
	var sfx_gen := AudioStreamGenerator.new()
	sfx_gen.mix_rate = SAMPLE_RATE_HZ
	sfx_gen.buffer_length = BUFFER_LENGTH_SEC
	_sfx_player.stream = sfx_gen
	add_child(_sfx_player)
	_sfx_player.play()
	var sfx_pb: Variant = _sfx_player.get_stream_playback()
	if sfx_pb is AudioStreamGeneratorPlayback:
		_sfx_playback = sfx_pb

func _connect_gameplay_signals() -> void:
	var wr: Node = get_node_or_null("/root/WorldRegistry")
	if wr != null and wr.has_signal("log_pose_locked"):
		wr.connect("log_pose_locked", func(_id: String, _cands: Array) -> void: play_log_pose_lock())

	var p: Node = get_parent()
	if p != null:
		var ship: Node = p.get_node_or_null("BuoyantShipVessel")
		if ship != null and ship.has_signal("coup_de_burst_fired"):
			ship.connect("coup_de_burst_fired", func(_c: int, _pos: Vector3) -> void: play_coup_de_burst_boom())

# ==============================================================================
# 2. REAL-TIME SYNTHESIS & PLANETARY ZONE AMBIENCE MODULATION
# ==============================================================================
func _process(delta: float) -> void:
	if not _audio_driver_active:
		return

	_zone_poll_accum_sec += delta
	if _zone_poll_accum_sec >= 0.25:
		_zone_poll_accum_sec = 0.0
		_update_zone_ambience_targets()

	_wind_current_gain = move_toward(_wind_current_gain, _wind_target_gain, delta * 0.8)
	_rapids_current_gain = move_toward(_rapids_current_gain, _rapids_target_gain, delta * 1.1)

	if ambience_enabled and _ambience_playback != null:
		_fill_ambience_buffer()
	if _sfx_playback != null:
		_fill_sfx_buffer()

func set_rapids_intensity(intensity: float) -> void:
	_rapids_target_gain = clampf(intensity, 0.0, 1.0)

func _update_zone_ambience_targets() -> void:
	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	var parent_node: Node = get_parent()
	var planet: Node = parent_node.get_node_or_null("PlanetSphere") if parent_node != null else null
	if fo == null or planet == null or not planet.has_method("classify_global_coordinates"):
		return

	var actor: Node3D = parent_node.get_node_or_null("SphericalPlayer") as Node3D
	var local_pos: Vector3 = actor.global_position if actor != null else Vector3.ZERO
	var world_vec: Vector3 = fo.call("local32_to_world_vec3", local_pos)
	var zinfo: Dictionary = planet.call("classify_global_coordinates", world_vec)

	if bool(zinfo.get("is_calm_belt", false)):
		_wind_target_gain = 0.0 # Zero wind inside Calm Belts!
		_rapids_target_gain = 0.0
	else:
		_wind_target_gain = 0.35 * float(zinfo.get("wind_multiplier", 1.0))
		var region_str: String = str(zinfo.get("region_name", ""))
		if region_str.contains("Reverse Mountain"):
			_rapids_target_gain = 0.95
		else:
			_rapids_target_gain = 0.0

func _fill_ambience_buffer() -> void:
	var frames: int = _ambience_playback.get_frames_available()
	if frames <= 0:
		return

	var inv_sr: float = 1.0 / SAMPLE_RATE_HZ
	var swell_alpha: float = 0.025 + _rapids_current_gain * 0.08
	var wind_alpha: float = 0.09

	for _i in range(frames):
		_surf_lfo_phase = fmod(_surf_lfo_phase + 0.14 * inv_sr, 1.0)
		var lfo: float = 0.55 + 0.45 * sin(_surf_lfo_phase * TAU)

		var white_a: float = randf_range(-1.0, 1.0)
		var white_b: float = randf_range(-1.0, 1.0)

		_surf_lp_state = _surf_lp_state + swell_alpha * (white_a - _surf_lp_state)
		_wind_lp_state = _wind_lp_state + wind_alpha * (white_b - _wind_lp_state)

		var surf_sample: float = _surf_lp_state * (0.28 * lfo + _rapids_current_gain * 0.65)
		var wind_sample: float = (_wind_lp_state - _surf_lp_state * 0.4) * _wind_current_gain * 0.45
		var out_val: float = clampf((surf_sample + wind_sample) * master_gain, -0.95, 0.95)
		_ambience_playback.push_frame(Vector2(out_val, out_val))

func _fill_sfx_buffer() -> void:
	var frames: int = _sfx_playback.get_frames_available()
	if frames <= 0:
		return

	if _active_sfx_voices.is_empty():
		for _i in range(frames):
			_sfx_playback.push_frame(Vector2.ZERO)
		return

	var dt: float = 1.0 / SAMPLE_RATE_HZ
	for _i in range(frames):
		var mix_l: float = 0.0
		var v_idx: int = _active_sfx_voices.size() - 1
		while v_idx >= 0:
			var voice: Dictionary = _active_sfx_voices[v_idx]
			var t: float = float(voice["t"])
			var dur: float = float(voice["dur"])
			if t >= dur:
				_active_sfx_voices.remove_at(v_idx)
				v_idx -= 1
				continue

			var env: float = exp(-t * float(voice["decay"])) * minf(1.0, t / 0.005)
			var freq: float = lerpf(float(voice["freq_start"]), float(voice["freq_end"]), t / dur)
			var phase: float = float(voice["phase"]) + freq * dt
			voice["phase"] = fmod(phase, 1.0)
			voice["t"] = t + dt

			var tone: float = sin(phase * TAU) * float(voice["tone_mix"])
			var noise: float = randf_range(-1.0, 1.0) * float(voice["noise_mix"])
			mix_l += (tone + noise) * env * float(voice["amp"])
			v_idx -= 1

		var out_s: float = clampf(mix_l * master_gain, -0.95, 0.95)
		_sfx_playback.push_frame(Vector2(out_s, out_s))

func _spawn_voice(
	freq_start: float,
	freq_end: float,
	dur: float,
	decay: float,
	amp: float,
	tone_mix: float = 1.0,
	noise_mix: float = 0.0,
	delay_sec: float = 0.0
) -> void:
	if not _audio_driver_active:
		return
	_active_sfx_voices.append({
		"freq_start": freq_start,
		"freq_end": freq_end,
		"dur": dur,
		"decay": decay,
		"amp": amp,
		"tone_mix": tone_mix,
		"noise_mix": noise_mix,
		"t": -delay_sec,
		"phase": 0.0
	})

# ==============================================================================
# 3. ONE-SHOT MARITIME, CURRENCY, HAKI & COMBAT SFX HOOKS
# ==============================================================================
func play_beli_chime() -> void:
	_spawn_voice(1046.5, 1046.5, 0.16, 18.0, 0.55, 1.0, 0.0, 0.0)
	_spawn_voice(1318.5, 1318.5, 0.18, 16.0, 0.55, 1.0, 0.0, 0.06)
	_spawn_voice(1568.0, 1568.0, 0.28, 12.0, 0.60, 1.0, 0.0, 0.12)

func play_log_pose_lock() -> void:
	_spawn_voice(587.3, 880.0, 0.35, 8.0, 0.50, 0.9, 0.05, 0.0)
	_spawn_voice(1174.7, 1174.7, 0.45, 7.0, 0.45, 1.0, 0.0, 0.08)

func play_coup_de_burst_boom() -> void:
	_spawn_voice(110.0, 26.0, 0.95, 3.2, 0.95, 0.8, 0.55, 0.0)
	_spawn_voice(440.0, 90.0, 0.55, 5.5, 0.45, 0.2, 0.85, 0.02)

func play_haki_pulse() -> void:
	_spawn_voice(185.0, 52.0, 0.65, 4.5, 0.75, 0.95, 0.15, 0.0)
	_spawn_voice(740.0, 370.0, 0.45, 7.5, 0.40, 1.0, 0.0, 0.02)

func play_cannon_fire() -> void:
	_spawn_voice(145.0, 34.0, 0.55, 6.0, 0.85, 0.45, 0.85, 0.0)
