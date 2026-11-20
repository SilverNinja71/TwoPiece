# south_blue_gameplay.gd
# Interactive Gameplay, Dialogue Trees, Marketplace & Quest Controller for South Blue
# Driven by SouthBlueData (res://regions/south_blue_data.gd) and integrated with WorldRegistry & StoryCampaignManager.

class_name SouthBlueGameplay
extends Node

# ==============================================================================
# 1. SIGNALS
# ==============================================================================
signal market_transaction_completed(market_id: String, item_id: String, quantity: int, total_cost_beli: int, remaining_beli: int)
signal market_transaction_failed(market_id: String, item_id: String, reason: String)
signal dialogue_started(npc_id: String, npc_name: String, node_id: String)
signal dialogue_node_presented(npc_id: String, node_data: Dictionary)
signal dialogue_ended(npc_id: String)
signal quest_state_changed(quest_id: String, new_state: int, stage_index: int, stage_title: String)
signal quest_completed(quest_id: String, title: String, reward_beli: int, reward_items: Array[String])
signal reputation_changed(faction_id: String, new_value: int)
signal ship_upgrade_unlocked(upgrade_id: String, island_id: String)

# ==============================================================================
# 2. ENUMS & RUNTIME STATE
# ==============================================================================
enum QuestState {
	LOCKED,
	AVAILABLE,
	ACTIVE,
	READY_TO_TURN_IN,
	COMPLETED
}

var player_inventory: Dictionary = {} # item_id (String) -> quantity (int)
var local_wallet_beli: int = 50000 # Fallback wallet when WorldRegistry autoload is not present
var current_island_id: String = "sorbet_kingdom"
var unlocked_ship_upgrades: Array[String] = []
var waterfall_meditation_seconds: float = 0.0

var faction_reputation: Dictionary = {
	"sorbet_monarchy": 0,
	"revolutionary_army": 0,
	"torino_scholars": 0,
	"karate_confederacy": 0,
	"wapol_konzern": 0,
	"kutsukku_gangs": 0,
	"briss_historians": 0,
	"baterilla_elders": 0,
	"vespa_mariners": 0,
	"taya_constabulary": 0,
	"samuwanai_guild": 0
}

var active_dialogue: Dictionary = {
	"active": false,
	"npc_id": "",
	"npc_name": "",
	"current_node_id": ""
}

var quests: Dictionary = {}
var dialogue_trees: Dictionary = {}

# ==============================================================================
# 3. LIFECYCLE & AUTOLOAD HELPERS
# ==============================================================================
func _ready() -> void:
	_init_quests()
	_init_dialogue_trees()

func _get_world_registry() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/WorldRegistry")
	return null

func _get_campaign_manager() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/StoryCampaignManager")
	return null

func get_beli_balance() -> int:
	var wr: Node = _get_world_registry()
	if wr != null and "wallet" in wr:
		return int(wr.wallet.get("Beli", local_wallet_beli))
	return local_wallet_beli

func _spend_beli(amount: int) -> bool:
	if amount <= 0:
		return true
	var wr: Node = _get_world_registry()
	if wr != null and wr.has_method("spend_currency"):
		var ok: bool = wr.spend_currency("Beli", amount)
		if ok:
			local_wallet_beli = int(wr.wallet.get("Beli", local_wallet_beli))
		return ok
	if local_wallet_beli < amount:
		return false
	local_wallet_beli -= amount
	return true

func _add_beli(amount: int) -> int:
	if amount <= 0:
		return get_beli_balance()
	var wr: Node = _get_world_registry()
	if wr != null and wr.has_method("add_currency"):
		var new_bal: int = wr.add_currency("Beli", amount)
		local_wallet_beli = new_bal
		return new_bal
	local_wallet_beli += amount
	return local_wallet_beli

func add_inventory_item(item_id: String, quantity: int = 1) -> void:
	if quantity <= 0:
		return
	var current: int = int(player_inventory.get(item_id, 0))
	player_inventory[item_id] = current + quantity

func get_item_count(item_id: String) -> int:
	return int(player_inventory.get(item_id, 0))

func adjust_reputation(faction_id: String, delta: int) -> int:
	var current: int = int(faction_reputation.get(faction_id, 0))
	var updated: int = clampi(current + delta, -100, 100)
	faction_reputation[faction_id] = updated
	reputation_changed.emit(faction_id, updated)
	return updated

# ==============================================================================
# 4. MARKETPLACE, APOTHECARY & FOUNDRY TRANSACTION CONTROLLERS
# ==============================================================================

## Returns all marketplaces on a given South Blue island.
func get_island_markets(island_id: String) -> Array[Dictionary]:
	var isl: Dictionary = SouthBlueData.get_island(island_id)
	if isl.is_empty():
		return []
	var result: Array[Dictionary] = []
	var raw_markets: Array = isl.get("shops_and_markets", [])
	for m in raw_markets:
		result.append(m)
	return result

## Computes the faction-adjusted price multiplier for a given market.
func get_market_price_multiplier(market_id: String) -> float:
	var market: Dictionary = SouthBlueData.get_market(market_id)
	if market.is_empty():
		return 1.0
	var isl_id: String = market.get("island_id", "")
	match isl_id:
		"sorbet_kingdom":
			return 0.85 if int(faction_reputation.get("sorbet_monarchy", 0)) >= 20 else 1.0
		"torino_kingdom":
			return 0.85 if int(faction_reputation.get("torino_scholars", 0)) >= 20 else 1.0
		"karate_island":
			return 0.90 if int(faction_reputation.get("karate_confederacy", 0)) >= 20 else 1.0
		"evil_black_drum":
			var rep: int = int(faction_reputation.get("wapol_konzern", 0))
			if rep >= 20:
				return 0.90
			return 1.10 # Wapol Konzern standard royal tariff
		"centaurea", "tumi":
			return 0.80 if int(faction_reputation.get("revolutionary_army", 0)) >= 20 else 1.0
		"briss_kingdom":
			return 0.90 if int(faction_reputation.get("briss_historians", 0)) >= 20 else 1.0
		"kutsukku_island":
			return 0.85 if int(faction_reputation.get("kutsukku_gangs", 0)) >= 20 else 1.05
	return 1.0

## Returns a market's inventory annotated with adjusted Beli prices.
func get_market_inventory_with_pricing(market_id: String) -> Array[Dictionary]:
	var market: Dictionary = SouthBlueData.get_market(market_id)
	if market.is_empty():
		return []
	var mult: float = get_market_price_multiplier(market_id)
	var out: Array[Dictionary] = []
	for item in market.get("inventory", []):
		var entry: Dictionary = item.duplicate()
		var base_price: int = int(item.get("price_beli", 0))
		entry["base_price_beli"] = base_price
		entry["adjusted_price_beli"] = maxi(1, int(round(float(base_price) * mult)))
		out.append(entry)
	return out

