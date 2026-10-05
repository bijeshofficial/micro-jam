# Micro Jam: Launch Guide (Google Play first, then the App Store)

Every step to get **Micro Jam: Bus Park Puzzle** from this repo into a
Google Play closed test, then production, then the App Store.

**How to use it:** tick an item by changing `[ ]` to `[x]`. If you're unsure
whether something is finished, leave it unticked and add `?` after the box.
Tell me when you've updated the file and I'll pick up the next items.

- **(you)** means only you can do it: consoles, accounts, passwords, keys.
- **(Claude)** means I do it in the code or the website. Just tell me to go.
- **(check)** means it was right as of October 2026. Store rules change often,
  so confirm it in the console.

## Key IDs and links

| What | Value |
|---|---|
| Package / bundle ID | `com.neuronnest.microjam` (**permanent** after the first upload) |
| App name | Micro Jam: Bus Park Puzzle (26 of 30 characters) |
| Privacy policy | https://www.neuronnest.com/micro-jam/privacy (page is ready in the neuron-nest repo, section 3) |
| app-ads.txt | https://www.neuronnest.com/app-ads.txt (already live; covers every app on the account) |
| AdMob publisher | `pub-7387045424284544` (same account as Aksyatra) |
| AdMob app IDs | Android `ca-app-pub-…~…` · iOS `ca-app-pub-…~…` (you create them, section 2) |
| Rewarded ad units | Android `ca-app-pub-…/…` · iOS `ca-app-pub-…/…` (you create them, section 2) |
| Support email | info@neuronnest.com |
| Version | 1.0.0 (version code 1) |

## The order that matters

1. AdMob: create the 2 apps and 2 ad units, then send me the **4 IDs** (section 2).
2. Deploy the website so the privacy page is live (section 3).
3. Make your upload key and test the build on your phone (sections 5–6).
4. Play Console: create the app, fill in every form, upload to **Closed testing** (section 7).
5. 12+ testers for 14 days, then apply for production (section 8).
6. Production launch, then the App Store (sections 9–10).

---

## 0. Already done in the code

These are in the repo now; nothing to do:

- [x] **Rewarded ads only.** No ads between levels, no banners. An ad plays
  only when the player taps "Watch ad": +1 life, a free booster, x2 coins,
  free daily coins, or the rescue when the bays are full.
- [x] **AdMob plugin** (Poing Studios v5.1.0, `addons/admob`), the same version
  that works in Aksyatra. It shows Google's consent form (EEA/UK) at startup,
  then preloads rewarded ads. The reward is given only when the player
  watches the ad to the end.
- [x] **Debug builds always use Google's test ads**; only release builds use
  your live ad units. A release build can never show the fake "TEST AD"
  screen; if no ad is ready it says so and gives nothing.
- [x] **No real-money store on Android.** The coin packs are hidden on
  Android: you can't get a Play merchant account from Nepal. On iOS they stay
  hidden until real App Store purchases are wired in (section 10). Buying
  boosters and cosmetics with in-game coins works everywhere.
- [x] **Reset progress is development-only.** It shows in debug builds only.
  Players reset by reinstalling.
- [x] **Settings** has a **Privacy** link and **Ad privacy options**. The
  options button appears only where the law requires it.
- [x] **Android export presets:**
  - **Android**: a signed **AAB** for Play;
  - **Android APK (phone test)**: an APK with test ads.
  - Both use a Gradle build, target API 36 / min 24, and 32- and 64-bit
    phones. Permissions: internet, network state, vibrate.
- [x] **Launcher icons:** `assets/app_icon/` holds the 192 px icon plus the
  adaptive foreground and background, drawn from the game's art.
