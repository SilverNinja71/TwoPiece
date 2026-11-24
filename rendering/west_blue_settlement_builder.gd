class_name WestBlueSettlementBuilder
extends Node3D
## West Blue Procedural 3D Settlement & Underworld Landmark Mesh Builder (Godot 4.3+, precision=double).
##
## Uses /root/FloatingOrigin (lat_lon_alt_to_local32, origin_rebased) and WestBlueData to stream
## procedural 3D MeshInstance3D settlements within 80 km (STREAM_RADIUS_M = 80_000.0):
##   1. Ohara Ruins: Colossal charred stump of the Tree of Knowledge, sunken circular Lake of Knowledge
##      crater, smuggler's coastal camp lantern, and Label3D NPC stand-ins (Aron the Ink-Stained,
##      Watcher Kestrel, Saul's Ice Marker).
##   2. Kano Country: Towering karst limestone pinnacles, tiered crimson imperial pagodas, and the
##      Happo Navy dragon-prow harbor dock.
##   3. Castello del Capone: Iron-plated Five Families mafia citadel, brick warehouse piers, and warm
##      amber speakeasy lanterns.
##   4. Esperia Kingdom: Musical luthier harbor, stone amphitheater, and moored royal convoy frigate.

const STREAM_RADIUS_M: float = 80_000.0
const DESPAWN_HYSTERESIS_M: float = 92_000.0

@export var player_node_path: NodePath = NodePath("")
@export var stream_radius_m: float = STREAM_RADIUS_M
@export var auto_connect_floating_origin: bool = true

var _spawned_settlements: Dictionary = {} # island_id -> Node3D
var _settlement_coords: Dictionary = {}   # island_id -> {"lat": float, "lon": float, "alt": float}
var _materials_cache: Dictionary = {}
var _cached_player: Node3D = null
var _flicker_lights: Array[OmniLight3D] = []
var _flicker_time: float = 0.0


func _ready() -> void:
	_init_shared_materials()
	_cache_island_coordinates()
	if auto_connect_floating_origin:
		var fo: Node = _get_floating_origin()
		if fo != null and fo.has_signal("origin_rebased"):
			fo.origin_rebased.connect(_on_origin_rebased)
	_update_proximity_streaming()


func _process(delta: float) -> void:
	_flicker_time += delta
	for i: int in range(_flicker_lights.size()):
		var light: OmniLight3D = _flicker_lights[i]
		if is_instance_valid(light):
			light.light_energy = 2.6 + 0.45 * sin(_flicker_time * 4.2 + float(i) * 1.7)
	_update_proximity_streaming()


func _get_floating_origin() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/FloatingOrigin")
	return null


func _cache_island_coordinates() -> void:
	var islands: Dictionary = WestBlueData.get_islands()
	for island_id: String in islands.keys():
		var isl: Dictionary = islands[island_id]
		var coords: Dictionary = isl.get("coordinates", {})
		_settlement_coords[island_id] = {
			"lat": float(coords.get("lat", 0.0)),
			"lon": float(coords.get("lon", 0.0)),
			"alt": float(coords.get("alt", 0.0)),
		}


func _on_origin_rebased(_delta_local: Vector3) -> void:
	_sync_all_settlement_transforms()


func _sync_all_settlement_transforms() -> void:
	for island_id: String in _spawned_settlements.keys():
		var root: Node3D = _spawned_settlements[island_id]
		if is_instance_valid(root):
			_apply_floating_origin_transform(root, island_id)


func _get_player_lat_lon() -> Dictionary:
	var fo: Node = _get_floating_origin()
	var player: Node3D = _resolve_player_node()
	if fo != null and player != null and fo.has_method("local32_to_lat_lon_alt"):
		return fo.local32_to_lat_lon_alt(player.global_position)
	if fo != null:
		return {
			"lat_deg": float(fo.get("origin_lat_deg")),
			"lon_deg": float(fo.get("origin_lon_deg")),
			"alt_m": float(fo.get("origin_alt_m")),
		}
	return {"lat_deg": -42.5, "lon_deg": -55.0, "alt_m": 0.0}


