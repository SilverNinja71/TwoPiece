# south_blue_data.gd
# Production Data Module for Project "Blue Planet" (Godot 4.3+ precision=double)
# Sector: South Blue Region (theta in [-75.0 deg, -15.0 deg], phi in [0.0 deg, 90.0 deg])
# Planet Radius R = 16,000,000.0 meters. Player scale baseline = 2.0 meters.

class_name SouthBlueData
extends RefCounted

# ==============================================================================
# 1. PLANETARY CONSTANTS & SECTOR BOUNDS
# ==============================================================================
const PLANET_RADIUS: float = 16000000.0 # 16,000 km Sea-Level Radius (64-bit double precision)
const REGION_NAME: String = "South Blue"
const REGION_JAPANESE: String = "南の海 (サウスブルー)"
const SECTOR_LAT_MIN: float = -75.0 # Degrees Latitude (South)
const SECTOR_LAT_MAX: float = -15.0 # Degrees Latitude (Bordering South Calm Belt)
const SECTOR_LON_MIN: float = 0.0   # Degrees Longitude (Red Line / Reverse Mountain Meridian)
const SECTOR_LON_MAX: float = 90.0  # Degrees Longitude (Eastern Bound)

# Coordinates for the South Blue Entrance into the Reverse Mountain Hydraulic Canal
const REVERSE_MOUNTAIN_CANAL_ENTRY: Dictionary = {
	"name": "Reverse Mountain South Blue Canal Mouth",
	"coordinates": Vector2(-15.5, 1.2), # lat, lon in degrees
	"target_summit_coordinates": Vector2(0.0, 0.0),
	"summit_elevation_m": 5000.0,
	"hydraulic_current_speed_mps": 85.0, # ~306 km/h upward surge
	"canal_width_m": 400.0,
	"ascent_duration_sec": 380.0,
	"danger_level": "EXTREME",
	"required_hull_integrity": 1500.0
}

# Currency conversion baselines
const CURRENCY_CONVERSIONS: Dictionary = {
	"Beli": 1.0,
	"Extol": 0.0001,       # 10,000 Extol = 1 Beli
	"Gor": 50.0,           # 1 Amazon Lily Gor = 50 Beli
	"Wano_Silver_Ryo": 1000.0,
	"Wano_Gold_Ryo": 50000.0
}

