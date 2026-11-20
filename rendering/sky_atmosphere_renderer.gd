class_name SkyAtmosphereRenderer
extends Node3D
## Planetary Atmosphere Dome, Sky Sea Cloud-Deck Rings (+7,000m / +10,000m),
## and Dynamic Strata Lighting/Fog Controller.
## Project "Blue Planet" — Godot 4.3+ Floating-Origin Compatible.

const PLANET_RADIUS_M: float = 16_000_000.0
const WHITE_SEA_ALT_M: float = 7_000.0
const WHITE_WHITE_SEA_ALT_M: float = 10_000.0

@export var dome_radius_m: float = 140_000.0
@export var cloud_ring_outer_radius_m: float = 42_000.0
@export var cloud_ring_inner_radius_m: float = 9_500.0
@export var sun_direction: Vector3 = Vector3(0.42, 0.68, -0.60)
@export var grand_line_simulator_path: NodePath
@export var directional_light_path: NodePath
@export var world_environment_path: NodePath

var _sky_dome: MeshInstance3D = null
var _sky_material: ShaderMaterial = null
var _white_sea_ring: MeshInstance3D = null
var _white_white_sea_ring: MeshInstance3D = null
var _simulator_ref: Node = null
var _dir_light_ref: DirectionalLight3D = null
var _world_env_ref: WorldEnvironment = null
var _cloud_spin_rad: float = 0.0


func _ready() -> void:
	name = "SkyAtmosphereRenderer"
	_resolve_scene_refs()
	_build_atmosphere_dome()
	_build_sky_sea_cloud_decks()
	_update_atmosphere_and_strata(0.0)


func _process(delta: float) -> void:
	_update_atmosphere_and_strata(delta)


func _resolve_scene_refs() -> void:
	if not grand_line_simulator_path.is_empty():
		_simulator_ref = get_node_or_null(grand_line_simulator_path)
	if _simulator_ref == null and get_parent() != null:
		_simulator_ref = get_parent().get_node_or_null("GrandLineSimulator")

	if not directional_light_path.is_empty():
		_dir_light_ref = get_node_or_null(directional_light_path) as DirectionalLight3D
	if _dir_light_ref == null and get_parent() != null:
		_dir_light_ref = get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D

	if not world_environment_path.is_empty():
		_world_env_ref = get_node_or_null(world_environment_path) as WorldEnvironment
	if _world_env_ref == null and get_parent() != null:
		_world_env_ref = get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment


func _build_atmosphere_dome() -> void:
	_sky_dome = MeshInstance3D.new()
	_sky_dome.name = "PlanetaryAtmosphereDome"
	var sphere := SphereMesh.new()
	sphere.radius = dome_radius_m
	sphere.height = dome_radius_m * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	_sky_dome.mesh = sphere
	_sky_dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var shader_path: String = "res://shaders/planetary_atmosphere.gdshader"
	if ResourceLoader.exists(shader_path):
		var sh: Shader = load(shader_path) as Shader
		if sh != null:
			_sky_material = ShaderMaterial.new()
			_sky_material.shader = sh
			_sky_dome.material_override = _sky_material

	if _sky_dome.material_override == null:
		var fb := StandardMaterial3D.new()
		fb.albedo_color = Color(0.32, 0.65, 0.95)
		fb.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fb.cull_mode = BaseMaterial3D.CULL_FRONT
		_sky_dome.material_override = fb

	add_child(_sky_dome)


func _build_sky_sea_cloud_decks() -> void:
	_white_sea_ring = _create_cloud_deck_ring("WhiteSeaCloudDeck_7km", Color(0.92, 0.95, 1.0, 0.72), 18)
	_white_white_sea_ring = _create_cloud_deck_ring("WhiteWhiteSeaCloudDeck_10km", Color(0.98, 0.99, 1.0, 0.85), 24)
	add_child(_white_sea_ring)
	add_child(_white_white_sea_ring)


