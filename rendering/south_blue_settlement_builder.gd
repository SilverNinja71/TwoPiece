class_name SouthBlueSettlementBuilder
extends Node3D
## Procedural 3D South Blue Settlement & Canopy/Dojo Landmark Mesh Builder (Godot 4.3+, precision=double).
##
## Streams detailed procedural 3D MeshInstance3D settlements around South Blue coordinates
## whenever the player/camera is within 80 km (STREAM_RADIUS_M = 80_000.0) using FloatingOrigin.

const STREAM_RADIUS_M: float = 80_000.0
const PROXIMITY_CHECK_INTERVAL_SEC: float = 0.5

@export var player_node_path: NodePath = NodePath("")
@export var stream_radius_m: float = STREAM_RADIUS_M

var _spawned_settlements: Dictionary = {} # island_id -> Node3D
var _settlement_coords: Dictionary = {}   # island_id -> Vector3(lat, lon, alt)
var _materials_cache: Dictionary = {}
var _foundry_gears: Array[Node3D] = []
var _smoke_puffs: Array[Dictionary] = []  # {node: MeshInstance3D, base_y: float, phase: float}
var _goayu_wings: Array[Dictionary] = []  # {left: Node3D, right: Node3D, phase: float}
var _waterfall_sheets: Array[MeshInstance3D] = []
var _cached_player: Node3D = null
var _check_accum: float = 0.0
var _anim_time: float = 0.0


func _ready() -> void:
	_init_shared_materials()
	var fo: Node = _get_floating_origin()
	if fo != null and fo.has_signal("origin_rebased"):
		fo.origin_rebased.connect(_on_origin_rebased)
	_update_proximity_streaming()


func _process(delta: float) -> void:
	_anim_time += delta

	for gear: Node3D in _foundry_gears:
		if is_instance_valid(gear):
			gear.rotate_z(0.6 * delta)

	for puff in _smoke_puffs:
		var node: MeshInstance3D = puff["node"]
		if is_instance_valid(node):
			var cycle: float = fmod(_anim_time * 0.45 + float(puff["phase"]), 1.0)
			node.position.y = float(puff["base_y"]) + cycle * 26.0
			var s: float = 0.6 + cycle * 1.4
			node.scale = Vector3(s, s, s)

	for wing in _goayu_wings:
		var l_wing: Node3D = wing["left"]
		var r_wing: Node3D = wing["right"]
		var flap: float = sin(_anim_time * 1.8 + float(wing["phase"])) * 0.22
		if is_instance_valid(l_wing):
			l_wing.rotation.z = flap
		if is_instance_valid(r_wing):
			r_wing.rotation.z = -flap

	for sheet: MeshInstance3D in _waterfall_sheets:
		if is_instance_valid(sheet):
			sheet.position.y = 175.0 + sin(_anim_time * 6.0) * 1.2

	_check_accum += delta
	if _check_accum >= PROXIMITY_CHECK_INTERVAL_SEC:
		_check_accum = 0.0
		_sync_settlement_transforms()
		_update_proximity_streaming()


func _get_floating_origin() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/FloatingOrigin")
	return null


func _on_origin_rebased(_delta_local: Vector3) -> void:
	_sync_settlement_transforms()


## Ensures a specific South Blue settlement is built and positioned in local floating-origin space.
func ensure_settlement_spawned(island_id: String) -> Node3D:
	if _spawned_settlements.has(island_id):
		var existing: Node3D = _spawned_settlements[island_id]
		if is_instance_valid(existing):
			return existing

	var island: Dictionary = SouthBlueData.get_island(island_id)
	if island.is_empty():
		return null

	var coords: Vector2 = island.get("coordinates", Vector2.ZERO)
	var lat_deg: float = coords.x
	var lon_deg: float = coords.y
	# Anchor harbor/settlement base at sea level (0.0 m) so piers meet the ocean
	var base_alt_m: float = 0.0

	var root: Node3D = Node3D.new()
	root.name = "SouthBlue_%s" % island_id
	add_child(root)

	_settlement_coords[island_id] = Vector3(lat_deg, lon_deg, base_alt_m)
	_apply_floating_origin_transform(root, lat_deg, lon_deg, base_alt_m)

	match island_id:
		"sorbet_kingdom":
			_build_sorbet_kingdom(root)
		"torino_kingdom":
			_build_torino_kingdom(root)
		"karate_island":
			_build_karate_island(root)
		"evil_black_drum":
			_build_evil_black_drum(root)
		_:
			_build_generic_south_blue_port(root, island.get("name", island_id))

	_spawned_settlements[island_id] = root
	return root


