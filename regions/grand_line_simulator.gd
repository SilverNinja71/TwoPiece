class_name GrandLineSimulator
extends Node3D
## Runtime Anomaly, Weather, Sea King, Sea Train, Zunesha & Abyss Simulator
## for "THE MIDDLE JUMBO MESS" in Project "Blue Planet" (Godot 4.3+ precision=double).
##
## Driven by `GrandLineData` and `PlanetSphere` (R = 16,000,000.0m, 2.0m player scale).
## Instanced inside `res://scenes/main_planet.tscn`.

signal weather_anomaly_shifted(cell_id: String, weather_type: String, center_lat: float, center_lon: float)
signal knock_up_stream_phase_changed(phase_name: String, vertical_velocity_ms: float)
signal knock_up_stream_launched_vessel(vessel_name: String, altitude_m: float)
signal calm_belt_sea_king_emerged(sea_king_data: Dictionary)
signal sea_train_station_arrived(train_id: String, station_id: String, station_name: String)
signal zunesha_rain_ruption_triggered(zunesha_pos: Vector3, active: bool)
signal abyssal_crush_warning(vessel_name: String, depth_m: float, pressure_atm: float)

# ==============================================================================
# 1. PLANETARY & SIMULATION CONSTANTS
# ==============================================================================
const PLANET_RADIUS_M: float = 16_000_000.0
const WHITE_SEA_ALT_M: float = 7_000.0
const WHITE_WHITE_SEA_ALT_M: float = 10_000.0
const ABYSS_FLOOR_ALT_M: float = -10_000.0

# Knock Up Stream (South of Jaya: Lat -3.5 deg, Lon 74.0 deg)
const KNOCK_UP_LAT_DEG: float = -3.5
const KNOCK_UP_LON_DEG: float = 74.0
const KNOCK_UP_RADIUS_M: float = 12_000.0
const KNOCK_UP_CYCLE_SEC: float = 300.0       # Erupts every 5 minutes
const KNOCK_UP_ACTIVE_DURATION_SEC: float = 45.0
const KNOCK_UP_PEAK_VELOCITY_MS: float = 320.0

# Calm Belt Sea King Spawner
const SEA_KING_SPAWN_INTERVAL_SEC: float = 15.0
const MAX_ACTIVE_SEA_KINGS: int = 8

# Zunesha Rain-ruption (twice daily cycle compressed to 240s gameplay period)
const RAIN_RUPTION_CYCLE_SEC: float = 240.0
const RAIN_RUPTION_DURATION_SEC: float = 22.0

enum WeatherType {
	CLEAR_TRADE_WINDS = 0,
	SUMMER_HEATWAVE = 1,
	WINTER_BLIZZARD = 2,
	RAIJIN_LIGHTNING_STORM = 3,
	GRAND_LINE_CYCLONE = 4,
	FLORIAN_PERPETUAL_FOG = 5,
	NEW_WORLD_FIRE_RAIN = 6,
	AQUA_LAGUNA_SURGE = 7
}

# ==============================================================================
# 2. EXPORTS & SCENE REFERENCES
# ==============================================================================
@export var planet_sphere_path: NodePath
@export var target_vessel_path: NodePath
@export var player_path: NodePath
@export var ocean_shader_material: ShaderMaterial
@export var terrain_shader_material: ShaderMaterial
@export var auto_tick_simulation: bool = true

var planet_sphere: Node = null
var target_vessel: Node3D = null
var player_node: Node3D = null

# ==============================================================================
# 3. RUNTIME STATE
# ==============================================================================
var _sim_clock_sec: float = 0.0
var _weather_rotation_timer_sec: float = 0.0
var _sea_king_timer_sec: float = 0.0

# Active magnetic weather anomaly cells across Paradise & New World
var weather_cells: Array[Dictionary] = []

# Knock Up Stream state
var knock_up_timer_sec: float = 240.0 # Starts near eruption for easier testing
var knock_up_phase: String = "DORMANT"
var knock_up_current_velocity_ms: float = 0.0
var _knock_up_epicenter_world: Vector3 = Vector3.ZERO

# Calm Belt Sea Kings
var active_sea_kings: Array[Dictionary] = []

# Sea Train Network (Puffing Tom & Rocketman)
var sea_train_states: Dictionary = {}
var _sea_train_stations: Array[Dictionary] = []

