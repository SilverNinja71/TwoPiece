# East Blue Wiki Atlas — Project "Blue Planet"

> **Region:** East Blue (*The Sea of Dawn*)  
> **Spherical Sector:** Latitude $\theta \in [+15^\circ, +75^\circ]$, Longitude $\phi \in [0^\circ, +90^\circ]$  
> **Planetary Scale:** Godot 4.3+ (`precision=double`), $1\text{ unit} = 1\text{ m}$, Player Height = $2.0\text{ m}$, Sea-Level Planet Radius $R = 16,000,000.0\text{ m}$  
> **Currency:** Beli (฿)  
> **Data Module:** [`regions/east_blue_data.gd`](../regions/east_blue_data.gd) (`class_name EastBlueData`)

---

## 1. Macro-Geography & Maritime Boundaries

East Blue is the starter sea of Project "Blue Planet," bounded on the **west** ($\phi = 0^\circ$ / $+45^\circ$ Great Circle) by the sheer $+10,000\text{ m}$ cliffs of the **Red Line**, and on the **south** ($\theta < +15^\circ$) by the windless, $150\text{ km}$-wide **North Calm Belt** teeming with Sea Kings. Unlike the Grand Line, standard magnetic compasses operate reliably throughout East Blue, and weather transitions follow gradual seasonal patterns—except for sudden squalls near **Loguetown** and circular trap currents around **Sixis**.

### Coordinate & Progression Overview

