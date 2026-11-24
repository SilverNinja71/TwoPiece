class_name EastBlueInteractableDirector
extends Node3D
## East Blue 3D NPC Proximity Interactable Director & Starter Sea Patrols (Godot 4.3+, precision=double).
##
## Bridges EastBlueSettlementBuilder, EastBlueGameplay, FloatingOrigin, and ExplorationHUD:
##   1. Tracks SphericalPlayer distance to spawned 3D NPCs and opens branching dialogue +
##      shop drawers in ExplorationHUD on pressing `interact_helm` (E) within 8.0 m.
##   2. Spawns procedural 3D East Blue pirate sloops (Alvida / Buggy / Krieg) and the
##      Lord of the Coast sea monster near Foosha Cove with orbital patrol AI and bounty hooks.

signal npc_prompt_changed(npc_id: String, npc_name: String, in_range: bool)
signal encounter_engaged(encounter_id: String, title: String, bounty_beli: int)
signal encounter_defeated(encounter_id: String, title: String, reward_beli: int)

const INTERACT_RADIUS_M: float = 8.0
const ENCOUNTER_AGGRO_RADIUS_M: float = 180.0
const ENCOUNTER_COMBAT_RADIUS_M: float = 45.0

const NPC_NODE_TO_DATA_ID: Dictionary = {
	"NPC_Makino": {"npc_id": "makino", "island_id": "dawn_island", "name": "Makino"},
	"NPC_WoopSlap": {"npc_id": "woop_slap", "island_id": "dawn_island", "name": "Mayor Woop Slap"},
	"NPC_Gyoru": {"npc_id": "gyoru", "island_id": "dawn_island", "name": "Gyoru"},
	"NPC_ChefZeff": {"npc_id": "chef_zeff", "island_id": "baratie", "name": "Chef Zeff"},
	"NPC_Patty": {"npc_id": "patty", "island_id": "baratie", "name": "Patty"},
	"NPC_Carne": {"npc_id": "carne", "island_id": "baratie", "name": "Carne"},
	"NPC_Nojiko": {"npc_id": "nojiko", "island_id": "conomi_islands", "name": "Nojiko"},
	"NPC_Genzo": {"npc_id": "genzo", "island_id": "conomi_islands", "name": "Sheriff Genzo"},
	"NPC_Ipponmatsu": {"npc_id": "ipponmatsu", "island_id": "loguetown", "name": "Ipponmatsu"},
	"NPC_Raoul": {"npc_id": "raoul", "island_id": "loguetown", "name": "Raoul"}
}

@export var settlement_builder_path: NodePath = NodePath("")
@export var gameplay_path: NodePath = NodePath("")
@export var player_path: NodePath = NodePath("")
@export var hud_path: NodePath = NodePath("")
@export var interact_radius_m: float = INTERACT_RADIUS_M

var _settlement_builder: EastBlueSettlementBuilder = null
var _gameplay: EastBlueGameplay = null
var _player: Node3D = null
var _hud: ExplorationHUD = null

var _nearest_npc_id: String = ""
var _nearest_npc_island_id: String = ""
var _nearest_npc_name: String = ""
var _prompt_label_3d: Label3D = null
var _was_e_key_down: bool = false

var _encounters: Dictionary = {}
var _encounter_materials: Dictionary = {}


func _ready() -> void:
	_init_materials()
	_resolve_scene_dependencies()
	_setup_prompt_label()
	_spawn_starter_encounters()


func _process(delta: float) -> void:
	_resolve_scene_dependencies()
	_update_npc_proximity()
	_update_encounters(delta)

	if _is_interact_pressed() and not _nearest_npc_id.is_empty():
		interact_with_nearest_npc()


## Triggers dialogue & shop interaction with the currently closest NPC within 8.0 m.
func interact_with_nearest_npc() -> Dictionary:
	if _nearest_npc_id.is_empty() or _gameplay == null:
		return {"ok": false, "error": "No NPC in interaction range."}

	if not _nearest_npc_island_id.is_empty():
		_gameplay.dock_at_island(_nearest_npc_island_id)

	var res: Dictionary = _gameplay.start_dialogue(_nearest_npc_id)
	if not bool(res.get("ok", false)):
		return res

	_push_dialogue_node_to_hud(res.get("node", {}))
	return res


