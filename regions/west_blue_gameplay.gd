class_name WestBlueGameplay
extends Node
## West Blue Interactive Gameplay, Dialogue & Marketplace Controller for Project "Blue Planet".
##
## Driven by WestBlueData (res://regions/west_blue_data.gd) and integrated with
## WorldRegistry (/root/WorldRegistry) and StoryCampaignManager (/root/StoryCampaignManager).
##
## Provides:
##   1. Playable Marketplace, Underworld Speakeasy & Shipyard Transaction Controllers
##      across all 77 WestBlueData.ITEMS, including Five Families contraband reputation gates,
##      Happo Navy dragon-prow upgrades, Esperia luthier instruments, and Reverse Mountain
##      high-tensile rudder chains.
##   2. Branching NPC Dialogue Trees across Ohara Ruins, Kano Country, Castello del Capone,
##      Ilusia, Ballywood, Esperia, Toroa, Gourd Island, Sake Cove, Las Camp, Tomb of Thriller,
##      God Valley, and the Reverse Mountain Gateway.
##   3. Five Quest State Machines:
##      - Sunken Codices of the Lake of Knowledge (Ohara stealth diving past Cipher Pol)
##      - Eight Impacts Tournament (Kano Country Happo Navy duel & armored prow unlock)
##      - Five Families Contraband Run (Mafia diplomacy & Las Camp smuggling)
##      - Caldera of Shadows (Tomb of Thriller Bark & Cindry's theater)
##      - Ghost Coordinates of 38 Years Ago (God Valley anomaly & Reverse Mountain readiness)

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal item_purchased(island_id: String, shop_id: String, item_id: String, quantity: int, total_beli: int)
signal item_sold(island_id: String, shop_id: String, item_id: String, quantity: int, payout_beli: int)
signal ship_upgrade_installed(upgrade_id: String, island_id: String, cost_beli: int)
signal reputation_changed(faction_id: String, new_score: int, delta: int)
signal dialogue_started(npc_id: String, node_id: String, speaker: String, text: String, choices: Array)
signal dialogue_advanced(npc_id: String, node_id: String, speaker: String, text: String, choices: Array)
signal dialogue_ended(npc_id: String)
signal quest_state_changed(quest_id: String, previous_stage: String, new_stage: String, objective: String)
signal quest_completed(quest_id: String, reward_beli: int, unlocked_items: Array)
signal god_valley_anomaly_triggered(magnetic_deviation_deg: float, depth_m: float)
signal reverse_mountain_readiness_checked(is_ready: bool, missing_requirements: Array)

# ---------------------------------------------------------------------------
# Contraband & Reputation Gate Definitions
# ---------------------------------------------------------------------------
## Items requiring specific faction reputation thresholds to purchase.
const REPUTATION_GATES: Dictionary = {
	"tommy_gun_flintlock": {"faction": "five_families", "min_rep": 20, "label": "Five Families Associate"},
	"wrist_dagger_sleeve": {"faction": "five_families", "min_rep": 15, "label": "Five Families Associate"},
	"lead_lined_contraband_chest": {"faction": "five_families", "min_rep": 25, "label": "Five Families Smuggler"},
	"iron_fortress_blueprints": {"faction": "five_families", "min_rep": 50, "label": "Five Families Made Capo"},
	"marine_transit_manifest_forged": {"faction": "five_families", "min_rep": 30, "label": "Five Families Broker"},
	"levely_sea_pass_forged": {"faction": "five_families", "min_rep": 40, "label": "Underworld Diplomat"},
	"weathered_poneglyph_rubbing": {"faction": "ohara_scholars", "min_rep": 35, "label": "Trusted Antiquity Diver"},
	"ancient_kingdom_lexicon": {"faction": "ohara_scholars", "min_rep": 20, "label": "Scholar Ally"},
	"happo_dragon_prow_keel": {"faction": "happo_navy", "min_rep": 40, "label": "Happo Navy Sworn Ally"},
	"hasshoken_vibration_scroll": {"faction": "happo_navy", "min_rep": 30, "label": "Eight Impacts Initiate"},
	"esperian_violin": {"faction": "esperia_guild", "min_rep": 15, "label": "Guild Patron"},
	"concealed_cane_sword": {"faction": "esperia_guild", "min_rep": 20, "label": "Convoy Duelist"},
}

## Ship upgrade item IDs mapped to StoryCampaignManager ship_state slots.
const SHIP_UPGRADE_SLOTS: Dictionary = {
	"happo_dragon_prow_keel": {
		"slot": "bow_ram",
		"tier": "happo_dragon_prow",
		"description": "Happo Navy Cast-Iron & Jade Dragon-Prow Battering Ram (3x Ramming Damage)",
	},
	"rudder_reinforcement_chains": {
		"slot": "rudder_bracing",
		"tier": "reverse_mountain_double_chain",
		"description": "Reverse Mountain High-Tensile Rudder Chains (-80% Canal Wall Rudder Damage)",
	},
	"watertight_cooper_cask": {
		"slot": "provision_hold",
		"tier": "sake_cove_cooper_casks",
		"description": "Sake Cove Watertight Oak Cooper Casks (100-Day Spoilage Immunity)",
	},
	"resonant_tone_wood": {
		"slot": "cabin_acoustics",
		"tier": "esperia_resonant_spruce",
		"description": "Esperian Resonant Tone-Wood Cabin Paneling (+50% Musical Buff Duration)",
	},
	"lead_lined_contraband_chest": {
		"slot": "smuggler_hold",
		"tier": "five_families_lead_vault",
		"description": "Five Families Lead-Lined Contraband Hold (Masks Devil Fruits & Contraband)",
	},
}

# ---------------------------------------------------------------------------
# Runtime Player & Regional State
# ---------------------------------------------------------------------------
var player_inventory: Dictionary = {} # item_id -> int
var fallback_wallet_beli: int = 250_000 # Used when WorldRegistry autoload is not active

var faction_reputation: Dictionary = {
	"five_families": 10,
	"happo_navy": 10,
	"ohara_scholars": 10,
	"revolutionary_army": 5,
	"esperia_guild": 15,
	"world_government": 0,
}

var installed_ship_upgrades: Dictionary = {} # slot -> tier
var discovered_secrets: Dictionary = {} # secret_id -> bool