- [x] **Store screenshots** (Play 1080×1920 and App Store 6.5"), a draft icon
  and a draft feature graphic, plus Canva prompts: `docs/store/`.
- [x] **Build script** `tools/build_android.sh`, tested: it built a working
  test APK on this Mac. A release build refuses to run while the AdMob IDs
  are still placeholders.

## 0.1 Decisions before you start (you)

- [ ] **Target audience.** Recommended: **13 and over**.
  - A cartoon bus game can look like it's for children. If you include
    under-13s, Google's Families policy applies: child-directed ads only, no
    personalised ads, and an extra review.
  - With 13+, aim the listing at "puzzle fans" and don't use words like
    "kids" or "children".
  - If Google later says the app "appeals to children", tell me. I'll switch
    the ads to child-directed mode.
- [ ] **iOS version 1: coin packs or not?**
  - **A (simplest):** iOS 1.0 ships like Android: ads only, no purchases. It
    needs no extra work and you can add purchases in an update.
  - **B:** I integrate real App Store purchases (StoreKit) plus the
    **Restore Purchases** button Apple requires. You create the 3 coin
    products in App Store Connect and sign the Paid Apps Agreement (section 10).
  - Android is the same either way: no purchases.

---

## 1. Accounts

### Google Play Console (you)
- [x] Developer account exists (the same one as Aksyatra and CallBreak Score)
- [ ] Open the account's **Home** page. Personal accounts created after
  13 Nov 2023 must run a **closed test with 12+ testers for 14 days in a
  row** before they can publish to production **(check)**. The app's Dashboard
  says so once the app exists.
- [ ] **Account details:** contact email and phone verified. The developer
  website is **https://www.neuronnest.com**, where AdMob looks for app-ads.txt.

### AdMob (you)
- [x] Account exists (publisher `pub-7387045424284544`)
- [ ] **Payments** (AdMob → Payments): address, payee name, tax form (W-8BEN
  for an individual outside the US) and bank account. If you already did this
  for Aksyatra it's shared; nothing to redo.

### Apple (later, once the Play closed test is running)
- [ ] Apple Developer Program, US$99 a year: https://developer.apple.com/programs/
- [ ] App Store Connect → **Business**: the Free Apps agreement is active.
  Also sign the **Paid Apps Agreement**, with banking and tax, if you chose
  option B in section 0.1.

---

## 2. AdMob: create the apps and ad units, then send me the 4 IDs (you)

You can do this now: the apps don't need to be on a store yet.

**You need 4 IDs in total:**

| # | ID | Looks like | What it is |
|---|---|---|---|
| 1 | Android **App ID** | `ca-app-pub-7387045424284544~1234567890` (with `~`) | identifies the Android app |
| 2 | Android **Rewarded ad unit ID** | `ca-app-pub-7387045424284544/1234567890` (with `/`) | the ad slot the game loads |
| 3 | iOS **App ID** | `ca-app-pub-7387045424284544~…` | identifies the iOS app |
| 4 | iOS **Rewarded ad unit ID** | `ca-app-pub-7387045424284544/…` | the iOS ad slot |

One rewarded unit per platform is enough: the game uses the same unit for
every rewarded button and decides the reward itself.

### 2.1 Android app
- [ ] Go to https://admob.google.com → **Apps** → **Add app**
- [ ] Platform: **Android**
- [ ] "Is the app listed on a supported app store?" → **No** (you'll link it
  after launch, section 9)
- [ ] App name: `Micro Jam` → **Add app**
- [ ] Copy the **App ID** (ID 1) from the confirmation screen or from **App
  settings**
- [ ] **Ad units** → **Add ad unit** → **Rewarded** → **Select**
  - Ad unit name: `Rewarded main`
  - Reward settings: amount `1`, item `reward` (the game hands out the real
    reward: coins, a life, a booster…)
  - Leave **Server-side verification** off
  - **Create ad unit**
- [ ] Copy the **Ad unit ID** (ID 2) → **Done**

### 2.2 iOS app
- [ ] **Apps** → **Add app** → Platform **iOS** → "listed on a store?" **No**
  → App name `Micro Jam` → **Add app**
- [ ] Copy the **App ID** (ID 3)
- [ ] **Ad units → Add ad unit → Rewarded**: name `Rewarded main`, amount `1`,
  item `reward` → **Create ad unit**
- [ ] Copy the **Ad unit ID** (ID 4)

### 2.3 Privacy and messaging (AdMob left menu → Privacy & messaging)
- [ ] **European regulations (GDPR):** if you already have an Aksyatra
  message, edit it and add the two Micro Jam apps. Otherwise **Create
  message**:
  - Apps: both Micro Jam apps
  - Language: English
  - Privacy policy URL: https://www.neuronnest.com/micro-jam/privacy
  - User choices: **Consent or Manage options** (the default)
  - **Publish**
- [ ] **US state regulations:** create a message (or edit the existing one)
  for both apps → **Publish**
- [ ] **IDFA explainer** (iOS app only): create it and **Publish**. It shows a
  short explanation before Apple's "Allow tracking?" prompt.

### 2.4 Blocking controls (recommended)
- [ ] **Apps** → Micro Jam (Android) → **Blocking controls** → **Content** →
  **Maximum ad content rating: PG**. Do the same for the iOS app. G blocks a
  lot of ads and lowers earnings; T and MA aren't right for a cosy puzzle
  game.
- [ ] Optional: under **Sensitive categories**, block gambling, dating and
  anything else you don't want next to the game.

### 2.5 Test devices
- [ ] **Settings** → **Test devices** → **Add test device**, and add your own
  phone. Android: the Advertising ID is in Settings → Google → Ads. This keeps
  release builds on your phone safe to test.

> **Never tap your own live ads.** AdMob can suspend the account for it.
> Debug builds use Google's test ads automatically, so they're always safe.

### 2.6 Send me the 4 IDs
- [ ] Paste them in chat, for example:
  ```
  Android app ID:      ca-app-pub-7387045424284544~...
  Android rewarded ID: ca-app-pub-7387045424284544/...
  iOS app ID:          ca-app-pub-7387045424284544~...
  iOS rewarded ID:     ca-app-pub-7387045424284544/...
  ```
- [ ] (Claude) I put them in the two places the game reads them from:
  - `data/ads.json` → `app_ids` and `ad_units`
  - `project.godot` → `[admob]` `general/android/app_id` and
    `general/ios/app_id` (the plugin writes these into the Android manifest
    and the iOS Info.plist)

  If you'd rather do it yourself, those are the only two files. Each value
  replaces an `XXXX` placeholder or one of Google's test IDs (the ones
  containing `3940256099942544`). The release build script checks for
  leftovers.

