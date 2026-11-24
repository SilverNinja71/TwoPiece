class_name GrandLineEnemyDirector
extends Node3D
## Grand Line Enemy AI, Calm Belt Sea King Visual Spawner & Yonko Patrol Director
## Project "Blue Planet" — Godot 4.3+ Floating-Origin Compatible
##
## Spawns and animates real procedural 3D naval & monster encounters around the player:
##   1. Calm Belt Sea Kings (500 m - 2,000 m multi-segment breaching sea monsters)
##   2. Marine Patrol Battleships & Buster Call Flagships (Sabaody, Enies Lobby, Marineford, New Marineford)
##   3. Yonko Territory Fleet Patrols (Totto Land Tart Ships, Wano Beast Pirate Galleons, Hachinosu Armada)

signal sea_king_breached(encounter_id: String, species: String, length_m: float, local_pos: Vector3)
signal naval_patrol_engaged(encounter_id: String, faction: String, ship_name: String)
signal naval_cannon_volley_fired(encounter_id: String, target_local_pos: Vector3, projectile_count: int)
signal enemy_defeated(encounter_id: String, faction: String, bounty_reward_beli: int)

const PLANET_RADIUS_M: float = 16_000_000.0
const PATROL_STREAM_RADIUS_M: float = 180_000.0
const SEA_KING_COOLDOWN_SEC: float = 18.0
const MAX_ACTIVE_SEA_KINGS: int = 4
const CANNON_PROJECTILE_SPEED_MS: float = 260.0

enum FactionType {
	CALM_BELT_SEA_KING = 0,
	MARINE_PATROL = 1,
	BUSTER_CALL_FLAGSHIP = 2,
	BIG_MOM_TART_SHIP = 3,
	BEAST_PIRATE_GALLEON = 4,
	BLACKBEARD_ARMADA = 5
}

@export var auto_update: bool = true
@export var patrol_stream_radius_m: float = PATROL_STREAM_RADIUS_M
@export var sea_king_breach_interval_sec: float = SEA_KING_COOLDOWN_SEC
@export var enable_cannon_volleys: bool = true

var _sim_ref: Node = null
var _planet_sphere_ref: Node = null
var _ship_ref: Node3D = null
var _player_ref: Node3D = null
var _combat_sys_ref: Node = null
var _audio_ref: Node = null

var _patrol_blueprints: Array[Dictionary] = []
var _active_naval_encounters: Dictionary = {} # encounter_id -> Dictionary
var _active_sea_kings: Array[Dictionary] = []
var _active_projectiles: Array[Dictionary] = []

var _sea_king_spawn_timer: float = 0.0
var _stream_refresh_timer: float = 0.0
var _clock_sec: float = 0.0


# ==============================================================================
# 1. LIFECYCLE & REFERENCES
# ==============================================================================
func _ready() -> void:
	name = "GrandLineEnemyDirector"
	_resolve_scene_references()
	_connect_signals()
	_initialize_patrol_blueprints()
	call_deferred("refresh_naval_patrols")


func _process(delta: float) -> void:
	if not auto_update:
		return
	_clock_sec += delta
	_stream_refresh_timer += delta
	if _stream_refresh_timer >= 0.75:
		_stream_refresh_timer = 0.0
		refresh_naval_patrols()

	_update_calm_belt_sea_king_spawner(delta)
	_update_sea_king_animations(delta)
	_update_naval_patrol_ai(delta)
	_update_cannon_projectiles(delta)


func _resolve_scene_references() -> void:
	var parent: Node = get_parent()
	if parent != null:
		_sim_ref = parent.get_node_or_null("GrandLineSimulator")
		_planet_sphere_ref = parent.get_node_or_null("PlanetSphere")
		_ship_ref = parent.get_node_or_null("BuoyantShipVessel") as Node3D
		_player_ref = parent.get_node_or_null("SphericalPlayer") as Node3D
		_combat_sys_ref = parent.get_node_or_null("CombatAndDevilFruitSystem")
		_audio_ref = parent.get_node_or_null("ProceduralAudioManager")


func _connect_signals() -> void:
	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	if fo != null and fo.has_signal("origin_rebased"):
		if not fo.origin_rebased.is_connected(_on_origin_rebased):
			fo.origin_rebased.connect(_on_origin_rebased)

	if _sim_ref != null and _sim_ref.has_signal("calm_belt_sea_king_emerged"):
		if not _sim_ref.calm_belt_sea_king_emerged.is_connected(_on_simulator_sea_king_emerged):
			_sim_ref.calm_belt_sea_king_emerged.connect(_on_simulator_sea_king_emerged)


func _on_origin_rebased(delta_local: Vector3) -> void:
	for sk in _active_sea_kings:
		var node_sk: Node3D = sk.get("node") as Node3D
		if is_instance_valid(node_sk):
			node_sk.position -= delta_local
	for enc_id in _active_naval_encounters.keys():
		var enc: Dictionary = _active_naval_encounters[enc_id]
		var node_ship: Node3D = enc.get("node") as Node3D
		if is_instance_valid(node_ship):
			node_ship.position -= delta_local
	for proj in _active_projectiles:
		var node_p: Node3D = proj.get("node") as Node3D
		if is_instance_valid(node_p):
			node_p.position -= delta_local
	refresh_naval_patrols()


