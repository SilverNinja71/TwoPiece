class_name GrandLineData
extends RefCounted
## Production Data Module for "THE MIDDLE JUMBO MESS":
## Grand Line (Paradise & New World), Flanking Calm Belts, Red Line Intersections
## (Mary Geoise & Sabaody/Red Port), Sky Seas (+7,000m White Sea / +10,000m White-White Sea),
## and the Abyss (-10,000m Fish-Man Island & Impel Down Sub-Levels).
##
## Engineered for Godot 4.3+ compiled with `precision=double` (64-bit IEEE 754 floats).
## Baseline Scale: 1 unit = 1.0 meter | Player Height = 2.0m | Planet Radius R = 16,000,000.0m.

const PLANET_RADIUS_M: float = 16000000.0
const PLANET_CIRCUMFERENCE_M: float = 100530964.91
const GRAND_LINE_TILT_DEG: float = -45.0
const RED_LINE_TILT_DEG: float = 45.0
const GRAND_LINE_WIDTH_M: float = 600000.0
const CALM_BELT_WIDTH_M: float = 150000.0
const RED_LINE_WIDTH_M: float = 250000.0

# Vertical Layer Elevations (meters relative to Sea-Level Radius R = 16,000,000.0m)
const ELEVATION_ABYSS_M: float = -10000.0
const ELEVATION_IMPEL_DOWN_BASE_M: float = -5500.0
const ELEVATION_CALM_BELT_NEST_M: float = -2000.0
const ELEVATION_SEA_LEVEL_M: float = 0.0
const ELEVATION_WHITE_SEA_M: float = 7000.0
const ELEVATION_WHITE_WHITE_SEA_M: float = 10000.0
const ELEVATION_RED_LINE_CREST_M: float = 10000.0

# Canonical Currencies
const CURRENCY_BELI: String = "Beli"
const CURRENCY_EXTOL: String = "Extol" # 10,000 Extol = 1 Beli
const CURRENCY_GOR: String = "Gor"     # Amazon Lily Kuja tribal coinage
const CURRENCY_RYO_SILVER: String = "WanoSilverRyo"
const CURRENCY_RYO_GOLD: String = "WanoGoldRyo"
const CURRENCY_RYO_PLATINUM: String = "WanoPlatinumRyo"


## Converts spherical (lat_deg, lon_deg, alt_m) into a 64-bit world-space Vector3
## on the R = 16,000,000.0m planetary sphere.
static func lat_lon_alt_to_vector3(lat_deg: float, lon_deg: float, alt_m: float = 0.0) -> Vector3:
	var lat_rad: float = deg_to_rad(lat_deg)
	var lon_rad: float = deg_to_rad(lon_deg)
	var r: float = PLANET_RADIUS_M + alt_m
	var cos_lat: float = cos(lat_rad)
	return Vector3(
		r * cos_lat * cos(lon_rad),
		r * sin(lat_rad),
		r * cos_lat * sin(lon_rad)
	)


## Master aggregator used by WorldRegistry autoload.
static func get_region_data() -> Dictionary:
	return {
		"region_id": "grand_line_jumbo_sector",
		"planet_radius_m": PLANET_RADIUS_M,
		"grand_line_tilt_deg": GRAND_LINE_TILT_DEG,
		"grand_line_width_m": GRAND_LINE_WIDTH_M,
		"calm_belt_width_m": CALM_BELT_WIDTH_M,
		"currencies": get_currency_exchange_rates(),
		"islands": get_all_islands(),
		"sabaody_groves": get_sabaody_groves_directory(),
		"totto_land_archipelago": get_totto_land_archipelago(),
		"wano_regions": get_wano_regions(),
		"sea_train_network": get_sea_train_network(),
		"log_pose_routes": get_log_pose_routes(),
		"road_poneglyphs": get_road_poneglyph_locations(),
	}


## Returns exchange rates relative to 1 Beli.
static func get_currency_exchange_rates() -> Dictionary:
	return {
		CURRENCY_BELI: {"rate_to_beli": 1.0, "symbol": "B", "region": "Global / World Government"},
		CURRENCY_EXTOL: {"rate_to_beli": 0.0001, "symbol": "E", "region": "Skypiea / White-White Sea (10,000 Extol = 1 Beli)"},
		CURRENCY_GOR: {"rate_to_beli": 100.0, "symbol": "G", "region": "Amazon Lily (Kuja Tribe)"},
		CURRENCY_RYO_SILVER: {"rate_to_beli": 500.0, "symbol": "AgRyo", "region": "Wano Country (Everyday Trade)"},
		CURRENCY_RYO_GOLD: {"rate_to_beli": 10000.0, "symbol": "AuRyo", "region": "Wano Country (Merchant Bullion)"},
		CURRENCY_RYO_PLATINUM: {"rate_to_beli": 500000.0, "symbol": "PtRyo", "region": "Wano Country (Daimyo / House-Price Coin)"},
	}


## Returns all islands across Paradise, New World, Calm Belts, Sky Seas, Red Line, and Abyss.
static func get_all_islands() -> Dictionary:
	var all: Dictionary = {}
	all.merge(get_paradise_islands(), true)
	all.merge(get_sky_islands(), true)
	all.merge(get_calm_belt_islands(), true)
	all.merge(get_red_line_and_abyss_nodes(), true)
	all.merge(get_new_world_islands(), true)

	# Provide canonical alias keys expected by WorldRegistrySystem / StoryCampaignManager
	var alias_map: Dictionary = {
		"skypiea": "skypiea_upper_yard",
		"thriller_bark": "florian_triangle_thriller_bark",
		"whole_cake_island": "totto_land_whole_cake",
		"fullalead_hachinosu": "hachinosu",
		"sphinx_island": "sphinx",
		"karai_bari": "karai_bari_island"
	}
	for alias_key in alias_map.keys():
		var src_key: String = alias_map[alias_key]
		if all.has(src_key) and not all.has(alias_key):
			var copy_rec: Dictionary = all[src_key].duplicate(true)
			copy_rec["id"] = alias_key
			all[alias_key] = copy_rec

	# Normalize WorldRegistrySystem schema fields on every island record
	for key in all.keys():
		var rec: Dictionary = all[key]
		if not rec.has("log_pose_lock_sec"):
			rec["log_pose_lock_sec"] = float(rec.get("log_pose_lock_seconds", 600.0))
		if not rec.has("danger_jitter_deg"):
			rec["danger_jitter_deg"] = float(rec.get("needle_risk_rating", 3)) * 3.0
		if not rec.has("next_islands"):
			rec["next_islands"] = rec.get("next_log_pose_targets", []).duplicate()
		if not rec.has("shops"):
			var shop_names: Array[String] = []
			for m in rec.get("marketplaces", []):
				if m is Dictionary and m.has("name"):
					shop_names.append(str(m["name"]))
			rec["shops"] = shop_names
	return all


static func get_islands() -> Dictionary:
	return get_all_islands()


static func get_island_by_id(island_id: String) -> Dictionary:
	var all: Dictionary = get_all_islands()
	return all.get(island_id, {})


