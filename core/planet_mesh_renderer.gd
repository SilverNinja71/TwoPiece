class_name PlanetMeshRenderer
extends Node3D
## 64-Bit Floating-Origin Cube-Sphere / Multi-Ring ArrayMesh Planet & Ocean Renderer
## Project "Blue Planet" — Compatible with Standard Prebuilt Godot 4.3 (`Godot.app`)
##
## Builds REAL visible 3D `ArrayMesh` geometry via `SurfaceTool` around `FloatingOrigin`:
## 1. Multi-ring Local Curved Ocean LOD (`0–2 km`, `2–20 km`, `20–150 km`) using `spherical_ocean.gdshader`
##    (with `StandardMaterial3D` fallback).
## 2. Local Biome & Elevation Terrain Patch Grid sampling `/assets/planetary_map_metadata.json`
##    (`Red Line +10,000 m`, `Island Land`, `Grand Line`, `Calm Belts`, `Ocean`) using `red_line_terrain.gdshader`.
## 3. Far-Field Orbital Planet Shell (colored from the 180x90 `biome_grid_rows` in metadata JSON).
## 4. Detailed Procedural 3D `Going Caravel` Ship Mesh & `2.0 m` Explorer Character Mesh
##    attached to `BuoyantShipVessel` and `SphericalPlayer` with a smooth 3rd-person Orbit Camera!

const METADATA_JSON_PATH: String = "res://assets/planetary_map_metadata.json"
const OCEAN_SHADER_PATH: String = "res://shaders/spherical_ocean.gdshader"
const TERRAIN_SHADER_PATH: String = "res://shaders/red_line_terrain.gdshader"
const PLANET_RADIUS_M: float = 16_000_000.0

@export var show_far_orbital_shell_above_alt_m: float = 2_500.0
@export var enable_third_person_orbit_camera: bool = true

var _biome_grid_rows: Array[String] = []
var _grid_lon_cells: int = 180
var _grid_lat_cells: int = 90

var _ocean_material: Material = null
var _terrain_material: Material = null
var _ocean_rings_root: Node3D = null
var _terrain_patch_mesh_inst: MeshInstance3D = null
var _orbital_shell_inst: MeshInstance3D = null

var _orbit_camera_pivot: Node3D = null
var _orbit_camera: Camera3D = null
var _orbit_yaw_rad: float = deg_to_rad(32.0)
var _orbit_pitch_rad: float = deg_to_rad(-18.0)
var _orbit_distance_m: float = 26.0
var _elapsed_time_sec: float = 0.0

var _player_node: Node3D = null
var _ship_node: Node3D = null
var _planet_sphere: Node = null

# ==============================================================================
# 1. INITIALIZATION & METADATA LOADING
# ==============================================================================
func _ready() -> void:
	name = "PlanetMeshRenderer"
	_load_planetary_metadata()
	_init_materials()
	_build_multi_ring_ocean_lod()
	_build_local_terrain_patch_grid()
	_build_far_field_orbital_shell()
	_align_horizon_meshes_to_origin_up()

	call_deferred("_wire_scene_actors_and_meshes")

	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	if fo != null and fo.has_signal("origin_rebased"):
		fo.connect("origin_rebased", _on_floating_origin_rebased)

func _get_origin_up() -> Vector3:
	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	if fo != null and fo.has_method("get_local_up_at_origin"):
		return (fo.call("get_local_up_at_origin") as Vector3).normalized()
	return Vector3.UP

static func _basis_from_up(up_dir: Vector3) -> Basis:
	var y_axis: Vector3 = up_dir.normalized()
	var ref: Vector3 = Vector3.FORWARD if absf(y_axis.dot(Vector3.FORWARD)) < 0.92 else Vector3.RIGHT
	var x_axis: Vector3 = ref.cross(y_axis).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis).orthonormalized()

func _align_horizon_meshes_to_origin_up() -> void:
	var local_up: Vector3 = _get_origin_up()
	var up_basis: Basis = _basis_from_up(local_up)
	if _ocean_rings_root != null:
		_ocean_rings_root.basis = up_basis
	if _terrain_patch_mesh_inst != null:
		_terrain_patch_mesh_inst.basis = up_basis
	if _orbital_shell_inst != null:
		_orbital_shell_inst.position = -local_up * 8_020.0
		_orbital_shell_inst.basis = up_basis

