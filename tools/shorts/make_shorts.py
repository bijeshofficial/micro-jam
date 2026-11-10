#!/usr/bin/env python3
"""Short-form videos (TikTok / Reels / YouTube Shorts) performed by the real game.

    python3 tools/shorts/make_shorts.py                 # the pilot set (a small window opens; leave it alone)
    python3 tools/shorts/make_shorts.py --only pick     # one format: pick, cascade, mystery, stuck
    python3 tools/shorts/make_shorts.py --limit 1       # first video of each format
    python3 tools/shorts/make_shorts.py --force         # redo finished videos

Positions come from tools/shorts/moments.json (tools/shorts/find_moments.gd).
Output: OUT/videos/NNN_format_name.mp4 (1080x1920, 60 fps, H.264 + AAC), numbered in
a suggested posting order, plus OUT/posting_plan.csv (hook, payoff, caption).
"""
import argparse
import csv
import json
import os
import subprocess

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
OUT = os.environ.get("SHORTS_OUT", "/Volumes/External SSD/Micro Jam Shorts")
RAW = os.path.join(OUT, "_raw")
VIDEOS = os.path.join(OUT, "videos")
FPS = 60
HASHTAGS = "#puzzle #mobilegame #indiegame #satisfying #bus #parkingjam"

# Renders the normal 1080x1920 layout whatever the screen size: only the window is small.
OVERRIDE = """[display]

window/size/viewport_width=1080
window/size/viewport_height=1920
window/size/window_width_override=450
window/size/window_height_override=800
window/stretch/mode="viewport"
window/size/always_on_top=true
"""

COLORS = [c["name"].upper() for c in json.load(open(os.path.join(ROOT, "data/meta.json")))["colors"]]


def pilot_jobs():
    """12 videos: 3 of each format, picked for variety (lots, colours, themes)."""
    m = json.load(open(os.path.join(ROOT, "tools/shorts/moments.json")))
    jobs = []

    def take(items, n, key=lambda x: x["level"]):
        out, seen = [], set()
        for it in items:
            k = key(it)
            if k not in seen:
                seen.add(k)
                out.append(it)
            if len(out) == n:
                break
        return out

    # Only one bus works: two traps (same colour, only one wins) and a plain one.
    readable = [x for x in m["pick"] if x["rows"] <= 9]
    chains = take(sorted([x for x in readable if not x["trap"]], key=lambda x: -x["right_departs"]), 2)
    traps = take([x for x in readable if x["trap"]], 1)
    plain_hooks = iter([("ONE BUS SAVES THIS LEVEL", "Comment 1, 2 or 3"), ("LAST BAY. PICK WRONG AND IT'S OVER", "Comment 1, 2 or 3")])
    # The finder lists the right bus first, so number them differently in each video.
    answer_at = iter([1, 2, 0])
    for it, theme in zip(chains + traps, ["theme_morning", "theme_festival", "theme_night"]):
        opts = [o for o in it["options"] if o != it["right"]]
        opts.insert(next(answer_at), it["right"])
        it = dict(it, options=opts)
        front = it["start"]["queue"][it["start"]["qpos"]]
        name = COLORS[front]
        same = sum(1 for o in opts if it["start"]["buses"][int(o)]["color"] == front)
        if it["trap"] and same >= 2:
            hook = ("%d %s BUSES. ONLY 1 WORKS." % (same, name), "Which one? Comment 1, 2 or 3")
        else:
            hook = next(plain_hooks)
        jobs.append(dict(it, kind="pick", name="pick_L%d" % it["level"], theme=theme, hook=hook[0], sub=hook[1], payoff="SAVED!",
                         caption="Last bay left and only one bus works. Which would you tap? %s" % HASHTAGS))

    # One tap clears every bay.
    casc_hooks = [("I'M FILLING EVERY BAY ON PURPOSE", "Trust me"), ("EVERY BAY IS ABOUT TO BE FULL", "Wait for it..."), ("WATCH WHAT ONE TAP DOES", "Wait for it...")]
    for it, hook, theme in zip(take(m["cascade"], 3), casc_hooks, ["theme_morning", "theme_snow", "theme_festival"]):
        jobs.append(dict(it, kind="cascade", name="cascade_L%d" % it["level"], theme=theme, hook=hook[0], sub=hook[1], payoff="%d BUSES. ONE TAP." % it["departs"],
                         caption="%d buses waiting and one tap sends them all off. So satisfying. %s" % (it["departs"], HASHTAGS)))

    # Guess the colour: one reveal, one the line needs, three in a row.
    triple = [x for x in m["mystery"] if len(x["pairs"]) == 3]
    wanted = [x for x in m["mystery"] if x.get("wanted") and len(x["pairs"]) == 1]
    single = [x for x in m["mystery"] if len(x["pairs"]) == 1 and not x.get("wanted") and not x.get("failed")]
    if wanted:
        it = wanted[0]
        name = COLORS[it["pairs"][0]["color"]]
        jobs.append(dict(it, kind="mystery", name="mystery_need_L%d" % it["level"], theme="theme_morning", hook="WHAT COLOUR IS THE GREY BUS?", sub="The line is waiting. Comment your guess", payoff="%s!" % name,
                         caption="Grey buses hide their colour until the way is clear. Did you guess it? %s" % HASHTAGS))
    if triple:
        it = triple[0]
        jobs.append(dict(it, kind="mystery", name="mystery_three_L%d" % it["level"], theme="theme_festival", hook="3 SECRET BUSES", sub="Can you guess all 3?", payoff="HOW MANY DID YOU GET?",
                         caption="Three grey buses, three guesses. How many did you get? %s" % HASHTAGS))
    for it in take(single, 3 - sum(1 for j in jobs if j["kind"] == "mystery")):
        name = COLORS[it["pairs"][0]["color"]]
        jobs.append(dict(it, kind="mystery", name="mystery_L%d" % it["level"], theme="theme_snow", hook="WHAT COLOUR IS THIS BUS?", sub="Comment your guess", payoff="%s!" % name,
                         caption="Grey buses hide their colour until the way is clear. What did you guess? %s" % HASHTAGS))

    # Everything is stuck, then the Crane.
    stuck = [("small", "EVERY BUS IS STUCK", "Each one blocks the next", "theme_morning"),
             ("big", "THIS LOOKS IMPOSSIBLE", "Not one bus can leave", "theme_night"),
             ("double", "A JAM INSIDE A JAM", "How do you get out of this?", "theme_festival")]
    for layout, head, sub, theme in stuck:
        jobs.append({"kind": "stuck", "name": "stuck_" + layout, "layout": layout, "theme": theme, "hook": head, "sub": sub, "payoff": "JAM CLEARED",
                     "caption": "Every bus blocks another. There's only one way out of this. %s" % HASHTAGS})
    return jobs


