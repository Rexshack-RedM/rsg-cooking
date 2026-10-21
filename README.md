# rsg-cooking

A cooking system for **RSG-Core (RedM)** that works the same way as [rsg-moonshine](https://github.com/Rexshack-RedM/rsg-moonshine): cooking stations keep their own pantry, firebox and serving tray, food cooks in real time on the server (even while you're away and across restarts), and everything is run from one NUI.

---

## How it works

1. **Find a station**: target any stove on the map (**Use Stove**) or set up your own **campfire**.
2. **Choose a recipe**: recipes are grouped by category tabs. Locked recipes show the cooking level they need.
3. **Fill the pantry**: load each ingredient (up to `Config.MaxBatches` batches' worth). Unload takes them back.
4. **Feed the fire**: add `resource_wood` or `resource_coal` to the firebox. Fuel only burns while a batch is cooking; if it runs out, the batch pauses.
5. **Wait**: a batch starts as soon as the pantry holds a full batch and the fire is lit, then the next one queues automatically.
6. **Collect**: finished food sits on the serving tray (up to `Config.OutputCap`). Collecting gives the food and **cooking xp** per item.

To change recipe, the pantry, current batch and tray must be empty.

### Stations
| Type | Where | Fuel | State |
|---|---|---|---|
| `stove` | stove props in `Config.WorldStations.models` | yes | private pot per character at each stove (`Config.WorldStations.private = false` shares one pot like moonshine world stills) |
| `campfire` | placed with the `campfire` item or `/setupcampfire` | yes | owned by the player who placed it. Only the owner can put it out (it must be empty), and the kit is returned |

Recipes use `types` to choose where they can be cooked (`'all'` or e.g. `{ 'stove' }`) and can be locked to a `job`.

---

## Installation

1. Put `rsg-cooking` in your `resources` folder.
2. Items: add `installation/shared_items.lua` to `rsg-core/shared/items.lua` and copy `installation/images/*.png` to `rsg-inventory/html/images/`.
3. Database: the `rsg_cooking_stations` table is created automatically (or run `installation/rsg-cooking.sql`). The old `rsg_cooking_campfires` table is no longer used.
4. `ensure rsg-cooking` after ox_lib, oxmysql, rsg-core, ox_target and rsg-inventory.
5. Webhooks live in `server/sv_config.lua` (server only, the URLs are never sent to clients).

---

## Configuration (`shared/config.lua`)

| Option | Description |
|---|---|
| `Config.MaxBatches` | batches' worth of each ingredient the pantry holds |
| `Config.OutputCap` | max items on the serving tray |
| `Config.StationTypes` | which station types need fuel |
| `Config.WorldStations` | stove models, target distance, private or shared pots |
| `Config.Campfire` | item, model, max per player, spacing, owner-only |
| `Config.Fuels` / `Config.MaxFuel` | fuel items, seconds each burns, firebox size |
| `Config.Levels` / `Config.XpPerItem` | cooking levels (rep `cooking`, existing xp carries over) |
| `Config.Recipes` | `key, category, level, time (seconds per batch), types, job, xp, ingredients, output` |

---

## Exports

**Client**
```lua
exports['rsg-cooking']:GetCookingRecipes(category?)
exports['rsg-cooking']:GetRecipesByCookingType(stype)
```

**Server**
```lua
exports['rsg-cooking']:GetPlayerCookingXP(src)
exports['rsg-cooking']:GetPlayerCookingLevel(src)
exports['rsg-cooking']:GivePlayerCookingXP(src, amount)
exports['rsg-cooking']:GetCookingRecipes()
exports['rsg-cooking']:CanCookItem(itemName)
exports['rsg-cooking']:AddCustomRecipe({ key = 'x', category = 'Meals', level = 1, time = 60, types = 'all',
    ingredients = { { item = 'raw_meat', amount = 1 } }, output = { item = 'x', amount = 1 } })
```

---

## Security notes
- All items, fuel, xp and food are handled on the server: the client only sends which action it wants, and the server checks distance, ownership, level, job, amounts and inventory space every time.
- Stove props are map objects the server can't see, so a modded client could open a "stove" pot anywhere. To limit this, each character keeps at most **one unused pot**, and unused pots are deleted on restart.

---

## Commands
- `/setupcampfire` place a campfire (needs the `campfire` item when one is configured; the item and campfire limit are checked before the preview opens)
- `/cooking_unfocus` releases the mouse if the UI ever gets stuck

---

## Support
If you enjoy this script, consider supporting development: https://buymeacoffee.com/rexshack
