# north_blue_data.gd
# Production GDScript 4 Data Module for Project "Blue Planet"
# Scale: Godot 4.3+ (precision=double), 1 unit = 1 meter, Planet Radius R = 16,000,000.0m
# Sector: North Blue Region (theta in [+15 deg, +75 deg], phi in [-90 deg, 0 deg])
# Center: Planet origin at Vector3.ZERO
class_name NorthBlueData
extends RefCounted

## Planet sea-level radius in meters (64-bit precision).
const PLANET_RADIUS: float = 16000000.0

## Geographic sector bounds for North Blue.
const LAT_MIN: float = 15.0
const LAT_MAX: float = 75.0
const LON_MIN: float = -90.0
const LON_MAX: float = 0.0

## North Blue Reverse Mountain Canal Entrance (Spherical coordinates at base of Red Line).
const CANAL_ENTRANCE_LAT: float = 2.25
const CANAL_ENTRANCE_LON: float = -1.60

## Nomadic Germa 66 Snail-Ship Fleet Waypoints (Patrol circuit across North Blue).
const GERMA_PATROL_ROUTE: Array[Vector2] = [
	Vector2(24.5, -65.0), # Staging waters south of Spider Miles
	Vector2(31.0, -48.0), # Central North Blue trade shipping corridor
	Vector2(42.0, -38.0), # Approach waters toward old Flevance perimeter
	Vector2(53.0, -22.0), # Northern feudal kingdoms (Deul & Whiteland border waters)
	Vector2(48.5, -55.0), # High-latitude crossing near Swallow & Rubeck islands
	Vector2(36.0, -72.0), # Western deep open sea border
]

## Speed of Germa mobile kingdom in knots (1 knot ~= 0.514444 m/s).
const GERMA_CRUISING_SPEED_KNOTS: float = 18.0
const GERMA_CRUISING_SPEED_MPS: float = 9.26

## Total patrol loop period in game hours.
const GERMA_PATROL_PERIOD_HOURS: float = 120.0

# -----------------------------------------------------------------------------
# GEODETIC / SPHERICAL CONVERSION HELPERS
# -----------------------------------------------------------------------------

## Converts spherical coordinates (latitude degrees, longitude degrees, altitude meters)
## into a 64-bit cartesian position vector centered on the planet.
## Coordinate convention:
##   Y axis: Planetary North Pole (+90 deg Lat)
##   X axis: Equatorial Prime Meridian intersection (0 deg Lat, 0 deg Lon)
##   Z axis: Equatorial 90 deg East longitude (+90 deg Lon)
static func lat_lon_to_cartesian(lat_deg: float, lon_deg: float, alt_m: float = 0.0) -> Vector3:
	var lat_rad: float = deg_to_rad(lat_deg)
	var lon_rad: float = deg_to_rad(lon_deg)
	var r: float = PLANET_RADIUS + alt_m
	
	var cos_lat: float = cos(lat_rad)
	var x: float = r * cos_lat * cos(lon_rad)
	var y: float = r * sin(lat_rad)
	var z: float = r * cos_lat * sin(lon_rad)
	return Vector3(x, y, z)

## Converts a 64-bit world cartesian position vector into spherical coordinates.
## Returns Dictionary with keys "lat", "lon", "alt".
static func cartesian_to_lat_lon(pos: Vector3) -> Dictionary:
	var r: float = pos.length()
	var alt: float = r - PLANET_RADIUS
	if r <= 0.0001:
		return {"lat": 0.0, "lon": 0.0, "alt": alt}
	
	var lat_rad: float = asin(clamp(pos.y / r, -1.0, 1.0))
	var lon_rad: float = atan2(pos.z, pos.x)
	return {
		"lat": rad_to_deg(lat_rad),
		"lon": rad_to_deg(lon_rad),
		"alt": alt
	}

## Returns the great-circle surface distance in meters between two lat/lon pairs.
static func surface_distance_meters(lat1_deg: float, lon1_deg: float, lat2_deg: float, lon2_deg: float) -> float:
	var lat1: float = deg_to_rad(lat1_deg)
	var lon1: float = deg_to_rad(lon1_deg)
	var lat2: float = deg_to_rad(lat2_deg)
	var lon2: float = deg_to_rad(lon2_deg)
	
	var dlat: float = lat2 - lat1
	var dlon: float = lon2 - lon1
	
	var a: float = sin(dlat * 0.5) * sin(dlat * 0.5) + cos(lat1) * cos(lat2) * sin(dlon * 0.5) * sin(dlon * 0.5)
	var c: float = 2.0 * atan2(sqrt(a), sqrt(max(0.0, 1.0 - a)))
	return PLANET_RADIUS * c

# -----------------------------------------------------------------------------
# MASTER ISLAND AND SETTLEMENT REGISTRY
# -----------------------------------------------------------------------------

## Returns an array of all canonical North Blue island records for WorldRegistrySystem.
static func get_all_islands() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var islands: Dictionary = get_islands()
	for id_key: String in islands:
		result.append(islands[id_key])
	return result

## Returns the dictionary of all canonical North Blue islands and key locations.
static func get_islands() -> Dictionary:
	return {
		"lvneel_kingdom": _get_lvneel_data(),
		"flevance_ruins": _get_flevance_data(),
		"spider_miles": _get_spider_miles_data(),
		"minion_island": _get_minion_island_data(),
		"swallow_island": _get_swallow_island_data(),
		"rubeck_island": _get_rubeck_island_data(),
		"notice_town": _get_notice_data(),
		"rakesh_port": _get_rakesh_data(),
		"downs_cove": _get_downs_data(),
		"micqueot_land": _get_micqueot_data(),
		"kuen_village": _get_kuen_village_data(),
		"deul_kingdom": _get_deul_kingdom_data(),
		"whiteland_kingdom": _get_whiteland_kingdom_data(),
		"germa_kingdom_mobile": _get_germa_kingdom_base_data()
	}

## Returns a single island dictionary by ID, or empty dict if not found.
static func get_island(island_id: String) -> Dictionary:
	var all_islands: Dictionary = get_islands()
	if all_islands.has(island_id):
		return all_islands[island_id]
	return {}

## Finds the closest registered North Blue island within tolerance degrees.
static func get_island_at_coords(lat: float, lon: float, tolerance_deg: float = 1.0) -> Dictionary:
	var all_islands: Dictionary = get_islands()
	var closest_island: Dictionary = {}
	var min_dist: float = 999999.0
	
	for island_id: String in all_islands:
		var data: Dictionary = all_islands[island_id]
		var coords: Dictionary = data.get("coordinates", {})
		var ilat: float = coords.get("lat", 0.0)
		var ilon: float = coords.get("lon", 0.0)
		var dlat: float = lat - ilat
		var dlon: float = lon - ilon
		var deg_dist: float = sqrt(dlat * dlat + dlon * dlon)
		if deg_dist < tolerance_deg and deg_dist < min_dist:
			min_dist = deg_dist
			closest_island = data
			
	return closest_island

# -----------------------------------------------------------------------------
# DETAILED ISLAND DATA DEFINITIONS
# -----------------------------------------------------------------------------

static func _get_lvneel_data() -> Dictionary:
	return {
		"id": "lvneel_kingdom",
		"name": "Lvneel Kingdom",
		"japanese_name": "ルブニール王国 (Rubunīru Ōkoku)",
		"lat_deg": 28.50,
		"lon_deg": -18.20,
		"alt_m": 12.0,
		"lat": 28.50,
		"lon": -18.20,
		"coordinates": {"lat": 28.50, "lon": -18.20, "altitude": 12.0},
		"radius_meters": 115000.0,
		"biome": "Temperate Coastal Forest & Royal Botanical Terraces",
		"climate": "Mild Maritime with lush floral seasons",
		"political_status": "World Government Allied Sovereign Monarchy",
		"ruling_dynasty": "House of Lvneel (Successors to King Aruyutayan V)",
		"lore_summary": "Ancient prestigious kingdom famous as the birthplace of the legendary botanist and explorer Mont Blanc Noland 400 years ago. After reporting the Golden City of Shandora on Jaya to King Aruyutayan V, Noland was branded a liar and executed when the island was blasted into the sky. The kingdom retains magnificent royal archives, an active botanical guild, and the solemn execution square where 'Liar Noland' was beheaded.",
		"ports": [
			{
				"id": "port_lvneel_royal",
				"name": "Port Northheim (Lvneel Grand Harbor)",
				"lat_deg": 28.32,
		"lon_deg": -18.05,
		"alt_m": 0.0,
		"lat": 28.32,
		"lon": -18.05,
		"coordinates": {"lat": 28.32, "lon": -18.05, "altitude": 0.0},
				"water_depth_meters": 28.0,
				"dock_fee_beli": 4500,
				"harbormaster": "Commander Alistair Vance",
				"facilities": ["Drydock Repair", "Astronomical Chart Bureau", "Royal Botanical Customs", "Tavern District"]
			}
		],
		"towns": [
			{
				"id": "town_lvneel_capital",
				"name": "Lvneel Royal Capital & Noland Memorial Square",
				"population": 185000,
				"description": "Grand classical white-columned city featuring the Execution Scaffold Monument, the Royal Academy of Botany, and the King Aruyutayan Archives."
			}
		],
		"shops": [
			{
				"id": "shop_lvneel_botanical",
				"name": "Lvneel Royal Botanical Exchange",
				"type": "Botanical Nursery & Expedition Supply",
				"keeper": "Master Horticulturist Ross",
				"inventory": [
					{
						"item_id": "seed_golden_pumpkin",
						"name": "Lvneel Golden Pumpkin Seeds",
						"category": "Agricultural Seed",
						"price_beli": 25000,
						"stock": 12,
						"trade_multiplier": 2.2,
						"description": "Rare cultivar descendant of Noland's historical botanical specimens. Produces giant pumpkins that replenish crew morale and combat scurvy."
					},
					{
						"item_id": "wood_kona_tree_sap",
						"name": "Kona Tree Extract Ointment",
						"category": "Medicine",
						"price_beli": 3500,
						"stock": 40,
						"trade_multiplier": 1.4,
						"description": "Herbal salve derived from tropical trees cataloged during the Great Lvneel Exploration of 1120. Cures jungle fevers and mild poison."
					},
					{
						"item_id": "item_surveying_astrolabe",
						"name": "North Sea Brass Astrolabe",
						"category": "Navigational Instrument",
						"price_beli": 85000,
						"stock": 4,
						"trade_multiplier": 1.8,
						"description": "Precision nautical instrument crafted by royal horologists. Decreases cartography surveying errors on uncharted coastlines by 25%."
					}
				]
			},
			{
				"id": "tavern_liar_roost",
				"name": "The Golden Bell Tavern & Archives",
				"type": "Tavern & Information Hub",
				"keeper": "Old Cedric (Historian Bartender)",
				"inventory": [
					{
						"item_id": "drink_lvneel_amber_ale",
						"name": "Lvneel Spiced Amber Ale",
						"category": "Provision",
						"price_beli": 450,
						"stock": 100,
						"trade_multiplier": 1.1,
						"description": "Traditional northern brew fermented with wild mountain honey and cloves."
					},
					{
						"item_id": "book_noland_the_liar",
						"name": "Picture Book: 'Noland the Liar'",
						"category": "Lore Item",
						"price_beli": 1200,
						"stock": 25,
						"trade_multiplier": 1.5,
						"description": "The widely distributed North Blue children's book depicting Mont Blanc Noland weeping before his executioners. Increases scholar knowledge of Grand Line myths."
					}
				]
			}
		],
		"npcs": [
			{
				"id": "npc_cedric_historian",
				"name": "Cedric of the Northheim Archive",
				"title": "Keeper of the Forgotten Logs",
				"role": "Lore Master & Questgiver",
				"location": "The Golden Bell Tavern",
				"dialogue_intro": "Four hundred years... and our kingdom still paints him as a clown to soothe royal pride. But Noland's logs do not lie, sailor. Have you looked toward the sky?",
				"dialogue_topics": {
					"Noland's Expedition": "In Year 1120 of the Sea Calendar, Noland set sail aboard the Northheim. He crossed the Calm Belt without engines, navigating by pure astronomical genius.",
					"King Aruyutayan V": "The fifth king was an arrogant tyrant who emptied the treasury chasing gold. When Jaya was severed, he executed Noland to conceal his own failure.",
					"Mont Blanc Cricket": "Noland's living bloodline fled to the Grand Line long ago. Rumor has it a descendant still dives into Jaya's abyss searching for the sunken gold."
				},
				"bounty_beli": 0,
				"is_canon": false
			},
			{
				"id": "npc_royal_botanist_elena",
				"name": "Elena Ross",
				"title": "Curator of the Royal Arboretum",
				"role": "Botanist Merchant & Quest Broker",
				"location": "Lvneel Royal Botanical Exchange",
				"dialogue_intro": "A botanist must look at plants with reverence, not greed. Noland brought back samples that saved thousands from tree-fever.",
				"dialogue_topics": {
					"Tree Fever Cure": "The Kona tree was the miracle Noland used to save the Shandia tribe. We still cultivate its distant cousins in our high glasshouses.",
					"Grand Line Flora": "The weather across the Calm Belt warps plant physiology. If you voyage toward Reverse Mountain, stock hearty seeds that tolerate rapid climatic shock."
				},
				"bounty_beli": 0,
				"is_canon": false
			}
		],
		"hazards": [
			{"type": "Royal Guard Inspection", "severity": 0.25, "description": "Strict customs checks; any contraband or piratical flags incur heavy harbor fines."}
		],
		"exploration_hooks": [
			{
				"id": "hook_lvneel_lost_log",
				"title": "The 400-Year-Old Logbook Fragment",
				"description": "Recover the missing coastal navigational page from Noland's Northheim journal, rumored to be held in a private auction vault behind the royal plaza."
			}
		]
	}

