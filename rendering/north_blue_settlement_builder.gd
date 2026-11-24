class_name NorthBlueSettlementBuilder
extends Node3D
## Procedural 3D North Blue Settlement & Mobile Germa 66 Fleet Mesh Builder (Godot 4.3+, precision=double).
##
## Uses `/root/FloatingOrigin` (`lat_lon_alt_to_local32`, `origin_rebased`) and `NorthBlueData`
## to stream procedural 3D `MeshInstance3D` settlements within `80 km` (`STREAM_RADIUS_M = 80_000.0`):
##   1. Lvneel Kingdom (Coastal stone citadel, Mont Blanc Noland statue plaza, botanical dome, harbor pier, 2.0m NPCs)
##   2. Flevance Ruins ("The White City" — pale alabaster limestone ruins, quarry towers, pale-cyan quarantine beacons)
##   3. Swallow Island / Pleasure Town (Timber shipyard pier, Inventor Wolf's workshop, yellow Polar Tang submarine)
##   4. Mobile Germa 66 Snail-Ship Fleet (Multi-vessel giant Den Den Mushi snail-castle barges moving in `_process()`)
##   5. Lightweight coastal port silhouettes for remaining North Blue islands when within 80 km.

const STREAM_RADIUS_M: float = 80_000.0
const NPC_HEIGHT_M: float = 2.0

@export var player_node_path: NodePath = NodePath("")
@export var stream_radius_m: float = STREAM_RADIUS_M
@export var germa_time_scale_hours_per_sec: float = 1.0 / 60.0

## island_id -> Node3D root
var _spawned_settlements: Dictionary = {}
## island_id -> Dictionary {"lat": float, "lon": float, "alt": float}
var _settlement_coords: Dictionary = {}
## Cached StandardMaterial3D instances
var _materials_cache: Dictionary = {}

## Animated elements
var _flevance_beacons: Array[OmniLight3D] = []
var _polar_tang_node: Node3D = null
var _germa_fleet_root: Node3D = null
var _germa_flank_snails: Array[Node3D] = []
var _germa_drawbridges: Array[MeshInstance3D] = []

var _sim_time_hours: float = 0.0
var _pulse_clock: float = 0.0
var _cached_player: Node3D = null

# ==============================================================================
# LIFECYCLE
# ==============================================================================
func _ready() -> void:
	_init_shared_materials()
	var fo: Node = _get_floating_origin()
	if fo != null and fo.has_signal("origin_rebased"):
		if not fo.is_connected("origin_rebased", Callable(self, "_on_origin_rebased")):
			fo.connect("origin_rebased", Callable(self, "_on_origin_rebased"))
	_update_proximity_streaming()

func _process(delta: float) -> void:
	_sim_time_hours += delta * germa_time_scale_hours_per_sec
	_pulse_clock += delta

	_update_proximity_streaming()
	_sync_static_settlement_positions()
	_update_germa_mobile_fleet(delta)
	_animate_settlement_details(delta)

# ==============================================================================
# FLOATING ORIGIN & DISTANCE HELPERS
# ==============================================================================
func _get_floating_origin() -> Node:
	if has_node("/root/FloatingOrigin"):
		return get_node("/root/FloatingOrigin")
	return null

func _on_origin_rebased(_delta_local: Vector3) -> void:
	_sync_static_settlement_positions()
	_update_germa_mobile_fleet(0.0)

func _get_reference_lat_lon() -> Vector2:
	var fo: Node = _get_floating_origin()
	if player_node_path != NodePath("") and has_node(player_node_path):
		_cached_player = get_node(player_node_path) as Node3D
	elif _cached_player == null and get_parent() != null:
		_cached_player = get_parent().get_node_or_null("SphericalPlayer") as Node3D

	if fo != null:
		if _cached_player != null and is_instance_valid(_cached_player) and fo.has_method("local32_to_lat_lon_alt"):
			var lla: Dictionary = fo.call("local32_to_lat_lon_alt", _cached_player.global_position)
			return Vector2(float(lla.get("lat_deg", 0.0)), float(lla.get("lon_deg", 0.0)))
		return Vector2(float(fo.get("origin_lat_deg")), float(fo.get("origin_lon_deg")))
	return Vector2(NorthBlueData.CANAL_ENTRANCE_LAT, NorthBlueData.CANAL_ENTRANCE_LON)

