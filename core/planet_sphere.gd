class_name PlanetSphere
extends Node3D
## Core 64-Bit Planetary Geodesy & 6-Face Cube-Sphere 22-Level Quadtree LOD Engine
## Project "Blue Planet" — Godot 4.3+ compiled with `precision=double` (IEEE 754 float64).
##
## Scale & Planetary Constants:
## - 1 Engine Unit = 1.0 Meter (Player height = 2.0m).
## - Planet Center = Vector3.ZERO.
## - Sea-Level Radius R = 16,000,000.0 meters (~2.5x Earth radius).
## - Equatorial Circumference C = 2 * PI * R ≈ 100,530,964.91 meters (~100,531 km).
## - Total Surface Area A = 4 * PI * R^2 ≈ 3.217e15 m^2 (~3.217 billion km^2, ~6.3x Earth).

signal ocean_zone_changed(previous_zone: String, new_zone: String)
signal vertical_layer_changed(previous_layer: String, new_layer: String)
signal calm_belt_sea_king_triggered(world_pos: Vector3, depth_m: float, sea_king_length_m: float)
signal knock_up_stream_erupted(epicenter_world_pos: Vector3, upward_velocity_ms: float)

# ==============================================================================
# 1. PLANETARY GEODESY CONSTANTS (64-BIT DOUBLE PRECISION)
# ==============================================================================
const SEA_LEVEL_RADIUS: float = 16_000_000.0
const EQUATORIAL_CIRCUMFERENCE: float = TAU * SEA_LEVEL_RADIUS # ~100,530,964.91487338 m
const SURFACE_AREA_M2: float = 4.0 * PI * SEA_LEVEL_RADIUS * SEA_LEVEL_RADIUS
const GRAVITY_ACCEL_MS2: float = 9.81
const PLAYER_REFERENCE_HEIGHT_M: float = 2.0

# Great Circle Geometry Constants
const RED_LINE_TILT_RAD: float = deg_to_rad(45.0)
const RED_LINE_WIDTH_M: float = 250_000.0
const RED_LINE_HALF_WIDTH_M: float = 125_000.0
const RED_LINE_ELEVATION_M: float = 10_000.0

const GRAND_LINE_TILT_RAD: float = deg_to_rad(-45.0)
const GRAND_LINE_WIDTH_M: float = 600_000.0
const GRAND_LINE_HALF_WIDTH_M: float = 300_000.0

const CALM_BELT_WIDTH_M: float = 150_000.0
const CALM_BELT_OUTER_OFFSET_M: float = GRAND_LINE_HALF_WIDTH_M + CALM_BELT_WIDTH_M # 450,000.0 m

# Antipodal Great Circle Intersection Nodes
# Node A: Reverse Mountain (lat = 0 deg, lon = 0 deg) -> +5,000m hydraulic summit, 400m canals
const NODE_A_REVERSE_MOUNTAIN_LAT_DEG: float = 0.0
const NODE_A_REVERSE_MOUNTAIN_LON_DEG: float = 0.0
const REVERSE_MOUNTAIN_RADIUS_M: float = 180_000.0
const REVERSE_MOUNTAIN_SUMMIT_M: float = 5_000.0
const REVERSE_MOUNTAIN_CANAL_WIDTH_M: float = 400.0

# Node B: Mary Geoise (+10,000m) / Sabaody & New Marineford (0m) / Fish-Man Island (-10,000m)
const NODE_B_MARY_GEOISE_LAT_DEG: float = 0.0
const NODE_B_MARY_GEOISE_LON_DEG: float = 180.0
const FISH_MAN_ISLAND_CAVERN_RADIUS_M: float = 65_000.0
const FISH_MAN_ISLAND_DEPTH_M: float = -10_000.0

# Vertical Layer Elevations (Meters Relative to Sea Level R = 16,000,000.0m)
const LAYER_ABYSSAL_FLOOR_M: float = -10_000.0
const LAYER_DEEP_SEA_KING_NEST_M: float = -2_000.0
const LAYER_BLUE_SEA_SURFACE_M: float = 0.0
const LAYER_WHITE_SEA_M: float = 7_000.0
const LAYER_WHITE_WHITE_SEA_M: float = 10_000.0

# Cube-Sphere 22-Level Quadtree Constants
const QUADTREE_MAX_LEVEL: int = 22
const QUADTREE_SPLIT_DISTANCE_FACTOR: float = 2.25
const CHUNK_GRID_RESOLUTION: int = 32 # 32x32 vertices per leaf chunk (~0.12m spacing at Level 22)