## Active branching dialogue session state.
var active_dialogue_npc_id: String = ""
var active_dialogue_node_id: String = ""
var _dialogue_trees: Dictionary = {}

## Five West Blue Quest State Machines.
var quest_states: Dictionary = {}

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	_initialize_quests()
	_initialize_dialogue_trees()


# ---------------------------------------------------------------------------
# Wallet & Autoload Integration Helpers
# ---------------------------------------------------------------------------
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
	if wr != null and wr.get("wallet") is Dictionary:
		return int(wr.wallet.get("Beli", fallback_wallet_beli))
	return fallback_wallet_beli


func _add_beli(amount: int) -> int:
	if amount <= 0:
		return get_beli_balance()
	var wr: Node = _get_world_registry()
	if wr != null and wr.has_method("add_currency"):
		return int(wr.add_currency("Beli", amount))
	fallback_wallet_beli += amount
	return fallback_wallet_beli


func _spend_beli(cost: int) -> bool:
	if cost <= 0:
		return true
	var wr: Node = _get_world_registry()
	if wr != null and wr.has_method("spend_currency"):
		return bool(wr.spend_currency("Beli", cost))
	if fallback_wallet_beli < cost:
		return false
	fallback_wallet_beli -= cost
	return true


func add_inventory_item(item_id: String, quantity: int = 1) -> int:
	if quantity <= 0 or not WestBlueData.ITEMS.has(item_id):
		return int(player_inventory.get(item_id, 0))
	var current: int = int(player_inventory.get(item_id, 0))
	player_inventory[item_id] = current + quantity
	return int(player_inventory[item_id])


func remove_inventory_item(item_id: String, quantity: int = 1) -> bool:
	var current: int = int(player_inventory.get(item_id, 0))
	if quantity <= 0 or current < quantity:
		return false
	var remaining: int = current - quantity
	if remaining == 0:
		player_inventory.erase(item_id)
	else:
		player_inventory[item_id] = remaining
	return true


func has_inventory_item(item_id: String, quantity: int = 1) -> bool:
	return int(player_inventory.get(item_id, 0)) >= quantity


func modify_reputation(faction_id: String, delta: int) -> int:
	var current: int = int(faction_reputation.get(faction_id, 0))
	var min_val: int = -100 if faction_id == "world_government" else 0
	var updated: int = clampi(current + delta, min_val, 100)
	faction_reputation[faction_id] = updated
	reputation_changed.emit(faction_id, updated, delta)
	return updated


# ---------------------------------------------------------------------------
# 1. Marketplace, Underworld Speakeasy & Shipyard Transaction Controllers
# ---------------------------------------------------------------------------
func _find_establishment(island_id: String, shop_id: String) -> Dictionary:
	var island: Dictionary = WestBlueData.get_island(island_id)
	if island.is_empty():
		return {}
	for est in island.get("establishments", []):
		if est.get("id", "") == shop_id:
			return est
	return {}


## Computes dynamic price modifier based on faction standing and apparel perks.
func get_effective_buy_price(item_id: String, island_id: String) -> int:
	var item: Dictionary = WestBlueData.get_item(item_id)
	if item.is_empty():
		return 0
	var base_price: int = int(item.get("price_beli", 0))
	var multiplier: float = 1.0

	# Ballywood Stovepipe Top Hat grants a 10% merchant charisma discount
	if has_inventory_item("stovepipe_top_hat"):
		multiplier -= 0.10

	# High local faction standing grants up to 15% discount
	if island_id == "castello_del_capone" and int(faction_reputation.get("five_families", 0)) >= 50:
		multiplier -= 0.10
	elif island_id == "kano_country" and int(faction_reputation.get("happo_navy", 0)) >= 50:
		multiplier -= 0.15
	elif island_id == "esperia_kingdom" and int(faction_reputation.get("esperia_guild", 0)) >= 40:
		multiplier -= 0.10

	return maxi(1, int(round(float(base_price) * maxf(0.65, multiplier))))


## Lists all items stocked at a West Blue shop with pricing and gate lock status.
func get_shop_catalog(island_id: String, shop_id: String) -> Array[Dictionary]:
	var est: Dictionary = _find_establishment(island_id, shop_id)
	var catalog: Array[Dictionary] = []
	if est.is_empty():
		return catalog

	for item_id in est.get("inventory", []):
		var item: Dictionary = WestBlueData.get_item(str(item_id))
		if item.is_empty():
			continue
		var entry: Dictionary = item.duplicate(true)
		entry["effective_price_beli"] = get_effective_buy_price(str(item_id), island_id)
		var gate_check: Dictionary = _check_reputation_gate(str(item_id))
		entry["unlocked"] = gate_check["allowed"]
		entry["gate_reason"] = gate_check["reason"]
		catalog.append(entry)
	return catalog


func _check_reputation_gate(item_id: String) -> Dictionary:
	if not REPUTATION_GATES.has(item_id):
		return {"allowed": true, "reason": ""}
	var gate: Dictionary = REPUTATION_GATES[item_id]
	var faction: String = str(gate["faction"])
	var min_rep: int = int(gate["min_rep"])
	var current_rep: int = int(faction_reputation.get(faction, 0))
	if current_rep >= min_rep:
		return {"allowed": true, "reason": ""}
	return {
		"allowed": false,
		"reason": "Requires %s standing (%s rep %d/%d)" % [gate["label"], faction, current_rep, min_rep],
	}


## Validates whether the player can purchase an item at the given West Blue establishment.
func can_purchase_item(island_id: String, shop_id: String, item_id: String, quantity: int = 1) -> Dictionary:
	if quantity <= 0:
		return {"ok": false, "reason": "Quantity must be positive."}
	var est: Dictionary = _find_establishment(island_id, shop_id)
	if est.is_empty():
		return {"ok": false, "reason": "Establishment not found: %s/%s" % [island_id, shop_id]}
	if not est.get("inventory", []).has(item_id):
		return {"ok": false, "reason": "Item '%s' is not stocked at %s." % [item_id, est.get("name", shop_id)]}

	var gate: Dictionary = _check_reputation_gate(item_id)
	if not gate["allowed"]:
		return {"ok": false, "reason": gate["reason"]}

	var unit_price: int = get_effective_buy_price(item_id, island_id)
	var total_cost: int = unit_price * quantity
	var balance: int = get_beli_balance()
	if balance < total_cost:
		return {
			"ok": false,
			"reason": "Insufficient Beli (%d / %d required)." % [balance, total_cost],
			"total_cost_beli": total_cost,
		}
	return {"ok": true, "reason": "", "total_cost_beli": total_cost, "unit_price_beli": unit_price}


