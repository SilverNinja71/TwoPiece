class_name BuoyantShipVessel
extends RigidBody3D
## 64-Bit Spherical Buoyant Ship Vessel for Project "Blue Planet"
## Operates seamlessly on the R = 16,000,000.0 m (C = 100,531 km) globe in Godot 4.3+ (precision=double).
##
## Features:
## - Dynamic spherical gravity (`-up_direction * 9.81`) and radial buoyancy at Sea Level (`0 m`),
##   White Sea (`+7,000 m`), White-White Sea (`+10,000 m`), or Abyssal Trench (`-10,000 m`).
## - Sail/wind propulsion + rudder steering with tangential geodesic velocity.
## - Calm Belt awareness (`0.0 m/s` wind clamp, Paddlewheel override, Seastone keel Sea King masking).
## - Cola-powered Coup de Burst (`1,000 m` aerial launch).
## - Yarukiman Mangrove Resin underwater diving (`-10,000 m` Fish-Man Island depth).
## - Deck boarding & helm piloting integration compatible with `SphericalPlayer`.

signal coup_de_burst_fired(cola_remaining: int, launch_origin: Vector3)
signal dive_depth_changed(current_alt_m: float, target_depth_m: float)
signal vessel_zone_updated(zone_info: Dictionary)
signal ship_damaged(amount: float, remaining_integrity: float, reason: String)

# ==============================================================================
# 1. SCALE & NAVAL PHYSICS CONSTANTS
# ==============================================================================
const GRAVITY_ACCEL_MS2: float = 9.81
const DECK_HALF_LENGTH_M: float = 11.0
const DECK_HALF_WIDTH_M: float = 4.2
const DECK_SURFACE_Y_OFFSET_M: float = 1.6

const MAX_SAIL_SPEED_MS: float = 34.0       # ~66 knots cinematic cruising speed across 100,531 km globe
const PADDLEWHEEL_SPEED_MS: float = 22.0    # Calm Belt / windless propulsion
const RUDDER_TURN_RATE_RAD_S: float = 0.85
const COUP_DE_BURST_BARRELS_COST: int = 3
const COUP_DE_BURST_RANGE_M: float = 1_000.0
const COUP_DE_BURST_COOLDOWN_SEC: float = 12.0
const MAX_ABYSSAL_DIVE_DEPTH_M: float = -10_000.0

# ==============================================================================
# 2. VESSEL CONFIGURATION & PROGRESSION STATE
# ==============================================================================
@export var vessel_name: String = "Going Caravel"
@export var max_hull_integrity: float = 2_500.0
@export var current_hull_integrity: float = 2_500.0
@export var has_seastone_keel: bool = false
@export var has_paddlewheel_drive: bool = false
@export var has_coup_de_burst: bool = true
@export var has_yarukiman_resin_coating: bool = false
@export var cola_barrels: int = 12
@export var sail_trim_ratio: float = 0.75

var up_direction: Vector3 = Vector3.UP
var target_submersion_alt_m: float = 0.0
var is_submerged_diving: bool = false
var current_zone_info: Dictionary = {}

var _helm_throttle: float = 0.0
var _helm_rudder: float = 0.0
var _coup_de_burst_timer_sec: float = 0.0
var _tangent_velocity: Vector3 = Vector3.ZERO
var _radial_velocity_ms: float = 0.0
var _zone_check_accum_sec: float = 0.0
var _planet_sphere: Node = null
var _boarding_area: Area3D = null

# ==============================================================================
# 3. LIFECYCLE & PROCEDURAL HULL / DECK RIG
# ==============================================================================
func _ready() -> void:
	custom_integrator = true
	can_sleep = false
	mass = 24_000.0
	_ensure_ship_hull_and_deck_rig()

	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	if fo != null and global_position.length() < 1_000_000.0:
		up_direction = fo.call("get_local_up_at_origin")
		if fo.has_signal("origin_rebased"):
			fo.connect("origin_rebased", _on_floating_origin_rebased)
	else:
		if global_position.length_squared() < 1.0:
			# Legacy 64-bit ECEF mooring at Dawn Island (lat=52.0 deg, lon=74.0 deg)
			global_position = PlanetSphere.lat_lon_alt_to_world(52.0, 74.0, 0.5)
		up_direction = global_position.normalized()

	_align_vessel_to_planet_up(up_direction, 1.0)
	_planet_sphere = _find_planet_sphere_node()
	_sync_upgrades_from_campaign()

