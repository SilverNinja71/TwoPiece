class_name ReverseMountainEncounterDirector
extends Node3D
## Runtime Encounter & Interactive Portal Director for Reverse Mountain & Twin Cape.
##
## Bridges ReverseMountainController, ReverseMountainMeshBuilder, TwinCapeDialogueAndQuests,
## FloatingOrigin, BuoyantShipVessel, ExplorationHUD, and ProceduralAudioManager:
##   1. Live Canal Proximity, Hydraulic Impulse & Rudder Assist Banners + Rapids Audio
##   2. Laboon Swallow (52 m maw) & Inside-Laboon Stomach Portal (Mr. 9 / Vivi & Steel Exit Doors)
##   3. Twin Cape Lighthouse (140 m) Docking Trigger -> Crocus Dialogue, Clinic Shop & Log Pose Tutorial

signal canal_approach_prompt(canal_id: StringName, distance_m: float)
signal inside_laboon_entered(ship: Node3D)
signal inside_laboon_exited(ship: Node3D)
signal crocus_dock_interaction_opened()

const APPROACH_SCAN_RADIUS_M: float = 220_000.0
const GATE_PROXIMITY_ALERT_M: float = 16_000.0
const LABOON_MAW_TRIGGER_M: float = 52.0
const TWIN_CAPE_DOCK_RADIUS_M: float = 140.0

@export var ship_beam_m: float = 12.0
@export var enable_onscreen_banner: bool = true

var _rm_controller: ReverseMountainController = null
var _rm_mesh_builder: ReverseMountainMeshBuilder = null
var _dialogue_quests: TwinCapeDialogueAndQuests = null
var _ship: Node3D = null
var _player: Node3D = null
var _hud: Node = null
var _audio_mgr: Node = null

var _banner_layer: CanvasLayer = null
var _banner_panel: PanelContainer = null
var _banner_label: Label = null
var _banner_hide_timer: float = 0.0

var rudder_integrity: float = 1.0
var has_acid_resistant_paint: bool = false
var is_inside_laboon: bool = false
var _dock_notified_this_visit: bool = false
var _last_active_canal: StringName = &""
var _last_gate_alert: StringName = &""
var _active_twin_cape_npc: String = ""

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_resolve_scene_dependencies()
	_connect_signals()
	if enable_onscreen_banner:
		_build_guidance_banner()


func _physics_process(delta: float) -> void:
	if _banner_hide_timer > 0.0:
		_banner_hide_timer -= delta
		if _banner_hide_timer <= 0.0 and _banner_panel != null:
			_banner_panel.visible = false

	if _rm_controller == null or _ship == null:
		_resolve_scene_dependencies()
		if _rm_controller == null or _ship == null:
			return

	var ship_world_pos: Vector3 = _to_planetary_vec3(_ship.global_position)
	var node_a_pos: Vector3 = ReverseMountainController.spherical_to_world(0.0, 0.0, 0.0)
	if ship_world_pos.distance_to(node_a_pos) > APPROACH_SCAN_RADIUS_M:
		_set_rapids_audio(0.0)
		return

	if is_inside_laboon:
		_process_inside_laboon_state(delta)
		return

	_process_canal_approach_and_hydraulics(ship_world_pos, delta)
	_process_laboon_maw_and_bay(ship_world_pos)
	_process_twin_cape_dock_trigger(ship_world_pos)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact_helm"):
		return
	if _rm_controller == null or _ship == null:
		return

	if is_inside_laboon:
		_exit_laboon_through_steel_doors()
		return

	var ship_world_pos: Vector3 = _to_planetary_vec3(_ship.global_position)
	var dock_info: Dictionary = _rm_controller.check_lighthouse_docking(_ship, ship_world_pos)
	if bool(dock_info.get("in_dock_zone", false)):
		open_crocus_encounter("crocus")


