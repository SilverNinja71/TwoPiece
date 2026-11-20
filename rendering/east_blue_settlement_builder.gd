class_name EastBlueSettlementBuilder
extends Node3D
## Procedural 3D East Blue Starter Sea Settlement & Port Mesh Builder (Godot 4.3+, precision=double).
##
## Spawns detailed procedural 3D MeshInstance3D settlements around East Blue coordinates
## whenever the player/camera is within 80 km (and auto-spawns Dawn Island / Foosha Village
## at startup so the player's opening harbor view is rich and alive).

const STREAM_RADIUS_M: float = 80_000.0
const WINDMILL_SPIN_RAD_PER_SEC: float = 0.85

@export var player_node_path: NodePath = NodePath("")
@export var auto_spawn_dawn_island: bool = true
@export var stream_radius_m: float = STREAM_RADIUS_M

var _spawned_settlements: Dictionary = {}
var _settlement_world_positions: Dictionary = {}
var _windmill_rotors: Array[Node3D] = []
var _materials_cache: Dictionary = {}
var _cached_player: Node3D = null


func _ready() -> void:
	_init_shared_materials()
	if auto_spawn_dawn_island:
		ensure_settlement_spawned("dawn_island")


func _process(delta: float) -> void:
	for rotor: Node3D in _windmill_rotors:
		if is_instance_valid(rotor):
			rotor.rotate_z(WINDMILL_SPIN_RAD_PER_SEC * delta)

	_sync_floating_origin_positions()
	_update_proximity_streaming()


## Ensures a specific East Blue settlement ("dawn_island", "baratie", "conomi_islands", "loguetown") is built.
func ensure_settlement_spawned(island_id: String) -> Node3D:
	if _spawned_settlements.has(island_id):
		var existing: Node3D = _spawned_settlements[island_id]
		if is_instance_valid(existing):
			return existing

	var island: Dictionary = EastBlueData.get_island(island_id)
	if island.is_empty():
		return null

	var lat_deg: float = float(island.get("lat_deg", 52.0))
	var lon_deg: float = float(island.get("lon_deg", 74.0))
	var alt_m: float = float(island.get("altitude_m", 0.0))
	var world_pos: Vector3 = EastBlueData.lat_lon_to_world_pos(lat_deg, lon_deg, alt_m)

	var root: Node3D = Node3D.new()
	root.name = "Settlement_%s" % island_id
	add_child(root)
	_settlement_world_positions[island_id] = world_pos
	_apply_spherical_transform(root, world_pos)

	match island_id:
		"dawn_island":
			_build_dawn_island_foosha(root)
		"baratie":
			_build_baratie_restaurant(root)
		"conomi_islands":
			_build_cocoyasi_village(root)
		"loguetown":
			_build_loguetown(root)
		_:
			_build_generic_port(root, island.get("name", island_id))

	_spawned_settlements[island_id] = root
	return root


## Removes a streamed settlement when far outside range (keeps Dawn Island if auto_spawn_dawn_island is true).
func despawn_settlement(island_id: String) -> void:
	if auto_spawn_dawn_island and island_id == "dawn_island":
		return
	if _spawned_settlements.has(island_id):
		var node: Node3D = _spawned_settlements[island_id]
		if is_instance_valid(node):
			node.queue_free()
		_spawned_settlements.erase(island_id)
		_settlement_world_positions.erase(island_id)


## Returns IDs of currently instantiated 3D settlements.
func get_spawned_settlement_ids() -> Array[String]:
	var ids: Array[String] = []
	for key: String in _spawned_settlements.keys():
		ids.append(key)
	return ids


# ------------------------------------------------------------------------------
# Spherical & FloatingOrigin Alignment
# ------------------------------------------------------------------------------

