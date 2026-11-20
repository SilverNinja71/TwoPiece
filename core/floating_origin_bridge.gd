class_name FloatingOriginBridge
extends Node
## 64-Bit Floating-Origin Rendering Bridge (`FloatingOrigin` Autoload) for Project "Blue Planet"
##
## In standard prebuilt Godot 4.3 (`Godot.app`), `Node3D.position` / `Vector3` uses 32-bit float,
## whereas GDScript `float` and `PackedFloat64Array` are ALWAYS 64-bit IEEE 754 double precision.
##
## This bridge stores the true 64-bit ECEF planetary origin (`origin_lat_deg`, `origin_lon_deg`,
## `origin_alt_m`, `origin_world64`), computes exact 64-bit `delta = world64 - origin64` on the CPU,
## and projects it into jitter-free 32-bit local `Vector3` near `(0, 0, 0)` aligned to ECEF axes
## so every regional builder (`IslandMeshStreamer`, `EastBlueSettlementBuilder`, `ReverseMountainMeshBuilder`,
## `SkyAtmosphereRenderer`, `PlanetMeshRenderer`, `SphericalPlayer`, `BuoyantShipVessel`) shares one
## unified spherical coordinate frame.

signal origin_rebased(delta_local: Vector3)

const PLANET_RADIUS_M: float = 16_000_000.0
const DEFAULT_START_LAT_DEG: float = 52.0  # Dawn Island (Foosha Village, East BlueData)
const DEFAULT_START_LON_DEG: float = 74.0
const DEFAULT_START_ALT_M: float = 0.0
const AUTO_REBASE_THRESHOLD_M: float = 1_000.0

## True 64-bit planetary origin coordinates
var origin_lat_deg: float = DEFAULT_START_LAT_DEG
var origin_lon_deg: float = DEFAULT_START_LON_DEG
var origin_alt_m: float = DEFAULT_START_ALT_M
var origin_world64: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0])
var origin_offset: Vector3 = Vector3.ZERO

var _local_up_vec: Vector3 = Vector3.UP

func _ready() -> void:
	set_origin_lat_lon_alt(origin_lat_deg, origin_lon_deg, origin_alt_m)

# ==============================================================================
# 1. 64-BIT SPHERICAL GEODESY HELPERS (IEEE 754 DOUBLE PRECISION)
# ==============================================================================
static func lat_lon_alt_to_world64(lat_deg: float, lon_deg: float, alt_m: float = 0.0) -> PackedFloat64Array:
	var lat_rad: float = deg_to_rad(clampf(lat_deg, -90.0, 90.0))
	var lon_rad: float = deg_to_rad(lon_deg)
	var r: float = PLANET_RADIUS_M + alt_m
	var cos_lat: float = cos(lat_rad)
	var x: float = r * cos_lat * cos(lon_rad)
	var y: float = r * sin(lat_rad)
	var z: float = r * cos_lat * sin(lon_rad)
	return PackedFloat64Array([x, y, z])

static func world64_to_lat_lon_alt(w64: PackedFloat64Array) -> Dictionary:
	if w64.size() < 3:
		return {"lat_deg": 0.0, "lon_deg": 0.0, "alt_m": 0.0, "radius_m": PLANET_RADIUS_M}
	var x: float = w64[0]
	var y: float = w64[1]
	var z: float = w64[2]
	var r: float = sqrt(x * x + y * y + z * z)
	if r < 0.0001:
		return {"lat_deg": 0.0, "lon_deg": 0.0, "alt_m": -PLANET_RADIUS_M, "radius_m": 0.0}
	var lat_rad: float = asin(clampf(y / r, -1.0, 1.0))
	var lon_rad: float = atan2(z, x)
	return {
		"lat_deg": rad_to_deg(lat_rad),
		"lon_deg": rad_to_deg(lon_rad),
		"alt_m": r - PLANET_RADIUS_M,
		"radius_m": r
	}

static func great_circle_distance64_m(lat1_deg: float, lon1_deg: float, lat2_deg: float, lon2_deg: float) -> float:
	var p1: PackedFloat64Array = lat_lon_alt_to_world64(lat1_deg, lon1_deg, 0.0)
	var p2: PackedFloat64Array = lat_lon_alt_to_world64(lat2_deg, lon2_deg, 0.0)
	var inv_r: float = 1.0 / PLANET_RADIUS_M
	var dot_val: float = clampf(
		(p1[0] * p2[0] + p1[1] * p2[1] + p1[2] * p2[2]) * inv_r * inv_r,
		-1.0,
		1.0
	)
	return PLANET_RADIUS_M * acos(dot_val)