# ==============================================================================
# 1. PARADISE ISLANDS (LON 0 DEG TO 180 DEG ALONG GRAND LINE GREAT CIRCLE)
# ==============================================================================
static func get_paradise_islands() -> Dictionary:
	return {
		"whisky_peak": {
			"id": "whisky_peak",
			"name": "Whisky Peak (Cactus Island)",
			"sector": "Paradise",
			"lat_deg": -2.4,
			"lon_deg": 14.5,
			"alt_m": 0.0,
			"radius_m": 4200.0,
			"climate": "Arid Cactus Mesas & Nocturnal Desert Winds",
			"log_pose_lock_seconds": 28800, # ~8 hours (less than a day)
			"needle_risk_rating": 2,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["little_garden"],
			"towns": [
				{
					"name": "Whisky Peak Hospitality Port",
					"description": "Welcoming river-canal port flanked by giant grave-covered " +
						"cactus rocks (Baroque Works bounty hunter ambush town)."
				}
			],
			"marketplaces": [
				{
					"id": "cactus_saloon",
					"name": "Cactus Saloon & Banquet Hall",
					"type": "Tavern & Bounty Ledger Exchange",
					"proprietor": "Igaram (Mr. 8, Disguised Mayor)",
					"inventory": [
						{"item": "Whisky Peak Cactus Tequila", "price": 800, "currency": CURRENCY_BELI, "effect": "+25 Stamina, Sleep Trap Resist"},
						{"item": "Peak Barrel Aged Rum", "price": 500, "currency": CURRENCY_BELI, "effect": "Crew Morale +10"},
						{"item": "Baroque Works Bounty Ledger (Paradise Vol. 1)", "price": 5000, "currency": CURRENCY_BELI, "effect": "Reveals local bounty targets"},
						{"item": "Eternal Pose: Alabasta (Sanji / Mr. 3 Drop)", "price": 250000, "currency": CURRENCY_BELI, "effect": "Locks permanently onto Alabasta"}
					]
				}
			],
			"npcs": [
				{"name": "Igaram (Mr. 8)", "role": "Disguised Mayor / Alabasta Royal Guard Captain", "location": "Town Square", "quest_hook": "Escort Princess Vivi to Alabasta"},
				{"name": "Miss Monday", "role": "Baroque Works Frontier Agent (Superhuman Brass Knuckles)", "location": "Cactus Church", "quest_hook": "Strength Sparring Trial"},
				{"name": "Mr. 9", "role": "Acrobatic Bat-Wielder", "location": "Roof Lookout", "quest_hook": "Peak Rooftop Parkour Challenge"},
				{"name": "Nefertari Vivi (Miss Wednesday)", "role": "Undercover Princess of Alabasta", "location": "Harbor Canal", "quest_hook": "Unmask Mr. 0 (Crocodile)"},
				{"name": "Karoo", "role": "Super Spot-Billed Duck Courier", "location": "Harbor Canal", "quest_hook": "Desert Mount Training"},
				{"name": "Mr. 5 & Miss Valentine", "role": "Baroque Works Officer Agents", "location": "Cactus Graveyard", "quest_hook": "Boss Encounter"}
			],
			"exploration_hooks": [
				"Climb the giant 'Cactus' rock formations to inspect thousands of pirate tombstones whose spines are made from gravestones.",
				"Survive the midnight Baroque Works Billions banquet ambush without falling asleep."
			]
		},

		"little_garden": {
			"id": "little_garden",
			"name": "Little Garden",
			"sector": "Paradise",
			"lat_deg": -5.8,
			"lon_deg": 28.0,
			"alt_m": 0.0,
			"radius_m": 9500.0,
			"climate": "Prehistoric Tropical Rainforest & Active Volcano",
			"log_pose_lock_seconds": 31536000, # 1 Full Year (365 days) canonical lock time!
			"needle_risk_rating": 4,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["alabasta", "drum_island"],
			"towns": [
				{
					"name": "Giant Warriors' Clearing & Central Volcano",
					"description": "Uninhabited prehistoric jungle where Dorry and Brogy have fought " +
						"73,467+ duels over 100 years whenever the central volcano erupts."
				}
			],
			"marketplaces": [
				{
					"id": "mr3_wax_house",
					"name": "Mr. 3's Secret Candle House",
					"type": "Abandoned Baroque Works Safehouse & Tea Spot",
					"proprietor": "Galdino (Mr. 3) & Marianne (Miss Goldenweek)",
					"inventory": [
						{"item": "Dorudoru Candle Wax Armor Polish", "price": 4500, "currency": CURRENCY_BELI, "effect": "+15 Blunt Defense"},
						{"item": "Earl Grey Calming Paint Tea", "price": 1200, "currency": CURRENCY_BELI, "effect": "Clears Color Trap status"},
						{"item": "Eternal Pose: Alabasta", "price": 0, "currency": CURRENCY_BELI, "effect": "Looted from Unluckies (Mr. 13 & Miss Friday); bypasses 1-year Log Pose lock"}
					]
				}
			],
			"npcs": [
				{"name": "Dorry the Blue Ogre", "role": "Co-Captain of the Giant Warrior Pirates", "location": "Northern Skull Crater", "quest_hook": "100-Year Duel & Elbaf Spear Mastery (Hakoku)"},
				{"name": "Brogy the Red Ogre", "role": "Co-Captain of the Giant Warrior Pirates", "location": "Southern Jungle Clearing", "quest_hook": "Dinosaur Hunt & Giant Feast"},
				{"name": "Galdino (Mr. 3)", "role": "Baroque Works Officer Agent", "location": "Giant Candle Service Set", "quest_hook": "Destroy the Giant Candle Set"},
				{"name": "Marianne (Miss Goldenweek)", "role": "Colors Trap Painter", "location": "Jungle Clearing", "quest_hook": "Break the Colors Trap"},
				{"name": "Island Eater (Giant Goldfish)", "role": "Colossal Sea Monster off the Coast", "location": "Eastern Departure Reef", "quest_hook": "Survive departure through the Island Eater"}
			],
			"exploration_hooks": [
				"Standard Log Pose requires 1 real-time/in-game year to set; players must acquire the Alabasta Eternal Pose from Mr. 3's Candle House or Sanji's intercept.",
				"Hunt prehistoric Triceratops, Brontosaurs, and Tyrannosaurs while avoiding Kestia ticks (which cause the fatal 5-Day Disease requiring Drum Island's doctors)."
			]
		},

		"drum_island": {
			"id": "drum_island",
			"name": "Drum Island (Sakura Kingdom)",
			"sector": "Paradise",
			"lat_deg": 4.2,
			"lon_deg": 41.0,
			"alt_m": 0.0,
			"radius_m": 11000.0,
			"climate": "Sub-Zero Winter Island & 5,000m Sheer Drum Rockies",
			"log_pose_lock_seconds": 86400, # 24 hours
			"needle_risk_rating": 3,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["alabasta"],
			"towns": [
				{"name": "Bighorn", "description": "Primary port village guarded by Dalton and the citizen militia."},
				{"name": "Cocoa Weed", "description": "Lakeside village connected to Drum Castle by the Ropeway sky-cable."},
				{"name": "Gyasta", "description": "Snowy resort town famous for cross-country skiing."},
				{"name": "Robelle", "description": "Old southern village where Dr. Hiriluk treated patients and Ace briefly visited."},
				{"name": "Drum Castle (Peak 5,000m)", "description": "Royal fortress atop the central Drum Rock peak housing Dr. Kureha and the Isshi-100."}
			],
			"marketplaces": [
				{
					"id": "kureha_castle_apothecary",
					"name": "Dr. Kureha's Drum Castle Apothecary & Isshi-100 Clinic",
					"type": "Master Medical Library & Pharmacy",
					"proprietor": "Dr. Kureha (141-Year-Old Witch Doctor)",
					"inventory": [
						{"item": "Kestia 5-Day Antibiotic Cure", "price": 50000, "currency": CURRENCY_BELI, "effect": "Cures Prehistoric Kestia Fever"},
						{"item": "Rumble Ball Formula Notes", "price": 120000, "currency": CURRENCY_BELI, "effect": "Unlocks Zoan Wavelength Transformations"},
						{"item": "Hiriluk's Sakura Blossom Gunpowder", "price": 25000, "currency": CURRENCY_BELI, "effect": "Turns snowclouds into pink cherry blossoms"},
						{"item": "Plum Wine Flask (Kureha's Favorite)", "price": 1500, "currency": CURRENCY_BELI, "effect": "+40 Cold Resistance"}
					]
				},
				{
					"id": "bighorn_winter_outfitter",
					"name": "Dalton's Bighorn Winter Provision Post",
					"type": "Cold-Weather Gear & Sled Shop",
					"proprietor": "Dalton & Negikuma Maria",
					"inventory": [
						{"item": "Lapahn Fur Arctic Parka", "price": 6500, "currency": CURRENCY_BELI, "effect": "Immunity to Drum Island hypothermia"},
						{"item": "Ropeway Cable Pass", "price": 1000, "currency": CURRENCY_BELI, "effect": "Fast-travel between Cocoa Weed and Drum Castle"},
						{"item": "Snow-Sled Ship Runners", "price": 35000, "currency": CURRENCY_BELI, "effect": "Allows small boats to slide over ice floes"}
					]
				}
			],
			"npcs": [
				{"name": "Dr. Kureha", "role": "Master Physician & Mentor to Chopper", "location": "Drum Castle (+5,000m)", "quest_hook": "The Secret of the Will of D. ('Gol D. Roger')"},
				{"name": "Dalton", "role": "King of Sakura Kingdom (Ushi Ushi no Mi, Model: Bison)", "location": "Bighorn Village", "quest_hook": "Defend Bighorn from Wapol's Return & Lapahn Avalanches"},
				{"name": "Tony Tony Chopper", "role": "Blue-Nosed Reindeer Doctor", "location": "Drum Castle", "quest_hook": "Panacea Dream & Crew Doctor Recruitment"},
				{"name": "Negikuma Maria", "role": "Middle-Aged Villager mistaken for Hiking Bear", "location": "Bighorn Trail", "quest_hook": "Polite Bowing Etiquette Tutorial"},
				{"name": "Tamachibi", "role": "Young Bighorn Guard", "location": "Bighorn Gate", "quest_hook": "Avalanche Rescue"},
				{"name": "Hiking Bear", "role": "Polite Mountain Bear", "location": "Drum Rockies", "quest_hook": "Bow back when encountered or provoke a boss fight"}
			],
			"exploration_hooks": [
				"Free-climb the vertical 5,000m Drum Rockies barehanded while carrying an injured crewmate to reach Kureha's Castle.",
				"Befriend the ferocious Lapahn snow-rabbits by rescuing their parent from a snow avalanche."
			]
		},

		"alabasta": {
			"id": "alabasta",
			"name": "Alabasta Kingdom (Sandy Island)",
			"sector": "Paradise",
			"lat_deg": -8.5,
			"lon_deg": 56.0,
			"alt_m": 0.0,
			"radius_m": 48000.0,
			"climate": "Vast Arid Desert Kingdom Divided by the 50km-Wide Sandora River",
			"log_pose_lock_seconds": 259200, # 3 days
			"needle_risk_rating": 4,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": true,
			"poneglyph_details": {
				"type": "Historical Poneglyph (Pluton Location)",
				"location": "Hidden Royal Tomb of the Kings beneath Alubarna Palace",
				"content": "Records the resting place of the Ancient Weapon Pluton inside Old Wano Country."
			},
			"next_log_pose_targets": ["jaya"],
			"towns": [
				{"name": "Nanohana", "description": "Southeastern port city famous for its exotic perfume and bustling spice bazaars."},
				{"name": "Erumalu (The Green City)", "description": "Ruined desert town destroyed by Dance Powder drought and sandstorms."},
				{"name": "Yuba", "description": "Western oasis town and former Rebel Army headquarters where Toto tirelessly digs for water."},
				{"name": "Katorea", "description": "Oasis town near Nanohana that served as Koza's relocated Rebel Army base."},
				{"name": "Rainbase", "description": "Gambling resort town hosting Crocodile's giant golden pyramid casino, Rain Dinners."},
				{"name": "Alubarna", "description": "Monumental stepped plateau capital housing the Royal Palace, Clock Tower, and Tomb of the Kings."},
				{"name": "Tamarisk", "description": "Eastern coastal port where the Going Merry anchored during the Alubarna battle."}
			],
			"marketplaces": [
				{
					"id": "spice_bean_restaurant",
					"name": "Spice Bean Restaurant (Nanohana)",
					"type": "Desert Tavern & Provision House",
					"proprietor": "Nanohana Head Chef",
					"inventory": [
						{"item": "Alabasta Spice Bean Curry", "price": 900, "currency": CURRENCY_BELI, "effect": "+30 Heat Resistance & Stamina"},
						{"item": "Desert Survival Canteen (10L)", "price": 1200, "currency": CURRENCY_BELI, "effect": "Prevents Sandora Desert dehydration"},
						{"item": "Desert Sun-Robes & Headscarf", "price": 2500, "currency": CURRENCY_BELI, "effect": "Reduces solar heat drain by 50%"}
					]
				},
				{
					"id": "nanohana_perfume_bazaar",
					"name": "Nanohana Perfume & Carpet Grand Bazaar",
					"type": "Regional Trade Commodity Market",
					"proprietor": "Merchant Guild of Nanohana",
					"inventory": [
						{"item": "Cask of Royal Nanohana Perfume", "price": 8500, "currency": CURRENCY_BELI, "effect": "High-margin trade good (sells for 22,000B in Water 7)"},
						{"item": "Alubarna Woven Silk Carpet", "price": 15000, "currency": CURRENCY_BELI, "effect": "Ship Cabin Luxury Upgrade"},
						{"item": "Super Spot-Billed Duck Saddle", "price": 18000, "currency": CURRENCY_BELI, "effect": "Allows mounting desert ducks at 45 km/h"}
					]
				},
				{
					"id": "spiders_cafe",
					"name": "Spiders Cafe",
					"type": "Isolated Desert Junction Bar & Baroque Works Rendezvous",
					"proprietor": "Zala (Paula / Miss Doublefinger)",
					"inventory": [
						{"item": "Prickly Pear Cocktail", "price": 1100, "currency": CURRENCY_BELI, "effect": "+15 Critical Hit Rate"},
						{"item": "Baroque Works Cipher Dossier", "price": 12000, "currency": CURRENCY_BELI, "effect": "Reveals Rain Dinners VIP Underground Entrance"}
					]
				},
				{
					"id": "rain_dinners_casino",
					"name": "Rain Dinners Pyramid Casino",
					"type": "High-Stakes Casino & Bananawani Lair",
					"proprietor": "Sir Crocodile (Mr. 0) & Nico Robin (Miss All Sunday)",
					"inventory": [
						{"item": "VIP Gold Casino Chips (x100)", "price": 100000, "currency": CURRENCY_BELI, "effect": "Access to VIP Room (Beware Seastone Cage trap)"},
						{"item": "Yuba Oasis Pure Water Vial", "price": 500, "currency": CURRENCY_BELI, "effect": "Allows tangible strikes against Suna Suna no Mi Logia"}
					]
				}
			],
			"npcs": [
				{"name": "King Nefertari Cobra", "role": "12th King of Alabasta", "location": "Alubarna Royal Palace", "quest_hook": "Guard the Tomb of the Kings & Poneglyph Heritage"},
				{"name": "Princess Nefertari Vivi", "role": "Princess of Alabasta", "location": "Alubarna Clock Tower", "quest_hook": "Stop the Rebel-Royal Civil War & Clock Tower Bomb"},
				{"name": "Pell the Falcon", "role": "Head Guard of Alabasta (Tori Tori no Mi, Model: Falcon)", "location": "Alubarna Sky Patrol", "quest_hook": "Aerial Scouting & Falcon Dive Technique"},
				{"name": "Chaka the Jackal", "role": "Head Guard of Alabasta (Inu Inu no Mi, Model: Jackal)", "location": "Alubarna Palace Gate", "quest_hook": "Royal Swordsmanship Trial"},
				{"name": "Koza", "role": "Rebel Army Leader & Childhood Friend of Vivi", "location": "Katorea / Alubarna Plaza", "quest_hook": "Deliver the Truth about Dance Powder"},
				{"name": "Toto", "role": "Keeper of Yuba & Koza's Father", "location": "Yuba Oasis Wells", "quest_hook": "Dig for Pure Yuba Groundwater"},
				{"name": "Zala (Miss Doublefinger)", "role": "Proprietor of Spiders Cafe & Baroque Works Officer", "location": "Spiders Cafe", "quest_hook": "Toge Toge Duel in Alubarna"},
				{"name": "Terracotta", "role": "Igaram's Wife & Palace Head Chef", "location": "Alubarna Banquet Hall", "quest_hook": "Royal Victory Feast"},
				{"name": "Kappa", "role": "Young Shoeshine Boy in Nanohana/Alubarna", "location": "Alubarna West Gate", "quest_hook": "Expose the Mr. 2 Bon Clay Impostor"},
				{"name": "Eyelash (Matsuge)", "role": "Chivalrous Desert Camel", "location": "Erumalu Dunes", "quest_hook": "Caravan Transport for Female Crewmates"},
				{"name": "Hasami", "role": "Giant Desert Moving Crab (Friend of Eyelash)", "location": "Rainbase Outskirts", "quest_hook": "Cross the Sandora Desert at 60 km/h"}
			],
			"exploration_hooks": [
				"Defeat the Kung-Fu Dugongs on the banks of the Sandora River to earn their lifelong martial arts discipleship.",
				"Descend into the hidden Tomb of the Kings beneath Alubarna with Nico Robin to decipher the Pluton Historical Poneglyph."
			]
		},

		"jaya": {
			"id": "jaya",
			"name": "Jaya (Mock Town & Shandora Skull Tail)",
			"sector": "Paradise",
			"lat_deg": -3.1,
			"lon_deg": 74.0,
			"alt_m": 0.0,
			"radius_m": 14000.0,
			"climate": "Tropical Spring Island with Geothermal Sub-Sea Caverns",
			"log_pose_lock_seconds": 345600, # 4 Days canonical lock time!
			"needle_risk_rating": 3,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["skypiea_upper_yard", "long_ring_long_land"],
			"towns": [
				{"name": "Mock Town", "description": "Lawless pirate resort town on western Jaya where notorious crews brawl and scoff at dreamers."},
				{"name": "Cricket's Cape (Eastern Headland)", "description": "Half-circle bay where the upper skull of Jaya was blasted into the sky 400 years ago; home of the Saruyama Alliance."}
			],
			"marketplaces": [
				{
					"id": "pub_and_pies",
					"name": "Pub and Pies (Mock Town)",
					"type": "Pirate Tavern & Bakery",
					"proprietor": "Terry (Mock Town Bartender)",
					"inventory": [
						{"item": "Mock Town Famous Cherry Pie", "price": 300, "currency": CURRENCY_BELI, "effect": "Either tastes heavenly (+50 HP) or atrocious (-5 Mood) depending on player Dream Alignment"},
						{"item": "Jaya Spiced Grog", "price": 450, "currency": CURRENCY_BELI, "effect": "+20 Brawl Damage"},
						{"item": "Mock Town Wanted Poster Bundle", "price": 2000, "currency": CURRENCY_BELI, "effect": "Reveals 100M+ Beli Super Rookies"}
					]
				},
				{
					"id": "tropical_hotel",
					"name": "Tropical Hotel",
					"type": "Luxury Pirate Inn",
					"proprietor": "Spector (Manager)",
					"inventory": [
						{"item": "Executive Pirate Suite Rest", "price": 10000, "currency": CURRENCY_BELI, "effect": "Full Crew HP/Stamina Restore"},
						{"item": "South Forest Bug-Catching Net", "price": 1500, "currency": CURRENCY_BELI, "effect": "Required to capture a South Bird"}
					]
				},
				{
					"id": "saruyama_salvage_dock",
					"name": "Saruyama Alliance Ship Reinforcement Dock",
					"type": "Deep-Sea Salvage & Knock Up Stream Shipwrights",
					"proprietor": "Mont Blanc Cricket, Masira & Shoujou",
					"inventory": [
						{"item": "Knock Up Stream Wing & Keel Reinforcement", "price": 0, "currency": CURRENCY_BELI, "effect": "Quest Reward: Prepares ship to ride the Knock Up Stream to +7,000m White Sea"},
						{"item": "400-Year-Old Golden South Bird Bell Statuette", "price": 500000, "currency": CURRENCY_BELI, "effect": "Proof of the City of Gold Shandora"}
					]
				}
			],
			"npcs": [
				{"name": "Mont Blanc Cricket", "role": "Descendant of Mont Blanc Noland & Head of Saruyama Alliance", "location": "Cricket's Cape", "quest_hook": "Prove Shandora Exists & Ride the Knock Up Stream"},
				{"name": "Masira", "role": "Salvage King (Monkey-like Captain)", "location": "Victory Hunter Ship", "quest_hook": "Deep Sea Salvage Dive"},
				{"name": "Shoujou", "role": "Sonar King (Orangutan-like Captain with Havoc Sonar)", "location": "Utan Sonar Ship", "quest_hook": "Locate Sunken Galleons via Sonar"},
				{"name": "Terry", "role": "Bartender at Pub and Pies", "location": "Mock Town", "quest_hook": "Serve Cherry Pies to Blackbeard & Luffy"},
				{"name": "Marshall D. Teach (Blackbeard)", "role": "Dreaming Pirate Encounter", "location": "Outside Pub and Pies", "quest_hook": "'People's Dreams... Never End!' Speech"},
				{"name": "Bellamy the Hyena & Sarquiss", "role": "New Age Cynic Pirates", "location": "Tropical Hotel / Pub", "quest_hook": "One-Punch Jaya Reckoning"}
			],
			"exploration_hooks": [
				"Venture into the insect-infested South Forest at night to capture a live South Bird (whose beak always points due South) before the Knock Up Stream erupts.",
				"Intercept the geothermal whirlpool south of Jaya and ride the vertical 7,000-meter Knock Up Stream into the White Sea."
			]
		},

		"long_ring_long_land": {
			"id": "long_ring_long_land",
			"name": "Long Ring Long Land",
			"sector": "Paradise",
			"lat_deg": 1.8,
			"lon_deg": 92.0,
			"alt_m": 0.0,
			"radius_m": 22000.0,
			"climate": "Ring of 10 Steppe Islands Connected Once a Year by Extreme Low Tide (Aqua Laguna Precursor)",
			"log_pose_lock_seconds": 86400, # 1 day
			"needle_risk_rating": 2,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["water_7"],
			"towns": [
				{"name": "Tonjit's Nomadic Steppe Camp", "description": "Circular grassland ring where all flora and fauna grow comically elongated due to carefree open plains."}
			],
			"marketplaces": [
				{
					"id": "tonjit_yurt_exchange",
					"name": "Tonjit's Nomadic Yurt",
					"type": "Nomadic Pastoral Camp",
					"proprietor": "Tonjit",
					"inventory": [
						{"item": "10-Year Aged Stilt-Cheese", "price": 400, "currency": CURRENCY_BELI, "effect": "+15 Stamina"},
						{"item": "Elongated Bamboo Stilts", "price": 1200, "currency": CURRENCY_BELI, "effect": "High-ground observation tool"},
						{"item": "Davy Back Fight 3-Coin Challenge Pennant", "price": 5000, "currency": CURRENCY_BELI, "effect": "Initiates Donut Race, Groggy Ring, and Captain Combat"}
					]
				}
			],
			"npcs": [
				{"name": "Tonjit", "role": "Nomadic Elder stranded on stilts for 10 years", "location": "Island #1 Steppe", "quest_hook": "Reunite Tonjit with Shelly across the Low-Tide Land Bridge"},
				{"name": "Shelly", "role": "Elongated Dachshund-like Horse", "location": "Steppe Pasture", "quest_hook": "Protect Shelly from Foxy's Net"},
				{"name": "Foxy the Silver Fox, Porche & Hamburg", "role": "Foxy Pirates (Noro Noro no Mi)", "location": "Sexy Foxy Galleon", "quest_hook": "Win the 3-Round Davy Back Fight"},
				{"name": "Admiral Aokiji (Kuzan)", "role": "Wandering Marine Admiral on Bicycle (Ao Chari)", "location": "Coastal Ice Path", "quest_hook": "Freeze the Ocean between Islands so Tonjit's Tribe Can Cross"}
			],
			"exploration_hooks": [
				"Time your exploration with the annual 3-hour extreme low tide that exposes the circular land bridge connecting all 10 islands (caused by the Aqua Laguna water drawback toward Water 7)."
			]
		},

		"water_7": {
			"id": "water_7",
			"name": "Water 7 (The Capital of Water)",
			"sector": "Paradise",
			"lat_deg": -4.6,
			"lon_deg": 115.0,
			"alt_m": 0.0,
			"radius_m": 16500.0,
			"climate": "Venetian Tiered Fountain Metropolis Threatened Annually by the Aqua Laguna Tsunami",
			"log_pose_lock_seconds": 604800, # 7 Days (1 week)
			"needle_risk_rating": 3,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["fish_man_island"],
			"towns": [
				{"name": "Blue Station & Shift Station", "description": "Southern Sea Train terminals where the Puffing Tom arrives along floating ocean tracks."},
				{"name": "Back Street & Lower Canals", "description": "Sunken residential canals and tavern alleys built atop the submerged ruins of old Water 7."},
				{"name": "Shopping Center & Yagara Canal Ring", "description": "Bustling gondola-served merchant waterways and gold exchange houses."},
				{"name": "Galley-La Company Shipyards (Docks 1 to 7)", "description": "Seven monumental radial dry docks encircling the central island."},
				{"name": "Upper Town & Iceburg's Mansion", "description": "Elevated baroque palace district overlooking the fountain summit."},
				{"name": "Scrap Island & Franky House", "description": "Ship-dismantling junkyard on the outer breakwater controlled by the Franky Family."}
			],
			"marketplaces": [
				{
					"id": "galley_la_dock_1",
					"name": "Galley-La Company Dock 1 (Master Shipyard)",
					"type": "World-Class Naval Architecture & Ship Upgrade Foundry",
					"proprietor": "Iceburg (Mayor/President) & Foremen Paulie, Peepley Lulu, Tilestone",
					"inventory": [
						{"item": "Full Hull Overhaul & Keel Refit", "price": 1000000, "currency": CURRENCY_BELI, "effect": "Restores 100% Ship Structural Integrity"},
						{"item": "Treasure Tree Adam Wood Brigantine Frame", "price": 200000000, "currency": CURRENCY_BELI, "effect": "Unlocks Thousand Sunny-class Adam Wood Hull (withstands New World storms)"},
						{"item": "Cola-Powered Coup de Burst Engine", "price": 50000000, "currency": CURRENCY_BELI, "effect": "Launches ship 1,000m through the air using 3 barrels of Cola"},
						{"item": "Soldier Dock System Channels 0-4", "price": 35000000, "currency": CURRENCY_BELI, "effect": "Integrates Mini Merry II, Shark Submerge III, and Shiro Mokuba I"}
					]
				},
				{
					"id": "bluenos_bar",
					"name": "Blueno's Bar (Back Street)",
					"type": "Neighborhood Canal Tavern & Cola Supply",
					"proprietor": "Blueno (Undercover CP9 Agent)",
					"inventory": [
						{"item": "Water 7 Super Cola Barrel (x3)", "price": 1500, "currency": CURRENCY_BELI, "effect": "Fuels Cyborg weapons & Coup de Burst"},
						{"item": "Aqua Laguna Storm Rum", "price": 800, "currency": CURRENCY_BELI, "effect": "+20 Cold & Wave Resistance"},
						{"item": "Water Water Meat Skewer", "price": 650, "currency": CURRENCY_BELI, "effect": "Famous juicy barbecue specialty of Water 7 (+45 HP)"}
					]
				},
				{
					"id": "yagara_bull_rental",
					"name": "Yagara Bull Gondola Rental & Gold Exchange",
					"type": "Canal Mount Rental & Bullion Appraiser",
					"proprietor": "Yagara Wrangler & Gold Appraiser",
					"inventory": [
						{"item": "Yagara Bull Gondola Rental Pass", "price": 1000, "currency": CURRENCY_BELI, "effect": "Summons a 2-seat Yagara Bull water-horse for canal navigation"},
						{"item": "King Bull Charter", "price": 5000, "currency": CURRENCY_BELI, "effect": "Summons a giant 8-crew King Bull"},
						{"item": "Skypiea Gold Pillar Appraisal", "price": 300000000, "currency": CURRENCY_BELI, "effect": "Exchanges Upper Yard gold relics for 300,000,000 Beli cash in suitcases"}
					]
				}
			],
			"npcs": [
				{"name": "Iceburg", "role": "Mayor of Water 7 & President of Galley-La (Apprentice of Tom)", "location": "Galley-La HQ / Dock 1", "quest_hook": "Protect the Pluton Blueprints & Plan to Float Water 7 into a Ship"},
				{"name": "Tyrannosaurus", "role": "Iceburg's Pet Pocket Mouse", "location": "Iceburg's Jacket Pocket", "quest_hook": "Mascot Companion"},
				{"name": "Paulie", "role": "Dock 1 Rigging & Mast Foreman (Rope Action Master)", "location": "Dock 1 Drydock", "quest_hook": "Rigging Rope Mastery & Debt Collector Chase"},
				{"name": "Peepley Lulu", "role": "Dock 1 Pitch, Blacksmith & Sawing Foreman", "location": "Dock 1 Forge", "quest_hook": "Hair-Spike Gag & Cannon Forging"},
				{"name": "Tilestone", "role": "Dock 1 Carpentry, Caulking & Flagmaker Foreman", "location": "Dock 1 Timber Yard", "quest_hook": "Heavy Hull Framing"},
				{"name": "Franky (Cutty Flam)", "role": "Leader of the Franky Family & Master Shipwright", "location": "Franky House / Scrap Island", "quest_hook": "Build the Ship of Dreams (Thousand Sunny) from Treasure Tree Adam"},
				{"name": "Zambai, Kiwi & Mozu", "role": "Franky Family Dismantlers & Square Sisters", "location": "Franky House", "quest_hook": "Ship Salvage & Enies Lobby Raid Alliance"},
				{"name": "Kokoro, Chimney & Gonbe", "role": "Shift Station Conductor, Granddaughter & Cat-Rabbit", "location": "Shift Station", "quest_hook": "Launch the Unstoppable Prototype Sea Train Rocketman"},
				{"name": "Yokozuna", "role": "Giant Sumo-Wrestling Frog who Challenges the Sea Train", "location": "Sea Train Tracks", "quest_hook": "Spar with Yokozuna to Gain His Trust"}
			],
			"exploration_hooks": [
				"Navigate the vertical fountain canals aboard a Yagara Bull before the annual Aqua Laguna megatsunami floods the lower city.",
				"Ride the Puffing Tom or the runaway Rocketman across the ocean tracks to St. Poplar, San Faldo, Pucci, and Enies Lobby."
			]
		},

		"enies_lobby": {
			"id": "enies_lobby",
			"name": "Enies Lobby (The Judicial Island / Never-Night Island)",
			"sector": "Paradise",
			"lat_deg": -7.2,
			"lon_deg": 124.0,
			"alt_m": 0.0,
			"radius_m": 6000.0,
			"climate": "Perpetual Daylight Island Suspended Over a Bottomless Ocean Waterfall Abyss",
			"log_pose_lock_seconds": 0, # Unreachable by normal Log Pose; connected via Sea Train & Tarai Current
			"needle_risk_rating": 5,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["water_7"],
			"towns": [
				{"name": "Enies Lobby Courthouse Plaza", "description": "Fortified garrison ring leading to Baskerville's Three-Headed Courthouse."},
				{"name": "Tower of Justice & Bridge of Hesitation", "description": "CP9 headquarters overlooking the colossal Gates of Justice and the Tarai Current."}
			],
			"marketplaces": [
				{
					"id": "cp9_armory_vault",
					"name": "Tower of Justice Quartermaster Vault",
					"type": "World Government Tactical Armory",
					"proprietor": "Captured Quartermaster",
					"inventory": [
						{"item": "Rokushiki Training Manual (Soru / Geppo / Tekkai)", "price": 150000, "currency": CURRENCY_BELI, "effect": "Unlocks Six Powers martial arts tree"},
						{"item": "Golden Den Den Mushi Replica (Disarmed)", "price": 50000, "currency": CURRENCY_BELI, "effect": "Historical Buster Call collectible"},
						{"item": "Seastone Handcuff Key (#1 to #5)", "price": 25000, "currency": CURRENCY_BELI, "effect": "Unlocks CP9 Seastone restraints"}
					]
				}
			],
			"npcs": [
				{"name": "Oimo & Kashii", "role": "Elbaf Giant Gatekeepers Deceived for 50 Years", "location": "Main Gate", "quest_hook": "Reveal the Truth About Dorry & Brogy on Little Garden"},
				{"name": "Rob Lucci, Kaku, Jabra, Blueno, Kumadori, Fukurou & Kalifa", "role": "CP9 Assassins", "location": "Tower of Justice", "quest_hook": "Five-Key Rescue Raid & Bridge Pillar Showdown"},
				{"name": "Baskerville (Bas, Kerville & Princess)", "role": "Three-Headed Chief Judge (Three Men in One Coat)", "location": "Courthouse", "quest_hook": "Courtroom Breakout"}
			],
			"exploration_hooks": [
				"Shoot down the World Government flag atop the Courthouse to declare war for a crewmate's freedom.",
				"Open the colossal Gates of Justice to manipulate the Tarai Current whirlpool connecting Enies Lobby, Impel Down, and Marineford."
			]
		},

		"florian_triangle_thriller_bark": {
			"id": "florian_triangle_thriller_bark",
			"name": "Florian Triangle & Thriller Bark",
			"sector": "Paradise",
			"lat_deg": -2.0,
			"lon_deg": 146.0,
			"alt_m": 0.0,
			"radius_m": 12000.0,
			"climate": "Pitch-Black Perpetual Fog Bank Where 100+ Ships Vanish Every Year",
			"log_pose_lock_seconds": 86400,
			"needle_risk_rating": 4,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"is_mobile_island": true,
			"next_log_pose_targets": ["sabaody_archipelago"],
			"towns": [
				{"name": "Thriller Bark (World's Largest Pirate Ship)", "description": "Entire island from the West Blue converted into a fortified Gothic castle-ship by Gecko Moria."}
			],
			"marketplaces": [
				{
					"id": "rolling_pirates_camp",
					"name": "Lola's Victim Association Forest Camp",
					"type": "Shadow-Victim Resistance Outpost",
					"proprietor": "Charlotte Lola, Risky Brothers & Spoil",
					"inventory": [
						{"item": "Purified Sea Salt Pouch (x20)", "price": 500, "currency": CURRENCY_BELI, "effect": "Exorcises Kage Kage no Mi Zombies when thrown into their mouths"},
						{"item": "Big Mom's Signed Vivre Card (Lola's Gift)", "price": 0, "currency": CURRENCY_BELI, "effect": "Quest Reward: Compels Seducing Woods Homies in Totto Land to obey the player"},
						{"item": "Rumbar Pirates 'Binks' Sake' Tone Dial", "price": 75000, "currency": CURRENCY_BELI, "effect": "Plays the final quartet of the Rumbar Pirates for Laboon at Twin Cape"}
					]
				}
			],
			"npcs": [
				{"name": "Brook ('Humming' Brook)", "role": "Musician & Last Survivor of the Rumbar Pirates (Yomi Yomi no Mi)", "location": "Ghost Ship / Thriller Bark Rooftop", "quest_hook": "Reclaim Brook's Shadow from Legendary Samurai Ryuma & Fulfill Laboon's Promise"},
				{"name": "Charlotte Lola", "role": "Captain of the Rolling Pirates (4,445 Marriage Proposals)", "location": "Dead Forest", "quest_hook": "Defeat Gecko Moria Before Sunrise & Receive Big Mom's Vivre Card"},
				{"name": "Spoil", "role": "Old Man President of the Thriller Bark Victim's Association", "location": "Dead Forest", "quest_hook": "Shadow Restoration Quest"},
				{"name": "Gecko Moria, Dr. Hogback, Absalom & Perona", "role": "Mysterious Four of Thriller Bark", "location": "Mast Mansion & Oars Freezer", "quest_hook": "Boss Raid against Ancient Giant Zombie #900 (Oars)"},
				{"name": "Shimotsuki Ryuma (Zombie #470)", "role": "Legendary Sword God of Wano (Wielder of Shusui)", "location": "Hogback's Lab Roof", "quest_hook": "Swordsmanship Duel for the 21 O Wazamono Black Blade Shusui"}
			],
			"exploration_hooks": [
				"Navigate the zero-visibility Florian Triangle fog where colossal, red-eyed umbral titans tower above the clouds in the background.",
				"Defeat Gecko Moria before the fog parts at dawn so stolen shadows return before sunlight incinerates their owners."
			]
		},

		"sabaody_archipelago": {
			"id": "sabaody_archipelago",
			"name": "Sabaody Archipelago (Groves 1-79)",
			"sector": "Paradise",
			"lat_deg": 0.0,
			"lon_deg": 178.5,
			"alt_m": 0.0,
			"radius_m": 25000.0,
			"climate": "Giant Yarukiman Mangrove Forest Exuding Buoyant Soap Resin Bubbles Next to the Red Line",
			"log_pose_lock_seconds": 259200, # 3 Days (Coating time required by Silvers Rayleigh)
			"needle_risk_rating": 5,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["fish_man_island"],
			"towns": [
				{"name": "Groves 1-29 (Lawless Zone)", "description": "Unpoliced pirate & bounty hunter district containing Grove 1 (former Human Auctioning House) and Grove 13 (Shakky's Rip-Off Bar)."},
				{"name": "Groves 30-39 (Sabaody Park)", "description": "Giant bubble-ferris-wheel amusement park and concert dome (Soul King tour venue)."},
				{"name": "Groves 40-49 (Tourist & Souvenir Area)", "description": "Bustling shopping boulevards selling bubble-packs and Bon Chari rentals."},
				{"name": "Groves 50-59 (Shipyard & Coating Artisans)", "description": "Drydocks where ships are coated in Yarukiman resin for the -10,000m dive to Fish-Man Island."},
				{"name": "Groves 60-69 (Marine Base Garrison)", "description": "Heavily fortified Marine garrison monitoring the Red Line approach."},
				{"name": "Groves 70-79 (Hotel Town)", "description": "Peaceful resort hotels and inns for travelers awaiting ship coating."}
			],
			"marketplaces": [
				{
					"id": "shakkys_ripoff_bar",
					"name": "Shakky's Rip-Off Bar (Grove 13)",
					"type": "Underworld Intelligence Tavern & Rayleigh's Safehouse",
					"proprietor": "Shakuyaku (Shakky, Former Kuja Empress)",
					"inventory": [
						{"item": "Rip-Off Bar House Drink (With Intel)", "price": 100000, "currency": CURRENCY_BELI, "effect": "Reveals live positions of Worst Generation crews and Marine Admirals"},
						{"item": "Silvers Rayleigh's Vivre Card Fragment", "price": 0, "currency": CURRENCY_BELI, "effect": "Tracks Rayleigh and the crew's hidden ship at Grove 44/17"},
						{"item": "Coating Artisan Referral Token", "price": 50000, "currency": CURRENCY_BELI, "effect": "Unlocks Rayleigh's free Yarukiman Resin Ship Coating"}
					]
				},
				{
					"id": "rayleigh_coating_workshop",
					"name": "Silvers Rayleigh's Yarukiman Coating Dock (Grove 53 / Grove 42)",
					"type": "Submarine Ship Coating & Haki Mentorship",
					"proprietor": "Silvers Rayleigh ('The Dark King')",
					"inventory": [
						{"item": "Full Yarukiman Mangrove Resin Ship Coating", "price": 5000000, "currency": CURRENCY_BELI, "effect": "Enables diving to -10,000m Abyssal Sea Floor (Free after Grove 1 quest)"},
						{"item": "Emergency Air-Bubble Buoyancy Bag", "price": 45000, "currency": CURRENCY_BELI, "effect": "Personal diving bubble for -10,000m pressure"},
						{"item": "Three-Haki Primer (Kenbunshoku / Busoshoku / Haoshoku)", "price": 0, "currency": CURRENCY_BELI, "effect": "Unlocks Haki skill trees"}
					]
				},
				{
					"id": "sabaody_tourist_bazaar",
					"name": "Grove 41 Bubble Goods & Bon Chari Bazaar",
					"type": "Resin Bubble Vehicle & Utility Market",
					"proprietor": "Sabaody Bubble Merchant",
					"inventory": [
						{"item": "Bon Chari (Flying Bubble Bike) Rental", "price": 500, "currency": CURRENCY_BELI, "effect": "Hover-bike transport across Groves 1-79 (pops if taken above the Red Line)"},
						{"item": "Bon Chari Purchase", "price": 10000, "currency": CURRENCY_BELI, "effect": "Permanent Sabaody bubble bike"},
						{"item": "Floating Bubble Shopping Bags (x5)", "price": 200, "currency": CURRENCY_BELI, "effect": "+50 Inventory Carry Weight inside Sabaody/Fish-Man Island"}
					]
				}
			],
			"npcs": [
				{"name": "Silvers Rayleigh", "role": "First Mate of the Roger Pirates & Master Coating Mechanic", "location": "Grove 13 / Grove 1 / Grove 53", "quest_hook": "Coat the Ship for Fish-Man Island & Hear the True History Preview"},
				{"name": "Shakuyaku (Shakky)", "role": "Proprietor of Shakky's Rip-Off Bar & Former Empress of Amazon Lily", "location": "Grove 13 (100 Steps from Base)", "quest_hook": "Worst Generation Eleven Supernovas Intel"},
				{"name": "Duval & the Rosy Life Riders", "role": "Flying Fish Riders Allies", "location": "Grove 44 (4 km off Northeast Sabaody)", "quest_hook": "Defend the Ship During the 3-Day Coating & Aerial Taxi Service"},
				{"name": "Hatchan, Camie & Pappag", "role": "Takoyaki 8 Crew & Guides to Fish-Man Island", "location": "Grove 32 (Sabaody Park)", "quest_hook": "Rescue Camie from Peterman & the Grove 1 Auction House"},
				{"name": "Eustass Kid, Trafalgar Law, Capone Bege, Jewelry Bonney, Scratchmen Apoo, Basil Hawkins, X Drake & Urouge", "role": "Eleven Supernovas (Worst Generation)", "location": "Groves 1-29", "quest_hook": "Rival Captain Encounters"}
			],
			"exploration_hooks": [
				"Ride a Bon Chari across all 79 numbered Yarukiman Mangrove groves, each with distinct ecology, law enforcement rules, and bubble physics.",
				"Complete the 3-day Yarukiman resin coating so the ship can submerge beneath the Red Line toward Fish-Man Island."
			]
		},

		"banaro_island": {
			"id": "banaro_island",
			"name": "Banaro Island",
			"sector": "Paradise",
			"lat_deg": 3.4,
			"lon_deg": 104.0,
			"alt_m": 0.0,
			"radius_m": 5500.0,
			"climate": "Western Frontier Mesa Island (Site of the Banaro Incident)",
			"log_pose_lock_seconds": 43200,
			"needle_risk_rating": 4,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["water_7"],
			"towns": [
				{"name": "Banaro Town & Banana Rock", "description": "Western-style frontier town beneath giant Balancing Banana Rocks where Ace and Blackbeard clashed."}
			],
			"marketplaces": [
				{
					"id": "banaro_frontier_saloon",
					"name": "Banaro Frontier Saloon",
					"type": "Salvage & Gunpowder Post",
					"proprietor": "Banaro Town Sheriff",
					"inventory": [
						{"item": "Flame-Scorched Cowboy Hat", "price": 4500, "currency": CURRENCY_BELI, "effect": "+15 Fire Resistance"},
						{"item": "Dark-Gravity Obsidian Shard", "price": 18000, "currency": CURRENCY_BELI, "effect": "Rare crafting catalyst from the Banaro Incident crater"}
					]
				}
			],
			"npcs": [
				{"name": "Banaro Historian", "role": "Witness to the Trigger of the Summit War", "location": "Banana Rock Crater", "quest_hook": "Investigate the Sun vs. Darkness Battlefield"}
			],
			"exploration_hooks": [
				"Explore the half-scorched, half-crushed ruins of Banaro Town left by the Mera Mera no Mi vs. Yami Yami no Mi duel."
			]
		},

		"karakuri_baldimore": {
			"id": "karakuri_baldimore",
			"name": "Karakuri Island (Future Country Baldimore)",
			"sector": "Paradise",
			"lat_deg": 7.8,
			"lon_deg": 135.0,
			"alt_m": 0.0,
			"radius_m": 9000.0,
			"climate": "Sub-Zero Cyborg Winter Island & Birthplace of Dr. Vegapunk",
			"log_pose_lock_seconds": 172800,
			"needle_risk_rating": 3,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["sabaody_archipelago"],
			"towns": [
				{"name": "Baldimore", "description": "Snowbound mechanical town warmed by Vegapunk's unfinished central heating furnace and inhabited by cyborg wildlife."},
				{"name": "Vegapunk's First & Second Laboratories", "description": "Mountain laboratories housing weapon, ship, and Wapometal blueprints (site of the Nightmare of Baldimore)."}
			],
			"marketplaces": [
				{
					"id": "baldimore_tea_atelier",
					"name": "Kitton & Taroimo's Earl Grey Cyborg Workshop",
					"type": "Cyborg Part & Blueprint Foundry",
					"proprietor": "Kitton's Grandfather & Cyborg Dog Taroimo",
					"inventory": [
						{"item": "Wapometal Shape-Memory Alloy Plate", "price": 85000, "currency": CURRENCY_BELI, "effect": "Required to construct General Franky / Iron Pirate"},
						{"item": "Gaon Cannon & Radical Beam Schematics", "price": 150000, "currency": CURRENCY_BELI, "effect": "Upgrades ship & cyborg laser systems"},
						{"item": "Hot Earl Grey Tea Thermos", "price": 600, "currency": CURRENCY_BELI, "effect": "Temporarily changes Cyborg personality to Gentleman mode"}
					]
				}
			],
			"npcs": [
				{"name": "Kitton & Grandfather", "role": "Caretakers of Vegapunk's Hometown", "location": "Baldimore Cabin", "quest_hook": "Access Vegapunk's Hidden Sub-Lab Behind the Self-Destruct Crater"},
				{"name": "Taroimo", "role": "Cyborg Bulldog", "location": "Snowy Patrol Path", "quest_hook": "Guard against Cyborg Gorillas"}
			],
			"exploration_hooks": [
				"Recover Vegapunk's youth blueprints for lasers, Wapometal mechs, and icebreaker hulls from the hidden basement of the ruined laboratory."
			]
		},

		"kuraigana_island": {
			"id": "kuraigana_island",
			"name": "Kuraigana Island (Gloom Island / Shikkearu Kingdom Ruins)",
			"sector": "Paradise",
			"lat_deg": -6.5,
			"lon_deg": 152.0,
			"alt_m": 0.0,
			"radius_m": 8000.0,
			"climate": "Perpetually Dark, Foggy Gothic Ruin Island",
			"log_pose_lock_seconds": 172800,
			"needle_risk_rating": 4,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["sabaody_archipelago"],
			"towns": [
				{"name": "Shikkearu Castle (Mihawk's Residence)", "description": "Ruined Gothic cathedral-castle surrounded by a forest of weapon-mimicking Humandrills."}
			],
			"marketplaces": [
				{
					"id": "perona_gothic_cellar",
					"name": "Perona's Castle Wine & Bandage Pantry",
					"type": "Castle Provision Cellar",
					"proprietor": "Perona",
					"inventory": [
						{"item": "Mihawk's Vintage Red Wine", "price": 12000, "currency": CURRENCY_BELI, "effect": "+25 Observation Focus (Forbidden until Black Blade Haki is mastered)"},
						{"item": "Kumacy Plush Talisman", "price": 3500, "currency": CURRENCY_BELI, "effect": "Immunity to Negative Hollow depression"}
					]
				}
			],
			"npcs": [
				{"name": "Dracule 'Hawk-Eyes' Mihawk", "role": "World's Strongest Swordsman", "location": "Shikkearu Castle", "quest_hook": "Master Busoshoku Haki to Forge Any Blade into a Black Blade (Kokuto)"},
				{"name": "Perona", "role": "Ghost Princess (Horo Horo no Mi)", "location": "Castle Courtyard", "quest_hook": "Guide back to Sabaody Grove 42"},
				{"name": "Humandrill Alpha", "role": "Yoru-Mimicking Baboon Leader", "location": "Ruined Battlefield", "quest_hook": "Defeat all 100 Humandrills in the Forest"}
			],
			"exploration_hooks": [
				"Train against the war-hardened Humandrills that learned swordsmanship from the fall of the Shikkearu Kingdom."
			]
		},

		"momoiro_island": {
			"id": "momoiro_island",
			"name": "Momoiro Island (Kamabakka Queendom)",
			"sector": "Paradise",
			"lat_deg": 5.5,
			"lon_deg": 158.0,
			"alt_m": 0.0,
			"radius_m": 7500.0,
			"climate": "Pink Heart-Shaped Spring Island",
			"log_pose_lock_seconds": 86400,
			"needle_risk_rating": 3,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["sabaody_archipelago"],
			"towns": [
				{"name": "Kamabakka Queendom Royal Palace", "description": "Vibrant pink sanctuary ruled by Queen Emporio Ivankov and the 99 Newkama Kenpo Masters."}
			],
			"marketplaces": [
				{
					"id": "attack_cuisine_kitchen",
					"name": "99 Vital Recipes Attack Cuisine Kitchen",
					"type": "Master Culinary & Sky Walk Dojo",
					"proprietor": "Emporio Ivankov & Caroline",
					"inventory": [
						{"item": "99 Vital Recipe Scroll (Hormone Soup)", "price": 75000, "currency": CURRENCY_BELI, "effect": "Permanent +10% Crew Max HP & Stamina Recovery"},
						{"item": "Sky Walk (Geppo) Conditioning Sandals", "price": 45000, "currency": CURRENCY_BELI, "effect": "Unlocks mid-air kick propulsion"}
					]
				}
			],
			"npcs": [
				{"name": "Emporio Ivankov", "role": "Queen of Kamabakka Queendom & Revolutionary Army G-Commander", "location": "Queendom Palace", "quest_hook": "Defeat all 99 Newkama Kenpo Masters to Earn the 99 Vital Recipes"},
				{"name": "Inazuma", "role": "Revolutionary Officer (Choki Choki no Mi)", "location": "Palace Balcony", "quest_hook": "Revolutionary Supply Delivery"},
				{"name": "Caroline", "role": "Substitute Queen", "location": "Beach Arena", "quest_hook": "Maiden's Trial"}
			],
			"exploration_hooks": [
				"Master 'Sky Walk' by sprinting across the ocean and sky without touching the ground."
			]
		},

		"boin_archipelago": {
			"id": "boin_archipelago",
			"name": "Boin Archipelago (Greenstone & Forest of Gluttony)",
			"sector": "Paradise",
			"lat_deg": -5.0,
			"lon_deg": 162.0,
			"alt_m": 0.0,
			"radius_m": 6000.0,
			"climate": "Carnivorous Flower-Shaped Floating Islands (Stomach Baron)",
			"log_pose_lock_seconds": 86400,
			"needle_risk_rating": 4,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["sabaody_archipelago"],
			"towns": [
				{"name": "Forest of Gluttony", "description": "Ramen rivers, ham-fruit trees, and giant man-eating beetles perched atop a colossal carnivorous plant (Stomach Baron)."}
			],
			"marketplaces": [
				{
					"id": "heracles_pop_green_camp",
					"name": "Heracles's Pop Green Botanical Stash",
					"type": "Botanical Artillery Seed Exchange",
					"proprietor": "Heracles'n (Warrior of the Forest)",
					"inventory": [
						{"item": "Pop Green Seed Pouch (Devil / Rafflesia / Bamboo Javelin / Impact Wolf)", "price": 35000, "currency": CURRENCY_BELI, "effect": "Unlocks rapid-growth botanical slingshot ammo"},
						{"item": "Black Kabuto Slingshot Frame", "price": 60000, "currency": CURRENCY_BELI, "effect": "Long-range sniper weapon that grows when fed water"}
					]
				}
			],
			"npcs": [
				{"name": "Heracles'n", "role": "Eccentric Beetle-Armored Botanist & Survival Mentor", "location": "Outer Petal Rim", "quest_hook": "Survive the Stomach Baron's Feeding Frenzy & Master Pop Greens"}
			],
			"exploration_hooks": [
				"Avoid overeating in the ramen rivers on the outer petals before the entire island snaps shut toward its central mouth!"
			]
		}
	}