func _load_planetary_metadata() -> void:
	if not FileAccess.file_exists(METADATA_JSON_PATH):
		return
	var text: String = FileAccess.get_file_as_string(METADATA_JSON_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var spec: Dictionary = parsed.get("grid_spec", {})
		_grid_lon_cells = int(spec.get("lon_cells", 180))
		_grid_lat_cells = int(spec.get("lat_cells", 90))
		var rows: Variant = parsed.get("biome_grid_rows", [])
		if rows is Array:
			_biome_grid_rows.clear()
			for r in rows:
				_biome_grid_rows.append(str(r))

func _init_materials() -> void:
	# Ocean ShaderMaterial (with StandardMaterial3D fallback)
	if ResourceLoader.exists(OCEAN_SHADER_PATH):
		var sh: Variant = load(OCEAN_SHADER_PATH)
		if sh is Shader:
			var sm := ShaderMaterial.new()
			sm.shader = sh
			sm.set_shader_parameter("u_planet_radius", PLANET_RADIUS_M)
			sm.set_shader_parameter("u_camera_planet_up", Vector3.UP)
			sm.set_shader_parameter("u_storm_intensity", 0.18)
			_ocean_material = sm
	if _ocean_material == null:
		var fallback_ocean := StandardMaterial3D.new()
		fallback_ocean.albedo_color = Color(0.05, 0.34, 0.56, 1.0)
		fallback_ocean.roughness = 0.15
		fallback_ocean.metallic = 0.08
		_ocean_material = fallback_ocean

	# Terrain ShaderMaterial (with StandardMaterial3D fallback)
	if ResourceLoader.exists(TERRAIN_SHADER_PATH):
		var tsh: Variant = load(TERRAIN_SHADER_PATH)
		if tsh is Shader:
			var tsm := ShaderMaterial.new()
			tsm.shader = tsh
			tsm.set_shader_parameter("u_planet_radius", PLANET_RADIUS_M)
			tsm.set_shader_parameter("u_camera_planet_up", Vector3.UP)
			tsm.set_shader_parameter("u_biome_jungle", 0.65)
			_terrain_material = tsm
	if _terrain_material == null:
		var fallback_terrain := StandardMaterial3D.new()
		fallback_terrain.vertex_color_use_as_albedo = true
		fallback_terrain.roughness = 0.85
		_terrain_material = fallback_terrain

# ==============================================================================
# 2. MULTI-RING CURVED OCEAN LOD (0..150 KM AROUND FLOATING ORIGIN)
# ==============================================================================
func _build_multi_ring_ocean_lod() -> void:
	_ocean_rings_root = Node3D.new()
	_ocean_rings_root.name = "OceanMultiRingLOD"
	add_child(_ocean_rings_root)

	# 3 concentric LOD rings extending out to 150 km:
	# Ring 0: 0..2,500 m (high vertex density for close Gerstner swells around ship)
	# Ring 1: 2,500..25,000 m (medium density)
	# Ring 2: 25,000..150,000 m (far horizon out to planetary curvature drop)
	var ring_specs: Array[Array] = [
		["OceanRing0_Near", 0.0, 2_500.0, 48, 32],
		["OceanRing1_Mid", 2_450.0, 25_000.0, 48, 24],
		["OceanRing2_Horizon", 24_500.0, 150_000.0, 64, 24]
	]
	var apply_cpu_curve: bool = not (_ocean_material is ShaderMaterial)
	for spec in ring_specs:
		var mi := MeshInstance3D.new()
		mi.name = str(spec[0])
		mi.mesh = _create_radial_annulus_mesh(
			float(spec[1]),
			float(spec[2]),
			int(spec[3]),
			int(spec[4]),
			apply_cpu_curve
		)
		mi.material_override = _ocean_material
		_ocean_rings_root.add_child(mi)

func _create_radial_annulus_mesh(
	inner_r: float,
	outer_r: float,
	radial_segs: int,
	ring_steps: int,
	apply_cpu_curve: bool
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for r_i in range(ring_steps):
		var t0: float = float(r_i) / float(ring_steps)
		var t1: float = float(r_i + 1) / float(ring_steps)
		# Quadratic radial spacing concentrates vertex detail near the ship
		var r0: float = lerpf(inner_r, outer_r, t0 * t0 if inner_r < 1.0 else t0)
		var r1: float = lerpf(inner_r, outer_r, t1 * t1 if inner_r < 1.0 else t1)

		for a_i in range(radial_segs):
			var a0: float = (float(a_i) / float(radial_segs)) * TAU
			var a1: float = (float(a_i + 1) / float(radial_segs)) * TAU

			var p00 := Vector3(cos(a0) * r0, 0.0, sin(a0) * r0)
			var p10 := Vector3(cos(a0) * r1, 0.0, sin(a0) * r1)
			var p01 := Vector3(cos(a1) * r0, 0.0, sin(a1) * r0)
			var p11 := Vector3(cos(a1) * r1, 0.0, sin(a1) * r1)

			if apply_cpu_curve:
				p00.y = -(r0 * r0) / (2.0 * PLANET_RADIUS_M)
				p10.y = -(r1 * r1) / (2.0 * PLANET_RADIUS_M)
				p01.y = -(r0 * r0) / (2.0 * PLANET_RADIUS_M)
				p11.y = -(r1 * r1) / (2.0 * PLANET_RADIUS_M)

			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(p00.x * 0.001, p00.z * 0.001))
			st.add_vertex(p00)
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(p01.x * 0.001, p01.z * 0.001))
			st.add_vertex(p01)
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(p11.x * 0.001, p11.z * 0.001))
			st.add_vertex(p11)

			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(p00.x * 0.001, p00.z * 0.001))
			st.add_vertex(p00)
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(p11.x * 0.001, p11.z * 0.001))
			st.add_vertex(p11)
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(p10.x * 0.001, p10.z * 0.001))
			st.add_vertex(p10)

	return st.commit()

