class_name WestBlueData
extends RefCounted
## West Blue Regional Data Module for Project "Blue Planet" (Godot 4.3+ precision=double).
##
## Manages the West Blue quadrant (theta in [-75 deg, -15 deg], phi in [-90 deg, 0 deg])
## on a planetary sphere of Sea-Level Radius R = 16,000,000.0 meters.
##
## West Blue is characterized by:
##   - The Five Families of the West underworld syndicates (Capone "Gang" Bege, iron fortresses, mob speakeasies)
##   - Ancient archaeological mysteries (Ohara Tree of Knowledge ruins, Buster Call crater, Lake of Knowledge)
##   - Feudal martial nations (Kano Country, Happo Navy, Don Chinjao, Don Sai, Hasshoken vibration martial arts)
##   - Royal Levely kingdoms (Ilusia Kingdom, Ballywood Kingdom)
##   - Cultural music sanctuaries (Esperia Kingdom - Brook's homeland, Toroa - Byron's origin)
##   - Frontier lawless zones & historical voids (Las Camp post-Marineford warzone, God Valley ghost atoll, Thriller Bark origin caldera)
##   - The West Blue approach current toward the Reverse Mountain canal entrance at (lat -0.430, lon -0.395).

# ---------------------------------------------------------------------------
# Geodesic & Planetary Constants (64-bit IEEE 754 Floating-Point)
# ---------------------------------------------------------------------------
const PLANET_RADIUS_M: float = 16_000_000.0
const METERS_PER_DEGREE: float = (TAU * PLANET_RADIUS_M) / 360.0 # ~279,252.68 m/deg

const SECTOR_LAT_MIN: float = -75.0
const SECTOR_LAT_MAX: float = -15.0
const SECTOR_LON_MIN: float = -90.0
const SECTOR_LON_MAX: float = 0.0

const REVERSE_MOUNTAIN_CANAL_ENTRY_LAT: float = -0.430
const REVERSE_MOUNTAIN_CANAL_ENTRY_LON: float = -0.395
const REVERSE_MOUNTAIN_CANAL_ID: StringName = &"west_blue_canal"