func _on_floating_origin_rebased(delta_local: Vector3) -> void:
	global_position += delta_local

func _ensure_ship_hull_and_deck_rig() -> void:
	if get_node_or_null("HullCollision") == null:
		var hull_col := CollisionShape3D.new()
		hull_col.name = "HullCollision"
		var box := BoxShape3D.new()
		box.size = Vector3(DECK_HALF_WIDTH_M * 2.0, 3.2, DECK_HALF_LENGTH_M * 2.0)
		hull_col.shape = box
		hull_col.position = Vector3(0.0, 0.0, 0.0)
		add_child(hull_col)

	if get_node_or_null("VisualHull") == null:
		var hull_mesh_inst := MeshInstance3D.new()
		hull_mesh_inst.name = "VisualHull"
		var hull_box := BoxMesh.new()
		hull_box.size = Vector3(DECK_HALF_WIDTH_M * 2.0, 3.0, DECK_HALF_LENGTH_M * 2.0)
		var hull_mat := StandardMaterial3D.new()
		hull_mat.albedo_color = Color(0.45, 0.26, 0.14)
		hull_mesh_inst.mesh = hull_box
		hull_mesh_inst.material_override = hull_mat
		add_child(hull_mesh_inst)

		# Main Mast + Sail
		var mast_inst := MeshInstance3D.new()
		mast_inst.name = "MainMast"
		var mast_cyl := CylinderMesh.new()
		mast_cyl.top_radius = 0.22
		mast_cyl.bottom_radius = 0.35
		mast_cyl.height = 16.0
		mast_inst.mesh = mast_cyl
		mast_inst.position = Vector3(0.0, 9.5, 0.0)
		add_child(mast_inst)

		var sail_inst := MeshInstance3D.new()
		sail_inst.name = "MainSail"
		var sail_box := BoxMesh.new()
		sail_box.size = Vector3(9.5, 8.5, 0.15)
		var sail_mat := StandardMaterial3D.new()
		sail_mat.albedo_color = Color(0.95, 0.92, 0.85)
		sail_inst.mesh = sail_box
		sail_inst.material_override = sail_mat
		sail_inst.position = Vector3(0.0, 11.0, -0.4)
		add_child(sail_inst)

	_boarding_area = get_node_or_null("DeckBoardingArea") as Area3D
	if _boarding_area == null:
		_boarding_area = Area3D.new()
		_boarding_area.name = "DeckBoardingArea"
		var deck_col := CollisionShape3D.new()
		deck_col.name = "DeckZoneShape"
		var deck_box := BoxShape3D.new()
		deck_box.size = Vector3(DECK_HALF_WIDTH_M * 2.2, 4.5, DECK_HALF_LENGTH_M * 2.2)
		deck_col.shape = deck_box
		deck_col.position = Vector3(0.0, DECK_SURFACE_Y_OFFSET_M + 1.8, 0.0)
		_boarding_area.add_child(deck_col)
		add_child(_boarding_area)
		_boarding_area.body_entered.connect(_on_deck_body_entered)
		_boarding_area.body_exited.connect(_on_deck_body_exited)