func _on_simulator_sea_king_emerged(sea_king_data: Dictionary) -> void:
	var length_m: float = float(sea_king_data.get("length_m", 950.0))
	var species: String = str(sea_king_data.get("species", "Abyssal Crowned Sea Dragon"))
	spawn_calm_belt_sea_king_near_origin(length_m, species)


# ==============================================================================
# 2. FLOATING-ORIGIN 64-BIT COORDINATE HELPERS
# ==============================================================================
func _get_origin_coords() -> Dictionary:
	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	if fo != null:
		var lat: Variant = fo.get("origin_lat_deg")
		var lon: Variant = fo.get("origin_lon_deg")
		var alt: Variant = fo.get("origin_alt_m")
		if lat != null and lon != null:
			return {
				"lat_deg": float(lat),
				"lon_deg": float(lon),
				"alt_m": float(alt) if alt != null else 0.0
			}
	return {"lat_deg": 52.0, "lon_deg": 74.0, "alt_m": 0.0}


func _lat_lon_alt_to_local32(lat_deg: float, lon_deg: float, alt_m: float) -> Vector3:
	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	if fo != null and fo.has_method("lat_lon_alt_to_local32"):
		return fo.call("lat_lon_alt_to_local32", lat_deg, lon_deg, alt_m)
	var orig: Dictionary = _get_origin_coords()
	var o_w64: PackedFloat64Array = _lat_lon_alt_to_world64(orig["lat_deg"], orig["lon_deg"], orig["alt_m"])
	var t_w64: PackedFloat64Array = _lat_lon_alt_to_world64(lat_deg, lon_deg, alt_m)
	return Vector3(t_w64[0] - o_w64[0], t_w64[1] - o_w64[1], t_w64[2] - o_w64[2])


func _get_local_up_at_origin() -> Vector3:
	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	if fo != null and fo.has_method("get_local_up_at_origin"):
		return fo.call("get_local_up_at_origin")
	var orig: Dictionary = _get_origin_coords()
	return _surface_normal(orig["lat_deg"], orig["lon_deg"])


static func _lat_lon_alt_to_world64(lat_deg: float, lon_deg: float, alt_m: float) -> PackedFloat64Array:
	var lat_r: float = deg_to_rad(clampf(lat_deg, -90.0, 90.0))
	var lon_r: float = deg_to_rad(lon_deg)
	var r: float = PLANET_RADIUS_M + alt_m
	var cos_lat: float = cos(lat_r)
	return PackedFloat64Array([r * cos_lat * cos(lon_r), r * sin(lat_r), r * cos_lat * sin(lon_r)])


static func _surface_normal(lat_deg: float, lon_deg: float) -> Vector3:
	var lat_r: float = deg_to_rad(clampf(lat_deg, -90.0, 90.0))
	var lon_r: float = deg_to_rad(lon_deg)
	var cos_lat: float = cos(lat_r)
	return Vector3(cos_lat * cos(lon_r), sin(lat_r), cos_lat * sin(lon_r)).normalized()


static func _great_circle_distance_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var p1: Vector3 = _surface_normal(lat1, lon1)
	var p2: Vector3 = _surface_normal(lat2, lon2)
	var angle: float = atan2(p1.cross(p2).length(), p1.dot(p2))
	return PLANET_RADIUS_M * angle