# ==============================================================================
# 2. SKY SEAS (+7,000M WHITE SEA & +10,000M WHITE-WHITE SEA)
# ==============================================================================
static func get_sky_islands() -> Dictionary:
	return {
		"skypiea_upper_yard": {
			"id": "skypiea_upper_yard",
			"name": "Skypiea (Angel Island & Upper Yard / Shandora)",
			"sector": "Sky Seas (White-White Sea)",
			"lat_deg": -3.1,
			"lon_deg": 74.2,
			"alt_m": ELEVATION_WHITE_WHITE_SEA_M, # +10,000.0 meters above Sea Level!
			"white_sea_gate_alt_m": ELEVATION_WHITE_SEA_M, # +7,000.0 meters (Heaven's Gate)
			"radius_m": 18000.0,
			"climate": "High-Altitude Pyrobloin Island Cloud & 400-Year-Old Vearth Jungle",
			"log_pose_lock_seconds": 86400,
			"needle_risk_rating": 4,
			"currency": CURRENCY_EXTOL, # 10,000 Extol = 1 Beli
			"has_road_poneglyph": false,
			"has_historical_poneglyph": true,
			"poneglyph_details": {
				"type": "Historical Poneglyph (Poseidon Location + Gol D. Roger's Oden Engraving)",
				"location": "Base of the Shandorian Golden Bell Belfry atop Giant Jack (+11,500m)",
				"content": "States that the Ancient Weapon Poseidon resides in Fish-Man Island; side-engraving in Ancient Script by Gol D. Roger ('I have come here and will lead this text to the farthest ends of the world')."
			},
			"next_log_pose_targets": ["long_ring_long_land"],
			"towns": [
				{"name": "Heaven's Gate (+7,000m White Sea)", "description": "Entry checkpoint guarded by Amazon where visitors pay 1,000,000,000 Extol (100,000 Beli) per person and ride the Milky Road Shrimp Express up to +10,000m."},
				{"name": "Angel Beach & Angel Island (+10,000m)", "description": "Peaceful Island Cloud city connected by Milky Road canals and Lovely Street."},
				{"name": "Shandia Village", "description": "Hidden cloud encampment of the exiled Shandian warriors sworn to relight the Light of Shandora."},
				{"name": "Upper Yard & Shandora Ruins", "description": "Sacred Vearth jungle blasted up from Jaya 400 years ago, pierced by the giant beanstalk Giant Jack."}
			],
			"marketplaces": [
				{
					"id": "lovely_street_dial_market",
					"name": "Lovely Street Dial & Cloud Bazaar",
					"type": "Sky Island Dial Tech & Waver Showroom",
					"proprietor": "Angel Island Dial Guild",
					"inventory": [
						{"item": "Impact Dial", "price": 50000000, "currency": CURRENCY_EXTOL, "beli_equivalent": 5000, "effect": "Absorbs kinetic impacts and releases them on press"},
						{"item": "Breath Dial (Wind / Propulsion)", "price": 15000000, "currency": CURRENCY_EXTOL, "beli_equivalent": 1500, "effect": "Stores wind currents or gas; powers Wavers"},
						{"item": "Flame Dial", "price": 20000000, "currency": CURRENCY_EXTOL, "beli_equivalent": 2000, "effect": "Stores and emits bursts of fire"},
						{"item": "Milky Dial", "price": 30000000, "currency": CURRENCY_EXTOL, "beli_equivalent": 3000, "effect": "Creates solid mid-air cloud tracks for Wavers"},
						{"item": "Tone Dial", "price": 10000000, "currency": CURRENCY_EXTOL, "beli_equivalent": 1000, "effect": "Records and plays back audio"},
						{"item": "Jet Dial (Extinct Antique)", "price": 500000000, "currency": CURRENCY_EXTOL, "beli_equivalent": 50000, "effect": "Extreme supersonic propulsion for Wavers or combat"},
						{"item": "Reject Dial (Forbidden Shandia Relic)", "price": 1000000000, "currency": CURRENCY_EXTOL, "beli_equivalent": 100000, "effect": "10x Impact Dial force with severe recoil to user"}
					]
				},
				{
					"id": "conis_pumpkin_cafe",
					"name": "Conis & Pagaya's Pumpkin Cafe (Lovely Street)",
					"type": "Sky Food & Beverage Tavern",
					"proprietor": "Conis & Pagaya",
					"inventory": [
						{"item": "Sky Pumpkin Juice", "price": 2000000, "currency": CURRENCY_EXTOL, "beli_equivalent": 200, "effect": "Cures high-altitude thin-air fatigue"},
						{"item": "Grilled Sky-Shark Fillet", "price": 4500000, "currency": CURRENCY_EXTOL, "beli_equivalent": 450, "effect": "+35 Stamina"},
						{"item": "Octopus Balloon (Descent Parachute)", "price": 80000000, "currency": CURRENCY_EXTOL, "beli_equivalent": 8000, "effect": "Required to float a ship safely from +10,000m down to the Blue Sea"}
					]
				}
			],
			"npcs": [
				{"name": "Gan Fall (The Sky Knight)", "role": "Former & Restored God of Skypiea", "location": "God's Sanctuary / Angel Beach", "quest_hook": "Blow the Whistle for 5,000,000 Extol Protection & Unite Skypieans and Shandians"},
				{"name": "Pierre", "role": "Spotted Bird with Uma Uma no Mi (Pegasus Form)", "location": "With Gan Fall", "quest_hook": "Aerial Mount Companion"},
				{"name": "Conis & Pagaya", "role": "Angel Island Citizen & Waver Engineer", "location": "Angel Beach / Lovely Street", "quest_hook": "Repair the Broken Blue-Sea Waver & Evacuate Angel Island"},
				{"name": "Su", "role": "Conis's Cloud Fox", "location": "Angel Beach", "quest_hook": "Leads to Hidden Cloud Stashes"},
				{"name": "Wyper (Descendant of Kalgara)", "role": "Leader of the Shandian Warriors (Burn Bazooka & Reject Dial)", "location": "Shandia Village / Giant Jack", "quest_hook": "Topple Giant Jack & Ring the Shandorian Golden Bell"},
				{"name": "Aisa, Laki, Kamakiri, Braham & Genbo", "role": "Shandian Warriors & Mantra (Observation Haki) Prodigy", "location": "Upper Yard", "quest_hook": "Mantra Radar Tracking of Enel"},
				{"name": "McKinley", "role": "Captain of the White Berets", "location": "Angel Island Gate", "quest_hook": "Enforce Cloud Law Codes"},
				{"name": "Amazon", "role": "Inspector at Heaven's Gate (+7,000m)", "location": "Heaven's Gate", "quest_hook": "Collect 1 Billion Extol Toll or Stamp as 'Illegal Entrants'"},
				{"name": "Nola (Son of Kashigami)", "role": "400-Year-Old Giant Sky Python", "location": "Upper Yard Ruins", "quest_hook": "Retrieve Gold from Inside Nola's Stomach & Ring the Bell for Cricket"}
			],
			"exploration_hooks": [
				"Climb the colossal beanstalk Giant Jack to +11,500m to ring the Golden Bell of Shandora, projecting the player's giant silhouette onto the clouds visible from Jaya below.",
				"Read Gol D. Roger's message carved beside the Poseidon Poneglyph at the base of the Golden Belfry.",
				"Descend back to the Blue Sea either via Cloud End with an Octopus Balloon or the perilous High West summit route."
			]
		},

		"weatheria": {
			"id": "weatheria",
			"name": "Weatheria",
			"sector": "Sky Seas (Drifting Sky Island)",
			"lat_deg": 6.0,
			"lon_deg": 148.0,
			"alt_m": ELEVATION_WHITE_WHITE_SEA_M,
			"radius_m": 3200.0,
			"climate": "Drifting Meteorological Sky Island",
			"log_pose_lock_seconds": 0,
			"needle_risk_rating": 1,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"is_mobile_island": true,
			"next_log_pose_targets": ["sabaody_archipelago"],
			"towns": [
				{"name": "Weatheria Observatory Dome", "description": "Floating cloud island inhabited by eccentric elderly wizard-meteorologists who sell weather-control services to the Blue Sea."}
			],
			"marketplaces": [
				{
					"id": "weatheria_wind_knot_atelier",
					"name": "Haredas's Weather Ball & Wind Knot Laboratory",
					"type": "New World Meteorology & Sorcery Clima-Tact Foundry",
					"proprietor": "Haredas & Weatheria Elders",
					"inventory": [
						{"item": "Three-Knot Wind Rope", "price": 15000, "currency": CURRENCY_BELI, "effect": "Untie 1 knot for breeze, 2 for gale, 3 for hurricane"},
						{"item": "Weather Ball (Rain / Thunder / Gust Cloud)", "price": 45000, "currency": CURRENCY_BELI, "effect": "Core component for Sorcery Clima-Tact"},
						{"item": "New World Meteorological Atlas", "price": 80000, "currency": CURRENCY_BELI, "effect": "Predicts sudden New World hailstorms, fire-rain, and eddy currents 10 minutes early"}
					]
				}
			],
			"npcs": [
				{"name": "Haredas", "role": "Chief Meteorologist of Weatheria", "location": "Observatory Roof", "quest_hook": "Master New World Weather Science & Sorcery Clima-Tact Upgrades"}
			],
			"exploration_hooks": [
				"Steal or earn the forbidden Weather Balls of Weatheria to manipulate localized storm systems over the Blue Sea."
			]
		},

		"birka_and_ballon_terminal": {
			"id": "birka_and_ballon_terminal",
			"name": "Birka Ruins & Ballon Terminal",
			"sector": "Sky Seas (White-White Sea)",
			"lat_deg": -4.5,
			"lon_deg": 168.0,
			"alt_m": ELEVATION_WHITE_WHITE_SEA_M,
			"radius_m": 4500.0,
			"climate": "High-Altitude Ruined Cloud Archipelago",
			"log_pose_lock_seconds": 0,
			"needle_risk_rating": 4,
			"currency": CURRENCY_EXTOL,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["sabaody_archipelago"],
			"towns": [
				{"name": "Ballon Terminal", "description": "Abandoned sky island floating above Kidd's hideout where millions of children's lost helium balloons from the Blue Sea accumulate."},
				{"name": "Birka Remnant", "description": "Southeastern sky cloud remnants of Enel and Urouge's homeland."}
			],
			"marketplaces": [
				{
					"id": "birka_monk_sanctuary",
					"name": "Fallen Monk Sky Shrine",
					"type": "Mantra & Karma Meditation Post",
					"proprietor": "Birkan Survivor",
					"inventory": [
						{"item": "Birkan Winged Priest Robes", "price": 40000000, "currency": CURRENCY_EXTOL, "beli_equivalent": 4000, "effect": "+15 Lightning Resistance"},
						{"item": "Ark Maxim Blueprint Fragment", "price": 250000000, "currency": CURRENCY_EXTOL, "beli_equivalent": 25000, "effect": "Reveals ancient lunar mural lore"}
					]
				}
			],
			"npcs": [
				{"name": "Urouge ('Mad Monk')", "role": "Birkan Supernova Captain", "location": "Ballon Terminal Edge", "quest_hook": "Endurance Trial on the Cloud Edge"}
			],
			"exploration_hooks": [
				"Inspect the Edge of the Sky Island where Kaido once jumped 10,000 meters down to the Blue Sea."
			]
		}
	}