static func _get_flevance_data() -> Dictionary:
	return {
		"id": "flevance_ruins",
		"name": "Flevance (The White City Ruins)",
		"japanese_name": "フレバンス (Frebansu)",
		"lat_deg": 44.15,
		"lon_deg": -41.80,
		"alt_m": 45.0,
		"lat": 44.15,
		"lon": -41.80,
		"coordinates": {"lat": 44.15, "lon": -41.80, "altitude": 45.0},
		"radius_meters": 78000.0,
		"biome": "Toxic Mineral Ruins & Calcified Chalk Forest",
		"climate": "Chilly Alpine Mist with Heavy Toxic Particulates",
		"political_status": "Quarantined Extinct Kingdom (Biohazard Exclusion Zone)",
		"ruling_dynasty": "Former House of Flevance (Extinct / Absconded)",
		"lore_summary": "Once celebrated throughout the world as a breathtaking fairytale kingdom where ground, trees, and stone shone alabaster white. The source of this beauty was Amber Lead—a wondrous subterranean ore used for pigments, chinaware, cosmetics, and armor. However, Amber Lead was a bioaccumulative heavy toxin. Both the World Government and local monarchy hid the fatal truth for centuries to preserve profits. Sixteen years ago, as entire generations succumbed to Amber Lead Syndrome, neighboring kingdoms blockaded the borders and exterminated the dying populace. Trafalgar D. Water Law was the sole survivor.",
		"ports": [
			{
				"id": "port_flevance_breakwater",
				"name": "Shattered Quarantine Quarantine Docks",
				"lat_deg": 43.85,
		"lon_deg": -41.50,
		"alt_m": 0.0,
		"lat": 43.85,
		"lon": -41.50,
		"coordinates": {"lat": 43.85, "lon": -41.50, "altitude": 0.0},
				"water_depth_meters": 18.0,
				"dock_fee_beli": 0,
				"harbormaster": "None (Abandoned / Automated Warning Beacons)",
				"facilities": ["Decaying Jetties", "Hazard Warning Signs", "Smuggler Cache"]
			}
		],
		"towns": [
			{
				"id": "town_flevance_necropolis",
				"name": "The Calcified Citadel (Silent White City)",
				"population": 0,
				"description": "Silent, snow-white streets where ruined cathedrals, crumbling hospital wings, and bone-white houses stand covered in chalky dust and rusted quarantine fences."
			}
		],
		"shops": [
			{
				"id": "shop_flevance_hazmat_scavenger",
				"name": "Hazmat Scavenger Den (Underground Crypt)",
				"type": "Black Market Scrap & Toxic Salvage",
				"keeper": "Kroll the Masked",
				"inventory": [
					{
						"item_id": "ore_raw_amber_lead",
						"name": "Raw Amber Lead Ore Chunk",
						"category": "Contraband Mineral",
						"price_beli": 45000,
						"stock": 18,
						"trade_multiplier": 3.5,
						"description": "Luminous, snow-white metallic mineral with intense hardness. Highly valuable to shady black-market armorers, but emits dangerous lead toxicity if handled without sealed gloves."
					},
					{
						"item_id": "item_flevance_lead_paint",
						"name": "Original Flevance Alabaster Lacquer",
						"category": "Luxury Material",
						"price_beli": 18000,
						"stock": 10,
						"trade_multiplier": 2.8,
						"description": "Ancient paint jar of the iconic gleaming white hue that once coated every palace wall. Extremely toxic."
					},
					{
						"item_id": "item_lead_filter_respirator",
						"name": "Military Charcoal Dust Mask",
						"category": "Survival Gear",
						"price_beli": 8500,
						"stock": 8,
						"trade_multiplier": 1.2,
						"description": "Heavy dual-canister breather mask that prevents toxic dust inhalation while exploring the White City mines."
					},
					{
						"item_id": "schematic_surgical_scalpel",
						"name": "Water Law's Hospital Clinic Blueprint",
						"category": "Medical Schematic",
						"price_beli": 60000,
						"stock": 1,
						"trade_multiplier": 2.0,
						"description": "Surgical operating room layout preserved from Law's father's clinic. Unlocks advanced field medical crafting in ship doctor bays."
					}
				]
			}
		],
		"npcs": [
			{
				"id": "npc_kroll_scavenger",
				"name": "Kroll the Masked",
				"title": "Lead-Eater Scavenger Boss",
				"role": "Black Market Merchant & Biohazard Guide",
				"location": "The Broken Hospital Undercroft",
				"dialogue_intro": "Keep that respirator strapped tight, rookie. The white dust in the air doesn't care who your captain is. One breath too deep and your grandkids will pay for it.",
				"dialogue_topics": {
					"The Amber Lead Tragedy": "They told the world it was an infectious plague. Lies! The World Government knew it was poisoning the blood 100 years prior, yet the kings kept digging.",
					"The Little Doctor Boy": "They say one child escaped through the corpse carts. Now there's a demon roaming Paradise calling himself the Surgeon of Death. Can't blame him."
				},
				"bounty_beli": 14000000,
				"is_canon": false
			}
		],
		"hazards": [
			{
				"type": "Amber Lead Dust Inhalation",
				"severity": 0.85,
				"description": "Requires Charcoal Dust Mask or airtight spacesuit. Lingering in town without protection causes progressive maximum HP reduction."
			},
			{
				"type": "Automated Marine Sentry Turrets",
				"severity": 0.60,
				"description": "Automated gun emplacements on the perimeter wall fire upon unidentified vessels attempting to land."
			}
		],
		"exploration_hooks": [
			{
				"id": "hook_flevance_hospital_vault",
				"title": "The Water Family Medical Journal",
				"description": "Infiltrate the collapsed basement of Dr. Water's clinic beneath the central plaza to locate his original treatise on heavy metal blood filtration."
			}
		]
	}