static func _basis_from_up_and_forward(up_dir: Vector3, forward_hint: Vector3) -> Basis:
	var y_axis: Vector3 = up_dir.normalized()
	var z_axis: Vector3 = (forward_hint - y_axis * forward_hint.dot(y_axis))
	if z_axis.length_squared() < 0.0001:
		var fallback := Vector3.FORWARD if absf(y_axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
		z_axis = fallback - y_axis * fallback.dot(y_axis)
	z_axis = z_axis.normalized()
	var x_axis: Vector3 = y_axis.cross(z_axis).normalized()
	return Basis(x_axis, y_axis, z_axis).orthonormalized()


func _get_player_or_ship_local_pos() -> Vector3:
	if _ship_ref != null and is_instance_valid(_ship_ref):
		return _ship_ref.position
	if _player_ref != null and is_instance_valid(_player_ref):
		return _player_ref.position
	return Vector3.ZERO


func _is_in_calm_belt_at_origin() -> bool:
	var orig: Dictionary = _get_origin_coords()
	var u: Vector3 = _surface_normal(orig["lat_deg"], orig["lon_deg"])
	if _planet_sphere_ref != null and _planet_sphere_ref.has_method("classify_global_coordinates"):
		var world_vec := u * (PLANET_RADIUS_M + float(orig["alt_m"]))
		var info: Dictionary = _planet_sphere_ref.call("classify_global_coordinates", world_vec)
		return bool(info.get("is_calm_belt", false))
	var gl_normal := Vector3(0.0, cos(deg_to_rad(-45.0)), -sin(deg_to_rad(-45.0))).normalized()
	var dist_gl_m: float = absf(PLANET_RADIUS_M * asin(clampf(u.dot(gl_normal), -1.0, 1.0)))
	return dist_gl_m > 300_000.0 and dist_gl_m <= 450_000.0


func _ship_has_seastone_keel() -> bool:
	if _ship_ref != null and "has_seastone_keel" in _ship_ref:
		return bool(_ship_ref.get("has_seastone_keel"))
	return false


# ==============================================================================
# 3. CALM BELT SEA KINGS (500m - 2,000m MULTI-SEGMENT SERPENTINE SPAWNER)
# ==============================================================================
func _update_calm_belt_sea_king_spawner(delta: float) -> void:
	if not _is_in_calm_belt_at_origin() or _ship_has_seastone_keel():
		_sea_king_spawn_timer = 0.0
		return

	_sea_king_spawn_timer += delta
	if _sea_king_spawn_timer >= sea_king_breach_interval_sec and _active_sea_kings.size() < MAX_ACTIVE_SEA_KINGS:
		_sea_king_spawn_timer = 0.0
		var species_pool: Array[String] = [
			"Spotted Island-Eater Eel",
			"Horned Sea Serpent",
			"Abyssal Crowned Sea Dragon",
			"Colossal Armored Sea Rhino",
			"Five-Finned Leviathan"
		]
		var chosen: String = species_pool[randi() % species_pool.size()]
		spawn_calm_belt_sea_king_near_origin(randf_range(500.0, 2_000.0), chosen)


## Spawns a real multi-segment serpentine Sea King (500 m to 2,000 m) that breaches vertically out of the Calm Belt.
func spawn_calm_belt_sea_king_near_origin(length_m: float = 900.0, species: String = "Abyssal Crowned Sea Dragon") -> Dictionary:
	var clamped_len: float = clampf(length_m, 500.0, 2_000.0)
	var enc_id: String = "sea_king_%d_%d" % [int(_clock_sec * 100.0), randi() % 9999]
	var up_dir: Vector3 = _get_local_up_at_origin()
	var basis_up: Basis = _basis_from_up_and_forward(up_dir, Vector3.FORWARD)
	var target_center: Vector3 = _get_player_or_ship_local_pos()
	var angle: float = randf_range(0.0, TAU)
	var dist_offset: float = randf_range(650.0, 1_450.0)
	var surf_offset: Vector3 = (basis_up.x * cos(angle) + basis_up.z * sin(angle)) * dist_offset
	var spawn_pos: Vector3 = target_center + surf_offset - up_dir * (clamped_len * 0.45)

	var sk_root := _build_sea_king_mesh_rig(enc_id, species, clamped_len)
	sk_root.position = spawn_pos
	sk_root.basis = _basis_from_up_and_forward(up_dir, -surf_offset.normalized())
	add_child(sk_root)

	var rec := {
		"id": enc_id,
		"faction": FactionType.CALM_BELT_SEA_KING,
		"faction_name": "Calm Belt Sea King",
		"species": species,
		"length_m": clamped_len,
		"hp": clamped_len * 2.5,
		"max_hp": clamped_len * 2.5,
		"bounty_beli": int(clamped_len * 10_000.0),
		"node": sk_root,
		"base_surf_pos": target_center + surf_offset,
		"breach_progress": 0.0,
		"phase_offset": randf_range(0.0, TAU)
	}
	_active_sea_kings.append(rec)
	if _active_sea_kings.size() > MAX_ACTIVE_SEA_KINGS:
		var oldest: Dictionary = _active_sea_kings.pop_front()
		if is_instance_valid(oldest.get("node")):
			oldest["node"].queue_free()

	sea_king_breached.emit(enc_id, species, clamped_len, spawn_pos)
	return rec


func _build_sea_king_mesh_rig(enc_id: String, species: String, length_m: float) -> Node3D:
	var root := Node3D.new()
	root.name = enc_id
	var seg_count: int = 16
	var seg_spacing: float = length_m / float(seg_count)
	var body_radius: float = clampf(length_m * 0.032, 14.0, 58.0)

	var scale_mat := StandardMaterial3D.new()
	scale_mat.albedo_color = Color(0.11, 0.34, 0.32) if species.contains("Serpent") else Color(0.18, 0.24, 0.42)
	scale_mat.roughness = 0.45
	scale_mat.metallic = 0.15

	var fin_mat := StandardMaterial3D.new()
	fin_mat.albedo_color = Color(0.76, 0.28, 0.22)
	fin_mat.roughness = 0.6

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(1.0, 0.85, 0.15)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.55, 0.1)
	eye_mat.emission_energy_multiplier = 2.4

	var segments_holder := Node3D.new()
	segments_holder.name = "SpineSegments"
	root.add_child(segments_holder)

	for i in range(seg_count):
		var frac: float = float(i) / float(seg_count - 1)
		var seg_node := Node3D.new()
		seg_node.name = "Seg_%d" % i
		seg_node.position = Vector3(0.0, -float(i) * seg_spacing * 0.55, -float(i) * seg_spacing * 0.45)

		var taper: float = 1.0 - frac * 0.72
		var seg_mi := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = body_radius * taper
		sph.height = seg_spacing * 1.15
		sph.radial_segments = 12
		sph.rings = 8
		seg_mi.mesh = sph
		seg_mi.material_override = scale_mat
		seg_node.add_child(seg_mi)

		# Dorsal fin crest on alternating segments
		if i % 2 == 1 and i < seg_count - 2:
			var fin := MeshInstance3D.new()
			var fbox := BoxMesh.new()
			fbox.size = Vector3(body_radius * 0.18, body_radius * 1.1 * taper, seg_spacing * 0.75)
			fin.mesh = fbox
			fin.position = Vector3(0.0, body_radius * 0.85 * taper, 0.0)
			fin.material_override = fin_mat
			seg_node.add_child(fin)

		# Head features on segment 0 (snout, glowing eyes, dorsal horns)
		if i == 0:
			var jaw := MeshInstance3D.new()
			var jbox := BoxMesh.new()
			jbox.size = Vector3(body_radius * 1.45, body_radius * 0.9, body_radius * 2.1)
			jaw.mesh = jbox
			jaw.position = Vector3(0.0, body_radius * 0.25, body_radius * 0.85)
			jaw.material_override = scale_mat
			seg_node.add_child(jaw)

			for side in [-1.0, 1.0]:
				var eye := MeshInstance3D.new()
				var esph := SphereMesh.new()
				esph.radius = body_radius * 0.24
				esph.height = esph.radius * 2.0
				eye.mesh = esph
				eye.position = Vector3(side * body_radius * 0.72, body_radius * 0.55, body_radius * 1.15)
				eye.material_override = eye_mat
				seg_node.add_child(eye)

		segments_holder.add_child(seg_node)

	var lbl := Label3D.new()
	lbl.name = "EncounterLabel"
	lbl.text = "%s (%dm)" % [species, int(length_m)]
	lbl.position = Vector3(0.0, body_radius * 2.6, 0.0)
	lbl.pixel_size = 0.8
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(1.0, 0.45, 0.35)
	root.add_child(lbl)

	return root


