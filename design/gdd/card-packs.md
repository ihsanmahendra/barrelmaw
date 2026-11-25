# Card Packs, Merge and Card Levels

Status: draft v1 for review. Target: next update after the current build (100 stages, day and night worlds).
Owner system: collection and progression. Touches: cards, daily gift, results screen, map rewards, save data, battle.

> Numbers in this document come from a first-pass Monte Carlo simulation (`prototype/tools/pack_sim.py`).
> They are starting values, not final. Section 7 lists every tuning knob and Section 8 the tests that guard them.

## 1. Overview

Players earn and buy **chests** (card packs) in five tiers: Common, Rare, Epic, Legendary and **Transcended**.
Opening a chest gives cards. Cards the player already owns become **copies**, and enough copies **merge** the
card up a level (max level 5), which makes that card stronger in every battle. Transcended is a new top
rarity: four pack-only cards that cannot be unlocked by playing stages.

The unlock path stays as it is: a card is *discovered* by reaching the stage that unlocks it (every 10 stages).
Chests never unlock a stage card early. They make cards you already have **stronger**, and they are the only
source of Transcended cards.

Why this design (summary of the choices made, with the flaw each one avoids, is in Section 9):

- Chests roll only from cards the player has unlocked, so no pull is ever a card they cannot use.
- Duplicates are never dead: they merge, and copies beyond max level turn into Pearls.
- Bad-luck streaks are capped by visible pity counters.
- Level bonuses are small and checked against a power budget, so the 100 tuned stages stay fair.
- No real-money purchase in this update. Chests come from play and from in-game Doubloons.

## 2. Player Fantasy

A pirate captain hauling in loot. Chests feel like finding treasure after a hard stage, not like a casino.
The player should feel: "my favorite cannon card is getting better," "that boss paid off," and, rarely,
"a ghost-ship relic joined my crew." The merge moment is a small forge-like ceremony the player triggers
themselves. Nothing is lost, hidden or taken away.

## 3. Detailed Rules

### 3.1 Currencies and items

| Item | Source | Use |
|---|---|---|
| Chests (5 tiers) | daily crate, stage rewards, boss rewards, shop | open for cards |
| Doubloons (soft currency) | first clears, stars, replays | buy chests |
| Pearls | copies beyond max level | Port Market: buy single card copies |
| Copies | chests, Market | merge into levels |

### 3.2 Chest tiers

| Chest | Card rarity | Cards | Unlocked at | Price (Doubloons) | Visual |
|---|---|---|---|---|---|
| Driftwood Crate | Common | 3 | start | 150 | rope-bound plain wood |
| Ironbound Chest | Rare | 4 | stage 10 cleared | 600 | blue steel bands |
| Captain's Coffer | Epic | 4 | stage 30 cleared | 2,000 | purple velvet, silver trim |
| Gilded Hoard | Legendary | 5 | stage 40 cleared | 6,000 | gold overflowing |
| Abyssal Vault | Transcended | 5 | stage 50 cleared | 9,000 | ghostly teal, chains, glowing lock |

A locked chest shows its unlock stage. Chests already in the inventory never expire.
"Cleared" means the stage was won at least once. The unlock stages match the stages where that rarity first
becomes available in `Stages.UNLOCKS` (stage 11 rare, 31 epic, 41 legendary) and the night world (stage 51+).

### 3.3 What a chest rolls

Each card slot has a rarity table (Section 4.1). The rolled rarity picks a random card of that rarity from
the **pool of cards the player has unlocked**. If the rolled rarity has no unlocked card, the roll steps down
one rarity until it finds one, so no slot is ever empty. Transcended cards are in the pool once the player has
cleared stage 50.

- The first Driftwood Crate a new player opens is **scripted**: two copies of the most common starter card
  (Power Shot) plus one more starter card, so a merge is ready in the first session.
- Opening reveals cards one at a time, lowest rarity first, so the best card comes last.
- A chest result is **decided, applied to the collection and saved before the animation starts**; the reveal
  is a queued replay of that saved result. Closing the app mid-opening cannot reroll it (see 5.2).