# Six Cube Faces (Unit Cube Normals & Tangents)
enum CubeFace {
	POS_X = 0, # Front (+X: Lat 0, Lon 0 -> Reverse Mountain face)
	NEG_X = 1, # Back (-X: Lat 0, Lon 180 -> Mary Geoise / Fish-Man Island face)
	POS_Y = 2, # North Pole (+Y)
	NEG_Y = 3, # South Pole (-Y)
	POS_Z = 4, # East (+Z: Lat 0, Lon +90)
	NEG_Z = 5  # West (-Z: Lat 0, Lon -90)
}

enum OceanRegion {
	EAST_BLUE,
	WEST_BLUE,
	NORTH_BLUE,
	SOUTH_BLUE,
	RED_LINE,
	REVERSE_MOUNTAIN,
	CALM_BELT_NORTH,
	CALM_BELT_SOUTH,
	GRAND_LINE_PARADISE,
	GRAND_LINE_NEW_WORLD,
	SABAODY_MARY_GEOISE_NODE
}

enum VerticalLayer {
	ABYSSAL_TRENCH,     # -10,000m to -5,000m (Fish-Man Island, Sea Forests, Old Wano)
	BATHYPELAGIC_ZONE,  # -5,000m to -200m (Calm Belt Sea King Nests, Impel Down Lower Levels)
	BLUE_SEA_SURFACE,   # -200m to +6,500m (Standard Four Blues & Grand Line Sailing)
	WHITE_SEA,          # +6,500m to +9,200m (+7,000m Cloud Gate / High West)
	WHITE_WHITE_SEA     # +9,200m to +15,000m (+10,000m Skypiea, Upper Yard, Birka, Mary Geoise)
}

# ==============================================================================
# 2. INNER CLASS: CUBE-SPHERE 22-LEVEL QUADTREE NODE
# ==============================================================================
class QuadtreeChunkNode extends RefCounted:
	var face: int
	var level: int
	var uv_min: Vector2
	var uv_max: Vector2
	var center_sphere_pos: Vector3
	var bounding_edge_length_m: float
	var children: Array[QuadtreeChunkNode] = []
	var is_leaf: bool = true

	func _init(
		p_face: int,
		p_level: int,
		p_uv_min: Vector2,
		p_uv_max: Vector2,
		p_center_sphere_pos: Vector3,
		p_edge_length_m: float
	) -> void:
		face = p_face
		level = p_level
		uv_min = p_uv_min
		uv_max = p_uv_max
		center_sphere_pos = p_center_sphere_pos
		bounding_edge_length_m = p_edge_length_m

# ==============================================================================
# 3. STATE VARIABLES
# ==============================================================================
var quadtree_roots: Array[QuadtreeChunkNode] = []
var active_leaf_chunks: Array[QuadtreeChunkNode] = []
var tracked_camera_world_pos: Vector3 = Vector3(SEA_LEVEL_RADIUS, 0.0, 0.0)
var _sea_king_spawn_cooldown_sec: float = 0.0

# Great Circle Unit Normal Vectors
# At Node A (lat=0, lon=0 -> +X = (1, 0, 0)) and Node B (lat=0, lon=180 -> -X = (-1, 0, 0)),
# any plane containing the X-axis has normal N = (0, ny, nz).
# Red Line is tilted +45 deg to the equatorial plane (Y-axis): N_RL = (0, cos(45°), -sin(45°)).
# Grand Line is perpendicular to Red Line (tilted -45 deg): N_GL = (0, cos(45°), +sin(45°)).
var _red_line_normal: Vector3 = Vector3(0.0, cos(RED_LINE_TILT_RAD), -sin(RED_LINE_TILT_RAD)).normalized()
var _grand_line_normal: Vector3 = Vector3(0.0, cos(GRAND_LINE_TILT_RAD), -sin(GRAND_LINE_TILT_RAD)).normalized()

# ==============================================================================
# 4. LIFECYCLE & INITIALIZATION
# ==============================================================================
func _ready() -> void:
	name = "PlanetSphere"
	global_position = Vector3.ZERO
	_initialize_cube_sphere_roots()
	update_quadtree_lod(tracked_camera_world_pos)

func _physics_process(delta: float) -> void:
	if _sea_king_spawn_cooldown_sec > 0.0:
		_sea_king_spawn_cooldown_sec = maxf(0.0, _sea_king_spawn_cooldown_sec - delta)