static func _get_spider_miles_data() -> Dictionary:
	return {
		"id": "spider_miles",
		"name": "Spider Miles",
		"japanese_name": "スパイダーマイルズ (Supaidā Mairuzu)",
		"lat_deg": 22.10,
		"lon_deg": -53.90,
		"alt_m": 4.0,
		"lat": 22.10,
		"lon": -53.90,
		"coordinates": {"lat": 22.10, "lon": -53.90, "altitude": 4.0},
		"radius_meters": 62000.0,
		"biome": "Industrial Waste Slag Basin & Smelting Docks",
		"climate": "Hot, Acrid Smog with Ashfall and Sulfuric Fumes",
		"political_status": "Lawless Industrial Port & Smuggler Haven",
		"ruling_dynasty": "Underworld Scrapyard Syndicates (Former Donquixote Base)",
		"lore_summary": "A desolate, smog-choked port town dominated by monumental scrap processing complexes, abandoned blast furnaces, and mountains of twisted naval iron. Sixteen years ago, Donquixote Doflamingo established the original headquarters of the Donquixote Pirates here, welcoming a young, grenade-strapped Trafalgar Law into the family. Today, the town remains North Blue's premiere hub for illegal iron dismantling, arms forgery, and black-market ship armor.",
		"ports": [
			{
				"id": "port_spider_slag_basin",
				"name": "Spider Miles Slag Basin",
				"lat_deg": 21.95,
		"lon_deg": -53.75,
		"alt_m": 0.0,
		"lat": 21.95,
		"lon": -53.75,
		"coordinates": {"lat": 21.95, "lon": -53.75, "altitude": 0.0},
				"water_depth_meters": 16.0,
				"dock_fee_beli": 1500,
				"harbormaster": "Iron-Jaw Briggs",
				"facilities": ["Scrap Hull Repair", "Black Market Fuel Depot", "Illegal Forge", "Underworld Arms Exchange"]
			}
		],
		"towns": [
			{
				"id": "town_spider_miles_slums",
				"name": "Rust Quarter & The Foundry Citadel",
				"population": 42000,
				"description": "Labyrinth of corrugated sheet metal shanties, burning slag canals, and the cavernous warehouse that served as Doflamingo's early command hall."
			}
		],
		"shops": [
			{
				"id": "shop_spider_arms_forge",
				"name": "Vulcan's Scrap & Heavy Ordinance",
				"type": "Black Market Arms & Heavy Ship Plating",
				"keeper": "Briggs the Welder",
				"inventory": [
					{
						"item_id": "armor_recycled_battleship_plate",
						"name": "Scrapped Marine Hull Plating",
						"category": "Ship Upgrade Material",
						"price_beli": 75000,
						"stock": 14,
						"trade_multiplier": 1.6,
						"description": "Heavy armored plates sheared off decommissioned Marine corvettes. Enhances ship hull defense against cannon fire by +15%."
					},
					{
						"item_id": "weapon_north_blue_grenade_crate",
						"name": "Spider Miles Demolition Crate",
						"category": "Explosive Weapon",
						"price_beli": 32000,
						"stock": 20,
						"trade_multiplier": 1.3,
						"description": "Crate of 12 contact-fuse fragmentation grenades of the design Law strapped to his chest as a child."
					},
					{
						"item_id": "item_lead_lined_smuggling_crate",
						"name": "Lead-Lined Smuggling Locker",
						"category": "Ship Utility",
						"price_beli": 48000,
						"stock": 5,
						"trade_multiplier": 1.7,
						"description": "Shields cargo hold contents from Marine Den Den Mushi radar and inspection scans."
					}
				]
			},
			{
				"id": "bar_pink_flamingo_ruins",
				"name": "The Flamingo's Perch Tavern",
				"type": "Outlaw Bar & Rumor Mill",
				"keeper": "Madam Roxie",
				"inventory": [
					{
						"item_id": "drink_slag_whiskey",
						"name": "Spider Miles 120-Proof Slag Moonshine",
						"category": "Provision",
						"price_beli": 300,
						"stock": 80,
						"trade_multiplier": 1.0,
						"description": "Rough, throat-scorching spirits distilled in scrap boiler pipes."
					},
					{
						"item_id": "intel_donquixote_cache",
						"name": "Old Donquixote Family Cache Map",
						"category": "Treasure Map",
						"price_beli": 95000,
						"stock": 1,
						"trade_multiplier": 2.5,
						"description": "Faded hand-drawn map indicating a concealed vault where Corazon and Trebol buried weapons shipments before leaving for Minion Island."
					}
				]
			}
		],
		"npcs": [
			{
				"id": "npc_briggs_welder",
				"name": "Iron-Jaw Briggs",
				"title": "Master of the Slag Basin",
				"role": "Shipwright & Black Market Merchant",
				"location": "Vulcan's Scrap Forge",
				"dialogue_intro": "You want your hull to survive the Grand Line? Wood won't cut it against the monsters down south. You need cold North Blue steel, hammered thick.",
				"dialogue_topics": {
					"Doflamingo's Days": "Ten years Doflamingo ruled these docks. He was ruthless, but he paid gold on the nail. Once he got the Warlord title, he left for the Grand Line and never looked back.",
					"Baby 5 and Buffalo": "I remember those brats running across the scrap piles. Baby 5 would do anything if you told her you needed her. Creepy loyalty."
				},
				"bounty_beli": 8500000,
				"is_canon": false
			}
		],
		"hazards": [
			{"type": "Acidic Smog", "severity": 0.35, "description": "Causes mild coughing and stamina drain during protracted foot sprints outdoors."}
		],
		"exploration_hooks": [
			{
				"id": "hook_spider_scrap_vault",
				"title": "The Submerged Boiler Vault",
				"description": "Dive into the flooded lower basement of the central foundry to salvage high-grade rifling tools left behind by the Donquixote arms smiths."
			}
		]
	}

static func _get_minion_island_data() -> Dictionary:
	return {
		"id": "minion_island",
		"name": "Minion Island",
		"japanese_name": "ミニオン島 (Minion-tō)",
		"lat_deg": 51.20,
		"lon_deg": -60.50,
		"alt_m": 24.0,
		"lat": 51.20,
		"lon": -60.50,
		"coordinates": {"lat": 51.20, "lon": -60.50, "altitude": 24.0},
		"radius_meters": 45000.0,
		"biome": "Snowy Taiga Forest & Ruined Pirate Redoubt",
		"climate": "Perpetual Subarctic Winter with Heavy Blizzards",
		"political_status": "Uninhabited Ruin (Site of the Op-Op Fruit Incident)",
		"ruling_dynasty": "None (Former Stronghold of Diez Barrels)",
		"lore_summary": "A desolate, snow-covered island in the northern reaches of North Blue. Sixteen years ago, ex-Marine rear admiral Diez Barrels and his pirate crew fortified an abandoned stone fortress here while preparing to sell the Ope Ope no Mi to the World Government for 5,000,000,000 Beli. Donquixote Rosinante (Corazon) infiltrated the base, endured gunfire, and stole the fruit to feed it to the dying Law. Doflamingo arrived shortly after, trapped the island in his colossal Birdcage, murdered Barrels and Rosinante, while young X Drake escaped into the snow to be rescued by Marine Vice Admiral Tsuru.",
		"ports": [
			{
				"id": "port_minion_frozen_cove",
				"name": "Frozen Anchorage Cove",
				"lat_deg": 51.05,
		"lon_deg": -60.35,
		"alt_m": 0.0,
		"lat": 51.05,
		"lon": -60.35,
		"coordinates": {"lat": 51.05, "lon": -60.35, "altitude": 0.0},
				"water_depth_meters": 14.0,
				"dock_fee_beli": 0,
				"harbormaster": "None (Frozen Natural Shoreline)",
				"facilities": ["Sheltered Bay", "Old Campfire Shelters"]
			}
		],
		"towns": [
			{
				"id": "town_minion_fortress_ruins",
				"name": "Barrels Pirates Ruined Redoubt",
				"population": 0,
				"description": "Charred stone battlements collapsed by Doflamingo's strings, with ancient bloodstains preserved beneath the permafrost."
			}
		],
		"shops": [
			{
				"id": "shop_minion_snow_trapper",
				"name": "Winter Trapper's Cache",
				"type": "Wilderness Supplies & Relics",
				"keeper": "Old Hatcher",
				"inventory": [
					{
						"item_id": "coat_taiga_bear_parka",
						"name": "Minion Snow-Bear Parka",
						"category": "Cold Weather Armor",
						"price_beli": 12500,
						"stock": 6,
						"trade_multiplier": 1.5,
						"description": "Heavy fur parka providing complete immunity to freezing conditions and subarctic blizzards."
					},
					{
						"item_id": "relic_charred_birdcage_strand",
						"name": "Severed Razor String Strand",
						"category": "Material Relic",
						"price_beli": 55000,
						"stock": 2,
						"trade_multiplier": 3.0,
						"description": "Thin, razor-sharp steel filament infused with residual strings from Doflamingo's Birdcage. High-tier crafting ingredient for wire traps."
					},
					{
						"item_id": "ammo_marine_cal_50_rounds",
						"name": "Diez Barrels Marine-Issue Munitions",
						"category": "Ammunition",
						"price_beli": 8000,
						"stock": 30,
						"trade_multiplier": 1.2,
						"description": "Heavy-caliber rifle cartridges recovered from Barrels' armory."
					}
				]
			}
		],
		"npcs": [
			{
				"id": "npc_old_hatcher_trapper",
				"name": "Hatcher the Hermit",
				"title": "Sole Witness of the Birdcage",
				"role": "Wilderness Guide & Lore Teller",
				"location": "The Hollowed Pine Cabin",
				"dialogue_intro": "I was hiding in the root caves when the sky turned into a cage of silver wire. Fire everywhere, men screaming... then silence, save for a child crying in the snow.",
				"dialogue_topics": {
					"Corazon's Sacrifice": "The tall man in the feather coat... he was riddled with bullet holes, yet he smiled as he leaned against the treasure chest. His silent magic kept that boy alive.",
					"Diez Drake's Escape": "Young Drake was bruised head to toe from his father's beatings. When the fire started, he ran like a mad dog into the beach where Tsuru's warship plucked him from the ice."
				},
				"bounty_beli": 0,
				"is_canon": false
			}
		],
		"hazards": [
			{"type": "Whiteout Blizzards", "severity": 0.65, "description": "Periodic snowstorms reduce visibility to zero and slow overland movement by 50%."},
			{"type": "Permafrost Frostbite", "severity": 0.40, "description": "Unprepared adventurers take cold damage every 30 seconds without winter gear."}
		],
		"exploration_hooks": [
			{
				"id": "hook_minion_corazon_chest",
				"title": "The Silent Treasure Chest Site",
				"description": "Locate the snowbank clearing where Rosinante concealed the young Law inside a wooden Marine munitions chest under his Nagi Nagi no Mi soundproof barrier."
			}
		]
	}

