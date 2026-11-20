class_name ReverseMountainMeshBuilder
extends Node3D
## Procedural 3D Mesh Generator for Reverse Mountain & Twin Cape (Node A: lat=0 deg, lon=0 deg).
##
## Uses FloatingOrigin (/root/FloatingOrigin) and ReverseMountainController spline math to construct
## visible 3D ArrayMesh / MeshInstance3D geometry within activation_radius_m of Reverse Mountain
## (or centered at local origin when force_preview_at_origin = true):
##   1. Reverse Mountain +5,000 m Crimson Peak & Carved Red Line Canyon Walls
##   2. 5 Animated Hydraulic Water Canal Ribbons (4 ascending Blue + 1 descending Paradise) & Summit Basin
##   3. Twin Cape Twin Lighthouses, Glowing Beacons, Crocus's Clinic House, Pier & Flower Garden
##   4. Laboon (400 m Island Whale) Multi-Part Procedural Mesh with Scarred Brow & Openable Mouth Cavern

const PLANET_RADIUS_M: float = 16_000_000.0
const METERS_PER_DEGREE: float = (TAU * PLANET_RADIUS_M) / 360.0
const SUMMIT_ELEVATION_M: float = 5_000.0
const CANAL_BASE_WIDTH_M: float = 400.0
const LABOON_LENGTH_M: float = 400.0

@export var activation_radius_m: float = 150_000.0
@export var force_preview_at_origin: bool = false
@export var animate_water_uv_speed: float = 1.85
@export var auto_rebuild_on_ready: bool = true

var _anchor_root: Node3D
var _canal_water_mat: StandardMaterial3D
var _laboon_root: Node3D
var _laboon_jaw_pivot: Node3D
var _laboon_jolly_roger: MeshInstance3D
var _beacon_lights: Array[OmniLight3D] = []

var _rm_controller: ReverseMountainController
var _is_built: bool = false
var _node_a_normal: Vector3 = Vector3(1.0, 0.0, 0.0)
var _local_east: Vector3 = Vector3(0.0, 0.0, 1.0)
var _local_north: Vector3 = Vector3(0.0, 1.0, 0.0)
var _anim_time: float = 0.0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_init_node_a_frame()
	_rm_controller = _find_rm_controller()

	var fo: Node = _get_floating_origin()
	if fo != null and fo.has_signal("origin_rebased"):
		fo.origin_rebased.connect(_on_floating_origin_rebased)

	if auto_rebuild_on_ready:
		_evaluate_streaming_visibility()


func _process(delta: float) -> void:
	_anim_time += delta
	if not _is_built:
		return

	# Scroll hydraulic water ribbon UVs uphill / down Paradise chute
	if _canal_water_mat != null:
		_canal_water_mat.uv1_offset.y = fmod(_canal_water_mat.uv1_offset.y - animate_water_uv_speed * delta, 100.0)

	# Gentle Lighthouse beacon pulse
	for i: int in range(_beacon_lights.size()):
		var light: OmniLight3D = _beacon_lights[i]
		if is_instance_valid(light):
			light.light_energy = 14.0 + sin(_anim_time * 2.4 + float(i) * PI) * 4.0

	# Sync Laboon's 400 m body, jaw animation & Jolly Roger state with ReverseMountainController
	_update_laboon_visuals()


# ---------------------------------------------------------------------------
# Floating Origin & Proximity Streaming
# ---------------------------------------------------------------------------
func _init_node_a_frame() -> void:
	_node_a_normal = Vector3(1.0, 0.0, 0.0)
	_local_east = Vector3(0.0, 0.0, 1.0)
	_local_north = Vector3(0.0, 1.0, 0.0)


func _get_floating_origin() -> Node:
	return get_node_or_null("/root/FloatingOrigin")


func _find_rm_controller() -> ReverseMountainController:
	var parent_node: Node = get_parent()
	if parent_node != null:
		for child: Node in parent_node.get_children():
			if child is ReverseMountainController:
				return child
		if parent_node is ReverseMountainController:
			return parent_node
	return null


func _on_floating_origin_rebased(_delta_local: Vector3) -> void:
	_evaluate_streaming_visibility()


func _distance_to_reverse_mountain_m() -> float:
	var fo: Node = _get_floating_origin()
	if fo == null:
		return 0.0 if force_preview_at_origin else INF

	var lat_val: Variant = fo.get("origin_lat_deg")
	var lon_val: Variant = fo.get("origin_lon_deg")
	if lat_val == null or lon_val == null:
		return INF

	var lat_rad: float = deg_to_rad(float(lat_val))
	var lon_rad: float = deg_to_rad(float(lon_val))
	var cos_c: float = clamp(cos(lat_rad) * cos(lon_rad), -1.0, 1.0)
	var arc_dist_m: float = PLANET_RADIUS_M * acos(cos_c)
	return arc_dist_m