### 3.4 Merge and card levels

- A card is **owned** at level 1 when it is unlocked by stage progress, or when it is first pulled from a chest
  (Transcended cards). The card itself is never spent. Every further copy is a **spare**.
- Spares collect on that card. When it has enough spares for the next level, the card shows a glowing
  **MERGE** button. Tapping it spends the spares and raises the level.
  A **Merge All** button does every ready merge. Merge is never automatic, so the player gets the moment,
  but it also never costs choice or resources: copies are only ever spent on that card's own next level.
- Max level is 5. **Spare copies** needed per level step:

| Rarity | Lv1 to 2 | 2 to 3 | 3 to 4 | 4 to 5 | Total spare copies to Lv5 |
|---|---|---|---|---|---|
| Common | 2 | 3 | 5 | 8 | 18 |
| Rare | 2 | 3 | 5 | 7 | 17 |
| Epic | 2 | 3 | 5 | 6 | 16 |
| Legendary | 2 | 3 | 4 | 5 | 14 |
| Transcended | 2 | 3 | 3 | 4 | 12 |

  (Each step spends exactly that many spares. A common card reaches level 2 with 2 spares, which is 3 copies
  in total counting the card itself.)

- A card at level 5 turns every further copy into Pearls: Common 1, Rare 3, Epic 10, Legendary 30,
  Transcended 100.
- A card's level applies to **every copy of it in the deck** (the deck still holds the same cards as today).
  The level is shown as 1 to 5 anchor pips on the card in hand, in the collection, and in the pack reveal.

### 3.5 What a level does (power budget)

Each card in `cards.json` has a `levels` list with the bonus at levels 2, 3, 4 and 5 (a level may have no
numeric bonus). Bonuses are small numeric gains, never new rules. The code is `scripts/core/card_levels.gd`;
`tools/make_card_levels.py` writes the table, so one edit there changes every card.

Power points (PP) keep the cards comparable:

| Gain | PP |
|---|---|
| +1 hit on the next cannonball | 1.0 (2.0 on a card that doubles its hits) |
| +1 barrel removed (random or color removal) | 0.8 |
| +1 card drawn | 2.0 |

Rules (enforced by a test, Section 8):

1. Each of levels 2, 3 and 4 adds at most **1.0 PP**. Level 5 (Mastery) adds at most **2.0 PP**.
2. The total bonus at level 5 is at most **5 PP**, or 40% of the card's base PP if that is larger.
3. A card may not gain a draw before level 5.

**The schedule is staggered on purpose.** The 100 stages are tuned with almost no slack, so one extra hit on
every card played moves the bot's win rate by 24 points. Measured with `tests/level_balance.gd` (all cards at
one level, 10,000 games): "+2 hits on every shape card" alone took the win rate from 52% to 77%, because a hit
on a Row or Blast clears a whole line or area; every other family moved it 0 to 5 points. So shapes get no
extra hits, and the rest get their bonuses at different levels instead of every level:

| Family | Cards | Lv2 | Lv3 | Lv4 | Lv5 Mastery |
|---|---|---|---|---|---|
| Hit boost | Power Shot, Heavy Round, Overclock, Tidy Up | +1 hit | no bonus | +1 hit | +1 hit |
| Utility | Skip, Wildcard, Focus, Clone, Second Wind, Roulette | +1 hit | no bonus | +1 hit | +1 hit |
| Draw | Quick Draw, Sniper, Triple Draw | +1 hit | no bonus | +1 hit | +1 card drawn |
| Added ball | Reload, Arsenal | +1 hit on the added ball | no bonus | +1 hit on the added ball | +1 hit on the added ball |
| Shape | Row, Column, Cross, Diagonal, Blast, the Wild variants, Heavy Blast, Prism | no bonus | no bonus | +1 barrel | +1 barrel |
| Multiplier | Rapid Fire, Echo, Double Blast | no bonus | +1 barrel | no bonus | +1 barrel |
| Small removal | Scatter, Pick Off, Pixel Rain | no bonus | +1 barrel | no bonus | +1 barrel |
| Color removal | Color Bomb, Color Storm | no bonus | +1 | no bonus | +1 |

