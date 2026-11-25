# Barrelmaw on TikTok Mini Games: Release Plan

Status: draft v1, written 2026-11-25 from TikTok's public developer docs. Facts below are marked **[verified]** when
a TikTok doc page said so, **[inferred]** when I concluded it, and **[check]** when it must be confirmed in the
Developer Portal or with TikTok before anyone commits money or time. Dates and limits on these pages change.

## 1. The blocker: the Godot web build cannot be submitted

- TikTok stopped accepting HTML5 mini games. The HTML (H5) route was retired in September 2026, and every mini game
  launched or kept up after 28 August 2026 must use the **native runtime**. **[verified]**
- The native runtime takes packages exported from **Cocos Creator 3.x** (TypeScript/JavaScript), **Unity 2021-2022**
  (C#, compiled to WebAssembly with IL2CPP) or **Laya 3.x**. A plain web build, an unadapted Unity WebGL build or a
  native app package cannot be delivered as a mini game. **[verified]**
- Godot is not on TikTok's engine list and its docs never mention it. A Godot web export therefore falls under "a plain
  web build". **[inferred]** Whether TikTok would make an exception is **[check]** (ask in the TikTok developer forum or
  through a TikTok contact; do not plan on it).

So releasing Barrelmaw on TikTok means **rebuilding the game in a supported engine**. The Godot version stays useful: it
is the finished design, the balance reference and the free web release on GitHub Pages.

## 2. Engine options

| Option | Fit | Cost and risk |
|---|---|---|
| **Cocos Creator 3.x (recommended)** | TypeScript, 2D-first, small output, drawing API close to what Barrelmaw does (sprites, labels, a 2D `Graphics` component for the code-drawn parts). TikTok has a Cocos build guide. | Rewrite all UI. The 30 MB total / 4 MB main-package limits need subpackages and lean audio. |
| Laya 3.x | Similar to Cocos, smaller community. | Same rewrite, fewer examples and tools. |
| Unity 2021-2022 | Mature tooling, 60 MB limit. | Heavier engine for a 2D puzzle, IL2CPP/WebAssembly start-up risk, C# rewrite. |
| Ask TikTok about Godot | Would save the rewrite. | Unlikely. Do not block on it. |
| Other HTML5 channels in parallel (for example YouTube Playables, which has a Godot wrapper, or itch.io) | Reuses the Godot build. | Different audiences and rules. A side channel, not a substitute. |

Recommendation: **Cocos Creator**, because the game is 2D, the logic is TypeScript-friendly and the size limits are
tightest for non-Unity builds, which a small engine meets more easily.

## 3. What carries over and what is rebuilt

| Carries over as is | Ported (same rules, new language) | Rebuilt for the new engine |
|---|---|---|
| `cards.json`, `pictures.json`, `packs.json` and the stage tables | Board, Battle, card effects and levels, stages and star tables (`board.gd`, `battle.gd`, `stages.gd`, `card_levels.gd`) | Every screen: menu, map, battle, results, Treasury, chest opening, Cargo Hold, Market, how-to |
| Art (PNG), the design docs, the balance tools' results | Collection, packs, rewards, pity and the save format (`collection.gd`, `packs.gd`, `rewards.gd`) | The code-drawn art: chests, map, pirate rig, effects (Cocos `Graphics` or pre-rendered sprites) |
| Sounds (convert WAV to a smaller format) | The tests, as the specification of the port | The scroll behaviour (`DragScroll` has a Cocos equivalent in its ScrollView) |

Porting the logic is the safe, mechanical part: the headless tests (`run_tests.gd`, `pack_tests.gd`) become the
acceptance tests of the TypeScript version. To prove equivalence, run both versions on the same seeds and compare
the results; this needs the random generator to match, or the comparison to use properties (win rates, pity limits,
preview equals play) instead of exact sequences.

## 4. TikTok requirements checklist

Account and approvals
- A TikTok for Developers account and an **organization**; a mini game must be registered under an organization.
  **[verified]** Whether a person without a company can register is **[check]**.
- A one-time **industry qualification review** that the organization is a legitimate mini games publisher. Extra
  documents (business registration, an authorization letter) are asked for when the game link is owned by an entity
  in another country, or the verified business is only a publisher. **[verified]**
- Basic app information approved first: name, icon, description, categories. The content rules cover the name, icons
  and other parts of the listing as well as the game. **[verified]**
- Public **Terms of Service** and **Privacy Policy** URLs. **[verified]**
- A copyright self-inspection form. **[verified]** Check the licence of every asset (Section 7).

Technical
- A `minigame.config.json` file and initialization of the Mini Games SDK. **[verified]**
- **TikTok Login** implemented. **[verified]** The login call returns only a temporary code that must be exchanged on a
  game server; the client secret must never be in the game. **[verified]** So a small **backend is required**.