# Live Zunesha & Thriller Bark states
var zunesha_state: Dictionary = {}
var thriller_bark_state: Dictionary = {}
var rain_ruption_active: bool = false

# Child Marker Nodes (spawned cleanly for 3D scene debugging / attachment)
var _zunesha_marker: Marker3D = null
var _puffing_tom_marker: Marker3D = null
var _rocketman_marker: Marker3D = null
var _knock_up_marker: Marker3D = null


# ==============================================================================
# 4. LIFECYCLE
# ==============================================================================
func _ready() -> void:
	name = "GrandLineSimulator"
	_resolve_scene_references()
	_knock_up_epicenter_world = GrandLineData.lat_lon_alt_to_vector3(KNOCK_UP_LAT_DEG, KNOCK_UP_LON_DEG, 0.0)
	_initialize_weather_cells()
	_initialize_sea_trains()
	_ensure_debug_markers()
	_update_zunesha_and_thriller_bark(0.0)


func _physics_process(delta: float) -> void:
	if not auto_tick_simulation:
		return
	_sim_clock_sec += delta
	_update_weather_cells(delta)
	_update_knock_up_stream(delta)
	_update_sea_trains(delta)
	_update_zunesha_and_thriller_bark(delta)
	_evaluate_vessel_environment(delta)
	_sync_shader_uniforms()


func _resolve_scene_references() -> void:
	if not planet_sphere_path.is_empty():
		planet_sphere = get_node_or_null(planet_sphere_path)
	if planet_sphere == null and get_parent() != null:
		planet_sphere = get_parent().get_node_or_null("PlanetSphere")

	if not target_vessel_path.is_empty():
		target_vessel = get_node_or_null(target_vessel_path) as Node3D
	if target_vessel == null and get_parent() != null:
		target_vessel = get_parent().get_node_or_null("BuoyantShipVessel") as Node3D

	if not player_path.is_empty():
		player_node = get_node_or_null(player_path) as Node3D
	if player_node == null and get_parent() != null:
		player_node = get_parent().get_node_or_null("SphericalPlayer") as Node3D


func _ensure_debug_markers() -> void:
	_zunesha_marker = _get_or_create_marker("ZuneshaMobileMarker")
	_puffing_tom_marker = _get_or_create_marker("PuffingTomMarker")
	_rocketman_marker = _get_or_create_marker("RocketmanMarker")
	_knock_up_marker = _get_or_create_marker("KnockUpStreamMarker")
	_knock_up_marker.global_position = _knock_up_epicenter_world


func _get_or_create_marker(marker_name: String) -> Marker3D:
	var existing: Marker3D = get_node_or_null(marker_name) as Marker3D
	if existing != null:
		return existing
	var m := Marker3D.new()
	m.name = marker_name
	add_child(m)
	return m