In the game, a card above level 1 shows a gold level badge in its corner and a line such as "Lv 4: +2 hits".
A level with no numeric bonus is still a visible step (the badge changes and the Cargo Hold shows the level
reached); a cosmetic frame tint for those levels is a polish item for phase 5.

Example, Power Shot ("+2 hits for the next cannonball"): level 2 and 3 give +3 hits, level 4 gives +4 and
level 5 gives +5.

Measured result (bot, 5,000 games per level, every unlocked card at that level; level 1 is today's game):

| Level of every card | Win rate | 3-star rate |
|---|---|---|
| 1 (baseline) | 52.6% | 47.2% |
| 2 | 55.2% | 51.3% |
| 3 | 60.8% | 57.4% |
| 4 | 66.9% | 64.7% |
| 5 | 77.5% | 76.4% |

This meets acceptance 8.10: level 3 is 8 points above the baseline (limit 12) and level 5 stays under 80%.
The first draft (+1 hit every level on every card) reached 85% at level 3 and 94% at level 5.

### 3.6 Transcended cards (new, pack-only)

Four new cards (`tools/make_transcended_cards.py`). They are not in `Stages.UNLOCKS` and not in the default
deck. The player equips them in the **Captain's Slot** (1 slot once stage 50 is cleared, 2 once stage 100 is
cleared). Equipped Transcended cards join the deck of every stage, one copy each. They have a shimmering
aurora frame and follow the level rules of Section 3.5.

| Card | Effect at level 1 | New rule it needed |
|---|---|---|
| Maelstrom | Remove every barrel of the biggest color, up to 20 | none (the same effect as Color Storm with a bigger number) |
| Jones' Ledger (`davy_ledger`) | Add two 3-hit cannonballs that can hit any color | a **wild** cannonball: it hits any color and is not thrown out when its own color is gone |
| Ghost Compass | Free turn (does not count for the star turn limit), +3 hits, draw 2 cards, play 1 more card | a **free turn**: firing this turn gives the turn number back |
| Phantom Echo | Repeat your last card at +1 level (up to 5), plus +1 hit. With no last card it draws 1 card instead | the battle remembers the **last card played**; Echo never counts as the last card |

Level bonuses: Maelstrom +1 barrel at levels 3 and 5; Jones' Ledger +1 barrel at levels 3 and 5 (a ball bump
would be worth two hits on a two-ball card); Ghost Compass and Phantom Echo +1 hit at levels 2, 4 and 5.

Balance, measured with `tests/level_balance.gd` on stages 51 to 100 (5,000 bot games, every card at level 1,
one Transcended card added to the deck; the baseline is 40.4% wins and 37.1% 3-stars):

| Added to the deck | Win rate | 3-star rate |
|---|---|---|
| nothing | 40.4% | 37.1% |
| Maelstrom | 43.3% (+2.9) | 40.8% (+3.7) |
| Jones' Ledger | 53.3% (+12.9) | 45.1% (+8.0) |
| Ghost Compass | 46.9% (+6.5) | 45.5% (+8.4) |
| Phantom Echo | 42.6% (+2.2) | 39.6% (+2.5) |
| all four | 60.8% (+20.4) | 57.1% (+20.0) |

Two lessons from tuning. A Ledger of two 5-hit balls gave +21.6 points, so it became two 3-hit balls. And a card
that only adds hits is worth *less* than an average card: extra Heavy Rounds in the deck lowered the win rate,
because they replace stronger cards. Ghost Compass needed the extra play and cards on top of its hits before it
beat the deck's average. The bot plays one best-scored card at a time, so Phantom Echo (whose value depends on
what was played before) is probably worth more to a person than these numbers say.

### 3.7 Where chests come from