## Purchases quantity of item_id from market_id using Beli.
func purchase_item(market_id: String, item_id: String, quantity: int = 1) -> Dictionary:
	if quantity <= 0:
		market_transaction_failed.emit(market_id, item_id, "Quantity must be positive.")
		return {"success": false, "reason": "Quantity must be positive."}

	var market: Dictionary = SouthBlueData.get_market(market_id)
	if market.is_empty():
		market_transaction_failed.emit(market_id, item_id, "Unknown market.")
		return {"success": false, "reason": "Unknown market."}

	var target_item: Dictionary = {}
	for item in market.get("inventory", []):
		if item.get("item_id", "") == item_id:
			target_item = item
			break

	if target_item.is_empty():
		market_transaction_failed.emit(market_id, item_id, "Item not stocked at this market.")
		return {"success": false, "reason": "Item not stocked at this market."}

	var mult: float = get_market_price_multiplier(market_id)
	var unit_price: int = maxi(1, int(round(float(int(target_item.get("price_beli", 0))) * mult)))
	var total_cost: int = unit_price * quantity

	if not _spend_beli(total_cost):
		var msg: String = "Insufficient Beli (need %d, have %d)." % [total_cost, get_beli_balance()]
		market_transaction_failed.emit(market_id, item_id, msg)
		return {"success": false, "reason": msg}

	add_inventory_item(item_id, quantity)
	_on_item_acquired_quest_hook(item_id)

	var remaining: int = get_beli_balance()
	market_transaction_completed.emit(market_id, item_id, quantity, total_cost, remaining)
	return {
		"success": true,
		"market_id": market_id,
		"item_id": item_id,
		"item_name": target_item.get("name", item_id),
		"quantity": quantity,
		"unit_price_beli": unit_price,
		"total_cost_beli": total_cost,
		"remaining_beli": remaining
	}

## Sells quantity of item_id at a South Blue market (60% value locally, 75% arbitrage for Wapometal/Torino exports).
func sell_item(market_id: String, item_id: String, quantity: int = 1) -> Dictionary:
	if quantity <= 0 or get_item_count(item_id) < quantity:
		market_transaction_failed.emit(market_id, item_id, "Insufficient item quantity to sell.")
		return {"success": false, "reason": "Insufficient item quantity to sell."}

	var market: Dictionary = SouthBlueData.get_market(market_id)
	var item_data: Dictionary = SouthBlueData.get_item(item_id)
	if market.is_empty() or item_data.is_empty():
		market_transaction_failed.emit(market_id, item_id, "Invalid market or item.")
		return {"success": false, "reason": "Invalid market or item."}

	var base_price: int = int(item_data.get("price_beli", 100))
	var sell_rate: float = 0.60
	if market.get("island_id", "") != item_data.get("sold_at_island_id", ""):
		sell_rate = 0.75 # Regional export arbitrage bonus

	var unit_payout: int = maxi(1, int(round(float(base_price) * sell_rate)))
	var total_payout: int = unit_payout * quantity

	player_inventory[item_id] = get_item_count(item_id) - quantity
	var new_balance: int = _add_beli(total_payout)
	market_transaction_completed.emit(market_id, item_id, -quantity, -total_payout, new_balance)
	return {
		"success": true,
		"item_id": item_id,
		"quantity_sold": quantity,
		"total_payout_beli": total_payout,
		"new_balance_beli": new_balance
	}

## Wapol Konzern Foundry Controller: smuggles/fuses Wapometal ingots into ship hull armor plating.
func craft_wapometal_armor_plate(ingot_count: int = 2) -> Dictionary:
	var smelting_fee: int = 15000
	if get_item_count("wapometal_ingot") < ingot_count:
		return {"success": false, "reason": "Need %d Pure Wapometal Ingots." % ingot_count}
	if not _spend_beli(smelting_fee):
		return {"success": false, "reason": "Need %d Beli for Baku Baku Foundry smelting." % smelting_fee}

	player_inventory["wapometal_ingot"] -= ingot_count
	add_inventory_item("wapometal_hull_plating", 1)
	if not unlocked_ship_upgrades.has("wapometal_hull_plating"):
		unlocked_ship_upgrades.append("wapometal_hull_plating")
	ship_upgrade_unlocked.emit("wapometal_hull_plating", "evil_black_drum")

	var cm: Node = _get_campaign_manager()
	if cm != null and cm.has_method("install_ship_upgrade"):
		cm.install_ship_upgrade("hull_plating", "Wapometal Shape-Memory Alloy")

	return {
		"success": true,
		"crafted_item": "wapometal_hull_plating",
		"remaining_beli": get_beli_balance()
	}

## Torino Herbal Apothecary Controller: brews Master Elixir from Golden Root Essence & Canopy Spores.
func brew_torino_tonic(root_count: int = 1, spore_count: int = 2) -> Dictionary:
	if get_item_count("rumble_ball_precursor") < root_count or get_item_count("torino_healing_spores") < spore_count:
		return {"success": false, "reason": "Requires %d Torino Golden Root Essence and %d Bioluminescent Spores." % [root_count, spore_count]}

	player_inventory["rumble_ball_precursor"] -= root_count
	player_inventory["torino_healing_spores"] -= spore_count
	add_inventory_item("torino_master_elixir", 1)
	return {
		"success": true,
		"crafted_item": "torino_master_elixir",
		"description": "Restores 1,200 HP and stabilizes Devil Fruit / stamina bursts for 30 minutes."
	}

## Briss Kingdom Shipyard Controller: fits St. Briss Atmospheric Storm Rigging to player ship.
func fit_st_briss_sky_rigging() -> Dictionary:
	if get_item_count("high_altitude_rigging") < 1:
		var purchase_res: Dictionary = purchase_item("briss_historical_shipwrights", "high_altitude_rigging", 1)
		if not purchase_res.get("success", false):
			return purchase_res

	if not unlocked_ship_upgrades.has("st_briss_sky_rigging"):
		unlocked_ship_upgrades.append("st_briss_sky_rigging")
	ship_upgrade_unlocked.emit("st_briss_sky_rigging", "briss_kingdom")

	var cm: Node = _get_campaign_manager()
	if cm != null and cm.has_method("install_ship_upgrade"):
		cm.install_ship_upgrade("rigging", "St. Briss High-Altitude Storm Rigging")

	return {
		"success": true,
		"upgrade_id": "st_briss_sky_rigging",
		"island_id": "briss_kingdom"
	}