func _create_cloud_deck_ring(node_name: String, tint: Color, puff_count: int) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Build a billowing ring of Pyrobloin cloud domes around the horizon
	for i in range(puff_count):
		var ang: float = (float(i) / float(puff_count)) * TAU
		var next_ang: float = (float(i + 1) / float(puff_count)) * TAU
		var r_in: float = cloud_ring_inner_radius_m + sin(ang * 3.0) * 1_600.0
		var r_out: float = cloud_ring_outer_radius_m + cos(ang * 2.0) * 3_200.0
		var h_crest: float = 420.0 + sin(ang * 5.0) * 180.0

		var p0 := Vector3(cos(ang) * r_in, 0.0, sin(ang) * r_in)
		var p1 := Vector3(cos(ang) * r_out, h_crest, sin(ang) * r_out)
		var p2 := Vector3(cos(next_ang) * r_out, h_crest, sin(next_ang) * r_out)
		var p3 := Vector3(cos(next_ang) * r_in, 0.0, sin(next_ang) * r_in)

		_add_cloud_tri(st, p0, p1, p2, tint)
		_add_cloud_tri(st, p0, p2, p3, tint)
		# Double-sided downward cloud belly
		_add_cloud_tri(st, p2, p1, p0, tint * Color(0.84, 0.88, 0.96, 1.0))
		_add_cloud_tri(st, p3, p2, p0, tint * Color(0.84, 0.88, 0.96, 1.0))

	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.95
	mat.emission_enabled = true
	mat.emission = Color(0.88, 0.93, 1.0)
	mat.emission_energy_multiplier = 0.16
	mi.material_override = mat
	return mi


static func _add_cloud_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	st.set_color(col)
	st.add_vertex(a)
	st.set_color(col)
	st.add_vertex(b)
	st.set_color(col)
	st.add_vertex(c)


# ==============================================================================
# 2. RUNTIME ATMOSPHERE, CLOUD STRATA & WEATHER SYNC
# ==============================================================================
func _update_atmosphere_and_strata(delta: float) -> void:
	var orig: Dictionary = _get_origin_state()
	var local_up: Vector3 = orig["local_up"]
	var alt_m: float = float(orig["alt_m"])

	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() != null else null
	if _sky_dome != null:
		_sky_dome.global_position = cam.global_position if cam != null else Vector3.ZERO

	# Align cloud decks with local planetary up at exact +7,000m and +10,000m strata
	_cloud_spin_rad += delta * 0.004
	var up_basis: Basis = _basis_from_up(local_up)
	if _white_sea_ring != null:
		_white_sea_ring.position = local_up * (WHITE_SEA_ALT_M - alt_m)
		_white_sea_ring.basis = up_basis.rotated(local_up, _cloud_spin_rad)
	if _white_white_sea_ring != null:
		_white_white_sea_ring.position = local_up * (WHITE_WHITE_SEA_ALT_M - alt_m)
		_white_white_sea_ring.basis = up_basis.rotated(local_up, -_cloud_spin_rad * 0.75)

	# Query GrandLineSimulator weather at origin
	var storm_intensity: float = 0.0
	if _simulator_ref != null and _simulator_ref.has_method("evaluate_weather_at_world_pos"):
		var w_pos: Vector3 = _lat_lon_alt_to_world32_proxy(orig["lat_deg"], orig["lon_deg"], alt_m)
		var eval: Dictionary = _simulator_ref.call("evaluate_weather_at_world_pos", w_pos)
		storm_intensity = float(eval.get("storm_intensity", 0.0))

	var abyss_depth: float = clampf((-alt_m - 200.0) / 9_800.0, 0.0, 1.0)

	if _sky_material != null:
		_sky_material.set_shader_parameter("u_sun_direction", sun_direction.normalized())
		_sky_material.set_shader_parameter("u_planet_up", local_up)
		_sky_material.set_shader_parameter("u_altitude_m", alt_m)
		_sky_material.set_shader_parameter("u_storm_intensity", storm_intensity)
		_sky_material.set_shader_parameter("u_abyss_depth", abyss_depth)

	_sync_lighting_and_fog(alt_m, storm_intensity, abyss_depth)