# ---------------------------------------------------------------------------
# Master Island & Settlement Dictionary
# ---------------------------------------------------------------------------
const ISLANDS: Dictionary = {
	"ohara": {
		"id": "ohara",
		"name": "Ohara",
		"japanese_name": "オハラ",
		"epithet": "Island of Archaeologists & The Fallen Tree of Knowledge",
		"coordinates": {
			"lat": -42.500,
			"lon": -55.000,
			"alt": 0.0,
		},
		"climate": "Temperate Maritime & Fog-Shrouded Forested Bluffs",
		"biome": "Ancient Deciduous Forest, Scorched Coastal Crater, Lake of Knowledge Lagoon",
		"danger_level": 7,
		"governance": "Extinct / World Government Absolute Exclusion Zone (Post-Buster Call)",
		"factions": [
			"Scholars of Ohara (Martyrs / Historical Legacy)",
			"Cipher Pol Plainclothes Surveillance Unit (CP9/CP0)",
			"Underground Historical Salvagers & Antiquity Divers",
			"Revolutionary Army Intelligence Sympathizers",
		],
		"magnetic_profile": {
			"has_magnetic_field": true,
			"compass_reliable": true,
			"magnetic_anomaly_rating": 0.12,
		},
		"settlements": [
			{
				"id": "ohara_crater_basin",
				"name": "The Great Tree Crater & Sunken Lake",
				"type": "Archaeological Ruin & Historical Sanctuary",
				"population": 15,
				"description": "The massive scorched circular crater gouged out by ten Marine battleships during the Buster Call 22 years ago. In the center stands the hollowed charred stump of the 5,000-year-old Tree of Knowledge rising 80 meters above the Lake of Knowledge.",
			},
			{
				"id": "smugglers_cove_camp",
				"name": "Smuggler's Research Encampment",
				"type": "Covert Coastal Outpost",
				"population": 45,
				"description": "Hidden between jagged basalt sea-stacks on Ohara's northern cliffs, rogue scholars, antiquarians, and black-market divers operate under camouflage nets to avoid World Government reconnaissance snails.",
			},
		],
		"ports": [
			{
				"id": "ohara_ghost_bay",
				"name": "Ghost Bay Anchorage",
				"coordinates": {"lat": -42.485, "lon": -54.980},
				"depth_m": 22.0,
				"facilities": ["Submerged Mooring Rings", "Hidden Scaffolding Wharf", "Diving Crane"],
				"docking_fee_beli": 0,
			},
		],
		"establishments": [
			{
				"id": "smugglers_research_camp",
				"name": "Smuggler's Research Camp",
				"type": "Black Market Antiquities & Diving Depot",
				"proprietor": "Aron the Ink-Stained",
				"services": [
					"Ancient Glyph Translation Inquiries",
					"Deep-Diving Equipment Rental",
					"Waterproof Antiquity Casks",
					"Historical Smuggling Transits",
				],
				"inventory": [
					"burned_library_fragment",
					"weathered_poneglyph_rubbing",
					"ancient_kingdom_lexicon",
					"waterproof_antiquity_lantern",
					"ohara_clover_tea",
					"deep_trench_dredging_hook",
				],
			},
			{
				"id": "memorial_cenotaph_shrine",
				"name": "Cenotaph of Clover & The Martyrs",
				"type": "Silent Memorial & Lore Offering Altar",
				"proprietor": "Echo of Dr. Vegapunk & Dragon",
				"services": [
					"Offering Reverence (Grants 'Scholar's Tenacity' Buff: +25% Ancient Text Decipher Speed)",
					"Reading the Secret Memorial Rubbings",
				],
				"inventory": [],
			},
		],
		"canon_npcs": [
			{
				"id": "clover_legacy",
				"name": "Professor Clover (Legacy Echo & Research Journals)",
				"japanese_name": "クローバー博士",
				"role": "Director of the Library of Ohara & Leading World Archaeologist",
				"status": "Deceased (Martyr of the Buster Call)",
				"lore": "Deduced the true name of the Great Ancient Kingdom before being shot by Spandine. His hidden underground research logs remain sealed in the flooded root vaults beneath the Tree of Knowledge.",
				"dialogue_samples": [
					"History is the shared wealth of all mankind... It cannot be erased simply because it inconveniences the present!",
					"The name of that magnificent ancient civilization was...!",
				],
			},
			{
				"id": "olvia_legacy",
				"name": "Nico Olvia (Historical Testament & Letter)",
				"japanese_name": "ニコ・オルビア",
				"role": "Pioneering Expedition Archaeologist & Mother of Nico Robin",
				"status": "Deceased (Martyr of the Buster Call)",
				"lore": "Sailed with the Ohara archaeological expeditionary crew across the Grand Line before being captured by the World Government. Escaped with Saul's assistance to deliver her findings home.",
				"dialogue_samples": [
					"Robin... Live! As long as you live, the seeds of truth will never die!",
				],
			},
			{
				"id": "saul_ice_marker",
				"name": "Jaguar D. Saul (Giant Footprint & Thawed Ice Marker)",
				"japanese_name": "ハグワール・D・サウロ",
				"role": "Former Marine Vice Admiral & Giant Clan Scholar Ally",
				"status": "Survived (Recovered Ohara Library to Elbaf)",
				"lore": "Washed ashore on Ohara after resigning from the Marines. Protected Nico Robin and was encased in Kuzan's 'Ice Time Capsule'. Later secretly recovered thousands of salvaged tomes with Elbaf giants.",
				"dialogue_samples": [
					"Dereshi! Dereshishi! Laugh when you're hurting, laugh when you're sad! No one in this world is born to be completely alone!",
				],
			},
		],
		"archetype_npcs": [
			{
				"id": "aron_antiquity_broker",
				"name": "Aron the Ink-Stained",
				"role": "Rogue Antiquities Broker & Salvage Diver",
				"dialogue": "Cipher Pol thinks every book burned 22 years ago. But the scholars threw them into the lake. Water preserved what fire tried to consume. If you have the Beli, I have the pages.",
			},
			{
				"id": "cp_shadow_watcher",
				"name": "Cipher Pol Watcher 'Kestrel'",
				"role": "Undercover Plainclothes Assassin & Sentry",
				"dialogue": "This island is under perpetual World Government quarantine. Turn your ship around, sailor, or your name will be added to the non-existent passenger logs.",
			},
		],
		"specialties": [
			"Burned Library Volumes of the Void Century",
			"Oharan Comparative Linguistic Ciphers",
			"Deep-Lake Waterproof Tomes",
			"Clover Blossom Infusion Tea",
		],
		"lore_and_secrets": [
			"The submerged Lake of Knowledge still contains waterproof wax-bound books trapped in root crevices 30 meters down.",
			"A subterranean drainage tunnel leads directly into Clover's secret study under the tree roots, bypassing Marine shore patrols.",
			"Dr. Vegapunk and Monkey D. Dragon met here after the Buster Call, laying the ideological foundation for the Revolutionary Army.",
		],
		"exploration_hooks": [
			{
				"id": "hook_lake_diving",
				"title": "Sunken Codices of the Lake of Knowledge",
				"target_item": "ancient_kingdom_lexicon",
				"reward_beli": 120_000,
				"description": "Equip deep diving gear and navigate the submerged root maze beneath the Tree stump to recover an intact Void Century comparative dictionary before Cipher Pol patrols dynamite the basin.",
			},
			{
				"id": "hook_saul_ice_relic",
				"title": "Cryogenic Traces of the Ice Time Capsule",
				"target_location": "ohara_beach_shoreline",
				"reward_beli": 80_000,
				"description": "Survey the crystalline permafrost patch where Vice Admiral Kuzan froze Saul 22 years ago to collect an intact Giant Navy Log Fragment.",
			},
		],
		"connected_routes": ["route_scholars_trail", "route_reverse_mountain_ascent"],
	},

	"kano_country": {
		"id": "kano_country",
		"name": "Kano Country (Flower Country)",
		"japanese_name": "花ノ国",
		"epithet": "Empire of Pagodas, Jewel Drills & The Eight Impacts",
		"coordinates": {
			"lat": -28.000,
			"lon": -40.000,
			"alt": 0.0,
		},
		"climate": "Subtropical Continental with Terraced Mountain Valleys",
		"biome": "Towering Karst Limestone Pinnacles, Bamboo Forests, Terraced Lotus Canals, Imperial Pagoda Citadel",
		"danger_level": 6,
		"governance": "Imperial Monarchy (World Government Member Nation)",
		"factions": [
			"Kano Royal Court (King Ramen)",
			"Happo Navy (8th Official Kano Navy - Chinjao Family)",
			"Nihappo Navy (28th Official Kano Navy - Uholisia Clan)",
			"Hasshoken Martial Monks & Smiths",
		],
		"magnetic_profile": {
			"has_magnetic_field": true,
			"compass_reliable": true,
			"magnetic_anomaly_rating": 0.08,
		},
		"settlements": [
			{
				"id": "joya_capital_citadel",
				"name": "Joya Imperial Harbor & Citadel",
				"type": "Fortified Sovereign Capital Port",
				"population": 380000,
				"description": "A magnificent metropolis built across tiered river terraces, adorned with vermilion pagodas, jade lion archways, and vast lotus canals where armed dragon-prow ramming galleys dock.",
			},
			{
				"id": "chinjao_family_compound",
				"name": "Chinjao Family Grand Dojo & Armory",
				"type": "Hasshoken Training Sanctuary",
				"population": 1200,
				"description": "The mountainous dojo compound where hundreds of Happo Navy sailors train daily to master Hasshoken vibrational shockwaves by punching steel slabs and split boulders.",
			},
		],
		"ports": [
			{
				"id": "happo_dragon_basin",
				"name": "Happo Navy Imperial Naval Basin",
				"coordinates": {"lat": -27.980, "lon": -39.970},
				"depth_m": 35.0,
				"facilities": [
					"Heavy Dragon-Prow Drydock",
					"Jade-Bronze Ram Foundry",
					"Armored Timber Crane",
					"Military Provision Silos",
				],
				"docking_fee_beli": 15000,
			},
		],
		"establishments": [
			{
				"id": "chinjao_martial_bazaar",
				"name": "Chinjao Grand Martial Bazaar",
				"type": "Martial Weapons, Armor & Combat Manuals",
				"proprietor": "Don Chinjao & Master Zhou",
				"services": [
					"Hasshoken Shockwave Weapon Tuning",
					"Bisen Naginata Forging",
					"Haki Resistance Sparring",
					"Dragon-Prow Hull Reinforcement",
				],
				"inventory": [
					"hasshoken_vibration_scroll",
					"reinforced_bisen_naginata",
					"happo_dragon_prow_keel",
					"jewel_jade_bullion",
					"kano_lotus_baijiu",
					"explosive_firework_rockets",
					"padded_silk_brigandine",
				],
			},
			{
				"id": "king_ramen_tea_pavilion",
				"name": "Imperial Lotus Teahouse",
				"type": "Royal Diplomatic Tea Pavilion & Tavern",
				"proprietor": "Grand Chamberlain Shen",
				"services": [
					"Diplomatic Levely Gossip & World News",
					"Kano Imperial Banquet Rations",
					"Beli Currency Exchange & Bond Issuance",
				],
				"inventory": [
					"kano_lotus_baijiu",
					"steamed_peony_dumplings",
					"imperial_jasmine_brick",
				],
			},
		],
		"canon_npcs": [
			{
				"id": "don_chinjao",
				"name": "Don Chinjao (The Drill)",
				"japanese_name": "首領・チンジャオ",
				"role": "12th Leader of the Happo Navy / Legend of Hasshoken",
				"bounty_beli": 542_000_000,
				"status": "Retired Grand Master (Active Patriarch)",
				"lore": "Legendary pirate who split the frozen Jewel Ice Sheet with his drill-shaped head. After Garp flattened his head 30 years ago, he held a bitter vendetta until Luffy restored his drill at Dressrosa.",
				"dialogue_samples": [
					"My Hasshoken shockwaves shatter armor from within! Even steel cannot resist the frequency of true impact!",
					"The wealth of the Chinjao Family was sealed beneath the eternal ice... until my drill split the continent!",
				],
			},
			{
				"id": "don_sai",
				"name": "Don Sai",
				"japanese_name": "サイ",
				"role": "13th Leader of the Happo Navy / 3rd Ship Captain of Straw Hat Grand Fleet",
				"bounty_beli": 210_000_000,
				"status": "Active Leader",
				"lore": "Master of the Hasshoken martial art who surpassed his grandfather by bending Chinjao's drill with his 'Kiryukiriko' kick. Married Baby 5 and pledged the Happo Navy's loyalty to Monkey D. Luffy.",
				"dialogue_samples": [
					"From this day forth, the 13th leader of the Happo Navy answers to no corrupt kings or underworld smugglers!",
					"If you threaten our brother crews, I'll carve you into kindling with this naginata!",
				],
			},
			{
				"id": "boo_vice_leader",
				"name": "Boo",
				"japanese_name": "ブー",
				"role": "Vice Leader of the Happo Navy",
				"status": "Active Vice Leader",
				"lore": "Sai's brother and formidable combatant wielding twin battle-axes combined with Hasshoken shockwave defensive shields.",
				"dialogue_samples": [
					"Sai's orders are absolute. If you plan to sail West Blue waters under our flag, pay your dues at the basin!",
				],
			},
			{
				"id": "baby_5_matriarch",
				"name": "Baby 5 (Chinjao Family Matriarch)",
				"japanese_name": "ベビー5",
				"role": "Former Donquixote Officer / Happo Navy Heavy Ordnance Specialist",
				"status": "Active",
				"lore": "Eater of the Arms-Arms Fruit (Buki Buki no Mi). Married Don Sai after he vowed to need and protect her. Can transform into Gatling cannons, anti-ship missiles, and sickle blades.",
				"dialogue_samples": [
					"Do you... do you need me?! If you need heavy bombardment for your flagship, just ask!",
				],
			},
			{
				"id": "king_ramen",
				"name": "King Ramen",
				"japanese_name": "ラーメン王",
				"role": "Sovereign Monarch of Kano Country",
				"status": "Active Monarch",
				"lore": "World Government sovereign who attended the Levely. Has a distinctive tall bald head with an imperial dragon tattoo and Fu Manchu mustache. Distrusts underworld brokers.",
				"dialogue_samples": [
					"The peace of Kano Country must not be tainted by pirate rabble or New World arms smugglers!",
				],
			},
		],
		"archetype_npcs": [
			{
				"id": "master_smith_lu",
				"name": "Master Artisan Lu",
				"role": "Happo Dragon-Prow Foundry Master",
				"dialogue": "A ship without a reinforced ram is just floating timber waiting to be splintered. We forge our dragon-prows from folded high-tensile iron and bronze leaf.",
			},
			{
				"id": "monk_zhao",
				"name": "Instructor Zhao of the Eight Impacts",
				"role": "Hasshoken Basic Forms Trainer",
				"dialogue": "Do not strike the surface. Push your spirit through the target until the opposite side ruptures. That is the first lesson of Hasshoken.",
			},
		],
		"specialties": [
			"Happo Navy Armored Dragon-Prow Galleys",
			"Hasshoken Vibration Combat Manuals",
			"Jewel Jade Bullion & Ornamental Carvings",
			"Lotus Blossom Baijiu Spirits",
			"High-Grade Terraced Peony Tea",
		],
		"lore_and_secrets": [
			"Underworld arms shipments from Doflamingo's factory in Dressrosa secretly fueled a proxy civil conflict against neighboring nations.",
			"The vault of the Jewel Ice Sheet contains over 100 billion Beli in unminted gold, gemstones, and Void Century relics.",
			"The Happo Navy possesses ancient naval charts indicating a calm-water passage along the West Blue Calm Belt boundary.",
		],
		"exploration_hooks": [
			{
				"id": "hook_hasshoken_trial",
				"title": "Trial of the Shattered Monolith",
				"target_location": "chinjao_family_compound",
				"reward_beli": 180_000,
				"description": "Prove your martial mastery to Don Chinjao by shattering a 5-meter reinforced granite obelisk using vibrational shockwave techniques.",
			},
			{
				"id": "hook_smuggled_ordnance",
				"title": "Intercepting Joker's Ghost Arsenal",
				"target_location": "joya_outer_reef",
				"reward_beli": 240_000,
				"description": "Track and seize a disguised cargo galleon delivering illegal Donquixote arms to rogue warlords before they destabilize Kano's borders.",
			},
		],
		"connected_routes": ["route_five_families_run", "route_martial_convoy"],
	},

	"ilusia_kingdom": {
		"id": "ilusia_kingdom",
		"name": "Ilusia Kingdom (Ilisia)",
		"japanese_name": "イロシア王国",
		"epithet": "Kingdom of Bastioned Cathedrals & Diplomatic Parley",
		"coordinates": {
			"lat": -34.500,
			"lon": -22.000,
			"alt": 0.0,
		},
		"climate": "Cool Maritime Temperate with Crisp Coastal Breezes",
		"biome": "Granite Sea-Cliffs, Tiered Cobblestone Ramparts, Gothic Clocktowers, Orderly Vineyard Terraces",
		"danger_level": 4,
		"governance": "Constitutional Monarchy (World Government Member Nation)",
		"factions": [
			"House of Lucas / House of Seki (Ilusian Royalty)",
			"Ilusian Royal Carabineers & Marine Garrison",
			"Underground Revolutionary Cell (Morley Sympathizers)",
			"Guild of Horologists & Navigational Smiths",
		],
		"magnetic_profile": {
			"has_magnetic_field": true,
			"compass_reliable": true,
			"magnetic_anomaly_rating": 0.05,
		},
		"settlements": [
			{
				"id": "thalassa_capital_harbor",
				"name": "Port Thalassa & Royal Promenade",
				"type": "Diplomatic Citadel & Deepwater Port",
				"population": 220000,
				"description": "The regal capital of Ilusia, featuring soaring Gothic spires, marble clocktowers, and a sheltered deepwater harbor capable of berthing triple-deck Royal Escort vessels.",
			},
		],
		"ports": [
			{
				"id": "grand_fleur_dock",
				"name": "The Grand Fleur Royal Docks",
				"coordinates": {"lat": -34.480, "lon": -21.980},
				"depth_m": 28.0,
				"facilities": [
					"Precision Drydock",
					"Chronometer Calibration Tower",
					"Royal Customs Bureau",
					"Grand Line Provision Wharf",
				],
				"docking_fee_beli": 8000,
			},
		],
		"establishments": [
			{
				"id": "clocktower_chronometers",
				"name": "Gaston's Maritime Horology & Navigation",
				"type": "Precision Navigational Tools & Clocks",
				"proprietor": "Master Horologist Gaston",
				"services": [
					"Navigational Chronometer Calibration",
					"Sextant Mirror Realignment",
					"Waterproof Pocket Watch Repair",
				],
				"inventory": [
					"precision_chronometer",
					"ilusia_brass_flintlock",
					"royal_fleur_wine",
					"gilded_breastplate",
					"levely_sea_pass_forged",
					"salted_provisions_30d",
				],
			},
			{
				"id": "golden_fleur_tavern",
				"name": "The Golden Fleur Inn & Diplomatic Lounge",
				"type": "Royal Tavern & Intelligence Hub",
				"proprietor": "Madame Vivienne",
				"services": [
					"Fine Ilusian Dining & Vintage Wines",
					"Noble Gossip & Diplomatic Manifests",
					"Safehouse Lodging for Disguised Travelers",
				],
				"inventory": [
					"royal_fleur_wine",
					"salted_provisions_30d",
				],
			},
		],
		"canon_npcs": [
			{
				"id": "thalassa_lucas",
				"name": "Thalassa Lucas",
				"japanese_name": "タラッサ・ルーカス",
				"role": "Former King of Ilusia / Senior Statesman",
				"status": "Active Elder Diplomat",
				"lore": "Attended the Levely in Mary Geoise 8 years ago and made the prophetic speech warning world monarchs of Monkey D. Dragon and the rising Revolutionary threat.",
				"dialogue_samples": [
					"Do not mock the name of Dragon! In five or six years, that man's ideology will become the greatest menace the World Government has ever faced!",
					"A throne without foresight is merely kindling for the revolutionary pyre.",
				],
			},
			{
				"id": "king_seki",
				"name": "King Seki",
				"japanese_name": "セキ王",
				"role": "Current Reigning Monarch of Ilusia",
				"status": "Active King",
				"lore": "Arrogant, luxury-obsessed king who attended the recent Levely. His exorbitant taxation policies sparked widespread citizen unrest and Revolutionary sympathy throughout Ilusia.",
				"dialogue_samples": [
					"My royal tribute to the Celestial Dragons must not be delayed! Tax the artisans another twenty percent!",
				],
			},
		],
		"archetype_npcs": [
			{
				"id": "marie_revolutionary",
				"name": "Marie of the Cobblestones",
				"role": "Covert Revolutionary Army Courier",
				"dialogue": "King Seki drinks wine from gold goblets while harbor laborers starve on cabbage water. Morley's West Blue comrades are organizing... Soon the spires will hear our song.",
			},
			{
				"id": "captain_valerie",
				"name": "Captain Valerie of the Carabineers",
				"role": "Royal Guard Chief of Security",
				"dialogue": "Keep your blades sheathed in the Grand Promenade. Foreign sailors are tolerated for commerce, but pirate rabble will find themselves in the sea-dungeons.",
			},
		],
		"specialties": [
			"Precision Maritime Chronometers & Astrolabes",
			"Brass-Inlaid Royal Flintlock Carbines",
			"Grand Fleur Aged Vintage Wines",
			"Diplomatic Transit Papers & World Government Decrees",
		],
		"lore_and_secrets": [
			"Beneath the royal palace lies an escape aqueduct constructed by giant hands over a century ago, suspected to be the work of Morley.",
			"Thalassa Lucas keeps an encrypted personal journal recording secret alliances between Levely kings who fear the Celestial Dragons.",
		],
		"exploration_hooks": [
			{
				"id": "hook_revolutionary_cache",
				"title": "Smuggling the Freedom Pamphlets",
				"target_location": "thalassa_catacombs",
				"reward_beli": 95_000,
				"description": "Assist Marie in moving a printing press and revolutionary tracts past King Seki's royal carabineers to an offshore fishing vessel.",
			},
		],
		"connected_routes": ["route_five_families_run", "route_scholars_trail"],
	},

	"ballywood_kingdom": {
		"id": "ballywood_kingdom",
		"name": "Ballywood Kingdom",
		"japanese_name": "バリウッド王国",
		"epithet": "Empire of Meatpacking, Brass Bands & Stovepipe Splendor",
		"coordinates": {
			"lat": -22.000,
			"lon": -62.000,
			"alt": 0.0,
		},
		"climate": "Warm Humid Temperate with Industrious Smoky Haze",
		"biome": "Broad Neo-Classical Marble Avenues, Brick Smokehouse Districts, Broadway Gaslit Theaters, Rail Harbors",
		"danger_level": 3,
		"governance": "Electoral Senate & Constitutional Monarchy (World Government Member)",
		"factions": [
			"The Ballywood Executive Senate (King Ham Burger)",
			"Grand Meatpackers & Smokehouse Guild",
			"Broadway Theatrical & Vaudeville Syndicate",
			"West Blue Maritime Steam & Whistle Works",
		],
		"magnetic_profile": {
			"has_magnetic_field": true,
			"compass_reliable": true,
			"magnetic_anomaly_rating": 0.04,
		},
		"settlements": [
			{
				"id": "hamburger_metropolis",
				"name": "Liberty City & Theater District",
				"type": "Industrialized Metropolis & Port",
				"population": 520000,
				"description": "A booming metropolis modeled after 19th-century Americana, filled with gaslit theater marquees, bustling meat markets, star-spangled banners, and iron steam paddlewheels.",
			},
		],
		"ports": [
			{
				"id": "star_spangled_wharf",
				"name": "The Great Star-Spangled Wharf",
				"coordinates": {"lat": -21.980, "lon": -61.980},
				"depth_m": 24.0,
				"facilities": [
					"Industrial Steam Cargo Cranes",
					"Cold-Storage Meat Lockers",
					"Coal & Boiler Bunkering",
					"High-Capacity Provision Conveyors",
				],
				"docking_fee_beli": 10000,
			},
		],
		"establishments": [
			{
				"id": "uncle_hams_saloon",
				"name": "Uncle Ham's Grand Smokehouse & Grill",
				"type": "Tavern, Smokehouse & Voyager Provisions",
				"proprietor": "Pitmaster Bob",
				"services": [
					"High-Calorie Stamina Meat Feasts (Restores 100% Party Energy)",
					"Smoked Voyage Provisions (Long Shelf-Life)",
					"Theater Show Tickets & Rumor Mill",
				],
				"inventory": [
					"ballywood_smoked_shank",
					"stovepipe_top_hat",
					"steam_whistle_horn",
					"stage_micro_horn",
					"ballywood_printing_stamp",
					"boiler_iron_rivets",
				],
			},
		],
		"canon_npcs": [
			{
				"id": "king_ham_burger",
				"name": "King Ham Burger",
				"japanese_name": "ハム・バーガー王",
				"role": "King of Ballywood Kingdom & Levely Council Chairman",
				"status": "Active Monarch",
				"lore": "Satirical monarch modeled after Abraham Lincoln and Uncle Sam, wearing a tall star-patterned top hat. Chaired the Levely summit in Mary Geoise and champions industrial progress and commercial prosperity.",
				"dialogue_samples": [
					"Four score and seven nautical miles ago, our forefathers founded this great union of commerce and smoked meat!",
					"Order! Order in the Levely chamber! Let the monarchs speak of trade, not ancient phantoms!",
				],
			},
		],
		"archetype_npcs": [
			{
				"id": "madame_clara_broadway",
				"name": "Madame Clara",
				"role": "Director of the Ballywood Revue & Scout",
				"dialogue": "Got a singing skeleton or a fire-eating martial artist on your crew? Bring them to the stage! Ballywood pays top Beli for real maritime drama!",
			},
			{
				"id": "pitmaster_bob",
				"name": "Bob 'Smokestack' Miller",
				"role": "Master Butcher & Provisioner",
				"dialogue": "You can't cross Reverse Mountain on hardtack and ditch-water. Take ten crates of hickory-smoked prime shank, and your sailors will haul canvas through any gale.",
			},
		],
		"specialties": [
			"Ballywood Hickory-Smoked Prime Beef Shanks",
			"Star-Spangled Stovepipe Top Hats",
			"Industrial High-Pressure Steam Whistles",
			"Broadway Stage Sound Amplifiers & Micro-Horns",
			"High-Tensile Ship Boiler Rivets",
		],
		"lore_and_secrets": [
			"Ballywood maintains secret contracts with the Five Families to transport cured provisions under forged commercial shipping manifests.",
			"King Ham Burger possesses an ironclad personal riverboat equipped with triple steam-powered Gatling volleys.",
		],
		"exploration_hooks": [
			{
				"id": "hook_broadway_audition",
				"title": "The Grand Ballywood Revue",
				"target_location": "hamburger_metropolis",
				"reward_beli": 110_000,
				"description": "Perform an authentic West Blue sea shanty on the main stage of the Grand Opera to earn the coveted Golden Top Hat and the sponsor purse.",
			},
		],
		"connected_routes": ["route_five_families_run"],
	},

	"esperia_kingdom": {
		"id": "esperia_kingdom",
		"name": "Esperia Kingdom",
		"japanese_name": "エスペリア王国",
		"epithet": "Sanctuary of Luthiers, Fencing Convoys & Melodic Steel",
		"coordinates": {
			"lat": -52.000,
			"lon": -45.000,
			"alt": 0.0,
		},
		"climate": "Cool Subalpine Maritime with Morning River Mists",
		"biome": "Deep Resonant Spruce & Maple Forests, Cobblestone Fjord Towns, Waterwheel Sawmills, Royal Training Grounds",
		"danger_level": 5,
		"governance": "Constitutional Monarchy with Military Battle Convoy Guilds",
		"factions": [
			"Royal Fencing Convoy Guards (Brook's former military unit)",
			"Master Luthiers Guild of Esperia",
			"Minstrel Guild & Bards of Binks",
			"Resonant Tone-Wood Foresters",
		],
		"magnetic_profile": {
			"has_magnetic_field": true,
			"compass_reliable": true,
			"magnetic_anomaly_rating": 0.07,
		},
		"settlements": [
			{
				"id": "allegro_haven",
				"name": "Port Allegro & The Violin Guild",
				"type": "Artisan Harbor & Fjord Township",
				"population": 95000,
				"description": "A picturesque fjord city nestled beneath steep pine-clad mountains, renowned worldwide for watermill sawmills producing the finest acoustic resonance spruce and violin workshops.",
			},
			{
				"id": "convoy_bastion",
				"name": "The Royal Convoy Barracks",
				"type": "Fencing Academy & Cavalry Redoubt",
				"population": 3500,
				"description": "The martial grounds where Brook once trained and commanded the royal battle convoys over fifty years ago, preserving swift fencing thrusts and cane-sword fencing styles.",
			},
		],
		"ports": [
			{
				"id": "clef_harbor",
				"name": "Golden Clef Harbor",
				"coordinates": {"lat": -51.980, "lon": -44.970},
				"depth_m": 26.0,
				"facilities": [
					"Acoustic Timber Docks",
					"Sail-Loft & Instrument Luthier Berths",
					"Fresh Mountain Spring Cisterns",
					"Master Carpenter Slips",
				],
				"docking_fee_beli": 7000,
			},
		],
		"establishments": [
			{
				"id": "stradivari_luthier_atelier",
				"name": "Stradivari Luthier Guild Atelier",
				"type": "Musical Instruments, Cane-Swords & Tone-Wood",
				"proprietor": "Grand Luthier Vivaldi",
				"services": [
					"Masterwork Violin & Bow Crafting",
					"Concealed Cane-Sword Fencing Blade Forging",
					"Acoustic Ship Cabin Soundproofing",
					"Sheet Music Transcription",
				],
				"inventory": [
					"esperian_violin",
					"concealed_cane_sword",
					"resonant_tone_wood",
					"binks_sake_sheet_music",
					"minstrel_frock_coat",
					"fencing_rosin_polish",
				],
			},
			{
				"id": "binks_rest_tavern",
				"name": "Binks' Rest Minstrel Hall",
				"type": "Tavern, Concert Hall & Sailor Parley",
				"proprietor": "Songstress Shuri",
				"services": [
					"Minstrel Song Performance (Boosts Crew Morale & Speed by 15%)",
					"Rumbar Pirate Legend Lore",
					"West Blue Vintage Cask Ale",
				],
				"inventory": [
					"binks_sake_sheet_music",
					"minstrel_frock_coat",
				],
			},
		],
		"canon_npcs": [
			{
				"id": "brook_legacy",
				"name": "Brook (Memory of the Convoy Leader)",
				"japanese_name": "ブルック",
				"role": "Former Royal Battle Convoy Leader / Musician of the Straw Hat Pirates",
				"bounty_beli": 383_000_000,
				"status": "Active Pirate (Grand Line)",
				"lore": "Born in West Blue, Brook commanded the royal battle convoy in Esperia over 52 years ago before joining the Rumbar Pirates under Captain Yorki. His signature fencing style 'Requiem la Banderole' was forged here.",
				"dialogue_samples": [
					"Yo-ho-ho-ho! Delivering Binks' sake through the sea spray! Even after death, my bones remember the fencing tempo of my homeland!",
				],
			},
		],
		"archetype_npcs": [
			{
				"id": "luthier_vivaldi",
				"name": "Grand Luthier Vivaldi",
				"role": "Master Artisan of Esperian Violins",
				"dialogue": "A violin made from Esperian spruce does not merely vibrate; it sings with the voice of the mountain wind. Treat the wood with respect, and your melody can charm even sea monsters.",
			},
			{
				"id": "fencing_master_lemaire",
				"name": "Swordsman Lemaire",
				"role": "Chief Fencing Instructor of the Convoy Guard",
				"dialogue": "Heavy chopping blades are for barbarians. The true soul of Esperian swordsmanship is the fencing thrust: faster than the eye, lighter than a swallow's wing.",
			},
		],
		"specialties": [
			"Masterwork Esperian Spruce Violins & Cellos",
			"Concealed Cane-Swords (Shikomizue Rapiers)",
			"Resonant Tone-Wood Planks for Ship Soundboards",
			"Authentic West Blue 'Binks' Sake' Musical Notations",
			"Fencing Frock Coats & Polished Leather Boots",
		],
		"lore_and_secrets": [
			"In the high spruce forest stands the old memorial cottage where the Rumbar Pirates held their final banquet before sailing toward Reverse Mountain.",
			"The Royal Convoy archives preserve Brook's original military fencing treatise detailing the 'Hanauta Sancho: Yahazu Giri' mechanics.",
		],
		"exploration_hooks": [
			{
				"id": "hook_resonant_timber",
				"title": "Harvesting the Singing Spruce",
				"target_location": "esperia_high_peaks",
				"reward_beli": 135_000,
				"description": "Climb into the mist-shrouded high peaks to harvest a fallen 300-year-old resonant spruce log without damaging its acoustic grain.",
			},
		],
		"connected_routes": ["route_scholars_trail"],
	},

	"toroa": {
		"id": "toroa",
		"name": "Toroa",
		"japanese_name": "トロア",
		"epithet": "Haven of Flute Dynasties & Coastal Melodies",
		"coordinates": {
			"lat": -60.000,
			"lon": -30.000,
			"alt": 0.0,
		},
		"climate": "Cool Coastal Mediterranean with Sea Mist",
		"biome": "White Limestone Sea-Cliffs, Marble Tiered Amphitheaters, Reed Lagoons, Flute Workshops",
		"danger_level": 4,
		"governance": "Civic Council of Guildmasters (World Government Affiliated)",
		"factions": [
			"Toroa Guild of Musicians & Woodwind Crafters",
			"Underground Human Trafficking Resistance (Byron Kinfolk)",
			"Coastal Whalewatcher Watchers",
		],
		"magnetic_profile": {
			"has_magnetic_field": true,
			"compass_reliable": true,
			"magnetic_anomaly_rating": 0.06,
		},
		"settlements": [
			{
				"id": "toroa_amphitheater_town",
				"name": "Toroa Haven",
				"type": "Coastal Musical Settlement",
				"population": 72000,
				"description": "Built around natural limestone amphitheatres facing the ocean, where the wind whistling through sea-caves produces constant musical harmonies. Famous for families of master woodwind players.",
			},
		],
		"ports": [
			{
				"id": "silverwind_wharf",
				"name": "Silverwind Harbor",
				"coordinates": {"lat": -59.980, "lon": -29.980},
				"depth_m": 20.0,
				"facilities": ["Sheltered Basin", "Soundproofing Drydock", "Flute Craft Shops"],
				"docking_fee_beli": 5000,
			},
		],
		"establishments": [
			{
				"id": "silverwind_flutes",
				"name": "Silverwind Woodwind Atelier",
				"type": "Wind Instruments & Marine Harps",
				"proprietor": "Master Flautist Corren",
				"services": [
					"Silverwind Concert Flute Carving",
					"Mother-of-Pearl Sea Harp Tuning",
					"Acoustic Marine Beast Taming Lessons",
				],
				"inventory": [
					"silverwind_concert_flute",
					"sea_harp",
					"toroa_reed_pipes",
					"acoustic_felt_padding",
					"tuning_fork",
				],
			},
		],
		"canon_npcs": [
			{
				"id": "byron_lore",
				"name": "Byron (Memorial & Slave Rescue Hook)",
				"japanese_name": "バイロン",
				"role": "Pirate Musician from Toroa / Sabaody Auction Victim",
				"bounty_beli": 4_000_000,
				"status": "Liberated (Post-Sabaody Celestial Chaos)",
				"lore": "Hails from a multi-generational family of Toroa musicians. Known for his virtuoso flute and instrument mastery before being captured by slavers and auctioned at Grove 1.",
				"dialogue_samples": [
					"In Toroa, our family breathed music like the sea breeze... Slavers can chain my hands, but they cannot silence my melodies!",
				],
			},
		],
		"archetype_npcs": [
			{
				"id": "flautist_corren",
				"name": "Master Corren",
				"role": "Byron's Uncle & Senior Woodwind Master",
				"dialogue": "When played at the correct pitch, this silverwind flute emits a frequency that pacifies agitated sea boars and migratory Island Whales. Try it when crossing the outer reefs.",
			},
		],
		"specialties": [
			"Silverwind Concert Flutes (Beast Pacification)",
			"Mother-of-Pearl Inlaid Sea Harps",
			"Toroa Reed-Pipes",
			"Acoustic Soundproofing Felt",
		],
		"lore_and_secrets": [
			"Toroa's sea caves resonate with natural wind harmonics that can be heard 10 nautical miles out to sea, serving as an acoustic lighthouse.",
			"Five Families trafficking syndicates frequently attempt to press-gang Toroa musicians to sell to corrupt nobility at Sabaody.",
		],
		"exploration_hooks": [
			{
				"id": "hook_whale_song",
				"title": "Echo of the Island Whales",
				"target_location": "toroa_echo_caves",
				"reward_beli": 75_000,
				"description": "Perform an acoustic melody inside Toroa's tidal caves during high tide to summon a pod of migrating young Island Whales.",
			},
		],
		"connected_routes": ["route_scholars_trail"],
	},

	"las_camp": {
		"id": "las_camp",
		"name": "Las Camp (Lascamp)",
		"japanese_name": "ラスキャンプ",
		"epithet": "The Frontier Badlands & Post-War Warzone",
		"coordinates": {
			"lat": -48.000,
			"lon": -72.000,
			"alt": 0.0,
		},
		"climate": "Arid Windy Scrubland with Desert Heat Waves",
		"biome": "Red Canyon Mesas, Dusty Frontier Shanty Ports, Fortified Saloons, Scorched Marine Bastions",
		"danger_level": 8,
		"governance": "Contested Lawless Frontier (Post-Marineford Pirate Uprising)",
		"factions": [
			"West Blue Pirate Insurgency (Post-Marineford Rookie Surge)",
			"Besieged 147th Marine Garrison (Sheriff Vance)",
			"Red Mesa Bounty Hunters & Outlaw Mercenaries",
			"Black-Market Munitions Syndicate",
		],
		"magnetic_profile": {
			"has_magnetic_field": true,
			"compass_reliable": true,
			"magnetic_anomaly_rating": 0.09,
		},
		"settlements": [
			{
				"id": "red_mesa_shanty",
				"name": "Red Rock Basin & Outlaw Haven",
				"type": "Frontier Port & Smuggler Shantytown",
				"population": 42000,
				"description": "A lawless settlement sprawling beneath towering red mesas, where pirate crews clashed openly after Whitebeard's death plunged the West Blue into chaos. Saloons, gunsmiths, and mercenary stables dominate the streets.",
			},
		],
		"ports": [
			{
				"id": "dusty_anchor_wharf",
				"name": "Dusty Anchor Anchorage",
				"coordinates": {"lat": -47.980, "lon": -71.970},
				"depth_m": 18.0,
				"facilities": ["Reinforced Palisade Berth", "Black-Powder Magazine", "Mount Corrals"],
				"docking_fee_beli": 3000,
			},
		],
		"establishments": [
			{
				"id": "red_mesas_cantina",
				"name": "The Red Mesas Cantina & Duelling Saloon",
				"type": "Saloon, Black-Market Munitions & Bounty Board",
				"proprietor": "Rosa the Quick-Draw",
				"services": [
					"Bounty Hunting Claims & Payouts",
					"Heavy Gunpowder & Dynamite Supplies",
					"Desert Mount Rentals",
					"High-Proof Firewater Tequila",
				],
				"inventory": [
					"heavy_caliber_revolver",
					"canyon_sand_goggles",
					"nitroglycerin_dynamite",
					"las_camp_firewater",
					"iron_riding_saddle",
					"outlaw_bounty_roster",
				],
			},
		],
		"canon_npcs": [],
		"archetype_npcs": [
			{
				"id": "sheriff_vance",
				"name": "Sheriff Vance",
				"role": "Besieged Marine Garrison Captain",
				"dialogue": "When Whitebeard fell at Marineford, every gutter rat in Las Camp declared themselves the next pirate king. We are holding the line at the palisade, but we need ammunition, not Marineford press releases.",
			},
			{
				"id": "rosa_cantina",
				"name": "Rosa the Quick-Draw",
				"role": "Cantina Mistress & Info Broker",
				"dialogue": "If you're drawing iron, make it fast. Blood cleans off mahogany tables, but gunpowder ruins the whiskey.",
			},
		],
		"specialties": [
			"Heavy Caliber Fast-Draw Revolvers",
			"High-Explosive Nitroglycerin Mining Sticks",
			"Las Camp Agave Firewater",
			"Canyon Sand Goggles & Weathered Ponchos",
		],
		"lore_and_secrets": [
			"Following the Summit War of Marineford, news of Whitebeard's demise triggered island-wide riots here as reported in Chapter 582.",
			"An abandoned iron mine in the northern red canyon conceals an unexploded Marine seismic ordnance cache.",
		],
		"exploration_hooks": [
			{
				"id": "hook_frontier_defense",
				"title": "Siege of the Red Palisade",
				"target_location": "red_mesa_shanty",
				"reward_beli": 200_000,
				"description": "Defend the battered frontier garrison from a 3-wave assault by rogue pirate raiding galleys during the post-Marineford turbulence.",
			},
		],
		"connected_routes": ["route_outlaw_frontier"],
	},

	"castello_del_capone": {
		"id": "castello_del_capone",
		"name": "Castello Del Capone (Iron Fort Island)",
		"japanese_name": "カポネ城塞島",
		"epithet": "Capital of the Five Families & The Iron Mob Citadel",
		"coordinates": {
			"lat": -38.000,
			"lon": -15.000,
			"alt": 0.0,
		},
		"climate": "Rainy Industrial Maritime with Heavy Coal Smog",
		"biome": "Black Granite Sea-Fortress, Wet Cobblestone Alleys, Iron Gun-Ports, Speakeasy Cellars",
		"danger_level": 7,
		"governance": "Underworld Syndicate Hegemony (The Five Families of the West)",
		"factions": [
			"Fire Tank Syndicate (Capone 'Gang' Bege's West Blue Base)",
			"The Five Families of the West (Godai Toubatsu)",
			"Underworld Arms Smugglers & Black Marketeers",
			"Corrupt Marine Collaborators",
		],
		"magnetic_profile": {
			"has_magnetic_field": true,
			"compass_reliable": true,
			"magnetic_anomaly_rating": 0.11,
		},
		"settlements": [
			{
				"id": "fortezza_capone",
				"name": "Fortezza Capone & Speakeasy Quarter",
				"type": "Heavily Fortified Syndicate Metropolis",
				"population": 180000,
				"description": "A dark, ironclad city surrounded by massive stone sea-walls and artillery bastions. This was the undisputed criminal seat of Capone 'Gang' Bege before he took to the sea as a pirate Supernova.",
			},
		],
		"ports": [
			{
				"id": "nostra_castello_berth",
				"name": "Nostra Castello Submerged Mooring",
				"coordinates": {"lat": -37.980, "lon": -14.980},
				"depth_m": 32.0,
				"facilities": [
					"Armored Iron Docks",
					"Submarine Wet-Dock",
					"Artillery Munitions Gantry",
					"Concealed Smuggler Sluice",
				],
				"docking_fee_beli": 25000,
			},
		],
		"establishments": [
			{
				"id": "godfathers_speakeasy",
				"name": "The Godfather's Speakeasy & Arsenal",
				"type": "Speakeasy, Ballistic Armory & Munitions Depot",
				"proprietor": "Underboss Don Vincenzo",
				"services": [
					"Tommy-Gun Rapid-Fire Firearms Supply",
					"Ballistic-Weave Pinstripe Armor Tailoring",
					"Underworld Money Laundering & Beli Transfer",
					"Mafia Hit Contracts & Protection Pacts",
				],
				"inventory": [
					"tommy_gun_flintlock",
					"pinstripe_ballistic_suit",
					"west_blue_cigar_box",
					"wrist_dagger_sleeve",
					"lead_lined_contraband_chest",
					"iron_fortress_blueprints",
					"marine_transit_manifest_forged",
				],
			},
		],
		"canon_npcs": [
			{
				"id": "capone_bege_legacy",
				"name": "Capone 'Gang' Bege (Legacy of the Godfather)",
				"japanese_name": "カポネ・“ギャング”・ベッジ",
				"role": "Former Boss of the Five Families / Captain of the Fire Tank Pirates",
				"bounty_beli": 350_000_000,
				"status": "Active Supernova (Grand Line / New World)",
				"lore": "Eater of the Castle-Castle Fruit (Shiro Shiro no Mi). Ruled the West Blue underworld by assassinating rival syndicate heads and laughing as their organizations tore themselves apart from within.",
				"dialogue_samples": [
					"In this world, the guy with the most firepower and the cold nerve to pull the trigger wins! Never turn your back on family, but never hesitate to put a bullet between a traitor's eyes!",
				],
			},
			{
				"id": "vito_ghost_gun_lore",
				"name": "Vito 'The Ghost Gun' (Legacy Echo)",
				"japanese_name": "ヴィト",
				"role": "Fire Tank Advisor & Hitman",
				"lore": "Bege's eccentric right-hand man, famous for his monstrously long tongue, dual revolvers, and fanatic obsession with Germa 66 comic serials.",
			},
			{
				"id": "gotti_enforcer_lore",
				"name": "Gotti (Legacy Echo)",
				"japanese_name": "ゴッティ",
				"role": "Fire Tank Heavy Enforcer",
				"lore": "Hot-tempered cyborg enforcer wielding a massive machine gun mounted on his right arm, fiercely loyal to Bege and Chiffon.",
			},
		],
		"archetype_npcs": [
			{
				"id": "don_vincenzo",
				"name": "Don Vincenzo",
				"role": "Current Regent of the Fire Tank West Blue Holdings",
				"dialogue": "The Boss took his crew to the Grand Line, but the Five Families still answer to the iron will of the Castello. Pay your protection tax, and you can buy all the tommy-guns your hold can carry.",
			},
			{
				"id": "marchetti_rival",
				"name": "Carmine Marchetti",
				"role": "Rival Syndicate Arms Broker",
				"dialogue": "Bege thought he could chop off every boss's head and leave. The Marchetti Family is rebuilding. We have ties directly to the New World underworld brokers.",
			},
		],
		"specialties": [
			"Tommy-Gun Rapid-Fire Flintlock Submachine Guns",
			"Ballistic-Weave Pinstripe Mobster Suits",
			"Aged West Blue Reserve Cuban-Style Cigars",
			"Lead-Lined Contraband Ship Cargo Chests",
			"Ironclad Castle-Ship Hull Plating Blueprints",
		],
		"lore_and_secrets": [
			"Jinbe explained Bege's past in Chapter 857: Bege was one of the Five Families of the West, obsessed with beheading enemy leaders and watching internal chaos.",
			"A secret submarine sluice connects the Castello's lowest vault directly to the outer sea trench, bypassing surface blockades.",
		],
		"exploration_hooks": [
			{
				"id": "hook_mafia_heist",
				"title": "Raid on the Marchetti Vault",
				"target_location": "fortezza_capone",
				"reward_beli": 300_000,
				"description": "Infiltrate a rival mob family's underground iron bank vault during a rainy midnight shootout to seize a crate of stolen high-grade Devil Fruit encryptions.",
			},
		],
		"connected_routes": ["route_five_families_run", "route_reverse_mountain_ascent"],
	},

	"god_valley": {
		"id": "god_valley",
		"name": "God Valley (Ghost Coordinates / Sunken Atoll)",
		"japanese_name": "ゴッドバレー",
		"epithet": "The Erased Holy Island & The Cataclysmic Crater",
		"coordinates": {
			"lat": -68.000,
			"lon": -58.000,
			"alt": 0.0,
		},
		"climate": "Perpetual Storm-Shrouded Squalls & Boiling Oceanic Mists",
		"biome": "Submerged Basalt Spikes, Ghost Reef Shallows, Blasted Caldera Abyss, Sunken Marble Temples",
		"danger_level": 10,
		"governance": "Erased from World Maps (Former World Government Sovereign Territory)",
		"factions": [
			"Ghost Echoes of the Rocks Pirates (Rocks D. Xebec)",
			"Celestial Dragon Extermination Taskforce (Figarland Garling)",
			"The Roger Pirates (Historical Legend)",
			"Marine Strike Corps (Monkey D. Garp)",
		],
		"magnetic_profile": {
			"has_magnetic_field": false,
			"compass_reliable": false,
			"magnetic_anomaly_rating": 0.95,
		},
		"settlements": [
			{
				"id": "god_valley_sunken_atoll",
				"name": "The Sunken Hunting Arena Reef",
				"type": "Submerged Forbidden Ruin & Abyssal Atoll",
				"population": 1,
				"description": "The terrifying geological scar left when God Valley was obliterated 38 years ago. Needle-sharp volcanic spires breach the frothing waves, surrounding a deep oceanic abyss where the island once stood.",
			},
		],
		"ports": [
			{
				"id": "ghost_reef_mooring",
				"name": "The Ghost Reef Mooring",
				"coordinates": {"lat": -67.980, "lon": -57.980},
				"depth_m": 45.0,
				"facilities": ["Jagged Basalt Natural Tie-Off", "No Shore Facilities"],
				"docking_fee_beli": 0,
			},
		],
		"establishments": [
			{
				"id": "hermits_coral_cave",
				"name": "Old Darrow's Reef Sanctuary",
				"type": "Hermit's Coral Cave & Lost Relic Cache",
				"proprietor": "Hermit Darrow (Survivor of the Native Hunt)",
				"services": [
					"Ancient God Valley Lore Sharing",
					"Abyssal Trench Diving Advice",
					"Barter of Ancient Relics",
				],
				"inventory": [
					"ancient_native_totem",
					"celestial_gold_medal",
					"rocks_cutlass_fragment",
					"abyss_diving_helmet",
					"corrupted_magnetic_pose",
				],
			},
		],
		"canon_npcs": [
			{
				"id": "rocks_xebec_echo",
				"name": "Rocks D. Xebec (Abyssal Echo & Memory)",
				"japanese_name": "ロックス・D・ジーベック",
				"role": "Captain of the Rocks Pirates / Seeker of the World Throne",
				"status": "Deceased (Fell 38 Years Ago at God Valley)",
				"lore": "The most dangerous pirate captain of his era, commanding Whitebeard, Big Mom, Kaido, and Shiki. Sought to become King of the World before being brought down by the combined forces of Roger and Garp.",
				"dialogue_samples": [
					"The World Nobles sit upon a throne of hollow clay! The world belongs to whoever has the ambition to seize it!",
				],
			},
			{
				"id": "shanks_birth_lore",
				"name": "Shanks (Discovery Location / Treasure Chest Hook)",
				"japanese_name": "シャンクス",
				"role": "Foundling of God Valley / Emperor of the Sea",
				"lore": "Found as a one-year-old infant tucked inside a treasure chest looted by Gol D. Roger following the battle of God Valley. Born to the Figarland bloodline.",
			},
		],
		"archetype_npcs": [
			{
				"id": "hermit_darrow",
				"name": "Old Darrow",
				"role": "Sole Surviving Native Witness",
				"dialogue": "38 years ago, the sky rained red fire. The gods arrived not with mercy, but with hunting rifles to cull us like cattle. Then the pirate titans clashed, and the earth itself split and swallowed our homeland whole.",
			},
		],
		"specialties": [
			"Ancient Native Totems of God Valley",
			"Celestial Dragon Gold Bullion Hunting Medals",
			"Weathered Rocks Pirate Weapon Fragments",
			"Deep Abyss Atmospheric Diving Helmets",
		],
		"lore_and_secrets": [
			"God Valley vanished from all official world maps 38 years ago, its very name forbidden by the Five Elders.",
			"During the incident, Bartholomew Kuma and Ginny secured the Nikyu Nikyu no Mi and Uo Uo no Mi from the Celestial Dragons' prize chests.",
			"Standard magnetic compasses spin erratically within 20 nautical miles of the sunken crater due to severed planetary magnetic core filaments.",
		],
		"exploration_hooks": [
			{
				"id": "hook_abyssal_trench",
				"title": "Diving the Sunken Hunting Pavilion",
				"target_location": "god_valley_sunken_atoll",
				"reward_beli": 500_000,
				"description": "Don an abyssal diving suit and descend 150 meters into the sunken hunting pavilion to recover an intact World Noble gold-sealed prize chest.",
			},
		],
		"connected_routes": ["route_outlaw_frontier"],
	},

	"tomb_of_thriller": {
		"id": "tomb_of_thriller",
		"name": "The Tomb of Thriller (Caldera of Thriller Bark)",
		"japanese_name": "スリラーの墓所",
		"epithet": "The Excavated Oceanic Void & Cindry's Mourning Ground",
		"coordinates": {
			"lat": -58.000,
			"lon": -78.000,
			"alt": 0.0,
		},
		"climate": "Chilly Foggy Waters with Gloomy Drizzle",
		"biome": "Circular Deep Caldera Trench, Jagged Perimeter Ring Reef, Gothic Abandoned Theaters, Crypt Estates",
		"danger_level": 6,
		"governance": "Deserted Ghost Territory (Historical Moria Origin)",
		"factions": [
			"Gecko Pirates Legacy (Moria's West Blue Origin)",
			"Victoria Cindry Memorial Society",
			"Dr. Hogback's Desecrated Lab Scavengers",
			"West Blue Gravekeeper Guild",
		],
		"magnetic_profile": {
			"has_magnetic_field": true,
			"compass_reliable": true,
			"magnetic_anomaly_rating": 0.08,
		},
		"settlements": [
			{
				"id": "cindry_memorial_ring",
				"name": "Cindry's Shore & Theater Ruins",
				"type": "Deserted Gothic Port & Memorial Ground",
				"population": 120,
				"description": "The remaining perimeter ring of an island whose massive central landmass was gouged out by Gecko Moria to build Thriller Bark. Contains the abandoned seaside theater where Victoria Cindry once performed.",
			},
		],
		"ports": [
			{
				"id": "pale_fog_slip",
				"name": "Pale Fog Slip",
				"coordinates": {"lat": -57.980, "lon": -77.980},
				"depth_m": 25.0,
				"facilities": ["Creaking Wooden Pier", "Lantern Float Buoys", "Crypt Storage"],
				"docking_fee_beli": 2000,
			},
		],
		"establishments": [
			{
				"id": "pale_moon_apothecary",
				"name": "Pale Moon Mortuary & Apothecary",
				"type": "Apothecary, Embalming Supplies & Stage Relics",
				"proprietor": "Igor the Undertaker",
				"services": [
					"Surgical Embalming Salve Supply",
					"Ghost-Lantern of the Pale Sea Crafting",
					"Vintage Stage Memorabilia",
				],
				"inventory": [
					"cindry_stage_poster",
					"embalming_salve",
					"ghost_lantern",
					"porcelain_dinner_plate",
					"gothic_iron_candelabra",
					"thriller_timber_splinter",
				],
			},
		],
		"canon_npcs": [
			{
				"id": "victoria_cindry_legacy",
				"name": "Victoria Cindry (Memorial & Stage Legacy)",
				"japanese_name": "ビクトリア・シンドリー",
				"role": "Famous Stage Actress from West Blue / Hogback's Obsession",
				"status": "Deceased (Corpse Stolen to Thriller Bark)",
				"lore": "Celebrated West Blue actress who died tragically at age 24 after falling from a stage. Dr. Hogback was madly in love with her and stole her corpse to resurrect her as Moria's zombie servant.",
				"dialogue_samples": [
					"Plates... plates are made to be broken! Why must I smile when my heart is made of cold ash?",
				],
			},
			{
				"id": "gecko_moria_origin",
				"name": "Gecko Moria (West Blue Roots)",
				"japanese_name": "ゲッコー・モリア",
				"role": "Former Warlord of the Sea / Captain of the Thriller Bark Pirates",
				"lore": "Originally sailed from West Blue as captain of the Gecko Pirates. Extracted an entire island from this very basin and converted it into the world's largest pirate ship before venturing to Wano and the Florian Triangle.",
			},
		],
		"archetype_npcs": [
			{
				"id": "madame_beatrice",
				"name": "Madame Beatrice",
				"role": "Former Theater Director of Cindry",
				"dialogue": "Cindry's voice could make the entire audience weep with joy. When that monster Hogback dug up her grave 12 years ago, a curse fell over this ring. Now only plate-smashing specters remain.",
			},
		],
		"specialties": [
			"Vintage Victoria Cindry Stage Posters",
			"Surgical Embalming Salves & Preservative Balms",
			"Pale Sea Ghost-Piercing Lanterns",
			"Fine Porcelain Dinner Plates (Thrown Weapons)",
			"Thriller Bark Excavated Timber Splinters",
		],
		"lore_and_secrets": [
			"Thriller Bark was canonically an island in the West Blue before Moria transformed it into a ship and navigated it through Reverse Mountain into the Florian Triangle.",
			"Dr. Hogback's secret subterranean laboratory beneath the theater contains preserved anatomic diagrams for reanimation.",
		],
		"exploration_hooks": [
			{
				"id": "hook_hogback_lab",
				"title": "Secrets of the Desecrated Lab",
				"target_location": "cindry_memorial_ring",
				"reward_beli": 160_000,
				"description": "Explore the flooded catacombs beneath the theater to retrieve Hogback's early surgical research journals before the rising tide collapses the vaults.",
			},
		],
		"connected_routes": ["route_outlaw_frontier"],
	},

	"gourd_island": {
		"id": "gourd_island",
		"name": "Gourd Island & Sheriff's Bastion",
		"japanese_name": "ヒョウタン島",
		"epithet": "The Demon Sheriff's Penitentiary & Exile Coast",
		"coordinates": {
			"lat": -31.000,
			"lon": -75.000,
			"alt": 0.0,
		},
		"climate": "Chilly Coastal Gales & Salt-Crusted Cliffs",
		"biome": "Granite Sea-Spurs, High Iron Penal Walls, Gourd-Shaped Twin Atolls, Marine Execution Bastion",
		"danger_level": 5,
		"governance": "Military Penitentiary Zone (World Government Marine 88th Branch)",
		"factions": [
			"Marine 88th Branch (Commander Briggs)",
			"Incarcerated Five Families Gangsters",
			"Legacy of the Demon Sheriff (Laffitte Sympathizers)",
		],
		"magnetic_profile": {
			"has_magnetic_field": true,
			"compass_reliable": true,
			"magnetic_anomaly_rating": 0.05,
		},
		"settlements": [
			{
				"id": "sheriff_penitentiary",
				"name": "Bastion 88 & Harbor Garrison",
				"type": "Fortified Penal Colony & Naval Port",
				"population": 18000,
				"description": "A stark granite fortress spanning the neck of a gourd-shaped double island. Built as a regional penitentiary, it was once the brutal jurisdiction of Laffitte before his expulsion.",
			},
		],
		"ports": [
			{
				"id": "gourd_naval_dock",
				"name": "Gourd Naval Quay",
				"coordinates": {"lat": -30.980, "lon": -74.980},
				"depth_m": 22.0,
				"facilities": ["Marine Iron Gate", "Prisoner Loading Hoist", "Seastone Armory Berth"],
				"docking_fee_beli": 6000,
			},
		],
		"establishments": [
			{
				"id": "penal_surplus_quartermaster",
				"name": "Penal Colony Surplus Quartermaster",
				"type": "Marine Surplus, Batons & Restraints",
				"proprietor": "Quartermaster Briggs",
				"services": [
					"Seastone Handcuff Re-Keying",
					"Weighted Cane Balance Tuning",
					"Marine Surplus Provisions",
				],
				"inventory": [
					"demon_sheriff_cane",
					"seastone_handcuffs",
					"police_baton",
					"penal_hard_bread",
					"hypnotic_pocket_watch",
				],
			},
		],
		"canon_npcs": [
			{
				"id": "laffitte_legacy",
				"name": "Laffitte (The Demon Sheriff)",
				"japanese_name": "ラフィット",
				"role": "Former West Blue Sheriff / Chief of Staff of the Blackbeard Pirates",
				"bounty_beli": 422_000_000,
				"status": "Active Titanic Captain (New World)",
				"lore": "Originally a peace officer in the West Blue nicknamed the 'Demon Sheriff' due to his sadistic brutality and violence toward citizens. Banished by the World Government, he later joined Marshall D. Teach.",
				"dialogue_samples": [
					"Ho-ho! A good sheriff needs rhythm, manners, and a cane that snaps collarbones cleanly! Shall we dance?",
				],
			},
		],
		"archetype_npcs": [
			{
				"id": "commander_briggs",
				"name": "Commander Briggs",
				"role": "Marine 88th Branch Warden",
				"dialogue": "Laffitte disgraced this badge with blood and madness. Under my watch, the 88th Branch enforces the law with iron discipline, not sadistic theatre.",
			},
		],
		"specialties": [
			"Demon Sheriff's Weighted Fencing Canes",
			"Seastone-Reinforced Iron Handcuffs",
			"Marine Standard Steel-Cored Batons",
			"Hypnotic Pendulum Chronometers",
		],
		"lore_and_secrets": [
			"Laffitte's former solitary interrogation cell is etched with intricate hypnosis spirals that disorient any guard standing in the chamber for over a minute.",
		],
		"exploration_hooks": [
			{
				"id": "hook_penal_breakout",
				"title": "Subduing the Iron Block Riot",
				"target_location": "sheriff_penitentiary",
				"reward_beli": 150_000,
				"description": "Prevent an armed breakout organized by imprisoned Five Families mob capos attempting to dynamite the eastern seawall.",
			},
		],
		"connected_routes": ["route_outlaw_frontier"],
	},

	"sake_cove": {
		"id": "sake_cove",
		"name": "Sake Cove & Cape Red-Hair",
		"japanese_name": "酒の入江（赤髪岬）",
		"epithet": "Haven of the Healing Brew & Master Coopers",
		"coordinates": {
			"lat": -45.000,
			"lon": -12.000,
			"alt": 0.0,
		},
		"climate": "Sunny Mild Maritime with Gentle Coastal Winds",
		"biome": "Sun-Drenched Terraced Vineyards, Aromatic White Oak Groves, Golden Sand Coves, Cavern Barrel Cellars",
		"danger_level": 2,
		"governance": "Free Cooper & Brewer Cooperative (Autonomous Haven)",
		"factions": [
			"Guild of Master Brewers & Distillers",
			"West Blue Cooperage Fraternity",
			"Red-Hair Pirate Sympathizers & Traveling Bards",
		],
		"magnetic_profile": {
			"has_magnetic_field": true,
			"compass_reliable": true,
			"magnetic_anomaly_rating": 0.03,
		},
		"settlements": [
			{
				"id": "red_calabash_village",
				"name": "Red Calabash Haven",
				"type": "Peaceful Brewing Harbor & Vineyard Township",
				"population": 36000,
				"description": "A tranquil haven nestled along sunlit sandstone coves, celebrated across all Four Seas as the origin of the world-famous West Blue sake brought by Shanks to Whitebeard.",
			},
		],
		"ports": [
			{
				"id": "calabash_cove_pier",
				"name": "Calabash Pier",
				"coordinates": {"lat": -44.980, "lon": -11.980},
				"depth_m": 19.0,
				"facilities": [
					"Cooperage Barrel Slips",
					"Freshwater Spring Loading Chute",
					"Wine Tasting Terrace",
				],
				"docking_fee_beli": 3000,
			},
		],
		"establishments": [
			{
				"id": "master_brewer_bacchus",
				"name": "The Grand Calabash Brewery & Cooperage",
				"type": "Brewery, Cask Cooperage & Provision Store",
				"proprietor": "Master Brewer Bacchus",
				"services": [
					"Grand Calabash Sake Bottling ('Healing Water')",
					"Watertight Voyage Cask Cooperage",
					"Vineyard Morale Rations",
				],
				"inventory": [
					"west_blue_calabash_sake",
					"vintage_west_wine",
					"watertight_cooper_cask",
					"red_felt_bandana",
					"terraced_sweet_grapes",
				],
			},
		],
		"canon_npcs": [
			{
				"id": "shanks_brew_lore",
				"name": "Shanks (Echo of the Red-Hair Emperor's Toast)",
				"japanese_name": "シャンクス",
				"role": "Emperor of the Sea / Chief Patron of West Blue Sake",
				"bounty_beli": 4_048_900_000,
				"status": "Active Emperor",
				"lore": "When visiting Edward Newgate (Whitebeard) aboard the Moby Dick in Chapter 434, Shanks presented a giant wooden calabash of this very brew, declaring: 'It's West Blue sake. Drink it. Healing water, so to speak.'",
				"dialogue_samples": [
					"It's West Blue sake. Drink it. Healing water, so to speak... Good liquor brings peace to men's hearts, even if just for one toast.",
				],
			},
		],
		"archetype_npcs": [
			{
				"id": "brewer_bacchus",
				"name": "Master Brewer Bacchus",
				"role": "Patriarch of the Calabash Cellars",
				"dialogue": "We age this brew in high-mountain sandstone barrels. A single cup clears sea-sickness, settles poisoned blood, and reminds a pirate why he set sail in the first place.",
			},
		],
		"specialties": [
			"Grand Calabash of West Blue Sake ('Healing Water')",
			"Oak-Aged 20-Year West Blue Vintage Red Wine",
			"Watertight Oak Cooper Casks (Prevents Voyage Spoilage)",
			"Terraced Vineyard Sweet Grape Clusters",
		],
		"lore_and_secrets": [
			"Drinking authentic West Blue Calabash Sake instantly cleanses all party poison, fatigue, and bleed debuffs.",
			"Shanks personally left a signed Red-Hair pirate pennant inside the highest cellar to guarantee the island's protection from mob shakedowns.",
		],
		"exploration_hooks": [
			{
				"id": "hook_calabash_vintage",
				"title": "The Golden Harvest Vintage",
				"target_location": "red_calabash_village",
				"reward_beli": 90_000,
				"description": "Gather high-altitude spring water from the sandstone falls to brew a limited batch of 'Healing Water' sake for the voyage through Reverse Mountain.",
			},
		],
		"connected_routes": ["route_scholars_trail", "route_martial_convoy", "route_reverse_mountain_ascent"],
	},

	"west_blue_reverse_mountain_gateway": {
		"id": "west_blue_reverse_mountain_gateway",
		"name": "West Blue Reverse Mountain Gateway (Approach & Guide-Light Gate)",
		"japanese_name": "リヴァース・マウンテン西海昇り口前哨",
		"epithet": "The Hydraulic Ascent Gateway & The Red Wall Threshold",
		"coordinates": {
			"lat": -15.500,
			"lon": -2.500,
			"alt": 0.0,
		},
		"climate": "Ferocious Storm Squalls, Convergent Rip-Currents & Upward Spray",
		"biome": "Sheer Red Line Cliff Bastions (+10,000m), Colossal Granite Guide-Light Gate, Surging High-Velocity Canal Throat",
		"danger_level": 9,
		"governance": "Free Maritime Staging Zone (Natural Great Circle Threshold)",
		"factions": [
			"Reverse Mountain Pilot Guild (Old Gregory)",
			"Extreme Hullwrights & Rudder Reinforcers",
			"Grand Line Bound Aspiring Crews",
		],
		"magnetic_profile": {
			"has_magnetic_field": true,
			"compass_reliable": true,
			"magnetic_anomaly_rating": 0.35,
		},
		"settlements": [
			{
				"id": "last_hope_staging",
				"name": "The Last Hope Staging Mooring",
				"type": "Floating Mooring Station & Repair Drydock",
				"population": 650,
				"description": "A cluster of heavy iron floating barges moored to massive chains bolted into the Red Line's outer basalt shelf, 163 km southwest of Reverse Mountain Node A. Aspiring crews make final repairs and wait for favorable tides before shooting into the canal.",
			},
		],
		"ports": [
			{
				"id": "staging_buoy_basin",
				"name": "Staging Buoy Basin",
				"coordinates": {"lat": -15.480, "lon": -2.480},
				"depth_m": 85.0,
				"facilities": [
					"Heavy Mooring Chains",
					"Rudder Reinforcement Slipway",
					"Storm Lighthouse Guidance Beacon",
					"Emergency Rescue Winches",
				],
				"docking_fee_beli": 12000,
			},
		],
		"establishments": [
			{
				"id": "last_hope_drydock",
				"name": "The Last Hope Hullwrights & Saloon",
				"type": "Ship Repair, Current Pilotage & Farewell Tavern",
				"proprietor": "Shipwright Tsuru & Pilot Gregory",
				"services": [
					"High-Tensile Rudder Chain Installation (Prevents Rudder Break on Canal Walls)",
					"Reverse Mountain Hydrodynamic Current Guidance",
					"Final Sea Provisions & Emergency Flares",
					"Grand Line Wills & Testament Registration",
				],
				"inventory": [
					"rudder_reinforcement_chains",
					"reverse_mountain_current_chart",
					"emergency_flare_gun",
					"iron_mooring_harpoon",
					"last_blue_pint_ale",
				],
			},
		],
		"canon_npcs": [],
		"archetype_npcs": [
			{
				"id": "pilot_gregory",
				"name": "Lighthouse Pilot Gregory",
				"role": "Master Canal Approach Navigator",
				"dialogue": "Listen to me closely! When the West Blue current grabs your hull, you will hit 65 knots in under twenty seconds! Keep your bow centered exactly between the twin stone gate pillars. Veering three degrees left means your ship becomes firewood against the Red Line!",
			},
			{
				"id": "carpenter_tsuru",
				"name": "Master Carpenter Tsuru",
				"role": "Heavy Rudder Brace Specialist",
				"dialogue": "You see those floating splinters? That was a brigantine from Toroa. Their rudder snapped in the first gorge. Double-chain your tiller, or don't bother setting sail.",
			},
		],
		"specialties": [
			"High-Tensile Steel Rudder Reinforcement Chains",
			"Reverse Mountain Hydrodynamic Current Charts",
			"High-Luminance Emergency Flare Guns",
			"Heavy Forged Iron Mooring Harpoons",
			"The 'Last Blue Pint' Farewell Dark Ale",
		],
		"lore_and_secrets": [
			"Connects directly to the West Blue Ascending Canal gate at (lat: -0.430, lon: -0.395), plunging up 5,000 meters to the Summit Basin of Reverse Mountain.",
			"Over seventy percent of rookie ships that attempt the canal without reinforced rudders crash against the outer canyon walls.",
		],
		"exploration_hooks": [
			{
				"id": "hook_canal_ascent",
				"title": "The 5,000-Meter Hydraulic Ascent",
				"target_location": "west_blue_reverse_mountain_gateway",
				"reward_beli": 250_000,
				"description": "Align your ship within the 400m-wide West Blue canal entrance, match current surge velocity, and maintain center rudder through the steep winter rapids to reach Reverse Mountain's summit basin.",
			},
		],
		"connected_routes": ["route_reverse_mountain_ascent"],
	},
}

