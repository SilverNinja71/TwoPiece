class_name SphericalPlayer
extends CharacterBody3D
## 2.0-Meter-Tall Spherical CharacterBody3D Controller for Project "Blue Planet"
## Operates seamlessly anywhere on the R = 16,000,000.0m (C = 100,531 km) 64-bit sphere.
##
## Features:
## - Dynamic `up_direction = global_position.normalized()` every physics frame.
## - Quaternion-based tangent basis slerp with zero gimbal lock at the poles.
## - Spherical point gravity (`-up_direction * 9.81 m/s^2`).
## - Ship deck walking / boarding state (`ABOARD_SHIP_DECK` & `HELM_PILOTING`) with moving platform velocity transfer.
## - Surveying Sextant cartography hook (computes geometric horizon from elevation + crow's nest/peaks).
## - Haki & Skypiea Dial traversal hooks (Observation Mantra pulse, Armament Ryuo, Jet/Milky Dial dash).

signal movement_mode_changed(previous_mode: int, new_mode: int)
signal sextant_survey_completed(lat_deg: float, lon_deg: float, elevation_m: float, horizon_radius_km: float)
signal ship_boarded(ship_node: Node3D)
signal ship_disembarked(previous_ship_node: Node3D)
signal haki_state_changed(observation_active: bool, armament_active: bool, conqueror_ready: bool)

# ==============================================================================
# 1. SCALE & MOVEMENT CONSTANTS (1 UNIT = 1 METER, PLAYER HEIGHT = 2.0m)
# ==============================================================================
const PLAYER_HEIGHT_M: float = 2.0
const CAPSULE_RADIUS_M: float = 0.4
const EYE_HEIGHT_OFFSET_M: float = 1.75
const GRAVITY_ACCEL_MS2: float = 9.81

const WALK_SPEED_MS: float = 5.5
const SPRINT_SPEED_MS: float = 9.2
const SWIM_SPEED_MS: float = 4.2
const JUMP_VELOCITY_MS: float = 6.5
const JET_DIAL_BURST_MS: float = 22.0
const BASIS_SLERP_SPEED: float = 14.0
const TERMINAL_FALL_SPEED_MS: float = 58.0

enum MovementMode {
	ON_FOOT = 0,
	ABOARD_SHIP_DECK = 1,
	HELM_PILOTING = 2,
	SWIMMING = 3,
	SURVEYING_SEXTANT = 4
}

# ==============================================================================
# 2. EXPORTED & RUNTIME PROPERTIES
# ==============================================================================
@export var mouse_sensitivity_rad: float = 0.0022
@export var devil_fruit_user: bool = false # If true, loses strength when submerged in Blue Sea water
var has_devil_fruit: bool:
	get:
		return devil_fruit_user
	set(value):
		devil_fruit_user = value
@export var equipped_jet_dial: bool = false
@export var equipped_surveying_sextant: bool = true

var current_mode: MovementMode = MovementMode.ON_FOOT
var boarded_ship: Node3D = null
var _ship_previous_global_pos: Vector3 = Vector3.ZERO
var _ship_previous_basis: Basis = Basis.IDENTITY

# Camera & Collision Rig Nodes
var collision_shape_node: CollisionShape3D = null
var camera_pivot_node: Node3D = null
var camera_3d_node: Camera3D = null
var _camera_pitch_rad: float = 0.0

# Haki & Progression Flags
var observation_haki_active: bool = false
var armament_haki_active: bool = false
var conqueror_haki_unlocked: bool = false
var _jet_dial_cooldown_sec: float = 0.0