# ---------------------------------------------------------------------------
# Scene Dependency Wiring
# ---------------------------------------------------------------------------
func _resolve_scene_dependencies() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return

	_rm_controller = _find_node_by_type_or_name(parent_node, "ReverseMountainController") as ReverseMountainController
	_rm_mesh_builder = _find_node_by_type_or_name(parent_node, "ReverseMountainMeshBuilder") as ReverseMountainMeshBuilder
	_ship = _find_node_by_type_or_name(parent_node, "BuoyantShipVessel") as Node3D
	_player = _find_node_by_type_or_name(parent_node, "SphericalPlayer") as Node3D
	_hud = _find_node_by_type_or_name(parent_node, "ExplorationHUD")
	_audio_mgr = _find_node_by_type_or_name(parent_node, "ProceduralAudioManager")

	_dialogue_quests = _find_node_by_type_or_name(parent_node, "TwinCapeDialogueAndQuests") as TwinCapeDialogueAndQuests
	if _dialogue_quests == null:
		_dialogue_quests = get_node_or_null("TwinCapeDialogueAndQuests") as TwinCapeDialogueAndQuests
	if _dialogue_quests == null:
		_dialogue_quests = TwinCapeDialogueAndQuests.new()
		_dialogue_quests.name = "TwinCapeDialogueAndQuests"
		if _rm_controller != null:
			_dialogue_quests.reverse_mountain_controller_path = _dialogue_quests.get_path_to(_rm_controller)
		add_child(_dialogue_quests)


func _find_node_by_type_or_name(root_node: Node, target_name: String) -> Node:
	var direct: Node = root_node.get_node_or_null(target_name)
	if direct != null:
		return direct
	for child: Node in root_node.get_children():
		if child.name == target_name:
			return child
	return null


func _connect_signals() -> void:
	if _rm_controller != null:
		if not _rm_controller.canal_entered.is_connected(_on_canal_entered):
			_rm_controller.canal_entered.connect(_on_canal_entered)
		if not _rm_controller.summit_basin_reached.is_connected(_on_summit_basin_reached):
			_rm_controller.summit_basin_reached.connect(_on_summit_basin_reached)
		if not _rm_controller.canal_wall_impact.is_connected(_on_canal_wall_impact):
			_rm_controller.canal_wall_impact.connect(_on_canal_wall_impact)
		if not _rm_controller.twin_cape_exited.is_connected(_on_twin_cape_exited):
			_rm_controller.twin_cape_exited.connect(_on_twin_cape_exited)
		if not _rm_controller.laboon_swallowed_ship.is_connected(_on_laboon_swallowed_ship):
			_rm_controller.laboon_swallowed_ship.connect(_on_laboon_swallowed_ship)
		if not _rm_controller.log_pose_gifted.is_connected(_on_log_pose_gifted):
			_rm_controller.log_pose_gifted.connect(_on_log_pose_gifted)

	if _hud != null and _hud.has_signal("dialogue_choice_selected"):
		if not _hud.is_connected("dialogue_choice_selected", _on_hud_dialogue_choice_selected):
			_hud.connect("dialogue_choice_selected", _on_hud_dialogue_choice_selected)

	if _dialogue_quests != null:
		if not _dialogue_quests.clinic_purchase_completed.is_connected(_on_clinic_purchase_completed):
			_dialogue_quests.clinic_purchase_completed.connect(_on_clinic_purchase_completed)
		if not _dialogue_quests.quest_completed.is_connected(_on_twin_cape_quest_completed):
			_dialogue_quests.quest_completed.connect(_on_twin_cape_quest_completed)