# ==============================================================================
# 5. QUEST STATE MACHINES
# ==============================================================================
func _init_quests() -> void:
	quests = {
		"quest_sorbet_sapphire_alms": {
			"quest_id": "quest_sorbet_sapphire_alms",
			"title": "Church of Sorbet & Sapphire Alms",
			"island_id": "sorbet_kingdom",
			"state": QuestState.AVAILABLE,
			"stage": 0,
			"stages": [
				"Speak with Pastor Aide Luke at the Southern Church of Sorbet.",
				"Acquire Blue Herb Sapphire Balm and Sorbet Loaded Brick-Oven Pizza for the Southern elders.",
				"Deliver the alms and report to King Bulldog or Queen Dowager Conney at the Northern Citadel."
			],
			"reward_beli": 18000,
			"reward_items": ["kuma_bible_page"],
			"reward_rep_faction": "sorbet_monarchy",
			"reward_rep_amount": 25
		},
		"quest_torino_canopy_remedy": {
			"quest_id": "quest_torino_canopy_remedy",
			"title": "Canopy Remedy & Rumble Precursor",
			"island_id": "torino_kingdom",
			"state": QuestState.AVAILABLE,
			"stage": 0,
			"stages": [
				"Consult Chief Shanba in the Torino Great Stone Library.",
				"Climb to the 1,250m Great Tree Canopy and earn Matriarch Masked Goayu's trust.",
				"Acquire Torino Golden Root Essence and Bioluminescent Spores, then brew/deliver the remedy to Shanba."
			],
			"reward_beli": 35000,
			"reward_items": ["ancient_medical_codex"],
			"reward_rep_faction": "torino_scholars",
			"reward_rep_amount": 30
		},
		"quest_karate_waterfall_trial": {
			"quest_id": "quest_karate_waterfall_trial",
			"title": "10,000-Ton Waterfall Trial",
			"island_id": "karate_island",
			"state": QuestState.AVAILABLE,
			"stage": 0,
			"stages": [
				"Speak with Grandmaster Dohyo at the Central Martial Amphitheater.",
				"Train with Max 'Thunder-Jab' at the Boxing Academy and equip Iron-Thread Black Belt Hand Wraps.",
				"Endure the Ten-Thousand Ton Waterfall Shrine and return to Grandmaster Dohyo for Black Belt certification."
			],
			"reward_beli": 28000,
			"reward_items": ["karate_black_belt_cert"],
			"reward_rep_faction": "karate_confederacy",
			"reward_rep_amount": 30
		},
		"quest_st_briss_sky_rigging": {
			"quest_id": "quest_st_briss_sky_rigging",
			"title": "St. Briss Sky-Rigging",
			"island_id": "briss_kingdom",
			"state": QuestState.AVAILABLE,
			"stage": 0,
			"stages": [
				"Speak with Curator Valerie in Briss Kingdom's Antiquarian Quarter.",
				"Acquire Traditional South Sea Enamel Tar and inspect the St. Briss Historical Naval Yards.",
				"Commission St. Briss Atmospheric Storm Rigging for Reverse Mountain and Knock Up Stream ascents."
			],
			"reward_beli": 45000,
			"reward_items": ["st_briss_logbook_copy"],
			"reward_rep_faction": "briss_historians",
			"reward_rep_amount": 25
		},
		"quest_liberators_beacon": {
			"quest_id": "quest_liberators_beacon",
			"title": "Liberator's Beacon",
			"island_id": "centaurea",
			"state": QuestState.AVAILABLE,
			"stage": 0,
			"stages": [
				"Report to Revolutionary Commander Caspian at Dragon's Bastion in Centaurea.",
				"Acquire an Encrypted White Den Den Mushi Receiver and deliver supplies to Elder Bram in Tumi.",
				"Check in with Master Pilot Gordon at the Reverse Mountain South Staging Gateway (lat -15.5, lon 1.2)."
			],
			"reward_beli": 60000,
			"reward_items": ["rev_army_cloak"],
			"reward_rep_faction": "revolutionary_army",
			"reward_rep_amount": 35
		},
		"quest_victoria_memorial_tribute": {
			"quest_id": "quest_victoria_memorial_tribute",
			"title": "Victoria's Memorial Tribute",
			"island_id": "kutsukku_island",
			"state": QuestState.AVAILABLE,
			"stage": 0,
			"stages": [
				"Speak with Slash the Spike at Kid's Magnetic Scrapyard on Kutsukku Island.",
				"Bring a South Blue Pink Hibiscus from Baterilla to Victoria Doruyanaika's Memorial Lookout."
			],
			"reward_beli": 25000,
			"reward_items": ["anti_curry_udon_sign"],
			"reward_rep_faction": "kutsukku_gangs",
			"reward_rep_amount": 25
		},
		"quest_wapol_wapometal_contract": {
			"quest_id": "quest_wapol_wapometal_contract",
			"title": "Wapol Konzern Foundry Contract",
			"island_id": "evil_black_drum",
			"state": QuestState.AVAILABLE,
			"stage": 0,
			"stages": [
				"Negotiate a metallurgical license with King Wapol at Black Drum Castle.",
				"Acquire 2 Pure Wapometal Ingots (or supply Salvaged High-Tensile Cogwheels) and forge Wapometal Hull Plating."
			],
			"reward_beli": 50000,
			"reward_items": ["tin_soldier_automaton"],
			"reward_rep_faction": "wapol_konzern",
			"reward_rep_amount": 20
		}
	}

func start_quest(quest_id: String) -> bool:
	if not quests.has(quest_id):
		return false
	var q: Dictionary = quests[quest_id]
	if q["state"] != QuestState.AVAILABLE:
		return false
	q["state"] = QuestState.ACTIVE
	q["stage"] = 1
	var stage_title: String = q["stages"][1]
	quest_state_changed.emit(quest_id, QuestState.ACTIVE, 1, stage_title)
	return true

func advance_quest(quest_id: String, target_stage: int = -1) -> bool:
	if not quests.has(quest_id):
		return false
	var q: Dictionary = quests[quest_id]
	if q["state"] == QuestState.COMPLETED:
		return false
	if q["state"] == QuestState.AVAILABLE:
		return start_quest(quest_id)

	var max_stage: int = q["stages"].size() - 1
	var next_stage: int = target_stage if target_stage >= 0 else int(q["stage"]) + 1
	next_stage = mini(next_stage, max_stage)
	q["stage"] = next_stage

	if next_stage >= max_stage:
		q["state"] = QuestState.READY_TO_TURN_IN
	else:
		q["state"] = QuestState.ACTIVE

	quest_state_changed.emit(quest_id, q["state"], next_stage, q["stages"][next_stage])
	return true

