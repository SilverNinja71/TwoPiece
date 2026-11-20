class_name WorldRegistrySystem
extends Node
## Master Autoload Registry (`WorldRegistry`) for Project "Blue Planet"
## Aggregates all regional island dictionaries (East Blue, North Blue, West Blue, South Blue,
## Reverse Mountain, Grand Line Paradise, Calm Belts, Sky Seas, Abyss, and New World),
## executes Log Pose / Triple-Needle Log Pose / Eternal Pose / Vivre Card navigation logic,
## manages the Multi-Currency Economy (Beli, Extol 10000:1, Gor, Wano Ryo),
## and drives the Spherical Cartography Fog-of-War & 4 Road Poneglyph Triangulation.

signal island_registered(island_id: String, region_key: String)
signal log_pose_locked(island_id: String, next_candidates: Array[String])
signal eternal_pose_equipped(target_island_id: String)
signal currency_balance_changed(currency_code: String, new_balance: int)
signal map_sector_revealed(sector_key: String, total_revealed_count: int)
signal poneglyph_deciphered(poneglyph_id: String, category: String, total_road_poneglyphs: int)
signal laugh_tale_triangulated(laugh_tale_coords: Dictionary)

# ==============================================================================
# 1. MULTI-CURRENCY CONSTANTS & EXCHANGE RATES
# ==============================================================================
## Canonical One Piece Currency System:
## - Beli (฿): Universal World Government & Pirate currency across Four Blues and Grand Line.
## - Extol (E): Skypiea / White-White Sea currency. Canonically pegged at 10,000 Extol = 1 Beli.
## - Gor (G): Kuja Tribe currency on Amazon Lily (Calm Belt). Valued at 1 Gor = 100 Beli at Shakky's / Kuja exchange.
## - Wano Ryo: Isolated metallic bullion currency of Wano Country:
##   - Silver Ryo (Gin): Everyday trade (1 Silver Ryo = 500 Beli).
##   - Gold Ryo (Kin): High-value trade (1 Gold Ryo = 10,000 Beli).
##   - Platinum Ryo (Hakkin): Estate-grade bullion — 1 coin builds a house (1 Platinum Ryo = 1,000,000 Beli).
const EXTOL_PER_BELI: int = 10_000
const BELI_PER_GOR: int = 100
const BELI_PER_WANO_SILVER_RYO: int = 500
const BELI_PER_WANO_GOLD_RYO: int = 10_000
const BELI_PER_WANO_PLATINUM_RYO: int = 1_000_000

enum NavigationToolMode {
	STANDARD_COMPASS = 0,     # Works in Four Blues; spins erratically in Grand Line & Calm Belts
	SINGLE_LOG_POSE = 1,      # Paradise: Locks onto current island's magnetic field, then points to next island
	TRIPLE_LOG_POSE = 2,      # New World: 3 needles point to 3 candidate islands; jitter indicates danger level
	ETERNAL_POSE = 3,         # Permanently locked onto one specific island's magnetic signature globally
	VIVRE_CARD = 4            # "Paper of Life" pulling toward a moving entity (e.g. Zunesha, Rayleigh, Germa 66)
}

# ==============================================================================
# 2. MASTER STATE DICTIONARIES
# ==============================================================================
## Keyed by `island_id` (String) -> canonical island record Dictionary
var islands_by_id: Dictionary = {}

## Keyed by region (`east_blue`, `north_blue`, `west_blue`, `south_blue`, `reverse_mountain`, `grand_line`)
var islands_by_region: Dictionary = {
	"east_blue": {},
	"north_blue": {},
	"west_blue": {},
	"south_blue": {},
	"reverse_mountain": {},
	"grand_line": {}
}

## Multi-Currency Wallet
var wallet: Dictionary = {
	"Beli": 5_000,
	"Extol": 0,
	"Gor": 0,
	"WanoSilverRyo": 0,
	"WanoGoldRyo": 0,
	"WanoPlatinumRyo": 0
}

## Navigation & Log Pose State
var active_nav_mode: NavigationToolMode = NavigationToolMode.STANDARD_COMPASS
var current_docked_island_id: String = ""
var log_pose_locked_island_id: String = "twin_cape"
var log_pose_charge_elapsed_sec: float = 0.0
var log_pose_required_sec: float = 0.0
var log_pose_is_locked: bool = true
var triple_needle_targets: Array[String] = ["punk_hazard", "raijin_island", "risky_red_island"]
var equipped_eternal_pose_island_id: String = ""
var owned_eternal_poses: Array[String] = []
var active_vivre_card_id: String = ""

## Moving Entities for Vivre Card & Dynamic World Simulation (Zunesha, Germa 66, Thriller Bark)
var dynamic_entities: Dictionary = {}
var _world_clock_sec: float = 0.0

## Cartography Fog-of-War (2-degree x 2-degree spherical grid cells, 16,200 total cells)
var revealed_map_sectors: Dictionary = {}
var discovered_island_ids: Dictionary = {}

## Poneglyph & Road Poneglyph Triangulation Registry
var poneglyph_database: Dictionary = {}
var deciphered_poneglyph_ids: Dictionary = {}
var laugh_tale_unlocked: bool = false
var laugh_tale_coordinates: Dictionary = {}

# ==============================================================================
# 3. LIFECYCLE & REGIONAL DATA AGGREGATION
# ==============================================================================
func _ready() -> void:
	_seed_core_canonical_islands()
	_initialize_dynamic_entities()
	_initialize_poneglyph_registry()
	call_deferred("reload_all_regional_modules")

func _physics_process(delta: float) -> void:
	_world_clock_sec += delta
	_update_dynamic_entities(delta)
	_update_log_pose_charge(delta)

## Dynamically loads all regional worker data scripts (`regions/*_data.gd` & `reverse_mountain_controller.gd`)
## if present on disk, merging their island, marketplace, and NPC records into `islands_by_id`.
func reload_all_regional_modules() -> int:
	var module_specs: Array[Dictionary] = [
		{"region": "east_blue", "path": "res://regions/east_blue_data.gd"},
		{"region": "north_blue", "path": "res://regions/north_blue_data.gd"},
		{"region": "west_blue", "path": "res://regions/west_blue_data.gd"},
		{"region": "south_blue", "path": "res://regions/south_blue_data.gd"},
		{"region": "reverse_mountain", "path": "res://regions/reverse_mountain_controller.gd"},
		{"region": "grand_line", "path": "res://regions/grand_line_data.gd"}
	]
	for spec in module_specs:
		var script_path: String = spec["path"]
		var region_key: String = spec["region"]
		if ResourceLoader.exists(script_path):
			var script_res: Variant = load(script_path)
			if script_res != null:
				_ingest_regional_script(region_key, script_res)
	return islands_by_id.size()