# ---------------------------------------------------------------------------
# 1. Live Canal Proximity, Hydraulic Drive & Rudder Assist Prompts
# ---------------------------------------------------------------------------
func _process_canal_approach_and_hydraulics(ship_world_pos: Vector3, delta: float) -> void:
	# Check outer Blue Sea gates for approach guidance before entering the 400 m canal
	var gates: Dictionary = _rm_controller.get_blue_sea_gate_coordinates()
	for canal_id: StringName in gates.keys():
		var gate_pos: Vector3 = gates[canal_id]["world_pos"]
		var dist_m: float = ship_world_pos.distance_to(gate_pos)
		if dist_m <= GATE_PROXIMITY_ALERT_M and _last_active_canal == &"":
			if _last_gate_alert != canal_id:
				_last_gate_alert = canal_id
				canal_approach_prompt.emit(canal_id, dist_m)
			_show_banner(
				"APPROACHING %s (%.1f km) — Align straight for the 400m stone guide-light gate!"
				% [String(gates[canal_id]["label"]).to_upper(), dist_m / 1_000.0],
				2.5
			)
			break

	var rudder_in: float = Input.get_axis("helm_steer_left", "helm_steer_right")
	var sail_trim: float = clampf(0.65 + Input.get_axis("sail_brake", "sail_throttle") * 0.35, 0.25, 1.0)
	var ship_vel: Vector3 = _get_ship_velocity()

	var step: Dictionary = _rm_controller.compute_hydraulic_step(
		_ship,
		ship_world_pos,
		ship_vel,
		rudder_in,
		sail_trim,
		ship_beam_m,
		rudder_integrity,
		delta
	)

	if not bool(step.get("active", false)):
		_last_active_canal = &""
		_set_rapids_audio(0.0)
		return

	var active_canal: StringName = step["canal_id"]
	_last_active_canal = active_canal

	# Push hydraulic current acceleration into BuoyantShipVessel
	var accel: Vector3 = step.get("acceleration", Vector3.ZERO)
	if _ship.has_method("apply_external_world_impulse"):
		_ship.call("apply_external_world_impulse", accel * delta)

	# Wall collision hull/rudder damage
	if bool(step.get("wall_hit", false)):
		var hull_dmg: float = float(step.get("hull_damage", 0.0))
		var r_dmg: float = float(step.get("rudder_damage", 0.0))
		rudder_integrity = clampf(rudder_integrity - r_dmg, 0.15, 1.0)
		if _ship.has_method("apply_hull_damage"):
			_ship.call("apply_hull_damage", hull_dmg, "Reverse Mountain Red Line Wall")

	# Live canal guidance / wall clearance HUD banner + rapids audio intensity
	var clearance_m: float = float(step.get("wall_clearance_m", 200.0))
	var lateral_m: float = float(step.get("lateral_offset_m", 0.0))
	var alt_m: float = float(step.get("alt_m", 0.0))
	var rapids_ratio: float = 1.0 if active_canal == ReverseMountainController.CANAL_PARADISE_EXIT else clampf(0.45 + (alt_m / 5_000.0) * 0.55, 0.45, 1.0)
	_set_rapids_audio(rapids_ratio)

	if clearance_m < 45.0:
		var steer_dir: String = "STEER PORT (LEFT)" if lateral_m > 0.0 else "STEER STARBOARD (RIGHT)"
		_show_banner(
			"RED LINE WALL WARNING [%.0f m clearance] — %s! (Rudder %.0f%%)"
			% [maxf(0.0, clearance_m), steer_dir, rudder_integrity * 100.0],
			0.5
		)
	else:
		_show_banner(
			"REVERSE MOUNTAIN [%s] | Alt: +%.0f m | Center Clearance: %.0f m | Slope: %.1f deg"
			% [String(step["zone"]).replace("_", " ").to_upper(), alt_m, clearance_m, float(step.get("slope_deg", 0.0))],
			0.5
		)


# ---------------------------------------------------------------------------
# 2. Laboon Swallow (52 m Maw) & Inside-Laboon Stomach Portal
# ---------------------------------------------------------------------------
func _process_laboon_maw_and_bay(ship_world_pos: Vector3) -> void:
	var ship_vel: Vector3 = _get_ship_velocity()
	var encounter: Dictionary = _rm_controller.evaluate_laboon_encounter(_ship, ship_world_pos, ship_vel)

	if bool(encounter.get("swallowed_this_frame", false)) or bool(encounter.get("inside_laboon", false)):
		_enter_laboon_stomach_portal()
		return

	# Proximity check to Laboon's 52 m maw for clear approach/swallow feedback
	var mouth_world: Vector3 = _rm_controller.laboon_world_pos + _rm_controller.laboon_forward * (ReverseMountainController.LABOON_LENGTH_M * 0.42)
	var dist_mouth: float = ship_world_pos.distance_to(mouth_world)
	if dist_mouth <= LABOON_MAW_TRIGGER_M and _rm_controller.laboon_state != ReverseMountainController.LaboonState.CALMED_JOLLY_ROGER_PROMISE:
		_enter_laboon_stomach_portal()
		return

	if bool(encounter.get("collided", false)):
		var push_n: Vector3 = encounter.get("push_normal", Vector3.UP)
		var dmg: float = float(encounter.get("hull_damage", 0.0))
		if _ship.has_method("apply_external_world_impulse"):
			_ship.call("apply_external_world_impulse", push_n * 24.0)
		if _ship.has_method("apply_hull_damage"):
			_ship.call("apply_hull_damage", dmg, "Laboon Island Whale Impact")
		_show_banner("COLLISION WITH LABOON (400m Island Whale)! Watch for his open mouth or steer toward Twin Cape Lighthouse.", 2.5)


