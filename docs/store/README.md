# Micro Jam store kit

Everything you need for the Google Play and App Store listings. The
screenshots and art are rendered from the real game, so they always match
what players see.

## What's in this folder

| File | Size | Use |
|---|---|---|
| `screenshots/android/01..08_*.png` | 1080 x 1920 | Google Play phone screenshots (upload as is) |
| `screenshots/ios-6.5/01..08_*.png` | 1242 x 2688 | App Store 6.5" iPhone screenshots (upload as is) |
| `art/icon_512.png` | 512 x 512 | Draft Play icon, rendered from the game |
| `art/icon_1024.png` | 1024 x 1024, no alpha | Draft App Store icon |
| `art/feature_graphic_1024x500.png` | 1024 x 500 | Draft Play feature graphic |
| `art/logo_micro_jam.png` | transparent | Title logo to drop into Canva |
| `art/bus_hero_red.png`, `art/bus_trio.png` | transparent | Bus cut-outs for Canva |
| `art/khalasi_conductor.png` | transparent | The conductor mascot, cheering |
| `art/passengers.png` | transparent | A queue of passengers (one with an umbrella) |

You can upload the draft icon and feature graphic directly. The Canva prompts
below are for making a more polished version. Upload the transparent cut-outs
into Canva and build on them, so the store art matches the game exactly.

### The screenshots, in order

1. `01_home_route_map`: the route map with its bus stops and the ticket PLAY button
2. `02_clear_the_jam`: buses heading to the loading bays, passengers lining up
3. `03_bump_and_twists`: a blocked bus bumping, roadwork cones, an umbrella passenger, the Festival theme
4. `04_crane_booster`: the Crane lifting a boxed-in bus
5. `05_night_bus_park`: SUPER HARD level 80 with the tunnel, Night Bus theme
6. `06_jam_cleared`: the win screen with the cheering conductor
7. `07_bus_liveries`: the shop: bus liveries and horn sounds
8. `08_daily_tasks`: the Daily Tasks popup over the route map

Google Play takes 2 to 8 phone screenshots, so upload all 8. The App Store
takes up to 10, so upload all 8. For captions, see "Captioned screenshots"
below.

## Upload checklist

**Google Play** (Main store listing)
- App icon: 512 x 512 PNG, 32-bit. Google rounds the corners itself, so fill
  the whole square.
- Feature graphic: 1024 x 500 PNG or JPG, no transparency.
- Phone screenshots: `screenshots/android/`.

**App Store Connect**
- App icon: 1024 x 1024 PNG with no transparency and no rounded corners. Apple
  rounds them.
- iPhone 6.5" display screenshots: `screenshots/ios-6.5/`. App Store
  Connect scales these down for the smaller iPhones.
- The game is portrait and phone-only. If you turn on iPad support you'll also
  need 13" iPad screenshots.

Store size rules change from time to time. If an upload is rejected, check the
current numbers in the console.

## Brand guide (use the same in Canva)

- **Colours:** bus red `#E63946`, bus blue `#1D7FE0`, yellow `#FFC300`,
  green `#2EC27E`, purple `#8E44AD`, orange `#FF7F11`, pink `#FF5FA2`,
  teal `#12B5B0`, mountain blue `#9FB7D9`, sky `#5FA8EA`, asphalt `#B9B2A6`,
  dust `#E8DCC6`, outline navy `#17213F`.
- **Font:** Titan One for titles. It's in Canva's font list; search "Titan One".
  If it's missing, upload `assets/fonts/TitanOne-Regular.ttf` (Canva Pro) or
  use Lilita One. Write text in white or yellow with a thick navy (`#17213F`)
  outline.
- **Look:** a 3/4 top-down "die-cast toy" view, chunky rounded shapes, strong
  soft drop shadows, bright clear-morning light.
- **Never use:** temples, stupas, prayer wheels or prayer flags, deities, or
  sacred text. Never use real bus company names, real logos, real political
  symbols, or "#1" / "best" claims. The bunting is plain coloured triangles
  with no writing on them. All town names are fictional (Juneli Pul, Chiya
  Danda, Momo Chowk...).

## Canva prompt: app icon

Canva: **Create a design > Custom size 1024 x 1024 px**. Then **Apps > Magic
Media** (or Dream Lab) > **Images**. Pick the style "3D" or "Illustration"
and paste:

> A cheerful app icon for a casual mobile puzzle game: one chunky red toy
> minibus seen from a slight 3/4 front-side angle, rounded die-cast toy
> shapes, glossy roof with two thin white and yellow painted stripes, dark
> blue windows, round headlights, small luggage boxes on the roof rack. The
> bus fills most of the square and sits on a light grey road with a short
> white dashed line. Behind it, a bright blue sky with soft hazy blue
> mountains with snowy tips. Strong soft drop shadow under the bus. Clean,
> bold, high contrast, vibrant casual-game style, smooth shading, no text, no
> letters, no logos, no border, no rounded corners, centered composition,
> readable at small size.

Finishing in Canva:
1. Keep the bus big. At 48 px on a phone, only the silhouette and the red
   should read. Don't add text or a title.
2. Optional: put `art/bus_hero_red.png` on top as the bus instead of the
   generated one, so the icon matches the game exactly.