func _resolve_player_node() -> Node3D:
	if _cached_player != null and is_instance_valid(_cached_player):
		return _cached_player
	if not player_node_path.is_empty():
		var n: Node = get_node_or_null(player_node_path)
		if n is Node3D:
			_cached_player = n as Node3D
			return _cached_player
	if is_inside_tree():
		var root: Node = get_tree().current_scene
		if root != null:
			var found: Node = root.find_child("SphericalPlayer", true, false)
			if found is Node3D:
				_cached_player = found as Node3D
				return _cached_player
	return null


func _update_proximity_streaming() -> void:
	var p_coords: Dictionary = _get_player_lat_lon()
	var p_lat: float = float(p_coords.get("lat_deg", 0.0))
	var p_lon: float = float(p_coords.get("lon_deg", 0.0))

	for island_id: String in _settlement_coords.keys():
		var c: Dictionary = _settlement_coords[island_id]
		var dist_m: float = WestBlueData.calculate_surface_distance_m(
			p_lat, p_lon, float(c["lat"]), float(c["lon"])
		)
		if dist_m <= stream_radius_m:
			if not _spawned_settlements.has(island_id):
				ensure_settlement_spawned(island_id)
		elif dist_m > DESPAWN_HYSTERESIS_M and _spawned_settlements.has(island_id):
			despawn_settlement(island_id)


## Spawns and positions a West Blue settlement using /root/FloatingOrigin.
func ensure_settlement_spawned(island_id: String) -> Node3D:
	if _spawned_settlements.has(island_id):
		var existing: Node3D = _spawned_settlements[island_id]
		if is_instance_valid(existing):
			return existing

	if not _settlement_coords.has(island_id):
		return null

	var root: Node3D = Node3D.new()
	root.name = "WestBlueSettlement_%s" % island_id
	add_child(root)
	_apply_floating_origin_transform(root, island_id)

	match island_id:
		"ohara":
			_build_ohara_ruins(root)
		"kano_country":
			_build_kano_country(root)
		"castello_del_capone":
			_build_castello_del_capone(root)
		"esperia_kingdom":
			_build_esperia_kingdom(root)
		_:
			var island: Dictionary = WestBlueData.get_island(island_id)
			_build_generic_west_blue_port(root, str(island.get("name", island_id)))

	_spawned_settlements[island_id] = root
	return root


func despawn_settlement(island_id: String) -> void:
	if _spawned_settlements.has(island_id):
		var root: Node3D = _spawned_settlements[island_id]
		if is_instance_valid(root):
			root.queue_free()
		_spawned_settlements.erase(island_id)


func _apply_floating_origin_transform(target: Node3D, island_id: String) -> void:
	var c: Dictionary = _settlement_coords[island_id]
	var lat_deg: float = float(c["lat"])
	var lon_deg: float = float(c["lon"])
	var alt_m: float = float(c["alt"])

	var fo: Node = _get_floating_origin()
	if fo != null and fo.has_method("lat_lon_alt_to_local32"):
		target.position = fo.lat_lon_alt_to_local32(lat_deg, lon_deg, alt_m)
	else:
		target.position = WestBlueData.spherical_to_world(lat_deg, lon_deg, alt_m)

	var up: Vector3 = WestBlueData.spherical_to_world(lat_deg, lon_deg, alt_m).normalized()
	var north_ref: Vector3 = Vector3(0.0, 1.0, 0.0)
	if abs(up.dot(north_ref)) > 0.99:
		north_ref = Vector3(0.0, 0.0, 1.0)
	var east: Vector3 = north_ref.cross(up).normalized()
	var north: Vector3 = up.cross(east).normalized()
	target.basis = Basis(east, up, -north).orthonormalized()


