# herra-iso-dnd (Herra D&D) — design document & project guide

An isometric, grid-based, turn-based dungeon RPG with pixel-art graphics and retro synthesized audio,
made in **Godot 4.7.2** (GDScript). The player controls a party of four (**Fighter, Rogue, Cleric,
Mage**) using simplified D&D 5e-style rules from the freely licensed SRD. Dungeons, treasure,
monsters, spells, items and character progression.

**Roles:** the user (Paul) designs and builds the maps in the Godot editor, may import some graphics
and sounds of his own, and playtests. Claude writes the code and generates the art and audio the user
doesn't supply.

## Working style the user likes
- Show visuals early (stills, GIFs). **Look at every image yourself before showing it.** Be honest
  about weak spots.
- Claude can't hear audio: check sounds by waveform/levels, and ask the user how they sound.
- Build in small playable steps. The user playtests and gives feedback.
- The user **loved the look and sound** of the concept mock-ups (`docs/previews/`). Keep new work
  consistent with them.

## Decisions
| Topic | Decision |
|---|---|
| Engine | Godot **4.7.2** exactly, GDScript. Renderer: Mobile. |
| Project | Godot name `herra-iso-dnd`, folder `C:\Godot\Projects\herra-iso-dnd`, repo https://github.com/PaulHeraty/herra-iso-dnd (branch `main`) |
| View | Isometric 2:1 diamond grid, top-down |
| Party | Fighter, Rogue, Cleric, Mage. The player controls all four in combat. |
| Rules | 5e SRD (CC-BY-4.0), simplified at first, more detail later |
| Exploration | Free movement on the grid; switches to turn-based when combat starts |
| Maps | Built by the user in the editor: TileMapLayers + placeable marker scenes |
| Resolution | 640×360 base, integer scaling (window 1280×720), nearest filtering, pixel snapping |
| Art | Pixel art, limited palettes, light ordered (Bayer 4×4) dithering, 1px dark outlines on sprites |
| Audio | Retro synthesized SFX (WAV); optional chiptune music later |
| Story | Placeholder. One pitch exists (below), not chosen. |

## Licensing (important)
- Rules, spells and monsters come only from the **5e SRD (CC-BY-4.0)**, with the attribution in
  `CREDITS.md`. Do **not** use the "Dungeons & Dragons" name or logo, or non-SRD monsters (beholder,
  mind flayer...). Our eye monster is the **Eye Tyrant**: an original name and design. Keep it ours.
- "Herra D&D" is fine as a personal project title. A public release needs a different name.
- Record every downloaded or user-imported asset in `CREDITS.md` (author + license).

## Machine / tooling
- Godot: `C:\Godot\Godot_v4.7.2-stable_win64.exe` (editor) and `..._console.exe` (for CLI output).
  Not on PATH. Headless script: `"/c/Godot/Godot_v4.7.2-stable_win64_console.exe" --headless --path . -s res://tools/godot/<script>.gd`
  Re-import after generating files: `... --headless --path . --import`
- Screenshot check: run a SceneTree script **without** `--headless` that loads a scene, waits ~30
  frames, and saves `root.get_texture().get_image()` (keep such scripts in the scratchpad).
- Python is **not installed** (as of 2026-11-04). The Python generators in `tools/python/` need
  Python 3 + Pillow + numpy (+ ffmpeg for videos). The Phase 0 art was ported to GDScript generators
  in `tools/godot/`, which need nothing but Godot.

## Project layout
```
assets/
  tiles/      floor_atlas.png, wall_atlas.png, dungeon_tileset.tres   (generated)
  sprites/    heroes/ (16×24), monsters/ (Eye Tyrant), props/ (chest, bones, torch_sheet, web)
  effects/    fireball_sheet.png (6×16px), explosion_sheet.png (7×32px)
  sfx/        13 WAVs from the concept session (torch_ambience imports as a forward loop)
scenes/
  maps/       map_template.tscn (copy this for new maps), test_room.tscn (main scene for now)
  markers/    party_start, monster_spawn, chest, torch, door, trap (.tscn)
  actors/     (Phase 1+)
scripts/
  iso_grid.gd           IsoGrid: cell <-> world maths
  maps/dungeon_map.gd   DungeonMap: root script of every map
  markers/              MapMarker base + one script per marker
data/         (Phase 2+) Resources: classes, monsters, spells, items
tools/
  godot/      gen_art.gd -> build_tileset.gd -> build_test_room.gd   (run in that order, import between)
  python/     concept-session generators (reference + future art/audio work)
docs/previews/  concept mock-ups (.gdignore'd: Godot does not import them)
_handoff/     original handoff package (.gdignore'd). Can be deleted once the user is happy.
```