func _ingest_regional_script(region_key: String, script_res: Variant) -> void:
	var instance: Variant = script_res
	if script_res is Script and script_res.can_instantiate():
		instance = script_res.new()

	var getter_candidates: Array[String] = [
		"get_all_islands",
		"get_islands",
		"get_region_islands",
		"get_twin_cape_data",
		"build_island_registry"
	]
	var matched_getter: bool = false
	for method_name in getter_candidates:
		if script_res != null and script_res.has_method(method_name):
			var raw_static: Variant = script_res.call(method_name)
			_merge_raw_island_collection(region_key, raw_static)
			matched_getter = true
			break
		elif instance != null and instance.has_method(method_name):
			var raw_inst: Variant = instance.call(method_name)
			_merge_raw_island_collection(region_key, raw_inst)
			matched_getter = true
			break

	if script_res is Script:
		var const_map: Dictionary = script_res.get_script_constant_map()
		for const_key in ["ISLANDS", "REGION_ISLANDS", "TWIN_CAPE_SETTLEMENT"]:
			if const_map.has(const_key):
				var const_val: Variant = const_map[const_key]
				if const_key == "TWIN_CAPE_SETTLEMENT" and const_val is Dictionary:
					register_island("twin_cape", region_key, const_val)
				elif not matched_getter:
					_merge_raw_island_collection(region_key, const_val)

	if instance is Object and not (instance is RefCounted) and not (instance is Resource):
		instance.free()

func _merge_raw_island_collection(region_key: String, raw_data: Variant) -> void:
	if raw_data is Dictionary:
		for key in raw_data.keys():
			var entry: Variant = raw_data[key]
			if entry is Dictionary:
				var island_id: String = str(entry.get("id", key)).to_snake_case()
				register_island(island_id, region_key, entry)
	elif raw_data is Array:
		for entry in raw_data:
			if entry is Dictionary:
				var island_id: String = str(entry.get("id", entry.get("name", "unknown"))).to_snake_case()
				register_island(island_id, region_key, entry)

## Extracts (lat_deg, lon_deg, alt_m) from any regional island schema:
## - Top-level keys: `lat_deg` / `lat` / `latitude`, `lon_deg` / `lon` / `longitude`, `alt_m` / `altitude_m` / `elevation_m` / `alt` / `altitude`
## - Nested `coordinates` key: `Vector2(lat, lon)`, `Vector3(lat, lon, alt)`, or `Dictionary` with `lat`/`lat_deg`, `lon`/`lon_deg`, `alt`/`alt_m`/`altitude_m`/`altitude`
static func extract_island_coordinates(record: Dictionary) -> Dictionary:
	var lat: float = 0.0
	var lon: float = 0.0
	var alt: float = 0.0
	var has_top_lat: bool = false
	var has_top_lon: bool = false
	var has_top_alt: bool = false

	for lat_key in ["lat_deg", "lat", "latitude_deg", "latitude"]:
		if record.has(lat_key):
			lat = float(record[lat_key])
			has_top_lat = true
			break

	for lon_key in ["lon_deg", "lon", "longitude_deg", "longitude"]:
		if record.has(lon_key):
			lon = float(record[lon_key])
			has_top_lon = true
			break

	for alt_key in ["alt_m", "altitude_m", "elevation_m", "alt", "altitude"]:
		if record.has(alt_key):
			alt = float(record[alt_key])
			has_top_alt = true
			break

	if record.has("coordinates"):
		var coords_val: Variant = record["coordinates"]
		if coords_val is Vector2:
			if not has_top_lat:
				lat = coords_val.x
			if not has_top_lon:
				lon = coords_val.y
		elif coords_val is Vector3:
			if not has_top_lat:
				lat = coords_val.x
			if not has_top_lon:
				lon = coords_val.y
			if not has_top_alt:
				alt = coords_val.z
		elif coords_val is Dictionary:
			if not has_top_lat:
				for k in ["lat_deg", "lat", "latitude_deg", "latitude"]:
					if coords_val.has(k):
						lat = float(coords_val[k])
						break
			if not has_top_lon:
				for k in ["lon_deg", "lon", "longitude_deg", "longitude"]:
					if coords_val.has(k):
						lon = float(coords_val[k])
						break
			if not has_top_alt:
				for k in ["alt_m", "altitude_m", "elevation_m", "alt", "altitude"]:
					if coords_val.has(k):
						alt = float(coords_val[k])
						break

	return {
		"lat_deg": lat,
		"lon_deg": lon,
		"alt_m": alt
	}

func register_island(island_id: String, region_key: String, record: Dictionary) -> void:
	var normalized_record: Dictionary = record.duplicate(true)
	normalized_record["id"] = island_id
	normalized_record["region"] = region_key

	var parsed_coords: Dictionary = extract_island_coordinates(normalized_record)
	var lat: float = parsed_coords["lat_deg"]
	var lon: float = parsed_coords["lon_deg"]
	var alt: float = parsed_coords["alt_m"]

	normalized_record["lat_deg"] = lat
	normalized_record["lon_deg"] = lon
	normalized_record["alt_m"] = alt
	normalized_record["altitude_m"] = alt
	normalized_record["world_pos"] = PlanetSphere.lat_lon_alt_to_world(lat, lon, alt)

	islands_by_id[island_id] = normalized_record
	if not islands_by_region.has(region_key):
		islands_by_region[region_key] = {}
	islands_by_region[region_key][island_id] = normalized_record
	island_registered.emit(island_id, region_key)