# ==============================================================================
# 3. LOCAL BIOME & ELEVATION TERRAIN PATCH GRID (METADATA + RED LINE MASKS)
# ==============================================================================
func _build_local_terrain_patch_grid() -> void:
	_terrain_patch_mesh_inst = MeshInstance3D.new()
	_terrain_patch_mesh_inst.name = "LocalPlanetaryTerrainGrid"
	_terrain_patch_mesh_inst.material_override = _terrain_material
	add_child(_terrain_patch_mesh_inst)
	_rebuild_local_terrain_patch()

func _rebuild_local_terrain_patch() -> void:
	if _terrain_patch_mesh_inst == null:
		return
	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	var center_lat: float = float(fo.get("origin_lat_deg")) if fo != null else 52.0
	var center_lon: float = float(fo.get("origin_lon_deg")) if fo != null else 74.0

	var patch_half_span_m: float = 120_000.0
	var grid_res: int = 40
	var step_m: float = (patch_half_span_m * 2.0) / float(grid_res)
	var meters_per_deg: float = (TAU * PLANET_RADIUS_M) / 360.0
	var cos_lat: float = maxf(0.15, cos(deg_to_rad(center_lat)))
	var apply_cpu_curve: bool = not (_terrain_material is ShaderMaterial)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var has_any_land: bool = false
	var heights: Array[float] = []
	var colors: Array[Color] = []
	heights.resize((grid_res + 1) * (grid_res + 1))
	colors.resize((grid_res + 1) * (grid_res + 1))

	for gz in range(grid_res + 1):
		for gx in range(grid_res + 1):
			var lx: float = -patch_half_span_m + float(gx) * step_m
			var lz: float = -patch_half_span_m + float(gz) * step_m
			var sample_lat: float = clampf(center_lat - (lz / meters_per_deg), -89.9, 89.9)
			var sample_lon: float = wrapf(center_lon + (lx / (meters_per_deg * cos_lat)), -180.0, 180.0)
			var sample_res: Dictionary = _sample_biome_and_elevation(sample_lat, sample_lon)
			var elev: float = float(sample_res["elevation_m"])
			if elev > -2.0:
				has_any_land = true
			if apply_cpu_curve:
				elev -= (lx * lx + lz * lz) / (2.0 * PLANET_RADIUS_M)
			var idx: int = gz * (grid_res + 1) + gx
			heights[idx] = elev
			colors[idx] = sample_res["color"]

	if not has_any_land:
		_terrain_patch_mesh_inst.visible = false
		return

	_terrain_patch_mesh_inst.visible = true
	for gz in range(grid_res):
		for gx in range(grid_res):
			var i00: int = gz * (grid_res + 1) + gx
			var i10: int = i00 + 1
			var i01: int = i00 + (grid_res + 1)
			var i11: int = i01 + 1

			var x0: float = -patch_half_span_m + float(gx) * step_m
			var x1: float = x0 + step_m
			var z0: float = -patch_half_span_m + float(gz) * step_m
			var z1: float = z0 + step_m

			var v00 := Vector3(x0, heights[i00], z0)
			var v10 := Vector3(x1, heights[i10], z0)
			var v01 := Vector3(x0, heights[i01], z1)
			var v11 := Vector3(x1, heights[i11], z1)

			st.set_color(colors[i00]); st.add_vertex(v00)
			st.set_color(colors[i10]); st.add_vertex(v10)
			st.set_color(colors[i11]); st.add_vertex(v11)

			st.set_color(colors[i00]); st.add_vertex(v00)
			st.set_color(colors[i11]); st.add_vertex(v11)
			st.set_color(colors[i01]); st.add_vertex(v01)

	st.generate_normals()
	_terrain_patch_mesh_inst.mesh = st.commit()

