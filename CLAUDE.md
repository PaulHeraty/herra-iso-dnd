# herra-iso-dnd (Herra D&D) — design document & project guide

An isometric, grid-based, turn-based dungeon RPG with pixel-art graphics and retro synthesized audio,
made in **Godot 4.7.2** (GDScript). The player controls a party of four (**Fighter, Rogue, Cleric,
Mage**) using simplified D&D 5e-style rules from the freely licensed SRD. Dungeons, treasure,
monsters, spells, items and character progression.

**Roles:** the user (Paul) designs and builds the maps in the Godot editor, may import some graphics
and sounds of his own, and playtests. Claude writes the code and generates the art and audio the user
doesn't supply.

## Modules (adventures) — the game's structure
The game is a series of **modules** (adventures) for the same party of four, meant to take them from
level 1 to about 20. A module is one folder, `modules/<id>/`:
- `module.gd` extends `AdventureModule` (`scripts/game/adventure_module.gd`): title, tagline,
  description, `level_min`..`level_max` (the party levels it can be **started** at), `level_end`,
  `start_map` / `start_entry`, `intro_pages` (typed out before the first map), `epilogue`, the quest
  (`quest_title`, `quest_giver`, `quest_where`, `reward_gold`, `reward_item`, `quest_stages`), the
  Rune of Return's `portal_home_map`, `module_items` (left behind when the party moves on; keys always
  are), `side_quests`, `quest_hint`, `new_party_kit` + `new_party_gold` (a brand-new party may start a
  later module at `level_min` with this gear: the start screen's quick start), and hooks
  (`on_start(map)`: a fresh story begins, e.g. the main quest given at once; `npc_talk(map, npc)`).
- `maps/` its map scenes; `build_maps.gd` its map data, built with the shared `tools/godot/map_builder.gd`
  (`MapBuilder`); `story/` its own scripts (e.g. `trader_talk.gd`).
- Everything else is shared by all modules: the engine (`scripts/`), rules data (`data/`: heroes,
  monsters, items, spells), art and sounds (`assets/`).
- `Modules` (`scripts/game/modules.gd`) finds the folders; `Modules.current` is the one being played
  (set by the start screen or a loaded save; a map run on its own from the editor picks its owner).
  Quest, RunePortal, the quest log, the victory screen read the current module.
- **Roster** (`scripts/game/roster.gd`, `user://parties/<id>.party`): finishing a module (victory
  screen → "Finish adventure") keeps the party: each hero's level, XP, equipment; the bag (minus keys
  + module items); party XP; the modules done. The start screen offers these parties for a new
  adventure; they start it rested, with no quest. Save games (F5 quick / F6 slots / F9 load) store the module id.
- **Levels:** `Progression` covers 1-9 (MAX_LEVEL). A module past 9 needs it extended first (XP,
  slots, class features at 10+, 6th-level spells).
