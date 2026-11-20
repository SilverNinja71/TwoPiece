class_name TwinCapeDialogueAndQuests
extends Node
## Interactive NPC Dialogue Trees, Crocus Clinic Shop & Quest State Machines for Twin Cape.
##
## Integrates with:
##   - ReverseMountainController (sibling or @export NodePath)
##   - WorldRegistry autoload (/root/WorldRegistry) for Beli wallet, Log Pose, & island docking
##   - StoryCampaignManager autoload (/root/StoryCampaignManager) for Act II milestones & Tone Dial

signal dialogue_started(npc_id: String, node_data: Dictionary)
signal dialogue_advanced(npc_id: String, node_data: Dictionary)
signal dialogue_ended(npc_id: String)
signal clinic_purchase_completed(item_id: String, quantity: int, total_cost_beli: int, remaining_beli: int)
signal clinic_purchase_failed(item_id: String, reason: String)
signal quest_updated(quest_id: String, stage: String, quest_state: Dictionary)
signal quest_completed(quest_id: String, rewards: Dictionary)

const QUEST_THE_50_YEAR_PROMISE: String = "the_50_year_promise"
const QUEST_MAGNETIC_HORIZON: String = "magnetic_horizon"
const QUEST_BINKS_SAKE_ECHO: String = "binks_sake_echo"

const MEDICAL_TREATMENT_COST_BELI: int = 1_500
const EMERGENCY_HULL_PATCH_COST_BELI: int = 5_000

@export var reverse_mountain_controller_path: NodePath

# Local fallback state when tested outside the main autoload tree
var _fallback_wallet_beli: int = 50_000
var _fallback_inventory: Dictionary = {}
var _active_npc_id: String = ""
var _active_node_id: String = ""
var _has_binks_sake_tone_dial: bool = false
var _selected_paradise_route_id: int = 1

var clinic_stock: Dictionary = {
	"standard_log_pose": 1,
	"acid_resistant_hull_paint": 5,
	"crocus_sedative_kit": 10,
	"twin_cape_harpoon_bundle": 8,
	"giant_squid_fillet": 15,
	"spare_caravel_rudder": 3,
}

var quest_states: Dictionary = {}