func _evaluate_streaming_visibility() -> void:
	var dist_m: float = _distance_to_reverse_mountain_m()
	# Reverse Mountain complex extends ~165 km from Node A; stream in within activation_radius_m of complex
	var should_show: bool = force_preview_at_origin or (dist_m <= activation_radius_m + 170_000.0)

	if should_show and not _is_built:
		build_reverse_mountain_geometry()
	elif not should_show and _is_built:
		clear_geometry()
		return

	if _is_built and is_instance_valid(_anchor_root):
		_sync_anchor_transform()


func _sync_anchor_transform() -> void:
	if not is_instance_valid(_anchor_root):
		return
	var fo: Node = _get_floating_origin()
	if force_preview_at_origin or fo == null:
		_anchor_root.position = Vector3.ZERO
		_anchor_root.basis = Basis.IDENTITY
		return

	if fo.has_method("lat_lon_alt_to_local32"):
		_anchor_root.position = fo.lat_lon_alt_to_local32(0.0, 0.0, 0.0)
	# Orient local Node-A frame (+X=East, +Y=Up, +Z=South) to PlanetSphere world axes at (0, 0)
	var planet_east: Vector3 = _local_east
	var planet_up: Vector3 = _node_a_normal
	var planet_south: Vector3 = -_local_north
	_anchor_root.basis = Basis(planet_east, planet_up, planet_south).orthonormalized()


func clear_geometry() -> void:
	if is_instance_valid(_anchor_root):
		_anchor_root.queue_free()
	_anchor_root = null
	_laboon_root = null
	_laboon_jaw_pivot = null
	_laboon_jolly_roger = null
	_beacon_lights.clear()
	_is_built = false


# ---------------------------------------------------------------------------
# Coordinate Helper (Node-A Tangent (east_m, north_m, alt_m) -> Local Curved 3D)
# ---------------------------------------------------------------------------
## Maps (east_m, north_m, alt_m) into Node-A local 3D space (+X East, +Y Up, -Z North)
## including the exact R = 16,000,000 m spherical horizon curvature drop.
func _tangent_to_anchor_local(east_m: float, north_m: float, alt_m: float) -> Vector3:
	var horiz_sq: float = east_m * east_m + north_m * north_m
	var s: float = sqrt(horiz_sq)
	if s < 1e-4:
		return Vector3(0.0, alt_m, 0.0)

	var angle: float = s / PLANET_RADIUS_M
	var r: float = PLANET_RADIUS_M + alt_m
	var radial_h: float = r * sin(angle)
	var vertical_y: float = r * cos(angle) - PLANET_RADIUS_M
	var scale_h: float = radial_h / s
	return Vector3(east_m * scale_h, vertical_y, -north_m * scale_h)


# ---------------------------------------------------------------------------
# Master Build Entry Point
# ---------------------------------------------------------------------------
func build_reverse_mountain_geometry() -> void:
	clear_geometry()
	_anchor_root = Node3D.new()
	_anchor_root.name = "ReverseMountainAnchor"
	add_child(_anchor_root)

	_sync_anchor_transform()
	_build_crimson_peak_and_canyons()
	_build_canal_water_ribbons()
	_build_twin_cape_landmarks()
	_build_laboon_mesh()
	_is_built = true


# ---------------------------------------------------------------------------
# 1. Reverse Mountain +5,000 m Crimson Peak & Carved Red Line Canyon Walls
# ---------------------------------------------------------------------------
func _get_canal_control_sets() -> Dictionary:
	return {
		&"north_blue_canal": [
			Vector3(-110_300.0, 120_100.0, 0.0),
			Vector3(-72_000.0, 78_000.0, 1_100.0),
			Vector3(-26_000.0, 28_000.0, 3_950.0),
			Vector3(-850.0, 850.0, SUMMIT_ELEVATION_M),
		],
		&"east_blue_canal": [
			Vector3(95_000.0, 135_400.0, 0.0),
			Vector3(58_000.0, 92_000.0, 1_250.0),
			Vector3(18_000.0, 34_000.0, 4_050.0),
			Vector3(350.0, 1_050.0, SUMMIT_ELEVATION_M),
		],
		&"west_blue_canal": [
			Vector3(-110_300.0, -120_100.0, 0.0),
			Vector3(-72_000.0, -78_000.0, 1_100.0),
			Vector3(-26_000.0, -28_000.0, 3_950.0),
			Vector3(-850.0, -850.0, SUMMIT_ELEVATION_M),
		],
		&"south_blue_canal": [
			Vector3(95_000.0, -135_400.0, 0.0),
			Vector3(58_000.0, -92_000.0, 1_250.0),
			Vector3(18_000.0, -34_000.0, 4_050.0),
			Vector3(350.0, -1_050.0, SUMMIT_ELEVATION_M),
		],
		&"paradise_exit_canal": [
			Vector3(1_050.0, 0.0, SUMMIT_ELEVATION_M),
			Vector3(52_000.0, 0.0, 4_200.0),
			Vector3(118_000.0, 0.0, 2_100.0),
			Vector3(148_000.0, 0.0, 0.0),
		],
	}