func _initialize_cube_sphere_roots() -> void:
	quadtree_roots.clear()
	var root_edge_m: float = SEA_LEVEL_RADIUS * (PI * 0.5) # ~25,132,741m arc per face, ~16,000km chord
	for face_idx in range(6):
		var center_pos: Vector3 = cube_uv_to_sphere_point(face_idx, Vector2(0.5, 0.5), 0.0)
		var root_node := QuadtreeChunkNode.new(
			face_idx,
			0,
			Vector2.ZERO,
			Vector2.ONE,
			center_pos,
			root_edge_m
		)
		quadtree_roots.append(root_node)

# ==============================================================================
# 5. 64-BIT SPHERICAL COORDINATE CONVERSIONS: (LAT, LON, ALT) <-> VECTOR3
# ==============================================================================
## Converts Spherical Geodetic Coordinates (latitude_deg in [-90, +90],
## longitude_deg in [-180, +180] or [0, 360], altitude_m relative to R=16,000,000.0m)
## into a 64-bit World Space Vector3.
## Convention:
## - (lat=0, lon=0)   -> +X axis: Vector3(R + alt, 0, 0) [Node A: Reverse Mountain]
## - (lat=0, lon=+90) -> +Z axis: Vector3(0, 0, R + alt) [East Blue / South Blue Meridian]
## - (lat=0, lon=180) -> -X axis: Vector3(-(R + alt), 0, 0) [Node B: Mary Geoise / Fish-Man Island]
## - (lat=+90, any)   -> +Y axis: Vector3(0, R + alt, 0) [North Pole]
static func lat_lon_alt_to_world(lat_deg: float, lon_deg: float, alt_m: float = 0.0) -> Vector3:
	var lat_rad: float = deg_to_rad(clampf(lat_deg, -90.0, 90.0))
	var lon_rad: float = deg_to_rad(lon_deg)
	var radius: float = SEA_LEVEL_RADIUS + alt_m
	var cos_lat: float = cos(lat_rad)
	var x: float = radius * cos_lat * cos(lon_rad)
	var y: float = radius * sin(lat_rad)
	var z: float = radius * cos_lat * sin(lon_rad)
	return Vector3(x, y, z)

## Converts a 64-bit World Space Vector3 back to a Dictionary with:
## { "lat_deg": float, "lon_deg": float, "lon_360_deg": float, "alt_m": float, "radius_m": float }
static func world_to_lat_lon_alt(world_pos: Vector3) -> Dictionary:
	var radius: float = world_pos.length()
	if radius < 0.0001:
		return {
			"lat_deg": 0.0,
			"lon_deg": 0.0,
			"lon_360_deg": 0.0,
			"alt_m": -SEA_LEVEL_RADIUS,
			"radius_m": 0.0
		}
	var unit_dir: Vector3 = world_pos / radius
	var lat_rad: float = asin(clampf(unit_dir.y, -1.0, 1.0))
	var lon_rad: float = atan2(unit_dir.z, unit_dir.x)
	var lon_deg: float = rad_to_deg(lon_rad)
	var lon_360: float = fposmod(lon_deg, 360.0)
	return {
		"lat_deg": rad_to_deg(lat_rad),
		"lon_deg": lon_deg,
		"lon_360_deg": lon_360,
		"alt_m": radius - SEA_LEVEL_RADIUS,
		"radius_m": radius
	}

## Computes the Great-Circle surface arc distance (in meters) at sea level between two coordinates.
static func great_circle_distance_m(lat1_deg: float, lon1_deg: float, lat2_deg: float, lon2_deg: float) -> float:
	var p1: Vector3 = lat_lon_alt_to_world(lat1_deg, lon1_deg, 0.0).normalized()
	var p2: Vector3 = lat_lon_alt_to_world(lat2_deg, lon2_deg, 0.0).normalized()
	var central_angle_rad: float = atan2(p1.cross(p2).length(), p1.dot(p2))
	return SEA_LEVEL_RADIUS * central_angle_rad

## Computes the unit tangent vector on the sphere surface at `from_world_pos` pointing along
## the shortest Great-Circle geodesic toward `to_world_pos`.
static func geodesic_tangent_direction(from_world_pos: Vector3, to_world_pos: Vector3) -> Vector3:
	var u_from: Vector3 = from_world_pos.normalized()
	var u_to: Vector3 = to_world_pos.normalized()
	var tangent: Vector3 = u_to - u_from * u_from.dot(u_to)
	if tangent.length_squared() < 1e-12:
		# Antipodal fallback: project local north
		tangent = Vector3.UP - u_from * u_from.dot(Vector3.UP)
	return tangent.normalized()