# ---------------------------------------------------------------------------
# Canonical Branching NPC Dialogue Trees
# ---------------------------------------------------------------------------
const DIALOGUE_TREES: Dictionary = {
	"crocus": {
		"npc_name": "Crocus",
		"title": "Keeper of the Twin Cape Lighthouse / Former Roger Pirates Doctor",
		"start_node": "comic_pause_intro",
		"nodes": {
			"comic_pause_intro": {
				"speaker": "Crocus",
				"stage_direction": "[Dramatic zoom-in. Crocus stares silently from his lawn chair.] ... ... ...",
				"text": "If you fire another cannon at this whale, someone is going to die.",
				"choices": [
					{"id": "who_dies", "label": "\"Who?!\"", "next": "comic_pause_punchline"},
					{"id": "log_pose_ask", "label": "\"We need a Log Pose to sail the Grand Line.\"", "next": "log_pose_tutorial"},
					{"id": "open_clinic", "label": "\"Treat our crew / open the Clinic Shop.\"", "next": "clinic_services"},
				],
			},
			"comic_pause_punchline": {
				"speaker": "Crocus",
				"stage_direction": "[Intense close-up pause.] ... ... ...",
				"text": "Me. (Don't underestimate a 71-year-old lighthouse keeper—put those cannons away before I reach for my harpoons.)",
				"choices": [
					{"id": "ask_laboon", "label": "\"Why does this giant whale keep smashing his head into the Red Line?\"", "next": "laboon_story"},
					{"id": "ask_roger", "label": "\"Wait... were you the doctor on Gol D. Roger's ship?!\"", "next": "roger_pirates_lore"},
					{"id": "log_pose_ask", "label": "\"How do we navigate Paradise from here?\"", "next": "log_pose_tutorial"},
				],
			},
			"laboon_story": {
				"speaker": "Crocus",
				"text": "Laboon is an Island Whale from the West Blue. Fifty years ago he followed the Rumbar Pirates across Reverse Mountain. They promised to circle the Grand Line and return for him, but they never came back. Now he rams the Red Line hoping to break through to them.",
				"sets_quest_stage": {"quest_id": QUEST_BINKS_SAKE_ECHO, "stage": "HEARD_RUMBAR_STORY"},
				"choices": [
					{"id": "promise_vow", "label": "\"I'll settle things with Laboon and give him a new promise.\"", "next": "promise_encouragement"},
					{"id": "play_tone_dial", "label": "\"Actually, we brought the Rumbar Pirates' Tone Dial!\"", "next": "tone_dial_reunion", "requires_tone_dial": true},
					{"id": "back_root", "label": "\"Tell me about navigation instead.\"", "next": "log_pose_tutorial"},
				],
			},
			"promise_encouragement": {
				"speaker": "Crocus",
				"text": "Hmph. A stubborn pirate with fire in their eyes... Go meet Laboon outside the steel hatches. If you can reach his heart—and paint your Jolly Roger over those scars—maybe he'll finally stop hurting himself.",
				"sets_quest_stage": {"quest_id": QUEST_THE_50_YEAR_PROMISE, "stage": "ENTERED_LABOON_STOMACH"},
				"choices": [
					{"id": "end", "label": "\"Leave it to us!\"", "next": ""},
				],
			},
			"roger_pirates_lore": {
				"speaker": "Crocus",
				"text": "Yes. I sailed with Gol D. Roger for his final three-year voyage to keep his terminal illness at bay—and to search for any trace of Laboon's old crew. We reached the end of the Grand Line, yet found no sign of the Rumbar Pirates' ship.",
				"choices": [
					{"id": "ask_end_island", "label": "\"What awaits at the end of the Log Pose?\"", "next": "lodestar_hint"},
					{"id": "back_laboon", "label": "\"Tell me more about Laboon.\"", "next": "laboon_story"},
				],
			},
			"lodestar_hint": {
				"speaker": "Crocus",
				"text": "Follow the Log Pose chains across Paradise and the New World until you reach Lodestar Island—or decipher the true secret of the Red Stones along the way. For now, survive Twin Cape first.",
				"choices": [
					{"id": "log_pose_ask", "label": "\"Show me how the Log Pose works.\"", "next": "log_pose_tutorial"},
					{"id": "end", "label": "\"We'll make it there.\"", "next": ""},
				],
			},
			"log_pose_tutorial": {
				"speaker": "Crocus",
				"text": "Ordinary Blue Sea compasses spin uselessly here—every island in the Grand Line holds immense magnetic minerals. Take this Log Pose. Wait on each island until its needle locks onto the next magnetic wave. Seven routes diverge from Twin Cape; choose your first heading wisely.",
				"action": "gift_log_pose_and_calibrate",
				"choices": [
					{"id": "route_1", "label": "Calibrate Route 1: Whisky Peak (Cactus Island — 10 min lock)", "next": "route_selected_1", "action": "select_route_1"},
					{"id": "route_2", "label": "Calibrate Route 2: Nanimonai Island (25 min lock)", "next": "route_selected_alt", "action": "select_route_2"},
					{"id": "route_3", "label": "Calibrate Route 3: Kyuka Island (15 min lock)", "next": "route_selected_alt", "action": "select_route_3"},
					{"id": "open_clinic", "label": "\"Let's check your Clinic & Supply Shop.\"", "next": "clinic_services"},
				],
			},
			"route_selected_1": {
				"speaker": "Crocus",
				"text": "Route 1 locked toward Whisky Peak. Watch your back there—not every welcoming town in Paradise flies an honest flag.",
				"choices": [{"id": "end", "label": "\"Set sail for Paradise!\"", "next": ""}],
			},
			"route_selected_alt": {
				"speaker": "Crocus",
				"text": "Your Log Pose needle is calibrated. Stay alive out there, rookie—and don't forget your promise to Laboon.",
				"choices": [{"id": "end", "label": "\"Thank you, Crocus!\"", "next": ""}],
			},
			"clinic_services": {
				"speaker": "Crocus",
				"text": "My Lighthouse Clinic stocks acid-resistant whale paint, Roger-grade trauma kits, heavy harpoons, and spare oak rudders if Reverse Mountain chewed yours up.",
				"action": "open_clinic_shop",
				"choices": [
					{"id": "back_intro", "label": "\"Actually, let's talk navigation.\"", "next": "log_pose_tutorial"},
					{"id": "end", "label": "\"Thanks, Doc.\"", "next": ""},
				],
			},
			"tone_dial_reunion": {
				"speaker": "Crocus",
				"text": "A Tone Dial from the Rumbar Pirates...?! Play 'Binks' Sake' out by the bay! Their surviving musician kept his promise after all!",
				"action": "play_rumbar_tone_dial",
				"choices": [{"id": "end", "label": "\"Listen, Laboon—they kept singing!\"", "next": ""}],
			},
		},
	},
	"mr_9_and_miss_wednesday": {
		"npc_name": "Mr. 9 & Miss Wednesday",
		"title": "Baroque Works Frontier Agents (Stomach Cavern Encounter)",
		"start_node": "stomach_ambush",
		"nodes": {
			"stomach_ambush": {
				"speaker": "Mr. 9 & Miss Wednesday",
				"text": "Ma-ma-ma-my! Hands off that whale—our town desperately needs that meat! Step aside before we fire our bazookas into his stomach walls!",
				"choices": [
					{"id": "stop_hunters", "label": "\"Attacking Laboon from the inside? Not on our watch!\"", "next": "hunters_foiled"},
					{"id": "ask_who", "label": "\"Who sent you two? And why are you riding a giant squid?\"", "next": "whisky_peak_hint"},
				],
			},
			"hunters_foiled": {
				"speaker": "Miss Wednesday",
				"text": "Gah! Crocus stopped our cannonball bare-handed and you beat us flat! Wait—if our boat is wrecked, give us a ride to Whisky Peak! We swear we won't cause trouble... probably.",
				"choices": [
					{"id": "grant_ride", "label": "\"Fine, you can hitch a ride to Whisky Peak (Route 1).\"", "next": "ride_accepted"},
					{"id": "refuse_ride", "label": "\"Swim out the steel doors yourselves!\"", "next": "ride_refused"},
				],
			},
			"whisky_peak_hint": {
				"speaker": "Mr. 9",
				"text": "We're from Cactus Island—Whisky Peak, the first stop on Route 1! If you give us a lift there, we'll make sure our whole town throws you a banquet!",
				"choices": [
					{"id": "grant_ride", "label": "\"A banquet? Alright, hop aboard once we exit Laboon.\"", "next": "ride_accepted"},
					{"id": "end", "label": "\"We'll deal with you after talking to Crocus.\"", "next": ""},
				],
			},
			"ride_accepted": {
				"speaker": "Miss Wednesday",
				"text": "(Whispers) Keep your guard up at Whisky Peak... That's all I can say for now.",
				"choices": [{"id": "end", "label": "\"See you on deck.\"", "next": ""}],
			},
			"ride_refused": {
				"speaker": "Mr. 9",
				"text": "You'll regret leaving a crown—uh, a frontier agent behind! Come on, Miss Wednesday, to the iron hatches!",
				"choices": [{"id": "end", "label": "\"Good riddance.\"", "next": ""}],
			},
		},
	},
	"laboon": {
		"npc_name": "Laboon",
		"title": "400m Island Whale of Twin Cape",
		"start_node": "bay_greeting",
		"nodes": {
			"bay_greeting": {
				"speaker": "Laboon",
				"stage_direction": "[A colossal deep-sea rumble vibrates across Twin Cape Bay.]",
				"text": "Mooooaaaan... (Laboon eyes the sheer cliff of the Red Line, old scars crisscrossing his massive brow.)",
				"choices": [
					{"id": "paint_jolly_roger", "label": "Duel Laboon to a draw & paint your Jolly Roger over his scars (Quest 1)", "next": "jolly_roger_vow"},
					{"id": "play_binks_sake", "label": "Play the Rumbar Pirates' 'Binks' Sake' Tone Dial (Quest 3)", "next": "binks_sake_joy", "requires_tone_dial": true},
					{"id": "end", "label": "\"Hang in there, big guy.\"", "next": ""},
				],
			},
			"jolly_roger_vow": {
				"speaker": "Laboon",
				"stage_direction": "[Laboon lets out a thunderous, hopeful cry and stops ramming the cliff.]",
				"text": "BOOOOM-MOOOAN! (The painted Jolly Roger gleams on his forehead—a solemn pact to meet again after circling the Grand Line.)",
				"action": "complete_50_year_promise",
				"choices": [{"id": "end", "label": "\"Don't rub it off until we return!\"", "next": ""}],
			},
			"binks_sake_joy": {
				"speaker": "Laboon",
				"stage_direction": "[Tears the size of boulders splash into Twin Cape Bay as 'Binks' Sake' echoes from the Tone Dial.]",
				"text": "MOOOAAAN!! (Recognizing Brook's violin and the Rumbar Pirates' chorus, Laboon breaches joyfully beneath the lighthouse beam.)",
				"action": "play_rumbar_tone_dial",
				"choices": [{"id": "end", "label": "\"We'll bring Brook back to you soon!\"", "next": ""}],
			},
		},
	},
}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_init_quests()


