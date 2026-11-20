class_name IslandMeshStreamer
extends Node3D
## Procedural 3D Island & Iconic Grand Line Landmark Mesh Streamer
## Project "Blue Planet" — Godot 4.3+ Floating-Origin Compatible
##
## Queries `WorldRegistry.islands_by_id` (or `GrandLineData` fallback) and streams
## procedural 3D `ArrayMesh` / `MeshInstance3D` terrain & iconic landmarks for every
## island within 250 km of the active FloatingOrigin, plus Red Line +10,000m cliff
## wall segments when approaching the Red Line Great Circle.

signal island_streamed_in(island_id: String, local_pos: Vector3)
signal island_streamed_out(island_id: String)

const PLANET_RADIUS_M: float = 16_000_000.0
const STREAM_RADIUS_M: float = 250_000.0
const RED_LINE_TILT_RAD: float = deg_to_rad(45.0)
const RED_LINE_HALF_WIDTH_M: float = 125_000.0
const RED_LINE_ELEVATION_M: float = 10_000.0

@export var stream_radius_m: float = STREAM_RADIUS_M
@export var update_interval_sec: float = 0.5
@export var max_visual_island_radius_m: float = 3_600.0
@export var min_visual_island_radius_m: float = 420.0

var _streamed_nodes: Dictionary = {} # island_id -> Node3D
var _island_records_cache: Dictionary = {} # island_id -> Dictionary
var _red_line_segment_node: Node3D = null
var _update_accum_sec: float = 0.0

# Shared Materials
var _vertex_terrain_mat: StandardMaterial3D = null
var _water_accent_mat: StandardMaterial3D = null
var _bubble_mat: StandardMaterial3D = null
var _cloud_mat: StandardMaterial3D = null
var _red_line_mat: Material = null


func _ready() -> void:
	name = "IslandMeshStreamer"
	_init_shared_materials()
	_connect_floating_origin()
	call_deferred("refresh_streamed_islands")


func _process(delta: float) -> void:
	_update_accum_sec += delta
	if _update_accum_sec >= update_interval_sec:
		_update_accum_sec = 0.0
		refresh_streamed_islands()
	_animate_dynamic_landmarks(delta)


func _connect_floating_origin() -> void:
	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	if fo != null and fo.has_signal("origin_rebased"):
		if not fo.origin_rebased.is_connected(_on_origin_rebased):
			fo.origin_rebased.connect(_on_origin_rebased)


func _on_origin_rebased(_delta_local: Vector3) -> void:
	_reposition_all_streamed_nodes()
	refresh_streamed_islands()


func _init_shared_materials() -> void:
	_vertex_terrain_mat = StandardMaterial3D.new()
	_vertex_terrain_mat.vertex_color_use_as_albedo = true
	_vertex_terrain_mat.roughness = 0.86
	_vertex_terrain_mat.metallic = 0.02

	_water_accent_mat = StandardMaterial3D.new()
	_water_accent_mat.albedo_color = Color(0.18, 0.58, 0.82, 0.92)
	_water_accent_mat.roughness = 0.18
	_water_accent_mat.metallic = 0.08
	_water_accent_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_bubble_mat = StandardMaterial3D.new()
	_bubble_mat.albedo_color = Color(0.62, 0.88, 1.0, 0.28)
	_bubble_mat.roughness = 0.05
	_bubble_mat.metallic = 0.15
	_bubble_mat.rim_enabled = true
	_bubble_mat.rim = 0.85
	_bubble_mat.emission_enabled = true
	_bubble_mat.emission = Color(0.28, 0.65, 0.85)
	_bubble_mat.emission_energy_multiplier = 0.35
	_bubble_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bubble_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_cloud_mat = StandardMaterial3D.new()
	_cloud_mat.vertex_color_use_as_albedo = true
	_cloud_mat.roughness = 0.92
	_cloud_mat.metallic = 0.0
	_cloud_mat.emission_enabled = true
	_cloud_mat.emission = Color(0.85, 0.9, 0.98)
	_cloud_mat.emission_energy_multiplier = 0.12

	var rl_shader_path: String = "res://shaders/red_line_terrain.gdshader"
	if ResourceLoader.exists(rl_shader_path):
		var sh: Shader = load(rl_shader_path) as Shader
		if sh != null:
			var sm := ShaderMaterial.new()
			sm.shader = sh
			sm.set_shader_parameter("u_red_line_mask", 1.0)
			sm.set_shader_parameter("u_planet_radius", PLANET_RADIUS_M)
			_red_line_mat = sm
	if _red_line_mat == null:
		var fb := StandardMaterial3D.new()
		fb.vertex_color_use_as_albedo = true
		fb.roughness = 0.9
		_red_line_mat = fb