func _enter_laboon_stomach_portal() -> void:
	if is_inside_laboon:
		return
	is_inside_laboon = true
	_set_rapids_audio(0.15)
	inside_laboon_entered.emit(_ship)
	_show_banner(
		"SWALLOWED BY LABOON! Painted fake sky cavern — Confront Mr. 9 & Miss Wednesday or press [E] at Crocus's Steel Doors to exit.",
		6.0
	)
	open_crocus_encounter("mr_9_and_miss_wednesday")


func _process_inside_laboon_state(delta: float) -> void:
	if not has_acid_resistant_paint and _ship.has_method("apply_hull_damage"):
		_ship.call("apply_hull_damage", _rm_controller.stomach_acid_dps * delta, "Laboon Gastric Acid Sea")
	_show_banner(
		"INSIDE LABOON'S STOMACH | %s | Press [E] to open Crocus's Steel Exit Doors to Twin Cape Dock"
		% ("Acid-Coated Hull OK" if has_acid_resistant_paint else "WARNING: Gastric Acid Eroding Hull!"),
		0.4
	)


func _exit_laboon_through_steel_doors() -> void:
	is_inside_laboon = false
	var dock_world_pos: Vector3 = _rm_controller.exit_laboon_via_steel_doors(_ship)
	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	if fo != null and fo.has_method("rebase_origin_to_world64"):
		var w64 := PackedFloat64Array([dock_world_pos.x, dock_world_pos.y, dock_world_pos.z])
		fo.call("rebase_origin_to_world64", w64)
		_ship.global_position = Vector3(0.0, 0.5, 0.0)
	elif _ship != null:
		_ship.global_position = dock_world_pos

	inside_laboon_exited.emit(_ship)
	_show_banner("Exited Laboon via Crocus's Riveted Steel Doors -> Moored at Twin Cape Lighthouse Dock!", 4.0)
	open_crocus_encounter("crocus")


# ---------------------------------------------------------------------------
# 3. Twin Cape Lighthouse & Crocus Dock Trigger -> ExplorationHUD
# ---------------------------------------------------------------------------
func _process_twin_cape_dock_trigger(ship_world_pos: Vector3) -> void:
	var dock_info: Dictionary = _rm_controller.check_lighthouse_docking(_ship, ship_world_pos)
	var in_dock: bool = bool(dock_info.get("in_dock_zone", false))

	if in_dock:
		if not _dock_notified_this_visit:
			_dock_notified_this_visit = true
			var wr: Node = get_node_or_null("/root/WorldRegistry")
			if wr != null and wr.has_method("notify_island_docked"):
				wr.call("notify_island_docked", "twin_cape")
		_show_banner("TWIN CAPE LIGHTHOUSE DOCK (%.0f m) — Press [E] to talk to Crocus (Log Pose Tutorial & Clinic Shop)" % float(dock_info["distance_m"]), 0.4)
	else:
		_dock_notified_this_visit = false


func open_crocus_encounter(npc_id: String = "crocus") -> void:
	if _dialogue_quests == null:
		return
	_active_twin_cape_npc = npc_id
	var payload: Dictionary = _dialogue_quests.start_dialogue(npc_id)
	_push_dialogue_to_hud(payload)
	if npc_id == "crocus":
		crocus_dock_interaction_opened.emit()


func _push_dialogue_to_hud(payload: Dictionary) -> void:
	if _hud == null or payload.is_empty():
		return
	if bool(payload.get("ended", false)):
		if _hud.has_method("close_dialogue_panel"):
			_hud.call("close_dialogue_panel")
		_active_twin_cape_npc = ""
		return

	var speaker: String = str(payload.get("speaker", "Crocus"))
	var stage_dir: String = str(payload.get("stage_direction", ""))
	var body: String = str(payload.get("text", ""))
	if not stage_dir.is_empty():
		body = stage_dir + "\n\n" + body

	var raw_choices: Array = payload.get("choices", [])
	var typed_choices: Array[Dictionary] = []
	for c in raw_choices:
		if c is Dictionary:
			typed_choices.append(c)

	# Inject convenient direct Clinic & Laboon actions inside Crocus's menu
	if _active_twin_cape_npc == "crocus" and str(payload.get("node_id", "")) == "clinic_services":
		typed_choices.append({"id": "buy_acid_paint", "label": "[Clinic] Buy Whale Acid-Resistant Paint (12,000 Beli)"})
		typed_choices.append({"id": "repair_hull_rudder", "label": "[Clinic] Emergency Hull & Rudder Repair (5,000+ Beli)"})
		typed_choices.append({"id": "heal_crew", "label": "[Clinic] Full Medical Treatment (1,500 Beli)"})
		typed_choices.append({"id": "open_hud_shop", "label": "[Clinic] Open Full Twin Cape Shop Drawer"})

	if _hud.has_method("open_dialogue_session"):
		_hud.call("open_dialogue_session", _active_twin_cape_npc, speaker, body, typed_choices)