func _init_quests() -> void:
	quest_states = {
		QUEST_THE_50_YEAR_PROMISE: {
			"id": QUEST_THE_50_YEAR_PROMISE,
			"title": "The 50-Year Promise",
			"stage": "NOT_STARTED",
			"completed": false,
			"objective": "Meet Laboon in Twin Cape Bay or his stomach cavern and forge a reunion pact by painting your Jolly Roger on his scars.",
			"reward_beli": 50_000,
		},
		QUEST_MAGNETIC_HORIZON: {
			"id": QUEST_MAGNETIC_HORIZON,
			"title": "Magnetic Horizon",
			"stage": "NOT_STARTED",
			"completed": false,
			"objective": "Speak with Crocus at Twin Cape Lighthouse, learn Grand Line magnetism, receive your Log Pose, and lock 1 of the 7 Paradise routes.",
			"reward_beli": 25_000,
			"selected_route_id": 1,
		},
		QUEST_BINKS_SAKE_ECHO: {
			"id": QUEST_BINKS_SAKE_ECHO,
			"title": "Binks' Sake Echo",
			"stage": "NOT_STARTED",
			"completed": false,
			"objective": "Obtain the Rumbar Pirates' Tone Dial from the Florian Triangle (Thriller Bark) and play 'Binks' Sake' for Laboon and Crocus.",
			"reward_beli": 250_000,
		},
	}


