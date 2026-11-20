# Project Blue Planet — One Piece Planetary Exploration RPG (Godot 4.3)

An indie planetary-scale spherical exploration RPG built in **Godot 4.3** where **1 unit = 1 meter** (player height = `2.0 m`) on a seamless sphere larger than Earth (**Radius $R = 16,000,000\text{ m}$**, **Circumference $\approx 100,531\text{ km}$**).

## Key Features
- **64-Bit Floating-Origin Planetary Engine (`core/floating_origin_bridge.gd`, `core/planet_sphere.gd`):** Stores true 64-bit IEEE 754 coordinates (`PackedFloat64Array`) and rebases Godot's local 3D origin every `1,000 m`, enabling jitter-free planetary exploration in standard prebuilt Godot 4.3.
- **Procedural 3D Rendering (`core/planet_mesh_renderer.gd`, `rendering/`, `shaders/`):**
  - Multi-ring curved ocean LODs (`0–150 km`) with `spherical_ocean.gdshader` and biome terrain patches with `red_line_terrain.gdshader`.
  - Rayleigh/Mie atmospheric sky dome (`planetary_atmosphere.gdshader`) with rotating `+7,000 m` White Sea and `+10,000 m` White-White Sea cloud decks.
  - Procedural 3D **Going Caravel** ship mesh, `2.0 m` Explorer character mesh, Dawn Island / Foosha Village harbor & windmills, Reverse Mountain's 5 animated hydraulic canals + `400 m` Laboon, and iconic Grand Line landmarks (Red Line cliffs, Drum Island, Alabasta, Water 7, Sabaody, Skypiea, Fish-Man Island, Wano, and Zunesha).
- **Complete One Piece World Atlas (`regions/`, `docs/`):** 107 registered island/settlement records across East Blue, North Blue, West Blue, South Blue, Reverse Mountain, and the Grand Line (Paradise, Calm Belts, Sky Seas, Abyss, and New World), with shops, multi-currency exchange (`Beli`, `Extol`, `Gor`, `Wano Ryo`), branching NPC dialogues, quests, and a 7-Act campaign culminating in 4 Road Poneglyph triangulation to Laugh Tale.

## Quick Start (Godot 4.3+)
1. Open the project in **Godot 4.3+**:
   ```bash
   /Applications/Godot.app/Contents/MacOS/Godot --path /Users/lin/Downloads/OnePieceBluePlanet
   ```
   Or open in the Godot Editor:
   ```bash
   /Applications/Godot.app/Contents/MacOS/Godot -e --path /Users/lin/Downloads/OnePieceBluePlanet
   ```
2. Run the static verification suite:
   ```bash
   python3 tools/verify_project.py
   ```

## Controls
- `W A S D` — Move / Steer Ship
- `Space` — Jump
- `Shift` — Sprint
- `E` — Board Ship / Helm Interact
- `M` — Surveying Sextant / Cartography Map
- `H` — Activate Haki
- `Q` — Coup de Burst