## Executes a purchase transaction at any West Blue shop, speakeasy, bazaar, or shipyard.
func purchase_item(island_id: String, shop_id: String, item_id: String, quantity: int = 1) -> Dictionary:
	var check: Dictionary = can_purchase_item(island_id, shop_id, item_id, quantity)
	if not check["ok"]:
		return check

	var total_cost: int = int(check["total_cost_beli"])
	if not _spend_beli(total_cost):
		return {"ok": false, "reason": "Currency deduction failed."}

	var new_qty: int = add_inventory_item(item_id, quantity)

	# Automatically apply ship upgrades when purchased at a shipyard/outfitter
	if SHIP_UPGRADE_SLOTS.has(item_id):
		_apply_ship_upgrade_record(item_id, island_id, total_cost)

	# Reputation gain from patronizing local merchants
	if island_id == "castello_del_capone":
		modify_reputation("five_families", 2)
	elif island_id == "kano_country":
		modify_reputation("happo_navy", 2)
	elif island_id == "esperia_kingdom":
		modify_reputation("esperia_guild", 2)
	elif island_id == "ohara":
		modify_reputation("ohara_scholars", 3)

	item_purchased.emit(island_id, shop_id, item_id, quantity, total_cost)
	return {
		"ok": true,
		"item_id": item_id,
		"quantity_bought": quantity,
		"inventory_total": new_qty,
		"total_cost_beli": total_cost,
		"remaining_beli": get_beli_balance(),
	}


## Sells an item from the player's inventory to a West Blue merchant (55% base rate, +10% with Top Hat).
func sell_item(island_id: String, shop_id: String, item_id: String, quantity: int = 1) -> Dictionary:
	if quantity <= 0 or not has_inventory_item(item_id, quantity):
		return {"ok": false, "reason": "Insufficient item quantity in inventory."}
	var est: Dictionary = _find_establishment(island_id, shop_id)
	if est.is_empty():
		return {"ok": false, "reason": "Unknown shop: %s/%s" % [island_id, shop_id]}
	var item: Dictionary = WestBlueData.get_item(item_id)
	if item.is_empty():
		return {"ok": false, "reason": "Unknown item: %s" % item_id}

	var rate: float = 0.55
	if has_inventory_item("stovepipe_top_hat"):
		rate += 0.10
	# Contraband & antiquities fetch premium payout at Castello Del Capone or Ohara
	var category: String = str(item.get("category", ""))
	if island_id == "castello_del_capone" and category in ["Relic", "Antiquity", "Document", "Blueprint"]:
		rate += 0.15
	elif island_id == "ohara" and category in ["Antiquity", "Book"]:
		rate += 0.20

	var payout: int = maxi(1, int(round(float(item.get("price_beli", 0)) * rate))) * quantity
	remove_inventory_item(item_id, quantity)
	var new_balance: int = _add_beli(payout)
	item_sold.emit(island_id, shop_id, item_id, quantity, payout)
	return {
		"ok": true,
		"item_id": item_id,
		"quantity_sold": quantity,
		"payout_beli": payout,
		"new_balance_beli": new_balance,
	}


func _apply_ship_upgrade_record(upgrade_item_id: String, island_id: String, cost_beli: int) -> void:
	var spec: Dictionary = SHIP_UPGRADE_SLOTS[upgrade_item_id]
	var slot: String = str(spec["slot"])
	var tier: String = str(spec["tier"])
	installed_ship_upgrades[slot] = tier

	var scm: Node = _get_campaign_manager()
	if scm != null and scm.has_method("install_ship_upgrade"):
		scm.install_ship_upgrade(slot, tier)

	ship_upgrade_installed.emit(upgrade_item_id, island_id, cost_beli)


## Installs an owned ship upgrade explicitly (e.g., if earned via quest reward).
func install_ship_upgrade_from_inventory(upgrade_item_id: String, island_id: String) -> Dictionary:
	if not SHIP_UPGRADE_SLOTS.has(upgrade_item_id):
		return {"ok": false, "reason": "Item is not a recognized ship upgrade."}
	if not has_inventory_item(upgrade_item_id):
		return {"ok": false, "reason": "Upgrade item not in inventory."}
	_apply_ship_upgrade_record(upgrade_item_id, island_id, 0)
	return {"ok": true, "upgrade": upgrade_item_id, "slot": SHIP_UPGRADE_SLOTS[upgrade_item_id]["slot"]}


## Checks if the player's vessel is equipped for the 5,000m Reverse Mountain hydraulic ascent.
func check_reverse_mountain_readiness() -> Dictionary:
	var missing: Array[String] = []
	if not installed_ship_upgrades.has("rudder_bracing") and not has_inventory_item("rudder_reinforcement_chains"):
		missing.append("Reverse Mountain High-Tensile Rudder Chains (sold at Last Hope Drydock)")
	if not has_inventory_item("reverse_mountain_current_chart"):
		missing.append("Reverse Mountain Hydrodynamic Current Chart")

	var is_ready: bool = missing.is_empty()
	reverse_mountain_readiness_checked.emit(is_ready, missing)
	return {
		"ready": is_ready,
		"missing_requirements": missing,
		"canal_entry": WestBlueData.get_reverse_mountain_canal_entry(),
		"has_happo_ram": installed_ship_upgrades.get("bow_ram", "") == "happo_dragon_prow",
	}