func _on_hud_dialogue_choice_selected(npc_id: String, choice_id: String) -> void:
	if npc_id != _active_twin_cape_npc or _dialogue_quests == null:
		return

	# Handle direct Clinic transactions injected into Crocus's dialogue drawer
	match choice_id:
		"buy_acid_paint":
			var res_paint: Dictionary = _dialogue_quests.buy_clinic_item("acid_resistant_hull_paint", 1)
			if bool(res_paint.get("success", false)):
				has_acid_resistant_paint = true
				_show_banner("Applied Whale-Stomach Acid-Resistant Coating! Gastric acid immunity active.", 4.0)
			else:
				_show_banner(str(res_paint.get("reason", "Purchase failed.")), 3.0)
			return
		"repair_hull_rudder":
			var cur_hull: float = float(_ship.get("current_hull_integrity")) if _ship != null and _ship.get("current_hull_integrity") != null else 60.0
			var max_hull: float = float(_ship.get("max_hull_integrity")) if _ship != null and _ship.get("max_hull_integrity") != null else 100.0
			var res_patch: Dictionary = _dialogue_quests.purchase_emergency_hull_patch(cur_hull, max_hull, rudder_integrity)
			if bool(res_patch.get("success", false)):
				rudder_integrity = 1.0
				if _ship != null:
					_ship.set("current_hull_integrity", max_hull)
				_show_banner("Crocus patched hull to 100% and replaced snapped rudder!", 4.0)
			else:
				_show_banner(str(res_patch.get("reason", "Repair failed.")), 3.0)
			return
		"heal_crew":
			var res_heal: Dictionary = _dialogue_quests.purchase_medical_treatment()
			if bool(res_heal.get("success", false)):
				_show_banner("Crocus treated the crew — 100% HP restored!", 3.5)
			else:
				_show_banner(str(res_heal.get("reason", "Treatment failed.")), 3.0)
			return
		"open_hud_shop":
			if _hud != null and _hud.has_method("toggle_shop_drawer"):
				_hud.call("toggle_shop_drawer")
			return

	var next_payload: Dictionary = _dialogue_quests.choose_dialogue_option(choice_id)
	if next_payload.has("error"):
		_show_banner(str(next_payload["error"]), 3.0)
		return
	_push_dialogue_to_hud(next_payload)


# ---------------------------------------------------------------------------
# Signal Callbacks & Audio / HUD Utilities
# ---------------------------------------------------------------------------
func _on_canal_entered(_ship_node: Node3D, canal_id: StringName) -> void:
	_show_banner("CAPTURED BY %s HYDRAULIC CURRENT! Hold rudder centered between the 400m cliffs!" % String(canal_id).to_upper(), 4.5)


func _on_summit_basin_reached(_ship_node: Node3D, from_canal: StringName) -> void:
	var scm: Node = get_node_or_null("/root/StoryCampaignManager")
	if scm != null and scm.has_method("complete_milestone"):
		scm.call("complete_milestone", "act2_reverse_mountain_ascent")
	_show_banner("SUMMIT BASIN REACHED (+5,000 m) from %s! Plunging eastward into Paradise -> Twin Cape!" % String(from_canal), 4.5)


func _on_canal_wall_impact(_ship_node: Node3D, _canal_id: StringName, impact_speed: float, hull_dmg: float, _rudder_dmg: float) -> void:
	if _audio_mgr != null and _audio_mgr.has_method("play_cannon_fire"):
		_audio_mgr.call("play_cannon_fire")
	_show_banner("RED LINE CLIFF IMPACT (%.1f m/s | -%.1f Hull)! Rudder integrity: %.0f%%" % [impact_speed, hull_dmg, rudder_integrity * 100.0], 2.5)