## Grid & map conventions
- TileSet: `tile_shape = ISOMETRIC`, `tile_layout = DIAMOND_DOWN`, `tile_size = 32×16`.
  Cell (0,0) is centred at world (16, 8); +x goes down-right on screen, +y goes down-left.
  `IsoGrid.cell_to_world()` / `world_to_cell()` match `TileMapLayer.map_to_local()` / `local_to_map()`
  as long as the layers sit at the map origin.
- Map scene layout (`DungeonMap`):
  `Ambient` (CanvasModulate, 0.34/0.36/0.50) · `Floor` (TileMapLayer) · `World` (y-sort) →
  `Walls` (TileMapLayer, y-sort), `Entities` (y-sort, markers/actors), `Decor` (y-sort, decoration sprites) · `Camera`.
- **dungeon_tileset.tres**: source 0 "Floor" (32×16): row 0 = 8 floor variants, row 1 = 8 dark-floor
  variants (doorways). Source 1 "Walls" (32×56, `texture_origin (0,20)`): row 0 = lit lower-left face
  (for back-right wall runs, along +x), row 1 = darker lower-right face (back-left runs, along +y),
  row 2 = both faces (pillars/outside corners), row 3 = cap only (back corner). 4 variants each.
  Custom data: `blocks_move` (bool), `kind` (String).
- Doorway = dark floor tile in the wall run + a `Door` marker on it.
- Markers (`MapMarker`, `@tool`) snap to cell centres while dragged in the editor and draw a coloured
  diamond + label, in the editor only. `Torch` sits on a **wall** cell and snaps to the middle of the
  bottom edge of its chosen face (so it y-sorts in front of that wall).
- `tools/godot/build_*.gd` overwrite their outputs. Once the user hand-edits the TileSet or maps,
  don't re-run them (or change them to merge).

## Art specs (user-made and generated assets must match)
- Characters **16×24 px** (14×22 drawn + 1px outline), feet at bottom centre. Sprite offset in maps: (-8, -22).
- Floor tiles **32×16** diamonds. Wall blocks 32 wide with **40 px** faces (texture 32×56). Lit face =
  lower-left (brightness 0.62), darker = lower-right (0.44).
- Monsters e.g. Eye Tyrant 32×32 floating, offset (-16, -33). Sheet rows: idle(8), blink(6),
  attack(6), hurt(4), death(9), 32×32 cells.
- Effects: fireball 16×16 × 6 frames, explosion 32×32 × 7 frames.
- PNG with transparency. Filter Nearest (project default), no mipmaps (import default).
- Sounds: WAV 44.1 kHz 16-bit mono, or OGG.

### Palettes
- Floor: (22,20,26) (38,36,44) (54,52,60) (72,69,76) (92,88,94) (114,108,112)
- Bricks: (26,24,30) (46,43,50) (64,60,66) (84,78,82) (106,98,98) (128,118,114)
- Fire: (110,20,10) (200,50,20) (255,130,30) (255,210,80) (255,250,200)
- Sprite outline (20,16,24). Hero palette = the `P` dict in `tools/python/make_iso_party.py`
  (`gen_art.gd` parses the palette and pixel grids from that file).
- Lighting: cool dim ambient ≈(0.34, 0.36, 0.50) + warm torch light (1.0, 0.68, 0.36), radius ~120 px,
  ellipse squashed 1.6× vertically, falloff (1-d/R)^1.6, gentle flicker.

