# Waterly

A water intake tracker in Flutter, where the screen itself is the glass.

<p>
  <img src="docs/screenshots/p650.png" width="230">
  <img src="docs/screenshots/p1150_tilt.png" width="230">
  <img src="docs/screenshots/p2150.png" width="230">
</p>

- **Water that follows gravity.** It reads the accelerometer, so the surface stays level when you tilt the phone and sloshes back when you stop.
- **Refraction.** The header and the big percentage wobble and pick up a colour fringe wherever the water covers them.
- **Pouring.** Tapping `+150 ml` / `+250 ml` / `Custom` pours a stream in, with bubbles and ripples. The level rises and the numbers count up.
- **Today sheet.** Every drink is logged with its time. Pull the sheet up to see more, or swipe an entry left to delete it (you can undo).
- **Daily goal.** Tap the header to change it (default 2,000 ml).
- Data is saved on the device and resets each day.

## Run it

```bash
flutter pub get
flutter run
```

Tilting only works on a real phone. On an emulator, use its virtual sensors to rotate the device.

## Code

| File | What it does |
| --- | --- |
| `lib/water_sim.dart` | Physics: level and tilt springs, waves, ripples, bubbles, the pour |
| `lib/water_painter.dart` | Draws the scene, including the refracted text |
| `lib/water_screen.dart` | Screen layout, the ticker, the accelerometer |
| `lib/water_store.dart` | Today's entries and the goal, stored with `shared_preferences` |
| `lib/widgets/` | Add buttons, the Today sheet, the amount picker |

Font: [Manrope](https://github.com/sharanda/manrope) (SIL Open Font License, see `assets/fonts/OFL.txt`).