# ---------------------------------------------------------------------------
# Master Oceanic Routes Dictionary
# ---------------------------------------------------------------------------
const ROUTES: Array[Dictionary] = [
	{
		"id": "route_scholars_trail",
		"name": "The Scholar's & Minstrel's Trail",
		"type": "Cultural, Historical & Musical Voyage",
		"stops": ["ohara", "esperia_kingdom", "toroa", "sake_cove"],
		"total_distance_km": 14200.0,
		"hazard_level": "Moderate (Patrolled by Cipher Pol & Slaver Raiding Cutters)",
		"prevailing_winds": "South-Southwesterly 15-20 knots",
		"description": "The tranquil southern arc connecting the historic ruins of Ohara through the music sanctuaries of Esperia and Toroa, terminating at the vineyard haven of Sake Cove.",
	},
	{
		"id": "route_five_families_run",
		"name": "The Five Families Underworld Run",
		"type": "Crime Syndicate & Commercial Highway",
		"stops": ["castello_del_capone", "ilusia_kingdom", "kano_country", "ballywood_kingdom"],
		"total_distance_km": 16800.0,
		"hazard_level": "High (Mob Gunboats, Turf Skirmishes, Customs Inspections)",
		"prevailing_winds": "North-Northwesterly 18-25 knots",
		"description": "The industrialized trade artery linking the criminal empire of Castello Del Capone to the royal markets of Ilusia, the martial shipyards of Kano, and the industrial meatpackers of Ballywood.",
	},
	{
		"id": "route_outlaw_frontier",
		"name": "The Outlaw Frontier & Ghost Reef Run",
		"type": "High-Hazard Exploration & Warzone Passage",
		"stops": ["las_camp", "gourd_island", "tomb_of_thriller", "god_valley"],
		"total_distance_km": 18500.0,
		"hazard_level": "Extreme (Pirate Riots, Penal Garrisons, Magnetic Voids, Ghost Reefs)",
		"prevailing_winds": "Unpredictable Storm Squalls 25-40 knots",
		"description": "The treacherous western badlands passage running from the war-torn scrublands of Las Camp down to the penitentiary of Gourd Island, the excavation crater of Thriller Bark, and the erased ghost atoll of God Valley.",
	},
	{
		"id": "route_martial_convoy",
		"name": "The Happo Martial Shipping Convoy",
		"type": "Heavy Naval Transport & Dragon-Prow Escort",
		"stops": ["kano_country", "sake_cove", "castello_del_capone"],
		"total_distance_km": 9400.0,
		"hazard_level": "Moderate-High (Heavy Armored Cargo, Underworld Interceptions)",
		"prevailing_winds": "Easterly Trade Winds 20 knots",
		"description": "The direct crossing connecting Kano Country's jade foundries and dragon-prow shipyards with the brewery haven of Sake Cove and the underworld arsenals of Capone.",
	},
	{
		"id": "route_reverse_mountain_ascent",
		"name": "The Grand Line Ascent Highway",
		"type": "Reverse Mountain Convergence Route",
		"stops": ["sake_cove", "castello_del_capone", "west_blue_reverse_mountain_gateway"],
		"total_distance_km": 8200.0,
		"hazard_level": "Extreme (Hydraulic Convergent Rip-Currents, Red Line Impact Risk)",
		"prevailing_winds": "Convergent Updraft Squalls 35-50 knots",
		"description": "The final oceanic highway where all West Blue routes converge at Sake Cove and Castello Del Capone, accelerating through surging rip-currents into the West Blue Reverse Mountain Gateway.",
	},
]