# ---------------------------------------------------------------------------
# 1. Ohara Ruins Builder
# ---------------------------------------------------------------------------
func _build_ohara_ruins(root: Node3D) -> void:
	# Sunken circular Lake of Knowledge crater rim & basin
	_add_mesh(root, "CraterRimRing", _make_torus(145.0, 165.0, 24), _mat("basalt"), Vector3(0.0, 2.0, 0.0))
	_add_mesh(root, "LakeOfKnowledge", _make_cylinder(142.0, 142.0, 1.5), _mat("lake_water"), Vector3(0.0, -0.5, 0.0))

	# Colossal charred stump of the 5,000-year-old Tree of Knowledge (80 m tall)
	_add_mesh(root, "TreeOfKnowledgeStump", _make_cylinder(24.0, 32.0, 80.0), _mat("charred_bark"), Vector3(0.0, 40.0, 0.0))
	_add_mesh(root, "TreeHollowLibraryArch", _make_box(Vector3(12.0, 18.0, 16.0)), _mat("obsidian_shadow"), Vector3(0.0, 9.0, 22.0))

	# Charred root buttresses radiating into the crater lake
	for idx: int in range(6):
		var angle: float = (TAU / 6.0) * float(idx)
		var root_node: Node3D = _add_mesh(
			root,
			"CharredRoot_%d" % idx,
			_make_box(Vector3(9.0, 8.0, 52.0)),
			_mat("charred_bark"),
			Vector3(sin(angle) * 44.0, 3.0, cos(angle) * 44.0)
		)
		root_node.rotation.y = angle

	# Smuggler's coastal camp, timber pier & flickering camp lantern
	_add_mesh(root, "SmugglerTimberPier", _make_box(Vector3(10.0, 1.4, 34.0)), _mat("weathered_timber"), Vector3(-115.0, 0.8, 128.0))
	_add_mesh(root, "SmugglerCanvasTent", _make_prism(Vector3(8.0, 4.5, 10.0)), _mat("canvas_tan"), Vector3(-118.0, 3.8, 110.0))
	_add_mesh(root, "CampLanternPost", _make_cylinder(0.18, 0.22, 3.8), _mat("dark_iron"), Vector3(-112.0, 3.4, 116.0))
	_add_mesh(root, "CampLanternGlobe", _make_sphere(0.42), _mat("amber_glow"), Vector3(-112.0, 5.4, 116.0))
	_add_flicker_light(root, "SmugglerCampLight", Vector3(-112.0, 5.5, 116.0), Color(1.0, 0.68, 0.28), 32.0)

	# Jaguar D. Saul's crystalline permafrost footprint marker on the shoreline
	_add_mesh(root, "SaulPermafrostPatch", _make_cylinder(6.5, 7.5, 0.8), _mat("ice_crystal"), Vector3(95.0, 0.4, 132.0))
	_add_mesh(root, "SaulOakStake", _make_box(Vector3(0.45, 3.2, 0.45)), _mat("weathered_timber"), Vector3(98.0, 1.8, 130.0))

	# 2.0m NPC stand-ins with Label3D
	_add_npc_standin(root, "Aron the Ink-Stained", Vector3(-114.0, 1.5, 118.0), Color(0.75, 0.58, 0.42))
	_add_npc_standin(root, "Watcher Kestrel (Cipher Pol)", Vector3(122.0, 5.0, -96.0), Color(0.92, 0.92, 0.95))
	_add_npc_standin(root, "Saul's Ice Marker", Vector3(95.0, 1.2, 132.0), Color(0.55, 0.88, 1.0))


