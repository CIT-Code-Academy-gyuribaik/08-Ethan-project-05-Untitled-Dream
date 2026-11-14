# 08-Ethan-project-05-Untitled-Dream

Roblox game **Untitled Dream** (place 139078469414385), a first-person story game.

You follow the steps of a strange video in your apartment on a rainy day and fall into a dreamscape:

1. **Prologue** - rainy city apartment, cutscenes
2. **Cloud Meadow** - collect 5 stars
3. **Lantern Lake** - light 4 lanterns to raise a bridge
4. **Toy Town** - find 3 blocks
5. **The Empty Plain** - walk to the light
6. **Home** - a cozy mansion that slowly goes wrong, then a night of hiding and running; find 3 items and escape out the back door
7. **Golden Hour** - a calm sunset playground... with quiet kids whose faces are covered by paper notes
8. **After Hours** - an empty school at night; find the locker code, avoid the hall monitor, unlock the front doors

## Scripts (`src/`)
- `ServerScriptService/GameServer` - dream progression, admin remote
- `StarterPlayerScripts/PrologueClient` - apartment prologue + cutscenes
- `StarterPlayerScripts/DreamClient` - dream missions, doors, lighting presets
- `StarterPlayerScripts/Nightmare`, `Playground`, `School` - gameplay modules for dreams 5-7
- `Ambience` - background music / ambient sound per area (Creator Store audio)
- `AdminPanel` (P), `MouseFree` (M), `CityTraffic`, `CensorGlitch`

Map/models live in the Roblox place itself; this repo backs up the scripts.