# ---------------------------------------------------------------------------
# 2. Branching NPC Dialogue Trees
# ---------------------------------------------------------------------------
func _initialize_dialogue_trees() -> void:
	_dialogue_trees = {
		# --- OHARA RUINS ---
		"aron_antiquity_broker": {
			"speaker": "Aron the Ink-Stained",
			"island_id": "ohara",
			"nodes": {
				"root": {
					"text": "Keep your voice low, sailor. Cipher Pol snails listen from the charred branches of the Tree. Looking to buy salvaged pages, or dive the Lake of Knowledge yourself?",
					"choices": [
						{"label": "Tell me about the Lake of Knowledge salvage.", "next": "lake_lore"},
						{"label": "I want to dive for the Void Century lexicon.", "next": "start_ohara_quest", "action": "start_quest:quest_sunken_codices"},
						{"label": "Show me your salvaged antiquities.", "next": "open_shop"},
						{"label": "Leave quietly.", "next": "END"},
					],
				},
				"lake_lore": {
					"text": "When the Buster Call shells fell 22 years ago, Professor Clover's scholars wrapped thousands of books in wax and hurled them into the crater lake. Water saved what fire tried to erase.",
					"choices": [
						{"label": "I'll recover a lexicon from the sunken roots.", "next": "start_ohara_quest", "action": "start_quest:quest_sunken_codices"},
						{"label": "Back", "next": "root"},
					],
				},
				"start_ohara_quest": {
					"text": "Take a waterproof dive lantern and watch the patrol cones of Watcher Kestrel. Bring back an intact Ancient Kingdom Lexicon and I'll pay 120,000 Beli—or let you study its ciphers.",
					"choices": [{"label": "Understood.", "next": "END"}],
				},
				"open_shop": {
					"text": "Keep the lantern shuttered when you leave camp. Here is what I dredged up this week.",
					"choices": [{"label": "Done browsing.", "next": "END"}],
				},
			},
		},
		"cp_shadow_watcher": {
			"speaker": "Cipher Pol Watcher 'Kestrel'",
			"island_id": "ohara",
			"nodes": {
				"root": {
					"text": "This crater is under World Government quarantine. State your business on Ohara before I file an arrest warrant—or worse.",
					"choices": [
						{"label": "Present Forged Marine Transit Manifest.", "next": "forged_pass", "req_item": "marine_transit_manifest_forged"},
						{"label": "Just an innocent hydrographer charting currents.", "next": "bluff_check"},
						{"label": "Back away toward the boat.", "next": "END"},
					],
				},
				"forged_pass": {
					"text": "...The seal checks out, though your ship smells like Capone's docks. Stay out of the lake basin and leave before nightfall.",
					"choices": [{"label": "Will do.", "next": "END"}],
				},
				"bluff_check": {
					"text": "Hydrographers don't carry dredging hooks. One more step toward the Tree stump and you'll join the ghosts of Ohara.",
					"choices": [{"label": "Retreat.", "next": "END"}],
				},
			},
		},
		"saul_ice_marker": {
			"speaker": "Jaguar D. Saul's Thawed Ice Marker",
			"island_id": "ohara",
			"nodes": {
				"root": {
					"text": "A colossal 4-meter footprint pressed into crystalline permafrost near the beach. Etched into a weathered oak stake beside it: 'Dereshi! No one in this world is born to be completely alone!'",
					"choices": [
						{"label": "Pay respects and record the coordinates.", "next": "respect", "action": "rep:ohara_scholars:+10"},
						{"label": "Step back.", "next": "END"},
					],
				},
				"respect": {
					"text": "You feel a quiet resolve. Local salvaged notes indicate giants from Elbaf secretly recovered the remaining Oharan books years ago.",
					"choices": [{"label": "Continue.", "next": "END"}],
				},
			},
		},

		# --- KANO COUNTRY ---
		"don_chinjao": {
			"speaker": "Don Chinjao (The Drill)",
			"island_id": "kano_country",
			"nodes": {
				"root": {
					"text": "Gahaha! A visitor to the Flower Country! Can your fists ring with the vibrational fury of Hasshoken, or are you just another soft-shelled tourist?",
					"choices": [
						{"label": "Challenge the Eight Impacts Tournament trial!", "next": "tournament", "action": "start_quest:quest_eight_impacts_tournament"},
						{"label": "Tell me about the Jewel Ice Sheet.", "next": "ice_sheet"},
						{"label": "Farewell, Elder.", "next": "END"},
					],
				},
				"tournament": {
					"text": "Good! Prove you can shatter a 5-meter granite monolith with vibrational force, and Sai will authorize the Happo Navy's Dragon-Prow ramming keel for your ship!",
					"choices": [{"label": "I accept the trial.", "next": "END"}],
				},
				"ice_sheet": {
					"text": "Beneath eternal ice lies a hundred billion Beli in Chinjao gold! Only a true drill—or a worthy ally of the Straw Hat Grand Fleet—earns the respect of our house.",
					"choices": [{"label": "Back", "next": "root"}],
				},
			},
		},
		"don_sai": {
			"speaker": "Don Sai (13th Leader of Happo Navy)",
			"island_id": "kano_country",
			"nodes": {
				"root": {
					"text": "The Happo Navy no longer tolerates Joker's illegal weapons in West Blue. State your allegiance clearly.",
					"choices": [
						{"label": "We stand against underworld arms traffickers.", "next": "ally", "action": "rep:happo_navy:+8"},
						{"label": "How do we install a Dragon-Prow Ram?", "next": "prow_info"},
						{"label": "Dismissed.", "next": "END"},
					],
				},
				"ally": {
					"text": "Well spoken. Any friend of the Straw Hat Grand Fleet is welcome at Joya Harbor.",
					"choices": [{"label": "Thank you, Commander.", "next": "END"}],
				},
				"prow_info": {
					"text": "Win our Eight Impacts trial or earn 40 Happo Navy standing, then speak with Master Artisan Lu at the martial bazaar.",
					"choices": [{"label": "Back", "next": "root"}],
				},
			},
		},
		"master_smith_lu": {
			"speaker": "Master Artisan Lu (Hasshoken Smith)",
			"island_id": "kano_country",
			"nodes": {
				"root": {
					"text": "Folded bronze, jade-tempered iron, and Bisen naginatas—every blade here is tuned to carry vibrational shockwaves.",
					"choices": [
						{"label": "Inspect Dragon-Prow & Hasshoken stock.", "next": "END"},
					],
				},
			},
		},

		# --- CASTELLO DEL CAPONE ---
		"don_vincenzo": {
			"speaker": "Don Vincenzo (Fire Tank Regent)",
			"island_id": "castello_del_capone",
			"nodes": {
				"root": {
					"text": "Bege took his iron fortress to the Grand Line, but the Five Families still run West Blue's docks. Keep your hands visible and your Beli heavy.",
					"choices": [
						{"label": "I'm looking for high-tier contraband work.", "next": "contraband_job", "action": "start_quest:quest_five_families_contraband"},
						{"label": "Tell me about Capone Bege's rise.", "next": "bege_lore"},
						{"label": "Leave the speakeasy.", "next": "END"},
					],
				},
				"contraband_job": {
					"text": "Carmine Marchetti's gunboats are intercepting our Las Camp spice and powder runs. Move a lead-lined contraband crate past the blockade and you'll earn Five Families respect—and access to our tommy-gun armory.",
					"choices": [{"label": "Consider it done.", "next": "END"}],
				},
				"bege_lore": {
					"text": "The Boss didn't build an empire by playing fair. He cut the heads off rival dons and laughed inside his iron castle while their crews tore each other apart.",
					"choices": [{"label": "Back", "next": "root"}],
				},
			},
		},
		"marchetti_rival": {
			"speaker": "Carmine Marchetti (Rival Underboss)",
			"island_id": "castello_del_capone",
			"nodes": {
				"root": {
					"text": "Vincenzo thinks he owns the speakeasy district? Soon the Marchetti Family will control every black-market berth from here to Ballywood.",
					"choices": [
						{"label": "Stay out of my ship's way, Marchetti.", "next": "END"},
					],
				},
			},
		},

		# --- ILUSIA KINGDOM ---
		"thalassa_lucas": {
			"speaker": "Thalassa Lucas (Former King)",
			"island_id": "ilusia_kingdom",
			"nodes": {
				"root": {
					"text": "Eight years ago at Mary Geoise, I warned the other kings about Monkey D. Dragon. They laughed. Now look at the fires burning across the Four Blues.",
					"choices": [
						{"label": "Do you support the Revolutionary Army?", "next": "dragon_warning"},
						{"label": "Farewell, Your Grace.", "next": "END"},
					],
				},
				"dragon_warning": {
					"text": "I support stability, but King Seki's taxes are driving our own citizens straight into Morley's underground cells.",
					"choices": [{"label": "I see.", "next": "END"}],
				},
			},
		},
		"king_seki": {
			"speaker": "King Seki",
			"island_id": "ilusia_kingdom",
			"nodes": {
				"root": {
					"text": "Pay the harbor tariff promptly, sailor! The Celestial Tribute waits for no commoner!",
					"choices": [{"label": "Bow and depart.", "next": "END"}],
				},
			},
		},
		"marie_revolutionary": {
			"speaker": "Marie of the Cobblestones",
			"island_id": "ilusia_kingdom",
			"nodes": {
				"root": {
					"text": "Keep your hood low. We're moving printing blocks through the aqueducts tonight while Captain Valerie's patrols change shift.",
					"choices": [
						{"label": "Offer logistical support (+Revolutionary standing).", "next": "aid", "action": "rep:revolutionary_army:+10"},
						{"label": "Move along.", "next": "END"},
					],
				},
				"aid": {
					"text": "Commander Morley remembers every friend who helps West Blue breathe free.",
					"choices": [{"label": "Stay safe.", "next": "END"}],
				},
			},
		},
		"captain_valerie": {
			"speaker": "Captain Valerie",
			"island_id": "ilusia_kingdom",
			"nodes": {
				"root": {
					"text": "Keep weapons sheathed in Port Thalassa. The Carabineers enforce royal law, even when the crown's taxes test our conscience.",
					"choices": [{"label": "Understood, Captain.", "next": "END"}],
				},
			},
		},
		"horologist_gaston": {
			"speaker": "Master Horologist Gaston",
			"island_id": "ilusia_kingdom",
			"nodes": {
				"root": {
					"text": "A sailor without a calibrated chronometer is blind in open fog. My spring-driven timepieces keep true to a second across ten thousand kilometers.",
					"choices": [{"label": "Check instruments.", "next": "END"}],
				},
			},
		},

		# --- BALLYWOOD KINGDOM ---
		"king_ham_burger": {
			"speaker": "King Ham Burger",
			"island_id": "ballywood_kingdom",
			"nodes": {
				"root": {
					"text": "Welcome to Ballywood! Four score and seven nautical miles of prime smoked beef, steam engineering, and liberty! Enjoy the Broadway Revue!",
					"choices": [{"label": "Thank you, Your Majesty!", "next": "END"}],
				},
			},
		},
		"madame_clara_broadway": {
			"speaker": "Madame Clara",
			"island_id": "ballywood_kingdom",
			"nodes": {
				"root": {
					"text": "Darling, if your crew has a musician from Esperia or Toroa, bring them to the Opera House! West Blue audiences adore sea shanties!",
					"choices": [{"label": "We'll keep that in mind.", "next": "END"}],
				},
			},
		},
		"pitmaster_bob": {
			"speaker": "Bob 'Smokestack' Miller",
			"island_id": "ballywood_kingdom",
			"nodes": {
				"root": {
					"text": "Hardtack breaks teeth! Stock up on hickory-smoked prime shanks before you ever point your bow toward Reverse Mountain.",
					"choices": [{"label": "Sounds delicious.", "next": "END"}],
				},
			},
		},

		# --- ESPERIA KINGDOM ---
		"luthier_vivaldi": {
			"speaker": "Grand Luthier Vivaldi",
			"island_id": "esperia_kingdom",
			"nodes": {
				"root": {
					"text": "Two-hundred-year-old Esperian spruce sings like the mountain wind. Even a skeleton's bones would dance to a violin carved in this atelier.",
					"choices": [
						{"label": "Praise the craft (+Esperia Guild standing).", "next": "praise", "action": "rep:esperia_guild:+8"},
						{"label": "Browse instruments.", "next": "END"},
					],
				},
				"praise": {
					"text": "A true patron of music! Take care of your ship's acoustics, and your crew will never lose heart.",
					"choices": [{"label": "Farewell, Maestro.", "next": "END"}],
				},
			},
		},
		"fencing_master_lemaire": {
			"speaker": "Swordsman Lemaire",
			"island_id": "esperia_kingdom",
			"nodes": {
				"root": {
					"text": "Fifty years ago, our convoy commander Brook carried the concealed shikomizue blade onto the Rumbar Pirates' deck. Speed and rhythm—that is Esperian steel.",
					"choices": [{"label": "An inspiring legacy.", "next": "END"}],
				},
			},
		},
		"songstress_shuri": {
			"speaker": "Songstress Shuri",
			"island_id": "esperia_kingdom",
			"nodes": {
				"root": {
					"text": "Gather around Binks' Rest Tavern! One chorus of Binks' Sake warms the blood against any fjord frost.",
					"choices": [{"label": "Raise a glass!", "next": "END"}],
				},
			},
		},

		# --- TOROA ---
		"flautist_corren": {
			"speaker": "Master Corren",
			"island_id": "toroa",
			"nodes": {
				"root": {
					"text": "My nephew Byron was taken by Sabaody slavers for his gift with the flute. We carve Silverwind flutes now so sailors can soothe the sea whales—and fight back against press-gangs.",
					"choices": [{"label": "We'll watch for slavers.", "next": "END"}],
				},
			},
		},

		# --- GOURD ISLAND ---
		"commander_briggs": {
			"speaker": "Commander Briggs (Marine 88th Branch)",
			"island_id": "gourd_island",
			"nodes": {
				"root": {
					"text": "Years ago, 'Demon Sheriff' Laffitte disgraced this island with torture and tyranny before we stripped his badge and exiled him. Now he sails with Blackbeard. Do not mistake our vigilance for mercy.",
					"choices": [{"label": "Understood, Commander.", "next": "END"}],
				},
			},
		},

		# --- SAKE COVE ---
		"brewer_bacchus": {
			"speaker": "Master Brewer Bacchus",
			"island_id": "sake_cove",
			"nodes": {
				"root": {
					"text": "Ha! Red-Haired Shanks himself swore by our sandstone-aged calabash sake—called it 'Healing Water' when he toasted Whitebeard! Take a calabash before braving Reverse Mountain.",
					"choices": [{"label": "We'll take a calabash!", "next": "END"}],
				},
			},
		},

		# --- LAS CAMP ---
		"sheriff_vance": {
			"speaker": "Sheriff Vance",
			"island_id": "las_camp",
			"nodes": {
				"root": {
					"text": "Ever since Whitebeard fell at Marineford, Las Camp has been a powder keg. Keep your revolver oiled if you're docking at Dusty Anchor.",
					"choices": [{"label": "Stay sharp, Sheriff.", "next": "END"}],
				},
			},
		},
		"rosa_cantina": {
			"speaker": "Rosa the Quick-Draw",
			"island_id": "las_camp",
			"nodes": {
				"root": {
					"text": "Gunpowder, dynamite, and agave firewater—name your poison, captain.",
					"choices": [{"label": "Just looking around.", "next": "END"}],
				},
			},
		},

		# --- TOMB OF THRILLER ---
		"madame_beatrice": {
			"speaker": "Madame Beatrice",
			"island_id": "tomb_of_thriller",
			"nodes": {
				"root": {
					"text": "Gecko Moria gouged out the heart of this island to build his pirate ship, and Dr. Hogback stole poor Victoria Cindry from her grave. Investigate the theater if you dare.",
					"choices": [
						{"label": "Investigate the Caldera of Shadows.", "next": "start_thriller_quest", "action": "start_quest:quest_caldera_of_shadows"},
						{"label": "Leave the misty shore.", "next": "END"},
					],
				},
				"start_thriller_quest": {
					"text": "Bring a Pale Sea Ghost-Lantern into the flooded theater catacombs. Recover Hogback's early surgical journals before the tide claims them.",
					"choices": [{"label": "We'll uncover the truth.", "next": "END"}],
				},
			},
		},

		# --- GOD VALLEY ---
		"hermit_darrow": {
			"speaker": "Old Darrow",
			"island_id": "god_valley",
			"nodes": {
				"root": {
					"text": "Thirty-eight years ago, the Celestial Dragons hunted us for sport while Rocks, Roger, and Garp shook the heavens. Then the island sank. What brings you to a ghost?",
					"choices": [
						{"label": "Chart the Ghost Coordinates & dive the sunken arena.", "next": "start_gv_quest", "action": "start_quest:quest_ghost_coordinates_38"},
						{"label": "Leave in silence.", "next": "END"},
					],
				},
				"start_gv_quest": {
					"text": "Your compass will spin madly in this magnetic void. Bring an Ilusian Chronometer and an Abyssal Diving Helmet if you want to survive the sunken pavilion.",
					"choices": [{"label": "We are prepared.", "next": "END"}],
				},
			},
		},

		# --- REVERSE MOUNTAIN GATEWAY ---
		"pilot_gregory": {
			"speaker": "Lighthouse Pilot Gregory",
			"island_id": "west_blue_reverse_mountain_gateway",
			"nodes": {
				"root": {
					"text": "That roaring white wall ahead is the West Blue Ascending Canal at (-0.430, -0.395)! You hit 65 knots uphill—don't enter without reinforced rudder chains!",
					"choices": [
						{"label": "Check my ship's Reverse Mountain readiness.", "next": "check_ready"},
						{"label": "Back to helm.", "next": "END"},
					],
				},
				"check_ready": {
					"text": "Let's inspect your tiller bracing and hydrodynamic charts right now.",
					"choices": [{"label": "Inspect.", "next": "END", "action": "check_rm_readiness"}],
				},
			},
		},
		"carpenter_tsuru": {
			"speaker": "Master Carpenter Tsuru",
			"island_id": "west_blue_reverse_mountain_gateway",
			"nodes": {
				"root": {
					"text": "Double-chain your rudder shaft before the winter rapids snap it like matchwood.",
					"choices": [{"label": "Wise advice.", "next": "END"}],
				},
			},
		},
	}


