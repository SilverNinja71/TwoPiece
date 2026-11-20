# north_blue_gameplay.gd
# Phase 2 Interactive Gameplay, Dialogue, Marketplace & Quest Controller for North Blue
# Driven by NorthBlueData (res://regions/north_blue_data.gd) and integrated with
# WorldRegistry & StoryCampaignManager autoloads.
class_name NorthBlueGameplay
extends Node

# ==============================================================================
# SIGNALS
# ==============================================================================
signal shop_transaction_completed(shop_id: String, item_id: String, quantity: int, total_beli: int, is_buy: bool)
signal shop_transaction_failed(shop_id: String, item_id: String, reason: String)
signal amber_lead_hazard_triggered(severity: float, message: String)
signal raid_tech_crafted(recipe_id: String, item_name: String)
signal dialogue_started(npc_id: String, node_data: Dictionary)
signal dialogue_ended(npc_id: String)
signal quest_updated(quest_id: String, new_stage: String, quest_data: Dictionary)
signal germa_fleet_intercepted(fleet_state: Dictionary)

# ==============================================================================
# CONSTANTS & ENUMS
# ==============================================================================
enum QuestStage {
	NOT_STARTED = 0,
	IN_PROGRESS = 1,
	COMPLETED = 2
}

const AMBER_LEAD_TOXIC_ITEMS: Array[String] = [
	"ore_raw_amber_lead",
	"item_flevance_lead_paint"
]

const RAID_TECH_RECIPES: Dictionary = {
	"raid_stealth_cloak_mk2": {
		"name": "Germa Stealth Cloak Mk.II",
		"cost_beli": 150000,
		"ingredients": {
			"gear_shape_memory_alloy_sheet": 1,
			"potion_germa_clone_stimulant": 1
		},
		"description": "Optical-camouflage shape-memory cloak engineered from Germa 66 alloys."
	},
	"raid_sparking_gauntlets": {
		"name": "Sparking Red Impact Gauntlets",
		"cost_beli": 210000,
		"ingredients": {
			"gear_shape_memory_alloy_sheet": 2,
			"weapon_electromagnetic_spear": 1
		},
		"description": "High-voltage melee gauntlets channeling electromagnetic discharge."
	},
	"raid_jet_propulsion_harness": {
		"name": "Germa Aerial Thruster Harness",
		"cost_beli": 320000,
		"ingredients": {
			"gear_shape_memory_alloy_sheet": 2,
			"boots_germa_hover_propulsion": 1
		},
		"description": "Sustained aerial boost harness capable of clearing 350m Red Line ledges."
	}
}

# ==============================================================================
# RUNTIME STATE
# ==============================================================================
## Player inventory for North Blue items: item_id -> int quantity
var player_inventory: Dictionary = {}

## Amber Lead accumulated toxicity (0.0 to 100.0)
var amber_lead_toxicity: float = 0.0

## Active world simulation time in hours (drives Germa mobile fleet)
var simulation_time_hours: float = 0.0

## Unlocked lore & gameplay flags
var lore_flags: Dictionary = {
	"sky_island_foreshadowed": false,
	"amber_lead_truth_uncovered": false,
	"polar_tang_blueprint_unlocked": false,
	"germa_bloodline_data_stolen": false,
	"reverse_mountain_canal_charted": false
}

## Quest State Machines
var quests: Dictionary = {}

## Branching Dialogue Trees keyed by npc_id
var _dialogue_trees: Dictionary = {}

# ==============================================================================
# LIFECYCLE
# ==============================================================================
func _ready() -> void:
	_initialize_quests()
	_initialize_dialogue_trees()

func _process(delta: float) -> void:
	# Advance simulation clock (1 real minute = 1 in-game hour)
	simulation_time_hours += delta / 60.0
	_tick_amber_lead_hazard(delta)

# ==============================================================================
# AUTOLOAD HELPERS (Safe access when running standalone or in scene tree)
# ==============================================================================
func _get_world_registry() -> Node:
	if has_node("/root/WorldRegistry"):
		return get_node("/root/WorldRegistry")
	return null

