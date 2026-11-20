class_name StoryCampaignSystem
extends Node
## Overarching Indie Exploration Plot & Progression State Machine (`StoryCampaignManager`)
## Project "Blue Planet" — Godot 4.3+ (`precision=double` 64-Bit Planetary Engine)
##
## Drives the complete One Piece-inspired planetary odyssey across the 100,531 km globe:
## Act I:   Birth Sea Prologue (East / North / West / South Blue origins -> Loguetown / Canal Entry)
## Act II:  Reverse Mountain & Twin Cape (+5,000m hydraulic climb, Laboon, Crocus & Log Pose gift)
## Act III: Paradise Saga (Whisky Peak -> Little Garden -> Drum -> Alabasta -> Jaya/Skypiea +10km -> Water 7 -> Thriller Bark -> Sabaody)
## Act IV:  Red Line Crossing & The Abyss (Rayleigh Coating + Rusukaina Haki -> -10,000m Fish-Man Island & Joy Boy Apology)
## Act V:   New World Entry & Dressrosa/Zou (Triple-Needle Log Pose -> Punk Hazard -> Dressrosa -> Mink Vivre Card to Zunesha)
## Act VI:  Yonko Territories & 4 Road Poneglyphs (Zou #1, Whole Cake #2, Wano #3, Egghead & Elbaf #4 -> Lodestar)
## Act VII: Laugh Tale Triangulation & Dawn of the World Finale (Geodesic intersection, Rio Poneglyph completion)

signal campaign_act_advanced(previous_act: int, new_act: int, act_title: String)
signal quest_milestone_completed(milestone_id: String, title: String, bounty_reward: int)
signal crew_member_recruited(role_id: String, character_name: String, origin_island: String)
signal ship_upgrade_installed(slot_name: String, tier_id: String, description: String)
signal haki_tier_unlocked(haki_branch: String, new_tier: int, technique_name: String)
signal bounty_updated(new_bounty_beli: int, epithet: String)

# ==============================================================================
# 1. CAMPAIGN ACTS & BIRTH SEA ENUMS
# ==============================================================================
enum CampaignAct {
	ACT_I_BIRTH_SEA_PROLOGUE = 1,
	ACT_II_REVERSE_MOUNTAIN_TWIN_CAPE = 2,
	ACT_III_PARADISE_ODYSSEY = 3,
	ACT_IV_RED_LINE_ABYSS_CROSSING = 4,
	ACT_V_NEW_WORLD_HAZARDS_DRESSROSA_ZOU = 5,
	ACT_VI_FOUR_ROAD_PONEGLYPHS_YONKO_SAGA = 6,
	ACT_VII_LAUGH_TALE_DAWN_FINALE = 7
}

enum BirthSeaOrigin {
	EAST_BLUE = 0,  # Dawn Island (Foosha Village) -> Shells Town -> Syrup Village -> Baratie -> Cocoyasi -> Loguetown
	NORTH_BLUE = 1, # Lvneel Kingdom -> Flevance Ruins -> Spider Miles -> Germa Waters
	WEST_BLUE = 2,  # Ohara Ruins -> Kano Country -> Ilusia / Toroa Five Families
	SOUTH_BLUE = 3  # Sorbet Kingdom -> Torino Kingdom -> Karate Island -> Briss Drydock
}

# ==============================================================================
# 2. CAMPAIGN STATE & PROGRESSION DATA
# ==============================================================================
var current_act: CampaignAct = CampaignAct.ACT_I_BIRTH_SEA_PROLOGUE
var birth_sea: BirthSeaOrigin = BirthSeaOrigin.EAST_BLUE
var player_bounty_beli: int = 0
var player_epithet: String = "Uncharted Rookie of the Blue Sea"
var selected_paradise_route_index: int = 1 # 1..7 canonical magnetic paths from Twin Cape

## Completed Story Milestones (`milestone_id` -> timestamp / true)
var completed_milestones: Dictionary = {}