- Package limits for non-Unity builds: total project 30 MB, main package 4 MB, each independent package 4 MB; ordinary
  subpackages have no per-package limit. Start-up needs only the main package; the rest loads on demand. **[verified]**
- Save data normally lives on the developer's server, with sessions, saves and leaderboards. **[verified]**
- Preview on a phone by scanning a QR code in the TikTok app, then submit a version for review. A security scan runs on
  upload. **[verified]**
- Client version floor for Unity packages is TikTok 43.1.0; the floor for Cocos is **[check]**.

Review (two layers) **[verified]**
- Safety moderation: illegal goods, adult content, violence, hate, youth protection.
- Experience moderation: performance, loading on both iOS and Android, core functions, payments and walkthroughs of
  every capability the game uses. A version can be rejected for runtime problems.
- No numeric start-up or frame-rate limit is published. **[check]** in the DevTool pre-checks.

Regions
- Indonesia is a live market for mini games, and its row in the regional table reads "None" for extra requirements,
  but the snippet was ambiguous. **[check]** Vietnam needs a G1 online game licence; South Korea needs a rating;
  the UK and France use PEGI. **[verified]**
- Indonesia has a national game classification system run by the communications ministry. **[check]** whether it
  applies to a mini game distributed through TikTok (this comes from my own knowledge, not from the search).

## 5. Backend (small, but required)

| Job | Why | Notes |
|---|---|---|
| Exchange the login code for a user id | TikTok Login returns a temporary code | Keep the client secret on the server |
| Store the save (stars, collection, levels, chests, Doubloons, Pearls, pity, daily state) | Cloud save across devices; a TikTok mini game should not rely on local storage alone | The existing `pack_state` dictionary is already one document; add a version number and merge rules |
| Validate rewards that matter | Stops edited saves from claiming chests, and protects the IAP path | Start server-side only for chests and currency; keep the rest client-side |
| Optional: leaderboards, events | Social features | Not for version 1 |

A serverless function and a small database are enough at launch. Cost is low at small scale. **[check]** TikTok's
trusted-domain and webhook rules for the server address.

## 6. Product changes for TikTok

- **Sessions and first minute.** Short sessions suit the platform. Skip any menu step that is not needed: open straight
  into play for a new user, keep the tutorial but let it be skipped.
- **Portrait and touch.** Already the design.
- **Monetization.** Two models exist: in-app ads (rewarded and interstitial) and in-app purchases through the SDK.
  **[verified]** Enabling them needs an organization admin, signed contracts and tax information. **[verified]**
  The revenue share is **not** in the public pages. **[check]**
  - Ads first. Good places for a rewarded ad: double the daily crate, one extra retry after a loss, open a chest at once
    instead of waiting. Ads must be offered at natural breaks, where the player expects a reward. **[verified]**
  - Purchases later, and not random: starter bundles or "remove ads", not paid chests. The Treasury already shows odds
    and has pity, but paid random boxes add review and legal risk. This keeps design decision 1 of the card pack GDD.
- **Creator-friendly moments.** The chest opening, the win stamp and the Transcended reveal are shareable. Add a
  "share this" button if the SDK offers it. **[check]**
- **Revisit incentives.** The SDK has revisit-incentive features. **[check]** how to use them for the daily crate.
- **Growth channels.** TikTok runs a creator-video incentive program (a pool of at least 10,000 USD per developer) and
  ad products for mini games. **[verified]** Both are paid; a first launch can rely on organic reach and a few creators
  you contact directly.

## 7. Compliance and rights (do this before submission)

- **Art licence.** The pirate, barrels, cards and UI were generated with SpriteCook. Its terms must allow commercial
  use, and free-tier generations are public. **[check]** the account's licence and keep the asset manifest
  (`design/art-source/spritecook-assets.json`) as proof of origin. The earlier look-alike check on the pirate should be
  repeated for the final art.
- **Sound.** The SoundWeaver sounds are MIT, credited in `audio/CREDITS.md`. The rest are synthesized in this repo.
- **Name.** "Barrelmaw" was chosen as a unique name; do a trademark and store-name search in the launch regions.
- **Privacy and children.** TikTok's youth protections apply. Decide the age rating; do not collect more than the login
  gives. Write the Privacy Policy around that.
- **Chests and odds.** Keep the odds panel and pity meters; they are already in the game.

## 8. Phases and estimates

Estimates assume one developer working part-time with Claude Code doing most of the porting. They are guesses to plan
with, not promises.