# ---------------------------------------------------------------------------
# Master Items & Equipment Catalog
# ---------------------------------------------------------------------------
const ITEMS: Dictionary = {
	# Consumables & Provisions
	"west_blue_calabash_sake": {
		"id": "west_blue_calabash_sake",
		"name": "Grand Calabash of West Blue Sake ('Healing Water')",
		"category": "Consumable",
		"price_beli": 12500,
		"weight_kg": 5.0,
		"description": "The legendary vintage brew Shanks offered to Whitebeard. Imbibing immediately cures all party status debuffs (poison, sea-sickness, fatigue) and boosts Morale to 100%.",
	},
	"ballywood_smoked_shank": {
		"id": "ballywood_smoked_shank",
		"name": "Ballywood Hickory-Smoked Prime Shank",
		"category": "Consumable",
		"price_beli": 3800,
		"weight_kg": 4.5,
		"description": "Dense, high-calorie cured beef shank prepared by Ballywood pitmasters. Restores 100% character stamina and prevents hunger for 3 in-game days.",
	},
	"kano_lotus_baijiu": {
		"id": "kano_lotus_baijiu",
		"name": "Kano Lotus Blossom Baijiu",
		"category": "Consumable",
		"price_beli": 4500,
		"weight_kg": 1.2,
		"description": "Potent 60-proof spirit infused with lotus blossoms. Temporarily increases unarmed strike damage by 20% for 5 minutes.",
	},
	"ohara_clover_tea": {
		"id": "ohara_clover_tea",
		"name": "Ohara Clover Leaf Tea",
		"category": "Consumable",
		"price_beli": 1200,
		"weight_kg": 0.3,
		"description": "Gentle herbal tea blended from wild clovers collected near the Tree of Knowledge. Calms the mind and enhances research focus.",
	},
	"las_camp_firewater": {
		"id": "las_camp_firewater",
		"name": "Las Camp Agave Firewater",
		"category": "Consumable",
		"price_beli": 2200,
		"weight_kg": 1.0,
		"description": "Rough frontier liquor distilled from canyon agave. Numbs physical pain, reducing incoming damage by 15% for 3 minutes.",
	},
	"salted_provisions_30d": {
		"id": "salted_provisions_30d",
		"name": "Ilusian Salted Voyager Provisions (30 Days)",
		"category": "Consumable",
		"price_beli": 5000,
		"weight_kg": 25.0,
		"description": "Barrels of salt pork, hard ship biscuits, and dried figs sufficient to feed a crew of four for an entire month at sea.",
	},
	"terraced_sweet_grapes": {
		"id": "terraced_sweet_grapes",
		"name": "Terraced Vineyard Sweet Grape Cluster",
		"category": "Consumable",
		"price_beli": 600,
		"weight_kg": 0.8,
		"description": "Crisp sweet grapes grown on the sunny sea-cliffs of Sake Cove. Cures mild thirst and provides quick sugar replenishment.",
	},
	"penal_hard_bread": {
		"id": "penal_hard_bread",
		"name": "Gourd Island Hardtack Biscuit Box",
		"category": "Consumable",
		"price_beli": 800,
		"weight_kg": 6.0,
		"description": "Hard-baked penal rations. Nearly rock-hard, but virtually impervious to weevils and sea water.",
	},
	"last_blue_pint_ale": {
		"id": "last_blue_pint_ale",
		"name": "The 'Last Blue Pint' Farewell Ale",
		"category": "Consumable",
		"price_beli": 800,
		"weight_kg": 0.7,
		"description": "Heavy dark ale served to sailors preparing to brave Reverse Mountain. Bestows a temporary courage boost.",
	},

	# Weapons & Martial Gear
	"tommy_gun_flintlock": {
		"id": "tommy_gun_flintlock",
		"name": "Tommy-Gun Rapid-Fire Submachine Flintlock",
		"category": "Weapon",
		"price_beli": 95000,
		"weight_kg": 5.2,
		"description": "Signature firearm of the Five Families mobsters. Features a 50-round drum magazine delivering rapid suppression volleys.",
	},
	"reinforced_bisen_naginata": {
		"id": "reinforced_bisen_naginata",
		"name": "Reinforced Bisen Heavy Naginata",
		"category": "Weapon",
		"price_beli": 95000,
		"weight_kg": 7.5,
		"description": "Heavy polearm favored by Don Sai and Happo Navy commanders. Wide curved blade engineered to conduct Hasshoken vibration shocks.",
	},
	"concealed_cane_sword": {
		"id": "concealed_cane_sword",
		"name": "Concealed Cane-Sword (Shikomizue Rapier)",
		"category": "Weapon",
		"price_beli": 88000,
		"weight_kg": 1.8,
		"description": "Disguised gentleman's cane concealing an ultra-light, razor-sharp fencing rapier favored by Esperian battle convoy officers like Brook.",
	},
	"demon_sheriff_cane": {
		"id": "demon_sheriff_cane",
		"name": "Demon Sheriff's Weighted Steel Cane",
		"category": "Weapon",
		"price_beli": 55000,
		"weight_kg": 3.4,
		"description": "Heavy steel-reinforced walking stick with a lead-weighted pommel. Balanced for rhythmic tap-dancing parries and bone-fracturing strikes.",
	},
	"heavy_caliber_revolver": {
		"id": "heavy_caliber_revolver",
		"name": "Las Camp Heavy Caliber Fast-Draw Revolver",
		"category": "Weapon",
		"price_beli": 38000,
		"weight_kg": 1.9,
		"description": "Rugged six-shot frontier sidearm. Delivers massive stopping power at close-to-medium range.",
	},
	"ilusia_brass_flintlock": {
		"id": "ilusia_brass_flintlock",
		"name": "Ilusian Brass-Inlaid Royal Musket",
		"category": "Weapon",
		"price_beli": 42000,
		"weight_kg": 4.1,
		"description": "Precision rifled flintlock manufactured for the Ilusian Royal Carabineers. High accuracy and elegant gilded engraving.",
	},
	"police_baton": {
		"id": "police_baton",
		"name": "Marine 88th Branch Police Baton",
		"category": "Weapon",
		"price_beli": 8000,
		"weight_kg": 1.4,
		"description": "Solid hardwood baton with a rubber-wrapped grip for non-lethal prisoner compliance.",
	},
	"porcelain_dinner_plate": {
		"id": "porcelain_dinner_plate",
		"name": "Victoria Cindry Ceramic Dinner Plate (Set of 10)",
		"category": "Weapon",
		"price_beli": 500,
		"weight_kg": 2.0,
		"description": "Ordinary ceramic dinner plates that can be hurled with surprising velocity, shattering into jagged razor-sharp ceramic shrapnel.",
	},

	# Armor & Apparel
	"pinstripe_ballistic_suit": {
		"id": "pinstripe_ballistic_suit",
		"name": "Ballistic-Weave Pinstripe Mobster Suit",
		"category": "Armor",
		"price_beli": 75000,
		"weight_kg": 3.8,
		"description": "Tailored double-breasted pinstripe wool suit woven with high-tensile steel fiber threads. Protects against shrapnel and small-arms fire.",
	},
	"padded_silk_brigandine": {
		"id": "padded_silk_brigandine",
		"name": "Kano Embroidered Silk Brigandine",
		"category": "Armor",
		"price_beli": 35000,
		"weight_kg": 6.2,
		"description": "Traditional Kano armor featuring overlapping steel plates riveted between heavy embroidered green silk layers.",
	},
	"gilded_breastplate": {
		"id": "gilded_breastplate",
		"name": "Ilusian Royal Guard Gilded Cuirass",
		"category": "Armor",
		"price_beli": 65000,
		"weight_kg": 9.5,
		"description": "Polished steel breastplate inlaid with gold fleur patterns. Imparts high defense and increases diplomatic charisma.",
	},
	"stovepipe_top_hat": {
		"id": "stovepipe_top_hat",
		"name": "Ballywood Star-Spangled Stovepipe Top Hat",
		"category": "Apparel",
		"price_beli": 18000,
		"weight_kg": 0.6,
		"description": "Eccentric 40cm-tall silk top hat modeled after King Ham Burger's headwear. Adds distinct presence in port markets.",
	},
	"minstrel_frock_coat": {
		"id": "minstrel_frock_coat",
		"name": "Esperian Minstrel Velvet Frock Coat",
		"category": "Apparel",
		"price_beli": 24000,
		"weight_kg": 2.1,
		"description": "Flamboyant purple velvet coat with gold embroidery. Expands inventory carrying capacity with concealed instrument pockets.",
	},
	"canyon_sand_goggles": {
		"id": "canyon_sand_goggles",
		"name": "Las Camp Dust Goggles & Weathered Poncho",
		"category": "Apparel",
		"price_beli": 6000,
		"weight_kg": 1.2,
		"description": "Protective tinted lenses and thick burlap poncho providing total immunity to desert sandstorm blindness and sunburn.",
	},

	# Ship Components & Engineering Upgrades
	"happo_dragon_prow_keel": {
		"id": "happo_dragon_prow_keel",
		"name": "Happo Navy Heavy Dragon-Prow Ramming Keel",
		"category": "ShipUpgrade",
		"price_beli": 450000,
		"weight_kg": 2400.0,
		"description": "Massive cast-iron and jade-reinforced dragon-head battering ram. Triples ship collision damage against enemy vessels and Sea Kings.",
	},
	"rudder_reinforcement_chains": {
		"id": "rudder_reinforcement_chains",
		"name": "Reverse Mountain High-Tensile Rudder Chains",
		"category": "ShipUpgrade",
		"price_beli": 65000,
		"weight_kg": 350.0,
		"description": "Forged double-link steel chains bracing the rudder shaft, preventing rudder breakage when navigating 65-knot canal rapids.",
	},
	"watertight_cooper_cask": {
		"id": "watertight_cooper_cask",
		"name": "Sake Cove Master Cooper Watertight Cask",
		"category": "ShipUpgrade",
		"price_beli": 18000,
		"weight_kg": 40.0,
		"description": "Precision oak barrel lined with natural beeswax, keeping fresh water or food provisions completely unspoiled across 100 days.",
	},
	"resonant_tone_wood": {
		"id": "resonant_tone_wood",
		"name": "Esperian Aged Resonant Tone-Wood Planks",
		"category": "ShipMaterial",
		"price_beli": 32000,
		"weight_kg": 80.0,
		"description": "200-year-old subalpine spruce planks. Installing them as ship cabin paneling amplifies musical buff durations by 50%.",
	},
	"lead_lined_contraband_chest": {
		"id": "lead_lined_contraband_chest",
		"name": "Five Families Lead-Lined Contraband Sea Chest",
		"category": "ShipStorage",
		"price_beli": 35000,
		"weight_kg": 95.0,
		"description": "Heavy iron sea chest lined with lead plates. Completely conceals contraband goods and Devil Fruits from Marine visual and Den Den Mushi scans.",
	},

	# Antiquities, Relics & Books
	"burned_library_fragment": {
		"id": "burned_library_fragment",
		"name": "Burned Library of Ohara Parchment Fragment",
		"category": "Antiquity",
		"price_beli": 85000,
		"weight_kg": 0.4,
		"description": "Charred leaf from a 5,000-year-old historical tome rescued from the flames of the Tree of Knowledge. Reveals ancient naval schematics.",
	},
	"weathered_poneglyph_rubbing": {
		"id": "weathered_poneglyph_rubbing",
		"name": "Weathered Poneglyph Charcoal Rubbing",
		"category": "Antiquity",
		"price_beli": 250000,
		"weight_kg": 0.5,
		"description": "Charcoal tracing of an unmapped historical Poneglyph stone once studied in secret by Professor Clover's archaeological guild.",
	},
	"ancient_kingdom_lexicon": {
		"id": "ancient_kingdom_lexicon",
		"name": "Oharan Ancient Kingdom Linguistic Primer",
		"category": "Book",
		"price_beli": 120000,
		"weight_kg": 2.2,
		"description": "Comparative linguistic grammar guide written by Oharan scholars, teaching the fundamentals of ancient glyph interpretation.",
	},
	"hasshoken_vibration_scroll": {
		"id": "hasshoken_vibration_scroll",
		"name": "Eight Impacts Fist Secret Vibration Scroll",
		"category": "Book",
		"price_beli": 180000,
		"weight_kg": 1.1,
		"description": "Authentic martial training parchment hand-annotated by Don Chinjao, detailing how to generate vibrational shockwaves through limbs and blades.",
	},
	"binks_sake_sheet_music": {
		"id": "binks_sake_sheet_music",
		"name": "Original West Blue Sheet Music of 'Binks' Sake'",
		"category": "SheetMusic",
		"price_beli": 15000,
		"weight_kg": 0.2,
		"description": "Authentic musical score of the timeless sea shanty as composed in West Blue, complete with the Rumbar Pirates' historical harmonies.",
	},
	"ancient_native_totem": {
		"id": "ancient_native_totem",
		"name": "Carved Basalt Totem of God Valley",
		"category": "Relic",
		"price_beli": 500000,
		"weight_kg": 8.0,
		"description": "Priceless basalt sculpture crafted by the vanished native people of God Valley before the World Nobles annexed the island for sport.",
	},
	"celestial_gold_medal": {
		"id": "celestial_gold_medal",
		"name": "Celestial Dragon Native Hunting Gold Medal",
		"category": "Relic",
		"price_beli": 300000,
		"weight_kg": 1.5,
		"description": "Pure solid gold medallion stamped with the Hoof of the Soaring Dragon, awarded to World Nobles during the 38-year-old massacre.",
	},
	"rocks_cutlass_fragment": {
		"id": "rocks_cutlass_fragment",
		"name": "Weathered Cutlass Blade of the Rocks Pirates",
		"category": "Relic",
		"price_beli": 150000,
		"weight_kg": 2.8,
		"description": "Corroded high-carbon steel saber fragment dredged from the abyssal reef of God Valley, etched with a jolly roger with a flaming skull.",
	},
	# Additional Regional Specialized Items & Equipment
	"iron_mooring_harpoon": {
		"id": "iron_mooring_harpoon",
		"name": "Heavy Forged Iron Mooring Harpoon",
		"category": "ShipEquipment",
		"price_beli": 22000,
		"weight_kg": 18.0,
		"description": "Massive barbed iron harpoon with anchor cable for securing a vessel to sheer basalt cliffs in violent rip-currents.",
	},
	"precision_chronometer": {
		"id": "precision_chronometer",
		"name": "Ilusian Precision Navigational Chronometer",
		"category": "NavigationalTool",
		"price_beli": 80000,
		"weight_kg": 1.5,
		"description": "Master-crafted spring-driven marine chronometer manufactured in Ilusia for precise longitude calculation without stellar visibility.",
	},
	"ghost_lantern": {
		"id": "ghost_lantern",
		"name": "Ghost-Lantern of the Pale Sea",
		"category": "Tool",
		"price_beli": 45000,
		"weight_kg": 2.2,
		"description": "Pale-burning chemical lantern that cuts through heavy fog, sea spray, and supernatural mists with ease.",
	},
	"iron_riding_saddle": {
		"id": "iron_riding_saddle",
		"name": "Las Camp Reinforced Iron Riding Saddle",
		"category": "MountGear",
		"price_beli": 14000,
		"weight_kg": 12.0,
		"description": "Heavy-duty leather and iron saddle built for riding canyon mounts across rocky badlands and scree slopes.",
	},
	"acoustic_felt_padding": {
		"id": "acoustic_felt_padding",
		"name": "Toroa Acoustic Soundproofing Felt",
		"category": "ShipMaterial",
		"price_beli": 18000,
		"weight_kg": 30.0,
		"description": "Dense natural wool and plant fiber felt used to soundproof ship quarters, instrument chambers, and captain cabins.",
	},
	"gothic_iron_candelabra": {
		"id": "gothic_iron_candelabra",
		"name": "Gothic Black Iron Candelabra",
		"category": "Furniture",
		"price_beli": 4800,
		"weight_kg": 4.5,
		"description": "Elaborate black wrought-iron candelabra salvaged from the abandoned estates of the Thriller Bark origin rim.",
	},
	"reverse_mountain_current_chart": {
		"id": "reverse_mountain_current_chart",
		"name": "Reverse Mountain Hydrodynamic Current Chart",
		"category": "NavigationalChart",
		"price_beli": 35000,
		"weight_kg": 0.6,
		"description": "Detailed bathymetric and tidal chart mapping the convergent rip-currents leading into the 400m-wide West Blue canal entrance.",
	},
	"steam_whistle_horn": {
		"id": "steam_whistle_horn",
		"name": "Ballywood Industrial Steam Whistle Horn",
		"category": "ShipEquipment",
		"price_beli": 22000,
		"weight_kg": 15.0,
		"description": "High-decibel dual-chamber brass steam whistle capable of signaling over 15 nautical miles through heavy fog.",
	},
	"emergency_flare_gun": {
		"id": "emergency_flare_gun",
		"name": "High-Luminance Emergency Flare Gun",
		"category": "Tool",
		"price_beli": 12000,
		"weight_kg": 1.8,
		"description": "Heavy-caliber brass flare gun firing phosphorus and magnesium rockets visible through storm squalls.",
	},
	"nitroglycerin_dynamite": {
		"id": "nitroglycerin_dynamite",
		"name": "Las Camp Nitroglycerin Dynamite Sticks (Crate of 12)",
		"category": "Weapon",
		"price_beli": 25000,
		"weight_kg": 8.0,
		"description": "High-explosive stabilized mining charges. Highly effective for breaching stone ramparts and clearing reef obstacles.",
	},
	"wrist_dagger_sleeve": {
		"id": "wrist_dagger_sleeve",
		"name": "Concealed Wrist Dagger Sleeve",
		"category": "Weapon",
		"price_beli": 28000,
		"weight_kg": 0.9,
		"description": "Spring-loaded forearm bracer concealing a poisoned stiletto blade favored by Five Families hitmen.",
	},
	"steamed_peony_dumplings": {
		"id": "steamed_peony_dumplings",
		"name": "Kano Steamed Peony Dumpling Box",
		"category": "Consumable",
		"price_beli": 1500,
		"weight_kg": 0.8,
		"description": "Delicate steamed dumplings filled with spiced lotus pork and water chestnuts. Restores 35% stamina.",
	},
	"marine_transit_manifest_forged": {
		"id": "marine_transit_manifest_forged",
		"name": "Forged Marine Transit Manifest",
		"category": "Document",
		"price_beli": 50000,
		"weight_kg": 0.2,
		"description": "Masterfully counter-stamped World Government naval customs pass that waives standard boarding inspections.",
	},
	"thriller_timber_splinter": {
		"id": "thriller_timber_splinter",
		"name": "Thriller Bark Excavated Timber Splinter",
		"category": "ShipMaterial",
		"price_beli": 35000,
		"weight_kg": 5.0,
		"description": "A jagged chunk of ancient mineral-dense timber excavated from the caldera where Moria cut out Thriller Bark.",
	},
	"stage_micro_horn": {
		"id": "stage_micro_horn",
		"name": "Broadway Stage Acoustic Micro-Horn",
		"category": "Tool",
		"price_beli": 45000,
		"weight_kg": 2.5,
		"description": "Gilded brass directional megaphone engineered for theatrical acoustics. Amplifies vocal orders across ship decks.",
	},
	"toroa_reed_pipes": {
		"id": "toroa_reed_pipes",
		"name": "Toroa Traditional Reed-Pipes",
		"category": "Instrument",
		"price_beli": 8500,
		"weight_kg": 0.7,
		"description": "Hollowed river-reed pipes producing sweet, piping tones traditional to West Blue coastal folklore.",
	},
	"deep_trench_dredging_hook": {
		"id": "deep_trench_dredging_hook",
		"name": "Deep-Trench Heavy Dredging Hook",
		"category": "Tool",
		"price_beli": 24000,
		"weight_kg": 22.0,
		"description": "Triple-pronged weighted grappling anchor attached to 120 meters of steel winch cable for seabed salvage.",
	},
	"corrupted_magnetic_pose": {
		"id": "corrupted_magnetic_pose",
		"name": "Corrupted God Valley Magnetic Pose",
		"category": "Relic",
		"price_beli": 60000,
		"weight_kg": 0.4,
		"description": "An enigmatic navigational pose whose needle spins violently, occasionally pointing toward severed magnetic lines of erased islands.",
	},
	"boiler_iron_rivets": {
		"id": "boiler_iron_rivets",
		"name": "High-Pressure Boiler Iron Rivets (Keg of 100)",
		"category": "ShipMaterial",
		"price_beli": 8500,
		"weight_kg": 35.0,
		"description": "Heavy heat-treated forged iron rivets from Ballywood foundries used for steam boilers and hull reinforcement.",
	},
	"fencing_rosin_polish": {
		"id": "fencing_rosin_polish",
		"name": "Esperian Fencing Rosin & Blade Polish",
		"category": "Tool",
		"price_beli": 4200,
		"weight_kg": 0.5,
		"description": "Aromatic cake of distilled spruce rosin used to condition violin bows and provide non-slip grip on fencing rapiers.",
	},
	"levely_sea_pass_forged": {
		"id": "levely_sea_pass_forged",
		"name": "Forged Levely Diplomatic Sea Pass",
		"category": "Document",
		"price_beli": 150000,
		"weight_kg": 0.2,
		"description": "High-level diplomatic passport bearing the counterfeit wax seal of King Seki, allowing free transit through naval blockades.",
	},
	"west_blue_cigar_box": {
		"id": "west_blue_cigar_box",
		"name": "West Blue Reserve Aged Cigar Box (25 Cigars)",
		"category": "Luxury",
		"price_beli": 12000,
		"weight_kg": 1.0,
		"description": "Cedar box of hand-rolled aged tobacco cigars favored by Capone 'Gang' Bege and top syndicate underbosses.",
	},
	"abyss_diving_helmet": {
		"id": "abyss_diving_helmet",
		"name": "Abyssal Atmospheric Diving Helmet",
		"category": "DivingGear",
		"price_beli": 85000,
		"weight_kg": 28.0,
		"description": "Heavy cast-bronze pressurized diving helmet equipped with quartz viewing ports and dual air valve attachments for depths exceeding 100 meters.",
	},
	"ballywood_printing_stamp": {
		"id": "ballywood_printing_stamp",
		"name": "Ballywood Movable Type Printing Stamp Set",
		"category": "Tool",
		"price_beli": 14000,
		"weight_kg": 8.5,
		"description": "Lead alloy movable typography blocks for printing pamphlets, theater bills, and counterfeit certificates.",
	},
	"outlaw_bounty_roster": {
		"id": "outlaw_bounty_roster",
		"name": "West Blue Outlaw Bounty Roster",
		"category": "Document",
		"price_beli": 5000,
		"weight_kg": 0.4,
		"description": "Official Marine bounty publication detailing active bounties, last known headings, and dead-or-alive rewards across West Blue.",
	},
	"iron_fortress_blueprints": {
		"id": "iron_fortress_blueprints",
		"name": "Underworld Iron Fortress Blueprint Fragment",
		"category": "Blueprint",
		"price_beli": 180000,
		"weight_kg": 1.2,
		"description": "Classified architectural drawings of Capone Bege's fortress design, detailing armored bulkheads, hidden gun-ports, and internal sluices.",
	},
	"sea_harp": {
		"id": "sea_harp",
		"name": "Mother-of-Pearl Inlaid Sea Harp",
		"category": "Instrument",
		"price_beli": 78000,
		"weight_kg": 6.5,
		"description": "Handcrafted coastal harp strung with treated whale-gut cords, producing resonant melodies that travel far across calm seas.",
	},
	"silverwind_concert_flute": {
		"id": "silverwind_concert_flute",
		"name": "Silverwind Concert Flute (Beast-Calming)",
		"category": "Instrument",
		"price_beli": 65000,
		"weight_kg": 0.8,
		"description": "Virtuoso sterling silver flute tuned to harmonic frequencies that pacify hostile marine wildlife and migratory Island Whales.",
	},
	"red_felt_bandana": {
		"id": "red_felt_bandana",
		"name": "Red Felt Sailor's Bandana",
		"category": "Apparel",
		"price_beli": 2500,
		"weight_kg": 0.2,
		"description": "Crimson felt headscarf worn by sailors in Sake Cove in tribute to the Red-Hair Pirates.",
	},
	"cindry_stage_poster": {
		"id": "cindry_stage_poster",
		"name": "Victoria Cindry Memorial Stage Poster (Vintage)",
		"category": "Relic",
		"price_beli": 25000,
		"weight_kg": 0.3,
		"description": "Authentic stage play poster from Cindry's famous tragic drama in West Blue before her untimely death.",
	},
	"embalming_salve": {
		"id": "embalming_salve",
		"name": "Dr. Hogback's Surgical Embalming Salve",
		"category": "Consumable",
		"price_beli": 16000,
		"weight_kg": 1.5,
		"description": "Pungent preservative unguent formulated by Dr. Hogback to arrest biological decay and mummify organic tissues.",
	},
	"imperial_jasmine_brick": {
		"id": "imperial_jasmine_brick",
		"name": "Kano Imperial Jasmine Tea Brick",
		"category": "Consumable",
		"price_beli": 3200,
		"weight_kg": 1.0,
		"description": "High-mountain compressed jasmine tea brick stamped with the Kano imperial seal. Yields 60 cups of restorative tea.",
	},
	"waterproof_antiquity_lantern": {
		"id": "waterproof_antiquity_lantern",
		"name": "Waterproof Antiquity Dive Lantern",
		"category": "Tool",
		"price_beli": 15000,
		"weight_kg": 3.0,
		"description": "Heavy brass submersible lantern sealed with gum-resin gaskets, illuminating underwater ruins down to 40 meters.",
	},
	"explosive_firework_rockets": {
		"id": "explosive_firework_rockets",
		"name": "Kano Multi-Stage Firework Rockets (Crate of 20)",
		"category": "Weapon",
		"price_beli": 12000,
		"weight_kg": 14.0,
		"description": "Brilliant multi-stage pyrotechnic rockets used for naval celebrations or incendiary bombardment of enemy rigging.",
	},
	"vintage_west_wine": {
		"id": "vintage_west_wine",
		"name": "Vintage West Blue Red Wine (Oak-Aged 20 Years)",
		"category": "Consumable",
		"price_beli": 8000,
		"weight_kg": 1.6,
		"description": "Full-bodied oak-aged vintage red wine from Sake Cove's terraced vineyards. Boosts party health regeneration.",
	},
	"jewel_jade_bullion": {
		"id": "jewel_jade_bullion",
		"name": "Jewel Jade Imperial Bullion (5 kg)",
		"category": "TradeGood",
		"price_beli": 75000,
		"weight_kg": 5.0,
		"description": "Uncut ingot of translucent emerald-green jade quarried from the mountains of Kano Country. Accepted as high-value trade tender worldwide.",
	},
	"royal_fleur_wine": {
		"id": "royal_fleur_wine",
		"name": "Ilusian Royal Fleur Reserve Wine",
		"category": "Consumable",
		"price_beli": 6500,
		"weight_kg": 1.4,
		"description": "Crisp white wine bottled for the court of King Seki. Favored by nobles and diplomats across the Four Seas.",
	},
	"esperian_violin": {
		"id": "esperian_violin",
		"name": "Masterwork Esperian Spruce Violin & Bow",
		"category": "Instrument",
		"price_beli": 110000,
		"weight_kg": 1.2,
		"description": "Flawlessly carved violin made from 200-year-old aged Esperian resonant spruce. Imparts brilliant acoustic projection.",
	},
	"seastone_handcuffs": {
		"id": "seastone_handcuffs",
		"name": "Marine Standard Seastone Handcuffs",
		"category": "Tool",
		"price_beli": 75000,
		"weight_kg": 2.5,
		"description": "High-security handcuffs tipped with Seastone alloy, completely draining the stamina and powers of any Devil Fruit user.",
	},
	"hypnotic_pocket_watch": {
		"id": "hypnotic_pocket_watch",
		"name": "Demon Sheriff's Hypnotic Pocket Watch",
		"category": "Tool",
		"price_beli": 32000,
		"weight_kg": 0.3,
		"description": "Engraved silver pocket watch with an eccentric spiraling face used by Laffitte for hypnotic suggestion and interrogation.",
	},
	"tuning_fork": {
		"id": "tuning_fork",
		"name": "Toroa Bell-Metal Tuning Fork",
		"category": "Tool",
		"price_beli": 3500,
		"weight_kg": 0.2,
		"description": "Precision-tuned bronze fork vibrating at the standard A-440 pitch, ensuring instruments remain harmonically aligned.",
	},
}