## Engages an active East Blue sea encounter (pirate sloop or Lord of the Coast).
func engage_encounter(encounter_id: String) -> Dictionary:
	if not _encounters.has(encounter_id):
		return {"ok": false, "error": "Unknown encounter: %s" % encounter_id}
	var enc: Dictionary = _encounters[encounter_id]
	if bool(enc.get("defeated", false)):
		return {"ok": false, "error": "Encounter already defeated."}
	enc["state"] = "engaged"
	_encounters[encounter_id] = enc
	encounter_engaged.emit(encounter_id, enc.get("title", ""), int(enc.get("bounty_beli", 0)))
	return {"ok": true, "encounter_id": encounter_id, "bounty_beli": int(enc.get("bounty_beli", 0))}


## Marks an East Blue sea encounter defeated, awarding Beli bounty & campaign milestone.
func defeat_encounter(encounter_id: String) -> Dictionary:
	if not _encounters.has(encounter_id):
		return {"ok": false, "error": "Unknown encounter: %s" % encounter_id}
	var enc: Dictionary = _encounters[encounter_id]
	if bool(enc.get("defeated", false)):
		return {"ok": true, "already_defeated": true}

	enc["defeated"] = true
	enc["state"] = "defeated"
	var node: Node3D = enc.get("node", null)
	if is_instance_valid(node):
		node.visible = false
	_encounters[encounter_id] = enc

	var reward: int = int(enc.get("reward_beli", 5_000))
	var registry: Node = get_node_or_null("/root/WorldRegistry")
	if registry != null and registry.has_method("add_currency"):
		registry.call("add_currency", "beli", reward)

	var campaign: Node = get_node_or_null("/root/StoryCampaignManager")
	var milestone_id: String = enc.get("milestone_id", "")
	if campaign != null and not milestone_id.is_empty() and campaign.has_method("complete_milestone"):
		campaign.call("complete_milestone", milestone_id)

	encounter_defeated.emit(encounter_id, enc.get("title", ""), reward)
	return {"ok": true, "encounter_id": encounter_id, "reward_beli": reward}


## Returns a snapshot of all spawned East Blue sea encounters.
func get_encounter_states() -> Dictionary:
	var out: Dictionary = {}
	for k: String in _encounters.keys():
		var e: Dictionary = _encounters[k]
		out[k] = {
			"title": e.get("title", ""),
			"bounty_beli": int(e.get("bounty_beli", 0)),
			"state": e.get("state", "patrol"),
			"defeated": bool(e.get("defeated", false))
		}
	return out


# ------------------------------------------------------------------------------
# Dependency Resolution & HUD Dialogue Bridge
# ------------------------------------------------------------------------------

func _resolve_scene_dependencies() -> void:
	if _gameplay == null:
		if not gameplay_path.is_empty():
			_gameplay = get_node_or_null(gameplay_path) as EastBlueGameplay
		if _gameplay == null:
			_gameplay = _find_node_by_script_class("EastBlueGameplay") as EastBlueGameplay
		if _gameplay == null:
			_gameplay = EastBlueGameplay.new()
			_gameplay.name = "EastBlueGameplay"
			add_child(_gameplay)

	if _settlement_builder == null:
		if not settlement_builder_path.is_empty():
			_settlement_builder = get_node_or_null(settlement_builder_path) as EastBlueSettlementBuilder
		if _settlement_builder == null:
			_settlement_builder = _find_node_by_script_class("EastBlueSettlementBuilder") as EastBlueSettlementBuilder

	if _player == null or not is_instance_valid(_player):
		if not player_path.is_empty():
			_player = get_node_or_null(player_path) as Node3D
		if _player == null:
			_player = _find_node_by_script_class("SphericalPlayer") as Node3D

	if _hud == null:
		if not hud_path.is_empty():
			_hud = get_node_or_null(hud_path) as ExplorationHUD
		if _hud == null:
			_hud = _find_node_by_script_class("ExplorationHUD") as ExplorationHUD
		if _hud != null and not _hud.dialogue_choice_selected.is_connected(_on_hud_dialogue_choice_selected):
			_hud.dialogue_choice_selected.connect(_on_hud_dialogue_choice_selected)


func _find_node_by_script_class(target_class: String) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return null
	var stack: Array[Node] = [tree.root]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		var scr: Variant = cur.get_script()
		if scr is Script and scr.get_global_name() == target_class:
			return cur
		for child: Node in cur.get_children():
			stack.append(child)
	return null