func _get_campaign_manager() -> Node:
	if has_node("/root/StoryCampaignManager"):
		return get_node("/root/StoryCampaignManager")
	return null

func _get_player_beli() -> int:
	var wr: Node = _get_world_registry()
	if wr != null and "wallet" in wr:
		return int(wr.wallet.get("Beli", 0))
	return 500000 # Fallback for isolated testing

func _spend_beli(amount: int) -> bool:
	var wr: Node = _get_world_registry()
	if wr != null and wr.has_method("spend_currency"):
		return bool(wr.spend_currency("Beli", amount))
	return true

func _add_beli(amount: int) -> void:
	var wr: Node = _get_world_registry()
	if wr != null and wr.has_method("add_currency"):
		wr.add_currency("Beli", amount)

# ==============================================================================
# MARKETPLACE & BLACK-MARKET TRANSACTION CONTROLLERS
# ==============================================================================

## Finds a shop dictionary by shop_id from NorthBlueData.
func find_shop(shop_id: String) -> Dictionary:
	var markets: Array = NorthBlueData.get_all_marketplaces()
	for market: Dictionary in markets:
		if market.get("id", "") == shop_id:
			return market
	return {}

## Purchases an item from a North Blue shop or black market using Beli.
func buy_item(shop_id: String, item_id: String, quantity: int = 1) -> Dictionary:
	if quantity <= 0:
		shop_transaction_failed.emit(shop_id, item_id, "Invalid quantity.")
		return {"success": false, "reason": "Invalid quantity."}

	var shop: Dictionary = find_shop(shop_id)
	if shop.is_empty():
		shop_transaction_failed.emit(shop_id, item_id, "Shop not found.")
		return {"success": false, "reason": "Shop not found."}

	var target_item: Dictionary = {}
	for entry: Dictionary in shop.get("inventory", []):
		if entry.get("item_id", "") == item_id:
			target_item = entry
			break

	if target_item.is_empty():
		shop_transaction_failed.emit(shop_id, item_id, "Item not carried by this vendor.")
		return {"success": false, "reason": "Item not carried by this vendor."}

	var stock: int = int(target_item.get("stock", 0))
	if stock < quantity:
		shop_transaction_failed.emit(shop_id, item_id, "Insufficient stock.")
		return {"success": false, "reason": "Insufficient stock."}

	var unit_price: int = int(target_item.get("price_beli", 0))
	var total_cost: int = unit_price * quantity

	# Amber Lead Containment Check
	if item_id in AMBER_LEAD_TOXIC_ITEMS and not has_lead_containment():
		amber_lead_hazard_triggered.emit(
			0.75,
			"WARNING: Purchasing Amber Lead without a Lead-Lined Smuggling Locker exposes your crew to heavy-metal toxicity!"
		)

	if not _spend_beli(total_cost):
		shop_transaction_failed.emit(shop_id, item_id, "Insufficient Beli.")
		return {"success": false, "reason": "Insufficient Beli.", "required_beli": total_cost}

	# Grant item to player inventory
	player_inventory[item_id] = int(player_inventory.get(item_id, 0)) + quantity

	# Special item hooks
	_handle_special_purchase_hooks(item_id)

	shop_transaction_completed.emit(shop_id, item_id, quantity, total_cost, true)
	return {
		"success": true,
		"shop_id": shop_id,
		"item_id": item_id,
		"quantity": quantity,
		"total_beli": total_cost
	}