| Source | Reward |
|---|---|
| Daily crate | 1 Driftwood Crate per day. Skipped days stack, up to 3. Every 7th claimed day gives an Ironbound Chest instead. The counter never resets if the player misses a day |
| First clear of a stage | 40 Doubloons, +20 per star earned (first clear and star improvements only) |
| Replaying a cleared stage | 10 Doubloons per win, up to 5 paid wins per day |
| Elite stage (every 5th, first clear) | 2 Driftwood Crates |
| Boss stage (every 10th, first clear) | stages 10 and 20: 2 Ironbound; 30: Coffer; 40: 2 Coffers; 50: Gilded Hoard; 60 and 80: Abyssal Vault; 70 and 90: Gilded Hoard; 100: 2 Vaults |
| Night-world star milestones | at stages 55, 65, 75, 85 and 95: an Abyssal Vault when the ten stages ending there all have 3 stars (paid once each, whenever the last missing star is earned) |
| Shop | any unlocked chest for Doubloons |
| Port Market | one specific card copy for Pearls (Section 4.5) |

### 3.8 Screens

1. **Treasury** (new button on the menu and on the map): the five chests with owned count, Open and Buy
   buttons, an "i" button with the odds, and the pity meters. Locked chests show their unlock stage.
2. **Chest opening** (full screen): the chest sits on the ship deck, the player taps it, it shakes and opens
   with a rarity-colored light, cards fly out face down and flip one by one. Tap to skip. After the last
   card a summary shows what merged, what is ready to merge and any Pearls gained.
3. **Cargo Hold** (collection): grid of all cards, with level pips and a copy bar (for example 3/5). Filters:
   all, ready to merge, by rarity. Tap a card for its level table (what each level adds) and the MERGE button.
   Locked cards are shown grayed with their unlock stage.
4. **Port Market**: the weekly Pearl shop.
5. **Results screen**: shows the Doubloons earned and any chest dropped, with the chest icon.
6. **Map**: elite and boss nodes show a small chest icon until their reward is claimed.
7. **Battle**: each card in hand shows its level pips; the description shows the leveled numbers; the
   preview (`preview_card`) uses the same leveled numbers.
8. **Menu**: red dots on Treasury (unopened chests) and on Cargo Hold (a merge is ready).

### 3.9 Daily gift migration

The current daily gift (a rare or better card for the next stage) is replaced by the daily crate. A gift
card already claimed but not yet used still works for one more stage. Existing saves also get a one-time
**Welcome Aboard** gift of 3 Driftwood Crates so returning players see the feature at once.

## 4. Formulas

### 4.1 Rarity tables per card slot (percent)

| Chest | Slots | Common | Rare | Epic | Legendary | Transcended |
|---|---|---|---|---|---|---|
| Driftwood Crate | 1 to 3 | 88 | 11 | 1 | 0 | 0 |
| Ironbound Chest | 1 to 3 | 70 | 27 | 3 | 0 | 0 |
| Ironbound Chest | 4 (guaranteed Rare+) | 0 | 85 | 14 | 1 | 0 |
| Captain's Coffer | 1 to 3 | 45 | 40 | 14 | 1 | 0 |
| Captain's Coffer | 4 (guaranteed Epic+) | 0 | 0 | 90 | 10 | 0 |
| Gilded Hoard | 1 to 4 | 0 | 55 | 40 | 5 | 0 |
| Gilded Hoard | 5 (guaranteed Epic+) | 0 | 0 | 80 | 18 | 2 |
| Abyssal Vault | 1 to 4 | 0 | 0 | 72 | 28 | 0 |
| Abyssal Vault | 5 (guaranteed Legendary+) | 0 | 0 | 0 | 62 | 38 |

The same tables, as the player-facing odds panel, are shown in the app. The panel reads these numbers from
the data file, so the shown odds cannot drift from the real ones.

### 4.2 Pity

Counters are saved and shared across all chests that can produce the rarity.

- **Epic pity:** every card slot in an Ironbound, Coffer, Gilded or Vault chest adds 1 to `since_epic`. At 30,
  the next common or rare roll in such a chest becomes Epic. Any Epic or better resets it.