# ==============================================================================
# 1. FLOATING-ORIGIN 64-BIT COORDINATE HELPERS
# ==============================================================================
func _get_origin_lat_lon_alt() -> Dictionary:
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

	# 64-bit GDScript float fallback subtraction before casting to 32-bit Vector3
	var orig: Dictionary = _get_origin_lat_lon_alt()
	var o_xyz: PackedFloat64Array = _lat_lon_alt_to_world64(orig["lat_deg"], orig["lon_deg"], orig["alt_m"])
	var t_xyz: PackedFloat64Array = _lat_lon_alt_to_world64(lat_deg, lon_deg, alt_m)
	return Vector3(
		t_xyz[0] - o_xyz[0],
		t_xyz[1] - o_xyz[1],
		t_xyz[2] - o_xyz[2]
	)


static func _lat_lon_alt_to_world64(lat_deg: float, lon_deg: float, alt_m: float) -> PackedFloat64Array:
	var lat_r: float = deg_to_rad(clampf(lat_deg, -90.0, 90.0))
	var lon_r: float = deg_to_rad(lon_deg)
	var r: float = PLANET_RADIUS_M + alt_m
	var cos_lat: float = cos(lat_r)
	return PackedFloat64Array([
		r * cos_lat * cos(lon_r),
		r * sin(lat_r),
		r * cos_lat * sin(lon_r)
	])


static func _surface_normal(lat_deg: float, lon_deg: float) -> Vector3:
	var lat_r: float = deg_to_rad(clampf(lat_deg, -90.0, 90.0))
	var lon_r: float = deg_to_rad(lon_deg)
	var cos_lat: float = cos(lat_r)
	return Vector3(
		cos_lat * cos(lon_r),
		sin(lat_r),
		cos_lat * sin(lon_r)
	).normalized()


static func _great_circle_distance_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var p1: Vector3 = _surface_normal(lat1, lon1)
	var p2: Vector3 = _surface_normal(lat2, lon2)
	var angle: float = atan2(p1.cross(p2).length(), p1.dot(p2))
	return PLANET_RADIUS_M * angle


static func _basis_from_up(up_dir: Vector3) -> Basis:
	var y_axis: Vector3 = up_dir.normalized()
	var ref: Vector3 = Vector3.FORWARD if absf(y_axis.dot(Vector3.FORWARD)) < 0.92 else Vector3.RIGHT
	var x_axis: Vector3 = ref.cross(y_axis).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis).orthonormalized()


# ==============================================================================
# 2. STREAMING LIFECYCLE
# ==============================================================================
func _collect_island_catalog() -> Dictionary:
	var wr: Node = get_node_or_null("/root/WorldRegistry")
	if wr != null:
		var reg: Variant = wr.get("islands_by_id")
		if reg is Dictionary and not reg.is_empty():
			return reg
	return GrandLineData.get_all_islands()


func refresh_streamed_islands() -> void:
	var catalog: Dictionary = _collect_island_catalog()
	var orig: Dictionary = _get_origin_lat_lon_alt()
	var o_lat: float = float(orig["lat_deg"])
	var o_lon: float = float(orig["lon_deg"])

	var desired_ids: Dictionary = {}
	for island_id in catalog.keys():
		var rec: Dictionary = catalog[island_id]
		if not (rec is Dictionary):
			continue
		var lat: float = float(rec.get("lat_deg", rec.get("lat", 0.0)))
		var lon: float = float(rec.get("lon_deg", rec.get("lon", 0.0)))
		var alt: float = float(rec.get("alt_m", rec.get("altitude_m", 0.0)))
		var surf_dist_m: float = _great_circle_distance_m(o_lat, o_lon, lat, lon)
		if surf_dist_m <= stream_radius_m:
			desired_ids[island_id] = {
				"record": rec,
				"lat": lat,
				"lon": lon,
				"alt": alt
			}

	# Unload islands outside 250 km
	var to_remove: Array[String] = []
	for existing_id in _streamed_nodes.keys():
		if not desired_ids.has(existing_id):
			to_remove.append(existing_id)
	for rem_id in to_remove:
		var node_rem: Node = _streamed_nodes[rem_id]
		if is_instance_valid(node_rem):
			node_rem.queue_free()
		_streamed_nodes.erase(rem_id)
		_island_records_cache.erase(rem_id)
		island_streamed_out.emit(rem_id)

	# Stream in new islands & update existing positions
	for island_id in desired_ids.keys():
		var info: Dictionary = desired_ids[island_id]
		var rec: Dictionary = info["record"]
		var lat: float = info["lat"]
		var lon: float = info["lon"]
		var alt: float = info["alt"]
		var local_pos: Vector3 = _lat_lon_alt_to_local32(lat, lon, alt)

		if not _streamed_nodes.has(island_id):
			var island_root: Node3D = _build_island_root(island_id, rec)
			island_root.position = local_pos
			island_root.basis = _basis_from_up(_surface_normal(lat, lon))
			add_child(island_root)
			_streamed_nodes[island_id] = island_root
			_island_records_cache[island_id] = info
			island_streamed_in.emit(island_id, local_pos)
		else:
			var existing_node: Node3D = _streamed_nodes[island_id]
			if is_instance_valid(existing_node):
				existing_node.position = local_pos
				existing_node.basis = _basis_from_up(_surface_normal(lat, lon))
			_island_records_cache[island_id] = info

	_update_red_line_cliff_stream(o_lat, o_lon)