static func _get_swallow_island_data() -> Dictionary:
	return {
		"id": "swallow_island",
		"name": "Swallow Island",
		"japanese_name": "スワロー島 (Suwarō-tō)",
		"lat_deg": 52.00,
		"lon_deg": -62.10,
		"alt_m": 35.0,
		"lat": 52.00,
		"lon": -62.10,
		"coordinates": {"lat": 52.00, "lon": -62.10, "altitude": 35.0},
		"radius_meters": 58000.0,
		"biome": "Alpine Swallow-Wing Peaks & Coniferous Forests",
		"climate": "Chilly Maritime Spring & Mountain Breezes",
		"political_status": "Independent Autonomous Settlement",
		"ruling_dynasty": "Pleasure Town Civic Council",
		"lore_summary": "A distinctive island shaped like a swallow spreading its wings. Trafalgar Law washed ashore here after fleeing Minion Island. In Pleasure Town, he met the eccentric, generous inventor Wolf, who took him in and funded the town's reconstruction using the island's legendary hidden treasure. Here Law befriended Bepo the Mink (who had drifted from Zou), along with Shachi and Penguin, defeated Wolf's villainous son Artur Bacca (user of the Dero Dero no Mi), and built their iconic yellow submarine, the Polar Tang, founding the Heart Pirates.",
		"ports": [
			{
				"id": "port_swallow_pleasure_dock",
				"name": "Pleasure Town Harbor",
				"lat_deg": 51.85,
		"lon_deg": -61.90,
		"alt_m": 0.0,
		"lat": 51.85,
		"lon": -61.90,
		"coordinates": {"lat": 51.85, "lon": -61.90, "altitude": 0.0},
				"water_depth_meters": 22.0,
				"dock_fee_beli": 2000,
				"harbormaster": "Foreman Otto",
				"facilities": ["Advanced Submersible Drydock", "Pneumatic Workshop", "Tavern", "Fish Market"]
			}
		],
		"towns": [
			{
				"id": "town_swallow_pleasure",
				"name": "Pleasure Town",
				"population": 28000,
				"description": "Cozy, prosperous mountain-valley town rebuilt by inventor Wolf with clockwork streetlamps, hydraulic heating channels, and pleasant bakeries."
			}
		],
		"shops": [
			{
				"id": "shop_wolf_invention_foundry",
				"name": "Wolf's Geodesic Workshop & Submarine Drydock",
				"type": "Advanced Ship Engineering & Submersible Works",
				"keeper": "Master Inventor Wolf",
				"inventory": [
					{
						"item_id": "upgrade_submarine_diving_ballast",
						"name": "Polar Tang Pneumatic Ballast System",
						"category": "Ship Submersible Module",
						"price_beli": 350000,
						"stock": 2,
						"trade_multiplier": 1.9,
						"description": "Wolf's proprietary submarine ballast blueprint. Allows custom vessels to submerge to depths of -250 meters without resin coating."
					},
					{
						"item_id": "gear_submersible_oxygen_scrubber",
						"name": "Rebreather Carbon Filter Unit",
						"category": "Naval Equipment",
						"price_beli": 42000,
						"stock": 6,
						"trade_multiplier": 1.5,
						"description": "Extends ship underwater diving air reserves by 4 hours."
					},
					{
						"item_id": "food_wolf_maple_syrup",
						"name": "Swallow Mountain Maple Syrup",
						"category": "Provision",
						"price_beli": 850,
						"stock": 50,
						"trade_multiplier": 1.3,
						"description": "Sweet, high-energy mountain syrup favored by Mink crewmates and bear cubs."
					}
				]
			},
			{
				"id": "bakery_swallow_wing",
				"name": "Pleasure Town Bakery & Tea House",
				"type": "Bakery & Rest Stop",
				"keeper": "Madame Lotte",
				"inventory": [
					{
						"item_id": "food_hot_cocoa_roll",
						"name": "Swallow Butter Croissant & Hot Chocolate",
						"category": "Provision",
						"price_beli": 400,
						"stock": 60,
						"trade_multiplier": 1.1,
						"description": "Warm, comforting pastry that restores stamina and warms frozen explorers."
					}
				]
			}
		],
		"npcs": [
			{
				"id": "npc_inventor_wolf",
				"name": "Wolf the Eccentric Inventor",
				"title": "Architect of the Polar Tang",
				"role": "Master Inventor & Submersible Engineer",
				"location": "Wolf's Geodesic Cliffside Lab",
				"dialogue_intro": "Hahaha! Don't touch that lever unless you want thirty atmospheres of steam in your face! What brings you to Swallow Island? Looking to dive beneath the waves?",
				"dialogue_topics": {
					"Building the Polar Tang": "That yellow boat was my masterpiece. Built from Swallow's hidden gold to keep Law, Bepo, and the boys safe from Doflamingo's eyes.",
					"Artur Bacca": "My boy Bacca... drank too deep of power. Ate that accursed Melt-Melt fruit and thought he could pillage his own father's town. Law operated on him good.",
					"Bepo the Mink": "A giant white walking bear in an orange jumpsuit! Washed up cold and shivering on my beach. Best martial artist and navigator you could ever find."
				},
				"bounty_beli": 0,
				"is_canon": true
			}
		],
		"hazards": [
			{"type": "Mountain Downdrafts", "severity": 0.20, "description": "Strong valley winds when navigating close to Swallow Peak."}
		],
		"exploration_hooks": [
			{
				"id": "hook_swallow_hidden_treasure_vault",
				"title": "The Legend of Swallow Island's Vault",
				"description": "Explore the caverns beneath the western cliff where Wolf unearthed the legendary pirate hoard used to rebuild Pleasure Town."
			}
		]
	}

static func _get_rubeck_island_data() -> Dictionary:
	return {
		"id": "rubeck_island",
		"name": "Rubeck Island",
		"japanese_name": "ルベック島 (Rubekku-tō)",
		"lat_deg": 50.40,
		"lon_deg": -58.90,
		"alt_m": 15.0,
		"lat": 50.40,
		"lon": -58.90,
		"coordinates": {"lat": 50.40, "lon": -58.90, "altitude": 15.0},
		"radius_meters": 65000.0,
		"biome": "Urban Coastal Port & Fortified Brick Harbor",
		"climate": "Crisp Cold Maritime",
		"political_status": "World Government Trade Hub & Marine Anchorage",
		"ruling_dynasty": "Municipal Merchant Directorate",
		"lore_summary": "A densely populated, bustling urban harbor island with towering brick warehouses, customs wharves, and cobbled commercial promenades. In canon, Rubeck Island was the scheduled rendezvous site where Diez Barrels planned to deliver the Ope Ope no Mi directly to the Marines in exchange for 5,000,000,000 Beli, and where Vice Admiral Tsuru stationed her grand battle fleet to secure the transaction.",
		"ports": [
			{
				"id": "port_rubeck_grand_dock",
				"name": "Rubeck Grand Customs Pier",
				"lat_deg": 50.25,
		"lon_deg": -58.70,
		"alt_m": 0.0,
		"lat": 50.25,
		"lon": -58.70,
		"coordinates": {"lat": 50.25, "lon": -58.70, "altitude": 0.0},
				"water_depth_meters": 32.0,
				"dock_fee_beli": 5000,
				"harbormaster": "Superintendent Vane",
				"facilities": ["Marine Inspection Wharf", "Bounty Exchange Guild", "Large Vessel Drydock", "Telegraph Station"]
			}
		],
		"towns": [
			{
				"id": "town_rubeck_metro",
				"name": "Rubeck Commercial Port City",
				"population": 140000,
				"description": "Victorian-style stone and red-brick trading metropolis equipped with maritime insurance banks, arms dealers, and grand seafood taverns."
			}
		],
		"shops": [
			{
				"id": "shop_rubeck_marine_surplus",
				"name": "North Sea Admiralty Surplus & Armory",
				"type": "Weapons, Munitions & Marine Gear",
				"keeper": "Ex-Quartermaster Thorne",
				"inventory": [
					{
						"item_id": "weapon_north_blue_flintlock_rifle",
						"name": "Rubeck Long-Barrel Marksman Musket",
						"category": "Ranged Weapon",
						"price_beli": 48000,
						"stock": 10,
						"trade_multiplier": 1.4,
						"description": "High-accuracy rifled musket favored by northern frontier scouts. Extreme effective range and stopping power."
					},
					{
						"item_id": "item_seastone_manacles_surplus",
						"name": "Confiscated Seastone Handcuffs (Keyed)",
						"category": "Bounty Hunter Tool",
						"price_beli": 120000,
						"stock": 2,
						"trade_multiplier": 2.5,
						"description": "Genuine Navy Seastone cuffs. Nullifies Devil Fruit powers on restrained targets."
					},
					{
						"item_id": "item_north_blue_sea_charts",
						"name": "Admiralty North Blue Ocean Chartbook",
						"category": "Cartography Document",
						"price_beli": 25000,
						"stock": 5,
						"trade_multiplier": 1.2,
						"description": "Authentic naval charts detailing ocean depths and reef hazards between Rubeck, Minion, and Swallow islands."
					}
				]
			}
		],
		"npcs": [
			{
				"id": "npc_bounty_broker_garrick",
				"name": "Garrick the Ledger",
				"title": "North Blue Bounty Hunter Guild Master",
				"role": "Bounty Broker & Mercenary Recruiter",
				"location": "Rubeck Harbor Guildhall",
				"dialogue_intro": "You want your pockets heavy with Beli? The North Blue waters breed cold-blooded cutthroats. Bring me their heads, and the Marines pay within the hour.",
				"dialogue_topics": {
					"Vice Admiral Tsuru": "Great Tsuru swept through here sixteen years ago like a cleansing tide. If she sets her sights on your ship, even Doflamingo turns his sails and runs.",
					"The 5 Billion Beli Fruit": "Five billion! The bounty on a Yonko's head! That was the price the World Government was ready to pay right here in Rubeck harbor for the Heart Fruit."
				},
				"bounty_beli": 0,
				"is_canon": false
			}
		],
		"hazards": [
			{"type": "Heavy Marine Patrols", "severity": 0.50, "description": "High-tier Marine corvettes cruise these waters; pirate crews face frequent interdiction."}
		],
		"exploration_hooks": [
			{
				"id": "hook_rubeck_trade_escort",
				"title": "The Merchant Convoy to Notice",
				"description": "Contract to escort a bullion-laden trade vessel sailing south toward the opulent city of Notice through pirate-infested waters."
			}
		]
	}

