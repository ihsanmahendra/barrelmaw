# Concept Brief: Barrelmaw

Status: draft v0.3. Engine: Godot 4. Platform plan: HTML5 (web) prototype first, then Android from the same project. Structure: roguelite run. Genre: hybrid-casual puzzle with a roguelite card layer.

> Assumption: Pixel Flow's loop is described here from general knowledge (colored units are queued and fired at a pixel-art grid until the picture is cleared). Verify against the live game before locking mechanics.

## 1. One-line pitch
Clear a pixel-art picture by playing a hand of random cards, where every card changes how your colored shooters fire.

## 2. Core loop (30-90 seconds per level)
1. A pixel-art picture (for example 20x20) sits on the board, made of colored cells.
2. A queue of colored shooters waits below. Each shooter clears matching-color cells when it fires.
3. The player draws from a **random card deck**. Each turn, 3 cards are offered; play 1, the others are kept or discarded.
4. Cards modify shooting: change a shooter's color, widen its line, fire diagonally, swap queue order, add ammo, freeze the queue, and so on.
5. Win: picture cleared. Lose: queue runs out of ammo or the holding slots overflow.

The skill is deciding which card to play and when. The luck is which cards appear.

## 3. Card system (the core differentiator)
- **Draw:** 3 random cards per turn from a weighted deck. Rarity weights: Common 70%, Rare 22%, Epic 7%, Legendary 1%.
- **Types:**
  - Color cards: recolor a shooter, wildcard color, color burst.
  - Shape cards: row, column, cross, diagonal, 3x3 blast.
  - Queue cards: reorder, skip, duplicate the next shooter, add a holding slot.
  - Tempo cards: freeze, extra turn, undo once.
  - Chaos cards (high risk): random effect with a big payoff.
- **Synergies:** certain pairs trigger combos (for example Cross + Recolor clears every cell of one color in a cross). Combos are the "feel-good" moments to design around.
- **Run structure (decided):** a run is 8-10 pictures in a row. You start with a 10-card starter deck. After each picture, pick 1 of 3 cards to add to the deck, or remove or upgrade one. Lives carry across the run, so a failed picture costs a life. A run ends when you lose all lives or clear the final boss picture. Every 3rd picture is an elite picture with a modifier (for example, fewer queue slots) and a better reward.
- **Meta:** collect cards, upgrade with duplicates, build a loadout of 12 cards before each run.

## 4. Why this should work
- Pixel Flow style puzzles proved demand for satisfying reveal puzzles.
- Random cards add replay value: each attempt differs, which supports retries and ad-based rewards.
- Cards give a natural monetization and collection layer without relying on level count alone.

## 5. Monetization (light hybrid)
- Rewarded ads: extra draw, revive, bonus card pick.
- Interstitials: after every 3-4 levels, skippable early on; none in the first 10 minutes.
- IAP: remove ads, starter bundles, card packs (no pay-to-win power gap; Epic and Legendary also earnable).
- Battle pass later, after retention is proven.

## 6. Progression and retention hooks
- Daily free card pack and daily picture.
- Picture albums: each completed picture goes into a gallery set (animals, food, retro games).
- Weekly challenge with a fixed deck seed, ranked by moves used.
- Streaks and collection milestones.

## 7. Risks
| Risk | Mitigation |
|---|---|
| Random draws feel unfair | Pity timer, always keep one playable card, reroll once per level |
| Too complex for hybrid-casual | Start with 6 card types in the first 20 levels, unlock the rest slowly |
| Balance across 100+ cards | Sim bot to auto-play levels and report win rates |
| UA cost | Playable ad: 10-second "play 2 cards, clear a picture" |

## 8. Prototype plan (Godot 4, HTML5 first)
Tech notes:
- Use Godot 4 with the Compatibility renderer and a Web export preset. Keep the project to 2D only.
- Prefer a single-threaded web export so it runs on any static host (itch.io, GitHub Pages) without special server headers. Verify this against the Godot version you install.
- Keep touch input as the primary control from day one, since the final target is Android. Test on a phone browser.
- Keep game logic separate from rendering (a pure board and card-effect module) so the same code runs in the HTML5 build and the Android export, and so a headless bot can balance levels.

Milestones:
1. **Week 1:** one picture, 5 shooters, 6 card types, grey-box art, running in the browser. Goal: is playing the card fun?
2. **Week 2:** full run loop (8 pictures, deck building, lives, rarity), placeholder SpriteCook art.
3. **Week 3:** balance bot, analytics events, share the web build with a few testers.
4. **Week 4:** polish and tuning from tester feedback. Decide whether to export to Android for a Google Play soft launch.

Success gates for the web prototype (initial guesses): testers finish a first run, the average run lasts 8-15 minutes, and at least half say they would start a second run.

## 9. Decisions made
- Art style: smooth rounded cells (no pixel-art look).
- Launch card pool: 30-40 cards. The prototype has 33.
- Run length: 10 pictures. Elite pictures at 3, 6 and 9, boss at 10.

## 10. Prototype status
Playable Godot project in `prototype/`. See `prototype/README.md`.