# ---------------------------------------------------------------------------
# Node Resolution Helpers
# ---------------------------------------------------------------------------
func _get_rm_controller() -> ReverseMountainController:
	if not reverse_mountain_controller_path.is_empty():
		var target: Node = get_node_or_null(reverse_mountain_controller_path)
		if target is ReverseMountainController:
			return target
	var parent_node: Node = get_parent()
	if parent_node is ReverseMountainController:
		return parent_node
	if parent_node != null:
		for child: Node in parent_node.get_children():
			if child is ReverseMountainController:
				return child
	return null


func _get_world_registry() -> Node:
	return get_node_or_null("/root/WorldRegistry")


func _get_campaign_manager() -> Node:
	return get_node_or_null("/root/StoryCampaignManager")


func get_beli_balance() -> int:
	var wr: Node = _get_world_registry()
	if wr != null and wr.get("wallet") is Dictionary:
		return int(wr.wallet.get("Beli", 0))
	return _fallback_wallet_beli


func _spend_beli(amount: int) -> bool:
	if amount <= 0:
		return true
	var wr: Node = _get_world_registry()
	if wr != null and wr.has_method("spend_currency"):
		return bool(wr.spend_currency("Beli", amount))
	if _fallback_wallet_beli < amount:
		return false
	_fallback_wallet_beli -= amount
	return true


func _add_beli(amount: int) -> void:
	if amount <= 0:
		return
	var wr: Node = _get_world_registry()
	if wr != null and wr.has_method("add_currency"):
		wr.add_currency("Beli", amount)
	else:
		_fallback_wallet_beli += amount


# ---------------------------------------------------------------------------
# Branching Dialogue Runner
# ---------------------------------------------------------------------------
func start_dialogue(npc_id: String) -> Dictionary:
	if not DIALOGUE_TREES.has(npc_id):
		return {"error": "Unknown NPC: " + npc_id}
	_active_npc_id = npc_id
	_active_node_id = str(DIALOGUE_TREES[npc_id]["start_node"])
	var payload: Dictionary = _build_dialogue_payload(_active_npc_id, _active_node_id)
	dialogue_started.emit(npc_id, payload)
	return payload


func get_current_dialogue_node() -> Dictionary:
	if _active_npc_id.is_empty() or _active_node_id.is_empty():
		return {}
	return _build_dialogue_payload(_active_npc_id, _active_node_id)