# ==============================================================================
# 5. ERRATIC GRAND LINE MAGNETIC WEATHER ANOMALIES
# ==============================================================================
func _initialize_weather_cells() -> void:
	weather_cells = [
		{
			"id": "paradise_drum_blizzard",
			"weather_type": WeatherType.WINTER_BLIZZARD,
			"weather_name": "Drum Sub-Zero Squall",
			"lat_deg": 4.2, "lon_deg": 41.0,
			"radius_m": 48_000.0,
			"wind_speed_ms": 24.0,
			"storm_intensity": 0.72,
			"lightning_rate": 0.05,
			"temperature_c": -18.0
		},
		{
			"id": "alabasta_sand_siesta",
			"weather_type": WeatherType.SUMMER_HEATWAVE,
			"weather_name": "Sandora Super-Thermal Gale",
			"lat_deg": -8.5, "lon_deg": 56.0,
			"radius_m": 62_000.0,
			"wind_speed_ms": 18.0,
			"storm_intensity": 0.45,
			"lightning_rate": 0.0,
			"temperature_c": 46.0
		},
		{
			"id": "water7_aqua_laguna",
			"weather_type": WeatherType.AQUA_LAGUNA_SURGE,
			"weather_name": "Aqua Laguna Tidal Cyclone",
			"lat_deg": -4.6, "lon_deg": 115.0,
			"radius_m": 55_000.0,
			"wind_speed_ms": 38.0,
			"storm_intensity": 0.95,
			"lightning_rate": 0.45,
			"temperature_c": 14.0
		},
		{
			"id": "florian_triangle_mist",
			"weather_type": WeatherType.FLORIAN_PERPETUAL_FOG,
			"weather_name": "Florian Triangle Umbral Fog",
			"lat_deg": -2.0, "lon_deg": 146.0,
			"radius_m": 95_000.0,
			"wind_speed_ms": 6.0,
			"storm_intensity": 0.35,
			"lightning_rate": 0.1,
			"temperature_c": 7.0
		},
		{
			"id": "raijin_lightning_cell",
			"weather_type": WeatherType.RAIJIN_LIGHTNING_STORM,
			"weather_name": "Raijin Perpetual Lightning Rain",
			"lat_deg": 4.5, "lon_deg": 191.0,
			"radius_m": 45_000.0,
			"wind_speed_ms": 32.0,
			"storm_intensity": 1.0,
			"lightning_rate": 1.0,
			"temperature_c": 22.0
		},
		{
			"id": "new_world_roaming_cyclone",
			"weather_type": WeatherType.GRAND_LINE_CYCLONE,
			"weather_name": "New World Magnetic Supercell",
			"lat_deg": -1.0, "lon_deg": 235.0,
			"radius_m": 70_000.0,
			"wind_speed_ms": 42.0,
			"storm_intensity": 0.92,
			"lightning_rate": 0.7,
			"temperature_c": 11.0
		},
		{
			"id": "punk_hazard_fire_ice_shear",
			"weather_type": WeatherType.NEW_WORLD_FIRE_RAIN,
			"weather_name": "Burning-Ice Thermal Shear",
			"lat_deg": 2.1, "lon_deg": 198.0,
			"radius_m": 40_000.0,
			"wind_speed_ms": 27.0,
			"storm_intensity": 0.85,
			"lightning_rate": 0.35,
			"temperature_c": 38.0
		}
	]


func _update_weather_cells(delta: float) -> void:
	_weather_rotation_timer_sec += delta
	# Roaming New World supercell drifts along the Grand Line corridor
	for cell in weather_cells:
		if cell["id"] == "new_world_roaming_cyclone":
			cell["lon_deg"] = wrapf(float(cell["lon_deg"]) + delta * 0.012, 185.0, 355.0)
			cell["lat_deg"] = 4.5 * sin(_sim_clock_sec * 0.015)

	# Sudden Grand Line weather flip every 90 seconds on the roaming cell
	if _weather_rotation_timer_sec >= 90.0:
		_weather_rotation_timer_sec = 0.0
		var roaming: Dictionary = weather_cells[5]
		var cycle: Array[int] = [
			WeatherType.GRAND_LINE_CYCLONE,
			WeatherType.WINTER_BLIZZARD,
			WeatherType.SUMMER_HEATWAVE,
			WeatherType.NEW_WORLD_FIRE_RAIN
		]
		var next_idx: int = (cycle.find(int(roaming["weather_type"])) + 1) % cycle.size()
		roaming["weather_type"] = cycle[next_idx]
		roaming["weather_name"] = _weather_type_label(cycle[next_idx])
		weather_anomaly_shifted.emit(
			roaming["id"],
			roaming["weather_name"],
			float(roaming["lat_deg"]),
			float(roaming["lon_deg"])
		)


static func _weather_type_label(w_type: int) -> String:
	match w_type:
		WeatherType.SUMMER_HEATWAVE: return "Sudden Grand Line Heatwave"
		WeatherType.WINTER_BLIZZARD: return "Sudden Grand Line Blizzard"
		WeatherType.RAIJIN_LIGHTNING_STORM: return "Lightning Rain Squall"
		WeatherType.GRAND_LINE_CYCLONE: return "Magnetic Super-Cyclone"
		WeatherType.FLORIAN_PERPETUAL_FOG: return "Pitch-Black Fog"
		WeatherType.NEW_WORLD_FIRE_RAIN: return "New World Fire-Rain"
		WeatherType.AQUA_LAGUNA_SURGE: return "Aqua Laguna Surge"
	return "Clear Trade Winds"