# ==============================================================================
# 3. CALM BELT ISLANDS & FORTRESSES (ZERO WIND, SEA KING NESTS)
# ==============================================================================
static func get_calm_belt_islands() -> Dictionary:
	return {
		"amazon_lily": {
			"id": "amazon_lily",
			"name": "Amazon Lily (Island of Women)",
			"sector": "Calm Belt (South Flanking Band)",
			"lat_deg": -12.5,
			"lon_deg": 156.0,
			"alt_m": 0.0,
			"radius_m": 11500.0,
			"climate": "Tropical Jungle Ring Surrounding a Colossal Carved Snake-Head Mountain inside the Calm Belt",
			"log_pose_lock_seconds": 0, # Unreachable by standard Log Pose
			"needle_risk_rating": 5,
			"currency": CURRENCY_GOR,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["sabaody_archipelago"],
			"towns": [
				{"name": "Kuja Village & Nine Snakes Castle", "description": "Ancient Chinese-inspired fortress city built into the central caldera, strictly forbidden to men."}
			],
			"marketplaces": [
				{
					"id": "kuja_haki_archery_foundry",
					"name": "Kuja Snake-Bow & Gor Bazaar",
					"type": "Busoshoku-Imbued Weaponry & Yuda Shipwrights",
					"proprietor": "Marguerite, Sweet Pea & Aphelandra",
					"inventory": [
						{"item": "Kuja Snake-Bow & Haki Arrow Quiver", "price": 250, "currency": CURRENCY_GOR, "effect": "Arrows imbued with Busoshoku Haki shatter stone and pierce Logia defenses"},
						{"item": "Yuda Fierce-Snake Paddlewheel Harness", "price": 5000, "currency": CURRENCY_GOR, "effect": "Allows ship to cross the windless Calm Belt without triggering Sea Kings"},
						{"item": "Belladonna's Mushroom Extraction Kit", "price": 40, "currency": CURRENCY_GOR, "effect": "Safely removes parasitic Body-Growing Mushrooms"}
					]
				}
			],
			"npcs": [
				{"name": "Boa Hancock (Pirate Empress)", "role": "Snake Princess of Amazon Lily & Captain of the Kuja Pirates (Mero Mero no Mi)", "location": "Nine Snakes Castle", "quest_hook": "Bacura Arena Trial & Smuggle Into Impel Down"},
				{"name": "Boa Sandersonia & Boa Marigold", "role": "Gorgon Sisters (Hebi Hebi no Mi: Anaconda & King Cobra)", "location": "Battle Arena", "quest_hook": "2v1 Observation & Advanced Armament Haki Trial"},
				{"name": "Elder Nyon (Gloriosa)", "role": "Former Empress of Amazon Lily (3 Generations Prior)", "location": "Outskirts Temple", "quest_hook": "Newspaper World Events & Love Sickness Lore"},
				{"name": "Marguerite, Sweet Pea & Aphelandra", "role": "Kuja Jungle Guards", "location": "Jungle Perimeter", "quest_hook": "Haki Arrow Training"},
				{"name": "Belladonna & Kikyo", "role": "Village Doctor & Guard Commander", "location": "Kuja Village", "quest_hook": "Calm Belt Sea King Hunting"}
			],
			"exploration_hooks": [
				"Sailing into the surrounding 150km-wide Calm Belt drops wind speed to 0.0 m/s and triggers 1,000m-long Sea King spawns from -2,000m depth unless the ship uses a Seastone keel or Yuda snake propulsion."
			]
		},

		"rusukaina": {
			"id": "rusukaina",
			"name": "Rusukaina (48-Season Island)",
			"sector": "Calm Belt (Northwest of Amazon Lily)",
			"lat_deg": -11.8,
			"lon_deg": 154.5,
			"alt_m": 0.0,
			"radius_m": 8500.0,
			"climate": "Extreme Hyper-Harsh Jungle Shifting Through 48 Distinct Seasons Every Year (Weekly Season Shift)",
			"log_pose_lock_seconds": 0,
			"needle_risk_rating": 5,
			"currency": CURRENCY_GOR,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["amazon_lily", "sabaody_archipelago"],
			"towns": [
				{"name": "Safe Zone Rock & Ruined Kingdom", "description": "Central plateau where no beasts dare tread, surrounded by 500+ apex monsters stronger than base Paradise captains."}
			],
			"marketplaces": [
				{
					"id": "rayleigh_haki_camp",
					"name": "Rayleigh's Safe-Rock Training Camp",
					"type": "Master Haki Dojo & Kuja Food Drop Point",
					"proprietor": "Silvers Rayleigh",
					"inventory": [
						{"item": "Blindfold of Kenbunshoku Mastery", "price": 100, "currency": CURRENCY_GOR, "effect": "Doubles Observation Haki XP gain while equipped"},
						{"item": "Rusukaina Boss Beast Roast", "price": 50, "currency": CURRENCY_GOR, "effect": "Full HP/Stamina restore + 20% Haki regeneration"}
					]
				}
			],
			"npcs": [
				{"name": "Silvers Rayleigh", "role": "Haki Grandmaster", "location": "Safe Zone Rock", "quest_hook": "18-Month Three-Haki Mastery & Gear 4 Beast Sparring"}
			],
			"exploration_hooks": [
				"Weather shifts dynamically every in-game week across 48 seasons while battling giant lions, gorillas, and crocodiles to unlock Gear 4 / Advanced Haki."
			]
		},

		"impel_down": {
			"id": "impel_down",
			"name": "Impel Down (The Underwater Great Prison)",
			"sector": "Calm Belt & Abyssal Tower",
			"lat_deg": -9.5,
			"lon_deg": 164.0,
			"alt_m": 0.0, # Top entrance at 0m, descending to -5,500m on the Calm Belt sea floor
			"bottom_alt_m": ELEVATION_IMPEL_DOWN_BASE_M,
			"radius_m": 3800.0,
			"climate": "Submerged Seastone Tower Surrounded by Calm Belt Sea Kings & Connected via the Tarai Current",
			"log_pose_lock_seconds": 0,
			"needle_risk_rating": 5,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["marineford", "enies_lobby"],
			"towns": [
				{"name": "Level 1: Crimson Hell (-500m)", "description": "Forest of razor-sharp blade trees (Kenshinju) and needle grass (Haribarisou) soaked in blood."},
				{"name": "Level 2: Wild Beast Hell (-1,500m)", "description": "Labyrinth patrolled by Basilisks, Manticores, Puzzle Scorpions, and the Sphinx guardian."},
				{"name": "Level 3: Starvation Hell (-2,500m)", "description": "Arid desert floor heated from below where 50M+ Beli bounties dehydrate."},
				{"name": "Level 4: Blazing Hell (-3,500m)", "description": "Cauldron of boiling blood and fire where Warden Magellan's office and kitchen sit."},
				{"name": "Level 5: Freezing Hell (-4,500m)", "description": "Sub-zero blizzard forest patrolled by Army Wolves where Den Den Mushi signals freeze."},
				{"name": "Level 5.5: Newkama Land (-4,750m)", "description": "Secret paradise carved inside the rock between Levels 5 and 6 by a former Morley tunneling prisoner, ruled by Ivankov and later Bon Clay."},
				{"name": "Level 6: Eternal Hell (-5,500m)", "description": "Deepest abyssal vault holding erased legends (Ace, Jinbe, Crocodile, Shiryu, Level 6 Titanic Captains)."}
			],
			"marketplaces": [
				{
					"id": "newkama_land_cabaret",
					"name": "Level 5.5 Newkama Land Cabaret & Stolen Armory",
					"type": "Underground Prisoner Sanctuary & Black Market",
					"proprietor": "Emporio Ivankov / Bentham (Mr. 2 Bon Clay)",
					"inventory": [
						{"item": "Emporio Healing Hormone Injection", "price": 100000, "currency": CURRENCY_BELI, "effect": "Purges lethal Magellan Hydra poison (costs 10% temporary max HP)"},
						{"item": "Emporio Tension Hormone", "price": 50000, "currency": CURRENCY_BELI, "effect": "24-Hour Adrenaline Overdrive (+50% Speed & Stamina)"},
						{"item": "Stolen Guard Uniform & Den Den Mushi Jammer", "price": 15000, "currency": CURRENCY_BELI, "effect": "Disguise for Levels 1-4"}
					]
				}
			],
			"npcs": [
				{"name": "Magellan", "role": "Chief Warden / Vice Warden of Impel Down (Doku Doku no Mi)", "location": "Level 4 Office", "quest_hook": "Survive the Venom Demon Pursuit"},
				{"name": "Hannyabal", "role": "Ambitious Vice Warden / Chief Warden (Kessui Spear)", "location": "Level 3 / Level 4", "quest_hook": "Hold the Gate of Level 4"},
				{"name": "Sadie, Saldeath & Domino", "role": "Chief Guards & Jailer Beast Tamers", "location": "Levels 1-4", "quest_hook": "Defeat the Awakened Zoan Jailer Beasts (Minotaurus, Minorhinoceros, Minokoala, Minozebra)"},
				{"name": "Bentham (Mr. 2 Bon Clay)", "role": "Queen of Level 5.5 & Ultimate Friend", "location": "Level 5.5 / Control Room", "quest_hook": "Open the Gates of Justice in the Name of Friendship"}
			],
			"exploration_hooks": [
				"Descend all 6 underwater tiers from 0m down to -5,500m, discover the secret tunnel into Level 5.5 Newkama Land, and hijack a Marine battleship on the Tarai Current."
			]
		},

		"marineford": {
			"id": "marineford",
			"name": "Marineford (Ox Bell Plaza & Old Marine Headquarters)",
			"sector": "Paradise / Red Line Approach",
			"lat_deg": 2.5,
			"lon_deg": 173.0,
			"alt_m": 0.0,
			"radius_m": 7200.0,
			"climate": "Crescent-Bay Fortress Island Connected to the Tarai Current",
			"log_pose_lock_seconds": 86400,
			"needle_risk_rating": 5,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["sabaody_archipelago"],
			"towns": [
				{"name": "Oris Plaza & Ox Bell Memorial", "description": "Crescent bay plaza where the Sacred Ox Bell from the warship Oris hangs, rung 16 times to herald a New Era."}
			],
			"marketplaces": [
				{
					"id": "marineford_quartermaster_depot",
					"name": "G-1 / Marineford Quartermaster Supply",
					"type": "Naval Munitions & Justice Cloak Outfitter",
					"proprietor": "Marine Quartermaster",
					"inventory": [
						{"item": "Justice Officer Coat", "price": 40000, "currency": CURRENCY_BELI, "effect": "+25 Command Aura (Never falls off shoulders)"},
						{"item": "Seastone Net Launcher", "price": 90000, "currency": CURRENCY_BELI, "effect": "Immobilizes Devil Fruit users for 8 seconds"}
					]
				}
			],
			"npcs": [
				{"name": "Fleet Admiral Sengoku & Vice Admiral Garp", "role": "Legends of the Marines", "location": "Oris Plaza", "quest_hook": "Summit War Historical Replay & 16 Bell Rings Ceremony"}
			],
			"exploration_hooks": [
				"Ring the Ox Bell 8 times to thank the old year and 8 times to welcome the new—or 16 times to broadcast a message across the globe."
			]
		}
	}