func _update_sea_king_animations(delta: float) -> void:
	var up_dir: Vector3 = _get_local_up_at_origin()
	for sk in _active_sea_kings:
		var root: Node3D = sk.get("node") as Node3D
		if not is_instance_valid(root):
			continue
		sk["breach_progress"] = minf(1.0, float(sk["breach_progress"]) + delta * 0.28)
		var b_t: float = float(sk["breach_progress"])
		var length_m: float = float(sk["length_m"])
		var base_surf: Vector3 = sk["base_surf_pos"]

		# Breach vertically upward out of ocean, then coil dynamically at the surface
		var breach_h: float = lerpf(-length_m * 0.45, length_m * 0.16, smoothstep(0.0, 1.0, b_t))
		var bob: float = sin(_clock_sec * 1.4 + float(sk["phase_offset"])) * 16.0
		root.position = base_surf + up_dir * (breach_h + bob)

		var holder: Node3D = root.get_node_or_null("SpineSegments") as Node3D
		if holder != null:
			var seg_idx: int = 0
			for seg in holder.get_children():
				var wave_phase: float = _clock_sec * 3.1 + float(sk["phase_offset"]) - float(seg_idx) * 0.45
				seg.position.x = sin(wave_phase) * clampf(length_m * 0.045, 18.0, 75.0)
				seg.rotation.y = cos(wave_phase) * 0.25
				seg_idx += 1