func complete_quest(quest_id: String) -> Dictionary:
	if not quests.has(quest_id):
		return {"success": false, "reason": "Unknown quest."}
	var q: Dictionary = quests[quest_id]
	if q["state"] == QuestState.COMPLETED:
		return {"success": false, "reason": "Quest already completed."}

	q["state"] = QuestState.COMPLETED
	q["stage"] = q["stages"].size() - 1

	var reward_beli: int = int(q.get("reward_beli", 0))
	_add_beli(reward_beli)

	var granted_items: Array[String] = []
	for item_id in q.get("reward_items", []):
		add_inventory_item(item_id, 1)
		granted_items.append(item_id)

	var rep_faction: String = q.get("reward_rep_faction", "")
	var rep_amount: int = int(q.get("reward_rep_amount", 0))
	if not rep_faction.is_empty() and rep_amount != 0:
		adjust_reputation(rep_faction, rep_amount)

	# Special story/progression hooks
	var cm: Node = _get_campaign_manager()
	if quest_id == "quest_karate_waterfall_trial" and cm != null and cm.has_method("unlock_haki_tier"):
		cm.unlock_haki_tier("armament", 1, "Karate Island Iron Body Foundation")
	elif quest_id == "quest_liberators_beacon" and cm != null and cm.has_method("complete_milestone"):
		cm.complete_milestone("south_blue_reverse_mountain_ready")

	quest_state_changed.emit(quest_id, QuestState.COMPLETED, q["stage"], "Completed")
	quest_completed.emit(quest_id, q["title"], reward_beli, granted_items)
	return {
		"success": true,
		"quest_id": quest_id,
		"title": q["title"],
		"reward_beli": reward_beli,
		"reward_items": granted_items
	}

func get_quest_status(quest_id: String) -> Dictionary:
	if quests.has(quest_id):
		return quests[quest_id].duplicate(true)
	return {}

## Automatically advances quest stages when key quest items are bought or looted.
func _on_item_acquired_quest_hook(item_id: String) -> void:
	if item_id in ["sapphire_balm", "bonney_brick_pizza"]:
		var q_sorbet: Dictionary = quests.get("quest_sorbet_sapphire_alms", {})
		if q_sorbet.get("state", QuestState.LOCKED) == QuestState.ACTIVE:
			if get_item_count("sapphire_balm") >= 1 and get_item_count("bonney_brick_pizza") >= 1:
				advance_quest("quest_sorbet_sapphire_alms", 2)

	elif item_id in ["rumble_ball_precursor", "torino_healing_spores"]:
		var q_torino: Dictionary = quests.get("quest_torino_canopy_remedy", {})
		if q_torino.get("state", QuestState.LOCKED) == QuestState.ACTIVE:
			if get_item_count("rumble_ball_precursor") >= 1 and get_item_count("torino_healing_spores") >= 1:
				advance_quest("quest_torino_canopy_remedy", 2)

	elif item_id == "black_belt_grips":
		var q_karate: Dictionary = quests.get("quest_karate_waterfall_trial", {})
		if q_karate.get("state", QuestState.LOCKED) == QuestState.ACTIVE:
			advance_quest("quest_karate_waterfall_trial", 2)

	elif item_id == "high_altitude_rigging":
		var q_briss: Dictionary = quests.get("quest_st_briss_sky_rigging", {})
		if q_briss.get("state", QuestState.LOCKED) == QuestState.ACTIVE:
			advance_quest("quest_st_briss_sky_rigging", 2)

	elif item_id == "encrypted_transponder_key":
		var q_lib: Dictionary = quests.get("quest_liberators_beacon", {})
		if q_lib.get("state", QuestState.LOCKED) == QuestState.ACTIVE and int(q_lib.get("stage", 0)) < 2:
			advance_quest("quest_liberators_beacon", 1)

## Call from Karate Island waterfall trigger when player meditates beneath the cataract.
func record_waterfall_meditation(delta_sec: float) -> bool:
	waterfall_meditation_seconds += delta_sec
	if waterfall_meditation_seconds >= 120.0:
		var q_karate: Dictionary = quests.get("quest_karate_waterfall_trial", {})
		if q_karate.get("state", QuestState.LOCKED) in [QuestState.ACTIVE, QuestState.READY_TO_TURN_IN]:
			advance_quest("quest_karate_waterfall_trial", 2)
			return true
	return false