# ==============================================================================
# 2. CANONICAL ISLAND REGISTRY (16 LOCATIONS)
# ==============================================================================
const ISLANDS: Dictionary = {
	"sorbet_kingdom": {
		"id": "sorbet_kingdom",
		"name": "Sorbet Kingdom",
		"japanese_name": "ソルベ王国",
		"affiliation": "World Government (Formerly Affiliated, Autonomous Post-Revolution)",
		"coordinates": Vector2(-32.5, 18.0),
		"altitude_m": 350.0,
		"radius_km": 140.0,
		"climate": "Temperate Maritime",
		"biome": "Coastal Forests, Popsicle Towers, Agricultural Plains",
		"lore_summary": "Homeland of Bartholomew Kuma, Ginny, and Jewelry Bonney. Site of King Bekori's oppressive segregation and Kuma's historic 'Solo Revolution'. Houses the peaceful Church of Sorbet where Kuma absorbed the ailments of the populace.",
		"historical_events": [
			"Reign of King Bekori and the burning of the Southern Province",
			"Bartholomew Kuma's Solo Revolution to overthrow Bekori",
			"Young Bonney's quarantine for Sapphire Scales disease",
			"CP8 surveillance under Agent Alpha and Bonney's sea escape with local fishermen",
			"Restoration of King Bulldog and Queen Dowager Conney"
		],
		"districts_and_ports": [
			{
				"district_id": "sorbet_royal_capital",
				"name": "Northern Royal Citadel",
				"type": "Capital City & Fortress",
				"description": "Ornate towers shaped like oversized popsicles overlooking paved plazas. Seat of King Bulldog.",
				"elevation_m": 120.0,
				"coordinates_offset": Vector2(0.12, 0.05)
			},
			{
				"district_id": "sorbet_church_sanctuary",
				"name": "Southern Church of Sorbet",
				"type": "Sacred Haven & Clinic",
				"description": "Weathered wooden church where Kuma lived as pastor. Contains a medical ward and bell tower.",
				"elevation_m": 45.0,
				"coordinates_offset": Vector2(-0.15, -0.08)
			},
			{
				"district_id": "gyogyo_fisher_wharf",
				"name": "Gyogyo's Fishing Wharf",
				"type": "Harbor & Market",
				"description": "Salt-crusted wooden wharves where local fishermen docked before joining the Bonney Pirates.",
				"elevation_m": 2.0,
				"coordinates_offset": Vector2(-0.22, 0.10)
			},
			{
				"district_id": "southern_rebuilt_province",
				"name": "Southern Commoners District",
				"type": "Residential Settlement",
				"description": "Vibrant working-class communities rebuilt by Kuma following Bekori's scorched-earth fires.",
				"elevation_m": 30.0,
				"coordinates_offset": Vector2(-0.05, -0.12)
			}
		],
		"shops_and_markets": [
			{
				"market_id": "sorbet_royal_bakery",
				"name": "Bonney's Hearthside Bakery & Pizzeria",
				"district": "sorbet_royal_capital",
				"shopkeeper_npc_id": "baker_michele",
				"description": "Famed brick-oven bakery producing thick pizzas and sweet citrus fruit tarts loved by royalty.",
				"inventory": [
					{
						"item_id": "bonney_brick_pizza",
						"name": "Sorbet Loaded Brick-Oven Pizza",
						"category": "Provisions",
						"price_beli": 480,
						"description": "Savory pizza dripping with melted sheep cheese and smoked bacon. Restores 350 HP and boosts stamina recovery by 20% for 15 mins."
					},
					{
						"item_id": "sorbet_citrus_glaze",
						"name": "Sorbet Orange-Glazed Pastry",
						"category": "Provisions",
						"price_beli": 220,
						"description": "Sweet citrus tart rich in Vitamin C. Cures minor scurvy and boosts sprint speed by 10% for 10 mins."
					}
				]
			},
			{
				"market_id": "church_alms_apothecary",
				"name": "Church Alms Dispensary",
				"district": "sorbet_church_sanctuary",
				"shopkeeper_npc_id": "pastor_aide_luke",
				"description": "Modest clinic counter dispensing herbal ointments and protective amulets founded in Kuma's memory.",
				"inventory": [
					{
						"item_id": "sapphire_balm",
						"name": "Blue Herb Sapphire Balm",
						"category": "Medicine",
						"price_beli": 1200,
						"description": "Potent skin ointment refined from local blue succulents. Alleviates degenerative dermal poisons and sun burns."
					},
					{
						"item_id": "church_prayer_bell",
						"name": "Sorbet Brass Prayer Bell",
						"category": "Curio",
						"price_beli": 850,
						"description": "A bell engraved with the Sun God motif. Calms crew morale during violent nighttime storms."
					},
					{
						"item_id": "kuma_bible_page",
						"name": "Illuminated Scripture Leaf",
						"category": "Lore Document",
						"price_beli": 3500,
						"description": "A preserved botanical parchment leaf from Kuma's traveling scriptures. Grants +5 Willpower when studied."
					}
				]
			},
			{
				"market_id": "gyogyo_salvage_coop",
				"name": "Southern Fishermen's Tackle & Salvage",
				"district": "gyogyo_fisher_wharf",
				"shopkeeper_npc_id": "old_man_mizore",
				"description": "Harborside store selling durable netting, diving harpoons, and salvaged Marine gear.",
				"inventory": [
					{
						"item_id": "pacifista_scrap_gear",
						"name": "Salvaged High-Tensile Cogwheel",
						"category": "Crafting Material",
						"price_beli": 5500,
						"description": "Heavy titanium-doped alloy gear salvaged from experimental World Government patrol wrecks."
					},
					{
						"item_id": "deep_current_net",
						"name": "South Sea Hemp Deep-Net",
						"category": "Naval Gear",
						"price_beli": 2400,
						"description": "Reinforced fishing net capable of catching 5-meter deep-sea tunas without tearing."
					}
				]
			}
		],
		"named_npcs": [
			{
				"npc_id": "queen_dowager_conney",
				"name": "Queen Dowager Conney",
				"title": "Queen Mother of Sorbet",
				"role": "Elder Monarch & Story Advisor",
				"affiliation": "Sorbet Monarchy",
				"location_district": "sorbet_royal_capital",
				"dialogue_hooks": [
					"Don't confuse me with that fiery young Bonney girl, though we share the same stubborn glare!",
					"Kuma gave his gentle soul so that this kingdom wouldn't be starved by the Celestial Dragons.",
					"If you sail toward the Red Line, keep your mouth shut about the Buccaneer bloodline."
				],
				"quest_prompts": [
					"Retrieve the royal ancestral silver locket misplaced in the burned archives of the old palace.",
					"Deliver emergency winter provisions to the elders residing in the Southern Commoners District."
				],
				"bounty_beli": 0,
				"combat_archetype": "Diplomat / Royal Elder"
			},
			{
				"npc_id": "king_bulldog",
				"name": "King Bulldog",
				"title": "Rightful Sovereign of Sorbet",
				"role": "King & Faction Leader",
				"affiliation": "Sorbet Monarchy",
				"location_district": "sorbet_royal_capital",
				"dialogue_hooks": [
					"We owe our restoration to Kuma's bravery. Bekori's wickedness nearly reduced Sorbet to ash.",
					"The World Government demands their Heavenly Tribute, but our people come first."
				],
				"quest_prompts": [
					"Patrol the southern coastline for unauthorized Cipher Pol infiltration cutters."
				],
				"bounty_beli": 0,
				"combat_archetype": "Heavy Guard Swordsman"
			},
			{
				"npc_id": "fisherman_gyogyo_elder",
				"name": "Gyogyo (Elder Brother)",
				"title": "Harbor Master & Bonney Pirate Contact",
				"role": "Dock Master & Smuggler",
				"affiliation": "Bonney Pirates sympathizer",
				"location_district": "gyogyo_fisher_wharf",
				"dialogue_hooks": [
					"Our young captain took to the sea with fire in her eyes to rescue her dad.",
					"If you're outfitting a schooner for Reverse Mountain, check your keel depth. The southern shelf is rocky."
				],
				"quest_prompts": [
					"Provide 10 units of South Sea Oak to repair the fishing fleet's storm-damaged piers."
				],
				"bounty_beli": 12000000,
				"combat_archetype": "Harpoon Brawler"
			}
		],
		"fauna_and_flora": [
			{
				"name": "Sorbet Golden Sturgeon",
				"type": "Fauna (Fish)",
				"rarity": "Uncommon",
				"description": "Large freshwater and estuarine fish valued for sweet caviar.",
				"harvest_yield": "2x Sturgeon Caviar (800 Beli)"
			},
			{
				"name": "Southern White Lily",
				"type": "Flora",
				"rarity": "Common",
				"description": "Fragrant white lily blooming across the church meadows.",
				"harvest_yield": "3x White Petals (120 Beli)"
			}
		],
		"exploration_hooks": [
			{
				"hook_id": "bekori_ruined_stronghold",
				"title": "Ruins of Fort Bekori",
				"coordinates_offset": Vector2(0.25, -0.18),
				"danger_rating": "Medium (Level 18)",
				"description": "Shattered stone battlements left from Kuma's Solo Revolution. Infested by rogue mercenaries.",
				"discovery_reward": "Hidden chest with 65,000 Beli and Bekori Royal Guard Armor"
			}
		],
		"docking_clearance": {
			"requirements": "Civilian or Merchant Flag; no active World Government Buster Call warrant",
			"dock_fee_beli": 1500,
			"marine_patrol_level": "Moderate"
		}
	},

	"baterilla": {
		"id": "baterilla",
		"name": "Baterilla",
		"japanese_name": "バテリラ",
		"affiliation": "Independent Island Community",
		"coordinates": Vector2(-24.0, 35.5),
		"altitude_m": 180.0,
		"radius_km": 95.0,
		"climate": "Tropical Paradise",
		"biome": "Hibiscus Groves, Coral Lagoons, White Sand Coves",
		"lore_summary": "Quiet tropical island where Gol D. Roger spent peaceful months before his execution. Home of Portgas D. Rouge, who held Portgas D. Ace in her womb for 20 months through pure maternal willpower. Marked by wild pink hibiscus flowers.",
		"historical_events": [
			"Gol D. Roger's secret visits and retirement with Rouge",
			"World Government and Cipher Pol's brutal 20-month island-wide newborn child hunts",
			"Birth of Portgas D. Ace and tragic passing of Portgas D. Rouge",
			"Monkey D. Garp's secret arrival to extract baby Ace to Dawn Island"
		],
		"districts_and_ports": [
			{
				"district_id": "baterilla_hibiscus_port",
				"name": "Hibiscus Port Harbor",
				"type": "Trading Port",
				"description": "Gentle harbor lined with wooden bungalows, fishing smacks, and palm-shaded taverns.",
				"elevation_m": 1.5,
				"coordinates_offset": Vector2(0.04, -0.06)
			},
			{
				"district_id": "rouge_secluded_cottage",
				"name": "Rouge's Memorial Grove & Cottage",
				"type": "Historical Sanctuary",
				"description": "Quiet coastal cottage surrounded by wild blooming pink hibiscus bushes. A peaceful shrine.",
				"elevation_m": 35.0,
				"coordinates_offset": Vector2(-0.08, 0.12)
			},
			{
				"district_id": "cp_old_watchtower",
				"name": "Abandoned Marine Observation Post",
				"type": "Military Relic",
				"description": "Overgrown stone watchtower used during the grim inquisitions 22 years ago.",
				"elevation_m": 110.0,
				"coordinates_offset": Vector2(0.15, 0.09)
			}
		],
		"shops_and_markets": [
			{
				"market_id": "baterilla_floral_exchange",
				"name": "Baterilla Island Flora & Dyes",
				"district": "baterilla_hibiscus_port",
				"shopkeeper_npc_id": "madame_florence",
				"description": "Aromatic boutique selling vibrant hibiscus extracts, fragrant oils, and hand-woven straw hats.",
				"inventory": [
					{
						"item_id": "south_blue_hibiscus",
						"name": "South Blue Pink Hibiscus",
						"category": "Flora & Accessory",
						"price_beli": 500,
						"description": "Iconic pink flower worn in Portgas D. Rouge's hair. Grants +10 Charm and slow passive morale regeneration."
					},
					{
						"item_id": "hibiscus_scarlet_dye",
						"name": "Baterilla Scarlet Sail Dye",
						"category": "Ship Customization",
						"price_beli": 7500,
						"description": "Vibrant permanent dye brewed from wild coastal blossoms. Grants ship sails weather resistance."
					},
					{
						"item_id": "rouge_will_amulet",
						"name": "Maternal Will Coral Amulet",
						"category": "Curio & Talisman",
						"price_beli": 12000,
						"description": "Hand-carved pendant infused with unyielding maternal spirit. Prevents lethal knockdown once per day (leaves 1 HP)."
					}
				]
			},
			{
				"market_id": "baterilla_sunset_inn",
				"name": "The King's Rest Tavern & Inn",
				"district": "baterilla_hibiscus_port",
				"shopkeeper_npc_id": "innkeeper_tobias",
				"description": "Cozy seaside tavern famous for spiced coconut rum and roasted reef snapper.",
				"inventory": [
					{
						"item_id": "roasted_reef_snapper",
						"name": "Grilled Coral Snapper",
						"category": "Provisions",
						"price_beli": 320,
						"description": "Fresh fish seasoned with sweet limes and chili. Restores 250 HP and cures fatigue."
					},
					{
						"item_id": "baterilla_coconut_rum",
						"name": "South Sea Spiced Coconut Rum",
						"category": "Beverage",
						"price_beli": 450,
						"description": "Smooth tropical rum favored by veteran sailors. Boosts crew musical performance by 15%."
					}
				]
			}
		],
		"named_npcs": [
			{
				"npc_id": "village_elder_nora",
				"name": "Elder Nora",
				"title": "Keeper of Baterilla Memories",
				"role": "Historian & Quest Giver",
				"affiliation": "Civilian",
				"location_district": "rouge_secluded_cottage",
				"dialogue_hooks": [
					"A child's laughter once echoed from this cove, shielded by a mother's miraculous love.",
					"The Marines tore this island inside-out looking for Roger's blood, but Rouge outwitted the entire world.",
					"Wear the pink flower proudly, child. It honors the bravest woman this sea ever knew."
				],
				"quest_prompts": [
					"Clear feral wild boars threatening the blooming hibiscus meadows around Rouge's cottage.",
					"Collect 5 samples of blooming coral lilies to place on the clifftop memorial."
				],
				"bounty_beli": 0,
				"combat_archetype": "Non-Combatant Elder"
			},
			{
				"npc_id": "retired_marine_garland",
				"name": "Warrant Officer Garland (Retired)",
				"title": "Penitent Veteran",
				"role": "Arms & Intel Vendor",
				"affiliation": "Ex-Marine",
				"location_district": "cp_old_watchtower",
				"dialogue_hooks": [
					"I was stationed here during the great sweep. It was no investigation; it was cruel paranoia.",
					"If you are heading for Reverse Mountain, watch for Cipher Pol cutters lurking off Centaurea."
				],
				"quest_prompts": [
					"Retrieve classified inquisition logs left inside the flooded cellar of the watchtower."
				],
				"bounty_beli": 0,
				"combat_archetype": "Flintlock Veteran Marksman"
			}
		],
		"fauna_and_flora": [
			{
				"name": "Baterilla Crested Dolphin",
				"type": "Fauna (Marine)",
				"rarity": "Common",
				"description": "Friendly dolphins that guide ships safely through the coral barrier reefs.",
				"harvest_yield": "Non-harvestable (Grants Navigation buff)"
			},
			{
				"name": "Pink South Blue Hibiscus",
				"type": "Flora",
				"rarity": "Common",
				"description": "Hearty, sweet-smelling tropical blossoms blooming year-round.",
				"harvest_yield": "4x Hibiscus Blossoms (160 Beli)"
			}
		],
		"exploration_hooks": [
			{
				"hook_id": "rouge_hidden_grotto",
				"title": "Secret Coral Grotto of the Will of D",
				"coordinates_offset": Vector2(-0.12, 0.16),
				"danger_rating": "Low (Level 12)",
				"description": "A secluded cavern accessible only during low tide, once used by Roger to dock his cutter.",
				"discovery_reward": "Ancient Oro Jackson Oak Timber Splinter and 40,000 Beli"
			}
		],
		"docking_clearance": {
			"requirements": "Open port, no military permits required",
			"dock_fee_beli": 800,
			"marine_patrol_level": "Low"
		}
	},

	"torino_kingdom": {
		"id": "torino_kingdom",
		"name": "Torino Kingdom",
		"japanese_name": "トリノ王国",
		"affiliation": "Independent Kingdom (Ancient Scholarly Tribe)",
		"coordinates": Vector2(-42.0, 58.0),
		"altitude_m": 1250.0, # Massive central tree summit
		"radius_km": 110.0,
		"climate": "Subtropical Primeval Canopy",
		"biome": "Colossal Ancient Tree, Canopy Nests, Giant Herb Groves",
		"lore_summary": "The 'Isle of Treasure' dominated by a titanic central tree reaching over 1,200m high. Inhabited by the giant, intelligent Masked Goayu (Tanagashima) birds and a peaceful tribe of rotund scholars led by Chief Shanba. Tony Tony Chopper's 2-year training ground during the timeskip.",
		"historical_events": [
			"Centuries-long conflict between the ground tribe and the giant canopy birds",
			"Arrival of Tony Tony Chopper via Bartholomew Kuma's Nikyu Nikyu repulsion",
			"Chopper brokering peace between humans and birds using medical translation",
			"Chopper's two-year botanical study in the ancient stone library developing new Rumble Balls"
		],
		"districts_and_ports": [
			{
				"district_id": "tree_of_life_canopy",
				"name": "Great Tree Canopy & Masked Goayu Nests",
				"type": "High-Altitude Bird Sanctuary",
				"description": "Gigantic woven branch walkways and bird nests perched 1,000m above ground level.",
				"elevation_m": 1100.0,
				"coordinates_offset": Vector2(0.00, 0.00)
			},
			{
				"district_id": "shanba_tribal_village",
				"name": "Shanba Tribal Settlement",
				"type": "Ground Village",
				"description": "Circular thatched stone huts built among colossal surface roots.",
				"elevation_m": 60.0,
				"coordinates_offset": Vector2(-0.06, -0.05)
			},
			{
				"district_id": "ancient_medical_library",
				"name": "Torino Great Stone Library",
				"type": "Ancient Botanical Archive",
				"description": "Monumental underground vault housing thousands of tomes on pharmacology and surgery.",
				"elevation_m": 85.0,
				"coordinates_offset": Vector2(0.08, -0.04)
			},
			{
				"district_id": "tanagashima_coastal_cove",
				"name": "South Root Beach & Anchor Cove",
				"type": "Natural Anchorage",
				"description": "Sheltered coastal cove where explorer ships moor among massive mossy buttress roots.",
				"elevation_m": 2.0,
				"coordinates_offset": Vector2(-0.14, 0.12)
			}
		],
		"shops_and_markets": [
			{
				"market_id": "torino_tribal_pharmacy",
				"name": "Shanba's Herbal & Botanical Dispensary",
				"district": "ancient_medical_library",
				"shopkeeper_npc_id": "chief_shanba",
				"description": "Vast dispensary stocked with rare curative roots, restorative fungal spores, and botanical formulas.",
				"inventory": [
					{
						"item_id": "rumble_ball_precursor",
						"name": "Torino Golden Root Essence",
						"category": "Alchemy & Medicine",
						"price_beli": 8500,
						"description": "Rare botanical extract used by Chopper to stabilize morphological transformations. Grants +30% Devil Fruit duration for 20 mins."
					},
					{
						"item_id": "torino_healing_spores",
						"name": "Canopy Bioluminescent Spores",
						"category": "Medicine",
						"price_beli": 1800,
						"description": "Antiseptic fungal powder that instantly stops heavy bleeding and restores 500 HP."
					},
					{
						"item_id": "ancient_medical_codex",
						"name": "Torino Botanical Compendium (Copy)",
						"category": "Skill Manual",
						"price_beli": 25000,
						"description": "Transcribed medical treatise containing 400 years of herbal remedies. Permanently increases Ship Doctor skill by +15."
					}
				]
			},
			{
				"market_id": "canopy_aviary_exchange",
				"name": "Masked Goayu Sky-Saddle Outpost",
				"district": "tree_of_life_canopy",
				"shopkeeper_npc_id": "bird_handler_goro",
				"description": "Canopy platform crafting sky-mount harnesses and down-feather aerial apparel.",
				"inventory": [
					{
						"item_id": "sky_mount_saddle",
						"name": "Masked Goayu Aerial Riding Saddle",
						"category": "Mount Gear",
						"price_beli": 45000,
						"description": "Sturdy leather harness designed to safely ride giant South Blue avians across high cloud layers."
					},
					{
						"item_id": "goayu_down_coat",
						"name": "Giant Bird Down Cold-Coat",
						"category": "Apparel",
						"price_beli": 9200,
						"description": "Super-lightweight insulated parkas capable of enduring sub-zero polar blizzards and high-altitude flight."
					},
					{
						"item_id": "masked_goayu_feather",
						"name": "Iridescent Goayu Flight Feather",
						"category": "Crafting Material",
						"price_beli": 3200,
						"description": "Huge 2-meter feather with aerodynamic oil coating. Used to craft high-efficiency aerodynamic ship gliders."
					}
				]
			}
		],
		"named_npcs": [
			{
				"npc_id": "chief_shanba",
				"name": "Chief Shanba",
				"title": "Head Scholar & Chieftain",
				"role": "Tribal Leader & Master Herbalist",
				"affiliation": "Torino Scholars",
				"location_district": "ancient_medical_library",
				"dialogue_hooks": [
					"We may dress in grass skirts, but our ancestors recorded the biology of this entire sea!",
					"The little tanuki doctor taught us that understanding heals deeper wounds than spears.",
					"The birds are our brothers now; mistreat them and you will find yourself cast from the canopy."
				],
				"quest_prompts": [
					"Climb to the +1,100m canopy to collect blooming Sun-Nectar Orchids from the highest bird nests.",
					"Synthesize 3 doses of Antidote Tonic for hatchlings suffering from root rot."
				],
				"bounty_beli": 0,
				"combat_archetype": "Botanical Alchemist / Tribal Shaman"
			},
			{
				"npc_id": "goayu_elder_bird",
				"name": "Matriarch Masked Goayu",
				"title": "Sovereign of the Canopy",
				"role": "Giant Aviary Guardian",
				"affiliation": "Masked Goayu Flock",
				"location_district": "tree_of_life_canopy",
				"dialogue_hooks": [
					"(The immense 15-meter bird lets out a melodious, thunderous trill that resonates in your chest.)",
					"(She nudges you gently with a beak capable of cracking ship timbers, indicating mutual trust.)"
				],
				"quest_prompts": [
					"Protect the canopy eggs from encroaching South Sea Wyverns."
				],
				"bounty_beli": 0,
				"combat_archetype": "Colossal Beast Guardian (HP: 18,000)"
			}
		],
		"fauna_and_flora": [
			{
				"name": "Masked Goayu (Tanagashima Bird)",
				"type": "Fauna (Colossal Aviary)",
				"rarity": "Legendary",
				"description": "Colossal birds with white plumage, dark facial plumage resembling a mask, and high intelligence.",
				"harvest_yield": "Goayu Down Feathers (Friendly shearing)"
			},
			{
				"name": "Torino Tree of Life Bark",
				"type": "Flora",
				"rarity": "Rare",
				"description": "Fibrous, resin-rich bark that repels insects and withstands sea acid.",
				"harvest_yield": "2x Resinous Bark (650 Beli)"
			}
		],
		"exploration_hooks": [
			{
				"hook_id": "deep_root_catacombs",
				"title": "Subterranean Root Labyrinth",
				"coordinates_offset": Vector2(0.04, -0.11),
				"danger_rating": "High (Level 28)",
				"description": "Twisting root tunnels beneath the island holding ancient South Blue Void Century pottery and overgrown medical stelae.",
				"discovery_reward": "Ancient Medical Scalpel (Meito grade tool) and 120,000 Beli"
			}
		],
		"docking_clearance": {
			"requirements": "Peaceful approach; weapons must be sheathed upon disembarking",
			"dock_fee_beli": 0,
			"marine_patrol_level": "None"
		}
	},

	"karate_island": {
		"id": "karate_island",
		"name": "Karate Island",
		"japanese_name": "カラテの島",
		"affiliation": "Independent Martial Confederacy",
		"coordinates": Vector2(-28.0, 48.0),
		"altitude_m": 480.0,
		"radius_km": 105.0,
		"climate": "Rugged Temperate",
		"biome": "Granite Peaks, Crashing Waterfalls, Stone Dojos",
		"lore_summary": "Renowned martial arts haven where bare-knuckle boxing and classical karate converge. Birthplace of Jerry (CP6), the tall boxing champion from the Puffing Tom. Thousands of disciples train under punishing waterfalls to temper their bodies into living steel.",
		"historical_events": [
			"Founding of the South Blue Hundred-Style Tournament",
			"Jerry's rise as Boxing Champion before recruitment into CP6",
			"Annual martial summit drawing brawlers and bounty hunters across the four seas"
		],
		"districts_and_ports": [
			{
				"district_id": "grand_karate_arena",
				"name": "Central Martial Amphitheater",
				"type": "Tournament Grounds",
				"description": "Colossal open-air stone ring surrounded by tiered spectator benches and training pillars.",
				"elevation_m": 120.0,
				"coordinates_offset": Vector2(0.00, 0.02)
			},
			{
				"district_id": "jerry_boxing_hall",
				"name": "South Blue Boxing Academy",
				"type": "Martial Gym",
				"description": "Rope rings, heavy sandbags, and leather gloves where Jerry honed his eccentric boxing style.",
				"elevation_m": 90.0,
				"coordinates_offset": Vector2(-0.06, 0.05)
			},
			{
				"district_id": "iron_body_waterfall",
				"name": "Ten-Thousand Ton Waterfall Shrine",
				"type": "Training Sanctuary",
				"description": "Thundering glacial runoff waterfalls where warriors practice Tekkai-adjacent breath control.",
				"elevation_m": 350.0,
				"coordinates_offset": Vector2(0.10, -0.08)
			},
			{
				"district_id": "brawler_dock_haven",
				"name": "Black Belt Pier",
				"type": "Harbor & Market",
				"description": "Bustling harbor filled with brawler sloops, training supply stalls, and meat rotisseries.",
				"elevation_m": 3.0,
				"coordinates_offset": Vector2(-0.12, -0.04)
			}
		],
		"shops_and_markets": [
			{
				"market_id": "black_belt_armory",
				"name": "Grandmaster's Martial Outfitters",
				"district": "grand_karate_arena",
				"shopkeeper_npc_id": "sensei_ryuzo",
				"description": "Dojo store offering woven martial belts, weighted gauntlets, and bone-strengthening ointments.",
				"inventory": [
					{
						"item_id": "black_belt_grips",
						"name": "Iron-Thread Black Belt Hand Wraps",
						"category": "Weapon / Gear",
						"price_beli": 4200,
						"description": "Dense martial wraps that increase unarmed strike damage by +18 and grant +10% blunt armor piercing."
					},
					{
						"item_id": "weighted_training_gi",
						"name": "100-Kilogram Lead-Lined Gi",
						"category": "Training Gear",
						"price_beli": 6800,
						"description": "Punishingly heavy training robe. Increases physical XP gain by 25% while reducing movement speed by 15%."
					},
					{
						"item_id": "jerry_spring_boots",
						"name": "Jerry's Long-Stilt Boxing Boots",
						"category": "Boots & Gear",
						"price_beli": 11500,
						"description": "Reinforced high-top boots inspired by Jerry's tall frame. Adds +2.0m jump height and increases kick knockback."
					},
					{
						"item_id": "iron_bone_liniment",
						"name": "Waterfall Tiger Herbal Liniment",
						"category": "Medicine",
						"price_beli": 950,
						"description": "Fiery rub that increases physical damage resistance by 15% for 12 minutes."
					}
				]
			},
			{
				"market_id": "brawler_meat_bazaar",
				"name": "Giant Boar Roastery & Ale",
				"district": "brawler_dock_haven",
				"shopkeeper_npc_id": "chef_gorobei",
				"description": "Massive smoking grills roasting whole island beasts to satisfy ravenous martial artists.",
				"inventory": [
					{
						"item_id": "karate_roast_shank",
						"name": "Glazed Mammoth Boar Shank",
						"category": "Provisions",
						"price_beli": 650,
						"description": "Enormous cut of protein-packed meat. Restores 600 HP and grants +10 Attack Power for 20 mins."
					}
				]
			}
		],
		"named_npcs": [
			{
				"npc_id": "grandmaster_dohyo",
				"name": "Grandmaster Dohyo",
				"title": "Dean of the Hundred-Style Dojo",
				"role": "Master Trainer & Sparring Partner",
				"affiliation": "Karate Island Council",
				"location_district": "grand_karate_arena",
				"dialogue_hooks": [
					"A punch without spirit is merely wind. Put your whole soul behind your fist!",
					"Jerry possessed formidable reach, but he allowed Cipher Pol to poison his discipline with arrogance.",
					"Face the waterfall for three hours, and we shall see if your stance can hold against the tide."
				],
				"quest_prompts": [
					"Defeat 5 reigning dojo champions in consecutive arena duels.",
					"Meditate beneath the Ten-Thousand Ton Waterfall for 120 seconds without falling."
				],
				"bounty_beli": 0,
				"combat_archetype": "Master Martial Artist (High HP / Tekkai Counters)"
			},
			{
				"npc_id": "sparring_boxer_max",
				"name": "Max 'Thunder-Jab'",
				"title": "Jerry's Former Sparring Partner",
				"role": "Boxing Coach & Gear Expert",
				"affiliation": "South Blue Boxing Union",
				"location_district": "jerry_boxing_hall",
				"dialogue_hooks": [
					"Jerry could jump clean over an elephant, but he never learned to guard his midsection!",
					"Keep your chin tucked, kid. The Grand Line will take your head clean off if you swing wild."
				],
				"quest_prompts": [
					"Deliver 5 sets of iron hand-wraps to the recruits training at the dock."
				],
				"bounty_beli": 3500000,
				"combat_archetype": "Fast Heavyweight Boxer"
			}
		],
		"fauna_and_flora": [
			{
				"name": "Granite Mountain Boar",
				"type": "Fauna (Beast)",
				"rarity": "Uncommon",
				"description": "Thick-hided boars that ram boulder formations; their tusks are hard as iron.",
				"harvest_yield": "Iron Boar Tusk (750 Beli) + Prime Boar Meat"
			}
		],
		"exploration_hooks": [
			{
				"hook_id": "fist_carved_peak",
				"title": "The God-Hand Precipice",
				"coordinates_offset": Vector2(0.18, -0.10),
				"danger_rating": "Medium (Level 22)",
				"description": "A sheer mountain peak carved into the shape of a clenched fist by legendary martial artists.",
				"discovery_reward": "Secret Scroll of Hasshoken Principles and 80,000 Beli"
			}
		],
		"docking_clearance": {
			"requirements": "Open dock; brawling on docks is legally permitted if kept outside taverns",
			"dock_fee_beli": 1200,
			"marine_patrol_level": "Low"
		}
	},

	"evil_black_drum": {
		"id": "evil_black_drum",
		"name": "Evil Black Drum Kingdom",
		"japanese_name": "悪ブラックドラム王国",
		"affiliation": "World Government (Re-Affiliated Sovereign State)",
		"coordinates": Vector2(-38.0, 72.0),
		"altitude_m": 620.0,
		"radius_km": 130.0,
		"climate": "Smoky Industrial / Volcanic Slag",
		"biome": "Drum-Shaped Iron Citadel, Smelting Slags, Mechanized Factories",
		"lore_summary": "The corporate-monarchical empire established in South Blue by King Wapol after losing Drum Island to Blackbeard and Luffy. Created via the invention of 'Wapometal' using the Baku Baku no Mi. Home of the massive Wapol Konzern toy conglomerate, Queen Kinderella, and the cyborg guard dog Hakowan.",
		"historical_events": [
			"Wapol's exile from Drum Island and discovery of Wapometal through trash-eating",
			"Founding of the Wapol Konzern toy manufacturing empire",
			"Marriage to Miss Universe Kinderella and recognition as King by the World Nobles",
			"Establishment of the Black Drum Fortress in South Blue",
			"Wapol's Levely appearance causing diplomatic incidents with Dalton and Vivi"
		],
		"districts_and_ports": [
			{
				"district_id": "black_drum_citadel",
				"name": "Wapol's Black Drum Castle",
				"type": "Royal Fortress",
				"description": "Grim castle shaped like an inverted iron snare drum with smoking cannon turrets.",
				"elevation_m": 580.0,
				"coordinates_offset": Vector2(0.00, 0.04)
			},
			{
				"district_id": "wapol_konzern_foundry",
				"name": "Wapol Konzern Mega-Foundry",
				"type": "Industrial Factory District",
				"description": "Hissing blast furnaces where scrap metal is combined with organic matter into Wapometal.",
				"elevation_m": 110.0,
				"coordinates_offset": Vector2(0.08, -0.06)
			},
			{
				"district_id": "kinderella_boulevard",
				"name": "Kinderella Golden Boulevard",
				"type": "Luxury Commercial District",
				"description": "Glittering shopping avenue filled with jewelry salons and haute couture boutiques.",
				"elevation_m": 45.0,
				"coordinates_offset": Vector2(-0.05, 0.08)
			},
			{
				"district_id": "tin_toy_wharf",
				"name": "Baku Baku Export Harbor",
				"type": "Industrial Shipping Port",
				"description": "Deep-water harbor loaded with container ships carrying tin toys and Wapometal alloys worldwide.",
				"elevation_m": 2.5,
				"coordinates_offset": Vector2(-0.16, -0.05)
			}
		],
		"shops_and_markets": [
			{
				"market_id": "wapometal_tech_exchange",
				"name": "Wapol Konzern Metallurgical Bureau",
				"district": "wapol_konzern_foundry",
				"shopkeeper_npc_id": "chief_metallurgist_kurt",
				"description": "Official dealership for authorized sales of shape-memory Wapometal ingots and heavy plates.",
				"inventory": [
					{
						"item_id": "wapometal_ingot",
						"name": "Pure Wapometal Ingot",
						"category": "Advanced Crafting Metal",
						"price_beli": 48000,
						"description": "Revolutionary shape-memory alloy invented by Wapol. Essential for Franky Shogun upgrades and high-durability ship armor."
					},
					{
						"item_id": "wapol_spring_cannon",
						"name": "Baku Baku Compact Spring Cannon",
						"category": "Ship Artillery",
						"price_beli": 85000,
						"description": "High-velocity mechanized deck gun utilizing Wapometal springs. High rate of fire with 1,200m effective range."
					},
					{
						"item_id": "tin_soldier_automaton",
						"name": "Wapol Konzern Wind-Up Soldier",
						"category": "Gadget / Decoy",
						"price_beli": 3500,
						"description": "Clockwork tin soldier that marches forward, distracting nearby enemies for 15 seconds."
					}
				]
			},
			{
				"market_id": "kinderella_boutique",
				"name": "Queen Kinderella's Haute Couture",
				"district": "kinderella_boulevard",
				"shopkeeper_npc_id": "couturier_celeste",
				"description": "Extravagant fashion boutique favored by nobles visiting from the Four Blues.",
				"inventory": [
					{
						"item_id": "kinderella_silk_gown",
						"name": "Miss Universe Diamond-Laced Cloak",
						"category": "Apparel",
						"price_beli": 32000,
						"description": "Dazzling silk garment that grants +25 Charisma in negotiations and discounts at noble markets."
					},
					{
						"item_id": "gold_plated_compact",
						"name": "Kinderella Mirror Compact",
						"category": "Curio",
						"price_beli": 5500,
						"description": "Mirror engraved with the Black Drum crest. Can signal allies over long distances in sunlight."
					}
				]
			}
		],
		"named_npcs": [
			{
				"npc_id": "king_wapol",
				"name": "King Wapol",
				"title": "CEO of Wapol Konzern & King of Evil Black Drum",
				"role": "Tyrannical Ruler & Corporate Mogul",
				"affiliation": "Evil Black Drum Monarchy",
				"location_district": "black_drum_citadel",
				"dialogue_hooks": [
					"Bwahahaha! Straw Hat thought he ruined me, but I became richer than five kingdoms put together!",
					"Wapometal is the future! Without my alloys, the World Government cannot even build their new weapons!",
					"Unless you've brought millions of Beli to invest in my Konzern, get out of my sight!"
				],
				"quest_prompts": [
					"Smuggle 20 tons of rare scrap titanium past Marine embargo cruisers into the blast foundry.",
					"Silence rogue whistleblowers in the slag slums who are leaking factory blueprints."
				],
				"bounty_beli": 0, # Protected by World Noble royal patent
				"combat_archetype": "Baku Baku Heavy Munch Brawler (Transforms into House Cannon)"
			},
			{
				"npc_id": "queen_kinderella",
				"name": "Queen Kinderella",
				"title": "Former Miss Universe & Queen Consort",
				"role": "Queen & Socialite",
				"affiliation": "Evil Black Drum Monarchy",
				"location_district": "kinderella_boulevard",
				"dialogue_hooks": [
					"Everything in this castle must sparkle! If it does not sparkle, Wapol will simply eat it!",
					"The Levely was terribly boring, though my diamond tiara completely outshone those Alabasta bumpkins."
				],
				"quest_prompts": [
					"Acquire 3 flawless South Sea Black Pearls from deep diving beds."
				],
				"bounty_beli": 0,
				"combat_archetype": "Non-Combatant Noble"
			},
			{
				"npc_id": "cyborg_hound_hakowan",
				"name": "Hakowan",
				"title": "Wapol's Modified Guard Hound",
				"role": "Cyborg Beast Companion",
				"affiliation": "Evil Black Drum Guard",
				"location_district": "black_drum_citadel",
				"dialogue_hooks": [
					"(Growls mechanically, metal jaws clicking with spring-loaded Wapometal teeth!)"
				],
				"quest_prompts": [],
				"bounty_beli": 0,
				"combat_archetype": "Mechanized Attack Hound (HP: 4,500)"
			}
		],
		"fauna_and_flora": [
			{
				"name": "Slag Scavenger Crow",
				"type": "Fauna (Avian)",
				"rarity": "Common",
				"description": "Hardy black birds with metallic beaks adapted to nesting near factory vents.",
				"harvest_yield": "Iron-Infused Beak (120 Beli)"
			}
		],
		"exploration_hooks": [
			{
				"hook_id": "secret_wapometal_lab",
				"title": "Forbidden R&D Testing Bunker",
				"coordinates_offset": Vector2(-0.09, -0.14),
				"danger_rating": "Very High (Level 34)",
				"description": "Underground research vault where Wapol's engineers conduct unstable fusion experiments on cybernetic automatons.",
				"discovery_reward": "Master Blueprint: Wapometal Ship Armor Keel and 250,000 Beli"
			}
		],
		"docking_clearance": {
			"requirements": "Strict customs clearance; must submit cargo manifest for Wapol Konzern tariff inspection",
			"dock_fee_beli": 5000,
			"marine_patrol_level": "Heavy (World Government Trade Protection)"
		}
	},

	"briss_kingdom": {
		"id": "briss_kingdom",
		"name": "Briss Kingdom",
		"japanese_name": "ブリス王国",
		"affiliation": "World Government Affiliated",
		"coordinates": Vector2(-55.0, 22.0),
		"altitude_m": 220.0,
		"radius_km": 115.0,
		"climate": "Cool Windswept Maritime",
		"biome": "Granite Cliffs, Ancient Shipyards, Antiquarian Museums",
		"lore_summary": "Ancient maritime kingdom famous for being the homeland of the 'St. Briss'—an exploration galleon that sailed into the Grand Line 208 years ago, rode the Knock Up Stream into Skypiea, and famously plunged from the clouds 200 years later near Jaya. Known for historical tooth-blackening cultural tar, trepanning skull arts, and high-altitude ship rigging.",
		"historical_events": [
			"Launch of the legendary exploratory vessel St. Briss 208 years ago",
			"The St. Briss's ascent into the White-White Sea via Knock Up Stream",
			"Robin's archaeological inspection of St. Briss skeletons in Jaya identifying South Blue teeth-tar",
			"Centuries of maritime research on high-altitude storm rigging"
		],
		"districts_and_ports": [
			{
				"district_id": "st_briss_drydocks",
				"name": "St. Briss Historical Naval Yards",
				"type": "Ancient Shipyard",
				"description": "Massive stone drydocks where monumental wooden exploration galleons have been built for three centuries.",
				"elevation_m": 8.0,
				"coordinates_offset": Vector2(-0.05, 0.08)
			},
			{
				"district_id": "antiquarian_museum_quarter",
				"name": "South Sea Antiquarian Quarter",
				"type": "Scholarly District",
				"description": "Cobblestone streets lined with natural history museums, skull reliquaries, and antique shops.",
				"elevation_m": 65.0,
				"coordinates_offset": Vector2(0.06, 0.02)
			},
			{
				"district_id": "high_rigging_academy",
				"name": "Storm-Sailor Rigging Guild",
				"type": "Naval Academy",
				"description": "Towering timber practice masts reaching 80 meters high where riggers train for violent atmospheric winds.",
				"elevation_m": 140.0,
				"coordinates_offset": Vector2(0.02, -0.09)
			}
		],
		"shops_and_markets": [
			{
				"market_id": "briss_historical_shipwrights",
				"name": "St. Briss Master Shipwright Guild",
				"district": "st_briss_drydocks",
				"shopkeeper_npc_id": "shipwright_harlan",
				"description": "Elite shipyard offering ancient hull designs, storm staysails, and knock-up shock absorbers.",
				"inventory": [
					{
						"item_id": "high_altitude_rigging",
						"name": "St. Briss Atmospheric Storm Rigging",
						"category": "Ship Component",
						"price_beli": 55000,
						"description": "Heavy-duty canvas and reinforced triple-braided halyards designed to withstand Knock Up Stream ascents."
					},
					{
						"item_id": "tooth_blackening_tar",
						"name": "Traditional South Sea Enamel Tar",
						"category": "Curio & Consumable",
						"price_beli": 750,
						"description": "Historical black pine tar used by 18th-century South Blue voyagers to preserve teeth from scurvy. Grants +15 Poison Resistance."
					},
					{
						"item_id": "trepanned_skull_relic",
						"name": "Antique Trepanning Surgical Kit",
						"category": "Medical Equipment",
						"price_beli": 8500,
						"description": "200-year-old steel instruments used by expedition doctors. Permanently increases Surgery success rate by +10%."
					}
				]
			}
		],
		"named_npcs": [
			{
				"npc_id": "historian_valerie",
				"name": "Curator Valerie",
				"title": "Director of the St. Briss Maritime Archive",
				"role": "Archaeologist & Quest Giver",
				"affiliation": "Briss Historical Society",
				"location_district": "antiquarian_museum_quarter",
				"dialogue_hooks": [
					"Our ancestors dared to believe that oceans existed above the clouds two hundred years ago!",
					"The ship that fell from the sky near Jaya bore our royal seal. The skeleton with black teeth was Captain Will.",
					"If you ever reach Skypiea, look for the carved name of our kingdom on the ruins of the White-White Sea."
				],
				"quest_prompts": [
					"Collect 4 antique bronze sextants lost at sea during the Great Gale of 1850.",
					"Locate the missing logbook volume detailing the original voyage of the St. Briss."
				],
				"bounty_beli": 0,
				"combat_archetype": "Non-Combatant Historian"
			}
		],
		"fauna_and_flora": [
			{
				"name": "Briss Cliff Osprey",
				"type": "Fauna (Avian)",
				"rarity": "Common",
				"description": "Keen-eyed raptors nesting on the shipyard cliffs that dive for deep ocean mackerel.",
				"harvest_yield": "Osprey Plume (180 Beli)"
			}
		],
		"exploration_hooks": [
			{
				"hook_id": "abandoned_sky_catapult",
				"title": "200-Year-Old Cloud Launch Ramp",
				"coordinates_offset": Vector2(0.14, 0.11),
				"danger_rating": "Medium (Level 20)",
				"description": "The moss-covered timber scaffolding where early explorers attempted to launch gliders into high-pressure cloud currents.",
				"discovery_reward": "Ancient High-Pressure Barometer and 90,000 Beli"
			}
		],
		"docking_clearance": {
			"requirements": "Civilian or Scholar clearance; standard harbor dues",
			"dock_fee_beli": 2000,
			"marine_patrol_level": "Moderate"
		}
	},

	"kutsukku_island": {
		"id": "kutsukku_island",
		"name": "Kutsukku Island",
		"japanese_name": "クツック島",
		"affiliation": "Lawless Outlaw Territory (Four Gangs Sector)",
		"coordinates": Vector2(-48.0, 38.0),
		"altitude_m": 150.0,
		"radius_km": 120.0,
		"climate": "Gloomy Temperate / Industrial Slums",
		"biome": "Scrap-Metal Yards, Gang Strongholds, Smuggler Wharves",
		"lore_summary": "The lawless, unaffiliated island where Eustass Kid, Killer, Heat, and Wire grew up leading rival youth gangs. Following the tragic murder of their childhood friend Victoria Shiruton Doruyanaika by the ruling syndicate, the four united, annihilated the criminal rulers, and set to sea as the Kid Pirates aboard the Victoria Punk.",
		"historical_events": [
			"Childhood feud and rivalry between the four district gangs (Kid, Killer, Heat, Wire)",
			"The Curry Udon incident involving Victoria Shiruton Doruyanaika",
			"Murder of Doruyanaika by the ruling underworld syndicate",
			"Kid's uprising: uniting the four gangs to butcher the island's overlords",
			"Construction and christening of the flagship Victoria Punk"
		],
		"districts_and_ports": [
			{
				"district_id": "kids_junkyard_citadel",
				"name": "Kid's Magnetic Scrapyard",
				"type": "Gang Fortress & Metal Yard",
				"description": "Mountains of rusted iron hulls, severed anchor chains, and electromagnets where Kid assembled his metal arms.",
				"elevation_m": 45.0,
				"coordinates_offset": Vector2(0.06, 0.05)
			},
			{
				"district_id": "killers_scythe_alley",
				"name": "Killer's Blade District",
				"type": "Industrial Slum & Forge",
				"description": "Narrow alleyways echoing with the screech of grinding wheels sharpening scythes and guillotine blades.",
				"elevation_m": 25.0,
				"coordinates_offset": Vector2(-0.08, 0.04)
			},
			{
				"district_id": "heats_furnace_quarter",
				"name": "Heat's Fire-Alley Precinct",
				"type": "Smelting Quarter",
				"description": "Smoke-choked foundries where molten iron flows and flamethrowers are forged.",
				"elevation_m": 35.0,
				"coordinates_offset": Vector2(0.04, -0.07)
			},
			{
				"district_id": "wires_snare_docks",
				"name": "Wire's Pitchfork Haven",
				"type": "Harbor & Gang Turf",
				"description": "Wharves draped in steel cables, barbed wire, and trident racks where ship cargo is extorted.",
				"elevation_m": 2.0,
				"coordinates_offset": Vector2(-0.09, -0.06)
			},
			{
				"district_id": "victoria_memorial_hill",
				"name": "Victoria Doruyanaika's Memorial Lookout",
				"type": "Memorial Shrine",
				"description": "Quiet grassy clifftop above the filth where Kid and Killer placed a solitary stone marker for Doruyanaika.",
				"elevation_m": 120.0,
				"coordinates_offset": Vector2(0.12, 0.10)
			}
		],
		"shops_and_markets": [
			{
				"market_id": "punk_scrap_forge",
				"name": "Victoria Punk Custom Ironworks",
				"district": "kids_junkyard_citadel",
				"shopkeeper_npc_id": "scrapsmith_vance",
				"description": "Heavy shipyard forge specializing in jagged iron ship plating, skull figureheads, and punk spikes.",
				"inventory": [
					{
						"item_id": "magnetic_junk_shards",
						"name": "High-Attraction Magnetic Scrap Cluster",
						"category": "Crafting & Weaponry",
						"price_beli": 12500,
						"description": "Super-conductive scrap iron clusters. Enhances magnetism abilities and crafts jagged shrapnel bombs."
					},
					{
						"item_id": "punk_rock_ram",
						"name": "Punk Rock Skull Battering Ram",
						"category": "Ship Weapon",
						"price_beli": 75000,
						"description": "Menacing steel dinosaur-skull ram modeled after the Victoria Punk. Deals triple damage on ship collisions."
					},
					{
						"item_id": "killer_scythe_whetstone",
						"name": "Dual-Scythe Diamond Whetstone",
						"category": "Tool",
						"price_beli": 4500,
						"description": "Precision sharpening stone that adds +20% Critical Hit rate to slashing blades for 30 minutes."
					},
					{
						"item_id": "anti_curry_udon_sign",
						"name": "'No Curry Udon' Brass Wall Sign",
						"category": "Curio & Souvenir",
						"price_beli": 1500,
						"description": "Humorous commemorative tavern plaque honoring Kid and Killer's eternal hatred of curry udon."
					}
				]
			}
		],
		"named_npcs": [
			{
				"npc_id": "gang_veteran_slash",
				"name": "Slash the Spike",
				"title": "Kid Gang Custodian",
				"role": "Gang Enforcer & Recruiter",
				"affiliation": "Kid Pirates Loyalist",
				"location_district": "kids_junkyard_citadel",
				"dialogue_hooks": [
					"Kid and Killer gutted every syndicate boss on this island after they touched Doruyanaika!",
					"If you look at our flag wrong, we'll turn your ribs into guitar strings and your hull into scrap!",
					"The Victoria Punk sailed from that pier straight for Reverse Mountain, and no Marine could stop her."
				],
				"quest_prompts": [
					"Raid rival syndicate holdouts hiding in the deep sewers and recover Kid's stolen electromagnet coils.",
					"Deliver fresh flowers to Doruyanaika's memorial marker on the northern hill."
				],
				"bounty_beli": 16000000,
				"combat_archetype": "Heavy Shrapnel Brawler"
			}
		],
		"fauna_and_flora": [
			{
				"name": "Junkyard Iron-Rat",
				"type": "Fauna (Rodent)",
				"rarity": "Common",
				"description": "Armored rodents with copper teeth that gnaw electrical wiring.",
				"harvest_yield": "Copper Tooth (80 Beli)"
			}
		],
		"exploration_hooks": [
			{
				"hook_id": "toppled_syndicate_manor",
				"title": "Crushed Syndicate Stronghold",
				"coordinates_offset": Vector2(-0.02, 0.11),
				"danger_rating": "High (Level 26)",
				"description": "The collapsed mansion where Kid and Killer slaughtered the old rulers. Still holds hidden vaults.",
				"discovery_reward": "Heavy Steel Spiked Gauntlet and 150,000 Beli"
			}
		],
		"docking_clearance": {
			"requirements": "Lawless port; enter at your own risk; pirate flag recommended to deter local street muggers",
			"dock_fee_beli": 0, # Extortion fee of 2000 Beli charged by local gang guards
			"marine_patrol_level": "None (Marines fear docking here)"
		}
	},

	"centaurea": {
		"id": "centaurea",
		"name": "Centaurea",
		"japanese_name": "センチュレア",
		"affiliation": "Revolutionary Army Liberated Nation",
		"coordinates": Vector2(-21.0, 12.0),
		"altitude_m": 290.0,
		"radius_km": 125.0,
		"climate": "Mediterranean / Warm Oceanic",
		"biome": "Stone Agoras, Olive Terraces, Liberated Fortresses",
		"lore_summary": "A once-militarized monarchy that was the site of a violent war between the government and the citizenry. The conflict was decisively won by the Revolutionary Army years prior to the current storyline, transforming Centaurea into a beacon of anti-World Government liberation in South Blue.",
		"historical_events": [
			"Royal exploitation and civil insurrection in Centaurea",
			"Intervention by the Revolutionary Army commanders to topple the monarchy",
			"Establishment of a democratic council allied with Monkey D. Dragon"
		],
		"districts_and_ports": [
			{
				"district_id": "liberated_agora",
				"name": "Central Freedom Agora",
				"type": "Civic Plaza & Assembly",
				"description": "Vibrant public forum where citizens deliberate laws and coordinate food distribution.",
				"elevation_m": 75.0,
				"coordinates_offset": Vector2(0.00, 0.03)
			},
			{
				"district_id": "revolutionary_command_haven",
				"name": "Dragon's Bastion (Covert Safehouse)",
				"type": "Revolutionary Base",
				"description": "Camouflaged stone garrison housing encrypted communications and logistics for South Blue cells.",
				"elevation_m": 160.0,
				"coordinates_offset": Vector2(-0.08, -0.06)
			},
			{
				"district_id": "centaurea_coop_harbor",
				"name": "Port Liberty",
				"type": "Harbor",
				"description": "Active merchant port welcoming autonomous trade vessels, free of Heavenly Tribute taxes.",
				"elevation_m": 2.0,
				"coordinates_offset": Vector2(0.10, 0.08)
			}
		],
		"shops_and_markets": [
			{
				"market_id": "revolutionary_cache_exchange",
				"name": "Centaurea People's Cooperative Supply",
				"district": "liberated_agora",
				"shopkeeper_npc_id": "quartermaster_nadia",
				"description": "Cooperative dispensary stocking surplus gear, olive oil, and covert revolutionary equipment.",
				"inventory": [
					{
						"item_id": "rev_army_cloak",
						"name": "Revolutionary Wind-Proof Cloak",
						"category": "Apparel",
						"price_beli": 4800,
						"description": "Heavy dark-green hooded traveling cloak that masks identity from low-level Marine scouts."
					},
					{
						"item_id": "encrypted_transponder_key",
						"name": "Encrypted White Den Den Mushi Receiver",
						"category": "Communications",
						"price_beli": 18000,
						"description": "Scrambler frequency device that intercepts Marine communications within a 50-mile radius."
					},
					{
						"item_id": "liberation_pamphlet",
						"name": "Dragon's Manifesto: Dawn of the World",
						"category": "Document",
						"price_beli": 150,
						"description": "Inspiring political treatise that permanently boosts crew loyalty and morale."
					}
				]
			}
		],
		"named_npcs": [
			{
				"npc_id": "commander_caspian",
				"name": "Commander Caspian",
				"title": "Revolutionary Army South Blue Logistics Officer",
				"role": "Regional Commander & Quest Giver",
				"affiliation": "Revolutionary Army",
				"location_district": "revolutionary_command_haven",
				"dialogue_hooks": [
					"Centaurea was the first stone to fall. One by one, every tributary slave-state will follow.",
					"The Marines have tightened patrols along the Reverse Mountain canal. If you carry contraband, stay off the direct meridian.",
					"Dragon watches all the four seas. Never surrender to the World Nobles' fear."
				],
				"quest_prompts": [
					"Intercept an incoming World Government tax convoy sailing near the South Calm Belt.",
					"Escort a liberated political refugee family safely to Baterilla."
				],
				"bounty_beli": 24000000,
				"combat_archetype": "Revolutionary Saboteur (Dual Pistols / Smoke Bombs)"
			}
		],
		"fauna_and_flora": [
			{
				"name": "Centaurea Mountain Dove",
				"type": "Fauna (Avian)",
				"rarity": "Common",
				"description": "Gentle white doves utilized by the Revolutionaries as carrier birds.",
				"harvest_yield": "Non-harvestable"
			}
		],
		"exploration_hooks": [
			{
				"hook_id": "old_royal_dungeon_vault",
				"title": "The Overthrown Tyrant's Subterranean Armory",
				"coordinates_offset": Vector2(-0.11, 0.09),
				"danger_rating": "Medium (Level 20)",
				"description": "Sealed vaults beneath the former royal fortress containing hoarded weapons and Beli.",
				"discovery_reward": "Officer Flintlock Rifle (Meito Tier 3) and 110,000 Beli"
			}
		],
		"docking_clearance": {
			"requirements": "World Government flags must be lowered upon entry; no Heavenly Tribute enforcement",
			"dock_fee_beli": 500,
			"marine_patrol_level": "None (Active Revolutionary Defense Fleet)"
		}
	},

	"tumi": {
		"id": "tumi",
		"name": "Tumi",
		"japanese_name": "ツミ",
		"affiliation": "Revolutionary Friendly Highland Nation",
		"coordinates": Vector2(-36.0, 28.0),
		"altitude_m": 720.0,
		"radius_km": 110.0,
		"climate": "Highland Alpine",
		"biome": "Terraced Valleys, Cold Mountain Rivers, Stone Villages",
		"lore_summary": "Mountainous South Blue country that experienced an uprising against royal despotism. Supported by Bartholomew Kuma and Revolutionary units following emergency distress requests, solidifying Kuma's reputation as a savior across the sea.",
		"historical_events": [
			"Highland workers' revolt against forced mining quotas",
			"Arrival of Bartholomew Kuma and Revolutionary reinforcements to relieve the rebel stronghold",
			"Liberation and signing of the Tumi Agrarian Pact"
		],
		"districts_and_ports": [
			{
				"district_id": "tumi_terrace_capital",
				"name": "Highland Terraced Council",
				"type": "Mountain Settlement",
				"description": "Multi-tiered stone villages carved into granite slopes, linked by suspension bridges.",
				"elevation_m": 680.0,
				"coordinates_offset": Vector2(0.02, 0.04)
			},
			{
				"district_id": "kuma_liberation_monument",
				"name": "Kuma's Paw-Print Lookout",
				"type": "Monument",
				"description": "A stone memorial overlooking the valley commemorating Kuma's protective barrier during the assault.",
				"elevation_m": 710.0,
				"coordinates_offset": Vector2(-0.05, 0.08)
			},
			{
				"district_id": "tumi_river_gorge_port",
				"name": "Gorge River Basin Port",
				"type": "River Port",
				"description": "Fjord-like river inlet where barges load alpine wool and mountain timber for export.",
				"elevation_m": 12.0,
				"coordinates_offset": Vector2(-0.12, -0.06)
			}
		],
		"shops_and_markets": [
			{
				"market_id": "tumi_alpine_apothecary",
				"name": "Tumi Highland Herbal & Wool Depot",
				"district": "tumi_terrace_capital",
				"shopkeeper_npc_id": "apothecary_silas",
				"description": "Alpine store selling frost-resistant mountain wool, herbal tonics, and climbing gear.",
				"inventory": [
					{
						"item_id": "tumi_highland_wool",
						"name": "Alpine Mountain Sheep Wool Coat",
						"category": "Apparel",
						"price_beli": 4200,
						"description": "Heavy water-resistant fleece that prevents stamina drain in freezing sea spray."
					},
					{
						"item_id": "tumi_arnica_salve",
						"name": "Tumi Highland Arnica Bruise Balm",
						"category": "Medicine",
						"price_beli": 850,
						"description": "Relieves bone fracture pain and accelerates stamina recovery by 30% for 15 mins."
					},
					{
						"item_id": "kuma_paw_coin",
						"name": "Commemorative Kuma Relief Medal",
						"category": "Curio",
						"price_beli": 2500,
						"description": "Silver coin stamped with a gentle bear paw. Shows allegiance to Kuma's memory."
					}
				]
			}
		],
		"named_npcs": [
			{
				"npc_id": "rebel_elder_bram",
				"name": "Elder Bram",
				"title": "Veteran of the Tumi Uprising",
				"role": "Village Elder & Storyteller",
				"affiliation": "Tumi Local Council",
				"location_district": "kuma_liberation_monument",
				"dialogue_hooks": [
					"When the royal cannons were shelling our children, Bartholomew Kuma stood in the gap and pushed the artillery shells clean back into the sky!",
					"The World Government called him a cruel tyrant, but here in Tumi, we call him an angel of mercy.",
					"Mind the high altitude winds; our rivers flow fast down to the sea."
				],
				"quest_prompts": [
					"Clear falling boulder debris blocking the high mountain aqueduct.",
					"Deliver medical herbs to the miners at the iron quarry."
				],
				"bounty_beli": 0,
				"combat_archetype": "Non-Combatant Elder"
			}
		],
		"fauna_and_flora": [
			{
				"name": "Tumi Highland Ibex",
				"type": "Fauna (Mammal)",
				"rarity": "Common",
				"description": "Agile horned goats leaping effortlessly along vertical granite cliffs.",
				"harvest_yield": "Ibex Horn (250 Beli) + Warm Fleece"
			}
		],
		"exploration_hooks": [
			{
				"hook_id": "kuma_deflection_crater",
				"title": "The Cannon-Buster Chasm",
				"coordinates_offset": Vector2(-0.09, 0.12),
				"danger_rating": "Low (Level 14)",
				"description": "The exact impact site where Kuma deflected a full royal bombardment into the mountain flank.",
				"discovery_reward": "Compressed Shockwave Crystal and 55,000 Beli"
			}
		],
		"docking_clearance": {
			"requirements": "Open river anchorage; small and medium vessels only due to gorge width",
			"dock_fee_beli": 600,
			"marine_patrol_level": "None"
		}
	},

	"roshwan_kingdom": {
		"id": "roshwan_kingdom",
		"name": "Roshwan Kingdom",
		"japanese_name": "ロシュワン王国",
		"affiliation": "World Government Affiliated",
		"coordinates": Vector2(-62.0, 45.0),
		"altitude_m": 310.0,
		"radius_km": 135.0,
		"climate": "Sub-Antarctic Glacial",
		"biome": "Ice-Covered Tundra, Onion-Domed Fortresses, Frosted Canals",
		"lore_summary": "World Government-affiliated kingdom in the chilly southern waters of South Blue. Ruled by King Beer VI and celebrated for the beautiful Matryo Princesses. Famous for heraldic sails bearing clinking beer tankards, frosted ice-stout brewing, and master Matryoshka doll woodcarvers.",
		"historical_events": [
			"Reign of King Beer VI and the royal succession of the Matryo Princesses",
			"Delegation to Mary Geoise for the Levely in a magnificent ship with beer-mug sails",
			"Diplomatic negotiations regarding South Blue fishing quotas"
		],
		"districts_and_ports": [
			{
				"district_id": "beer_vi_ice_citadel",
				"name": "Fortress of Beer VI",
				"type": "Royal Castle",
				"description": "Towering stone castle adorned with colorful onion domes and massive brass brewery chimneys.",
				"elevation_m": 280.0,
				"coordinates_offset": Vector2(0.00, 0.05)
			},
			{
				"district_id": "matryo_artisan_plaza",
				"name": "Matryoshka Guild Square",
				"type": "Crafts & Cultural Market",
				"description": "Vibrant snow-covered plaza where woodcarvers sculpt nesting dolls and winter pelts are traded.",
				"elevation_m": 85.0,
				"coordinates_offset": Vector2(-0.06, 0.02)
			},
			{
				"district_id": "clinking_tankard_port",
				"name": "The Frosted Tankard Harbor",
				"type": "Harbor & Brewery District",
				"description": "Icebreaker wharves lined with heated taverns and copper vats brewing famous Roshwan stout.",
				"elevation_m": 3.0,
				"coordinates_offset": Vector2(0.12, -0.07)
			}
		],
		"shops_and_markets": [
			{
				"market_id": "roshwan_imperial_brewery",
				"name": "King Beer VI's Imperial Brewery & Tavern",
				"district": "clinking_tankard_port",
				"shopkeeper_npc_id": "master_brewer_vladimir",
				"description": "Warm, boisterous tavern serving frosted dark ales, roast venison, and rye bread.",
				"inventory": [
					{
						"item_id": "roshwan_frosted_stout",
						"name": "Roshwan Frosted Imperial Stout (Keg)",
						"category": "Beverage & Provisions",
						"price_beli": 1800,
						"description": "Rich, warming dark beer. Completely removes Hypothermia debuffs and boosts crew melee damage by 15% for 20 mins."
					},
					{
						"item_id": "matryo_armor_doll",
						"name": "Carved Matryo Nesting Shield Doll",
						"category": "Curio & Armor",
						"price_beli": 7200,
						"description": "Finely carved nesting wooden figures that grant layered physical shielding against bludgeoning attacks."
					},
					{
						"item_id": "clinking_tankard_banner",
						"name": "Roshwan Heraldic Beer Sailcloth",
						"category": "Ship Customization",
						"price_beli": 12000,
						"description": "Festive sail bearing King Beer VI's clinking tankard insignia. Inspires friendly greetings from merchant ships."
					}
				]
			}
		],
		"named_npcs": [
			{
				"npc_id": "king_beer_vi",
				"name": "King Beer VI",
				"title": "Sovereign of Roshwan",
				"role": "Monarch & Levely Delegate",
				"affiliation": "World Government (Roshwan Monarchy)",
				"location_district": "beer_vi_ice_citadel",
				"dialogue_hooks": [
					"A hearty toast to our frosty South Blue! If a man cannot drink a keg of our stout, he is no true captain!",
					"My lovely daughters, the Matryo Princesses, represent the elegance of our frozen kingdom at the Levely.",
					"The World Nobles drink champagne, but they know nothing of good South Sea beer!"
				],
				"quest_prompts": [
					"Retrieve a stolen cask of Century Reserve Stout captured by rogue ice-pirates."
				],
				"bounty_beli": 0,
				"combat_archetype": "Heavy Royal Brawler (Keg Swinger)"
			},
			{
				"npc_id": "princess_matryo_eldest",
				"name": "Princess Matryo (Eldest)",
				"title": "Crown Princess of Roshwan",
				"role": "Diplomat & Artisan Patron",
				"affiliation": "Roshwan Monarchy",
				"location_district": "matryo_artisan_plaza",
				"dialogue_hooks": [
					"Our nesting dolls hold a secret: inside the final wooden heart is an ancient prayer for safe voyage.",
					"Do not let the winter chill freeze your compass needle."
				],
				"quest_prompts": [
					"Deliver a set of handcrafted royal Matryoshka dolls to Queen Dowager Conney of Sorbet."
				],
				"bounty_beli": 0,
				"combat_archetype": "Non-Combatant Princess"
			}
		],
		"fauna_and_flora": [
			{
				"name": "Roshwan White Polar Bear",
				"type": "Fauna (Mammal)",
				"rarity": "Uncommon",
				"description": "Gigantic, furry white bears roaming coastal ice shelves, capable of swimming 50 miles.",
				"harvest_yield": "Warm White Bear Fur (1,200 Beli)"
			}
		],
		"exploration_hooks": [
			{
				"hook_id": "frozen_ice_cavern_vault",
				"title": "Glacial Beer Cellar of the First King",
				"coordinates_offset": Vector2(0.14, 0.09),
				"danger_rating": "Medium (Level 22)",
				"description": "Ancient subterranean glacier storage holding 300-year-old preserved liquors and ancestral armor.",
				"discovery_reward": "King's Golden Tankard Relic and 100,000 Beli"
			}
		],
		"docking_clearance": {
			"requirements": "World Government vessel or licensed trader; icebreaker hull recommended in winter months",
			"dock_fee_beli": 2500,
			"marine_patrol_level": "Moderate"
		}
	},

	"samba_kingdom": {
		"id": "samba_kingdom",
		"name": "Samba Kingdom",
		"japanese_name": "サンバ王国",
		"affiliation": "World Government Affiliated",
		"coordinates": Vector2(-18.5, 65.0),
		"altitude_m": 160.0,
		"radius_km": 110.0,
		"climate": "Vibrant Tropical / Equatorial",
		"biome": "Carnival Boulevards, Palm-Fringed Shores, Coral Plazas",
		"lore_summary": "World Government-affiliated kingdom celebrated for its year-round musical carnivals, rhythmic capoeira martial arts, brass horn artisans, and festive maritime culture. Ruled by King Moqueca, a joyful delegate at the Levely.",
		"historical_events": [
			"Annual Great South Blue Carnival celebration",
			"King Moqueca's Levely participation representing the musical nations of South Blue",
			"Cultural exchange with the floating restaurant Baratie in East Blue"
		],
		"districts_and_ports": [
			{
				"district_id": "carnival_esplanade",
				"name": "Grand Carnival Boulevard",
				"type": "Civic & Festival Street",
				"description": "Colorful avenue filled with dancing masqueraders, steel drums, and tropical fruit stalls.",
				"elevation_m": 15.0,
				"coordinates_offset": Vector2(0.00, 0.03)
			},
			{
				"district_id": "moqueca_sun_palace",
				"name": "Sun Palace of King Moqueca",
				"type": "Monarchical Residence",
				"description": "Open-air golden palace filled with fountains, musical gardens, and banquet halls.",
				"elevation_m": 120.0,
				"coordinates_offset": Vector2(-0.05, -0.06)
			},
			{
				"district_id": "brass_horn_haven",
				"name": "Harbor of the Trumpets",
				"type": "Harbor & Artisan District",
				"description": "Harbor where docking ships are greeted by orchestral brass fanfares from waterfront balconies.",
				"elevation_m": 2.0,
				"coordinates_offset": Vector2(0.08, 0.05)
			}
		],
		"shops_and_markets": [
			{
				"market_id": "samba_carnival_bazaar",
				"name": "Moqueca's Brass & Spice Emporium",
				"district": "carnival_esplanade",
				"shopkeeper_npc_id": "maestro_orlando",
				"description": "Rhythmic market selling brass instruments, feather carnival costumes, and coconut seafood stew.",
				"inventory": [
					{
						"item_id": "brass_samba_trumpet",
						"name": "Handcrafted Samba Brass Trumpet",
						"category": "Musical Instrument",
						"price_beli": 8500,
						"description": "Polished horn with vibrant acoustic resonance. Playing songs on deck boosts crew sailing speed by 10%."
					},
					{
						"item_id": "moqueca_seafood_stew",
						"name": "King Moqueca's Coconut Palm Stew",
						"category": "Provisions",
						"price_beli": 550,
						"description": "Rich seafood stew cooked in coconut milk and dende oil. Restores 400 HP and grants high thermal resistance."
					},
					{
						"item_id": "carnival_feather_crown",
						"name": "Vibrant Macaw Feather Headdress",
						"category": "Apparel",
						"price_beli": 3200,
						"description": "Dazzling parade headdress that boosts movement speed and dodging agility by +12%."
					}
				]
			}
		],
		"named_npcs": [
			{
				"npc_id": "king_moqueca",
				"name": "King Moqueca",
				"title": "Sovereign of Samba",
				"role": "Monarch & Levely Representative",
				"affiliation": "World Government (Samba Monarchy)",
				"location_district": "moqueca_sun_palace",
				"dialogue_hooks": [
					"A kingdom without rhythm is a kingdom without a heartbeat! Dance, my friends!",
					"At the Levely, everyone is so tense and grim! A good drumbeat would solve half the world's wars!",
					"Sail safely through the South Calm Belt border. The Sea Kings sleep soundly if you play gentle melodies."
				],
				"quest_prompts": [
					"Procure 10 resonant coral pearls from the offshore reefs to craft royal maracas."
				],
				"bounty_beli": 0,
				"combat_archetype": "Rhythmic Capoeira Brawler"
			}
		],
		"fauna_and_flora": [
			{
				"name": "South Sea Rainbow Macaw",
				"type": "Fauna (Avian)",
				"rarity": "Common",
				"description": "Brilliantly feathered parrots that imitate human singing.",
				"harvest_yield": "Rainbow Feather (150 Beli)"
			}
		],
		"exploration_hooks": [
			{
				"hook_id": "rhythm_sea_caves",
				"title": "Acoustic Whispering Sea Caves",
				"coordinates_offset": Vector2(0.12, -0.08),
				"danger_rating": "Low (Level 12)",
				"description": "Tidal caves that resonate like giant organs when the ocean swell rushes inside.",
				"discovery_reward": "Resonant Tone Shell and 45,000 Beli"
			}
		],
		"docking_clearance": {
			"requirements": "Open carnival port; visiting ships must fire a three-note musical whistle upon docking",
			"dock_fee_beli": 1000,
			"marine_patrol_level": "Low"
		}
	},

	"taya_kingdom": {
		"id": "taya_kingdom",
		"name": "Taya Kingdom",
		"japanese_name": "タヤ王国",
		"affiliation": "World Government Affiliated",
		"coordinates": Vector2(-29.0, 82.0),
		"altitude_m": 410.0,
		"radius_km": 115.0,
		"climate": "Subtropical Bamboo Forest",
		"biome": "Dense Bamboo Groves, Serene Shrines, Constabulary Forts",
		"lore_summary": "World Government-affiliated nation noted as the homeland and former workplace of Marine Admiral Aramaki (Ryokugyu), who served as a strict local police officer here before being imprisoned and later conscripted via the World Military Draft.",
		"historical_events": [
			"Aramaki's service as a local police officer in Taya Kingdom",
			"Aramaki's subsequent arrest and imprisonment for disciplinary defiance",
			"The World Military Draft recruiting Ryokugyu directly from penal custody into the Marines as Admiral"
		],
		"districts_and_ports": [
			{
				"district_id": "taya_constabulary_precinct",
				"name": "Old Central Constabulary Headquarters",
				"type": "Police Barracks",
				"description": "Strict stone fortress where the kingdom's gendarmes and former officer Aramaki were stationed.",
				"elevation_m": 140.0,
				"coordinates_offset": Vector2(0.02, 0.04)
			},
			{
				"district_id": "emerald_bamboo_sanctuary",
				"name": "Forest of Ten Thousand Bamboos",
				"type": "Natural Forest",
				"description": "Endless groves of towering bamboo stalks reaching 30 meters high with sunlight filtering through.",
				"elevation_m": 220.0,
				"coordinates_offset": Vector2(-0.06, -0.05)
			},
			{
				"district_id": "taya_river_dock",
				"name": "Bamboo Basin Port",
				"type": "Harbor",
				"description": "Quiet harbor handling timber barges and bamboo fiber export caravels.",
				"elevation_m": 3.0,
				"coordinates_offset": Vector2(0.09, -0.07)
			}
		],
		"shops_and_markets": [
			{
				"market_id": "taya_bamboo_forge",
				"name": "Taya Armory & Bamboo Craft Works",
				"district": "taya_constabulary_precinct",
				"shopkeeper_npc_id": "constable_inspector_kenji",
				"description": "Armory selling hardened bamboo bokken, police staves, and woven armor.",
				"inventory": [
					{
						"item_id": "hardened_bamboo_bokken",
						"name": "Iron-Bamboo Practice Bokken",
						"category": "Weapon",
						"price_beli": 3800,
						"description": "Lacquered bamboo training sword that never splinters. Deals high stun damage without lethal injury."
					},
					{
						"item_id": "taya_police_badge",
						"name": "Taya Gendarme Brass Shield Badge",
						"category": "Accessory",
						"price_beli": 2400,
						"description": "Official badge once worn by Aramaki's unit. Grants minor authority when dealing with local officials."
					},
					{
						"item_id": "photosynthesis_herbal_brew",
						"name": "Sun-Soaked Green Chlorophyll Tonic",
						"category": "Medicine",
						"price_beli": 1200,
						"description": "Nutrient brew inspired by Ryokugyu's ability to live without eating. Regenerates stamina in direct sunlight."
					}
				]
			}
		],
		"named_npcs": [
			{
				"npc_id": "chief_inspector_gentatsu",
				"name": "Chief Inspector Gentatsu",
				"title": "Director of Taya Constabulary",
				"role": "Law Enforcement Head",
				"affiliation": "Taya Kingdom Government",
				"location_district": "taya_constabulary_precinct",
				"dialogue_hooks": [
					"Aramaki was the most relentless officer this force ever saw—and the most dangerous rogue.",
					"He spent three years in our deepest cell refusing food, yet walked out stronger than an ox when the Marines drafted him.",
					"Do not disturb the peace in our bamboo forests; justice here is swift and uncompromising."
				],
				"quest_prompts": [
					"Track down escaped convicts hiding in the dense bamboo thickets."
				],
				"bounty_beli": 0,
				"combat_archetype": "Master Jitte Swordsman"
			}
		],
		"fauna_and_flora": [
			{
				"name": "Iron Bamboo",
				"type": "Flora",
				"rarity": "Common",
				"description": "Extremely fast-growing bamboo species with tensile strength matching mild steel.",
				"harvest_yield": "Iron Bamboo Stalk (140 Beli)"
			}
		],
		"exploration_hooks": [
			{
				"hook_id": "aramakis_sealed_cell",
				"title": "The Fasting Dungeon of the Green Bull",
				"coordinates_offset": Vector2(0.05, 0.08),
				"danger_rating": "Medium (Level 18)",
				"description": "The underground cell where Aramaki was imprisoned. Strange floral tendrils and petrified roots still burst through the floor.",
				"discovery_reward": "Petrified Wood Shard of Photosynthesis and 70,000 Beli"
			}
		],
		"docking_clearance": {
			"requirements": "Vessel inspection by Constabulary patrols; registration required",
			"dock_fee_beli": 1500,
			"marine_patrol_level": "Heavy"
		}
	},

	"vespa_kingdom": {
		"id": "vespa_kingdom",
		"name": "Vespa Kingdom",
		"japanese_name": "ヴェスパ王国",
		"affiliation": "World Government Affiliated",
		"coordinates": Vector2(-68.0, 15.0),
		"altitude_m": 260.0,
		"radius_km": 125.0,
		"climate": "Polar Windswept Maritime",
		"biome": "Glacial Fjords, Frozen Canals, Stone Fishing Lodges",
		"lore_summary": "Sub-polar nation in the far southern reaches of South Blue, known as the birthplace and early home of former Marine Admiral Kuzan (Aokiji). Characterized by coastal bicycle paths along frozen seawalls, ice-breaker smacks, seal wool weaving, and chilled seafaring taverns.",
		"historical_events": [
			"Birth and early childhood of Kuzan (Aokiji)",
			"Kuzan's departure to join the Marines under Instructor Zephyr",
			"Preservation of Kuzan's familial roots and coastal cycling traditions"
		],
		"districts_and_ports": [
			{
				"district_id": "kuzan_birthplace_cove",
				"name": "Blue Pheasant Coastal Cove",
				"type": "Historical Hamlet",
				"description": "Snowy fishing village where young Kuzan watched passing icebergs and learned to ride his bicycle.",
				"elevation_m": 25.0,
				"coordinates_offset": Vector2(-0.06, 0.05)
			},
			{
				"district_id": "glacial_fjord_harbor",
				"name": "Vespa Ice-Fjord Port",
				"type": "Deep Ice Harbor",
				"description": "Sheltered deep-water harbor equipped with heavy steam-driven icebreakers.",
				"elevation_m": 2.0,
				"coordinates_offset": Vector2(0.08, -0.04)
			},
			{
				"district_id": "frozen_canal_market",
				"name": "The Glacial Promenade",
				"type": "Marketplace",
				"description": "Canals frozen solid into natural ice-skating boulevards lined with dried fish stalls.",
				"elevation_m": 15.0,
				"coordinates_offset": Vector2(0.01, 0.07)
			}
		],
		"shops_and_markets": [
			{
				"market_id": "vespa_fjord_outfitters",
				"name": "Vespa Polar Outfitters & Bicycle Shop",
				"district": "frozen_canal_market",
				"shopkeeper_npc_id": "mechanic_oskar",
				"description": "Workshop specializing in amphibious sea-bicycles, ice crampons, and sleep masks.",
				"inventory": [
					{
						"item_id": "kuzan_sleep_mask",
						"name": "Kuzan's 'Lazy Justice' Silk Sleep Mask",
						"category": "Apparel & Curio",
						"price_beli": 2800,
						"description": "Soft eye mask modeled after Kuzan's trademark gear. Triples resting HP recovery while asleep on ship deck."
					},
					{
						"item_id": "amphibious_sea_bicycle",
						"name": "Aokiji-Pattern Amphibious Cruiser Bicycle",
						"category": "Vehicle / Mount",
						"price_beli": 65000,
						"description": "Pedal-powered cruiser equipped with outrigger pontoons. Allows traveling across flat ice and calm water."
					},
					{
						"item_id": "glacial_sea_trout",
						"name": "Smoked Vespa Glacial Trout",
						"category": "Provisions",
						"price_beli": 350,
						"description": "Cured arctic fish packed with omega oils. Cures fatigue and restores 280 HP."
					}
				]
			}
		],
		"named_npcs": [
			{
				"npc_id": "fisherman_torkel",
				"name": "Old Man Torkel",
				"title": "Kuzan's Childhood Neighbor",
				"role": "Village Historian & Ice Fisher",
				"affiliation": "Civilian",
				"location_district": "kuzan_birthplace_cove",
				"dialogue_hooks": [
					"Young Kuzan was always lying on the grass staring at the clouds, muttering about 'unhurried justice'.",
					"He rode his bicycle clear across the frozen bay when he was just ten years old!",
					"The sea down here will freeze your blood if you fall in without a wool coat. Keep your hearth fires burning."
				],
				"quest_prompts": [
					"Catch 3 Glacial King Trouts from the deep fjord ice holes.",
					"Rescue a stranded sea-cyclist caught on a drifting ice floe."
				],
				"bounty_beli": 0,
				"combat_archetype": "Hardy Harpooner"
			}
		],
		"fauna_and_flora": [
			{
				"name": "Vespa Frost Seal",
				"type": "Fauna (Marine)",
				"rarity": "Common",
				"description": "Playful seals that sunbathe on ice floes, barking cheerfully at passing ships.",
				"harvest_yield": "Non-harvestable"
			}
		],
		"exploration_hooks": [
			{
				"hook_id": "ice_shelf_crystal_cave",
				"title": "Cryo-Glacial Crystal Cavern",
				"coordinates_offset": Vector2(-0.12, -0.09),
				"danger_rating": "Medium (Level 24)",
				"description": "Natural ice cave glittering with perpetual glacial frost and frozen prehistoric fossils.",
				"discovery_reward": "Ever-Ice Crystal (Never melts) and 85,000 Beli"
			}
		],
		"docking_clearance": {
			"requirements": "Icebreaker hull or reinforced bows recommended; open harbor",
			"dock_fee_beli": 1200,
			"marine_patrol_level": "Moderate"
		}
	},

	"samuwanai_island": {
		"id": "samuwanai_island",
		"name": "Samuwanai Island",
		"japanese_name": "サムワナイ島",
		"affiliation": "Independent Geothermal Community",
		"coordinates": Vector2(-71.5, 55.0),
		"altitude_m": 380.0,
		"radius_km": 85.0,
		"climate": "Geothermal Volcanic in Sub-Polar Seas",
		"biome": "Steaming Sulfur Springs, Volcanic Calderas, Hot Spring Inns",
		"lore_summary": "The 'Never Cold' island in the deep sub-polar waters of South Blue. Homeland of Ida. Despite floating among ice floes and freezing southern blizzards, intense underground volcanic fissures heat the island into a paradise of natural steaming bathhouses and rich sulfur mud.",
		"historical_events": [
			"Birth and upbringing of Ida",
			"Discovery of the Great Geothermal Caldera warming the island ecosystem",
			"Development of the South Blue Hot Spring Sanitarium"
		],
		"districts_and_ports": [
			{
				"district_id": "ida_hot_spring_village",
				"name": "Steaming Hearth Village",
				"type": "Thermal Spa Town",
				"description": "Rustic wooden village enveloped in swirling warm volcanic mist with steaming cedar hot tubs.",
				"elevation_m": 90.0,
				"coordinates_offset": Vector2(0.01, 0.03)
			},
			{
				"district_id": "geyser_basin",
				"name": "The Great Geyser Valley",
				"type": "Volcanic Basin",
				"description": "Crater field with erupting boiling sulfur geysers shooting 50 meters into the icy air.",
				"elevation_m": 240.0,
				"coordinates_offset": Vector2(-0.05, -0.04)
			},
			{
				"district_id": "thermal_steam_wharf",
				"name": "Warm Water Harbor",
				"type": "Ice-Free Port",
				"description": "Geothermally warmed bay where ice instantly melts, providing safe year-round docking.",
				"elevation_m": 2.0,
				"coordinates_offset": Vector2(0.07, 0.06)
			}
		],
		"shops_and_markets": [
			{
				"market_id": "samuwanai_thermal_bazaar",
				"name": "Ida's Mineral Springs & Mud Depot",
				"district": "ida_hot_spring_village",
				"shopkeeper_npc_id": "innkeeper_ida_relative",
				"description": "Bathhouse store selling therapeutic sulfur salts, geyser-boiled black eggs, and cedar buckets.",
				"inventory": [
					{
						"item_id": "samuwanai_bath_salt",
						"name": "Never-Cold Geothermal Bath Salts",
						"category": "Consumable",
						"price_beli": 650,
						"description": "Mineral salts that grant 24 hours of total immunity to environmental cold and freezing status effects."
					},
					{
						"item_id": "geyser_black_egg",
						"name": "Sulfur-Steamed Volcanic Black Egg",
						"category": "Provisions",
						"price_beli": 180,
						"description": "Nutrient-rich egg boiled in natural volcanic springs. Legend says each egg adds 7 years of vitality (restores 200 HP)."
					},
					{
						"item_id": "volcanic_mud_pack",
						"name": "Samuwanai Healing Sulfur Mud",
						"category": "Medicine",
						"price_beli": 900,
						"description": "Cleanses skin burns, poisons, and restores 350 HP with high soothing mineral action."
					}
				]
			}
		],
		"named_npcs": [
			{
				"npc_id": "bathmaster_tomi",
				"name": "Bathmaster Tomi",
				"title": "Curator of the Sacred Springs",
				"role": "Healer & Hot Spring Host",
				"affiliation": "Samuwanai Spa Guild",
				"location_district": "ida_hot_spring_village",
				"dialogue_hooks": [
					"Out there, the blizzards howl, but here in Samuwanai, nobody ever catches a cold!",
					"Ida always loved bathing under the stars while icebergs drifted past the bay.",
					"Rest your tired bones in the sulfur bath. The Grand Line requires a rested spirit."
				],
				"quest_prompts": [
					"Check the pressure valves on the steam vents in the Geyser Valley to prevent a dangerous explosion."
				],
				"bounty_beli": 0,
				"combat_archetype": "Non-Combatant Host"
			}
		],
		"fauna_and_flora": [
			{
				"name": "Geothermal Steam Crab",
				"type": "Fauna (Crustacean)",
				"rarity": "Common",
				"description": "Bright red crabs thriving in boiling volcanic runoff channels.",
				"harvest_yield": "Steam Crab Meat (220 Beli)"
			}
		],
		"exploration_hooks": [
			{
				"hook_id": "submerged_sulfur_chimney",
				"title": "Subterranean Magma Vent Chamber",
				"coordinates_offset": Vector2(-0.08, -0.07),
				"danger_rating": "Medium (Level 20)",
				"description": "Caverns underneath the caldera where liquid sulfur flows into natural subterranean pools.",
				"discovery_reward": "Thermal Heat-Core Stone and 60,000 Beli"
			}
		],
		"docking_clearance": {
			"requirements": "Open haven; warm water naturally prevents hull ice accumulation",
			"dock_fee_beli": 800,
			"marine_patrol_level": "None"
		}
	},

	"san_brisa_atoll": {
		"id": "san_brisa_atoll",
		"name": "San Brisa Atoll",
		"japanese_name": "サン・ブリサ環礁",
		"affiliation": "Uninhabited Wildlife Sanctuary",
		"coordinates": Vector2(-58.5, 78.0),
		"altitude_m": 85.0,
		"radius_km": 65.0,
		"climate": "Temperate Oceanic",
		"biome": "Coral Ring Atoll, Limestone Cliffs, Bird Rookeries",
		"lore_summary": "Remote atoll famous for colossal colonies of Super Sparrows (the breed of Chuchun ridden by Davy Back Fight announcer Itomimizu), giant South Blue raptors, and migration feeding channels of Island-eating fish.",
		"historical_events": [
			"Discovery of the Super Sparrow nesting colonies",
			"Foxy Pirates expedition capturing avian mounts"
		],
		"districts_and_ports": [
			{
				"district_id": "super_sparrow_cliffs",
				"name": "Super Sparrow High Rookery",
				"type": "Nesting Sanctuary",
				"description": "Sheer limestone cliffs alive with thousands of giant 4-meter Super Sparrows chirping loudly.",
				"elevation_m": 80.0,
				"coordinates_offset": Vector2(0.00, 0.02)
			},
			{
				"district_id": "atoll_lagoon_anchorage",
				"name": "Lagoon Coral Haven",
				"type": "Natural Anchorage",
				"description": "Calm turquoise lagoon protected by outer coral reefs from violent South Sea swells.",
				"elevation_m": 1.0,
				"coordinates_offset": Vector2(0.04, -0.03)
			}
		],
		"shops_and_markets": [
			{
				"market_id": "naturalist_field_camp",
				"name": "Rogue Zoologist's Trading Tent",
				"district": "atoll_lagoon_anchorage",
				"shopkeeper_npc_id": "zoologist_barnaby",
				"description": "Expedition tent trading in bird feed, taming whistles, and rare biological specimens.",
				"inventory": [
					{
						"item_id": "super_sparrow_whistle",
						"name": "High-Pitch Super Sparrow Call Whistle",
						"category": "Tool & Mount Summon",
						"price_beli": 15000,
						"description": "Acoustic flute tuned to South Blue sparrow frequencies. Tames or summons a wild avian mount."
					},
					{
						"item_id": "giant_raptor_talon",
						"name": "South Sea Raptor Hunting Talon",
						"category": "Crafting Material",
						"price_beli": 4800,
						"description": "Razor-sharp 30cm claw used in crafting high-penetration arrowheads and daggers."
					}
				]
			}
		],
		"named_npcs": [
			{
				"npc_id": "zoologist_barnaby",
				"name": "Dr. Barnaby",
				"title": "Avian Field Biologist",
				"role": "Fauna Researcher & Quest Giver",
				"affiliation": "Independent Scholar",
				"location_district": "atoll_lagoon_anchorage",
				"dialogue_hooks": [
					"These Super Sparrows can fly non-stop for three days across the Calm Belt if properly fed!",
					"Watch the outer reef waters at twilight; Island-eaters breach when the tide turns.",
					"Do not disturb the eggs in the upper limestone ledges."
				],
				"quest_prompts": [
					"Band 3 juvenile Super Sparrows with tracking rings on the high cliff ledges.",
					"Defend the rookery from an encroaching pack of reef sharks."
				],
				"bounty_beli": 0,
				"combat_archetype": "Naturalist Marksman"
			}
		],
		"fauna_and_flora": [
			{
				"name": "Super Sparrow (Chuchun's Breed)",
				"type": "Fauna (Giant Avian)",
				"rarity": "Uncommon",
				"description": "Enormous 4-meter sparrows with round, fluffy bodies and astonishing load-bearing strength.",
				"harvest_yield": "Sparrow Down Feathers (Friendly grooming)"
			},
			{
				"name": "Island-Eater Fish (Juvenile)",
				"type": "Fauna (Sea Beast)",
				"rarity": "Very Rare",
				"description": "Colossal predatorial marine beasts that swallow smaller islets and coral boulders whole.",
				"harvest_yield": "Island-Eater Armored Scale (8,500 Beli)"
			}
		],
		"exploration_hooks": [
			{
				"hook_id": "sunken_whaler_wreck",
				"title": "Wreck of the Golden Harpoon",
				"coordinates_offset": Vector2(-0.06, 0.05),
				"danger_rating": "Medium (Level 18)",
				"description": "A shattered whaling galleon resting half-submerged on the coral reef.",
				"discovery_reward": "Heavy Harpoon Launcher and 65,000 Beli"
			}
		],
		"docking_clearance": {
			"requirements": "Wild atoll; shallow draft vessels only inside the lagoon passage",
			"dock_fee_beli": 0,
			"marine_patrol_level": "None"
		}
	},

	"reverse_mountain_south_gateway": {
		"id": "reverse_mountain_south_gateway",
		"name": "Reverse Mountain South Staging Gateway",
		"japanese_name": "リヴァース・マウンテン南運河入口",
		"affiliation": "International Waterway / World Government Observation",
		"coordinates": Vector2(-15.5, 1.2),
		"altitude_m": 45.0,
		"radius_km": 40.0,
		"climate": "Violent Maelstrom / Convergent Ocean Current",
		"biome": "Red Line Basalt Cliff Walls, Hydraulic Rapids, Staging Outposts",
		"lore_summary": "The monumental staging mouth where the raging waters of the South Blue converge into the colossal hydraulic canal that climbs 5,000 meters up the sheer face of the Red Line into Reverse Mountain. Flanked by warning lighthouses, ship repair docks, and nervous crews making final preparations before the perilous ascent into the Grand Line.",
		"historical_events": [
			"Centuries of pirate, explorer, and merchant ascents up the southern canal",
			"Construction of the Twin Horns Warning Lighthouse atop the Red Line gate",
			"The Kid Pirates' roaring ascent aboard the Victoria Punk",
			"Jewelry Bonney's escape voyage ascending into Paradise"
		],
		"districts_and_ports": [
			{
				"district_id": "canal_outflow_basin",
				"name": "The Great Hydraulic Basin",
				"type": "Surging Waterway",
				"description": "Whirling 400-meter-wide funnel where sea currents accelerate to 85 m/s toward the upward ramp.",
				"elevation_m": 0.0,
				"coordinates_offset": Vector2(0.00, 0.00)
			},
			{
				"district_id": "twin_horns_lighthouse",
				"name": "Twin Horns Marine Watchtower & Beacon",
				"type": "Navigational Beacon",
				"description": "Monumental stone tower bolted to the sheer red rock of the Red Line broadcasting foghorn signals.",
				"elevation_m": 180.0,
				"coordinates_offset": Vector2(0.02, -0.03)
			},
			{
				"district_id": "last_chance_anchorage",
				"name": "Last Chance Staging Anchorage",
				"type": "Ship Staging Harbor",
				"description": "Sheltered rock grotto where ships purchase emergency rudder straps and hire canal pilots.",
				"elevation_m": 3.0,
				"coordinates_offset": Vector2(-0.04, 0.05)
			}
		],
		"shops_and_markets": [
			{
				"market_id": "reverse_staging_outfitters",
				"name": "The Upward Surge Shipwright & Tackle",
				"district": "last_chance_anchorage",
				"shopkeeper_npc_id": "veteran_pilot_duncan",
				"description": "Harbor workshop outfitting vessels with high-tension rudder cables, reinforced keels, and sea charts.",
				"inventory": [
					{
						"item_id": "hydraulic_keel_reinforcement",
						"name": "Reverse Mountain Heavy Keel Straps",
						"category": "Ship Upgrade",
						"price_beli": 35000,
						"description": "Steel-reinforced oak timbers that double hull integrity during the 85 m/s hydraulic climb up the mountain."
					},
					{
						"item_id": "reverse_current_compass",
						"name": "Canal Vector Alignment Compass",
						"category": "Navigation",
						"price_beli": 12000,
						"description": "Specialized magnetic compass that locks onto the central current channel, preventing ships from slamming into the Red Line walls."
					},
					{
						"item_id": "grand_line_entry_log",
						"name": "Twin Cape Entry Waypoint Chart",
						"category": "Sea Chart",
						"price_beli": 5000,
						"description": "Nautical rubbing showing the downward ramp into Crocus's lighthouse and Laboon's territorial bay."
					}
				]
			}
		],
		"named_npcs": [
			{
				"npc_id": "canal_master_gordon",
				"name": "Master Pilot Gordon",
				"title": "Veteran of Forty Mountain Ascents",
				"role": "Canal Pilot & Guide",
				"affiliation": "Independent Guild of Pilots",
				"location_district": "last_chance_anchorage",
				"dialogue_hooks": [
					"Once you enter the canal gates, there is no turning around! The current will carry you up 5,000 meters whether your ship holds together or snaps in two!",
					"Keep your rudder dead center! If you drift three meters to the left or right, the Red Line will grind your hull into matchsticks!",
					"At the summit, all four oceans collide before plunging into the Grand Line. Give a prayer to whatever god you believe in."
				],
				"quest_prompts": [
					"Salvage drifting wreckage from an ill-fated schooner that missed the canal entrance.",
					"Replace the burnt-out magnesium beacon bulb at the Twin Horns Lighthouse summit."
				],
				"bounty_beli": 0,
				"combat_archetype": "Master Helmsman & Sailor"
			}
		],
		"fauna_and_flora": [
			{
				"name": "Red Line Current Gull",
				"type": "Fauna (Avian)",
				"rarity": "Common",
				"description": "Powerful-winged gulls riding the thermal updrafts created by the roaring hydraulic canal.",
				"harvest_yield": "Non-harvestable"
			}
		],
		"exploration_hooks": [
			{
				"hook_id": "red_line_base_cavern",
				"title": "Under-Canal Hydraulic Intake Grotto",
				"coordinates_offset": Vector2(0.01, -0.06),
				"danger_rating": "Extreme (Level 35)",
				"description": "Submerged cavern beneath the canal gate where the massive ocean pressure creates whirlpools and deposits deep-sea relics.",
				"discovery_reward": "Ancient Seastone Ingot and 200,000 Beli"
			}
		],
		"docking_clearance": {
			"requirements": "Mandatory hull structural inspection before clearance into the upward canal",
			"dock_fee_beli": 3000,
			"marine_patrol_level": "Heavy (Marine Canal Patrol Sloop Stationed)"
		}
	}
}