- **Legendary pity:** same idea, `since_legendary`, threshold 60, only in Coffer, Gilded and Vault chests.
- **Transcended pity:** `vault_dry` counts Vaults opened without a Transcended card. At 6, the last slot of
  the next Vault is Transcended.
- **Duplicate protection (Transcended):** when a Transcended roll happens and the player does not own all four,
  60% of the time it picks a card they do not own yet.

The displayed meter says "Epic or better guaranteed within N more cards".

### 4.3 Merge

```
need(rarity, level)      = STEP[rarity][level - 1]          # level 1..4
ready(card)              = spare[card] >= need(rarity, level[card])
merge(card):  spare     -= need ; level += 1
at level 5:   leftover spares at merge time, and every later copy, give PEARLS[rarity] each
```

The first copy of a Transcended card only owns it (no spare). Section 3.4's table lists spares.

### 4.4 Doubloons

```
first_clear(stage, stars)   = 40 + 20 * stars
star_improvement(old, new)  = 20 * (new - old)
replay_win                  = 10        (max 5 paid per day)
```

### 4.5 Port Market

```
price_in_pearls(rarity) = 8 * PEARLS[rarity]       # Common 8, Rare 24, Epic 80, Legendary 240, Transcended 800
limit = 5 purchases per week; Transcended 1 per week
```

### 4.6 Simulation results (first pass)

A player who opens the daily crate, claims every stage and boss reward, and spends Doubloons on the best
unlocked chest. Average level counts every unlocked Common, Rare, Epic and Legendary card. 200 runs each.

| Day | Casual (3 stages/day): stage, avg level, chests | Hardcore (6 stages/day): stage, avg level, chests |
|---|---|---|
| 7 | 21, 2.2, 29 | 42, 1.8, 35 |
| 14 | 42, 2.2, 57 | 84, 2.6, 69 |
| 30 | 90, 3.3, 124 | 100, 3.3, 106 |
| 60 | 100, 3.7, 179 | 100, 3.7, 152 |
| 100 | 100, 3.9, 241 | 100, 3.9, 214 |

Other results: a Gilded Hoard gives a Legendary or better in a median 2 chests (p90 6); a Coffer in a median
5 (p90 15); collecting all four Transcended cards takes a mean of about 12 Vaults (max 35, with duplicate
protection and pity). By day 100 a typical player owns about 2.5 Transcended cards and has about 15 cards at
level 5, mostly Commons.

Reading: pacing is a little generous. If the beta shows the 100-stage balance eroding, lower first-clear
Doubloons by 15% before touching merge costs.

## 5. Edge Cases

1. **Empty pool.** A rolled rarity with no unlocked card steps down one rarity. Never an empty slot.
2. **Quit during opening.** The roll is applied and written to `save.cfg` with a queued reveal, then animated. On
   restart the player sees the same reveal. This also stops "close the app to reroll."
3. **Time rollback (device clock).** The daily crate is keyed to the local date, as the daily gift is today.
   Moving the clock back cannot claim twice because `last_claim_date` only moves forward; moving it forward
   gives at most the stacked 3 crates. Documented as an accepted exploit for a single-player game.
4. **Merge at max level.** The MERGE button does not appear; copies go to Pearls at pull time.
5. **Level up while a battle is open.** Not possible: merging happens only from menu screens. The battle
   copies the level table when it starts.
6. **Preview and play must match.** Both read the same leveled card data; the existing test that compares
   `preview_card` with the real play is extended to levels 1 to 5.
7. **Transcended slot with no cards owned.** The slot is empty and hidden until the first Transcended card.
8. **Phantom Echo.** It repeats the last card played in this battle at +1 level, capped at level 5. It is
   never recorded as the last card, so two Echos in a row repeat the same card twice. With no last card it
   draws 1 card instead.
9. **Existing saves.** Every card unlocked by stage progress becomes 1 copy, level 1. No one loses anything.
10. **Debug mode.** `debug_unlock` shows all cards in the Cargo Hold but does **not** grant chests or levels.
    A separate debug flag `--packs=N` grants chests for testing.