## Queries weather, wind speed (clamped to 0.0 m/s in Calm Belts), and storm intensity at any 64-bit world_pos.
func evaluate_weather_at_world_pos(world_pos: Vector3) -> Dictionary:
	var coords: Dictionary = _world_to_lat_lon_alt(world_pos)
	var in_calm_belt: bool = _is_in_calm_belt(world_pos)

	if in_calm_belt:
		return {
			"weather_type": WeatherType.CLEAR_TRADE_WINDS,
			"weather_name": "Calm Belt — Dead Stillness",
			"in_calm_belt": true,
			"wind_speed_ms": 0.0,
			"storm_intensity": 0.0,
			"lightning_rate": 0.0,
			"visibility_km": 40.0
		}

	var best_match: Dictionary = {}
	var best_weight: float = 0.0
	for cell in weather_cells:
		var cell_pos: Vector3 = GrandLineData.lat_lon_alt_to_vector3(
			float(cell["lat_deg"]), float(cell["lon_deg"]), 0.0
		)
		var dist_m: float = world_pos.distance_to(cell_pos)
		var radius_m: float = float(cell["radius_m"])
		if dist_m <= radius_m:
			var weight: float = 1.0 - (dist_m / radius_m)
			if weight > best_weight:
				best_weight = weight
				best_match = cell

	if best_match.is_empty():
		# Baseline Grand Line sea breeze vs Sky Sea altitude air
		var alt_m: float = float(coords["alt_m"])
		return {
			"weather_type": WeatherType.CLEAR_TRADE_WINDS,
			"weather_name": "White-White Sea Jet Stream" if alt_m >= 6_500.0 else "Grand Line Variable Breeze",
			"in_calm_belt": false,
			"wind_speed_ms": 16.0 if alt_m >= 6_500.0 else 13.5,
			"storm_intensity": 0.15,
			"lightning_rate": 0.0,
			"visibility_km": 28.0
		}

	return {
		"weather_type": int(best_match["weather_type"]),
		"weather_name": String(best_match["weather_name"]),
		"in_calm_belt": false,
		"wind_speed_ms": float(best_match["wind_speed_ms"]) * (0.4 + 0.6 * best_weight),
		"storm_intensity": float(best_match["storm_intensity"]) * best_weight,
		"lightning_rate": float(best_match["lightning_rate"]) * best_weight,
		"visibility_km": 1.2 if int(best_match["weather_type"]) == WeatherType.FLORIAN_PERPETUAL_FOG else 12.0
	}


# ==============================================================================
# 6. KNOCK UP STREAM GEOTHERMAL ERUPTION (JAYA -> +7KM / +10KM SKYPIA)
# ==============================================================================
func trigger_knock_up_stream_eruption() -> void:
	knock_up_timer_sec = KNOCK_UP_CYCLE_SEC - KNOCK_UP_ACTIVE_DURATION_SEC
	_set_knock_up_phase("ERUPTING", KNOCK_UP_PEAK_VELOCITY_MS)


func _update_knock_up_stream(delta: float) -> void:
	knock_up_timer_sec = fposmod(knock_up_timer_sec + delta, KNOCK_UP_CYCLE_SEC)
	var time_until_eruption: float = KNOCK_UP_CYCLE_SEC - knock_up_timer_sec

	if time_until_eruption <= KNOCK_UP_ACTIVE_DURATION_SEC:
		var t_active: float = 1.0 - (time_until_eruption / KNOCK_UP_ACTIVE_DURATION_SEC)
		var pulse: float = sin(t_active * PI)
		_set_knock_up_phase("ERUPTING", KNOCK_UP_PEAK_VELOCITY_MS * maxf(0.35, pulse))
	elif time_until_eruption <= KNOCK_UP_ACTIVE_DURATION_SEC + 35.0:
		_set_knock_up_phase("WHIRLPOOL_DRAW", -18.0)
	else:
		_set_knock_up_phase("DORMANT", 0.0)

	# Apply upward geothermal stream acceleration if target vessel enters the Jaya stream column
	if knock_up_phase == "ERUPTING" and target_vessel != null:
		var vessel_surface_pos: Vector3 = target_vessel.global_position.normalized() * PLANET_RADIUS_M
		var dist_to_stream: float = vessel_surface_pos.distance_to(_knock_up_epicenter_world)
		var vessel_alt: float = target_vessel.global_position.length() - PLANET_RADIUS_M
		if dist_to_stream <= KNOCK_UP_RADIUS_M and vessel_alt < WHITE_WHITE_SEA_ALT_M:
			var up_dir: Vector3 = target_vessel.global_position.normalized()
			if target_vessel is RigidBody3D:
				(target_vessel as RigidBody3D).apply_central_force(up_dir * knock_up_current_velocity_ms * 120.0)
			else:
				target_vessel.global_position += up_dir * knock_up_current_velocity_ms * delta
			knock_up_stream_launched_vessel.emit(target_vessel.name, target_vessel.global_position.length() - PLANET_RADIUS_M)