static func _get_notice_data() -> Dictionary:
	return {
		"id": "notice_town",
		"name": "Notice",
		"japanese_name": "ノーティス (Nōtisu)",
		"lat_deg": 34.20,
		"lon_deg": -26.40,
		"alt_m": 8.0,
		"lat": 34.20,
		"lon": -26.40,
		"coordinates": {"lat": 34.20, "lon": -26.40, "altitude": 8.0},
		"radius_meters": 70000.0,
		"biome": "Sunny Subtropical Riviera & Palm Boulevard",
		"climate": "Warm, Breezy Mediterranean",
		"political_status": "Affluent Merchant Republic",
		"ruling_dynasty": "Notice Grand Mercantile Senate",
		"lore_summary": "A wealthy, hedonistic port city renowned for luxury casinos, private yacht clubs, and affluent leisure districts. Notice is famous as the hometown of Bellamy 'The Hyena', Sarquiss 'Big Knife', and the rest of the Bellamy Pirates. Born into privilege and bored with decadent luxury, they turned to piracy out of cynical admiration for Donquixote Doflamingo and his 'New Age' ideology of contempt for romantic dreamers.",
		"ports": [
			{
				"id": "port_notice_marina",
				"name": "Notice Gold Coast Marina",
				"lat_deg": 34.05,
		"lon_deg": -26.20,
		"alt_m": 0.0,
		"lat": 34.05,
		"lon": -26.20,
		"coordinates": {"lat": 34.05, "lon": -26.20, "altitude": 0.0},
				"water_depth_meters": 24.0,
				"dock_fee_beli": 8000,
				"harbormaster": "Lord Chancellor Sterling",
				"facilities": ["Luxury Yacht Berths", "Casino Saloons", "Silk & Jewelry Boutiques", "High-End Shipwrights"]
			}
		],
		"towns": [
			{
				"id": "town_notice_riviera",
				"name": "The Golden Promenade & Casino Row",
				"population": 110000,
				"description": "Opulent white-marble streets lined with palms, neon-lit gaming parlors, high-fashion boutiques, and private villas."
			}
		],
		"shops": [
			{
				"id": "shop_notice_couture",
				"name": "Bellamy & Sarquiss Tailoring Atelier",
				"type": "Luxury Apparel & High-Society Armor",
				"keeper": "Monsieur Claude",
				"inventory": [
					{
						"item_id": "armor_flamboyant_coat",
						"name": "Velvet Feathered Captain's Cloak",
						"category": "Charisma Armor",
						"price_beli": 85000,
						"stock": 4,
						"trade_multiplier": 1.6,
						"description": "Flashy, silk-lined coat modeled after high-society pirate fashion. Increases tavern NPC intimidation and trading charisma."
					},
					{
						"item_id": "weapon_kukri_carving_blade",
						"name": "Gilded Sarquiss-Pattern Kukri",
						"category": "Melee Weapon",
						"price_beli": 65000,
						"stock": 5,
						"trade_multiplier": 1.5,
						"description": "Heavy curved hacking blade balanced for acrobatic cleaving strikes."
					},
					{
						"item_id": "jewelry_notice_gold_cufflinks",
						"name": "Solid Gold Flamingo Sigil Ring",
						"category": "Luxury Trade Good",
						"price_beli": 110000,
						"stock": 6,
						"trade_multiplier": 2.0,
						"description": "Lavish gold signet ring worn by affluent youths to show allegiance to the Donquixote flag."
					}
				]
			},
			{
				"id": "casino_notice_high_roller",
				"name": "The Golden Maelstrom Casino",
				"type": "Gambling Hall & VIP Lounge",
				"keeper": "Madame Vivienne",
				"inventory": [
					{
						"item_id": "drink_notice_sparkling_champagne",
						"name": "Notice Grand Vintage 1515 Champagne",
						"category": "Provision",
						"price_beli": 1500,
						"stock": 40,
						"trade_multiplier": 1.4,
						"description": "Effervescent golden wine celebrated across high-society balls."
					}
				]
			}
		],
		"npcs": [
			{
				"id": "npc_claude_couturier",
				"name": "Claude the Couturier",
				"title": "Tailor to the Spoiled Generation",
				"role": "Fashion Merchant & Social Lore",
				"location": "Notice Tailoring Atelier",
				"dialogue_intro": "Ah, another aspiring pirate! Bellamy sat right in that chair before he departed for Jaya. He laughed at dreams and swore only gold and power mattered in the New Age.",
				"dialogue_topics": {
					"Bellamy's Youth": "Born with a silver spoon in his mouth, Bellamy got bored with mansions and yacht races. He worshipped Doflamingo like a god.",
					"The New Age Philosophy": "The era of dreaming of the One Piece or the City of Gold is over, they said. Realists take what is right in front of them."
				},
				"bounty_beli": 0,
				"is_canon": false
			}
		],
		"hazards": [
			{"type": "Pickpockets & Card Sharps", "severity": 0.20, "description": "Unattended Beli pouches in casino zones can be swiped by local thieves."}
		],
		"exploration_hooks": [
			{
				"id": "hook_notice_high_stakes",
				"title": "The High Roller's Debt Ledger",
				"description": "Recover the lost gambling promissory notes of a visiting foreign prince from the underground vault beneath the Golden Maelstrom Casino."
			}
		]
	}

static func _get_rakesh_data() -> Dictionary:
	return {
		"id": "rakesh_port",
		"name": "Rakesh",
		"japanese_name": "ラケシュ (Rakeshu)",
		"lat_deg": 32.50,
		"lon_deg": -38.20,
		"alt_m": 6.0,
		"lat": 32.50,
		"lon": -38.20,
		"coordinates": {"lat": 32.50, "lon": -38.20, "altitude": 6.0},
		"radius_meters": 55000.0,
		"biome": "Fortified Coastal Commerce Port & Stone Wharves",
		"climate": "Temperate Maritime with Regular Trade Winds",
		"political_status": "Free Trading Harbor (Former Donquixote Tribute City)",
		"ruling_dynasty": "Rakesh Guild of Harbor Barons",
		"lore_summary": "A fortified, heavy-stone trading port that sits astride the central North Blue shipping lines. Historically targeted and extorted by the Donquixote Pirates during their rise to prominence, Rakesh fortified its sea-walls and created an expansive merchant exchange dealing in raw timber, canvas, and northern spices.",
		"ports": [
			{
				"id": "port_rakesh_sea_gate",
				"name": "Rakesh Fortified Sea-Gate Pier",
				"lat_deg": 32.35,
		"lon_deg": -38.00,
		"alt_m": 0.0,
		"lat": 32.35,
		"lon": -38.00,
		"coordinates": {"lat": 32.35, "lon": -38.00, "altitude": 0.0},
				"water_depth_meters": 20.0,
				"dock_fee_beli": 3000,
				"harbormaster": "Captain Hector Ward",
				"facilities": ["Stone Drydocks", "Naval Armory", "Spice Exchange", "Sailmaker Lofts"]
			}
		],
		"towns": [
			{
				"id": "town_rakesh_citadel",
				"name": "Rakesh Port Citadel",
				"population": 75000,
				"description": "Heavy granite walls protecting concentric circles of timber merchant houses, sail-weaving lofts, and busy spice markets."
			}
		],
		"shops": [
			{
				"id": "shop_rakesh_ship_outfitters",
				"name": "Rakesh Canvas & Northern Pine Timber Co.",
				"type": "Shipyard Supplies & Rigging",
				"keeper": "Master Carpenter Brand",
				"inventory": [
					{
						"item_id": "mat_north_blue_pine_planks",
						"name": "Northern Dense Pine Timber",
						"category": "Ship Repair Material",
						"price_beli": 18000,
						"stock": 50,
						"trade_multiplier": 1.3,
						"description": "Resilient, slow-growth coniferous wood that withstands freezing spray and heavy storm swells."
					},
					{
						"item_id": "mat_reinforced_storm_canvas",
						"name": "Triple-Weave Heavy Storm Canvas",
						"category": "Ship Upgrade Material",
						"price_beli": 36000,
						"stock": 25,
						"trade_multiplier": 1.5,
						"description": "Heavy-duty sailcloth engineered to prevent tearing in high-gale Arctic and Grand Line squalls."
					}
				]
			}
		],
		"npcs": [
			{
				"id": "npc_hector_ward",
				"name": "Hector Ward",
				"title": "Castellan of the Sea-Gate",
				"role": "Defense Officer & Trade Route Broker",
				"location": "Rakesh Sea-Gate Tower",
				"dialogue_intro": "Rakesh does not bow to pirates any longer. When Doflamingo was extorting this bay, we were weak. Now our walls mount forty-eight heavy cannons.",
				"dialogue_topics": {
					"Doflamingo's Tribute": "Every merchant vessel paid 10% or had its rudder broken. We learned the hard way that peace must be backed by iron.",
					"The Reverse Mountain Route": "If you are sailing toward Reverse Mountain, stock double canvas. The southern approach currents will drag you toward the Red Line rocks if your sails blow out."
				},
				"bounty_beli": 0,
				"is_canon": false
			}
		],
		"hazards": [],
		"exploration_hooks": []
	}

static func _get_downs_data() -> Dictionary:
	return {
		"id": "downs_cove",
		"name": "Downs",
		"japanese_name": "ダウンズ (Daunzu)",
		"lat_deg": 19.50,
		"lon_deg": -72.00,
		"alt_m": 10.0,
		"lat": 19.50,
		"lon": -72.00,
		"coordinates": {"lat": 19.50, "lon": -72.00, "altitude": 10.0},
		"radius_meters": 48000.0,
		"biome": "Jagged Sea-Caves & Sunken Cove Archipelago",
		"climate": "Chilly, Damp Oceanic Fog",
		"political_status": "Underworld Sanctuary & Outlaw Haven",
		"ruling_dynasty": "None (Underworld Council of Smugglers)",
		"lore_summary": "A secluded, fog-veiled island riddled with natural sea arches, sunken grottoes, and hidden subterranean docks. Downs is historically notable as the birthplace of the criminal syndicate and pirate networks that preceded the formal founding of the Donquixote Pirates. Today, it remains an unmapped haven for black-market arms dealers, bounty fugitives, and rogue cartographers.",
		"ports": [
			{
				"id": "port_downs_smuggler_cove",
				"name": "Downs Grotto Hidden Anchorage",
				"lat_deg": 19.38,
		"lon_deg": -71.85,
		"alt_m": 0.0,
		"lat": 19.38,
		"lon": -71.85,
		"coordinates": {"lat": 19.38, "lon": -71.85, "altitude": 0.0},
				"water_depth_meters": 22.0,
				"dock_fee_beli": 1000,
				"harbormaster": "Blind Silas",
				"facilities": ["Hidden Cave Moorings", "Forged Document Mill", "Fencing Warehouse", "Tavern"]
			}
		],
		"towns": [
			{
				"id": "town_downs_cavern",
				"name": "The Sunken Wharf",
				"population": 16000,
				"description": "Subterranean village suspended from stalactites and wooden catwalks above the sea-caves."
			}
		],
		"shops": [
			{
				"id": "shop_downs_black_market",
				"name": "Silas's Vault of Forgeries & Contraband",
				"type": "Black Market Broker",
				"keeper": "Blind Silas",
				"inventory": [
					{
						"item_id": "doc_forged_world_govt_pass",
						"name": "Forged Marine Transit Warrant",
						"category": "Contraband Document",
						"price_beli": 140000,
						"stock": 2,
						"trade_multiplier": 2.2,
						"description": "Flawless counterfeit papers permitting merchant passage through World Government naval checkpoints without inspection."
					},
					{
						"item_id": "book_devil_fruit_encyclopedia_fragment",
						"name": "Devil Fruit Compendium (North Blue Excerpt)",
						"category": "Lore Document",
						"price_beli": 220000,
						"stock": 1,
						"trade_multiplier": 3.0,
						"description": "Ancient ink rubbings cataloging the shapes, swirls, and known powers of Paramecia fruits originating in the northern seas."
					}
				]
			}
		],
		"npcs": [
			{
				"id": "npc_blind_silas",
				"name": "Blind Silas",
				"title": "Archivist of the Underworld",
				"role": "Black Market Broker & Document Forger",
				"location": "The Sunken Wharf",
				"dialogue_intro": "I may not have eyes, traveler, but I can hear the cut of your jib and the rustle of your Beli. What illegal commodity brings you to Downs?",
				"dialogue_topics": {
					"Doflamingo's Roots": "Downs was where young Doffy first brought Trebol, Diamante, and Pica together. They were street thugs back then, but they had devils in their eyes.",
					"The Underworld Brokers": "Everything flows through North Blue: guns, scrap, lead, and secrets. If you know who to pay, you can cross the world unnoticed."
				},
				"bounty_beli": 22000000,
				"is_canon": false
			}
		],
		"hazards": [
			{"type": "Hidden Submerged Reefs", "severity": 0.45, "description": "Sailing into the grotto without a pilot risks hull puncture."}
		],
		"exploration_hooks": []
	}