# ==============================================================================
# 3. INITIALIZATION & RIG SETUP
# ==============================================================================
func _ready() -> void:
	_ensure_2m_capsule_and_camera_rig()
	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	if fo != null and global_position.length() < 1_000_000.0:
		up_direction = fo.call("get_local_up_at_origin")
		if global_position.length() < 10.0:
			global_position = up_direction * 2.2
		if fo.has_signal("origin_rebased"):
			fo.connect("origin_rebased", _on_floating_origin_rebased)
	else:
		if global_position.length_squared() < 1.0:
			# Legacy 64-bit ECEF fallback spawn at Dawn Island (lat=+52.0 deg, lon=+74.0 deg, alt=+2.0m)
			global_position = PlanetSphere.lat_lon_alt_to_world(52.0, 74.0, 2.0)
		up_direction = global_position.normalized()
	_align_basis_to_planet_up(up_direction, 1.0)
	floor_stop_on_slope = true
	floor_max_angle = deg_to_rad(50.0)

func _ensure_2m_capsule_and_camera_rig() -> void:
	collision_shape_node = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape_node == null:
		collision_shape_node = CollisionShape3D.new()
		collision_shape_node.name = "CollisionShape3D"
		var capsule := CapsuleShape3D.new()
		capsule.height = PLAYER_HEIGHT_M
		capsule.radius = CAPSULE_RADIUS_M
		collision_shape_node.shape = capsule
		# Center the 2.0m capsule so the bottom of the feet sits at local origin (0, 1.0, 0)
		collision_shape_node.position = Vector3(0.0, PLAYER_HEIGHT_M * 0.5, 0.0)
		add_child(collision_shape_node)

	camera_pivot_node = get_node_or_null("CameraPivot") as Node3D
	if camera_pivot_node == null:
		camera_pivot_node = Node3D.new()
		camera_pivot_node.name = "CameraPivot"
		camera_pivot_node.position = Vector3(0.0, EYE_HEIGHT_OFFSET_M, 0.0)
		add_child(camera_pivot_node)

	camera_3d_node = camera_pivot_node.get_node_or_null("Camera3D") as Camera3D
	if camera_3d_node == null:
		camera_3d_node = Camera3D.new()
		camera_3d_node.name = "Camera3D"
		camera_3d_node.fov = 75.0
		camera_3d_node.near = 0.1
		camera_3d_node.far = 250_000.0 # 250 km horizon visibility for +10,000m Red Line & Sky Islands
		camera_pivot_node.add_child(camera_3d_node)

# ==============================================================================
# 4. INPUT HANDLING (MOUSE LOOK, SEXTANT, SHIP HELM, HAKI)
# ==============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		# Yaw rotates around the player's local planetary Up axis (global_transform.basis.y)
		rotate_object_local(Vector3.UP, -motion.relative.x * mouse_sensitivity_rad)
		_camera_pitch_rad = clampf(
			_camera_pitch_rad - motion.relative.y * mouse_sensitivity_rad,
			deg_to_rad(-85.0),
			deg_to_rad(85.0)
		)
		if camera_pivot_node != null:
			camera_pivot_node.rotation.x = _camera_pitch_rad

	elif event.is_action_pressed("survey_sextant"):
		use_surveying_sextant()
	elif event.is_action_pressed("interact_helm"):
		toggle_helm_piloting()
	elif event.is_action_pressed("activate_haki"):
		toggle_haki_modes()