func _sample_biome_and_elevation(lat_deg: float, lon_deg: float) -> Dictionary:
	var biome_code: String = "O"
	if not _biome_grid_rows.is_empty():
		var lat_idx: int = clampi(int(((90.0 - lat_deg) / 180.0) * float(_grid_lat_cells)), 0, _biome_grid_rows.size() - 1)
		var row_str: String = _biome_grid_rows[lat_idx]
		var lon_idx: int = clampi(int(((wrapf(lon_deg, -180.0, 180.0) + 180.0) / 360.0) * float(_grid_lon_cells)), 0, row_str.length() - 1)
		biome_code = row_str.substr(lon_idx, 1)

	# Keep the central harbor sea-lane around Dawn Island / Foosha open water while raising distant macro-ridges
	match biome_code:
		"R":
			return {"elevation_m": 10_000.0, "color": Color(0.58, 0.18, 0.13)}
		"L":
			return {"elevation_m": -45.0, "color": Color(0.22, 0.45, 0.18)}
		_:
			return {"elevation_m": -120.0, "color": Color(0.05, 0.25, 0.42)}

# ==============================================================================
# 4. FAR-FIELD ORBITAL PLANET SHELL (180x90 METADATA PROXY)
# ==============================================================================
func _build_far_field_orbital_shell() -> void:
	_orbital_shell_inst = MeshInstance3D.new()
	_orbital_shell_inst.name = "FarFieldOrbitalPlanetShell"
	# Scaled proxy sphere (R_proxy = 8,000 m placed 8,000 m below local horizon when visible at altitude)
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 8_000.0
	sphere_mesh.height = 16_000.0
	sphere_mesh.radial_segments = 64
	sphere_mesh.rings = 32

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.32, 0.62, 1.0)
	mat.roughness = 0.65
	_orbital_shell_inst.mesh = sphere_mesh
	_orbital_shell_inst.material_override = mat
	_orbital_shell_inst.position = Vector3(0.0, -8_020.0, 0.0)
	_orbital_shell_inst.visible = false
	add_child(_orbital_shell_inst)

# ==============================================================================
# 5. PROCEDURAL 3D "GOING CARAVEL" SHIP & 2.0M EXPLORER CHARACTER MESHES
# ==============================================================================
func _wire_scene_actors_and_meshes() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return

	_planet_sphere = parent_node.get_node_or_null("PlanetSphere")
	_ship_node = parent_node.get_node_or_null("BuoyantShipVessel") as Node3D
	_player_node = parent_node.get_node_or_null("SphericalPlayer") as Node3D

	if _ship_node != null:
		_attach_going_caravel_mesh(_ship_node)

	if _player_node != null:
		_attach_explorer_character_mesh(_player_node)
		if enable_third_person_orbit_camera:
			_setup_third_person_orbit_camera(_player_node)