# ==============================================================================
# 4. MARINE PATROL BATTLESHIPS & YONKO TERRITORY FLEET PATROLS
# ==============================================================================
func _initialize_patrol_blueprints() -> void:
	_patrol_blueprints = [
		# --- MARINE PATROLS & BUSTER CALL FLAGSHIPS ---
		{
			"id": "marine_sabaody_garrison_1",
			"name": "Marine G-66 Sabaody Cruiser",
			"faction": FactionType.MARINE_PATROL,
			"faction_name": "Marines",
			"lat_deg": 0.4, "lon_deg": 178.1, "alt_m": 0.0,
			"patrol_radius_m": 6_500.0, "speed_ms": 22.0, "aggro_radius_m": 4_200.0,
			"max_hp": 450.0, "bounty_beli": 15_000_000, "hull_scale": 1.0
		},
		{
			"id": "marine_enies_lobby_buster_flagship",
			"name": "Buster Call Golden Flagship",
			"faction": FactionType.BUSTER_CALL_FLAGSHIP,
			"faction_name": "Marine Buster Call Fleet",
			"lat_deg": -7.1, "lon_deg": 124.2, "alt_m": 0.0,
			"patrol_radius_m": 8_000.0, "speed_ms": 25.0, "aggro_radius_m": 5_500.0,
			"max_hp": 1_200.0, "bounty_beli": 60_000_000, "hull_scale": 1.45
		},
		{
			"id": "marine_marineford_vanguard",
			"name": "Marineford Ox-Bell Battleship",
			"faction": FactionType.BUSTER_CALL_FLAGSHIP,
			"faction_name": "Marine Headquarters",
			"lat_deg": 2.6, "lon_deg": 173.2, "alt_m": 0.0,
			"patrol_radius_m": 7_500.0, "speed_ms": 24.0, "aggro_radius_m": 5_000.0,
			"max_hp": 1_000.0, "bounty_beli": 50_000_000, "hull_scale": 1.35
		},
		{
			"id": "marine_new_marineford_interceptor",
			"name": "New Marineford Interceptor",
			"faction": FactionType.MARINE_PATROL,
			"faction_name": "New World Marines",
			"lat_deg": 0.5, "lon_deg": -178.5, "alt_m": 0.0,
			"patrol_radius_m": 7_000.0, "speed_ms": 26.0, "aggro_radius_m": 4_800.0,
			"max_hp": 650.0, "bounty_beli": 30_000_000, "hull_scale": 1.15
		},
		{
			"id": "marine_g5_punk_hazard_patrol",
			"name": "Marine G-5 Cruiser",
			"faction": FactionType.MARINE_PATROL,
			"faction_name": "Marine Base G-5",
			"lat_deg": 2.2, "lon_deg": -162.0, "alt_m": 0.0,
			"patrol_radius_m": 6_000.0, "speed_ms": 24.0, "aggro_radius_m": 4_200.0,
			"max_hp": 550.0, "bounty_beli": 25_000_000, "hull_scale": 1.05
		},
		# --- YONKO TERRITORY FLEET PATROLS ---
		{
			"id": "totto_land_tart_ship_alpha",
			"name": "Big Mom Pirates Tart Ship #14",
			"faction": FactionType.BIG_MOM_TART_SHIP,
			"faction_name": "Big Mom Pirates (Totto Land)",
			"lat_deg": -7.4, "lon_deg": -114.0, "alt_m": 0.0,
			"patrol_radius_m": 11_000.0, "speed_ms": 24.0, "aggro_radius_m": 5_800.0,
			"max_hp": 900.0, "bounty_beli": 85_000_000, "hull_scale": 1.25
		},
		{
			"id": "totto_land_tart_ship_cacao",
			"name": "Cacao Blockade Tart Ship",
			"faction": FactionType.BIG_MOM_TART_SHIP,
			"faction_name": "Big Mom Pirates (Totto Land)",
			"lat_deg": -7.7, "lon_deg": -114.5, "alt_m": 0.0,
			"patrol_radius_m": 9_500.0, "speed_ms": 26.0, "aggro_radius_m": 5_500.0,
			"max_hp": 850.0, "bounty_beli": 75_000_000, "hull_scale": 1.2
		},
		{
			"id": "wano_beast_pirate_galleon",
			"name": "Beast Pirates Onigashima Galleon",
			"faction": FactionType.BEAST_PIRATE_GALLEON,
			"faction_name": "Beast Pirates (Wano Country)",
			"lat_deg": 6.8, "lon_deg": -82.0, "alt_m": 0.0,
			"patrol_radius_m": 10_500.0, "speed_ms": 25.0, "aggro_radius_m": 6_000.0,
			"max_hp": 1_100.0, "bounty_beli": 120_000_000, "hull_scale": 1.35
		},
		{
			"id": "hachinosu_blackbeard_armada",
			"name": "Blackbeard Armada Log-Galleon",
			"faction": FactionType.BLACKBEARD_ARMADA,
			"faction_name": "Blackbeard Pirates (Hachinosu)",
			"lat_deg": -9.1, "lon_deg": -55.0, "alt_m": 0.0,
			"patrol_radius_m": 11_500.0, "speed_ms": 27.0, "aggro_radius_m": 6_200.0,
			"max_hp": 1_250.0, "bounty_beli": 150_000_000, "hull_scale": 1.4
		}
	]