# ---------------------------------------------------------------------------
# 2. Kano Country Builder
# ---------------------------------------------------------------------------
func _build_kano_country(root: Node3D) -> void:
	# Towering karst limestone pinnacles framing Joya Harbor
	var pinnacle_specs: Array[Dictionary] = [
		{"pos": Vector3(-110.0, 55.0, -85.0), "r_top": 10.0, "r_bot": 26.0, "h": 110.0},
		{"pos": Vector3(-72.0, 72.0, -120.0), "r_top": 8.0, "r_bot": 24.0, "h": 144.0},
		{"pos": Vector3(98.0, 62.0, -95.0), "r_top": 9.0, "r_bot": 25.0, "h": 124.0},
		{"pos": Vector3(135.0, 48.0, -60.0), "r_top": 11.0, "r_bot": 28.0, "h": 96.0},
	]
	for idx: int in range(pinnacle_specs.size()):
		var spec: Dictionary = pinnacle_specs[idx]
		_add_mesh(
			root,
			"KarstPinnacle_%d" % idx,
			_make_cylinder(float(spec["r_top"]), float(spec["r_bot"]), float(spec["h"])),
			_mat("limestone"),
			spec["pos"] as Vector3
		)

	# Harbor stone terrace & Tiered Crimson Imperial Pagoda
	_add_mesh(root, "JoyaStoneTerrace", _make_box(Vector3(78.0, 6.0, 68.0)), _mat("limestone"), Vector3(0.0, 3.0, -35.0))
	for tier: int in range(4):
		var scale_f: float = 1.0 - float(tier) * 0.18
		var y_base: float = 6.0 + float(tier) * 11.0
		_add_mesh(
			root,
			"PagodaBody_%d" % tier,
			_make_box(Vector3(24.0 * scale_f, 9.0, 24.0 * scale_f)),
			_mat("crimson_lacquer"),
			Vector3(0.0, y_base + 4.5, -38.0)
		)
		_add_mesh(
			root,
			"PagodaRoof_%d" % tier,
			_make_cylinder(16.0 * scale_f, 22.0 * scale_f, 3.2, 4),
			_mat("imperial_jade"),
			Vector3(0.0, y_base + 10.2, -38.0)
		).rotation.y = PI * 0.25
	_add_mesh(root, "PagodaGoldenSpire", _make_cylinder(0.25, 1.4, 9.0), _mat("gold_trim"), Vector3(0.0, 54.0, -38.0))

	# Happo Navy dragon-prow harbor dock & moored warship
	_add_mesh(root, "HappoHarborDock", _make_box(Vector3(24.0, 2.2, 62.0)), _mat("weathered_timber"), Vector3(0.0, 1.1, 40.0))
	_add_mesh(root, "HappoWarshipHull", _make_box(Vector3(12.0, 5.5, 38.0)), _mat("crimson_lacquer"), Vector3(24.0, 2.2, 55.0))
	_add_mesh(root, "HappoDragonProw", _make_cylinder(1.5, 4.2, 9.5), _mat("gold_trim"), Vector3(24.0, 4.5, 76.0)).rotation.x = deg_to_rad(55.0)
	_add_mesh(root, "HappoWarshipMast", _make_cylinder(0.45, 0.65, 24.0), _mat("weathered_timber"), Vector3(24.0, 16.0, 55.0))
	_add_mesh(root, "HappoSail", _make_box(Vector3(14.0, 12.0, 0.4)), _mat("canvas_tan"), Vector3(24.0, 17.0, 56.0))

	# 2.0m NPC stand-ins with Label3D
	_add_npc_standin(root, "Don Chinjao (The Drill)", Vector3(-6.0, 6.0, -8.0), Color(0.85, 0.24, 0.20))
	_add_npc_standin(root, "Don Sai (13th Leader)", Vector3(6.0, 6.0, -8.0), Color(0.20, 0.62, 0.42))
	_add_npc_standin(root, "Master Artisan Lu", Vector3(-6.0, 2.2, 48.0), Color(0.82, 0.68, 0.25))