---

## 3. Website: privacy policy (Claude done, you deploy)

- [x] (Claude) The page is written: `neuron-nest/src/app/micro-jam/privacy/page.js`.
  It covers:
  - local-only game data and no accounts;
  - rewarded ads by AdMob, consent and the iOS tracking prompt;
  - no purchases on Android (App Store only on iOS);
  - deletion by uninstalling, children under 13, and contact details.
  The site builds with it.
- [x] `public/app-ads.txt` already contains `google.com, pub-7387045424284544,
  DIRECT, f08c47fec0942fa0`. One line covers every app, so nothing to add.
- [ ] (you) Commit and deploy neuron-nest, then open
  https://www.neuronnest.com/micro-jam/privacy on your phone to confirm it loads
- [ ] (you) Open https://www.neuronnest.com/app-ads.txt and confirm it shows
  that line

---

## 4. Launcher icon (you, optional)

- [ ] The game already has a launcher icon drawn from its art
  (`assets/app_icon/`). For the polished version, make the icon in Canva
  (`docs/store/README.md` has the prompts) and send it to me as a
  1024×1024 PNG. (Claude) I'll cut the 192 px icon and the adaptive
  foreground and background from it.

---

## 5. Upload key (you)

Google Play needs every upload signed with **your** key.

- [ ] Open Terminal and run this, choosing a strong password when asked:
  ```
  keytool -genkeypair -v -keystore ~/microjam-upload.keystore -alias microjam -keyalg RSA -keysize 2048 -validity 10000
  ```
  It asks for your name and organisation. "Neuron Nest" and the country
  `NP` are fine.
- [ ] **Back up `~/microjam-upload.keystore` and its password in two safe
  places**, such as a password manager plus a USB stick. Every future update
  must be signed with the same key. It never goes in the repo.
- [ ] If you use another path or alias, set them when building:
  `MICROJAM_KEYSTORE=/path/file.keystore MICROJAM_KEY_ALIAS=name tools/build_android.sh release`

## 6. Build and test on your phone (both)