func choose_dialogue_option(choice_id: String) -> Dictionary:
	if _active_npc_id.is_empty() or _active_node_id.is_empty():
		return {"error": "No active dialogue."}

	var tree: Dictionary = DIALOGUE_TREES[_active_npc_id]
	var node: Dictionary = tree["nodes"][_active_node_id]
	var chosen: Dictionary = {}
	for c: Dictionary in node.get("choices", []):
		if str(c.get("id", "")) == choice_id:
			chosen = c
			break

	if chosen.is_empty():
		return {"error": "Invalid choice id: " + choice_id}

	if chosen.get("requires_tone_dial", false) and not has_binks_sake_tone_dial():
		return {"error": "Requires the Rumbar Pirates' 'Binks' Sake' Tone Dial from Florian Triangle."}

	_execute_dialogue_action(str(chosen.get("action", "")))

	var next_id: String = str(chosen.get("next", ""))
	if next_id.is_empty():
		var ended_npc: String = _active_npc_id
		_active_npc_id = ""
		_active_node_id = ""
		dialogue_ended.emit(ended_npc)
		return {"ended": true, "npc_id": ended_npc}

	_active_node_id = next_id
	var next_node: Dictionary = tree["nodes"][_active_node_id]
	_execute_dialogue_action(str(next_node.get("action", "")))
	if next_node.has("sets_quest_stage"):
		var qs: Dictionary = next_node["sets_quest_stage"]
		_set_quest_stage(str(qs["quest_id"]), str(qs["stage"]))

	var payload: Dictionary = _build_dialogue_payload(_active_npc_id, _active_node_id)
	dialogue_advanced.emit(_active_npc_id, payload)
	return payload


func _build_dialogue_payload(npc_id: String, node_id: String) -> Dictionary:
	var tree: Dictionary = DIALOGUE_TREES[npc_id]
	var node: Dictionary = tree["nodes"][node_id]
	var filtered_choices: Array[Dictionary] = []
	for c: Dictionary in node.get("choices", []):
		if c.get("requires_tone_dial", false) and not has_binks_sake_tone_dial():
			continue
		filtered_choices.append(c.duplicate(true))

	return {
		"ended": false,
		"npc_id": npc_id,
		"npc_name": tree["npc_name"],
		"node_id": node_id,
		"speaker": node["speaker"],
		"stage_direction": node.get("stage_direction", ""),
		"text": node["text"],
		"choices": filtered_choices,
	}


func _execute_dialogue_action(action_name: String) -> void:
	match action_name:
		"gift_log_pose_and_calibrate":
			_set_quest_stage(QUEST_MAGNETIC_HORIZON, "TALKED_TO_CROCUS")
		"select_route_1":
			complete_magnetic_horizon_quest(1)
		"select_route_2":
			complete_magnetic_horizon_quest(2)
		"select_route_3":
			complete_magnetic_horizon_quest(3)
		"complete_50_year_promise":
			complete_50_year_promise_quest()
		"play_rumbar_tone_dial":
			complete_binks_sake_quest()


# ---------------------------------------------------------------------------
# Crocus Clinic Shop & Ship Repair Transactions
# ---------------------------------------------------------------------------
func get_clinic_inventory() -> Array[Dictionary]:
	var catalog: Array = ReverseMountainController.TWIN_CAPE_SETTLEMENT["marketplace_inventory"]
	var out: Array[Dictionary] = []
	for entry: Dictionary in catalog:
		var item_copy: Dictionary = entry.duplicate(true)
		var item_id: String = str(item_copy["id"])
		item_copy["stock"] = int(clinic_stock.get(item_id, 0))
		out.append(item_copy)
	return out


