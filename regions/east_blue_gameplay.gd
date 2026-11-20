class_name EastBlueGameplay
extends Node
## Interactive East Blue gameplay controller for Project "Blue Planet" (Godot 4.3+, precision=double).
##
## Driven by EastBlueData and integrated with WorldRegistry and StoryCampaignManager:
##   - Live marketplace shop transactions (Beli buy/sell, stock tracking, trade arbitrage)
##   - Baratie recipe unlocks & Cocoyasi tangerine grove ship-deck planting (scurvy immunity)
##   - Branching NPC dialogue trees for 17 canonical East Blue NPCs
##   - 6 East Blue quest state machines culminating in Loguetown & Reverse Mountain canal dash

signal shop_transaction_completed(shop_id: String, action: String, item_id: String, quantity: int, total_beli: int)
signal dialogue_started(npc_id: String, node_id: String, payload: Dictionary)
signal dialogue_ended(npc_id: String)
signal quest_state_changed(quest_id: String, new_state: String, step_index: int)
signal recipe_unlocked(recipe_id: String, recipe_name: String)
signal ship_perk_unlocked(perk_id: String, description: String)
signal cursed_blade_trial_resolved(passed: bool, reward_items: Array[String])

const QUEST_STATE_LOCKED: String = "locked"
const QUEST_STATE_AVAILABLE: String = "available"
const QUEST_STATE_ACTIVE: String = "active"
const QUEST_STATE_READY: String = "ready_to_turn_in"
const QUEST_STATE_COMPLETED: String = "completed"

var _live_shops: Dictionary = {}
var _npcs_by_id: Dictionary = {}
var _player_inventory: Dictionary = {}
var _fallback_beli_balance: int = 15_000
var _unlocked_recipes: Array[String] = []
var _unlocked_ship_perks: Array[String] = []
var _tangerine_grove_planted: bool = false
var _caravel_unlocked: bool = false
var _cursed_blade_trial_passed: bool = false
var _current_island_id: String = "dawn_island"

var _dialogue_trees: Dictionary = {}
var _active_dialogue_npc_id: String = ""
var _active_dialogue_node_id: String = ""

var _quests: Dictionary = {}


func _ready() -> void:
	initialize_region_state()


## Initializes or resets East Blue shops, NPCs, dialogue trees, and quest state machines.
func initialize_region_state() -> void:
	_live_shops.clear()
	_npcs_by_id.clear()
	for shop: Dictionary in EastBlueData.get_all_shops():
		var shop_id: String = shop.get("id", "")
		if not shop_id.is_empty():
			_live_shops[shop_id] = shop.duplicate(true)
	for npc: Dictionary in EastBlueData.get_all_npcs():
		var npc_id: String = npc.get("id", "")
		if not npc_id.is_empty():
			_npcs_by_id[npc_id] = npc.duplicate(true)
	_build_dialogue_trees()
	_build_quest_catalog()


## Notifies WorldRegistry of docking on an East Blue island and updates local context.
func dock_at_island(island_id: String) -> Dictionary:
	var island: Dictionary = EastBlueData.get_island(island_id)
	if island.is_empty():
		return {"ok": false, "error": "Unknown East Blue island: %s" % island_id}
	_current_island_id = island_id
	var registry: Node = _get_world_registry()
	if registry != null and registry.has_method("notify_island_docked"):
		registry.notify_island_docked(island_id)
	return {
		"ok": true,
		"island_id": island_id,
		"name": island.get("name", ""),
		"shops": EastBlueData.get_shops_on_island(island_id),
		"npcs": EastBlueData.get_npcs_on_island(island_id)
	}


# ------------------------------------------------------------------------------
# Marketplace & Shop Transaction Controllers
# ------------------------------------------------------------------------------

## Returns live shop state and current inventory for UI rendering.
func open_shop(shop_id: String) -> Dictionary:
	if not _live_shops.has(shop_id):
		return {"ok": false, "error": "Shop not found: %s" % shop_id}
	var shop: Dictionary = _live_shops[shop_id]
	return {
		"ok": true,
		"shop": shop.duplicate(true),
		"player_beli": get_beli_balance()
	}


## Purchases `quantity` of `item_id` from `shop_id`, deducting Beli and applying special unlocks.
func buy_item(shop_id: String, item_id: String, quantity: int = 1) -> Dictionary:
	if quantity <= 0:
		return {"ok": false, "error": "Quantity must be positive."}
	if not _live_shops.has(shop_id):
		return {"ok": false, "error": "Shop not found: %s" % shop_id}

	var shop: Dictionary = _live_shops[shop_id]
	var inventory: Array = shop.get("inventory", [])
	var target_idx: int = -1
	for i: int in range(inventory.size()):
		if inventory[i].get("item_id", "") == item_id:
			target_idx = i
			break
	if target_idx == -1:
		return {"ok": false, "error": "Item not stocked in shop: %s" % item_id}

	var item: Dictionary = inventory[target_idx]
	var available: int = int(item.get("stock", 0))
	if available < quantity:
		return {"ok": false, "error": "Insufficient stock (%d available)." % available}

	var unit_price: int = _resolve_effective_buy_price(shop_id, item)
	var total_cost: int = unit_price * quantity
	if not _spend_beli(total_cost):
		return {
			"ok": false,
			"error": "Insufficient Beli (need %d, have %d)." % [total_cost, get_beli_balance()]
		}

	item["stock"] = available - quantity
	inventory[target_idx] = item
	_add_to_player_inventory(item, quantity)
	_apply_purchase_side_effects(item_id)

	shop_transaction_completed.emit(shop_id, "buy", item_id, quantity, total_cost)
	return {
		"ok": true,
		"shop_id": shop_id,
		"item_id": item_id,
		"quantity": quantity,
		"total_cost_beli": total_cost,
		"remaining_beli": get_beli_balance()
	}