func _set_knock_up_phase(new_phase: String, velocity_ms: float) -> void:
	knock_up_current_velocity_ms = velocity_ms
	if new_phase == knock_up_phase:
		return
	knock_up_phase = new_phase
	knock_up_stream_phase_changed.emit(new_phase, velocity_ms)
	if new_phase == "ERUPTING" and planet_sphere != null and planet_sphere.has_signal("knock_up_stream_erupted"):
		planet_sphere.knock_up_stream_erupted.emit(_knock_up_epicenter_world, velocity_ms)


func get_knock_up_stream_status() -> Dictionary:
	return {
		"epicenter_lat_deg": KNOCK_UP_LAT_DEG,
		"epicenter_lon_deg": KNOCK_UP_LON_DEG,
		"epicenter_world_pos": _knock_up_epicenter_world,
		"phase": knock_up_phase,
		"vertical_velocity_ms": knock_up_current_velocity_ms,
		"seconds_until_next_eruption": maxf(0.0, (KNOCK_UP_CYCLE_SEC - KNOCK_UP_ACTIVE_DURATION_SEC) - knock_up_timer_sec),
		"target_sky_layer_alt_m": WHITE_SEA_ALT_M,
		"upper_sky_layer_alt_m": WHITE_WHITE_SEA_ALT_M
	}


# ==============================================================================
# 7. CALM BELT 0.0 M/S WIND CLAMP & SEA KING EMERGENCE SPAWNER
# ==============================================================================
func _evaluate_vessel_environment(delta: float) -> void:
	if target_vessel == null:
		return

	var vessel_pos: Vector3 = target_vessel.global_position
	var has_seastone_keel: bool = bool(target_vessel.get("has_seastone_keel")) if "has_seastone_keel" in target_vessel else false
	var has_paddlewheel: bool = bool(target_vessel.get("has_paddlewheel_drive")) if "has_paddlewheel_drive" in target_vessel else false
	var has_coating: bool = bool(target_vessel.get("has_yarukiman_resin_coating")) if "has_yarukiman_resin_coating" in target_vessel else false

	# 1. Calm Belt Sea King emergence spawner
	if _is_in_calm_belt(vessel_pos):
		_sea_king_timer_sec += delta
		if not has_seastone_keel and _sea_king_timer_sec >= SEA_KING_SPAWN_INTERVAL_SEC:
			_sea_king_timer_sec = 0.0
			_spawn_calm_belt_sea_king(vessel_pos, has_paddlewheel)
	else:
		_sea_king_timer_sec = 0.0

	# 2. Abyssal -10,000m Fish-Man Island dual-bubble pressure check
	var abyss_eval: Dictionary = evaluate_abyss_environment(vessel_pos, has_coating)
	if abyss_eval["crush_hazard"]:
		abyssal_crush_warning.emit(target_vessel.name, abyss_eval["depth_m"], abyss_eval["pressure_atm"])


func _spawn_calm_belt_sea_king(vessel_pos: Vector3, has_paddlewheel: bool) -> void:
	var species_pool: Array[String] = [
		"Spotted Island-Eater Eel",
		"Horned Sea Serpent",
		"Colossal Armored Sea Rhino",
		"Abyssal Crowned Sea Dragon",
		"Five-Finned Leviathan"
	]
	var length_m: float = randf_range(500.0, 2_000.0)
	var up_dir: Vector3 = vessel_pos.normalized()
	var tangent: Vector3 = up_dir.cross(Vector3.UP)
	if tangent.length_squared() < 0.01:
		tangent = up_dir.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var angle: float = randf_range(0.0, TAU)
	var offset_dir: Vector3 = (tangent * cos(angle) + up_dir.cross(tangent).normalized() * sin(angle)).normalized()
	var nest_pos: Vector3 = (up_dir * (PLANET_RADIUS_M - 2_000.0)) + offset_dir * randf_range(350.0, 1_400.0)

	var sea_king := {
		"id": "sea_king_%d" % int(_sim_clock_sec * 10.0),
		"species": species_pool[randi() % species_pool.size()],
		"length_m": length_m,
		"spawn_depth_m": -2_000.0,
		"world_pos": nest_pos,
		"aggro": not has_paddlewheel
	}
	active_sea_kings.append(sea_king)
	if active_sea_kings.size() > MAX_ACTIVE_SEA_KINGS:
		active_sea_kings.pop_front()

	calm_belt_sea_king_emerged.emit(sea_king)
	if planet_sphere != null and planet_sphere.has_signal("calm_belt_sea_king_triggered"):
		planet_sphere.calm_belt_sea_king_triggered.emit(nest_pos, -2_000.0, length_m)