func buy_clinic_item(item_id: String, quantity: int = 1) -> Dictionary:
	if quantity <= 0:
		clinic_purchase_failed.emit(item_id, "Quantity must be positive.")
		return {"success": false, "reason": "Quantity must be positive."}

	var catalog_entry: Dictionary = {}
	for entry: Dictionary in ReverseMountainController.TWIN_CAPE_SETTLEMENT["marketplace_inventory"]:
		if str(entry["id"]) == item_id:
			catalog_entry = entry
			break

	if catalog_entry.is_empty():
		clinic_purchase_failed.emit(item_id, "Item not stocked at Crocus's Clinic.")
		return {"success": false, "reason": "Item not stocked at Crocus's Clinic."}

	var available: int = int(clinic_stock.get(item_id, 0))
	if available < quantity:
		clinic_purchase_failed.emit(item_id, "Insufficient stock.")
		return {"success": false, "reason": "Insufficient stock."}

	var unit_price: int = int(catalog_entry["price_beli"])
	if item_id == "standard_log_pose" and _get_rm_controller() != null and _get_rm_controller().player_log_pose_gifted:
		unit_price = 150_000 # Replacement Log Pose cost after initial Crocus gift

	var total_cost: int = unit_price * quantity
	if not _spend_beli(total_cost):
		clinic_purchase_failed.emit(item_id, "Not enough Beli.")
		return {"success": false, "reason": "Not enough Beli.", "required_beli": total_cost}

	clinic_stock[item_id] = available - quantity
	_fallback_inventory[item_id] = int(_fallback_inventory.get(item_id, 0)) + quantity

	var remaining: int = get_beli_balance()
	clinic_purchase_completed.emit(item_id, quantity, total_cost, remaining)
	return {
		"success": true,
		"item_id": item_id,
		"item_name": catalog_entry["name"],
		"quantity": quantity,
		"total_cost_beli": total_cost,
		"remaining_beli": remaining,
	}


func purchase_medical_treatment() -> Dictionary:
	if not _spend_beli(MEDICAL_TREATMENT_COST_BELI):
		clinic_purchase_failed.emit("medical_treatment", "Not enough Beli.")
		return {"success": false, "reason": "Not enough Beli."}
	var remaining: int = get_beli_balance()
	clinic_purchase_completed.emit("medical_treatment", 1, MEDICAL_TREATMENT_COST_BELI, remaining)
	return {
		"success": true,
		"service": "Crocus Clinic Full Recovery",
		"crew_hp_restored_pct": 1.0,
		"clears_status": ["gastric_acid_burn", "hypothermia", "shock"],
		"remaining_beli": remaining,
	}


func purchase_emergency_hull_patch(current_hull: float, max_hull: float, current_rudder_integrity: float) -> Dictionary:
	var missing_ratio: float = clamp(1.0 - (current_hull / max(1.0, max_hull)), 0.0, 1.0)
	var rudder_needed: bool = current_rudder_integrity < 0.99
	var cost: int = EMERGENCY_HULL_PATCH_COST_BELI + int(round(missing_ratio * 4_500.0)) + (2_500 if rudder_needed else 0)
	if not _spend_beli(cost):
		clinic_purchase_failed.emit("emergency_hull_patch", "Not enough Beli.")
		return {"success": false, "reason": "Not enough Beli.", "required_beli": cost}

	var remaining: int = get_beli_balance()
	clinic_purchase_completed.emit("emergency_hull_patch", 1, cost, remaining)
	return {
		"success": true,
		"restored_hull": max_hull,
		"restored_rudder_integrity": 1.0,
		"total_cost_beli": cost,
		"remaining_beli": remaining,
	}


# ---------------------------------------------------------------------------
# Quest State Machines (Quests 1, 2 & 3)
# ---------------------------------------------------------------------------
func _set_quest_stage(quest_id: String, stage: String) -> void:
	if not quest_states.has(quest_id):
		return
	if quest_states[quest_id]["completed"]:
		return
	quest_states[quest_id]["stage"] = stage
	quest_updated.emit(quest_id, stage, quest_states[quest_id].duplicate(true))


## Quest 1: "The 50-Year Promise" — Paint the Jolly Roger over Laboon's forehead scars.
func complete_50_year_promise_quest() -> Dictionary:
	var q: Dictionary = quest_states[QUEST_THE_50_YEAR_PROMISE]
	if q["completed"]:
		return {"already_completed": true, "quest": q}

	var rm: ReverseMountainController = _get_rm_controller()
	if rm != null:
		rm.fulfill_laboon_jolly_roger_promise()

	q["stage"] = "JOLLY_ROGER_PAINTED"
	q["completed"] = true
	var reward: int = int(q["reward_beli"])
	_add_beli(reward)

	var rewards: Dictionary = {
		"beli": reward,
		"laboon_state": "CALMED_JOLLY_ROGER_PROMISE",
		"scar_emblem": "Jolly Roger Promise",
	}
	quest_updated.emit(QUEST_THE_50_YEAR_PROMISE, q["stage"], q.duplicate(true))
	quest_completed.emit(QUEST_THE_50_YEAR_PROMISE, rewards)
	return {"already_completed": false, "quest": q, "rewards": rewards}