func _reposition_all_streamed_nodes() -> void:
	for island_id in _streamed_nodes.keys():
		var node_ref: Node3D = _streamed_nodes[island_id]
		if not is_instance_valid(node_ref) or not _island_records_cache.has(island_id):
			continue
		var info: Dictionary = _island_records_cache[island_id]
		node_ref.position = _lat_lon_alt_to_local32(info["lat"], info["lon"], info["alt"])


func _animate_dynamic_landmarks(delta: float) -> void:
	# Gentle Zunesha sway & Sabaody floating bubble drift
	if _streamed_nodes.has("zou"):
		var zou_node: Node3D = _streamed_nodes["zou"]
		if is_instance_valid(zou_node):
			var trunk: Node3D = zou_node.get_node_or_null("ZuneshaTrunk") as Node3D
			if trunk != null:
				trunk.rotation.x = sin(Time.get_ticks_msec() * 0.0008) * 0.14
	if _streamed_nodes.has("sabaody_archipelago"):
		var sab_node: Node3D = _streamed_nodes["sabaody_archipelago"]
		if is_instance_valid(sab_node):
			for child in sab_node.get_children():
				if child.name.begins_with("SoapBubble"):
					child.position.y += sin(Time.get_ticks_msec() * 0.001 + child.position.x) * 4.5 * delta


func get_streamed_island_ids() -> Array[String]:
	var ids: Array[String] = []
	for k in _streamed_nodes.keys():
		ids.append(str(k))
	return ids


func get_streamed_island_count() -> int:
	return _streamed_nodes.size()


# ==============================================================================
# 3. RED LINE +10,000M SHEER CRIMSON CLIFF WALL SEGMENT BUILDER
# ==============================================================================
func _update_red_line_cliff_stream(o_lat: float, o_lon: float) -> void:
	var u_orig: Vector3 = _surface_normal(o_lat, o_lon)
	var rl_normal: Vector3 = Vector3(0.0, cos(RED_LINE_TILT_RAD), -sin(RED_LINE_TILT_RAD)).normalized()
	var signed_dist_m: float = PLANET_RADIUS_M * asin(clampf(u_orig.dot(rl_normal), -1.0, 1.0))

	# Show Red Line wall segment when within 250 km of the Red Line centerline
	if absf(signed_dist_m) > RED_LINE_HALF_WIDTH_M + stream_radius_m:
		if _red_line_segment_node != null and is_instance_valid(_red_line_segment_node):
			_red_line_segment_node.queue_free()
			_red_line_segment_node = null
		return

	# Project origin onto the Red Line centerline
	var proj_dir: Vector3 = (u_orig - rl_normal * u_orig.dot(rl_normal)).normalized()
	var p_lat: float = rad_to_deg(asin(clampf(proj_dir.y, -1.0, 1.0)))
	var p_lon: float = rad_to_deg(atan2(proj_dir.z, proj_dir.x))
	var rl_local: Vector3 = _lat_lon_alt_to_local32(p_lat, p_lon, 0.0)

	if _red_line_segment_node == null or not is_instance_valid(_red_line_segment_node):
		_red_line_segment_node = _build_red_line_cliff_segment()
		add_child(_red_line_segment_node)

	_red_line_segment_node.position = rl_local
	var tangent_along_rl: Vector3 = proj_dir.cross(rl_normal).normalized()
	var x_axis: Vector3 = rl_normal
	var y_axis: Vector3 = proj_dir
	var z_axis: Vector3 = tangent_along_rl
	_red_line_segment_node.basis = Basis(x_axis, y_axis, z_axis).orthonormalized()