func despawn_settlement(island_id: String) -> void:
	if _spawned_settlements.has(island_id):
		var node: Node3D = _spawned_settlements[island_id]
		if is_instance_valid(node):
			node.queue_free()
		_spawned_settlements.erase(island_id)
		_settlement_coords.erase(island_id)


func _sync_settlement_transforms() -> void:
	for island_id: String in _spawned_settlements.keys():
		var node: Node3D = _spawned_settlements[island_id]
		if not is_instance_valid(node):
			continue
		var c: Vector3 = _settlement_coords.get(island_id, Vector3.ZERO)
		_apply_floating_origin_transform(node, c.x, c.y, c.z)


func _apply_floating_origin_transform(node: Node3D, lat_deg: float, lon_deg: float, alt_m: float) -> void:
	var world_pos: Vector3 = SouthBlueData.spherical_to_cartesian(lat_deg, lon_deg, alt_m)
	var local_pos: Vector3 = world_pos
	var fo: Node = _get_floating_origin()
	if fo != null and fo.has_method("lat_lon_alt_to_local32"):
		local_pos = fo.lat_lon_alt_to_local32(lat_deg, lon_deg, alt_m)

	var up_dir: Vector3 = world_pos.normalized()
	if up_dir.length_squared() < 0.001:
		up_dir = Vector3.UP

	var ref_forward: Vector3 = Vector3.FORWARD
	if absf(up_dir.dot(ref_forward)) > 0.95:
		ref_forward = Vector3.RIGHT
	var right_dir: Vector3 = up_dir.cross(ref_forward).normalized()
	var forward_dir: Vector3 = right_dir.cross(up_dir).normalized()

	node.global_transform = Transform3D(Basis(right_dir, up_dir, forward_dir), local_pos)


func _update_proximity_streaming() -> void:
	var player_lat: float = 0.0
	var player_lon: float = 0.0
	var has_coords: bool = false

	var fo: Node = _get_floating_origin()
	var player_node: Node3D = _resolve_player_node()
	if player_node != null and fo != null and fo.has_method("local32_to_lat_lon_alt"):
		var geo: Dictionary = fo.local32_to_lat_lon_alt(player_node.global_position)
		player_lat = float(geo.get("lat_deg", 0.0))
		player_lon = float(geo.get("lon_deg", 0.0))
		has_coords = true
	elif fo != null and "origin_lat_deg" in fo:
		player_lat = float(fo.origin_lat_deg)
		player_lon = float(fo.origin_lon_deg)
		has_coords = true

	if not has_coords:
		return

	# Quick coarse filter: only iterate South Blue islands if near South Blue bounds
	for island_id: String in SouthBlueData.ISLANDS.keys():
		var isl: Dictionary = SouthBlueData.ISLANDS[island_id]
		var coords: Vector2 = isl.get("coordinates", Vector2.ZERO)
		var dist_m: float = SouthBlueData.get_great_circle_distance(player_lat, player_lon, coords.x, coords.y)
		if dist_m <= stream_radius_m:
			ensure_settlement_spawned(island_id)
		elif dist_m > stream_radius_m * 1.25 and _spawned_settlements.has(island_id):
			despawn_settlement(island_id)


func _resolve_player_node() -> Node3D:
	if is_instance_valid(_cached_player):
		return _cached_player
	if not player_node_path.is_empty():
		var n: Node = get_node_or_null(player_node_path)
		if n is Node3D:
			_cached_player = n
			return _cached_player
	if is_inside_tree():
		var found: Node = get_tree().get_root().find_child("SphericalPlayer", true, false)
		if found is Node3D:
			_cached_player = found
			return _cached_player
	return null