## Sells an item from player inventory at a regional shop (applies trade_multiplier if exported).
func sell_item(shop_id: String, item_id: String, quantity: int = 1) -> Dictionary:
	if quantity <= 0 or int(player_inventory.get(item_id, 0)) < quantity:
		shop_transaction_failed.emit(shop_id, item_id, "Insufficient inventory to sell.")
		return {"success": false, "reason": "Insufficient inventory to sell."}

	var shop: Dictionary = find_shop(shop_id)
	if shop.is_empty():
		shop_transaction_failed.emit(shop_id, item_id, "Shop not found.")
		return {"success": false, "reason": "Shop not found."}

	var item_record: Dictionary = _lookup_item_in_north_blue(item_id)
	var base_price: int = int(item_record.get("price_beli", 1000))
	var multiplier: float = float(item_record.get("trade_multiplier", 1.0))
	var origin_island: String = str(item_record.get("island_id", ""))
	var target_island: String = str(shop.get("island_id", ""))

	# Arbitrage bonus if sold outside its origin island
	var sale_ratio: float = 0.55 if origin_island == target_island else (0.75 * multiplier)
	var payout_beli: int = int(round(float(base_price) * sale_ratio)) * quantity

	player_inventory[item_id] = int(player_inventory.get(item_id, 0)) - quantity
	if int(player_inventory[item_id]) <= 0:
		player_inventory.erase(item_id)

	_add_beli(payout_beli)
	shop_transaction_completed.emit(shop_id, item_id, quantity, payout_beli, false)
	return {
		"success": true,
		"shop_id": shop_id,
		"item_id": item_id,
		"quantity": quantity,
		"payout_beli": payout_beli
	}

## Returns true if the player owns a Lead-Lined Smuggling Locker from Spider Miles.
func has_lead_containment() -> bool:
	return int(player_inventory.get("item_lead_lined_smuggling_crate", 0)) > 0

## Returns true if the player owns a Military Charcoal Dust Mask for Flevance exploration.
func has_dust_respirator() -> bool:
	return int(player_inventory.get("item_lead_filter_respirator", 0)) > 0

## Crafts high-tier Germa 66 Raid Tech equipment at the Germa Science Directorate.
func craft_raid_tech(recipe_id: String) -> Dictionary:
	if not RAID_TECH_RECIPES.has(recipe_id):
		return {"success": false, "reason": "Unknown Raid Tech recipe."}

	var recipe: Dictionary = RAID_TECH_RECIPES[recipe_id]
	var ingredients: Dictionary = recipe.get("ingredients", {})

	for req_id: String in ingredients:
		var req_qty: int = int(ingredients[req_id])
		if int(player_inventory.get(req_id, 0)) < req_qty:
			return {"success": false, "reason": "Missing ingredient: " + req_id}

	var cost: int = int(recipe.get("cost_beli", 0))
	if not _spend_beli(cost):
		return {"success": false, "reason": "Insufficient Beli for foundry calibration."}

	for req_id: String in ingredients:
		var req_qty: int = int(ingredients[req_id])
		player_inventory[req_id] = int(player_inventory[req_id]) - req_qty
		if int(player_inventory[req_id]) <= 0:
			player_inventory.erase(req_id)

	player_inventory[recipe_id] = int(player_inventory.get(recipe_id, 0)) + 1
	raid_tech_crafted.emit(recipe_id, str(recipe.get("name", recipe_id)))
	return {"success": true, "recipe_id": recipe_id, "name": recipe.get("name", "")}

func _lookup_item_in_north_blue(item_id: String) -> Dictionary:
	var goods: Array = NorthBlueData.get_all_trade_goods()
	for g: Dictionary in goods:
		if g.get("item_id", "") == item_id:
			return g
	return {}