func _eval_bezier_local(pts: Array, t: float) -> Vector3:
	var u: float = 1.0 - t
	return (
		pts[0] * (u * u * u)
		+ pts[1] * (3.0 * u * u * t)
		+ pts[2] * (3.0 * u * t * t)
		+ pts[3] * (t * t * t)
	)


func _build_crimson_peak_and_canyons() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Build terraced crimson canyon walls flanking each of the 5 canals so every gorge is dramatic
	var canals: Dictionary = _get_canal_control_sets()
	var steps: int = 44

	for canal_id: StringName in canals.keys():
		var pts: Array = canals[canal_id]
		var prev_left_in := Vector3.ZERO
		var prev_left_top := Vector3.ZERO
		var prev_left_outer := Vector3.ZERO
		var prev_right_in := Vector3.ZERO
		var prev_right_top := Vector3.ZERO
		var prev_right_outer := Vector3.ZERO

		for i: int in range(steps + 1):
			var t: float = float(i) / float(steps)
			var p: Vector3 = _eval_bezier_local(pts, t)
			var p_next: Vector3 = _eval_bezier_local(pts, min(1.0, t + 0.01))
			var p_prev: Vector3 = _eval_bezier_local(pts, max(0.0, t - 0.01))
			var tangent_2d := Vector2(p_next.x - p_prev.x, p_next.y - p_prev.y).normalized()
			var right_2d := Vector2(tangent_2d.y, -tangent_2d.x)

			var gate_flare: float = 160.0 * pow(1.0 - t, 3.0) if canal_id != &"paradise_exit_canal" else 120.0 * pow(t, 3.0)
			var half_w: float = (CANAL_BASE_WIDTH_M + gate_flare) * 0.5
			# Wall height swells near the Red Line spine (up to +2,600 m above water surface)
			var ridge_factor: float = sin(t * PI)
			var wall_h: float = 360.0 + ridge_factor * 2_250.0 + (1.0 - t) * 180.0
			var terrace_w: float = half_w + 1_100.0 + ridge_factor * 2_400.0

			var l_in := _tangent_to_anchor_local(p.x - right_2d.x * half_w, p.y - right_2d.y * half_w, p.z - 25.0)
			var l_top := _tangent_to_anchor_local(p.x - right_2d.x * (half_w + 260.0), p.y - right_2d.y * (half_w + 260.0), p.z + wall_h)
			var l_out := _tangent_to_anchor_local(p.x - right_2d.x * terrace_w, p.y - right_2d.y * terrace_w, p.z + wall_h * 0.55)

			var r_in := _tangent_to_anchor_local(p.x + right_2d.x * half_w, p.y + right_2d.y * half_w, p.z - 25.0)
			var r_top := _tangent_to_anchor_local(p.x + right_2d.x * (half_w + 260.0), p.y + right_2d.y * (half_w + 260.0), p.z + wall_h)
			var r_out := _tangent_to_anchor_local(p.x + right_2d.x * terrace_w, p.y + right_2d.y * terrace_w, p.z + wall_h * 0.55)

			if i > 0:
				var c_base := _crimson_strata_color(p.z)
				var c_crest := _crimson_strata_color(p.z + wall_h)
				var c_outer := _crimson_strata_color(p.z + wall_h * 0.55)

				# Left sheer canyon cliff + outer mountain slope
				_emit_quad(st, prev_left_in, l_in, l_top, prev_left_top, c_base, c_base, c_crest, c_crest)
				_emit_quad(st, prev_left_top, l_top, l_out, prev_left_outer, c_crest, c_crest, c_outer, c_outer)
				# Right sheer canyon cliff + outer mountain slope
				_emit_quad(st, prev_right_top, r_top, r_in, prev_right_in, c_crest, c_crest, c_base, c_base)
				_emit_quad(st, prev_right_outer, r_out, r_top, prev_right_top, c_outer, c_outer, c_crest, c_crest)

			prev_left_in = l_in
			prev_left_top = l_top
			prev_left_outer = l_out
			prev_right_in = r_in
			prev_right_top = r_top
			prev_right_outer = r_out

	# Build Summit Caldera Ring around +5,000 m peak + flanking Red Line +10,000 m Twin Peaks
	_append_summit_ring_and_peaks(st)

	st.generate_normals()
	var rock_mesh := st.commit()

	var rock_mat := StandardMaterial3D.new()
	rock_mat.vertex_color_use_as_albedo = true
	rock_mat.roughness = 0.92
	rock_mat.metallic = 0.04
	rock_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var rock_mi := MeshInstance3D.new()
	rock_mi.name = "ReverseMountainCrimsonWalls"
	rock_mi.mesh = rock_mesh
	rock_mi.material_override = rock_mat
	_anchor_root.add_child(rock_mi)


