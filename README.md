# Micro Jam

Kathmandu's bus park is jammed. Tap microbuses to drive them out to the
loading bays; colour-matched passengers hop on; full buses honk and leave.
A portrait puzzle game for mobile (Godot 4, GDScript, 2D, Compatibility
renderer). There are infinite seeded levels, and every one is guaranteed solvable.

## Docs

- [`docs/LAUNCH_GUIDE.md`](docs/LAUNCH_GUIDE.md): every step to launch on Google Play and the App Store (AdMob IDs, Play Console forms, closed test, iOS).
- [`docs/LEVELS.md`](docs/LEVELS.md): how many levels there are and how to add more.
- [`docs/store/README.md`](docs/store/README.md): the store kit, with
  ready-to-upload screenshots (Google Play 1080x1920, App Store 6.5"
  1242x2688), a draft icon and feature graphic, transparent art cut-outs, Canva
  prompts and draft listing text.

## Run

- **Editor:** open `project.godot` in Godot 4.3+ (tested on 4.7.2) and press Play.
  The mouse works as touch (`emulate_touch_from_mouse`). Escape acts as the Android back button.
- **Command line:**
  ```
  /Applications/Godot.app/Contents/MacOS/Godot --path .
  ```
  Useful flags after `--`: `--safe-debug` (fake notch insets), `--ad-fail` (every mock ad fails).

## Tests

```
# Rules (path-clear in all 4 directions x both bus lengths, boarding, fail,
# twists, boosters), level 1 solved by real touch input, failure + lives,
# rescue, resume, back button, ads, IAP, shop, achievements, save/load,
# corrupt save + migration, layout at 1080x1920 and 1080x2400, audio/haptic hooks.
godot --headless --path . --script res://tests/smoke_test.gd

# Levels 21-400: generated, solved by the bounded solver within budget,
# stored solution works, deterministic, difficulty follows the rhythm.
godot --headless --path . --script res://tests/generator_test.gd

# A real two-process relaunch: board, coins, lives, boosters, cosmetics, settings.
godot --headless --path . --script res://tests/relaunch_check.gd -- --phase=write
godot --headless --path . --script res://tests/relaunch_check.gd -- --phase=verify

# Every script and scene compiles.
godot --headless --path . --script res://tools/parse_check.gd

# Store screenshots and Canva art: see docs/store/README.md (tools/store_shots.gd).

# Screenshots for visual review (needs a window).
godot --path . --resolution 540x960 --always-on-top --no-focus-pause --script res://tests/capture.gd -- --out=/tmp/shots --set=boot,hub,play,action,win,popups,themes
```
All tests use their own save files, never the player's `user://save.json`.

## Daily features

- **Daily Tasks** (Home, left side): 3 easy tasks a day, such as "Win 2 levels",
  "Send 10 full buses" or "Use a booster". They're picked from `data/daily.json`
  using the date as the seed. Each task has a reward, and claiming all three
  opens a bonus chest.
- **Daily Jam** (Home, left side): one extra level a day, generated from the
  date and sized to your progress. It's free to play (no lives) and doesn't move
  your level on. Clearing it on consecutive days builds a streak worth more coins.
- `scripts/core/daily_manager.gd` handles both. Progress counts how much each
  stat has grown since the day began, so tasks need no extra hooks in
  gameplay.

## How a level works

`scripts/systems/park.gd` holds the rules and nothing else: a grid lot,
buses 2 or 3 cells long facing up, right, down or left, five loading bays and one
passenger queue. A tapped bus drives out if every cell to the lot edge is
free; otherwise it bumps the first blocker and backs up (no penalty). The
front passenger boards the earliest-arrived bay bus of their colour; a full
bus (micro 4 seats, bus 6) leaves. The level is lost when every bay is taken and
the front passenger fits none of them.

Twists: sleeping driver (L15, tap twice), roadwork cones (L30, gone after 3
buses leave), umbrella passengers (L50, colour hidden until the front),
tunnel (L80, buses roll out one by one in a fixed order).