# ==============================================================================
# 3. NAVIGATION ROUTES TOWARD REVERSE MOUNTAIN
# ==============================================================================
const ROUTES_TO_REVERSE_MOUNTAIN: Array[Dictionary] = [
	{
		"route_id": "route_revolutionary_run",
		"name": "The Revolutionary Freedom Run",
		"departure_island_id": "centaurea",
		"difficulty": "Moderate",
		"total_distance_km": 1420.0,
		"waypoints": [
			{
				"waypoint_name": "Centaurea Offshore Deep Channel",
				"coordinates": Vector2(-21.0, 12.0),
				"current_vector": Vector2(0.8, -0.4), # Northwest drift
				"wind_knots": 18.0,
				"hazard": "Cipher Pol patrol cutters scouting the liberation zone"
			},
			{
				"waypoint_name": "Sorbet Outer Shoals",
				"coordinates": Vector2(-23.5, 9.5),
				"current_vector": Vector2(1.1, -0.5),
				"wind_knots": 22.0,
				"hazard": "Submerged granite shoals and sudden squalls"
			},
			{
				"waypoint_name": "Red Line Boundary Meridian",
				"coordinates": Vector2(-19.0, 4.2),
				"current_vector": Vector2(1.6, -0.7),
				"wind_knots": 28.0,
				"hazard": "Violent cliff-rebound waves bouncing off the +10,000m Red Line wall"
			},
			{
				"waypoint_name": "South Canal Approach Funnel",
				"coordinates": Vector2(-15.5, 1.2),
				"current_vector": Vector2(2.5, -0.9),
				"wind_knots": 35.0,
				"hazard": "Raging 85 m/s hydraulic suction funnel into Reverse Mountain"
			}
		]
	},
	{
		"route_id": "route_industrial_convoy",
		"name": "The Wapol Konzern Scrap Highway",
		"departure_island_id": "evil_black_drum",
		"difficulty": "Hard",
		"total_distance_km": 2850.0,
		"waypoints": [
			{
				"waypoint_name": "Black Drum Slag Channel",
				"coordinates": Vector2(-38.0, 72.0),
				"current_vector": Vector2(0.5, -0.8),
				"wind_knots": 14.0,
				"hazard": "Heavy factory smog reducing visibility to 200 meters"
			},
			{
				"waypoint_name": "Kutsukku Outlaw Shoals",
				"coordinates": Vector2(-44.0, 48.0),
				"current_vector": Vector2(0.9, -1.0),
				"wind_knots": 20.0,
				"hazard": "Rival scrap-pirate sloops hunting for metal cargo"
			},
			{
				"waypoint_name": "Karate Island Swells",
				"coordinates": Vector2(-30.0, 42.0),
				"current_vector": Vector2(1.2, -0.8),
				"wind_knots": 25.0,
				"hazard": "Thundering surf crashing from martial training cliffs"
			},
			{
				"waypoint_name": "Baterilla Floral Passage",
				"coordinates": Vector2(-22.0, 25.0),
				"current_vector": Vector2(1.4, -0.7),
				"wind_knots": 18.0,
				"hazard": "Coral reef labyrinths requiring careful rudder control"
			},
			{
				"waypoint_name": "South Canal Staging Gateway",
				"coordinates": Vector2(-15.5, 1.2),
				"current_vector": Vector2(2.5, -0.9),
				"wind_knots": 35.0,
				"hazard": "Hydraulic convergence into Reverse Mountain"
			}
		]
	},
	{
		"route_id": "route_polar_sub_antarctic",
		"name": "The Great Sub-Polar Glacial Highway",
		"departure_island_id": "vespa_kingdom",
		"difficulty": "Extreme",
		"total_distance_km": 3600.0,
		"waypoints": [
			{
				"waypoint_name": "Vespa Fjord Ice Gate",
				"coordinates": Vector2(-68.0, 15.0),
				"current_vector": Vector2(0.4, 0.2),
				"wind_knots": 30.0,
				"hazard": "Drifting tabular icebergs and freezing sea spray causing top-heavy icing"
			},
			{
				"waypoint_name": "Briss Historic Sea Corridor",
				"coordinates": Vector2(-55.0, 22.0),
				"current_vector": Vector2(1.0, -0.4),
				"wind_knots": 26.0,
				"hazard": "Ancient gale corridors where the St. Briss sailed"
			},
			{
				"waypoint_name": "Torino Canopy Thermal Line",
				"coordinates": Vector2(-38.0, 20.0),
				"current_vector": Vector2(1.3, -0.6),
				"wind_knots": 20.0,
				"hazard": "Sudden downbursts from high-altitude avians and cloud banks"
			},
			{
				"waypoint_name": "South Canal Staging Gateway",
				"coordinates": Vector2(-15.5, 1.2),
				"current_vector": Vector2(2.5, -0.9),
				"wind_knots": 35.0,
				"hazard": "Reverse Mountain canal entrance"
			}
		]
	}
]