The tools are already set up on this Mac: Godot 4.7.2 with its export
templates, the Android SDK at `~/Library/Android/sdk`, and JDK 17.

- [ ] (Claude or you) Test build, which uses Google's test ads:
  ```
  tools/build_android.sh test
  ```
  It makes `build/android/micro-jam-test.apk`. The test APK is big (~175 MB)
  because it carries the debug engine for two phone types. The release AAB
  is much smaller, and Play only sends each phone the part it needs.
- [ ] (you) On your Android phone: Settings → About → tap **Build number** 7
  times to unlock Developer options → Developer options → **USB debugging** on
- [ ] (you) Plug it in and install:
  ```
  ~/Library/Android/sdk/platform-tools/adb install -r build/android/micro-jam-test.apk
  ```
- [ ] (you) Play through and tick:
  - [ ] First launch: the loading screen, then the tutorial levels 1–3
  - [ ] A rewarded ad: tap "+1 life" (or x2 coins on the win screen). A
    Google **test** ad plays and the reward arrives. Closing it early
    gives nothing.
  - [ ] The game pauses and goes silent during the ad, then resumes
  - [ ] **No ad ever plays by itself** between levels
  - [ ] Shop: **no coin packs and no prices**, only boosters, the free daily
    coins (watch ad) and cosmetics
  - [ ] Settings: **no Reset progress** in the release build. The test build
    is a debug build, so it still shows "Reset progress (dev)" there.
  - [ ] Settings → **Privacy** opens the privacy page
  - [ ] The Android back button closes popups, opens Pause in a level, and
    asks before quitting on Home
  - [ ] Notch and gesture bar: nothing is cut off at the top or bottom
  - [ ] Kill the app mid-level → reopen → the level resumes
  - [ ] Airplane mode: the game still plays, and ad buttons say "Ad not
    available"
  - [ ] Daily Jam and Daily Tasks work; a Daily Jam never costs a life
- [ ] (you) Consent form: it only shows in the EEA/UK. To see it, use a VPN set
  to Germany, or ask me for a build with AdMob's debug geography switched on.
- [ ] (Claude) Fix anything you find.
- [ ] (Claude or you) Release build, once the 4 IDs are in:
  ```
  tools/build_android.sh release
  ```
  It asks for your keystore password and makes `build/android/micro-jam.aab`.

---

## 7. Google Play Console: create the app and fill in every form (you)

### 7.1 Create the app
- [ ] https://play.google.com/console → **Create app**
  - App name: `Micro Jam: Bus Park Puzzle`
  - Default language: English (United States)
  - App or game: **Game**
  - Free or paid: **Free**
  - Tick both declarations (Developer Program Policies, US export laws) →
    **Create app**

### 7.2 App content (Dashboard → "Set up your app", or Policy → App content)
Each item is a short form, and the closed test can't go out until all of them
are done.

- [ ] **Privacy policy:** `https://www.neuronnest.com/micro-jam/privacy`
- [ ] **App access:** "All functionality in my app is available without any
  access restrictions" (there's no login)
- [ ] **Ads:** "Yes, my app contains ads"
- [ ] **Content rating:** start the IARC questionnaire
  - Email: info@neuronnest.com. Category: **All other app types**, or
    **Game** if offered.
  - Violence, blood, sexuality, nudity, bad language, drugs, alcohol,
    tobacco, crude humour, fear/horror: **No**
  - Simulated gambling: **No**
  - Users can interact or communicate with each other: **No**
  - Shares the user's location with others: **No**
  - Digital purchases: **No** (none on Android)
  - Unrestricted internet access or browsing: **No**
  - Expected result: **Everyone / PEGI 3 / USK 0**
- [ ] **Target audience and content:** the ages from section 0.1 (13–15,
  16–17, 18+ recommended).
  - "Could your store listing unintentionally appeal to children?" Answer
    honestly. If it asks for more, tell me.