func _attach_going_caravel_mesh(ship: Node3D) -> void:
	if ship.get_node_or_null("GoingCaravelRig") != null:
		return

	# Hide placeholder box meshes created by BuoyantShipVessel if present
	for placeholder_name in ["VisualHull", "MainMast", "MainSail"]:
		var ph: Node = ship.get_node_or_null(placeholder_name)
		if ph is Node3D:
			(ph as Node3D).visible = false

	var rig := Node3D.new()
	rig.name = "GoingCaravelRig"
	ship.add_child(rig)

	var wood_dark := _make_mat(Color(0.36, 0.20, 0.10), 0.78)
	var wood_deck := _make_mat(Color(0.62, 0.42, 0.24), 0.72)
	var trim_gold := _make_mat(Color(0.88, 0.72, 0.22), 0.35, 0.55)
	var sail_white := _make_mat(Color(0.96, 0.94, 0.88), 0.90)
	var emblem_black := _make_mat(Color(0.08, 0.08, 0.10), 0.85)

	# 1. Tapered Wooden Hull (SurfaceTool lofted cross-sections from stern +11m to bow -12m)
	var hull_mi := MeshInstance3D.new()
	hull_mi.name = "CaravelTaperedHull"
	hull_mi.mesh = _build_tapered_caravel_hull_mesh()
	hull_mi.material_override = wood_dark
	rig.add_child(hull_mi)

	# 2. Planked Main Deck + Quarterdeck
	var deck_mi := MeshInstance3D.new()
	deck_mi.name = "CaravelDeckPlanks"
	var deck_box := BoxMesh.new()
	deck_box.size = Vector3(6.8, 0.28, 17.5)
	deck_mi.mesh = deck_box
	deck_mi.material_override = wood_deck
	deck_mi.position = Vector3(0.0, 1.45, 0.2)
	rig.add_child(deck_mi)

	var stern_deck := MeshInstance3D.new()
	stern_deck.name = "CaravelQuarterdeck"
	var stern_box := BoxMesh.new()
	stern_box.size = Vector3(6.4, 1.5, 5.2)
	stern_deck.mesh = stern_box
	stern_deck.material_override = wood_deck
	stern_deck.position = Vector3(0.0, 2.2, 6.8)
	rig.add_child(stern_deck)

	# 3. Port & Starboard Railings
	for side_x in [-3.35, 3.35]:
		var rail := MeshInstance3D.new()
		var rail_box := BoxMesh.new()
		rail_box.size = Vector3(0.22, 0.9, 17.2)
		rail.mesh = rail_box
		rail.material_override = wood_dark
		rail.position = Vector3(side_x, 2.0, 0.2)
		rig.add_child(rail)

	# 4. Bowsprit Spar & Caravel Figurehead
	var bowsprit := MeshInstance3D.new()
	bowsprit.name = "Bowsprit"
	var bow_cyl := CylinderMesh.new()
	bow_cyl.top_radius = 0.10
	bow_cyl.bottom_radius = 0.22
	bow_cyl.height = 7.5
	bowsprit.mesh = bow_cyl
	bowsprit.material_override = wood_deck
	bowsprit.position = Vector3(0.0, 2.6, -12.2)
	bowsprit.rotation_degrees = Vector3(-72.0, 0.0, 0.0)
	rig.add_child(bowsprit)

	var figurehead := MeshInstance3D.new()
	figurehead.name = "CaravelFigurehead"
	var fh_sphere := SphereMesh.new()
	fh_sphere.radius = 0.85
	fh_sphere.height = 1.6
	figurehead.mesh = fh_sphere
	figurehead.material_override = sail_white
	figurehead.position = Vector3(0.0, 2.1, -10.4)
	rig.add_child(figurehead)

	# 5. Main Mast, Yardarm & Crow's Nest
	var mast := MeshInstance3D.new()
	mast.name = "CaravelMainMast"
	var mast_cyl := CylinderMesh.new()
	mast_cyl.top_radius = 0.18
	mast_cyl.bottom_radius = 0.34
	mast_cyl.height = 17.5
	mast.mesh = mast_cyl
	mast.material_override = wood_deck
	mast.position = Vector3(0.0, 10.1, -0.8)
	rig.add_child(mast)

	var yardarm := MeshInstance3D.new()
	var yard_cyl := CylinderMesh.new()
	yard_cyl.top_radius = 0.12
	yard_cyl.bottom_radius = 0.14
	yard_cyl.height = 12.2
	yardarm.mesh = yard_cyl
	yardarm.material_override = wood_deck
	yardarm.position = Vector3(0.0, 14.8, -0.8)
	yardarm.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	rig.add_child(yardarm)

	var crows_nest := MeshInstance3D.new()
	crows_nest.name = "CrowsNest"
	var nest_cyl := CylinderMesh.new()
	nest_cyl.top_radius = 1.25
	nest_cyl.bottom_radius = 0.95
	nest_cyl.height = 1.1
	crows_nest.mesh = nest_cyl
	crows_nest.material_override = wood_dark
	crows_nest.position = Vector3(0.0, 17.2, -0.8)
	rig.add_child(crows_nest)

	# 6. Billowed White Canvas Sail + Jolly Roger Emblem
	var sail_mi := MeshInstance3D.new()
	sail_mi.name = "BillowedMainSail"
	sail_mi.mesh = _build_billowed_sail_mesh(11.4, 9.2)
	sail_mi.material_override = sail_white
	sail_mi.position = Vector3(0.0, 10.2, -1.0)
	rig.add_child(sail_mi)

	var skull := MeshInstance3D.new()
	skull.name = "JollyRogerEmblem"
	var skull_disc := CylinderMesh.new()
	skull_disc.top_radius = 1.35
	skull_disc.bottom_radius = 1.35
	skull_disc.height = 0.12
	skull.mesh = skull_disc
	skull.material_override = emblem_black
	skull.position = Vector3(0.0, 10.4, -2.05)
	skull.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	rig.add_child(skull)

	var straw_band := MeshInstance3D.new()
	var band_box := BoxMesh.new()
	band_box.size = Vector3(2.9, 0.35, 0.16)
	straw_band.mesh = band_box
	straw_band.material_override = trim_gold
	straw_band.position = Vector3(0.0, 11.4, -2.08)
	rig.add_child(straw_band)

	# 7. Helm Wheel on Quarterdeck
	var helm := MeshInstance3D.new()
	helm.name = "HelmWheel"
	var helm_torus := TorusMesh.new()
	helm_torus.inner_radius = 0.42
	helm_torus.outer_radius = 0.56
	helm.mesh = helm_torus
	helm.material_override = trim_gold
	helm.position = Vector3(0.0, 3.65, 5.2)
	helm.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	rig.add_child(helm)