# ==============================================================================
# 6. BRANCHING NPC DIALOGUE TREES
# ==============================================================================
func _init_dialogue_trees() -> void:
	dialogue_trees = {
		# --- SORBET KINGDOM ---
		"pastor_aide_luke": {
			"root": {
				"speaker": "Pastor Aide Luke",
				"text": "Peace be upon you, traveler. This humble church was Pastor Bartholomew Kuma's sanctuary—where he took the elders' pain into himself every week.",
				"choices": [
					{"label": "How can I help the Southern Commoners District?", "next_node": "alms_offer"},
					{"label": "Open Church Alms Dispensary.", "next_node": "open_shop", "action": {"type": "open_market", "market_id": "church_alms_apothecary"}},
					{"label": "Farewell.", "next_node": "END"}
				]
			},
			"alms_offer": {
				"speaker": "Pastor Aide Luke",
				"text": "Many elders still suffer from coastal chills and old Sapphire Scales scars. Bring 1 Blue Herb Sapphire Balm and 1 Sorbet Loaded Brick-Oven Pizza to King Bulldog's relief ward.",
				"choices": [
					{"label": "I will gather the alms and deliver them.", "next_node": "alms_accepted", "action": {"type": "start_quest", "quest_id": "quest_sorbet_sapphire_alms"}},
					{"label": "Maybe later.", "next_node": "END"}
				]
			},
			"alms_accepted": {
				"speaker": "Pastor Aide Luke",
				"text": "May Kuma's gentle strength guide your ship. Baker Michele in the Northern Citadel bakes the finest pizzas.",
				"choices": [{"label": "Understood.", "next_node": "END"}]
			},
			"open_shop": {
				"speaker": "Pastor Aide Luke",
				"text": "Our remedies are priced modestly for those in need.",
				"choices": [{"label": "Thank you.", "next_node": "END"}]
			}
		},

		"baker_michele": {
			"root": {
				"speaker": "Baker Michele",
				"text": "Fresh from the brick oven! Young Bonney used to eat three whole pies before noon—always with tomato sauce on her cheeks!",
				"choices": [
					{"label": "Browse Hearthside Bakery wares.", "next_node": "END", "action": {"type": "open_market", "market_id": "sorbet_royal_bakery"}},
					{"label": "Tell me about Bonney and Kuma.", "next_node": "lore"},
					{"label": "Leave.", "next_node": "END"}
				]
			},
			"lore": {
				"speaker": "Baker Michele",
				"text": "When that CP8 nurse Alpha kept her locked in the church, we smuggled pizzas through the back window. When Bonney turned ten, she broke right out and sailed with Gyogyo!",
				"choices": [{"label": "She's a fierce captain now.", "next_node": "END"}]
			}
		},

		"old_man_mizore": {
			"root": {
				"speaker": "Old Man Mizore",
				"text": "A fine day for hauling nets! We also pull strange cogwheels and World Government scrap from the outer shoals.",
				"choices": [
					{"label": "Browse Tackle & Salvage.", "next_node": "END", "action": {"type": "open_market", "market_id": "gyogyo_salvage_coop"}},
					{"label": "Leave.", "next_node": "END"}
				]
			}
		},

		"king_bulldog": {
			"root": {
				"speaker": "King Bulldog",
				"text": "Welcome to Sorbet Kingdom. We rebuilt these towers after Kuma's Solo Revolution drove out the tyrant Bekori.",
				"choices": [
					{"label": "I brought Sapphire Balm and warm provisions for the elders.", "next_node": "deliver_alms", "condition": {"type": "quest_stage_min", "quest_id": "quest_sorbet_sapphire_alms", "stage": 2}},
					{"label": "Ask about Sorbet's current politics.", "next_node": "politics"},
					{"label": "Farewell, Your Majesty.", "next_node": "END"}
				]
			},
			"deliver_alms": {
				"speaker": "King Bulldog",
				"text": "You have a noble heart, sailor. Take these Beli and a preserved scripture leaf in Kuma's honor.",
				"choices": [{"label": "Long live Sorbet.", "next_node": "END", "action": {"type": "complete_quest", "quest_id": "quest_sorbet_sapphire_alms"}}]
			},
			"politics": {
				"speaker": "King Bulldog",
				"text": "The World Government watches our shores closely, yet my mother Conney and I refuse to let any citizen be cast aside again.",
				"choices": [{"label": "I respect your resolve.", "next_node": "END"}]
			}
		},

		"queen_dowager_conney": {
			"root": {
				"speaker": "Queen Dowager Conney",
				"text": "Hmph! Don't stare so hard—yes, Bonney borrows my face when she ages herself up! Worked like a charm at Mary Geoise, I hear.",
				"choices": [
					{"label": "Tell me about Kuma's heritage.", "next_node": "buccaneer"},
					{"label": "Good day, Queen Mother.", "next_node": "END"}
				]
			},
			"buccaneer": {
				"speaker": "Queen Dowager Conney",
				"text": "Keep your voice low. The Buccaneers carry the blood of giants and the rhythm of the Sun God. The World Government fears that memory above all else.",
				"choices": [{"label": "I will guard that secret.", "next_node": "END", "action": {"type": "grant_reputation", "faction_id": "sorbet_monarchy", "amount": 5}}]
			}
		},

		"fisherman_gyogyo_elder": {
			"root": {
				"speaker": "Elder Gyogyo",
				"text": "Our little Bonney grew up fast on these docks. If you're sailing north toward Reverse Mountain, reinforce your keel first!",
				"choices": [
					{"label": "Any advice for the Reverse Mountain canal?", "next_node": "canal_tip"},
					{"label": "See you on the tide.", "next_node": "END"}
				]
			},
			"canal_tip": {
				"speaker": "Elder Gyogyo",
				"text": "Head northwest past Centaurea to Lat -15.5, Lon 1.2. Once the Red Line walls close in, keep your helm dead center!",
				"choices": [{"label": "Thanks for the chart bearing.", "next_node": "END"}]
			}
		},

		# --- BATERILLA ---
		"village_elder_nora": {
			"root": {
				"speaker": "Elder Nora",
				"text": "Smell the pink hibiscus, traveler. Twenty-two years ago, Portgas D. Rouge walked these bluffs carrying the Pirate King's child for twenty impossible months.",
				"choices": [
					{"label": "Tell me about Gol D. Roger's time here.", "next_node": "roger_lore"},
					{"label": "Ask about local flowers and shops.", "next_node": "shop_hint"},
					{"label": "Pay respects at the memorial.", "next_node": "END"}
				]
			},
			"roger_lore": {
				"speaker": "Elder Nora",
				"text": "He lived quietly, like an ordinary man in love. When Cipher Pol swept the island, Rouge's willpower alone kept Ace hidden until his birth.",
				"choices": [{"label": "A truly unbreakable will.", "next_node": "END", "action": {"type": "grant_reputation", "faction_id": "baterilla_elders", "amount": 5}}]
			},
			"shop_hint": {
				"speaker": "Elder Nora",
				"text": "Madame Florence at Hibiscus Port presses genuine South Blue Pink Hibiscus blooms—the very kind Rouge wore in her hair.",
				"choices": [{"label": "I'll visit Hibiscus Port.", "next_node": "END"}]
			}
		},

		"retired_marine_garland": {
			"root": {
				"speaker": "Warrant Officer Garland (Retired)",
				"text": "I took off my Marine coat after the Baterilla inquisitions. Hunting innocent mothers isn't justice.",
				"choices": [
					{"label": "Are Cipher Pol ships still patrolling nearby?", "next_node": "patrols"},
					{"label": "Carry on, veteran.", "next_node": "END"}
				]
			},
			"patrols": {
				"speaker": "Warrant Officer Garland (Retired)",
				"text": "They lurk near Centaurea and the South Calm Belt border. Keep an encrypted transponder if you trade with the Revolutionaries.",
				"choices": [{"label": "Good warning.", "next_node": "END"}]
			}
		},

		# --- TORINO KINGDOM ---
		"chief_shanba": {
			"root": {
				"speaker": "Chief Shanba",
				"text": "Welcome to Torino, the Isle of Treasure! Our true wealth lies in the 1,250-meter Tree of Life and our Stone Botanical Library.",
				"choices": [
					{"label": "I heard Chopper studied medicine here.", "next_node": "chopper_lore"},
					{"label": "Can I assist your medical research?", "next_node": "quest_offer"},
					{"label": "Deliver the canopy herbs.", "next_node": "turn_in", "condition": {"type": "quest_stage_min", "quest_id": "quest_torino_canopy_remedy", "stage": 2}},
					{"label": "Open Shanba's Herbal Dispensary.", "next_node": "END", "action": {"type": "open_market", "market_id": "torino_tribal_pharmacy"}},
					{"label": "Farewell.", "next_node": "END"}
				]
			},
			"chopper_lore": {
				"speaker": "Chief Shanba",
				"text": "The little tanuki doctor healed our Masked Goayu birds and ended a century-old feud! He studied our archives for two years to refine his Rumble Balls.",
				"choices": [{"label": "Remarkable.", "next_node": "END"}]
			},
			"quest_offer": {
				"speaker": "Chief Shanba",
				"text": "Ascend to the +1,100m canopy, earn the Matriarch bird's trust, and bring Golden Root Essence and Bioluminescent Spores back to the library.",
				"choices": [
					{"label": "I will climb the Great Tree.", "next_node": "END", "action": {"type": "start_quest", "quest_id": "quest_torino_canopy_remedy"}},
					{"label": "Not right now.", "next_node": "END"}
				]
			},
			"turn_in": {
				"speaker": "Chief Shanba",
				"text": "Splendid specimens! Take our transcribed Torino Botanical Compendium—it will serve your ship's doctor well.",
				"choices": [{"label": "Thank you, Chief Shanba.", "next_node": "END", "action": {"type": "complete_quest", "quest_id": "quest_torino_canopy_remedy"}}]
			}
		},

		"goayu_elder_bird": {
			"root": {
				"speaker": "Matriarch Masked Goayu",
				"text": "(The colossal 15-meter bird spreads her iridescent wings, eyeing you with calm, ancient intelligence.)",
				"choices": [
					{"label": "Bow respectfully and offer canopy berries.", "next_node": "trust", "action": {"type": "advance_quest", "quest_id": "quest_torino_canopy_remedy", "stage": 2}},
					{"label": "Inspect Sky-Saddle Outpost.", "next_node": "END", "action": {"type": "open_market", "market_id": "canopy_aviary_exchange"}},
					{"label": "Step back quietly.", "next_node": "END"}
				]
			},
			"trust": {
				"speaker": "Matriarch Masked Goayu",
				"text": "(She lets out a resonant trill and bows her masked head, granting you safe passage among the high nests.)",
				"choices": [{"label": "Honored to fly beside you.", "next_node": "END", "action": {"type": "grant_reputation", "faction_id": "torino_scholars", "amount": 10}}]
			}
		},

		# --- KARATE ISLAND ---
		"grandmaster_dohyo": {
			"root": {
				"speaker": "Grandmaster Dohyo",
				"text": "A fist without spirit is merely wind! Here on Karate Island, warriors temper bone and breath beneath the Ten-Thousand Ton Waterfall.",
				"choices": [
					{"label": "I wish to take the Black Belt certification trial.", "next_node": "trial_offer"},
					{"label": "I have endured the waterfall and trained with wraps.", "next_node": "trial_complete", "condition": {"type": "quest_stage_min", "quest_id": "quest_karate_waterfall_trial", "stage": 2}},
					{"label": "Open Grandmaster's Martial Outfitters.", "next_node": "END", "action": {"type": "open_market", "market_id": "black_belt_armory"}},
					{"label": "Bow and depart.", "next_node": "END"}
				]
			},
			"trial_offer": {
				"speaker": "Grandmaster Dohyo",
				"text": "First, spar with Max 'Thunder-Jab' at the Boxing Academy and acquire Iron-Thread Black Belt Hand Wraps. Then meditate beneath the waterfall shrine!",
				"choices": [
					{"label": "I accept the 10,000-Ton Waterfall Trial.", "next_node": "END", "action": {"type": "start_quest", "quest_id": "quest_karate_waterfall_trial"}},
					{"label": "I need more preparation.", "next_node": "END"}
				]
			},
			"trial_complete": {
				"speaker": "Grandmaster Dohyo",
				"text": "Your stance did not waver against the cataract! Receive your Karate Island Black Belt Certification and the foundations of Iron Body.",
				"choices": [{"label": "Osu! Thank you, Grandmaster.", "next_node": "END", "action": {"type": "complete_quest", "quest_id": "quest_karate_waterfall_trial"}}]
			}
		},

		"sparring_boxer_max": {
			"root": {
				"speaker": "Max 'Thunder-Jab'",
				"text": "Keep your chin tucked! I used to spar with Jerry before Cipher Pol poached him for CP6. Tall guy had springs for legs, terrible rib guard though!",
				"choices": [
					{"label": "Show me your boxing footwork.", "next_node": "spar"},
					{"label": "Browse Black Belt Armory.", "next_node": "END", "action": {"type": "open_market", "market_id": "black_belt_armory"}},
					{"label": "Catch you later.", "next_node": "END"}
				]
			},
			"spar": {
				"speaker": "Max 'Thunder-Jab'",
				"text": "Good snap on that jab! Grab yourself a pair of Iron-Thread Hand Wraps and head up to the waterfall.",
				"choices": [{"label": "Will do!", "next_node": "END", "action": {"type": "grant_reputation", "faction_id": "karate_confederacy", "amount": 5}}]
			}
		},

		# --- EVIL BLACK DRUM KINGDOM ---
		"king_wapol": {
			"root": {
				"speaker": "King Wapol",
				"text": "Bwahahaha! Look upon my Black Drum Castle! Straw Hat thought he ruined me, but Wapometal made Wapol Konzern richer than five kingdoms!",
				"choices": [
					{"label": "I want a Wapometal metallurgy contract.", "next_node": "contract"},
					{"label": "Complete Wapometal Foundry Contract.", "next_node": "complete_contract", "condition": {"type": "quest_stage_min", "quest_id": "quest_wapol_wapometal_contract", "stage": 1}},
					{"label": "Access Wapol Konzern Metallurgical Bureau.", "next_node": "END", "action": {"type": "open_market", "market_id": "wapometal_tech_exchange"}},
					{"label": "Leave the throne room.", "next_node": "END"}
				]
			},
			"contract": {
				"speaker": "King Wapol",
				"text": "Hmph! Buy two Pure Wapometal Ingots or smelt them into Wapometal Hull Plating at my foundry, and I'll sign your merchant patent!",
				"choices": [
					{"label": "Deal, King Wapol.", "next_node": "END", "action": {"type": "start_quest", "quest_id": "quest_wapol_wapometal_contract"}},
					{"label": "Too rich for me.", "next_node": "END"}
				]
			},
			"complete_contract": {
				"speaker": "King Wapol",
				"text": "Now THAT is proper Wapol Konzern quality! Take your tariff rebate and a Wind-Up Soldier!",
				"choices": [{"label": "Pleasure doing business.", "next_node": "END", "action": {"type": "complete_quest", "quest_id": "quest_wapol_wapometal_contract"}}]
			}
		},

		"queen_kinderella": {
			"root": {
				"speaker": "Queen Kinderella",
				"text": "Everything in Evil Black Drum must glitter! If it lacks elegance, Wapol simply munches it into scrap toys.",
				"choices": [
					{"label": "Browse Haute Couture Boutique.", "next_node": "END", "action": {"type": "open_market", "market_id": "kinderella_boutique"}},
					{"label": "Your Majesty.", "next_node": "END"}
				]
			}
		},

		# --- BRISS KINGDOM ---
		"historian_valerie": {
			"root": {
				"speaker": "Curator Valerie",
				"text": "Two hundred and eight years ago, the galleon St. Briss sailed from these very drydocks—and soared into the White-White Sea above the clouds!",
				"choices": [
					{"label": "How can I outfit my ship for extreme altitudes?", "next_node": "rigging_quest"},
					{"label": "I've reviewed the shipyards and secured St. Briss rigging.", "next_node": "turn_in", "condition": {"type": "quest_stage_min", "quest_id": "quest_st_briss_sky_rigging", "stage": 2}},
					{"label": "Visit St. Briss Master Shipwright Guild.", "next_node": "END", "action": {"type": "open_market", "market_id": "briss_historical_shipwrights"}},
					{"label": "Farewell.", "next_node": "END"}
				]
			},
			"rigging_quest": {
				"speaker": "Curator Valerie",
				"text": "Study our ancient enamel tar preservation and commission St. Briss Atmospheric Storm Rigging from our master shipwrights.",
				"choices": [
					{"label": "I'll prepare the ship for the sky currents.", "next_node": "END", "action": {"type": "start_quest", "quest_id": "quest_st_briss_sky_rigging"}},
					{"label": "Later.", "next_node": "END"}
				]
			},
			"turn_in": {
				"speaker": "Curator Valerie",
				"text": "Magnificent! Should you ever ride a Knock Up Stream near Jaya, remember the explorers of Briss!",
				"choices": [{"label": "I will carry their banner.", "next_node": "END", "action": {"type": "complete_quest", "quest_id": "quest_st_briss_sky_rigging"}}]
			}
		},

		# --- KUTSUKKU ISLAND ---
		"gang_veteran_slash": {
			"root": {
				"speaker": "Slash the Spike",
				"text": "Watch your boots on this scrap iron! Kid, Killer, Heat, and Wire tore the old syndicate to ribbons right here after they killed Doruyanaika.",
				"choices": [
					{"label": "Tell me about Victoria Shiruton Doruyanaika.", "next_node": "victoria_lore"},
					{"label": "I brought a South Blue Pink Hibiscus for her memorial.", "next_node": "turn_in_hibiscus", "condition": {"type": "has_item", "item_id": "south_blue_hibiscus", "count": 1}},
					{"label": "Browse Victoria Punk Custom Ironworks.", "next_node": "END", "action": {"type": "open_market", "market_id": "punk_scrap_forge"}},
					{"label": "Move along.", "next_node": "END"}
				]
			},
			"victoria_lore": {
				"speaker": "Slash the Spike",
				"text": "She beat Kid and Killer black and blue over a bowl of curry udon once. When the mob took her out, the four gangs united and launched the Victoria Punk. Bring a hibiscus from Baterilla if you want to pay respects.",
				"choices": [
					{"label": "I'll bring a hibiscus to her lookout.", "next_node": "END", "action": {"type": "start_quest", "quest_id": "quest_victoria_memorial_tribute"}},
					{"label": "Respect.", "next_node": "END"}
				]
			},
			"turn_in_hibiscus": {
				"speaker": "Slash the Spike",
				"text": "Hah... Kid would've grunted, and Killer would've nodded. Here—take this metal plaque and some Beli from the gang vault.",
				"choices": [{"label": "Rest in peace, Victoria.", "next_node": "END", "action": {"type": "complete_quest", "quest_id": "quest_victoria_memorial_tribute"}}]
			}
		},

		# --- CENTAUREA & TUMI ---
		"commander_caspian": {
			"root": {
				"speaker": "Commander Caspian",
				"text": "Centaurea stands free of Heavenly Tribute! Our Revolutionary cells across South Blue depend on fast, discreet captains.",
				"choices": [
					{"label": "Any covert supply missions?", "next_node": "beacon_offer"},
					{"label": "Open Centaurea Cooperative Supply.", "next_node": "END", "action": {"type": "open_market", "market_id": "revolutionary_cache_exchange"}},
					{"label": "Long live the Revolution.", "next_node": "END"}
				]
			},
			"beacon_offer": {
				"speaker": "Commander Caspian",
				"text": "Pick up an Encrypted White Den Den Mushi Receiver, deliver relief to Elder Bram in Tumi, and check in with Pilot Gordon at Reverse Mountain's South Gateway.",
				"choices": [
					{"label": "Count me in for Liberator's Beacon.", "next_node": "END", "action": {"type": "start_quest", "quest_id": "quest_liberators_beacon"}},
					{"label": "Too hot for me.", "next_node": "END"}
				]
			}
		},

		"rebel_elder_bram": {
			"root": {
				"speaker": "Elder Bram",
				"text": "Look at that paw-shaped crater in the mountain! When royal cannons shelled our families, Bartholomew Kuma pushed every shell back into the sky!",
				"choices": [
					{"label": "I carry Revolutionary supplies from Commander Caspian.", "next_node": "deliver_tumi", "condition": {"type": "quest_stage_min", "quest_id": "quest_liberators_beacon", "stage": 1}},
					{"label": "Open Tumi Highland Depot.", "next_node": "END", "action": {"type": "open_market", "market_id": "tumi_alpine_apothecary"}},
					{"label": "Farewell, Elder.", "next_node": "END"}
				]
			},
			"deliver_tumi": {
				"speaker": "Elder Bram",
				"text": "Bless you! Now make haste northwest to Master Pilot Gordon at Reverse Mountain's South Gateway before Cipher Pol closes the meridian.",
				"choices": [{"label": "Setting sail!", "next_node": "END", "action": {"type": "advance_quest", "quest_id": "quest_liberators_beacon", "stage": 2}}]
			}
		},

		# --- VESPA / TAYA / SAMUWANAI ---
		"fisherman_torkel": {
			"root": {
				"speaker": "Old Man Torkel",
				"text": "Brrr! Young Kuzan used to nap right on this seawall, talking about 'Lazy Justice' before pedaling his bicycle across the frozen bay!",
				"choices": [
					{"label": "Browse Vespa Polar Outfitters.", "next_node": "END", "action": {"type": "open_market", "market_id": "vespa_fjord_outfitters"}},
					{"label": "Stay warm, Torkel.", "next_node": "END"}
				]
			}
		},

		"chief_inspector_gentatsu": {
			"root": {
				"speaker": "Chief Inspector Gentatsu",
				"text": "Keep order in the bamboo groves. Aramaki—whom the Marines now call Admiral Ryokugyu—once patrolled these precincts before his three-year prison fast.",
				"choices": [
					{"label": "Browse Taya Armory & Bamboo Works.", "next_node": "END", "action": {"type": "open_market", "market_id": "taya_bamboo_forge"}},
					{"label": "Understood, Inspector.", "next_node": "END"}
				]
			}
		},

		"bathmaster_tomi": {
			"root": {
				"speaker": "Bathmaster Tomi",
				"text": "Icebergs drift outside the bay, yet nobody ever catches a cold at Ida's hearth in Samuwanai! Step into the sulfur springs.",
				"choices": [
					{"label": "Browse Ida's Mineral Springs & Mud Depot.", "next_node": "END", "action": {"type": "open_market", "market_id": "samuwanai_thermal_bazaar"}},
					{"label": "Thank you, Bathmaster.", "next_node": "END"}
				]
			}
		},

		# --- REVERSE MOUNTAIN SOUTH GATEWAY ---
		"canal_master_gordon": {
			"root": {
				"speaker": "Master Pilot Gordon",
				"text": "That roaring 400-meter flume climbs 5,000 meters up the Red Line at 85 meters per second! Check your keel before you enter!",
				"choices": [
					{"label": "Report Revolutionary Beacon readiness.", "next_node": "complete_beacon", "condition": {"type": "quest_stage_min", "quest_id": "quest_liberators_beacon", "stage": 2}},
					{"label": "Open Upward Surge Shipwright & Tackle.", "next_node": "END", "action": {"type": "open_market", "market_id": "reverse_staging_outfitters"}},
					{"label": "Ready the helm!", "next_node": "END"}
				]
			},
			"complete_beacon": {
				"speaker": "Master Pilot Gordon",
				"text": "Caspian's coded signal came through loud and clear! Your route through the South Canal is cleared—aim straight for Twin Cape!",
				"choices": [{"label": "To the Grand Line!", "next_node": "END", "action": {"type": "complete_quest", "quest_id": "quest_liberators_beacon"}}]
			}
		}
	}