# ==============================================================================
# 1. SORBET KINGDOM (Popsicle Towers, Church of Sorbet, Bakery, Gyogyo Wharf)
# ==============================================================================
func _build_sorbet_kingdom(root: Node3D) -> void:
	# Harbor & Wharf (Gyogyo's Fishing Wharf)
	_add_box(root, Vector3(0.0, 0.5, 40.0), Vector3(16.0, 1.5, 55.0), "wood_weathered")
	_add_box(root, Vector3(14.0, 0.5, 50.0), Vector3(14.0, 1.2, 10.0), "wood_weathered")
	_add_label(root, Vector3(0.0, 4.5, 64.0), "GYOGYO'S FISHING WHARF — SORBET KINGDOM", Color(0.95, 0.90, 0.72), 36)

	# Coastal Promenade & Island Plinth
	_add_cylinder(root, Vector3(0.0, -1.0, -30.0), 110.0, 120.0, 4.0, "sand_tan")

	# Iconic Popsicle-Shaped Royal Citadel Towers (Northern Citadel)
	var popsicle_specs: Array[Dictionary] = [
		{"pos": Vector3(0.0, 0.0, -90.0), "scale": Vector3(16.0, 48.0, 10.0), "mat": "popsicle_pink"},
		{"pos": Vector3(-24.0, 0.0, -82.0), "scale": Vector3(12.0, 36.0, 8.0), "mat": "popsicle_mint"},
		{"pos": Vector3(24.0, 0.0, -82.0), "scale": Vector3(12.0, 36.0, 8.0), "mat": "popsicle_cream"},
		{"pos": Vector3(-42.0, 0.0, -70.0), "scale": Vector3(9.0, 26.0, 7.0), "mat": "popsicle_pink"},
		{"pos": Vector3(42.0, 0.0, -70.0), "scale": Vector3(9.0, 26.0, 7.0), "mat": "popsicle_mint"}
	]
	for spec in popsicle_specs:
		var p: Vector3 = spec["pos"]
		var s: Vector3 = spec["scale"]
		# Wooden "stick" base
		_add_box(root, p + Vector3(0.0, 5.0, 0.0), Vector3(s.x * 0.35, 10.0, s.z * 0.5), "wood_light")
		# Main popsicle marble tower
		_add_box(root, p + Vector3(0.0, 10.0 + s.y * 0.5, 0.0), s, spec["mat"])
		# Rounded popsicle crown
		_add_cylinder(root, p + Vector3(0.0, 10.0 + s.y, 0.0), s.x * 0.5, s.x * 0.5, s.z, spec["mat"], Vector3(PI * 0.5, 0.0, 0.0))

	_add_label(root, Vector3(0.0, 68.0, -90.0), "SORBET ROYAL CITADEL", Color(1.0, 0.85, 0.90), 48)

	# Weathered Wooden Church of Sorbet (Kuma's Sanctuary)
	var church_pos: Vector3 = Vector3(-35.0, 1.0, -18.0)
	_add_box(root, church_pos + Vector3(0.0, 6.0, 0.0), Vector3(16.0, 12.0, 24.0), "wood_weathered")
	_add_prism_roof(root, church_pos + Vector3(0.0, 14.5, 0.0), Vector3(18.0, 6.0, 26.0), "roof_slate")
	# Bell Tower & Golden Bell
	_add_box(root, church_pos + Vector3(0.0, 18.0, 9.0), Vector3(5.5, 14.0, 5.5), "wood_weathered")
	_add_cylinder(root, church_pos + Vector3(0.0, 22.0, 9.0), 1.4, 1.8, 2.2, "gold_brass")
	_add_label(root, church_pos + Vector3(0.0, 28.0, 9.0), "CHURCH OF SORBET", Color(0.95, 0.88, 0.65), 34)

	# Bonney's Hearthside Bakery & Pizzeria
	var bakery_pos: Vector3 = Vector3(28.0, 1.0, -14.0)
	_add_box(root, bakery_pos + Vector3(0.0, 4.5, 0.0), Vector3(14.0, 9.0, 12.0), "stone_warm")
	_add_box(root, bakery_pos + Vector3(0.0, 6.0, 7.0), Vector3(12.0, 0.4, 4.0), "awning_red")
	_add_cylinder(root, bakery_pos + Vector3(4.5, 11.0, -3.0), 1.2, 1.5, 6.0, "brick_red")
	_add_label(root, bakery_pos + Vector3(0.0, 12.0, 0.0), "BONNEY'S HEARTHSIDE BAKERY", Color(1.0, 0.72, 0.45), 32)

	# NPC Stand-ins (2.0m scale)
	_add_npc_standin(root, church_pos + Vector3(3.0, 1.0, 14.0), "Pastor Aide Luke", Color(0.85, 0.85, 0.95))
	_add_npc_standin(root, bakery_pos + Vector3(-2.0, 1.0, 8.0), "Baker Michele", Color(1.0, 0.80, 0.60))
	_add_npc_standin(root, Vector3(4.0, 1.2, 52.0), "Elder Gyogyo", Color(0.55, 0.78, 0.95))
	_add_npc_standin(root, Vector3(-5.0, 1.0, -68.0), "King Bulldog", Color(0.95, 0.78, 0.30))
	_add_npc_standin(root, Vector3(5.0, 1.0, -68.0), "Queen Dowager Conney", Color(0.95, 0.65, 0.85))