func _push_dialogue_node_to_hud(node_payload: Dictionary) -> void:
	if _hud == null or node_payload.is_empty():
		return
	var npc_id: String = str(node_payload.get("npc_id", ""))
	var speaker: String = str(node_payload.get("npc_name", npc_id))
	var role: String = str(node_payload.get("role", ""))
	if not role.is_empty():
		speaker = "%s — %s" % [speaker, role]
	var body_text: String = str(node_payload.get("text", "..."))
	var raw_choices: Array = node_payload.get("choices", [])
	var hud_choices: Array[Dictionary] = []
	for i: int in range(raw_choices.size()):
		var ch: Dictionary = raw_choices[i]
		hud_choices.append({
			"id": str(i),
			"label": str(ch.get("label", "Continue"))
		})
	_hud.open_dialogue_session(npc_id, speaker, body_text, hud_choices)


func _on_hud_dialogue_choice_selected(_npc_id: String, choice_id: String) -> void:
	if _gameplay == null or not choice_id.is_valid_int():
		return
	var choice_idx: int = int(choice_id)
	var result: Dictionary = _gameplay.advance_dialogue(choice_idx)
	if not bool(result.get("ok", false)):
		return

	var action_res: Dictionary = result.get("action_result", {})
	if action_res.has("shop") and _hud != null:
		_hud.toggle_shop_drawer()

	if bool(result.get("ended", false)):
		if _hud != null:
			_hud.close_dialogue_panel()
	else:
		_push_dialogue_node_to_hud(result.get("node", {}))


# ------------------------------------------------------------------------------
# 3D NPC Proximity Tracking
# ------------------------------------------------------------------------------

func _setup_prompt_label() -> void:
	_prompt_label_3d = Label3D.new()
	_prompt_label_3d.name = "InteractPromptLabel"
	_prompt_label_3d.visible = false
	_prompt_label_3d.font_size = 42
	_prompt_label_3d.pixel_size = 0.035
	_prompt_label_3d.modulate = Color(1.0, 0.92, 0.45)
	_prompt_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_prompt_label_3d)


func _update_npc_proximity() -> void:
	if _settlement_builder == null:
		return
	var viewer_local_pos: Vector3 = _get_viewer_local_pos()
	if viewer_local_pos == Vector3.ZERO and _player == null:
		return

	var best_npc_id: String = ""
	var best_island_id: String = ""
	var best_npc_name: String = ""
	var best_dist: float = interact_radius_m
	var best_world_pos: Vector3 = Vector3.ZERO

	for island_id: String in _settlement_builder.get_spawned_settlement_ids():
		var settlement_node: Node3D = _settlement_builder.get_node_or_null("Settlement_%s" % island_id) as Node3D
		if settlement_node == null:
			continue
		for child: Node in settlement_node.get_children():
			if child is Node3D and NPC_NODE_TO_DATA_ID.has(child.name):
				var npc_node: Node3D = child as Node3D
				var dist: float = viewer_local_pos.distance_to(npc_node.global_position)
				if dist <= best_dist:
					best_dist = dist
					var info: Dictionary = NPC_NODE_TO_DATA_ID[child.name]
					best_npc_id = info["npc_id"]
					best_island_id = info["island_id"]
					best_npc_name = info["name"]
					best_world_pos = npc_node.global_position

	if best_npc_id != _nearest_npc_id:
		_nearest_npc_id = best_npc_id
		_nearest_npc_island_id = best_island_id
		_nearest_npc_name = best_npc_name
		npc_prompt_changed.emit(_nearest_npc_id, _nearest_npc_name, not _nearest_npc_id.is_empty())

	if _prompt_label_3d != null:
		if _nearest_npc_id.is_empty():
			_prompt_label_3d.visible = false
		else:
			_prompt_label_3d.visible = true
			var up_vec: Vector3 = _get_local_up()
			_prompt_label_3d.global_position = best_world_pos + up_vec * 3.1
			_prompt_label_3d.text = "[E] Talk to %s" % _nearest_npc_name


func _is_interact_pressed() -> bool:
	if InputMap.has_action("interact_helm") and Input.is_action_just_pressed("interact_helm"):
		return true
	var e_down: bool = Input.is_key_pressed(KEY_E)
	var just_pressed: bool = e_down and not _was_e_key_down
	_was_e_key_down = e_down
	return just_pressed