func _build_red_line_cliff_segment() -> Node3D:
	var root := Node3D.new()
	root.name = "RedLineCliffSegment"

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Build a colossal +10,000m sheer crimson sedimentary ridge (width 250 km capped locally to 120 km span)
	var half_w: float = 45_000.0
	var half_len: float = 95_000.0
	var cols: int = 12
	var rows: int = 10
	var grid: Array = []

	for r in range(rows + 1):
		var tz: float = (float(r) / float(rows)) * 2.0 - 1.0
		var z: float = tz * half_len
		var row_pts: Array = []
		for c in range(cols + 1):
			var tx: float = (float(c) / float(cols)) * 2.0 - 1.0
			var x: float = tx * half_w
			var edge_dist: float = clampf(1.0 - absf(tx), 0.0, 1.0)
			var h: float = RED_LINE_ELEVATION_M * smoothstep(0.0, 0.18, edge_dist)
			if h > 9_000.0:
				h += sin(x * 0.0002) * cos(z * 0.0002) * 320.0
			var col := Color(0.58, 0.17, 0.12)
			if h > 9_500.0:
				col = Color(0.28, 0.44, 0.22)
			elif int(h / 1_200.0) % 2 == 0:
				col = Color(0.72, 0.30, 0.16)
			row_pts.append({"pos": Vector3(x, h - 120.0, z), "col": col})
		grid.append(row_pts)

	for r in range(rows):
		for c in range(cols):
			var p00: Dictionary = grid[r][c]
			var p10: Dictionary = grid[r][c + 1]
			var p01: Dictionary = grid[r + 1][c]
			var p11: Dictionary = grid[r + 1][c + 1]
			_add_colored_tri(st, p00["pos"], p10["pos"], p11["pos"], p00["col"], p10["col"], p11["col"])
			_add_colored_tri(st, p00["pos"], p11["pos"], p01["pos"], p00["col"], p11["col"], p01["col"])

	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "RedLineCliffMesh"
	mi.mesh = st.commit()
	mi.material_override = _red_line_mat
	root.add_child(mi)
	return root


# ==============================================================================
# 4. DISPATCHER FOR STANDARD ISLANDS & ICONIC GRAND LINE LANDMARKS
# ==============================================================================
func _build_island_root(island_id: String, rec: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Island_" + island_id

	var raw_radius: float = float(rec.get("radius_m", 4_000.0))
	var vis_radius: float = clampf(raw_radius * 0.12, min_visual_island_radius_m, max_visual_island_radius_m)

	var label := Label3D.new()
	label.name = "IslandLabel"
	label.text = str(rec.get("name", island_id))
	label.position = Vector3(0.0, vis_radius * 0.48 + 45.0, 0.0)
	label.pixel_size = 0.65
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.96, 0.78)
	root.add_child(label)

	var lower_id: String = island_id.to_lower()
	if lower_id.contains("drum"):
		_build_drum_island_landmark(root, vis_radius)
	elif lower_id.contains("alabasta"):
		_build_alabasta_landmark(root, vis_radius)
	elif lower_id.contains("water_7"):
		_build_water7_landmark(root, vis_radius)
	elif lower_id.contains("sabaody"):
		_build_sabaody_landmark(root, vis_radius)
	elif lower_id.contains("skypiea"):
		_build_skypiea_landmark(root, vis_radius)
	elif lower_id.contains("fish_man"):
		_build_fish_man_island_landmark(root, vis_radius)
	elif lower_id.contains("wano"):
		_build_wano_landmark(root, vis_radius)
	elif lower_id.contains("zou"):
		_build_zunesha_landmark(root, vis_radius)
	else:
		_build_standard_island_geometry(root, rec, vis_radius)

	return root


func _build_standard_island_geometry(root: Node3D, rec: Dictionary, vis_radius: float) -> void:
	var climate: String = str(rec.get("climate", "")).to_lower()
	var peak_color := Color(0.24, 0.48, 0.22)
	var mid_color := Color(0.22, 0.56, 0.24)
	var beach_color := Color(0.88, 0.78, 0.54)
	var foliage_color := Color(0.14, 0.45, 0.16)

	if climate.contains("winter") or climate.contains("snow") or climate.contains("ice") or climate.contains("frozen"):
		peak_color = Color(0.92, 0.96, 1.0)
		mid_color = Color(0.75, 0.84, 0.92)
		beach_color = Color(0.62, 0.68, 0.74)
		foliage_color = Color(0.18, 0.34, 0.28)
	elif climate.contains("desert") or climate.contains("arid") or climate.contains("cactus"):
		peak_color = Color(0.72, 0.44, 0.24)
		mid_color = Color(0.84, 0.68, 0.40)
		beach_color = Color(0.90, 0.78, 0.48)
		foliage_color = Color(0.32, 0.52, 0.22)
	elif climate.contains("volcan") or climate.contains("magma") or climate.contains("gothic") or climate.contains("fog"):
		peak_color = Color(0.22, 0.18, 0.20)
		mid_color = Color(0.32, 0.28, 0.30)
		beach_color = Color(0.36, 0.34, 0.36)
		foliage_color = Color(0.20, 0.28, 0.22)

	var peak_h: float = vis_radius * 0.36
	var terrain_mesh: ArrayMesh = _create_radial_heightfield_mesh(vis_radius, peak_h, beach_color, mid_color, peak_color, 18, 8)
	var mi := MeshInstance3D.new()
	mi.name = "IslandTerrainMesh"
	mi.mesh = terrain_mesh
	mi.material_override = _vertex_terrain_mat
	root.add_child(mi)

	# Green canopy foliage clusters
	var seed_val: int = hash(root.name)
	for i in range(10):
		var ang: float = float(i) * (TAU / 10.0) + float(abs(seed_val) % 100) * 0.01
		var r_frac: float = 0.28 + 0.35 * float((i * 37) % 10) / 10.0
		var pos := Vector3(cos(ang) * vis_radius * r_frac, peak_h * (1.0 - r_frac) * 0.75, sin(ang) * vis_radius * r_frac)
		var crown := _create_colored_box_or_sphere_cluster(vis_radius * 0.075, foliage_color, "CanopyCluster_%d" % i)
		crown.position = pos
		root.add_child(crown)

	_add_harbor_dock_pier(root, vis_radius * 0.92, 0.0)


