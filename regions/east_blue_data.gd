class_name EastBlueData
extends RefCounted
## Canonical East Blue regional dataset for Project "Blue Planet" (Godot 4.3+, precision=double).
##
## Sector Bounds:
##   - Latitude (theta): +15.0 deg to +75.0 deg
##   - Longitude (phi):   0.0 deg to +90.0 deg
##   - Bounded on the west by the Red Line (+45 deg Great Circle) and on the south by
##     the 150 km North Calm Belt. Trade routes converge toward Loguetown and the
##     East Blue Reverse Mountain ascending hydraulic canal at (lat=0.0, lon=0.0).
##
## Scale Baseline:
##   - 1 Godot unit = 1.0 meter, Planet Sea-Level Radius R = 16,000,000.0 meters.

const PLANET_RADIUS_M: float = 16_000_000.0
const SEA_ID: String = "east_blue"
const CURRENCY_ID: String = "beli"

const SECTOR_LAT_MIN_DEG: float = 15.0
const SECTOR_LAT_MAX_DEG: float = 75.0
const SECTOR_LON_MIN_DEG: float = 0.0
const SECTOR_LON_MAX_DEG: float = 90.0

## East Blue Reverse Mountain canal approach coordinates (hand-off to ReverseMountainController).
const REVERSE_MOUNTAIN_APPROACH: Dictionary = {
	"buoy_id": "eb_rm_approach_buoy",
	"buoy_name": "East Blue Canal Approach Current",
	"approach_lat_deg": 15.0,
	"approach_lon_deg": 8.5,
	"canal_mouth_lat_deg": 2.0,
	"canal_mouth_lon_deg": 2.0,
	"summit_lat_deg": 0.0,
	"summit_lon_deg": 0.0,
	"summit_altitude_m": 5000.0,
	"canal_width_m": 400.0,
	"notes": "Follow the rushing winter current southwest from Loguetown. Keep helm centered inside the 400m canal walls."
}


## Returns true if spherical coordinates (deg) fall inside the East Blue sector.
static func is_in_east_blue_sector(lat_deg: float, lon_deg: float) -> bool:
	return (
		lat_deg >= SECTOR_LAT_MIN_DEG
		and lat_deg <= SECTOR_LAT_MAX_DEG
		and lon_deg >= SECTOR_LON_MIN_DEG
		and lon_deg <= SECTOR_LON_MAX_DEG
	)


## Converts planetary spherical coordinates (lat_deg, lon_deg, alt_m) to 64-bit world Vector3 (Y-up).
static func lat_lon_to_world_pos(lat_deg: float, lon_deg: float, alt_m: float = 0.0) -> Vector3:
	var lat_rad: float = deg_to_rad(lat_deg)
	var lon_rad: float = deg_to_rad(lon_deg)
	var r: float = PLANET_RADIUS_M + alt_m
	var cos_lat: float = cos(lat_rad)
	return Vector3(
		r * cos_lat * cos(lon_rad),
		r * sin(lat_rad),
		r * cos_lat * sin(lon_rad)
	)


## Computes great-circle surface distance in meters between two (lat, lon) pairs at sea level.
static func great_circle_distance_m(lat_a: float, lon_a: float, lat_b: float, lon_b: float) -> float:
	var phi1: float = deg_to_rad(lat_a)
	var phi2: float = deg_to_rad(lat_b)
	var d_phi: float = deg_to_rad(lat_b - lat_a)
	var d_lam: float = deg_to_rad(lon_b - lon_a)
	var a: float = sin(d_phi * 0.5) * sin(d_phi * 0.5) + cos(phi1) * cos(phi2) * sin(d_lam * 0.5) * sin(d_lam * 0.5)
	var c: float = 2.0 * atan2(sqrt(a), sqrt(maxf(0.0, 1.0 - a)))
	return PLANET_RADIUS_M * c


## Returns every canonical East Blue island and maritime landmark in structured dictionary form.
static func get_all_islands() -> Array[Dictionary]:
	var islands: Array[Dictionary] = [
		_build_dawn_island(),
		_build_goat_island(),
		_build_shells_town(),
		_build_shimotsuki_village(),
		_build_organ_islands(),
		_build_island_of_rare_animals(),
		_build_gecko_islands(),
		_build_baratie(),
		_build_conomi_islands(),
		_build_loguetown(),
		_build_tequila_wolf(),
		_build_sixis(),
		_build_mirrorball_island(),
		_build_kumate_island(),
		_build_oykot_kingdom(),
		_build_minor_kingdoms_frauce(),
		_build_minor_kingdoms_nagagutsu(),
		_build_minor_kingdoms_satsuruzo(),
		_build_minor_kingdoms_cozia()
	]
	return islands


## Looks up a single East Blue island by its string ID; returns empty Dictionary if not found.
static func get_island(island_id: String) -> Dictionary:
	for island: Dictionary in get_all_islands():
		if island.get("id", "") == island_id:
			return island
	return {}