# ==============================================================================
# 4. RED LINE INTERSECTION NODE B (+10,000M MARY GEOISE & -10,000M FISH-MAN ISLAND)
# ==============================================================================
static func get_red_line_and_abyss_nodes() -> Dictionary:
	return {
		"mary_geoise_red_port": {
			"id": "mary_geoise_red_port",
			"name": "Mary Geoise & Red Port (Holy Land atop the Red Line)",
			"sector": "Red Line Intersection Node B",
			"lat_deg": 0.0,
			"lon_deg": 180.0,
			"alt_m": ELEVATION_RED_LINE_CREST_M, # +10,000.0 meters above Sea Level!
			"red_port_alt_m": 0.0, # Sea-level Bondola elevator ports on Paradise and New World sides
			"radius_m": 30000.0,
			"climate": "Alpine Marble Metropolis Perched on +10,000m Sheer Red Cliffs",
			"log_pose_lock_seconds": 0,
			"needle_risk_rating": 5,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["sabaody_archipelago", "new_marineford"],
			"towns": [
				{"name": "Red Port (Paradise & New World Base Docks, 0m)", "description": "Twin sea-level harbor fortresses operating the giant bubble-powered Bondola cable elevators up the 10,000m Red Line cliff."},
				{"name": "Socializing Plaza & Travelator Boulevard (+10,000m)", "description": "Moving walkways and forested gardens leading to Pangaea Castle."},
				{"name": "Domain of the Gods (+10,000m)", "description": "Walled residential district of the Celestial Dragons (World Nobles)."},
				{"name": "Pangaea Castle (+10,200m)", "description": "Seat of the World Government containing the Empty Throne, Room of Authority, Room of Flowers, and the frozen giant Straw Hat vault."}
			],
			"marketplaces": [
				{
					"id": "red_port_transit_office",
					"name": "Red Port Bondola Transit & Official Pass Bureau",
					"type": "Legal Red Line Crossing Checkpoint",
					"proprietor": "World Government Port Commissioner",
					"inventory": [
						{"item": "Official Red Line Transit Permit (Ship Abandoned)", "price": 10000000, "currency": CURRENCY_BELI, "effect": "Allows legal Bondola ascent over the Red Line (requires leaving your current ship behind)"},
						{"item": "Celestial Bubble Respirator", "price": 50000, "currency": CURRENCY_BELI, "effect": "Disguise accessory inside Domain of the Gods"}
					]
				}
			],
			"npcs": [
				{"name": "Five Elders (Gorosei)", "role": "Highest Authorities of the World Government", "location": "Pangaea Castle Room of Authority", "quest_hook": "Infiltrate Pangaea Castle During the Levely"},
				{"name": "Fisher Tiger Memorial Plaque (Hidden)", "role": "Liberation History Marker", "location": "Red Line Cliff Wall", "quest_hook": "Follow Fisher Tiger's Barehanded 10,000m Climb Route"}
			],
			"exploration_hooks": [
				"Players who refuse to abandon their ship at Red Port must instead coat their vessel at Sabaody and dive -10,000m beneath the Red Line through the submarine cavern of Fish-Man Island."
			]
		},

		"fish_man_island": {
			"id": "fish_man_island",
			"name": "Fish-Man Island (Ryugu Kingdom)",
			"sector": "The Abyss (Under the Red Line)",
			"lat_deg": 0.0,
			"lon_deg": 180.0,
			"alt_m": ELEVATION_ABYSS_M, # -10,000.0 meters below Sea Level!
			"radius_m": 20000.0,
			"climate": "Submarine Cavern Illuminated by Sunlight Tree Eve Inside a Double-Layered Yarukiman Resin Bubble",
			"log_pose_lock_seconds": 86400, # 1 Day; awards the New World Triple-Needle Log Pose!
			"needle_risk_rating": 4,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": true,
			"poneglyph_details": {
				"type": "Historical Poneglyph (Joy Boy's Apology Letter to Poseidon) + Missing Road Poneglyph Pedestal",
				"location": "Sea Forest (Grave of Queen Otohime at -10,000m)",
				"content": "Joy Boy's apology letter to the Mermaid Princess of the Void Century for failing to keep his promise regarding the Ark Noah; adjacent pedestal once held the 4th Road Poneglyph before it was moved."
			},
			"next_log_pose_targets": ["punk_hazard", "raijin_island", "risky_red_island", "mystoria_island"],
			"towns": [
				{"name": "Coral Hill", "description": "Bustling port town and commercial hub housing the Mermaid Cafe and bubble tube junctions."},
				{"name": "Mermaid Cove", "description": "Idyllic lagoon with giant clam shells and sea turtles where mermaids swim and sing."},
				{"name": "Gyoverly Hills", "description": "Ultra-wealthy celebrity district housing Pappag's mansion and the Criminal Brand flagship boutique."},
				{"name": "Ryugu Palace", "description": "Coral castle suspended in its own upper bubble at the top of Fish-Man Island, connected by an air-corridor tube."},
				{"name": "Fish-Man District & Ark Noah", "description": "Lawless sunken hull of the colossal ship of promise Noah just outside the main bubble."},
				{"name": "Sea Forest", "description": "Ship graveyard on the ocean floor illuminated by Sunlight Tree Eve's roots, where Den researches currents and Joy Boy's Poneglyph rests."},
				{"name": "Candy Factory", "description": "Industrial confectionery plant producing 10 tons of sweets monthly for Big Mom's protection tribute."}
			],
			"marketplaces": [
				{
					"id": "mermaid_cafe",
					"name": "Mermaid Cafe (Coral Hill)",
					"type": "Undersea Lounge, Bakery & Madam Shyarly's Crystal Room",
					"proprietor": "Madam Shyarly (Owner/Fortune Teller), Camie & Ishilly",
					"inventory": [
						{"item": "Wakame Kelp Brulee & Clam Tart", "price": 1200, "currency": CURRENCY_BELI, "effect": "+40 HP & Underwater Swim Speed +15%"},
						{"item": "Mermaid Kelp Herbal Tea", "price": 600, "currency": CURRENCY_BELI, "effect": "Clears deep-sea decompression fatigue"},
						{"item": "New World Triple-Needle Log Pose (Minister of the Left Gift)", "price": 0, "currency": CURRENCY_BELI, "effect": "Required to navigate the chaotic magnetic fields of the New World"}
					]
				},
				{
					"id": "criminal_brand_store",
					"name": "Criminal Brand Flagship Boutique (Gyoverly Hills)",
					"type": "High-Fashion Streetwear & Accessory Shop",
					"proprietor": "Pappag (Starfish Designer)",
					"inventory": [
						{"item": "Criminal Star Hoodie (Limited Edition)", "price": 25000, "currency": CURRENCY_BELI, "effect": "+20 Reputation in Fish-Man Island & Sabaody"},
						{"item": "Coral Pearl Necklace", "price": 45000, "currency": CURRENCY_BELI, "effect": "Luxury trade item"},
						{"item": "Coral Bubble Ring (Personal Air Bubble)", "price": 15000, "currency": CURRENCY_BELI, "effect": "Generates a breathable air bubble outside the island dome"}
					]
				},
				{
					"id": "den_sea_forest_coating",
					"name": "Den's Sea Forest Ship Recoating & Current Observatory",
					"type": "Abyssal Shipwright & Ocean Current Cartography",
					"proprietor": "Den (Younger Brother of Legendary Shipwright Tom)",
					"inventory": [
						{"item": "New World Ascent Bubble Recoating", "price": 1000000, "currency": CURRENCY_BELI, "effect": "Repairs ship bubble for the ascent up the White Strom to the New World"},
						{"item": "Deep-Sea Plankton Current Chart", "price": 30000, "currency": CURRENCY_BELI, "effect": "Maps the Downward Plume, Kraken Trench, and White Strom"}
					]
				}
			],
			"npcs": [
				{"name": "King Neptune (God of the Sea)", "role": "King of the Ryugu Kingdom", "location": "Ryugu Palace", "quest_hook": "Defend Gyoncorde Plaza & Receive the Royal Banquet Invitation"},
				{"name": "Princess Shirahoshi (Poseidon)", "role": "Mermaid Princess & Sovereign of the Sea Kings", "location": "Hard-Shell Tower / Sea Forest", "quest_hook": "Escort Shirahoshi to Queen Otohime's Grave in the Sea Forest"},
				{"name": "Fukaboshi, Ryuboshi & Manboshi", "role": "Three Princes of the Neptune Army", "location": "Coral Hill / Gyoncorde Plaza", "quest_hook": "Deliver Jinbe's Message & Protect the Kingdom"},
				{"name": "Jinbe ('Knight of the Sea')", "role": "Former Captain of the Sun Pirates & Master Helmsman", "location": "Sea Forest", "quest_hook": "Blood Transfusion of Reconciliation & Helmsman Recruitment"},
				{"name": "Madam Shyarly", "role": "Mako Shark Mermaid & Proprietor of the Mermaid Cafe", "location": "Mermaid Cafe", "quest_hook": "Prophecy of the Straw Hat Destruction of Fish-Man Island"},
				{"name": "Pappag, Camie & Hatchan", "role": "Criminal Designer, Mermaid Waitress & Takoyaki Chef", "location": "Gyoverly Hills / Coral Hill", "quest_hook": "Free Shopping Spree at the Criminal Store"},
				{"name": "Den", "role": "Shipwright & Sea Forest Researcher (Tom's Brother)", "location": "Sea Forest", "quest_hook": "Explain Sunlight Tree Eve & Treasure Tree Adam's Shared Roots"},
				{"name": "Minister of the Left & Minister of the Right", "role": "Royal Ministers of Ryugu Palace", "location": "Ryugu Palace", "quest_hook": "Award the Triple-Needle Log Pose & Explain Tamatebako Lore"},
				{"name": "Surume (The Kraken)", "role": "Tamed North Pole Giant Squid", "location": "Undersea Trench Entrance", "quest_hook": "Tame Surume to Tow the Ship Past Wadatsumi and the Flying Dutchman"}
			],
			"exploration_hooks": [
				"Dive 10,000 meters down the Downward Plume past the Kraken, Flying Dutchman (Vander Decken IX), and deep-sea volcanic vents into the glowing double bubble of Fish-Man Island.",
				"Explore the Sea Forest to read Joy Boy's 800-year-old Apology Poneglyph beside the colossal Ark Noah, then ride a Whale Shark stream up to the New World."
			]
		}
	}