# ==============================================================================
# 5. ICONIC GRAND LINE LANDMARKS
# ==============================================================================
func _build_drum_island_landmark(root: Node3D, vis_radius: float) -> void:
	# Snow base plateau
	var base_mesh: ArrayMesh = _create_radial_heightfield_mesh(
		vis_radius, vis_radius * 0.18,
		Color(0.75, 0.82, 0.88), Color(0.88, 0.93, 0.98), Color(0.95, 0.98, 1.0), 16, 6
	)
	var base_mi := MeshInstance3D.new()
	base_mi.mesh = base_mesh
	base_mi.material_override = _vertex_terrain_mat
	root.add_child(base_mi)

	# Twin sheer Drum-Rock peaks (Drum Rockies)
	for idx in range(2):
		var offset_x: float = (-0.26 if idx == 0 else 0.28) * vis_radius
		var cyl := CylinderMesh.new()
		cyl.top_radius = vis_radius * (0.14 if idx == 0 else 0.11)
		cyl.bottom_radius = vis_radius * (0.19 if idx == 0 else 0.15)
		cyl.height = vis_radius * (0.85 if idx == 0 else 0.68)
		var peak := MeshInstance3D.new()
		peak.name = "DrumRockPeak_%d" % idx
		peak.mesh = cyl
		peak.position = Vector3(offset_x, cyl.height * 0.45, 0.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.58, 0.65)
		mat.roughness = 0.88
		peak.material_override = mat
		root.add_child(peak)

	# Drum Castle keep atop the main Drum Rock
	var castle := MeshInstance3D.new()
	castle.name = "DrumCastleKeep"
	var box := BoxMesh.new()
	box.size = Vector3(vis_radius * 0.14, vis_radius * 0.12, vis_radius * 0.14)
	castle.mesh = box
	castle.position = Vector3(-0.26 * vis_radius, vis_radius * 0.91, 0.0)
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.86, 0.84, 0.80)
	castle.material_override = cmat
	root.add_child(castle)
	_add_harbor_dock_pier(root, vis_radius * 0.92, 0.0)


func _build_alabasta_landmark(root: Node3D, vis_radius: float) -> void:
	var sand_mesh: ArrayMesh = _create_radial_heightfield_mesh(
		vis_radius, vis_radius * 0.16,
		Color(0.92, 0.80, 0.50), Color(0.86, 0.68, 0.38), Color(0.76, 0.52, 0.28), 18, 7
	)
	var mi := MeshInstance3D.new()
	mi.mesh = sand_mesh
	mi.material_override = _vertex_terrain_mat
	root.add_child(mi)

	# Stepped Alubarna Desert Plateau + Palace Spire
	var plateau := MeshInstance3D.new()
	plateau.name = "AlubarnaPlateau"
	var pmesh := CylinderMesh.new()
	pmesh.top_radius = vis_radius * 0.24
	pmesh.bottom_radius = vis_radius * 0.32
	pmesh.height = vis_radius * 0.22
	plateau.mesh = pmesh
	plateau.position = Vector3(0.0, vis_radius * 0.20, 0.0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.86, 0.74, 0.52)
	plateau.material_override = pmat
	root.add_child(plateau)

	var spire := MeshInstance3D.new()
	spire.name = "AlubarnaPalaceSpire"
	var smesh := CylinderMesh.new()
	smesh.top_radius = vis_radius * 0.015
	smesh.bottom_radius = vis_radius * 0.08
	smesh.height = vis_radius * 0.28
	spire.mesh = smesh
	spire.position = Vector3(0.0, vis_radius * 0.42, 0.0)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.96, 0.92, 0.82)
	spire.material_override = smat
	root.add_child(spire)
	_add_harbor_dock_pier(root, vis_radius * 0.92, 0.0)