## Canonical Story Arcs & Milestones Database
var campaign_milestones: Dictionary = {}

## Crew Roster (`role_id` -> Dictionary with `recruited`, `name`, `origin_island`, `perk`)
var crew_roster: Dictionary = {
	"first_mate_swordsman": {
		"recruited": false,
		"name": "Roronoa-Style Kenshi",
		"origin_island": "shells_town",
		"perk": "Meito Graded Blade Mastery & Ship Lookout"
	},
	"navigator_cartographer": {
		"recruited": false,
		"name": "Cocoyasi Master Navigator",
		"origin_island": "conomi_islands",
		"perk": "Unlocks World Chart Sextant Triangulation, Grand Line Cyclone Prediction & Triple Log Pose Reading"
	},
	"sharpshooter_artificer": {
		"recruited": false,
		"name": "Syrup Marksman & Dial Engineer",
		"origin_island": "syrup_village",
		"perk": "Integrates Skypiea Breath/Flame/Impact Dials into Slingshot & Clima-Tact Weapons"
	},
	"maritime_chef": {
		"recruited": false,
		"name": "Baratie Sous-Chef of the All Blue",
		"origin_island": "baratie",
		"perk": "Eliminates Scurvy/Starvation & Cooks Stat-Buffing Sea King / Sky Fish Feasts"
	},
	"ship_doctor": {
		"recruited": false,
		"name": "Sakura Kingdom Physician",
		"origin_island": "drum_island",
		"perk": "Synthesizes Antidotes for 500 Grand Line Diseases & Rumble Ball Bio-Enhancers"
	},
	"archaeologist_scholar": {
		"recruited": false,
		"name": "Survivor of Ohara's Library",
		"origin_island": "alabasta",
		"perk": "Reads Ancient Kozuki Poneglyph Script to Decipher the Rio Poneglyph & 4 Road Poneglyphs"
	},
	"master_shipwright": {
		"recruited": false,
		"name": "Galley-La & Tom's Workers Shipwright",
		"origin_island": "water_7",
		"perk": "Constructs Treasure Tree Adam Hull, Cola Coup de Burst & Soldier Dock Vehicles"
	},
	"musician_soul_king": {
		"recruited": false,
		"name": "Rumbar Tone-Dial Musician",
		"origin_island": "thriller_bark",
		"perk": "Restores Crew Morale in Florian Fog, Plays Binks' Sake for Laboon &Projects Soul Parade"
	},
	"master_helmsman": {
		"recruited": false,
		"name": "Sun Pirate Fish-Man Helmsman",
		"origin_island": "fish_man_island",
		"perk": "Rides Green Room Tube Waves, Masters Knock Up Streams & Fish-Man Jujutsu Ocean Currents"
	}
}

## Ship Progression & Modular Upgrade State
var ship_state: Dictionary = {
	"vessel_class": "Starter Fishing Dinghy",
	"hull_tier": "STANDARD_OAK",             # STANDARD_OAK -> REINFORCED_IRONBARK -> TREASURE_TREE_ADAM
	"propulsion_tier": "CANVAS_SAILS",       # CANVAS_SAILS -> YUDA_PADDLEWHEEL -> COLA_COUP_DE_BURST
	"keel_plating": "NONE",                  # NONE -> SEASTONE_KEEL_PLATING (Calm Belt Sea King cloak)
	"submersion_coating": "NONE",            # NONE -> YARUKIMAN_RESIN_COATING (-10,000m Abyssal diving)
	"deck_tangerine_grove": false,           # Prevents Vitamin C deficiency on long voyages
	"soldier_dock_channels": {
		"channel_0": "Mini Paddle Steamer",
		"channel_1": "Waver Sky-Jet (Jet Dial Powered)",
		"channel_2": "Three-Man Shark Submerge (-5,000m Recon)",
		"channel_3": "Armored Kurosai Bike",
		"channel_4": "Brachio Tank Artillery"
	}
}