# ==============================================================================
# 5. NEW WORLD ISLANDS (LON 180 DEG TO 360 DEG ALONG GRAND LINE GREAT CIRCLE)
# ==============================================================================
static func get_new_world_islands() -> Dictionary:
	return {
		"raijin_island": {
			"id": "raijin_island",
			"name": "Raijin Island",
			"sector": "New World (First Triple-Needle Candidate #1)",
			"lat_deg": 4.5,
			"lon_deg": 191.0,
			"alt_m": 0.0,
			"radius_m": 6500.0,
			"climate": "Perpetual Lightning-Rain Storm where Bolts Fall Like Raindrops",
			"log_pose_lock_seconds": 86400,
			"needle_risk_rating": 5, # Maximum needle jitter!
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["dressrosa"],
			"towns": [
				{"name": "Lightning Umbrella Pier", "description": "Charred stone harbor constantly struck by thousands of lightning bolts per minute."}
			],
			"marketplaces": [
				{
					"id": "raijin_umbrella_boat",
					"name": "Old Woman's Lightning-Umbrella Boat",
					"type": "Floating Insulation Stall",
					"proprietor": "Raijin Old Umbrella Peddler",
					"inventory": [
						{"item": "Raijin Lightning-Rod Umbrella", "price": 20000, "currency": CURRENCY_BELI, "effect": "Grants 100% immunity to Raijin Island's continuous lightning rain"}
					]
				}
			],
			"npcs": [
				{"name": "Old Umbrella Woman", "role": "Eccentric Peddler of Raijin Island", "location": "Coastal Rowboat", "quest_hook": "'Care to buy an umbrella?'"},
				{"name": "Urouge ('Mad Monk')", "role": "Visiting Supernova", "location": "Offshore Ship", "quest_hook": "Survive Landing on Raijin Island"}
			],
			"exploration_hooks": [
				"The most violent needle of the three starting New World routes; impossible for non-rubber/uninsulated crews to step ashore without buying the Old Woman's Lightning Umbrella."
			]
		},

		"risky_red_island": {
			"id": "risky_red_island",
			"name": "Risky Red Island",
			"sector": "New World (First Triple-Needle Candidate #2)",
			"lat_deg": -1.5,
			"lon_deg": 192.0,
			"alt_m": 0.0,
			"radius_m": 7000.0,
			"climate": "Scorched Crimson Volcanic Badlands",
			"log_pose_lock_seconds": 86400,
			"needle_risk_rating": 4,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["dressrosa"],
			"towns": [
				{"name": "Crimson Crater Outpost", "description": "Harsh volcanic port along the central New World route."}
			],
			"marketplaces": [],
			"npcs": [],
			"exploration_hooks": ["Middle-jitter candidate on the Triple-Needle Log Pose upon exiting Fish-Man Island."]
		},

		"mystoria_island": {
			"id": "mystoria_island",
			"name": "Mystoria Island",
			"sector": "New World (First Triple-Needle Candidate #3)",
			"lat_deg": -5.2,
			"lon_deg": 190.5,
			"alt_m": 0.0,
			"radius_m": 6200.0,
			"climate": "Mist-Shrouded Rocky Atoll",
			"log_pose_lock_seconds": 86400,
			"needle_risk_rating": 3,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["dressrosa"],
			"towns": [
				{"name": "Mystoria Anchorage", "description": "Calmest of the three initial Triple-Needle options."}
			],
			"marketplaces": [],
			"npcs": [],
			"exploration_hooks": ["Safest needle jitter of the three initial New World routes."]
		},

		"punk_hazard": {
			"id": "punk_hazard",
			"name": "Punk Hazard (Burning Lands & Ice Lands)",
			"sector": "New World (Unmapped Magnetic Anomaly)",
			"lat_deg": 2.1,
			"lon_deg": 198.0,
			"alt_m": 0.0,
			"radius_m": 13500.0,
			"climate": "Half-Magma Inferno & Half-Frozen Blizzard (Permanently Altered by the Akainu vs. Aokiji 10-Day Duel)",
			"log_pose_lock_seconds": 43200,
			"needle_risk_rating": 5,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["dressrosa"],
			"towns": [
				{"name": "Burning Lands & Vegapunk Lab #1 Ruins", "description": "Sea of fire and ruined facility patrolled by artificial dragons."},
				{"name": "Central Lake (Dual-Temperature Crater)", "description": "Impact epicenter of the 10-day Admiral duel connecting to the freezing ocean."},
				{"name": "Ice Lands & Caesar's Research Facility (Buildings A, B, C, D, R)", "description": "Frozen mountain range housing the Biscuit Room, SAD Production Tank, and Building R evacuation tunnel."}
			],
			"marketplaces": [
				{
					"id": "brownbeard_centaur_depot",
					"name": "Centaur Patrol & G-5 Salvage Locker (Building C)",
					"type": "Hazmat & Thermal Gear Depot",
					"proprietor": "Brownbeard's Centaur Survivors",
					"inventory": [
						{"item": "Shinokuni H2S Gas Mask", "price": 15000, "currency": CURRENCY_BELI, "effect": "Prevents petrification inside poison gas clouds"},
						{"item": "Punk Hazard Thermal Parka", "price": 8000, "currency": CURRENCY_BELI, "effect": "Immunity to Ice Lands frostbite"},
						{"item": "SAD Tank Chemical Sample", "price": 120000, "currency": CURRENCY_BELI, "effect": "Key quest item to dismantle Doflamingo's SMILE supply chain"}
					]
				}
			],
			"npcs": [
				{"name": "Trafalgar D. Water Law", "role": "Surgeon of Death (Ope Ope no Mi)", "location": "Facility Entrance", "quest_hook": "Form the Pirate Alliance to Topple Kaido & Destroy the SAD Tank"},
				{"name": "Kin'emon & Kozuki Momonosuke", "role": "Wano Samurai & Young Lord (Artificial Dragon Form)", "location": "Biscuit Room / Trash Dump", "quest_hook": "Reassemble Kin'emon's Torso/Legs/Head & Escort to Dressrosa/Zou"},
				{"name": "Smoker & Tashigi (G-5 Marines)", "role": "Vice Admiral & Captain of Marine Base G-5", "location": "Building R", "quest_hook": "Temporary Ceasefire to Rescue the Giantified Children"},
				{"name": "Caesar Clown & Monet", "role": "Mad Scientist (Gasu Gasu no Mi) & Harpy Assistant", "location": "Building R / SAD Room", "quest_hook": "Capture Caesar Clown for the Dressrosa Hostage Exchange"},
				{"name": "Brownbeard", "role": "Alligator-Centaur Patrol Commander", "location": "Central Lake", "quest_hook": "Mount Transport Across the Ice Lands"}
			],
			"exploration_hooks": [
				"Punk Hazard emits no magnetic field for a Log Pose; players must intercept an emergency Den Den Mushi distress call and cross the burning sea via the Central Lake."
			]
		},

		"dressrosa": {
			"id": "dressrosa",
			"name": "Dressrosa & Green Bit (Kingdom of Passion and Toys)",
			"sector": "New World",
			"lat_deg": -3.8,
			"lon_deg": 212.0,
			"alt_m": 0.0,
			"radius_m": 19000.0,
			"climate": "Mediterranean Sun-Drenched Island Ringed by Sheer Rocky Mesas, Sunflower Hills & Fighting Fish Seas",
			"log_pose_lock_seconds": 172800,
			"needle_risk_rating": 4,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["zou", "totto_land_whole_cake"],
			"towns": [
				{"name": "Acacia", "description": "Port city famous for tapas bistros, passionate flamenco dancers, and the colossal Corrida Colosseum."},
				{"name": "Sebio, Carta & Primula", "description": "Coastal and southern towns overlooking the rocky archipelago ring."},
				{"name": "Flower Hill & Soldier's Secret House", "description": "Elevated sunflower field hiding the tunnel to the Riku Royal Resistance."},
				{"name": "King's Plateau & Royal Palace", "description": "Central stepped mesa housing the palace, Suit Seats, Toy House, and deep Underground Trade Port."},
				{"name": "Green Bit & Tontatta Kingdom", "description": "Giant-plant forest island north of Dressrosa linked by an Iron Bridge over Fighting Fish waters, home to the subterranean Tontatta Dwarves."}
			],
			"marketplaces": [
				{
					"id": "acacia_tapas_bistro",
					"name": "Acacia Tapas & Fairy Wine Bistro",
					"type": "Mediterranean Restaurant & Roulette Hall",
					"proprietor": "Acacia Restaurateur",
					"inventory": [
						{"item": "Dressrosa Seafood Paella & Gazpacho", "price": 1800, "currency": CURRENCY_BELI, "effect": "+50 HP & +15 Agility"},
						{"item": "Fighting Fish Fin Steak", "price": 2400, "currency": CURRENCY_BELI, "effect": "+25 Attack Power for 15 minutes"},
						{"item": "Dressrosa Fairy Wine", "price": 3200, "currency": CURRENCY_BELI, "effect": "+20 Crew Morale"}
					]
				},
				{
					"id": "corrida_colosseum_armory",
					"name": "Corrida Colosseum Gladiator Registration & Armory",
					"type": "Arena Tournament & Combat Gear",
					"proprietor": "Gatz (Colosseum Announcer)",
					"inventory": [
						{"item": "Lucy Disguise Beard, Helmet & Cape", "price": 5000, "currency": CURRENCY_BELI, "effect": "Allows registration in Corrida Colosseum Blocks A-D"},
						{"item": "Kyros Tribute Bronze Greatsword", "price": 45000, "currency": CURRENCY_BELI, "effect": "Heavy two-handed gladiator blade (stays under the Colosseum weight limit)"}
					]
				},
				{
					"id": "tontatta_botanical_patch",
					"name": "Tontatta Kingdom Underground Botanical Exchange",
					"type": "Dwarven Super-Botany & Fairy Craft",
					"proprietor": "Gancho (Tontontatta Chief) & Bian",
					"inventory": [
						{"item": "Tontatta Super-Growth Fertilizer", "price": 20000, "currency": CURRENCY_BELI, "effect": "Doubles ship-deck Tangerine and Pop Green harvest speed"},
						{"item": "Yellow-Cab Beetle Aerial Charter", "price": 3000, "currency": CURRENCY_BELI, "effect": "Flies the player across the Iron Bridge over the Fighting Fish"}
					]
				}
			],
			"npcs": [
				{"name": "Kyros (Thunder Soldier)", "role": "Undefeated 3,000-Win Legend of the Colosseum & Father of Rebecca", "location": "Flower Hill / Royal Palace", "quest_hook": "Operation SOP: Knock Out Sugar to Restore Every Forgotten Toy in Dressrosa"},
				{"name": "King Riku Doldo III, Viola & Rebecca", "role": "Restored Royal Family of Dressrosa", "location": "King's Plateau", "quest_hook": "Shatter Doflamingo's Birdcage & Restore Peace"},
				{"name": "Leo, Kabu, Bian, Wicca & Princess Mansherry", "role": "Tontatta Corps (5th Division of the Straw Hat Grand Fleet)", "location": "Green Bit Tontatta Kingdom", "quest_hook": "Liberate the Dwarves from the SMILE Factory"},
				{"name": "Gatz", "role": "Announcer of the Corrida Colosseum", "location": "Corrida Colosseum", "quest_hook": "10-Minute Gear 4 Haki Recovery Countdown Broadcast"},
				{"name": "Cavendish, Bartolomeo, Sai, Ideo, Leo, Hajrudin & Orlumbus", "role": "7 Captains of the Straw Hat Grand Fleet (5,640 Members)", "location": "Eastern Port / Yonta Maria", "quest_hook": "Exchange Sons' Cups of Sake & Receive Grand Fleet Vivre Cards"},
				{"name": "Sabo, Koala & Hack", "role": "Revolutionary Army Chief of Staff & Operatives", "location": "Corrida Colosseum / Underground Port", "quest_hook": "Inherit Ace's Mera Mera no Mi & Uncover the Underground Weapons Port"}
			],
			"exploration_hooks": [
				"Cross the broken 200-year-old Iron Bridge to Green Bit while fending off horned Fighting Fish capable of capsizing iron battleships.",
				"Infiltrate the subterranean Trade Port and Toy House to execute Operation SOP and form the 5,640-strong Straw Hat Grand Fleet."
			]
		},

		"zou": {
			"id": "zou",
			"name": "Zou (Mokomo Dukedom atop Zunesha)",
			"sector": "New World (Mobile Phantom Island)",
			"lat_deg": 4.0,
			"lon_deg": 228.0,
			"alt_m": 20000.0, # Back of Zunesha towers 20,000m above the sea floor (~10,000m above Sea Level)!
			"radius_m": 15000.0,
			"climate": "Ancient Forest Civilization on the Back of the Walking 1,000-Year-Old Elephant Zunesha, Irrigated Twice Daily by Rain-ruption Floods",
			"log_pose_lock_seconds": 0, # Cannot be reached via Log Pose! Requires a Mink Vivre Card!
			"needle_risk_rating": 5,
			"currency": CURRENCY_BELI,
			"is_mobile_island": true,
			"has_road_poneglyph": true,
			"has_historical_poneglyph": false,
			"poneglyph_details": {
				"type": "Road Poneglyph #1 (Crimson Stone of Zou)",
				"location": "Secret Chamber Inside the Whale Tree (Protected by the Guardians & Kozuki Crest)",
				"spherical_coord_encoded": {"lat_deg": 18.5, "lon_deg": 240.0},
				"content": "Encodes Coordinate Point #1 of the 4-way geodesic intersection that reveals Laugh Tale."
			},
			"next_log_pose_targets": ["totto_land_whole_cake", "wano_country"],
			"towns": [
				{"name": "Right Belly Fortress", "description": "Sentinel gate and residential village of the Day-Ruler Inuarashi Musketeers."},
				{"name": "Kurau City (Claw City)", "description": "Ancient stone metropolis at the center of Mokomo Dukedom where the Great Bell rings at 6:00 AM and 6:00 PM for the Ruler Shift."},
				{"name": "Guardians' Forest", "description": "Nocturnal forest encampment of Master Nekomamushi and the Night Guardians."},
				{"name": "Whale Forest & Whale Tree", "description": "Sacred whale-shaped giant tree housing the secret chamber of the Kozuki Clan and Road Poneglyph #1."}
			],
			"marketplaces": [
				{
					"id": "claw_city_electro_bazaar",
					"name": "Kurau City Electro-Silk & Medicine Bazaar",
					"type": "Mink Electro Gear & Whale Sap Apothecary",
					"proprietor": "Dr. Miyagi, Tristan & Wanda",
					"inventory": [
						{"item": "Electro-Conductive Mink Gauntlets", "price": 65000, "currency": CURRENCY_BELI, "effect": "Channels static electricity into melee strikes (+35 Shock Damage)"},
						{"item": "Whale Tree Sap Poultice", "price": 18000, "currency": CURRENCY_BELI, "effect": "Rapidly heals crushed limbs and poison gas exposure"},
						{"item": "Rain-ruption Fresh Fish Barrel", "price": 1500, "currency": CURRENCY_BELI, "effect": "Freshly caught ocean fish sprayed onto Zou's back twice a day by Zunesha's trunk"}
					]
				}
			],
			"npcs": [
				{"name": "Duke Inuarashi (Dogstorm)", "role": "Ruler of the Day (6:00 AM - 6:00 PM) & Nine Red Scabbards Member", "location": "Right Belly Fortress / Whale Tree", "quest_hook": "Form the Ninja-Pirate-Mink-Samurai Alliance"},
				{"name": "Master Nekomamushi (Cat Viper)", "role": "Ruler of the Night (6:00 PM - 6:00 AM) & Guardian of the Whale Forest", "location": "Guardians' Forest / Whale Tree", "quest_hook": "Unseal the Whale Tree Chamber & Recruit Marco on Sphinx"},
				{"name": "Carrot, Wanda & Pedro", "role": "Ruler's Aide Musketeers & Captain of the Guardians", "location": "Kurau City / Whale Forest", "quest_hook": "Whole Cake Island Retrieval Team & Sulong Full-Moon Awakening"},
				{"name": "Raizo of the Mist", "role": "Wano Ninja Chained Inside the Whale Tree for His Own Protection", "location": "Whale Tree Secret Room", "quest_hook": "'Raizo-dono is Safe!' & Reveal Road Poneglyph #1"},
				{"name": "Sicilian, Concelot & Giovanni", "role": "Three Inuarashi Musketeers", "location": "Right Belly Fortress", "quest_hook": "Musketeer Sword Sparring"},
				{"name": "Bariete & Monjii", "role": "Gatekeeper Monkey Mink & Elder Historian", "location": "Entry Gate", "quest_hook": "Climb Zunesha's 20,000m Hind Leg"}
			],
			"exploration_hooks": [
				"Zunesha walks continuously along a spherical orbit in the New World; players must follow a Mink Vivre Card, scale the 20,000m-tall elephant leg, and enter the Whale Tree to take a rubbing of Road Poneglyph #1."
			]
		},

		"totto_land_whole_cake": {
			"id": "totto_land_whole_cake",
			"name": "Totto Land Archipelago (Whole Cake Island + 34 Food Islands)",
			"sector": "New World (Emperor Territory)",
			"lat_deg": -7.5,
			"lon_deg": 246.0,
			"alt_m": 0.0,
			"radius_m": 65000.0,
			"climate": "35-Island Confectionery Archipelago Monitored by Sea Slug Territorial Radars and Homie Weather",
			"log_pose_lock_seconds": 259200,
			"needle_risk_rating": 5,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": true,
			"has_historical_poneglyph": true,
			"poneglyph_details": {
				"type": "Road Poneglyph #2 + 2 Historical Poneglyphs",
				"location": "Whole Cake Chateau Treasure Room (Guarded by Charlotte Smoothie & Chess Soldiers)",
				"spherical_coord_encoded": {"lat_deg": -14.2, "lon_deg": 272.0},
				"content": "Encodes Coordinate Point #2 of the 4-way Laugh Tale triangulation (copied via Brook's Soul King skull compartment)."
			},
			"next_log_pose_targets": ["wano_country", "elbaf"],
			"towns": [
				{"name": "Sweet City (Whole Cake Island Capital)", "description": "Edible metropolis surrounding the towering Whole Cake Chateau."},
				{"name": "Seducing Woods & Cracker's Coast", "description": "Sentient Homie forest where trees, ground, and rivers shift to trap intruders indefinitely."},
				{"name": "Chocolat Town (Cacao Island)", "description": "Outer southwestern gateway island built entirely of milk, dark, and white chocolate."},
				{"name": "Hakuriki Town (Komugi Island)", "description": "Wheat and flour island governed by Minister of Flour Charlotte Katakuri."},
				{"name": "33 Additional Subsidiary Food Islands", "description": "Jam, Biscuits, Nuts, Cheese, Candy, 100%, Poripori, Yakigashi, Fruits, Potato, Noko, Margarine, Ice, Piepie, Loving, Kibo, Futoru, Liqueur, Pakupaku, Funwari, Tanega, Rokumitsu, Sanshoku, Torigara, Milenge, Crunchy, Topping, Mini, Hoya, Milky, Black, and Kinoko Islands (see full 35-island registry)."}
			],
			"marketplaces": [
				{
					"id": "chocolat_cafe_cacao",
					"name": "Caramel Cafe (Chocolat Town, Cacao Island)",
					"type": "Artisanal Chocolate Confectionery",
					"proprietor": "Charlotte Pudding & Nitro (Gelatin Homie) / Rabiyan (Carpet Homie)",
					"inventory": [
						{"item": "Pudding's Melt-in-Your-Mouth Chocolate Brick", "price": 1500, "currency": CURRENCY_BELI, "effect": "+60 HP & Stamina"},
						{"item": "Simsim Whip & Chiffon Cake Slice (Wedding Cake Replica)", "price": 50000, "currency": CURRENCY_BELI, "effect": "Pacifies Big Mom's Hunger Pangs and grants +100% Stamina Regen"},
						{"item": "Cacao Architecture Permit", "price": 2000, "currency": CURRENCY_BELI, "effect": "Allows eating chocolate walls in Chocolat Town without arrest (excluding roofs and structural pillars)"}
					]
				},
				{
					"id": "brulee_mirror_network",
					"name": "Mirro-World Portal Network (Seducing Woods House)",
					"type": "Dimensional Fast-Travel Network Across All 35 Totto Land Islands",
					"proprietor": "Charlotte Brulee (Captured / Ally)",
					"inventory": [
						{"item": "Pocket Hand-Mirror Portal Key", "price": 35000, "currency": CURRENCY_BELI, "effect": "Enables instant teleportation between any two islands in Totto Land via the Mirro-World"}
					]
				}
			],
			"npcs": [
				{"name": "Charlotte Linlin (Big Mom)", "role": "Queen of Totto Land (Soru Soru no Mi)", "location": "Whole Cake Chateau Rooftop", "quest_hook": "Survive the Tea Party From Hell & Bake the Replacement Wedding Cake"},
				{"name": "Charlotte Katakuri", "role": "Minister of Flour & Sweet Commander (Mochi Mochi no Mi, 1,057,000,000B)", "location": "Mirro-World / Komugi Island", "quest_hook": "Duel in the Mirro-World to Unlock Future Sight (Advanced Kenbunshoku Haki)"},
				{"name": "Charlotte Smoothie & Charlotte Cracker", "role": "Minister of Juice & Minister of Biscuits (Sweet Commanders)", "location": "Treasure Room / Seducing Woods", "quest_hook": "Infiltrate the Treasure Room for Road Poneglyph #2"},
				{"name": "Charlotte Perospero, Oven, Daifuku, Mont-d'Or & Brulee", "role": "Leading Ministers of Totto Land", "location": "Whole Cake Island / Cacao Island", "quest_hook": "Break the Cacao Island Naval Blockade"},
				{"name": "Charlotte Pudding & Charlotte Chiffon", "role": "Master Chocolatier & Minister of Chiffon (Wife of Capone Bege)", "location": "Cacao Island / Nostra Castello", "quest_hook": "Bake the Ultimate Wedding Cake with Sanji & the WCI 31 Chefs"},
				{"name": "Streusen", "role": "Executive Chef of the Big Mom Pirates (Kuku Kuku no Mi)", "location": "Chateau Kitchen", "quest_hook": "Master Confectionery Recipes"},
				{"name": "Pound & Kingbaum", "role": "25th Ex-Husband of Big Mom & Master of the Seducing Woods", "location": "Seducing Woods", "quest_hook": "Navigate the Shifting Homie Forest"}
			],
			"exploration_hooks": [
				"Sail through the 34 ingredient-themed outer islands while evading territorial Sea Slugs (or using Pudding's route map), navigate the Seducing Woods using Lola's Vivre Card, and steal a rubbing of Road Poneglyph #2 from the Chateau Treasure Room."
			]
		},

		"wano_country": {
			"id": "wano_country",
			"name": "Wano Country & Onigashima (Land of Samurai)",
			"sector": "New World (Fortress Waterfall Nation)",
			"lat_deg": 6.8,
			"lon_deg": 278.0,
			"alt_m": 2500.0, # Mainland Wano sits atop an elevated freshwater plateau surrounded by giant waterfalls!
			"old_wano_abyss_alt_m": -4000.0, # Sunken Old Wano & Pluton chamber beneath Mount Fuji
			"radius_m": 42000.0,
			"climate": "Six-Season Isolationist Archipelago Atop Giant Waterfalls (Spring, Autumn, Winter, Wasteland & Industrial Zones)",
			"log_pose_lock_seconds": 432000, # 5 Days
			"needle_risk_rating": 5,
			"currency": CURRENCY_RYO_SILVER, # Also uses Gold Ryo and Platinum Ryo internally
			"has_road_poneglyph": true,
			"has_historical_poneglyph": true,
			"poneglyph_details": {
				"type": "Road Poneglyph #3 + Kokeshi Doll Basement Poneglyph",
				"location": "Deep Underwater Cavern of Old Wano beneath Mount Fuji (Accessed via the Secret Staircase behind the Kokeshi Doll Room inFlower Capital Castle; rests directly above Ancient Weapon Pluton)",
				"spherical_coord_encoded": {"lat_deg": 11.4, "lon_deg": 318.0},
				"content": "Encodes Coordinate Point #3 of the 4-way Laugh Tale triangulation, guarded by Kozuki Sukiyaki."
			},
			"next_log_pose_targets": ["egghead_island", "elbaf", "winner_island"],
			"towns": [
				{"name": "Flower Capital (Hana no Miyako)", "description": "Central spring-climate capital featuring Shogun's Castle, Rasetsu Town prison, Ebisu Town on the outskirts, and the Fire Festival lantern sky."},
				{"name": "Kuri (Amigasa Village, Okobore Town, Bakura Town & Oden Castle Ruins)", "description": "Southern province with Kuri Beach, Hitetsu's Amigasa bamboo village, Tsuru's Okobore tea house, and Atamayama bandit peak."},
				{"name": "Udon (Prisoner Excavation Mines & Tokage Port)", "description": "Rocky cactus quarry where Hyogoro teaches Ryuo (Advanced Armament Haki) and 4,200 samurai rally at Tokage Port."},
				{"name": "Ringo (Northern Cemetery & Bandit's Bridge)", "description": "Perpetual snow province where samurai are buried with their swords, guarded by Kawamatsu and Onimaru."},
				{"name": "Hakumai (Habu Port & Mogura Port)", "description": "Autumn-foliage eastern province with the secret gondola lift inside Mogura Port leading up the waterfall."},
				{"name": "Kibi", "description": "Western arid wasteland connecting Kuri, Udon, and the Flower Capital."},
				{"name": "Onigashima (Skull Dome Island)", "description": "Horned giant skull island off the southern coast of Kuri, lifted into the sky via Flame Clouds during the Fire Festival Raid."}
			],
			"marketplaces": [
				{
					"id": "amigasa_hitetsu_forge",
					"name": "Tenguyama Hitetsu's Amigasa Sword & Seastone Forge (Kuri)",
					"type": "Master Meito Katana & Seastone Artisan Workshop",
					"proprietor": "Tenguyama Hitetsu (Kozuki Sukiyaki)",
					"inventory": [
						{"item": "Wano Seastone Nails (x10)", "price": 50, "currency": CURRENCY_RYO_SILVER, "beli_equivalent": 25000, "effect": "Ranged projectiles that nullify Devil Fruit abilities on hit"},
						{"item": "Kitetsu Maintenance & Meito Scabbard Refit", "price": 20, "currency": CURRENCY_RYO_GOLD, "beli_equivalent": 200000, "effect": "+15% Sword Slash Range & Haki Flow Efficiency"},
						{"item": "Amigasa Woven Straw Hat", "price": 2, "currency": CURRENCY_RYO_SILVER, "beli_equivalent": 1000, "effect": "Traditional Wano rain & sun protection"}
					]
				},
				{
					"id": "tsurujo_okobore_teahouse",
					"name": "O-Tsuru's Okobore Tea House & O-Sobamask Stall",
					"type": "Wano Culinary & Herbal Remedy Tavern",
					"proprietor": "Tsurujo (Kin'emon's Wife) & Sangoro (Sanji)",
					"inventory": [
						{"item": "Sangoro's Secret Soba Noodles", "price": 1, "currency": CURRENCY_RYO_SILVER, "beli_equivalent": 500, "effect": "+65 HP & +20 Movement Speed"},
						{"item": "O-Tsuru's Bitter Jagan Grass Decoction", "price": 3, "currency": CURRENCY_RYO_SILVER, "beli_equivalent": 1500, "effect": "Purges polluted factory river toxins"},
						{"item": "Udon Sweet Red-Bean Shiruko Pot", "price": 5, "currency": CURRENCY_RYO_SILVER, "beli_equivalent": 2500, "effect": "Full Crew Stamina & Morale Restore"}
					]
				}
			],
			"npcs": [
				{"name": "Shogun Kozuki Momonosuke & Kozuki Hiyori", "role": "Shogun & Princess of Wano Country", "location": "Flower Capital Castle", "quest_hook": "Protect Wano's Borders & Guard Pluton Until the Time to Open the Land Arrives"},
				{"name": "Kozuki Sukiyaki (Tenguyama Hitetsu)", "role": "Former Shogun, Master Swordsmith & Keeper of the Poneglyphs", "location": "Amigasa Village / Old Wano Underground Cavern", "quest_hook": "Descend the Secret Staircase to Read Road Poneglyph #3 & View Sunken Old Wano"},
				{"name": "Yamato (Son of Kaido / 'Kozuki Oden')", "role": "Guardian Deity of Wano (Inu Inu no Mi, Model: Okuchi no Makami)", "location": "Onigashima / Wano Tour", "quest_hook": "Oden's Logbook Lore & Rooftop Conqueror's Coating Sparring"},
				{"name": "Kin'emon, Denjiro, Kawamatsu, Ashura Doji, Kikunojo, Raizo & Shinobu", "role": "The Nine Red Scabbards", "location": "Across Wano's 6 Regions", "quest_hook": "Fire Festival Raid on Onigashima"},
				{"name": "Hyogoro the Flower", "role": "Legendary Yakuza Boss of Wano & Ryuo Master", "location": "Udon Sumo Ring / Flower Capital", "quest_hook": "Master Internal Destruction & Emission Armament Haki (Ryuo)"},
				{"name": "Tama (O-Tama), Toko (O-Toko) & Komachiyo", "role": "Kibi Dango Kunoichi Apprentice, Kamuro & Komainu Mount", "location": "Amigasa Village / Flower Capital", "quest_hook": "Tame Gifters & Baboon Mounts with Kibi Dango"}
			],
			"exploration_hooks": [
				"Hitch a ride on giant Carp swimming up the vertical waterfall into the whirlpool atop Wano's outer wall (or take the secret gondola lift inside Mogura Port).",
				"Descend the hidden staircase beneath the Flower Capital Castle past the Kokeshi doll vault to view the submerged ruins of Old Wano through glass walls and claim Road Poneglyph #3."
			]
		},

		"egghead_island": {
			"id": "egghead_island",
			"name": "Egghead (Future Island / 500 Years in the Future)",
			"sector": "New World (Southeast of Wano)",
			"lat_deg": -5.4,
			"lon_deg": 298.0,
			"alt_m": 0.0,
			"labophase_alt_m": 3500.0, # Island Cloud Labophase floating above the giant Egg dome!
			"radius_m": 11000.0,
			"climate": "Winter Sea Surrounded by Mechanical Sea Beast Weapons, Heated Inside by an Island-Wide Air Conditioner",
			"log_pose_lock_seconds": 86400, # 1 Day
			"needle_risk_rating": 5,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["elbaf"],
			"towns": [
				{"name": "Fabriophase (Lower Futuristic City)", "description": "Neon holographic metropolis where researchers live and work alongside giant mechs and automated food synthesizers."},
				{"name": "Labophase (Upper Cloud Stratum, +3,500m)", "description": "Encrypted laboratory complex built on Artificial Island Clouds inside the Frontier Dome laser grid, crowned by the giant Egg containing Punk Records (Vegapunk's shared brain)."}
			],
			"marketplaces": [
				{
					"id": "vegapunk_auto_dispenser",
					"name": "Vegapunk Automated Food & Future-Wear Dispenser (Fabriophase)",
					"type": "Instant Matter-Synthesizer & Anti-Gravity Gear Foundry",
					"proprietor": "Vegapunk Lilith, Atlas & Edison",
					"inventory": [
						{"item": "DOM Shoes (Anti-Gravity Electromagnetic Hover Boots)", "price": 120000, "currency": CURRENCY_BELI, "effect": "Allows walking and hovering in mid-air inside Egghead and on ship decks"},
						{"item": "Light-Pressure Gloves (Photonic Matter Gloves)", "price": 95000, "currency": CURRENCY_BELI, "effect": "Allows physically punching holograms and light-based Logia attacks"},
						{"item": "Mark III Bubble Shield", "price": 75000, "currency": CURRENCY_BELI, "effect": "Deflects heavy cannon fire and laser beams"},
						{"item": "60-Second Synthesized Gourmet Burger & Cola", "price": 500, "currency": CURRENCY_BELI, "effect": "Instant full meal synthesized from raw nutrient cartridges"}
					]
				}
			],
			"npcs": [
				{"name": "Dr. Vegapunk (Stella)", "role": "World's Greatest Genius Scientist (Nomi Nomi no Mi)", "location": "Labophase / Scrapheap", "quest_hook": "Protect the Global Broadcast of the Sinking World (+200m Sea Level Rise)"},
				{"name": "Shaka, Lilith, Edison, Pythagoras, Atlas & York", "role": "The Six Satellites of Vegapunk", "location": "Labophase Control Room", "quest_hook": "Solve the Frontier Dome Mystery & Escape to Elbaf"},
				{"name": "Sentomaru", "role": "Captain of the Marine Science Unit", "location": "Fabriophase", "quest_hook": "Command the 50 Mark III Pacifista"},
				{"name": "Jewelry Bonney & Bartholomew Kuma", "role": "Captain of the Bonney Pirates & Former Revolutionary Commander", "location": "Memory Bubble Room / Fabriophase", "quest_hook": "Experience Kuma's Paw-Shaped Memory Bubble"},
				{"name": "Emet (The Iron Giant)", "role": "900-Year-Old Ancient Robot That Attacked Mary Geoise 200 Years Ago", "location": "Scrapheap", "quest_hook": "Awaken to the Drums of Liberation & Unleash Joy Boy's Stored Haki Knot"}
			],
			"exploration_hooks": [
				"Ride the Vegaforce-01 and Vacuum Rocket up to the Island Cloud Labophase, equip DOM Shoes, and witness Vegapunk's global broadcast revealing that the ancient world sank 200 meters beneath the sea."
			]
		},

		"elbaf": {
			"id": "elbaf",
			"name": "Elbaf / Elbaph (Warland — Kingdom of Giants)",
			"sector": "New World (Northeast of Egghead)",
			"lat_deg": 8.5,
			"lon_deg": 318.0,
			"alt_m": 0.0,
			"sun_world_alt_m": 4500.0,
			"heaven_world_alt_m": 9500.0,
			"radius_m": 55000.0,
			"climate": "Colossal Three-Realm Kingdom Built Upon the Primordial Treasure Tree Adam (Yggdrasil)",
			"log_pose_lock_seconds": 345600,
			"needle_risk_rating": 5,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": true,
			"has_historical_poneglyph": false,
			"poneglyph_details": {
				"type": "Road Poneglyph #4 (The Final Flame-Scarred Rubbing / Elbaf Sanctuary)",
				"location": "Sanctuary of the Sun & Owl's Library Archive on Elbaf (Linked to the 'Man Marked by Flames' and his pitch-black whirlpool ship)",
				"spherical_coord_encoded": {"lat_deg": -18.5, "lon_deg": 352.0},
				"content": "Encodes the 4th and final spherical coordinate required to triangulate the exact geodesic intersection of Laugh Tale."
			},
			"next_log_pose_targets": ["lodestar_island"],
			"towns": [
				{"name": "The Underworld (Base Root Layer, 0m)", "description": "Frozen, beast-ridden root abyss where Prince Loki is chained with Seastone to the trunk of Treasure Tree Adam."},
				{"name": "The Sun World (Mid-Canopy Layer, +4,500m)", "description": "Main giant civilization built on colossal tree branches and Island Clouds, featuring the Western Village, Aurust Castle, Warrior's Spring, Walrus School, and the Owl's Library."},
				{"name": "The Heaven World (Crown Layer, +9,500m)", "description": "Highest sacred canopy of the giant world tree."}
			],
			"marketplaces": [
				{
					"id": "western_village_mead_hall",
					"name": "Western Village Giant Mead Hall & Sun-Stone Smithy",
					"type": "Elbaf Feast Hall & Giant Weaponry",
					"proprietor": "Brogy, Dorry, Oimo & Kashii",
					"inventory": [
						{"item": "Elbaf Green Fairy Absinthe (Hallucinogenic Mead)", "price": 5000, "currency": CURRENCY_BELI, "effect": "+50 Berserker Attack Power (Causes vivid illusions)"},
						{"item": "Painter's Sun-Stone Prism (Rainbow Boat Maker)", "price": 80000, "currency": CURRENCY_BELI, "effect": "Draws solid sail-able rainbow bridges in the sky"},
						{"item": "Giant-Scale Hakoku Spear Manual", "price": 250000, "currency": CURRENCY_BELI, "effect": "Unlocks flying shockwave slash techniques"}
					]
				},
				{
					"id": "owls_library_ohara_archive",
					"name": "The Owl's Library (Warrior's Spring, Sun World)",
					"type": "Ancient History & Poneglyph Translation Sanctuary",
					"proprietor": "Jaguar D. Saul & Biblo (Giant Owl who Enlarges Books)",
					"inventory": [
						{"item": "Complete Ohara Lake Book Archive Access", "price": 0, "currency": CURRENCY_BELI, "effect": "Deciphers all Historical & Road Poneglyph rubbings collected across the globe"},
						{"item": "Harley Sacred Text Rubbing", "price": 0, "currency": CURRENCY_BELI, "effect": "Reveals Elbaf's Three Worlds mythology of the Sun God Nika"}
					]
				}
			],
			"npcs": [
				{"name": "Jaguar D. Saul", "role": "History Teacher at Walrus School & Saviour of Ohara's Books", "location": "Warrior's Spring / Owl's Library", "quest_hook": "Reunite Nico Robin with Saul ('Dereshishishi!') & Study Ohara's Rescued Library"},
				{"name": "Dorry & Brogy", "role": "Co-Captains of the Giant Warrior Pirates", "location": "Western Village", "quest_hook": "Celebrate the Great Feast of Elbaf"},
				{"name": "Hajrudin, Gerd, Goldberg, Stansen & Road", "role": "New Giant Warrior Pirates (6th Division of the Straw Hat Grand Fleet)", "location": "Sun World / Great Eirik", "quest_hook": "Ascend the Rainbow Bridge into the Sun World"},
				{"name": "Prince Loki", "role": "Accursed Prince of Elbaf Chained in the Underworld", "location": "Underworld Trunk", "quest_hook": "Confront Loki & Uncover the Truth of King Harald"},
				{"name": "Jarul (Mountain Beard)", "role": "408-Year-Old Oldest Living Giant Warrior (With a Sword Through His Helmet)", "location": "Western Village", "quest_hook": "Lore of the Winter Solstice Festival & Ancient Giant History"}
			],
			"exploration_hooks": [
				"Sail up a solid Rainbow painted across the sky using an Elbaf Sun-Stone alongside the Great Eirik to reach the Sun World at +4,500m.",
				"Enter the Owl's Library where Biblo enlarges human-sized books rescued from Ohara's lake, and unlock the 4th Road Poneglyph coordinate to triangulate Laugh Tale."
			]
		},

		"hachinosu": {
			"id": "hachinosu",
			"name": "Hachinosu (Fullalead / Pirate Island)",
			"sector": "New World (Lawless Emperor Stronghold)",
			"lat_deg": -9.2,
			"lon_deg": 305.0,
			"alt_m": 0.0,
			"radius_m": 12500.0,
			"climate": "Arid Outlaw Island Dominated by a Colossal Beehive-Shaped Skull Rock",
			"log_pose_lock_seconds": 86400,
			"needle_risk_rating": 5,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["lodestar_island"],
			"towns": [
				{"name": "Skull Dome Plaza & Outlaw Port", "description": "Historic birthplace of the Rocks Pirates and Davy Back Fight, now controlled by Blackbeard and merged with Avalo Pizarro's Shima Shima no Mi."}
			],
			"marketplaces": [
				{
					"id": "hachinosu_cross_bounty_board",
					"name": "Fullalead Black Market & Cross Guild Marine Bounty Exchange",
					"type": "Outlaw Armory & Devil Fruit Hunter Broker",
					"proprietor": "Hachinosu Underworld Broker",
					"inventory": [
						{"item": "Blackbeard Armada Rum Barrel", "price": 1200, "currency": CURRENCY_BELI, "effect": "+30 Attack, -10 Defense"},
						{"item": "Marine Crown Bounty Poster", "price": 10000, "currency": CURRENCY_BELI, "effect": "Lists Cross Guild star-bounties on Marine officers"}
					]
				}
			],
			"npcs": [
				{"name": "Marshall D. Teach (Blackbeard) & Ten Titanic Captains", "role": "Emperor of the Sea", "location": "Skull Fortress", "quest_hook": "Survive the Beehive Raid"},
				{"name": "Koby, Helmeppo, Prince Grus, Kujaku & Hibari (SWORD)", "role": "Marine Special Secret Force Operatives", "location": "Prison / Harbor", "quest_hook": "Honesty Impact Breakout alongside Vice Admiral Garp"}
			],
			"exploration_hooks": [
				"The entire central skull mountain is physically fused with Avalo Pizarro (Shima Shima no Mi), causing buildings and cliff walls to move dynamically during combat."
			]
		},

		"sphinx": {
			"id": "sphinx",
			"name": "Sphinx (Whitebeard's Homeland)",
			"sector": "New World",
			"lat_deg": 3.2,
			"lon_deg": 262.0,
			"alt_m": 0.0,
			"radius_m": 8000.0,
			"climate": "Peaceful Mountain Sanctuary Hidden Behind a Giant Waterfall",
			"log_pose_lock_seconds": 86400,
			"needle_risk_rating": 2,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["wano_country"],
			"towns": [
				{"name": "Hidden Waterfall Village & Whitebeard/Ace Memorial", "description": "Pastoral village secretly funded by all of Edward Newgate's lifetime pirate treasure, protected by Dr. Marco."}
			],
			"marketplaces": [
				{
					"id": "marco_phoenix_clinic",
					"name": "Dr. Marco's Phoenix Flame Clinic",
					"type": "Regenerative Healing Sanctuary",
					"proprietor": "Marco the Phoenix",
					"inventory": [
						{"item": "Blue Flame Regeneration Salve", "price": 25000, "currency": CURRENCY_BELI, "effect": "Restores 100% Crew HP and clears all status ailments"}
					]
				}
			],
			"npcs": [
				{"name": "Marco the Phoenix", "role": "Former 1st Division Commander of the Whitebeard Pirates & Village Doctor", "location": "Hidden Waterfall Clinic", "quest_hook": "Pay Respects at Whitebeard & Ace's Graves"}
			],
			"exploration_hooks": [
				"Sail through the hidden cavern behind the coastal waterfall to discover the peaceful village and the twin graves of Edward Newgate and Portgas D. Ace."
			]
		},

		"karai_bari_island": {
			"id": "karai_bari_island",
			"name": "Karai Bari Island (Cross Guild HQ)",
			"sector": "New World",
			"lat_deg": -2.2,
			"lon_deg": 255.0,
			"alt_m": 0.0,
			"radius_m": 7000.0,
			"climate": "Circus-Tent Fortress Island",
			"log_pose_lock_seconds": 86400,
			"needle_risk_rating": 4,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": false,
			"next_log_pose_targets": ["wano_country"],
			"towns": [
				{"name": "Buggy's Delivery & Cross Guild Big Top", "description": "Mercenary circus metropolis commanded by Buggy, Dracule Mihawk, and Sir Crocodile."}
			],
			"marketplaces": [
				{
					"id": "cross_guild_mercenary_exchange",
					"name": "Cross Guild Mercenary & Muggy Ball Commissary",
					"type": "Outlaw Munitions & Marine Bounty Desk",
					"proprietor": "Cabaji, Mohji & Alvida",
					"inventory": [
						{"item": "Compact Muggy Ball (x3)", "price": 45000, "currency": CURRENCY_BELI, "effect": "Town-shattering micro-explosive"},
						{"item": "Cross Guild Marine Star Ledger", "price": 5000, "currency": CURRENCY_BELI, "effect": "Allows turning in defeated Marine ships for Cross Guild Crown rewards"}
					]
				}
			],
			"npcs": [
				{"name": "Buggy the Star Clown, Dracule Mihawk & Sir Crocodile", "role": "Leadership of Cross Guild", "location": "Big Top Castle", "quest_hook": "Join the Race for the One Piece"}
			],
			"exploration_hooks": [
				"Witness the construction of Cross Guild's figurehead ship and claim bounties on corrupt naval convoys."
			]
		},

		"lodestar_island": {
			"id": "lodestar_island",
			"name": "Lodestar Island (Road Star Island)",
			"sector": "New World (Final Log Pose Convergence)",
			"lat_deg": 0.0,
			"lon_deg": 342.0,
			"alt_m": 0.0,
			"radius_m": 9000.0,
			"climate": "Magnetically Charged Horizon Island Where All 7 Grand Line Routes Converge",
			"log_pose_lock_seconds": 0, # The Log Pose spins endlessly here and never points further!
			"needle_risk_rating": 5,
			"currency": CURRENCY_BELI,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": true,
			"poneglyph_details": {
				"type": "Convergence Inscription",
				"location": "Lodestar Magnetic Observatory Summit",
				"content": "Reveals to crews who did not meet Crocus/Inuarashi earlier that Lodestar is NOT the true final island; the Log Pose needles spin endlessly here because the true final island can only be reached by triangulating the 4 crimson Road Poneglyphs."
			},
			"next_log_pose_targets": [],
			"towns": [
				{"name": "Roger's Landing & Magnetic Observatory Ruins", "description": "Desolate wind-swept promontory reached by Gol D. Roger 39 years ago before he restarted his voyage to read the Road Poneglyphs."}
			],
			"marketplaces": [],
			"npcs": [
				{"name": "Ancient Magnetic Beacon Keeper", "role": "Hermit Cartographer of the End of the Log", "location": "Summit Observatory", "quest_hook": "Verify All 4 Road Poneglyph Rubbings to Unlock the Geodesic Path to Laugh Tale"}
			],
			"exploration_hooks": [
				"Upon docking at Lodestar, all 3 needles of the Triple-Needle Log Pose spin in chaotic circles, proving that another unmapped island lies beyond the magnetic grid."
			]
		},

		"laugh_tale": {
			"id": "laugh_tale",
			"name": "Laugh Tale (The Final Island)",
			"sector": "New World (4-Road-Poneglyph Geodesic Intersection)",
			"lat_deg": 0.0,
			"lon_deg": 356.0,
			"alt_m": 0.0,
			"radius_m": 16000.0,
			"climate": "Unmapped Mythical Horizon Visible Only After Triangulating All 4 Road Poneglyphs",
			"log_pose_lock_seconds": 0,
			"needle_risk_rating": 5,
			"currency": CURRENCY_BELI,
			"requires_four_road_poneglyphs": true,
			"has_road_poneglyph": false,
			"has_historical_poneglyph": true,
			"poneglyph_details": {
				"type": "The Rio Poneglyph (True History of the Void Century)",
				"location": "Sanctum of Joy Boy at the Heart of Laugh Tale",
				"content": "Unites all 9 Historical Poneglyph texts to reveal the complete 100-Year Void Century, the Ancient Kingdom, the Will of D., the three Ancient Weapons (Pluton, Poseidon, Uranus), and the treasure left behind by Joy Boy that made Gol D. Roger and his crew laugh."
			},
			"next_log_pose_targets": [],
			"towns": [
				{"name": "Sanctum of Joy Boy & Roger's Anchor Bay", "description": "The legendary final shore reached only by Joy Boy (800 years ago) and the Roger Pirates (25 years ago)."}
			],
			"marketplaces": [],
			"npcs": [
				{"name": "Echo of the Void Century", "role": "Custodian of the Rio Poneglyph", "location": "Sanctum of Joy Boy", "quest_hook": "'He Laughed.' — Complete the Planetary Odyssey & Trigger the Dawn of the World"}
			],
			"exploration_hooks": [
				"Hidden by permanent planetary spatial fog until the player's Archaeologist translates all 4 Road Poneglyphs (Zou, Whole Cake Island, Wano, Elbaf) and draws two intersecting great-circle arcs across the 3D globe."
			]
		}
	}