| Phase | Work | Rough time | Gate |
|---|---|---|---|
| 0. Decisions and accounts | Choose the engine, the launch region and the monetization; register the organization; start the qualification review; write the Terms and Privacy pages | 1 to 3 weeks (reviews run in the background) | Account approved, engine chosen |
| 1. Pipeline spike | A "hello world" Cocos mini game with the SDK, login against a stub server, a QR preview on a real phone, and a package within the size limits | 1 week | The preview runs on iOS and Android |
| 2. Port the logic | Board, Battle, stages, cards, levels, packs, rewards and save in TypeScript with the ported tests; equivalence checks against the Godot results | 3 to 4 weeks | All ported tests pass; bot win rates match within a point |
| 3. Port the screens | Menu, map, battle, results, Treasury, chest opening, Cargo Hold, Market, how-to; art and sound in packages | 5 to 8 weeks | A full playthrough of the first 20 stages and the pack flow on a phone |
| 4. Platform features | Login and backend, cloud save, rewarded ads, Terms and Privacy links, analytics events | 2 to 3 weeks | Save syncs between two devices; ads pay out the reward |
| 5. QA and the self-test | The acceptance checklist, performance on a low-end phone, start-up time, size limits, a security-scan dry run | 2 weeks | Checklist all green |
| 6. Submit and iterate | Upload, preview, review, fix, resubmit; regional launch | 2 to 4 weeks (review turnaround is **[check]**) | Approved and live in the first region |
| 7. Live | Watch retention and ad revenue, fix balance, add events, then purchases | Ongoing | |

Total: about 4 to 6 months part-time; most of it is the screens in phase 3.

## 9. Risks and open questions

| Risk or question | Why it matters | How to settle it |
|---|---|---|
| Revenue share and payout terms are not public | Decides whether ads and purchases make the project worth it | Ask TikTok or read the contracts shown during enablement |
| An individual may not be able to register | Blocks everything | Check the Developer Portal registration flow before any porting |
| Start-up time and frame rate limits are unpublished | Could fail the experience review | Run the DevTool pre-checks in the phase 1 spike |
| Indonesian game classification or other regional rules | A launch blocker in one market | Ask the ministry or TikTok; pick a region with "None" first |
| Backend and privacy duties | Login needs a server and a privacy policy | Keep the backend minimal and document the data it holds |
| Art licence on the free SpriteCook tier | The copyright form and the review | Confirm the licence in the account; if unclear, redraw with a free route (a local FLUX model, Kenney's CC0 packs, or Claude-drawn code art) and keep the manifest |
| Porting effort is mostly UI | The schedule slips in phase 3 | Port screens in the order of the player's first session; ship a smaller first release |
| Two codebases (Godot and Cocos) | Fixes and balance get duplicated | Treat Godot as frozen after the port; keep one set of data files |

## 10. First steps (this week)

1. Check the Developer Portal: can you register as an individual or does it need a company? Which regions can you pick?
2. Decide the first launch region and whether ads, purchases or both will be used.
3. Install Cocos Creator and build the phase 1 spike (login stub, QR preview, size check). If it fails, nothing else
   matters yet.
4. Ask SpriteCook (or check the account) about commercial rights to the generated art.
5. Write the Privacy Policy and Terms drafts (they are needed even for the first review).
6. Start the port with the logic and its tests (phase 2); it can begin while the account review runs.

## Sources

TikTok for Developers, accessed through search on 2026-11-25. Pages carry different "last updated" dates; open them
again before acting.
- Migrate from HTML to native runtime: https://developers.tiktok.com/docs/en/migrate-from-html-to-native-runtime
- Mini Games technical overview: https://developers.tiktok.com/docs/en/mini-games-technical-overview
- Build mini games with Cocos: https://developers.tiktok.com/docs/en/build-mini-games-with-cocos
- Build mini games with Unity: https://developers.tiktok.com/docs/en/build-mini-games-with-unity
- Mini Games integration workflow: https://developers.tiktok.com/docs/en/mini-games-integration-workflow
- Release your mini game: https://developers.tiktok.com/docs/en/submit-your-app-for-review
- Acceptance testing guidelines: https://developers.tiktok.com/docs/en/acceptance-testing-guidlines
- Basic information specifications: https://developers.tiktok.com/docs/en/basic-information-specifications
- Industry qualification review: https://developers.tiktok.com/docs/en/industry-qualification-review
- Regional launch requirements: https://developers.tiktok.com/docs/en/regional-launch-requirements
- Monetization overview: https://developers.tiktok.com/docs/en/monetization-overview
- Game incentive creator videos: https://developers.tiktok.com/docs/en/game-incentive-creator-videos
- Mini Games SDK overview: https://developers.tiktok.com/docs/en/mini-games-sdk-overview
- Mini Games development troubleshooting: https://developers.tiktok.com/docs/en/mini-games-development-troubleshooting