## Look to reproduce (from the mock-ups)
- Iso room: stone brick back walls, doorway, wall torches with flicker + warm light (PointLight2D),
  corner spider web, bones, treasure chest. Soft elliptical shadows under figures and chests.
- Combat UI: bottom panel with 4 portraits, HP bars, spell-slot pips (Cleric 4, Mage 4), action menu
  (Attack / Spell / Item / Wait), combat log top-right, "X'S TURN" top-left.
- Tactical overlays: blue = move range, pulsing orange = spell area (Fireball 3×3), yellow = active hero.
- Fireball: staff gem charges with spiralling sparks → arcing projectile with ember trail that lights
  the room → main blast + 8 delayed bursts on the 3×3 → floor flash, screen shake, floating damage
  number → scorch mark stays → monster hurt/death animation → smoke wisps.
- Dice: time freezes before impact, room dims with a spotlight on the target, left panel shows the
  d20 save (purple d20, "9 + 2 = 11 vs DC 15", "FAILED!"), then 8d6 (red d6s dropping in, running
  total, "31 FIRE DAMAGE"). Clack sound per landing. Rolls are really random. Setting: full animation
  / quick / off (full maybe only for crits & bosses).
- Rules example: Fireball = 8d6 fire, DEX save vs spell DC (DC 15 = 8 + prof 3 + INT 4), full damage
  on a fail, half on a success. Eye Tyrant DEX +2.

## Roadmap
- [x] **Phase 0 — Setup:** project settings for pixel art, folder structure, this file, iso TileSet
  (floor, walls, doorway), marker scenes (party start, monster spawn, chest, torch, door, trap),
  assets brought in, test room. *Open: git commit + GitHub repo (ask the user).*
- [ ] **Phase 1 — Walking around:** iso map, camera, click-to-move with pathfinding (AStarGrid2D),
  y-sorting/depth, torch lighting, shadows under figures.
- [ ] **Phase 2 — Combat:** exploration → combat switch, initiative, move + action, d20 vs AC, damage,
  HP/death, simple monster AI, combat UI, damage numbers.
- [ ] **Phase 3 — Spells & abilities:** data-driven (Resources); targeting (single, 3×3, line, cone,
  self, ally); spell slots, rests. Mage: Fireball, Magic Missile, Shield. Cleric: Cure Wounds, Bless,
  Sacred Flame. Rogue: Sneak Attack, Hide. Fighter: Second Wind, Shove. VFX + SFX hooks.
- [ ] **Phase 4 — Items:** chests, loot, gold, inventory, equipment changing stats, potions, scrolls, keys.
- [ ] **Phase 5 — Progression:** XP, levels 1–5, SRD class features, character sheet.
- [ ] **Phase 6 — Dungeon features:** doors/locks/keys, traps (Rogue detect/disarm), secret walls,
  levers, room descriptions, triggers, level transitions, more monsters.
- [ ] **Phase 7 — Story:** quests, NPCs, dialogue, lore notes.
- [ ] **Phase 8 — Wrapper:** title screen, save/load, settings, music, mixing, game over/victory.
- [ ] **Phase 9 — Polish & release:** balance, bugs, juice, export builds (Windows/Mac/Linux, itch.io).
- **First milestone (after phases 0–3):** one user-built dungeon, 4 heroes, 2–3 monster types,
  Fireball + healing + melee working, playable start to finish.

Biggest art job still ahead: heroes need **4 facing directions** and idle/walk/attack/cast/hurt/death
animations. `DungeonMap.preview_actors` (static sprites at the markers) is a Phase 0 stand-in, to be
replaced by real actors in Phase 1.

## Story pitch (optional, not chosen)
"The Weaver's Deep": an apprentice's master vanished in the silver mines beneath Harrowmere, which
broke into sealed, web-choked halls. Levels: Collapsed Mine → Webbed Galleries (spiders, cocooned
miners, the first Eye Tyrant) → Sealed Observatory (an ancient wizard's tower built downward). Twist:
the master broke the seal on purpose; the Eye Tyrants were guards keeping something worse locked in.
(Written for a solo wizard; adapt for a party of four.)