func _apply_spherical_transform(node: Node3D, world_pos: Vector3) -> void:
	var origin_offset: Vector3 = _get_floating_origin_offset()
	node.global_position = world_pos - origin_offset

	var up: Vector3 = world_pos.normalized()
	var ref_axis: Vector3 = Vector3.UP if absf(up.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var east: Vector3 = ref_axis.cross(up).normalized()
	var north: Vector3 = up.cross(east).normalized()
	node.global_basis = Basis(east, up, -north).orthonormalized()


func _sync_floating_origin_positions() -> void:
	var origin_offset: Vector3 = _get_floating_origin_offset()
	for island_id: String in _spawned_settlements.keys():
		var node: Node3D = _spawned_settlements[island_id]
		if is_instance_valid(node) and _settlement_world_positions.has(island_id):
			var world_pos: Vector3 = _settlement_world_positions[island_id]
			node.global_position = world_pos - origin_offset


func _get_floating_origin_offset() -> Vector3:
	if not is_inside_tree():
		return Vector3.ZERO
	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	if fo == null:
		return Vector3.ZERO
	if fo.has_method("get_origin_offset"):
		return fo.call("get_origin_offset")
	if "origin_offset" in fo:
		return fo.get("origin_offset")
	if "world_origin" in fo:
		return fo.get("world_origin")
	return Vector3.ZERO


func _update_proximity_streaming() -> void:
	var viewer_world_pos: Vector3 = _resolve_viewer_world_pos()
	if viewer_world_pos == Vector3.ZERO:
		return

	var targets: Array[String] = ["dawn_island", "baratie", "conomi_islands", "loguetown"]
	for island_id: String in targets:
		var island: Dictionary = EastBlueData.get_island(island_id)
		if island.is_empty():
			continue
		var world_pos: Vector3 = EastBlueData.lat_lon_to_world_pos(
			float(island.get("lat_deg", 0.0)),
			float(island.get("lon_deg", 0.0)),
			float(island.get("altitude_m", 0.0))
		)
		var dist_m: float = viewer_world_pos.distance_to(world_pos)
		if dist_m <= stream_radius_m:
			ensure_settlement_spawned(island_id)
		elif dist_m > stream_radius_m * 1.35:
			despawn_settlement(island_id)


func _resolve_viewer_world_pos() -> Vector3:
	var origin_offset: Vector3 = _get_floating_origin_offset()
	if not player_node_path.is_empty():
		if _cached_player == null or not is_instance_valid(_cached_player):
			_cached_player = get_node_or_null(player_node_path) as Node3D
		if _cached_player != null:
			return _cached_player.global_position + origin_offset

	var vp: Viewport = get_viewport()
	if vp != null:
		var cam: Camera3D = vp.get_camera_3d()
		if cam != null:
			return cam.global_position + origin_offset
	return Vector3.ZERO


# ------------------------------------------------------------------------------
# 1. Dawn Island / Foosha Village
# ------------------------------------------------------------------------------

func _build_dawn_island_foosha(root: Node3D) -> void:
	# Sandy cove beach & coastal hillside rising toward Mt. Colubo
	_add_cylinder(root, "SandyCove", Vector3(0.0, 0.2, 0.0), 85.0, 2.5, "sand")
	_add_cylinder(root, "VillageMeadow", Vector3(-18.0, 3.0, -35.0), 70.0, 6.0, "grass")
	_add_cylinder(root, "MtColuboFoothill", Vector3(-48.0, 22.0, -110.0), 75.0, 44.0, "grass_dark")
	_add_cylinder(root, "MtColuboPeak", Vector3(-65.0, 56.0, -155.0), 48.0, 68.0, "stone")

	# Wooden harbor pier extending into the bay
	_add_box(root, "FooshaPierDeck", Vector3(0.0, 2.0, 55.0), Vector3(8.0, 0.7, 46.0), "wood")
	for z_off: float in [36.0, 48.0, 60.0, 72.0]:
		_add_cylinder(root, "PierPilingL_%d" % int(z_off), Vector3(-3.4, 0.5, z_off), 0.35, 4.0, "wood_dark")
		_add_cylinder(root, "PierPilingR_%d" % int(z_off), Vector3(3.4, 0.5, z_off), 0.35, 4.0, "wood_dark")
	_add_lantern(root, "PierLantern", Vector3(3.2, 4.2, 74.0), Color(1.0, 0.78, 0.42))

	# Iconic Foosha Windmill with rotating wooden blades
	var mill_base: Vector3 = Vector3(-22.0, 6.0, -12.0)
	_add_cylinder(root, "WindmillTower", mill_base + Vector3(0.0, 7.5, 0.0), 4.2, 15.0, "plaster")
	_add_cylinder(root, "WindmillRoof", mill_base + Vector3(0.0, 16.5, 0.0), 4.8, 3.2, "roof_red")
	var rotor_hub: Node3D = Node3D.new()
	rotor_hub.name = "WindmillRotor"
	rotor_hub.position = mill_base + Vector3(0.0, 13.5, 4.4)
	root.add_child(rotor_hub)
	for i: int in range(4):
		var blade_pivot: Node3D = Node3D.new()
		blade_pivot.rotation.z = float(i) * PI * 0.5
		rotor_hub.add_child(blade_pivot)
		_add_box(blade_pivot, "Blade_%d" % i, Vector3(0.0, 5.2, 0.2), Vector3(1.4, 9.5, 0.18), "wood")
	_windmill_rotors.append(rotor_hub)

	# Partys Bar tavern with warm lantern glow
	var bar_pos: Vector3 = Vector3(14.0, 3.2, 10.0)
	_add_box(root, "PartysBarBody", bar_pos + Vector3(0.0, 2.5, 0.0), Vector3(12.0, 5.0, 9.0), "wood")
	_add_box(root, "PartysBarRoof", bar_pos + Vector3(0.0, 6.0, 0.0), Vector3(13.4, 2.0, 10.4), "roof_red")
	_add_box(root, "PartysBarDoor", bar_pos + Vector3(0.0, 1.4, 4.55), Vector3(2.0, 2.8, 0.2), "wood_dark")
	_add_label(root, "PartysBarSign", bar_pos + Vector3(0.0, 5.2, 4.7), "PARTYS BAR", Color(1.0, 0.9, 0.6))
	_add_lantern(root, "PartysBarLantern", bar_pos + Vector3(2.2, 3.3, 5.2), Color(1.0, 0.72, 0.35))

	# Village cottages
	_add_cottage(root, "Cottage_A", Vector3(-6.0, 3.0, 6.0), Vector3(7.0, 4.0, 6.5))
	_add_cottage(root, "Cottage_B", Vector3(28.0, 3.0, -4.0), Vector3(7.5, 4.2, 7.0))
	_add_cottage(root, "Cottage_C", Vector3(-12.0, 5.5, -28.0), Vector3(6.8, 3.8, 6.0))

	# Visible 3D NPC Stand-ins (2.0m scale)
	_add_npc_standin(root, "Makino", Vector3(14.0, 3.2, 16.5), Color(0.25, 0.65, 0.45), "Makino (Partys Bar)")
	_add_npc_standin(root, "WoopSlap", Vector3(2.0, 2.4, 34.0), Color(0.55, 0.45, 0.35), "Mayor Woop Slap")
	_add_npc_standin(root, "Gyoru", Vector3(-3.0, 2.4, 46.0), Color(0.25, 0.45, 0.75), "Gyoru (Fish Pier)")


# ------------------------------------------------------------------------------
# 2. The Baratie (Floating Sea Restaurant)
# ------------------------------------------------------------------------------

func _build_baratie_restaurant(root: Node3D) -> void:
	# Main ship hull & giant fish-head prow
	_add_box(root, "BaratieHull", Vector3(0.0, 2.0, 0.0), Vector3(26.0, 6.0, 52.0), "wood")
	_add_sphere(root, "SabagashiraFishHead", Vector3(0.0, 4.5, 29.0), 11.5, "teal")
	_add_sphere(root, "FishEyeL", Vector3(-7.0, 8.5, 34.0), 1.8, "plaster")
	_add_sphere(root, "FishEyeR", Vector3(7.0, 8.5, 34.0), 1.8, "plaster")

	# Multi-deck dining hall & rooftop cupola
	_add_box(root, "DiningHallLower", Vector3(0.0, 8.5, -4.0), Vector3(22.0, 7.0, 34.0), "plaster")
	_add_box(root, "DiningHallUpper", Vector3(0.0, 14.5, -6.0), Vector3(16.0, 5.0, 22.0), "roof_red")
	_add_cylinder(root, "BaratieMainMast", Vector3(0.0, 24.0, -6.0), 0.7, 20.0, "wood_dark")

	# Port & Starboard folding combat fin platforms
	_add_box(root, "FinPlatformPort", Vector3(-22.0, 1.2, 2.0), Vector3(16.0, 0.8, 28.0), "wood_dark")
	_add_box(root, "FinPlatformStarboard", Vector3(22.0, 1.2, 2.0), Vector3(16.0, 0.8, 28.0), "wood_dark")
	_add_lantern(root, "BaratieHallGlow", Vector3(0.0, 11.0, 14.0), Color(1.0, 0.85, 0.5))
	_add_label(root, "BaratieSign", Vector3(0.0, 18.5, 6.0), "BARATIE — SEA RESTAURANT", Color(1.0, 0.9, 0.5))

	_add_npc_standin(root, "ChefZeff", Vector3(0.0, 5.2, 16.0), Color(0.95, 0.95, 0.95), "Chef Zeff")
	_add_npc_standin(root, "Patty", Vector3(-16.0, 1.8, 8.0), Color(0.85, 0.35, 0.35), "Patty")
	_add_npc_standin(root, "Carne", Vector3(16.0, 1.8, 8.0), Color(0.75, 0.45, 0.25), "Carne")


# ------------------------------------------------------------------------------
# 3. Cocoyasi Village (Conomi Islands)
# ------------------------------------------------------------------------------

func _build_cocoyasi_village(root: Node3D) -> void:
	_add_cylinder(root, "CocoyasiBeach", Vector3(0.0, 0.2, 0.0), 75.0, 2.2, "sand")
	_add_cylinder(root, "OrchardTerrace", Vector3(0.0, 4.0, -30.0), 65.0, 8.0, "grass")
	_add_box(root, "CocoyasiDock", Vector3(0.0, 1.8, 46.0), Vector3(7.0, 0.6, 36.0), "wood")

	# Bell-mère's cottage
	_add_cottage(root, "BellmereCottage", Vector3(-18.0, 8.0, -24.0), Vector3(10.0, 4.5, 8.5))
	_add_label(root, "GroveSign", Vector3(0.0, 13.0, -20.0), "BELL-MERE'S TANGERINE GROVE", Color(1.0, 0.72, 0.22))

	# Tangerine tree orchard rows with orange fruit clusters
	for row: int in range(3):
		for col: int in range(4):
			var tx: float = -4.0 + float(col) * 10.0
			var tz: float = -18.0 - float(row) * 11.0
			_add_tangerine_tree(root, "MikanTree_%d_%d" % [row, col], Vector3(tx, 8.0, tz))

	_add_npc_standin(root, "Nojiko", Vector3(-8.0, 8.2, -16.0), Color(0.45, 0.55, 0.85), "Nojiko")
	_add_npc_standin(root, "Genzo", Vector3(2.0, 2.2, 28.0), Color(0.35, 0.55, 0.35), "Sheriff Genzo")


# ------------------------------------------------------------------------------
# 4. Loguetown (Polestar Islands)
# ------------------------------------------------------------------------------

func _build_loguetown(root: Node3D) -> void:
	# Coastal town square & harbor seawall
	_add_box(root, "ExecutionPlazaFloor", Vector3(0.0, 2.0, 0.0), Vector3(80.0, 4.0, 80.0), "stone")
	_add_box(root, "HarborSeawall", Vector3(0.0, 2.5, 48.0), Vector3(95.0, 5.0, 10.0), "stone")
	_add_box(root, "LoguetownPier", Vector3(0.0, 2.0, 68.0), Vector3(12.0, 0.8, 34.0), "wood")

	# Iconic towering Execution Platform
	_add_box(root, "ScaffoldBase", Vector3(0.0, 10.0, -10.0), Vector3(10.0, 14.0, 10.0), "wood_dark")
	_add_box(root, "ScaffoldRoof", Vector3(0.0, 18.5, -10.0), Vector3(12.0, 2.0, 12.0), "roof_red")
	_add_label(root, "ScaffoldLabel", Vector3(0.0, 21.0, -10.0), "EXECUTION PLATFORM", Color(1.0, 0.85, 0.45))

	# Ipponmatsu's Arms Shop & Gold Roger Bar
	_add_box(root, "IpponmatsuShop", Vector3(-24.0, 6.5, 10.0), Vector3(12.0, 5.0, 10.0), "plaster")
	_add_box(root, "IpponmatsuRoof", Vector3(-24.0, 10.0, 10.0), Vector3(13.2, 2.0, 11.2), "wood_dark")
	_add_label(root, "IpponmatsuSign", Vector3(-24.0, 9.2, 15.3), "IPPONMATSU ARMS SHOP", Color(0.95, 0.9, 0.8))

	_add_box(root, "GoldRogerBar", Vector3(24.0, 6.5, 12.0), Vector3(12.0, 5.0, 10.0), "wood")
	_add_box(root, "GoldRogerBarRoof", Vector3(24.0, 10.0, 12.0), Vector3(13.2, 2.0, 11.2), "roof_red")
	_add_lantern(root, "GoldRogerBarLantern", Vector3(24.0, 7.2, 17.5), Color(1.0, 0.75, 0.35))

	_add_npc_standin(root, "Ipponmatsu", Vector3(-24.0, 4.2, 17.0), Color(0.65, 0.45, 0.25), "Ipponmatsu")
	_add_npc_standin(root, "Raoul", Vector3(24.0, 4.2, 18.5), Color(0.45, 0.35, 0.3), "Raoul (Gold Roger Bar)")


func _build_generic_port(root: Node3D, display_name: String) -> void:
	_add_cylinder(root, "IslandBase", Vector3.ZERO, 40.0, 4.0, "sand")
	_add_box(root, "PortPier", Vector3(0.0, 1.5, 42.0), Vector3(6.0, 0.6, 26.0), "wood")
	_add_label(root, "PortLabel", Vector3(0.0, 8.0, 0.0), display_name, Color.WHITE)


# ------------------------------------------------------------------------------
# Primitive & Material Helpers
# ------------------------------------------------------------------------------

func _init_shared_materials() -> void:
	_register_mat("sand", Color(0.88, 0.80, 0.58), 0.9)
	_register_mat("grass", Color(0.28, 0.58, 0.24), 0.85)
	_register_mat("grass_dark", Color(0.18, 0.42, 0.18), 0.88)
	_register_mat("stone", Color(0.50, 0.50, 0.52), 0.92)
	_register_mat("wood", Color(0.55, 0.36, 0.20), 0.82)
	_register_mat("wood_dark", Color(0.32, 0.20, 0.11), 0.85)
	_register_mat("plaster", Color(0.92, 0.89, 0.82), 0.80)
	_register_mat("roof_red", Color(0.72, 0.22, 0.18), 0.78)
	_register_mat("teal", Color(0.18, 0.55, 0.60), 0.60)
	_register_mat("tangerine", Color(0.98, 0.52, 0.08), 0.55)


func _register_mat(key: String, albedo: Color, roughness: float) -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.roughness = roughness
	_materials_cache[key] = mat


func _get_mat(key: String) -> StandardMaterial3D:
	return _materials_cache.get(key, null)


func _add_box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, mat_key: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _get_mat(mat_key)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _add_cylinder(parent: Node3D, node_name: String, pos: Vector3, radius: float, height: float, mat_key: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mi.mesh = mesh
	mi.material_override = _get_mat(mat_key)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _add_sphere(parent: Node3D, node_name: String, pos: Vector3, radius: float, mat_key: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 10
	mi.mesh = mesh
	mi.material_override = _get_mat(mat_key)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _add_cottage(parent: Node3D, node_name: String, pos: Vector3, size: Vector3) -> void:
	_add_box(parent, node_name + "_Wall", pos + Vector3(0.0, size.y * 0.5, 0.0), size, "plaster")
	_add_box(parent, node_name + "_Roof", pos + Vector3(0.0, size.y + 0.7, 0.0), Vector3(size.x + 1.0, 1.4, size.z + 1.0), "roof_red")


func _add_tangerine_tree(parent: Node3D, node_name: String, pos: Vector3) -> void:
	_add_cylinder(parent, node_name + "_Trunk", pos + Vector3(0.0, 1.5, 0.0), 0.35, 3.0, "wood_dark")
	_add_sphere(parent, node_name + "_Canopy", pos + Vector3(0.0, 3.8, 0.0), 2.1, "grass")
	_add_sphere(parent, node_name + "_FruitA", pos + Vector3(1.1, 3.7, 1.2), 0.32, "tangerine")
	_add_sphere(parent, node_name + "_FruitB", pos + Vector3(-1.2, 4.1, 0.9), 0.32, "tangerine")
	_add_sphere(parent, node_name + "_FruitC", pos + Vector3(0.2, 4.5, -1.3), 0.32, "tangerine")


func _add_lantern(parent: Node3D, node_name: String, pos: Vector3, color: Color) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = node_name
	light.position = pos
	light.light_color = color
	light.light_energy = 2.4
	light.omni_range = 18.0
	parent.add_child(light)


func _add_label(parent: Node3D, node_name: String, pos: Vector3, text_str: String, color: Color) -> void:
	var lbl: Label3D = Label3D.new()
	lbl.name = node_name
	lbl.position = pos
	lbl.text = text_str
	lbl.modulate = color
	lbl.font_size = 48
	lbl.pixel_size = 0.04
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(lbl)


func _add_npc_standin(parent: Node3D, npc_name: String, pos: Vector3, tunic_color: Color, label_text: String) -> void:
	var npc_root: Node3D = Node3D.new()
	npc_root.name = "NPC_" + npc_name
	npc_root.position = pos
	parent.add_child(npc_root)

	var body: MeshInstance3D = MeshInstance3D.new()
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.38
	cap.height = 1.65
	body.mesh = cap
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = tunic_color
	body.material_override = mat
	body.position = Vector3(0.0, 0.85, 0.0)
	npc_root.add_child(body)

	var head: MeshInstance3D = MeshInstance3D.new()
	var sph: SphereMesh = SphereMesh.new()
	sph.radius = 0.24
	sph.height = 0.48
	head.mesh = sph
	head.material_override = _get_mat("plaster")
	head.position = Vector3(0.0, 1.85, 0.0)
	npc_root.add_child(head)

	_add_label(npc_root, "Nameplate", Vector3(0.0, 2.45, 0.0), label_text, Color(1.0, 0.96, 0.78))