# ==============================================================================
# 5. 64-BIT SPHERICAL PHYSICS & TANGENT BASIS SLERP
# ==============================================================================
func _physics_process(delta: float) -> void:
	if _jet_dial_cooldown_sec > 0.0:
		_jet_dial_cooldown_sec = maxf(0.0, _jet_dial_cooldown_sec - delta)

	# 1. Compute planetary Up vector (FloatingOrigin local tangent frame when near origin, else ECEF radial)
	var radial_distance: float = global_position.length()
	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	var using_floating_origin: bool = (fo != null and radial_distance < 1_000_000.0)
	if using_floating_origin:
		up_direction = fo.call("get_local_up_at_origin")
	elif radial_distance > 1.0:
		up_direction = global_position / radial_distance
	else:
		up_direction = Vector3.UP

	# 2. Smoothly slerp basis orientation to match local tangent plane (zero gimbal lock at poles)
	var slerp_weight: float = clampf(BASIS_SLERP_SPEED * delta, 0.0, 1.0)
	_align_basis_to_planet_up(up_direction, slerp_weight)

	# 3. Apply moving ship deck displacement if aboard a vessel
	if (current_mode == MovementMode.ABOARD_SHIP_DECK or current_mode == MovementMode.HELM_PILOTING) and is_instance_valid(boarded_ship):
		_apply_ship_deck_motion(delta)

	# 4. Evaluate altitude relative to sea level for swimming / buoyancy
	var current_alt_m: float = 0.0
	if using_floating_origin:
		var lla: Dictionary = fo.call("local32_to_lat_lon_alt", global_position)
		current_alt_m = float(lla.get("alt_m", global_position.y))
	else:
		current_alt_m = radial_distance - PlanetSphere.SEA_LEVEL_RADIUS

	if current_alt_m < -1.2 and current_mode == MovementMode.ON_FOOT:
		set_movement_mode(MovementMode.SWIMMING)
	elif current_alt_m >= -0.4 and current_mode == MovementMode.SWIMMING:
		set_movement_mode(MovementMode.ON_FOOT)

	# 5. Compute velocity along local spherical tangent plane + radial axis
	match current_mode:
		MovementMode.HELM_PILOTING:
			_process_helm_piloting(delta)
		MovementMode.SWIMMING:
			_process_spherical_swimming(delta, current_alt_m)
		_:
			_process_spherical_ground_movement(delta)

	move_and_slide()

	# 6. Auto-rebase floating origin when player/ship moves > 1,000 m from local (0, 0, 0)
	if using_floating_origin:
		fo.call("rebase_if_needed", global_position, 1_000.0)

func _on_floating_origin_rebased(delta_local: Vector3) -> void:
	global_position += delta_local
	_ship_previous_global_pos += delta_local

## Rotates `global_transform.basis` via minimal-arc Quaternion from current Y-axis to `target_up`
## so the player can walk continuously across all 100,531 km and directly over North/South Poles
## without Euler gimbal lock.
func _align_basis_to_planet_up(target_up: Vector3, weight: float) -> void:
	var current_up: Vector3 = global_transform.basis.y.normalized()
	var dot_val: float = clampf(current_up.dot(target_up), -1.0, 1.0)
	if dot_val > 0.999999:
		return
	var rot_quat := Quaternion(current_up, target_up)
	var target_basis: Basis = (Basis(rot_quat) * global_transform.basis).orthonormalized()
	global_transform.basis = global_transform.basis.slerp(target_basis, weight).orthonormalized()

func _process_spherical_ground_movement(delta: float) -> void:
	# Decompose current velocity into radial (vertical) and tangent (horizontal) components
	var radial_speed: float = velocity.dot(up_direction)
	var tangent_velocity: Vector3 = velocity - (up_direction * radial_speed)

	# Apply spherical gravity (-up_direction * 9.81) when airborne
	if not is_on_floor():
		radial_speed = maxf(radial_speed - GRAVITY_ACCEL_MS2 * delta, -TERMINAL_FALL_SPEED_MS)
	else:
		if radial_speed < 0.0:
			radial_speed = -0.5 # Keep feet planted cleanly against curved sphere chunks
		if Input.is_action_just_pressed("jump"):
			radial_speed = JUMP_VELOCITY_MS

	# Read tangent plane WASD input relative to player's local Basis
	var input_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var forward_tangent: Vector3 = (-global_transform.basis.z)
	forward_tangent = (forward_tangent - up_direction * forward_tangent.dot(up_direction)).normalized()
	var right_tangent: Vector3 = global_transform.basis.x
	right_tangent = (right_tangent - up_direction * right_tangent.dot(up_direction)).normalized()

	var move_dir: Vector3 = (right_tangent * input_vec.x + forward_tangent * (-input_vec.y)).normalized()
	var target_speed: float = SPRINT_SPEED_MS if Input.is_action_pressed("sprint") else WALK_SPEED_MS

	# Skypiea Jet Dial forward burst hook
	if equipped_jet_dial and _jet_dial_cooldown_sec <= 0.0 and Input.is_action_just_pressed("coup_de_burst"):
		var burst_dir: Vector3 = move_dir if move_dir.length_squared() > 0.01 else forward_tangent
		tangent_velocity = burst_dir * JET_DIAL_BURST_MS
		_jet_dial_cooldown_sec = 4.0
	elif move_dir.length_squared() > 0.001:
		tangent_velocity = tangent_velocity.move_toward(move_dir * target_speed, 38.0 * delta)
	else:
		tangent_velocity = tangent_velocity.move_toward(Vector3.ZERO, 32.0 * delta)

	velocity = tangent_velocity + (up_direction * radial_speed)