## Starts a branching dialogue conversation with a West Blue NPC.
func start_dialogue(npc_id: String) -> Dictionary:
	if not _dialogue_trees.has(npc_id):
		return {"ok": false, "reason": "No dialogue tree registered for NPC: " + npc_id}
	active_dialogue_npc_id = npc_id
	active_dialogue_node_id = "root"
	var payload: Dictionary = get_current_dialogue_node()
	dialogue_started.emit(
		npc_id,
		active_dialogue_node_id,
		payload.get("speaker", ""),
		payload.get("text", ""),
		payload.get("choices", [])
	)
	return payload


## Returns the currently active dialogue node with requirement-filtered choices.
func get_current_dialogue_node() -> Dictionary:
	if active_dialogue_npc_id.is_empty() or not _dialogue_trees.has(active_dialogue_npc_id):
		return {}
	var tree: Dictionary = _dialogue_trees[active_dialogue_npc_id]
	var nodes: Dictionary = tree.get("nodes", {})
	if not nodes.has(active_dialogue_node_id):
		return {}
	var node: Dictionary = nodes[active_dialogue_node_id]
	var visible_choices: Array[Dictionary] = []
	for c in node.get("choices", []):
		if c.has("req_item") and not has_inventory_item(str(c["req_item"])):
			continue
		visible_choices.append(c)
	return {
		"ok": true,
		"npc_id": active_dialogue_npc_id,
		"island_id": tree.get("island_id", ""),
		"node_id": active_dialogue_node_id,
		"speaker": tree.get("speaker", ""),
		"text": node.get("text", ""),
		"choices": visible_choices,
	}