# ==============================================================================
# 2. 64-BIT ECEF <-> JITTER-FREE 32-BIT LOCAL CONVERSIONS
# ==============================================================================
func _refresh_local_up() -> void:
	var lat_rad: float = deg_to_rad(clampf(origin_lat_deg, -90.0, 90.0))
	var lon_rad: float = deg_to_rad(origin_lon_deg)
	var cos_lat: float = cos(lat_rad)
	_local_up_vec = Vector3(
		cos_lat * cos(lon_rad),
		sin(lat_rad),
		cos_lat * sin(lon_rad)
	).normalized()
	origin_offset = Vector3(origin_world64[0], origin_world64[1], origin_world64[2])

func set_origin_lat_lon_alt(lat_deg: float, lon_deg: float, alt_m: float = 0.0) -> void:
	origin_lat_deg = clampf(lat_deg, -90.0, 90.0)
	origin_lon_deg = wrapf(lon_deg, -180.0, 180.0)
	origin_alt_m = alt_m
	origin_world64 = lat_lon_alt_to_world64(origin_lat_deg, origin_lon_deg, origin_alt_m)
	_refresh_local_up()

## Converts a 64-bit ECEF coordinate `w64` into jitter-free local 32-bit `Vector3` near `(0, 0, 0)`.
func world64_to_local32(w64: PackedFloat64Array) -> Vector3:
	if w64.size() < 3 or origin_world64.size() < 3:
		return Vector3.ZERO
	return Vector3(
		w64[0] - origin_world64[0],
		w64[1] - origin_world64[1],
		w64[2] - origin_world64[2]
	)

func lat_lon_alt_to_local32(lat_deg: float, lon_deg: float, alt_m: float = 0.0) -> Vector3:
	return world64_to_local32(lat_lon_alt_to_world64(lat_deg, lon_deg, alt_m))

## Converts a local 32-bit `Vector3` back into 64-bit ECEF `PackedFloat64Array`.
func local32_to_world64(local_pos: Vector3) -> PackedFloat64Array:
	return PackedFloat64Array([
		origin_world64[0] + float(local_pos.x),
		origin_world64[1] + float(local_pos.y),
		origin_world64[2] + float(local_pos.z)
	])

func local32_to_lat_lon_alt(local_pos: Vector3) -> Dictionary:
	return world64_to_lat_lon_alt(local32_to_world64(local_pos))

func local32_to_world_vec3(local_pos: Vector3) -> Vector3:
	var w64: PackedFloat64Array = local32_to_world64(local_pos)
	return Vector3(w64[0], w64[1], w64[2])

## Returns the planet's outward radial Up vector at `(origin_lat_deg, origin_lon_deg)`.
func get_local_up_at_origin() -> Vector3:
	return _local_up_vec

func get_origin_offset() -> Vector3:
	return origin_offset

# ==============================================================================
# 3. FLOATING-ORIGIN REBASING (THRESHOLD = 1,000.0 METERS)
# ==============================================================================
## Shifts the floating origin to `new_origin64` and emits `origin_rebased(delta_local)`.
func rebase_origin_to_world64(new_origin64: PackedFloat64Array) -> Vector3:
	if new_origin64.size() < 3:
		return Vector3.ZERO
	var delta_local: Vector3 = Vector3(
		origin_world64[0] - new_origin64[0],
		origin_world64[1] - new_origin64[1],
		origin_world64[2] - new_origin64[2]
	)
	var new_coords: Dictionary = world64_to_lat_lon_alt(new_origin64)
	origin_lat_deg = float(new_coords["lat_deg"])
	origin_lon_deg = float(new_coords["lon_deg"])
	origin_alt_m = float(new_coords["alt_m"])
	origin_world64 = new_origin64.duplicate()
	_refresh_local_up()

	origin_rebased.emit(delta_local)
	return delta_local

## Automatically rebases horizontally along sea level (`alt_m = 0.0`) whenever the tracked
## local position drifts further than `threshold_m` (default `1,000.0` m) from `(0, 0, 0)`.
func rebase_if_needed(tracked_local_pos: Vector3, threshold_m: float = AUTO_REBASE_THRESHOLD_M) -> Dictionary:
	var radial_comp: float = tracked_local_pos.dot(_local_up_vec)
	var horiz_vec: Vector3 = tracked_local_pos - _local_up_vec * radial_comp
	if horiz_vec.length() <= threshold_m:
		return {"rebased": false}

	var tracked_coords: Dictionary = local32_to_lat_lon_alt(tracked_local_pos)
	var new_sea_origin64: PackedFloat64Array = lat_lon_alt_to_world64(
		float(tracked_coords["lat_deg"]),
		float(tracked_coords["lon_deg"]),
		0.0
	)
	var delta_local: Vector3 = rebase_origin_to_world64(new_sea_origin64)
	return {
		"rebased": true,
		"delta_local": delta_local,
		"new_lat_deg": origin_lat_deg,
		"new_lon_deg": origin_lon_deg
	}