# ==============================================================================
# 4. MATHEMATICAL & GEODESIC HELPER METHODS
# ==============================================================================

## Converts spherical coordinates (latitude in deg, longitude in deg, altitude in meters)
## to 64-bit 3D Cartesian coordinates (Vector3) at planet radius R = 16,000,000.0m.
static func spherical_to_cartesian(lat_deg: float, lon_deg: float, alt_m: float = 0.0) -> Vector3:
	var lat_rad: float = deg_to_rad(lat_deg)
	var lon_rad: float = deg_to_rad(lon_deg)
	var r: float = PLANET_RADIUS + alt_m
	
	var x: float = r * cos(lat_rad) * sin(lon_rad)
	var y: float = r * sin(lat_rad)
	var z: float = r * cos(lat_rad) * cos(lon_rad)
	return Vector3(x, y, z)

## Converts 3D Cartesian coordinates (Vector3) back to spherical (lat_deg, lon_deg, alt_m).
## Returns a Vector3 where x = lat_deg, y = lon_deg, z = alt_m.
static func cartesian_to_spherical(pos: Vector3) -> Vector3:
	var r: float = pos.length()
	var alt_m: float = r - PLANET_RADIUS
	if r < 0.001:
		return Vector3.ZERO
	
	var lat_rad: float = asin(clamp(pos.y / r, -1.0, 1.0))
	var lon_rad: float = atan2(pos.x, pos.z)
	
	var lat_deg: float = rad_to_deg(lat_rad)
	var lon_deg: float = rad_to_deg(lon_rad)
	return Vector3(lat_deg, lon_deg, alt_m)