## Advances the active dialogue by selecting a visible choice index.
func select_dialogue_choice(choice_index: int) -> Dictionary:
	var current: Dictionary = get_current_dialogue_node()
	if current.is_empty():
		return {"ok": false, "reason": "No active dialogue."}
	var choices: Array = current.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return {"ok": false, "reason": "Invalid dialogue choice index."}

	var chosen: Dictionary = choices[choice_index]
	if chosen.has("action"):
		_execute_dialogue_action(str(chosen["action"]))

	var next_node: String = str(chosen.get("next", "END"))
	if next_node == "END":
		var ended_npc: String = active_dialogue_npc_id
		end_dialogue()
		return {"ok": true, "ended": true, "npc_id": ended_npc}

	active_dialogue_node_id = next_node
	var payload: Dictionary = get_current_dialogue_node()
	dialogue_advanced.emit(
		active_dialogue_npc_id,
		active_dialogue_node_id,
		payload.get("speaker", ""),
		payload.get("text", ""),
		payload.get("choices", [])
	)
	return payload


func end_dialogue() -> void:
	if not active_dialogue_npc_id.is_empty():
		var npc_id: String = active_dialogue_npc_id
		active_dialogue_npc_id = ""
		active_dialogue_node_id = ""
		dialogue_ended.emit(npc_id)