# ==============================================================================
# 6. SABAODY ARCHIPELAGO COMPLETE 79 GROVES DIRECTORY
# ==============================================================================
static func get_sabaody_groves_directory() -> Dictionary:
	return {
		"total_groves": 79,
		"tree_species": "Yarukiman Mangrove (Giant Soap-Resin Trees rooted directly on the ocean floor)",
		"zones": [
			{
				"grove_range": [1, 29],
				"zone_name": "Lawless Zone (Pirate, Bounty Hunter & Underworld Groves)",
				"marine_patrol": "Low / Restricted",
				"notable_groves": {
					1: {"name": "Grove 1 — Former Human Auctioning House (Now Burned / Lawless Plaza)", "npcs": ["Disco (Ruined)", "Silvers Rayleigh", "Hatchan", "Camie"]},
					12: {"name": "Grove 12 — Bonney Pirates & Supernova Restaurant District", "npcs": ["Jewelry Bonney", "Capone Bege"]},
					13: {"name": "Grove 13 — Shakky's Rip-Off Bar (100 Steps from Base)", "npcs": ["Shakuyaku (Shakky)", "Silvers Rayleigh"]},
					17: {"name": "Grove 17 — Hidden Anchorage & Timeskip Reunion Rally Point", "npcs": ["Duval", "Bartholomew Kuma"]},
					21: {"name": "Grove 21 — Bounty Hunter Ambush Bridge", "npcs": ["Scratchmen Apoo", "Basil Hawkins", "X Drake", "Urouge"]},
					24: {"name": "Grove 24 — Lawless Plaza & Pacifista Battleground", "npcs": ["Trafalgar Law", "Eustass Kid"]},
					27: {"name": "Grove 27 — Fake Straw Hat Recruiting Tavern", "npcs": ["Demaro Black"]}
				}
			},
			{
				"grove_range": [30, 39],
				"zone_name": "Sabaody Park (Amusement Park & Concert Dome)",
				"marine_patrol": "Moderate",
				"notable_groves": {
					32: {"name": "Grove 32 — Sabaody Park Bubble Ferris Wheel & Rollercoaster", "npcs": ["Camie", "Pappag"]},
					33: {"name": "Grove 33 — Sabaody Dome (Soul King Brook Final Encore Concert)", "npcs": ["Brook (Soul King)", "Longarm Managers"]},
					35: {"name": "Grove 35 — Bon Chari Rental Station #1", "npcs": ["Park Attendant"]}
				}
			},
			{
				"grove_range": [40, 49],
				"zone_name": "Tourist & Souvenir Shopping Area",
				"marine_patrol": "Moderate",
				"notable_groves": {
					41: {"name": "Grove 41 — Main Bubble-Pack & Souvenir Boulevard", "npcs": ["Sabaody Merchants"]},
					42: {"name": "Grove 42 — Coastal Pier & Thousand Sunny Departure Bay", "npcs": ["Heracles", "Perona", "Boa Hancock Escort"]},
					44: {"name": "Grove 44 — Outer Mangrove Pier (Nearest to Duval's Flying Fish Base)", "npcs": ["Rosy Life Riders"]},
					46: {"name": "Grove 46 — Fake Straw Hat Rally Grove", "npcs": ["Sentomaru", "Pacifista PX-5", "Pacifista PX-7"]}
				}
			},
			{
				"grove_range": [50, 59],
				"zone_name": "Shipyard & Yarukiman Resin Coating District",
				"marine_patrol": "Moderate",
				"notable_groves": {
					53: {"name": "Grove 53 — Master Coating Artisan Drydocks", "npcs": ["Silvers Rayleigh", "Sabaody Shipwrights"]}
				}
			},
			{
				"grove_range": [60, 69],
				"zone_name": "Marine Base Garrison (G-66 / Former HQ Annex)",
				"marine_patrol": "Maximum",
				"notable_groves": {
					66: {"name": "Grove 66 — Sabaody Marine Garrison Command", "npcs": ["Marine Rear Admiral"]}
				}
			},
			{
				"grove_range": [70, 79],
				"zone_name": "Hotel Town & Peaceful Residential District",
				"marine_patrol": "High",
				"notable_groves": {
					74: {"name": "Grove 74 — Grand Bubble Resort Hotel", "npcs": ["Weatheria Scholars", "Traveling Merchants"]}
				}
			}
		]
	}