func _append_summit_ring_and_peaks(st: SurfaceTool) -> void:
	# 4 monumental Red Line massif shoulders sitting in the quadrants between the canals (up to +10,000 m)
	var peak_offsets: Array[Vector3] = [
		Vector3(-22_000.0, 0.0, 9_400.0),     # West Red Line Shoulder
		Vector3(0.0, 32_000.0, 9_800.0),      # North Red Line Spine
		Vector3(0.0, -32_000.0, 9_800.0),     # South Red Line Spine
		Vector3(48_000.0, 26_000.0, 8_200.0), # NE Twin Cape Cliff Massif
		Vector3(48_000.0, -26_000.0, 8_200.0),# SE Twin Cape Cliff Massif
	]
	for peak: Vector3 in peak_offsets:
		var base_r: float = 16_000.0
		var top_r: float = 3_800.0
		var segs: int = 12
		var apex := _tangent_to_anchor_local(peak.x, peak.y, peak.z)
		for s_idx: int in range(segs):
			var a0: float = (float(s_idx) / float(segs)) * TAU
			var a1: float = (float(s_idx + 1) / float(segs)) * TAU
			var b0 := _tangent_to_anchor_local(peak.x + cos(a0) * base_r, peak.y + sin(a0) * base_r, 800.0)
			var b1 := _tangent_to_anchor_local(peak.x + cos(a1) * base_r, peak.y + sin(a1) * base_r, 800.0)
			var m0 := _tangent_to_anchor_local(peak.x + cos(a0) * top_r, peak.y + sin(a0) * top_r, peak.z * 0.72)
			var m1 := _tangent_to_anchor_local(peak.x + cos(a1) * top_r, peak.y + sin(a1) * top_r, peak.z * 0.72)
			var c_base := _crimson_strata_color(800.0)
			var c_mid := _crimson_strata_color(peak.z * 0.72)
			var c_top := _crimson_strata_color(peak.z)
			_emit_quad(st, b0, b1, m1, m0, c_base, c_base, c_mid, c_mid)
			_emit_tri(st, m0, m1, apex, c_mid, c_mid, c_top)


func _crimson_strata_color(alt_m: float) -> Color:
	var band: float = 0.5 + 0.5 * sin(alt_m * 0.012)
	var base_red := Color(0.54, 0.19, 0.14).lerp(Color(0.72, 0.31, 0.21), band)
	if alt_m > 4_300.0:
		# Winter Island frost & snow cap at high Reverse Mountain altitude
		var snow_t: float = clamp((alt_m - 4_300.0) / 3_500.0, 0.0, 0.85)
		return base_red.lerp(Color(0.88, 0.91, 0.96), snow_t)
	return base_red


