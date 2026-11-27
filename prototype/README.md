# Barrelmaw prototype

Godot 4.7 project (GL Compatibility renderer, 540x960 portrait).

## Run
Open the `prototype` folder in Godot and press Play, or:

    /Applications/Godot.app/Contents/MacOS/Godot --path prototype

## Test and balance
Headless checks plus a bot that plays 200 full runs:

    /Applications/Godot.app/Contents/MacOS/Godot --headless --path prototype --script res://tests/run_tests.gd

`tests/sfx_test.gd` (same command, other script name) checks that sound effects do not cut each other off.

## Performance
Code-drawn art costs about one draw call per shape, which phones feel. Art that holds still (card icons, shut chests,
map decorations, path dots and stage buttons) goes through `BakedArt` (`scripts/ui/baked_art.gd`): painted once into a
texture, then one draw call. The web build runs at 60 fps at most and at most 2 device pixels per CSS pixel
(`web/shell.html`). `godot --path . --resolution 540x960 --script res://tests/perf_budget_test.gd` (needs a visible
window) fails if a screen exceeds its draw-call budget, if ordinary cards run every frame, or if cached art differs.

## Layout
- `data/cards.json`: 33 cards, rarity weights, starter deck. Balance lives here.
- `data/pictures.json`: 10 pictures and the color palette.
- `scripts/core/`: board, battle, run and data loading (no UI code).
- `scripts/ui/`: screens and the board and queue views, all built in code.

## Art
The menu title is a hand-cut style lettering drawn in code (`flat_logo.gd`) over the same beach and ship deck as the stages.

Generated with SpriteCook (pirate with cannon, barrel, cannonball, beach background, a UI sheet cut
into the wooden plank button, parchment panel, star and ribbon, the card frame and name plate, and the map
islands); files are in
`assets/art`, originals and the asset manifest in `../design/art-source`. The barrel is baked per game color into one atlas
(`design/art-source/make_barrels.py`), and cannonballs are a neutral light texture tinted in code. If an art file is missing, the game falls
back to the drawn vector versions in `scripts/ui/pirate_art.gd` and `beach_bg.gd`.

Drawn in code in the same painted style: the card icons (`card_art.gd`, one silhouette per kind of effect), the
chests (`chest_art.gd`), the win and lose scene (`result_art.gd`) and the reefs, ships and sea creatures on the
map (`map_decor.gd`).

## Rules in short
A turn has two steps: pick one card (tap it to preview, then Play) or skip, then press FIRE. The NEXT
cannonball smashes barrels of its own color, as many as its number. White outlines preview exactly which
barrels will go. Cannonballs whose color is gone are removed (shown leaving the queue, with a message), and the "hits left"
counter only counts hits that can still hit something. Clear the picture before you run out.

## Main menu
One big Play/Continue button with a small "How to play" link, a gear button (sound, music, how to play, reset
progress), a plaque with the next stage, the next boss and the star total, and a daily gift card that joins the
deck of the next stage you play. The sky follows the time of day (dawn, day, dusk, night with stars and a moon)
and has gulls and water glints. Tap the pirate to make him fire. The version number comes from `project.godot`.

## Win celebration
When a picture is cleared its ghost image lights up barrel by barrel from the bottom, gold doubloons spin down the
board, and a "PLUNDERED!" rubber stamp slams onto it (`BoardView.celebrate`).

## Debug mode
Menu gear > Settings > "Debug" opens every stage on the map (nothing else changes; clearing still records stars).
Turn it off in the same place. Reset progress also turns it off.

## Night world (stages 51-100)
Night stages have their own pictures (`tools/make_night_pictures.py`), a dark starry sky with a moon, a dimmed deck and
pirate lit by a lantern, a slower minor-key music track (`audio/bgm_night.wav`), more iron barrels and cursed skulls,
and a night sea on the map with glowing islands and a "Night Seas" banner where stage 51 begins.

## Special barrels
Some barrels in a picture are special: a **bomb** also smashes the 3x3 area around it (bombs chain), a **supply
crate** gives a free 3-hit cannonball, an **iron barrel** takes two hits, and a **cursed skull** takes 2 hits off
your next cannonball. They appear gradually (bombs from stage 3, crates 5, iron 8, skulls 12) and never make up
more than a fifth of a picture, except on Powder Keg and Iron Hull stages where they may fill two fifths
(`Stages.specials_for`). The card and shot previews account for them. The first time each effect actually happens in play, a pop-up
explains it (green BUFF for bombs and crates, red DEBUFF for iron and skulls) and waits for a tap.