func _process_spherical_swimming(delta: float, current_alt_m: float) -> void:
	var radial_speed: float = velocity.dot(up_direction)
	var tangent_velocity: Vector3 = velocity - (up_direction * radial_speed)

	if devil_fruit_user:
		# Canonical Devil Fruit sea-water weakness: sinks like a hammer unless rescued or coated
		radial_speed = maxf(radial_speed - (GRAVITY_ACCEL_MS2 * 0.65) * delta, -12.0)
		tangent_velocity = tangent_velocity.move_toward(Vector3.ZERO, 20.0 * delta)
	else:
		var buoyancy_target_speed: float = clampf((-0.8 - current_alt_m) * 3.5, -4.0, 5.0)
		if Input.is_action_pressed("jump"):
			buoyancy_target_speed = 4.5
		radial_speed = move_toward(radial_speed, buoyancy_target_speed, 12.0 * delta)

		var input_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		var forward_tangent: Vector3 = (-global_transform.basis.z)
		forward_tangent = (forward_tangent - up_direction * forward_tangent.dot(up_direction)).normalized()
		var right_tangent: Vector3 = global_transform.basis.x
		right_tangent = (right_tangent - up_direction * right_tangent.dot(up_direction)).normalized()
		var swim_dir: Vector3 = (right_tangent * input_vec.x + forward_tangent * (-input_vec.y)).normalized()
		tangent_velocity = tangent_velocity.move_toward(swim_dir * SWIM_SPEED_MS, 18.0 * delta)

	velocity = tangent_velocity + (up_direction * radial_speed)

# ==============================================================================
# 6. SHIP DECK WALKING, BOARDING & HELM PILOTING
# ==============================================================================
## Called when the player steps onto a ship's deck collider or interacts with a boarding gangplank.
func board_ship_deck(ship_node: Node3D) -> void:
	if ship_node == null:
		return
	boarded_ship = ship_node
	_ship_previous_global_pos = ship_node.global_position
	_ship_previous_basis = ship_node.global_transform.basis
	set_movement_mode(MovementMode.ABOARD_SHIP_DECK)
	ship_boarded.emit(ship_node)

## Called when leaving the ship for an island dock or diving overboard.
func disembark_ship() -> void:
	var prev_ship: Node3D = boarded_ship
	boarded_ship = null
	set_movement_mode(MovementMode.ON_FOOT)
	if prev_ship != null:
		ship_disembarked.emit(prev_ship)

func toggle_helm_piloting() -> void:
	if not is_instance_valid(boarded_ship):
		return
	if current_mode == MovementMode.HELM_PILOTING:
		set_movement_mode(MovementMode.ABOARD_SHIP_DECK)
	elif current_mode == MovementMode.ABOARD_SHIP_DECK:
		set_movement_mode(MovementMode.HELM_PILOTING)