# ---------------------------------------------------------------------------
# 2. 5 Animated Hydraulic Water Canal Ribbons + Summit Basin + Entry Gates
# ---------------------------------------------------------------------------
func _build_canal_water_ribbons() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var canals: Dictionary = _get_canal_control_sets()
	var steps: int = 56

	for canal_id: StringName in canals.keys():
		var pts: Array = canals[canal_id]
		var prev_l := Vector3.ZERO
		var prev_c := Vector3.ZERO
		var prev_r := Vector3.ZERO
		var prev_v: float = 0.0

		for i: int in range(steps + 1):
			var t: float = float(i) / float(steps)
			var p: Vector3 = _eval_bezier_local(pts, t)
			var p_next: Vector3 = _eval_bezier_local(pts, min(1.0, t + 0.01))
			var p_prev: Vector3 = _eval_bezier_local(pts, max(0.0, t - 0.01))
			var tangent_2d := Vector2(p_next.x - p_prev.x, p_next.y - p_prev.y).normalized()
			var right_2d := Vector2(tangent_2d.y, -tangent_2d.x)

			var gate_flare: float = 160.0 * pow(1.0 - t, 3.0) if canal_id != &"paradise_exit_canal" else 120.0 * pow(t, 3.0)
			var half_w: float = (CANAL_BASE_WIDTH_M + gate_flare) * 0.5
			var v_coord: float = t * 48.0

			var wl := _tangent_to_anchor_local(p.x - right_2d.x * half_w, p.y - right_2d.y * half_w, p.z + 4.0)
			var wc := _tangent_to_anchor_local(p.x, p.y, p.z + 10.0) # Cambered hydraulic jet crest
			var wr := _tangent_to_anchor_local(p.x + right_2d.x * half_w, p.y + right_2d.y * half_w, p.z + 4.0)

			if i > 0:
				var foam_col := Color(0.86, 0.96, 1.0)
				var core_col := Color(0.11, 0.55, 0.82) if canal_id != &"paradise_exit_canal" else Color(0.16, 0.68, 0.92)
				_emit_uv_quad(st, prev_l, prev_c, wc, wl, Vector2(0.0, prev_v), Vector2(0.5, prev_v), Vector2(0.5, v_coord), Vector2(0.0, v_coord), foam_col, core_col, core_col, foam_col)
				_emit_uv_quad(st, prev_c, prev_r, wr, wc, Vector2(0.5, prev_v), Vector2(1.0, prev_v), Vector2(1.0, v_coord), Vector2(0.5, v_coord), core_col, foam_col, foam_col, core_col)

			prev_l = wl
			prev_c = wc
			prev_r = wr
			prev_v = v_coord

	# Summit Convergence Whirlpool Basin Disc (+5,000 m)
	var center_pt := _tangent_to_anchor_local(0.0, 0.0, SUMMIT_ELEVATION_M - 15.0)
	var basin_segs: int = 24
	var basin_r: float = 1_450.0
	for b_idx: int in range(basin_segs):
		var a0: float = (float(b_idx) / float(basin_segs)) * TAU
		var a1: float = (float(b_idx + 1) / float(basin_segs)) * TAU
		var p0 := _tangent_to_anchor_local(cos(a0) * basin_r, sin(a0) * basin_r, SUMMIT_ELEVATION_M + 8.0)
		var p1 := _tangent_to_anchor_local(cos(a1) * basin_r, sin(a1) * basin_r, SUMMIT_ELEVATION_M + 8.0)
		_emit_uv_tri(st, center_pt, p0, p1, Vector2(0.5, 0.5), Vector2(cos(a0) * 0.5 + 0.5, sin(a0) * 0.5 + 0.5), Vector2(cos(a1) * 0.5 + 0.5, sin(a1) * 0.5 + 0.5), Color(0.2, 0.72, 0.95), Color(0.85, 0.96, 1.0), Color(0.85, 0.96, 1.0))

	st.generate_normals()
	var water_mesh := st.commit()

	_canal_water_mat = StandardMaterial3D.new()
	_canal_water_mat.vertex_color_use_as_albedo = true
	_canal_water_mat.roughness = 0.14
	_canal_water_mat.metallic = 0.12
	_canal_water_mat.emission_enabled = true
	_canal_water_mat.emission = Color(0.18, 0.52, 0.76)
	_canal_water_mat.emission_energy_multiplier = 0.35
	_canal_water_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var flow_noise := FastNoiseLite.new()
	flow_noise.frequency = 0.08
	var flow_tex := NoiseTexture2D.new()
	flow_tex.width = 128
	flow_tex.height = 128
	flow_tex.seamless = true
	flow_tex.noise = flow_noise
	_canal_water_mat.albedo_texture = flow_tex

	var water_mi := MeshInstance3D.new()
	water_mi.name = "ReverseMountainCanalWaterRibbons"
	water_mi.mesh = water_mesh
	water_mi.material_override = _canal_water_mat
	_anchor_root.add_child(water_mi)

	# Add ancient stone canal entry gates & guide lights at all 4 Blue Sea mouths
	for canal_id: StringName in [&"north_blue_canal", &"east_blue_canal", &"west_blue_canal", &"south_blue_canal"]:
		var pts: Array = canals[canal_id]
		var p0: Vector3 = pts[0]
		var p1: Vector3 = pts[1]
		var dir_2d := Vector2(p1.x - p0.x, p1.y - p0.y).normalized()
		var right_2d := Vector2(dir_2d.y, -dir_2d.x)
		_spawn_canal_entry_gate(String(canal_id), p0, right_2d)


func _spawn_canal_entry_gate(canal_name: String, gate_pos: Vector3, right_2d: Vector2) -> void:
	var gate_node := Node3D.new()
	gate_node.name = "StoneGate_" + canal_name
	_anchor_root.add_child(gate_node)

	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.62, 0.25, 0.19)
	pillar_mat.roughness = 0.88

	var half_span: float = 295.0
	for side_sign: float in [-1.0, 1.0]:
		var pillar_mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 22.0
		cyl.bottom_radius = 34.0
		cyl.height = 180.0
		pillar_mi.mesh = cyl
		pillar_mi.material_override = pillar_mat
		pillar_mi.position = _tangent_to_anchor_local(
			gate_pos.x + right_2d.x * half_span * side_sign,
			gate_pos.y + right_2d.y * half_span * side_sign,
			90.0
		)
		gate_node.add_child(pillar_mi)

	var guide_light := OmniLight3D.new()
	guide_light.position = _tangent_to_anchor_local(gate_pos.x, gate_pos.y, 130.0)
	guide_light.light_color = Color(1.0, 0.88, 0.55)
	guide_light.light_energy = 10.0
	guide_light.omni_range = 4_000.0
	gate_node.add_child(guide_light)