## Stages and progress
100 stages on a scrolling treasure map: stages 1-50 are the day world and 51-100 the night world (every 5th
stage is elite, every 10th is a boss). Clearing a stage
unlocks the next and earns 1-3 stars for finishing within a turn limit (shown in the stars box at the top of
the battle screen, limits in `Stages.STAR3_TURNS` / `STAR2_TURNS`). Every stage uses the starter deck plus the cards unlocked so far: six new cards join the deck at stages 11, 21,
31 and 41, introduced on a "New cards!" screen (`Stages.UNLOCKS`).
Progress is saved in `user://save.cfg` (browser storage on the web build). The first Play runs a guided
practice picture. How many cannonballs each stage gets (`Stages.SLACK_TABLE`) and the star turn limits come from the
Design tool `design/balance/rebalance.py`; they were measured together with the card numbers and the elite rules, so
change them together. Stages 21-50 pictures come from `tools/make_pictures.py`.

Elite stages (every 5th that is not a boss) each have a rule, shown in the stage pop-up, in the battle title and in a
pop-up the first time: **Powder Keg** (stages 5, 35) packs in bombs and gives fewer cannonballs, **Iron Hull** (15, 45,
65, 85) makes a quarter of the barrels iron, **Short Hand** (25, 55, 75, 95) offers 2 cards a turn instead of 3
(`Stages.ELITE_RULES`).

## Web export
Run `bash tools/export_web.sh` (exports and copies the loading-screen pictures). The loading page is
`web/shell.html` (pirate, progress bar, tips); the pictures it uses are `web/loading_*.`

Needs Godot export templates (Editor > Manage Export Templates). Use the Web preset with
threads off so it runs on plain static hosting.

## Card packs (phase 1, rules only)
Chests, merge and card levels live in `scripts/core/` (`pack_config.gd`, `collection.gd`, `packs.gd`,
`rewards.gd`) with their numbers in `data/packs.json`. The state is saved with the progress
(`SaveData.pack_state()`). No screen uses it yet. Design: `design/gdd/card-packs.md`. Checks:
`godot --headless --path . --script res://tests/run_pack_tests.gd` (pack checks only) or `run_tests.gd` (all).

### Card levels (phase 2)
Each card in `data/cards.json` has a `levels` list (bonus at levels 2 to 5), written by
`tools/make_card_levels.py`. `Battle.levels` (card id to level) is filled by `Stages.new_battle`; `CardLevels`
turns a level into effects. Debug: `--levels=N` puts every card at level N. Balance check:
`LEVEL=3 PER_STAGE=50 godot --headless --path . --script res://tests/level_balance.gd`.

### Transcended cards (phase 3)
Four chest-only cards (`tools/make_transcended_cards.py`): Maelstrom, Jones' Ledger, Ghost Compass, Phantom Echo.
Equipped ones join every deck (`Collection.equip`, `Collection.deck_with_equipped`; 1 slot after stage 50, 2
after stage 100). Debug: `--tcards` adds all four to the deck. Balance check:
`EXTRA=maelstrom FROM=50 TO=99 MULTI=1 godot --headless --path . --script res://tests/level_balance.gd`.

### Card pack screens (phase 4)
`scripts/ui/pack_screens.gd` holds the Treasury, chest opening, Cargo Hold and Port Market; the menu has
Treasury and Cargo Hold buttons (red dot when something waits) and the daily crate; the results screen shows
Doubloons and chests; the map shows the chest of elite and boss stages. Debug (use with `--progress=N` so the
real save is not touched): `--packs=N`, `--treasury`, `--cargo`, `--market`, `--opening --open-chest=gilded
--auto-tap`, `--claim-crate`. Smoke test: `godot --headless --path . --script res://tests/screens_smoke.gd`.

### Card pack polish (phase 5)
Chest art is drawn in `scripts/ui/chest_art.gd` (see the gallery with `--chest-gallery`); `burst_fx.gd` is the
burst of light on flips and merges; new sounds come from `tools/make_sfx.py`. The how-to has a sixth step about
chests and merging. Real generated chest art can replace `ChestArt` later (keep `ChestArt.draw`'s signature).

### Scrolling
Lists that hold buttons, cards or panels (Treasury, Cargo Hold, Port Market, How to play) use `DragScroll`
(`scripts/ui/drag_scroll.gd`): you can drag from anywhere, a button being dragged is not tapped, and the list coasts
after a flick. Call `scroll.wire(content)` after building the content. The treasure map uses a plain ScrollContainer
(its stage nodes handle taps themselves). Test: `godot --path . --script res://tests/scroll_test.gd` (needs a window,
not `--headless`); it drags over every scrolling screen from buttons, cards, panels and gaps.

### Layout and phone safe area
`SafeArea` (`scripts/ui/safe_area.gd`) keeps titles, buttons and text clear of a phone's notch, status bar and home
bar. The web shell (`web/shell.html`) measures `env(safe-area-inset-*)` and Godot reads it for every new screen and
when the window changes shape; the background still fills the whole screen. Debug: `--safe=left,top,right,bottom`
fakes the insets. Test: `godot --path . --resolution 390x844 --script res://tests/layout_test.gd` builds every screen
with a fake notch and fails if any label, button or panel is outside the safe area (try 540x960, 360x800, 320x568,
768x1024, 800x600). It needs a window, not `--headless`.
It also fails if map pictures cover each other (stage ship and reward chest, treasure box and compass) or the
chest-opening hint sits on the chest.