## Returns all islands matching a given danger tier (1=Starter, 5=High Hazard/WG).
static func get_islands_by_danger_tier(tier: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for island: Dictionary in get_all_islands():
		if int(island.get("danger_tier", 1)) == tier:
			out.append(island)
	return out


## Returns a flattened list of all shops, bars, markets, and shipyards across East Blue.
static func get_all_shops() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for island: Dictionary in get_all_islands():
		var island_id: String = island.get("id", "")
		var island_name: String = island.get("name", "")
		for shop: Dictionary in island.get("shops", []):
			var entry: Dictionary = shop.duplicate(true)
			entry["island_id"] = island_id
			entry["island_name"] = island_name
			out.append(entry)
	return out


## Returns all shops on a specific island.
static func get_shops_on_island(island_id: String) -> Array[Dictionary]:
	var island: Dictionary = get_island(island_id)
	if island.is_empty():
		return []
	var out: Array[Dictionary] = []
	for shop: Dictionary in island.get("shops", []):
		out.append(shop)
	return out


## Returns a flattened list of all named canon and archetype NPCs in East Blue.
static func get_all_npcs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for island: Dictionary in get_all_islands():
		var island_id: String = island.get("id", "")
		var island_name: String = island.get("name", "")
		for npc: Dictionary in island.get("npcs", []):
			var entry: Dictionary = npc.duplicate(true)
			entry["island_id"] = island_id
			entry["island_name"] = island_name
			out.append(entry)
	return out


## Returns all NPCs residing at a specific island.
static func get_npcs_on_island(island_id: String) -> Array[Dictionary]:
	var island: Dictionary = get_island(island_id)
	if island.is_empty():
		return []
	var out: Array[Dictionary] = []
	for npc: Dictionary in island.get("npcs", []):
		out.append(npc)
	return out


## Returns all quest hooks across East Blue, or filtered by island_id when provided.
static func get_quest_hooks(island_id: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for island: Dictionary in get_all_islands():
		var cur_id: String = island.get("id", "")
		if not island_id.is_empty() and cur_id != island_id:
			continue
		for q: Dictionary in island.get("quest_hooks", []):
			var entry: Dictionary = q.duplicate(true)
			entry["island_id"] = cur_id
			out.append(entry)
	return out


## Returns primary canonical sea lanes and trade routes leading toward Loguetown and Reverse Mountain.
static func get_trade_routes() -> Array[Dictionary]:
	return [
		{
			"id": "route_straw_hat_main",
			"name": "Dawn-to-Loguetown Great Voyage Route",
			"waypoints": [
				"dawn_island",
				"goat_island",
				"shells_town",
				"organ_islands",
				"island_of_rare_animals",
				"gecko_islands",
				"baratie",
				"conomi_islands",
				"loguetown",
				"reverse_mountain_east_blue_canal"
			],
			"recommended_vessel": "Caravel (Going Merry class) or Sloop",
			"cargo_highlights": ["Foosha Spiced Ale", "Cocoyasi Tangerines", "All-Blue Preserves", "Meito Blades"],
			"notes": "Primary starter progression route across East Blue leading directly to the Reverse Mountain entrance."
		},
		{
			"id": "route_eastern_dojo_circuit",
			"name": "Eastern Blade & Livestock Run",
			"waypoints": ["dawn_island", "shimotsuki_village", "shells_town", "kumate_island", "mirrorball_island"],
			"recommended_vessel": "Coastal Sloop",
			"cargo_highlights": ["Wado Maintenance Kits", "Colubo Boar Meat", "Marine Timber"],
			"notes": "Connects Dawn Island and Shimotsuki Village down toward southeastern East Blue."
		},
		{
			"id": "route_sambas_citrus_trade",
			"name": "Sambas-Conomi Maritime Supply Line",
			"waypoints": ["baratie", "conomi_islands", "loguetown"],
			"recommended_vessel": "Merchant Brig",
			"cargo_highlights": ["Cocoyasi Tangerine Trees", "Elephant Bluefin Tuna", "Scurvy-Curing Rations"],
			"notes": "Crucial provisioning lane near the North Calm Belt border before entering Reverse Mountain."
		},
		{
			"id": "route_northern_smuggler_run",
			"name": "Northern Ice-Bridge Smuggler Route",
			"waypoints": ["sixis", "tequila_wolf", "oykot_kingdom", "frauce_kingdom", "loguetown"],
			"recommended_vessel": "Reinforced Schooner",
			"cargo_highlights": ["Cold-Weather Coats", "Void Century Bridge Rubbings", "Salvaged Scrap"],
			"notes": "High-risk northern sea route avoiding Marine patrols near Tequila Wolf."
		}
	]


## Returns the Reverse Mountain canal handoff data for East Blue ships heading into the Grand Line.
static func get_reverse_mountain_route() -> Dictionary:
	return REVERSE_MOUNTAIN_APPROACH.duplicate(true)


# ------------------------------------------------------------------------------
# Private Helper Builders
# ------------------------------------------------------------------------------

static func _item(
	item_id: String,
	item_name: String,
	category: String,
	price_beli: int,
	stock: int,
	effects: String,
	canon_note: String = ""
) -> Dictionary:
	return {
		"item_id": item_id,
		"name": item_name,
		"category": category,
		"price_beli": price_beli,
		"stock": stock,
		"effects": effects,
		"canon_note": canon_note
	}


static func _npc(
	npc_id: String,
	npc_name: String,
	role: String,
	affiliation: String,
	location_id: String,
	is_canon: bool,
	is_hostile: bool,
	services: Array[String],
	dialogue_hook: String,
	bounty_beli: int = 0
) -> Dictionary:
	return {
		"id": npc_id,
		"name": npc_name,
		"role": role,
		"affiliation": affiliation,
		"location_id": location_id,
		"is_canon": is_canon,
		"is_hostile": is_hostile,
		"services": services,
		"dialogue_hook": dialogue_hook,
		"bounty_beli": bounty_beli
	}


static func _build_dawn_island() -> Dictionary:
	return {
		"id": "dawn_island",
		"name": "Dawn Island",
		"archipelago_or_region": "Goa Kingdom Territory",
		"sea": SEA_ID,
		"lat_deg": 52.0,
		"lon_deg": 74.0,
		"altitude_m": 0.0,
		"island_radius_m": 22000.0,
		"biome": "Temperate Forest, Coastal Village, Walled Capital & Scrapyard Slum",
		"climate": "Mild Four-Season Temperate",
		"danger_tier": 1,
		"currency": CURRENCY_ID,
		"is_starter_hub": true,
		"is_canonical": true,
		"has_dock": true,
		"settlements": [
			{
				"id": "foosha_village",
				"name": "Foosha Village (Windmill Village)",
				"type": "starter_port_village",
				"lat_offset_deg": -0.08,
				"lon_offset_deg": 0.12,
				"elevation_m": 4.0,
				"description": "Peaceful windmill-dotted port on Dawn Island's eastern shore where Luffy grew up.",
				"features": ["Windmills", "Partys Bar", "Foosha Fish Pier", "Dinghy Mooring"]
			},
			{
				"id": "mt_colubo",
				"name": "Mt. Colubo",
				"type": "mountain_wilderness",
				"lat_offset_deg": -0.02,
				"lon_offset_deg": 0.04,
				"elevation_m": 620.0,
				"description": "Rugged mountain behind Foosha Village housing the Dadan Family bandit hideout and giant beasts.",
				"features": ["Dadan Family Hut", "Giant Tiger Territory", "Lookout Cliff"]
			},
			{
				"id": "midway_forest",
				"name": "Midway Forest",
				"type": "dense_forest",
				"lat_offset_deg": 0.01,
				"lon_offset_deg": -0.02,
				"elevation_m": 120.0,
				"description": "Dangerous jungle corridor linking Mt. Colubo to the Gray Terminal.",
				"features": ["Predator Dens", "Secret Treehouse Trail"]
			},
			{
				"id": "gray_terminal",
				"name": "Gray Terminal",
				"type": "scrapyard_slum",
				"lat_offset_deg": 0.04,
				"lon_offset_deg": -0.06,
				"elevation_m": 15.0,
				"description": "Lawless, mountainous landfill outside Goa Kingdom's Great Gate.",
				"features": ["Scrap Heaps", "Outcast Camps", "Bluejam Pier"]
			},
			{
				"id": "edge_town",
				"name": "Edge Town",
				"type": "walled_outer_district",
				"lat_offset_deg": 0.05,
				"lon_offset_deg": -0.08,
				"elevation_m": 25.0,
				"description": "Outermost district inside Goa Kingdom's massive stone perimeter wall.",
				"features": ["Great Outer Gate", "Customs Checkpoint"]
			},
			{
				"id": "town_center",
				"name": "Town Center",
				"type": "middle_class_city",
				"lat_offset_deg": 0.07,
				"lon_offset_deg": -0.10,
				"elevation_m": 45.0,
				"description": "Bustling artisan and merchant district of Goa Kingdom.",
				"features": ["Craftsman Guilds", "Watch Garrison"]
			},
			{
				"id": "high_town",
				"name": "High Town & Goa Royal Palace",
				"type": "noble_citadel",
				"lat_offset_deg": 0.09,
				"lon_offset_deg": -0.12,
				"elevation_m": 110.0,
				"description": "Wealthy innermost walled citadel reserved for Goa royalty and nobility.",
				"features": ["Goa Royal Palace", "High Town Royal Bazaar", "Inner Noble Gate"]
			}
		],
		"shops": [
			{
				"id": "partys_bar",
				"name": "Partys Bar",
				"type": "tavern",
				"keeper_npc_id": "makino",
				"location_id": "foosha_village",
				"description": "Cozy timber tavern run by Makino; former hangout of the Red Hair Pirates.",
				"inventory": [
					_item("foosha_spiced_ale", "Foosha Spiced Ale", "beverage", 350, 20, "Restores +25 Stamina; boosts crew morale", "Served to Shanks and his crew"),
					_item("fresh_milk_mug", "Foosha Pasture Milk", "beverage", 150, 30, "Restores +20 HP and clears mild fatigue", "Luffy's childhood staple"),
					_item("partys_meat_platter", "Partys Bar Roast Platter", "food", 650, 12, "Restores +60 HP, +40 Stamina", ""),
					_item("starter_sea_rations", "Starter Sea Travel Rations", "provision", 1200, 15, "3 days ship crew food supply", ""),
					_item("treasure_tree_juice", "Goa Citrus Juice", "beverage", 250, 25, "Prevents early scurvy for 2 days", "")
				]
			},
			{
				"id": "foosha_fish_market",
				"name": "Foosha Fish Pier Stall",
				"type": "market",
				"keeper_npc_id": "gyoru",
				"location_id": "foosha_village",
				"description": "Harbor-side wooden stall run by Gyoru selling fresh East Blue catch.",
				"inventory": [
					_item("east_blue_bream", "Fresh East Blue Sea Bream", "food", 400, 18, "Cooking ingredient or +30 HP grilled", "Gyoru's daily catch"),
					_item("salted_mackerel_barrel", "Salted Mackerel Barrel", "provision", 2400, 8, "6 days preserved ship rations", ""),
					_item("bamboo_fishing_rod", "Beginner Bamboo Fishing Rod", "tool", 1800, 5, "Allows fishing off dinghy or pier", ""),
					_item("bait_pouch", "Shrimp & Worm Bait Pouch", "consumable", 200, 30, "20 fishing casts", "")
				]
			},
			{
				"id": "colubo_bandit_camp_trade",
				"name": "Mt. Colubo Bandit Supply Cache",
				"type": "outfitter",
				"keeper_npc_id": "curly_dadan",
				"location_id": "mt_colubo",
				"description": "Rough-hewn mountain shack where the Dadan Family trades forest pelts and survival gear.",
				"inventory": [
					_item("colubo_boar_meat", "Colubo Giant Boar Steak", "food", 950, 10, "Restores +95 HP, +50 Stamina", "Hunted in Mt. Colubo"),
					_item("bandit_iron_pipe", "Reinforced Steel Pipe", "weapon", 3200, 3, "Blunt melee weapon (+12 ATK)", "Sabo/Ace/Luffy childhood sparring gear"),
					_item("mountain_flint", "Bandit Flint & Tinderbox", "tool", 450, 12, "Starts campfires in rain", ""),
					_item("forest_antidote", "Colubo Herbal Antidote", "medicine", 700, 10, "Cures forest venom and poison", "")
				]
			},
			{
				"id": "gray_terminal_scrap_exchange",
				"name": "Gray Terminal Scrap Exchange",
				"type": "black_market",
				"keeper_npc_id": "gray_scrap_broker",
				"location_id": "gray_terminal",
				"description": "Shanty stall trading salvaged noble castoffs, scrap metal, and cheap ship repair timber.",
				"inventory": [
					_item("salvaged_noble_scrap", "Salvaged Noble Silverware", "trade_good", 1500, 14, "Resells for 2,800 Beli at Shells Town or Loguetown", ""),
					_item("driftwood_repair_planks", "Scrap Hull Repair Planks", "ship_supply", 900, 20, "Repairs +15% dinghy/sloop hull integrity", ""),
					_item("rusted_cutlass", "Rusted Sailor Cutlass", "weapon", 2500, 6, "Entry slashing blade (+10 ATK)", ""),
					_item("whale_oil_lantern", "Salvaged Brass Lantern", "tool", 1100, 8, "Illuminates night/cave exploration", "")
				]
			},
			{
				"id": "high_town_royal_bazaar",
				"name": "High Town Royal Bazaar",
				"type": "boutique_market",
				"keeper_npc_id": "goa_royal_purveyor",
				"location_id": "high_town",
				"description": "Exclusive aristocratic plaza inside Goa's inner walls. Requires High Town pass or noble disguise.",
				"inventory": [
					_item("goa_silk_coat", "Goa Aristocrat Silk Coat", "armor", 18000, 4, "+15 Defense, +10 Charisma with nobles", ""),
					_item("goa_royal_tea_crate", "Goa Imperial Tea Crate", "trade_good", 8500, 6, "High-margin luxury trade good for Loguetown", ""),
					_item("brass_pocket_compass", "Precision East Blue Compass", "navigation", 6500, 5, "Displays accurate north bearing across all Four Blues", ""),
					_item("dawn_island_charter", "Goa Harbor Exit Charter", "permit", 5000, 10, "Official customs clearance for starter vessels", "")
				]
			}
		],
		"npcs": [
			_npc("makino", "Makino", "Bartender & Owner of Partys Bar", "Foosha Village", "foosha_village", true, false, ["shop", "rest", "quest", "rumors"], "Welcome back to Partys Bar! Taking a dinghy out to sea already? Take some provisions before the Lord of the Coast spots you."),
			_npc("woop_slap", "Mayor Woop Slap", "Village Mayor", "Foosha Village", "foosha_village", true, false, ["quest", "lore", "harbor_permit"], "Becoming a pirate brings nothing but shame to the village... Wait, you're leaving anyway? At least take this coastal chart!"),
			_npc("gyoru", "Gyoru", "Fishmonger", "Foosha Village", "foosha_village", true, false, ["shop", "fishing_tips"], "Fresh bream straight off the pier! Watch the deep water past the headland."),
			_npc("curly_dadan", "Curly Dadan", "Boss of the Dadan Family", "Mt. Colubo", "mt_colubo", true, false, ["shop", "survival_training", "quest"], "Don't tell Garp I helped you! If you want to survive the sea, learn to hunt a Colubo giant tiger first."),
			_npc("dogra", "Dogra", "Mountain Bandit Scout", "Mt. Colubo", "mt_colubo", true, false, ["lore", "trail_guide"], "Keep your head down near Midway Forest—there are crocodiles bigger than boats."),
			_npc("magra", "Magra", "Mountain Bandit", "Mt. Colubo", "mt_colubo", true, false, ["lore"], "Boss Dadan pretends to be tough, but she keeps extra bandages in the shed."),
			_npc("king_stelly", "King Stelly", "Monarch of Goa Kingdom", "High Town", "high_town", true, false, ["faction_lore"], "Commoners should stay outside the Great Gate! Only true nobles belong in High Town."),
			_npc("minatomo_eb", "Minatomo", "Traveling Door Carpenter", "Foosha Village", "foosha_village", true, false, ["repair_gag", "ship_patch"], "Who broke this tavern door?! Stand aside, it'll be fixed in three seconds!"),
			_npc("gray_scrap_broker", "Raggedy Scrap Broker", "Salvage Trader", "Gray Terminal", "gray_terminal", false, false, ["shop", "black_market"], "Nobles throw away half a fortune every week. Buy cheap here, sell high at Loguetown."),
			_npc("goa_royal_purveyor", "High Town Purveyor", "Royal Merchant", "High Town", "high_town", false, false, ["shop"], "Only the finest silks and compasses pass through Goa's inner gate."),
			_npc("higuma_remnant", "Higuma's Mountain Bandits", "Hostile Bandit Remnant", "Mt. Colubo", "mt_colubo", true, true, ["combat"], "Hand over your Beli before you even reach the harbor!"),
			_npc("lord_of_the_coast", "Lord of the Coast", "Local Sea King Boss", "Foosha Offshore Reef", "foosha_village", true, true, ["boss_encounter"], "A 30-meter Sea King guarding the bay outside Foosha Village.")
		],
		"quest_hooks": [
			{
				"id": "q_dawn_first_sail",
				"title": "A Dinghy and a Dream",
				"giver_npc_id": "makino",
				"min_tier": 1,
				"objectives": ["Speak with Mayor Woop Slap for a harbor permit", "Buy Starter Sea Travel Rations at Partys Bar", "Sail past Foosha Reef and survive or evade the Lord of the Coast"],
				"rewards_beli": 5000,
				"unlocks": ["east_blue_starter_chart", "goat_island_waypoint"]
			},
			{
				"id": "q_colubo_tiger_trial",
				"title": "Dadan's Mountain Trial",
				"giver_npc_id": "curly_dadan",
				"min_tier": 1,
				"objectives": ["Track and defeat a Mt. Colubo Giant Boar or Tiger", "Recover stolen supplies from Higuma's remnant camp"],
				"rewards_beli": 8000,
				"unlocks": ["survival_stamina_perk"]
			}
		],
		"local_specialties": ["Foosha Spiced Ale", "Colubo Boar Meat", "Goa Aristocrat Silks", "Salvaged Noble Scrap"],
		"wildlife_and_hazards": ["Lord of the Coast (Sea King)", "Mt. Colubo Giant Tigers & Bears", "Midway Forest Crocodiles", "Gray Terminal Fires"],
		"lore_summary": "Birthplace of Monkey D. Luffy and childhood home of Portgas D. Ace and Sabo. Governed by the starkly stratified Goa Kingdom."
	}


static func _build_goat_island() -> Dictionary:
	return {
		"id": "goat_island",
		"name": "Goat Island",
		"archipelago_or_region": "Eastern Sea Crags",
		"sea": SEA_ID,
		"lat_deg": 47.0,
		"lon_deg": 78.5,
		"altitude_m": 0.0,
		"island_radius_m": 3200.0,
		"biome": "Craggy Limestone Island & Hidden Pirate Cove",
		"climate": "Mild Coastal Breeze",
		"danger_tier": 1,
		"currency": CURRENCY_ID,
		"is_starter_hub": false,
		"is_canonical": true,
		"has_dock": true,
		"settlements": [
			{
				"id": "alvida_cove",
				"name": "Alvida Pirates Hidden Cove",
				"type": "pirate_hideout",
				"lat_offset_deg": 0.0,
				"lon_offset_deg": 0.0,
				"elevation_m": 6.0,
				"description": "Rocky sea cave where 'Iron Mace' Alvida moored the Miss Love Duck in the manga.",
				"features": ["Barrel Storage", "Lookout Ridge", "Pirate Anchor Point"]
			}
		],
		"shops": [
			{
				"id": "alvida_cove_stash",
				"name": "Cove Salvage Cask",
				"type": "cache",
				"keeper_npc_id": "koby_goat",
				"location_id": "alvida_cove",
				"description": "Plundered merchant crates rescued after driving off Alvida's lookout.",
				"inventory": [
					_item("stolen_cider_barrel", "Recovered Cider Barrel", "provision", 800, 5, "Restores crew stamina and trades well at Shells Town", "Same barrel Luffy popped out of"),
					_item("iron_stud_club_scrap", "Pirate Scrap Iron", "material", 600, 8, "Basic weapon forging material", "")
				]
			}
		],
		"npcs": [
			_npc("alvida", "Iron Mace Alvida", "Captain of the Alvida Pirates", "Alvida Pirates", "alvida_cove", true, true, ["boss_encounter"], "Who is the most beautiful woman on all these seas?!", 5000000),
			_npc("koby_goat", "Koby", "Forced Chore Boy", "Alvida Pirates (Captive)", "alvida_cove", true, false, ["quest", "ally_escort"], "I just want to join the Marines and catch bad guys... Help me escape to Shells Town!"),
			_npc("heppoko", "Heppoko", "Alvida Pirate Lookout", "Alvida Pirates", "alvida_cove", true, true, ["combat"], "Hey! How'd a kid break out of that barrel?!")
		],
		"quest_hooks": [
			{
				"id": "q_goat_escape_alvida",
				"title": "The Barrel & The Chore Boy",
				"giver_npc_id": "koby_goat",
				"min_tier": 1,
				"objectives": ["Defeat Iron Mace Alvida at Goat Island Cove", "Escort Koby safely across to Shells Town Harbor"],
				"rewards_beli": 12000,
				"unlocks": ["shells_town_waypoint", "koby_marine_contact"]
			}
		],
		"local_specialties": ["Recovered Merchant Cider", "Coastal Goat Cheese"],
		"wildlife_and_hazards": ["Alvida Pirate Sentries", "Jagged Limestone Reefs"],
		"lore_summary": "Canon manga hideout of the Alvida Pirates where Luffy emerged from a drifting barrel and freed Koby."
	}


static func _build_shells_town() -> Dictionary:
	return {
		"id": "shells_town",
		"name": "Shells Town",
		"archipelago_or_region": "Yotsuba Island Region",
		"sea": SEA_ID,
		"lat_deg": 46.5,
		"lon_deg": 68.0,
		"altitude_m": 0.0,
		"island_radius_m": 8500.0,
		"biome": "Fortified Coastal Garrison Town",
		"climate": "Temperate Harbor",
		"danger_tier": 2,
		"currency": CURRENCY_ID,
		"is_starter_hub": false,
		"is_canonical": true,
		"has_dock": true,
		"settlements": [
			{
				"id": "shells_harbor",
				"name": "Shells Town Harbor",
				"type": "port",
				"lat_offset_deg": -0.02,
				"lon_offset_deg": 0.03,
				"elevation_m": 2.0,
				"description": "Busy Marine-patrolled port serving the 153rd Branch.",
				"features": ["Marine Pier", "Supply Stalls"]
			},
			{
				"id": "shells_town_square",
				"name": "Shells Town Square & Tavern Quarter",
				"type": "town",
				"lat_offset_deg": 0.0,
				"lon_offset_deg": 0.0,
				"elevation_m": 12.0,
				"description": "Residential streets and eateries living under Morgan's strict curfew.",
				"features": ["Food Foo Tavern", "Town Fountain"]
			},
			{
				"id": "marine_base_153",
				"name": "Marine Base 153rd Branch",
				"type": "marine_fortress",
				"lat_offset_deg": 0.03,
				"lon_offset_deg": -0.02,
				"elevation_m": 38.0,
				"description": "Hilltop fortress topped by Captain Morgan's towering stone statue and courtyard execution posts.",
				"features": ["Execution Courtyard", "Morgan Statue Rooftop", "Base 153 Armory"]
			}
		],
		"shops": [
			{
				"id": "food_foo",
				"name": "Food Foo (Ririka's Food & Bar)",
				"type": "tavern",
				"keeper_npc_id": "ririka",
				"location_id": "shells_town_square",
				"description": "Beloved local restaurant and bar run by Ririka and her young daughter Rika.",
				"inventory": [
					_item("rika_sweet_onigiri", "Rika's Sweet Sugar Onigiri", "food", 150, 25, "Restores +35 HP, +25 Stamina; boosts Resolve", "Made with sugar instead of salt!"),
					_item("shells_grilled_sea_bass", "Shells Town Grilled Sea Bass", "food", 550, 15, "Restores +55 HP", ""),
					_item("shells_harbor_ale", "Harbor Draft Ale", "beverage", 400, 20, "Restores +30 Stamina", ""),
					_item("marine_lunch_bento", "Garrison Sailor Bento", "provision", 900, 12, "2 days crew rations", "")
				]
			},
			{
				"id": "base_153_armory",
				"name": "Base 153 Surplus Armory",
				"type": "armory",
				"keeper_npc_id": "base_153_quartermaster",
				"location_id": "marine_base_153",
				"description": "Marine quartermaster depot trading standard-issue cutlasses, flintlocks, and navigation tools.",
				"inventory": [
					_item("marine_standard_cutlass", "Standard Marine Cutlass", "weapon", 12000, 8, "Reliable steel saber (+22 ATK)", ""),
					_item("marine_flintlock_pistol", "Marine Issue Flintlock", "weapon", 15000, 6, "Single-shot ranged sidearm (+25 Ranged ATK)", ""),
					_item("lead_shot_pouch", "Flintlock Lead Shot & Powder (x20)", "ammo", 1800, 20, "20 rounds of flintlock ammunition", ""),
					_item("brass_spyglass", "Marine Lookout Spyglass", "tool", 7500, 5, "Doubles island & ship scouting range for Sextant mapping", ""),
					_item("seastone_handcuff_key", "Seastone Handcuff Master Key", "key_item", 45000, 2, "Unlocks Marine Seastone restraints; rare surplus", "")
				]
			},
			{
				"id": "shells_harbor_stalls",
				"name": "Shells Harbor Supply Stalls",
				"type": "ship_supply",
				"keeper_npc_id": "shells_chandler",
				"location_id": "shells_harbor",
				"description": "Dockside stalls repairing rigging and restocking fresh water.",
				"inventory": [
					_item("hemp_rigging_coil", "Tarred Hemp Rigging Coil", "ship_supply", 2200, 15, "+10% sail turn responsiveness", ""),
					_item("fresh_water_cask", "50-Gallon Fresh Water Cask", "provision", 500, 30, "4 days drinking water for crew", "")
				]
			}
		],
		"npcs": [
			_npc("ririka", "Ririka", "Owner of Food Foo", "Shells Town", "shells_town_square", true, false, ["shop", "rest", "rumors"], "Please keep your voice down if Captain Morgan's patrols pass by..."),
			_npc("rika", "Rika", "Little Girl & Apprentice Chef", "Shells Town", "shells_town_square", true, false, ["quest", "gift"], "Please! That swordsman tied up in the yard hasn't eaten in days—can you bring him my rice balls?"),
			_npc("lt_ripper", "Lieutenant Ripper", "153rd Branch Acting Commander", "Marine Base 153", "marine_base_153", true, false, ["quest", "armory_access", "marine_pardon"], "With Morgan arrested, the 153rd Branch owes you a debt. Koby's application is approved."),
			_npc("koby_shells", "Koby", "153rd Branch Chore Recruit", "Marine Base 153", "marine_base_153", true, false, ["lore", "farewell"], "I'll work from the bottom up! Someday I'll be an Admiral!"),
			_npc("captain_morgan", "Captain 'Axe-Hand' Morgan", "Corrupt 153rd Branch Captain", "Marine Base 153", "marine_base_153", true, true, ["boss_encounter"], "I am great! Everything in Shells Town belongs to my statue!"),
			_npc("helmeppo", "Helmeppo", "Morgan's Spoiled Son", "Shells Town Square", "shells_town_square", true, true, ["mini_boss"], "Do you know who my father is?!"),
			_npc("base_153_quartermaster", "153rd Quartermaster", "Marine Arms Merchant", "Marine Base 153", "marine_base_153", false, false, ["shop"], "Keep your receipt stamped if you're buying Marine steel."),
			_npc("shells_chandler", "Yotsuba Ship Chandler", "Harbor Outfitter", "Shells Town Harbor", "shells_harbor", false, false, ["shop"], "Fresh casks and hemp line—no sailor leaves Yotsuba dry.")
		],
		"quest_hooks": [
			{
				"id": "q_shells_onigiri_delivery",
				"title": "Rice Balls in the Courtyard",
				"giver_npc_id": "rika",
				"min_tier": 1,
				"objectives": ["Deliver Rika's Sweet Onigiri past the 153rd guard", "Retrieve confiscated swords from Morgan's tower"],
				"rewards_beli": 10000,
				"unlocks": ["zoro_three_sword_style_manual"]
			},
			{
				"id": "q_shells_overthrow_morgan",
				"title": "Topple the Stone Tyrant",
				"giver_npc_id": "lt_ripper",
				"min_tier": 2,
				"objectives": ["Defeat Captain 'Axe-Hand' Morgan atop Base 153", "Liberate Shells Town from Morgan's taxes"],
				"rewards_beli": 25000,
				"unlocks": ["base_153_armory_access", "organ_islands_chart"]
			}
		],
		"local_specialties": ["Sweet Onigiri", "Standard Marine Cutlasses", "Seastone Handcuff Keys"],
		"wildlife_and_hazards": ["Helmeppo's Pet Wolf (Soro)", "153rd Marine Patrols"],
		"lore_summary": "Fortified East Blue Marine garrison town in the Yotsuba Island Region where Roronoa Zoro was freed and Koby enlisted."
	}


static func _build_shimotsuki_village() -> Dictionary:
	return {
		"id": "shimotsuki_village",
		"name": "Shimotsuki Village",
		"archipelago_or_region": "Eastern Shimotsuki Coast",
		"sea": SEA_ID,
		"lat_deg": 43.0,
		"lon_deg": 80.0,
		"altitude_m": 0.0,
		"island_radius_m": 6200.0,
		"biome": "Traditional Bamboo & Cedar Coastal Village",
		"climate": "Crisp Temperate Breeze",
		"danger_tier": 1,
		"currency": CURRENCY_ID,
		"is_starter_hub": false,
		"is_canonical": true,
		"has_dock": true,
		"settlements": [
			{
				"id": "shimotsuki_pier",
				"name": "Shimotsuki Wooden Pier",
				"type": "port",
				"lat_offset_deg": -0.02,
				"lon_offset_deg": 0.02,
				"elevation_m": 2.0,
				"description": "Quiet fishing pier built decades ago by Wano emigrants.",
				"features": ["Lantern Posts", "Small Boat Slip"]
			},
			{
				"id": "isshin_dojo",
				"name": "Isshin Dojo",
				"type": "martial_dojo",
				"lat_offset_deg": 0.0,
				"lon_offset_deg": 0.0,
				"elevation_m": 28.0,
				"description": "Traditional Wano-styled timber kendo dojo founded by Shimotsuki Koushirou.",
				"features": ["Main Tatami Hall", "2,001-Step Training Courtyard", "Kuina's Shrine"]
			}
		],
		"shops": [
			{
				"id": "isshin_dojo_store",
				"name": "Isshin Dojo Martial Quartermaster",
				"type": "dojo",
				"keeper_npc_id": "koushirou",
				"location_id": "isshin_dojo",
				"description": "Dojo training stores offering practice blades, kendo manuals, and blade-care kits.",
				"inventory": [
					_item("bamboo_shinai", "Isshin Bamboo Training Sword", "weapon", 2800, 12, "Non-lethal training blade (+14 ATK, +20% Parry window)", ""),
					_item("wado_maintenance_kit", "Wado-Style Katana Maintenance Kit", "consumable", 4500, 10, "Restores 100% blade sharpness; +10% Crit for 1 hour", ""),
					_item("isshin_kendo_scroll", "Scroll of the Breath of All Things (Primer)", "skill_book", 35000, 2, "Teaches foundational steel-cutting stance", "Inspired by Wano swordsmanship")
				]
			},
			{
				"id": "shimotsuki_forge",
				"name": "Shimotsuki Village Swordsmith Forge",
				"type": "armory",
				"keeper_npc_id": "shimotsuki_smith",
				"location_id": "isshin_dojo",
				"description": "Traditional charcoal forge preserving techniques brought from Wano Country 55 years ago.",
				"inventory": [
					_item("shimotsuki_steel_katana", "Shimotsuki Folded Steel Katana", "weapon", 38000, 4, "Balanced East Blue katana (+34 ATK)", ""),
					_item("tsubaki_blade_oil", "Camellia Blade Oil", "consumable", 1200, 20, "Protects swords from salt-water rust", ""),
					_item("lacquered_saya", "Lacquered White Saya Scabbard", "accessory", 6500, 5, "+5 Sword Draw Speed", "")
				]
			}
		],
		"npcs": [
			_npc("koushirou", "Shimotsuki Koushirou", "Master of Isshin Dojo", "Isshin Dojo", "isshin_dojo", true, false, ["shop", "sword_training", "quest"], "A sword that cuts nothing when it wills, yet severs steel when needed—that is true mastery."),
			_npc("shimotsuki_smith", "Kouzaburou's Apprentice Smith", "Village Swordsmith", "Shimotsuki Forge", "isshin_dojo", false, false, ["shop", "blade_upgrade"], "Old Kouzaburou forged the Wado Ichimonji and Enma before settling here."),
			_npc("dojo_senior_disciple", "Isshin Senior Disciple", "Sparring Instructor", "Isshin Dojo", "isshin_dojo", false, false, ["sparring"], "Can you beat two thousand sparring matches without resting?")
		],
		"quest_hooks": [
			{
				"id": "q_shimotsuki_two_thousand",
				"title": "Promise Beneath the Stars",
				"giver_npc_id": "koushirou",
				"min_tier": 2,
				"objectives": ["Spar with Isshin Dojo disciples", "Pay respects at Kuina's stone with a Wado Maintenance Kit"],
				"rewards_beli": 15000,
				"unlocks": ["santoryu_stance_bonus", "wano_heritage_lore"]
			}
		],
		"local_specialties": ["Wado-Style Katana Maintenance Kits", "Folded Steel Katanas", "Kendo Scrolls"],
		"wildlife_and_hazards": ["Wild Mountain Boars", "Steep Coastal Cliffs"],
		"lore_summary": "Founded by Wano samurai Shimotsuki Kouzaburou and home to Roronoa Zoro's childhood Isshin Dojo."
	}


static func _build_organ_islands() -> Dictionary:
	return {
		"id": "organ_islands",
		"name": "Organ Islands (Orange Town)",
		"archipelago_or_region": "Central Organ Archipelago",
		"sea": SEA_ID,
		"lat_deg": 45.0,
		"lon_deg": 58.0,
		"altitude_m": 0.0,
		"island_radius_m": 9200.0,
		"biome": "Coastal Port Town & Pipe-Organ Rock Cliffs",
		"climate": "Temperate Maritime",
		"danger_tier": 2,
		"currency": CURRENCY_ID,
		"is_starter_hub": false,
		"is_canonical": true,
		"has_dock": true,
		"settlements": [
			{
				"id": "orange_town",
				"name": "Orange Town",
				"type": "coastal_town",
				"lat_offset_deg": 0.0,
				"lon_offset_deg": 0.0,
				"elevation_m": 8.0,
				"description": "Neatly paved merchant port rebuilt by Mayor Boodle forty years ago, temporarily occupied by Buggy.",
				"features": ["Chouchou's Pet Food Shop", "Drinker's Pub", "Poro's Bookstore", "Orange Town Plaza"]
			}
		],
		"shops": [
			{
				"id": "chouchou_pet_shop",
				"name": "Chouchou's Pet Food Shop",
				"type": "specialty_market",
				"keeper_npc_id": "chouchou",
				"location_id": "orange_town",
				"description": "Originally owned by the late Hocker and fiercely guarded by Chouchou; reopened with Mayor Boodle's aid.",
				"inventory": [
					_item("premium_beast_rations", "Premium Beast Rations", "taming", 1600, 20, "Tames or pacifies hostile island fauna", "Chouchou's prized stock"),
					_item("crunchy_dog_biscuits", "Hocker's Famous Dog Biscuits", "consumable", 300, 30, "Heals companion pets +100% HP", ""),
					_item("guardian_collar", "Red Guardian Collar", "accessory", 4200, 4, "+15% Companion Defense", "")
				]
			},
			{
				"id": "drinkers_pub",
				"name": "Drinker's Pub",
				"type": "tavern",
				"keeper_npc_id": "orange_barkeep",
				"location_id": "orange_town",
				"description": "Local harbor pub commandeered as Buggy the Clown's drinking hall during the occupation.",
				"inventory": [
					_item("circus_spiced_rum", "Orange Town Spiced Rum", "beverage", 500, 20, "Restores +35 Stamina", ""),
					_item("buggy_ball_gunpowder", "Buggy Ball Blasting Powder", "ammo", 14000, 4, "High-yield cannon/bomb powder (+80 AoE Blast)", "Confiscated from Buggy's stash"),
					_item("pub_roast_mutton", "Tavern Mutton Skewer", "food", 750, 14, "Restores +65 HP", "")
				]
			},
			{
				"id": "boodle_rebuild_depot",
				"name": "Mayor Boodle's Rebuild Supply Depot",
				"type": "shipyard_supply",
				"keeper_npc_id": "mayor_boodle",
				"location_id": "orange_town",
				"description": "Civic material yard supplying timber and blueprints to repair Buggy Ball blast damage.",
				"inventory": [
					_item("town_architect_blueprints", "Orange Town Structural Blueprints", "trade_good", 5500, 5, "Improves settlement building & dock repair efficiency", ""),
					_item("seasoned_oak_planks", "Seasoned Oak Hull Planks", "ship_supply", 3200, 15, "Repairs +30% ship hull integrity", ""),
					_item("waterproof_pitch_tar", "Pine Pitch & Caulking Tar", "ship_supply", 1400, 20, "Seals leaks after cannon hits", "")
				]
			},
			{
				"id": "poro_bookstore",
				"name": "Poro's Orange Town Bookstore",
				"type": "bookstore",
				"keeper_npc_id": "poro",
				"location_id": "orange_town",
				"description": "Quiet corner bookshop stocked with East Blue charts and tide almanacs.",
				"inventory": [
					_item("east_blue_tide_tables", "East Blue Tide & Current Almanac", "navigation", 4800, 6, "+8% sailing speed along East Blue currents", ""),
					_item("blank_survey_logbook", "Cartographer's Blank Logbook", "tool", 1500, 12, "Stores 25 new sextant island surveys", "")
				]
			}
		],
		"npcs": [
			_npc("mayor_boodle", "Mayor Boodle", "Mayor & Town Founder", "Orange Town", "orange_town", true, false, ["shop", "quest", "lore"], "I helped build Orange Town from wilderness! No clown is chasing me out!"),
			_npc("chouchou", "Chouchou", "Loyal Pet Shop Guardian", "Orange Town", "orange_town", true, false, ["shop", "companion_hint"], "Woof! (He watches over Hocker's last box of dog food with unwavering pride.)"),
			_npc("poro", "Poro", "Bookstore Owner", "Orange Town", "orange_town", true, false, ["shop", "lore"], "Take a tide almanac before sailing south toward the Rare Animal Island."),
			_npc("buggy", "Buggy the Clown", "Captain of the Buggy Pirates", "Orange Town", "orange_town", true, true, ["boss_encounter"], "Who are you calling BIG NOSE?! Eat a Special Buggy Ball!", 15000000),
			_npc("mohji_richie", "Mohji & Richie", "Beast Tamer & Giant Lion", "Orange Town", "orange_town", true, true, ["mini_boss"], "Richie, smash that pet shop!"),
			_npc("cabaji", "Cabaji the Acrobat", "Buggy Pirates Chief of Staff", "Orange Town", "orange_town", true, true, ["mini_boss"], "Taste my unicycle-style swordsmanship!"),
			_npc("orange_barkeep", "Drinker's Pub Barkeep", "Tavern Keeper", "Orange Town", "orange_town", false, false, ["shop", "rumors"], "Now that the circus is gone, I can finally sweep up the cannon debris.")
		],
		"quest_hooks": [
			{
				"id": "q_orange_save_pet_shop",
				"title": "Treasure of the Pet Food Shop",
				"giver_npc_id": "mayor_boodle",
				"min_tier": 2,
				"objectives": ["Drive Mohji & Richie away from Chouchou's shop", "Defeat Buggy the Clown in Orange Town Plaza"],
				"rewards_beli": 30000,
				"unlocks": ["grand_line_map_fragment_buggy", "gecko_islands_chart"]
			}
		],
		"local_specialties": ["Premium Beast Rations", "Buggy Ball Gunpowder", "Orange Town Blueprints"],
		"wildlife_and_hazards": ["Buggy Ball Bombardment", "Richie the Lion"],
		"lore_summary": "Site of Luffy's clash with Buggy the Clown and the loyal dog Chouchou's defense of Hocker's shop."
	}


static func _build_island_of_rare_animals() -> Dictionary:
	return {
		"id": "island_of_rare_animals",
		"name": "Island of Rare Animals",
		"archipelago_or_region": "Central East Blue Wilderness",
		"sea": SEA_ID,
		"lat_deg": 36.5,
		"lon_deg": 56.5,
		"altitude_m": 0.0,
		"island_radius_m": 4500.0,
		"biome": "Treasure-Chest-Shaped Jungle & High Plateau",
		"climate": "Warm Humid Forest",
		"danger_tier": 1,
		"currency": CURRENCY_ID,
		"is_starter_hub": false,
		"is_canonical": true,
		"has_dock": false,
		"settlements": [
			{
				"id": "gaimon_forest_clearing",
				"name": "Gaimon's Forest & Plateau",
				"type": "wilderness_sanctuary",
				"lat_offset_deg": 0.0,
				"lon_offset_deg": 0.0,
				"elevation_m": 95.0,
				"description": "Jungle shaped like an open treasure chest; home to bizarre hybrid creatures and five empty summit chests.",
				"features": ["Five Empty Treasure Chests", "Hybrid Fauna Habitat", "Cliffside Lookout"]
			}
		],
		"shops": [],
		"npcs": [
			_npc("gaimon", "Gaimon", "Guardian of the Forest", "Island of Rare Animals", "gaimon_forest_clearing", true, false, ["lore", "compendium_quest"], "Twenty years stuck in this chest guarding the plateau... Turns out my real treasure was these strange beasts all along!"),
			_npc("sarfunkel", "Sarfunkel", "Barrel-Bound Companion", "Island of Rare Animals", "gaimon_forest_clearing", true, false, ["lore"], "Don't mind me, just keeping Gaimon company in my wooden barrel!")
		],
		"quest_hooks": [
			{
				"id": "q_rare_animals_compendium",
				"title": "The Empty Chests & The Hybrid Zoo",
				"giver_npc_id": "gaimon",
				"min_tier": 1,
				"objectives": ["Feed 3 hybrid animals using Beast Rations", "Inspect the 5 empty treasure chests atop the plateau"],
				"rewards_beli": 5000,
				"unlocks": ["fauna_compendium_rare_animals", "gaimon_blessing_charm"]
			}
		],
		"local_specialties": ["Empty Treasure Chests (Keepsake)", "Cocox / Usagihebi Compendium Entries"],
		"wildlife_and_hazards": ["Cocox (Fox-Rooster)", "Usagihebi (Rabbit-Snake)", "Lion-Pig", "Hippo-Rhino", "Giraffe-Lion"],
		"lore_summary": "Secluded wilderness island with zero shops, guarded by Gaimon inside his treasure chest."
	}


static func _build_gecko_islands() -> Dictionary:
	return {
		"id": "gecko_islands",
		"name": "Gecko Islands (Syrup Village)",
		"archipelago_or_region": "Gecko Archipelago",
		"sea": SEA_ID,
		"lat_deg": 43.5,
		"lon_deg": 47.0,
		"altitude_m": 0.0,
		"island_radius_m": 9800.0,
		"biome": "Rolling Green Hills, Steep Coastal Slopes & Estate Village",
		"climate": "Mild Coastal Breeze",
		"danger_tier": 2,
		"currency": CURRENCY_ID,
		"is_starter_hub": false,
		"is_canonical": true,
		"has_dock": true,
		"settlements": [
			{
				"id": "syrup_village",
				"name": "Syrup Village",
				"type": "plateau_village",
				"lat_offset_deg": 0.0,
				"lon_offset_deg": 0.0,
				"elevation_m": 34.0,
				"description": "Idyllic hilltop village overlooking two rocky landing beaches; Usopp's hometown.",
				"features": ["Meshi Restaurant", "Kaya's Mansion", "Two-Tree Hill", "North & South Slopes"]
			},
			{
				"id": "kaya_mansion_yard",
				"name": "Kaya's Mansion & Private Pier",
				"type": "estate_shipyard",
				"lat_offset_deg": 0.02,
				"lon_offset_deg": -0.02,
				"elevation_m": 45.0,
				"description": "Grand white manor whose private cove houses Merry's caravel design workshop.",
				"features": ["Going Merry Slipway", "Medical Library"]
			}
		],
		"shops": [
			{
				"id": "meshi_restaurant",
				"name": "Meshi Restaurant",
				"type": "restaurant",
				"keeper_npc_id": "meshi_owner",
				"location_id": "syrup_village",
				"description": "Modest neighborhood eatery in Syrup Village frequented by the Usopp Pirates.",
				"inventory": [
					_item("syrup_herb_soup", "Syrup Village Herb Soup", "food", 420, 20, "Restores +45 HP and clears fatigue", ""),
					_item("golden_butter_rolls", "Fresh Buttered Bread Rolls", "food", 220, 30, "Restores +25 Stamina", ""),
					_item("ginger_honey_tea", "Kaya's Ginger Honey Tea", "beverage", 350, 15, "Boosts recovery speed by +20% for 10 min", "")
				]
			},
			{
				"id": "kaya_mansion_shipyard",
				"name": "Kaya Mansion Shipyard & Outfitter",
				"type": "shipyard",
				"keeper_npc_id": "merry_butler",
				"location_id": "kaya_mansion_yard",
				"description": "Private shipyard supervised by Merry; builds and repairs Caravel-class vessels.",
				"inventory": [
					_item("going_merry_blueprints", "Going Merry Caravel Hull Blueprints", "ship_blueprint", 120000, 1, "Unlocks Caravel-class flagship (4 cannons, sheep figurehead)", "Designed by Merry"),
					_item("lead_star_ammo", "Lead Star Slingshot Ammo (x25)", "ammo", 1200, 25, "High-impact sniper pellets", "Usopp specialty"),
					_item("smoke_star_ammo", "Smoke Star Pellets (x10)", "ammo", 1800, 15, "Creates obscuring smoke cloud", ""),
					_item("kaya_herbal_tonic", "Mansion Herbal Restorative Tonic", "medicine", 1600, 12, "Restores +120 HP and cures illness", "")
				]
			}
		],
		"npcs": [
			_npc("kaya", "Kaya", "Wealthy Heiress & Medical Student", "Syrup Village", "kaya_mansion_yard", true, false, ["quest", "ship_gift", "healing"], "Please accept our caravel, the Going Merry, and carry Usopp safely across the sea!"),
			_npc("merry_butler", "Merry", "Mansion Butler & Ship Designer", "Syrup Village", "kaya_mansion_yard", true, false, ["shop", "ship_build"], "Every timber on this caravel was laid with care. Treat her well!"),
			_npc("ninjin", "Ninjin", "Usopp Pirates Member", "Syrup Village", "syrup_village", true, false, ["guide"], "Captain Usopp is the greatest warrior on the island!"),
			_npc("piiman", "Piiman", "Usopp Pirates Member", "Syrup Village", "syrup_village", true, false, ["guide"], "Watch the northern rocky slope if pirates ever show up!"),
			_npc("tamanegi", "Tamanegi", "Usopp Pirates Member", "Syrup Village", "syrup_village", true, false, ["guide"], "Something big is happening at Two-Tree Hill!"),
			_npc("mornin", "Mayor Mornin", "Village Chief & Watchman", "Syrup Village", "syrup_village", true, false, ["lore"], "Morning! Wait—why is Usopp yelling about pirates again?"),
			_npc("captain_kuro", "Captain Kuro (Klahadore)", "Mastermind of the Black Cat Pirates", "Syrup Village", "syrup_village", true, true, ["boss_encounter"], "Three years of playing the gentle butler end tonight.", 16000000),
			_npc("jango", "Jango the Hypnotist", "Acting Captain / Hypnotist", "Syrup Village", "syrup_village", true, true, ["mini_boss"], "One, two, Jango! You are getting very sleepy...", 9000000),
			_npc("nyaban_brothers", "Sham & Buchi (Nyaban Brothers)", "Black Cat Ship Guards", "Syrup Village", "syrup_village", true, true, ["mini_boss"], "We'll shred anyone trying to climb the north slope!", 7000000),
			_npc("meshi_owner", "Meshi Chef", "Restaurant Proprietor", "Syrup Village", "syrup_village", false, false, ["shop"], "Pull up a chair—hot soup before you sail south to Baratie?")
		],
		"quest_hooks": [
			{
				"id": "q_syrup_hold_the_slope",
				"title": "Defense of the Northern Slope",
				"giver_npc_id": "kaya",
				"min_tier": 2,
				"objectives": ["Hold the north coastal slope against Jango & the Nyaban Brothers", "Defeat Captain Kuro before dawn"],
				"rewards_beli": 45000,
				"unlocks": ["caravel_going_merry_hull", "baratie_waypoint"]
			}
		],
		"local_specialties": ["Caravel Hull Blueprints", "Lead Star Ammo", "Syrup Herbal Tonics"],
		"wildlife_and_hazards": ["Black Cat Pirates Ambush", "Slick Oil-Coated Coastal Slope"],
		"lore_summary": "Usopp's hometown in the Gecko Islands where Kaya and Merry gift the Going Merry caravel."
	}


static func _build_baratie() -> Dictionary:
	return {
		"id": "baratie",
		"name": "The Baratie",
		"archipelago_or_region": "Sambas Region (Near North Calm Belt)",
		"sea": SEA_ID,
		"lat_deg": 28.0,
		"lon_deg": 45.0,
		"altitude_m": 0.0,
		"island_radius_m": 220.0,
		"biome": "Floating Fish-Shaped Ocean Restaurant Vessel",
		"climate": "Warm Southern Sea Breeze (Calm Belt Edge)",
		"danger_tier": 3,
		"currency": CURRENCY_ID,
		"is_starter_hub": false,
		"is_canonical": true,
		"has_dock": true,
		"settlements": [
			{
				"id": "baratie_dining_hall",
				"name": "Baratie Main Dining Hall & Sabagashira I",
				"type": "floating_restaurant",
				"lat_offset_deg": 0.0,
				"lon_offset_deg": 0.0,
				"elevation_m": 6.0,
				"description": "Monumental fish-headed restaurant ship staffed by fighting cooks; expands fins into battle decks.",
				"features": ["Fish-Head Cannon Proportions", "Folding Combat Fin Decks", "Main Kitchen"]
			},
			{
				"id": "sister_anko",
				"name": "Sister Anko Dessert Submarine",
				"type": "galley_sub_vessel",
				"lat_offset_deg": 0.002,
				"lon_offset_deg": 0.002,
				"elevation_m": 3.0,
				"description": "Anglerfish-shaped patisserie and galley tender docked beside Baratie (post-expansion craft).",
				"features": ["Patisserie Counter", "Cold Storage Hold"]
			}
		],
		"shops": [
			{
				"id": "baratie_dining_menu",
				"name": "The Baratie Dining Hall",
				"type": "restaurant",
				"keeper_npc_id": "chef_zeff",
				"location_id": "baratie_dining_hall",
				"description": "East Blue's premier culinary flagship run by former Cook Pirate captain 'Red-Leg' Zeff.",
				"inventory": [
					_item("all_blue_risotto", "All-Blue Seafood Risotto", "food", 4500, 10, "Restores 100% HP & Stamina; +15% All Stats for 30 min", "Inspired by the mythical All Blue"),
					_item("zeff_pirate_pilaf", "Zeff's Pirate Seafood Pilaf", "food", 2200, 15, "Restores +140 HP, +80 Stamina", ""),
					_item("elephant_tuna_carpaccio", "Rare Sea-Tuna Carpaccio", "food", 6800, 5, "Grants +20% Swim & Dodge Speed for 20 min", ""),
					_item("scurvy_curing_citrus", "Baratie Citrus-Glazed Rations", "provision", 3800, 20, "Cures & prevents Scurvy for 7 days", ""),
					_item("zeff_culinary_tome", "Zeff's Maritime Cookbook", "skill_book", 42000, 1, "Unlocks Master Ship Galley Cooking recipes", "")
				]
			},
			{
				"id": "sister_anko_market",
				"name": "Sister Anko Galley Market",
				"type": "bakery_market",
				"keeper_npc_id": "patty",
				"location_id": "sister_anko",
				"description": "Patty's dessert & specialty galley deck stocking sweet pastries and rare cooking spices.",
				"inventory": [
					_item("anko_sea_fruit_tart", "Sister Anko Sea-Fruit Tart", "food", 1400, 18, "Restores +90 Stamina", ""),
					_item("sambas_pepper_tin", "Sambas Black-Pepper Spice Tin", "trade_good", 3200, 12, "High-demand trade item in Loguetown & Twin Cape", "")
				]
			},
			{
				"id": "patty_carne_provisions",
				"name": "Patty & Carne's Provision Deck",
				"type": "ship_supply",
				"keeper_npc_id": "carne",
				"location_id": "baratie_dining_hall",
				"description": "Bulk sea-rations and heavy cast-iron cookware sold by Baratie's burly sous-chefs.",
				"inventory": [
					_item("bulk_hardtack_crate", "Baratie Galley Bulk Crate", "provision", 6000, 15, "15 days crew rations", ""),
					_item("meatball_cannon_pan", "Patty's Heavy Iron Skillet", "weapon", 18000, 3, "Heavy blunt/shield pan (+28 ATK)", "")
				]
			}
		],
		"npcs": [
			_npc("chef_zeff", "Chef 'Red-Leg' Zeff", "Owner & Head Chef", "Baratie", "baratie_dining_hall", true, false, ["shop", "cooking_master", "quest"], "If you're hungry, you eat—pirate or Marine! Just don't waste a single crumb on my ocean."),
			_npc("patty", "Patty", "Head Patissier & Bouncer", "Baratie", "sister_anko", true, false, ["shop", "bouncer"], "Welcome to the floating crap-heap—I mean, the finest restaurant in the Sambas Region!"),
			_npc("carne", "Carne", "Meat Chef & Bouncer", "Baratie", "baratie_dining_hall", true, false, ["shop", "bouncer"], "Cross Chef Zeff and you're eating the fin deck!"),
			_npc("lt_fullbody", "Lieutenant Fullbody", "Marine HQ Ironfist Patron", "Baratie", "baratie_dining_hall", true, true, ["duel_event"], "I am a Marine Lieutenant! Bring me your finest vintage immediately!"),
			_npc("moodie", "Moodie", "Fullbody's Aristocratic Date", "Baratie", "baratie_dining_hall", true, false, ["lore"], "What dreadful manners that Marine has..."),
			_npc("motzel", "Motzel", "Gluttonous Gourmet Patron", "Baratie", "baratie_dining_hall", true, false, ["flavor"], "Hey, are you going to finish that steak?"),
			_npc("don_krieg", "Don Krieg", "Admiral of the Krieg Pirate Fleet", "Baratie Offshore", "baratie_dining_hall", true, true, ["boss_encounter"], "Hand over this restaurant ship and Zeff's Grand Line logbook!", 17000000),
			_npc("gin", "Gin the 'Man-Demon'", "Krieg Pirates Combat Commander", "Baratie", "baratie_dining_hall", true, true, ["mini_boss", "ally_turn"], "That fried rice... I've never tasted anything so warm in my life.", 12000000),
			_npc("dracule_mihawk", "Dracule 'Hawk-Eyes' Mihawk", "Seven Warlords / World's Greatest Swordsman", "Baratie Offshore", "baratie_dining_hall", true, false, ["legendary_duel", "world_event"], "Know the size of the world, frog in the well. Aim to surpass this black blade!")
		],
		"quest_hooks": [
			{
				"id": "q_baratie_krieg_siege",
				"title": "Siege of the Floating Restaurant",
				"giver_npc_id": "chef_zeff",
				"min_tier": 3,
				"objectives": ["Feed starving Gin and repel Pearl's boarding party", "Defeat Don Krieg aboard the wreckage of the Dreadnaught Sabre"],
				"rewards_beli": 65000,
				"unlocks": ["master_maritime_cooking", "conomi_islands_chart"]
			}
		],
		"local_specialties": ["All-Blue Seafood Risotto", "Scurvy-Curing Citrus Rations", "Sambas Spices", "Grand Line Rumors"],
		"wildlife_and_hazards": ["Krieg Pirate Armada", "Proximity to North Calm Belt Sea Kings"],
		"lore_summary": "Famous fish-shaped sea restaurant in the Sambas Region where Sanji trained under Red-Leg Zeff."
	}


static func _build_conomi_islands() -> Dictionary:
	return {
		"id": "conomi_islands",
		"name": "Conomi Islands",
		"archipelago_or_region": "Conomi Archipelago",
		"sea": SEA_ID,
		"lat_deg": 41.0,
		"lon_deg": 31.0,
		"altitude_m": 0.0,
		"island_radius_m": 13500.0,
		"biome": "Tropical Tangerine Orchards, Coastal Villages & Fortress Lagoon",
		"climate": "Warm Subtropical",
		"danger_tier": 4,
		"currency": CURRENCY_ID,
		"is_starter_hub": false,
		"is_canonical": true,
		"has_dock": true,
		"settlements": [
			{
				"id": "cocoyasi_village",
				"name": "Cocoyasi Village",
				"type": "agricultural_village",
				"lat_offset_deg": -0.05,
				"lon_offset_deg": -0.04,
				"elevation_m": 10.0,
				"description": "Tight-knit coastal village famed for Bell-mère's tangerine groves; Nami and Nojiko's hometown.",
				"features": ["Bell-mère's Mikan Grove", "Dr. Nako's Clinic", "Genzo's Post", "Village Bookstore"]
			},
			{
				"id": "gosa_village",
				"name": "Gosa Village (Ruins)",
				"type": "ruined_village",
				"lat_offset_deg": 0.03,
				"lon_offset_deg": -0.06,
				"elevation_m": 5.0,
				"description": "Neighboring village flipped upside-down by sea cow Momoo when citizens defaulted on Arlong's tribute.",
				"features": ["Inverted Houses", "Salvage Crates"]
			},
			{
				"id": "arlong_park",
				"name": "Arlong Park",
				"type": "fortress_compound",
				"lat_offset_deg": 0.06,
				"lon_offset_deg": 0.05,
				"elevation_m": 14.0,
				"description": "Pagoda-topped Fish-Man stronghold modeled after Sabaody Park, housing Nami's locked map room.",
				"features": ["Central Pool", "Map Room Tower", "Sea-Gate"]
			}
		],
		"shops": [
			{
				"id": "bellmere_tangerine_grove",
				"name": "Bell-mère's Tangerine Grove",
				"type": "specialty_market",
				"keeper_npc_id": "nojiko",
				"location_id": "cocoyasi_village",
				"description": "Lush cliffside mikan orchard tended by Nojiko and Chabo.",
				"inventory": [
					_item("cocoyasi_tangerine_tree", "Cocoyasi Deck Tangerine Tree", "ship_upgrade", 25000, 3, "Plants on ship deck; grants infinite Vitamin C / permanent crew Scurvy immunity", "Nami's beloved orchard gift"),
					_item("fresh_mikan_crate", "Fresh Cocoyasi Mikan Crate", "provision", 1800, 25, "Cures Scurvy; restores +35 HP per serving", ""),
					_item("mikan_marmalade_jar", "Bell-mère's Mikan Marmalade", "trade_good", 3400, 12, "Premium East Blue luxury preserve", "")
				]
			},
			{
				"id": "cocoyasi_cartography_guild",
				"name": "Cocoyasi Cartography & Bookstore",
				"type": "navigation_market",
				"keeper_npc_id": "cocoyasi_bookseller",
				"location_id": "cocoyasi_village",
				"description": "Shop where young Nami once stole navigation treatises; now trades genuine East Blue charts.",
				"inventory": [
					_item("blank_sea_chart_pack", "Blank Parchment Sea Charts (x5)", "navigation", 3000, 15, "Required for sextant coast triangulation", ""),
					_item("surveying_sextant", "Navigator's Brass Sextant", "tool", 16000, 4, "Measures spherical lat/lon from peaks & crow's nests", ""),
					_item("nami_weather_notes", "East Blue Barometric Primer", "skill_book", 22000, 2, "+15% storm prediction accuracy", "")
				]
			},
			{
				"id": "genzo_gear_stall",
				"name": "Genzo's Pinwheel & Gear Stall",
				"type": "outfitter",
				"keeper_npc_id": "genzo",
				"location_id": "cocoyasi_village",
				"description": "Sheriff Genzo's supply post offering village defense gear and waterproof chart cases.",
				"inventory": [
					_item("genzo_pinwheel_charm", "Genzo's Lucky Pinwheel", "accessory", 2000, 10, "Indicates exact wind direction & speed on deck", ""),
					_item("waterproof_map_case", "Brass Waterproof Chart Cylinder", "tool", 4500, 8, "Protects charts & Vivre Cards from sea spray", "")
				]
			},
			{
				"id": "dr_nako_clinic",
				"name": "Dr. Nako's Clinic",
				"type": "clinic",
				"keeper_npc_id": "dr_nako",
				"location_id": "cocoyasi_village",
				"description": "Village medical clinic treating wounds, scurvy, and marine toxins.",
				"inventory": [
					_item("scurvy_cure_elixir", "Vitamin-Rich Scurvy Cure", "medicine", 950, 25, "Immediately cures Scurvy status", ""),
					_item("field_trauma_kit", "Cocoyasi Field Medkit", "medicine", 2800, 15, "Restores +160 HP and stops bleeding", "")
				]
			},
			{
				"id": "arlong_park_salvage",
				"name": "Arlong Park Salvage & Bounty Cache",
				"type": "black_market",
				"keeper_npc_id": "johnny_yosaku",
				"location_id": "arlong_park",
				"description": "Looted Fish-Man weaponry and charts recovered after Arlong Park's fall.",
				"inventory": [
					_item("fishman_karate_scroll", "Fish-Man Karate Water-Impact Scroll", "skill_book", 55000, 1, "Unlocks shockwave palm strike techniques", "Recovered from Kuroobi's dojo hall"),
					_item("kiribachi_shard_blade", "Serrated Shark-Tooth Sabre", "weapon", 42000, 2, "Heavy serrated blade (+46 ATK, Bleed)", "")
				]
			}
		],
		"npcs": [
			_npc("nojiko", "Nojiko", "Tangerine Farmer & Nami's Sister", "Cocoyasi Village", "cocoyasi_village", true, false, ["shop", "quest", "lore"], "If you're sailing into the Grand Line, take a couple of Bell-mère's tangerine trees for your deck."),
			_npc("genzo", "Genzo", "Village Sheriff", "Cocoyasi Village", "cocoyasi_village", true, false, ["shop", "quest"], "Make her cry and I'll hunt you to the ends of the sea!"),
			_npc("dr_nako", "Dr. Nako", "Village Physician", "Cocoyasi Village", "cocoyasi_village", true, false, ["shop", "heal"], "These aren't fish-men fins—it's just my hairstyle! Need bandages?"),
			_npc("chabo", "Chabo", "Mikan Grove Helper (from Gosa)", "Cocoyasi Village", "cocoyasi_village", true, false, ["lore"], "My parents in Gosa couldn't pay Arlong's 100,000 Beli adult tribute..."),
			_npc("johnny_yosaku", "Johnny & Yosaku", "Pirate Hunter Duo & Brokers", "Conomi Coast", "arlong_park", true, false, ["shop", "bounty_broker", "ally"], "Aniki! Give us a lime for scurvy and we'll point you straight to the biggest East Blue bounties!"),
			_npc("arlong", "Saw-Shark Arlong", "Captain of the Arlong Pirates", "Arlong Park", "arlong_park", true, true, ["boss_encounter"], "100,000 Beli per adult, 50,000 per child! Inferiors pay tribute to live!", 20000000),
			_npc("hatchan", "Hatchan (Hachi)", "Six-Sword Fish-Man Officer", "Arlong Park", "arlong_park", true, true, ["mini_boss"], "Nyu! Wait until you taste my takoyaki—uh, I mean my six blades!"),
			_npc("kuroobi", "Kuroobi", "Fish-Man Karate Master", "Arlong Park", "arlong_park", true, true, ["mini_boss"], "A human cannot withstand Thousand Brick Fist!"),
			_npc("chew", "Chew", "Water-Shot Sniper", "Arlong Park", "arlong_park", true, true, ["mini_boss"], "Chuuu! Nobody outruns my water cannon!"),
			_npc("momoo", "Momoo", "Giant Grand Line Sea Cow", "Conomi Lagoon", "arlong_park", true, true, ["creature_encounter"], "A terrified 40-meter sea cow pressed into Arlong's service."),
			_npc("captain_nezumi", "Captain Nezumi", "Corrupt Marine 16th Branch Captain", "Conomi Coast", "cocoyasi_village", true, true, ["corrupt_event"], "By Marine authority, I am confiscating all 100,000,000 Beli!"),
			_npc("cocoyasi_bookseller", "Cocoyasi Bookseller", "Cartography Merchant", "Cocoyasi Village", "cocoyasi_village", false, false, ["shop"], "Every good navigator starts with blank parchment and a steady sextant.")
		],
		"quest_hooks": [
			{
				"id": "q_conomi_liberation",
				"title": "100 Million Beli & The Fall of Arlong Park",
				"giver_npc_id": "genzo",
				"min_tier": 4,
				"objectives": ["Investigate Gosa Village ruins", "Defeat Hatchan, Kuroobi, Chew, and Arlong inside Arlong Park", "Expose Captain Nezumi's bribery"],
				"rewards_beli": 100000,
				"unlocks": ["cocoyasi_tangerine_trees", "loguetown_waypoint"]
			}
		],
		"local_specialties": ["Cocoyasi Deck Tangerine Trees", "Blank Sea Charts", "Fish-Man Karate Scrolls"],
		"wildlife_and_hazards": ["Arlong Pirates (20,000,000 Beli Boss)", "Momoo the Sea Cow", "Corrupt 16th Branch Marines"],
		"lore_summary": "Archipelago liberated from Arlong's 8-year tribute rule (100,000 Beli/adult, 50,000 Beli/child) and home to Bell-mère's tangerine groves."
	}


static func _build_loguetown() -> Dictionary:
	return {
		"id": "loguetown",
		"name": "Loguetown",
		"archipelago_or_region": "Polestar Islands (Gateway to Reverse Mountain)",
		"sea": SEA_ID,
		"lat_deg": 21.5,
		"lon_deg": 14.0,
		"altitude_m": 0.0,
		"island_radius_m": 11000.0,
		"biome": "Grand Maritime Port City & Execution Plaza",
		"climate": "Frequent Squalls & Western Gales",
		"danger_tier": 4,
		"currency": CURRENCY_ID,
		"is_starter_hub": false,
		"is_canonical": true,
		"has_dock": true,
		"settlements": [
			{
				"id": "execution_plaza",
				"name": "Execution Plaza (Central Square)",
				"type": "historic_square",
				"lat_offset_deg": 0.0,
				"lon_offset_deg": 0.0,
				"elevation_m": 18.0,
				"description": "Cobbled plaza housing the wooden scaffold where Pirate King Gol D. Roger sparked the Great Pirate Era.",
				"features": ["Execution Scaffold", "Plaza Bell"]
			},
			{
				"id": "loguetown_bazaar",
				"name": "Loguetown Merchant & Arms Quarter",
				"type": "commercial_district",
				"lat_offset_deg": -0.02,
				"lon_offset_deg": 0.02,
				"elevation_m": 10.0,
				"description": "Bustling streets packed with sword shops, fashion boutiques, fish markets, and taverns serving Grand Line bound crews.",
				"features": ["Ipponmatsu's Arms Shop", "Gold Roger Bar", "Robecca Hanberg", "Antique House", "Uotome Fish Market"]
			},
			{
				"id": "loguetown_harbor",
				"name": "Loguetown Harbor & Marine Base",
				"type": "major_port",
				"lat_offset_deg": -0.04,
				"lon_offset_deg": -0.03,
				"elevation_m": 2.0,
				"description": "Final East Blue port before Reverse Mountain, heavily patrolled by Captain Smoker's Marine garrison.",
				"features": ["Grand Line Pier", "Marine Watchtower", "Shipyard Drydock"]
			}
		],
		"shops": [
			{
				"id": "ipponmatsu_arms_shop",
				"name": "Ipponmatsu's Arms Shop",
				"type": "armory",
				"keeper_npc_id": "ipponmatsu",
				"location_id": "loguetown_bazaar",
				"description": "Renowned weapon shop where Zoro tested his luck against the cursed Sandai Kitetsu.",
				"inventory": [
					_item("sandai_kitetsu", "Sandai Kitetsu (Grade / Cursed)", "weapon", 1000000, 1, "Cursed Grade Katana (+75 ATK, +20% Crit); available for 50,000 Beli barrel-bin luck test", "Forged by Tenguyama Hitetsu"),
					_item("yubashiri", "Yubashiri (Ryo Wazamono / Skillful Grade)", "weapon", 0, 1, "50 Skillful Grade black-hilted katana (+70 ATK, Featherweight); gifted after passing Sandai Kitetsu test", "Ipponmatsu family heirloom"),
					_item("loguetown_standard_katana", "Loguetown Steel Katana", "weapon", 50000, 10, "Reliable East Blue blade (+38 ATK)", "Standard 50,000 Beli sword"),
					_item("heavy_boarding_axe", "Marine Boarding Axe", "weapon", 32000, 6, "Cleaves wooden ship railings (+40 ATK)", "")
				]
			},
			{
				"id": "gold_roger_bar",
				"name": "Gold Roger Bar",
				"type": "tavern",
				"keeper_npc_id": "raoul",
				"location_id": "loguetown_bazaar",
				"description": "Dimly lit old tavern run by Raoul (anime canon), once frequented by a young Gol D. Roger.",
				"inventory": [
					_item("roger_era_aged_rum", "Old Era Pirate Rum", "beverage", 1800, 15, "Restores +60 Stamina; unlocks Gold Roger lore dialogue", ""),
					_item("grand_line_sea_stew", "Raoul's Red-Line Crossing Stew", "food", 2400, 12, "Restores +120 HP, +60 Stamina", "")
				]
			},
			{
				"id": "robecca_hanberg",
				"name": "Robecca Hanberg Boutique",
				"type": "boutique",
				"keeper_npc_id": "hanger",
				"location_id": "loguetown_bazaar",
				"description": "High-fashion luxury boutique where Nami tried on designer outfits.",
				"inventory": [
					_item("hanberg_navigator_coat", "Robecca Hanberg Storm Trenchcoat", "armor", 65000, 3, "+28 Defense, Cold/Rain Resistance", ""),
					_item("grand_line_silk_vest", "Crimson Polestar Silk Vest", "armor", 48000, 4, "+22 Defense, +15% Persuasion", "")
				]
			},
			{
				"id": "antique_house",
				"name": "Antique House Clothing",
				"type": "boutique",
				"keeper_npc_id": "antique_clerk",
				"location_id": "loguetown_bazaar",
				"description": "Trendy, affordable clothing outlet favored by sailors stocking up on travel wear.",
				"inventory": [
					_item("antique_sailor_jacket", "Trendy Polestar Travel Jacket", "armor", 8500, 10, "+12 Defense, Windproof", "70% cheaper than Robecca Hanberg"),
					_item("straw_sun_hat", "Woven Navigator Sun Hat", "armor", 2400, 12, "Heat protection", "")
				]
			},
			{
				"id": "uotome_fish_market",
				"name": "The Fisherman King Uotome",
				"type": "market",
				"keeper_npc_id": "sapi",
				"location_id": "loguetown_bazaar",
				"description": "Bustling seafood hall run by half-fishman Sapi; famous for giant pelagic tuna.",
				"inventory": [
					_item("elephant_true_blue_tuna", "Elephant True Bluefin Tuna", "food", 250000, 1, "Legendary trophy fish; yields 30 days of All-Blue grade gourmet feasts", "Bought by Sanji in Loguetown"),
					_item("polestar_giant_lobster", "Polestar Giant Spiny Lobster", "food", 14000, 6, "Restores +180 HP when cooked", "")
				]
			},
			{
				"id": "love_love_pirates_shop",
				"name": "Ed's Love Love Pirates Novelty Shop",
				"type": "curio_shop",
				"keeper_npc_id": "ed_shopkeeper",
				"location_id": "loguetown_bazaar",
				"description": "Souvenir and novelty shop (anime canon) selling brass sniper goggles and questionable pirate relics.",
				"inventory": [
					_item("sniper_brass_goggles", "North Blue Marksman Goggles", "accessory", 12000, 4, "+15% Ranged Accuracy & Glare Immunity", "Usopp bought his signature goggles here"),
					_item("fake_roger_compass", "Souvenir 'Pirate King' Compass", "curio", 3000, 10, "Novelty trinket (slightly magnetized)", "")
				]
			},
			{
				"id": "loguetown_port_outfitter",
				"name": "Loguetown Grand Line Outfitter",
				"type": "shipyard_supply",
				"keeper_npc_id": "loguetown_shipwright",
				"location_id": "loguetown_harbor",
				"description": "Last full-service outfitter before ascending Reverse Mountain.",
				"inventory": [
					_item("reverse_mountain_rudder_brace", "Hydraulic Canal Rudder Brace", "ship_upgrade", 40000, 3, "+30% Steering Stability inside Reverse Mountain canals", ""),
					_item("grand_line_blank_log_pose_case", "Empty Log Pose Wrist Mount", "navigation", 15000, 5, "Ready for Crocus's magnetic needle calibration at Twin Cape", ""),
					_item("emergency_repair_timber_pack", "Reverse Mountain Timber Pack", "ship_supply", 12000, 12, "Full emergency hull & mast patch kit", "")
				]
			}
		],
		"npcs": [
			_npc("ipponmatsu", "Ipponmatsu", "Arms Shop Owner", "Loguetown", "loguetown_bazaar", true, false, ["shop", "sword_luck_trial"], "You've got the eyes of a swordsman... Dare test your arm against the cursed Sandai Kitetsu?"),
			_npc("ipponume", "Ipponume", "Ipponmatsu's Sharp-Tongued Wife", "Loguetown", "loguetown_bazaar", true, false, ["shop_assistant"], "Don't go giving away our best family sword to some broke pirate!"),
			_npc("raoul", "Raoul", "Bartender of Gold Roger Bar", "Loguetown", "loguetown_bazaar", true, false, ["shop", "lore", "quest"], "Right at this counter, Roger asked me if I believed in destiny before heading to Reverse Mountain."),
			_npc("hanger", "Hanger", "Boutique Stylist at Robecca Hanberg", "Loguetown", "loguetown_bazaar", true, false, ["shop"], "Try anything you like, miss—though our coats cost a small fortune!"),
			_npc("sapi", "Sapi", "Half-Fishman Fishmonger", "Loguetown", "loguetown_bazaar", true, false, ["shop"], "Look at that snout! A genuine Elephant True Bluefin Tuna!"),
			_npc("ed_shopkeeper", "Ed", "Owner of Love Love Pirates", "Loguetown", "loguetown_bazaar", true, false, ["shop"], "Genuine North Blue sniper goggles—only one pair left!"),
			_npc("yu", "Yu", "Young Loguetown Resident", "Loguetown", "loguetown_bazaar", true, false, ["flavor"], "Careful around Captain Smoker—he never lets a single pirate leave port!"),
			_npc("koze_packy", "Koze & Packy", "Street Toughs", "Loguetown", "loguetown_bazaar", true, false, ["flavor"], "Did you see the size of that giant tuna?"),
			_npc("captain_smoker", "Captain Smoker (White Hunter)", "Marine Garrison Commander", "Loguetown Harbor", "loguetown_harbor", true, true, ["boss_encounter", "pursuit"], "No pirate has ever left Loguetown alive under my watch!"),
			_npc("tashigi", "Ensign Tashigi", "Marine Swordsman & Meito Collector", "Loguetown Bazaar", "loguetown_bazaar", true, true, ["mini_boss", "meito_lore"], "Pirates shouldn't be allowed to wield named Meito blades!"),
			_npc("monkey_d_dragon", "Monkey D. Dragon", "Supreme Commander of the Revolutionary Army", "Execution Plaza", "execution_plaza", true, false, ["world_event"], "A pirate? Fine by me. The winds of change are blowing toward the Grand Line."),
			_npc("antique_clerk", "Antique House Clerk", "Boutique Clerk", "Loguetown", "loguetown_bazaar", false, false, ["shop"], "Stylish jackets at honest sailor prices!"),
			_npc("loguetown_shipwright", "Polestar Master Shipwright", "Harbor Outfitter", "Loguetown Harbor", "loguetown_harbor", false, false, ["shop", "ship_repair"], "Reinforce your rudder before riding the uphill current at Reverse Mountain!")
		],
		"quest_hooks": [
			{
				"id": "q_loguetown_cursed_blade",
				"title": "Luck vs. Curse at Ipponmatsu's",
				"giver_npc_id": "ipponmatsu",
				"min_tier": 3,
				"objectives": ["Pass the Sandai Kitetsu arm-toss trial", "Earn Yubashiri as Ipponmatsu's heirloom gift"],
				"rewards_beli": 0,
				"unlocks": ["sandai_kitetsu", "yubashiri"]
			},
			{
				"id": "q_loguetown_storm_escape",
				"title": "The Town of the Beginning and the End",
				"giver_npc_id": "raoul",
				"min_tier": 4,
				"objectives": ["Provision ship for Reverse Mountain", "Break through Captain Smoker's harbor blockade during the green lightning squall", "Reach East Blue Reverse Mountain Canal Mouth"],
				"rewards_beli": 80000,
				"unlocks": ["reverse_mountain_ascent"]
			}
		],
		"local_specialties": ["Meito Graded & Cursed Blades", "Elephant True Bluefin Tuna", "Polestar Travel Coats", "Canal Rudder Braces"],
		"wildlife_and_hazards": ["Captain Smoker & Tashigi Marine Blockade", "Sudden Green-Gale Thunderstorms", "Buggy & Alvida Alliance"],
		"lore_summary": "Birthplace and execution site of Gol D. Roger in the Polestar Islands; final East Blue staging port before Reverse Mountain."
	}


static func _build_tequila_wolf() -> Dictionary:
	return {
		"id": "tequila_wolf",
		"name": "Tequila Wolf",
		"archipelago_or_region": "Northern Cold Sea Span",
		"sea": SEA_ID,
		"lat_deg": 68.5,
		"lon_deg": 48.0,
		"altitude_m": 15.0,
		"island_radius_m": 16000.0,
		"biome": "Frozen Stone Megastructure Bridge & Labor Camp",
		"climate": "Sub-Arctic Blizzard & Sleet",
		"danger_tier": 5,
		"currency": CURRENCY_ID,
		"is_starter_hub": false,
		"is_canonical": true,
		"has_dock": true,
		"settlements": [
			{
				"id": "tequila_bridge_span",
				"name": "Tequila Wolf Bridge Span (700-Year Sector)",
				"type": "megastructure",
				"lat_offset_deg": 0.0,
				"lon_offset_deg": 0.0,
				"elevation_m": 25.0,
				"description": "Colossal stone bridge under construction for 700 years by World Government decree using slave labor.",
				"features": ["Prisoner Barracks", "Watchtower Bastions", "Stone Quarry Piers"]
			}
		],
		"shops": [
			{
				"id": "prisoner_black_market",
				"name": "Prisoner Underground Exchange",
				"type": "black_market",
				"keeper_npc_id": "rev_bridge_operative",
				"location_id": "tequila_bridge_span",
				"description": "Covert Revolutionary-backed cellar trading warm coats, mason tools, and ancient stone rubbings.",
				"inventory": [
					_item("tequila_fur_coat", "Cold-Weather Bridge Guard Coat", "armor", 14000, 6, "Prevents Freezing status in sub-arctic zones", ""),
					_item("heavy_mason_tools", "Heavy Stone-Mason Chisel & Hammer", "tool", 6500, 10, "Harvests rare ores & ancient inscriptions", ""),
					_item("void_century_bridge_rubbing", "700-Year Bridge Charter Rubbing", "lore_item", 30000, 2, "Void Century clue connecting World Noble decrees", "")
				]
			},
			{
				"id": "bridge_supply_depot",
				"name": "Bridge Labor Supply Depot",
				"type": "depot",
				"keeper_npc_id": "soran",
				"location_id": "tequila_bridge_span",
				"description": "Meager rations and lamp oil traded discreetly away from the wardens.",
				"inventory": [
					_item("boiled_turnip_ration", "Camp Boiled Turnip Soup", "food", 200, 20, "Restores +20 HP and warms character", ""),
					_item("camp_lamp_oil", "Tallow Lamp Oil Flask", "consumable", 450, 15, "Extends lantern burn time by 3 hours", "")
				]
			}
		],
		"npcs": [
			_npc("soran", "Soran", "Young Bridge Prisoner & Artist", "Tequila Wolf", "tequila_bridge_span", true, false, ["shop", "lore", "quest"], "They've been building this bridge for seven hundred years... nobody alive remembers why."),
			_npc("rev_bridge_operative", "Revolutionary Liberation Scout", "Revolutionary Army", "Tequila Wolf", "tequila_bridge_span", true, false, ["shop", "quest"], "Help us sabotage Watchtower 4 and free the chain gang!"),
			_npc("tequila_warden", "Bridge Fortress Warden", "World Government Guard", "Tequila Wolf", "tequila_bridge_span", false, true, ["boss_encounter"], "Back to the quarry, criminals!")
		],
		"quest_hooks": [
			{
				"id": "q_tequila_liberation",
				"title": "Seven Hundred Years of Stone",
				"giver_npc_id": "rev_bridge_operative",
				"min_tier": 4,
				"objectives": ["Infiltrate Watchtower 4 during a snow squall", "Obtain a 700-Year Bridge Charter Rubbing", "Free Soran's barracks"],
				"rewards_beli": 75000,
				"unlocks": ["revolutionary_army_reputation", "void_century_clue_tequila"]
			}
		],
		"local_specialties": ["Cold-Weather Coats", "Heavy Mason Tools", "700-Year Void Century Bridge Rubbings"],
		"wildlife_and_hazards": ["Sub-Zero Blizzards", "World Government Rifle Towers"],
		"lore_summary": "World Government slave-built bridge begun 700 years ago; site where Bartholomew Kuma sent Nico Robin."
	}


static func _build_sixis() -> Dictionary:
	return {
		"id": "sixis",
		"name": "Sixis",
		"archipelago_or_region": "North-Central Current Eddy",
		"sea": SEA_ID,
		"lat_deg": 64.0,
		"lon_deg": 62.0,
		"altitude_m": 0.0,
		"island_radius_m": 4200.0,
		"biome": "Barren Reef-Locked Desolate Island",
		"climate": "Harsh Winds & Encircling Whirlpools",
		"danger_tier": 3,
		"currency": CURRENCY_ID,
		"is_starter_hub": false,
		"is_canonical": true,
		"has_dock": false,
		"settlements": [
			{
				"id": "sixis_shore",
				"name": "Sixis Wreckage Beach & Reef",
				"type": "marooned_island",
				"lat_offset_deg": 0.0,
				"lon_offset_deg": 0.0,
				"elevation_m": 12.0,
				"description": "Current-locked desolate rock where Portgas D. Ace and Masked Deuce formed the Spade Pirates.",
				"features": ["Driftwood Camp", "Mera Mera Cave", "Encircling Barrier Reef"]
			}
		],
		"shops": [],
		"npcs": [
			_npc("sixis_castaway_scribe", "Marooned Navigator", "Stranded Sailor", "Sixis", "sixis_shore", false, false, ["lore", "navigation_warning"], "The currents here spin in a closed ring! You'll need a strong wind or flame-driven raft to break free."),
			_npc("masked_deuce_log", "Masked Deuce's Weathered Journal", "Spade Pirates Lore Object", "Sixis", "sixis_shore", true, false, ["lore_cache"], "Entry 1: Split a strange swirling fruit with a guy named Ace...")
		],
		"quest_hooks": [
			{
				"id": "q_sixis_spade_legacy",
				"title": "Ashes of the Spade Pirates",
				"giver_npc_id": "sixis_castaway_scribe",
				"min_tier": 3,
				"objectives": ["Navigate past the Sixis barrier reef", "Recover Masked Deuce's Weathered Journal", "Rescue the marooned sailor"],
				"rewards_beli": 35000,
				"unlocks": ["spade_pirates_lore_entry", "whirlpool_escape_maneuver"]
			}
		],
		"local_specialties": ["Spade Pirates Journal Fragment", "Salvaged Driftwood"],
		"wildlife_and_hazards": ["Circular Trap Currents", "Sharp Barrier Reefs", "Scarce Fresh Water"],
		"lore_summary": "Barren current-locked island where Portgas D. Ace and Masked Deuce were stranded and Ace ate the Mera Mera no Mi."
	}


static func _build_mirrorball_island() -> Dictionary:
	return {
		"id": "mirrorball_island",
		"name": "Mirrorball Island",
		"archipelago_or_region": "Southeastern East Blue",
		"sea": SEA_ID,
		"lat_deg": 26.0,
		"lon_deg": 72.0,
		"altitude_m": 0.0,
		"island_radius_m": 5100.0,
		"biome": "Festive Harbor & Lantern Plaza",
		"climate": "Warm Evening Sea Breeze",
		"danger_tier": 1,
		"currency": CURRENCY_ID,
		"is_starter_hub": false,
		"is_canonical": true,
		"has_dock": true,
		"settlements": [
			{
				"id": "mirrorball_plaza",
				"name": "Mirrorball Dance Plaza",
				"type": "entertainment_port",
				"lat_offset_deg": 0.0,
				"lon_offset_deg": 0.0,
				"elevation_m": 10.0,
				"description": "Lively seaside town hosting famous dance contests; featured in Jango's Dance Paradise.",
				"features": ["Hanging Crystal Mirrorball", "Dance Stage", "Harbor Lounge"]
			}
		],
		"shops": [
			{
				"id": "mirrorball_lounge",
				"name": "Mirrorball Dance Hall & Bar",
				"type": "tavern",
				"keeper_npc_id": "mirrorball_mc",
				"location_id": "mirrorball_plaza",
				"description": "Open-air stage bar serving sparkling drinks and flashy dance attire.",
				"inventory": [
					_item("sparkling_berry_punch", "Mirrorball Sparkling Punch", "beverage", 650, 20, "Restores +50 Stamina and +10% Dodge Agility for 10 min", ""),
					_item("disco_step_boots", "Moonwalk Rhythm Boots", "armor", 9500, 4, "+15% Sprint & Dodge Speed", ""),
					_item("heart_sunglasses", "Heart-Shaped Hypnotist Shades", "accessory", 4200, 6, "+20% Sleep/Hypnosis Resistance", "")
				]
			}
		],
		"npcs": [
			_npc("mirrorball_mc", "Dance Hall Master", "Contest Host & Bartender", "Mirrorball Island", "mirrorball_plaza", false, false, ["shop", "minigame_dance"], "Step onto the plaza under the giant mirrorball! Beat the house champion and win a purse of Beli!"),
			_npc("jango_traveler", "Disguised Dancer (Jango)", "Cover-Story Cameo", "Mirrorball Island", "mirrorball_plaza", true, false, ["lore", "dance_rival"], "Watch my moonwalk! Nobody dances better than—wait, aren't those Marines?!")
		],
		"quest_hooks": [
			{
				"id": "q_mirrorball_dance_cup",
				"title": "Jango's Dance Paradise",
				"giver_npc_id": "mirrorball_mc",
				"min_tier": 1,
				"objectives": ["Enter the Mirrorball Dance Contest", "Outscore the mysterious disguised champion"],
				"rewards_beli": 15000,
				"unlocks": ["moonwalk_agility_perk"]
			}
		],
		"local_specialties": ["Moonwalk Rhythm Boots", "Sparkling Berry Punch", "Hypnotist Shades"],
		"wildlife_and_hazards": ["Rowdy Marine Patrols Searching for Fugitive Pirates"],
		"lore_summary": "Festive dance-contest island from Jango's Dance Paradise cover story."
	}


static func _build_kumate_island() -> Dictionary:
	return {
		"id": "kumate_island",
		"name": "Kumate Tribe Island",
		"archipelago_or_region": "Southeastern Wilds",
		"sea": SEA_ID,
		"lat_deg": 33.0,
		"lon_deg": 76.0,
		"altitude_m": 0.0,
		"island_radius_m": 5400.0,
		"biome": "Bear-Paw Shaped Tropical Jungle",
		"climate": "Humid Jungle",
		"danger_tier": 3,
		"currency": CURRENCY_ID,
		"is_starter_hub": false,
		"is_canonical": true,
		"has_dock": false,
		"settlements": [
			{
				"id": "kumate_stockade",
				"name": "Kumate Jungle Stockade",
				"type": "tribal_camp",
				"lat_offset_deg": 0.0,
				"lon_offset_deg": 0.0,
				"elevation_m": 30.0,
				"description": "Bear-paw island inhabited by the hostile Kumate Tribe; site of Buggy's Crew Adventure Chronicles.",
				"features": ["Bamboo Stockade", "Giant Cooking Pot Clearing"]
			}
		],
		"shops": [
			{
				"id": "kumate_salvage_rack",
				"name": "Jungle Salvage Rack",
				"type": "cache",
				"keeper_npc_id": "kumate_scout",
				"location_id": "kumate_stockade",
				"description": "Weapons and shipwreck provisions left behind after the Buggy Pirates' chaotic rescue.",
				"inventory": [
					_item("jungle_spear", "Kumate Carved Hardwood Spear", "weapon", 7500, 5, "Long-reach polearm (+24 ATK)", ""),
					_item("tropical_root_rations", "Roasted Jungle Tubers", "food", 450, 15, "Restores +40 HP", "")
				]
			}
		],
		"npcs": [
			_npc("kumate_chieftain", "Kumate Tribe Chieftain", "Tribal Leader", "Kumate Tribe", "kumate_stockade", true, true, ["combat"], "Strangers who land on Bear-Paw Beach belong in the cooking pot!"),
			_npc("kumate_scout", "Exiled Tribe Barterer", "Outcast Trader", "Kumate Tribe", "kumate_stockade", false, false, ["shop"], "Keep away from the stockade drums—trade quick and sail on.")
		],
		"quest_hooks": [],
		"local_specialties": ["Hardwood Spears", "Exotic Jungle Roots"],
		"wildlife_and_hazards": ["Hostile Kumate Tribe Warriors", "Dense Mangrove Shallows"],
		"lore_summary": "Bear-paw-shaped island from Buggy's Crew Adventure Chronicles where Buggy and Alvida rescued his crew."
	}


static func _build_oykot_kingdom() -> Dictionary:
	return {
		"id": "oykot_kingdom",
		"name": "Oykot Kingdom",
		"archipelago_or_region": "Northern East Blue",
		"sea": SEA_ID,
		"lat_deg": 57.5,
		"lon_deg": 40.0,
		"altitude_m": 0.0,
		"island_radius_m": 11500.0,
		"biome": "Rebuilt Battlefield Ruins & Coastal Town",
		"climate": "Cool Temperate",
		"danger_tier": 2,
		"currency": CURRENCY_ID,
		"is_starter_hub": false,
		"is_canonical": true,
		"has_dock": true,
		"settlements": [
			{
				"id": "oykot_port",
				"name": "Oykot Memorial Harbor",
				"type": "town",
				"lat_offset_deg": 0.0,
				"lon_offset_deg": 0.0,
				"elevation_m": 15.0,
				"description": "Kingdom once devastated by pirates 20 years ago, where young Marine Bell-mère found infant Nami and Nojiko.",
				"features": ["Bell-mère Memorial", "Harbor Market"]
			}
		],
		"shops": [
			{
				"id": "oykot_harbor_market",
				"name": "Oykot Reconstruction Market",
				"type": "market",
				"keeper_npc_id": "oykot_elder",
				"location_id": "oykot_port",
				"description": "Local merchants rebuilding Oykot's trade with Cocoyasi Village.",
				"inventory": [
					_item("oykot_wool_cloak", "Oykot Woven Wool Cloak", "armor", 6800, 8, "+10 Defense, Cold Breeze protection", ""),
					_item("oykot_dried_apples", "Oykot Orchard Dried Fruit", "provision", 1100, 20, "3 days crew rations", "")
				]
			}
		],
		"npcs": [
			_npc("oykot_elder", "Oykot Town Elder", "Civic Leader & Merchant", "Oykot Kingdom", "oykot_port", false, false, ["shop", "lore"], "Twenty years ago a wounded Marine saved two little girls from the rubble here... We still send tangerines from Cocoyasi.")
		],
		"quest_hooks": [],
		"local_specialties": ["Oykot Wool Cloaks", "Dried Orchard Fruit"],
		"wildlife_and_hazards": ["Old War Ruins", "Northern Squalls"],
		"lore_summary": "East Blue kingdom where Bell-mère found Nami and Nojiko during a pirate raid 20 years prior to the main story."
	}


static func _build_minor_kingdoms_frauce() -> Dictionary:
	return _minor_kingdom_template(
		"frauce_kingdom",
		"Frauce Kingdom",
		"Northwestern East Blue",
		55.0,
		22.0,
		7200.0,
		"Temperate Timberlands",
		"Known East Blue member kingdom appearing on World Government charts."
	)


static func _build_minor_kingdoms_nagagutsu() -> Dictionary:
	return _minor_kingdom_template(
		"nagagutsu_kingdom",
		"Nagagutsu Kingdom",
		"Southwestern East Blue",
		30.0,
		25.0,
		6800.0,
		"Coastal Highlands",
		"Minor East Blue kingdom located along the southwestern shipping lanes toward Loguetown."
	)


static func _build_minor_kingdoms_satsuruzo() -> Dictionary:
	return _minor_kingdom_template(
		"satsuruzo_kingdom",
		"Satsuruzo Kingdom",
		"Far Northeastern East Blue",
		61.0,
		82.0,
		7000.0,
		"Sub-Temperate Highlands",
		"Easternmost peripheral kingdom recorded in East Blue geographic ledgers."
	)


static func _build_minor_kingdoms_cozia() -> Dictionary:
	return _minor_kingdom_template(
		"cozia_island",
		"Cozia",
		"Southern East Blue",
		23.5,
		60.0,
		5800.0,
		"Coastal Lowlands",
		"East Blue island famously invaded by Germa 66 thirteen years prior to the current era."
	)


static func _minor_kingdom_template(
	id_str: String,
	kingdom_name: String,
	region_str: String,
	lat_val: float,
	lon_val: float,
	radius_m: float,
	biome_str: String,
	lore_str: String
) -> Dictionary:
	return {
		"id": id_str,
		"name": kingdom_name,
		"archipelago_or_region": region_str,
		"sea": SEA_ID,
		"lat_deg": lat_val,
		"lon_deg": lon_val,
		"altitude_m": 0.0,
		"island_radius_m": radius_m,
		"biome": biome_str,
		"climate": "Temperate Maritime",
		"danger_tier": 2,
		"currency": CURRENCY_ID,
		"is_starter_hub": false,
		"is_canonical": true,
		"has_dock": true,
		"settlements": [
			{
				"id": id_str + "_port",
				"name": kingdom_name + " Harbor",
				"type": "port",
				"lat_offset_deg": 0.0,
				"lon_offset_deg": 0.0,
				"elevation_m": 8.0,
				"description": "Regional port of call in " + region_str + ".",
				"features": ["Harbor Customs Pier", "Merchant Wharf"]
			}
		],
		"shops": [
			{
				"id": id_str + "_market",
				"name": kingdom_name + " Port Chandlery",
				"type": "ship_supply",
				"keeper_npc_id": id_str + "_harbormaster",
				"location_id": id_str + "_port",
				"description": "Standard East Blue maritime provisioning dock.",
				"inventory": [
					_item(id_str + "_rations", "Regional Sailor Rations", "provision", 1200, 15, "3 days crew provisions", ""),
					_item(id_str + "_repair_timber", "Port Repair Timber", "ship_supply", 2500, 10, "Repairs +20% hull integrity", "")
				]
			}
		],
		"npcs": [
			_npc(id_str + "_harbormaster", kingdom_name + " Harbormaster", "Port Official", kingdom_name, id_str + "_port", false, false, ["shop", "lore"], "Welcome to " + kingdom_name + ". Keep your sextant logged and watch the southern Calm Belt.")
		],
		"quest_hooks": [],
		"local_specialties": ["Regional Sailor Rations", "Repair Timber"],
		"wildlife_and_hazards": ["Regional Pirate Raiders", "Seasonal Gales"],
		"lore_summary": lore_str
	}
