# WRONG CHAT 📱💀

*Flick every text to the right person. One wrong send and it's ✓✓ SEEN.*

**Play in your browser:** https://ahmadfaizan44.github.io/wrong-chat/ · Android APK: the latest *Test, build and deploy* run under Actions → artifacts.

An original, ad-funded casual arcade game (Flutter). It is a sibling project to ROT and reuses ROT's ad stack and pacing rules.

## The game (v1)
- Texts fall from the top: "report attached 📊", "love you mum ❤️", "wanna get pizza sometime? 🍕💕".
- Drag a text sideways. Its tail shows which chat it will land in: **Mom 👩**, **Boss 💼** or **Crush 😍**. **Squad 🎉** joins after 10 correct sends.
- Tap it or flick it down to send it now. Sending early gives a +5 QUICK bonus.
- Right chat: 10 points × combo, and the chat reacts (❤️, "noted.", 😳). Wrong chat: a big **SEEN ✓✓** stamp, the screen shakes, and an embarrassed reply ("HR has been cc'd"). 3 wrong sends end the run.
- The game-over card shows a mock screenshot of your worst send. **📸 Share the cringe** sends it as a PNG through the phone's share sheet (the viral loop).
- **First run = interactive tutorial**: the first 2 texts wait mid-screen while a hand shows where to drag them. You can't be struck until you've learned the controls.
- Juice: typing dots before each reply, unsent texts pulse red just before they land, "Rush hour" banners as speed steps up, a mid-run 🏆 NEW BEST, combo pops and haptics.
- Original music loop (`tool/gen_music.mjs`, 118 BPM "phone-pop" with notification-ping ear candy). It pauses during ads and in the background, and the mute button covers it.
- App icon: a glossy chat bubble with a red SEEN ✓✓ stamp (`tool/gen_icon_test.dart`, then `sh tool/gen_icons.sh`).

## Ads (same rules as ROT, shown in-game under "?")
| Moment | Format | Why players want it |
|---|---|---|
| ↩️ **UNSEND** (once per run) | Rewarded | Revive: takes back the last wrong send |
| Double coins (shown when the run earned ≥5 🪙) | Rewarded | ×2 the run's coins |
| 🌙 Do Not Disturb +1 | Rewarded | Booster: everything falls at 45% speed for 8 s (1 is free daily, or 100 🪙; you earn 1 🪙 per 10 points) |
| Short break between runs | Interstitial (skippable ≤5 s) | Never in the first 3 sessions, at most every 3 runs, ≥90 s apart, never right after another ad |

One ad at a time (lock), and a "quick ad break" card always shows before an interstitial. Google **test** IDs are in use. Before release, swap them in `lib/ads/ad_service.dart`, the Android manifest and the iOS Info.plist, then turn **off** AdMob "High-engagement ads".

## Fair play
Every player gets the same rules. Speed depends only on how many texts you've delivered in this run, and it's capped. Each chat is equally likely to get the next text. Every message fits exactly one chat (a test checks this). Nothing is adjusted per player.

## Code map
- `lib/core/chats.dart`: chats, reactions and the message bank
- `lib/core/run.dart`: the rules (pure Dart, unit-tested)
- `lib/ui/game_screen.dart`: play screen, effects and game-over card
- `lib/ui/menu_screen.dart`: menu, Do Not Disturb shop, and How to play / odds
- `lib/ads/`: AdMob service and pacing (adapted from ROT)
- `test/`: rules, pacing, and a drag-and-send widget test

## Build (Windows)
```bash
C:/src/flutter/bin/flutter test
C:/src/flutter/bin/flutter build web --release
# Android: JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=C:\gtmp and the Android Studio JBR, as for ROT
C:/src/flutter/bin/flutter build apk --release
```

## Roadmap
- **v1 (now):** endless run, 4 chats, combo, quick bonus, DND booster, coins, UNSEND revive, ×2 coins, paced breaks.
- **v1.1, stickiness:** daily login streak gift, missions ("deliver 20 to Boss"), more message lines (aim for 40+ per chat), and localised message packs.
- **v1.2, depth:** more chats (Ex 🚩, Grandma 👵, Teacher 📚); special texts (🔥 "urgent" must go fast; 🔒 "secret" rotates its chat); themed weeks such as Valentine's.
- **v1.3, meta:** a phone-wallpaper and chat-theme collection bought with coins, missions ("deliver 20 to Boss"), and leaderboards.
- **Release:** real AdMob IDs, UMP consent, a store listing, then Play internal testing.