- [ ] **News app:** No
- [ ] **Data safety.** The game itself sends nothing off the phone; every
  item below comes from the AdMob SDK. Google's guide is "Google Mobile Ads
  SDK: data disclosure" **(check)**.
  - Does your app collect or share any of the required user data types?
    **Yes**
  - Is all user data encrypted in transit? **Yes**
  - Do you provide a way to request deletion? **Yes**: email
    info@neuronnest.com. Game data is deleted by uninstalling.
  - Data types. For each one: **Collected: Yes · Shared: Yes · Processed
    ephemerally: No · Required (not optional) · Purposes: Advertising or
    marketing, Analytics, Fraud prevention, security and compliance**
    - **Location → Approximate location** (AdMob uses the IP address)
    - **App activity → App interactions**
    - **App info and performance → Crash logs** and **Diagnostics**
    - **Device or other IDs → Device or other IDs** (the advertising ID)
- [ ] **Advertising ID:** "Yes", used for **Advertising or marketing**. The
  AdMob SDK adds the `AD_ID` permission.
- [ ] **Government apps:** No · **Financial features:** none · **Health:** No

### 7.3 Store settings and listing
- [ ] **Grow → Store presence → Store settings**
  - App category: **Games → Puzzle**
  - Tags (up to 5): Puzzle, Casual, Logic, Relaxing, Offline. Pick whichever
    Google offers.
  - Email: info@neuronnest.com · Website: https://www.neuronnest.com
- [ ] **Grow → Store presence → Main store listing**
  - [ ] App name, short description and full description (Appendix A)
  - [ ] **App icon:** 512×512 PNG, from your Canva icon or
    `docs/store/art/icon_512.png`
  - [ ] **Feature graphic:** 1024×500, from Canva or
    `docs/store/art/feature_graphic_1024x500.png`
  - [ ] **Phone screenshots:** upload all 8 from
    `docs/store/screenshots/android/`, in order (01 first)
  - [ ] Optional: 7-inch/10-inch tablet screenshots. Skip them; the game is
    built for phones.
- [ ] **Monetize → Products:** leave empty. There are no in-app products on
  Android.
- [ ] **Pricing and distribution** (under Release → Production → Countries,
  or "Select countries")
  - Free
  - Countries: all, or at least Nepal plus every country your testers live in

### 7.4 Closed testing track
- [ ] **Test and release → Testing → Closed testing** → open the default
  track ("Closed testing - Alpha") or **Create track**
- [ ] **Countries / regions:** the same as production, or at least every
  tester's country
- [ ] **Testers** tab: create a **Google Group** (easiest, e.g.
  `microjam-testers@googlegroups.com`) at https://groups.google.com, then
  paste its address. Testers join the group, so you can add people without a
  new release. An email list works too.
- [ ] **Create new release**
  - App signing: **Use Google-generated key (Play App Signing)**, the default.
    Your upload key from section 5 only signs uploads.
  - Upload `build/android/micro-jam.aab`
  - Release name: `1.0.0 (1)`
  - Release notes:
    `First test build: please play a few levels and tell us what you think!`
  - **Next** → fix any errors it lists → **Save**
- [ ] **Publishing overview** → **Send changes for review**. The first review
  usually takes a few hours to 3 days.