## Solves the spherical intersection of two Great-Circle geodesic arcs (A1 <-> A2) and (B1 <-> B2).
## Used by the Road Poneglyph Triangulation System to pinpoint Laugh Tale on the 16,000km sphere.
static func intersect_great_circle_arcs(
	a1_lat: float, a1_lon: float,
	a2_lat: float, a2_lon: float,
	b1_lat: float, b1_lon: float,
	b2_lat: float, b2_lon: float
) -> Dictionary:
	var u_a1: Vector3 = lat_lon_alt_to_world(a1_lat, a1_lon, 0.0).normalized()
	var u_a2: Vector3 = lat_lon_alt_to_world(a2_lat, a2_lon, 0.0).normalized()
	var u_b1: Vector3 = lat_lon_alt_to_world(b1_lat, b1_lon, 0.0).normalized()
	var u_b2: Vector3 = lat_lon_alt_to_world(b2_lat, b2_lon, 0.0).normalized()

	var normal_a: Vector3 = u_a1.cross(u_a2).normalized()
	var normal_b: Vector3 = u_b1.cross(u_b2).normalized()
	var line_dir: Vector3 = normal_a.cross(normal_b)
	if line_dir.length_squared() < 1e-12:
		return {"valid": false, "reason": "Great circle planes are collinear"}

	var candidate_pos: Vector3 = line_dir.normalized()
	var candidate_neg: Vector3 = -candidate_pos
	var centroid: Vector3 = (u_a1 + u_a2 + u_b1 + u_b2).normalized()
	var chosen_dir: Vector3 = candidate_pos if candidate_pos.dot(centroid) >= 0.0 else candidate_neg
	var world_hit: Vector3 = chosen_dir * SEA_LEVEL_RADIUS
	var coords: Dictionary = world_to_lat_lon_alt(world_hit)
	return {
		"valid": true,
		"world_pos": world_hit,
		"lat_deg": coords["lat_deg"],
		"lon_deg": coords["lon_deg"],
		"lon_360_deg": coords["lon_360_deg"]
	}

# ==============================================================================
# 6. CUBE-SPHERE TANGENTIAL PROJECTION & 22-LEVEL QUADTREE LOD
# ==============================================================================
## Maps a CubeFace [0..5] and normalized face UV in [0, 1]^2 to a unit cube point,
## then applies tangential spherical warp and projects to `SEA_LEVEL_RADIUS + extra_alt_m`.
func cube_uv_to_sphere_point(face: int, uv: Vector2, extra_alt_m: float = 0.0) -> Vector3:
	# Tangential warp reduces cube-corner distortion across the 6 cube faces
	var s: float = tan((uv.x * 2.0 - 1.0) * (PI * 0.25))
	var t: float = tan((uv.y * 2.0 - 1.0) * (PI * 0.25))
	var p_cube: Vector3
	match face:
		CubeFace.POS_X:
			p_cube = Vector3(1.0, t, s)
		CubeFace.NEG_X:
			p_cube = Vector3(-1.0, t, -s)
		CubeFace.POS_Y:
			p_cube = Vector3(-s, 1.0, t)
		CubeFace.NEG_Y:
			p_cube = Vector3(s, -1.0, t)
		CubeFace.POS_Z:
			p_cube = Vector3(-s, t, 1.0)
		CubeFace.NEG_Z, _:
			p_cube = Vector3(s, t, -1.0)
	var unit_sphere: Vector3 = p_cube.normalized()
	var procedural_elevation: float = sample_macro_elevation_m(unit_sphere)
	return unit_sphere * (SEA_LEVEL_RADIUS + procedural_elevation + extra_alt_m)

## Computes the edge length (in meters) of a Quadtree chunk at a given depth level [0..22].
## Level 0  = ~16,000,000.0 m (~16,000 km cube face)
## Level 22 = ~3.8147 m chunk edge (with 32x32 vertices -> ~0.12m vertex spacing at player feet)
static func get_quadtree_chunk_edge_m(level: int) -> float:
	var clamped_level: int = clampi(level, 0, QUADTREE_MAX_LEVEL)
	return SEA_LEVEL_RADIUS / float(1 << clamped_level)