# ==============================================================================
# 2. TORINO KINGDOM (1,250m Great Tree of Life, Canopy Discs, Masked Goayu Nests)
# ==============================================================================
func _build_torino_kingdom(root: Node3D) -> void:
	# Island Base Mound
	_add_cylinder(root, Vector3(0.0, -2.0, 0.0), 160.0, 190.0, 12.0, "grass_emerald")

	# Colossal 1,250m Great Tree of Life Trunk
	_add_cylinder(root, Vector3(0.0, 625.0, 0.0), 34.0, 58.0, 1250.0, "bark_ancient")
	# Buttress Roots
	for i in range(6):
		var ang: float = float(i) * (TAU / 6.0)
		var r_pos: Vector3 = Vector3(cos(ang) * 58.0, 28.0, sin(ang) * 58.0)
		_add_box(root, r_pos, Vector3(16.0, 56.0, 26.0), "bark_ancient", Vector3(0.0, -ang, 0.35))

	# Layered Emerald Canopy Discs (+450m, +800m, +1,100m, +1,250m)
	_add_cylinder(root, Vector3(0.0, 460.0, 0.0), 210.0, 240.0, 28.0, "canopy_emerald")
	_add_cylinder(root, Vector3(0.0, 810.0, 0.0), 260.0, 290.0, 32.0, "canopy_emerald")
	_add_cylinder(root, Vector3(0.0, 1100.0, 0.0), 220.0, 240.0, 30.0, "canopy_emerald")
	_add_cylinder(root, Vector3(0.0, 1245.0, 0.0), 130.0, 150.0, 24.0, "canopy_light")
	_add_label(root, Vector3(0.0, 1290.0, 0.0), "TORINO KINGDOM — GREAT TREE OF LIFE (1,250m)", Color(0.55, 1.0, 0.60), 64)

	# Giant Masked Goayu Nests & Bird Silhouettes on +1,100m Canopy
	var nest_offsets: Array[Vector3] = [
		Vector3(95.0, 1118.0, 40.0),
		Vector3(-90.0, 1118.0, -55.0)
	]
	for idx in range(nest_offsets.size()):
		var n_pos: Vector3 = nest_offsets[idx]
		_add_cylinder(root, n_pos, 26.0, 20.0, 8.0, "wood_weathered")
		_add_masked_goayu_bird(root, n_pos + Vector3(0.0, 12.0, 0.0), float(idx) * 1.4)

	_add_label(root, Vector3(95.0, 1142.0, 40.0), "Matriarch Masked Goayu", Color(1.0, 0.95, 0.70), 42)

	# Shanba Tribal Village & Great Stone Botanical Library at Base Roots
	var village_center: Vector3 = Vector3(0.0, 4.0, 110.0)
	for h in range(4):
		var hx: float = -36.0 + float(h) * 24.0
		_add_cylinder(root, village_center + Vector3(hx, 3.0, 0.0), 6.0, 6.5, 5.0, "stone_warm")
		_add_cylinder(root, village_center + Vector3(hx, 7.5, 0.0), 0.5, 7.5, 4.5, "thatch_gold")

	# Stone Library Facade
	_add_box(root, Vector3(0.0, 10.0, 78.0), Vector3(28.0, 18.0, 16.0), "stone_ancient")
	_add_label(root, Vector3(0.0, 23.0, 78.0), "TORINO GREAT STONE LIBRARY", Color(0.85, 0.95, 0.75), 38)
	_add_npc_standin(root, Vector3(0.0, 4.0, 92.0), "Chief Shanba", Color(0.45, 0.90, 0.50))