## Sells `quantity` of `item_id` from player inventory to `shop_id`, awarding regional Beli value.
func sell_item(shop_id: String, item_id: String, quantity: int = 1) -> Dictionary:
	if quantity <= 0:
		return {"ok": false, "error": "Quantity must be positive."}
	if not _live_shops.has(shop_id):
		return {"ok": false, "error": "Shop not found: %s" % shop_id}
	if not _player_inventory.has(item_id):
		return {"ok": false, "error": "Item not in player inventory."}

	var entry: Dictionary = _player_inventory[item_id]
	var owned: int = int(entry.get("quantity", 0))
	if owned < quantity:
		return {"ok": false, "error": "Not enough quantity to sell."}

	var item_data: Dictionary = entry.get("item", {})
	var base_price: int = int(item_data.get("price_beli", 100))
	var multiplier: float = _get_sell_multiplier(shop_id, item_data)
	var unit_payout: int = maxi(1, int(round(float(base_price) * multiplier)))
	var total_payout: int = unit_payout * quantity

	entry["quantity"] = owned - quantity
	if int(entry["quantity"]) <= 0:
		_player_inventory.erase(item_id)
	else:
		_player_inventory[item_id] = entry

	_add_beli(total_payout)
	shop_transaction_completed.emit(shop_id, "sell", item_id, quantity, total_payout)
	return {
		"ok": true,
		"shop_id": shop_id,
		"item_id": item_id,
		"quantity": quantity,
		"total_payout_beli": total_payout,
		"new_beli": get_beli_balance()
	}


## Plants Bell-mère's Cocoyasi Tangerine Tree on the player's ship deck for permanent Scurvy immunity.
func plant_cocoyasi_tangerine_grove() -> Dictionary:
	if _tangerine_grove_planted:
		return {"ok": true, "already_planted": true, "perk": "scurvy_immunity"}
	_tangerine_grove_planted = true
	if not _unlocked_ship_perks.has("scurvy_immunity"):
		_unlocked_ship_perks.append("scurvy_immunity")
	var desc: String = "Bell-mère's Tangerine Grove planted on deck: permanent Vitamin C / Scurvy immunity."
	ship_perk_unlocked.emit("scurvy_immunity", desc)
	_notify_ship_upgrade("deck_orchard", "cocoyasi_tangerine_grove")
	return {"ok": true, "already_planted": false, "perk": "scurvy_immunity", "description": desc}


## Unlocks a Baratie culinary recipe for shipboard galley crafting.
func unlock_baratie_recipe(recipe_id: String, recipe_name: String = "") -> Dictionary:
	if _unlocked_recipes.has(recipe_id):
		return {"ok": true, "already_unlocked": true, "recipe_id": recipe_id}
	_unlocked_recipes.append(recipe_id)
	var display_name: String = recipe_name if not recipe_name.is_empty() else recipe_id.capitalize()
	recipe_unlocked.emit(recipe_id, display_name)
	return {"ok": true, "already_unlocked": false, "recipe_id": recipe_id, "recipe_name": display_name}


## Returns current Beli balance from WorldRegistry (or local fallback if standalone).
func get_beli_balance() -> int:
	var registry: Node = _get_world_registry()
	if registry != null and "wallet" in registry:
		var wallet_dict: Dictionary = registry.get("wallet")
		return int(wallet_dict.get("beli", _fallback_beli_balance))
	return _fallback_beli_balance


## Returns a copy of the player's East Blue item inventory.
func get_player_inventory() -> Dictionary:
	return _player_inventory.duplicate(true)


## Returns true if the player has planted Cocoyasi tangerine trees on deck.
func has_scurvy_immunity() -> bool:
	return _tangerine_grove_planted


## Returns unlocked Baratie culinary recipe IDs.
func get_unlocked_recipes() -> Array[String]:
	return _unlocked_recipes.duplicate()


# ------------------------------------------------------------------------------
# Branching NPC Dialogue System
# ------------------------------------------------------------------------------

## Begins a branching dialogue conversation with an East Blue NPC.
func start_dialogue(npc_id: String) -> Dictionary:
	if not _dialogue_trees.has(npc_id):
		var fallback_npc: Dictionary = _npcs_by_id.get(npc_id, {})
		if fallback_npc.is_empty():
			return {"ok": false, "error": "Unknown NPC: %s" % npc_id}
		var single_payload: Dictionary = {
			"npc_id": npc_id,
			"npc_name": fallback_npc.get("name", npc_id),
			"node_id": "root",
			"text": fallback_npc.get("dialogue_hook", "..."),
			"choices": [{"label": "Leave", "next_node": ""}]
		}
		_active_dialogue_npc_id = npc_id
		_active_dialogue_node_id = "root"
		dialogue_started.emit(npc_id, "root", single_payload)
		return {"ok": true, "node": single_payload}

	_active_dialogue_npc_id = npc_id
	_active_dialogue_node_id = "root"
	var payload: Dictionary = _format_dialogue_node(npc_id, "root")
	dialogue_started.emit(npc_id, "root", payload)
	return {"ok": true, "node": payload}