- **Quests:** the main quest (module quest_*) + side quests (Quest.side, given by NPCs), story flags
  (Quest.flags: set by puzzles (`Puzzle.flag`), NPC talks, `met_<npc_id>`), stage kinds map / item / kill
  / flag / claim, optional stage `xp` (5e milestone XP: monsters alone don't carry a party 5 -> 9).
- **The Rune of Return** goes on with the party; each module's trader binds it (`RunePortal.bound`).
- Module 1: `modules/wraith_below/` "The Wraith Below" (start level 1, ends ~5).
- Module 2: `modules/frost_spire/` "The Frost Spire" (start level 5-6, ends ~9): the Frostfell (snow
  lands: three beacons = an ALL_ON puzzle that melts an ICE ward into the hidden vale; a young white
  dragon; Hilde's camp: shop, rune binding, two side quests) and the Rimecaller's tower (five floors:
  lever orrery vault, Tamsin's cell + block puzzle, ring of frost fires + the Sunfire Lantern, the Star
  Key, a riddle mask + secret hoard, Morvaine the Rimecaller). XP: ~174000 over the module
  (maps 133000 + quest stages 41000): level 6 early in the tower, 7 by the laboratory, 8 in the chapel,
  9 at the Rimecaller.

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
| Party level | The party starts at **level 1** in the woods and reaches **5** by the last floor (Phase 5). Data files hold level-1 stat blocks; `Progression` grows them. Each map has `start_level` for playing it on its own. |
| XP | SRD thresholds (300 / 900 / 2700 / 6500 per hero); a fight's XP is split between the heroes who aren't dead; level-ups happen right after the fight (fixed average HP, "LEVEL UP!" box + fanfare). |
| Campaign (module 1) | `modules/wraith_below/`: `surface.tscn` "The Harrow Woods" (first map, after the intro; L1→2) → mine entrance → 5 floors: Upper Halls (L2→3), Webbed Deep (L3, Eye Tyrant), Goblin Warrens (L3→4), Sunken Crypts (L4), Sealed Vault (L4→5, the **Wraith**). All built by `modules/wraith_below/build_maps.gd`; it prints each map's XP (total ~31,200 incl. disarmed traps, solved puzzles + the ambushers). |
| Combat start | A monster with **line of sight** to a hero within its sight range (~8 cells) starts combat; its whole `group_id` joins. Walls block sight. |
| UI font | **Our own** generated bitmap pixel font (no third-party font). |
| Monsters | Eye Tyrant + **Giant Spider** (SRD), Phase 2; **Skeleton** (SRD: shortsword/shortbow, vulnerable to bludgeoning) added with the first dungeon. |
| Maps | Generated by each module's `build_maps.gd` with `MapBuilder` (`tools/godot/map_builder.gd`) (`-- surface dungeon_3` rebuilds only those). Floors: rooms on a slot grid (SLOT 15×13), links = corridors with an arch + door, contents placed from `spawn` letters, `theme`, `chests`. Woods: clearings + 2-wide dirt paths, everything else forest blocks (cliff blocks in `cliffs` zones). A starting point for the user to rework; don't rebuild a map once it's hand-edited. |
| Monsters (Phase 5) | SRD: Giant Rat, Wolf, Goblin, Goblin Boss, Bandit, Zombie, Ghoul, Ghast, Hobgoblin, Bugbear, Ogre, Wight, Mummy, Specter, **Wraith** (final boss). Traits in `CreatureStats.traits`: pack_tactics, martial_advantage, undead_fortitude, resist_nonmagical, turn_resistance; attack riders can add conditions (wolf prone, ghoul paralyzed). Multiattack = `extra_attacks` for monsters too. |
| Levels 6-9 (module 2) | XP 14000 / 23000 / 34000 / 48000; prof +3 (5-8), +4 (9); full-caster slots to 4/3/3/3/1. Fighter: ASI CON (6) + STR (8), Remarkable Athlete (7, half prof on untrained STR/DEX/CON checks + initiative), Indomitable (9, auto: reroll one failed save per long rest, `CombatManager.save_vs`). Rogue: Expertise athletics + thieves' tools (6), Evasion (7, area DEX saves: 0 / half), Sneak 4d6 / 5d6, Supreme Sneak (9, Hide with advantage). Cleric: Channel Divinity x2 + Blessed Healer (6), Death Ward (7, condition `death_ward`), Divine Strike 1d8 + Destroy Undead CR 1 (8), Mass Cure Wounds (9). Mage: Lightning Bolt (6), Ice Storm (7, 3x3, 2d8+4d6 counted as cold), Hold Person (8), Cone of Cold (9). Per-level uses: `Progression.uses_of`. |
| Monsters (module 2) | SRD: Winter Wolf (cold breath, prone bite), Polar Bear, Ice Mephit (death burst, frost breath), Troll (`regeneration`: 10 HP a turn unless fire/acid hurt it), Young White Dragon (cold breath 10d8), Animated Armor, Flying Sword, Gargoyle, Flesh Golem (`immune_nonmagical`, `magic_resistance`: advantage on saves vs spells), Mage (Fire Bolt, a Fireball, a Hold Person), Mimic (a Chest with `mimic`: opening it wakes the monster; passive Perception DC 15 spots it). Our own boss: Morvaine the Rimecaller (built on the SRD Archmage). Monster damage powers (breaths, Fireball, Cone of Cold) are chosen by expected damage over everyone in the shape (`_damage_power_value`). |
| Gear on heroes | Armour, main weapon, ranged weapon (shoot frames: bow or crossbow, any hero; throw frames: a handaxe), shield and **cloak** show on the sprites; rings, amulets etc. don't. `HeroLook` (`scripts/actors/hero_look.gd`) builds each hero's walk + action sheets at runtime from `HeroDrawings` (the walk-sheet grids) + the gear, cached per outfit (~40 ms each); `Hero.refresh_stats()` rebuilds. Armour = the drawing's armour pixels restyled per part (torso / arms / legs: leather, studded, chain, scale (bronze), plate, lames; plate-type armour also covers the Fighter's tabard top + the Cleric's robe front); magic armour = recoloured per its description + a thin moving gleam. Each weapon kind has its own shape. Effects overlay (`scripts/fx/hero_fx.gdshader`, additive, its own sheet: R main weapon, G armour/shield glint, B ranged): +1 shimmer, +2 glow, Flame Tongue fire, Frost Brand mist, Mace of Disruption radiant; fire/frost/radiant also carry a PointLight2D. Preview: `tools/godot/preview_hero_looks.gd -- <png> fighter|others|catalog`. The intro shows the party in its gear too (HeroLook + the overlay). The static `<hero>_sheet.png` / `_actions.png` stay for the tools. |
| Ambushes + lore (Phase 6) | `Trigger` marker (area like a RoomNote): the first time the party walks in, the MonsterSpawns whose `ambush` is its `link` appear (they don't exist or block anything before: `MonsterSpawn.lurking()`; `how` = step out / rise out of the floor / drop from above, `DungeonMap.wake_ambusher`) and the fight starts (or they join one); `seal` = the open portcullises with that link slam shut behind the party (then it waits until the **whole** party is inside) and rise again when every ambusher is dead (`Mechanisms.after_combat`). `LoreNote` (book on a lectern / stone tablet / a dead adventurer's pack, blocks its cell, twinkles until read): click = read it in the dialogue box (which grows to fit long text); kept in the **journal** (`Quest.lore`, saved with the story; quest log J 'Journal' page). Builder: room `ambush` / `lore`, link `{seal = name}`. Module 1: the Lords' Vault guardians (animated armour, the vault gate drops again), spiders dropping in the Silk Gallery, zombies rising in the Drowned Crypt, gargoyles on the sealed Treasure Vault, a mimic in the Forgotten Crypt, 9 lore notes (woods + every floor). |
| Items (module 2) | WONDROUS kind in two **Worn** slots (`worn1`/`worn2`): Cloak of Protection, Amulet of Health / Gauntlets of Ogre Power / Headband of Intellect (`ability_set`: score raised to 19 before the level's maths), Bracers of Defense (`ac_unarmored`). Frost Brand (+1d6 cold, resist fire: a main-hand weapon's `resistances` count), +2 armour/weapons, rings of Warmth / fire / lightning resistance, Potion of Supreme Healing, scrolls up to 5th level, Rime Key, Star Key, the Sunfire Lantern (quest item, can't be sold). |
| Doors (module 2) | `Door.Style.ICE`: a wall of magic ice (blocks moving + sight), melted only by its `link` (the beacons). Npc `show_flag` / `hide_flag` (story flags), `guard_monster` (hide only from that monster: Hilde and the dragon), `calls_party`. |
| Doors | Click to walk up and open. Locked: Rogue picks (thieves' tools DEX vs `lock_dc`), else strongest hero forces (Athletics vs DC+2); retry allowed. In combat: open = free once a turn, pick = your action. Monsters don't open doors. |
| Stairs / floors | `Stairs` marker -> `target_map` + `target_entry` (a PartyStart `entry_id`). Outside combat only. Party HP/slots/uses/hit dice carry over (`PartyState`); each map remembers open doors, dead monsters, opened chests (`MapState`; written to disk by save games). R after a wipe restarts the current floor as the party arrived. |
| Save / load | **F5** = quick save (straight to `user://saves/quick-save.sav`, overwritten each time, no screen; `SaveGame.QUICK` = slot 0), **F6** = save screen with **3 named slots** (`user://saves/slot<N>.sav`), **F9** = load (the quick save + the 3 slots; also the start screen's Load game). At most 4 files on disk. Binary `store_var`, no objects. Name typed or left blank = `save001`, `save002`... (one more than the highest number in any slot). Saving: exploring only (not in combat, talking, or after a wipe). Loading: any time, also from the game-over screen. A save = PartyState + every map's MapState (current one as it is now) + each hero's cell/facing + view rotation; loading arrives with `MapState.next_entry = AT_SAVE`. Saving doesn't move the R-restart point; after a load, R restarts from the load. The screen pauses the game. |
| Fog of war | On by default (`DungeonMap.fog_of_war`). Unexplored = not drawn (black); explored but out of sight = dimmed, its monsters hidden (combatants in a fight stay visible). Sight = shadowcasting 12 cells from each conscious hero, walls + closed doors block. No pathing, moving or aiming into unexplored cells. Explored cells kept per map in MapState. |
| Fireball area | **3×3** like the mock-up (simplified from the SRD 20-ft sphere); 8d6 fire, DEX save half. |
| Reactions | **Prompt the player** (e.g. "Cast Shield?") when a reaction could change the outcome. |
| Hero at 0 HP | **5e death saves** (3 successes stabilise, 3 failures = dead); any healing revives. |
| Dice scene | Full animation for **big moments** (Fireball/area spells, crits, bosses); quick inline rolls otherwise; setting full / quick / off. |
| Trader + quest | **Brannoc** (`Npc`) at his stall in the mine clearing hides until the goblins within `guard_radius` are dead, then calls the party over: quest **"The Wraith Below"** (`Quest`: stages = maps reached, keys found, Eye Tyrant + Wraith killed; a later stage ticks off the earlier ones), reward 3000 gold + Ring of Protection, and the **Rune of Return**. Shop: buys at `value_gp`, sells at half (not keys/rune). Quest log = Quest button / J. |
| Rune of Return | Endless. Used from the Bag anywhere but the woods (not in combat): a portal opens next to the party; through it = the stall (`PartyStart` `portal`); the stall's portal leads back to that exact cell, then closes. One portal at a time (`RunePortal`). |
| Start screen / win | Main scene `scenes/intro.tscn` (`Intro`, `scripts/ui/intro.gd`): **Herrasoft** splash -> **HerraDnD** title (two torches) -> menu (New adventure / Load game / Quit) -> choose a party (new level 1, or a Roster party; skipped when there are none) -> choose an adventure (modules whose level range fits the party; others greyed) -> the module's typed story pages over the four heroes -> its first map fades in (`DungeonMap.fade_from_black`). Click/Space = skip ahead, Esc = to the menu / back / (story) straight in. `Intro.begin(module, party)` sets up a new adventure. Win: Brannoc's reward line -> "Farewell" -> `VictoryScreen` (pauses; heroes in the cast pose, time played (`PartyState.play_seconds`, saved), monsters slain, gold, party XP; Keep exploring / Finish adventure = party to the Roster, back to the start screen). Sounds `logo_chime`, `victory_fanfare`. |
| Traps (Phase 6) | `Trap` marker: spikes, darts (attack roll), fire vent (3×3, save half), pit (one-shot), alarm tripwire (the nearest monster group comes running). Hidden until spotted: each conscious hero's **passive Perception** vs `detect_dc` when in sight within 4 cells, or **Search (F / button)**: everyone rolls Perception or Investigation (best), checked against hidden traps + secret doors in sight within 5 cells; unlimited. Walking onto an armed **unspotted** trap sets it off (walk stops). A **known armed trap blocks the party's paths** (A* + combat reach; monsters walk over their own traps); click it = walk up and disarm (the Rogue: thieves' tools vs `disarm_dc`; else best DEX; fail by 5+ = it goes off; retry allowed; in combat = the action). Disarming gives `xp`. Exploring, trap damage can't kill (knocked out → 1 HP after 2 s, like after a won fight). |
| Secret doors / portcullis | `Door.style`: SECRET draws the wall block its place would show (until found by passive Perception / Search vs `secret_dc`, then a glinting seam; opened by hand or its `link`); PORTCULLIS = bars (blocks moving, **not sight**), raised only by its mechanism. |
| Puzzles (Phase 6) | Wiring by `link` strings (`Mechanisms`): Lever / PressurePlate / linked Brazier / pushable block belong to the `Puzzle` with that link; a solved puzzle opens the doors whose link is its `opens` and stays solved. Kinds: SEQUENCE (levers by symbol, wrong = all spring back + dart penalty), ALL_ON (plates pressed by heroes/monsters/blocks, levers down, braziers lit), RING (Lights-Out on a ring of braziers: one flips its 2 neighbours). Without a Puzzle, a lever / plate drives its doors directly (plate = held open while pressed). `StoneFace` = riddle in the dialogue box (wrong = lightning). Blocks: click = push one cell away from the leader (who steps after it); a reset lever puts them back. Every puzzle guards **optional** treasure, never the way on. Solving gives XP. |
| Room descriptions | `RoomNote` over each room (builder `name` + `desc`): caption box + log the first time a hero walks in (and on arrival); `clue` = modal (dialogue box) for inscriptions / puzzle rules. Seen notes are remembered. |
| Maps (minimap / M) | Minimap top-left (`MiniMap`, - / + buttons or wheel zoom, click = full map; follows the leader); full map on **M** (`MapScreen`: fitted to the explored area, wheel / - + zoom, drag pan, Space = party, M / Esc closes; also in combat). Both honour the fog (unexplored hidden, out of sight dimmed, monsters only while seen) and the view rotation. The combat banner/hint sit right of the minimap (`CombatHud.TEXT_X`). |
| Help mode | On by default. `HelpBox.tip(id, focus)` (`scripts/ui/help_box.gd`, texts in `help_topics.gd` `HelpTopics.TOPICS`): the first time something new happens a box explains it, once ever (first fight: initiative, turns, actions, hitting; a hero at 0 HP: death saves + healing; conditions, concentration, reactions, spells menu, traps spotted / sprung, locks, chests, secret doors, puzzles, riddles, lore, ambushes, talking, trading, quests, the rune, stairs, level-ups, first turn of each class). First map: a tour (party panel, buttons, minimap, then the inventory and the character sheet section by section, opened by the tour). The box pauses the tree **and** sets `Engine.time_scale = 0` (fight timers wait), frames its area (`at` rect, or "focus" = the rect / Control passed) and dims the rest. Calm tips wait for exploring with no screen open. "Help off" button on every box; **F1** = help menu (read any topic, tips on/off, show all again). Kept in `user://settings.cfg` [help] enabled + seen. Off (and never written) for `-s` scripts, HERRA_AUTO_REACT, headless; `HERRA_HELP=1` = on without the file (screenshots). |

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
- **Windowed runs (tests, screenshots, dev checks) go through `tools/run_godot.sh [-t secs] <godot args>`**: 60 s default limit, closes Godot 4 s after a SCRIPT ERROR, and closes any game window the run left (never the editor). Bare `timeout 300` left windows on the user's screen for minutes after a script error or a stopped run.
- Screenshot check: run a SceneTree script **without** `--headless` that loads a scene, waits ~30
  frames, and saves `root.get_texture().get_image()` (keep such scripts in the scratchpad).
- Python is **not installed** (as of 2026-11-04). The Python generators in `tools/python/` need
  Python 3 + Pillow + numpy (+ ffmpeg for videos). The Phase 0 art was ported to GDScript generators
  in `tools/godot/`, which need nothing but Godot.

## Project layout
```
assets/
  tiles/      floor_atlas.png, wall_atlas.png, dungeon_tileset.tres; outdoor_floor_atlas.png, cliff_atlas.png,
              forest_atlas.png, outdoor_tileset.tres (same layout: 0 ground, 1 cliffs, 2 forest)   (generated)
  sprites/    heroes/ (walk sheets 16×24, action sheets 32×32, face portraits 32×32 `<hero>_portrait.png`), monsters/ (Eye Tyrant), npcs/ (trader_sheet 16x24: idle, idle, talk), props/ (chest, chest_open, bones, torch_sheet, web, stairs_up/down, barrel, crate, sarcophagus, rubble, cocoon, urn, brazier, stall, portal_sheet 8x24x40; Phase 6: trap_* (armed + sprung, flat 34x18 at (-17,-9)), plate(_down), lever_up/down (24x34 at (-12,-27)), block (28x34 at (-14,-27)), stone_face (28x44 at (-14,-36)), lore_book / lore_tablet (24x34 at (-12,-27)), lore_remains (flat 34x18 at (-17,-9)))
  effects/    fireball_sheet.png (6×16px), explosion_sheet.png (7×32px)
  fonts/      herra_pixel.fnt/.png: our pixel font (use size 10; scale the Control 2x/3x for big text)
  sfx/        13 WAVs from the concept session (torch_ambience imports as a forward loop) + generated ones (gen_sfx.gd)
  ui/         condition_icons.png (gen_icons.gd), item_icons.png (16x16 per item, columns = ItemData.ICON_ORDER; row 0 plain, row 1 = magic glimmer (ItemData.is_magic); gen_item_art.gd)
scenes/
  maps/       map_template.tscn (copy this for new maps), test_room.tscn (the campaign maps live in modules/<id>/maps/)
  markers/    party_start, monster_spawn, chest, torch, door, trap, prop, brazier, stairs, npc, portal (.tscn)
  actors/     hero.tscn (Actor/Hero; spawned by DungeonMap at PartyStart), monsters/<monster_id>.tscn (Monster)
scripts/
  iso_grid.gd           IsoGrid: cell <-> world maths, view rotation
  maps/dungeon_map.gd   DungeonMap: root script of every map (walk grid/A*, view rotation, spawns party + overlay + controllers)
  maps/grid_overlay.gd  GridOverlay: unlit tinted floor diamonds (cursor, path, later ranges/areas)
  maps/camera_controller.gd  CameraController: follow leader, WASD/arrows + middle-drag pan, wheel zoom 1-3x, Space recentres, clamped to map
  maps/wall_fader.gd    WallFader: walls in front of a hero or revealed overlay cell fade to 55% (runtime alternative tiles 101-104)
  party/party_controller.gd  PartyController: exploration click-to-move, trail-follow, camera follow
  party/rest.gd         Rest: short (hit dice, short-rest powers) / long (everything) rests; blocked near enemies
  party/party_state.gd  PartyState: hero HP/slots/uses/hit dice carried between maps (static)
  maps/map_state.gd     MapState: per-map memory (open doors, dead spawns, opened chests) + the entry to use (static)
  maps/fog_of_war.gd    FogOfWar: explored + visible cells (shadowcasting); DungeonMap draws/dims/hides by it
  maps/mechanisms.gd    Mechanisms (map.mech, Phase 6): traps (spot / spring / disarm), Search, secret doors, levers,
                        plates, puzzles (fire(link) opens doors), pushable blocks, the riddle face, room notes; thing_under /
                        approach_cells / interact for PartyController + CombatManager; after_party_step / after_combat_step
  markers/              ... + trap, lever, pressure_plate, puzzle (invisible rules), stone_face (riddle), room_note (area text),
                        trigger (ambush: hidden monsters appear, a portcullis may seal the room), lore_note (something to read);
                        MapMarker.save_state() / load_state() = per-marker state kept by MapState (`marks`) and save games
  maps/map_picture.gd  MapPicture: the map as an Image, 1 px per cell (tile average colour, fog: transparent / dimmed / lit),
                        redrawn only where the fog changed; DungeonMap.map_picture, marked dirty by _refresh_fog_look
  markers/              MapMarker base + one script per marker
  actors/               Actor base (grid cell, shadow, step tween) + Hero + Monster (stats, named sheet anims);
                        hero_look.gd HeroLook (sheets built from the gear + the effects sheet), hero_drawings.gd HeroDrawings (hero pixel grids)
  fx/hero_fx.gdshader   magic gear overlay on heroes (shimmer, glow, fire, frost, radiant, armour gleam)
  rules/progression.gd  Progression: levels 1-5 (XP table, HP, slots, ASI, powers by level, class numbers)
  rules/                Dice + DiceRoll (really random, seedable), CreatureStats + AttackData (stat-block Resources),
                        SpellData (spell/ability/monster power), Condition (blessed, prone, restrained, hidden,
                        frightened, shielded: durations + their effects on attacks/saves/AC)
  combat/combat_manager.gd  CombatManager: LOS detection -> combat, initiative, turns, movement, attacks (d20 vs AC, crits, riders, resist), apply_damage (concentration saves, death saves,
                        massive damage), Shield reaction prompt, monster AI (expected-damage plan; groups that see the party join mid-fight) (DungeonMap.combat_reach: 1 sq per step incl. diagonals; one creature per square: nobody passes through or stops on anyone, downed heroes included, the dead not; `DungeonMap.occupant()`)
  ui/combat_hud.gd      CombatHud: mock-up combat UI (turn banner, hint, next turns, colour log; hero cards + action menu,
                        Spell/Ability + weapon popups; exploration: rest buttons, Bag (I), gold)
  ui/inventory_screen.gd  InventoryScreen (I / Bag button): bag grid, the shown hero's 6 slots + stats, description box
                        with what equipping changes; click = equip / take off, drag to a slot, hero tab or the bag;
                        read-only in combat (potions: click = drink, exploring only). Hero.equip_from(bag, id) / unequip_to(bag, slot) do the moves.
  combat/targeting.gd   Targeting: area (NxN) / line / cone cells. CombatManager: menu_powers, begin_targeting,
                        resolve_power (generic: spell attack / save / auto darts+conditions / heal / contest)
  fx/                   FloatText (damage numbers), Projectile (arrow / beam), SpellFx (bolt, dart, column,
                        sparkles, burst, charge; pixel particles + PointLight2D)
  items/item_data.gd   ItemData: one item kind (weapon: AttackData + category/slot; armour: base AC, DEX cap, STR;
                       Scrolls: `spell` + the readers come from `SpellData.classes`; keys: `key_id` (Door/Chest `key_id`, lock_dc 0 = key only).
                        shield; potion heal; scroll spell; key_id; ring AC/save bonus). ItemData.get_item(id), cached
  items/equipment.gd   Equipment (static): slots, training, build_stats(base, eq) -> the hero's own CreatureStats copy.
                        Hero.base_stats = data/heroes/ file, Hero.stats = derived; Hero.equip()/unequip()
  items/inventory.gd   Inventory: the shared bag (gold, stacks), on DungeonMap.inventory; PartyState carries it
  audio/sfx.gd          Sfx.play("name"): static, self-creating player for assets/sfx/<name>.wav
  story/quest.gd        Quest (static): the current module's quest (stages + reward from Modules.current); snapshotted with the party (PartyState.story)
  story/rune_portal.gd  RunePortal (static): the Rune of Return's open portal (map + cell; home = the module's portal_home_map); DungeonMap.use_rune / take_portal
  (modules/wraith_below/story/trader_talk.gd) TraderTalk: Brannoc's lines (intro, quest, reward), his STOCK; uses CombatHud.dialogue / .shop
  ui/dialogue_box.gd    DialogueBox: portrait, name, typed line, choices (1-4, Space, Esc = goodbye); camera frames the speaker
  ui/shop_screen.gd     ShopScreen: wares list + party bag; click = pick, Buy/Sell button or double-click
  ui/quest_screen.gd    QuestScreen (J): stages done (ticked) + the current one; HUD quest_toast() on updates
  ui/character_sheet.gd CharacterSheet (C / Sheet button / right-click a hero card; also in combat, read-only): portrait,
                        level + XP, HP + hit dice, AC/init/speed/prof, abilities, saves, skills, attacks, spell slots,
                        powers + Progression.FEATURES (hover = details); rebuilds live while open
  ui/map_view.gd        MapView: draws a MapPicture through an iso transform (pixel -> diamond, view rotation) + markers
  ui/mini_map.gd        MiniMap: top-left panel, - / + zoom; ui/map_screen.gd MapScreen: the full map (M)
  game/save_game.gd     SaveGame (static): slots, header (name, map, level, gold, time), save / prepare_load; DungeonMap.load_game(slot)
  ui/intro.gd           Intro, the start screen (scenes/intro.tscn = main scene): splash, title, menu, party + adventure choice, story pages
  game/adventure_module.gd  AdventureModule (a module's definition); game/modules.gd Modules (registry, current);
                        game/roster.gd Roster (parties kept between modules)
  ui/victory_screen.gd  VictoryScreen: the win screen after Brannoc pays for the Wraith (DungeonMap.show_victory)
  ui/save_screen.gd     SaveScreen (F5 quick save, F6 / F9): own CanvasLayer 60, pauses the tree; slot rows, name LineEdit, Save/Overwrite/Load
  ui/help_box.gd        HelpBox (help mode: tips, the tour, F1 menu; one per map, DungeonMap.help, added last), ui/help_topics.gd HelpTopics (texts + screen rects)
modules/      <id>/module.gd (AdventureModule), maps/*.tscn, build_maps.gd (map data for MapBuilder), story/*.gd (dialogue):
              wraith_below/ (module 1), frost_spire/ (module 2: frostfell + tower_1..5, hilde_talk.gd, tamsin_talk.gd)
data/         heroes/*.tres (level 1; Progression grows them to 9), monsters/*.tres: CreatureStats + AttackData; spells/*.tres: SpellData
              (spells, class abilities, monster powers) — all from tools/godot/build_data.gd;
              items/*.tres: ItemData — from tools/godot/build_items.gd
tools/
  godot/      gen_art.gd -> build_tileset.gd -> build_test_room.gd   (run in that order, import between)
              gen_hero_sheets.gd (hero walk sheets), gen_portraits.gd (hero face portraits: HUD cards 1:1, character sheet 2x; `Hero.portrait()`),
              gen_hero_actions.gd (hero action sheets, from the walk drawings),
              preview_hero_walk.gd / preview_hero_actions.gd + gif_writer.gd (GIF previews), preview_hero_looks.gd (HeroLook outfits)
              build_items.gd (items -> data/items/; hero kits in build_data.gd refer to these ids)
              build_data.gd (stat blocks -> data/), test_rules.gd (headless rules tests: PASS/FAIL)
              gen_spider.gd (procedural Giant Spider sheet: 3D-ish model projected to iso)
              gen_sfx.gd (SFX: hits, miss, bow, hurt, hiss, ray, crit, mm_zip, radiant, heal_chime, fire_impact, chest_open, coins, potion_drink, scroll_read, lightning_crack, logo_chime, victory_fanfare; Phase 6: trap_spikes/darts/fire/pit/alarm, lever, plate_click, gate_rise, stone_slide, stone_push, puzzle_solved, puzzle_fail, discover, search, flame_whoosh)
              gen_font.gd (our HerraPixel bitmap font -> assets/fonts/herra_pixel.fnt + .png)
              gen_icons.gd (9x9 condition icons -> assets/ui/condition_icons.png; order = Condition.ICON_INDEX)
              gen_item_art.gd (open chest + item icons; weapons drawn along the diagonal from code)
              gen_trader_art.gd (Brannoc, his stall, the portal sheet), test_story.gd (trader, quest, shop, rune portal: PASS/FAIL; run without --headless), test_save.gd (save / load + the slot screen; writes user://test_saves only)
              gen_puzzle_art.gd (traps armed/sprung, pressure plate up/down, lever up/down, pushable block, stone face,
              lectern, tablet, adventurer's remains),
              test_modules.gd (modules, start screen, Roster, saves with a module; writes user://test_parties + test_saves),
              test_frost.gd (module 2: beacons + ward, Hilde, side quests, rune binding, mimic, the tower's puzzles, levels 6-9 rules,
              troll regeneration, breath AI, the ending: PASS/FAIL; run without --headless, HERRA_AUTO_REACT=1, -t 200),
              gen_frost_art.gd (module 2: snow + tower tilesets by palette remapping, snow props, the spire, the ice ward,
              bookshelf / alchemy table / frost crystal, Hilde + Tamsin; run, --import, run again for the tilesets),
              test_puzzles.gd (Phase 6: traps, Search, secret doors, levers, blocks, ring, riddle, notes, ambushes, lore, MapState: PASS/FAIL;
              run without --headless, HERRA_AUTO_REACT=1, -t 150),
              gen_dungeon_art.gd (stairs + props), gen_skeleton.gd (Skeleton sheet), map_builder.gd (MapBuilder: builds
              map scenes from a module's descriptions; see modules/wraith_below/build_maps.gd), gen_monsters.gd (the Phase 5 monsters: sheets + scenes;
              `-- <ids>`), gen_outdoor_art.gd + build_outdoor_tileset.gd (the woods), gen_sfx.gd `-- <names>` = only those, test_dungeon.gd (doors, locks, stairs,
              state between floors: PASS/FAIL; run without --headless, HERRA_AUTO_REACT=1)
  python/     concept-session generators (reference + future art/audio work)
docs/previews/  concept mock-ups (.gdignore'd: Godot does not import them)
_handoff/     original handoff package (.gdignore'd). Can be deleted once the user is happy.
```

## Grid & map conventions
- TileSet: `tile_shape = ISOMETRIC`, `tile_layout = DIAMOND_DOWN`, `tile_size = 32×16`.
  Cell (0,0) is centred at world (16, 8); +x goes down-right on screen, +y goes down-left.
  `IsoGrid.view_cell_to_world()` / `view_world_to_cell()` match `TileMapLayer.map_to_local()` /
  `local_to_map()` as long as the layers sit at the map origin.
- **View rotation (Q/E, quarter turns):** game logic always uses *map* cells (as painted). At runtime
  the painted `Floor`/`Walls` layers are hidden and `FloorView`/`WallsView` show the map turned by
  `IsoGrid.rotation` around `IsoGrid.pivot`. `IsoGrid.cell_to_world()` / `world_to_cell()` convert
  map cells through the rotation; use them for anything placed by cell. Turned views auto-pick wall
  rows from exposed faces; the unturned view uses the painted tiles as-is. Markers lock their map
  cell at start (`MapMarker.lock_cell`) and re-place in `apply_view()` (Torch moves to its face, hides
  its flame on back faces; Door turns its panel). Decor sprites in group `wall_decor` (webs) hide when turned.
- **Lights on big maps:** a 2D canvas item only takes a limited number of lights, so the visible
  FloorView/WallsView use `rendering_quadrant_size = 4` (DungeonMap.LIGHT_CHUNK). With the default 16,
  rooms on a 40-torch map went dark.
- Fog dimming reuses WallFader's runtime tile alternatives: DIM_BASE+k (200-204) = dimmed (+faded) for
  every tile of every source, so the floor's dimmed variant is alternative 200.
- Props (`Prop` marker: barrel, crate, sarcophagus, rubble, cocoon, urn) and `Brazier` (free-standing
  Torch) block movement, not sight. Bones/webs are Decor sprites (walkable).
- **Front walls hide the last two rows/columns of a room** (the +x / +y sides in the unturned view):
  a 40 px block covers anything on the cells just behind it. Put things the player must see (chests,
  puzzle pieces) at least 3 cells from the +x / +y walls. As a backstop, walls fade (WallFader) in
  front of known traps and puzzle pieces in sight (`Mechanisms.pieces`), and a known trap shows a red
  warning sign drawn above the walls.
- Flat floor markers (Trap, PressurePlate) sit 9 px up from their cell centre (`SORT_UP`) so they
  y-sort under anyone on their own or neighbouring cells; they draw at -SORT_UP.
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
  bottom edge of its chosen face (so it y-sorts in front of that wall). At runtime its flame is
  unshaded (fire palette shows as drawn, warm-tinted) with a small additive glow halo; the
  PointLight2D (240×150 radial gradient ≈ (1-d/R)^1.6, energy 1.25) reproduces the mock-up's
  lighting model — checked by sampling against `iso_scene.png` with the mock-up's torch layout.
- `tools/godot/build_*.gd` overwrite their outputs. Once the user hand-edits the TileSet or maps,
  don't re-run them (or change them to merge).

## Art specs (user-made and generated assets must match)
- Characters **16×24 px** (14×22 drawn + 1px outline), feet at bottom centre. Sprite offset in maps: (-8, -22).
- Hero **walk sheets** `assets/sprites/heroes/<hero>_sheet.png` (80×48): 5 cols (idle, walk A, pass,
  walk B, pass) × 2 rows (0 = front 3/4 facing screen down-left, 1 = back 3/4 facing up-left);
  right-facing = mirrored. Drawn as text pixel grids in `tools/godot/gen_hero_sheets.gd` (upper body +
  standing legs; walk = alternate leg lifted 1px, robes: feet tuck under + hem sways). Preview:
  `tools/godot/preview_hero_walk.gd` → GIF. Walk feel may be revisited later (user: "fine for now").
  `Actor` keeps its facing in map cells and picks row/mirror for the current view rotation.
- In the game the hero sheets come from `HeroLook` (same rig + poses as gen_hero_actions.gd, drawings from `HeroDrawings`, which gen_hero_sheets.gd also uses): walk sheet 160×64 with **32×32** cells (offset (-16, -30) like the action sheet), action sheet 512×64. The files below are the static default-kit versions.
- Hero **action sheets** `assets/sprites/heroes/<hero>_actions.png` (512×64): **32×32** cells (the
  16×24 figure cell sits at (8, 8); sprite offset (-16, -30)), 16 cols × 2 rows (front / back):
  attack 0-3 (wind-up, strike + swoosh, follow-through, recover), shoot 4-6 (Rogue bow; others copy
  the wind-up), cast 7-10 (raise + 3 looping glow frames), hurt 11-12, down 13-15 (kneel, slump,
  lying). HeroLook's runtime action sheets add throw 16-18 (wind-up with the handaxe, release, follow-through: 608×64).
  Built by `tools/godot/gen_hero_actions.gd` from the walk-sheet drawings: a per-hero rig
  erases the weapon and redraws arm (sleeve line from the shoulder) + weapon + hand per pose, so
  changes to `gen_hero_sheets.gd` carry over (re-run both). Preview: `preview_hero_actions.gd` → GIF.
  `Hero.play_action()` swaps to the action sheet and back; `Hero.ACTION_ANIMS` must match the columns.
  Combat: melee = attack, ranged = shoot (any bow or crossbow) / throw (a handaxe, which tumbles to the target), spells +
  Second Wind = cast (held until the power resolves; Mage/Cleric spells leave from the raised gem /
  holy symbol, `Hero.CAST_POINTS`), Shove = attack, Shield reaction = a short cast, hurt on damage,
  down at 0 HP (stays lying, greyed; darker when dead).
- Floor tiles **32×16** diamonds. Wall blocks 32 wide with **40 px** faces (texture 32×56). Lit face =
  lower-left (brightness 0.62), darker = lower-right (0.44).
- Monsters e.g. Eye Tyrant 32×32 floating, offset (-16, -33). Sheet rows: idle(8), blink(6),
  attack(6), hurt(4), death(9), 32×32 cells. Giant Spider 40×32 cells (Large), offset (-20, -27), 17 cols
  (idle 2, walk 4, attack 4, hurt 2, death 5) × 2 rows (front / back 3/4). `Monster.anims` maps names to
  [row, col, count, fps, loop].
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
  assets brought in, test room, git repo on GitHub.
- [x] **Phase 1 — Walking around:** iso map, camera, click-to-move with pathfinding (AStarGrid2D),
  y-sorting/depth, torch lighting, shadows under figures. Also done: wall fading, Q/E view rotation,
  back-face torches, hero 4-facing walk sheets. Next: Phase 2 (combat).
- [x] **Phase 2 — Combat:** exploration → combat switch, initiative, move + action, d20 vs AC, damage,
  HP/death, simple monster AI, combat UI, damage numbers. Steps:
  1. Rules core: dice roller, hero + monster stat Resources in `data/` (SRD, level 5), headless tests.
  2. Monsters as actors: Eye Tyrant (existing sheet) + Giant Spider (new art), replacing previews.
  3. Combat start: line-of-sight trigger, group joins, initiative, turn order, "X'S TURN", camera.
  4. Turn movement: blue move range (30 ft = 6 cells), path preview, split move around the action.
  5. Attacks: d20 + bonus vs AC, crit on 20, damage dice, floating numbers, hurt flash, SFX, death/down.
  6. Monster AI: approach / ranged (Eye Tyrant eye ray), attack.
  7. Combat UI: portraits, HP bars, slot pips, action menu (Spell/Item greyed), combat log, pixel font.
  8. End of combat: victory -> exploration; party down -> game-over placeholder.
  Full dice-roll animation scene comes with Fireball in Phase 3.
  Done. Simplifications to revisit: downed heroes come to with 1 HP after a victory (no death saves
  yet), a hit always deals at least 1 damage (house rule), unlimited thrown weapons, Large spider takes 1 cell, Web/recharge/conditions not used,
  slot pips not spent. R restarts the map after a party wipe.
- [x] **Phase 3 — Spells & abilities:** data-driven (Resources); targeting (single, 3×3, line, cone,
  self, ally); spell slots, rests. Mage: Fireball, Magic Missile, Shield. Cleric: Cure Wounds, Bless,
  Sacred Flame. Rogue: Sneak Attack, Hide. Fighter: Second Wind, Shove. VFX + SFX hooks.
  Steps:
  1. Core: SpellData + ability Resources, slots spent (pips), bonus actions, conditions w/ durations, tests.
  2. Menus + targeting: Spell list (slot costs), class-ability menu, weapon choice; single/ally/self/
     area (pulsing orange)/line/cone with range + LOS.
  3. Simple spells: Fire Bolt, Magic Missile, Sacred Flame, Cure Wounds (+ VFX/SFX).
  4. Bless (concentration), Shield (reaction prompt), death saves + stabilise. DONE.
     + condition icons on the hero portraits (small pixel symbols instead of the text; hover shows
       the condition name + effect). User request.)
  5. Class abilities: Sneak Attack, Hide, Second Wind, Shove (prone/push). DONE (Hide: not with an
     enemy adjacent; no cover/obscurement rules yet).
  6. Fireball showcase (charge, arc, 3x3 blast + bursts, flash, shake, scorch, smoke). DONE
     (scripts/fx/fireball_fx.gd, scorch_layer.gd). User changes vs the mock-up: straight flight, one big
     3x3 blast (explosion sheet at 3x), big boom sound (fireball_boom.wav).
  7. Dice-roll scene (freeze, spotlight, d20 save panel, damage dice + clacks); full/quick/off. DONE
     (scripts/ui/dice_scene.gd + spotlight.gdshader; F2 cycles Full / Big moments / Quick / Off;
     save spells pre-roll so the scene shows the real rolls; crits show the d20 + doubled dice).
  8. Monster abilities (spider Web: restrained, recharge; Eye Tyrant fear ray) + short/long rests. DONE
     (AI scores condition powers; Recharge 5-6 rolled at turn start; "Break free" action; Rest.gd;
     the party panel stays visible while exploring, with Short/Long rest buttons).
- [x] **Phase 4 — Items:** chests, loot, gold, inventory, equipment changing stats, potions, scrolls, keys.
  Inventory model (user's choice): **one shared party bag** (gold + items) + per-hero equipment slots
  (main hand, off hand = shield, ranged, armour, 2 rings). Steps:
  1. Items core: ItemData (data/items/, tools/godot/build_items.gd: SRD weapons, armour, shield,
     potions, Ring of Protection), Inventory (bag), Equipment (base stat block + kit -> AC, attacks,
     save bonus, speed; SRD class training: no armour for the Mage, light only for the Rogue...),
     carried over the stairs (PartyState), tests. DONE.
  2. Chests: open sprite, walk up + open (locked: key from the bag, else pick / force like doors;
     exploration only), loot box + "+N gold" + coins sound, gold shown in the party panel. Chests
     in both floors now hold items (storeroom chest locked DC 12). DONE.
  3. Inventory screen (I): bag grid with generated pixel icons, hero equipment slots, equip/unequip
     (outside combat only), tooltips, training rules. DONE (scripts/ui/inventory_screen.gd; click or
     drag; hero tabs or the party cards pick the hero; Sort button; hover shows AC/attack/speed changes).
  4. Potions + the Item action in combat (drink, or feed an adjacent ally). DONE (Item menu lists the
     bag's potions; an action; targets = self or an adjacent ally that is hurt or downed (revives);
     each potion becomes a runtime heal power, `CombatManager.item_power()`. Exploring: click a potion
     in the inventory (or drag it onto a hero tab) to drink it, no action. potion_drink.wav.)
  5. Scrolls (cast from a scroll, class spell list check) + keys (locked doors / chests). DONE
     (SRD Spell Scroll: `CombatManager.scroll_power()` = a copy of the spell, no slot, the scroll's DC/attack
     (13/+5 up to 2nd, 15/+7 3rd-4th...), higher than the reader can cast = DC 10+level check or it
     crumbles; `SpellData.classes` = spell lists; Item menu lists scrolls; healing scrolls can be read
     from the bag while exploring. New scroll-only spell Lightning Bolt (LINE, stops at walls, own
     bolt VFX + lightning_crack.wav, scroll_read.wav). Keys: Iron Key (crypt door, floor 1, also
     pickable) in the storeroom chest; Bone Key (lair door, floor 2, key only) in the ossuary chest;
     keys are kept; in combat unlocking with a key = the free door interaction; hover hints name the key.)
  6. Magic items (+1 weapons/armour, rings) + stocking both floors with loot. DONE (`<id>_plus1` = copy of
     the plain item, magic_bonus 1, build_items.gd `_plus1()`: Longsword/Mace/Rapier/Dagger/Shortbow +1, Chain Mail/
     Studded Leather/Shield +1; Ring of Free Action (`ItemData.condition_immunities` -> `CreatureStats.condition_immunities`:
     never restrained; `CombatManager._shrugs_off`, the AI skips webbing them), Ring of Resistance (poison) (`resistances`).
     Magic names in blue, glimmer icons. 8 chests, 4 per floor. No attunement yet.)
- [x] **Phase 5 — Progression + the campaign:** XP, levels 1–5, SRD class features, an outdoor start, a
  five-floor dungeon, new monsters and gear. Steps:
  1. Progression core: `scripts/rules/progression.gd` (XP table, HP per level, slots, ASI at 4,
     powers learned by level), level-1 hero data, `Hero.level/xp/add_xp/gain_level`, XP split on
     victory (`DungeonMap.award_xp`), level-up box + `level_up.wav`, "Lv N" + XP line on the cards,
     `DungeonMap.start_level`. DONE.
  2. Class features: Fighter Defense (+1 AC), Action Surge (2), Improved Critical 19-20 (3), Extra
     Attack (5); Rogue Sneak Attack 1d6/2d6/3d6, Cunning Action Hide (2), Uncanny Dodge (5, reaction
     prompt); Cleric Healing Word, Turn Undead (2, `turned`), Hold Person (3, `paralyzed`, save each
     turn), Mass Healing Word + Destroy Undead (5), Disciple of Life; Mage Burning Hands, Scorching
     Ray (3), Fireball (5), Arcane Recovery (short rest). DONE.
  3. New monsters: `tools/godot/gen_monsters.gd` (template humanoids + overlays, beasts, floating
     undead; sheets + scenes) and stats in `build_data.gd`. DONE (art is a first pass).
  4. The woods: `gen_outdoor_art.gd` (grass/path/forest-floor tiles, cliff + forest blocks, trees,
     pines, bushes, boulders, stumps, logs, tents, graves, campfire, mine entrance),
     `outdoor_tileset.tres` (`build_outdoor_tileset.gd`), Prop kinds that block sight and fade when
     someone is behind them, Brazier `campfire`, Stairs `cave`. DONE.
  5. Five floors + loot: new SRD gear (scimitar, battleaxe, greataxe, morningstar, heavy crossbow,
     breastplate, half plate, +2 items, Flame Tongue, Mace of Disruption, Ring of Resistance
     (necrotic), Potion of Superior Healing, new scrolls, Chief's Key, Sun Key). DONE.
  6. Brannoc the trader + the quest "The Wraith Below" + shop + Rune of Return portal + quest log (J). DONE.
  7. Character sheet (C). DONE.
  8. Intro (Herrasoft splash, HerraDnD title, story pages) + the win screen after the reward. DONE.
  Phase 5 complete (playtested start to finish by the user).
- [x] **Phase 6 — Dungeon features + puzzles:** doors/locks/keys and level transitions were done early.
  Steps:
  1. Traps: `Trap` (5 kinds), passive Perception spotting, Search (F / button), springing on hidden
     traps (walk stops; exploring can't kill), known traps block paths + red edge + warning sign,
     disarming (Rogue, XP), combat (heroes stop on hidden traps; disarm = action). DONE.
  2. Mechanisms: Lever, PressurePlate, portcullis + secret door (`Door.style`), pushable blocks + reset
     lever, room descriptions / clues (`RoomNote`), per-marker state in MapState + saves. DONE.
  3. Puzzles (user request): lever SEQUENCE (Upper Halls: the Hall of Hours), blocks onto plates
     (Webbed Deep: the Weighing Room), ring of five fires (Sunken Crypts: the Chapel of Five Fires),
     riddle stone face (Sealed Vault: opens a secret door to the Kings' Hoard); secret rooms on floors
     1, 2, 3; a lever + portcullis in the Warrens; traps on every floor and two in the woods; a name +
     description for every room and clearing. All built by the module's build_maps.gd (maps rebuilt: older
     saves' monster/chest names no longer match). DONE, waiting for the user's playtest.
  4. Ambushes (`Trigger`: hidden monsters appear, sealing portcullises), lore notes + the journal, module 2's
     monsters (animated armour, gargoyles, a mimic) in module 1; also the throw animation, gear on the intro's
     heroes, tab icons that follow the outfit. DONE (module 1 maps rebuilt), waiting for the user's playtest.
- [x] **Module 2 — The Frost Spire** (user request, after the module system): levels 6-9 rules, 12 new
  monsters, damage-power AI, Worn slots + new SRD items, side quests + story flags + stage XP, rune
  rebinding, mimics, the ice ward, snow + tower tilesets, Hilde + Tamsin, six maps. Waiting for the
  user's playtest. Possible next: a level 9-13 module (needs Progression past 9).
- [ ] **Phase 7 — Story:** quests, NPCs, dialogue, lore notes.
- [ ] **Phase 8 — Wrapper:** title screen + module select (DONE early: Modules, Roster, start screen), save/load (DONE early: F5 quick save, F6 3 slots, F9 load), settings, music, mixing, game over/victory.
- [ ] **Phase 9 — Polish & release:** balance, bugs, juice, export builds (Windows/Mac/Linux, itch.io).
- **First milestone (after phases 0–3):** one user-built dungeon, 4 heroes, 2–3 monster types,
  Fireball + healing + melee working, playable start to finish.

All 4 heroes have 4 facings + idle/walk + attack/shoot/cast/hurt/down animations (walk and action
sheets in Art specs). Possible later: drink-potion / use-item pose (Phase 4). Monsters are real `Monster` actors spawned at `MonsterSpawn` markers
(scene `scenes/actors/monsters/<monster_id>.tscn` + stats `data/monsters/<monster_id>.tres`). Heroes are real `Hero` actors (`scenes/actors/hero.tscn`,
`scripts/actors/actor.gd` + `hero.gd`), spawned by `DungeonMap` at the `PartyStart` marker.

## Story pitch (optional, not chosen)
"The Weaver's Deep": an apprentice's master vanished in the silver mines beneath Harrowmere, which
broke into sealed, web-choked halls. Levels: Collapsed Mine → Webbed Galleries (spiders, cocooned
miners, the first Eye Tyrant) → Sealed Observatory (an ancient wizard's tower built downward). Twist:
the master broke the seal on purpose; the Eye Tyrants were guards keeping something worse locked in.
(Written for a solo wizard; adapt for a party of four.)