# ---------------------------------------------------------------------------
# 3. Castello del Capone Builder
# ---------------------------------------------------------------------------
func _build_castello_del_capone(root: Node3D) -> void:
	# Iron-plated Five Families mafia citadel
	_add_mesh(root, "CitadelFoundation", _make_box(Vector3(96.0, 6.0, 90.0)), _mat("basalt"), Vector3(0.0, 3.0, -45.0))
	_add_mesh(root, "IronFortressKeep", _make_box(Vector3(54.0, 32.0, 48.0)), _mat("dark_iron"), Vector3(0.0, 22.0, -48.0))
	_add_mesh(root, "CitadelUpperBattlement", _make_box(Vector3(32.0, 14.0, 30.0)), _mat("dark_iron"), Vector3(0.0, 45.0, -48.0))

	# Four armored corner bastion towers
	var tower_offsets: Array[Vector3] = [
		Vector3(-32.0, 20.0, -24.0),
		Vector3(32.0, 20.0, -24.0),
		Vector3(-32.0, 20.0, -72.0),
		Vector3(32.0, 20.0, -72.0),
	]
	for idx: int in range(tower_offsets.size()):
		_add_mesh(root, "BastionTower_%d" % idx, _make_cylinder(7.5, 8.5, 36.0), _mat("dark_iron"), tower_offsets[idx])

	# Brick warehouse piers & contraband crates
	_add_mesh(root, "BrickWarehousePier", _make_box(Vector3(82.0, 2.5, 42.0)), _mat("basalt"), Vector3(0.0, 1.25, 22.0))
	_add_mesh(root, "BrickWarehouseWest", _make_box(Vector3(24.0, 12.0, 18.0)), _mat("brick_red"), Vector3(-26.0, 8.5, 18.0))
	_add_mesh(root, "BrickWarehouseEast", _make_box(Vector3(24.0, 12.0, 18.0)), _mat("brick_red"), Vector3(26.0, 8.5, 18.0))
	_add_mesh(root, "ContrabandCrateStack", _make_box(Vector3(6.0, 4.0, 6.0)), _mat("weathered_timber"), Vector3(14.0, 4.5, 34.0))

	# Warm amber speakeasy lanterns
	var lantern_positions: Array[Vector3] = [
		Vector3(-12.0, 6.5, 4.0),
		Vector3(12.0, 6.5, 4.0),
		Vector3(-12.0, 6.5, 36.0),
		Vector3(12.0, 6.5, 36.0),
	]
	for idx: int in range(lantern_positions.size()):
		var lpos: Vector3 = lantern_positions[idx]
		_add_mesh(root, "SpeakeasyPost_%d" % idx, _make_cylinder(0.18, 0.24, 5.0), _mat("dark_iron"), lpos - Vector3(0.0, 2.5, 0.0))
		_add_mesh(root, "SpeakeasyLamp_%d" % idx, _make_sphere(0.45), _mat("amber_glow"), lpos)
		_add_flicker_light(root, "SpeakeasyAmberLight_%d" % idx, lpos, Color(1.0, 0.62, 0.18), 38.0)

	# 2.0m NPC stand-ins with Label3D
	_add_npc_standin(root, "Don Vincenzo", Vector3(-4.0, 2.5, 6.0), Color(0.28, 0.28, 0.34))
	_add_npc_standin(root, "Carmine Marchetti", Vector3(20.0, 2.5, 28.0), Color(0.55, 0.22, 0.22))