## Updates the 22-level Cube-Sphere Quadtree around `camera_world_pos` and populates `active_leaf_chunks`.
func update_quadtree_lod(camera_world_pos: Vector3) -> int:
	tracked_camera_world_pos = camera_world_pos
	active_leaf_chunks.clear()
	for root in quadtree_roots:
		_subdivide_quadtree_recursive(root, camera_world_pos)
	return active_leaf_chunks.size()

func _subdivide_quadtree_recursive(node: QuadtreeChunkNode, camera_world_pos: Vector3) -> void:
	var dist_to_camera: float = node.center_sphere_pos.distance_to(camera_world_pos)
	var split_threshold: float = node.bounding_edge_length_m * QUADTREE_SPLIT_DISTANCE_FACTOR

	if node.level < QUADTREE_MAX_LEVEL and dist_to_camera < split_threshold:
		if node.children.is_empty():
			var uv_mid: Vector2 = (node.uv_min + node.uv_max) * 0.5
			var next_level: int = node.level + 1
			var child_edge_m: float = get_quadtree_chunk_edge_m(next_level)
			var quadrants: Array[ Array ] = [
				[node.uv_min, uv_mid],
				[Vector2(uv_mid.x, node.uv_min.y), Vector2(node.uv_max.x, uv_mid.y)],
				[Vector2(node.uv_min.x, uv_mid.y), Vector2(uv_mid.x, node.uv_max.y)],
				[uv_mid, node.uv_max]
			]
			for quad in quadrants:
				var c_min: Vector2 = quad[0]
				var c_max: Vector2 = quad[1]
				var c_center_uv: Vector2 = (c_min + c_max) * 0.5
				var c_world_pos: Vector3 = cube_uv_to_sphere_point(node.face, c_center_uv, 0.0)
				node.children.append(
					QuadtreeChunkNode.new(node.face, next_level, c_min, c_max, c_world_pos, child_edge_m)
				)
		node.is_leaf = false
		for child in node.children:
			_subdivide_quadtree_recursive(child, camera_world_pos)
	else:
		node.children.clear()
		node.is_leaf = true
		active_leaf_chunks.append(node)

# ==============================================================================
# 7. MACRO-GEOGRAPHIC MATHEMATICAL MASKS (RED LINE, GRAND LINE, CALM BELTS)
# ==============================================================================
## Signed perpendicular surface distance (in meters) from the Red Line Great Circle centerline.
func get_signed_distance_to_red_line_m(unit_sphere_dir: Vector3) -> float:
	var sin_angle: float = clampf(unit_sphere_dir.dot(_red_line_normal), -1.0, 1.0)
	return SEA_LEVEL_RADIUS * asin(sin_angle)

## Signed perpendicular surface distance (in meters) from the Grand Line Great Circle centerline.
func get_signed_distance_to_grand_line_m(unit_sphere_dir: Vector3) -> float:
	var sin_angle: float = clampf(unit_sphere_dir.dot(_grand_line_normal), -1.0, 1.0)
	return SEA_LEVEL_RADIUS * asin(sin_angle)

## Great-circle distance (in meters) from Node A: Reverse Mountain (lat=0, lon=0 -> +X).
func get_distance_to_reverse_mountain_m(unit_sphere_dir: Vector3) -> float:
	var node_a_dir := Vector3(1.0, 0.0, 0.0)
	var angle: float = atan2(unit_sphere_dir.cross(node_a_dir).length(), unit_sphere_dir.dot(node_a_dir))
	return SEA_LEVEL_RADIUS * angle

## Great-circle distance (in meters) from Node B: Mary Geoise / Fish-Man Island (lat=0, lon=180 -> -X).
func get_distance_to_mary_geoise_node_m(unit_sphere_dir: Vector3) -> float:
	var node_b_dir := Vector3(-1.0, 0.0, 0.0)
	var angle: float = atan2(unit_sphere_dir.cross(node_b_dir).length(), unit_sphere_dir.dot(node_b_dir))
	return SEA_LEVEL_RADIUS * angle