func _get_viewer_local_pos() -> Vector3:
	if _player != null and is_instance_valid(_player):
		return _player.global_position
	var vp: Viewport = get_viewport()
	if vp != null:
		var cam: Camera3D = vp.get_camera_3d()
		if cam != null:
			return cam.global_position
	return Vector3.ZERO


func _get_local_up() -> Vector3:
	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	if fo != null and fo.has_method("get_local_up_at_origin"):
		return fo.call("get_local_up_at_origin")
	return Vector3.UP


# ------------------------------------------------------------------------------
# Starter Sea Encounters (Lord of the Coast & East Blue Pirate Sloops)
# ------------------------------------------------------------------------------

func _spawn_starter_encounters() -> void:
	_create_sea_monster_encounter(
		"lord_of_the_coast",
		"Lord of the Coast (Sea King)",
		52.0,
		74.0,
		420.0,
		0.14,
		0,
		25_000,
		"eb_dawn_departure"
	)
	_create_pirate_sloop_encounter(
		"alvida_sloop_patrol",
		"Alvida Pirates Sloop — Miss Love Duck Scout",
		47.0,
		78.5,
		650.0,
		0.10,
		5_000_000,
		15_000,
		"eb_alvida_patrol",
		Color(0.85, 0.25, 0.55)
	)
	_create_pirate_sloop_encounter(
		"buggy_sloop_patrol",
		"Buggy Pirates Big Top Sloop",
		45.0,
		58.0,
		780.0,
		0.09,
		15_000_000,
		30_000,
		"eb_orange_town",
		Color(0.88, 0.22, 0.20)
	)
	_create_pirate_sloop_encounter(
		"krieg_vanguard_sloop",
		"Krieg Armada Vanguard Sloop",
		28.0,
		45.0,
		700.0,
		0.11,
		17_000_000,
		50_000,
		"eb_baratie",
		Color(0.75, 0.62, 0.18)
	)


func _create_sea_monster_encounter(
	enc_id: String,
	title: String,
	lat_deg: float,
	lon_deg: float,
	orbit_radius_m: float,
	angular_speed: float,
	bounty_beli: int,
	reward_beli: int,
	milestone_id: String
) -> void:
	var root: Node3D = Node3D.new()
	root.name = "Encounter_" + enc_id
	add_child(root)

	# 30m serpentine Sea King mesh
	var body_segments: int = 5
	for i: int in range(body_segments):
		var seg: MeshInstance3D = MeshInstance3D.new()
		var sph: SphereMesh = SphereMesh.new()
		var r: float = 3.2 - float(i) * 0.42
		sph.radius = r
		sph.height = r * 2.2
		seg.mesh = sph
		seg.material_override = _encounter_materials["sea_king"]
		seg.position = Vector3(0.0, 1.5 + sin(float(i) * 1.1) * 1.8, -float(i) * 5.2)
		root.add_child(seg)

	var lbl: Label3D = Label3D.new()
	lbl.text = "%s\nReward: %d Beli" % [title, reward_beli]
	lbl.position = Vector3(0.0, 8.5, 0.0)
	lbl.font_size = 44
	lbl.pixel_size = 0.05
	lbl.modulate = Color(1.0, 0.45, 0.35)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(lbl)

	var center_world: Vector3 = EastBlueData.lat_lon_to_world_pos(lat_deg, lon_deg, 0.0)
	_encounters[enc_id] = {
		"id": enc_id,
		"title": title,
		"center_world": center_world,
		"orbit_radius_m": orbit_radius_m,
		"angle_rad": 0.0,
		"angular_speed": angular_speed,
		"bounty_beli": bounty_beli,
		"reward_beli": reward_beli,
		"milestone_id": milestone_id,
		"state": "patrol",
		"defeated": false,
		"node": root
	}


