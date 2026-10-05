# Levels in Micro Jam

## How many levels are there?

**There is no last level.** There are two kinds:

| Levels | Where they come from |
|---|---|
| 1-2 | Placed by hand in `data/levels_authored.json` (the tap tutorial and the "blocked bus" lesson) |
| 3-20 | Curated from hand-picked settings (lot size, bus count, colours, twist, tutorial) by `tools/author_levels.gd`, then frozen in the same JSON file |
| 21 and up | Built by the level generator from the level number |

A generated level is the same for every player and on every replay, because
the level number is the random seed. It's also built so a solution always
exists. The generator builds it backwards from a winning exit order, plays
that order under the real rules, and has a bounded solver confirm it before
the level is used.

What's been checked:
- `tests/generator_test.gd` builds and solves **levels 21-1000** (every one).
  It also checks that they're deterministic and that HARD / SUPER HARD levels
  really are harder.
- Above 1000 the generator keeps working the same way, at the top of the
  difficulty curve. The route map, the level counter and the save have no
  upper limit.

### How difficulty grows

| Level | Buses | Colours | Lot | Comes in |
|---|---|---|---|---|
| 1 | 3 | 2 | 4 x 5 | tutorial |
| 10 | 8 | 3 | 5 x 6 | Crane (L6), Extra Bay (L8) |
| 30 | 14 | 5 | 6 x 7 | Shuffle (L12), sleeping drivers (L15), roadwork cones (L30) |
| 60 | 18 | 6 | 7 x 8 | umbrella passengers (L50), **shaped lots** start |
| 100 | 21 | 7 | 8 x 9 | tunnel (L80) |
| 200 | 27 | 8 | 9 x 10 | |
| 350 | 33 | 8 | 9 x 11 | |
| 600 | 39 | 8 | 10 x 12 | |
| 1000+ | ~42 (max) | 8 | 10 x 12 | everything mixed |

**Shaped lots.** From level 60, about 4 in 10 levels use a round, octagon,
diamond or cross-shaped lot instead of a rectangle. The cells outside the
shape are grass with bushes, and buses leaving the shape drive straight across
the grass to the ring road. Shaped lots hold fewer buses than a rectangle of
the same size (about 33-36 at 10 x 12).

**The maximum.** A 10 x 12 rectangle holds about 42 buses (`max_buses` in
`data/difficulty.json` is 45; the lot's size caps it first). The limit is
the screen, not the generator. At 10 x 12 a bus is about 66 px wide on a
1080 x 1920 phone, still tappable because taps snap to the nearest bus. On
taller 19.5:9 phones it's about 90 px. Going much past ~45 buses (12 x 14
lots and up) would need pinch-zoom on the lot. The solver and generator
handle up to about 60 buses.

### Keeping big levels beatable

Every level is solvable by construction. How *forgiving* it is gets tuned
per tier in `data/difficulty.json > tiers`:
- `target_fail`: the generator builds several candidate layouts per level
  (`candidates`) and keeps the one closest to this difficulty. Difficulty is
  measured as the share of simulated players who fail. The simulated player
  is careful: it matches colours, digs out buses that block ones it needs
  soon, and slips about 3 times per level (`generator.slips_per_level`).
  Targets: breather 0.15, normal 0.35, HARD 0.6, SUPER HARD 0.7.
- `window`: how many buses the passenger line serves at once. Fewer means more
  spare bays. It's 2 on most levels and drifts toward 1 at the very top, with
  1 fewer on breather levels.
- `color_delta`: breather levels use 2 fewer colours, normal and SUPER HARD
  1 fewer. Fewer colours means more buses can serve any given passenger.

Measured on generated levels:

| Tier | Levels 101-400 | Levels 401-1000 |
|---|---|---|
| Breather | 0.13 | 0.27 |
| Normal | 0.37 | 0.45 |
| HARD | 0.60 | 0.56 |
| SUPER HARD | 0.62 | 0.71 |

Lower these targets (or the windows) to make the game easier overall.

On top of the ramp there's a sawtooth rhythm. Every 5th level is **HARD**
(+50% coins) and every 10th is **SUPER HARD** (x2 coins), and the level after
either one is an easier breather. From their first level onward, each twist
shows up on about half the levels.

## Can we add more?

Yes. There are four ways, from least to most work:

### 1. Nothing to do: levels are already endless
Players can never run out. Level 1,000 and level 10,000 both work.

### 2. Make the generated levels feel different (no code)
Edit `data/difficulty.json`:
- `ramp`: bus count, colours, lot size (max 8 x 9), share of big 3-cell
  buses (`big`) and `window` (how many buses the queue serves at once;
  higher = more bay juggling) at each milestone level. The game interpolates
  between rows. Add a row (for example `{"level": 1000, ...}`) to keep
  raising difficulty further.
- `tiers`: how much harder HARD / SUPER HARD are, and the coin multipliers.
- `twists`: the level where each twist first appears, and `twist_chance`
  (how often twists show up afterwards).

Changing these changes every generated level, including ones players have
already reached, but nobody's progress is lost. After editing, run
`tests/generator_test.gd` to confirm every level is still solvable.

### 3. Add more hand-curated levels (a little code)
Open `tools/author_levels.gd` and add rows to `TABLE`. Each row is
`[level, w, h, buses, colours, big, window, tier, twists, tutorial]`, for
example:
```
[21, 6, 7, 12, 5, 0.25, 2, "easy", ["sleep"], ""],
```
Then run:
```
godot --headless --path . --script res://tools/author_levels.gd
```
The tool rewrites `data/levels_authored.json`. Any level number in that file
replaces the generated one, so you can hand-tune levels 21-50 (or any
others) and leave the rest generated. It also keeps levels 1-2 untouched.

To place a level fully by hand, add it to `data/levels_authored.json` in the
same format as levels 1-2 (each bus has `x`, `y`, `len` 2/3, `dir` 0 up / 1
right / 2 down / 3 left, `color` 0-7, plus a `queue` of passenger colours).
The passenger counts must match the seats: 4 per microbus, 6 per big bus.
Then run the smoke test, which solves every authored level.

### 4. New twists or new level content (code)
New mechanics, such as a ferry crossing, one-way lanes or VIP passengers, go in
`scripts/systems/park.gd` (rules), `park_solver.gd` (so the solver
understands them), `level_generator.gd` (placement) and
`scripts/gameplay/park_view.gd` (drawing). Then add an intro card to
`data/difficulty.json > twists`. Each twist should get its own test in
`tests/smoke_test.gd`.

## Ideas worth adding next
- A **daily puzzle**: seed a level from the date, the same for everyone that day.
- **Region chapters**: every 50 levels, change the backdrop town and the
  route-map scenery so long-term players see their progress.
- **Hand-tuned milestone levels** (every 50th) using option 3, as showpieces.