static func _get_micqueot_data() -> Dictionary:
	return {
		"id": "micqueot_land",
		"name": "Micqueot (Northern Land)",
		"japanese_name": "ミッキュオ (Mikkyuo)",
		"lat_deg": 39.00,
		"lon_deg": -15.10,
		"alt_m": 20.0,
		"lat": 39.00,
		"lon": -15.10,
		"coordinates": {"lat": 39.00, "lon": -15.10, "altitude": 20.0},
		"radius_meters": 68000.0,
		"biome": "Rolling Sunlit Terraces & Ancient Vineyards",
		"climate": "Crisp Cool Highland with Abundant Sunshine",
		"political_status": "World Government Allied Aristocratic Duchy",
		"ruling_dynasty": "Ducal House of Micqueot",
		"lore_summary": "A picturesque, pastoral northern realm world-famous for its terraced vineyards and high-altitude cellars. Micqueot produces the legendary 'Ithürzburger Stein'—one of the One Piece world's most prized and costly vintage wines, shipped directly to the World Nobles of Mary Geoise and prestigious banquets across the Four Blues.",
		"ports": [
			{
				"id": "port_micqueot_wine_basin",
				"name": "Port Ithürz (Micqueot Wine Pier)",
				"lat_deg": 38.85,
		"lon_deg": -14.90,
		"alt_m": 0.0,
		"lat": 38.85,
		"lon": -14.90,
		"coordinates": {"lat": 38.85, "lon": -14.90, "altitude": 0.0},
				"water_depth_meters": 18.0,
				"dock_fee_beli": 3500,
				"harbormaster": "Baron De Roche",
				"facilities": ["Wine Vault Warehouses", "Oak Barrel Coopers", "Tasting Saloons", "Customs Export Wharf"]
			}
		],
		"towns": [
			{
				"id": "town_micqueot_chateau",
				"name": "Chateau Micqueot & Upper Vineyards",
				"population": 52000,
				"description": "Cobbled stone village nestled among sprawling vine hills, crowned by ancient stone pressing chateaus and deep limestone cellars."
			}
		],
		"shops": [
			{
				"id": "shop_micqueot_cellar",
				"name": "Grand Cellar of Ithürzburger Stein",
				"type": "Premier Vintner & Luxury Export",
				"keeper": "Sommelier Jean-Luc",
				"inventory": [
					{
						"item_id": "wine_ithurzburger_stein_vintage",
						"name": "Ithürzburger Stein (Grand Vintage)",
						"category": "Luxury Wine Trade Good",
						"price_beli": 95000,
						"stock": 15,
						"trade_multiplier": 2.4,
						"description": "World-renowned North Blue dry white wine bottled in distinctive bocksbeutel stone flagons. Highly prized by Mary Geoise nobles and Grand Line aristocrats."
					},
					{
						"item_id": "wine_micqueot_reserve_cask",
						"name": "Micqueot Oak Wine Cask (Whole Barrel)",
						"category": "Trade Commodity",
						"price_beli": 180000,
						"stock": 4,
						"trade_multiplier": 2.8,
						"description": "Full 200-liter wooden cask of fermented vintage. Delivers monumental profits when traded in Water 7 or Sabaody."
					}
				]
			}
		],
		"npcs": [
			{
				"id": "npc_jean_luc_sommelier",
				"name": "Sommelier Jean-Luc",
				"title": "Master Vintner of the Northern Land",
				"role": "Wine Merchant & Aristocratic Contact",
				"location": "Grand Cellar of Ithürzburger Stein",
				"dialogue_intro": "The cold northern night, the intense mountain sun—that is the secret of the Stein, mon ami. Even the Celestial Dragons request two hundred cases every Reverie.",
				"dialogue_topics": {
					"Ithürzburger Stein": "It takes twelve years of aging in subterranean chalk cellars. A single glass clears the palate and soothes the wildest pirate crew.",
					"The Reverie Shipments": "Government escorts arrive every four years to load the vintage. We maintain strict neutrality so our vines are never trampled by war."
				},
				"bounty_beli": 0,
				"is_canon": true
			}
		],
		"hazards": [],
		"exploration_hooks": []
	}

static func _get_kuen_village_data() -> Dictionary:
	return {
		"id": "kuen_village",
		"name": "Kuen Village",
		"japanese_name": "クエン村 (Kuen-mura)",
		"lat_deg": 61.20,
		"lon_deg": -35.40,
		"alt_m": 65.0,
		"lat": 61.20,
		"lon": -35.40,
		"coordinates": {"lat": 61.20, "lon": -35.40, "altitude": 65.0},
		"radius_meters": 38000.0,
		"biome": "Arid Mountain Steppe & Drought Ravines",
		"climate": "Extreme Subpolar Arid with Bitter Cold Winds",
		"political_status": "Impoverished Forgotten Village",
		"ruling_dynasty": "None (Tribal Council of Elders)",
		"lore_summary": "A bleak, drought-stricken highland village perched on cold, windswept stone plateaus. Infamous as the birthplace of Baby 5. The village suffered such catastrophic famine and poverty that its desperate inhabitants practiced cruel triage, abandoning 'useless' infants in the mountains. Baby 5's mother famously cast her out, declaring she was 'not needed'—a psychological trauma that led her to blindly obey anyone who claimed to need her assistance.",
		"ports": [
			{
				"id": "port_kuen_rocky_inlet",
				"name": "Kuen Rocky Inlet",
				"lat_deg": 60.95,
		"lon_deg": -35.15,
		"alt_m": 0.0,
		"lat": 60.95,
		"lon": -35.15,
		"coordinates": {"lat": 60.95, "lon": -35.15, "altitude": 0.0},
				"water_depth_meters": 12.0,
				"dock_fee_beli": 0,
				"harbormaster": "None (Crude Timber Jetty)",
				"facilities": ["Crude Moorings"]
			}
		],
		"towns": [
			{
				"id": "town_kuen_hamlet",
				"name": "Kuen Mountain Hamlet",
				"population": 3200,
				"description": "Austere stone huts, dry stone wells, and cracked terraced fields battling perennial famine."
			}
		],
		"shops": [
			{
				"id": "shop_kuen_herbalist",
				"name": "Grandmother Morna's Dried Mountain Roots",
				"type": "Herbal Apothecary & Scarcity Trading",
				"keeper": "Grandmother Morna",
				"inventory": [
					{
						"item_id": "herb_kuen_drought_root",
						"name": "Bitter Kuen Drought Root",
						"category": "Herbal Medicine",
						"price_beli": 450,
						"stock": 25,
						"trade_multiplier": 1.2,
						"description": "Hardy desert tuber that suppresses hunger pangs and restores minor stamina."
					},
					{
						"item_id": "item_baby5_antique_doll",
						"name": "Carved Wooden Maiden Figurine",
						"category": "Lore Relic",
						"price_beli": 5000,
						"stock": 1,
						"trade_multiplier": 1.8,
						"description": "Crude wooden doll carved from barren scrub pine, representing the discarded children of Kuen Village."
					}
				]
			}
		],
		"npcs": [
			{
				"id": "npc_morna_elder",
				"name": "Grandmother Morna",
				"title": "Village Matriarch",
				"role": "Village Lore Keeper & Healer",
				"location": "Kuen Stone Hovel",
				"dialogue_intro": "Are you bringing bread, or have you come to take more of our youth? The mountains are dry, child. They give nothing, and they forgive nothing.",
				"dialogue_topics": {
					"Baby 5's Childhood": "A poor girl born in the worst winter we ever endured. Her mother was half-crazed with hunger when she threw her to the wolves, whispering 'you are useless'. It cursed that poor soul forever.",
					"The Great Mountain Drought": "For thirty years the rains have skipped Kuen. If you sail with provisions, bring grain to our docks."
				},
				"bounty_beli": 0,
				"is_canon": false
			}
		],
		"hazards": [
			{"type": "Food & Water Scarcity", "severity": 0.40, "description": "Local food vendors have virtually no inventory; player must rely on own rations."}
		],
		"exploration_hooks": [
			{
				"id": "hook_kuen_famine_relief",
				"title": "Relief for the Discarded Village",
				"description": "Deliver 50 crates of grain and fresh water from Lvneel or Micqueot to rescue Kuen Village from starvation, unlocking unique goodwill dialogue."
			}
		]
	}