11. **Save tampering.** `save.cfg` is a plain text file the player can edit. That is acceptable for a
    single-player game with no real-money purchases. Revisit if leaderboards or paid chests are added.
12. **Web build storage cleared.** Collection and levels live in the same save as stage progress, so they
    are lost together. A cloud save is a separate, later feature; the Treasury screen should say that clearing
    browser data resets progress.

## 6. Dependencies

| System | How it is affected |
|---|---|
| Cards (`cards.json`, `GameData`) | new `levels` per card, new rarity `transcended`, 4 new cards, `UiKit.RARITY_COLORS` gets a Transcended color |
| Battle (`battle.gd`, `Stages.new_battle`) | takes a `levels` dictionary; effects read leveled values; preview uses them |
| Decks (`Stages.deck_for`) | unchanged, plus the equipped Transcended cards appended |
| Save (`save_data.gd`) | new sections for copies, levels, chests, pity, Doubloons, Pearls, equipped slot; save version number |
| Daily gift | replaced by the daily crate (Section 3.9) |
| Results and map | show chest and Doubloon rewards |
| Balance tools (`tune_slack.gd`, `star_stats.gd`, `run_tests.gd`) | must run with a level profile; level 1 stays the tuning baseline |
| Art and audio | chest art, Transcended frame, level pips, merge and reveal effects, sounds |

## 7. Tuning Knobs

All in a new `data/packs.json` unless noted.

- Chest prices, card counts, unlock stages, slot rarity tables (4.1).
- Pity thresholds: Epic 30, Legendary 60, Vault 6; duplicate-protection chance 60%.
- Merge steps per rarity and max level (5).
- Pearl values per rarity, Market price multiplier (8), weekly limits.
- Doubloon faucet: first clear 40, per star 20, replay 10, replays per day 5.
- Daily crate stack cap (3), streak length for the Ironbound bonus (7).
- Per-card `levels` bonuses and the power budget (Section 3.5) in `cards.json`.
- Captain's Slot count (1 and 2) and the unlock stages (50 and 100).

## 8. Acceptance Criteria

Testable in `tests/run_tests.gd` (headless) unless marked manual.

1. **Odds.** Over 100,000 simulated chests of each tier, observed rarity rates are within 1 percentage point of
   the tables in 4.1 (pity disabled for this test).
2. **Pity.** With pity enabled, no run goes more than 30 cards without an Epic or better in an
   Ironbound or higher chest, more than 60 cards without a Legendary or better in a Coffer or higher chest,
   or more than 6 Vaults without a Transcended card.
3. **No impossible pulls.** For every stage-progress profile, a chest never gives a card that is locked.
4. **No empty slots.** Opening every chest with the smallest possible pool (starter cards only) returns the
   full card count.
5. **Merge math.** For each rarity, feeding the exact total copies reaches level 5 and not before; one fewer
   copy stops at level 4. Copies at level 5 become Pearls at the listed rate.
6. **Level budget.** Every card's `levels` list passes the power-point rules in 3.5, so a bad data entry
   fails the test, not the game.
7. **Preview equals play.** `preview_card` output equals the real play result for every card at levels 1 to 5.
8. **Save.** A save written with copies, levels, chests, pity and a pending reveal loads back identically,
   and a pending reveal cannot be rerolled.
9. **Migration.** An old save loads with every unlocked card at level 1 with 1 copy and receives the
   Welcome Aboard crates exactly once.
10. **Balance.** The bot (`tests/level_balance.gd`, run by hand because it plays 10,000 games) with every unlocked card at level 3
    wins at most 12 percentage points more than the level 1 baseline (currently 52%), and its average
    3-star rate is at most 15 points higher. With every card at level 5, win rate stays under 80%.
11. **Economy.** The simulation (`tools/pack_sim.py`) shows, for the casual profile, average level between
    2.0 and 2.5 at day 14 and below 4.2 at day 100.
12. **Performance (manual).** Chest opening stays at 60 fps in the web build on a mid-range phone; the
    Cargo Hold with 37 cards scrolls without hitches.