func _execute_dialogue_action(action_str: String) -> void:
	var parts: PackedStringArray = action_str.split(":")
	if parts.is_empty():
		return
	match parts[0]:
		"start_quest":
			if parts.size() >= 2:
				start_quest(parts[1])
		"rep":
			if parts.size() >= 3:
				modify_reputation(parts[1], int(parts[2]))
		"check_rm_readiness":
			check_reverse_mountain_readiness()


# ---------------------------------------------------------------------------
# 3. West Blue Quest State Machines
# ---------------------------------------------------------------------------
func _initialize_quests() -> void:
	quest_states = {
		"quest_sunken_codices": {
			"id": "quest_sunken_codices",
			"title": "Sunken Codices of the Lake of Knowledge",
			"island_id": "ohara",
			"stage": "not_started", # not_started -> accepted -> diving_lake -> completed
			"objective": "Speak with Aron the Ink-Stained at Ohara's Smuggler Camp.",
			"reward_beli": 120_000,
			"reward_items": ["ancient_kingdom_lexicon"],
			"reputation_reward": {"ohara_scholars": 25},
		},
		"quest_eight_impacts_tournament": {
			"id": "quest_eight_impacts_tournament",
			"title": "Eight Impacts Tournament",
			"island_id": "kano_country",
			"stage": "not_started", # not_started -> accepted -> monolith_trial -> completed
			"objective": "Challenge Don Chinjao at the Chinjao Family Grand Dojo.",
			"reward_beli": 180_000,
			"reward_items": ["hasshoken_vibration_scroll"],
			"reputation_reward": {"happo_navy": 30},
		},
		"quest_five_families_contraband": {
			"id": "quest_five_families_contraband",
			"title": "Five Families Contraband Run",
			"island_id": "castello_del_capone",
			"stage": "not_started", # not_started -> accepted -> smuggling_run -> completed
			"objective": "Meet Don Vincenzo at The Godfather's Speakeasy in Castello del Capone.",
			"reward_beli": 220_000,
			"reward_items": ["marine_transit_manifest_forged"],
			"reputation_reward": {"five_families": 25},
		},
		"quest_caldera_of_shadows": {
			"id": "quest_caldera_of_shadows",
			"title": "Caldera of Shadows",
			"island_id": "tomb_of_thriller",
			"stage": "not_started", # not_started -> accepted -> theater_catacombs -> completed
			"objective": "Speak with Madame Beatrice at Cindry's Shore in the Tomb of Thriller.",
			"reward_beli": 160_000,
			"reward_items": ["embalming_salve", "cindry_stage_poster"],
			"reputation_reward": {"esperia_guild": 10},
		},
		"quest_ghost_coordinates_38": {
			"id": "quest_ghost_coordinates_38",
			"title": "Ghost Coordinates of 38 Years Ago",
			"island_id": "god_valley",
			"stage": "not_started", # not_started -> accepted -> abyssal_dive -> completed
			"objective": "Consult Hermit Darrow on the God Valley Ghost Reef before heading to Reverse Mountain.",
			"reward_beli": 500_000,
			"reward_items": ["ancient_native_totem", "corrupted_magnetic_pose"],
			"reputation_reward": {"ohara_scholars": 20},
		},
	}


func get_quest_status(quest_id: String) -> Dictionary:
	return quest_states.get(quest_id, {}).duplicate(true)


func get_all_quests() -> Dictionary:
	return quest_states.duplicate(true)


func start_quest(quest_id: String) -> Dictionary:
	if not quest_states.has(quest_id):
		return {"ok": false, "reason": "Unknown quest ID: " + quest_id}
	var q: Dictionary = quest_states[quest_id]
	if q["stage"] != "not_started":
		return {"ok": true, "already_active": true, "quest": q.duplicate(true)}
	var prev: String = str(q["stage"])
	q["stage"] = "accepted"
	match quest_id:
		"quest_sunken_codices":
			q["objective"] = "Stealth-dive the Lake of Knowledge past Cipher Pol Watcher 'Kestrel'."
		"quest_eight_impacts_tournament":
			q["objective"] = "Shatter the 5m granite monolith and defeat the Happo Navy champion."
		"quest_five_families_contraband":
			q["objective"] = "Run Five Families contraband from Castello del Capone to Las Camp."
		"quest_caldera_of_shadows":
			q["objective"] = "Descend into Cindry's flooded theater catacombs with a Ghost-Lantern."
		"quest_ghost_coordinates_38":
			q["objective"] = "Navigate God Valley's magnetic anomaly and dive 150m to the sunken pavilion."
	quest_state_changed.emit(quest_id, prev, "accepted", str(q["objective"]))
	return {"ok": true, "quest": q.duplicate(true)}