3. Download as **PNG** at 1024 x 1024 for the App Store, then resize to
   512 x 512 for Google Play (**Resize & Magic Switch**, or download at 50%).

If the AI result looks too "realistic", add *"flat-shaded cartoon, toy-like,
simple shapes"* to the prompt. If the bus is too small, add *"close-up,
bus filling 80% of the frame"*.

## Canva prompt: Google Play feature graphic

Canva: **Create a design > Custom size 1024 x 500 px**. Magic Media prompt
for the background:

> Wide banner illustration for a casual mobile game: a sunny, lively
> fictional mountain-town bus park on a clear morning. Hazy blue snow-capped
> mountains on the horizon, a few fluffy clouds, colourful plain triangle
> bunting strung across, a small tea stall with steam, colourful low
> buildings. In the foreground a light grey asphalt yard with painted yellow
> parking bays. Bright saturated colours, toy-like 3/4 top-down
> view, chunky rounded shapes, soft shadows, casual game art style, no text,
> no logos, no people's faces in close-up, no temples or religious symbols.
> Leave the left third calm and uncluttered for a title.

Finishing in Canva:
1. Left third: place `art/logo_micro_jam.png` (about 380 px wide).
2. Right two-thirds: place `art/bus_trio.png`. Put `art/khalasi_conductor.png`
   at the far right and `art/passengers.png` along the bottom edge.
3. Optional tagline under the logo, in Titan One with a navy outline:
   **"Clear the bus park jam!"**
4. Keep important things away from the outer 10%, because Google sometimes
   crops the edges or overlays a play button in the middle. Keep the centre
   free of small text.
5. Download as **PNG** (or JPG), 1024 x 500.

## Captioned screenshots (optional)

Raw screenshots are fine to upload. Captions usually lift conversion. To add
them, use Canva **Custom size 1080 x 1920** (and 1242 x 2688 for iOS) and lay
out each one like this:

- Background: sky blue `#5FA8EA` to light `#CFE6F7` gradient
- Top 22%: caption in Titan One, white with a navy outline, 2 short lines max
- Below: the screenshot scaled to about 86% width, rounded corners, drop shadow

Captions:

| Shot | Caption |
|---|---|
| 01 | **Every level is a new bus stop** |
| 02 | **Tap a bus. Clear the jam!** |
| 03 | **Bumps, cones and surprise umbrellas** |
| 04 | **Boxed in? Call the Crane!** |
| 05 | **Rush hour, day and night** |
| 06 | **Full bus? Honk and go!** |
| 07 | **Paint your buses your way** |
| 08 | **Easy daily tasks, daily rewards** |

Prompt if you want an AI background for these frames:

> Soft blurred background of a sunny cartoon bus park with hazy blue
> mountains, bright sky blue and warm yellow tones, lots of empty space,
> casual mobile game style, no text, no people.

## Store listing text (draft)

**Title** (30 characters max): `Micro Jam: Bus Park Puzzle`

**Short description** (80 max):
`Tap the buses out, fill them with the right passengers and clear the jam!`

**Full description:**

> The bus park is jammed! Tap a microbus to drive it out of the lot. If
> another bus is in the way it bumps and backs up, so plan your moves. Send
> each bus to a loading bay, and passengers hop on the bus of their colour.
> When a bus is full it honks, the conductor bangs the side, and it heads off
> to its next town.
>
> • Simple to play: one tap moves a bus
> • A real puzzle: pick the right order before the bays fill up
> • Endless levels that slowly get busier, with HARD and SUPER HARD rush hours
> • A new Daily Jam every day, free to play: keep your streak for bigger rewards
> • Three easy daily tasks and a bonus chest every day
> • Twists: sleeping drivers, roadwork cones, umbrella passengers and a tunnel
> • Boosters: Crane, Extra Bay and Shuffle Queue
> • Paint your buses, pick your horn and dress your passengers
> • Bus park themes: rainy day, festival, night bus and snowy mountain town
> • No timer, play at your own pace, works offline
>
> A cheerful, fictional bus park inspired by the busy, friendly bus stations
> of the Himalayan foothills.

## Re-rendering

Run these from the project folder. The game renders at the window size, so
the window must fit on the monitor. `--target` scales each PNG to the exact
store size. Use the biggest window your screen allows, at the same aspect
ratio, for the sharpest result.

```
# Laptop screen (what the current files were made with):
godot --path . --always-on-top --resolution 1000x1778 --script res://tools/store_shots.gd -- --set=android --target=1080x1920
godot --path . --always-on-top --resolution 820x1775 --script res://tools/store_shots.gd -- --set=ios-6.5 --target=1242x2688

# With a 4K monitor attached as screen 1 (sharper):
godot --path . --always-on-top --screen 1 --resolution 1080x1920 --script res://tools/store_shots.gd -- --set=android
godot --path . --always-on-top --screen 1 --resolution 932x2018 --script res://tools/store_shots.gd -- --set=ios-6.5 --target=1242x2688

# Icon, feature graphic and transparent cut-outs
godot --path . --always-on-top --script res://tools/store_shots.gd -- --art
```

Keep the Godot window visible while it renders. If another window covers
it, rendering stops; the tool notices the repeated frame and prints
`STALE SHOTS`, so you know to re-run. The screenshot tool uses its own save
file, never yours. Which levels and
themes it shows is set at the top of `tools/store_shots.gd`.