func _handle_special_purchase_hooks(item_id: String) -> void:
	var cm: Node = _get_campaign_manager()
	if item_id == "upgrade_submarine_diving_ballast":
		lore_flags["polar_tang_blueprint_unlocked"] = true
		if cm != null and cm.has_method("install_ship_upgrade"):
			cm.install_ship_upgrade("submersible_ballast", "Polar Tang Pneumatic (-250m)")
		advance_quest("five_billion_beli_triangle", "COMPLETED")
	elif item_id == "seed_golden_pumpkin" or item_id == "wood_kona_tree_sap":
		if get_quest_stage("in_nolands_footsteps") == "BOTANICAL_SAMPLES":
			advance_quest("in_nolands_footsteps", "LOGBOOK_RECOVERY")
	elif item_id == "item_lead_filter_respirator":
		if get_quest_stage("white_city_quarantine") == "HAZMAT_PREPARATION":
			advance_quest("white_city_quarantine", "INFILTRATE_RUINS")
	elif item_id == "schematic_surgical_scalpel":
		lore_flags["amber_lead_truth_uncovered"] = true
		if get_quest_stage("white_city_quarantine") in ["INFILTRATE_RUINS", "RECOVER_MEDICAL_LEDGER"]:
			advance_quest("white_city_quarantine", "COMPLETED")

func _tick_amber_lead_hazard(delta: float) -> void:
	if has_lead_containment():
		amber_lead_toxicity = max(0.0, amber_lead_toxicity - delta * 0.5)
		return

	var has_toxic_cargo: bool = false
	for tid: String in AMBER_LEAD_TOXIC_ITEMS:
		if int(player_inventory.get(tid, 0)) > 0:
			has_toxic_cargo = true
			break

	if has_toxic_cargo:
		amber_lead_toxicity = min(100.0, amber_lead_toxicity + delta * 1.2)
		if amber_lead_toxicity >= 25.0:
			amber_lead_hazard_triggered.emit(
				amber_lead_toxicity / 100.0,
				"Unshielded Amber Lead ore is poisoning the crew! Acquire a Lead-Lined Smuggling Locker at Spider Miles."
			)

# ==============================================================================
# BRANCHING NPC DIALOGUE TREES
# ==============================================================================

func start_dialogue(npc_id: String, node_key: String = "root") -> Dictionary:
	if not _dialogue_trees.has(npc_id):
		return {"error": "No dialogue tree registered for NPC: " + npc_id}

	var tree: Dictionary = _dialogue_trees[npc_id]
	if not tree.has(node_key):
		return {"error": "Dialogue node not found: " + node_key}

	var node_data: Dictionary = tree[node_key].duplicate(true)
	dialogue_started.emit(npc_id, node_data)
	return node_data

func select_dialogue_choice(npc_id: String, current_node_key: String, choice_index: int) -> Dictionary:
	if not _dialogue_trees.has(npc_id):
		return {"ended": true}
	var tree: Dictionary = _dialogue_trees[npc_id]
	var current_node: Dictionary = tree.get(current_node_key, {})
	var choices: Array = current_node.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		dialogue_ended.emit(npc_id)
		return {"ended": true}

	var choice: Dictionary = choices[choice_index]
	_execute_dialogue_action(choice.get("action", {}))

	var next_key: String = str(choice.get("next", ""))
	if next_key.is_empty() or not tree.has(next_key):
		dialogue_ended.emit(npc_id)
		return {"ended": true}

	return start_dialogue(npc_id, next_key)

func _execute_dialogue_action(action: Dictionary) -> void:
	if action.is_empty():
		return
	var act_type: String = str(action.get("type", ""))
	match act_type:
		"start_quest":
			start_quest(str(action.get("quest_id", "")))
		"advance_quest":
			advance_quest(str(action.get("quest_id", "")), str(action.get("stage", "")))
		"set_flag":
			lore_flags[str(action.get("flag", ""))] = action.get("value", true)
		"grant_item":
			var item_id: String = str(action.get("item_id", ""))
			player_inventory[item_id] = int(player_inventory.get(item_id, 0)) + int(action.get("qty", 1))