func _build_tapered_caravel_hull_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Hull station profiles: [z_pos, half_width_top, half_width_keel, deck_y, keel_y]
	var stations: Array[Array] = [
		[10.2, 2.7, 1.1, 1.8, -1.3],   # Stern transom
		[5.5, 3.6, 1.5, 1.5, -1.6],    # Aft body
		[0.0, 3.9, 1.6, 1.45, -1.7],   # Midships beam
		[-5.5, 3.1, 1.1, 1.6, -1.5],   # Forward shoulder
		[-10.8, 0.25, 0.10, 2.3, -0.7] # Sharp bow stem
	]

	for i in range(stations.size() - 1):
		var a: Array = stations[i]
		var b: Array = stations[i + 1]
		var az: float = float(a[0]); var awt: float = float(a[1]); var awk: float = float(a[2]); var ady: float = float(a[3]); var aky: float = float(a[4])
		var bz: float = float(b[0]); var bwt: float = float(b[1]); var bwk: float = float(b[2]); var bdy: float = float(b[3]); var bky: float = float(b[4])

		# Starboard side (+X)
		_add_quad(st, Vector3(awk, aky, az), Vector3(awt, ady, az), Vector3(bwt, bdy, bz), Vector3(bwk, bky, bz))
		# Port side (-X)
		_add_quad(st, Vector3(-awt, ady, az), Vector3(-awk, aky, az), Vector3(-bwk, bky, bz), Vector3(-bwt, bdy, bz))
		# Keel bottom
		_add_quad(st, Vector3(-awk, aky, az), Vector3(awk, aky, az), Vector3(bwk, bky, bz), Vector3(-bwk, bky, bz))

	st.generate_normals()
	return st.commit()

