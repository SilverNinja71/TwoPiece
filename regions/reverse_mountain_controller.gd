class_name ReverseMountainController
extends Node3D
## Reverse Mountain & Twin Cape Region Controller for Project "Blue Planet" (Godot 4.3+ precision=double).
##
## Manages Antipodal Great Circle Intersection Node A at (lat = 0.0 deg, lon = 0.0 deg) on a sphere of
## radius R = 16,000,000.0 meters:
##   - 4 ascending hydraulic mountain canals (~400 m wide) entering from North, East, West, and South Blue
##     from sea level (0 m) up to the +5,000 m Summit Basin.
##   - 1 steep descending 5th canal plunging eastward into Twin Cape (Grand Line Paradise entry).
##   - Uphill/downhill hydraulic current physics, rudder/sail trim assist, and Red Line canal wall impact damage.
##   - Laboon (400 m Island Whale) dynamic obstacle, headbutt shockwaves, and Crocus-modified interior cavern.
##   - Twin Cape Lighthouse docking zone, Crocus Clinic, Initial Log Pose tutorial/gift, 7-route calibration,
##     and the Rumbar Pirates / Brook Tone Dial ("Binks' Sake") quest hook.

signal canal_entered(ship: Node3D, canal_id: StringName)
signal summit_basin_reached(ship: Node3D, from_canal: StringName)
signal canal_wall_impact(ship: Node3D, canal_id: StringName, impact_speed_mps: float, hull_damage: float, rudder_damage: float)
signal twin_cape_exited(ship: Node3D)
signal laboon_swallowed_ship(ship: Node3D)
signal laboon_headbutt_shockwave(epicenter: Vector3, intensity: float)
signal laboon_promise_fulfilled()
signal lighthouse_docked(ship: Node3D)
signal log_pose_gifted(recipient: Node, item_data: Dictionary)
signal rumbar_tone_dial_played(unlock_data: Dictionary)

# ---------------------------------------------------------------------------
# Planetary & Reverse Mountain Constants (64-bit IEEE-754 double precision)
# ---------------------------------------------------------------------------
const PLANET_RADIUS_M: float = 16_000_000.0
const METERS_PER_DEGREE: float = (TAU * PLANET_RADIUS_M) / 360.0 # ~279,252.6803 m/deg
const GRAVITY_MPS2: float = 9.81

const NODE_A_LAT_DEG: float = 0.0
const NODE_A_LON_DEG: float = 0.0

const RED_LINE_WIDTH_M: float = 250_000.0
const RED_LINE_HALF_WIDTH_M: float = 125_000.0
const RED_LINE_ELEVATION_M: float = 10_000.0
const RED_LINE_TILT_DEG: float = 45.0

const GRAND_LINE_WIDTH_M: float = 600_000.0
const GRAND_LINE_TILT_DEG: float = -45.0
const CALM_BELT_WIDTH_M: float = 150_000.0

const CANAL_WIDTH_M: float = 400.0
const CANAL_HALF_WIDTH_M: float = 200.0
const CANAL_WALL_HEIGHT_M: float = 350.0
const SUMMIT_ELEVATION_M: float = 5_000.0
const SUMMIT_BASIN_RADIUS_M: float = 1_400.0

const LABOON_LENGTH_M: float = 400.0
const LABOON_BEAM_M: float = 110.0
const LABOON_HEIGHT_M: float = 120.0
const LABOON_SWALLOW_MOUTH_RADIUS_M: float = 52.0

const TWIN_CAPE_DOCK_RADIUS_M: float = 140.0
const LIGHTHOUSE_BEACON_RANGE_M: float = 18_000.0

const CANAL_NORTH_BLUE: StringName = &"north_blue_canal"
const CANAL_EAST_BLUE: StringName = &"east_blue_canal"
const CANAL_WEST_BLUE: StringName = &"west_blue_canal"
const CANAL_SOUTH_BLUE: StringName = &"south_blue_canal"
const CANAL_PARADISE_EXIT: StringName = &"paradise_exit_canal"

enum LaboonState {
	HEADBUTTING_RED_LINE,
	PATROLLING_BAY,
	MOUTH_OPEN_SWALLOW,
	CALMED_JOLLY_ROGER_PROMISE,
	REUNITED_BINKS_SAKE,
}

# ---------------------------------------------------------------------------
# Tunable Designer Parameters
# ---------------------------------------------------------------------------
@export_group("Hydraulic Physics")
@export var ascend_target_speed_mps: float = 65.0
@export var descend_target_speed_mps: float = 95.0
@export var hydraulic_gain: float = 1.65
@export var winter_storm_turbulence_mps2: float = 2.4
@export var steering_assist_strength: float = 0.55
@export var wall_restitution: float = 0.35
@export var rudder_break_threshold_mps: float = 18.0

@export_group("Laboon & Twin Cape")
@export var headbutt_cycle_seconds: float = 42.0
@export var stomach_acid_dps: float = 1.8
@export var allow_swallow_event: bool = true

# ---------------------------------------------------------------------------
# Runtime State
# ---------------------------------------------------------------------------
var _canal_defs: Dictionary = {}
var _canal_samples: Dictionary = {}
var _node_a_normal: Vector3 = Vector3(1.0, 0.0, 0.0)
var _local_east: Vector3 = Vector3(0.0, 0.0, 1.0)
var _local_north: Vector3 = Vector3(0.0, 1.0, 0.0)

var laboon_state: LaboonState = LaboonState.HEADBUTTING_RED_LINE
var laboon_world_pos: Vector3 = Vector3.ZERO
var laboon_forward: Vector3 = Vector3.ZERO
var laboon_scar_jolly_roger_painted: bool = false
var rumbar_tone_dial_delivered: bool = false
var player_log_pose_gifted: bool = false
var selected_paradise_route: int = 1