func _add_masked_goayu_bird(root: Node3D, pos: Vector3, phase: float) -> void:
	var bird: Node3D = Node3D.new()
	bird.position = pos
	root.add_child(bird)

	_add_box(bird, Vector3.ZERO, Vector3(8.0, 6.0, 14.0), "feather_white")
	_add_box(bird, Vector3(0.0, 4.0, 8.0), Vector3(4.0, 4.0, 4.5), "mask_dark")
	_add_cylinder(bird, Vector3(0.0, 3.5, 11.5), 0.2, 1.2, 3.5, "gold_brass", Vector3(PI * 0.5, 0.0, 0.0))

	var left_wing: Node3D = Node3D.new()
	left_wing.position = Vector3(-4.0, 1.5, 0.0)
	bird.add_child(left_wing)
	_add_box(left_wing, Vector3(-11.0, 0.0, 0.0), Vector3(22.0, 1.0, 7.0), "feather_white")

	var right_wing: Node3D = Node3D.new()
	right_wing.position = Vector3(4.0, 1.5, 0.0)
	bird.add_child(right_wing)
	_add_box(right_wing, Vector3(11.0, 0.0, 0.0), Vector3(22.0, 1.0, 7.0), "feather_white")

	_goayu_wings.append({"left": left_wing, "right": right_wing, "phase": phase})


# ==============================================================================
# 3. KARATE ISLAND (Martial Amphitheater, 350m Waterfall Shrine, Black Belt Pier)
# ==============================================================================
func _build_karate_island(root: Node3D) -> void:
	# Black Belt Pier
	_add_box(root, Vector3(0.0, 0.5, 65.0), Vector3(14.0, 1.5, 45.0), "wood_weathered")
	_add_label(root, Vector3(0.0, 4.5, 85.0), "BLACK BELT PIER — KARATE ISLAND", Color(0.95, 0.85, 0.65), 36)

	# Open-Air Stone Martial Amphitheater
	var arena_pos: Vector3 = Vector3(0.0, 2.0, 0.0)
	_add_cylinder(root, arena_pos, 46.0, 48.0, 4.0, "stone_granite")
	_add_cylinder(root, arena_pos + Vector3(0.0, 3.0, 0.0), 34.0, 36.0, 2.5, "stone_warm")
	_add_cylinder(root, arena_pos + Vector3(0.0, 4.5, 0.0), 22.0, 22.0, 1.0, "dojo_mat")
	for p in range(8):
		var ang: float = float(p) * (TAU / 8.0)
		_add_cylinder(root, arena_pos + Vector3(cos(ang) * 32.0, 12.0, sin(ang) * 32.0), 1.8, 2.0, 16.0, "stone_granite")
	_add_label(root, arena_pos + Vector3(0.0, 24.0, 0.0), "CENTRAL MARTIAL AMPHITHEATER", Color(1.0, 0.65, 0.40), 42)

	# Boxing Academy Ring
	var gym_pos: Vector3 = Vector3(-52.0, 2.0, 18.0)
	_add_box(root, gym_pos + Vector3(0.0, 1.5, 0.0), Vector3(16.0, 3.0, 16.0), "wood_light")
	_add_box(root, gym_pos + Vector3(0.0, 6.0, -10.0), Vector3(20.0, 10.0, 4.0), "stone_warm")
	_add_label(root, gym_pos + Vector3(0.0, 13.0, -10.0), "SOUTH BLUE BOXING ACADEMY", Color(0.95, 0.55, 0.55), 32)

	# Towering 350m Waterfall Cliff Shrine
	var cliff_pos: Vector3 = Vector3(0.0, 0.0, -110.0)
	_add_box(root, cliff_pos + Vector3(0.0, 175.0, -18.0), Vector3(85.0, 350.0, 36.0), "stone_granite")
	var sheet: MeshInstance3D = _add_box(root, cliff_pos + Vector3(0.0, 175.0, 1.0), Vector3(24.0, 345.0, 1.5), "water_cascade")
	_waterfall_sheets.append(sheet)
	_add_cylinder(root, cliff_pos + Vector3(0.0, 1.0, 12.0), 26.0, 28.0, 2.0, "water_cascade")
	_add_label(root, cliff_pos + Vector3(0.0, 42.0, 14.0), "TEN-THOUSAND TON WATERFALL SHRINE", Color(0.55, 0.90, 1.0), 38)

	# NPC Stand-ins
	_add_npc_standin(root, arena_pos + Vector3(0.0, 5.0, 8.0), "Grandmaster Dohyo", Color(1.0, 0.85, 0.40))
	_add_npc_standin(root, gym_pos + Vector3(0.0, 3.0, 4.0), "Max 'Thunder-Jab'", Color(0.95, 0.45, 0.45))


