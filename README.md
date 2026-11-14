# 08-Ethan-project-05-Untitled-Dream

Roblox game **Untitled Dream** (place 139078469414385), a first-person story game.

You follow the steps of a strange video in your apartment on a rainy day and fall into a dreamscape.
Nothing is ever explained outright: people you can't remember have paper notes over their faces.

## Chapter 1: The Dream
0. **Prologue** - the video, the rainy apartment, cutscenes
1. **Cloud Meadow** - collect 5 stars
2. **Lantern Lake** - light 4 lanterns to raise a bridge
3. **Toy Town** - find 3 blocks
4. **The Empty Plain** - walk to the light
5. **Home** - a cozy mansion that slowly goes wrong; a night of hiding and running
6. **Golden Hour** - a sunset playground with quiet note-faced kids
7. **After Hours** - an empty school; find the locker code, avoid the hall monitor
8. **The Lake Trip** - a peaceful morning: campfire, fishing, rowing, a timer photo
9. **The Birthday** - a living-room party; only two guests came
10. **Visiting Hours** - a 3-story hospital at night; Room 12; then escape without getting caught

## Chapter 2: Waking Up
- **Waking up** in the apartment: things followed you out of the dream; then you sleep again, deeper
11. **Too Big** - your room, three times bigger; stack books to reach the handle; a giant you walks the hall
12. **Playground at Night** - hide and seek before the lamps go out; there were always six
13. **The Summer Fair** - a happy one: ring toss, cotton candy, fireworks from the Ferris wheel
14. **The Car in the Rain** - the back seat; keep your panic down until it's over

Progress is saved (chapter select for returning players), plus 5 badges and a Flashlight game pass.

## Scripts (`src/`)
- `ServerScriptService/GameServer` - dream progression, chapters + saved progress, badges, game pass, admin remote
- `StarterPlayerScripts/PrologueClient` - prologue + cutscenes
- `StarterPlayerScripts/DreamClient` - dream missions, doors, lighting presets
- `StarterPlayerScripts/Chapters` - chapter select menu, End of Chapter 1, the Chapter 2 wake-up
- Dream modules: `Nightmare` (5), `Playground` (6), `School` (7), `Lake` (8), `Birthday` (9), `Hospital` (10), `TooBig` (11), `PlaygroundNight` (12), `Fair` (13), `CarRain` (14)
- `Ambience` (background sound per area), `Extras` (badge reports + Flashlight pass), `AdminPanel` (P), `MouseFree` (M), `CityTraffic`, `CensorGlitch`

Map and models live in the Roblox place itself; this repo backs up the scripts.