# ---------------------------------------------------------------------------
# Geodesic Math & Spherical Utility Functions
# ---------------------------------------------------------------------------

## Converts geographic (lat_deg, lon_deg, alt_m) to 64-bit world Vector3 on the R=16,000,000.0m sphere.
## Convention matches ReverseMountainController & PlanetSphere:
##   lat=0, lon=0 -> +X; lon=+90 -> +Z; lat=+90 -> +Y.
static func spherical_to_world(lat_deg: float, lon_deg: float, alt_m: float = 0.0) -> Vector3:
	var lat_rad: float = deg_to_rad(lat_deg)
	var lon_rad: float = deg_to_rad(lon_deg)
	var cos_lat: float = cos(lat_rad)
	var dir: Vector3 = Vector3(
		cos_lat * cos(lon_rad),
		sin(lat_rad),
		cos_lat * sin(lon_rad)
	).normalized()
	return dir * (PLANET_RADIUS_M + alt_m)


## Converts a 64-bit Cartesian world Vector3 back to spherical geographic coordinates.
static func world_to_spherical(pos: Vector3) -> Dictionary:
	var r: float = pos.length()
	if r <= 0.0001:
		return {"lat_deg": 0.0, "lon_deg": 0.0, "alt_m": -PLANET_RADIUS_M}
	var dir: Vector3 = pos / r
	var lat_deg: float = rad_to_deg(asin(clamp(dir.y, -1.0, 1.0)))
	var lon_deg: float = rad_to_deg(atan2(dir.z, dir.x))
	return {
		"lat_deg": lat_deg,
		"lon_deg": lon_deg,
		"alt_m": r - PLANET_RADIUS_M,
	}