# ==============================================================================
# 4. CANONICAL BASELINE SEED REGISTRY (GARANTEED MULTI-REGION ANCHORS)
# ==============================================================================
func _seed_core_canonical_islands() -> void:
	var seed_records: Array[Dictionary] = [
		# --- EAST BLUE ---
		{
			"id": "dawn_island",
			"name": "Dawn Island (Foosha Village & Goa Kingdom)",
			"region": "east_blue",
			"lat_deg": 24.0, "lon_deg": 42.0, "alt_m": 0.0,
			"log_pose_lock_sec": 0.0,
			"danger_jitter_deg": 0.0,
			"currency": "Beli",
			"next_islands": ["shells_town", "shimotsuki_village"],
			"shops": ["Partys Bar", "Foosha Fish Market", "High Town Royal Bazaar", "Gray Terminal Scrap Exchange"],
			"npcs": ["Makino", "Woop Slap", "Curly Dadan", "Gyoru"]
		},
		{
			"id": "shells_town",
			"name": "Shells Town (Marine Base 153)",
			"region": "east_blue",
			"lat_deg": 26.5, "lon_deg": 36.0, "alt_m": 0.0,
			"log_pose_lock_sec": 0.0,
			"danger_jitter_deg": 1.0,
			"currency": "Beli",
			"next_islands": ["orange_town", "shimotsuki_village"],
			"shops": ["Food & Bar (Ririka's Tavern)", "Base 153 Surplus Armory"],
			"npcs": ["Rika", "Ririka", "Koby"]
		},
		{
			"id": "orange_town",
			"name": "Organ Islands (Orange Town)",
			"region": "east_blue",
			"lat_deg": 23.0, "lon_deg": 29.0, "alt_m": 0.0,
			"log_pose_lock_sec": 0.0,
			"danger_jitter_deg": 1.5,
			"currency": "Beli",
			"next_islands": ["syrup_village"],
			"shops": ["Chouchou's Pet Food Shop", "Mayor Boodle's Rebuild Supply Depot"],
			"npcs": ["Boodle", "Chouchou", "Poro"]
		},
		{
			"id": "syrup_village",
			"name": "Gecko Islands (Syrup Village)",
			"region": "east_blue",
			"lat_deg": 21.0, "lon_deg": 23.5, "alt_m": 0.0,
			"log_pose_lock_sec": 0.0,
			"danger_jitter_deg": 1.0,
			"currency": "Beli",
			"next_islands": ["baratie"],
			"shops": ["Meshi Restaurant", "Kaya Mansion Shipyard"],
			"npcs": ["Kaya", "Merry", "Ninjin", "Piiman", "Tamanegi"]
		},
		{
			"id": "baratie",
			"name": "Baratie (Sambas Region Ocean Restaurant)",
			"region": "east_blue",
			"lat_deg": 17.5, "lon_deg": 19.0, "alt_m": 0.0,
			"log_pose_lock_sec": 0.0,
			"danger_jitter_deg": 2.0,
			"currency": "Beli",
			"next_islands": ["conomi_islands", "loguetown"],
			"shops": ["The Baratie Dining Hall", "Sister Anko Galley Market"],
			"npcs": ["Chef Zeff", "Patty", "Carne"]
		},
		{
			"id": "conomi_islands",
			"name": "Conomi Islands (Cocoyasi Village & Arlong Park)",
			"region": "east_blue",
			"lat_deg": 22.0, "lon_deg": 13.5, "alt_m": 0.0,
			"log_pose_lock_sec": 0.0,
			"danger_jitter_deg": 2.5,
			"currency": "Beli",
			"next_islands": ["loguetown"],
			"shops": ["Bell-mere's Tangerine Grove", "Cocoyasi Cartography Guild"],
			"npcs": ["Nojiko", "Genzo", "Dr. Nako", "Johnny", "Yosaku"]
		},
		{
			"id": "loguetown",
			"name": "Loguetown (Town of Beginning and End)",
			"region": "east_blue",
			"lat_deg": 16.0, "lon_deg": 5.5, "alt_m": 0.0,
			"log_pose_lock_sec": 0.0,
			"danger_jitter_deg": 3.0,
			"currency": "Beli",
			"next_islands": ["reverse_mountain"],
			"shops": ["Ipponmatsu's Arms Shop", "Gold Roger Bar", "Crownsmen Boutique", "Grand Fish Market"],
			"npcs": ["Ipponmatsu", "Ipponume", "Raoul", "Hanger"]
		},
		# --- NORTH, WEST & SOUTH BLUE STARTER HUBS ---
		{
			"id": "lvneel_kingdom",
			"name": "Lvneel Kingdom",
			"region": "north_blue",
			"lat_deg": 38.0, "lon_deg": -34.0, "alt_m": 0.0,
			"log_pose_lock_sec": 0.0,
			"danger_jitter_deg": 1.5,
			"currency": "Beli",
			"next_islands": ["spider_miles", "reverse_mountain"],
			"shops": ["Royal Botanical Exchange", "Lvneel Explorer's Guild"],
			"npcs": ["Noland Descendants", "Royal Botanists"]
		},
		{
			"id": "ohara_ruins",
			"name": "Ohara (Ruins of the Tree of Knowledge)",
			"region": "west_blue",
			"lat_deg": -34.0, "lon_deg": -52.0, "alt_m": 0.0,
			"log_pose_lock_sec": 0.0,
			"danger_jitter_deg": 4.0,
			"currency": "Beli",
			"next_islands": ["kano_country", "reverse_mountain"],
			"shops": ["Smuggler's Research Camp"],
			"npcs": ["Rogue Archaeologists"]
		},
		{
			"id": "sorbet_kingdom",
			"name": "Sorbet Kingdom & Kuma's Sanctuary",
			"region": "south_blue",
			"lat_deg": -36.0, "lon_deg": 48.0, "alt_m": 0.0,
			"log_pose_lock_sec": 0.0,
			"danger_jitter_deg": 2.0,
			"currency": "Beli",
			"next_islands": ["torino_kingdom", "reverse_mountain"],
			"shops": ["Kuma's Old Church Sanctuary", "Bonney's Brick-Oven Bakery"],
			"npcs": ["Gyogyo", "Conney", "Sorbet Elders"]
		},
		# --- REVERSE MOUNTAIN & PARADISE (FIRST HALF OF GRAND LINE) ---
		{
			"id": "reverse_mountain",
			"name": "Reverse Mountain Hydraulic Summit",
			"region": "reverse_mountain",
			"lat_deg": 0.0, "lon_deg": 0.0, "alt_m": 5_000.0,
			"log_pose_lock_sec": 60.0,
			"danger_jitter_deg": 5.0,
			"currency": "Beli",
			"next_islands": ["twin_cape"],
			"shops": [],
			"npcs": []
		},
		{
			"id": "twin_cape",
			"name": "Twin Cape Lighthouse (Entrance to Paradise)",
			"region": "reverse_mountain",
			"lat_deg": -1.5, "lon_deg": 2.2, "alt_m": 0.0,
			"log_pose_lock_sec": 120.0,
			"danger_jitter_deg": 2.5,
			"currency": "Beli",
			"next_islands": ["whisky_peak", "vira", "pucci"],
			"shops": ["Crocus's Lighthouse Clinic", "Inside-Laboon Stomach Salvage"],
			"npcs": ["Crocus", "Laboon"]
		},
		{
			"id": "whisky_peak",
			"name": "Whisky Peak (Cactus Island)",
			"region": "grand_line",
			"lat_deg": -8.0, "lon_deg": 16.0, "alt_m": 0.0,
			"log_pose_lock_sec": 600.0,
			"danger_jitter_deg": 4.0,
			"currency": "Beli",
			"next_islands": ["little_garden"],
			"shops": ["Cactus Saloon", "Bounty Hunter Trap Inn"],
			"npcs": ["Igaram", "Miss Monday"]
		},
		{
			"id": "little_garden",
			"name": "Little Garden (Prehistoric Island)",
			"region": "grand_line",
			"lat_deg": -14.0, "lon_deg": 32.0, "alt_m": 0.0,
			"log_pose_lock_sec": 7_200.0, # Canonical 1-year lock; overridden via Alabasta/Drum Eternal Pose
			"danger_jitter_deg": 7.5,
			"currency": "Beli",
			"next_islands": ["drum_island", "alabasta"],
			"shops": [],
			"npcs": ["Dorry", "Brogy"]
		},
		{
			"id": "drum_island",
			"name": "Drum Island (Sakura Kingdom)",
			"region": "grand_line",
			"lat_deg": -18.5, "lon_deg": 46.0, "alt_m": 0.0,
			"log_pose_lock_sec": 900.0,
			"danger_jitter_deg": 5.0,
			"currency": "Beli",
			"next_islands": ["alabasta"],
			"shops": ["Dr. Kureha's Castle Apothecary", "Dalton's Bighorn Provision Post", "Gyasta Ski-Lift Tavern"],
			"npcs": ["Dr. Kureha", "Dalton", "Negikuma Maria"]
		},
		{
			"id": "alabasta",
			"name": "Alabasta Kingdom (Sandy Island)",
			"region": "grand_line",
			"lat_deg": -22.0, "lon_deg": 64.0, "alt_m": 0.0,
			"log_pose_lock_sec": 1_800.0,
			"danger_jitter_deg": 6.0,
			"currency": "Beli",
			"next_islands": ["jaya"],
			"shops": ["Spice Bean Restaurant", "Nanohana Perfume Bazaar", "Spiders Cafe", "Rain Dinners Casino"],
			"npcs": ["Nefertari Vivi", "King Cobra", "Pell", "Chaka", "Igaram", "Toto", "Zala"]
		},
		{
			"id": "jaya",
			"name": "Jaya (Mock Town & Shandora Half-Skull)",
			"region": "grand_line",
			"lat_deg": -26.0, "lon_deg": 88.0, "alt_m": 0.0,
			"log_pose_lock_sec": 2_400.0,
			"danger_jitter_deg": 8.5,
			"currency": "Beli",
			"next_islands": ["skypiea", "long_ring_long_land"],
			"shops": ["Pub and Pies", "Tropical Hotel"],
			"npcs": ["Mont Blanc Cricket", "Masira", "Shoujou", "Terry", "Spector"]
		},
		{
			"id": "skypiea",
			"name": "Skypiea (Angel Island & Upper Yard)",
			"region": "grand_line",
			"lat_deg": -25.5, "lon_deg": 90.0, "alt_m": 10_000.0,
			"log_pose_lock_sec": 1_200.0,
			"danger_jitter_deg": 9.5,
			"currency": "Extol",
			"next_islands": ["long_ring_long_land", "water_7"],
			"shops": ["Lovely Street Dial Market", "Conis's Pumpkin Cafe"],
			"npcs": ["Gan Fall", "Conis", "Pagaya", "Wiper", "Aisa"]
		},
		{
			"id": "long_ring_long_land",
			"name": "Long Ring Long Land",
			"region": "grand_line",
			"lat_deg": -20.0, "lon_deg": 112.0, "alt_m": 0.0,
			"log_pose_lock_sec": 600.0,
			"danger_jitter_deg": 3.5,
			"currency": "Beli",
			"next_islands": ["water_7"],
			"shops": ["Tonjit's Nomadic Yurt"],
			"npcs": ["Tonjit", "Shelly"]
		},
		{
			"id": "water_7",
			"name": "Water 7 (The Capital of Water)",
			"region": "grand_line",
			"lat_deg": -14.5, "lon_deg": 134.0, "alt_m": 0.0,
			"log_pose_lock_sec": 1_800.0,
			"danger_jitter_deg": 6.5,
			"currency": "Beli",
			"next_islands": ["thriller_bark", "sabaody_archipelago"],
			"shops": ["Galley-La Dock 1-7 Shipyards", "Blueno's Bar", "Yagara Bull Rental", "Skypiea Gold-to-Beli Exchange"],
			"npcs": ["Iceburg", "Paulie", "Peepley Lulu", "Tilestone", "Kokoro", "Chimney", "Zambai"]
		},
		{
			"id": "thriller_bark",
			"name": "Florian Triangle (Thriller Bark)",
			"region": "grand_line",
			"lat_deg": -7.5, "lon_deg": 158.0, "alt_m": 0.0,
			"log_pose_lock_sec": 900.0,
			"danger_jitter_deg": 9.0,
			"currency": "Beli",
			"next_islands": ["sabaody_archipelago"],
			"shops": ["Dr. Hogback's Lab Ruins"],
			"npcs": ["Lola", "Risky Brothers", "Spoil"]
		},
		{
			"id": "amazon_lily",
			"name": "Amazon Lily (Island of Women — Calm Belt)",
			"region": "grand_line",
			"lat_deg": -19.0, "lon_deg": 166.0, "alt_m": 0.0,
			"log_pose_lock_sec": 1_200.0,
			"danger_jitter_deg": 8.0,
			"currency": "Gor",
			"next_islands": ["sabaody_archipelago"],
			"shops": ["Kuja Snake-Archery Foundry", "Gor Currency Bazaar"],
			"npcs": ["Boa Hancock", "Gloriosa (Elder Nyon)", "Marguerite", "Aphelandra", "Sweet Pea"]
		},
		{
			"id": "sabaody_archipelago",
			"name": "Sabaody Archipelago (Groves 1-79)",
			"region": "grand_line",
			"lat_deg": -1.0, "lon_deg": 177.5, "alt_m": 0.0,
			"log_pose_lock_sec": 2_400.0,
			"danger_jitter_deg": 7.0,
			"currency": "Beli",
			"next_islands": ["fish_man_island"],
			"shops": ["Shakky's Rip-Off Bar (GR 13)", "Rayleigh's Coating Workshop", "Sabaody Park Mall", "Tourist Street"],
			"npcs": ["Shakuyaku (Shakky)", "Silvers Rayleigh", "Duval"]
		},
		# --- ABYSS & THE NEW WORLD (SECOND HALF OF GRAND LINE) ---
		{
			"id": "fish_man_island",
			"name": "Fish-Man Island (-10,000m Under the Red Line)",
			"region": "grand_line",
			"lat_deg": 0.0, "lon_deg": 180.0, "alt_m": -10_000.0,
			"log_pose_lock_sec": 1_500.0,
			"danger_jitter_deg": 6.0,
			"currency": "Beli",
			"next_islands": ["punk_hazard", "raijin_island", "risky_red_island"],
			"shops": ["Mermaid Cafe", "Criminal Brand Flagship Store", "Takoyaki 8", "Candy Factory"],
			"npcs": ["Madam Shyarly", "King Neptune", "Shirahoshi", "Jinbe", "Pappag", "Camie", "Den", "Hatchan"]
		},
		{
			"id": "punk_hazard",
			"name": "Punk Hazard (Burning & Ice Restricted Island)",
			"region": "grand_line",
			"lat_deg": 7.5, "lon_deg": -164.0, "alt_m": 0.0,
			"log_pose_lock_sec": 900.0,
			"danger_jitter_deg": 16.5, # Extreme magnetic anomaly
			"currency": "Beli",
			"next_islands": ["dressrosa", "green_bit", "prodence_kingdom"],
			"shops": ["Caesar's Abandoned Lab Supply", "G-5 Surplus Locker"],
			"npcs": ["Brownbeard", "Mocha"]
		},
		{
			"id": "dressrosa",
			"name": "Dressrosa & Green Bit (Kingdom of Passion & Tontatta)",
			"region": "grand_line",
			"lat_deg": 14.0, "lon_deg": -146.0, "alt_m": 0.0,
			"log_pose_lock_sec": 1_800.0,
			"danger_jitter_deg": 8.5,
			"currency": "Beli",
			"next_islands": ["whole_cake_island", "karai_bari", "applenine"],
			"shops": ["Acacia Tapas & Wine Bistro", "Corrida Colosseum Armory", "Tontatta Botanical Patch"],
			"npcs": ["Kyros", "King Riku", "Viola", "Rebecca", "Leo", "Gatz"]
		},
		{
			"id": "zou",
			"name": "Zou (Mokomo Dukedom atop Zunesha)",
			"region": "grand_line",
			"lat_deg": 19.5, "lon_deg": -128.0, "alt_m": 10_000.0,
			"log_pose_lock_sec": 0.0, # Cannot be locked by Log Pose; requires Mink Vivre Card
			"danger_jitter_deg": 0.0,
			"currency": "Beli",
			"next_islands": ["whole_cake_island", "wano_country"],
			"shops": ["Claw City Silk & Electro Bazaar", "Guardians' Forest Outpost"],
			"npcs": ["Inuarashi", "Nekomamushi", "Carrot", "Wanda", "Pedro", "Miyagi"]
		},
		{
			"id": "whole_cake_island",
			"name": "Totto Land — Whole Cake Island & 34 Food Islands",
			"region": "grand_line",
			"lat_deg": 24.0, "lon_deg": -106.0, "alt_m": 0.0,
			"log_pose_lock_sec": 2_400.0,
			"danger_jitter_deg": 14.0,
			"currency": "Beli",
			"next_islands": ["wano_country", "sphinx_island", "fullalead_hachinosu"],
			"shops": ["Chocolat Cafe (Cacao Island)", "Sweet City Confectionery Boulevard", "Hakuriki Flour Market"],
			"npcs": ["Charlotte Pudding", "Charlotte Katakuri", "Streusen", "Kingbaum"]
		},
		{
			"id": "wano_country",
			"name": "Wano Country (Flower Capital, Kuri, Ringo, Udon, Hakumai, Onigashima)",
			"region": "grand_line",
			"lat_deg": 27.5, "lon_deg": -78.0, "alt_m": 800.0,
			"log_pose_lock_sec": 3_600.0,
			"danger_jitter_deg": 15.5,
			"currency": "WanoSilverRyo",
			"next_islands": ["egghead_island", "elbaf", "winner_island"],
			"shops": ["O-Sobamask Noodle Stall", "Hitetsu's Amigasa Sword Forge", "Ebisu Town Flea Market"],
			"npcs": ["Kozuki Momonosuke", "Kozuki Sukiyaki (Tenguyama Hitetsu)", "Hyogoro", "Tsurujo", "Tama"]
		},
		{
			"id": "egghead_island",
			"name": "Egghead (Island of the Future — 500 Years Ahead)",
			"region": "grand_line",
			"lat_deg": 18.0, "lon_deg": -52.0, "alt_m": 0.0,
			"log_pose_lock_sec": 1_800.0,
			"danger_jitter_deg": 13.0,
			"currency": "Beli",
			"next_islands": ["elbaf", "fullalead_hachinosu", "lodestar_island"],
			"shops": ["Vegapunk Automated Food Dispenser", "Labophase Invention Foundry"],
			"npcs": ["Dr. Vegapunk", "Shaka", "Lilith", "Edison", "Pythagoras", "Atlas", "Sentomaru"]
		},
		{
			"id": "elbaf",
			"name": "Elbaf (Warland — Kingdom of Giants)",
			"region": "grand_line",
			"lat_deg": 11.0, "lon_deg": -28.0, "alt_m": 0.0,
			"log_pose_lock_sec": 2_400.0,
			"danger_jitter_deg": 12.0,
			"currency": "Beli",
			"next_islands": ["lodestar_island"],
			"shops": ["Great Tree Yggdrasil Mead Hall", "Owl's Giant Library"],
			"npcs": ["Jaguar D. Saul", "Dorry", "Brogy", "Hajrudin", "Oimo", "Kashii"]
		},
		{
			"id": "lodestar_island",
			"name": "Lodestar Island (Road Star — Endpoint of the Log Pose)",
			"region": "grand_line",
			"lat_deg": 4.0, "lon_deg": -12.0, "alt_m": 0.0,
			"log_pose_lock_sec": 3_600.0,
			"danger_jitter_deg": 25.0, # Needles spin wildly past Lodestar; reveals need for 4 Road Poneglyphs
			"currency": "Beli",
			"next_islands": [],
			"shops": ["Lodestar Magnetic Observatory"],
			"npcs": ["Ancient Log Pose Archivists"]
		}
	]
	for rec in seed_records:
		register_island(rec["id"], rec["region"], rec)