func _lat_lon_alt_to_local(lat_deg: float, lon_deg: float, alt_m: float) -> Vector3:
	var fo: Node = _get_floating_origin()
	if fo != null and fo.has_method("lat_lon_alt_to_local32"):
		return fo.call("lat_lon_alt_to_local32", lat_deg, lon_deg, alt_m)
	return NorthBlueData.lat_lon_to_cartesian(lat_deg, lon_deg, alt_m)

func _compute_spherical_basis(lat_deg: float, lon_deg: float, heading_deg: float = 0.0) -> Basis:
	var lat_rad: float = deg_to_rad(lat_deg)
	var lon_rad: float = deg_to_rad(lon_deg)
	var cos_lat: float = cos(lat_rad)
	var up: Vector3 = Vector3(
		cos_lat * cos(lon_rad),
		sin(lat_rad),
		cos_lat * sin(lon_rad)
	).normalized()
	var ref_axis: Vector3 = Vector3.UP if absf(up.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var east: Vector3 = ref_axis.cross(up).normalized()
	var north: Vector3 = up.cross(east).normalized()
	var base: Basis = Basis(east, up, -north).orthonormalized()
	if absf(heading_deg) > 0.001:
		base = base.rotated(up, -deg_to_rad(heading_deg))
	return base

# ==============================================================================
# PROXIMITY STREAMING (80 KM RADIUS)
# ==============================================================================
func _update_proximity_streaming() -> void:
	var ref_ll: Vector2 = _get_reference_lat_lon()
	var islands: Dictionary = NorthBlueData.get_islands()

	for island_id: String in islands.keys():
		if island_id == "germa_kingdom_mobile":
			continue # Handled dynamically by _update_germa_mobile_fleet()

		var data: Dictionary = islands[island_id]
		var ilat: float = float(data.get("lat_deg", 0.0))
		var ilon: float = float(data.get("lon_deg", 0.0))
		var dist_m: float = NorthBlueData.surface_distance_meters(ref_ll.x, ref_ll.y, ilat, ilon)

		if dist_m <= stream_radius_m:
			ensure_settlement_spawned(island_id)
		elif dist_m > stream_radius_m * 1.15:
			despawn_settlement(island_id)

func ensure_settlement_spawned(island_id: String) -> Node3D:
	if _spawned_settlements.has(island_id):
		var existing: Node3D = _spawned_settlements[island_id]
		if is_instance_valid(existing):
			return existing

	if island_id == "germa_kingdom_mobile":
		return _ensure_germa_fleet_spawned()

	var island: Dictionary = NorthBlueData.get_island(island_id)
	if island.is_empty():
		return null

	var lat_deg: float = float(island.get("lat_deg", 28.5))
	var lon_deg: float = float(island.get("lon_deg", -18.2))
	var alt_m: float = float(island.get("alt_m", 0.0))

	var root: Node3D = Node3D.new()
	root.name = "NorthBlue_%s" % island_id
	add_child(root)

	_settlement_coords[island_id] = {"lat": lat_deg, "lon": lon_deg, "alt": alt_m}
	root.global_position = _lat_lon_alt_to_local(lat_deg, lon_deg, alt_m)
	root.global_basis = _compute_spherical_basis(lat_deg, lon_deg)

	match island_id:
		"lvneel_kingdom":
			_build_lvneel_kingdom(root)
		"flevance_ruins":
			_build_flevance_ruins(root)
		"swallow_island":
			_build_swallow_island(root)
		_:
			_build_generic_north_blue_port(root, str(island.get("name", island_id)))

	_spawned_settlements[island_id] = root
	return root

func despawn_settlement(island_id: String) -> void:
	if _spawned_settlements.has(island_id):
		var node: Node3D = _spawned_settlements[island_id]
		if is_instance_valid(node):
			node.queue_free()
		_spawned_settlements.erase(island_id)
		_settlement_coords.erase(island_id)

	if island_id == "flevance_ruins":
		_flevance_beacons.clear()
	elif island_id == "swallow_island":
		_polar_tang_node = null

func _sync_static_settlement_positions() -> void:
	for island_id: String in _spawned_settlements.keys():
		if island_id == "germa_kingdom_mobile":
			continue
		var node: Node3D = _spawned_settlements[island_id]
		if is_instance_valid(node) and _settlement_coords.has(island_id):
			var c: Dictionary = _settlement_coords[island_id]
			node.global_position = _lat_lon_alt_to_local(c["lat"], c["lon"], c["alt"])
			node.global_basis = _compute_spherical_basis(c["lat"], c["lon"])

func get_spawned_settlement_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: String in _spawned_settlements.keys():
		ids.append(key)
	return ids

# ==============================================================================
# 1. LVNEEL KINGDOM (CITADEL, NOLAND STATUE PLAZA, BOTANICAL DOME, PIER)
# ==============================================================================
func _build_lvneel_kingdom(root: Node3D) -> void:
	# Harbor Stone Pier (Port Northheim)
	_add_box(root, Vector3(0.0, 0.5, 42.0), Vector3(14.0, 2.0, 56.0), "stone_dark", "PortNorthheimPier")
	for z_off: float in [20.0, 36.0, 52.0, 66.0]:
		_add_cylinder(root, Vector3(-5.8, 2.0, z_off), 0.45, 0.45, 1.4, "iron_dark")
		_add_cylinder(root, Vector3(5.8, 2.0, z_off), 0.45, 0.45, 1.4, "iron_dark")

	# Coastal Stone Citadel & Ramparts
	_add_box(root, Vector3(0.0, 5.0, -36.0), Vector3(54.0, 10.0, 18.0), "stone_light", "LvneelCitadelKeep")
	_add_box(root, Vector3(0.0, 12.5, -38.0), Vector3(24.0, 8.0, 14.0), "stone_light", "LvneelRoyalPalace")
	_add_sphere(root, Vector3(0.0, 17.5, -38.0), 6.5, "gold_trim", "PalaceDome")

	# Corner Bastion Towers
	for x_side: float in [-26.0, 26.0]:
		_add_cylinder(root, Vector3(x_side, 8.5, -28.0), 4.2, 4.6, 17.0, "stone_light")
		_add_cone(root, Vector3(x_side, 19.0, -28.0), 4.8, 5.0, "royal_blue")

	# Mont Blanc Noland Memorial Statue Plaza
	_add_cylinder(root, Vector3(0.0, 0.4, 2.0), 12.0, 12.5, 0.8, "marble_white", "NolandPlaza")
	_add_box(root, Vector3(0.0, 2.4, 2.0), Vector3(3.6, 3.2, 3.6), "stone_dark", "NolandPedestal")
	_add_cylinder(root, Vector3(0.0, 5.4, 2.0), 0.85, 1.0, 2.8, "bronze_statue", "NolandStatueBody")
	_add_sphere(root, Vector3(0.0, 7.2, 2.0), 0.65, "bronze_statue", "NolandStatueHead")
	_add_label3d(root, Vector3(0.0, 8.6, 2.0), "Mont Blanc Noland\nMemorial Plaza", Color(1.0, 0.88, 0.45))

	# Royal Botanical Conservatory Dome
	_add_cylinder(root, Vector3(30.0, 0.6, -4.0), 13.0, 13.5, 1.2, "stone_light", "BotanicalBase")
	_add_sphere(root, Vector3(30.0, 1.2, -4.0), 11.5, "glass_conservatory", "BotanicalGlassDome")
	_add_sphere(root, Vector3(27.0, 2.0, -4.0), 1.4, "gold_pumpkin", "GoldenPumpkinSpecimen")
	_add_cylinder(root, Vector3(33.0, 3.5, -5.0), 0.8, 1.2, 5.0, "wood_timber", "KonaTreeTrunk")
	_add_sphere(root, Vector3(33.0, 6.8, -5.0), 3.2, "foliage_green", "KonaTreeCanopy")
	_add_label3d(root, Vector3(30.0, 14.0, -4.0), "Royal Botanical\nConservatory", Color(0.65, 1.0, 0.65))

	# 2.0m NPC Stand-Ins with Label3D Nameplates
	_spawn_npc_standin(root, Vector3(-6.0, 1.5, 14.0), "Cedric of the Northheim Archive", Color(0.75, 0.55, 0.35))
	_spawn_npc_standin(root, Vector3(22.0, 1.2, 2.0), "Elena Ross (Royal Botanist)", Color(0.35, 0.78, 0.48))

# ==============================================================================
# 2. FLEVANCE RUINS ("THE WHITE CITY" & AMBER LEAD QUARANTINE BEACONS)
# ==============================================================================
func _build_flevance_ruins(root: Node3D) -> void:
	# Alabaster Chalk Ground Slab
	_add_cylinder(root, Vector3(0.0, 0.25, 0.0), 48.0, 50.0, 0.5, "alabaster_white", "FlevanceChalkPlaza")

	# Shattered White Cathedral Colonnade
	for i: int in range(-2, 3):
		var col_h: float = 9.0 if (i % 2 == 0) else 5.5
		_add_cylinder(root, Vector3(float(i) * 6.5, col_h * 0.5 + 0.5, -18.0), 0.9, 1.0, col_h, "alabaster_white")
	_add_box(root, Vector3(-6.5, 10.0, -18.0), Vector3(16.0, 1.4, 2.6), "alabaster_white", "BrokenArchitrave")

	# Ruined White Fairytale Townhouses
	_add_box(root, Vector3(-22.0, 3.5, -6.0), Vector3(10.0, 6.0, 10.0), "alabaster_white", "RuinedClinic")
	_add_box(root, Vector3(22.0, 4.0, -10.0), Vector3(11.0, 7.0, 9.0), "alabaster_white", "RuinedManor")

	# Shattered Amber Lead Quarry Tower & Minehead
	_add_box(root, Vector3(16.0, 6.5, 18.0), Vector3(8.0, 12.0, 8.0), "amber_lead_pale", "ShatteredQuarryTower")
	_add_box(root, Vector3(24.0, 2.5, 22.0), Vector3(7.0, 4.0, 7.0), "stone_dark", "MineShaftEntrance")

	# Eerie Pale-Cyan Quarantine Beacon Towers & OmniLight3D
	var beacon_positions: Array[Vector3] = [
		Vector3(-28.0, 0.5, 26.0),
		Vector3(28.0, 0.5, 26.0),
		Vector3(0.0, 0.5, -34.0)
	]
	for b_pos: Vector3 in beacon_positions:
		_add_cylinder(root, b_pos + Vector3(0.0, 5.0, 0.0), 0.6, 0.9, 10.0, "iron_dark", "QuarantinePylon")
		_add_sphere(root, b_pos + Vector3(0.0, 10.6, 0.0), 1.1, "quarantine_cyan_emissive", "BeaconOrb")
		var light: OmniLight3D = OmniLight3D.new()
		light.position = b_pos + Vector3(0.0, 11.2, 0.0)
		light.light_color = Color(0.45, 0.95, 1.0)
		light.light_energy = 3.5
		light.omni_range = 45.0
		root.add_child(light)
		_flevance_beacons.append(light)

	_add_label3d(root, Vector3(0.0, 12.5, -18.0), "FLEVANCE — QUARANTINE ZONE\n[AMBER LEAD BIOHAZARD]", Color(0.55, 0.95, 1.0))
	_spawn_npc_standin(root, Vector3(-16.0, 0.5, 4.0), "Kroll the Masked (Scavenger)", Color(0.55, 0.85, 0.9))

# ==============================================================================
# 3. SWALLOW ISLAND / PLEASURE TOWN (WOLF'S WORKSHOP & POLAR TANG SUBMARINE)
# ==============================================================================
func _build_swallow_island(root: Node3D) -> void:
	# Timber Shipyard Pier
	_add_box(root, Vector3(0.0, 0.6, 32.0), Vector3(12.0, 1.6, 42.0), "wood_timber", "PleasureTownPier")

	# Inventor Wolf's Geodesic Workshop
	_add_cylinder(root, Vector3(-16.0, 1.0, -8.0), 11.0, 11.5, 2.0, "stone_dark", "WolfLabFoundation")
	_add_sphere(root, Vector3(-16.0, 2.0, -8.0), 9.5, "copper_workshop", "WolfGeodesicDome")
	_add_cylinder(root, Vector3(-10.0, 9.0, -12.0), 1.1, 1.3, 10.0, "iron_dark", "SteamSmokestack")
	_add_label3d(root, Vector3(-16.0, 13.5, -8.0), "Inventor Wolf's\nSubmersible Drydock", Color(1.0, 0.85, 0.4))

	# Pleasure Town Bakery & Lodge
	_add_box(root, Vector3(16.0, 3.5, -10.0), Vector3(12.0, 6.0, 10.0), "wood_timber", "PleasureTownBakery")
	_add_cone(root, Vector3(16.0, 8.5, -10.0), 8.5, 4.5, "royal_blue")

	# Iconic Yellow Polar Tang Submarine Moored in the Bay
	var sub: Node3D = Node3D.new()
	sub.name = "PolarTangSubmarine"
	sub.position = Vector3(14.0, 0.2, 38.0)
	root.add_child(sub)
	_polar_tang_node = sub

	# Streamlined Yellow Hull (rotated capsule along Z)
	var hull: MeshInstance3D = _add_capsule(sub, Vector3.ZERO, 2.8, 22.0, "polar_tang_yellow", "PolarTangHull")
	hull.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	# Conning Tower & Periscope
	_add_cylinder(sub, Vector3(0.0, 3.2, 1.0), 1.4, 1.7, 3.2, "polar_tang_yellow", "ConningTower")
	_add_cylinder(sub, Vector3(0.0, 5.4, 1.4), 0.18, 0.18, 2.4, "iron_dark", "Periscope")
	# Heart Pirates Dorsal Emblem Plate
	_add_box(sub, Vector3(0.0, 2.2, -6.5), Vector3(0.4, 2.2, 3.4), "iron_dark", "HeartPiratesFin")
	_add_label3d(sub, Vector3(0.0, 7.2, 1.0), "POLAR TANG\n(Heart Pirates Submersible)", Color(1.0, 0.92, 0.25))

	_spawn_npc_standin(root, Vector3(-4.0, 1.4, 14.0), "Master Inventor Wolf", Color(0.95, 0.78, 0.35))

# ==============================================================================
# 4. MOBILE GERMA 66 SNAIL-SHIP FLEET (48-SNAIL NOMADIC EMPIRE)
# ==============================================================================
func _ensure_germa_fleet_spawned() -> Node3D:
	if _germa_fleet_root != null and is_instance_valid(_germa_fleet_root):
		return _germa_fleet_root

	var fleet: Node3D = Node3D.new()
	fleet.name = "Germa66_MobileSnailFleet"
	add_child(fleet)
	_germa_fleet_root = fleet
	_germa_flank_snails.clear()
	_germa_drawbridges.clear()

	# Central Royal Castle Snail Flagship ("St. German")
	_build_germa_snail_barge(fleet, Vector3.ZERO, 1.5, true, "GermaRoyalCastleSnail")
	_add_label3d(fleet, Vector3(0.0, 32.0, 0.0), "GERMA KINGDOM (MOBILE CITADEL)\nVinsmoke Royal Snail Flagship", Color(1.0, 0.4, 0.55))

	# 4 Flanking Giant Den Den Mushi Snail-Castle Barges
	var flank_offsets: Array[Vector3] = [
		Vector3(-26.0, 0.0, 0.0),
		Vector3(26.0, 0.0, 0.0),
		Vector3(0.0, 0.0, -28.0),
		Vector3(0.0, 0.0, 28.0)
	]
	for idx: int in range(flank_offsets.size()):
		var snail_node: Node3D = _build_germa_snail_barge(fleet, flank_offsets[idx], 1.0, false, "GermaFlankSnail_%d" % idx)
		_germa_flank_snails.append(snail_node)

		# Interlocking Hydraulic Drawbridge connecting to flagship
		var bridge: MeshInstance3D = _add_box(
			fleet,
			flank_offsets[idx] * 0.5 + Vector3(0.0, 3.0, 0.0),
			Vector3(6.0, 0.8, 12.0) if absf(flank_offsets[idx].z) > 1.0 else Vector3(12.0, 0.8, 6.0),
			"iron_dark",
			"HydraulicDrawbridge_%d" % idx
		)
		_germa_drawbridges.append(bridge)

	_spawn_npc_standin(fleet, Vector3(0.0, 12.0, 6.0), "Vinsmoke Judge (Garuda)", Color(1.0, 0.78, 0.2))
	_spawn_npc_standin(fleet, Vector3(4.0, 6.0, 10.0), "Clone Unit #04", Color(0.75, 0.75, 0.85))

	_spawned_settlements["germa_kingdom_mobile"] = fleet
	return fleet

func _build_germa_snail_barge(parent: Node3D, local_pos: Vector3, scale_factor: float, has_castle: bool, node_name: String) -> Node3D:
	var snail: Node3D = Node3D.new()
	snail.name = node_name
	snail.position = local_pos
	parent.add_child(snail)

	# Giant Sea-Snail Muscular Foot Hull
	var foot: MeshInstance3D = _add_capsule(snail, Vector3(0.0, 1.5 * scale_factor, 0.0), 4.8 * scale_factor, 20.0 * scale_factor, "germa_snail_body")
	foot.rotation_degrees = Vector3(90.0, 0.0, 0.0)

	# Coiled Giant Den Den Mushi Shell
	var shell: MeshInstance3D = _add_cylinder(snail, Vector3(0.0, 6.0 * scale_factor, -1.5 * scale_factor), 6.2 * scale_factor, 6.2 * scale_factor, 8.5 * scale_factor, "germa_shell_purple")
	shell.rotation_degrees = Vector3(0.0, 0.0, 90.0)

	# Head & Twin Eyestalks
	_add_sphere(snail, Vector3(0.0, 3.8 * scale_factor, 9.2 * scale_factor), 2.8 * scale_factor, "germa_snail_body")
	for x_eye: float in [-1.4, 1.4]:
		_add_cylinder(snail, Vector3(x_eye * scale_factor, 6.8 * scale_factor, 9.6 * scale_factor), 0.25 * scale_factor, 0.32 * scale_factor, 3.8 * scale_factor, "germa_snail_body")
		_add_sphere(snail, Vector3(x_eye * scale_factor, 8.9 * scale_factor, 9.6 * scale_factor), 0.75 * scale_factor, "quarantine_cyan_emissive")

	# Fortress Deck & Ramparts mounted atop the shell
	_add_box(snail, Vector3(0.0, 10.5 * scale_factor, -1.5 * scale_factor), Vector3(11.0 * scale_factor, 1.6 * scale_factor, 12.0 * scale_factor), "stone_dark")
	if has_castle:
		_add_box(snail, Vector3(0.0, 15.0 * scale_factor, -1.5 * scale_factor), Vector3(8.5 * scale_factor, 8.0 * scale_factor, 8.5 * scale_factor), "stone_light")
		_add_cone(snail, Vector3(0.0, 21.5 * scale_factor, -1.5 * scale_factor), 5.5 * scale_factor, 5.5 * scale_factor, "royal_crimson")
		# Germa "66" Insignia Banner
		_add_box(snail, Vector3(0.0, 16.5 * scale_factor, 3.2 * scale_factor), Vector3(4.5 * scale_factor, 3.5 * scale_factor, 0.4 * scale_factor), "royal_crimson")

	return snail

func _update_germa_mobile_fleet(_delta: float) -> void:
	var fleet_state: Dictionary = NorthBlueData.get_germa_fleet_state(_sim_time_hours)
	var coords: Dictionary = fleet_state.get("coordinates", {})
	var flat: float = float(coords.get("lat", 31.0))
	var flon: float = float(coords.get("lon", -48.0))
	var falt: float = float(coords.get("altitude", 8.0))
	var heading_deg: float = float(fleet_state.get("heading_degrees", 0.0))
	var formation: String = str(fleet_state.get("fleet_formation", "ASSEMBLED_ISLAND_FORTRESS"))

	var ref_ll: Vector2 = _get_reference_lat_lon()
	var dist_m: float = NorthBlueData.surface_distance_meters(ref_ll.x, ref_ll.y, flat, flon)

	if dist_m > stream_radius_m * 1.15:
		if _germa_fleet_root != null and is_instance_valid(_germa_fleet_root):
			_germa_fleet_root.queue_free()
			_germa_fleet_root = null
			_spawned_settlements.erase("germa_kingdom_mobile")
		return

	var fleet: Node3D = _ensure_germa_fleet_spawned()
	fleet.global_position = _lat_lon_alt_to_local(flat, flon, falt)
	fleet.global_basis = _compute_spherical_basis(flat, flon, heading_deg)

	# Morph between assembled fortress and cruising convoy divisions
	var is_fortress: bool = (formation == "ASSEMBLED_ISLAND_FORTRESS")
	var spread: float = 1.0 if is_fortress else 2.2
	var base_offsets: Array[Vector3] = [
		Vector3(-26.0 * spread, 0.0, 0.0),
		Vector3(26.0 * spread, 0.0, 0.0),
		Vector3(0.0, 0.0, -28.0 * spread),
		Vector3(0.0, 0.0, 28.0 * spread)
	]
	for idx: int in range(min(_germa_flank_snails.size(), base_offsets.size())):
		var snail: Node3D = _germa_flank_snails[idx]
		if is_instance_valid(snail):
			snail.position = snail.position.lerp(base_offsets[idx], 0.08)
	for bridge: MeshInstance3D in _germa_drawbridges:
		if is_instance_valid(bridge):
			bridge.visible = is_fortress

# ==============================================================================
# 5. GENERIC PORT SILHOUETTE & ANIMATIONS
# ==============================================================================
func _build_generic_north_blue_port(root: Node3D, display_name: String) -> void:
	_add_box(root, Vector3(0.0, 0.5, 22.0), Vector3(10.0, 1.5, 32.0), "wood_timber", "PortWharf")
	_add_box(root, Vector3(0.0, 3.5, -10.0), Vector3(16.0, 6.0, 12.0), "stone_light", "HarborWarehouse")
	_add_label3d(root, Vector3(0.0, 9.0, -10.0), display_name, Color(0.9, 0.95, 1.0))

func _animate_settlement_details(_delta: float) -> void:
	# Pulse Flevance pale-cyan quarantine beacons
	var pulse: float = 2.6 + sin(_pulse_clock * 3.0) * 1.4
	for light: OmniLight3D in _flevance_beacons:
		if is_instance_valid(light):
			light.light_energy = pulse

	# Gentle wave bob on the Polar Tang submarine
	if _polar_tang_node != null and is_instance_valid(_polar_tang_node):
		_polar_tang_node.position.y = 0.2 + sin(_pulse_clock * 1.4) * 0.28

func _spawn_npc_standin(parent: Node3D, local_pos: Vector3, npc_name: String, tunic_color: Color) -> void:
	var npc_root: Node3D = Node3D.new()
	npc_root.position = local_pos
	parent.add_child(npc_root)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = tunic_color
	mat.roughness = 0.65

	var body: MeshInstance3D = MeshInstance3D.new()
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = NPC_HEIGHT_M
	body.mesh = cap
	body.material_override = mat
	body.position = Vector3(0.0, NPC_HEIGHT_M * 0.5, 0.0)
	npc_root.add_child(body)

	_add_label3d(npc_root, Vector3(0.0, NPC_HEIGHT_M + 0.65, 0.0), npc_name, Color(1.0, 0.98, 0.85))

# ==============================================================================
# SHARED MATERIALS & PROCEDURAL MESH PRIMITIVES
# ==============================================================================
func _init_shared_materials() -> void:
	var specs: Dictionary = {
		"stone_light": {"color": Color(0.78, 0.77, 0.74), "roughness": 0.88},
		"stone_dark": {"color": Color(0.36, 0.37, 0.40), "roughness": 0.90},
		"marble_white": {"color": Color(0.92, 0.92, 0.90), "roughness": 0.45},
		"alabaster_white": {"color": Color(0.95, 0.97, 0.99), "roughness": 0.55},
		"amber_lead_pale": {"color": Color(0.82, 0.90, 0.92), "roughness": 0.35, "metallic": 0.25},
		"wood_timber": {"color": Color(0.45, 0.29, 0.16), "roughness": 0.85},
		"iron_dark": {"color": Color(0.22, 0.24, 0.27), "roughness": 0.45, "metallic": 0.75},
		"gold_trim": {"color": Color(0.90, 0.72, 0.22), "roughness": 0.30, "metallic": 0.85},
		"bronze_statue": {"color": Color(0.55, 0.42, 0.24), "roughness": 0.42, "metallic": 0.70},
		"royal_blue": {"color": Color(0.16, 0.32, 0.65), "roughness": 0.65},
		"royal_crimson": {"color": Color(0.72, 0.14, 0.18), "roughness": 0.60},
		"foliage_green": {"color": Color(0.22, 0.55, 0.25), "roughness": 0.85},
		"gold_pumpkin": {"color": Color(0.95, 0.62, 0.12), "roughness": 0.50},
		"copper_workshop": {"color": Color(0.68, 0.40, 0.24), "roughness": 0.40, "metallic": 0.65},
		"polar_tang_yellow": {"color": Color(0.96, 0.78, 0.10), "roughness": 0.35, "metallic": 0.40},
		"germa_snail_body": {"color": Color(0.64, 0.58, 0.50), "roughness": 0.75},
		"germa_shell_purple": {"color": Color(0.44, 0.22, 0.54), "roughness": 0.60},
		"glass_conservatory": {"color": Color(0.75, 0.92, 0.96, 0.42), "roughness": 0.15, "transparent": true},
		"quarantine_cyan_emissive": {"color": Color(0.45, 0.95, 1.0), "emission": Color(0.35, 0.90, 1.0), "emission_energy": 2.4}
	}
	for key: String in specs.keys():
		var s: Dictionary = specs[key]
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = s["color"]
		mat.roughness = float(s.get("roughness", 0.7))
		mat.metallic = float(s.get("metallic", 0.0))
		if bool(s.get("transparent", false)):
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if s.has("emission"):
			mat.emission_enabled = true
			mat.emission = s["emission"]
			mat.emission_energy_multiplier = float(s.get("emission_energy", 1.5))
		_materials_cache[key] = mat

func _add_box(parent: Node3D, pos: Vector3, size: Vector3, mat_key: String, mesh_name: String = "Box") -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = mesh_name
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _materials_cache.get(mat_key, null)
	mi.position = pos
	parent.add_child(mi)
	return mi

func _add_cylinder(parent: Node3D, pos: Vector3, top_r: float, bot_r: float, h: float, mat_key: String, mesh_name: String = "Cyl") -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = mesh_name
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	mi.mesh = cm
	mi.material_override = _materials_cache.get(mat_key, null)
	mi.position = pos
	parent.add_child(mi)
	return mi

func _add_cone(parent: Node3D, pos: Vector3, bot_r: float, h: float, mat_key: String, mesh_name: String = "Cone") -> MeshInstance3D:
	return _add_cylinder(parent, pos, 0.05, bot_r, h, mat_key, mesh_name)

func _add_sphere(parent: Node3D, pos: Vector3, r: float, mat_key: String, mesh_name: String = "Sphere") -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = mesh_name
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = _materials_cache.get(mat_key, null)
	mi.position = pos
	parent.add_child(mi)
	return mi

func _add_capsule(parent: Node3D, pos: Vector3, r: float, h: float, mat_key: String, mesh_name: String = "Capsule") -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = mesh_name
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = r
	cap.height = h
	mi.mesh = cap
	mi.material_override = _materials_cache.get(mat_key, null)
	mi.position = pos
	parent.add_child(mi)
	return mi

func _add_label3d(parent: Node3D, pos: Vector3, text_str: String, color: Color) -> Label3D:
	var lbl: Label3D = Label3D.new()
	lbl.text = text_str
	lbl.modulate = color
	lbl.font_size = 42
	lbl.pixel_size = 0.015
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = false
	lbl.position = pos
	parent.add_child(lbl)
	return lbl