func refresh_naval_patrols() -> void:
	var orig: Dictionary = _get_origin_coords()
	var o_lat: float = float(orig["lat_deg"])
	var o_lon: float = float(orig["lon_deg"])

	var desired: Dictionary = {}
	for bp in _patrol_blueprints:
		var dist_m: float = _great_circle_distance_m(o_lat, o_lon, float(bp["lat_deg"]), float(bp["lon_deg"]))
		if dist_m <= patrol_stream_radius_m:
			desired[bp["id"]] = bp

	# Remove out-of-range naval patrols
	var to_remove: Array[String] = []
	for active_id in _active_naval_encounters.keys():
		if not desired.has(active_id):
			to_remove.append(active_id)
	for rem_id in to_remove:
		var enc: Dictionary = _active_naval_encounters[rem_id]
		if is_instance_valid(enc.get("node")):
			enc["node"].queue_free()
		_active_naval_encounters.erase(rem_id)

	# Spawn newly in-range naval patrols
	for enc_id in desired.keys():
		if _active_naval_encounters.has(enc_id):
			continue
		var bp: Dictionary = desired[enc_id]
		var ship_node: Node3D = _build_warship_mesh(bp)
		var anchor_local: Vector3 = _lat_lon_alt_to_local32(float(bp["lat_deg"]), float(bp["lon_deg"]), float(bp["alt_m"]))
		ship_node.position = anchor_local
		add_child(ship_node)

		var enc := bp.duplicate(true)
		enc["node"] = ship_node
		enc["hp"] = float(bp["max_hp"])
		enc["orbit_angle"] = randf_range(0.0, TAU)
		enc["cannon_cooldown_sec"] = randf_range(1.0, 3.5)
		enc["engaged"] = false
		_active_naval_encounters[enc_id] = enc