# ==============================================================================
# 8. PUFFING TOM & ROCKETMAN SEA TRAIN LIVE TRACK SIMULATION
# ==============================================================================
func _initialize_sea_trains() -> void:
	var network: Dictionary = GrandLineData.get_sea_train_network()
	var raw_stations: Array = network.get("stations", [])
	_sea_train_stations.clear()
	for st in raw_stations:
		if st is Dictionary:
			var copy_st: Dictionary = st.duplicate(true)
			copy_st["world_pos"] = GrandLineData.lat_lon_alt_to_vector3(
				float(st["lat_deg"]), float(st["lon_deg"]), 0.0
			)
			_sea_train_stations.append(copy_st)

	sea_train_states = {
		"puffing_tom": {
			"id": "puffing_tom",
			"name": "Puffing Tom",
			"progress": 0.0,
			"direction": 1.0,
			"speed_m_per_s": 45.0,
			"dwell_remaining_sec": 0.0,
			"current_station_index": 0,
			"world_pos": _sea_train_stations[0]["world_pos"] if not _sea_train_stations.is_empty() else Vector3.ZERO
		},
		"rocketman": {
			"id": "rocketman",
			"name": "Rocketman (Unstoppable Prototype)",
			"progress": 0.0,
			"direction": 1.0,
			"speed_m_per_s": 75.0,
			"dwell_remaining_sec": 0.0,
			"current_station_index": 0,
			"world_pos": _sea_train_stations[0]["world_pos"] if not _sea_train_stations.is_empty() else Vector3.ZERO
		}
	}


func _update_sea_trains(delta: float) -> void:
	if _sea_train_stations.size() < 2:
		return

	var seg_count: int = _sea_train_stations.size() - 1
	for train_id in sea_train_states.keys():
		var tr: Dictionary = sea_train_states[train_id]
		if float(tr["dwell_remaining_sec"]) > 0.0:
			tr["dwell_remaining_sec"] = maxf(0.0, float(tr["dwell_remaining_sec"]) - delta)
			continue

		# Compute approximate route arc length (~1,200 km from Water 7 Blue Station to Enies Lobby Dry Station)
		var total_track_m: float = 0.0
		for idx in range(seg_count):
			total_track_m += _sea_train_stations[idx]["world_pos"].distance_to(_sea_train_stations[idx + 1]["world_pos"])
		total_track_m = maxf(1.0, total_track_m)

		var step_norm: float = (float(tr["speed_m_per_s"]) * delta) / total_track_m
		var new_prog: float = float(tr["progress"]) + step_norm * float(tr["direction"])

		if new_prog >= 1.0:
			new_prog = 1.0
			tr["direction"] = -1.0
			if train_id == "puffing_tom":
				tr["dwell_remaining_sec"] = 12.0
		elif new_prog <= 0.0:
			new_prog = 0.0
			tr["direction"] = 1.0
			if train_id == "puffing_tom":
				tr["dwell_remaining_sec"] = 12.0

		tr["progress"] = new_prog
		var scaled: float = new_prog * float(seg_count)
		var seg_idx: int = clampi(int(floor(scaled)), 0, seg_count - 1)
		var seg_t: float = scaled - float(seg_idx)

		var p_a: Vector3 = _sea_train_stations[seg_idx]["world_pos"].normalized()
		var p_b: Vector3 = _sea_train_stations[seg_idx + 1]["world_pos"].normalized()
		var interp_pos: Vector3 = p_a.slerp(p_b, seg_t).normalized() * PLANET_RADIUS_M
		tr["world_pos"] = interp_pos

		var nearest_idx: int = seg_idx if seg_t < 0.5 else seg_idx + 1
		if nearest_idx != int(tr["current_station_index"]):
			tr["current_station_index"] = nearest_idx
			var st: Dictionary = _sea_train_stations[nearest_idx]
			sea_train_station_arrived.emit(train_id, String(st["id"]), String(st["name"]))

	if _puffing_tom_marker != null:
		_puffing_tom_marker.global_position = sea_train_states["puffing_tom"]["world_pos"]
	if _rocketman_marker != null:
		_rocketman_marker.global_position = sea_train_states["rocketman"]["world_pos"]