# ==============================================================================
# 5. LOG POSE, TRIPLE-NEEDLE LOG POSE, ETERNAL POSE & VIVRE CARD NAVIGATION
# ==============================================================================
## Docks the player's vessel at `island_id`, starting the island's magnetic field lock timer.
func notify_island_docked(island_id: String) -> Dictionary:
	if not islands_by_id.has(island_id):
		return {"success": false, "reason": "Unknown island_id: " + island_id}

	current_docked_island_id = island_id
	discovered_island_ids[island_id] = true
	var record: Dictionary = islands_by_id[island_id]
	log_pose_required_sec = float(record.get("log_pose_lock_sec", 600.0))
	log_pose_charge_elapsed_sec = 0.0

	if log_pose_required_sec <= 0.0:
		_complete_log_pose_lock(island_id)
	else:
		log_pose_is_locked = false

	return {
		"success": true,
		"island_id": island_id,
		"required_lock_sec": log_pose_required_sec,
		"is_locked": log_pose_is_locked
	}

func _update_log_pose_charge(delta: float) -> void:
	if current_docked_island_id.is_empty() or log_pose_is_locked:
		return
	log_pose_charge_elapsed_sec += delta
	if log_pose_charge_elapsed_sec >= log_pose_required_sec:
		_complete_log_pose_lock(current_docked_island_id)