## Evaluates the macro-topographic elevation (in meters relative to R=16,000,000.0m) at `unit_sphere_dir`.
## Carves the +10,000m Red Line continent ring, the +5,000m Reverse Mountain peak with its 4 ascending
## hydraulic canals and 1 descending Twin Cape canal, and Sabaody / Red Port channels.
func sample_macro_elevation_m(unit_sphere_dir: Vector3) -> float:
	var u: Vector3 = unit_sphere_dir.normalized()
	var dist_rm: float = get_distance_to_reverse_mountain_m(u)

	# 1. Node A: Reverse Mountain (+5,000m cone with 4 Blue canals + 1 Paradise exit canal)
	if dist_rm <= REVERSE_MOUNTAIN_RADIUS_M:
		var t_rm: float = 1.0 - (dist_rm / REVERSE_MOUNTAIN_RADIUS_M)
		var base_peak_m: float = REVERSE_MOUNTAIN_SUMMIT_M * smoothstep(0.0, 1.0, t_rm)
		# Check if point falls inside one of the 4 diagonal Blue canals or the eastern Twin Cape canal
		var local_angle: float = atan2(u.y, u.z) # Angle around the +X axis
		var canal_angles: Array[float] = [
			deg_to_rad(45.0),   # North-East canal (East Blue entry)
			deg_to_rad(135.0),  # North-West canal (North Blue entry)
			deg_to_rad(-135.0), # South-West canal (West Blue entry)
			deg_to_rad(-45.0),  # South-East canal (South Blue entry)
			0.0                 # Eastward descending canal into Twin Cape (Paradise)
		]
		for c_angle in canal_angles:
			var ang_diff: float = absf( wrapf(local_angle - c_angle, -PI, PI) )
			var arc_offset_m: float = dist_rm * sin(minf(ang_diff, PI * 0.5))
			if arc_offset_m <= REVERSE_MOUNTAIN_CANAL_WIDTH_M * 0.5:
				# Hydraulic water channel carved 25m below the mountain slope
				return maxf(0.0, base_peak_m - 25.0)
		return base_peak_m

	# 2. Red Line Great Circle Mountain Ring (+10,000m sheer red cliffs, 250 km wide)
	var dist_rl: float = absf(get_signed_distance_to_red_line_m(u))
	if dist_rl <= RED_LINE_HALF_WIDTH_M:
		# Sheer cliff wall ramp over the outer 4,000m edge up to the +10,000m plateau
		var cliff_factor: float = clampf((RED_LINE_HALF_WIDTH_M - dist_rl) / 4_000.0, 0.0, 1.0)
		return RED_LINE_ELEVATION_M * smoothstep(0.0, 1.0, cliff_factor)

	return 0.0