var _headbutt_timer: float = 0.0
var _ship_canal_tracking: Dictionary = {} # instance_id -> StringName
var _ships_inside_laboon: Dictionary = {} # instance_id -> bool

# ---------------------------------------------------------------------------
# Canonical Settlement, NPC, Shop & Route Data Dictionaries
# ---------------------------------------------------------------------------
const TWIN_CAPE_SETTLEMENT: Dictionary = {
	"id": "twin_cape",
	"name": "Twin Cape (Futago Misaki)",
	"region": "Grand Line Entrance (Paradise Mile 0)",
	"island_classification": "Entrance Promontory / Adjacent to Winter Island (Reverse Mountain)",
	"lat_deg": 0.0,
	"lon_deg": 0.545,
	"alt_m": 0.0,
	"dock_lat_deg": -0.008,
	"dock_lon_deg": 0.562,
	"lighthouse_lat_deg": -0.012,
	"lighthouse_lon_deg": 0.558,
	"lighthouse_alt_m": 48.0,
	"climate": "Turbulent Winter-Transition Squalls & Strong Outflow Surge",
	"biome": "Twin Red-Stone Capes, Beacon Cliff, Sheltered Bay",
	"currencies": ["Beli"],
	"establishments": [
		{
			"id": "twin_cape_lighthouse_clinic",
			"name": "Crocus's Lighthouse & Clinic",
			"type": "Lighthouse / Medical Clinic / Navigation Hub",
			"services": [
				"Initial Log Pose Gifting & Tutorial",
				"7-Route Magnetic Calibration",
				"Crew Medical Treatment & Antidotes",
				"Hull Acid-Sealant & Harpoon Supply",
			],
		},
		{
			"id": "laboon_stomach_complex",
			"name": "Inside Laboon — Crocus's Engineered Cavern",
			"type": "Interior Whale Cavern / Salvage Zone",
			"zones": [
				"Digestive Acid Sea",
				"Artificial Island & Painted Sky Horizon",
				"Crocus's Observation Cabin & Lawn Chair",
				"Riveted Steel Observation & Exit Doors",
			],
		},
	],
	"npcs": {
		"crocus": {
			"name": "Crocus",
			"epithet": "Keeper of the Twin Cape Lighthouse",
			"affiliation": "Former Roger Pirates (Ship's Doctor)",
			"age_pre_timeskip": 71,
			"age_post_timeskip": 73,
			"height_cm": 203,
			"birthday": "June 4",
			"weapons": ["Harpoons", "Sedative Launchers"],
			"role": "Quest Giver / Physician / Log Pose Master / Merchant",
			"dialogue_hooks": [
				"Explains why standard Blue Sea compasses spin uselessly on the Grand Line.",
				"Gifts initial Log Pose and warns of the 7 diverging Paradise routes.",
				"Shares 50-year vigil story of Laboon and the Rumbar Pirates.",
			],
		},
		"laboon": {
			"name": "Laboon",
			"species": "Island Whale (Native to West Blue)",
			"length_m": 400.0,
			"role": "Dynamic Bay Guardian / Interior Dungeon / Rumbar Quest Target",
			"quest_hooks": [
				"Promise Duel & Straw Hat Jolly Roger Scar Painting",
				"Rumbar Pirates Tone Dial ('Binks' Sake') Reunion",
			],
		},
		"mr_9_and_miss_wednesday": {
			"names": ["Mr. 9", "Miss Wednesday (Nefertari Vivi)"],
			"affiliation": "Baroque Works (Frontier Agents — Whisky Peak)",
			"role": "Encounter / Stowaway Hook inside Laboon",
			"reward_hook": "Leads toward Whisky Peak (Route 1) & Alabasta Saga.",
		},
	},
	"marketplace_inventory": [
		{
			"id": "standard_log_pose",
			"name": "Grand Line Log Pose",
			"price_beli": 0,
			"unlock_condition": "Crocus Tutorial Gift (or 150,000 Beli replacement)",
			"description": "Spherical wrist compass that locks onto an island's magnetic field.",
		},
		{
			"id": "acid_resistant_hull_paint",
			"name": "Whale-Stomach Acid-Resistant Coating",
			"price_beli": 12000,
			"description": "Resists Laboon's gastric acid sea and corrosive sea mist.",
		},
		{
			"id": "crocus_sedative_kit",
			"name": "Crocus's Maritime Trauma Kit",
			"price_beli": 4500,
			"description": "High-grade Roger Pirates medical supplies restoring 100% crew HP & curing shock.",
		},
		{
			"id": "twin_cape_harpoon_bundle",
			"name": "Heavy Lighthouse Harpoons (x10)",
			"price_beli": 3200,
			"description": "Reinforced iron harpoons for fending off Giant Squid and Sea Beasts.",
		},
		{
			"id": "giant_squid_fillet",
			"name": "Fresh Giant Squid Meat",
			"price_beli": 900,
			"description": "High-protein galley ration harvested outside Twin Cape.",
		},
		{
			"id": "spare_caravel_rudder",
			"name": "Reinforced Oak Emergency Rudder",
			"price_beli": 8500,
			"description": "Replaces rudders snapped during the Reverse Mountain canal ascent.",
		},
	],
	"seven_paradise_routes": [
		{"route_id": 1, "first_island": "Whisky Peak (Cactus Island)", "lock_time_minutes": 10, "danger_tier": 1, "canon_straw_hat_route": true},
		{"route_id": 2, "first_island": "Nanimonai Island", "lock_time_minutes": 25, "danger_tier": 2, "canon_straw_hat_route": false},
		{"route_id": 3, "first_island": "Kyuka Island (Holiday Isle)", "lock_time_minutes": 15, "danger_tier": 1, "canon_straw_hat_route": false},
		{"route_id": 4, "first_island": "Merveille Frontier Reef", "lock_time_minutes": 40, "danger_tier": 3, "canon_straw_hat_route": false},
		{"route_id": 5, "first_island": "Kuraigana Approach Current", "lock_time_minutes": 35, "danger_tier": 3, "canon_straw_hat_route": false},
		{"route_id": 6, "first_island": "Bananawani Outer Atoll", "lock_time_minutes": 30, "danger_tier": 2, "canon_straw_hat_route": false},
		{"route_id": 7, "first_island": "Karakuri / Winter Vanguard Isle", "lock_time_minutes": 45, "danger_tier": 4, "canon_straw_hat_route": false},
	],
}