## Calculates the Great Circle distance in meters between two spherical points on the 16,000km sphere.
static func get_great_circle_distance(lat1_deg: float, lon1_deg: float, lat2_deg: float, lon2_deg: float) -> float:
	var lat1: float = deg_to_rad(lat1_deg)
	var lon1: float = deg_to_rad(lon1_deg)
	var lat2: float = deg_to_rad(lat2_deg)
	var lon2: float = deg_to_rad(lon2_deg)
	
	var d_lon: float = lon2 - lon1
	var cos_c: float = sin(lat1) * sin(lat2) + cos(lat1) * cos(lat2) * cos(d_lon)
	cos_c = clamp(cos_c, -1.0, 1.0)
	var central_angle_rad: float = acos(cos_c)
	return PLANET_RADIUS * central_angle_rad

## Calculates initial navigation compass bearing in degrees (0 = North, 90 = East, 180 = South, 270 = West).
static func get_initial_bearing(lat1_deg: float, lon1_deg: float, lat2_deg: float, lon2_deg: float) -> float:
	var lat1: float = deg_to_rad(lat1_deg)
	var lat2: float = deg_to_rad(lat2_deg)
	var d_lon: float = deg_to_rad(lon2_deg - lon1_deg)
	
	var y: float = sin(d_lon) * cos(lat2)
	var x: float = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(d_lon)
	var bearing_rad: float = atan2(y, x)
	var bearing_deg: float = fmod(rad_to_deg(bearing_rad) + 360.0, 360.0)
	return bearing_deg