## Calculates the Great Circle surface distance in meters between two spherical points.
static func calculate_surface_distance_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
	var phi1: float = deg_to_rad(lat1)
	var phi2: float = deg_to_rad(lat2)
	var delta_phi: float = deg_to_rad(lat2 - lat1)
	var delta_lambda: float = deg_to_rad(lon2 - lon1)

	var sin_half_dphi: float = sin(delta_phi * 0.5)
	var sin_half_dlam: float = sin(delta_lambda * 0.5)
	var a: float = (sin_half_dphi * sin_half_dphi) + (cos(phi1) * cos(phi2) * sin_half_dlam * sin_half_dlam)
	var c: float = 2.0 * atan2(sqrt(a), sqrt(max(0.0, 1.0 - a)))
	return PLANET_RADIUS_M * c


## Tests whether a given coordinate falls within the West Blue geographic bounding sector.
static func is_coordinate_in_sector(lat_deg: float, lon_deg: float) -> bool:
	return (
		lat_deg >= SECTOR_LAT_MIN and lat_deg <= SECTOR_LAT_MAX and
		lon_deg >= SECTOR_LON_MIN and lon_deg <= SECTOR_LON_MAX
	)


# ---------------------------------------------------------------------------
# Query & Retrieval Public API
# ---------------------------------------------------------------------------