## Starts a branching dialogue session with a South Blue NPC.
func start_dialogue(npc_id: String) -> Dictionary:
	if not dialogue_trees.has(npc_id):
		var npc_info: Dictionary = SouthBlueData.get_npc(npc_id)
		if npc_info.is_empty():
			return {"success": false, "reason": "No dialogue tree or NPC record for '%s'." % npc_id}
		# Fallback generic presentation using SouthBlueData hooks
		var hooks: Array = npc_info.get("dialogue_hooks", ["Greetings, traveler."])
		var fallback_node: Dictionary = {
			"speaker": npc_info.get("name", npc_id),
			"text": hooks[0] if not hooks.is_empty() else "Fair winds in the South Blue.",
			"choices": [{"label": "Farewell.", "next_node": "END"}]
		}
		active_dialogue = {"active": true, "npc_id": npc_id, "npc_name": npc_info.get("name", npc_id), "current_node_id": "root"}
		dialogue_started.emit(npc_id, active_dialogue["npc_name"], "root")
		dialogue_node_presented.emit(npc_id, fallback_node)
		return {"success": true, "node": fallback_node}

	var npc_record: Dictionary = SouthBlueData.get_npc(npc_id)
	var root_speaker: String = dialogue_trees[npc_id]["root"].get("speaker", npc_id)
	var display_name: String = npc_record.get("name", root_speaker)
	active_dialogue = {
		"active": true,
		"npc_id": npc_id,
		"npc_name": display_name,
		"current_node_id": "root"
	}
	dialogue_started.emit(npc_id, display_name, "root")
	var filtered: Dictionary = _filter_dialogue_node(dialogue_trees[npc_id]["root"])
	dialogue_node_presented.emit(npc_id, filtered)
	return {"success": true, "node": filtered}