## Selects a dialogue branch choice by index and executes any attached gameplay action.
func advance_dialogue(choice_index: int) -> Dictionary:
	if _active_dialogue_npc_id.is_empty() or _active_dialogue_node_id.is_empty():
		return {"ok": false, "error": "No active dialogue."}

	var current: Dictionary = _format_dialogue_node(_active_dialogue_npc_id, _active_dialogue_node_id)
	var choices: Array = current.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return {"ok": false, "error": "Invalid dialogue choice index: %d" % choice_index}

	var choice: Dictionary = choices[choice_index]
	var action_result: Dictionary = _execute_dialogue_action(choice.get("action", ""), choice.get("action_arg", ""))
	var next_node_id: String = choice.get("next_node", "")

	if next_node_id.is_empty():
		var ended_npc: String = _active_dialogue_npc_id
		end_dialogue()
		return {"ok": true, "ended": true, "npc_id": ended_npc, "action_result": action_result}

	_active_dialogue_node_id = next_node_id
	var next_payload: Dictionary = _format_dialogue_node(_active_dialogue_npc_id, next_node_id)
	return {"ok": true, "ended": false, "node": next_payload, "action_result": action_result}


## Returns the currently active dialogue node payload, or empty Dictionary if idle.
func get_current_dialogue() -> Dictionary:
	if _active_dialogue_npc_id.is_empty() or _active_dialogue_node_id.is_empty():
		return {}
	return _format_dialogue_node(_active_dialogue_npc_id, _active_dialogue_node_id)


## Closes the current NPC conversation.
func end_dialogue() -> void:
	if _active_dialogue_npc_id.is_empty():
		return
	var npc_id: String = _active_dialogue_npc_id
	_active_dialogue_npc_id = ""
	_active_dialogue_node_id = ""
	dialogue_ended.emit(npc_id)


# ------------------------------------------------------------------------------
# Quest State Machines
# ------------------------------------------------------------------------------

## Starts an East Blue quest if it is currently available.
func start_quest(quest_id: String) -> Dictionary:
	if not _quests.has(quest_id):
		return {"ok": false, "error": "Unknown quest: %s" % quest_id}
	var q: Dictionary = _quests[quest_id]
	var state: String = q.get("state", QUEST_STATE_LOCKED)
	if state == QUEST_STATE_COMPLETED:
		return {"ok": false, "error": "Quest already completed."}
	if state == QUEST_STATE_ACTIVE or state == QUEST_STATE_READY:
		return {"ok": true, "quest": q.duplicate(true)}

	q["state"] = QUEST_STATE_ACTIVE
	q["current_step"] = 0
	_quests[quest_id] = q
	quest_state_changed.emit(quest_id, QUEST_STATE_ACTIVE, 0)
	return {"ok": true, "quest": q.duplicate(true)}


## Marks a quest step completed and transitions to `ready_to_turn_in` when all steps finish.
func advance_quest_step(quest_id: String, step_index: int = -1) -> Dictionary:
	if not _quests.has(quest_id):
		return {"ok": false, "error": "Unknown quest: %s" % quest_id}
	var q: Dictionary = _quests[quest_id]
	if q.get("state", "") == QUEST_STATE_AVAILABLE:
		start_quest(quest_id)
		q = _quests[quest_id]
	if q.get("state", "") != QUEST_STATE_ACTIVE:
		return {"ok": false, "error": "Quest is not active: %s" % quest_id}

	var steps: Array = q.get("steps", [])
	var idx: int = int(q.get("current_step", 0)) if step_index < 0 else step_index
	if idx < 0 or idx >= steps.size():
		return {"ok": false, "error": "Invalid step index."}

	steps[idx]["done"] = true
	var next_step: int = idx + 1
	q["current_step"] = mini(next_step, steps.size())

	var all_done: bool = true
	for s: Dictionary in steps:
		if not bool(s.get("done", false)):
			all_done = false
			break

	if all_done:
		q["state"] = QUEST_STATE_READY
	_quests[quest_id] = q
	quest_state_changed.emit(quest_id, q.get("state", QUEST_STATE_ACTIVE), int(q.get("current_step", 0)))
	return {"ok": true, "quest": q.duplicate(true)}


## Turns in a completed quest, awarding Beli, ship/recipe unlocks, and StoryCampaignManager milestones.
func complete_quest(quest_id: String) -> Dictionary:
	if not _quests.has(quest_id):
		return {"ok": false, "error": "Unknown quest: %s" % quest_id}
	var q: Dictionary = _quests[quest_id]
	if q.get("state", "") == QUEST_STATE_COMPLETED:
		return {"ok": false, "error": "Quest already completed."}

	# Ensure all steps are flagged done if turned in directly.
	var steps: Array = q.get("steps", [])
	for i: int in range(steps.size()):
		steps[i]["done"] = true

	q["state"] = QUEST_STATE_COMPLETED
	q["current_step"] = steps.size()
	_quests[quest_id] = q

	var reward_beli: int = int(q.get("reward_beli", 0))
	if reward_beli > 0:
		_add_beli(reward_beli)

	_apply_quest_completion_rewards(quest_id)
	quest_state_changed.emit(quest_id, QUEST_STATE_COMPLETED, steps.size())
	return {
		"ok": true,
		"quest_id": quest_id,
		"reward_beli": reward_beli,
		"unlocks": q.get("unlocks", []),
		"new_beli": get_beli_balance()
	}


## Returns the state dictionary for a single quest.
func get_quest_state(quest_id: String) -> Dictionary:
	if not _quests.has(quest_id):
		return {}
	return _quests[quest_id].duplicate(true)


## Returns all East Blue quests and their current states.
func get_all_quests() -> Dictionary:
	return _quests.duplicate(true)