func _complete_log_pose_lock(island_id: String) -> void:
	log_pose_is_locked = true
	log_pose_locked_island_id = island_id
	var record: Dictionary = islands_by_id.get(island_id, {})
	var next_candidates: Array[String] = []
	for cand in record.get("next_islands", []):
		next_candidates.append(str(cand))

	if next_candidates.size() >= 3:
		triple_needle_targets = [next_candidates[0], next_candidates[1], next_candidates[2]]
	elif not next_candidates.is_empty():
		triple_needle_targets.clear()
		for c in next_candidates:
			triple_needle_targets.append(c)

	log_pose_locked.emit(island_id, next_candidates)

## Grants & equips an Eternal Pose (instant override of standard Log Pose sequential wait).
func acquire_and_equip_eternal_pose(target_island_id: String) -> bool:
	if not islands_by_id.has(target_island_id):
		return false
	if not owned_eternal_poses.has(target_island_id):
		owned_eternal_poses.append(target_island_id)
	equipped_eternal_pose_island_id = target_island_id
	active_nav_mode = NavigationToolMode.ETERNAL_POSE
	eternal_pose_equipped.emit(target_island_id)
	return true

## Computes the real-time 3D navigation vector(s) on the 64-bit sphere for the player's ship at `ship_world_pos`.
func compute_navigation_reading(ship_world_pos: Vector3) -> Dictionary:
	var coords: Dictionary = PlanetSphere.world_to_lat_lon_alt(ship_world_pos)
	var north_pole_pos: Vector3 = PlanetSphere.lat_lon_alt_to_world(90.0, 0.0, 0.0)

	match active_nav_mode:
		NavigationToolMode.STANDARD_COMPASS:
			# In Grand Line or Calm Belt, standard magnetic compass spins erratically
			var u: Vector3 = ship_world_pos.normalized()
			var gl_normal := Vector3(0.0, cos(deg_to_rad(-45.0)), -sin(deg_to_rad(-45.0))).normalized()
			var dist_gl_m: float = absf(PlanetSphere.SEA_LEVEL_RADIUS * asin(clampf(u.dot(gl_normal), -1.0, 1.0)))
			if dist_gl_m <= PlanetSphere.CALM_BELT_OUTER_OFFSET_M:
				var chaotic_angle: float = _world_clock_sec * 4.7
				return {
					"mode": "STANDARD_COMPASS",
					"reliable": false,
					"status": "CHAOTIC_MAGNETIC_ANOMALY — Equip Log Pose!",
					"heading_tangent": Vector3(cos(chaotic_angle), 0.0, sin(chaotic_angle)).normalized()
				}
			return {
				"mode": "STANDARD_COMPASS",
				"reliable": true,
				"status": "True Magnetic North",
				"heading_tangent": PlanetSphere.geodesic_tangent_direction(ship_world_pos, north_pole_pos)
			}

		NavigationToolMode.SINGLE_LOG_POSE:
			var rec: Dictionary = islands_by_id.get(log_pose_locked_island_id, {})
			var next_list: Array = rec.get("next_islands", [])
			var target_id: String = str(next_list[0]) if not next_list.is_empty() else log_pose_locked_island_id
			var target_rec: Dictionary = islands_by_id.get(target_id, {})
			var target_pos: Vector3 = target_rec.get("world_pos", north_pole_pos)
			var dist_m: float = PlanetSphere.great_circle_distance_m(
				coords["lat_deg"], coords["lon_deg"],
				float(target_rec.get("lat_deg", 0.0)), float(target_rec.get("lon_deg", 0.0))
			)
			return {
				"mode": "SINGLE_LOG_POSE",
				"reliable": log_pose_is_locked,
				"locked_from": log_pose_locked_island_id,
				"target_island_id": target_id,
				"target_name": target_rec.get("name", target_id),
				"distance_km": dist_m / 1_000.0,
				"charge_progress": 1.0 if log_pose_is_locked else clampf(log_pose_charge_elapsed_sec / maxf(1.0, log_pose_required_sec), 0.0, 1.0),
				"heading_tangent": PlanetSphere.geodesic_tangent_direction(ship_world_pos, target_pos)
			}

		NavigationToolMode.TRIPLE_LOG_POSE:
			var needles: Array[Dictionary] = []
			for idx in range(triple_needle_targets.size()):
				var tid: String = triple_needle_targets[idx]
				var trec: Dictionary = islands_by_id.get(tid, {})
				var tpos: Vector3 = trec.get("world_pos", north_pole_pos)
				var base_jitter_deg: float = float(trec.get("danger_jitter_deg", 5.0))
				var instant_jitter_deg: float = sin(_world_clock_sec * (3.0 + idx * 2.3)) * base_jitter_deg
				var dist_m: float = PlanetSphere.great_circle_distance_m(
					coords["lat_deg"], coords["lon_deg"],
					float(trec.get("lat_deg", 0.0)), float(trec.get("lon_deg", 0.0))
				)
				needles.append({
					"needle_index": idx + 1,
					"target_island_id": tid,
					"target_name": trec.get("name", tid),
					"danger_jitter_amplitude_deg": base_jitter_deg,
					"instant_jitter_deg": instant_jitter_deg,
					"stability_rating": "EXTREME_HAZARD" if base_jitter_deg >= 14.0 else ("MODERATE" if base_jitter_deg >= 7.0 else "STABLE"),
					"distance_km": dist_m / 1_000.0,
					"heading_tangent": PlanetSphere.geodesic_tangent_direction(ship_world_pos, tpos)
				})
			return {
				"mode": "TRIPLE_LOG_POSE",
				"reliable": true,
				"needles": needles
			}

		NavigationToolMode.ETERNAL_POSE:
			var erec: Dictionary = islands_by_id.get(equipped_eternal_pose_island_id, {})
			var epos: Vector3 = erec.get("world_pos", north_pole_pos)
			var dist_m: float = PlanetSphere.great_circle_distance_m(
				coords["lat_deg"], coords["lon_deg"],
				float(erec.get("lat_deg", 0.0)), float(erec.get("lon_deg", 0.0))
			)
			return {
				"mode": "ETERNAL_POSE",
				"reliable": true,
				"target_island_id": equipped_eternal_pose_island_id,
				"target_name": erec.get("name", equipped_eternal_pose_island_id),
				"distance_km": dist_m / 1_000.0,
				"heading_tangent": PlanetSphere.geodesic_tangent_direction(ship_world_pos, epos)
			}

		NavigationToolMode.VIVRE_CARD:
			var v_entity: Dictionary = dynamic_entities.get(active_vivre_card_id, {})
			var v_pos: Vector3 = v_entity.get("world_pos", north_pole_pos)
			var v_coords: Dictionary = PlanetSphere.world_to_lat_lon_alt(v_pos)
			var dist_m: float = PlanetSphere.great_circle_distance_m(
				coords["lat_deg"], coords["lon_deg"],
				v_coords["lat_deg"], v_coords["lon_deg"]
			)
			return {
				"mode": "VIVRE_CARD",
				"reliable": true,
				"vivre_card_id": active_vivre_card_id,
				"owner_name": v_entity.get("name", active_vivre_card_id),
				"life_force_ratio": float(v_entity.get("life_force_ratio", 1.0)),
				"distance_km": dist_m / 1_000.0,
				"heading_tangent": PlanetSphere.geodesic_tangent_direction(ship_world_pos, v_pos)
			}

	return {"mode": "UNKNOWN", "reliable": false}