func _sync_lighting_and_fog(alt_m: float, storm_intensity: float, abyss_depth: float) -> void:
	if _dir_light_ref != null:
		var blue_sea_col := Color(1.0, 0.96, 0.88)
		var storm_col := Color(0.62, 0.68, 0.78)
		var sky_sea_col := Color(1.0, 0.99, 0.95)
		var abyss_col := Color(0.28, 0.76, 0.82)

		var sky_blend: float = clampf((alt_m - 5_500.0) / 3_500.0, 0.0, 1.0)
		var target_col: Color = blue_sea_col.lerp(storm_col, storm_intensity * 0.75)
		target_col = target_col.lerp(sky_sea_col, sky_blend)
		target_col = target_col.lerp(abyss_col, abyss_depth)
		_dir_light_ref.light_color = target_col
		_dir_light_ref.light_energy = lerpf(1.35, 0.55, abyss_depth) * (1.0 - storm_intensity * 0.35)

	if _world_env_ref != null and _world_env_ref.environment != null:
		var env: Environment = _world_env_ref.environment
		env.fog_enabled = true
		var sea_fog := Color(0.66, 0.82, 0.94)
		var storm_fog := Color(0.26, 0.32, 0.38)
		var sky_fog := Color(0.88, 0.94, 1.0)
		var abyss_fog := Color(0.05, 0.28, 0.38)

		var sky_blend: float = clampf((alt_m - 5_500.0) / 3_500.0, 0.0, 1.0)
		var fog_col: Color = sea_fog.lerp(storm_fog, storm_intensity * 0.8)
		fog_col = fog_col.lerp(sky_fog, sky_blend)
		fog_col = fog_col.lerp(abyss_fog, abyss_depth)
		env.fog_light_color = fog_col
		env.fog_density = lerpf(0.000018, 0.00014, maxf(storm_intensity, abyss_depth))


func _get_origin_state() -> Dictionary:
	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	var lat: float = 52.0
	var lon: float = 74.0
	var alt: float = 0.0
	var local_up := Vector3.UP

	if fo != null:
		var f_lat: Variant = fo.get("origin_lat_deg")
		var f_lon: Variant = fo.get("origin_lon_deg")
		var f_alt: Variant = fo.get("origin_alt_m")
		if f_lat != null: lat = float(f_lat)
		if f_lon != null: lon = float(f_lon)
		if f_alt != null: alt = float(f_alt)
		if fo.has_method("get_local_up_at_origin"):
			local_up = fo.call("get_local_up_at_origin")
			return {"lat_deg": lat, "lon_deg": lon, "alt_m": alt, "local_up": local_up.normalized()}

	var lat_r: float = deg_to_rad(lat)
	var lon_r: float = deg_to_rad(lon)
	local_up = Vector3(cos(lat_r) * cos(lon_r), sin(lat_r), cos(lat_r) * sin(lon_r)).normalized()
	return {"lat_deg": lat, "lon_deg": lon, "alt_m": alt, "local_up": local_up}


static func _lat_lon_alt_to_world32_proxy(lat_deg: float, lon_deg: float, alt_m: float) -> Vector3:
	var lat_r: float = deg_to_rad(clampf(lat_deg, -90.0, 90.0))
	var lon_r: float = deg_to_rad(lon_deg)
	var r: float = PLANET_RADIUS_M + alt_m
	return Vector3(r * cos(lat_r) * cos(lon_r), r * sin(lat_r), r * cos(lat_r) * sin(lon_r))


static func _basis_from_up(up_dir: Vector3) -> Basis:
	var y_axis: Vector3 = up_dir.normalized()
	var ref: Vector3 = Vector3.FORWARD if absf(y_axis.dot(Vector3.FORWARD)) < 0.92 else Vector3.RIGHT
	var x_axis: Vector3 = ref.cross(y_axis).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis).orthonormalized()