## Executes Ipponmatsu's Sandai Kitetsu willpower arm-toss test in Loguetown.
func resolve_cursed_blade_trial(willpower_score: int = 10) -> Dictionary:
	var passed: bool = willpower_score >= 8
	var rewards: Array[String] = []
	if passed:
		_cursed_blade_trial_passed = true
		rewards.append("sandai_kitetsu")
		rewards.append("yubashiri")
		_grant_shop_item_direct("ipponmatsu_arms_shop", "sandai_kitetsu")
		_grant_shop_item_direct("ipponmatsu_arms_shop", "yubashiri")
		advance_quest_step("willpower_of_cursed_blade", 0)
	cursed_blade_trial_resolved.emit(passed, rewards)
	return {"ok": true, "passed": passed, "rewards": rewards}


# ------------------------------------------------------------------------------
# Internal Helpers & Integration
# ------------------------------------------------------------------------------

func _get_world_registry() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/WorldRegistry")


func _get_campaign_manager() -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/StoryCampaignManager")


func _add_beli(amount: int) -> void:
	var registry: Node = _get_world_registry()
	if registry != null and registry.has_method("add_currency"):
		registry.add_currency("beli", amount)
	else:
		_fallback_beli_balance += amount


func _spend_beli(cost: int) -> bool:
	var registry: Node = _get_world_registry()
	if registry != null and registry.has_method("spend_currency"):
		return bool(registry.spend_currency("beli", cost))
	if _fallback_beli_balance < cost:
		return false
	_fallback_beli_balance -= cost
	return true


func _notify_ship_upgrade(slot_name: String, tier_id: String) -> void:
	var campaign: Node = _get_campaign_manager()
	if campaign != null and campaign.has_method("install_ship_upgrade"):
		campaign.install_ship_upgrade(slot_name, tier_id)


func _notify_campaign_milestone(milestone_id: String) -> void:
	var campaign: Node = _get_campaign_manager()
	if campaign != null and campaign.has_method("complete_milestone"):
		campaign.complete_milestone(milestone_id)


func _resolve_effective_buy_price(shop_id: String, item: Dictionary) -> int:
	var item_id: String = item.get("item_id", "")
	if shop_id == "ipponmatsu_arms_shop" and item_id == "sandai_kitetsu" and _cursed_blade_trial_passed:
		return 50_000
	return int(item.get("price_beli", 0))


func _get_sell_multiplier(shop_id: String, item_data: Dictionary) -> float:
	var cat: String = item_data.get("category", "")
	if cat == "trade_good":
		if shop_id == "loguetown_port_outfitter" or shop_id == "gold_roger_bar" or shop_id == "uotome_fish_market":
			return 1.25
		return 1.10
	return 0.60


func _add_to_player_inventory(item: Dictionary, quantity: int) -> void:
	var item_id: String = item.get("item_id", "")
	if item_id.is_empty():
		return
	if _player_inventory.has(item_id):
		var cur: Dictionary = _player_inventory[item_id]
		cur["quantity"] = int(cur.get("quantity", 0)) + quantity
		_player_inventory[item_id] = cur
	else:
		_player_inventory[item_id] = {
			"item": item.duplicate(true),
			"quantity": quantity
		}


func _grant_shop_item_direct(shop_id: String, item_id: String) -> void:
	if not _live_shops.has(shop_id):
		return
	var inventory: Array = _live_shops[shop_id].get("inventory", [])
	for i: int in range(inventory.size()):
		if inventory[i].get("item_id", "") == item_id:
			var item: Dictionary = inventory[i]
			if int(item.get("stock", 0)) > 0:
				item["stock"] = int(item["stock"]) - 1
				inventory[i] = item
			_add_to_player_inventory(item, 1)
			return


func _apply_purchase_side_effects(item_id: String) -> void:
	match item_id:
		"zeff_culinary_tome":
			unlock_baratie_recipe("all_blue_risotto", "All-Blue Seafood Risotto")
			unlock_baratie_recipe("elephant_tuna_carpaccio", "Rare Sea-Tuna Carpaccio")
			unlock_baratie_recipe("scurvy_curing_citrus", "Baratie Citrus-Glazed Rations")
		"cocoyasi_tangerine_tree":
			plant_cocoyasi_tangerine_grove()
		"going_merry_blueprints":
			_caravel_unlocked = true
			if not _unlocked_ship_perks.has("caravel_going_merry"):
				_unlocked_ship_perks.append("caravel_going_merry")
			ship_perk_unlocked.emit("caravel_going_merry", "Caravel-class Going Merry hull unlocked.")
			_notify_ship_upgrade("hull", "caravel_going_merry")
		_:
			pass


func _apply_quest_completion_rewards(quest_id: String) -> void:
	match quest_id:
		"dawn_departure":
			_notify_campaign_milestone("eb_dawn_departure")
		"chouchous_treasure":
			_notify_campaign_milestone("eb_orange_town")
		"caravel_blueprint":
			_caravel_unlocked = true
			if not _unlocked_ship_perks.has("caravel_going_merry"):
				_unlocked_ship_perks.append("caravel_going_merry")
			ship_perk_unlocked.emit("caravel_going_merry", "Kaya & Merry gifted the Caravel-class Going Merry.")
			_notify_ship_upgrade("hull", "caravel_going_merry")
			_notify_campaign_milestone("eb_syrup_village")
		"all_blue_tasting":
			unlock_baratie_recipe("all_blue_risotto", "All-Blue Seafood Risotto")
			unlock_baratie_recipe("zeff_pirate_pilaf", "Zeff's Pirate Seafood Pilaf")
			_notify_campaign_milestone("eb_baratie")
		"tangerine_scurvy_cure":
			plant_cocoyasi_tangerine_grove()
			_notify_campaign_milestone("eb_arlong_park")
		"willpower_of_cursed_blade":
			if not _cursed_blade_trial_passed:
				resolve_cursed_blade_trial(10)
			_notify_campaign_milestone("eb_loguetown_reverse_mountain")
		_:
			pass