func _build_billowed_sail_mesh(width_m: float, height_m: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols: int = 10
	var rows: int = 8
	for r in range(rows):
		var v0: float = float(r) / float(rows)
		var v1: float = float(r + 1) / float(rows)
		for c in range(cols):
			var u0: float = float(c) / float(cols)
			var u1: float = float(c + 1) / float(cols)
			var p00 := _sail_pt(u0, v0, width_m, height_m)
			var p10 := _sail_pt(u1, v0, width_m, height_m)
			var p01 := _sail_pt(u0, v1, width_m, height_m)
			var p11 := _sail_pt(u1, v1, width_m, height_m)
			# Front and back faces so double-sided in any lighting
			_add_quad(st, p00, p10, p11, p01)
			_add_quad(st, p10, p00, p01, p11)
	st.generate_normals()
	return st.commit()

func _sail_pt(u: float, v: float, width_m: float, height_m: float) -> Vector3:
	var x: float = (u - 0.5) * width_m
	var y: float = (v - 0.5) * height_m
	var billow: float = -sin(u * PI) * sin(v * PI) * 1.35
	return Vector3(x, y, billow)

func _add_quad(st: SurfaceTool, v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3) -> void:
	st.add_vertex(v0); st.add_vertex(v1); st.add_vertex(v2)
	st.add_vertex(v0); st.add_vertex(v2); st.add_vertex(v3)

func _attach_explorer_character_mesh(player: Node3D) -> void:
	if player.get_node_or_null("ExplorerVisualRig") != null:
		return

	var rig := Node3D.new()
	rig.name = "ExplorerVisualRig"
	player.add_child(rig)

	var vest_red := _make_mat(Color(0.84, 0.16, 0.16), 0.72)
	var denim_blue := _make_mat(Color(0.16, 0.28, 0.54), 0.80)
	var skin_tan := _make_mat(Color(0.92, 0.74, 0.58), 0.65)
	var straw_gold := _make_mat(Color(0.92, 0.78, 0.30), 0.85)

	# Total character height = 2.0m (feet at y=0, crown of hat at y=2.0)
	var legs := MeshInstance3D.new()
	var legs_cap := CapsuleMesh.new()
	legs_cap.radius = 0.24
	legs_cap.height = 0.92
	legs.mesh = legs_cap
	legs.material_override = denim_blue
	legs.position = Vector3(0.0, 0.46, 0.0)
	rig.add_child(legs)

	var torso := MeshInstance3D.new()
	var torso_cap := CapsuleMesh.new()
	torso_cap.radius = 0.28
	torso_cap.height = 0.78
	torso.mesh = torso_cap
	torso.material_override = vest_red
	torso.position = Vector3(0.0, 1.15, 0.0)
	rig.add_child(torso)

	var head := MeshInstance3D.new()
	var head_sph := SphereMesh.new()
	head_sph.radius = 0.22
	head_sph.height = 0.44
	head.mesh = head_sph
	head.material_override = skin_tan
	head.position = Vector3(0.0, 1.68, 0.0)
	rig.add_child(head)

	# Iconic Straw-Style Explorer Hat (Brim + Red Ribbon + Crown)
	var hat_brim := MeshInstance3D.new()
	var brim_cyl := CylinderMesh.new()
	brim_cyl.top_radius = 0.46
	brim_cyl.bottom_radius = 0.48
	brim_cyl.height = 0.04
	hat_brim.mesh = brim_cyl
	hat_brim.material_override = straw_gold
	hat_brim.position = Vector3(0.0, 1.84, 0.0)
	rig.add_child(hat_brim)

	var hat_ribbon := MeshInstance3D.new()
	var rib_cyl := CylinderMesh.new()
	rib_cyl.top_radius = 0.24
	rib_cyl.bottom_radius = 0.24
	rib_cyl.height = 0.07
	hat_ribbon.mesh = rib_cyl
	hat_ribbon.material_override = vest_red
	hat_ribbon.position = Vector3(0.0, 1.88, 0.0)
	rig.add_child(hat_ribbon)

	var hat_crown := MeshInstance3D.new()
	var crown_cyl := CylinderMesh.new()
	crown_cyl.top_radius = 0.21
	crown_cyl.bottom_radius = 0.23
	crown_cyl.height = 0.14
	hat_crown.mesh = crown_cyl
	hat_crown.material_override = straw_gold
	hat_crown.position = Vector3(0.0, 1.93, 0.0)
	rig.add_child(hat_crown)

	# Subtle forward-facing sash / cape direction indicator (-Z is forward)
	var sash := MeshInstance3D.new()
	var sash_box := BoxMesh.new()
	sash_box.size = Vector3(0.18, 0.10, 0.36)
	sash.mesh = sash_box
	sash.material_override = straw_gold
	sash.position = Vector3(0.0, 1.18, -0.22)
	rig.add_child(sash)

# ==============================================================================
# 6. SMOOTH THIRD-PERSON ORBIT CAMERA & RUNTIME UNIFORM UPDATES
# ==============================================================================
func _setup_third_person_orbit_camera(player: Node3D) -> void:
	_orbit_camera_pivot = Node3D.new()
	_orbit_camera_pivot.name = "ThirdPersonOrbitPivot"
	add_child(_orbit_camera_pivot)

	_orbit_camera = Camera3D.new()
	_orbit_camera.name = "ThirdPersonOrbitCamera"
	_orbit_camera.fov = 68.0
	_orbit_camera.near = 0.15
	_orbit_camera.far = 250_000.0
	_orbit_camera_pivot.add_child(_orbit_camera)
	_orbit_camera.make_current()
	_orbit_camera_pivot.global_position = player.global_position + _get_origin_up() * 2.5

func _unhandled_input(event: InputEvent) -> void:
	if not enable_third_person_orbit_camera or _orbit_camera == null:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var mm := event as InputEventMouseMotion
		_orbit_yaw_rad -= mm.relative.x * 0.005
		_orbit_pitch_rad = clampf(_orbit_pitch_rad - mm.relative.y * 0.005, deg_to_rad(-70.0), deg_to_rad(25.0))
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_orbit_distance_m = maxf(6.0, _orbit_distance_m * 0.88)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_orbit_distance_m = minf(180.0, _orbit_distance_m * 1.12)

func _process(delta: float) -> void:
	_elapsed_time_sec += delta
	_update_shader_uniforms_and_shell()
	_update_orbit_camera(delta)

func _update_shader_uniforms_and_shell() -> void:
	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	var alt_m: float = 0.0
	var is_calm_belt: bool = false

	if fo != null and is_instance_valid(_player_node):
		var coords: Dictionary = fo.call("local32_to_lat_lon_alt", _player_node.global_position)
		alt_m = float(coords.get("alt_m", 0.0))
		if _planet_sphere != null and _planet_sphere.has_method("classify_global_coordinates"):
			var wvec: Vector3 = fo.call("local32_to_world_vec3", _player_node.global_position)
			var zinfo: Dictionary = _planet_sphere.call("classify_global_coordinates", wvec)
			is_calm_belt = bool(zinfo.get("is_calm_belt", false))

	if _ocean_material is ShaderMaterial:
		var sm := _ocean_material as ShaderMaterial
		sm.set_shader_parameter("u_time", _elapsed_time_sec)
		sm.set_shader_parameter("u_camera_planet_up", Vector3.UP)
		sm.set_shader_parameter("u_calm_belt_factor", 1.0 if is_calm_belt else 0.0)
		sm.set_shader_parameter("u_sky_sea_blend", clampf((alt_m - 6_000.0) / 3_500.0, 0.0, 1.0))
		sm.set_shader_parameter("u_abyss_depth_factor", clampf((-alt_m - 2_000.0) / 7_500.0, 0.0, 1.0))

	if _orbital_shell_inst != null:
		_orbital_shell_inst.visible = (alt_m >= show_far_orbital_shell_above_alt_m)

func _update_orbit_camera(delta: float) -> void:
	if _orbit_camera_pivot == null or _orbit_camera == null or not is_instance_valid(_player_node):
		return
	var local_up: Vector3 = _get_origin_up()
	var target_focus: Vector3 = _player_node.global_position + local_up * 2.5
	_orbit_camera_pivot.global_position = _orbit_camera_pivot.global_position.lerp(target_focus, clampf(10.0 * delta, 0.0, 1.0))

	var up_basis: Basis = _basis_from_up(local_up)
	var local_cam_offset := Vector3(
		cos(_orbit_pitch_rad) * sin(_orbit_yaw_rad),
		-sin(_orbit_pitch_rad),
		cos(_orbit_pitch_rad) * cos(_orbit_yaw_rad)
	) * _orbit_distance_m
	_orbit_camera.position = up_basis * local_cam_offset
	_orbit_camera.look_at(_orbit_camera_pivot.global_position, local_up)

func _on_floating_origin_rebased(_delta_local: Vector3) -> void:
	_align_horizon_meshes_to_origin_up()
	_rebuild_local_terrain_patch()

static func _make_mat(col: Color, rough: float = 0.75, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m