static func _get_deul_kingdom_data() -> Dictionary:
	return {
		"id": "deul_kingdom",
		"name": "Deul Kingdom",
		"japanese_name": "デュール王国 (Dyūru Ōkoku)",
		"lat_deg": 48.00,
		"lon_deg": -22.30,
		"alt_m": 25.0,
		"lat": 48.00,
		"lon": -22.30,
		"coordinates": {"lat": 48.00, "lon": -22.30, "altitude": 25.0},
		"radius_meters": 82000.0,
		"biome": "Temperate Coastal Plains & Granite Fortresses",
		"climate": "Brisk Continental Oceanic",
		"political_status": "World Government Allied Kingdom",
		"ruling_dynasty": "House of Chap (Ruled by King Chap)",
		"lore_summary": "A proud, militaristic World Government member nation ruled by the pompous King Chap. Deul Kingdom maintains heavy coastal artillery batteries and a permanent diplomatic envoy to Mary Geoise. In the past, it was heavily threatened during Germa 66's expansionist campaigns, prompting its king to advocate strongly for Marine naval garrisons in North Blue.",
		"ports": [
			{
				"id": "port_deul_citadel_pier",
				"name": "Port Chap (Deul Grand Bastion)",
				"lat_deg": 47.85,
		"lon_deg": -22.05,
		"alt_m": 0.0,
		"lat": 47.85,
		"lon": -22.05,
		"coordinates": {"lat": 47.85, "lon": -22.05, "altitude": 0.0},
				"water_depth_meters": 26.0,
				"dock_fee_beli": 4000,
				"harbormaster": "Baron Vance",
				"facilities": ["Naval Garrison Wharf", "Diplomatic Consulate", "Heavy Cannon Foundry"]
			}
		],
		"towns": [
			{
				"id": "town_deul_metropolis",
				"name": "Deul Royal City",
				"population": 160000,
				"description": "Neoclassical granite buildings, royal military parade grounds, and the towering Palace of King Chap."
			}
		],
		"shops": [
			{
				"id": "shop_deul_royal_foundry",
				"name": "Deul Royal Cannon & Powder Works",
				"type": "Military Munitions & Naval Artillery",
				"keeper": "Master Artificer Kurt",
				"inventory": [
					{
						"item_id": "cannon_deul_grand_culverin",
						"name": "Deul Royal 36-Pounder Culverin",
						"category": "Ship Weapon",
						"price_beli": 125000,
						"stock": 8,
						"trade_multiplier": 1.7,
						"description": "Cast-bronze long naval cannon with superior muzzle velocity and extreme range."
					},
					{
						"item_id": "ammo_deul_explosive_grape",
						"name": "Deul Canister Shot Crate",
						"category": "Ship Ammunition",
						"price_beli": 18000,
						"stock": 20,
						"trade_multiplier": 1.3,
						"description": "Anti-crew fragmentation shot designed to decimate enemy ship decks during boarding actions."
					}
				]
			}
		],
		"npcs": [
			{
				"id": "npc_king_chap",
				"name": "King Chap",
				"title": "Sovereign of Deul Kingdom",
				"role": "Monarch & World Government Dignitary",
				"location": "Deul Royal Throne Room",
				"dialogue_intro": "Stand before the throne of Deul! Our kingdom has stood loyal to the World Government for six centuries! We fear neither pirates nor the cybernetic snails of Germa!",
				"dialogue_topics": {
					"Germa 66 Threat": "Judge and his mutant sons are demons without borders! They murdered the Four Kings in one bloody night. Only our cannons keep their snails at bay.",
					"The Reverie": "I travel personally to the Holy Land to demand more Marine battleships for the North Blue. The common rabble knows nothing of statecraft."
				},
				"bounty_beli": 0,
				"is_canon": true
			}
		],
		"hazards": [
			{"type": "Royal Military Harbor Checkpoint", "severity": 0.30, "description": "Naval inspection for bounty targets over 10,000,000 Beli."}
		],
		"exploration_hooks": []
	}

static func _get_whiteland_kingdom_data() -> Dictionary:
	return {
		"id": "whiteland_kingdom",
		"name": "Whiteland Kingdom",
		"japanese_name": "ホワイトランド王国 (Howaitorando Ōkoku)",
		"lat_deg": 68.40,
		"lon_deg": -48.50,
		"alt_m": 40.0,
		"lat": 68.40,
		"lon": -48.50,
		"coordinates": {"lat": 68.40, "lon": -48.50, "altitude": 40.0},
		"radius_meters": 95000.0,
		"biome": "Glacial Fjords, Polar Tundra & Ice-Breaker Bays",
		"climate": "Severe Polar Glacial with Dancing Aurora Borealis",
		"political_status": "World Government Allied Northern Monarchy",
		"ruling_dynasty": "House of Iwatobi (Ruled by King Iwatobi)",
		"lore_summary": "An austere, subpolar northern kingdom characterized by deep icy fjords, colossal icebergs, and permanent snowfields. Ruled by King Iwatobi, a sovereign who attends the Levely (Reverie) draped in heavy ceremonial royal furs. Whiteland is the world's chief supplier of arctic fox and bear furs, seal oil, and mammoth ivory, boasting heavily armored ice-breaker ships capable of crushing through pack-ice.",
		"ports": [
			{
				"id": "port_whiteland_fjord_haven",
				"name": "Iwatobi Fjord Ice-Breaker Haven",
				"lat_deg": 68.15,
		"lon_deg": -48.20,
		"alt_m": 0.0,
		"lat": 68.15,
		"lon": -48.20,
		"coordinates": {"lat": 68.15, "lon": -48.20, "altitude": 0.0},
				"water_depth_meters": 35.0,
				"dock_fee_beli": 3000,
				"harbormaster": "Captain Bjorn Ice-Bane",
				"facilities": ["Ice-Breaker Drydock", "Mammoth Ivory Guild", "Heated Pier Houses", "Fur Trade Depot"]
			}
		],
		"towns": [
			{
				"id": "town_whiteland_capital",
				"name": "Whiteland Glacial Bastion",
				"population": 68000,
				"description": "Massive fortress carved directly into blue glacial ice and basalt rock, heated by geothermal volcanic steam vents."
			}
		],
		"shops": [
			{
				"id": "shop_whiteland_fur_exchange",
				"name": "Royal Arctic Guild of Furs & Ivory",
				"type": "Luxury Polar Goods & Cold Gear",
				"keeper": "Master Trapper Sven",
				"inventory": [
					{
						"item_id": "mat_arctic_mammoth_ivory",
						"name": "Fossilized Mammoth Tusk Ivory",
						"category": "Precious Luxury Commodity",
						"price_beli": 135000,
						"stock": 8,
						"trade_multiplier": 2.5,
						"description": "Prime carved ivory tusk extracted from permafrost glaciers. Commands staggering prices in Mary Geoise and Sabaody."
					},
					{
						"item_id": "armor_whiteland_royal_fur_mantle",
						"name": "King Iwatobi-Style Polar Ermine Mantle",
						"category": "Cold Resistance Armor",
						"price_beli": 48000,
						"stock": 6,
						"trade_multiplier": 1.6,
						"description": "Luxurious fur cloak that grants total immunity to extreme sub-zero weather and freezing spray."
					},
					{
						"item_id": "upgrade_ship_icebreaker_prow",
						"name": "Reinforced Steel Ice-Breaker Ram",
						"category": "Ship Ram Upgrade",
						"price_beli": 160000,
						"stock": 2,
						"trade_multiplier": 2.0,
						"description": "Heavy cast-iron reinforced bow plating. Allows a vessel to smash through polar ice-sheets and deal +30% ramming damage."
					}
				]
			}
		],
		"npcs": [
			{
				"id": "npc_king_iwatobi",
				"name": "King Iwatobi",
				"title": "Lord of the Northern Glaciers",
				"role": "Monarch & World Government Dignitary",
				"location": "Whiteland Basalt Throne Room",
				"dialogue_intro": "Hmph! You look shivering, warm-water sailor. In Whiteland, the ice makes men hard as diamonds. What trade do you seek in my frozen fjords?",
				"dialogue_topics": {
					"The Polar Sea": "Beyond our northern cap lies only the howling pack-ice. Even the Marines do not venture further north. Here, only our ice-breakers survive.",
					"The Reverie": "Every four years I sail across the Red Line to Mary Geoise. The southern kings complain of sun and heat; they have soft bones."
				},
				"bounty_beli": 0,
				"is_canon": true
			}
		],
		"hazards": [
			{"type": "Drifting Icebergs", "severity": 0.55, "description": "High-density icebergs in the approach fjord cause severe collision damage to wooden hulls without an ice-breaker ram."},
			{"type": "Polar Hypothermia", "severity": 0.45, "description": "Extreme sub-zero chill requires fur mantle or heater stove."}
		],
		"exploration_hooks": []
	}

# -----------------------------------------------------------------------------
# GERMA KINGDOM MOBILE FLEET SIMULATION
# -----------------------------------------------------------------------------