Big levels grow to about 42 buses on a 10 x 12 lot. From level 60 some lots are
round, octagon, diamond or cross-shaped (`scripts/systems/lot_shape.gd`).
The cells outside the shape are grass that buses drive straight over, so the
rules and the solver don't change.

## Levels

- 1-2 are hand-placed; 3-20 are curated from hand-picked parameters by
  `tools/author_levels.gd` and frozen in `data/levels_authored.json`.
- 21+ come from `scripts/systems/level_generator.gd`, seeded by the level
  number. The generator builds in reverse: it picks an exit order, then places
  buses from last-to-leave to first so that no exit path crosses a bus that
  leaves later. It builds the queue from that order with a controlled
  interleave, checks it by playing the order lazily under the real rules, and
  then verifies it with the bounded solver (`park_solver.gd`). Simulated
  imperfect players measure how punishing each candidate is: HARD and SUPER HARD
  keep the most punishing one, and easy levels keep the gentlest.
- The next level is generated on a worker thread while you play.

## Tuning

- Bus-count ramp, lot sizes, colours, interleave window, rhythm (HARD every
  5th, SUPER HARD every 10th, easy after), twists and solver budgets:
  `data/difficulty.json`.
- Rewards, booster prices, lives, shop items and cosmetics: `data/economy.json`.
- Colours, town names, bus names, avatars, tips: `data/meta.json`.
- Achievements: `data/achievements.json`.
- Daily tasks, bonus chest and Daily Jam rewards: `data/daily.json`.

## Replacing placeholder art

All art is drawn in code and isolated:
- `scenes/components/bus_visual.tscn` (`scripts/visuals/bus_art.gd`)
- `passenger_visual.tscn` and `khalasi_visual.tscn` (`people_art.gd`)
- `park_backdrop.gd`, `bus_wipe.gd`, `route_map.gd` and `game_logo.gd`

Gameplay talks to the visuals only through their public methods (`travel`,
`bump`, `wake`, `add_passenger`, `hop_to`, `bang`, `cheer`, ...), so sprites
can replace the `_draw()` code without touching gameplay. Sounds are
generated (`tone_synth.gd`). Drop `assets/audio/<id>.ogg` (or `.wav`) to replace
any of them, and `assets/audio/music.ogg` to replace the music.

## Ads and purchases

- **Ads are rewarded only.** There are no ads between levels and no banners.
  `AdManager` uses the AdMob plugin (`addons/admob`, `scripts/ads/`) on
  phones, and Google's consent form runs first. Debug builds use Google's test
  ads and a labelled "TEST AD" overlay on desktop. A release build without
  AdMob shows no ads and never grants a fake reward. The IDs go in
  `data/ads.json` and `project.godot [admob]`.
- **Real-money coin packs are App Store only** (`data/economy.json`
  `store_platforms`). They're hidden on Android (no Play merchant account) and
  hidden on iOS too until a StoreKit backend replaces the mock
  `IAPManager.buy()`. Desktop debug builds can show the mock store with
  `-- --store`.
- **Reset progress** is in debug builds only.
- The game is fully playable without ads or purchases.

## Layout

```
data/              JSON tuning tables + authored levels
scripts/core/      autoloads (no class_name): Save, Game, Currency, Progression,
                   Lives, Booster, Achievement, Audio, Haptics, Pool, VFX,
                   Screen, Ad (mock), IAP (mock), Daily
scripts/systems/   Park (rules), ParkSolver, LevelGenerator, ToneSynth
scripts/gameplay/  Gameplay (level flow), ParkView (drawing + animation
                   timeline), TutorialDirector
scripts/ui/        hub, pages, route map, bottom dock, popups (incl. daily),
                   win panel, settings, buttons
scripts/visuals/   code-drawn art (buses, people, backdrop, wipe, logo, ...)
assets/ui/         game_theme.tres (built by tools/build_theme.gd)
assets/fonts/      Titan One + Baloo 2 (OFL)
tests/, tools/
```