func _build_warship_mesh(bp: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = str(bp["id"])
	var s: float = float(bp.get("hull_scale", 1.0))
	var faction: int = int(bp["faction"])

	var hull_col := Color(0.28, 0.30, 0.34)
	var trim_col := Color(0.18, 0.42, 0.85)
	var sail_col := Color(0.95, 0.96, 0.98)

	match faction:
		FactionType.BUSTER_CALL_FLAGSHIP:
			hull_col = Color(0.32, 0.24, 0.16)
			trim_col = Color(0.88, 0.72, 0.22)
		FactionType.BIG_MOM_TART_SHIP:
			hull_col = Color(0.88, 0.48, 0.62)
			trim_col = Color(0.98, 0.92, 0.78)
			sail_col = Color(0.98, 0.72, 0.82)
		FactionType.BEAST_PIRATE_GALLEON:
			hull_col = Color(0.18, 0.16, 0.20)
			trim_col = Color(0.68, 0.18, 0.18)
			sail_col = Color(0.22, 0.20, 0.24)
		FactionType.BLACKBEARD_ARMADA:
			hull_col = Color(0.34, 0.22, 0.12)
			trim_col = Color(0.12, 0.12, 0.14)
			sail_col = Color(0.16, 0.16, 0.18)

	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = hull_col
	hull_mat.roughness = 0.78

	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = trim_col
	trim_mat.metallic = 0.35

	var sail_mat := StandardMaterial3D.new()
	sail_mat.albedo_color = sail_col
	sail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Main hull
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	var hbox := BoxMesh.new()
	hbox.size = Vector3(14.0 * s, 7.5 * s, 52.0 * s)
	hull.mesh = hbox
	hull.position = Vector3(0.0, 2.2 * s, 0.0)
	hull.material_override = hull_mat
	root.add_child(hull)

	# Stern castle / Tart cake tier
	var stern := MeshInstance3D.new()
	stern.name = "SternSuperstructure"
	var sbox := BoxMesh.new()
	sbox.size = Vector3(13.0 * s, 8.0 * s, 14.0 * s)
	stern.mesh = sbox
	stern.position = Vector3(0.0, 9.0 * s, -16.0 * s)
	stern.material_override = trim_mat
	root.add_child(stern)

	# Twin masts & square sails
	for m_z in [-4.0 * s, 12.0 * s]:
		var mast := MeshInstance3D.new()
		var mcyl := CylinderMesh.new()
		mcyl.top_radius = 0.55 * s
		mcyl.bottom_radius = 0.85 * s
		mcyl.height = 30.0 * s
		mast.mesh = mcyl
		mast.position = Vector3(0.0, 18.0 * s, m_z)
		mast.material_override = hull_mat
		root.add_child(mast)

		var sail := MeshInstance3D.new()
		var pmesh := BoxMesh.new()
		pmesh.size = Vector3(18.0 * s, 14.0 * s, 0.35 * s)
		sail.mesh = pmesh
		sail.position = Vector3(0.0, 20.0 * s, m_z + 0.6 * s)
		sail.material_override = sail_mat
		root.add_child(sail)

	# Twin broadside cannons on port & starboard
	for side in [-1.0, 1.0]:
		for c_z in [-6.0 * s, 6.0 * s]:
			var cannon := MeshInstance3D.new()
			var ccyl := CylinderMesh.new()
			ccyl.top_radius = 0.45 * s
			ccyl.bottom_radius = 0.55 * s
			ccyl.height = 4.2 * s
			cannon.mesh = ccyl
			cannon.rotation.z = deg_to_rad(90.0)
			cannon.position = Vector3(side * 8.0 * s, 5.2 * s, c_z)
			cannon.material_override = trim_mat
			root.add_child(cannon)

	var lbl := Label3D.new()
	lbl.name = "ShipLabel"
	lbl.text = "%s\n[%s]" % [str(bp["name"]), str(bp["faction_name"])]
	lbl.position = Vector3(0.0, 38.0 * s, 0.0)
	lbl.pixel_size = 0.45
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(1.0, 0.85, 0.42)
	root.add_child(lbl)

	return root


func _update_naval_patrol_ai(delta: float) -> void:
	var target_pos: Vector3 = _get_player_or_ship_local_pos()
	var up_dir: Vector3 = _get_local_up_at_origin()
	var up_basis: Basis = _basis_from_up_and_forward(up_dir, Vector3.FORWARD)

	for enc_id in _active_naval_encounters.keys():
		var enc: Dictionary = _active_naval_encounters[enc_id]
		var ship_node: Node3D = enc.get("node") as Node3D
		if not is_instance_valid(ship_node) or float(enc["hp"]) <= 0.0:
			continue

		var anchor_local: Vector3 = _lat_lon_alt_to_local32(float(enc["lat_deg"]), float(enc["lon_deg"]), float(enc["alt_m"]))
		var dist_to_player: float = ship_node.position.distance_to(target_pos)
		var aggro_r: float = float(enc["aggro_radius_m"])

		var heading: Vector3
		if dist_to_player <= aggro_r:
			if not bool(enc["engaged"]):
				enc["engaged"] = true
				naval_patrol_engaged.emit(enc_id, str(enc["faction_name"]), str(enc["name"]))

			# Circle-strafe broadside pursuit around player
			var to_player: Vector3 = (target_pos - ship_node.position)
			to_player -= up_dir * to_player.dot(up_dir)
			var tangent_broadside: Vector3 = up_dir.cross(to_player).normalized()
			if dist_to_player > 450.0:
				heading = (to_player.normalized() * 0.6 + tangent_broadside * 0.4).normalized()
			else:
				heading = tangent_broadside
			ship_node.position += heading * float(enc["speed_ms"]) * delta

			# Fire cannon volley periodically
			enc["cannon_cooldown_sec"] = float(enc["cannon_cooldown_sec"]) - delta
			if enable_cannon_volleys and float(enc["cannon_cooldown_sec"]) <= 0.0:
				enc["cannon_cooldown_sec"] = 4.5
				_fire_cannon_volley(enc_id, ship_node.position + up_dir * 6.0, target_pos + up_dir * 4.0)
		else:
			enc["engaged"] = false
			var p_rad: float = float(enc["patrol_radius_m"])
			var ang_speed: float = float(enc["speed_ms"]) / maxf(p_rad, 100.0)
			enc["orbit_angle"] = float(enc["orbit_angle"]) + ang_speed * delta
			var a: float = float(enc["orbit_angle"])
			var desired_pos: Vector3 = anchor_local + (up_basis.x * cos(a) + up_basis.z * sin(a)) * p_rad
			heading = (-up_basis.x * sin(a) + up_basis.z * cos(a)).normalized()
			ship_node.position = desired_pos

		ship_node.basis = _basis_from_up_and_forward(up_dir, heading)


func _fire_cannon_volley(enc_id: String, origin_pos: Vector3, target_pos: Vector3) -> void:
	var volley_count: int = 3
	var up_dir: Vector3 = _get_local_up_at_origin()
	var base_dir: Vector3 = (target_pos - origin_pos).normalized()
	var right_vec: Vector3 = base_dir.cross(up_dir).normalized()

	var ball_mat := StandardMaterial3D.new()
	ball_mat.albedo_color = Color(0.15, 0.15, 0.18)
	ball_mat.emission_enabled = true
	ball_mat.emission = Color(1.0, 0.42, 0.12)
	ball_mat.emission_energy_multiplier = 1.6

	for i in range(volley_count):
		var spread: float = float(i - 1) * 0.045
		var vel: Vector3 = (base_dir + right_vec * spread + up_dir * 0.06).normalized() * CANNON_PROJECTILE_SPEED_MS
		var proj_mi := MeshInstance3D.new()
		proj_mi.name = "Cannonball_%s_%d" % [enc_id, i]
		var sph := SphereMesh.new()
		sph.radius = 1.2
		sph.height = 2.4
		proj_mi.mesh = sph
		proj_mi.material_override = ball_mat
		proj_mi.position = origin_pos
		add_child(proj_mi)
		_active_projectiles.append({
			"node": proj_mi,
			"velocity": vel,
			"ttl_sec": 6.0,
			"damage": 18.0
		})

	if _audio_ref != null and _audio_ref.has_method("play_cannon_fire"):
		_audio_ref.call("play_cannon_fire")
	naval_cannon_volley_fired.emit(enc_id, target_pos, volley_count)


func _update_cannon_projectiles(delta: float) -> void:
	var up_dir: Vector3 = _get_local_up_at_origin()
	var ship_pos: Vector3 = _get_player_or_ship_local_pos()
	for idx in range(_active_projectiles.size() - 1, -1, -1):
		var p: Dictionary = _active_projectiles[idx]
		var node_p: Node3D = p["node"] as Node3D
		p["ttl_sec"] = float(p["ttl_sec"]) - delta
		if not is_instance_valid(node_p) or float(p["ttl_sec"]) <= 0.0:
			if is_instance_valid(node_p):
				node_p.queue_free()
			_active_projectiles.remove_at(idx)
			continue

		var vel: Vector3 = p["velocity"]
		vel -= up_dir * 9.81 * delta
		p["velocity"] = vel
		node_p.position += vel * delta

		if node_p.position.distance_to(ship_pos) <= 24.0:
			if _combat_sys_ref != null and _combat_sys_ref.has_method("apply_damage"):
				_combat_sys_ref.call("apply_damage", "player", float(p["damage"]))
			node_p.queue_free()
			_active_projectiles.remove_at(idx)


# ==============================================================================
# 5. COMBAT & BOUNTY RESOLUTION API
# ==============================================================================
## Applies player/ability damage to any active Sea King or Naval Patrol encounter.
func damage_encounter(encounter_id: String, damage_amount: float) -> Dictionary:
	if _active_naval_encounters.has(encounter_id):
		var enc: Dictionary = _active_naval_encounters[encounter_id]
		enc["hp"] = maxf(0.0, float(enc["hp"]) - damage_amount)
		if float(enc["hp"]) <= 0.0:
			return _resolve_defeat(encounter_id, enc, true)
		return {"hit": true, "encounter_id": encounter_id, "remaining_hp": enc["hp"], "defeated": false}

	for i in range(_active_sea_kings.size()):
		var sk: Dictionary = _active_sea_kings[i]
		if sk["id"] == encounter_id:
			sk["hp"] = maxf(0.0, float(sk["hp"]) - damage_amount)
			if float(sk["hp"]) <= 0.0:
				_active_sea_kings.remove_at(i)
				return _resolve_defeat(encounter_id, sk, false)
			return {"hit": true, "encounter_id": encounter_id, "remaining_hp": sk["hp"], "defeated": false}

	return {"hit": false, "encounter_id": encounter_id, "defeated": false}


func _resolve_defeat(encounter_id: String, rec: Dictionary, is_naval: bool) -> Dictionary:
	var bounty: int = int(rec.get("bounty_beli", 10_000_000))
	var faction_name: String = str(rec.get("faction_name", "Grand Line Hostile"))
	var node_ref: Node = rec.get("node")
	if is_instance_valid(node_ref):
		node_ref.queue_free()
	if is_naval:
		_active_naval_encounters.erase(encounter_id)

	# Duck-typed bounty/currency reward integration
	if _combat_sys_ref != null and _combat_sys_ref.has_method("register_defeat_bounty"):
		_combat_sys_ref.call("register_defeat_bounty", encounter_id, bounty)
	var wr: Node = get_node_or_null("/root/WorldRegistry")
	if wr != null and wr.has_method("add_currency"):
		wr.call("add_currency", "Beli", int(bounty / 100)) # Prize loot share in Beli
	var scm: Node = get_node_or_null("/root/StoryCampaignManager")
	if scm != null and scm.has_method("add_bounty"):
		scm.call("add_bounty", bounty)

	enemy_defeated.emit(encounter_id, faction_name, bounty)
	return {"hit": true, "encounter_id": encounter_id, "remaining_hp": 0.0, "defeated": true, "bounty_beli": bounty}


func get_nearest_hostile(local_pos: Vector3, max_range_m: float = 15_000.0) -> Dictionary:
	var best: Dictionary = {}
	var best_dist: float = max_range_m
	for enc_id in _active_naval_encounters.keys():
		var enc: Dictionary = _active_naval_encounters[enc_id]
		var n: Node3D = enc.get("node") as Node3D
		if is_instance_valid(n):
			var d: float = n.position.distance_to(local_pos)
			if d < best_dist:
				best_dist = d
				best = {"id": enc_id, "name": enc["name"], "distance_m": d, "hp": enc["hp"]}
	for sk in _active_sea_kings:
		var n: Node3D = sk.get("node") as Node3D
		if is_instance_valid(n):
			var d: float = n.position.distance_to(local_pos)
			if d < best_dist:
				best_dist = d
				best = {"id": sk["id"], "name": sk["species"], "distance_m": d, "hp": sk["hp"]}
	return best


func get_active_encounter_summaries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for enc_id in _active_naval_encounters.keys():
		var enc: Dictionary = _active_naval_encounters[enc_id]
		out.append({
			"id": enc_id,
			"name": enc["name"],
			"faction": enc["faction_name"],
			"hp": enc["hp"],
			"engaged": enc["engaged"]
		})
	for sk in _active_sea_kings:
		out.append({
			"id": sk["id"],
			"name": sk["species"],
			"faction": "Calm Belt Sea King",
			"length_m": sk["length_m"],
			"hp": sk["hp"]
		})
	return out