# ---------------------------------------------------------------------------
# 4. Esperia Kingdom Builder
# ---------------------------------------------------------------------------
func _build_esperia_kingdom(root: Node3D) -> void:
	# Musical luthier harbor quay & guildhall
	_add_mesh(root, "EsperiaStoneQuay", _make_box(Vector3(84.0, 3.0, 56.0)), _mat("limestone"), Vector3(0.0, 1.5, 10.0))
	_add_mesh(root, "LuthierGuildhall", _make_box(Vector3(26.0, 14.0, 20.0)), _mat("canvas_tan"), Vector3(-24.0, 10.0, -4.0))
	_add_mesh(root, "LuthierGuildRoof", _make_prism(Vector3(28.0, 8.0, 22.0)), _mat("spruce_wood"), Vector3(-24.0, 21.0, -4.0))

	# Stone coastal amphitheater (tiered arcs)
	for step: int in range(4):
		var radius: float = 16.0 + float(step) * 5.0
		_add_mesh(
			root,
			"AmphitheaterTier_%d" % step,
			_make_torus(radius - 2.0, radius + 2.0, 18),
			_mat("limestone"),
			Vector3(22.0, 3.0 + float(step) * 2.2, -12.0)
		)
	_add_mesh(root, "AmphitheaterStage", _make_cylinder(10.0, 10.5, 1.6), _mat("spruce_wood"), Vector3(22.0, 3.8, -12.0))

	# Moored Royal Convoy Frigate at Golden Clef Harbor
	_add_mesh(root, "ConvoyFrigateHull", _make_box(Vector3(11.0, 5.2, 42.0)), _mat("spruce_wood"), Vector3(0.0, 2.0, 62.0))
	_add_mesh(root, "ConvoyQuarterdeck", _make_box(Vector3(10.5, 3.0, 12.0)), _mat("gold_trim"), Vector3(0.0, 6.1, 47.0))
	_add_mesh(root, "ConvoyBowsprit", _make_cylinder(0.25, 0.45, 11.0), _mat("gold_trim"), Vector3(0.0, 6.0, 87.0)).rotation.x = deg_to_rad(72.0)
	for m_idx: int in range(2):
		var mz: float = 54.0 + float(m_idx) * 16.0
		_add_mesh(root, "FrigateMast_%d" % m_idx, _make_cylinder(0.35, 0.55, 22.0), _mat("weathered_timber"), Vector3(0.0, 15.0, mz))
		_add_mesh(root, "FrigateSail_%d" % m_idx, _make_box(Vector3(13.0, 11.0, 0.35)), _mat("canvas_tan"), Vector3(0.0, 16.0, mz + 0.8))

	# 2.0m NPC stand-ins with Label3D
	_add_npc_standin(root, "Grand Luthier Vivaldi", Vector3(-16.0, 3.0, 8.0), Color(0.55, 0.35, 0.72))
	_add_npc_standin(root, "Swordsman Lemaire", Vector3(6.0, 3.0, 24.0), Color(0.24, 0.32, 0.65))
	_add_npc_standin(root, "Songstress Shuri", Vector3(22.0, 4.6, -12.0), Color(0.88, 0.48, 0.62))


# ---------------------------------------------------------------------------
# Generic West Blue Port Fallback (Ilusia, Ballywood, Toroa, Las Camp, etc.)
# ---------------------------------------------------------------------------
func _build_generic_west_blue_port(root: Node3D, display_name: String) -> void:
	_add_mesh(root, "HarborPier", _make_box(Vector3(16.0, 2.0, 44.0)), _mat("weathered_timber"), Vector3(0.0, 1.0, 10.0))
	_add_mesh(root, "TownHall", _make_box(Vector3(22.0, 12.0, 18.0)), _mat("limestone"), Vector3(0.0, 6.0, -24.0))
	_add_mesh(root, "TownHallRoof", _make_prism(Vector3(24.0, 6.5, 20.0)), _mat("crimson_lacquer"), Vector3(0.0, 15.2, -24.0))
	_add_npc_standin(root, "%s Harbormaster" % display_name, Vector3(0.0, 2.0, 18.0), Color(0.45, 0.55, 0.72))