func get_sea_train_state(train_id: String = "puffing_tom") -> Dictionary:
	return sea_train_states.get(train_id, {}).duplicate(true)


# ==============================================================================
# 9. LIVE ZUNESHA (ZOU) & THRILLER BARK ORBITAL SYNC + RAIN-RUPTION
# ==============================================================================
func _update_zunesha_and_thriller_bark(_delta: float) -> void:
	zunesha_state = GrandLineData.get_zunesha_orbital_state(_sim_clock_sec)
	thriller_bark_state = GrandLineData.get_thriller_bark_drift_state(_sim_clock_sec)

	if _zunesha_marker != null:
		_zunesha_marker.global_position = zunesha_state["world_position"]

	# Twice-daily Zunesha Rain-ruption irrigation flood check
	var rain_phase: float = fposmod(_sim_clock_sec, RAIN_RUPTION_CYCLE_SEC)
	var is_raining: bool = rain_phase < RAIN_RUPTION_DURATION_SEC
	if is_raining != rain_ruption_active:
		rain_ruption_active = is_raining
		zunesha_rain_ruption_triggered.emit(zunesha_state["world_position"], rain_ruption_active)

	# Sync Zunesha's live spherical position with WorldRegistry Autoload (Vivre Card tracking)
	if has_node("/root/WorldRegistry"):
		var wr: Node = get_node("/root/WorldRegistry")
		var dyn: Variant = wr.get("dynamic_entities")
		if dyn is Dictionary and dyn.has("zunesha_zou"):
			dyn["zunesha_zou"]["world_pos"] = zunesha_state["world_position"]
		var by_id: Variant = wr.get("islands_by_id")
		if by_id is Dictionary and by_id.has("zou"):
			by_id["zou"]["lat_deg"] = zunesha_state["lat_deg"]
			by_id["zou"]["lon_deg"] = zunesha_state["lon_deg"]
			by_id["zou"]["world_pos"] = zunesha_state["world_position"]


# ==============================================================================
# 10. ABYSSAL -10,000M FISH-MAN ISLAND BUBBLE PRESSURE & MARINE SNOW
# ==============================================================================
func evaluate_abyss_environment(world_pos: Vector3, has_yarukiman_resin_coating: bool) -> Dictionary:
	var coords: Dictionary = _world_to_lat_lon_alt(world_pos)
	var alt_m: float = float(coords["alt_m"])
	var depth_m: float = maxf(0.0, -alt_m)
	# Hydrostatic pressure: 1 atm at surface + ~1 atm per 10 meters depth (~1,001 atm at -10,000m)
	var pressure_atm: float = 1.0 + (depth_m / 10.0)
	var inside_fmi_cavern: bool = _is_inside_fish_man_island_bubble(world_pos, alt_m)
	var crush_hazard: bool = (depth_m > 300.0) and (not has_yarukiman_resin_coating) and (not inside_fmi_cavern)
	var marine_snow_density: float = clampf((depth_m - 1_000.0) / 6_000.0, 0.0, 1.0)
	var eve_tree_glow: float = 1.0 if inside_fmi_cavern else clampf(1.0 - absf(alt_m - ABYSS_FLOOR_ALT_M) / 4_000.0, 0.0, 0.8)

	return {
		"alt_m": alt_m,
		"depth_m": depth_m,
		"pressure_atm": pressure_atm,
		"inside_double_bubble": inside_fmi_cavern,
		"crush_hazard": crush_hazard,
		"marine_snow_density": marine_snow_density,
		"sunlight_tree_eve_luminance": eve_tree_glow
	}


func _is_inside_fish_man_island_bubble(world_pos: Vector3, alt_m: float) -> bool:
	if alt_m > -7_500.0:
		return false
	var fmi_center: Vector3 = GrandLineData.lat_lon_alt_to_vector3(0.0, 180.0, ABYSS_FLOOR_ALT_M)
	return world_pos.distance_to(fmi_center) <= 22_000.0