13. **Transcended balance.** On stages 51 to 100, adding any one Transcended card to the deck changes the bot's
    win rate by between +2 and +14 points, and all four together by at most +22 (measured: +2.2 to +12.9
    and +20.4). A wild ball is never thrown out while any barrel is left, and a free turn never makes the
    turn count negative.
14. **UX (manual).** A new player can open the first crate and merge their first card without any help text
    other than the on-screen prompts (target: first merge within the first session).

## 9. Flaw Review: What This Design Fixes

This is the "improve any flaws" pass. Each row is a known weakness of card-pack and merge systems, and what
this design does about it.

| Flaw | Fix in this design |
|---|---|
| Packs make players stronger and ruin the tuned 100-stage balance | Small level bonuses under a power budget (3.5), level 1 stays the tuning baseline, bot acceptance test (8.10), with the sim as an early warning |
| Pulling cards the player cannot use yet | Chests roll only from unlocked cards; chest tiers unlock with the stages that introduce that rarity (3.2, 3.3) |
| Dead duplicates | Duplicates merge; copies past max level become Pearls; Pearls buy specific cards (3.4, 4.5) |
| Long bad-luck streaks | Three saved pity counters plus a visible meter (4.2) |
| Hidden odds | Odds panel in the app, generated from the same data the game rolls from (4.1) |
| Rolling again by closing the app | Result is saved before the animation (5.2) |
| Opening fatigue | Tap to skip the reveal, lowest rarity first, short reveal for small chests, an "Open another" button after each chest (an Open All button is a later idea) |
| Daily gift expires or is wasted | Daily crate stacks up to 3, never resets; the old one-stage-only gift card goes away |
| Streak anxiety | The 7-day bonus counts claimed days and never resets |
| Merge regret ("did I level the wrong card?") | Merge only spends copies of that same card, never other resources, and can never be wasted or undone wrongly |
| First-session boredom | Scripted first crate guarantees a merge-ready card (3.3) |
| The top tier feels pointless or unfair | Transcended is capped to a 1 to 2 card Captain's Slot, one effect per draw, with duplicate protection and pity, and a free source in the night world |
| Pay-to-win and loot-box laws | No real-money chests in this update. If paid chests are ever added, odds are already public and a direct-purchase alternative is required in some regions |
| Currency hoarding or inflation | Chest prices rise steeply by tier, Doubloon replays are capped per day, Pearls have a weekly spend limit |
| Information overload in the collection | Filters (all, ready to merge, by rarity), a MERGE glow, and level tables shown only on the card detail |
| Save loss or editing | Called out in 5.11 and 5.12; a cloud save is a later feature |

## 10. Art and Audio Needs

- Five chest illustrations (closed, opening, open light burst) in the existing SpriteCook pirate style, rarity
  colors from `UiKit.RARITY_COLORS`. Vault has a ghostly teal look.
- A **Transcended** card frame and rarity color (aurora cyan, a slow shimmer) and a short full-screen
  reveal for the first copy of each Transcended card.
- Level pips (five small anchors), a MERGE glow, a forge-style merge flash, Doubloon and Pearl icons.
- Four new card icons for the Transcended cards.
- Sounds (reuse SoundWeaver where it fits): chest creak, lid open, card flip, five rarity stings (rising),
  merge hammer strike, Pearl clink. A calm 15 second Treasury music loop is optional.
- All new pictures follow the artwork notes in the repo README (credits and licenses).

## 11. Implementation Plan

Suggested order. Each phase ships and tests on its own, behind a feature flag until phase 5.

1. **Data and rules (no UI). Done.** `data/packs.json`; `scripts/core/collection.gd` (copies, levels, merge,
   Pearls); `scripts/core/packs.gd` (rolling with pity, pending reveal); save format with a version number and
   migration; the new tests (8.1 to 8.9). Add `tools/pack_sim.py` to the repo.
2. **Leveled cards in battle. Done.** `levels` in `cards.json` for all 33 cards (`tools/make_card_levels.py`),
   `CardLevels` and `Battle.levels`, preview parity test at levels 1 to 5, a level badge and bonus line on the
   card, the `--levels=N` debug flag, and `tests/level_balance.gd` (bot win rate with every card at one level).
   The first schedule was far too strong and was rebalanced (Section 3.5).