func _initialize_dialogue_trees() -> void:
	_dialogue_trees = {
		# --- LVNEEL KINGDOM ---
		"npc_cedric_historian": {
			"root": {
				"speaker": "Cedric of the Northheim Archive",
				"text": "Four hundred years... and our kingdom still paints Mont Blanc Noland as a liar to soothe royal pride. Tell me, sailor—do you believe a Golden City could vanish into the clouds?",
				"choices": [
					{"label": "I believe Noland's logs. Tell me about the Northheim.", "next": "noland_logs", "action": {"type": "start_quest", "quest_id": "in_nolands_footsteps"}},
					{"label": "Only fools chase fairy tales in the sky.", "next": "cynic_reply", "action": {}},
					{"label": "Leave the tavern.", "next": "", "action": {}}
				]
			},
			"noland_logs": {
				"speaker": "Cedric of the Northheim Archive",
				"text": "In 1120, Noland sailed to Jaya and cured the Shandia of Tree Fever with Kona tree extract. Speak with Elena Ross at the Royal Botanical Exchange to gather matching specimens, then help me recover his missing logbook page.",
				"choices": [
					{"label": "I'll speak with Elena Ross.", "next": "", "action": {"type": "advance_quest", "quest_id": "in_nolands_footsteps", "stage": "BOTANICAL_SAMPLES"}}
				]
			},
			"cynic_reply": {
				"speaker": "Cedric of the Northheim Archive",
				"text": "Hmph. You sound like the spoiled youths over in Notice. Mark my words: the Knock Up Stream answers to no king's decree.",
				"choices": [{"label": "Farewell.", "next": "", "action": {}}]
			}
		},
		"npc_royal_botanist_elena": {
			"root": {
				"speaker": "Elena Ross",
				"text": "Welcome to the Lvneel Royal Botanical Exchange. Are you provisioning for the Calm Belt, or studying Noland's ancient flora?",
				"choices": [
					{"label": "I'm tracing Noland's botanical expedition.", "next": "botanical_lore", "action": {"type": "set_flag", "flag": "sky_island_foreshadowed", "value": true}},
					{"label": "Goodbye.", "next": "", "action": {}}
				]
			},
			"botanical_lore": {
				"speaker": "Elena Ross",
				"text": "Take our Golden Pumpkin Seeds or Kona Extract Ointment. If you ever reach Jaya in Paradise, look upward—ancient South Birds always point toward the sky!",
				"choices": [{"label": "Thank you, Curator.", "next": "", "action": {}}]
			}
		},

		# --- FLEVANCE RUINS ---
		"npc_kroll_scavenger": {
			"root": {
				"speaker": "Kroll the Masked",
				"text": "Keep that respirator strapped tight! The white dust of Flevance is Amber Lead—it doesn't rot your lungs overnight, it poisons your bloodline for generations.",
				"choices": [
					{"label": "What happened to Dr. Water's clinic?", "next": "clinic_info", "action": {"type": "start_quest", "quest_id": "white_city_quarantine"}},
					{"label": "Why do you still scavenge here?", "next": "scavenge_reason", "action": {}},
					{"label": "Step back.", "next": "", "action": {}}
				]
			},
			"clinic_info": {
				"speaker": "Kroll the Masked",
				"text": "The collapsed hospital sits beneath the central plaza. If you have a Charcoal Dust Mask, you can descend into the undercroft and recover the Water Family surgical schematics.",
				"choices": [
					{"label": "I'll recover the medical ledger.", "next": "", "action": {"type": "advance_quest", "quest_id": "white_city_quarantine", "stage": "RECOVER_MEDICAL_LEDGER"}}
				]
			},
			"scavenge_reason": {
				"speaker": "Kroll the Masked",
				"text": "Underworld armorers pay 45,000 Beli a chunk for raw Amber Lead. Just make sure you lock it inside a Lead-Lined Smuggling Crate from Spider Miles.",
				"choices": [{"label": "Understood.", "next": "", "action": {}}]
			}
		},

		# --- SPIDER MILES ---
		"npc_briggs_welder": {
			"root": {
				"speaker": "Iron-Jaw Briggs",
				"text": "Doflamingo's boys ruled this slag basin for ten years before heading to the Grand Line. You need steel plating or lead-lined lockers?",
				"choices": [
					{"label": "Tell me about Trafalgar Law's time here.", "next": "law_story", "action": {}},
					{"label": "Leave the forge.", "next": "", "action": {}}
				]
			},
			"law_story": {
				"speaker": "Iron-Jaw Briggs",
				"text": "Kid walked in strapped with grenades, eyes dead as winter. Corazon threw him out a window, yet still risked his life to steal the Op-Op Fruit at Minion Island.",
				"choices": [{"label": "A grim history.", "next": "", "action": {}}]
			}
		},

		# --- RUBECK / MINION / SWALLOW TRIANGLE ---
		"npc_bounty_broker_garrick": {
			"root": {
				"speaker": "Garrick the Ledger",
				"text": "Rubeck Harbor is crawling with Marines and bounty hunters. Sixteen years ago, Vice Admiral Tsuru anchored her fleet right outside this pier for a 5-billion-Beli trade.",
				"choices": [
					{"label": "Tell me about the 5-Billion-Beli Triangle.", "next": "triangle_brief", "action": {"type": "start_quest", "quest_id": "five_billion_beli_triangle"}},
					{"label": "Move along.", "next": "", "action": {}}
				]
			},
			"triangle_brief": {
				"speaker": "Garrick the Ledger",
				"text": "Barrels hid on Minion Island just northwest of here. Go see what remains of his fort, then sail on to Swallow Island where the survivor fled.",
				"choices": [
					{"label": "Setting sail for Minion Island.", "next": "", "action": {"type": "advance_quest", "quest_id": "five_billion_beli_triangle", "stage": "MINION_BIRDCAGE_SITE"}}
				]
			}
		},
		"npc_old_hatcher_trapper": {
			"root": {
				"speaker": "Hatcher the Hermit",
				"text": "Sixteen winters ago, the sky over Minion Island turned into a cage of razor strings. A tall man in black feathers died smiling beside a wooden chest.",
				"choices": [
					{"label": "Where did the boy in the chest go?", "next": "swallow_lead", "action": {}},
					{"label": "Leave the snowbank.", "next": "", "action": {}}
				]
			},
			"swallow_lead": {
				"speaker": "Hatcher the Hermit",
				"text": "He stumbled across the frozen strait toward Swallow Island. Look for an eccentric inventor named Wolf in Pleasure Town.",
				"choices": [
					{"label": "I'll find Wolf on Swallow Island.", "next": "", "action": {"type": "advance_quest", "quest_id": "five_billion_beli_triangle", "stage": "SWALLOW_POLAR_TANG"}}
				]
			}
		},
		"npc_inventor_wolf": {
			"root": {
				"speaker": "Wolf the Eccentric Inventor",
				"text": "Hahaha! Watch the steam valves! Law, Bepo, Shachi, and Penguin built the Polar Tang right in this drydock. Want to equip your hull with submarine ballast?",
				"choices": [
					{"label": "Yes! Show me the Polar Tang ballast blueprints.", "next": "ballast_offer", "action": {}},
					{"label": "How did you beat Artur Bacca?", "next": "bacca_story", "action": {}},
					{"label": "Maybe later.", "next": "", "action": {}}
				]
			},
			"ballast_offer": {
				"speaker": "Wolf the Eccentric Inventor",
				"text": "Purchase the Polar Tang Pneumatic Ballast System from my workshop catalog for 350,000 Beli and your ship will dive 250 meters beneath the waves!",
				"choices": [{"label": "I'll check your workshop inventory.", "next": "", "action": {}}]
			},
			"bacca_story": {
				"speaker": "Wolf the Eccentric Inventor",
				"text": "My son Bacca used the Melt-Melt Fruit to terrorize Pleasure Town, until Law awakened his Room and sliced his ambitions in half.",
				"choices": [{"label": "A true surgeon.", "next": "", "action": {}}]
			}
		},

		# --- NOTICE ---
		"npc_claude_couturier": {
			"root": {
				"speaker": "Claude the Couturier",
				"text": "Welcome to Notice! Bellamy and Sarquiss used to buy their velvet cloaks here before they sailed for Jaya to mock dreamers.",
				"choices": [{"label": "Good day.", "next": "", "action": {}}]
			}
		},

		# --- GERMA KINGDOM ---
		"npc_vinsmoke_judge": {
			"root": {
				"speaker": "Vinsmoke Judge (Garuda)",
				"text": "How dare an outsider board the mobile citadel of Germa 66! Science and Bloodline Elements alone dictate sovereignty in the North Blue!",
				"choices": [
					{"label": "We seek passage and Germa technology.", "next": "germa_parley", "action": {"type": "advance_quest", "quest_id": "mobile_fortress_interception", "stage": "BLOODLINE_DATA_HEIST"}},
					{"label": "Ask about climbing the Red Line.", "next": "red_line_snails", "action": {}},
					{"label": "Depart the throne room.", "next": "", "action": {}}
				]
			},
			"germa_parley": {
				"speaker": "Vinsmoke Judge (Garuda)",
				"text": "If you have Beli, our Science Directorate will sell you shape-memory alloys and hover soles. Touch our clone gestation tanks, however, and my sons will end you.",
				"choices": [{"label": "Understood, King Judge.", "next": "", "action": {}}]
			},
			"red_line_snails": {
				"speaker": "Vinsmoke Judge (Garuda)",
				"text": "Only Germa's 48 giant snails can scale the 10,000-meter cliffs of the Red Line. Everyone else must brave the 55-knot rapids of Reverse Mountain!",
				"choices": [
					{"label": "Then Reverse Mountain is our path.", "next": "", "action": {"type": "set_flag", "flag": "reverse_mountain_canal_charted", "value": true}}
				]
			}
		},
		"npc_germa_quartermaster": {
			"root": {
				"speaker": "Unit #04 (Clone Logistics Overseer)",
				"text": "Orders received. Commercial hover equipment and clone nutrient ampoules are available for requisition.",
				"choices": [{"label": "Proceed.", "next": "", "action": {}}]
			}
		}
	}