# ---------------------------------------------------------------------------
# 3. Twin Cape Twin Lighthouses, Crocus's Clinic House & Flower Garden
# ---------------------------------------------------------------------------
func _build_twin_cape_landmarks() -> void:
	var tc_root := Node3D.new()
	tc_root.name = "TwinCapeSettlement3D"
	_anchor_root.add_child(tc_root)

	# Two Twin Cape Lighthouses flanking the Paradise Canal exit (South Cape = Crocus's primary station)
	var cape_offsets: Array[Vector3] = [
		Vector3(155_823.0, -3_351.0, 48.0),  # South Cape Lighthouse (Crocus's active lighthouse)
		Vector3(155_823.0, 3_351.0, 48.0),   # North Cape Twin Lighthouse
	]

	for idx: int in range(cape_offsets.size()):
		var c_pos: Vector3 = cape_offsets[idx]
		var tower_root := Node3D.new()
		tower_root.name = "TwinLighthouse_" + str(idx + 1)
		tower_root.position = _tangent_to_anchor_local(c_pos.x, c_pos.y, 0.0)
		tc_root.add_child(tower_root)

		# Coastal rocky headland pedestal
		var cliff := MeshInstance3D.new()
		var cliff_mesh := CylinderMesh.new()
		cliff_mesh.top_radius = 48.0
		cliff_mesh.bottom_radius = 85.0
		cliff_mesh.height = 50.0
		cliff.mesh = cliff_mesh
		cliff.position = Vector3(0.0, 24.0, 0.0)
		var cliff_mat := StandardMaterial3D.new()
		cliff_mat.albedo_color = Color(0.56, 0.24, 0.18)
		cliff.material_override = cliff_mat
		tower_root.add_child(cliff)

		# Striped tower segments (alternating white & crimson bands)
		for seg: int in range(4):
			var band_mi := MeshInstance3D.new()
			var band_cyl := CylinderMesh.new()
			band_cyl.top_radius = 7.5 - float(seg) * 0.8
			band_cyl.bottom_radius = 8.3 - float(seg) * 0.8
			band_cyl.height = 12.0
			band_mi.mesh = band_cyl
			band_mi.position = Vector3(0.0, 54.0 + float(seg) * 12.0, 0.0)
			var band_mat := StandardMaterial3D.new()
			band_mat.albedo_color = Color(0.95, 0.94, 0.91) if seg % 2 == 0 else Color(0.84, 0.18, 0.16)
			band_mi.material_override = band_mat
			tower_root.add_child(band_mi)

		# Lantern glass housing + glowing beacon OmniLight3D
		var lantern := MeshInstance3D.new()
		var l_cyl := CylinderMesh.new()
		l_cyl.top_radius = 5.2
		l_cyl.bottom_radius = 5.2
		l_cyl.height = 7.5
		lantern.mesh = l_cyl
		lantern.position = Vector3(0.0, 99.5, 0.0)
		var l_mat := StandardMaterial3D.new()
		l_mat.albedo_color = Color(1.0, 0.92, 0.65)
		l_mat.emission_enabled = true
		l_mat.emission = Color(1.0, 0.86, 0.42)
		l_mat.emission_energy_multiplier = 2.6
		lantern.material_override = l_mat
		tower_root.add_child(lantern)

		var beacon := OmniLight3D.new()
		beacon.position = Vector3(0.0, 100.0, 0.0)
		beacon.light_color = Color(1.0, 0.9, 0.58)
		beacon.light_energy = 16.0
		beacon.omni_range = 18_000.0
		tower_root.add_child(beacon)
		_beacon_lights.append(beacon)

	# Crocus's Dock House, Wooden Pier & Flower Garden at CrocusClinicDock
	var dock_root := Node3D.new()
	dock_root.name = "CrocusClinicAndGarden"
	dock_root.position = _tangent_to_anchor_local(156_940.0, -2_234.0, 0.0)
	tc_root.add_child(dock_root)

	var house_mi := MeshInstance3D.new()
	var house_box := BoxMesh.new()
	house_box.size = Vector3(18.0, 9.0, 14.0)
	house_mi.mesh = house_box
	house_mi.position = Vector3(18.0, 5.5, 0.0)
	var house_mat := StandardMaterial3D.new()
	house_mat.albedo_color = Color(0.86, 0.78, 0.64)
	house_mi.material_override = house_mat
	dock_root.add_child(house_mi)

	var roof_mi := MeshInstance3D.new()
	var roof_prism := PrismMesh.new()
	roof_prism.size = Vector3(21.0, 6.0, 16.0)
	roof_mi.mesh = roof_prism
	roof_mi.position = Vector3(18.0, 13.0, 0.0)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.68, 0.22, 0.16)
	roof_mi.material_override = roof_mat
	dock_root.add_child(roof_mi)

	var pier_mi := MeshInstance3D.new()
	var pier_box := BoxMesh.new()
	pier_box.size = Vector3(44.0, 2.2, 12.0)
	pier_mi.mesh = pier_box
	pier_mi.position = Vector3(-14.0, 1.5, 0.0)
	var pier_mat := StandardMaterial3D.new()
	pier_mat.albedo_color = Color(0.48, 0.31, 0.17)
	pier_mi.material_override = pier_mat
	dock_root.add_child(pier_mi)

	# Flower Garden patch beside Crocus's cottage (sunflower & blossom clusters)
	var flower_colors: Array[Color] = [
		Color(1.0, 0.82, 0.12),
		Color(0.95, 0.38, 0.56),
		Color(0.98, 0.62, 0.22),
	]
	for f_idx: int in range(12):
		var fl_mi := MeshInstance3D.new()
		var fl_sph := SphereMesh.new()
		fl_sph.radius = 1.4
		fl_sph.height = 2.0
		fl_mi.mesh = fl_sph
		var angle_f: float = float(f_idx) * (TAU / 12.0)
		fl_mi.position = Vector3(18.0 + cos(angle_f) * 14.0, 1.4, sin(angle_f) * 11.0)
		var fl_mat := StandardMaterial3D.new()
		fl_mat.albedo_color = flower_colors[f_idx % flower_colors.size()]
		fl_mi.material_override = fl_mat
		dock_root.add_child(fl_mi)