func _format_dialogue_node(npc_id: String, node_id: String) -> Dictionary:
	var tree: Dictionary = _dialogue_trees.get(npc_id, {})
	var node: Dictionary = tree.get(node_id, {})
	var npc_info: Dictionary = _npcs_by_id.get(npc_id, {})
	return {
		"npc_id": npc_id,
		"npc_name": npc_info.get("name", npc_id),
		"role": npc_info.get("role", ""),
		"node_id": node_id,
		"text": node.get("text", "..."),
		"choices": node.get("choices", [])
	}


func _execute_dialogue_action(action: String, arg: String) -> Dictionary:
	match action:
		"open_shop":
			return open_shop(arg)
		"start_quest":
			return start_quest(arg)
		"advance_quest":
			return advance_quest_step(arg)
		"complete_quest":
			return complete_quest(arg)
		"plant_tangerines":
			return plant_cocoyasi_tangerine_grove()
		"unlock_recipe":
			return unlock_baratie_recipe(arg)
		"cursed_blade_trial":
			return resolve_cursed_blade_trial(10)
		_:
			return {}


# ------------------------------------------------------------------------------
# Data Builders: Quests & Branching Dialogue Trees
# ------------------------------------------------------------------------------

func _build_quest_catalog() -> void:
	_quests = {
		"dawn_departure": {
			"id": "dawn_departure",
			"title": "Dawn Departure",
			"island_id": "dawn_island",
			"giver_npc_id": "makino",
			"state": QUEST_STATE_AVAILABLE,
			"current_step": 0,
			"reward_beli": 5_000,
			"unlocks": ["east_blue_starter_chart", "partys_bar_discount"],
			"steps": [
				{"label": "Obtain Foosha dinghy permit from Mayor Woop Slap", "done": false},
				{"label": "Stock starter rations at Makino's Partys Bar", "done": false},
				{"label": "Clear the Mt. Colubo bandit trail and sail past Foosha Reef", "done": false}
			]
		},
		"chouchous_treasure": {
			"id": "chouchous_treasure",
			"title": "Chouchou's Treasure",
			"island_id": "organ_islands",
			"giver_npc_id": "mayor_boodle",
			"state": QUEST_STATE_AVAILABLE,
			"current_step": 0,
			"reward_beli": 30_000,
			"unlocks": ["premium_beast_rations", "grand_line_map_fragment"],
			"steps": [
				{"label": "Speak with Chouchou outside Hocker's Pet Food Shop", "done": false},
				{"label": "Defeat Mohji & Richie defending the shop", "done": false},
				{"label": "Drive Buggy the Clown out of Orange Town Plaza", "done": false}
			]
		},
		"caravel_blueprint": {
			"id": "caravel_blueprint",
			"title": "Caravel Blueprint",
			"island_id": "gecko_islands",
			"giver_npc_id": "kaya",
			"state": QUEST_STATE_AVAILABLE,
			"current_step": 0,
			"reward_beli": 45_000,
			"unlocks": ["caravel_going_merry"],
			"steps": [
				{"label": "Consult Merry at Kaya's Mansion Shipyard", "done": false},
				{"label": "Hold the northern slope against Jango & Nyaban Brothers", "done": false},
				{"label": "Defeat Captain Kuro and receive the Going Merry Caravel", "done": false}
			]
		},
		"all_blue_tasting": {
			"id": "all_blue_tasting",
			"title": "All-Blue Tasting",
			"island_id": "baratie",
			"giver_npc_id": "chef_zeff",
			"state": QUEST_STATE_AVAILABLE,
			"current_step": 0,
			"reward_beli": 65_000,
			"unlocks": ["all_blue_risotto", "zeff_pirate_pilaf"],
			"steps": [
				{"label": "Sample dishes and help Patty & Carne on the Provision Deck", "done": false},
				{"label": "Serve starving Gin and repel Don Krieg's armada", "done": false},
				{"label": "Pass Chef Zeff's All-Blue culinary tasting", "done": false}
			]
		},
		"tangerine_scurvy_cure": {
			"id": "tangerine_scurvy_cure",
			"title": "Tangerine Scurvy Cure",
			"island_id": "conomi_islands",
			"giver_npc_id": "nojiko",
			"state": QUEST_STATE_AVAILABLE,
			"current_step": 0,
			"reward_beli": 100_000,
			"unlocks": ["scurvy_immunity"],
			"steps": [
				{"label": "Speak with Sheriff Genzo and Nojiko in Cocoyasi Village", "done": false},
				{"label": "Liberate Arlong Park and expose Captain Nezumi", "done": false},
				{"label": "Plant Bell-mère's tangerine tree on your ship deck", "done": false}
			]
		},
		"willpower_of_cursed_blade": {
			"id": "willpower_of_cursed_blade",
			"title": "Willpower of the Cursed Blade",
			"island_id": "loguetown",
			"giver_npc_id": "ipponmatsu",
			"state": QUEST_STATE_AVAILABLE,
			"current_step": 0,
			"reward_beli": 80_000,
			"unlocks": ["sandai_kitetsu", "yubashiri", "reverse_mountain_approach"],
			"steps": [
				{"label": "Pass Ipponmatsu's Sandai Kitetsu arm-toss trial", "done": false},
				{"label": "Hear Raoul's tale at the Gold Roger Bar", "done": false},
				{"label": "Dash through the Loguetown storm toward the East Blue Reverse Mountain canal", "done": false}
			]
		}
	}