# ==============================================================================
# QUEST STATE MACHINES
# ==============================================================================

func _initialize_quests() -> void:
	quests = {
		"in_nolands_footsteps": {
			"id": "in_nolands_footsteps",
			"title": "In Noland's Footsteps",
			"island_id": "lvneel_kingdom",
			"status": QuestStage.NOT_STARTED,
			"stage": "NOT_STARTED",
			"reward_beli": 50000,
			"description": "Investigate Mont Blanc Noland's 400-year-old botanical expedition at Lvneel Kingdom and uncover Sky Island clues."
		},
		"white_city_quarantine": {
			"id": "white_city_quarantine",
			"title": "White City Quarantine",
			"island_id": "flevance_ruins",
			"status": QuestStage.NOT_STARTED,
			"stage": "NOT_STARTED",
			"reward_beli": 120000,
			"description": "Equip a Charcoal Dust Mask, infiltrate the quarantined ruins of Flevance, and recover Dr. Water's surgical ledger."
		},
		"five_billion_beli_triangle": {
			"id": "five_billion_beli_triangle",
			"title": "The 5-Billion-Beli Triangle",
			"island_id": "swallow_island",
			"status": QuestStage.NOT_STARTED,
			"stage": "NOT_STARTED",
			"reward_beli": 180000,
			"description": "Trace the Op-Op Fruit incident across Rubeck, Minion, and Swallow Islands to unlock Inventor Wolf's Polar Tang sub-hull."
		},
		"mobile_fortress_interception": {
			"id": "mobile_fortress_interception",
			"title": "Mobile Fortress Interception",
			"island_id": "germa_kingdom_mobile",
			"status": QuestStage.NOT_STARTED,
			"stage": "NOT_STARTED",
			"reward_beli": 250000,
			"description": "Track the moving 48-snail Germa 66 fleet, board Judge's citadel, and chart your approach to the North Blue Reverse Mountain canal."
		}
	}