## Haki & Skypiea Dial Mastery State
var haki_progression: Dictionary = {
	"observation_tier": 0, # 0: Locked, 1: Mantra / Presence Sensing, 2: Intent & Aura Reading, 3: Advanced Future Sight
	"armament_tier": 0,    # 0: Locked, 1: Invisible Armor, 2: Koka Hardening, 3: Ryuo Emission & Internal Destruction
	"conqueror_tier": 0    # 0: Locked, 1: Haoshoku Intimidation Wave, 2: Targeted Will Crush, 3: Advanced Conqueror's Infusion
}

var unlocked_dials: Array[String] = []

# ==============================================================================
# 3. LIFECYCLE & INITIALIZATION
# ==============================================================================
func _ready() -> void:
	_build_canonical_milestone_catalog()

func start_new_campaign(chosen_birth_sea: BirthSeaOrigin = BirthSeaOrigin.EAST_BLUE) -> Dictionary:
	birth_sea = chosen_birth_sea
	current_act = CampaignAct.ACT_I_BIRTH_SEA_PROLOGUE
	player_bounty_beli = 0
	completed_milestones.clear()

	var starter_island_id: String = "dawn_island"
	match birth_sea:
		BirthSeaOrigin.EAST_BLUE:
			starter_island_id = "dawn_island"
			player_epithet = "Rookie of Dawn Island"
		BirthSeaOrigin.NORTH_BLUE:
			starter_island_id = "lvneel_kingdom"
			player_epithet = "Explorer of Lvneel"
		BirthSeaOrigin.WEST_BLUE:
			starter_island_id = "ohara_ruins"
			player_epithet = "Seeker of West Blue"
		BirthSeaOrigin.SOUTH_BLUE:
			starter_island_id = "sorbet_kingdom"
			player_epithet = "Voyager of Sorbet"

	var registry: Node = get_node_or_null("/root/WorldRegistry")
	if registry != null and registry.has_method("notify_island_docked"):
		registry.call("notify_island_docked", starter_island_id)

	return {
		"act": current_act,
		"act_title": get_act_title(current_act),
		"birth_sea": birth_sea,
		"starter_island_id": starter_island_id
	}