# ---------------------------------------------------------------------------
# 4. Laboon (400 m Island Whale Procedural Multi-Part Mesh)
# ---------------------------------------------------------------------------
func _build_laboon_mesh() -> void:
	_laboon_root = Node3D.new()
	_laboon_root.name = "LaboonIslandWhale400m"
	_laboon_root.position = _tangent_to_anchor_local(149_200.0, 0.0, 0.0)
	_anchor_root.add_child(_laboon_root)

	# Main 400 m fusiform whale torso (oriented facing -X toward Red Line cliff)
	var body_st := SurfaceTool.new()
	body_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var len_segs: int = 22
	var rad_segs: int = 18
	var half_len: float = LABOON_LENGTH_M * 0.5

	for i: int in range(len_segs):
		var t0: float = float(i) / float(len_segs)
		var t1: float = float(i + 1) / float(len_segs)
		for j: int in range(rad_segs):
			var a0: float = (float(j) / float(rad_segs)) * TAU
			var a1: float = (float(j + 1) / float(rad_segs)) * TAU
			var p00 := _laboon_profile_vertex(t0, a0, half_len)
			var p10 := _laboon_profile_vertex(t1, a0, half_len)
			var p11 := _laboon_profile_vertex(t1, a1, half_len)
			var p01 := _laboon_profile_vertex(t0, a1, half_len)
			var c0 := _laboon_skin_color(t0, a0)
			var c1 := _laboon_skin_color(t1, a0)
			var c2 := _laboon_skin_color(t1, a1)
			var c3 := _laboon_skin_color(t0, a1)
			_emit_quad(body_st, p00, p10, p11, p01, c0, c1, c2, c3)

	body_st.generate_normals()
	var body_mi := MeshInstance3D.new()
	body_mi.name = "LaboonBodyMesh"
	body_mi.mesh = body_st.commit()
	var body_mat := StandardMaterial3D.new()
	body_mat.vertex_color_use_as_albedo = true
	body_mat.roughness = 0.58
	body_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	body_mi.material_override = body_mat
	_laboon_root.add_child(body_mi)

	# Pectoral Fins (left & right)
	var fin_mat := StandardMaterial3D.new()
	fin_mat.albedo_color = Color(0.24, 0.31, 0.42)
	fin_mat.roughness = 0.62
	for side_z: float in [-1.0, 1.0]:
		var fin := MeshInstance3D.new()
		var fin_box := BoxMesh.new()
		fin_box.size = Vector3(52.0, 8.0, 74.0)
		fin.mesh = fin_box
		fin.position = Vector3(-35.0, -14.0, side_z * 68.0)
		fin.rotation_degrees = Vector3(side_z * 14.0, side_z * -22.0, 0.0)
		fin.material_override = fin_mat
		_laboon_root.add_child(fin)

	# Tail Fluke (+200 m astern)
	var fluke := MeshInstance3D.new()
	var fluke_box := BoxMesh.new()
	fluke_box.size = Vector3(38.0, 7.0, 128.0)
	fluke.mesh = fluke_box
	fluke.position = Vector3(195.0, 6.0, 0.0)
	fluke.material_override = fin_mat
	_laboon_root.add_child(fluke)

	# Openable Lower Jaw & Dark Stomach Cavern Throat (-168 m toward nose)
	_laboon_jaw_pivot = Node3D.new()
	_laboon_jaw_pivot.name = "LaboonJawPivot"
	_laboon_jaw_pivot.position = Vector3(-130.0, -16.0, 0.0)
	_laboon_root.add_child(_laboon_jaw_pivot)

	var jaw_mi := MeshInstance3D.new()
	var jaw_box := BoxMesh.new()
	jaw_box.size = Vector3(68.0, 16.0, 48.0)
	jaw_mi.mesh = jaw_box
	jaw_mi.position = Vector3(-32.0, -6.0, 0.0)
	var jaw_mat := StandardMaterial3D.new()
	jaw_mat.albedo_color = Color(0.32, 0.36, 0.44)
	jaw_mi.material_override = jaw_mat
	_laboon_jaw_pivot.add_child(jaw_mi)

	var maw_glow := MeshInstance3D.new()
	var maw_sph := SphereMesh.new()
	maw_sph.radius = 28.0
	maw_sph.height = 46.0
	maw_glow.mesh = maw_sph
	maw_glow.position = Vector3(-164.0, -4.0, 0.0)
	var maw_mat := StandardMaterial3D.new()
	maw_mat.albedo_color = Color(0.14, 0.06, 0.08)
	maw_mat.emission_enabled = true
	maw_mat.emission = Color(0.28, 0.45, 0.62)
	maw_mat.emission_energy_multiplier = 0.6
	maw_glow.material_override = maw_mat
	_laboon_root.add_child(maw_glow)

	# Straw Hat Jolly Roger Scar Emblem on Laboon's forehead (visible once Quest 1 completes)
	_laboon_jolly_roger = MeshInstance3D.new()
	_laboon_jolly_roger.name = "LaboonJollyRogerScarPaint"
	var emblem := SphereMesh.new()
	emblem.radius = 22.0
	emblem.height = 10.0
	_laboon_jolly_roger.mesh = emblem
	_laboon_jolly_roger.position = Vector3(-186.0, 26.0, 0.0)
	_laboon_jolly_roger.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	var jr_mat := StandardMaterial3D.new()
	jr_mat.albedo_color = Color(0.98, 0.96, 0.88)
	jr_mat.emission_enabled = true
	jr_mat.emission = Color(0.95, 0.85, 0.4)
	jr_mat.emission_energy_multiplier = 0.45
	_laboon_jolly_roger.material_override = jr_mat
	_laboon_jolly_roger.visible = false
	_laboon_root.add_child(_laboon_jolly_roger)