# ==============================================================================
# 6. DYNAMIC MOVING ENTITIES (ZUNESHA / ZOU, GERMA 66 SNAIL FLEET, RAYLEIGH)
# ==============================================================================
func _initialize_dynamic_entities() -> void:
	dynamic_entities = {
		"zunesha_zou": {
			"name": "Zunesha (20km Millennial Elephant Carrying Zou)",
			"center_lat_deg": 19.5,
			"center_lon_deg": -128.0,
			"orbit_radius_deg": 3.5,
			"angular_speed_rad_s": 0.00025,
			"alt_m": 10_000.0,
			"life_force_ratio": 1.0,
			"world_pos": PlanetSphere.lat_lon_alt_to_world(19.5, -128.0, 10_000.0)
		},
		"silvers_rayleigh": {
			"name": "Silvers Rayleigh (Sabaody Grove 13 — Shakky's Rip-Off Bar)",
			"center_lat_deg": -1.0,
			"center_lon_deg": 177.5,
			"orbit_radius_deg": 0.0,
			"angular_speed_rad_s": 0.0,
			"alt_m": 0.0,
			"life_force_ratio": 1.0,
			"world_pos": PlanetSphere.lat_lon_alt_to_world(-1.0, 177.5, 0.0)
		},
		"germa_66_fleet": {
			"name": "Germa Kingdom (Nomadic Snail-Ship Maritime Empire)",
			"center_lat_deg": 42.0,
			"center_lon_deg": -45.0,
			"orbit_radius_deg": 6.0,
			"angular_speed_rad_s": 0.0004,
			"alt_m": 0.0,
			"life_force_ratio": 1.0,
			"world_pos": PlanetSphere.lat_lon_alt_to_world(42.0, -45.0, 0.0)
		}
	}