# ==============================================================================
# 4. PHYSICS LOOP: 64-BIT SPHERICAL BUOYANCY, GRAVITY & PROPULSION
# ==============================================================================
func _physics_process(delta: float) -> void:
	if _coup_de_burst_timer_sec > 0.0:
		_coup_de_burst_timer_sec = maxf(0.0, _coup_de_burst_timer_sec - delta)

	_zone_check_accum_sec += delta
	if _zone_check_accum_sec >= 0.5:
		_zone_check_accum_sec = 0.0
		_refresh_planetary_zone_and_hazards()

	# Allow Coup de Burst when piloted or requested
	if Input.is_action_just_pressed("coup_de_burst") and has_coup_de_burst:
		trigger_coup_de_burst()

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var delta: float = state.step
	var pos: Vector3 = state.transform.origin
	var radius: float = pos.length()
	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	var using_floating_origin: bool = (fo != null and radius < 1_000_000.0)
	var current_alt_m: float = 0.0

	if using_floating_origin:
		up_direction = fo.call("get_local_up_at_origin")
		var lla: Dictionary = fo.call("local32_to_lat_lon_alt", pos)
		current_alt_m = float(lla.get("alt_m", pos.y))
	else:
		if radius > 1.0:
			up_direction = pos / radius
		else:
			up_direction = Vector3.UP
		current_alt_m = radius - PlanetSphere.SEA_LEVEL_RADIUS

	# 1. Align ship basis smoothly to local planetary tangent plane + apply rudder yaw
	var current_basis: Basis = state.transform.basis
	var current_up: Vector3 = current_basis.y.normalized()
	if current_up.dot(up_direction) < 0.999999:
		var align_quat := Quaternion(current_up, up_direction)
		current_basis = (Basis(align_quat) * current_basis).orthonormalized()

	if absf(_helm_rudder) > 0.01:
		var yaw_delta: float = -_helm_rudder * RUDDER_TURN_RATE_RAD_S * delta
		current_basis = current_basis.rotated(up_direction, yaw_delta).orthonormalized()

	# 2. Sample vertical fluid layer (Blue Sea 0m, White Sea +7km, White-White Sea +10km, Abyss -10km)
	var fluid_info: Dictionary = _sample_fluid_layer(pos)
	var fluid_surface_alt_m: float = float(fluid_info.get("surface_alt_m", 0.0))
	var fluid_density: float = float(fluid_info.get("fluid_density_ratio", 1.0))

	if is_submerged_diving and has_yarukiman_resin_coating:
		# Yarukiman bubble buoyancy pedal target depth down to -10,000m Fish-Man Island
		var depth_error: float = target_submersion_alt_m - current_alt_m
		_radial_velocity_ms = clampf(depth_error * 0.65, -28.0, 28.0)
	else:
		# Standard spherical gravity + hydrostatic spring-damper buoyancy on the curved ocean
		var submerged_m: float = fluid_surface_alt_m - current_alt_m
		if submerged_m > -0.2:
			var buoyant_accel: float = clampf(submerged_m * 18.0 * fluid_density, 0.0, 45.0)
			_radial_velocity_ms += (buoyant_accel - GRAVITY_ACCEL_MS2) * delta
			_radial_velocity_ms *= exp(-2.8 * delta) # Hydrodynamic vertical heave damping
		else:
			# Airborne (e.g., riding a Coup de Burst or Knock Up Stream)
			_radial_velocity_ms = maxf(_radial_velocity_ms - GRAVITY_ACCEL_MS2 * delta, -65.0)

	# 3. Wind & Paddlewheel Propulsion along local spherical tangent plane
	var forward_tangent: Vector3 = -current_basis.z
	forward_tangent = (forward_tangent - up_direction * forward_tangent.dot(up_direction)).normalized()

	var in_calm_belt: bool = bool(current_zone_info.get("is_calm_belt", false))
	var wind_mult: float = 0.0 if in_calm_belt else float(current_zone_info.get("wind_multiplier", 1.0))
	var effective_top_speed: float = 0.0
	if wind_mult > 0.01:
		effective_top_speed = MAX_SAIL_SPEED_MS * wind_mult * clampf(sail_trim_ratio, 0.25, 1.0)
	elif has_paddlewheel_drive:
		effective_top_speed = PADDLEWHEEL_SPEED_MS

	if absf(_helm_throttle) > 0.01 and effective_top_speed > 0.0:
		var target_vec: Vector3 = forward_tangent * (_helm_throttle * effective_top_speed)
		_tangent_velocity = _tangent_velocity.move_toward(target_vec, 14.0 * delta)
	else:
		# Water drag preserves Coup de Burst horizontal momentum when airborne
		var drag_rate: float = 4.5 if (fluid_surface_alt_m - current_alt_m) >= -0.2 else 0.4
		_tangent_velocity = _tangent_velocity.move_toward(Vector3.ZERO, drag_rate * delta)

	# Project tangent velocity cleanly onto the sphere tangent plane so speed stays parallel to curvature
	_tangent_velocity = _tangent_velocity - up_direction * _tangent_velocity.dot(up_direction)

	# 4. Integrate final 64-bit world velocity and transform
	var total_vel: Vector3 = _tangent_velocity + (up_direction * _radial_velocity_ms)
	state.linear_velocity = total_vel
	state.angular_velocity = Vector3.ZERO
	state.transform = Transform3D(current_basis, pos + total_vel * delta)

	# Decay helm inputs each tick (must be held by SphericalPlayer or AI autopilot)
	_helm_throttle = move_toward(_helm_throttle, 0.0, 3.0 * delta)
	_helm_rudder = move_toward(_helm_rudder, 0.0, 4.0 * delta)