# ==============================================================================
# 7. TOTTO LAND COMPLETE 35-ISLAND ARCHIPELAGO DIRECTORY
# ==============================================================================
static func get_totto_land_archipelago() -> Dictionary:
	return {
		"capital_island": {
			"number": 0,
			"name": "Whole Cake Island",
			"town": "Sweet City & Whole Cake Chateau",
			"theme": "Wedding Cake",
			"governor": "Queen Charlotte Linlin (Big Mom) & Head Chef Streusen"
		},
		"subsidiary_islands": [
			{"number": 1, "name": "Cacao Island", "town": "Chocolat Town", "theme": "Chocolate", "minister": "Charlotte Lola (Formerly) / Charlotte Pudding"},
			{"number": 2, "name": "Jam Island", "town": "Swirly Town", "theme": "Jam", "minister": "Charlotte Dacquoise (Minister of Jam)"},
			{"number": 3, "name": "Biscuits Island", "town": "Biscuits Town", "theme": "Biscuits", "minister": "Charlotte Cracker (Minister of Biscuits)"},
			{"number": 4, "name": "Nuts Island", "town": "Peanuts Town", "theme": "Nuts", "minister": "Charlotte Amande (Minister of Nuts)"},
			{"number": 5, "name": "Cheese Island", "town": "Cheddar Town", "theme": "Cheese", "minister": "Charlotte Mont-d'Or (Minister of Cheese)"},
			{"number": 6, "name": "Candy Island", "town": "Pero Town", "theme": "Candy", "minister": "Charlotte Perospero (Minister of Candy)"},
			{"number": 7, "name": "Komugi Island", "town": "Hakuriki Town", "theme": "Wheat Flour", "minister": "Charlotte Katakuri (Minister of Flour)"},
			{"number": 8, "name": "100% Island", "town": "Mix Town", "theme": "Fresh Fruit Juice", "minister": "Charlotte Smoothie (Minister of Juice)"},
			{"number": 9, "name": "Poripori Island", "town": "Edamame Town", "theme": "Beans", "minister": "Charlotte Daifuku (Minister of Beans)"},
			{"number": 10, "name": "Yakigashi Island", "town": "Kongari Town", "theme": "Baked / Browned Sweets", "minister": "Charlotte Oven (Minister of Browned Food)"},
			{"number": 11, "name": "Fruits Island", "town": "Cantaloupe Town", "theme": "Fruits", "minister": "Charlotte Compote (Minister of Fruits)"},
			{"number": 12, "name": "Potato Island", "town": "Chips Town", "theme": "Potato Fries", "minister": "Charlotte Snack (Minister of Fries)"},
			{"number": 13, "name": "Noko Island", "town": "Nama Town", "theme": "Whipped Cream", "minister": "Charlotte Opera (Minister of Whipped Cream)"},
			{"number": 14, "name": "Margarine Island", "town": "Butter Town", "theme": "Butter", "minister": "Charlotte Galette (Minister of Butter)"},
			{"number": 15, "name": "Ice Island", "town": "Sherbet Town", "theme": "Gelato & Ice Cream", "minister": "Charlotte Moscato (Minister of Gelato)"},
			{"number": 16, "name": "Piepie Island", "town": "Pie Town", "theme": "Pie", "minister": "Charlotte Compo (Minister of Pie)"},
			{"number": 17, "name": "Loving Island", "town": "Love Town", "theme": "Cornstarch / Love", "minister": "Charlotte Cornstarch (Minister of Love)"},
			{"number": 18, "name": "Kibo Island", "town": "Eclair Town", "theme": "Yeast", "minister": "Charlotte Basskarte (Minister of Yeast)"},
			{"number": 19, "name": "Futoru Island", "town": "Fat Town", "theme": "Suet", "minister": "Charlotte Dosmarche (Minister of Suet)"},
			{"number": 20, "name": "Liqueur Island", "town": "Chuhai Town", "theme": "Alcohol & Liqueur", "minister": "Charlotte Zuccotto (Minister of Alcohol)"},
			{"number": 21, "name": "Pakupaku Island", "town": "Gatsugatsu Town", "theme": "Meat", "minister": "Charlotte Nougat (Minister of Meat)"},
			{"number": 22, "name": "Funwari Island", "town": "Shittori Town", "theme": "Chiffon Cake", "minister": "Charlotte Chiffon (Formerly, Minister of Chiffon)"},
			{"number": 23, "name": "Tanega Island", "town": "Mehari Town", "theme": "Seeds", "minister": "Charlotte Kato (Minister of Seeds)"},
			{"number": 24, "name": "Rokumitsu Island", "town": "Anmitsu Town", "theme": "Agar & Syrup", "minister": "Charlotte Montb (Minister of Agar)"},
			{"number": 25, "name": "Sanshoku Island", "town": "Sundae Town", "theme": "Parfait", "minister": "Charlotte Broye (Minister of Parfait)"},
			{"number": 26, "name": "Torigara Island", "town": "Dashi Town", "theme": "Essence & Broth", "minister": "Charlotte Mascarpone & Joscarpone"},
			{"number": 27, "name": "Milenge Island", "town": "Meringue Town", "theme": "Meringue", "minister": "Charlotte Mobile (Minister of Meringue)"},
			{"number": 28, "name": "Crunchy Island", "town": "Gratin Town", "theme": "Gratin", "minister": "Charlotte Myukuru (Minister of Gratin)"},
			{"number": 29, "name": "Topping Island", "town": "Decoration Town", "theme": "Toppings", "minister": "Charlotte High-Fat (Minister of Topping)"},
			{"number": 30, "name": "Mini Island", "town": "Petite Town", "theme": "Bite-Sized Sweets", "minister": "Charlotte Tablet (Minister of Bite-Sized)"},
			{"number": 31, "name": "Hoya Island", "town": "Simmer Town", "theme": "Simmered Foods", "minister": "Charlotte Saint-Marc (Minister of Simmering)"},
			{"number": 32, "name": "Milky Island", "town": "Miruku Town", "theme": "Milk", "minister": "Charlotte Custard (Minister of Milk)"},
			{"number": 33, "name": "Black Island", "town": "Kuro Town", "theme": "Dark Cocoa", "minister": "Charlotte Cabaletta (Minister of Cocoa)"},
			{"number": 34, "name": "Kinoko Island", "town": "Mushroom Town", "theme": "Mushrooms", "minister": "Charlotte Nusstorte (Minister of Mushrooms)"}
		]
	}


# ==============================================================================
# 8. WANO COUNTRY 6 REGIONS + ONIGASHIMA + OLD WANO PLUTON CAVERN
# ==============================================================================
static func get_wano_regions() -> Dictionary:
	return {
		"flower_capital": {
			"name": "Flower Capital (Hana no Miyako)",
			"climate": "Perpetual Spring (Cherry Blossoms)",
			"historical_ruler": "Kozuki Shogunate",
			"settlements": ["Shogun's Castle", "Rasetsu District", "Flower Capital Bathhouse", "Ebisu Town (Outskirts)"],
			"specialties": ["Sangoro Soba", "Kokeshi Dolls", "Fire Festival Sky Lanterns"]
		},
		"kuri": {
			"name": "Kuri",
			"climate": "Temperate Forest & Bamboo Groves",
			"historical_ruler": "Kozuki Oden (Daimyo of Kuri)",
			"settlements": ["Kuri Beach", "Amigasa Village", "Okobore Town", "Bakura Town", "Oden Castle Ruins", "Atamayama", "Itachi Port"],
			"specialties": ["Hitetsu's Meito Katanas", "Amigasa Hats", "Okobore Tea"]
		},
		"udon": {
			"name": "Udon",
			"climate": "Arid Rocky Quarry",
			"historical_ruler": "Daimyo of Udon",
			"settlements": ["Prisoner Excavation Mines", "Tokage Port"],
			"specialties": ["Seastone Ore", "Sweet Red-Bean Shiruko", "Ryuo Haki Training"]
		},
		"ringo": {
			"name": "Ringo",
			"climate": "Perpetual Winter Blizzard",
			"historical_ruler": "Shimotsuki Ushimaru (Daimyo of Ringo)",
			"settlements": ["Northern Cemetery", "Oihagi Bridge (Bandit's Bridge)", "Kakekawa Port"],
			"specialties": ["Eternal Grave Swords (Shusui Shrine)"]
		},
		"hakumai": {
			"name": "Hakumai",
			"climate": "Perpetual Golden Autumn",
			"historical_ruler": "Shimotsuki Yasuie (Daimyo of Hakumai)",
			"settlements": ["Habu Port", "Mogura Port (Secret Gondola Lift)", "Enma Shrine"],
			"specialties": ["Gondola Waterfall Ascent", "Oden Nabe"]
		},
		"kibi": {
			"name": "Kibi",
			"climate": "Wasteland Steppe",
			"historical_ruler": "Daimyo of Kibi",
			"settlements": ["Kibi Crossroads", "Nekozaemon Port"],
			"specialties": ["Cross-Country Courier Routes"]
		},
		"onigashima": {
			"name": "Onigashima (Skull Dome Island)",
			"climate": "Stormy Winter Sea / Floating Flame-Cloud Fortress",
			"historical_ruler": "Previously known as Laughing Island before Kaido's occupation",
			"settlements": ["Skull Dome Live Floor", "Performance Stage", "Treasure Repository (Historical Poneglyph)"],
			"specialties": ["Onigashima Banquet Sake"]
		},
		"old_wano_abyss": {
			"name": "Submerged Old Wano & Mount Fuji Pluton Chamber (-4,000m)",
			"climate": "Freshwater Underwater Basin Enclosed by Wano's Outer Borders",
			"historical_ruler": "Void Century Kozuki Ancestors",
			"settlements": ["Sunken 800-Year-Old Wano Metropolis", "Road Poneglyph #3 Vault", "Ancient Weapon Pluton Drydock"],
			"specialties": ["Road Poneglyph #3", "Ancient Weapon Pluton"]
		}
	}


# ==============================================================================
# 9. PUFFING TOM & ROCKETMAN SEA TRAIN NETWORK
# ==============================================================================
static func get_sea_train_network() -> Dictionary:
	return {
		"trains": [
			{
				"id": "puffing_tom",
				"name": "Puffing Tom",
				"builder": "Tom's Workers (Tom, Iceburg & Cutty Flam)",
				"speed_m_per_s": 45.0,
				"description": "Primary passenger and cargo steam Sea Train running along sub-surface ocean tracks."
			},
			{
				"id": "rocketman",
				"name": "Rocketman (Runaway Prototype)",
				"builder": "Tom's Workers",
				"speed_m_per_s": 75.0,
				"description": "Unstoppable high-pressure steam prototype with a giant shark prow and zero brakes."
			}
		],
		"stations": [
			{"order": 1, "id": "blue_station", "name": "Blue Station (Water 7 Inner Terminal)", "lat_deg": -4.6, "lon_deg": 115.0, "description": "Main passenger terminal inside Water 7."},
			{"order": 2, "id": "shift_station", "name": "Shift Station (Water 7 Outer Reef)", "lat_deg": -4.8, "lon_deg": 115.4, "description": "Track-switching lighthouse manned by Kokoro, Chimney, and Gonbe."},
			{"order": 3, "id": "st_poplar", "name": "St. Poplar (Town of the Spring Queen)", "lat_deg": -5.2, "lon_deg": 117.5, "description": "Bustling market island 1 hour from Water 7."},
			{"order": 4, "id": "san_faldo", "name": "San Faldo (Carnival Town)", "lat_deg": -5.8, "lon_deg": 119.5, "description": "Festive iron-trading island along the southern track."},
			{"order": 5, "id": "pucci", "name": "Pucci (Gourmet City)", "lat_deg": -6.4, "lon_deg": 121.5, "description": "Wealthy culinary island governed by Mayor Bimine."},
			{"order": 6, "id": "enies_lobby_dry_station", "name": "Dry Station (Enies Lobby)", "lat_deg": -7.2, "lon_deg": 124.0, "description": "Heavily guarded judicial terminal outside the Main Gate of Enies Lobby."}
		]
	}


# ==============================================================================
# 10. ROAD PONEGLYPHS & LOG POSE NAVIGATION GRAPH
# ==============================================================================
static func get_road_poneglyph_locations() -> Array[Dictionary]:
	return [
		{
			"index": 1,
			"id": "road_poneglyph_zou",
			"island_id": "zou",
			"name": "Road Poneglyph #1 — Whale Tree of Zou",
			"location": "Secret Chamber inside the Whale Tree, Mokomo Dukedom",
			"guardian": "Duke Inuarashi, Master Nekomamushi & Raizo",
			"encoded_coord": {"lat_deg": 18.5, "lon_deg": 240.0}
		},
		{
			"index": 2,
			"id": "road_poneglyph_totto_land",
			"island_id": "totto_land_whole_cake",
			"name": "Road Poneglyph #2 — Whole Cake Chateau Treasure Room",
			"location": "Chateau Treasure Room, Whole Cake Island, Totto Land",
			"guardian": "Charlotte Linlin (Big Mom) & Charlotte Smoothie",
			"encoded_coord": {"lat_deg": -14.2, "lon_deg": 272.0}
		},
		{
			"index": 3,
			"id": "road_poneglyph_wano",
			"island_id": "wano_country",
			"name": "Road Poneglyph #3 — Underwater Old Wano beneath Mount Fuji",
			"location": "Submerged Old Wano Cavern (above Ancient Weapon Pluton)",
			"guardian": "Kozuki Sukiyaki & Kozuki Clan",
			"encoded_coord": {"lat_deg": 11.4, "lon_deg": 318.0}
		},
		{
			"index": 4,
			"id": "road_poneglyph_elbaf",
			"island_id": "elbaf",
			"name": "Road Poneglyph #4 — Elbaf Sanctuary / Man Marked by Flames",
			"location": "Sanctuary of the Sun / Owl's Library Archive on Elbaf",
			"guardian": "Jaguar D. Saul & the Man Marked by Flames",
			"encoded_coord": {"lat_deg": -18.5, "lon_deg": 352.0}
		}
	]


static func get_log_pose_routes() -> Dictionary:
	return {
		"paradise_single_needle_graph": {
			"twin_cape": ["whisky_peak", "banaro_island", "karakuri_baldimore"],
			"whisky_peak": ["little_garden"],
			"little_garden": ["alabasta", "drum_island"],
			"drum_island": ["alabasta"],
			"alabasta": ["jaya"],
			"jaya": ["skypiea_upper_yard", "long_ring_long_land"],
			"skypiea_upper_yard": ["long_ring_long_land"],
			"long_ring_long_land": ["water_7"],
			"banaro_island": ["water_7"],
			"water_7": ["florian_triangle_thriller_bark", "sabaody_archipelago"],
			"florian_triangle_thriller_bark": ["sabaody_archipelago"],
			"karakuri_baldimore": ["sabaody_archipelago"],
			"kuraigana_island": ["sabaody_archipelago"],
			"momoiro_island": ["sabaody_archipelago"],
			"boin_archipelago": ["sabaody_archipelago"],
			"sabaody_archipelago": ["fish_man_island"]
		},
		"new_world_triple_needle_graph": {
			"fish_man_island": ["raijin_island", "risky_red_island", "mystoria_island"],
			"unmapped_distress_anomaly": ["punk_hazard"],
			"punk_hazard": ["dressrosa"],
			"raijin_island": ["dressrosa"],
			"risky_red_island": ["dressrosa"],
			"mystoria_island": ["dressrosa"],
			"dressrosa": ["totto_land_whole_cake", "karai_bari_island", "sphinx"],
			"vivre_card_only": ["zou"],
			"zou": ["totto_land_whole_cake", "wano_country"],
			"totto_land_whole_cake": ["wano_country", "elbaf"],
			"sphinx": ["wano_country"],
			"karai_bari_island": ["wano_country"],
			"wano_country": ["egghead_island", "elbaf", "hachinosu"],
			"egghead_island": ["elbaf"],
			"hachinosu": ["lodestar_island"],
			"elbaf": ["lodestar_island"],
			"lodestar_island": [],
			"road_poneglyph_triangulation": ["laugh_tale"]
		}
	}


## Computes the live spherical & 64-bit world position of the walking elephant Zunesha (Zou)
## as it wanders a slow figure-eight path in the New World.
static func get_zunesha_orbital_state(world_time_sec: float) -> Dictionary:
	var angular_speed: float = 0.00005
	var phase: float = world_time_sec * angular_speed
	var lat_deg: float = 4.0 + 2.5 * sin(phase)
	var lon_deg: float = 228.0 + 4.0 * cos(phase * 0.5)
	var world_pos: Vector3 = lat_lon_alt_to_vector3(lat_deg, lon_deg, 20000.0)
	return {
		"island_id": "zou",
		"entity": "Zunesha (Naitamie-Norida Elephant)",
		"lat_deg": lat_deg,
		"lon_deg": lon_deg,
		"alt_m": 20000.0,
		"world_position": world_pos
	}


## Computes the drifting position of Thriller Bark inside the Florian Triangle fog bank.
static func get_thriller_bark_drift_state(world_time_sec: float) -> Dictionary:
	var phase: float = world_time_sec * 0.00008
	var lat_deg: float = -2.0 + 0.8 * sin(phase)
	var lon_deg: float = 146.0 + 1.2 * cos(phase)
	return {
		"island_id": "florian_triangle_thriller_bark",
		"lat_deg": lat_deg,
		"lon_deg": lon_deg,
		"alt_m": 0.0,
		"world_position": lat_lon_alt_to_vector3(lat_deg, lon_deg, 0.0)
	}