func _build_dialogue_trees() -> void:
	_dialogue_trees = {
		"makino": {
			"root": {
				"text": "Welcome to Partys Bar! Heading out across the East Blue today?",
				"choices": [
					{"label": "Let me see Partys Bar's drinks and travel rations.", "next_node": "shop_hint", "action": "open_shop", "action_arg": "partys_bar"},
					{"label": "I'm ready to set sail from Foosha Village.", "next_node": "quest_offer", "action": "start_quest", "action_arg": "dawn_departure"},
					{"label": "Tell me about Shanks and the mountain bandits.", "next_node": "lore_shanks"},
					{"label": "See you later, Makino.", "next_node": ""}
				]
			},
			"shop_hint": {
				"text": "Stock up on Foosha Spiced Ale and travel rations before leaving the bay!",
				"choices": [{"label": "Thanks, Makino.", "next_node": ""}]
			},
			"quest_offer": {
				"text": "Mayor Woop Slap has your dinghy permit, and Dadan's boys spotted trouble on the Mt. Colubo trail.",
				"choices": [{"label": "I'll check with Woop Slap and clear the trail.", "next_node": ""}]
			},
			"lore_shanks": {
				"text": "Shanks always laughed off insults—until someone threatened his friends. Never forget what that straw hat stands for.",
				"choices": [{"label": "Back", "next_node": "root"}]
			}
		},
		"woop_slap": {
			"root": {
				"text": "Another young fool chasing pirate dreams?! Foosha Village doesn't need more trouble!",
				"choices": [
					{"label": "I just need a coastal dinghy permit, Mayor.", "next_node": "permit_given", "action": "advance_quest", "action_arg": "dawn_departure"},
					{"label": "Leave", "next_node": ""}
				]
			},
			"permit_given": {
				"text": "Hmph... Fine! Here is your Dawn Island departure permit. Watch out for the Lord of the Coast beyond the reef!",
				"choices": [{"label": "I'll be careful. Thanks, Mayor.", "next_node": ""}]
			}
		},
		"rika": {
			"root": {
				"text": "Excuse me! That swordsman tied up in Base 153 hasn't eaten in days—can you help?",
				"choices": [
					{"label": "Tell me about your rice balls.", "next_node": "onigiri"},
					{"label": "I'll help free Shells Town from Morgan.", "next_node": "morgan_tip"},
					{"label": "Goodbye", "next_node": ""}
				]
			},
			"onigiri": {
				"text": "I used sugar instead of salt so they'd taste sweet! My mom Ririka sells them at Food Foo!",
				"choices": [{"label": "Back", "next_node": "root"}]
			},
			"morgan_tip": {
				"text": "Be careful! Captain Morgan's son Helmeppo and his wolf patrol the square!",
				"choices": [{"label": "Got it.", "next_node": ""}]
			}
		},
		"ririka": {
			"root": {
				"text": "Welcome to Food Foo! Keep your voice low if Morgan's Marines march past.",
				"choices": [
					{"label": "Show me today's menu and onigiri.", "next_node": "opened", "action": "open_shop", "action_arg": "food_foo"},
					{"label": "Leave", "next_node": ""}
				]
			},
			"opened": {
				"text": "Fresh grilled sea bass and Rika's sweet onigiri—eat up before tackling Base 153!",
				"choices": [{"label": "Thanks!", "next_node": ""}]
			}
		},
		"mayor_boodle": {
			"root": {
				"text": "Orange Town was built from wilderness forty years ago! I won't let Buggy's circus level it!",
				"choices": [
					{"label": "Let's drive Buggy out and protect Chouchou's shop.", "next_node": "quest_start", "action": "start_quest", "action_arg": "chouchous_treasure"},
					{"label": "Browse the Rebuild Supply Depot.", "next_node": "depot", "action": "open_shop", "action_arg": "boodle_rebuild_depot"},
					{"label": "Leave", "next_node": ""}
				]
			},
			"quest_start": {
				"text": "Chouchou hasn't left Hocker's storefront once. Help that brave dog!",
				"choices": [{"label": "On it, Mayor!", "next_node": ""}]
			},
			"depot": {
				"text": "Take seasoned oak planks and blueprints—every ship needs timber after a Buggy Ball!",
				"choices": [{"label": "Thanks, Mayor Boodle.", "next_node": ""}]
			}
		},
		"chouchou": {
			"root": {
				"text": "Woof! (Chouchou stands guard over the last boxes of Hocker's Pet Food Shop.)",
				"choices": [
					{"label": "Browse Chouchou's Pet Food Shop.", "next_node": "shop_done", "action": "open_shop", "action_arg": "chouchou_pet_shop"},
					{"label": "Pat Chouchou's head and vow to protect the shop.", "next_node": "patted", "action": "advance_quest", "action_arg": "chouchous_treasure"},
					{"label": "Leave", "next_node": ""}
				]
			},
			"shop_done": {
				"text": "Bark! (Premium Beast Rations can pacify even fierce island wildlife.)",
				"choices": [{"label": "Good boy!", "next_node": ""}]
			},
			"patted": {
				"text": "Wroof! (Chouchou nudges a box of dog biscuits toward you in trust.)",
				"choices": [{"label": "I'll bring back your treasure.", "next_node": ""}]
			}
		},
		"koushirou": {
			"root": {
				"text": "Welcome to Isshin Dojo. A true blade cuts steel only when its wielder wills it.",
				"choices": [
					{"label": "Inspect Dojo training gear & Kendo scrolls.", "next_node": "dojo_shop", "action": "open_shop", "action_arg": "isshin_dojo_store"},
					{"label": "Ask about Wano Country's connection to this village.", "next_node": "wano_lore"},
					{"label": "Bow and depart", "next_node": ""}
				]
			},
			"dojo_shop": {
				"text": "Keep your edge honed with Wado-style oil and steady footwork.",
				"choices": [{"label": "Thank you, Sensei.", "next_node": ""}]
			},
			"wano_lore": {
				"text": "Our ancestors sailed from Wano decades ago, bringing master smithing—and the Wado Ichimonji.",
				"choices": [{"label": "Back", "next_node": "root"}]
			}
		},
		"gaimon": {
			"root": {
				"text": "Hey there! Welcome to the Island of Rare Animals! Mind the Cocox and Usagihebi!",
				"choices": [
					{"label": "What's in those five treasure chests atop the hill?", "next_node": "chests"},
					{"label": "Tell me about Sarfunkel.", "next_node": "sarfunkel"},
					{"label": "See you around, Gaimon!", "next_node": ""}
				]
			},
			"chests": {
				"text": "Empty for twenty years! Haha! Turns out the weird animals here were the real treasure all along!",
				"choices": [{"label": "Back", "next_node": "root"}]
			},
			"sarfunkel": {
				"text": "She's stuck in a barrel just like I'm stuck in a chest—best company in East Blue!",
				"choices": [{"label": "Back", "next_node": "root"}]
			}
		},
		"kaya": {
			"root": {
				"text": "Oh, hello! Are you friends of Usopp's? Please—Syrup Village is in grave danger!",
				"choices": [
					{"label": "We'll defend the northern slope and stop Kuro!", "next_node": "quest_start", "action": "start_quest", "action_arg": "caravel_blueprint"},
					{"label": "Talk to Merry about the Caravel ship.", "next_node": "caravel_note"},
					{"label": "Leave", "next_node": ""}
				]
			},
			"quest_start": {
				"text": "Thank you! If you save our village, our Caravel—the Going Merry—is yours!",
				"choices": [{"label": "Count on us, Kaya.", "next_node": ""}]
			},
			"caravel_note": {
				"text": "Merry designed every beam of that sheep-prowed Caravel himself.",
				"choices": [{"label": "Back", "next_node": "root"}]
			}
		},
		"merry_butler": {
			"root": {
				"text": "Welcome to Kaya's Mansion Shipyard. Every plank of the Going Merry is ready for the open sea.",
				"choices": [
					{"label": "Open Shipyard & Slingshot Outfitter.", "next_node": "yard", "action": "open_shop", "action_arg": "kaya_mansion_shipyard"},
					{"label": "Complete Caravel Blueprint delivery.", "next_node": "caravel_done", "action": "complete_quest", "action_arg": "caravel_blueprint"},
					{"label": "Leave", "next_node": ""}
				]
			},
			"yard": {
				"text": "Pick up Lead Star ammo and herbal tonics while you're docked.",
				"choices": [{"label": "Thanks, Merry.", "next_node": ""}]
			},
			"caravel_done": {
				"text": "She's yours! Treat the Going Merry kindly—she'll carry you all the way to the Grand Line.",
				"choices": [{"label": "We will!", "next_node": ""}]
			}
		},
		"chef_zeff": {
			"root": {
				"text": "If you're hungry, you eat at the Baratie! Just don't waste a single scrap on my ocean!",
				"choices": [
					{"label": "Order from the Baratie Dining Hall.", "next_node": "menu", "action": "open_shop", "action_arg": "baratie_dining_menu"},
					{"label": "Accept the All-Blue Tasting culinary challenge.", "next_node": "tasting", "action": "start_quest", "action_arg": "all_blue_tasting"},
					{"label": "Turn in the All-Blue Tasting challenge.", "next_node": "tasting_done", "action": "complete_quest", "action_arg": "all_blue_tasting"},
					{"label": "Leave", "next_node": ""}
				]
			},
			"menu": {
				"text": "Try the All-Blue Seafood Risotto—and grab my Maritime Cookbook if you run your own galley.",
				"choices": [{"label": "Delicious!", "next_node": ""}]
			},
			"tasting": {
				"text": "Help Patty and Carne on deck, feed that starving pirate Gin, and show me you respect the sea's bounty!",
				"choices": [{"label": "On it, Chef!", "next_node": ""}]
			},
			"tasting_done": {
				"text": "Not bad, brat! You've earned Baratie's All-Blue recipes. Maybe the All Blue really is out there.",
				"choices": [{"label": "Thanks, Chef Zeff!", "next_node": ""}]
			}
		},
		"patty": {
			"root": {
				"text": "Welcome to the floating crap-heap—ha! Want desserts from Sister Anko or a fight on the fin deck?",
				"choices": [
					{"label": "Open Sister Anko Galley Market.", "next_node": "anko", "action": "open_shop", "action_arg": "sister_anko_market"},
					{"label": "Leave", "next_node": ""}
				]
			},
			"anko": {
				"text": "Best sea-fruit tarts and Sambas pepper in East Blue!",
				"choices": [{"label": "Thanks, Patty.", "next_node": ""}]
			}
		},
		"carne": {
			"root": {
				"text": "Need bulk sea-rations or a heavy skillet before sailing toward the Calm Belt edge?",
				"choices": [
					{"label": "Open Patty & Carne's Provision Deck.", "next_node": "deck", "action": "open_shop", "action_arg": "patty_carne_provisions"},
					{"label": "Leave", "next_node": ""}
				]
			},
			"deck": {
				"text": "Fifteen days of hardtack per crate—don't let Krieg's thugs near the pantry!",
				"choices": [{"label": "Got it, Carne.", "next_node": ""}]
			}
		},
		"nojiko": {
			"root": {
				"text": "Welcome to Bell-mère's tangerine grove in Cocoyasi Village.",
				"choices": [
					{"label": "Browse Bell-mère's Tangerine Grove.", "next_node": "grove", "action": "open_shop", "action_arg": "bellmere_tangerine_grove"},
					{"label": "Help liberate Cocoyasi and plant tangerine trees on deck.", "next_node": "scurvy_quest", "action": "start_quest", "action_arg": "tangerine_scurvy_cure"},
					{"label": "Plant Bell-mère's tangerine tree on our ship deck!", "next_node": "planted", "action": "plant_tangerines"},
					{"label": "Leave", "next_node": ""}
				]
			},
			"grove": {
				"text": "Take a live mikan tree aboard—your crew will never suffer from scurvy again.",
				"choices": [{"label": "Thank you, Nojiko.", "next_node": ""}]
			},
			"scurvy_quest": {
				"text": "Arlong Park lies just up the coast. Free our island and Bell-mère's orchard is yours to share.",
				"choices": [{"label": "We'll bring Arlong down.", "next_node": ""}]
			},
			"planted": {
				"text": "Look at those blossoms! Bell-mère's tangerines will sail all the way into the Grand Line with you.",
				"choices": [{"label": "We'll take care of them!", "next_node": ""}]
			}
		},
		"genzo": {
			"root": {
				"text": "I'm Sheriff Genzo. Anyone who makes Nami or Nojiko cry answers to me!",
				"choices": [
					{"label": "Open Genzo's Pinwheel & Gear Stall.", "next_node": "stall", "action": "open_shop", "action_arg": "genzo_gear_stall"},
					{"label": "Report Arlong Park's defeat.", "next_node": "liberated", "action": "complete_quest", "action_arg": "tangerine_scurvy_cure"},
					{"label": "Leave", "next_node": ""}
				]
			},
			"stall": {
				"text": "Grab a wind-reading pinwheel and waterproof chart cylinder before heading to Loguetown.",
				"choices": [{"label": "Thanks, Genzo.", "next_node": ""}]
			},
			"liberated": {
				"text": "Eight years of tribute—over at last! Sail west-southwest to Loguetown, and don't look back!",
				"choices": [{"label": "Farewell, Sheriff!", "next_node": ""}]
			}
		},
		"ipponmatsu": {
			"root": {
				"text": "Looking for steel in Loguetown? Mind the bargain barrel—that Kitetsu blade carries a curse.",
				"choices": [
					{"label": "Browse Ipponmatsu's Arms Shop.", "next_node": "arms", "action": "open_shop", "action_arg": "ipponmatsu_arms_shop"},
					{"label": "Start 'Willpower of the Cursed Blade' & take the arm-toss test!", "next_node": "trial", "action": "start_quest", "action_arg": "willpower_of_cursed_blade"},
					{"label": "Toss Sandai Kitetsu into the air and hold out my arm!", "next_node": "trial_result", "action": "cursed_blade_trial"},
					{"label": "Leave", "next_node": ""}
				]
			},
			"arms": {
				"text": "Standard katanas are 50,000 Beli—unless you've got the nerve for something sharper.",
				"choices": [{"label": "Thanks.", "next_node": ""}]
			},
			"trial": {
				"text": "If your luck beats Sandai Kitetsu's curse, I'll let you have it—and my family heirloom Yubashiri!",
				"choices": [{"label": "Let's test my luck!", "next_node": "trial_result", "action": "cursed_blade_trial"}]
			},
			"trial_result": {
				"text": "Incredible! It spun right around your wrist without a scratch! Take both Sandai Kitetsu and Yubashiri!",
				"choices": [{"label": "I'll wield them well, Ipponmatsu!", "next_node": ""}]
			}
		},
		"raoul": {
			"root": {
				"text": "Welcome to the Gold Roger Bar. Right at this counter, Roger asked me if I believed in destiny.",
				"choices": [
					{"label": "Order drinks & Red-Line Crossing Stew.", "next_node": "bar", "action": "open_shop", "action_arg": "gold_roger_bar"},
					{"label": "Ask about the route from Loguetown to Reverse Mountain.", "next_node": "rm_route", "action": "advance_quest", "action_arg": "willpower_of_cursed_blade"},
					{"label": "Complete the Loguetown storm dash quest.", "next_node": "storm_done", "action": "complete_quest", "action_arg": "willpower_of_cursed_blade"},
					{"label": "Leave", "next_node": ""}
				]
			},
			"bar": {
				"text": "Have a glass before facing Smoker's garrison outside.",
				"choices": [{"label": "Cheers, Raoul.", "next_node": ""}]
			},
			"rm_route": {
				"text": "Sail southwest from Loguetown to (15.0° N, 8.5° E) and ride the East Blue canal straight up Reverse Mountain!",
				"choices": [{"label": "To the Grand Line!", "next_node": ""}]
			},
			"storm_done": {
				"text": "Green lightning and gale winds—just like Roger's day! The Reverse Mountain canal awaits you!",
				"choices": [{"label": "See you on the other side!", "next_node": ""}]
			}
		}
	}