func _align_vessel_to_planet_up(target_up: Vector3, weight: float) -> void:
	var current_up: Vector3 = global_transform.basis.y.normalized()
	if current_up.dot(target_up) > 0.999999:
		return
	var rot_quat := Quaternion(current_up, target_up)
	var target_basis: Basis = (Basis(rot_quat) * global_transform.basis).orthonormalized()
	global_transform.basis = global_transform.basis.slerp(target_basis, weight).orthonormalized()

# ==============================================================================
# 5. HELM, COUP DE BURST (1,000m LAUNCH), AND YARUKIMAN ABYSSAL DIVING
# ==============================================================================
## Called by `SphericalPlayer._process_helm_piloting()` when steering at the ship's wheel.
func apply_helm_input(throttle_forward: float, rudder_right: float, _delta: float) -> void:
	_helm_throttle = clampf(throttle_forward, -0.5, 1.0)
	_helm_rudder = clampf(rudder_right, -1.0, 1.0)

## Launches the vessel ~1,000 meters forward & upward using 3 barrels of Cola!
## Ballistic range d = v^2 / g -> for d=1000m at 45 deg, v = sqrt(1000 * 9.81) ≈ 99.05 m/s.
func trigger_coup_de_burst() -> Dictionary:
	if not has_coup_de_burst:
		return {"success": false, "reason": "Coup de Burst engine not installed (Visit Water 7)"}
	if _coup_de_burst_timer_sec > 0.0:
		return {"success": false, "reason": "Cola pressure recharging", "cooldown_sec": _coup_de_burst_timer_sec}
	if cola_barrels < COUP_DE_BURST_BARRELS_COST:
		return {"success": false, "reason": "Insufficient Cola barrels (requires 3)"}

	cola_barrels -= COUP_DE_BURST_BARRELS_COST
	_coup_de_burst_timer_sec = COUP_DE_BURST_COOLDOWN_SEC

	var forward_tangent: Vector3 = -global_transform.basis.z
	forward_tangent = (forward_tangent - up_direction * forward_tangent.dot(up_direction)).normalized()
	var launch_speed_comp: float = sqrt(COUP_DE_BURST_RANGE_M * GRAVITY_ACCEL_MS2 * 0.5) # ~70.0 m/s H + ~70.0 m/s V
	_tangent_velocity += forward_tangent * launch_speed_comp
	_radial_velocity_ms = maxf(_radial_velocity_ms, launch_speed_comp)
	is_submerged_diving = false

	coup_de_burst_fired.emit(cola_barrels, global_position)
	return {
		"success": true,
		"cola_barrels_remaining": cola_barrels,
		"estimated_arc_m": COUP_DE_BURST_RANGE_M
	}

## Sets target diving altitude (e.g., -10,000.0 m for Fish-Man Island) if coated in Yarukiman Resin.
func set_abyssal_dive_depth(target_alt_m: float) -> Dictionary:
	if target_alt_m < -50.0 and not has_yarukiman_resin_coating:
		return {
			"success": false,
			"reason": "Requires Yarukiman Mangrove Resin Coating from Sabaody Grove 50s!"
		}
	target_submersion_alt_m = clampf(target_alt_m, MAX_ABYSSAL_DIVE_DEPTH_M, 0.0)
	is_submerged_diving = (target_submersion_alt_m < -2.0)
	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	var coords: Dictionary = (
		fo.call("local32_to_lat_lon_alt", global_position)
		if (fo != null and global_position.length() < 1_000_000.0)
		else PlanetSphere.world_to_lat_lon_alt(global_position)
	)
	dive_depth_changed.emit(coords["alt_m"], target_submersion_alt_m)
	return {
		"success": true,
		"is_submerged": is_submerged_diving,
		"target_alt_m": target_submersion_alt_m
	}