func _update_dynamic_entities(_delta: float) -> void:
	for key in dynamic_entities.keys():
		var ent: Dictionary = dynamic_entities[key]
		var r_deg: float = float(ent["orbit_radius_deg"])
		if r_deg > 0.0001:
			var phase: float = _world_clock_sec * float(ent["angular_speed_rad_s"])
			var lat: float = float(ent["center_lat_deg"]) + sin(phase) * r_deg
			var lon: float = float(ent["center_lon_deg"]) + cos(phase) * r_deg
			var alt: float = float(ent["alt_m"])
			var wpos: Vector3 = PlanetSphere.lat_lon_alt_to_world(lat, lon, alt)
			ent["world_pos"] = wpos
			if key == "zunesha_zou" and islands_by_id.has("zou"):
				islands_by_id["zou"]["lat_deg"] = lat
				islands_by_id["zou"]["lon_deg"] = lon
				islands_by_id["zou"]["world_pos"] = wpos

# ==============================================================================
# 7. MULTI-CURRENCY ECONOMY (BELI, EXTOL 10,000:1, GOR, WANO RYO)
# ==============================================================================
## Converts an `amount` of `from_currency` into `to_currency` using canonical exchange rates:
## 1 Beli = 10,000 Extol | 1 Gor = 100 Beli | 1 Wano Silver Ryo = 500 Beli |
## 1 Wano Gold Ryo = 10,000 Beli | 1 Wano Platinum Ryo = 1,000,000 Beli.
static func convert_currency_amount(amount: int, from_currency: String, to_currency: String) -> int:
	if from_currency == to_currency:
		return amount

	# Convert into Extol as the smallest integer atomic unit (1 Beli = 10,000 Extol) to avoid truncation
	var value_in_extol: int = 0
	match from_currency:
		"Beli":
			value_in_extol = amount * EXTOL_PER_BELI
		"Extol":
			value_in_extol = amount
		"Gor":
			value_in_extol = amount * BELI_PER_GOR * EXTOL_PER_BELI
		"WanoSilverRyo":
			value_in_extol = amount * BELI_PER_WANO_SILVER_RYO * EXTOL_PER_BELI
		"WanoGoldRyo":
			value_in_extol = amount * BELI_PER_WANO_GOLD_RYO * EXTOL_PER_BELI
		"WanoPlatinumRyo":
			value_in_extol = amount * BELI_PER_WANO_PLATINUM_RYO * EXTOL_PER_BELI
		_:
			return 0

	match to_currency:
		"Beli":
			return value_in_extol / EXTOL_PER_BELI
		"Extol":
			return value_in_extol
		"Gor":
			return value_in_extol / (BELI_PER_GOR * EXTOL_PER_BELI)
		"WanoSilverRyo":
			return value_in_extol / (BELI_PER_WANO_SILVER_RYO * EXTOL_PER_BELI)
		"WanoGoldRyo":
			return value_in_extol / (BELI_PER_WANO_GOLD_RYO * EXTOL_PER_BELI)
		"WanoPlatinumRyo":
			return value_in_extol / (BELI_PER_WANO_PLATINUM_RYO * EXTOL_PER_BELI)
	return 0

func add_currency(currency_code: String, amount: int) -> int:
	if not wallet.has(currency_code):
		wallet[currency_code] = 0
	wallet[currency_code] = maxi(0, int(wallet[currency_code]) + amount)
	currency_balance_changed.emit(currency_code, wallet[currency_code])
	return wallet[currency_code]

func spend_currency(currency_code: String, cost: int) -> bool:
	var current_bal: int = int(wallet.get(currency_code, 0))
	if current_bal < cost:
		return false
	wallet[currency_code] = current_bal - cost
	currency_balance_changed.emit(currency_code, wallet[currency_code])
	return true

func exchange_wallet_currency(from_currency: String, to_currency: String, from_amount: int) -> Dictionary:
	var converted: int = convert_currency_amount(from_amount, from_currency, to_currency)
	if converted <= 0 or not spend_currency(from_currency, from_amount):
		return {"success": false, "converted_amount": 0}
	add_currency(to_currency, converted)
	return {
		"success": true,
		"from_currency": from_currency,
		"from_spent": from_amount,
		"to_currency": to_currency,
		"converted_amount": converted
	}

# ==============================================================================
# 8. CARTOGRAPHY FOG-OF-WAR & SEXTANT SURVEYING
# ==============================================================================
func record_sextant_survey(
	center_lat_deg: float,
	center_lon_deg: float,
	_eye_elevation_m: float,
	horizon_distance_m: float
) -> Dictionary:
	var angular_radius_deg: float = rad_to_deg(horizon_distance_m / PlanetSphere.SEA_LEVEL_RADIUS)
	var step_deg: float = 2.0
	var newly_revealed: int = 0

	var lat_start: float = clampf(snappedf(center_lat_deg - angular_radius_deg, step_deg), -90.0, 90.0)
	var lat_end: float = clampf(snappedf(center_lat_deg + angular_radius_deg, step_deg), -90.0, 90.0)
	var lon_start: float = snappedf(center_lon_deg - angular_radius_deg, step_deg)
	var lon_end: float = snappedf(center_lon_deg + angular_radius_deg, step_deg)

	var lat_cursor: float = lat_start
	while lat_cursor <= lat_end:
		var lon_cursor: float = lon_start
		while lon_cursor <= lon_end:
			var wrapped_lon: float = wrapf(lon_cursor, -180.0, 180.0)
			var sector_key: String = "%d_%d" % [int(round(lat_cursor / step_deg)), int(round(wrapped_lon / step_deg))]
			if not revealed_map_sectors.has(sector_key):
				revealed_map_sectors[sector_key] = true
				newly_revealed += 1
				map_sector_revealed.emit(sector_key, revealed_map_sectors.size())
			lon_cursor += step_deg
		lat_cursor += step_deg

	var detected_islands: Array[String] = []
	for island_id in islands_by_id.keys():
		var rec: Dictionary = islands_by_id[island_id]
		var dist_m: float = PlanetSphere.great_circle_distance_m(
			center_lat_deg, center_lon_deg,
			float(rec["lat_deg"]), float(rec["lon_deg"])
		)
		if dist_m <= horizon_distance_m * 1.25:
			detected_islands.append(island_id)
			discovered_island_ids[island_id] = true

	return {
		"newly_revealed_sectors": newly_revealed,
		"total_revealed_sectors": revealed_map_sectors.size(),
		"global_completion_percent": (float(revealed_map_sectors.size()) / 16200.0) * 100.0,
		"detected_islands": detected_islands
	}