## Classifies any 64-bit `world_pos` into its canonical `OceanRegion` enum & metadata dictionary.
func classify_global_coordinates(world_pos: Vector3) -> Dictionary:
	var coords: Dictionary = world_to_lat_lon_alt(world_pos)
	var u: Vector3 = world_pos.normalized()
	var dist_rl: float = absf(get_signed_distance_to_red_line_m(u))
	var signed_dist_gl: float = get_signed_distance_to_grand_line_m(u)
	var abs_dist_gl: float = absf(signed_dist_gl)
	var dist_rm: float = get_distance_to_reverse_mountain_m(u)
	var dist_mg: float = get_distance_to_mary_geoise_node_m(u)

	var region_enum: OceanRegion = OceanRegion.EAST_BLUE
	var region_name: String = "East Blue"
	var compass_functional: bool = true
	var wind_multiplier: float = 1.0

	if dist_rm <= REVERSE_MOUNTAIN_RADIUS_M:
		region_enum = OceanRegion.REVERSE_MOUNTAIN
		region_name = "Reverse Mountain & Twin Cape (Node A)"
		compass_functional = false
	elif dist_mg <= FISH_MAN_ISLAND_CAVERN_RADIUS_M:
		region_enum = OceanRegion.SABAODY_MARY_GEOISE_NODE
		if coords["alt_m"] <= -5_000.0:
			region_name = "Fish-Man Island Abyssal Cavern (-10,000m)"
		elif coords["alt_m"] >= 5_000.0:
			region_name = "Holy Land Mary Geoise (+10,000m)"
		else:
			region_name = "Sabaody Archipelago / Red Port (Node B)"
		compass_functional = false
	elif dist_rl <= RED_LINE_HALF_WIDTH_M:
		region_enum = OceanRegion.RED_LINE
		region_name = "The Red Line (+10,000m Continent Ring)"
		compass_functional = false
	elif abs_dist_gl <= GRAND_LINE_HALF_WIDTH_M:
		compass_functional = false
		if coords["lon_360_deg"] >= 0.0 and coords["lon_360_deg"] <= 180.0:
			region_enum = OceanRegion.GRAND_LINE_PARADISE
			region_name = "Grand Line — Paradise"
		else:
			region_enum = OceanRegion.GRAND_LINE_NEW_WORLD
			region_name = "Grand Line — The New World"
	elif abs_dist_gl <= CALM_BELT_OUTER_OFFSET_M:
		compass_functional = false
		wind_multiplier = 0.0 # Zero wind inside the 150km Calm Belts
		if signed_dist_gl > 0.0:
			region_enum = OceanRegion.CALM_BELT_NORTH
			region_name = "North Calm Belt"
		else:
			region_enum = OceanRegion.CALM_BELT_SOUTH
			region_name = "South Calm Belt"
	else:
		# Outer Four Blues quadrant classification
		var lat: float = coords["lat_deg"]
		var lon: float = coords["lon_deg"]
		if lat >= 0.0 and lon >= 0.0:
			region_enum = OceanRegion.EAST_BLUE
			region_name = "East Blue (The Sea of Dawn)"
		elif lat >= 0.0 and lon < 0.0:
			region_enum = OceanRegion.NORTH_BLUE
			region_name = "North Blue"
		elif lat < 0.0 and lon < 0.0:
			region_enum = OceanRegion.WEST_BLUE
			region_name = "West Blue"
		else:
			region_enum = OceanRegion.SOUTH_BLUE
			region_name = "South Blue"

	var v_layer: VerticalLayer = classify_vertical_layer(coords["alt_m"])
	return {
		"region_enum": region_enum,
		"region_name": region_name,
		"vertical_layer": v_layer,
		"vertical_layer_name": get_vertical_layer_name(v_layer),
		"lat_deg": coords["lat_deg"],
		"lon_deg": coords["lon_deg"],
		"lon_360_deg": coords["lon_360_deg"],
		"alt_m": coords["alt_m"],
		"compass_functional": compass_functional,
		"wind_multiplier": wind_multiplier,
		"is_calm_belt": (
			region_enum == OceanRegion.CALM_BELT_NORTH
			or region_enum == OceanRegion.CALM_BELT_SOUTH
		)
	}

## Classifies altitude relative to sea level (-10,000m Abyss up to +10,000m White-White Sea).
static func classify_vertical_layer(alt_m: float) -> VerticalLayer:
	if alt_m <= -5_000.0:
		return VerticalLayer.ABYSSAL_TRENCH
	elif alt_m < -200.0:
		return VerticalLayer.BATHYPELAGIC_ZONE
	elif alt_m < 6_500.0:
		return VerticalLayer.BLUE_SEA_SURFACE
	elif alt_m < 9_200.0:
		return VerticalLayer.WHITE_SEA
	else:
		return VerticalLayer.WHITE_WHITE_SEA

static func get_vertical_layer_name(layer: VerticalLayer) -> String:
	match layer:
		VerticalLayer.ABYSSAL_TRENCH:
			return "Abyssal Trench (-10,000m Fish-Man Island / Sea Forest)"
		VerticalLayer.BATHYPELAGIC_ZONE:
			return "Bathypelagic Zone (-5,000m to -200m Sea King Nests / Impel Down)"
		VerticalLayer.BLUE_SEA_SURFACE:
			return "Blue Sea Surface (0m Standard Maritime Layer)"
		VerticalLayer.WHITE_SEA:
			return "The White Sea (+7,000m Cloud Ocean)"
		VerticalLayer.WHITE_WHITE_SEA:
			return "The White-White Sea (+10,000m Skypiea / Upper Yard / Red Line Crest)"
	return "Unknown Layer"