func _laboon_profile_vertex(t: float, angle: float, half_len: float) -> Vector3:
	# t=0 is blunt island-whale brow (-half_len), t=1 is tapered tail (+half_len)
	var x: float = lerp(-half_len, half_len, t)
	var width_env: float = pow(sin(clamp(t * 0.92 + 0.08, 0.0, 1.0) * PI), 0.65)
	var blunt_head_boost: float = 1.0 + 0.38 * exp(-pow((t - 0.14) / 0.14, 2.0))
	var ry: float = 56.0 * width_env * blunt_head_boost
	var rz: float = 52.0 * width_env * blunt_head_boost
	return Vector3(x, sin(angle) * ry + 8.0, cos(angle) * rz)


func _laboon_skin_color(t: float, angle: float) -> Color:
	var belly: float = clamp(-sin(angle), 0.0, 1.0)
	var base := Color(0.24, 0.30, 0.40).lerp(Color(0.58, 0.64, 0.72), belly * 0.75)
	# Iconic crisscrossed Red Line collision scars on forehead (t < 0.26)
	if t < 0.26 and sin(angle) > -0.1:
		var scar: float = abs(sin(t * 68.0 + angle * 5.0))
		if scar > 0.88:
			return Color(0.76, 0.44, 0.46)
	return base


func _update_laboon_visuals() -> void:
	if not is_instance_valid(_laboon_root):
		return
	var base_pos: Vector3 = _tangent_to_anchor_local(149_200.0, 0.0, 0.0)
	var target_x: float = base_pos.x
	var bob_y: float = sin(_anim_time * 1.15) * 2.2
	_laboon_root.position.y = base_pos.y + bob_y

	var mouth_open_deg: float = 6.0
	if _rm_controller != null:
		if is_instance_valid(_laboon_jolly_roger):
			_laboon_jolly_roger.visible = _rm_controller.laboon_scar_jolly_roger_painted
		if _rm_controller.laboon_state == ReverseMountainController.LaboonState.MOUTH_OPEN_SWALLOW:
			mouth_open_deg = 36.0
		elif _rm_controller.laboon_state == ReverseMountainController.LaboonState.HEADBUTTING_RED_LINE:
			target_x = _tangent_to_anchor_local(148_250.0, 0.0, 0.0).x

	_laboon_root.position.x = lerp(_laboon_root.position.x, target_x, 0.08)
	if is_instance_valid(_laboon_jaw_pivot):
		_laboon_jaw_pivot.rotation_degrees.z = lerp(_laboon_jaw_pivot.rotation_degrees.z, mouth_open_deg, 0.08)


# ---------------------------------------------------------------------------
# SurfaceTool Geometry Helpers
# ---------------------------------------------------------------------------
func _emit_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


func _emit_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	_emit_tri(st, a, b, c, ca, cb, cc)
	_emit_tri(st, a, c, d, ca, cc, cd)


func _emit_uv_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uva: Vector2, uvb: Vector2, uvc: Vector2, ca: Color, cb: Color, cc: Color) -> void:
	st.set_uv(uva)
	st.set_color(ca)
	st.add_vertex(a)
	st.set_uv(uvb)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_uv(uvc)
	st.set_color(cc)
	st.add_vertex(c)


func _emit_uv_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uva: Vector2, uvb: Vector2, uvc: Vector2, uvd: Vector2, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	_emit_uv_tri(st, a, b, c, uva, uvb, uvc, ca, cb, cc)
	_emit_uv_tri(st, a, c, d, uva, uvc, uvd, ca, cc, cd)