# ==============================================================================
# 4. CANONICAL MILESTONE CATALOG (ALL 7 ACTS FROM BIRTH SEA TO LAUGH TALE)
# ==============================================================================
func _build_canonical_milestone_catalog() -> void:
	campaign_milestones = {
		# --- ACT I: BIRTH SEA PROLOGUE ---
		"act1_foosha_departure": {
			"act": CampaignAct.ACT_I_BIRTH_SEA_PROLOGUE,
			"island_id": "dawn_island",
			"title": "Departure from Partys Bar & The Lord of the Coast",
			"description": "Receive rations from Makino, obtain your starter dinghy permit from Mayor Woop Slap, and set sail across the Sea of Dawn.",
			"bounty_reward": 0
		},
		"act1_syrup_caravel_hull": {
			"act": CampaignAct.ACT_I_BIRTH_SEA_PROLOGUE,
			"island_id": "syrup_village",
			"title": "The Caravel of Syrup Village (Going Merry Class)",
			"description": "Defend Syrup Village alongside Kaya and Merry to receive a full-rigged Caravel vessel with central whipstaff rudder.",
			"bounty_reward": 5_000_000,
			"recruits_role": "sharpshooter_artificer",
			"ship_upgrade": {"slot": "vessel_class", "value": "Caravel (Going Merry Class)"}
		},
		"act1_baratie_all_blue_galley": {
			"act": CampaignAct.ACT_I_BIRTH_SEA_PROLOGUE,
			"island_id": "baratie",
			"title": "Chef Zeff's Logbook & The Dream of the All Blue",
			"description": "Prove your resolve at the ocean-going restaurant Baratie in the Sambas Region and recruit a master maritime chef.",
			"bounty_reward": 10_000_000,
			"recruits_role": "maritime_chef"
		},
		"act1_cocoyasi_world_chart": {
			"act": CampaignAct.ACT_I_BIRTH_SEA_PROLOGUE,
			"island_id": "conomi_islands",
			"title": "Liberation of Cocoyasi & The 100,531 km World Map",
			"description": "Topple the Arlong Park stronghold, transplant Bell-mere's Tangerine trees onto your ship deck, and recruit a master navigator.",
			"bounty_reward": 30_000_000,
			"recruits_role": "navigator_cartographer",
			"ship_upgrade": {"slot": "deck_tangerine_grove", "value": "true"}
		},
		"act1_loguetown_execution_storm": {
			"act": CampaignAct.ACT_I_BIRTH_SEA_PROLOGUE,
			"island_id": "loguetown",
			"title": "The Town of Beginning and End",
			"description": "Test your fate against Sandai Kitetsu at Ipponmatsu's Arms Shop, hear Raoul's tales of Gol D. Roger at the Gold Roger Bar, and break through the storm toward the Red Line light.",
			"bounty_reward": 30_000_000,
			"recruits_role": "first_mate_swordsman",
			"advances_to_act": CampaignAct.ACT_II_REVERSE_MOUNTAIN_TWIN_CAPE
		},

		# --- ACT II: REVERSE MOUNTAIN & TWIN CAPE ---
		"act2_reverse_mountain_ascent": {
			"act": CampaignAct.ACT_II_REVERSE_MOUNTAIN_TWIN_CAPE,
			"island_id": "reverse_mountain",
			"title": "Climbing the +5,000m Hydraulic Red Line Canal",
			"description": "Steer cleanly through the 400m stone gates at (lat=0, lon=0) without shattering your hull on the Red Line cliffs, crest the +5,000m summit where the Four Blues converge, and plunge into Paradise.",
			"bounty_reward": 30_000_000
		},
		"act2_twin_cape_laboon_log_pose": {
			"act": CampaignAct.ACT_II_REVERSE_MOUNTAIN_TWIN_CAPE,
			"island_id": "twin_cape",
			"title": "Crocus, Laboon's Promise & The Single-Needle Log Pose",
			"description": "Navigate the stomach canals of the island whale Laboon, hear the 50-year tale of the Rumbar Pirates from Crocus, receive your first Grand Line Log Pose, and choose one of the 7 magnetic routes across Paradise.",
			"bounty_reward": 30_000_000,
			"advances_to_act": CampaignAct.ACT_III_PARADISE_ODYSSEY
		},

		# --- ACT III: PARADISE SAGA ---
		"act3_whisky_peak_little_garden": {
			"act": CampaignAct.ACT_III_PARADISE_ODYSSEY,
			"island_id": "little_garden",
			"title": "The 100-Year Duel of Elbaf Giants & The Eternal Pose Override",
			"description": "Survive the Baroque Works ambush at Whisky Peak, earn the respect of Giant Captains Dorry and Brogy on prehistoric Little Garden, and bypass the 1-year magnetic lock using an Eternal Pose.",
			"bounty_reward": 42_000_000
		},
		"act3_drum_island_hiriluk_sakura": {
			"act": CampaignAct.ACT_III_PARADISE_ODYSSEY,
			"island_id": "drum_island",
			"title": "Cherry Blossoms Over the Drum Rockies",
			"description": "Scale the vertical 5,000m Drum Peak to Dr. Kureha's castle, witness Hiriluk's miracle cherry blossom snow, and recruit a ship doctor.",
			"bounty_reward": 50_000_000,
			"recruits_role": "ship_doctor"
		},
		"act3_alabasta_tomb_of_kings": {
			"act": CampaignAct.ACT_III_PARADISE_ODYSSEY,
			"island_id": "alabasta",
			"title": "Liberation of Alabasta & The Pluton Poneglyph",
			"description": "Cross the Sandora Desert from Nanohana and Yuba to Alubarna, defeat the Baroque Works conspiracy, decipher the Tomb of the Kings Poneglyph (Ancient Weapon Pluton), and welcome an Ohara Archaeologist aboard.",
			"bounty_reward": 100_000_000,
			"recruits_role": "archaeologist_scholar",
			"poneglyph_id": "alabasta_pluton_poneglyph"
		},
		"act3_jaya_knock_up_stream_skypiea": {
			"act": CampaignAct.ACT_III_PARADISE_ODYSSEY,
			"island_id": "skypiea",
			"title": "Riding the Knock Up Stream to +10,000m & The Golden Bell of Shandora",
			"description": "Reinforce your ship with Mont Blanc Cricket's Saruyama Alliance on Jaya, capture a South Bird, ride the geothermal Knock Up Stream +7,000m to the White Sea and +10,000m to Skypiea, ring the Shandorian Golden Belfry, and read Gol D. Roger's message alongside the Poseidon Poneglyph.",
			"bounty_reward": 130_000_000,
			"poneglyph_id": "skypiea_shandora_poneglyph",
			"unlocks_dials": ["ImpactDial", "BreathDial", "FlameDial", "ToneDial", "MilkyDial", "JetDial", "FlashDial"]
		},
		"act3_water_7_treasure_tree_adam": {
			"act": CampaignAct.ACT_III_PARADISE_ODYSSEY,
			"island_id": "water_7",
			"title": "The Shipwrights of Water 7 & The Brigantine of Treasure Tree Adam",
			"description": "Exchange Skypiea gold for 300,000,000 Beli at Water 7, survive the Aqua Laguna tsunami and Puffing Tom Sea Train to Enies Lobby, and build a new flagship from legendary Treasure Tree Adam wood equipped with a Cola-Powered Coup de Burst and Soldier Dock System.",
			"bounty_reward": 300_000_000,
			"recruits_role": "master_shipwright",
			"ship_upgrade": {"slot": "hull_tier", "value": "TREASURE_TREE_ADAM"}
		},
		"act3_thriller_bark_vivre_card": {
			"act": CampaignAct.ACT_III_PARADISE_ODYSSEY,
			"island_id": "thriller_bark",
			"title": "Dawn in the Florian Triangle & Binks' Sake Recorded on Tone Dial",
			"description": "Reclaim stolen shadows in the Florian Triangle, receive a New World Vivre Card from Lola, and recruit the last surviving Rumbar Pirate musician carrying the final Tone Dial for Laboon.",
			"bounty_reward": 320_000_000,
			"recruits_role": "musician_soul_king"
		},
		"act3_sabaody_and_rusukaina_haki": {
			"act": CampaignAct.ACT_III_PARADISE_ODYSSEY,
			"island_id": "sabaody_archipelago",
			"title": "Sabaody Groves 1-79, Amazon Lily & The 2-Year Haki Awakening",
			"description": "Meet Shakky and Silvers Rayleigh at Grove 13, visit the Kuja tribe on Amazon Lily in the Calm Belt, and master the three colors of Haki (Kenbunshoku, Busoshoku, Haoshoku) with Rayleigh before coating your ship in Yarukiman Mangrove Resin.",
			"bounty_reward": 400_000_000,
			"ship_upgrade": {"slot": "submersion_coating", "value": "YARUKIMAN_RESIN_COATING"},
			"advances_to_act": CampaignAct.ACT_IV_RED_LINE_ABYSS_CROSSING
		},

		# --- ACT IV: RED LINE CROSSING & FISH-MAN ISLAND (-10,000M ABYSS) ---
		"act4_fish_man_island_joyboy_apology": {
			"act": CampaignAct.ACT_IV_RED_LINE_ABYSS_CROSSING,
			"island_id": "fish_man_island",
			"title": "10,000 Meters Beneath the Red Line — Joy Boy's Apology & The Triple Log Pose",
			"description": "Descend via the Deep-Sea Plume and Undersea Currents into the double-layered bubble of Fish-Man Island, uncover the Sea Forest Poneglyph containing Joy Boy's 800-year-old apology to Poseidon alongside the Ark Noah, recruit a master Fish-Man Helmsman, and receive the New World Triple-Needle Log Pose.",
			"bounty_reward": 450_000_000,
			"recruits_role": "master_helmsman",
			"poneglyph_id": "fish_man_joyboy_apology",
			"advances_to_act": CampaignAct.ACT_V_NEW_WORLD_HAZARDS_DRESSROSA_ZOU
		},

		# --- ACT V: NEW WORLD ENTRY, DRESSROSA & ZOU ---
		"act5_punk_hazard_and_dressrosa": {
			"act": CampaignAct.ACT_V_NEW_WORLD_HAZARDS_DRESSROSA_ZOU,
			"island_id": "dressrosa",
			"title": "Shattering the SAD Supply Chain & The Corrida Colosseum Grand Fleet",
			"description": "Follow the most erratic needle of your Triple Log Pose to the burning and freezing wasteland of Punk Hazard, then liberate Dressrosa and the Tontatta Dwarves to forge an allied Grand Fleet.",
			"bounty_reward": 500_000_000
		},
		"act5_zou_road_poneglyph_1": {
			"act": CampaignAct.ACT_V_NEW_WORLD_HAZARDS_DRESSROSA_ZOU,
			"island_id": "zou",
			"title": "Atop the 20km Walking Elephant Zunesha — Road Poneglyph #1",
			"description": "Use a Mink Vivre Card to track the moving island of Zou across the New World, ascend Zunesha's left hind leg to Mokomo Dukedom, and decipher the first deep-red Road Poneglyph inside the Whale Tree.",
			"bounty_reward": 550_000_000,
			"poneglyph_id": "road_poneglyph_1_zou",
			"advances_to_act": CampaignAct.ACT_VI_FOUR_ROAD_PONEGLYPHS_YONKO_SAGA
		},

		# --- ACT VI: YONKO TERRITORIES & THE 4 ROAD PONEGLYPHS ---
		"act6_whole_cake_road_poneglyph_2": {
			"act": CampaignAct.ACT_VI_FOUR_ROAD_PONEGLYPHS_YONKO_SAGA,
			"island_id": "whole_cake_island",
			"title": "Infiltration of Totto Land, Future Sight & Road Poneglyph #2",
			"description": "Sail through the 34 food-themed islands of Totto Land, steal a rubbing of Road Poneglyph #2 from Whole Cake Chateau's Room of Treasure, and awaken Advanced Observation Haki (Future Sight) in the Mirror-World.",
			"bounty_reward": 1_500_000_000,
			"poneglyph_id": "road_poneglyph_2_whole_cake"
		},
		"act6_wano_onigashima_road_poneglyph_3": {
			"act": CampaignAct.ACT_VI_FOUR_ROAD_PONEGLYPHS_YONKO_SAGA,
			"island_id": "wano_country",
			"title": "Opening the Borders of Wano, Ryuo Mastery & Road Poneglyph #3",
			"description": "Climb the carp waterfall into isolated Wano Country, master Flowing Ryuo (Internal Destruction) and Conqueror's Infusion, forge Seastone hull plating, and descend into submerged Old Wano with Kozuki Sukiyaki to view Pluton's chamber and decipher Road Poneglyph #3.",
			"bounty_reward": 3_000_000_000,
			"poneglyph_id": "road_poneglyph_3_wano",
			"ship_upgrade": {"slot": "keel_plating", "value": "SEASTONE_KEEL_PLATING"}
		},
		"act6_egghead_elbaf_road_poneglyph_4": {
			"act": CampaignAct.ACT_VI_FOUR_ROAD_PONEGLYPHS_YONKO_SAGA,
			"island_id": "elbaf",
			"title": "Egghead's Void Century Broadcast, Warland Elbaf & Road Poneglyph #4",
			"description": "Visit Dr. Vegapunk's Labophase on Egghead to learn of the Void Century's 200-meter sea level rise, reunite with Dorry, Brogy, and Jaguar D. Saul at the Owl's Library on Elbaf (housing Ohara's saved books), and decipher the final Road Poneglyph #4 before verifying the magnetic convergence at Lodestar Island.",
			"bounty_reward": 4_000_000_000,
			"poneglyph_id": "road_poneglyph_4_elbaf",
			"advances_to_act": CampaignAct.ACT_VII_LAUGH_TALE_DAWN_FINALE
		},

		# --- ACT VII: LAUGH TALE & DAWN OF THE WORLD FINALE ---
		"act7_laugh_tale_rio_poneglyph_finale": {
			"act": CampaignAct.ACT_VII_LAUGH_TALE_DAWN_FINALE,
			"island_id": "laugh_tale",
			"title": "Laugh Tale — The Rio Poneglyph, The True History & The One Piece",
			"description": "Plot the intersecting Great-Circle geodesics of all 4 Road Poneglyphs across the 16,000,000m sphere, sail into the unmapped coordinates of Laugh Tale, unite all historical Poneglyphs into the Rio Poneglyph to uncover the full truth of Joy Boy and the Great Kingdom, and bring about the Dawn of the World.",
			"bounty_reward": 5_600_000_000
		}
	}