const LABOON_INTERIOR_ZONES: Dictionary = {
	"stomach_acid_sea": {
		"name": "Gastric Acid Basin",
		"local_center": Vector3(0.0, -28.0, 0.0),
		"radius_m": 165.0,
		"hazard": "Corrosive digestive surge; damages unpainted wooden hulls over time.",
	},
	"artificial_island": {
		"name": "Crocus's Floating Steel Platform & Cabin",
		"local_center": Vector3(0.0, -24.0, 20.0),
		"radius_m": 42.0,
		"features": ["Painted Blue Sky Dome", "Painted Ocean Horizon", "Crocus's Cabin", "Lawn Chair & Tea Table"],
	},
	"steel_exit_doors": {
		"name": "Riveted Iron Maintenance Hatches",
		"local_center": Vector3(0.0, -18.0, 145.0),
		"radius_m": 22.0,
		"features": ["Manual Lever Gate", "Direct Sea Exit Passage to Twin Cape Bay"],
	},
	"giant_squid_lair": {
		"name": "Swallowed Giant Squid Drift",
		"local_center": Vector3(-35.0, -26.0, -40.0),
		"radius_m": 30.0,
		"loot": ["giant_squid_fillet", "salvaged_east_blue_crates"],
	},
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_init_node_a_basis()
	_build_all_canal_splines()
	_reset_laboon_to_bay()


func _physics_process(delta: float) -> void:
	_update_laboon_cycle(delta)


# ---------------------------------------------------------------------------
# Coordinate Conversions (64-bit Sphere <-> Geographic Lat/Lon/Alt)
# ---------------------------------------------------------------------------
func _init_node_a_basis() -> void:
	_node_a_normal = lat_lon_to_unit_dir(NODE_A_LAT_DEG, NODE_A_LON_DEG)
	var world_north: Vector3 = Vector3(0.0, 1.0, 0.0)
	_local_east = world_north.cross(_node_a_normal).normalized()
	if _local_east.length_squared() < 0.5:
		_local_east = Vector3(0.0, 0.0, 1.0)
	_local_north = _node_a_normal.cross(_local_east).normalized()


## Converts geographic (lat_deg, lon_deg, alt_m) to 64-bit world Vector3 on the R=16,000,000m sphere.
## Convention: lat=0, lon=0 -> +X; lon=+90 -> +Z (East); lat=+90 -> +Y (North Pole).
static func lat_lon_to_unit_dir(lat_deg: float, lon_deg: float) -> Vector3:
	var lat_rad: float = deg_to_rad(lat_deg)
	var lon_rad: float = deg_to_rad(lon_deg)
	var cos_lat: float = cos(lat_rad)
	return Vector3(
		cos_lat * cos(lon_rad),
		sin(lat_rad),
		cos_lat * sin(lon_rad)
	).normalized()


static func spherical_to_world(lat_deg: float, lon_deg: float, alt_m: float = 0.0) -> Vector3:
	return lat_lon_to_unit_dir(lat_deg, lon_deg) * (PLANET_RADIUS_M + alt_m)


static func world_to_spherical(world_pos: Vector3) -> Dictionary:
	var r: float = world_pos.length()
	if r <= 0.0001:
		return {"lat_deg": 0.0, "lon_deg": 0.0, "alt_m": -PLANET_RADIUS_M}
	var dir: Vector3 = world_pos / r
	var lat_deg: float = rad_to_deg(asin(clamp(dir.y, -1.0, 1.0)))
	var lon_deg: float = rad_to_deg(atan2(dir.z, dir.x))
	return {
		"lat_deg": lat_deg,
		"lon_deg": lon_deg,
		"alt_m": r - PLANET_RADIUS_M,
	}


## Maps local tangent offsets (east_m, north_m) from Node A onto the curved sphere at altitude alt_m.
func local_tangent_to_world(east_m: float, north_m: float, alt_m: float = 0.0) -> Vector3:
	var offset_m: Vector3 = _local_east * east_m + _local_north * north_m
	var arc_len: float = offset_m.length()
	if arc_len < 1e-6:
		return _node_a_normal * (PLANET_RADIUS_M + alt_m)
	var angle_rad: float = arc_len / PLANET_RADIUS_M
	var tangent_dir: Vector3 = offset_m / arc_len
	var unit_dir: Vector3 = (_node_a_normal * cos(angle_rad) + tangent_dir * sin(angle_rad)).normalized()
	return unit_dir * (PLANET_RADIUS_M + alt_m)


# ---------------------------------------------------------------------------
# 5-Canal Spherical Spline Architecture (4 Ascending + 1 Descending)
# ---------------------------------------------------------------------------
func _build_all_canal_splines() -> void:
	# Entry gates lie ~150-165 km from Node A outside the 250 km Red Line cliffs so ships from
	# all 4 Blues enter cleanly via stone guide-light gates without colliding into the Red Line.
	_canal_defs = {
		CANAL_NORTH_BLUE: {
			"label": "North Blue Ascending Canal",
			"direction_sign": 1.0, # t=0 sea entry -> t=1 summit
			"entry_lat_deg": 0.430,
			"entry_lon_deg": -0.395,
			"control_pts_local": [
				Vector3(-110_300.0, 120_100.0, 0.0),      # P0: North Blue Sea Gate (0m, ~163km NW)
				Vector3(-72_000.0, 78_000.0, 1_100.0),    # P1: Outer Stone Canyon Gorge
				Vector3(-26_000.0, 28_000.0, 3_950.0),    # P2: Steep Winter Rapids
				Vector3(-850.0, 850.0, SUMMIT_ELEVATION_M), # P3: Summit Basin NW Lip (+5,000m)
			],
		},
		CANAL_EAST_BLUE: {
			"label": "East Blue Ascending Canal",
			"direction_sign": 1.0,
			"entry_lat_deg": 0.485,
			"entry_lon_deg": 0.340,
			"control_pts_local": [
				Vector3(95_000.0, 135_400.0, 0.0),        # P0: East Blue Guide-Light Gate (0m, ~165km NE)
				Vector3(58_000.0, 92_000.0, 1_250.0),     # P1: Outer Stone Canyon Gorge
				Vector3(18_000.0, 34_000.0, 4_050.0),     # P2: Steep Winter Rapids (clear of East exit)
				Vector3(350.0, 1_050.0, SUMMIT_ELEVATION_M), # P3: Summit Basin NE Lip (+5,000m)
			],
		},
		CANAL_WEST_BLUE: {
			"label": "West Blue Ascending Canal",
			"direction_sign": 1.0,
			"entry_lat_deg": -0.430,
			"entry_lon_deg": -0.395,
			"control_pts_local": [
				Vector3(-110_300.0, -120_100.0, 0.0),     # P0: West Blue Sea Gate (0m, ~163km SW)
				Vector3(-72_000.0, -78_000.0, 1_100.0),
				Vector3(-26_000.0, -28_000.0, 3_950.0),
				Vector3(-850.0, -850.0, SUMMIT_ELEVATION_M),
			],
		},
		CANAL_SOUTH_BLUE: {
			"label": "South Blue Ascending Canal",
			"direction_sign": 1.0,
			"entry_lat_deg": -0.485,
			"entry_lon_deg": 0.340,
			"control_pts_local": [
				Vector3(95_000.0, -135_400.0, 0.0),       # P0: South Blue Sea Gate (0m, ~165km SE)
				Vector3(58_000.0, -92_000.0, 1_250.0),
				Vector3(18_000.0, -34_000.0, 4_050.0),
				Vector3(350.0, -1_050.0, SUMMIT_ELEVATION_M),
			],
		},
		CANAL_PARADISE_EXIT: {
			"label": "Paradise Descending Canal (5th Canal -> Twin Cape)",
			"direction_sign": -1.0, # t=0 summit (+5,000m) -> t=1 Twin Cape sea level (0m)
			"entry_lat_deg": 0.0,
			"entry_lon_deg": 0.0,
			"control_pts_local": [
				Vector3(1_050.0, 0.0, SUMMIT_ELEVATION_M), # P0: Summit East Spillway (+5,000m)
				Vector3(52_000.0, 0.0, 4_200.0),           # P1: Upper High-Velocity Chute
				Vector3(118_000.0, 0.0, 2_100.0),          # P2: Steep Waterfall Plunge
				Vector3(148_000.0, 0.0, 0.0),              # P3: Twin Cape Mouth (0m, ~0.53 deg Lon)
			],
		},
	}

	# Pre-sample lookup tables (65 points per canal) for fast closest-point projection
	_canal_samples.clear()
	for canal_id: StringName in _canal_defs.keys():
		var samples: Array[Dictionary] = []
		var steps: int = 64
		for i: int in range(steps + 1):
			var t: float = float(i) / float(steps)
			samples.append(sample_canal(canal_id, t))
		_canal_samples[canal_id] = samples


## Evaluates cubic Bezier point & tangent in local (east_m, north_m, alt_m) and projects onto the 64-bit sphere.
func sample_canal(canal_id: StringName, t_raw: float) -> Dictionary:
	var t: float = clamp(t_raw, 0.0, 1.0)
	var pts: Array = _canal_defs[canal_id]["control_pts_local"]
	var p0: Vector3 = pts[0]
	var p1: Vector3 = pts[1]
	var p2: Vector3 = pts[2]
	var p3: Vector3 = pts[3]

	var u: float = 1.0 - t
	var local_pos: Vector3 = (
		p0 * (u * u * u)
		+ p1 * (3.0 * u * u * t)
		+ p2 * (3.0 * u * t * t)
		+ p3 * (t * t * t)
	)
	var local_deriv: Vector3 = (
		(p1 - p0) * (3.0 * u * u)
		+ (p2 - p1) * (6.0 * u * t)
		+ (p3 - p2) * (3.0 * t * t)
	)

	var world_pos: Vector3 = local_tangent_to_world(local_pos.x, local_pos.y, local_pos.z)
	var up_dir: Vector3 = world_pos.normalized()

	# Finite-difference tangent on the curved sphere for exact 3D hydraulic alignment
	var dt: float = 0.002
	var t_next: float = min(1.0, t + dt)
	var t_prev: float = max(0.0, t - dt)
	var u_n: float = 1.0 - t_next
	var lp_n: Vector3 = p0 * (u_n * u_n * u_n) + p1 * (3.0 * u_n * u_n * t_next) + p2 * (3.0 * u_n * t_next * t_next) + p3 * (t_next * t_next * t_next)
	var u_p: float = 1.0 - t_prev
	var lp_p: Vector3 = p0 * (u_p * u_p * u_p) + p1 * (3.0 * u_p * u_p * t_prev) + p2 * (3.0 * u_p * t_prev * t_prev) + p3 * (t_prev * t_prev * t_prev)
	var wp_n: Vector3 = local_tangent_to_world(lp_n.x, lp_n.y, lp_n.z)
	var wp_p: Vector3 = local_tangent_to_world(lp_p.x, lp_p.y, lp_p.z)

	var flow_tangent: Vector3 = (wp_n - wp_p).normalized()
	var right_dir: Vector3 = flow_tangent.cross(up_dir).normalized()
	var slope_rad: float = asin(clamp(flow_tangent.dot(up_dir), -1.0, 1.0))

	# Width widens slightly at sea entry gates (560 m) for safe Red Line approach, narrowing to 400 m in gorge
	var gate_flare: float = 160.0 * pow(1.0 - t, 3.0) if canal_id != CANAL_PARADISE_EXIT else 120.0 * pow(t, 3.0)
	var width_m: float = CANAL_WIDTH_M + gate_flare

	return {
		"canal_id": canal_id,
		"t": t,
		"world_pos": world_pos,
		"flow_tangent": flow_tangent,
		"up_dir": up_dir,
		"right_dir": right_dir,
		"alt_m": local_pos.z,
		"slope_deg": rad_to_deg(slope_rad),
		"width_m": width_m,
		"half_width_m": width_m * 0.5,
		"local_deriv_len": local_deriv.length(),
	}


## Returns entry coordinates and approach bearing for all 4 Blue Sea canal gates.
func get_blue_sea_gate_coordinates() -> Dictionary:
	var result: Dictionary = {}
	for canal_id: StringName in [CANAL_NORTH_BLUE, CANAL_EAST_BLUE, CANAL_WEST_BLUE, CANAL_SOUTH_BLUE]:
		var gate_sample: Dictionary = sample_canal(canal_id, 0.0)
		var geo: Dictionary = world_to_spherical(gate_sample["world_pos"])
		result[canal_id] = {
			"label": _canal_defs[canal_id]["label"],
			"lat_deg": geo["lat_deg"],
			"lon_deg": geo["lon_deg"],
			"alt_m": geo["alt_m"],
			"gate_width_m": gate_sample["width_m"],
			"world_pos": gate_sample["world_pos"],
			"inward_flow_dir": gate_sample["flow_tangent"],
		}
	return result


## Projects any 3D world coordinate onto the nearest canal or the Summit Basin.
func find_closest_canal_sample(world_pos: Vector3) -> Dictionary:
	var summit_center: Vector3 = local_tangent_to_world(0.0, 0.0, SUMMIT_ELEVATION_M)
	var summit_offset: Vector3 = world_pos - summit_center
	var summit_radial_dist: float = (summit_offset - _node_a_normal * summit_offset.dot(_node_a_normal)).length()
	var summit_alt_err: float = abs(world_pos.length() - (PLANET_RADIUS_M + SUMMIT_ELEVATION_M))
	var in_summit_basin: bool = summit_radial_dist <= SUMMIT_BASIN_RADIUS_M and summit_alt_err <= 450.0

	var best_canal: StringName = &""
	var best_sample: Dictionary = {}
	var best_dist_sq: float = INF

	for canal_id: StringName in _canal_samples.keys():
		var table: Array = _canal_samples[canal_id]
		var coarse_idx: int = 0
		var coarse_dist_sq: float = INF
		for i: int in range(table.size()):
			var d_sq: float = world_pos.distance_squared_to(table[i]["world_pos"])
			if d_sq < coarse_dist_sq:
				coarse_dist_sq = d_sq
				coarse_idx = i

		# Refine t around coarse_idx via golden-section / binary ternary search
		var t_low: float = max(0.0, float(coarse_idx - 1) / 64.0)
		var t_high: float = min(1.0, float(coarse_idx + 1) / 64.0)
		for _iter: int in range(10):
			var t_m1: float = t_low + (t_high - t_low) * 0.3333333333
			var t_m2: float = t_low + (t_high - t_low) * 0.6666666667
			var d1: float = world_pos.distance_squared_to(sample_canal(canal_id, t_m1)["world_pos"])
			var d2: float = world_pos.distance_squared_to(sample_canal(canal_id, t_m2)["world_pos"])
			if d1 < d2:
				t_high = t_m2
			else:
				t_low = t_m1

		var t_best: float = (t_low + t_high) * 0.5
		var cand: Dictionary = sample_canal(canal_id, t_best)
		var cand_d_sq: float = world_pos.distance_squared_to(cand["world_pos"])
		if cand_d_sq < best_dist_sq:
			best_dist_sq = cand_d_sq
			best_canal = canal_id
			best_sample = cand

	var rel: Vector3 = world_pos - best_sample["world_pos"]
	var lateral_offset_m: float = rel.dot(best_sample["right_dir"])
	var vertical_offset_m: float = rel.dot(best_sample["up_dir"])
	var half_w: float = best_sample["half_width_m"]
	var wall_clearance_m: float = half_w - abs(lateral_offset_m)
	var inside_canal: bool = abs(lateral_offset_m) <= half_w + 15.0 and abs(vertical_offset_m) <= CANAL_WALL_HEIGHT_M

	return {
		"canal_id": best_canal,
		"t": best_sample["t"],
		"sample": best_sample,
		"lateral_offset_m": lateral_offset_m,
		"vertical_offset_m": vertical_offset_m,
		"wall_clearance_m": wall_clearance_m,
		"inside_canal": inside_canal,
		"in_summit_basin": in_summit_basin,
		"summit_center": summit_center,
	}


# ---------------------------------------------------------------------------
# Hydraulic Current Forces, Steering Assist & Wall Collision Damage
# ---------------------------------------------------------------------------
## Computes 64-bit hydraulic acceleration, gravity compensation, steering assist, and wall impact data
## for a ShipVessel navigating Reverse Mountain.
func compute_hydraulic_step(
	ship: Node3D,
	ship_pos: Vector3,
	ship_vel: Vector3,
	rudder_input: float,
	sail_trim: float,
	ship_beam_m: float = 12.0,
	rudder_integrity: float = 1.0,
	delta: float = 0.0166667
) -> Dictionary:
	var proj: Dictionary = find_closest_canal_sample(ship_pos)
	var ship_id: int = ship.get_instance_id() if ship != null else 0

	if proj["in_summit_basin"]:
		return _compute_summit_convergence_step(ship, ship_id, ship_pos, ship_vel, proj["summit_center"], delta)

	if not proj["inside_canal"]:
		if _ship_canal_tracking.has(ship_id):
			var prev_canal: StringName = _ship_canal_tracking[ship_id]
			_ship_canal_tracking.erase(ship_id)
			if prev_canal == CANAL_PARADISE_EXIT and proj["t"] >= 0.94:
				twin_cape_exited.emit(ship)
		return {
			"active": false,
			"zone": &"open_sea_or_red_line",
			"acceleration": Vector3.ZERO,
			"corrected_velocity": ship_vel,
			"wall_hit": false,
			"hull_damage": 0.0,
			"rudder_damage": 0.0,
			"canal_id": &"",
		}

	var canal_id: StringName = proj["canal_id"]
	if _ship_canal_tracking.get(ship_id, &"") != canal_id:
		_ship_canal_tracking[ship_id] = canal_id
		canal_entered.emit(ship, canal_id)

	var s: Dictionary = proj["sample"]
	var flow_dir: Vector3 = s["flow_tangent"]
	var right_dir: Vector3 = s["right_dir"]
	var up_dir: Vector3 = s["up_dir"]

	# Winter Island hydraulic velocity target: steeper uphill surges faster; downhill exit accelerates hard
	var is_exit: bool = (canal_id == CANAL_PARADISE_EXIT)
	var base_speed: float = descend_target_speed_mps if is_exit else ascend_target_speed_mps
	var trim_bonus: float = clamp(sail_trim, 0.0, 1.0) * 14.0
	var target_flow_speed: float = base_speed + trim_bonus

	# Hydraulic stream pushes along flow_dir AND balances the component of gravity pulling back down the slope
	var along_speed: float = ship_vel.dot(flow_dir)
	var gravity_opposing_along: float = GRAVITY_MPS2 * up_dir.dot(flow_dir)
	var hydraulic_accel_along: float = (target_flow_speed - along_speed) * hydraulic_gain + gravity_opposing_along

	# Lateral rudder control + subtle centering assist (reduced if rudder is damaged)
	var lateral_offset: float = proj["lateral_offset_m"]
	var effective_rudder: float = clamp(rudder_input, -1.0, 1.0) * clamp(rudder_integrity, 0.15, 1.0)
	var rudder_lateral_accel: float = effective_rudder * 16.0
	var assist_centering_accel: float = (-lateral_offset / max(1.0, s["half_width_m"])) * steering_assist_strength * 14.0
	var turbulence: float = sin(Time.get_ticks_msec() * 0.0023 + proj["t"] * 31.0) * winter_storm_turbulence_mps2

	var total_accel: Vector3 = (
		flow_dir * hydraulic_accel_along
		+ right_dir * (rudder_lateral_accel + assist_centering_accel + turbulence)
	)

	# Keep vessel buoyed near the canal water surface elevation
	var vertical_error: float = proj["vertical_offset_m"]
	total_accel += up_dir * (-vertical_error * 6.5 - ship_vel.dot(up_dir) * 2.2)

	# Red Line sheer stone wall collision check
	var usable_half_width: float = s["half_width_m"] - (ship_beam_m * 0.5)
	var wall_hit: bool = false
	var hull_damage: float = 0.0
	var rudder_damage: float = 0.0
	var out_vel: Vector3 = ship_vel + total_accel * delta

	if abs(lateral_offset) > usable_half_width:
		wall_hit = true
		var wall_sign: float = sign(lateral_offset)
		var outward_speed: float = max(0.0, out_vel.dot(right_dir * wall_sign))
		var scrape_speed: float = max(outward_speed, out_vel.length() * 0.12)
		hull_damage = scrape_speed * 2.1
		if outward_speed >= rudder_break_threshold_mps:
			rudder_damage = (outward_speed - rudder_break_threshold_mps) * 0.045 + 0.15
		# Reflect & slide back inside the 400m stone channel
		out_vel -= right_dir * wall_sign * outward_speed * (1.0 + wall_restitution)
		out_vel -= right_dir * wall_sign * 4.5
		canal_wall_impact.emit(ship, canal_id, outward_speed, hull_damage, rudder_damage)

	return {
		"active": true,
		"zone": canal_id,
		"canal_id": canal_id,
		"t": proj["t"],
		"alt_m": s["alt_m"],
		"slope_deg": s["slope_deg"],
		"lateral_offset_m": lateral_offset,
		"wall_clearance_m": usable_half_width - abs(lateral_offset),
		"acceleration": total_accel,
		"corrected_velocity": out_vel,
		"wall_hit": wall_hit,
		"hull_damage": hull_damage,
		"rudder_damage": rudder_damage,
		"water_surface_pos": s["world_pos"],
	}


func _compute_summit_convergence_step(
	ship: Node3D,
	ship_id: int,
	ship_pos: Vector3,
	ship_vel: Vector3,
	summit_center: Vector3,
	delta: float
) -> Dictionary:
	var prev_canal: StringName = _ship_canal_tracking.get(ship_id, &"")
	if prev_canal != &"" and prev_canal != CANAL_PARADISE_EXIT:
		summit_basin_reached.emit(ship, prev_canal)
		_ship_canal_tracking[ship_id] = CANAL_PARADISE_EXIT

	var exit_entry: Dictionary = sample_canal(CANAL_PARADISE_EXIT, 0.0)
	var to_exit: Vector3 = (exit_entry["world_pos"] - ship_pos).normalized()
	var up_dir: Vector3 = ship_pos.normalized()
	var desired_vel: Vector3 = to_exit * 52.0
	var accel: Vector3 = (desired_vel - ship_vel) * 2.2
	var alt_err: float = ship_pos.length() - (PLANET_RADIUS_M + SUMMIT_ELEVATION_M)
	accel += up_dir * (-alt_err * 6.0)

	return {
		"active": true,
		"zone": &"summit_basin",
		"canal_id": CANAL_PARADISE_EXIT,
		"t": 0.0,
		"alt_m": SUMMIT_ELEVATION_M,
		"slope_deg": 0.0,
		"lateral_offset_m": 0.0,
		"wall_clearance_m": SUMMIT_BASIN_RADIUS_M,
		"acceleration": accel,
		"corrected_velocity": ship_vel + accel * delta,
		"wall_hit": false,
		"hull_damage": 0.0,
		"rudder_damage": 0.0,
		"water_surface_pos": summit_center,
	}


# ---------------------------------------------------------------------------
# Laboon (400m Island Whale) Dynamic Obstacle & Interior Cavern Zone
# ---------------------------------------------------------------------------
func _reset_laboon_to_bay() -> void:
	# Positioned directly in Twin Cape Bay just outside the Canal 5 exit (~149.2 km east of Node A)
	laboon_world_pos = local_tangent_to_world(149_200.0, 0.0, 0.0)
	laboon_forward = (-_local_east).normalized() # Facing west toward the Red Line wall


func _update_laboon_cycle(delta: float) -> void:
	if laboon_state == LaboonState.CALMED_JOLLY_ROGER_PROMISE or laboon_state == LaboonState.REUNITED_BINKS_SAKE:
		# Calmly circles Twin Cape Bay near the lighthouse on the spherical ocean surface
		_headbutt_timer += delta * 0.25
		var orbit_r: float = 420.0
		laboon_world_pos = local_tangent_to_world(
			151_500.0 + cos(_headbutt_timer) * orbit_r,
			-600.0 + sin(_headbutt_timer) * orbit_r,
			0.0
		)
		laboon_forward = (-_local_east * sin(_headbutt_timer) + _local_north * cos(_headbutt_timer)).normalized()
		return

	_headbutt_timer = fmod(_headbutt_timer + delta, headbutt_cycle_seconds)
	var phase: float = _headbutt_timer / headbutt_cycle_seconds
	if phase < 0.72:
		laboon_state = LaboonState.PATROLLING_BAY
		var sway: float = sin(phase * TAU) * 320.0
		laboon_world_pos = local_tangent_to_world(149_400.0, sway, 0.0)
		laboon_forward = (-_local_east).normalized()
	elif phase < 0.88:
		laboon_state = LaboonState.MOUTH_OPEN_SWALLOW
		laboon_world_pos = local_tangent_to_world(148_850.0, 0.0, 0.0)
		laboon_forward = (-_local_east).normalized()
	else:
		if laboon_state != LaboonState.HEADBUTTING_RED_LINE:
			laboon_state = LaboonState.HEADBUTTING_RED_LINE
			laboon_headbutt_shockwave.emit(laboon_world_pos, 1.0)
		laboon_world_pos = local_tangent_to_world(148_250.0, 0.0, 0.0)
		laboon_forward = (-_local_east).normalized()


## Evaluates whether an approaching ship collides with Laboon's 400m body or gets swallowed into the stomach cavern.
func evaluate_laboon_encounter(ship: Node3D, ship_pos: Vector3, ship_vel: Vector3) -> Dictionary:
	var ship_id: int = ship.get_instance_id() if ship != null else 0
	if _ships_inside_laboon.get(ship_id, false):
		return {
			"zone": &"laboon_stomach_interior",
			"inside_laboon": true,
			"acid_dps": stomach_acid_dps,
			"zones": LABOON_INTERIOR_ZONES,
		}

	var rel: Vector3 = ship_pos - laboon_world_pos
	var along: float = rel.dot(laboon_forward)
	var perp: Vector3 = rel - laboon_forward * along
	var radial_dist: float = perp.length()

	# Check mouth swallow volume near head (+200m forward along Laboon's axis)
	var mouth_pos: Vector3 = laboon_world_pos + laboon_forward * (LABOON_LENGTH_M * 0.42)
	var dist_to_mouth: float = ship_pos.distance_to(mouth_pos)
	if allow_swallow_event and laboon_state == LaboonState.MOUTH_OPEN_SWALLOW and dist_to_mouth <= LABOON_SWALLOW_MOUTH_RADIUS_M:
		_ships_inside_laboon[ship_id] = true
		laboon_swallowed_ship.emit(ship)
		return {
			"zone": &"laboon_stomach_interior",
			"swallowed_this_frame": true,
			"inside_laboon": true,
			"acid_dps": stomach_acid_dps,
			"zones": LABOON_INTERIOR_ZONES,
		}

	# Ellipsoid obstacle collision against Laboon's 400m x 110m body
	var half_len: float = LABOON_LENGTH_M * 0.5
	var half_beam: float = LABOON_BEAM_M * 0.5
	var norm_ellipsoid: float = (along * along) / (half_len * half_len) + (radial_dist * radial_dist) / (half_beam * half_beam)
	if norm_ellipsoid <= 1.0:
		var push_normal: Vector3 = rel.normalized() if rel.length_squared() > 0.01 else laboon_forward
		var impact_speed: float = max(0.0, -ship_vel.dot(push_normal))
		return {
			"zone": &"laboon_exterior_impact",
			"collided": true,
			"push_normal": push_normal,
			"impact_speed_mps": impact_speed,
			"hull_damage": impact_speed * 1.4,
			"inside_laboon": false,
		}

	return {
		"zone": &"twin_cape_bay",
		"collided": false,
		"inside_laboon": false,
		"distance_to_laboon_m": rel.length(),
		"laboon_state": laboon_state,
	}


## Exits Laboon's stomach via Crocus's riveted steel doors back into Twin Cape Bay.
func exit_laboon_via_steel_doors(ship: Node3D) -> Vector3:
	if ship != null:
		_ships_inside_laboon.erase(ship.get_instance_id())
	return get_twin_cape_dock_world_pos()


## Completes the Luffy-style promise duel and paints the crew's Jolly Roger onto Laboon's forehead scar.
func fulfill_laboon_jolly_roger_promise() -> void:
	laboon_scar_jolly_roger_painted = true
	if laboon_state != LaboonState.REUNITED_BINKS_SAKE:
		laboon_state = LaboonState.CALMED_JOLLY_ROGER_PROMISE
	laboon_promise_fulfilled.emit()


# ---------------------------------------------------------------------------
# Twin Cape Lighthouse Docking Zone, Crocus Clinic & Log Pose System
# ---------------------------------------------------------------------------
func get_twin_cape_dock_world_pos() -> Vector3:
	return spherical_to_world(
		TWIN_CAPE_SETTLEMENT["dock_lat_deg"],
		TWIN_CAPE_SETTLEMENT["dock_lon_deg"],
		0.0
	)


func get_lighthouse_world_pos() -> Vector3:
	return spherical_to_world(
		TWIN_CAPE_SETTLEMENT["lighthouse_lat_deg"],
		TWIN_CAPE_SETTLEMENT["lighthouse_lon_deg"],
		TWIN_CAPE_SETTLEMENT["lighthouse_alt_m"]
	)


func check_lighthouse_docking(ship: Node3D, ship_pos: Vector3) -> Dictionary:
	var dock_pos: Vector3 = get_twin_cape_dock_world_pos()
	var dist_m: float = ship_pos.distance_to(dock_pos)
	var in_dock_zone: bool = dist_m <= TWIN_CAPE_DOCK_RADIUS_M
	if in_dock_zone and ship != null:
		lighthouse_docked.emit(ship)
	return {
		"in_dock_zone": in_dock_zone,
		"distance_m": dist_m,
		"dock_world_pos": dock_pos,
		"lighthouse_world_pos": get_lighthouse_world_pos(),
		"beacon_visible": ship_pos.distance_to(get_lighthouse_world_pos()) <= LIGHTHOUSE_BEACON_RANGE_M,
	}


## Crocus Clinic interaction: heals crew, offers clinic wares, gifts the initial Log Pose, and sets 1 of 7 routes.
func interact_with_crocus(recipient: Node, route_choice: int = 1) -> Dictionary:
	selected_paradise_route = clamp(route_choice, 1, 7)
	var gifted_now: bool = false
	var log_pose_item: Dictionary = TWIN_CAPE_SETTLEMENT["marketplace_inventory"][0].duplicate(true)
	log_pose_item["locked_route_id"] = selected_paradise_route
	log_pose_item["first_target"] = TWIN_CAPE_SETTLEMENT["seven_paradise_routes"][selected_paradise_route - 1]

	if not player_log_pose_gifted:
		player_log_pose_gifted = true
		gifted_now = true
		log_pose_gifted.emit(recipient, log_pose_item)

	return {
		"npc": TWIN_CAPE_SETTLEMENT["npcs"]["crocus"],
		"gifted_log_pose_now": gifted_now,
		"log_pose_item": log_pose_item,
		"tutorial_steps": [
			"Standard magnetic compasses fail in the Grand Line due to iron-rich island magnetic fields.",
			"Wait on each island until your Log Pose finishes recording its magnetic wave before sailing.",
			"Twin Cape branches into 7 magnetic routes; Route 1 leads straight to Whisky Peak (10-min lock).",
		],
		"clinic_shop": TWIN_CAPE_SETTLEMENT["marketplace_inventory"],
	}


## Late-game Thriller Bark / Brook hook: delivers the Rumbar Pirates' Tone Dial recording of "Binks' Sake".
func trigger_rumbar_tone_dial_hook(has_binks_sake_tone_dial: bool) -> Dictionary:
	if not has_binks_sake_tone_dial:
		return {
			"completed": false,
			"message": "Requires the Rumbar Pirates' Tone Dial containing Brook's recording of 'Binks' Sake' (Florian Triangle).",
		}

	rumbar_tone_dial_delivered = true
	laboon_state = LaboonState.REUNITED_BINKS_SAKE
	var unlock_data: Dictionary = {
		"completed": true,
		"song": "Binks' Sake (Rumbar Pirates Final Chorus)",
		"reward_title": "Oathkeeper of Twin Cape",
		"laboon_blessing": "Island Whale Resonance — reduces Calm Belt & Sea King aggro near Red Line crossings.",
		"crocus_gift": "Roger Pirates Sea Chart Fragment",
	}
	rumbar_tone_dial_played.emit(unlock_data)
	return unlock_data