# ==============================================================================
# 4. EVIL BLACK DRUM KINGDOM (Black Drum Castle, Wapol Konzern Foundry, Harbor)
# ==============================================================================
func _build_evil_black_drum(root: Node3D) -> void:
	# Baku Baku Export Harbor
	_add_box(root, Vector3(0.0, 0.8, 58.0), Vector3(24.0, 2.0, 48.0), "steel_dark")
	_add_box(root, Vector3(-10.0, 12.0, 62.0), Vector3(2.5, 22.0, 2.5), "steel_tin")
	_add_box(root, Vector3(-4.0, 22.0, 62.0), Vector3(14.0, 2.0, 2.0), "steel_tin")
	_add_label(root, Vector3(0.0, 6.0, 80.0), "BAKU BAKU EXPORT HARBOR", Color(0.85, 0.88, 0.95), 36)

	# Wapol's Black Drum Castle (Inverted Snare-Drum Citadel)
	var castle_pos: Vector3 = Vector3(0.0, 2.0, -70.0)
	_add_cylinder(root, castle_pos + Vector3(0.0, 22.0, 0.0), 34.0, 30.0, 44.0, "steel_dark")
	_add_cylinder(root, castle_pos + Vector3(0.0, 46.0, 0.0), 38.0, 38.0, 6.0, "steel_tin")
	_add_cylinder(root, castle_pos + Vector3(0.0, 2.0, 0.0), 38.0, 38.0, 5.0, "steel_tin")
	# Drum tension rods
	for r in range(10):
		var ang: float = float(r) * (TAU / 10.0)
		_add_cylinder(root, castle_pos + Vector3(cos(ang) * 35.5, 24.0, sin(ang) * 35.5), 0.9, 0.9, 44.0, "gold_brass")
	_add_label(root, castle_pos + Vector3(0.0, 58.0, 0.0), "BLACK DRUM CASTLE (KING WAPOL)", Color(1.0, 0.45, 0.45), 44)

	# Wapol Konzern Wapometal Mega-Foundry & Smokestacks
	var foundry_pos: Vector3 = Vector3(46.0, 2.0, -12.0)
	_add_box(root, foundry_pos + Vector3(0.0, 11.0, 0.0), Vector3(36.0, 22.0, 28.0), "steel_tin")
	_add_box(root, foundry_pos + Vector3(0.0, 6.0, 14.2), Vector3(14.0, 5.0, 0.6), "molten_glow")

	# Rotating Tin Gear
	var gear: Node3D = Node3D.new()
	gear.position = foundry_pos + Vector3(-18.5, 13.0, 0.0)
	gear.rotation.y = PI * 0.5
	root.add_child(gear)
	_add_cylinder(gear, Vector3.ZERO, 6.5, 6.5, 1.8, "gold_brass", Vector3(PI * 0.5, 0.0, 0.0))
	_foundry_gears.append(gear)

	# Towering Smokestacks with rising smoke puffs
	var stacks: Array[Vector3] = [
		foundry_pos + Vector3(-10.0, 30.0, -6.0),
		foundry_pos + Vector3(10.0, 30.0, -6.0)
	]
	for idx in range(stacks.size()):
		var st_pos: Vector3 = stacks[idx]
		_add_cylinder(root, st_pos, 2.2, 3.0, 24.0, "steel_dark")
		for p in range(3):
			var puff: MeshInstance3D = _add_sphere(root, st_pos + Vector3(0.0, 14.0, 0.0), 2.8, "smoke_gray")
			_smoke_puffs.append({
				"node": puff,
				"base_y": st_pos.y + 13.0,
				"phase": float(idx) * 0.5 + float(p) * 0.33
			})

	_add_label(root, foundry_pos + Vector3(0.0, 26.0, 0.0), "WAPOL KONZERN WAPOMETAL FOUNDRY", Color(1.0, 0.75, 0.35), 34)

	# NPC Stand-ins
	_add_npc_standin(root, castle_pos + Vector3(-4.0, 0.0, 42.0), "King Wapol", Color(0.85, 0.40, 0.95))
	_add_npc_standin(root, castle_pos + Vector3(4.0, 0.0, 42.0), "Queen Kinderella", Color(1.0, 0.85, 0.95))


