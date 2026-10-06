# Waterly

<img src="docs/screenshots/icon.png" width="96" align="right">

A water intake tracker in Flutter, where the screen itself is the glass.

<p>
  <img src="docs/screenshots/main.png" width="200">
  <img src="docs/screenshots/tilt.png" width="200">
  <img src="docs/screenshots/goal.png" width="200">
  <img src="docs/screenshots/settings.png" width="200">
</p>

<p>
  <img src="docs/screenshots/ob1.png" width="230">
  <img src="docs/screenshots/ob2.png" width="230">
  <img src="docs/screenshots/ob3.png" width="230">
</p>

- **Onboarding.** Three pages over live water that rises as you swipe. The last page sets your daily goal. It only shows on first launch.
- **Water that follows gravity.** It reads the accelerometer, so the surface stays level when you tilt the phone and sloshes back when you stop.
- **Refraction.** The header and the big percentage wobble and pick up a colour fringe wherever the water covers them.
- **Pouring.** Tapping `+150 ml` / `+250 ml` / `Custom` sends up bubbles and ripples. The level rises and the numbers count up.
- **Goal-reached moment.** Hitting 100% makes the water surge and bubble, with a buzz.
- **Today sheet.** Every drink is logged with its time. Pull the sheet up to see more, or swipe an entry left to delete it (you can undo).
- **This week and streak.** Seven tiny glasses next to "Today" show each day's level, plus how many days in a row you've hit your goal.
- **Your own cups.** Long-press `+150` or `+250` to set your mug or bottle size.
- **Gentle reminders.** Off by default. When on, they come every 1–3 hours within the hours you choose, and stay quiet when you've just had a drink, are ahead of pace, or have hit your goal.
- **Settings** (top-left button): daily goal, cup sizes and reminders. You can also tap the header to change the goal.
- Data is saved on the device and resets each day.

## Run it

```bash
flutter pub get
flutter run
```

Tilting only works on a real phone. On an emulator, use its virtual sensors to rotate the device.

To build an APK you can install on an Android phone:

```bash
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk
```

The release build is signed with the debug key, which is fine for installing it yourself. Publishing to the Play Store needs your own signing key.

## Icon

The icon is drawn in code (`tool/icon/generate_icon_test.dart`). To regenerate it:

```bash
flutter test tool/icon --update-goldens && cp tool/icon/icon_*.png assets/icon/
dart run flutter_launcher_icons
```

## Code

| File | What it does |
| --- | --- |
| `lib/water_sim.dart` | Physics: level and tilt springs, waves, ripples, bubbles, the pour |
| `lib/water_painter.dart` | Draws the scene, including the refracted text |
| `lib/water_screen.dart` | Screen layout, the ticker, the accelerometer |
| `lib/onboarding_screen.dart` | First-launch onboarding and goal picker |
| `lib/water_store.dart` | Entries per day, goal, cups, reminder settings, streak |
| `lib/reminders.dart` | Plans and schedules reminders (`flutter_local_notifications`) |
| `lib/widgets/` | Add buttons, Today sheet, week strip, settings and amount sheets |
| `tool/render/` | Renders app screens to PNG (`flutter test tool/render --update-goldens`) |

Font: [Manrope](https://github.com/sharanda/manrope) (SIL Open Font License, see `assets/fonts/OFL.txt`).