## Quest 2: "Magnetic Horizon" — Log Pose tutorial, initial gift, and 1 of 7 Paradise routes.
func complete_magnetic_horizon_quest(route_id: int = 1) -> Dictionary:
	_selected_paradise_route_id = clamp(route_id, 1, 7)
	var q: Dictionary = quest_states[QUEST_MAGNETIC_HORIZON]

	var rm: ReverseMountainController = _get_rm_controller()
	var crocus_result: Dictionary = {}
	if rm != null:
		crocus_result = rm.interact_with_crocus(self, _selected_paradise_route_id)

	var wr: Node = _get_world_registry()
	if wr != null:
		if wr.has_method("notify_island_docked"):
			wr.notify_island_docked("twin_cape")
		wr.set("active_nav_mode", 1) # WorldRegistrySystem.NavigationToolMode.SINGLE_LOG_POSE

	var scm: Node = _get_campaign_manager()
	if scm != null:
		scm.set("selected_paradise_route_index", _selected_paradise_route_id)
		if scm.has_method("complete_milestone"):
			scm.complete_milestone("act2_reverse_mountain_ascent")
			scm.complete_milestone("act2_twin_cape_laboon_log_pose")

	if q["completed"]:
		q["selected_route_id"] = _selected_paradise_route_id
		return {"already_completed": true, "quest": q, "crocus_result": crocus_result}

	q["stage"] = "LOG_POSE_RECEIVED"
	q["completed"] = true
	q["selected_route_id"] = _selected_paradise_route_id
	var reward: int = int(q["reward_beli"])
	_add_beli(reward)

	var route_info: Dictionary = ReverseMountainController.TWIN_CAPE_SETTLEMENT["seven_paradise_routes"][_selected_paradise_route_id - 1]
	var rewards: Dictionary = {
		"beli": reward,
		"item_id": "standard_log_pose",
		"selected_route": route_info,
	}
	quest_updated.emit(QUEST_MAGNETIC_HORIZON, q["stage"], q.duplicate(true))
	quest_completed.emit(QUEST_MAGNETIC_HORIZON, rewards)
	return {"already_completed": false, "quest": q, "rewards": rewards, "crocus_result": crocus_result}


## Allows StoryCampaignManager or Thriller Bark / Florian Triangle quests to grant the Tone Dial.
func grant_binks_sake_tone_dial() -> void:
	_has_binks_sake_tone_dial = true
	_set_quest_stage(QUEST_BINKS_SAKE_ECHO, "TONE_DIAL_ACQUIRED")


func has_binks_sake_tone_dial() -> bool:
	if _has_binks_sake_tone_dial:
		return true
	var scm: Node = _get_campaign_manager()
	if scm != null:
		var completed: Variant = scm.get("completed_milestones")
		if completed is Dictionary and (completed.has("act3_thriller_bark_brook") or completed.has("act3_florian_triangle_rumbar")):
			return true
		var dials: Variant = scm.get("unlocked_dials")
		if dials is Array and dials.has("BinksSakeToneDial"):
			return true
	return false


## Quest 3: "Binks' Sake Echo" — Play the Rumbar Pirates Tone Dial for Laboon & Crocus.
func complete_binks_sake_quest() -> Dictionary:
	var q: Dictionary = quest_states[QUEST_BINKS_SAKE_ECHO]
	if q["completed"]:
		return {"already_completed": true, "quest": q}
	if not has_binks_sake_tone_dial():
		return {"completed": false, "reason": "Missing Rumbar Pirates 'Binks' Sake' Tone Dial."}

	var rm: ReverseMountainController = _get_rm_controller()
	var hook_res: Dictionary = {}
	if rm != null:
		hook_res = rm.trigger_rumbar_tone_dial_hook(true)

	q["stage"] = "SONG_PLAYED_AT_TWIN_CAPE"
	q["completed"] = true
	var reward: int = int(q["reward_beli"])
	_add_beli(reward)

	var rewards: Dictionary = {
		"beli": reward,
		"hook_result": hook_res,
		"title": "Oathkeeper of Twin Cape",
	}
	quest_updated.emit(QUEST_BINKS_SAKE_ECHO, q["stage"], q.duplicate(true))
	quest_completed.emit(QUEST_BINKS_SAKE_ECHO, rewards)
	return {"already_completed": false, "quest": q, "rewards": rewards}