# ==============================================================================
# 5. GENERIC PORT FALLBACK (Remaining 12 South Blue Islands)
# ==============================================================================
func _build_generic_south_blue_port(root: Node3D, display_name: String) -> void:
	_add_box(root, Vector3(0.0, 0.5, 22.0), Vector3(12.0, 1.5, 36.0), "wood_weathered")
	_add_cylinder(root, Vector3(0.0, 0.0, -18.0), 34.0, 38.0, 4.0, "sand_tan")
	_add_box(root, Vector3(-10.0, 5.0, -12.0), Vector3(12.0, 8.0, 10.0), "stone_warm")
	_add_cylinder(root, Vector3(12.0, 9.0, -14.0), 1.8, 2.4, 16.0, "stone_granite")
	_add_sphere(root, Vector3(12.0, 18.0, -14.0), 2.0, "molten_glow")
	_add_label(root, Vector3(0.0, 14.0, -10.0), display_name.to_upper(), Color(0.92, 0.95, 1.0), 36)


# ==============================================================================
# 6. PRIMITIVE MESH & MATERIAL HELPERS
# ==============================================================================
func _init_shared_materials() -> void:
	var palette: Dictionary = {
		"wood_weathered": {"color": Color(0.38, 0.27, 0.18), "rough": 0.90, "metal": 0.0},
		"wood_light": {"color": Color(0.68, 0.50, 0.32), "rough": 0.80, "metal": 0.0},
		"sand_tan": {"color": Color(0.76, 0.68, 0.50), "rough": 0.95, "metal": 0.0},
		"stone_warm": {"color": Color(0.74, 0.69, 0.60), "rough": 0.88, "metal": 0.0},
		"stone_granite": {"color": Color(0.45, 0.47, 0.50), "rough": 0.85, "metal": 0.05},
		"stone_ancient": {"color": Color(0.52, 0.54, 0.48), "rough": 0.90, "metal": 0.0},
		"roof_slate": {"color": Color(0.24, 0.28, 0.34), "rough": 0.80, "metal": 0.1},
		"awning_red": {"color": Color(0.82, 0.20, 0.18), "rough": 0.75, "metal": 0.0},
		"brick_red": {"color": Color(0.62, 0.25, 0.20), "rough": 0.90, "metal": 0.0},
		"popsicle_pink": {"color": Color(0.92, 0.56, 0.68), "rough": 0.45, "metal": 0.05},
		"popsicle_mint": {"color": Color(0.55, 0.88, 0.78), "rough": 0.45, "metal": 0.05},
		"popsicle_cream": {"color": Color(0.95, 0.90, 0.74), "rough": 0.45, "metal": 0.05},
		"gold_brass": {"color": Color(0.88, 0.70, 0.25), "rough": 0.30, "metal": 0.85},
		"bark_ancient": {"color": Color(0.32, 0.21, 0.13), "rough": 0.95, "metal": 0.0},
		"canopy_emerald": {"color": Color(0.14, 0.46, 0.20), "rough": 0.85, "metal": 0.0},
		"canopy_light": {"color": Color(0.22, 0.58, 0.26), "rough": 0.85, "metal": 0.0},
		"grass_emerald": {"color": Color(0.20, 0.50, 0.22), "rough": 0.92, "metal": 0.0},
		"thatch_gold": {"color": Color(0.75, 0.62, 0.30), "rough": 0.95, "metal": 0.0},
		"feather_white": {"color": Color(0.94, 0.94, 0.96), "rough": 0.70, "metal": 0.0},
		"mask_dark": {"color": Color(0.18, 0.16, 0.22), "rough": 0.75, "metal": 0.0},
		"dojo_mat": {"color": Color(0.78, 0.74, 0.52), "rough": 0.85, "metal": 0.0},
		"water_cascade": {"color": Color(0.32, 0.74, 0.96), "rough": 0.15, "metal": 0.10},
		"steel_dark": {"color": Color(0.20, 0.22, 0.25), "rough": 0.45, "metal": 0.80},
		"steel_tin": {"color": Color(0.56, 0.60, 0.65), "rough": 0.35, "metal": 0.85},
		"smoke_gray": {"color": Color(0.36, 0.36, 0.38), "rough": 0.98, "metal": 0.0}
	}
	for k: String in palette.keys():
		var spec: Dictionary = palette[k]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = spec["color"]
		mat.roughness = float(spec["rough"])
		mat.metallic = float(spec["metal"])
		_materials_cache[k] = mat

	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 0.48, 0.12)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.42, 0.08)
	glow_mat.emission_energy_multiplier = 2.4
	_materials_cache["molten_glow"] = glow_mat