# ==============================================================================
# 9. PONEGLYPH DATABASE & 4 ROAD PONEGLYPH TRIANGULATION FOR LAUGH TALE
# ==============================================================================
func _initialize_poneglyph_registry() -> void:
	poneglyph_database = {
		# --- HISTORICAL / RIO PONEGLYPHS ---
		"ohara_tree_poneglyph": {
			"id": "ohara_tree_poneglyph",
			"category": "HISTORICAL_RIO",
			"location_island_id": "ohara_ruins",
			"title": "Ohara Basement Stele — Name of the Ancient Great Kingdom",
			"lore_summary": "Records the civilization of the Great Kingdom prior to the Void Century (900–800 years ago) before the Twenty Kingdoms erased its name."
		},
		"alabasta_pluton_poneglyph": {
			"id": "alabasta_pluton_poneglyph",
			"category": "HISTORICAL_RIO",
			"location_island_id": "alabasta",
			"title": "Tomb of the Kings Poneglyph — Ancient Weapon Pluton",
			"lore_summary": "Hidden beneath Alubarna Royal Palace; reveals that the world-destroying battleship Pluton sleeps deep beneath Old Wano Country."
		},
		"skypiea_shandora_poneglyph": {
			"id": "skypiea_shandora_poneglyph",
			"category": "HISTORICAL_RIO",
			"location_island_id": "skypiea",
			"title": "Shandora Golden Belfry Poneglyph — Ancient Weapon Poseidon",
			"lore_summary": "Inscribed alongside Gol D. Roger's Oden-carved message ('We came here, found the text, and followed its guidance to the final land'); reveals Poseidon rests at Fish-Man Island."
		},
		"fish_man_joyboy_apology": {
			"id": "fish_man_joyboy_apology",
			"category": "HISTORICAL_RIO",
			"location_island_id": "fish_man_island",
			"title": "Sea Forest Poneglyph — Joy Boy's Apology Letter",
			"lore_summary": "An apology from Joy Boy of the Void Century to the Mermaid Princess Poseidon for breaking his promise regarding the Ark Noah, promising someone in the future will fulfill it."
		},
		# --- THE 4 DEEP-RED ROAD PONEGLYPHS ---
		# Canonical coordinate bearings on the New World Great Circle that intersect at Laugh Tale (lat=0.0, lon=-4.5 / 355.5 deg)
		"road_poneglyph_1_zou": {
			"id": "road_poneglyph_1_zou",
			"category": "ROAD",
			"location_island_id": "zou",
			"title": "Road Poneglyph #1 — Whale Tree Sanctuary (Zou)",
			"encrypted_bearing_lat_deg": 12.0,
			"encrypted_bearing_lon_deg": -16.5,
			"lore_summary": "Guarded for 800 years by the Mink Tribe inside the Whale Tree of Mokomo Dukedom."
		},
		"road_poneglyph_2_whole_cake": {
			"id": "road_poneglyph_2_whole_cake",
			"category": "ROAD",
			"location_island_id": "whole_cake_island",
			"title": "Road Poneglyph #2 — Whole Cake Chateau Room of Treasure",
			"encrypted_bearing_lat_deg": -12.0,
			"encrypted_bearing_lon_deg": 7.5,
			"lore_summary": "Held by Charlotte Linlin in Totto Land; rubbing acquired via infiltration of Whole Cake Chateau."
		},
		"road_poneglyph_3_wano": {
			"id": "road_poneglyph_3_wano",
			"category": "ROAD",
			"location_island_id": "wano_country",
			"title": "Road Poneglyph #3 — Submerged Old Wano / Mount Fuji Cavern",
			"encrypted_bearing_lat_deg": -12.0,
			"encrypted_bearing_lon_deg": -16.5,
			"lore_summary": "Preserved deep beneath Old Wano beside the sealed chamber of Ancient Weapon Pluton."
		},
		"road_poneglyph_4_elbaf": {
			"id": "road_poneglyph_4_elbaf",
			"category": "ROAD",
			"location_island_id": "elbaf",
			"title": "Road Poneglyph #4 — The Final Red Stone (Fish-Man Island Origin / Elbaf & Man Marked by Flame)",
			"encrypted_bearing_lat_deg": 12.0,
			"encrypted_bearing_lon_deg": 7.5,
			"lore_summary": "Originally stood beside Joy Boy's apology in the Sea Forest 25 years ago; relocated to Warland Elbaf under the guardianship of the Man Marked by Flame."
		}
	}

## Records a Poneglyph rubbing and, if the crew has an Archaeologist scholar (Ohara / Kozuki cipher),
## deciphers its coordinate or historical text. Automatically triangulates Laugh Tale when all 4 Road Poneglyphs are deciphered.
func decipher_poneglyph(poneglyph_id: String, has_archaeologist_crewmate: bool = true) -> Dictionary:
	if not poneglyph_database.has(poneglyph_id):
		return {"success": false, "reason": "Unknown Poneglyph ID"}
	if not has_archaeologist_crewmate:
		return {"success": false, "reason": "Requires an Archaeologist Crewmate (Ohara / Kozuki Script) to translate"}

	deciphered_poneglyph_ids[poneglyph_id] = true
	var entry: Dictionary = poneglyph_database[poneglyph_id]
	var road_count: int = get_deciphered_road_poneglyph_count()
	poneglyph_deciphered.emit(poneglyph_id, entry["category"], road_count)

	if road_count >= 4 and not laugh_tale_unlocked:
		_triangulate_and_spawn_laugh_tale()

	return {
		"success": true,
		"poneglyph_id": poneglyph_id,
		"category": entry["category"],
		"title": entry["title"],
		"road_poneglyphs_deciphered": road_count,
		"laugh_tale_unlocked": laugh_tale_unlocked,
		"laugh_tale_coordinates": laugh_tale_coordinates
	}

func get_deciphered_road_poneglyph_count() -> int:
	var count: int = 0
	for pid in ["road_poneglyph_1_zou", "road_poneglyph_2_whole_cake", "road_poneglyph_3_wano", "road_poneglyph_4_elbaf"]:
		if deciphered_poneglyph_ids.has(pid):
			count += 1
	return count

func _triangulate_and_spawn_laugh_tale() -> void:
	var rp1: Dictionary = poneglyph_database["road_poneglyph_1_zou"]
	var rp2: Dictionary = poneglyph_database["road_poneglyph_2_whole_cake"]
	var rp3: Dictionary = poneglyph_database["road_poneglyph_3_wano"]
	var rp4: Dictionary = poneglyph_database["road_poneglyph_4_elbaf"]

	var intersection: Dictionary = PlanetSphere.intersect_great_circle_arcs(
		float(rp1["encrypted_bearing_lat_deg"]), float(rp1["encrypted_bearing_lon_deg"]),
		float(rp2["encrypted_bearing_lat_deg"]), float(rp2["encrypted_bearing_lon_deg"]),
		float(rp3["encrypted_bearing_lat_deg"]), float(rp3["encrypted_bearing_lon_deg"]),
		float(rp4["encrypted_bearing_lat_deg"]), float(rp4["encrypted_bearing_lon_deg"])
	)
	if intersection.get("valid", false):
		laugh_tale_unlocked = true
		laugh_tale_coordinates = intersection
		register_island("laugh_tale", "grand_line", {
			"id": "laugh_tale",
			"name": "Laugh Tale (The Final Island — Rio Poneglyph & The One Piece)",
			"region": "grand_line",
			"lat_deg": intersection["lat_deg"],
			"lon_deg": intersection["lon_deg"],
			"alt_m": 0.0,
			"log_pose_lock_sec": 0.0,
			"danger_jitter_deg": 0.0,
			"currency": "Beli",
			"next_islands": [],
			"shops": [],
			"npcs": ["Echoes of Joy Boy & Gol D. Roger"]
		})
		laugh_tale_triangulated.emit(laugh_tale_coordinates)