# ---------------------------------------------------------------------------
# Shared Procedural Mesh, Material & NPC Stand-In Helpers
# ---------------------------------------------------------------------------
func _init_shared_materials() -> void:
	_materials_cache["basalt"] = _make_mat(Color(0.18, 0.19, 0.21), 0.92, 0.05)
	_materials_cache["charred_bark"] = _make_mat(Color(0.10, 0.08, 0.07), 0.95, 0.02)
	_materials_cache["obsidian_shadow"] = _make_mat(Color(0.03, 0.03, 0.04), 0.98, 0.0)
	_materials_cache["lake_water"] = _make_mat(Color(0.08, 0.26, 0.32, 0.85), 0.15, 0.1, true)
	_materials_cache["ice_crystal"] = _make_mat(Color(0.62, 0.88, 0.98), 0.18, 0.1)
	_materials_cache["limestone"] = _make_mat(Color(0.76, 0.74, 0.68), 0.85, 0.02)
	_materials_cache["crimson_lacquer"] = _make_mat(Color(0.66, 0.14, 0.14), 0.42, 0.12)
	_materials_cache["imperial_jade"] = _make_mat(Color(0.12, 0.44, 0.32), 0.38, 0.18)
	_materials_cache["gold_trim"] = _make_mat(Color(0.86, 0.70, 0.22), 0.25, 0.85)
	_materials_cache["dark_iron"] = _make_mat(Color(0.20, 0.22, 0.26), 0.45, 0.78)
	_materials_cache["brick_red"] = _make_mat(Color(0.52, 0.22, 0.18), 0.88, 0.04)
	_materials_cache["weathered_timber"] = _make_mat(Color(0.38, 0.26, 0.16), 0.88, 0.02)
	_materials_cache["spruce_wood"] = _make_mat(Color(0.56, 0.36, 0.20), 0.72, 0.05)
	_materials_cache["canvas_tan"] = _make_mat(Color(0.86, 0.80, 0.66), 0.90, 0.0)

	var glow: StandardMaterial3D = _make_mat(Color(1.0, 0.72, 0.28), 0.2, 0.0)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.68, 0.22)
	glow.emission_energy_multiplier = 3.2
	_materials_cache["amber_glow"] = glow


func _mat(key: String) -> Material:
	return _materials_cache.get(key, _materials_cache["limestone"])


func _make_mat(albedo: Color, roughness: float, metallic: float, transparent: bool = false) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = roughness
	m.metallic = metallic
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _add_mesh(parent: Node3D, node_name: String, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _add_flicker_light(parent: Node3D, node_name: String, pos: Vector3, color: Color, range_m: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = node_name
	light.position = pos
	light.light_color = color
	light.light_energy = 2.6
	light.omni_range = range_m
	light.shadow_enabled = false
	parent.add_child(light)
	_flicker_lights.append(light)


## Creates a 2.0m-tall NPC stand-in silhouette with a floating Label3D nameplate.
func _add_npc_standin(parent: Node3D, npc_name: String, pos: Vector3, coat_color: Color) -> Node3D:
	var npc_root: Node3D = Node3D.new()
	npc_root.name = "NPC_%s" % npc_name.replace(" ", "_")
	npc_root.position = pos
	parent.add_child(npc_root)

	var body_mat: StandardMaterial3D = _make_mat(coat_color, 0.75, 0.05)
	_add_mesh(npc_root, "Body", _make_cylinder(0.36, 0.42, 1.45), body_mat, Vector3(0.0, 0.725, 0.0))
	_add_mesh(npc_root, "Head", _make_sphere(0.24), _make_mat(Color(0.92, 0.78, 0.66), 0.7, 0.0), Vector3(0.0, 1.72, 0.0))

	var lbl: Label3D = Label3D.new()
	lbl.name = "Nameplate"
	lbl.text = npc_name
	lbl.position = Vector3(0.0, 2.35, 0.0)
	lbl.pixel_size = 0.012
	lbl.font_size = 36
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(1.0, 0.96, 0.82)
	npc_root.add_child(lbl)
	return npc_root


func _make_box(size_vec: Vector3) -> BoxMesh:
	var b: BoxMesh = BoxMesh.new()
	b.size = size_vec
	return b


func _make_cylinder(top_r: float, bot_r: float, h: float, radial_segs: int = 16) -> CylinderMesh:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bot_r
	c.height = h
	c.radial_segments = radial_segs
	return c


func _make_sphere(r: float) -> SphereMesh:
	var s: SphereMesh = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


func _make_prism(size_vec: Vector3) -> PrismMesh:
	var p: PrismMesh = PrismMesh.new()
	p.size = size_vec
	return p


func _make_torus(inner_r: float, outer_r: float, rings: int = 24) -> TorusMesh:
	var t: TorusMesh = TorusMesh.new()
	t.inner_radius = inner_r
	t.outer_radius = outer_r
	t.rings = rings
	t.ring_segments = 12
	return t