## Emergency/scripting impulse hook (used by Reverse Mountain canals & Knock Up Stream).
func apply_external_world_impulse(world_delta_velocity: Vector3) -> void:
	var rad_comp: float = world_delta_velocity.dot(up_direction)
	var tan_comp: Vector3 = world_delta_velocity - up_direction * rad_comp
	_radial_velocity_ms += rad_comp
	_tangent_velocity += tan_comp

func apply_hull_damage(amount: float, reason: String = "Collision") -> void:
	current_hull_integrity = maxf(0.0, current_hull_integrity - amount)
	ship_damaged.emit(amount, current_hull_integrity, reason)

# ==============================================================================
# 6. ZONE AWARENESS, BOARDING & CAMPAIGN SYNC HELPERS
# ==============================================================================
func _to_global_planet_vec3(pos: Vector3) -> Vector3:
	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	if fo != null and pos.length() < 1_000_000.0:
		return fo.call("local32_to_world_vec3", pos)
	return pos

func _refresh_planetary_zone_and_hazards() -> void:
	if _planet_sphere != null and _planet_sphere.has_method("classify_global_coordinates"):
		var world_vec: Vector3 = _to_global_planet_vec3(global_position)
		current_zone_info = _planet_sphere.call("classify_global_coordinates", world_vec)
		if _planet_sphere.has_method("evaluate_calm_belt_hazard"):
			_planet_sphere.call(
				"evaluate_calm_belt_hazard",
				world_vec,
				has_seastone_keel,
				has_paddlewheel_drive
			)
		vessel_zone_updated.emit(current_zone_info)

func _sample_fluid_layer(pos: Vector3) -> Dictionary:
	if _planet_sphere != null and _planet_sphere.has_method("sample_buoyant_fluid_layer"):
		return _planet_sphere.call("sample_buoyant_fluid_layer", _to_global_planet_vec3(pos), has_yarukiman_resin_coating)
	return {"surface_alt_m": 0.0, "fluid_density_ratio": 1.0, "crush_hazard": false}

func _find_planet_sphere_node() -> Node:
	var parent_node: Node = get_parent()
	if parent_node != null:
		var sibling: Node = parent_node.get_node_or_null("PlanetSphere")
		if sibling != null:
			return sibling
	return null

func _sync_upgrades_from_campaign() -> void:
	var scm: Node = get_node_or_null("/root/StoryCampaignManager")
	if scm == null:
		return
	var state: Variant = scm.get("ship_state")
	if state is Dictionary:
		vessel_name = str(state.get("vessel_class", vessel_name))
		has_seastone_keel = (str(state.get("keel_plating", "NONE")) == "SEASTONE_KEEL_PLATING")
		has_yarukiman_resin_coating = (str(state.get("submersion_coating", "NONE")) == "YARUKIMAN_RESIN_COATING")
		var prop_tier: String = str(state.get("propulsion_tier", "CANVAS_SAILS"))
		has_paddlewheel_drive = (prop_tier == "YUDA_PADDLEWHEEL" or prop_tier == "COLA_COUP_DE_BURST")
		has_coup_de_burst = (prop_tier == "COLA_COUP_DE_BURST" or has_coup_de_burst)

func get_deck_spawn_world_position() -> Vector3:
	return global_position + up_direction * (DECK_SURFACE_Y_OFFSET_M + 0.5)

func _on_deck_body_entered(body: Node3D) -> void:
	if body != self and body.has_method("board_ship_deck"):
		body.call("board_ship_deck", self)

func _on_deck_body_exited(body: Node3D) -> void:
	if body != self and body.has_method("disembark_ship"):
		var current_boarded: Variant = body.get("boarded_ship")
		if current_boarded == self:
			body.call("disembark_ship")