# ==============================================================================
# 5. PROGRESSION EXECUTION API
# ==============================================================================
func complete_milestone(milestone_id: String) -> Dictionary:
	if not campaign_milestones.has(milestone_id):
		return {"success": false, "reason": "Unknown milestone_id: " + milestone_id}
	if completed_milestones.has(milestone_id):
		return {"success": true, "already_completed": true, "milestone_id": milestone_id}

	completed_milestones[milestone_id] = true
	var spec: Dictionary = campaign_milestones[milestone_id]
	var registry: Node = get_node_or_null("/root/WorldRegistry")

	# 1. Recruit Crew Role if linked
	if spec.has("recruits_role"):
		var role_id: String = str(spec["recruits_role"])
		recruit_crew_role(role_id)

	# 2. Apply Ship Upgrade if linked
	if spec.has("ship_upgrade"):
		var upg: Dictionary = spec["ship_upgrade"]
		install_ship_upgrade(str(upg["slot"]), str(upg["value"]))

	# 3. Unlock Skypiea Dials if linked
	if spec.has("unlocks_dials"):
		for dial_name in spec["unlocks_dials"]:
			if not unlocked_dials.has(str(dial_name)):
				unlocked_dials.append(str(dial_name))

	# 4. Decipher Poneglyph in WorldRegistry if linked
	if spec.has("poneglyph_id") and registry != null and registry.has_method("decipher_poneglyph"):
		var has_arch: bool = bool(crew_roster["archaeologist_scholar"]["recruited"])
		registry.call("decipher_poneglyph", str(spec["poneglyph_id"]), has_arch)

	# 5. Update Haki Milestones automatically at Sabaody, Whole Cake, and Wano
	if milestone_id == "act3_sabaody_and_rusukaina_haki":
		unlock_haki_tier("observation", 2, "Kenbunshoku Aura & Intent Sensing")
		unlock_haki_tier("armament", 2, "Busoshoku Koka Hardening")
		unlock_haki_tier("conqueror", 1, "Haoshoku Sovereign Burst")
		if registry != null:
			registry.set("active_nav_mode", 2) # Switch to TRIPLE_LOG_POSE for New World
	elif milestone_id == "act6_whole_cake_road_poneglyph_2":
		unlock_haki_tier("observation", 3, "Advanced Kenbunshoku — Future Sight")
	elif milestone_id == "act6_wano_onigashima_road_poneglyph_3":
		unlock_haki_tier("armament", 3, "Advanced Ryuo — Internal Destruction")
		unlock_haki_tier("conqueror", 3, "Advanced Haoshoku — Conqueror's Infusion")
		install_ship_upgrade("propulsion_tier", "COLA_COUP_DE_BURST")

	# 6. Update Bounty & Epithet
	var new_bounty: int = int(spec.get("bounty_reward", player_bounty_beli))
	if new_bounty > player_bounty_beli:
		player_bounty_beli = new_bounty
		_refresh_epithet_from_bounty()
		bounty_updated.emit(player_bounty_beli, player_epithet)

	# 7. Advance Campaign Act if specified
	if spec.has("advances_to_act"):
		var prev_act: CampaignAct = current_act
		current_act = spec["advances_to_act"]
		campaign_act_advanced.emit(prev_act, current_act, get_act_title(current_act))

	quest_milestone_completed.emit(milestone_id, str(spec["title"]), player_bounty_beli)
	return {
		"success": true,
		"milestone_id": milestone_id,
		"current_act": current_act,
		"act_title": get_act_title(current_act),
		"player_bounty_beli": player_bounty_beli
	}