# ==============================================================================
# 11. CAMERA-RELATIVE SHADER UNIFORM SYNCHRONIZATION & HELPERS
# ==============================================================================
func _sync_shader_uniforms() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	var cam_pos: Vector3 = cam.global_position if cam != null else (
		target_vessel.global_position if target_vessel != null else Vector3(PLANET_RADIUS_M, 0.0, 0.0)
	)
	var local_up: Vector3 = cam_pos.normalized()
	var weather_eval: Dictionary = evaluate_weather_at_world_pos(cam_pos)
	var abyss_eval: Dictionary = evaluate_abyss_environment(cam_pos, true)
	var cam_alt_m: float = cam_pos.length() - PLANET_RADIUS_M
	var sky_blend: float = clampf((cam_alt_m - 5_500.0) / 2_500.0, 0.0, 1.0)

	if ocean_shader_material != null:
		var chunk_origin: Vector3 = local_up * PLANET_RADIUS_M
		var offset: Vector3 = chunk_origin - cam_pos
		ocean_shader_material.set_shader_parameter("camera_relative_chunk_offset", offset)
		ocean_shader_material.set_shader_parameter("u_chunk_camera_offset", offset)
		ocean_shader_material.set_shader_parameter("u_camera_planet_up", local_up)
		ocean_shader_material.set_shader_parameter("u_planet_radius", PLANET_RADIUS_M)
		ocean_shader_material.set_shader_parameter("u_time", _sim_clock_sec)
		ocean_shader_material.set_shader_parameter("u_calm_belt_factor", 1.0 if weather_eval["in_calm_belt"] else 0.0)
		ocean_shader_material.set_shader_parameter("u_storm_intensity", float(weather_eval["storm_intensity"]))
		ocean_shader_material.set_shader_parameter("u_sky_sea_blend", sky_blend)
		ocean_shader_material.set_shader_parameter("u_abyss_depth_factor", float(abyss_eval["marine_snow_density"]))
		ocean_shader_material.set_shader_parameter("u_knock_up_vortex", 1.0 if knock_up_phase == "ERUPTING" else 0.0)

	if terrain_shader_material != null:
		var terrain_origin: Vector3 = local_up * PLANET_RADIUS_M
		var t_offset: Vector3 = terrain_origin - cam_pos
		terrain_shader_material.set_shader_parameter("camera_relative_chunk_offset", t_offset)
		terrain_shader_material.set_shader_parameter("u_chunk_camera_offset", t_offset)
		terrain_shader_material.set_shader_parameter("u_camera_planet_up", local_up)
		terrain_shader_material.set_shader_parameter("u_planet_radius", PLANET_RADIUS_M)
		terrain_shader_material.set_shader_parameter("u_altitude_m", cam_alt_m)


func _world_to_lat_lon_alt(world_pos: Vector3) -> Dictionary:
	if planet_sphere != null and planet_sphere.has_method("world_to_lat_lon_alt"):
		return planet_sphere.world_to_lat_lon_alt(world_pos)
	var r: float = world_pos.length()
	if r < 0.001:
		return {"lat_deg": 0.0, "lon_deg": 0.0, "alt_m": -PLANET_RADIUS_M}
	var u: Vector3 = world_pos / r
	return {
		"lat_deg": rad_to_deg(asin(clampf(u.y, -1.0, 1.0))),
		"lon_deg": rad_to_deg(atan2(u.z, u.x)),
		"alt_m": r - PLANET_RADIUS_M
	}


func _is_in_calm_belt(world_pos: Vector3) -> bool:
	if planet_sphere != null and planet_sphere.has_method("classify_global_coordinates"):
		var info: Dictionary = planet_sphere.classify_global_coordinates(world_pos)
		return bool(info.get("is_calm_belt", false))
	var u: Vector3 = world_pos.normalized()
	var gl_normal := Vector3(0.0, cos(deg_to_rad(-45.0)), -sin(deg_to_rad(-45.0))).normalized()
	var dist_gl_m: float = absf(PLANET_RADIUS_M * asin(clampf(u.dot(gl_normal), -1.0, 1.0)))
	return dist_gl_m > 300_000.0 and dist_gl_m <= 450_000.0