func _build_water7_landmark(root: Node3D, vis_radius: float) -> void:
	# Stepped Venetian Fountain Pyramid (6 concentric tiers + central fountain plume)
	for tier in range(6):
		var frac: float = 1.0 - float(tier) / 6.0
		var cyl := CylinderMesh.new()
		cyl.top_radius = vis_radius * 0.78 * frac
		cyl.bottom_radius = vis_radius * 0.85 * frac
		cyl.height = vis_radius * 0.09
		var tier_mi := MeshInstance3D.new()
		tier_mi.name = "Water7Tier_%d" % tier
		tier_mi.mesh = cyl
		tier_mi.position = Vector3(0.0, float(tier) * vis_radius * 0.085 + vis_radius * 0.04, 0.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.88, 0.84, 0.78) if tier % 2 == 0 else Color(0.24, 0.62, 0.84)
		tier_mi.material_override = mat
		root.add_child(tier_mi)

	# Central Iceburg Spire
	var spire := MeshInstance3D.new()
	spire.name = "Water7FountainSpire"
	var s_cyl := CylinderMesh.new()
	s_cyl.top_radius = vis_radius * 0.02
	s_cyl.bottom_radius = vis_radius * 0.09
	s_cyl.height = vis_radius * 0.30
	spire.mesh = s_cyl
	spire.position = Vector3(0.0, vis_radius * 0.64, 0.0)
	spire.material_override = _water_accent_mat
	root.add_child(spire)
	_add_harbor_dock_pier(root, vis_radius * 0.9, 0.0)


func _build_sabaody_landmark(root: Node3D, vis_radius: float) -> void:
	# Giant Yarukiman Mangrove Trunks + Canopy + Floating Translucent Soap Bubbles
	for i in range(9):
		var ang: float = float(i) * (TAU / 9.0)
		var r_off: float = vis_radius * (0.0 if i == 0 else 0.45)
		var tx: float = cos(ang) * r_off
		var tz: float = sin(ang) * r_off

		var trunk := MeshInstance3D.new()
		trunk.name = "YarukimanMangrove_%d" % i
		var tcyl := CylinderMesh.new()
		tcyl.top_radius = vis_radius * 0.055
		tcyl.bottom_radius = vis_radius * 0.095
		tcyl.height = vis_radius * 0.55
		trunk.mesh = tcyl
		trunk.position = Vector3(tx, tcyl.height * 0.45, tz)
		var tmat := StandardMaterial3D.new()
		tmat.albedo_color = Color(0.36, 0.24, 0.14)
		trunk.material_override = tmat
		root.add_child(trunk)

		var canopy := _create_colored_box_or_sphere_cluster(vis_radius * 0.18, Color(0.16, 0.52, 0.24), "MangroveCanopy_%d" % i)
		canopy.position = Vector3(tx, tcyl.height * 0.92, tz)
		root.add_child(canopy)

	for b in range(12):
		var bang: float = float(b) * (TAU / 12.0)
		var bubble := MeshInstance3D.new()
		bubble.name = "SoapBubble_%d" % b
		var bsph := SphereMesh.new()
		bsph.radius = vis_radius * (0.03 + 0.015 * float(b % 3))
		bsph.height = bsph.radius * 2.0
		bubble.mesh = bsph
		bubble.position = Vector3(
			cos(bang) * vis_radius * 0.55,
			vis_radius * (0.28 + 0.12 * float(b % 4)),
			sin(bang) * vis_radius * 0.55
		)
		bubble.material_override = _bubble_mat
		root.add_child(bubble)


func _build_skypiea_landmark(root: Node3D, vis_radius: float) -> void:
	# Cumulonimbus Pyrobloin Island Cloud Base + Upper Yard Vearth + Giant Jack Beanstalk
	for i in range(7):
		var ang: float = float(i) * (TAU / 7.0)
		var rad: float = vis_radius * (0.45 if i == 0 else 0.28)
		var puff := MeshInstance3D.new()
		puff.name = "CumulonimbusCloud_%d" % i
		var sph := SphereMesh.new()
		sph.radius = rad
		sph.height = rad * 1.1
		puff.mesh = sph
		puff.position = Vector3(
			0.0 if i == 0 else cos(ang) * vis_radius * 0.45,
			0.0,
			0.0 if i == 0 else sin(ang) * vis_radius * 0.45
		)
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color(0.95, 0.97, 1.0)
		cmat.roughness = 0.95
		puff.material_override = cmat
		root.add_child(puff)

	# Giant Jack beanstalk rising high above Upper Yard
	var jack := MeshInstance3D.new()
	jack.name = "GiantJackBeanstalk"
	var jcyl := CylinderMesh.new()
	jcyl.top_radius = vis_radius * 0.035
	jcyl.bottom_radius = vis_radius * 0.12
	jcyl.height = vis_radius * 1.25
	jack.mesh = jcyl
	jack.position = Vector3(0.0, jcyl.height * 0.5, 0.0)
	var jmat := StandardMaterial3D.new()
	jmat.albedo_color = Color(0.18, 0.56, 0.20)
	jack.material_override = jmat
	root.add_child(jack)