func _complete_quest(quest_id: String) -> Dictionary:
	var q: Dictionary = quest_states[quest_id]
	if q["stage"] == "completed":
		return {"ok": true, "already_completed": true, "quest": q.duplicate(true)}

	var prev: String = str(q["stage"])
	q["stage"] = "completed"
	q["objective"] = "Completed"

	var reward_beli: int = int(q.get("reward_beli", 0))
	_add_beli(reward_beli)

	var unlocked: Array = q.get("reward_items", [])
	for item_id in unlocked:
		add_inventory_item(str(item_id), 1)

	var rep_rewards: Dictionary = q.get("reputation_reward", {})
	for faction in rep_rewards:
		modify_reputation(str(faction), int(rep_rewards[faction]))

	quest_state_changed.emit(quest_id, prev, "completed", "Completed")
	quest_completed.emit(quest_id, reward_beli, unlocked)
	return {"ok": true, "quest": q.duplicate(true), "reward_beli": reward_beli, "unlocked_items": unlocked}


## Quest 1 Gameplay: Ohara stealth dive past Cipher Pol patrols.
func attempt_ohara_stealth_dive(stealth_rating: float, force_dive_without_lantern: bool = false) -> Dictionary:
	var q_id: String = "quest_sunken_codices"
	if quest_states[q_id]["stage"] == "not_started":
		start_quest(q_id)
	var has_lantern: bool = has_inventory_item("waterproof_antiquity_lantern")
	if not has_lantern and not force_dive_without_lantern:
		return {"ok": false, "detected": false, "reason": "Equip a Waterproof Antiquity Dive Lantern first."}

	var effective_stealth: float = stealth_rating + (0.25 if has_lantern else -0.20)
	if has_inventory_item("marine_transit_manifest_forged"):
		effective_stealth += 0.25

	if effective_stealth < 0.60:
		modify_reputation("world_government", -10)
		return {
			"ok": false,
			"detected": true,
			"reason": "Cipher Pol Watcher 'Kestrel' spotted your air bubbles! Evade patrol and improve stealth.",
		}

	var result: Dictionary = _complete_quest(q_id)
	result["detected"] = false
	return result


## Quest 2 Gameplay: Kano Country Eight Impacts Tournament duel & armored prow unlock.
func attempt_kano_tournament_duel(player_combat_power: float) -> Dictionary:
	var q_id: String = "quest_eight_impacts_tournament"
	if quest_states[q_id]["stage"] == "not_started":
		start_quest(q_id)
	var effective_power: float = player_combat_power
	if has_inventory_item("kano_lotus_baijiu"):
		effective_power *= 1.20
	if has_inventory_item("reinforced_bisen_naginata"):
		effective_power += 25.0

	if effective_power < 80.0:
		return {
			"ok": false,
			"reason": "Your strike lacked vibrational resonance (Power %.1f < 80.0). Train or equip Kano gear." % effective_power,
		}

	# Completing the tournament elevates Happo Navy standing above 40, unlocking Dragon-Prow Ram purchase
	var result: Dictionary = _complete_quest(q_id)
	result["dragon_prow_unlocked"] = int(faction_reputation.get("happo_navy", 0)) >= 40
	return result


## Quest 3 Gameplay: Five Families Contraband Run to Las Camp.
func attempt_contraband_smuggling_run() -> Dictionary:
	var q_id: String = "quest_five_families_contraband"
	if quest_states[q_id]["stage"] == "not_started":
		start_quest(q_id)

	var has_lead_chest: bool = has_inventory_item("lead_lined_contraband_chest") or installed_ship_upgrades.get("smuggler_hold", "") == "five_families_lead_vault"
	var has_manifest: bool = has_inventory_item("marine_transit_manifest_forged")
	if not has_lead_chest and not has_manifest:
		modify_reputation("world_government", -15)
		return {
			"ok": false,
			"reason": "Marine blockade inspected your hold! Acquire a Lead-Lined Contraband Chest or Forged Manifest.",
		}

	return _complete_quest(q_id)


## Quest 4 Gameplay: Tomb of Thriller Bark & Victoria Cindry's theater catacombs.
func explore_thriller_caldera() -> Dictionary:
	var q_id: String = "quest_caldera_of_shadows"
	if quest_states[q_id]["stage"] == "not_started":
		start_quest(q_id)
	if not has_inventory_item("ghost_lantern"):
		return {
			"ok": false,
			"reason": "The flooded theater catacombs are shrouded in supernatural fog. Acquire a Ghost-Lantern of the Pale Sea.",
		}
	return _complete_quest(q_id)


## Quest 5 Gameplay: Navigating God Valley's 38-year-old magnetic void & abyssal dive.
func navigate_god_valley_anomaly() -> Dictionary:
	var q_id: String = "quest_ghost_coordinates_38"
	if quest_states[q_id]["stage"] == "not_started":
		start_quest(q_id)

	var has_chronometer: bool = has_inventory_item("precision_chronometer")
	var has_helmet: bool = has_inventory_item("abyss_diving_helmet")
	god_valley_anomaly_triggered.emit(142.5 if not has_chronometer else 0.0, 150.0)

	if not has_chronometer:
		return {
			"ok": false,
			"reason": "Standard compasses spin wildly in God Valley's severed magnetic core. Equip an Ilusian Precision Chronometer.",
		}
	if not has_helmet:
		return {
			"ok": false,
			"reason": "The Celestial Hunting Pavilion lies 150m below the ghost reef. Equip an Abyssal Atmospheric Diving Helmet.",
		}

	var result: Dictionary = _complete_quest(q_id)
	result["reverse_mountain_readiness"] = check_reverse_mountain_readiness()
	return result