static func _get_germa_kingdom_base_data() -> Dictionary:
	return {
		"id": "germa_kingdom_mobile",
		"name": "Germa Kingdom (Mobile Snail-Ship Fleet)",
		"japanese_name": "ジェルマ王国 (Jeruma Ōkoku)",
		"lat_deg": 31.00,
		"lon_deg": -48.00,
		"alt_m": 8.0,
		"lat": 31.00,
		"lon": -48.00,
		"coordinates": {"lat": 31.00, "lon": -48.00, "altitude": 8.0}, # Nominal center
		"radius_meters": 45000.0,
		"biome": "Oceanic Mobile Citadel & Cybernetic Snail Decks",
		"climate": "Controlled Marine Microclimate & High-Tech Smog",
		"political_status": "Sovereign Seafaring Empire / 'Kingdom of Science'",
		"ruling_dynasty": "Vinsmoke Royal Family (Supreme Commander Vinsmoke Judge)",
		"lore_summary": "The world's only seafaring nation without fixed landmass. Germa Kingdom consists of dozens of monumental platforms erected upon the shells of giant ocean-going snails (Den Den Mushi subspecies). These colossal snails can navigate across turbulent oceans, lock together via mechanical drawbridges to form a unified island-fortress castle city, or scale the sheer vertical cliffs of the Red Line to project military force into other seas. It houses advanced clone soldier cultivation vats, Raid Suit foundries, and the cybernetic labs of the Vinsmoke Family.",
		"ports": [
			{
				"id": "port_germa_snail_dock",
				"name": "Vinsmoke Royal Flagship Mooring Deck",
				"lat_deg": 31.00,
		"lon_deg": -48.00,
		"alt_m": 4.0,
		"lat": 31.00,
		"lon": -48.00,
		"coordinates": {"lat": 31.00, "lon": -48.00, "altitude": 4.0},
				"water_depth_meters": 999.0, # Deep ocean anywhere
				"dock_fee_beli": 15000,
				"harbormaster": "Germa 66 Quartermaster Unit #04",
				"facilities": ["Clone Bio-Rejuvenation", "Raid Suit Calibration", "High-Tech Foundry", "Weapons Depot"]
			}
		],
		"towns": [
			{
				"id": "town_germa_citadel",
				"name": "Germa Castle & Interlocking Snail Platforms",
				"population": 85000, # Clones and technical staff
				"description": "Vast modular floating kingdom composed of interlocking snail-borne towers, clone laboratories, electromagnetic training yards, and the central Royal Palace."
			}
		],
		"shops": [
			{
				"id": "shop_germa_tech_foundry",
				"name": "Germa 66 Science Directorate & Clone Commissary",
				"type": "Cybernetic Military Tech & Advanced Metallurgy",
				"keeper": "Chief Cyber-Engineer Gauss",
				"inventory": [
					{
						"item_id": "gear_shape_memory_alloy_sheet",
						"name": "Germa Shape-Memory Resin Alloy",
						"category": "High-Tech Material",
						"price_beli": 240000,
						"stock": 6,
						"trade_multiplier": 2.5,
						"description": "Ultra-lightweight memory alloy developed by Vinsmoke Judge. Used in Raid Suit chassis and advanced morphing naval plating."
					},
					{
						"item_id": "boots_germa_hover_propulsion",
						"name": "Germa Hover-Jet Float Soles",
						"category": "Advanced Mobility Gear",
						"price_beli": 450000,
						"stock": 2,
						"trade_multiplier": 3.0,
						"description": "Miniaturized rocket propulsion soles. Grants the wearer a double-jump burst and allows mid-air hovering for 4 seconds."
					},
					{
						"item_id": "potion_germa_clone_stimulant",
						"name": "Germa 66 Clone Nutrient Ampoule",
						"category": "Military Stimulant",
						"price_beli": 12000,
						"stock": 30,
						"trade_multiplier": 1.4,
						"description": "Electrolyte bio-fluid that instantly restores 100% stamina and clears exhaustion."
					},
					{
						"item_id": "weapon_electromagnetic_spear",
						"name": "Germa Electrified Shock Spear",
						"category": "Melee Weapon",
						"price_beli": 180000,
						"stock": 3,
						"trade_multiplier": 2.0,
						"description": "High-voltage battle pike modeled after Vinsmoke Judge's royal electromagnetic weaponry."
					}
				]
			}
		],
		"npcs": [
			{
				"id": "npc_vinsmoke_judge",
				"name": "Vinsmoke Judge (Garuda)",
				"title": "Supreme Commander of Germa 66 & King of Germa",
				"role": "Sovereign & Master Cyber-Scientist",
				"location": "Germa Throne Room of the Four Kings",
				"dialogue_intro": "Science is the only true power in this wretched world! With our clone legions and our technological might, the glory of the Germa Empire shall rule the North Blue once more!",
				"dialogue_topics": {
					"The Conquest of Four Nations": "In one single afternoon, Germa 66 beheaded the four monarchs who dared stand against our sovereignty. The portrait hangs in this very hall.",
					"Red Line Scaling": "No other nation can cross between the Four Blues at will. Our colossal snails scale the 10,000-meter cliffs of the Red Line with ease.",
					"MADS and Vegapunk": "Vegapunk, Caesar, Queen... we discovered the Bloodline Elements together! But I was the only one who forged it into a true sovereign army!"
				},
				"bounty_beli": 0, # Allied/unaligned mercenary warlord
				"is_canon": true
			},
			{
				"id": "npc_germa_quartermaster",
				"name": "Unit #04 (Clone Logistics Overseer)",
				"title": "Germa Quartermaster",
				"role": "Military Quartermaster",
				"location": "Germa Flight Deck",
				"dialogue_intro": "Orders received. Equipment requisition approved upon presentation of sufficient Beli. Long live the Kingdom of Science.",
				"dialogue_topics": {
					"Clone Soldier Obedience": "We are programmed from the tank to fear nothing and obey the Vinsmoke bloodline without hesitation. Pain is irrelevant.",
					"Raid Suit Canisters": "The Raid Suits are bio-locked to royal DNA. Civilians cannot activate them, but our commercial hover equipment is available for sale."
				},
				"bounty_beli": 0,
				"is_canon": false
			}
		],
		"hazards": [
			{"type": "Germa 66 Patrol Radar", "severity": 0.40, "description": "Unidentified vessels approaching within 5,000m are intercepted by clone assault skiffs."}
		],
		"exploration_hooks": [
			{
				"id": "hook_germa_bloodline_schematic",
				"title": "The Stolen Bloodline Tank Data",
				"description": "Hack into an auxiliary terminal in the lower clone gestation bays to acquire research notes on Bloodline Element genetic synthesis."
			}
		]
	}

## Calculates the dynamic position and formation of the mobile Germa Kingdom fleet
## at any given in-game elapsed time in hours.
static func get_germa_fleet_state(time_hours: float) -> Dictionary:
	var num_pts: int = GERMA_PATROL_ROUTE.size()
	if num_pts < 2:
		return _get_germa_kingdom_base_data()
	
	var normalized_time: float = fmod(time_hours, GERMA_PATROL_PERIOD_HOURS) / GERMA_PATROL_PERIOD_HOURS
	var path_index_float: float = normalized_time * float(num_pts)
	var curr_idx: int = int(path_index_float) % num_pts
	var next_idx: int = (curr_idx + 1) % num_pts
	var segment_t: float = path_index_float - float(int(path_index_float))
	
	var p0: Vector2 = GERMA_PATROL_ROUTE[curr_idx]
	var p1: Vector2 = GERMA_PATROL_ROUTE[next_idx]
	
	# Smooth cosine interpolation between waypoints
	var smooth_t: float = (1.0 - cos(segment_t * PI)) * 0.5
	var current_lat: float = lerp(p0.x, p1.x, smooth_t)
	var current_lon: float = lerp(p0.y, p1.y, smooth_t)
	
	# Compute heading vector
	var dlat: float = p1.x - p0.x
	var dlon: float = p1.y - p0.y
	var heading_deg: float = rad_to_deg(atan2(dlon, dlat))
	
	# Determine fleet formation state:
	# Even segments = Assembled Fortress City; Odd segments = Cruising Convoy
	var is_fortress: bool = (curr_idx % 2 == 0)
	var formation_state: String = "ASSEMBLED_ISLAND_FORTRESS" if is_fortress else "CRUISING_CONVOY_DIVISIONS"
	
	var dynamic_data: Dictionary = _get_germa_kingdom_base_data()
	dynamic_data["coordinates"] = {
		"lat": current_lat,
		"lon": current_lon,
		"altitude": 8.0
	}
	dynamic_data["cartesian_position"] = lat_lon_to_cartesian(current_lat, current_lon, 8.0)
	dynamic_data["heading_degrees"] = heading_deg
	dynamic_data["fleet_formation"] = formation_state
	dynamic_data["cruising_speed_knots"] = GERMA_CRUISING_SPEED_KNOTS
	dynamic_data["snail_count"] = 48
	dynamic_data["can_scale_red_line"] = true
	
	return dynamic_data

# -----------------------------------------------------------------------------
# REVERSE MOUNTAIN CANAL ROUTE & NAVIGATION DATA
# -----------------------------------------------------------------------------

## Returns the authored navigation route leading from North Blue into the ascending
## hydraulic canal of Reverse Mountain at the Red Line.
static func get_reverse_mountain_canal_route() -> Dictionary:
	return {
		"canal_id": "north_blue_reverse_mountain_canal",
		"name": "North Blue Hydraulic Ascent Canal",
		"canal_mouth_coordinates": {
			"lat": CANAL_ENTRANCE_LAT,
			"lon": CANAL_ENTRANCE_LON,
			"altitude": 0.0
		},
		"canal_mouth_cartesian": lat_lon_to_cartesian(CANAL_ENTRANCE_LAT, CANAL_ENTRANCE_LON, 0.0),
		"summit_coordinates": {
			"lat": 0.0,
			"lon": 0.0,
			"altitude": 5000.0
		},
		"current_speed_knots_at_mouth": 14.0,
		"current_speed_knots_in_canal": 55.0,
		"canal_width_meters": 400.0,
		"cliff_wall_height_meters": 350.0,
		"approach_waypoints": [
			{
				"id": "wp_north_approach_3",
				"name": "North Blue Gathering Shoals",
				"lat": 6.50,
				"lon": -4.20,
				"notes": "Calm seas before the tidal suction zone. Safe anchoring area to trim sails."
			},
			{
				"id": "wp_north_approach_2",
				"name": "Red Wall Funnel Zone",
				"lat": 4.10,
				"lon": -2.80,
				"notes": "Red Line sheer cliffs come into view. Strong hydraulic pull begins dragging ship inward."
			},
			{
				"id": "wp_north_approach_1",
				"name": "The Hydraulic Maw",
				"lat": 2.50,
				"lon": -1.80,
				"notes": "Points of no return. Ocean current accelerates to 25+ knots into the ascending stone lock."
			},
			{
				"id": "wp_canal_gate",
				"name": "North Blue Canal Entrance Gate",
				"lat": CANAL_ENTRANCE_LAT,
				"lon": CANAL_ENTRANCE_LON,
				"notes": "Must keep rudder dead center! Ships hitting canal gate stone take fatal hull damage."
			}
		],
		"navigational_hazard_guide": [
			"CRITICAL: Do not approach the canal entrance with full canvas deployed; drop top sails to prevent loss of rudder steerage.",
			"CANAL CONVERGENCE: The North Blue canal merges at the +5,000m summit basin with canals from East Blue, West Blue, and South Blue before plunging into Twin Cape.",
			"RED LINE EDDIES: Coastal whirlpools within 50km north of the canal entrance can capsize vessels under 20 meters length."
		]
	}

# -----------------------------------------------------------------------------
# AGGREGATE QUERY HELPERS
# -----------------------------------------------------------------------------

## Returns an array of all marketplace and shop dictionaries in North Blue.
static func get_all_marketplaces() -> Array:
	var result: Array = []
	var islands: Dictionary = get_islands()
	for island_id: String in islands:
		var island_data: Dictionary = islands[island_id]
		var shops: Array = island_data.get("shops", [])
		for shop: Dictionary in shops:
			var shop_copy: Dictionary = shop.duplicate(true)
			shop_copy["island_id"] = island_id
			shop_copy["island_name"] = island_data.get("name", "")
			result.append(shop_copy)
	return result

## Returns an array of all named NPC records across all North Blue settlements.
static func get_all_npcs() -> Array:
	var result: Array = []
	var islands: Dictionary = get_islands()
	for island_id: String in islands:
		var island_data: Dictionary = islands[island_id]
		var npcs: Array = island_data.get("npcs", [])
		for npc: Dictionary in npcs:
			var npc_copy: Dictionary = npc.duplicate(true)
			npc_copy["island_id"] = island_id
			npc_copy["island_name"] = island_data.get("name", "")
			result.append(npc_copy)
	return result

## Returns an array of all trade items available for purchase across North Blue.
static func get_all_trade_goods() -> Array:
	var items: Array = []
	var marketplaces: Array = get_all_marketplaces()
	for market: Dictionary in marketplaces:
		var inventory: Array = market.get("inventory", [])
		for item: Dictionary in inventory:
			var item_copy: Dictionary = item.duplicate(true)
			item_copy["shop_id"] = market.get("id", "")
			item_copy["shop_name"] = market.get("name", "")
			item_copy["island_id"] = market.get("island_id", "")
			items.append(item_copy)
	return items