## Returns the geographic bounds dictionary for West Blue.
static func get_sector_bounds() -> Dictionary:
	return {
		"lat_min": SECTOR_LAT_MIN,
		"lat_max": SECTOR_LAT_MAX,
		"lon_min": SECTOR_LON_MIN,
		"lon_max": SECTOR_LON_MAX,
		"planet_radius_m": PLANET_RADIUS_M,
		"meters_per_degree": METERS_PER_DEGREE,
	}


## Returns the master dictionary of all West Blue islands.
static func get_islands() -> Dictionary:
	return ISLANDS


## Returns a specific island dictionary by ID, or an empty Dictionary if not found.
static func get_island(island_id: String) -> Dictionary:
	if ISLANDS.has(island_id):
		return ISLANDS[island_id]
	return {}


## Returns whether an island ID exists in the database.
static func has_island(island_id: String) -> bool:
	return ISLANDS.has(island_id)


## Returns an array of all registered island IDs in West Blue.
static func get_island_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in ISLANDS.keys():
		ids.append(str(key))
	return ids


## Returns an array of all oceanic routes traversing West Blue.
static func get_routes() -> Array[Dictionary]:
	return ROUTES


## Returns a specific route by ID.
static func get_route(route_id: String) -> Dictionary:
	for r in ROUTES:
		if r.get("id") == route_id:
			return r
	return {}


