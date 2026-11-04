# Asset generators

## tools/godot (GDScript, needs only Godot 4.7.2)
Run from the project folder, in this order, importing between steps:

```sh
G="/c/Godot/Godot_v4.7.2-stable_win64_console.exe"
$G --headless --path . -s res://tools/godot/gen_art.gd         # tiles, heroes, props, torch, web PNGs
$G --headless --path . --import
$G --headless --path . -s res://tools/godot/build_tileset.gd   # assets/tiles/dungeon_tileset.tres
$G --headless --path . -s res://tools/godot/build_test_room.gd # scenes/maps/map_template + test_room
```
`build_tileset.gd` and `build_test_room.gd` **overwrite** their outputs. Don't re-run them after
editing those files by hand.

## tools/python (concept-session scripts)
Need Python 3 + Pillow + numpy (ffmpeg for the videos). **Not yet adapted to this layout:** they
still expect to run from one flat folder, writing to `cave/`, `fireball/`, `iso/`, `sfx/` beside
themselves and reading `eye_tyrant_sheet.png` from there. Order: eye_tyrant_anims → cave_textures →
fireball → sfx → iso_party → iso_fireball → iso_dice. To use them now, copy them into a scratch folder
and run them there. `make_iso_party.py` is also the source of the hero pixel grids and palette that
`gen_art.gd` reads, so edit the heroes there.