func _build_fish_man_island_landmark(root: Node3D, vis_radius: float) -> void:
	# Double translucent Yarukiman resin bubble domes + Coral Ryugu Palace + Sunlight Tree Eve Glow
	for layer in range(2):
		var dome := MeshInstance3D.new()
		dome.name = "FishManBubbleDome_%d" % layer
		var sph := SphereMesh.new()
		sph.radius = vis_radius * (0.95 if layer == 0 else 0.78)
		sph.height = sph.radius * 2.0
		dome.mesh = sph
		dome.material_override = _bubble_mat
		root.add_child(dome)

	var palace := MeshInstance3D.new()
	palace.name = "RyuguPalaceCoralSpire"
	var pmesh := CylinderMesh.new()
	pmesh.top_radius = vis_radius * 0.08
	pmesh.bottom_radius = vis_radius * 0.25
	pmesh.height = vis_radius * 0.55
	palace.mesh = pmesh
	palace.position = Vector3(0.0, -vis_radius * 0.15, 0.0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.95, 0.48, 0.58)
	pmat.emission_enabled = true
	pmat.emission = Color(0.35, 0.18, 0.24)
	palace.material_override = pmat
	root.add_child(palace)

	var eve_light := OmniLight3D.new()
	eve_light.name = "SunlightTreeEveCoreLight"
	eve_light.light_color = Color(0.75, 0.92, 1.0)
	eve_light.light_energy = 4.5
	eve_light.omni_range = vis_radius * 2.5
	eve_light.position = Vector3(0.0, vis_radius * 0.65, 0.0)
	root.add_child(eve_light)


func _build_wano_landmark(root: Node3D, vis_radius: float) -> void:
	# High sheer waterfall plateau + cascading blue-white falls + Mt. Fuji cone
	var plateau := MeshInstance3D.new()
	plateau.name = "WanoBorderPlateau"
	var cyl := CylinderMesh.new()
	cyl.top_radius = vis_radius * 0.78
	cyl.bottom_radius = vis_radius * 0.88
	cyl.height = vis_radius * 0.34
	plateau.mesh = cyl
	plateau.position = Vector3(0.0, cyl.height * 0.42, 0.0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.24, 0.42, 0.22)
	plateau.material_override = pmat
	root.add_child(plateau)

	var fuji := MeshInstance3D.new()
	fuji.name = "MountFujiWano"
	var fcyl := CylinderMesh.new()
	fcyl.top_radius = vis_radius * 0.06
	fcyl.bottom_radius = vis_radius * 0.30
	fcyl.height = vis_radius * 0.45
	fuji.mesh = fcyl
	fuji.position = Vector3(0.0, vis_radius * 0.52, 0.0)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.88, 0.92, 0.98)
	fuji.material_override = fmat
	root.add_child(fuji)

	# Cascading waterfall curtain on the approach side
	var falls := MeshInstance3D.new()
	falls.name = "WanoWaterfallCurtain"
	var fbox := BoxMesh.new()
	fbox.size = Vector3(vis_radius * 0.32, vis_radius * 0.36, vis_radius * 0.04)
	falls.mesh = fbox
	falls.position = Vector3(0.0, vis_radius * 0.16, vis_radius * 0.83)
	falls.material_override = _water_accent_mat
	root.add_child(falls)


func _build_zunesha_landmark(root: Node3D, vis_radius: float) -> void:
	# Colossal walking elephant Zunesha silhouette carrying Mokomo Dukedom
	var body := MeshInstance3D.new()
	body.name = "ZuneshaBody"
	var bmesh := BoxMesh.new()
	bmesh.size = Vector3(vis_radius * 0.55, vis_radius * 0.35, vis_radius * 0.85)
	body.mesh = bmesh
	body.position = Vector3(0.0, 0.0, 0.0)
	var zmat := StandardMaterial3D.new()
	zmat.albedo_color = Color(0.54, 0.52, 0.56)
	zmat.roughness = 0.92
	body.material_override = zmat
	root.add_child(body)

	# 4 colossal legs descending into the ocean below
	var leg_offsets: Array[Vector3] = [
		Vector3(-0.20, -0.8, -0.30),
		Vector3(0.20, -0.8, -0.30),
		Vector3(-0.20, -0.8, 0.30),
		Vector3(0.20, -0.8, 0.30)
	]
	for idx in range(4):
		var leg := MeshInstance3D.new()
		leg.name = "ZuneshaLeg_%d" % idx
		var lcyl := CylinderMesh.new()
		lcyl.top_radius = vis_radius * 0.08
		lcyl.bottom_radius = vis_radius * 0.095
		lcyl.height = vis_radius * 1.6
		leg.mesh = lcyl
		leg.position = leg_offsets[idx] * vis_radius
		leg.material_override = zmat
		root.add_child(leg)

	# Animated swinging trunk
	var trunk := MeshInstance3D.new()
	trunk.name = "ZuneshaTrunk"
	var tcyl := CylinderMesh.new()
	tcyl.top_radius = vis_radius * 0.06
	tcyl.bottom_radius = vis_radius * 0.03
	tcyl.height = vis_radius * 1.1
	trunk.mesh = tcyl
	trunk.position = Vector3(0.0, -vis_radius * 0.35, vis_radius * 0.55)
	trunk.material_override = zmat
	root.add_child(trunk)

	# Mokomo Dukedom forest crown atop Zunesha's back
	var crown := _create_colored_box_or_sphere_cluster(vis_radius * 0.34, Color(0.18, 0.48, 0.22), "MokomoWhaleForest")
	crown.position = Vector3(0.0, vis_radius * 0.25, 0.0)
	root.add_child(crown)