## Returns the Reverse Mountain Gateway approach details.
static func get_reverse_mountain_gateway() -> Dictionary:
	return ISLANDS["west_blue_reverse_mountain_gateway"]


## Returns the exact Reverse Mountain canal entry gate coordinates.
static func get_reverse_mountain_canal_entry() -> Dictionary:
	return {
		"canal_id": REVERSE_MOUNTAIN_CANAL_ID,
		"entry_lat_deg": REVERSE_MOUNTAIN_CANAL_ENTRY_LAT,
		"entry_lon_deg": REVERSE_MOUNTAIN_CANAL_ENTRY_LON,
		"entry_world_pos": spherical_to_world(REVERSE_MOUNTAIN_CANAL_ENTRY_LAT, REVERSE_MOUNTAIN_CANAL_ENTRY_LON, 0.0),
		"ascent_target_speed_mps": 65.0,
		"canal_width_m": 400.0,
	}


## Gathers all marketplace and shop establishments across all West Blue islands.
static func get_all_marketplaces() -> Array[Dictionary]:
	var markets: Array[Dictionary] = []
	for island_id in ISLANDS:
		var island: Dictionary = ISLANDS[island_id]
		var ests: Array = island.get("establishments", [])
		for e in ests:
			var copy: Dictionary = e.duplicate(true)
			copy["island_id"] = island_id
			copy["island_name"] = island.get("name", "")
			markets.append(copy)
	return markets


## Gathers all named NPCs (both canon and archetype) across all West Blue islands.
static func get_all_npcs() -> Array[Dictionary]:
	var npcs: Array[Dictionary] = []
	for island_id in ISLANDS:
		var island: Dictionary = ISLANDS[island_id]
		for c_npc in island.get("canon_npcs", []):
			var c: Dictionary = c_npc.duplicate(true)
			c["island_id"] = island_id
			c["type"] = "canon"
			npcs.append(c)
		for a_npc in island.get("archetype_npcs", []):
			var a: Dictionary = a_npc.duplicate(true)
			a["island_id"] = island_id
			a["type"] = "archetype"
			npcs.append(a)
	return npcs


## Returns all settlements and ports across West Blue.
static func get_settlements() -> Array[Dictionary]:
	var setts: Array[Dictionary] = []
	for island_id in ISLANDS:
		var island: Dictionary = ISLANDS[island_id]
		for s in island.get("settlements", []):
			var sc: Dictionary = s.duplicate(true)
			sc["island_id"] = island_id
			setts.append(sc)
	return setts


## Returns the master catalog of all regional items and equipment.
static func get_items() -> Dictionary:
	return ITEMS


## Returns a single item record by ID.
static func get_item(item_id: String) -> Dictionary:
	if ITEMS.has(item_id):
		return ITEMS[item_id]
	return {}


## Gathers all exploration and quest hooks in West Blue.
static func get_lore_hooks() -> Array[Dictionary]:
	var hooks: Array[Dictionary] = []
	for island_id in ISLANDS:
		var island: Dictionary = ISLANDS[island_id]
		for h in island.get("exploration_hooks", []):
			var hc: Dictionary = h.duplicate(true)
			hc["island_id"] = island_id
			hooks.append(hc)
	return hooks


## Finds the closest West Blue island to any given spherical coordinates.
static func find_nearest_island(lat_deg: float, lon_deg: float) -> Dictionary:
	var closest_island: Dictionary = {}
	var min_dist_m: float = 1e20

	for island_id in ISLANDS:
		var island: Dictionary = ISLANDS[island_id]
		var coords: Dictionary = island.get("coordinates", {})
		var dist_m: float = calculate_surface_distance_m(
			lat_deg, lon_deg,
			coords.get("lat", 0.0), coords.get("lon", 0.0)
		)
		if dist_m < min_dist_m:
			min_dist_m = dist_m
			closest_island = island.duplicate(true)
			closest_island["distance_m"] = dist_m

	return closest_island


## Self-validation routine ensuring all island records contain valid coordinates, establishments, and items.
static func validate_data() -> bool:
	var valid: bool = true
	for island_id in ISLANDS:
		var isl: Dictionary = ISLANDS[island_id]
		var coords: Dictionary = isl.get("coordinates", {})
		var lat: float = coords.get("lat", 999.0)
		var lon: float = coords.get("lon", 999.0)
		if not is_coordinate_in_sector(lat, lon):
			# Note: Gateway is at lat -15.5, lon -2.5 (right inside the sector bounds)
			push_warning("Island coordinate out of sector: " + island_id + " at (" + str(lat) + ", " + str(lon) + ")")
			valid = false

		for est in isl.get("establishments", []):
			for item_id in est.get("inventory", []):
				if not ITEMS.has(item_id):
					push_error("Establishment references unknown item ID: " + str(item_id) + " on island: " + island_id)
					valid = false
	return valid