func _apply_ship_deck_motion(_delta: float) -> void:
	var current_ship_pos: Vector3 = boarded_ship.global_position
	var current_ship_basis: Basis = boarded_ship.global_transform.basis

	# Compute relative deck position in the ship's previous frame and transform to new ship frame
	var rel_offset: Vector3 = global_position - _ship_previous_global_pos
	var local_deck_pos: Vector3 = _ship_previous_basis.inverse() * rel_offset
	var new_rel_offset: Vector3 = current_ship_basis * local_deck_pos
	global_position = current_ship_pos + new_rel_offset

	_ship_previous_global_pos = current_ship_pos
	_ship_previous_basis = current_ship_basis

func _process_helm_piloting(delta: float) -> void:
	velocity = Vector3.ZERO
	if not is_instance_valid(boarded_ship):
		set_movement_mode(MovementMode.ON_FOOT)
		return
	var input_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if boarded_ship.has_method("apply_helm_input"):
		boarded_ship.call("apply_helm_input", -input_vec.y, input_vec.x, delta)

func set_movement_mode(new_mode: MovementMode) -> void:
	if current_mode == new_mode:
		return
	var prev: MovementMode = current_mode
	current_mode = new_mode
	movement_mode_changed.emit(prev, new_mode)

# ==============================================================================
# 7. SURVEYING SEXTANT CARTOGRAPHY HOOK (UNVEILING THE 100,531 KM GLOBE)
# ==============================================================================
## Uses the geometric sphere horizon formula d = sqrt(2 * R * h + h^2) where R = 16,000,000.0m
## and h is the player's eye elevation above sea level (e.g., ship crow's nest +28m or island peak +800m).
## Automatically registers the surveyed sector in the `WorldRegistry` autoload.
func use_surveying_sextant() -> Dictionary:
	if not equipped_surveying_sextant:
		return {"success": false, "reason": "No Surveying Sextant equipped"}

	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	var coords: Dictionary = (
		fo.call("local32_to_lat_lon_alt", global_position)
		if (fo != null and global_position.length() < 1_000_000.0)
		else PlanetSphere.world_to_lat_lon_alt(global_position)
	)
	var eye_elevation_m: float = maxf(PLAYER_HEIGHT_OFFSET_FOR_SURVEY(), coords["alt_m"] + EYE_HEIGHT_OFFSET_M)
	var R: float = PlanetSphere.SEA_LEVEL_RADIUS
	var horizon_distance_m: float = sqrt(2.0 * R * eye_elevation_m + eye_elevation_m * eye_elevation_m)
	var horizon_radius_km: float = horizon_distance_m / 1_000.0

	var registry: Node = get_node_or_null("/root/WorldRegistry")
	var newly_revealed_sectors: int = 0
	var nearby_islands: Array = []
	if registry != null and registry.has_method("record_sextant_survey"):
		var survey_res: Dictionary = registry.call(
			"record_sextant_survey",
			coords["lat_deg"],
			coords["lon_deg"],
			eye_elevation_m,
			horizon_distance_m
		)
		newly_revealed_sectors = survey_res.get("newly_revealed_sectors", 0)
		nearby_islands = survey_res.get("detected_islands", [])

	sextant_survey_completed.emit(coords["lat_deg"], coords["lon_deg"], eye_elevation_m, horizon_radius_km)
	return {
		"success": true,
		"lat_deg": coords["lat_deg"],
		"lon_deg": coords["lon_deg"],
		"eye_elevation_m": eye_elevation_m,
		"horizon_radius_km": horizon_radius_km,
		"newly_revealed_sectors": newly_revealed_sectors,
		"detected_islands": nearby_islands
	}

func PLAYER_HEIGHT_OFFSET_FOR_SURVEY() -> float:
	return EYE_HEIGHT_OFFSET_M

# ==============================================================================
# 8. HAKI & PROGRESSION ABILITY HOOKS
# ==============================================================================
func toggle_haki_modes() -> void:
	observation_haki_active = not observation_haki_active
	armament_haki_active = observation_haki_active
	haki_state_changed.emit(observation_haki_active, armament_haki_active, conqueror_haki_unlocked)