## Selects a dialogue choice index and advances or ends the conversation.
func select_dialogue_choice(choice_index: int) -> Dictionary:
	if not active_dialogue.get("active", false):
		return {"success": false, "reason": "No active dialogue."}

	var npc_id: String = active_dialogue["npc_id"]
	var node_id: String = active_dialogue["current_node_id"]
	if not dialogue_trees.has(npc_id) or not dialogue_trees[npc_id].has(node_id):
		end_dialogue()
		return {"success": true, "ended": true}

	var current_node: Dictionary = _filter_dialogue_node(dialogue_trees[npc_id][node_id])
	var choices: Array = current_node.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return {"success": false, "reason": "Invalid choice index."}

	var chosen: Dictionary = choices[choice_index]
	var action_result: Dictionary = {}
	if chosen.has("action"):
		action_result = _execute_dialogue_action(chosen["action"])

	var next_id: String = chosen.get("next_node", "END")
	if next_id == "END" or not dialogue_trees[npc_id].has(next_id):
		end_dialogue()
		return {"success": true, "ended": true, "action_result": action_result}

	active_dialogue["current_node_id"] = next_id
	var next_node: Dictionary = _filter_dialogue_node(dialogue_trees[npc_id][next_id])
	dialogue_node_presented.emit(npc_id, next_node)
	return {"success": true, "ended": false, "node": next_node, "action_result": action_result}

