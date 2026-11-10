# Short-form video plan (TikTok, Reels, YouTube Shorts)

Every video is the real game playing a scripted moment, so what people see is what they download.

```bash
python3 tools/shorts/make_shorts.py                 # the 12 pilot videos (about 6 minutes; a small window opens, leave it alone)
python3 tools/shorts/make_shorts.py --only pick     # one format: pick, cascade, mystery, stuck
python3 tools/shorts/make_shorts.py --force         # redo videos that already exist
```

Output goes to `/Volumes/External SSD/Micro Jam Shorts/`:
- `videos/NNN_format_name.mp4`: 1080×1920, 60 fps, H.264 + AAC, 6–17 s, numbered in posting order
- `posting_plan.csv`: the hook, payoff and a ready caption for each video
- `_raw/`: each video's job and frame log (raw recordings are deleted once encoded)

## The four formats

| Format | What happens | Why it should work |
|---|---|---|
| **pick** (only one bus works) | Last bay, three numbered buses, a countdown. The wrong one fails, the clip rewinds, the right one saves it | People guess and comment |
| **cascade** (one tap clears it all) | Every bay filled on purpose, then one tap and all five buses leave, counted on screen | Satisfying and rewatchable |
| **mystery** (guess the colour) | A grey bus, a countdown, the way clears and its colour pops in | Very short, easy to guess |
| **stuck** (everything blocked) | Every bus bumps another, then the Crane lifts one and the rest drive out | Problem, then rescue |

None of this is faked: `tools/shorts/find_moments.gd` searches real levels with the game's rules and solver.
A "pick" clip only exists if exactly one of the shown buses keeps the level winnable. The stuck lots are hand-built
in `shorts_director.gd`, and it checks that no bus can move before the Crane and that the lot clears after it.

## Posting

- One or two a day for two weeks, in the CSV's order, which rotates the formats. The same file goes to all three apps.
- For **pick** and **mystery**, pin a comment asking for the answer.
- After two weeks, compare how many people watched past 3 seconds per format, then make more of the winner.

## Changing things

- **Hooks, captions, which levels, themes:** `pilot_jobs()` in `tools/shorts/make_shorts.py`.
- **More positions:** `godot --headless --path . --script res://tools/shorts/find_moments.gd` rewrites `tools/shorts/moments.json`. Levels change if `data/difficulty.json` changes, so rerun it after retuning.
- **How a format plays:** `tools/shorts/shorts_director.gd`.
- **Output folder:** set `SHORTS_OUT`.