func recruit_crew_role(role_id: String) -> bool:
	if not crew_roster.has(role_id):
		return false
	crew_roster[role_id]["recruited"] = true
	crew_member_recruited.emit(
		role_id,
		str(crew_roster[role_id]["name"]),
		str(crew_roster[role_id]["origin_island"])
	)
	return true

func install_ship_upgrade(slot_name: String, value: String) -> void:
	if slot_name == "deck_tangerine_grove":
		ship_state["deck_tangerine_grove"] = (value == "true")
	else:
		ship_state[slot_name] = value
	ship_upgrade_installed.emit(slot_name, value, "Installed " + value + " on " + slot_name)

func unlock_haki_tier(branch: String, tier: int, technique_name: String) -> void:
	var key: String = branch + "_tier"
	if haki_progression.has(key):
		haki_progression[key] = maxi(int(haki_progression[key]), tier)
		haki_tier_unlocked.emit(branch, haki_progression[key], technique_name)

func _refresh_epithet_from_bounty() -> void:
	if player_bounty_beli >= 5_000_000_000:
		player_epithet = "Sovereign of the Dawn & Conqueror of Laugh Tale"
	elif player_bounty_beli >= 3_000_000_000:
		player_epithet = "Emperor of the Sea (Yonko)"
	elif player_bounty_beli >= 1_500_000_000:
		player_epithet = "The Fifth Emperor of the New World"
	elif player_bounty_beli >= 300_000_000:
		player_epithet = "Supernova of the Worst Generation"
	elif player_bounty_beli >= 100_000_000:
		player_epithet = "Hundred-Million Rookie of Paradise"
	elif player_bounty_beli >= 30_000_000:
		player_epithet = "Champion of the Birth Sea"