func end_dialogue() -> void:
	if active_dialogue.get("active", false):
		var npc_id: String = active_dialogue["npc_id"]
		active_dialogue = {"active": false, "npc_id": "", "npc_name": "", "current_node_id": ""}
		dialogue_ended.emit(npc_id)

func _filter_dialogue_node(node_data: Dictionary) -> Dictionary:
	var out: Dictionary = {
		"speaker": node_data.get("speaker", ""),
		"text": node_data.get("text", ""),
		"choices": []
	}
	for ch in node_data.get("choices", []):
		if not ch.has("condition") or _evaluate_condition(ch["condition"]):
			out["choices"].append(ch)
	return out

func _evaluate_condition(cond: Dictionary) -> bool:
	var c_type: String = cond.get("type", "")
	match c_type:
		"quest_stage_min":
			var qid: String = cond.get("quest_id", "")
			var min_stage: int = int(cond.get("stage", 0))
			if not quests.has(qid):
				return false
			var q: Dictionary = quests[qid]
			return q["state"] in [QuestState.ACTIVE, QuestState.READY_TO_TURN_IN] and int(q["stage"]) >= min_stage
		"has_item":
			return get_item_count(cond.get("item_id", "")) >= int(cond.get("count", 1))
	return true

func _execute_dialogue_action(action: Dictionary) -> Dictionary:
	var a_type: String = action.get("type", "")
	match a_type:
		"start_quest":
			return {"quest_started": start_quest(action.get("quest_id", ""))}
		"advance_quest":
			return {"quest_advanced": advance_quest(action.get("quest_id", ""), int(action.get("stage", -1)))}
		"complete_quest":
			return complete_quest(action.get("quest_id", ""))
		"open_market":
			var m_id: String = action.get("market_id", "")
			return {"open_market_id": m_id, "inventory": get_market_inventory_with_pricing(m_id)}
		"grant_reputation":
			var f_id: String = action.get("faction_id", "")
			var amt: int = int(action.get("amount", 0))
			return {"faction_id": f_id, "new_reputation": adjust_reputation(f_id, amt)}
	return {}