## Validates whether a given latitude/longitude coordinate pair lies inside the South Blue sector bounds.
static func is_in_south_blue_sector(lat_deg: float, lon_deg: float) -> bool:
	return (lat_deg >= SECTOR_LAT_MIN and lat_deg <= SECTOR_LAT_MAX and
			lon_deg >= SECTOR_LON_MIN and lon_deg <= SECTOR_LON_MAX)

# ==============================================================================
# 5. QUERY & RETRIEVAL API
# ==============================================================================

## Returns an island dictionary by its unique string identifier.
static func get_island(island_id: String) -> Dictionary:
	if ISLANDS.has(island_id):
		return ISLANDS[island_id]
	push_warning("SouthBlueData: Island id '%s' not found." % island_id)
	return {}

## Returns an array of all registered South Blue island records.
static func get_all_islands() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in ISLANDS.keys():
		result.append(ISLANDS[key])
	return result

## Returns all islands matching a specific political affiliation.
static func get_islands_by_affiliation(keyword: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var kw_lower: String = keyword.to_lower()
	for key in ISLANDS.keys():
		var isl: Dictionary = ISLANDS[key]
		var aff: String = isl.get("affiliation", "").to_lower()
		if aff.contains(kw_lower):
			result.append(isl)
	return result

## Returns all islands situated within a given radius in meters from a target coordinate.
static func get_islands_in_range(center_lat: float, center_lon: float, max_dist_m: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in ISLANDS.keys():
		var isl: Dictionary = ISLANDS[key]
		var coords: Vector2 = isl.get("coordinates", Vector2.ZERO)
		var dist_m: float = get_great_circle_distance(center_lat, center_lon, coords.x, coords.y)
		if dist_m <= max_dist_m:
			var isl_copy: Dictionary = isl.duplicate()
			isl_copy["distance_to_target_m"] = dist_m
			result.append(isl_copy)
	return result

## Finds a specific NPC by their unique identifier across all South Blue settlements.
static func get_npc(npc_id: String) -> Dictionary:
	for isl_key in ISLANDS.keys():
		var isl: Dictionary = ISLANDS[isl_key]
		var npcs: Array = isl.get("named_npcs", [])
		for n in npcs:
			if n.get("npc_id", "") == npc_id:
				var res: Dictionary = n.duplicate()
				res["home_island_id"] = isl_key
				res["home_island_name"] = isl.get("name", "")
				return res
	return {}

## Finds a specific market by its unique market_id.
static func get_market(market_id: String) -> Dictionary:
	for isl_key in ISLANDS.keys():
		var isl: Dictionary = ISLANDS[isl_key]
		var markets: Array = isl.get("shops_and_markets", [])
		for m in markets:
			if m.get("market_id", "") == market_id:
				var res: Dictionary = m.duplicate()
				res["island_id"] = isl_key
				res["island_name"] = isl.get("name", "")
				return res
	return {}

## Finds an item by item_id across all markets in South Blue.
static func get_item(item_id: String) -> Dictionary:
	for isl_key in ISLANDS.keys():
		var isl: Dictionary = ISLANDS[isl_key]
		var markets: Array = isl.get("shops_and_markets", [])
		for m in markets:
			var inv: Array = m.get("inventory", [])
			for item in inv:
				if item.get("item_id", "") == item_id:
					var res: Dictionary = item.duplicate()
					res["sold_at_market_id"] = m.get("market_id", "")
					res["sold_at_market_name"] = m.get("name", "")
					res["sold_at_island_id"] = isl_key
					return res
	return {}

## Searches for items by category across all South Blue markets.
static func find_items_by_category(category_keyword: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var cat_lower: String = category_keyword.to_lower()
	for isl_key in ISLANDS.keys():
		var isl: Dictionary = ISLANDS[isl_key]
		var markets: Array = isl.get("shops_and_markets", [])
		for m in markets:
			var inv: Array = m.get("inventory", [])
			for item in inv:
				var item_cat: String = item.get("category", "").to_lower()
				if item_cat.contains(cat_lower):
					var entry: Dictionary = item.duplicate()
					entry["island_id"] = isl_key
					entry["market_id"] = m.get("market_id", "")
					result.append(entry)
	return result

## Returns pre-calculated route waypoints to Reverse Mountain for a given departure island.
static func get_route_to_reverse_mountain(departure_island_id: String) -> Dictionary:
	for route in ROUTES_TO_REVERSE_MOUNTAIN:
		if route.get("departure_island_id", "") == departure_island_id:
			return route
	# If no specific authored route exists, compute direct Great Circle trajectory to Canal Gateway
	var isl: Dictionary = get_island(departure_island_id)
	if isl.is_empty():
		return {}
	var coords: Vector2 = isl.get("coordinates", Vector2.ZERO)
	var gateway_coords: Vector2 = REVERSE_MOUNTAIN_CANAL_ENTRY["coordinates"]
	var dist_m: float = get_great_circle_distance(coords.x, coords.y, gateway_coords.x, gateway_coords.y)
	var bearing: float = get_initial_bearing(coords.x, coords.y, gateway_coords.x, gateway_coords.y)
	
	return {
		"route_id": "direct_geodesic_" + departure_island_id,
		"name": "Direct Geodesic Approach from " + isl.get("name", ""),
		"departure_island_id": departure_island_id,
		"difficulty": "Dynamic",
		"total_distance_km": dist_m / 1000.0,
		"initial_compass_bearing_deg": bearing,
		"destination_node": REVERSE_MOUNTAIN_CANAL_ENTRY["name"],
		"destination_coordinates": gateway_coords
	}