static func get_act_title(act: CampaignAct) -> String:
	match act:
		CampaignAct.ACT_I_BIRTH_SEA_PROLOGUE:
			return "Act I — Romance Dawn: The Birth Sea Prologue"
		CampaignAct.ACT_II_REVERSE_MOUNTAIN_TWIN_CAPE:
			return "Act II — The +5,000m Hydraulic Climb: Reverse Mountain & Twin Cape"
		CampaignAct.ACT_III_PARADISE_ODYSSEY:
			return "Act III — The Seven Magnetic Paths: Paradise & Skypiea Odyssey"
		CampaignAct.ACT_IV_RED_LINE_ABYSS_CROSSING:
			return "Act IV — 10,000 Meters Under the Red Line: Sabaody & Fish-Man Island"
		CampaignAct.ACT_V_NEW_WORLD_HAZARDS_DRESSROSA_ZOU:
			return "Act V — Into the New World: Punk Hazard, Dressrosa & Zunesha"
		CampaignAct.ACT_VI_FOUR_ROAD_PONEGLYPHS_YONKO_SAGA:
			return "Act VI — The Four Emperors & The Four Deep-Red Road Poneglyphs"
		CampaignAct.ACT_VII_LAUGH_TALE_DAWN_FINALE:
			return "Act VII — Laugh Tale, The Rio Poneglyph & The Dawn of the World"
	return "Unknown Act"