| Island / Landmark | ID | Lat ($\theta$) | Lon ($\phi$) | Radius (m) | Danger Tier | Primary Role |
| :--- | :--- | :---: | :---: | :---: | :---: | :--- |
| **Dawn Island** | `dawn_island` | $+52.0^\circ$ | $+74.0^\circ$ | 22,000 | 1 | Starter Hub (Foosha Village, Goa Kingdom, Mt. Colubo, Gray Terminal) |
| **Goat Island** | `goat_island` | $+47.0^\circ$ | $+78.5^\circ$ | 3,200 | 1 | Alvida Pirates Cove & Koby Rescue |
| **Shells Town** | `shells_town` | $+46.5^\circ$ | $+68.0^\circ$ | 8,500 | 2 | Marine Base 153rd Branch (Yotsuba Island Region) |
| **Shimotsuki Village** | `shimotsuki_village` | $+43.0^\circ$ | $+80.0^\circ$ | 6,200 | 1 | Isshin Dojo & Wano Emigrant Forge |
| **Organ Islands** | `organ_islands` | $+45.0^\circ$ | $+58.0^\circ$ | 9,200 | 2 | Orange Town, Buggy Occupation & Chouchou's Shop |
| **Island of Rare Animals** | `island_of_rare_animals` | $+36.5^\circ$ | $+56.5^\circ$ | 4,500 | 1 | Wilderness Sanctuary (Gaimon & Hybrid Beasts) |
| **Gecko Islands** | `gecko_islands` | $+43.5^\circ$ | $+47.0^\circ$ | 9,800 | 2 | Syrup Village & *Going Merry* Shipyard |
| **The Baratie** | `baratie` | $+28.0^\circ$ | $+45.0^\circ$ | 220 | 3 | Floating Sea Restaurant (Sambas Region) |
| **Conomi Islands** | `conomi_islands` | $+41.0^\circ$ | $+31.0^\circ$ | 13,500 | 4 | Cocoyasi Village, Gosa Ruins & Arlong Park |
| **Loguetown** | `loguetown` | $+21.5^\circ$ | $+14.0^\circ$ | 11,000 | 4 | Polestar Islands Finale Port before Reverse Mountain |
| **Tequila Wolf** | `tequila_wolf` | $+68.5^\circ$ | $+48.0^\circ$ | 16,000 | 5 | 700-Year World Government Slave Bridge |
| **Sixis** | `sixis` | $+64.0^\circ$ | $+62.0^\circ$ | 4,200 | 3 | Current-Locked Reef & Spade Pirates Origin |
| **Mirrorball Island** | `mirrorball_island` | $+26.0^\circ$ | $+72.0^\circ$ | 5,100 | 1 | Festive Dance Contest Port (*Jango's Dance Paradise*) |
| **Kumate Tribe Island** | `kumate_island` | $+33.0^\circ$ | $+76.0^\circ$ | 5,400 | 3 | Bear-Paw Jungle (*Buggy's Crew Adventure Chronicles*) |
| **Oykot Kingdom** | `oykot_kingdom` | $+57.5^\circ$ | $+40.0^\circ$ | 11,500 | 2 | Rebuilt War Kingdom (Bell-mère / Nami & Nojiko origin) |
| **Frauce Kingdom** | `frauce_kingdom` | $+55.0^\circ$ | $+22.0^\circ$ | 7,200 | 2 | Canonical East Blue Member Kingdom |
| **Nagagutsu Kingdom** | `nagagutsu_kingdom` | $+30.0^\circ$ | $+25.0^\circ$ | 6,800 | 2 | Southwestern Shipping Lane Kingdom |
| **Satsuruzo Kingdom** | `satsuruzo_kingdom` | $+61.0^\circ$ | $+82.0^\circ$ | 7,000 | 2 | Far Northeastern Peripheral Kingdom |
| **Cozia** | `cozia_island` | $+23.5^\circ$ | $+60.0^\circ$ | 5,800 | 2 | Southern Island (invaded by Germa 66 13 years prior) |

---

## 2. Exhaustive Island-by-Island Canon Atlas

### 2.1 Dawn Island & Goa Kingdom (`dawn_island`)
- **Lore & Geography:** Birthplace of **Monkey D. Luffy** and childhood home of **Portgas D. Ace** and **Sabo**. Dawn Island is governed by the **Goa Kingdom**, regarded as the most prosperous yet fiercely class-stratified nation in East Blue. Massive stone walls divide the island inward from lawless slums to aristocratic luxury:
  1. **Foosha Village (Windmill Village):** Peaceful port on the eastern coast where windmills turn above **Partys Bar** and **Gyoru's Fish Pier**. Offshore lurks the **Lord of the Coast**, a 30-meter Sea King.
  2. **Mt. Colubo:** Rugged, beast-filled mountain behind Foosha Village housing the **Dadan Family** mountain bandit cabin.
  3. **Midway Forest:** Dense predator-filled woodland separating Mt. Colubo from the Gray Terminal.
  4. **Gray Terminal:** Mountainous scrapyard and outcast slum outside Goa's Great Gate, infamously burned by the Bluejam Pirates under noble orders.
  5. **Edge Town → Town Center → High Town:** Concentric walled districts progressing from gate guards and artisan guilds up to **King Stelly's** High Town Royal Palace.
- **Marketplaces, Taverns & Inventories:**
  - **Partys Bar** (*Keeper: Makino*): *Foosha Spiced Ale* (350 ฿), *Foosha Pasture Milk* (150 ฿), *Partys Bar Roast Platter* (650 ฿), *Starter Sea Travel Rations* (1,200 ฿), *Goa Citrus Juice* (250 ฿).
  - **Foosha Fish Pier Stall** (*Keeper: Gyoru*): *Fresh East Blue Sea Bream* (400 ฿), *Salted Mackerel Barrel* (2,400 ฿), *Beginner Bamboo Fishing Rod* (1,800 ฿), *Bait Pouch* (200 ฿).
  - **Mt. Colubo Bandit Supply Cache** (*Keeper: Curly Dadan*): *Colubo Giant Boar Steak* (950 ฿), *Reinforced Steel Pipe* (3,200 ฿), *Bandit Flint & Tinderbox* (450 ฿), *Colubo Herbal Antidote* (700 ฿).
  - **Gray Terminal Scrap Exchange** (*Keeper: Raggedy Scrap Broker*): *Salvaged Noble Silverware* (1,500 ฿), *Scrap Hull Repair Planks* (900 ฿), *Rusted Sailor Cutlass* (2,500 ฿), *Salvaged Brass Lantern* (1,100 ฿).
  - **High Town Royal Bazaar** (*Keeper: High Town Purveyor*): *Goa Aristocrat Silk Coat* (18,000 ฿), *Goa Imperial Tea Crate* (8,500 ฿), *Precision East Blue Compass* (6,500 ฿), *Goa Harbor Exit Charter* (5,000 ฿).
- **Key NPCs:** **Makino**, **Mayor Woop Slap**, **Gyoru** (fishmonger), **Curly Dadan**, **Dogra**, **Magra**, **King Stelly**, **Minatomo** (door-repair carpenter gag NPC), **Higuma's Remnant Bandits**, **Lord of the Coast**.

---

### 2.2 Goat Island (`goat_island`)
- **Lore & Geography:** Craggy limestone island in eastern East Blue serving in the manga as the hidden cove of **"Iron Mace" Alvida** (5,000,000 ฿ bounty) and her ship *Miss Love Duck*, where Luffy emerged from a drifting cider barrel and freed **Koby**.
- **Establishments & NPCs:**
  - **Cove Salvage Cask** (*Keeper: Koby*): *Recovered Cider Barrel* (800 ฿), *Pirate Scrap Iron* (600 ฿).
  - **NPCs:** **Iron Mace Alvida**, **Koby** (chore boy seeking escort to Shells Town), **Heppoko** (lookout).

---

### 2.3 Shells Town (`shells_town`)
- **Lore & Geography:** Fortified port town in the **Yotsuba Island Region** dominated by the **153rd Marine Branch**, formerly ruled under terror by **Captain "Axe-Hand" Morgan** and his spoiled son **Helmeppo**. Here Roronoa Zoro was bound in the courtyard until Luffy and **Rika** intervened.
- **Marketplaces, Taverns & Inventories:**
  - **Food Foo (Ririka's Food & Bar)** (*Keepers: Ririka & Rika*): *Rika's Sweet Sugar Onigiri* (150 ฿ — canonically made with sugar instead of salt), *Shells Town Grilled Sea Bass* (550 ฿), *Harbor Draft Ale* (400 ฿), *Garrison Sailor Bento* (900 ฿).
  - **Base 153 Surplus Armory** (*Keeper: 153rd Quartermaster*): *Standard Marine Cutlass* (12,000 ฿), *Marine Issue Flintlock* (15,000 ฿), *Flintlock Lead Shot & Powder x20* (1,800 ฿), *Marine Lookout Spyglass* (7,500 ฿), *Seastone Handcuff Master Key* (45,000 ฿).
  - **Shells Harbor Supply Stalls**: *Tarred Hemp Rigging Coil* (2,200 ฿), *50-Gallon Fresh Water Cask* (500 ฿).
- **Key NPCs:** **Rika**, **Ririka**, **Lieutenant Ripper**, **Koby** (153rd recruit), **Captain Morgan**, **Helmeppo**.

---

### 2.4 Shimotsuki Village (`shimotsuki_village`)
- **Lore & Geography:** Peaceful coastal settlement founded 55 years ago by emigrants from **Wano Country** including master swordsmith **Shimotsuki Kouzaburou** (creator of *Wado Ichimonji* and *Enma*). Home to **Isshin Dojo**, where Zoro and Kuina trained.
- **Establishments & Inventories:**
  - **Isshin Dojo Martial Quartermaster** (*Keeper: Shimotsuki Koushirou*): *Isshin Bamboo Training Sword* (2,800 ฿), *Wado-Style Katana Maintenance Kit* (4,500 ฿), *Scroll of the Breath of All Things (Primer)* (35,000 ฿).
  - **Shimotsuki Village Swordsmith Forge**: *Shimotsuki Folded Steel Katana* (38,000 ฿), *Camellia Blade Oil* (1,200 ฿), *Lacquered White Saya Scabbard* (6,500 ฿).
- **Key NPCs:** **Shimotsuki Koushirou**, **Village Swordsmith**, **Isshin Senior Disciple**.

---

### 2.5 Organ Islands — Orange Town (`organ_islands`)
- **Lore & Geography:** Archipelago shaped around pipe-organ sea cliffs and home to **Orange Town**, built out of wilderness forty years prior by **Mayor Boodle** and briefly occupied by **Buggy the Clown** (15,000,000 ฿). Famous for **Chouchou**, the loyal white dog guarding the late **Hocker's** pet food shop.
- **Marketplaces, Taverns & Inventories:**
  - **Chouchou's Pet Food Shop** (*Keeper: Chouchou*): *Premium Beast Rations* (1,600 ฿ — tames/pacifies island fauna), *Hocker's Famous Dog Biscuits* (300 ฿), *Red Guardian Collar* (4,200 ฿).
  - **Drinker's Pub**: *Orange Town Spiced Rum* (500 ฿), *Buggy Ball Blasting Powder* (14,000 ฿), *Tavern Mutton Skewer* (750 ฿).
  - **Mayor Boodle's Rebuild Supply Depot**: *Orange Town Structural Blueprints* (5,500 ฿), *Seasoned Oak Hull Planks* (3,200 ฿), *Pine Pitch & Caulking Tar* (1,400 ฿).
  - **Poro's Orange Town Bookstore** (*Keeper: Poro*): *East Blue Tide & Current Almanac* (4,800 ฿), *Cartographer's Blank Logbook* (1,500 ฿).
- **Key NPCs:** **Mayor Boodle**, **Chouchou**, **Poro**, **Buggy the Clown**, **Mohji & Richie**, **Cabaji**.

---

### 2.6 Island of Rare Animals (`island_of_rare_animals`)
- **Lore & Geography:** Solitary treasure-chest-shaped jungle island with **no commercial shops**. Home to bizarre hybrid wildlife (*Cocox* fox-rooster, *Usagihebi* rabbit-snake, *Lion-Pig*, *Hippo-Rhino*, *Giraffe-Lion*) and **Gaimon**, who spent 20 years stuck in a chest guarding five empty summit chests, later joined by **Sarfunkel**.

---

### 2.7 Gecko Islands — Syrup Village (`gecko_islands`)
- **Lore & Geography:** Plateau village flanked by twin steep coastal slopes, Usopp's birthplace. Threatened by **Captain Kuro (Klahadore)** (16,000,000 ฿), **Jango** (9,000,000 ฿), and the **Nyaban Brothers (Sham & Buchi)** (7,000,000 ฿). Saving the village unlocks the Caravel-class flagship ***Going Merry***, designed by **Merry** and gifted by **Kaya**.
- **Establishments & Inventories:**
  - **Meshi Restaurant**: *Syrup Village Herb Soup* (420 ฿), *Fresh Buttered Bread Rolls* (220 ฿), *Kaya's Ginger Honey Tea* (350 ฿).
  - **Kaya Mansion Shipyard & Outfitter** (*Keepers: Merry & Kaya*): *Going Merry Caravel Hull Blueprints* (120,000 ฿), *Lead Star Slingshot Ammo x25* (1,200 ฿), *Smoke Star Pellets x10* (1,800 ฿), *Mansion Herbal Restorative Tonic* (1,600 ฿).
- **Key NPCs:** **Kaya**, **Merry**, **Ninjin, Piiman & Tamanegi** (Usopp Pirates), **Mayor Mornin**, **Captain Kuro**, **Jango**, **Sham & Buchi**.

---

### 2.8 The Baratie — Sambas Region (`baratie`)
- **Lore & Geography:** Colossal fish-shaped ocean restaurant moored near the **North Calm Belt** border in the Sambas Region, captained by **"Red-Leg" Zeff**. Features folding fin battle decks, the Sabagashira I battle prow, and the **Sister Anko** anglerfish dessert submarine tender. Site of the **Don Krieg** (17,000,000 ฿) armada siege and **Dracule Mihawk's** legendary duel.
- **Establishments & Inventories:**
  - **The Baratie Dining Hall** (*Keeper: Chef Zeff*): *All-Blue Seafood Risotto* (4,500 ฿), *Zeff's Pirate Seafood Pilaf* (2,200 ฿), *Rare Sea-Tuna Carpaccio* (6,800 ฿), *Baratie Citrus-Glazed Rations* (3,800 ฿), *Zeff's Maritime Cookbook* (42,000 ฿).
  - **Sister Anko Galley Market** (*Keeper: Patty*): *Sister Anko Sea-Fruit Tart* (1,400 ฿), *Sambas Black-Pepper Spice Tin* (3,200 ฿).
  - **Patty & Carne's Provision Deck** (*Keeper: Carne*): *Baratie Galley Bulk Crate* (6,000 ฿), *Patty's Heavy Iron Skillet* (18,000 ฿).
- **Key NPCs:** **Chef Zeff**, **Patty**, **Carne**, **Lt. Fullbody**, **Moodie**, **Motzel**, **Don Krieg**, **Gin**, **Dracule Mihawk**.

---

### 2.9 Conomi Islands (`conomi_islands`)
- **Lore & Geography:** Tropical archipelago comprising **Cocoyasi Village**, the shattered ruins of **Gosa Village** (flipped upside down by sea cow **Momoo**), and **Arlong Park** (modeled after Sabaody Park). Endured 8 years of extortion under **Arlong** (20,000,000 ฿) and corrupt **Captain Nezumi** (16th Marine Branch), charging **100,000 ฿ per adult** and **50,000 ฿ per child** monthly, while Nami worked to buy back her village for **100,000,000 ฿**.
- **Establishments & Inventories:**
  - **Bell-mère's Tangerine Grove** (*Keepers: Nojiko & Chabo*): *Cocoyasi Deck Tangerine Tree* (25,000 ฿ — permanent ship-deck Scurvy immunity), *Fresh Cocoyasi Mikan Crate* (1,800 ฿), *Bell-mère's Mikan Marmalade* (3,400 ฿).
  - **Cocoyasi Cartography & Bookstore**: *Blank Parchment Sea Charts x5* (3,000 ฿), *Navigator's Brass Sextant* (16,000 ฿), *East Blue Barometric Primer* (22,000 ฿).
  - **Genzo's Pinwheel & Gear Stall** (*Keeper: Sheriff Genzo*): *Genzo's Lucky Pinwheel* (2,000 ฿), *Brass Waterproof Chart Cylinder* (4,500 ฿).
  - **Dr. Nako's Clinic** (*Keeper: Dr. Nako*): *Vitamin-Rich Scurvy Cure* (950 ฿), *Cocoyasi Field Medkit* (2,800 ฿).
  - **Arlong Park Salvage & Bounty Cache** (*Keepers: Johnny & Yosaku*): *Fish-Man Karate Water-Impact Scroll* (55,000 ฿), *Serrated Shark-Tooth Sabre* (42,000 ฿).
- **Key NPCs:** **Nojiko**, **Genzo**, **Dr. Nako**, **Chabo**, **Johnny & Yosaku**, **Arlong**, **Hatchan**, **Kuroobi**, **Chew**, **Momoo**, **Captain Nezumi**.

---

### 2.10 Loguetown — Polestar Islands (`loguetown`)
- **Lore & Geography:** *"The Town of the Beginning and the End"*—birthplace and execution site of Pirate King **Gol D. Roger**, and the final major staging port before sailing southwest into **Reverse Mountain**. Heavily garrisoned by **Captain Smoker** and **Ensign Tashigi**.
- **Marketplaces, Taverns & Inventories:**
  - **Ipponmatsu's Arms Shop** (*Keepers: Ipponmatsu & Ipponume*):
    - *Sandai Kitetsu* (Cursed Grade Katana, 1,000,000 ฿ value / 50,000 ฿ bargain bin test).
    - *Yubashiri* (50 Skillful Grade / *Ryo Wazamono*, 0 ฿ heirloom gift upon passing Ipponmatsu's willpower test).
    - *Loguetown Steel Katana* (50,000 ฿), *Marine Boarding Axe* (32,000 ฿).
  - **Gold Roger Bar** (*Keeper: Raoul*, anime canon): *Old Era Pirate Rum* (1,800 ฿), *Raoul's Red-Line Crossing Stew* (2,400 ฿).
  - **Robecca Hanberg Boutique** (*Keeper: Hanger*): *Robecca Hanberg Storm Trenchcoat* (65,000 ฿), *Crimson Polestar Silk Vest* (48,000 ฿).
  - **Antique House Clothing**: *Trendy Polestar Travel Jacket* (8,500 ฿), *Woven Navigator Sun Hat* (2,400 ฿).
  - **The Fisherman King Uotome** (*Keeper: Sapi*, half-fishman): *Elephant True Bluefin Tuna* (250,000 ฿), *Polestar Giant Spiny Lobster* (14,000 ฿).
  - **Ed's Love Love Pirates Novelty Shop** (*Keeper: Ed*, anime canon): *North Blue Marksman Goggles* (12,000 ฿), *Souvenir 'Pirate King' Compass* (3,000 ฿).
  - **Loguetown Grand Line Outfitter**: *Hydraulic Canal Rudder Brace* (40,000 ฿), *Empty Log Pose Wrist Mount* (15,000 ฿), *Reverse Mountain Timber Pack* (12,000 ฿).
- **Key NPCs:** **Ipponmatsu**, **Ipponume**, **Raoul**, **Hanger**, **Sapi**, **Ed**, **Yu**, **Koze & Packy**, **Captain Smoker**, **Ensign Tashigi**, **Monkey D. Dragon** (Execution Plaza storm event).

---

### 2.11 Northern, Cover-Story & Minor East Blue Locations
- **Tequila Wolf (`tequila_wolf`):** Colossal stone bridge built over **700 years** by World Government slave labor in sub-arctic waters (where Kuma sent Nico Robin). Houses the **Prisoner Underground Exchange** (*Cold-Weather Coat* 14,000 ฿, *Heavy Mason Tools* 6,500 ฿, *700-Year Bridge Charter Rubbing* 30,000 ฿) and **Bridge Supply Depot**. Key NPCs: **Soran**, **Revolutionary Liberation Scout**, **Bridge Fortress Warden**.
- **Sixis (`sixis`):** Barren, whirlpool-locked island where **Portgas D. Ace** and **Masked Deuce** founded the **Spade Pirates** and Ace awakened the *Mera Mera no Mi*.
- **Mirrorball Island (`mirrorball_island`):** Southeastern dance-contest port featured in *Jango's Dance Paradise* (*Moonwalk Rhythm Boots* 9,500 ฿, *Heart-Shaped Hypnotist Shades* 4,200 ฿).
- **Kumate Tribe Island (`kumate_island`):** Bear-paw-shaped cannibal tribe island featured in *Buggy's Crew Adventure Chronicles*.
- **Oykot Kingdom (`oykot_kingdom`):** Northern kingdom rebuilt after pirate devastation 20 years prior, where young Marine **Bell-mère** rescued infant **Nami** and **Nojiko**.
- **Minor Canonical Kingdoms:** **Frauce Kingdom**, **Nagagutsu Kingdom**, **Satsuruzo Kingdom**, and **Cozia** (raided by Germa 66 13 years prior).

---

## 3. Sea Lanes & Reverse Mountain Approach

1. **Dawn-to-Loguetown Great Voyage Route:** `dawn_island` $\rightarrow$ `goat_island` $\rightarrow$ `shells_town` $\rightarrow$ `organ_islands` $\rightarrow$ `island_of_rare_animals` $\rightarrow$ `gecko_islands` $\rightarrow$ `baratie` $\rightarrow$ `conomi_islands` $\rightarrow$ `loguetown` $\rightarrow$ **East Blue Reverse Mountain Canal**.
2. **Reverse Mountain Handoff (`EastBlueData.get_reverse_mountain_route()`):**
   - Depart **Loguetown** ($\theta = +21.5^\circ, \phi = +14.0^\circ$) southwest toward the **East Blue Canal Approach Buoy** ($\theta = +15.0^\circ, \phi = +8.5^\circ$).
   - Enter the $400\text{ m}$-wide ascending hydraulic canal at $(\theta = +2.0^\circ, \phi = +2.0^\circ)$ and ride the winter current up to the $+5,000\text{ m}$ summit at $(\theta = 0.0^\circ, \phi = 0.0^\circ)$ before plunging eastward into **Twin Cape**.