# ==============================================================================
# 6. SHARED PROCEDURAL GEOMETRY HELPERS
# ==============================================================================
func _create_radial_heightfield_mesh(
	radius_m: float,
	peak_height_m: float,
	beach_col: Color,
	mid_col: Color,
	peak_col: Color,
	segments: int,
	rings: int
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var ring_verts: Array = []
	for r_idx in range(rings + 1):
		var frac: float = float(r_idx) / float(rings)
		var ring_pts: Array = []
		for s_idx in range(segments):
			var ang: float = (float(s_idx) / float(segments)) * TAU
			var radial_noise: float = 1.0 + 0.14 * sin(ang * 3.0) + 0.08 * cos(ang * 5.0)
			var r_dist: float = radius_m * frac * radial_noise
			var elev: float = peak_height_m * pow(maxf(0.0, 1.0 - frac), 1.45) - 6.0
			if frac > 0.85:
				elev = -12.0 * (frac - 0.85) / 0.15
			var col: Color = peak_col.lerp(mid_col, clampf(frac * 1.4, 0.0, 1.0))
			if frac > 0.72:
				col = mid_col.lerp(beach_col, clampf((frac - 0.72) / 0.28, 0.0, 1.0))
			ring_pts.append({
				"pos": Vector3(cos(ang) * r_dist, elev, sin(ang) * r_dist),
				"col": col
			})
		ring_verts.append(ring_pts)

	for r_idx in range(rings):
		for s_idx in range(segments):
			var next_s: int = (s_idx + 1) % segments
			var a: Dictionary = ring_verts[r_idx][s_idx]
			var b: Dictionary = ring_verts[r_idx][next_s]
			var c: Dictionary = ring_verts[r_idx + 1][s_idx]
			var d: Dictionary = ring_verts[r_idx + 1][next_s]
			_add_colored_tri(st, a["pos"], b["pos"], d["pos"], a["col"], b["col"], d["col"])
			_add_colored_tri(st, a["pos"], d["pos"], c["pos"], a["col"], d["col"], c["col"])

	st.generate_normals()
	return st.commit()


func _create_colored_box_or_sphere_cluster(radius_m: float, color: Color, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var sph := SphereMesh.new()
	sph.radius = radius_m
	sph.height = radius_m * 1.5
	sph.radial_segments = 10
	sph.rings = 6
	mi.mesh = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	mi.material_override = mat
	return mi


func _add_harbor_dock_pier(root: Node3D, coastal_dist_m: float, y_m: float) -> void:
	var pier := MeshInstance3D.new()
	pier.name = "HarborDockPier"
	var box := BoxMesh.new()
	box.size = Vector3(14.0, 2.2, 65.0)
	pier.mesh = box
	pier.position = Vector3(0.0, y_m + 1.1, coastal_dist_m + 20.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.28, 0.14)
	mat.roughness = 0.85
	pier.material_override = mat
	root.add_child(pier)

	var lantern := OmniLight3D.new()
	lantern.name = "PierLantern"
	lantern.light_color = Color(1.0, 0.78, 0.42)
	lantern.light_energy = 2.5
	lantern.omni_range = 45.0
	lantern.position = Vector3(0.0, y_m + 6.0, coastal_dist_m + 48.0)
	root.add_child(lantern)


static func _add_colored_tri(
	st: SurfaceTool,
	p0: Vector3, p1: Vector3, p2: Vector3,
	c0: Color, c1: Color, c2: Color
) -> void:
	st.set_color(c0)
	st.add_vertex(p0)
	st.set_color(c1)
	st.add_vertex(p1)
	st.set_color(c2)
	st.add_vertex(p2)