func start_quest(quest_id: String) -> Dictionary:
	if not quests.has(quest_id):
		return {}
	var q: Dictionary = quests[quest_id]
	if q["status"] == QuestStage.NOT_STARTED:
		q["status"] = QuestStage.IN_PROGRESS
		q["stage"] = _get_initial_stage_for_quest(quest_id)
		quest_updated.emit(quest_id, q["stage"], q)
	return q

func advance_quest(quest_id: String, new_stage: String) -> Dictionary:
	if not quests.has(quest_id):
		return {}
	var q: Dictionary = quests[quest_id]
	if q["status"] == QuestStage.COMPLETED:
		return q

	if q["status"] == QuestStage.NOT_STARTED:
		q["status"] = QuestStage.IN_PROGRESS

	q["stage"] = new_stage
	if new_stage == "COMPLETED":
		q["status"] = QuestStage.COMPLETED
		var reward: int = int(q.get("reward_beli", 0))
		if reward > 0:
			_add_beli(reward)

	quest_updated.emit(quest_id, new_stage, q)
	return q

func get_quest_stage(quest_id: String) -> String:
	if quests.has(quest_id):
		return str(quests[quest_id].get("stage", "NOT_STARTED"))
	return "NOT_STARTED"

func _get_initial_stage_for_quest(quest_id: String) -> String:
	match quest_id:
		"in_nolands_footsteps":
			return "ARCHIVE_INVESTIGATION"
		"white_city_quarantine":
			return "INFILTRATE_RUINS" if has_dust_respirator() else "HAZMAT_PREPARATION"
		"five_billion_beli_triangle":
			return "RUBECK_INTEL"
		"mobile_fortress_interception":
			return "TRACK_GERMA_FLEET"
	return "IN_PROGRESS"