func _create_pirate_sloop_encounter(
	enc_id: String,
	title: String,
	lat_deg: float,
	lon_deg: float,
	orbit_radius_m: float,
	angular_speed: float,
	bounty_beli: int,
	reward_beli: int,
	milestone_id: String,
	sail_color: Color
) -> void:
	var root: Node3D = Node3D.new()
	root.name = "Encounter_" + enc_id
	add_child(root)

	# Hull
	var hull: MeshInstance3D = MeshInstance3D.new()
	var hull_box: BoxMesh = BoxMesh.new()
	hull_box.size = Vector3(6.5, 3.2, 18.0)
	hull.mesh = hull_box
	hull.material_override = _encounter_materials["wood"]
	hull.position = Vector3(0.0, 1.2, 0.0)
	root.add_child(hull)

	# Mast & Pirate Sail
	var mast: MeshInstance3D = MeshInstance3D.new()
	var mast_cyl: CylinderMesh = CylinderMesh.new()
	mast_cyl.top_radius = 0.25
	mast_cyl.bottom_radius = 0.35
	mast_cyl.height = 14.0
	mast.mesh = mast_cyl
	mast.material_override = _encounter_materials["wood_dark"]
	mast.position = Vector3(0.0, 8.5, 0.0)
	root.add_child(mast)

	var sail: MeshInstance3D = MeshInstance3D.new()
	var sail_box: BoxMesh = BoxMesh.new()
	sail_box.size = Vector3(9.0, 7.5, 0.25)
	sail.mesh = sail_box
	var sail_mat: StandardMaterial3D = StandardMaterial3D.new()
	sail_mat.albedo_color = sail_color
	sail.material_override = sail_mat
	sail.position = Vector3(0.0, 10.0, 0.5)
	root.add_child(sail)

	var lbl: Label3D = Label3D.new()
	lbl.text = "%s\nBounty: %d Beli" % [title, bounty_beli]
	lbl.position = Vector3(0.0, 17.5, 0.0)
	lbl.font_size = 44
	lbl.pixel_size = 0.05
	lbl.modulate = Color(1.0, 0.85, 0.35)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(lbl)

	var center_world: Vector3 = EastBlueData.lat_lon_to_world_pos(lat_deg, lon_deg, 0.0)
	_encounters[enc_id] = {
		"id": enc_id,
		"title": title,
		"center_world": center_world,
		"orbit_radius_m": orbit_radius_m,
		"angle_rad": float(_encounters.size()) * 1.4,
		"angular_speed": angular_speed,
		"bounty_beli": bounty_beli,
		"reward_beli": reward_beli,
		"milestone_id": milestone_id,
		"state": "patrol",
		"defeated": false,
		"node": root
	}


func _update_encounters(delta: float) -> void:
	var origin_offset: Vector3 = _get_floating_origin_offset()
	var viewer_local: Vector3 = _get_viewer_local_pos()

	for enc_id: String in _encounters.keys():
		var enc: Dictionary = _encounters[enc_id]
		if bool(enc.get("defeated", false)):
			continue
		var node: Node3D = enc.get("node", null)
		if not is_instance_valid(node):
			continue

		var center_world: Vector3 = enc["center_world"]
		var up: Vector3 = center_world.normalized()
		var ref_axis: Vector3 = Vector3.UP if absf(up.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		var east: Vector3 = ref_axis.cross(up).normalized()
		var north: Vector3 = up.cross(east).normalized()

		var angle: float = float(enc["angle_rad"]) + float(enc["angular_speed"]) * delta
		enc["angle_rad"] = fmod(angle, TAU)

		var radius: float = float(enc["orbit_radius_m"])
		var tangent_offset: Vector3 = (east * cos(angle) + north * sin(angle)) * radius
		var world_pos: Vector3 = (center_world + tangent_offset).normalized() * EastBlueData.PLANET_RADIUS_M
		node.global_position = world_pos - origin_offset

		var heading: Vector3 = (-east * sin(angle) + north * cos(angle)).normalized()
		node.global_basis = Basis(heading.cross(up).normalized(), up, -heading).orthonormalized()

		if viewer_local != Vector3.ZERO:
			var dist: float = viewer_local.distance_to(node.global_position)
			if dist <= ENCOUNTER_AGGRO_RADIUS_M and enc.get("state", "patrol") == "patrol":
				engage_encounter(enc_id)

		_encounters[enc_id] = enc


func _get_floating_origin_offset() -> Vector3:
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


func _init_materials() -> void:
	var sk := StandardMaterial3D.new()
	sk.albedo_color = Color(0.12, 0.52, 0.48)
	sk.roughness = 0.45
	_encounter_materials["sea_king"] = sk

	var wd := StandardMaterial3D.new()
	wd.albedo_color = Color(0.48, 0.30, 0.16)
	wd.roughness = 0.85
	_encounter_materials["wood"] = wd

	var wdd := StandardMaterial3D.new()
	wdd.albedo_color = Color(0.28, 0.17, 0.09)
	wdd.roughness = 0.88
	_encounter_materials["wood_dark"] = wdd