func _on_twin_cape_exited(_ship_node: Node3D) -> void:
	_set_rapids_audio(0.0)
	_show_banner("WELCOME TO THE GRAND LINE (PARADISE)! Watch ahead for Laboon & Twin Cape Lighthouse!", 5.0)


func _on_laboon_swallowed_ship(_ship_node: Node3D) -> void:
	_enter_laboon_stomach_portal()


func _on_log_pose_gifted(_recipient: Node, item_data: Dictionary) -> void:
	if _audio_mgr != null and _audio_mgr.has_method("play_log_pose_lock"):
		_audio_mgr.call("play_log_pose_lock")
	var route_info: Dictionary = item_data.get("first_target", {})
	_show_banner("LOG POSE RECEIVED! Calibrated for Route %d -> %s." % [int(item_data.get("locked_route_id", 1)), str(route_info.get("first_island", "Whisky Peak"))], 5.0)


func _on_clinic_purchase_completed(item_id: String, _qty: int, _cost: int, _remaining: int) -> void:
	if item_id == "acid_resistant_hull_paint":
		has_acid_resistant_paint = true
	if _audio_mgr != null and _audio_mgr.has_method("play_beli_chime"):
		_audio_mgr.call("play_beli_chime")


func _on_twin_cape_quest_completed(quest_id: String, _rewards: Dictionary) -> void:
	if _audio_mgr != null and _audio_mgr.has_method("play_haki_pulse"):
		_audio_mgr.call("play_haki_pulse")
	_show_banner("QUEST COMPLETED: %s!" % quest_id.replace("_", " ").to_upper(), 4.5)


func _to_planetary_vec3(local_or_world_pos: Vector3) -> Vector3:
	var fo: Node = get_node_or_null("/root/FloatingOrigin")
	if fo != null and local_or_world_pos.length() < 1_000_000.0 and fo.has_method("local32_to_world_vec3"):
		return fo.call("local32_to_world_vec3", local_or_world_pos)
	return local_or_world_pos


func _get_ship_velocity() -> Vector3:
	if _ship is RigidBody3D:
		return (_ship as RigidBody3D).linear_velocity
	var v: Variant = _ship.get("linear_velocity")
	if v is Vector3:
		return v
	return Vector3.ZERO


func _set_rapids_audio(intensity: float) -> void:
	if _audio_mgr == null:
		return
	if _audio_mgr.has_method("set_reverse_mountain_rapids_intensity"):
		_audio_mgr.call("set_reverse_mountain_rapids_intensity", intensity)
	elif _audio_mgr.has_method("set_rapids_intensity"):
		_audio_mgr.call("set_rapids_intensity", intensity)
	elif _audio_mgr.has_method("set_ocean_turbulence"):
		_audio_mgr.call("set_ocean_turbulence", intensity)


# ---------------------------------------------------------------------------
# On-Screen Guidance Banner (Self-Contained Overlay)
# ---------------------------------------------------------------------------
func _build_guidance_banner() -> void:
	_banner_layer = CanvasLayer.new()
	_banner_layer.name = "ReverseMountainBannerLayer"
	_banner_layer.layer = 12
	add_child(_banner_layer)

	_banner_panel = PanelContainer.new()
	_banner_panel.anchor_left = 0.2
	_banner_panel.anchor_right = 0.8
	_banner_panel.anchor_top = 0.03
	_banner_panel.anchor_bottom = 0.03
	_banner_panel.offset_bottom = 44.0
	_banner_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.2, 0.86)
	style.border_color = Color(0.95, 0.72, 0.28, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	_banner_panel.add_theme_stylebox_override("panel", style)
	_banner_layer.add_child(_banner_panel)

	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
	_banner_panel.add_child(_banner_label)


func _show_banner(text: String, duration_sec: float = 2.0) -> void:
	if _hud != null and _hud.has_method("show_banner"):
		_hud.call("show_banner", text, duration_sec)
	if _banner_panel == null or _banner_label == null:
		return
	_banner_label.text = text
	_banner_panel.visible = true
	_banner_hide_timer = maxf(_banner_hide_timer, duration_sec)