def record(job, force):
    job_path = os.path.join(RAW, job["name"] + ".job.json")
    log = os.path.join(RAW, job["name"] + ".json")
    avi = os.path.join(RAW, job["name"] + ".avi")
    json.dump(job, open(job_path, "w"))
    print("  recording", job["name"], flush=True)
    override = os.path.join(ROOT, "override.cfg")
    try:
        open(override, "w").write(OVERRIDE)
        r = subprocess.run([GODOT, "--path", ROOT, "--write-movie", avi, "--fixed-fps", str(FPS),
                            "--script", "res://tools/shorts/record_short.gd", "--", "--job=" + job_path, "--log=" + log],
                           capture_output=True, text=True, timeout=600)
        for line in r.stdout.splitlines() + r.stderr.splitlines():
            if "SCRIPT ERROR" in line or "Parse Error" in line or "Assertion failed" in line:
                print("   ", line)
    finally:
        if os.path.exists(override):
            os.remove(override)
    if not os.path.exists(log):
        print("  ! no log for", job["name"])
        return None, avi
    return json.load(open(log)), avi


def encode(avi, log, out_path):
    """Keeps only the logged frame ranges, then encodes."""
    expr = "+".join("between(n\\,%d\\,%d)" % (a, b - 1) for a, b in log["keep"])
    aexpr = "+".join("between(t\\,%.4f\\,%.4f)" % (a / FPS, b / FPS) for a, b in log["keep"])
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", avi,
                    "-vf", "select='%s',setpts=N/FRAME_RATE/TB,format=yuv420p" % expr,
                    "-af", "aselect='%s',asetpts=N/SR/TB,loudnorm=I=-14:TP=-1.5:LRA=11" % aexpr,
                    "-c:v", "libx264", "-preset", "medium", "-crf", "19", "-profile:v", "high", "-r", str(FPS),
                    "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2", "-movflags", "+faststart", out_path], check=True)


def seconds(path):
    return float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only")
    ap.add_argument("--limit", type=int)
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()
    os.makedirs(RAW, exist_ok=True)
    os.makedirs(VIDEOS, exist_ok=True)
    jobs = pilot_jobs()
    # Posting order: rotate through the formats so the feed never repeats one.
    order = []
    by_kind = {k: [j for j in jobs if j["kind"] == k] for k in ["pick", "cascade", "mystery", "stuck"]}
    for i in range(3):
        for k in ["pick", "cascade", "stuck", "mystery"]:
            if i < len(by_kind[k]):
                order.append(by_kind[k][i])
    rows = []
    done = {}
    for no, job in enumerate(order, 1):
        kind = job["kind"]
        done[kind] = done.get(kind, 0) + 1
        out = os.path.join(VIDEOS, "%03d_%s.mp4" % (no, job["name"]))
        selected = (not a.only or kind == a.only) and (not a.limit or done[kind] <= a.limit)
        if selected and (a.force or not os.path.exists(out)):
            log, avi = record(job, a.force)
            if log:
                encode(avi, log, out)
                print("   ->", os.path.basename(out), "%.1f s" % seconds(out), flush=True)
            if os.path.exists(avi):
                os.remove(avi)
        if os.path.exists(out):
            rows.append({"order": no, "file": os.path.basename(out), "kind": kind, "seconds": "%.1f" % seconds(out),
                         "hook": job["hook"] + " / " + job["sub"], "payoff": job["payoff"], "caption": job["caption"]})
    with open(os.path.join(OUT, "posting_plan.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["order", "file", "kind", "seconds", "hook", "payoff", "caption"])
        w.writeheader()
        w.writerows(rows)
    print("%d videos in %s" % (len(rows), VIDEOS))


if __name__ == "__main__":
    main()