func _add_box(parent: Node3D, pos: Vector3, size: Vector3, mat_key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.rotation = rot
	mi.material_override = _materials_cache.get(mat_key, null)
	parent.add_child(mi)
	return mi


func _add_cylinder(parent: Node3D, pos: Vector3, top_r: float, bot_r: float, height: float, mat_key: String, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = top_r
	cyl.bottom_radius = bot_r
	cyl.height = height
	cyl.radial_segments = 16
	mi.mesh = cyl
	mi.position = pos
	mi.rotation = rot
	mi.material_override = _materials_cache.get(mat_key, null)
	parent.add_child(mi)
	return mi


func _add_sphere(parent: Node3D, pos: Vector3, radius: float, mat_key: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = radius
	sph.height = radius * 2.0
	sph.radial_segments = 12
	sph.rings = 8
	mi.mesh = sph
	mi.position = pos
	mi.material_override = _materials_cache.get(mat_key, null)
	parent.add_child(mi)
	return mi


func _add_prism_roof(parent: Node3D, pos: Vector3, size: Vector3, mat_key: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = size
	mi.mesh = prism
	mi.position = pos
	mi.material_override = _materials_cache.get(mat_key, null)
	parent.add_child(mi)
	return mi


func _add_label(parent: Node3D, pos: Vector3, text_val: String, color_val: Color, font_px: int = 32) -> Label3D:
	var lbl := Label3D.new()
	lbl.text = text_val
	lbl.position = pos
	lbl.font_size = font_px
	lbl.modulate = color_val
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = false
	parent.add_child(lbl)
	return lbl


func _add_npc_standin(parent: Node3D, pos: Vector3, npc_name: String, tunic_color: Color) -> void:
	var holder := Node3D.new()
	holder.position = pos
	parent.add_child(holder)

	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.38
	cap.height = 1.95 # 2.0m scale baseline
	body.mesh = cap
	body.position = Vector3(0.0, 1.0, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tunic_color
	mat.roughness = 0.75
	body.material_override = mat
	holder.add_child(body)

	_add_label(holder, Vector3(0.0, 2.5, 0.0), npc_name, Color(1.0, 0.96, 0.80), 26)