# ==============================================================================
# 8. CALM BELT SEA KING SPAWNER & SKY/ABYSS FLUID PHYSICS
# ==============================================================================
## Evaluates Calm Belt hazards for a vessel at `ship_world_pos`.
## Returns wind velocity (0.0 m/s in Calm Belts) and spawns colossal 500m-2,000m Sea Kings
## from -2,000m depth if `has_seastone_keel` is false.
func evaluate_calm_belt_hazard(
	ship_world_pos: Vector3,
	has_seastone_keel: bool,
	has_paddlewheel_drive: bool
) -> Dictionary:
	var zone_info: Dictionary = classify_global_coordinates(ship_world_pos)
	if not zone_info["is_calm_belt"]:
		return {
			"in_calm_belt": false,
			"wind_speed_ms": 14.0,
			"can_propel": true,
			"sea_king_spawned": false
		}

	var spawned: bool = false
	var sea_king_length_m: float = 0.0
	if not has_seastone_keel and _sea_king_spawn_cooldown_sec <= 0.0:
		spawned = true
		sea_king_length_m = randf_range(500.0, 2_000.0)
		_sea_king_spawn_cooldown_sec = 18.0
		var spawn_pos: Vector3 = ship_world_pos.normalized() * (SEA_LEVEL_RADIUS + LAYER_DEEP_SEA_KING_NEST_M)
		calm_belt_sea_king_triggered.emit(spawn_pos, LAYER_DEEP_SEA_KING_NEST_M, sea_king_length_m)

	return {
		"in_calm_belt": true,
		"wind_speed_ms": 0.0,
		"can_propel": has_paddlewheel_drive,
		"sea_king_spawned": spawned,
		"sea_king_length_m": sea_king_length_m
	}

## Returns effective fluid surface altitude (0.0m for Blue Sea, +7,000m for White Sea,
## +10,000m for White-White Sea) and fluid buoyancy density multiplier.
func sample_buoyant_fluid_layer(world_pos: Vector3, has_yarukiman_resin_coating: bool = false) -> Dictionary:
	var coords: Dictionary = world_to_lat_lon_alt(world_pos)
	var alt_m: float = coords["alt_m"]

	if alt_m >= 9_200.0:
		return {
			"layer_name": "White-White Sea (Pyrobroin Island/Sea Cloud)",
			"surface_alt_m": LAYER_WHITE_WHITE_SEA_M,
			"fluid_density_ratio": 0.78, # Less dense than Blue Sea water
			"submerged_depth_m": maxf(0.0, LAYER_WHITE_WHITE_SEA_M - alt_m),
			"crush_hazard": false
		}
	elif alt_m >= 6_500.0:
		return {
			"layer_name": "White Sea (Pyrobroin Sea Cloud)",
			"surface_alt_m": LAYER_WHITE_SEA_M,
			"fluid_density_ratio": 0.85,
			"submerged_depth_m": maxf(0.0, LAYER_WHITE_SEA_M - alt_m),
			"crush_hazard": false
		}
	elif alt_m < -150.0:
		var crush_danger: bool = (alt_m < -300.0) and (not has_yarukiman_resin_coating)
		return {
			"layer_name": "Deep Blue Sea / Abyssal Trench",
			"surface_alt_m": LAYER_BLUE_SEA_SURFACE_M,
			"fluid_density_ratio": 1.025,
			"submerged_depth_m": -alt_m,
			"crush_hazard": crush_danger
		}
	else:
		return {
			"layer_name": "Blue Sea Surface",
			"surface_alt_m": LAYER_BLUE_SEA_SURFACE_M,
			"fluid_density_ratio": 1.0,
			"submerged_depth_m": maxf(0.0, -alt_m),
			"crush_hazard": false
		}

# ==============================================================================
# 9. CAMERA-RELATIVE FLOATING ORIGIN SHADER UNIFORM HELPER
# ==============================================================================
## Because GPUs execute vertex shaders in 32-bit float (`single`), passing raw 16,000,000.0m
## coordinates directly to a GPU shader causes ~1.0-2.0m vertex jitter.
## This helper subtracts the 64-bit `camera_origin_double` from the 64-bit `chunk_origin_double`
## on the CPU first, producing a small near-zero 32-bit-safe offset vector for GPU shaders.
static func compute_camera_relative_offset(chunk_origin_double: Vector3, camera_origin_double: Vector3) -> Vector3:
	return chunk_origin_double - camera_origin_double

## Applies camera-relative 32-bit-safe uniforms (`u_chunk_camera_offset`, `u_planet_up`,
## `u_planet_radius`) to a terrain or ocean `ShaderMaterial`.
static func apply_camera_relative_shader_uniforms(
	material: ShaderMaterial,
	chunk_origin_double: Vector3,
	camera_origin_double: Vector3
) -> void:
	if material == null:
		return
	var relative_offset: Vector3 = chunk_origin_double - camera_origin_double
	var local_up: Vector3 = camera_origin_double.normalized()
	material.set_shader_parameter("u_chunk_camera_offset", relative_offset)
	material.set_shader_parameter("u_camera_planet_up", local_up)
	material.set_shader_parameter("u_planet_radius", SEA_LEVEL_RADIUS)