- [ ] Once approved, copy the **opt-in link** (Testers tab → "How testers join
  your test")

---

## 8. The 14-day closed test (you)

- [ ] **12 or more testers opted in.** Aim for 15–20, because some drop out.
  - Each one opens the opt-in link **while signed in with the Gmail they
    joined with**, taps **Become a tester**, installs from Play, and **keeps it
    installed for all 14 days**.
  - Track it on the Dashboard. The 14 days restart if you drop below 12.
  - Message to send them: Appendix B
  - Testers from Aksyatra or Pasal Sort can join this test too.
- [ ] Keep notes during the test (who found what, what you changed); the
  production application asks for them.
- [ ] Push **at least one update** during the test, such as fixes from
  feedback. (Claude) I raise `version/code` (2, 3…) and rebuild; you upload to
  the same closed track. It shows Google the test was real.
- [ ] Ask testers to actually play on several days, not just install it.
- [ ] After 14 days: Dashboard → **Apply for production**. It asks:
  - How you recruited testers and how engaged they were
  - A summary of their feedback and what you changed because of it
  - Who the app is for and what makes it different (a Nepali bus park, a
    jam puzzle with passengers, the Daily Jam)
  - Why it's ready for production
  - Usually 1–7 days to hear back

## 9. Production and after launch

- [ ] **Test and release → Production → Create new release** → **Add from
  library** (the tested AAB) → release notes → **staged rollout 20%**, then
  raise it to 100% after a day or two without crashes
- [ ] AdMob → **Apps** → Micro Jam (Android) → **App settings** → **Link to
  store** → search for "Micro Jam" → link it. Until it's linked and reviewed,
  ads serve at a limited rate.
- [ ] AdMob shows **app-ads.txt: Verified** for the app. That can take a few
  days after linking.
- [ ] Check that real ads show for other people, from a friend's phone.
  Never tap them yourself.
- [ ] Watch **Android vitals** (crashes, ANRs) and the reviews in the first week.
- [ ] Every update: (Claude) raise `version/code` and `version/name` in
  `export_presets.cfg`; Play rejects a repeated code.

---

## 10. App Store (iOS), after Play

- [ ] (you) The Apple items from section 1 are done
- [ ] (you) **Xcode** from the Mac App Store, signed in with your Apple ID
  (Xcode → Settings → Accounts)
- [ ] (Claude) iOS export preset:
  - bundle ID `com.neuronnest.microjam` and your **Team ID** (Apple
    Developer → Membership);
  - icons from the 1024 px icon;
  - AdMob's `GADApplicationIdentifier`, written by the plugin from
    `project.godot [admob]`;
  - Google's `SKAdNetworkItems` list;
  - `NSUserTrackingUsageDescription`: "Your data will be used to show you
    more relevant ads.";
  - I'll check the Poing plugin's iOS steps when we get there **(check)**.
- [ ] (Claude) If you picked option **B**: integrate StoreKit (real purchases)
  plus a **Restore Purchases** button. The coin packs then appear on iOS only.
  (you) In App Store Connect → the app → **Monetization → In-App Purchases**,
  create 3 **Consumable** products. Use these IDs:
  `com.neuronnest.microjam.coins_small`, `.coins_medium`, `.coins_large`,
  each with a price tier, a display name and a review screenshot.
- [ ] (you) App Store Connect → **Apps → + New App**: platform iOS, name
  `Micro Jam: Bus Park Puzzle`, language English (U.S.), bundle ID
  `com.neuronnest.microjam` (register it first in Developer → Identifiers if
  it isn't listed), SKU `microjam`
- [ ] (Claude) Export the Xcode project. (you) In Xcode: select **Any iOS
  Device** → **Product → Archive** → **Distribute App → App Store Connect →
  Upload**
- [ ] (you) **TestFlight:** add yourself (and anyone else) as internal
  testers and install it on a real iPhone. Check that ads play and that the
  tracking prompt appears once. TestFlight has no 14-day rule.
- [ ] (you) **App Privacy** (App Store Connect → the app → App Privacy):
  - Data collected:
    - **Identifiers → Device ID**;
    - **Location → Coarse location**;
    - **Usage data → Product interaction**, **Advertising data**;
    - **Diagnostics → Crash data**, **Performance data**.
  - Each is used for **Third-party advertising** (plus Analytics) and is
    **not linked to the user's identity**.
  - **Tracking: Yes**, because ads can be personalised with the IDFA.
  - With option B, add **Purchases → Purchase history**, used for **App
    functionality**.
- [ ] (you) **Age rating:** answer **None/No** to everything. In-app
  purchases: **Yes** only with option B. Loot boxes: **No** (coins buy
  specific items, never random ones).
- [ ] (you) **Screenshots:** iPhone 6.5" display, 1242×2688, from
  `docs/store/screenshots/ios-6.5/`. If App Store Connect asks for 6.9"
  (1320×2868), tell me and I'll render that set.
- [ ] (you) Subtitle, keywords, promotional text, description (Appendix A),
  support URL `https://www.neuronnest.com/contact`, privacy URL
- [ ] (you) **Submit for review**. Usually 24–48 hours.
- [ ] (you) After approval: AdMob → Micro Jam (iOS) → **Link to store**

---

## Appendix A. Store listing text (ready to paste)

### A.1 Short fields

| Field | Text | Limit |
|---|---|---|
| Title (Play and Apple) | Micro Jam: Bus Park Puzzle | 30 |
| Play short description | Tap the buses out, fill them with the right passengers and clear the jam! | 80 |
| Apple subtitle | Clear the Bus Park Jam! | 30 |
| Apple promotional text | Kathmandu's bus park is jammed! Tap buses out in the right order, fill them with matching passengers and clear the lot. | 170 |
| Apple keywords | `bus,jam,parking,traffic,puzzle,car out,unblock,colour,match,passenger,nepal,offline,brain,escape` | 100 |

### A.2 Full description (Play and Apple)

```
The bus park is jammed! Tap a microbus to drive it out of the lot. If another bus is in the way it bumps and backs up, so plan your moves. Send each bus to a loading bay, and the passengers hop on the bus of their colour. When a bus is full, it honks, the conductor bangs the side, and off it goes to its next town.

SIMPLE TO PLAY, CLEVER TO MASTER
• One tap moves a bus. No timers, no rush.
• Pick the right order before the bays fill up.
• Endless levels that get busier and busier, up to 40+ buses in round, octagon, diamond and cross-shaped lots.
• HARD and SUPER HARD rush hours, with an easier level right after.

TWISTS ON THE ROAD
• Sleeping drivers who need a wake-up tap
• Roadwork cones that block the way
• Passengers hiding under umbrellas
• A tunnel that sends out buses one by one

HANDY BOOSTERS
• Crane: lift any bus straight out, even a boxed-in one
• Extra Bay: open a sixth loading bay
• Shuffle Queue: put the passengers in a better order

SOMETHING NEW EVERY DAY
• A new Daily Jam every day: free to play, and a streak for bigger rewards
• Three easy Daily Tasks and a bonus chest
• Achievements and a driving licence that shows your progress

MAKE IT YOURS
• Paint your buses with fun liveries
• Pick your horn, from Peep Peep to Big Air Horn
• Dress your passengers and change the bus park's look: rainy day, festival, night bus, snowy mountain town

FAIR AND COSY
• No ads between levels. Watching an ad is always your choice, for a bonus.
• Plays offline.

All towns, buses and people in the game are fictional. Grab the wheel and clear the jam!
```
(With iOS option B, you may add "Optional coin packs available" on the App
Store version only. Keep the Play text as it is: there are no purchases on
Android.)

### A.3 Tips
- Play has no keyword field. It ranks on the title and descriptions, so the
  search words (bus, jam, parking, puzzle, passengers, offline) appear in
  normal sentences above. Don't add a keyword block.
- Only describe what's in the build you submit.
- Screenshots sell more than text. The strongest one is first.

## Appendix B. Message for testers (copy and send)

```
Hi! I've made a bus-park puzzle game called Micro Jam, and Google needs 12 people to test it for 14 days before I can publish it. Could you help?

1. Open this link on your Android phone, signed in with your Gmail: <OPT-IN LINK>
2. Tap "Become a tester", then "Download it on Google Play" and install it.
3. Please keep it installed for 14 days, and play a few levels whenever you have a minute.

If anything looks wrong or confusing, just reply to this message. Thank you so much!
```
(Replace `<OPT-IN LINK>` with the link from section 7.4. If you use a Google
Group, send the group's join link first.)

## Appendix C. Where things live in the code

| What | Where |
|---|---|
| AdMob IDs | `data/ads.json` (`app_ids`, `ad_units`) and `project.godot` `[admob]` |
| Ad logic (rewarded only) | `scripts/core/ad_manager.gd`, `scripts/ads/admob_provider.gd` |
| Where coin packs show | `data/economy.json` → `"store_platforms": ["ios"]`, `scripts/core/iap_manager.gd` |
| Coin pack products | `data/economy.json` → `coin_packs` |
| Version | `export_presets.cfg` → `version/code`, `version/name` (and `project.godot` → `config/version`) |
| Package ID | `export_presets.cfg` → `package/unique_name` |
| Build | `tools/build_android.sh test` / `release` |
| Launcher icons | `assets/app_icon/` |
| Store images | `docs/store/` (`tools/store_shots.gd` re-renders them) |
| Privacy page | `neuron-nest/src/app/micro-jam/privacy/page.js` |