# ==============================================================================
# GERMA 66 MOBILE FLEET TRACKING & REVERSE MOUNTAIN CANAL HANDOFF
# ==============================================================================

## Queries NorthBlueData.get_germa_fleet_state() and checks if the player's vessel
## is within boarding range (in meters) of the moving 48-snail fortress.
func track_and_check_germa_interception(ship_lat_deg: float, ship_lon_deg: float, boarding_range_m: float = 15000.0) -> Dictionary:
	var fleet_state: Dictionary = NorthBlueData.get_germa_fleet_state(simulation_time_hours)
	var fleet_coords: Dictionary = fleet_state.get("coordinates", {})
	var f_lat: float = float(fleet_coords.get("lat", 31.0))
	var f_lon: float = float(fleet_coords.get("lon", -48.0))

	var dist_m: float = NorthBlueData.surface_distance_meters(ship_lat_deg, ship_lon_deg, f_lat, f_lon)
	var can_board: bool = dist_m <= boarding_range_m

	if can_board:
		germa_fleet_intercepted.emit(fleet_state)
		if get_quest_stage("mobile_fortress_interception") in ["NOT_STARTED", "TRACK_GERMA_FLEET"]:
			advance_quest("mobile_fortress_interception", "BOARD_AND_PARLEY")

	return {
		"fleet_lat_deg": f_lat,
		"fleet_lon_deg": f_lon,
		"formation": fleet_state.get("fleet_formation", ""),
		"heading_degrees": fleet_state.get("heading_degrees", 0.0),
		"distance_meters": dist_m,
		"within_boarding_range": can_board,
		"fleet_state": fleet_state
	}

## Completes Mobile Fortress Interception and returns the North Blue Reverse Mountain
## canal approach route for navigation handoff.
func chart_reverse_mountain_canal_approach() -> Dictionary:
	lore_flags["reverse_mountain_canal_charted"] = true
	if get_quest_stage("mobile_fortress_interception") in ["BOARD_AND_PARLEY", "BLOODLINE_DATA_HEIST", "CANAL_APPROACH_READY"]:
		advance_quest("mobile_fortress_interception", "COMPLETED")
	return NorthBlueData.get_reverse_mountain_canal_route()