3. **Transcended. Done.** Four new cards, the wild ball, free turn and repeat-last rules, the aurora frame and
   new icons, the Captain's Slots (`Collection.equip`, `deck_with_equipped`), `--tcards` debug flag, tests and
   balance numbers (Section 3.6). Equipping has no screen yet; that is phase 4.
4. **Screens. Done.** `scripts/ui/pack_screens.gd` (Treasury with odds and luck meters, chest opening, Cargo Hold
   with filters, card detail, MERGE and Captain's Slot equip, Port Market), `chest_art.gd` and `chest_view.gd`
   (chests drawn in code for now), the daily crate on the menu replacing the daily gift, red dots on the Treasury
   and Cargo Hold buttons, rewards on the results screen, and chest icons on elite and boss stages of the map.
   Debug flags: `--packs=N`, `--treasury`, `--cargo [--filter=ready] [--detail=id]`, `--market`,
   `--opening --open-chest=id`, `--claim-crate`, `--auto-tap`, `--rewards`. Tests: the screen logic in
   `pack_tests.gd` and `tests/screens_smoke.gd`, which opens every screen in a real Main scene. Checked in a
   web build served locally: claim, open, reveal and merge all work, no console errors. Not in this phase:
   an "Open all" button (each chest has "Open another" instead) and a one-tap skip for the first-ever reveal.
5. **Polish and release. Done, with one gap.** Chests are redrawn in code to match the pirate and barrel art (smooth
   shading from the top left, outlines in a darker shade of each color, glossy highlights, dark steel hoops with
   domed rivets like the barrels', a gold padlock like the map chest's, an ornament per tier, a raised lid and a
   treasure heap when open); the generated chest art in
   Section 10 could not be made because the SpriteCook account had 1 credit left. New synthesized sounds (chest
   shake and open, card flip, five rarity stings, merge, pearls), a burst of light on every flip, level badges that
   change color (bronze, silver, gold, ice-blue) so levels without a numeric bonus still look like progress, a
   full-screen reveal for the first copy of a Transcended card, a gold flash on merge, a sixth how-to step with its
   own picture (the how-to screen now scrolls), and Transcended shimmer that only redraws while visible. Measured in
   a web build on desktop: menu, Treasury, Cargo Hold (scrolling) and the chest idle all hold 60 fps; the reveal
   holds about 50 fps with a worst frame of 34 ms. Not measured on a phone.

Phase 1 as built: `data/packs.json`, `scripts/core/pack_config.gd`, `collection.gd`, `packs.gd`, `rewards.gd`,
pack state in `SaveData` (`pack_state()`, migration, `record()` now returns the previous best stars), and
`tests/pack_tests.gd` (run alone with `tests/run_pack_tests.gd`). Not wired to any screen yet, so the game
plays exactly as before. Real Transcended cards do not exist yet; the tests use four stand-in cards.

Rough size: phases 1 and 2 are the core; phase 4 is the largest by amount of UI. About two to three weeks of
focused work for one developer, plus art time for phase 5.

## 12. Assumptions and Open Questions

Decided here, easy to change:

- "Transcended" is both a new **card rarity** (four pack-only cards) and the top **chest tier**. (The request
  spelled it "Trancended"; the doc uses the standard spelling.)
- No real-money purchases in this update.
- Chest tiers unlock with story progress instead of being buyable from the start.
- Merge is a manual tap with Merge All, not automatic.
- One Captain's Slot for Transcended cards, two after stage 100.

Please confirm or change before implementation starts:

1. Should chests ever be sold for real money? That changes Sections 3.7, 9 and the legal notes.
2. Should the level-up make a card appear **more often** in the draw (deck weight) instead of, or in addition
   to, stronger numbers? Not included here because it would shift balance more than a small number bonus.
3. Is a cloud save planned? If yes, it moves up, because the collection becomes a longer-term asset.
