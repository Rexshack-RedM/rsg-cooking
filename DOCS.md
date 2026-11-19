# rsg-cooking – Docs (v3.2.0)

## Contents
1. Files
2. How it works
3. Configuration
4. Exports and events
5. Database
6. Security
7. Server owner how-tos
8. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `fxmanifest.lua` | Manifest; depends on `rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql` |
| `shared/config.lua` | Stations, campfire, fuels, levels, recipes |
| `client/client.lua` | Targets, campfire placement, NUI bridge |
| `server/server.lua` | Stations, cooking ticks, actions, XP, exports |
| `server/sv_config.lua`, `server/webhooks.lua` | Webhook settings and Discord logs |
| `server/versionchecker.lua` | GitHub version check |
| `html/` | NUI (same style as rsg-moonshine) |
| `installation/rsg-cooking.sql` | Manual database install |
| `installation/shared_items.lua` | Items to add to your items file |
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro, ru |

## 2. How it works
Works the same way as rsg-moonshine.
1. **Find a station:** target a stove prop (**Use Stove**) or set up your own **campfire**.
2. **Choose a recipe** by category tab; locked recipes show the level they need.
3. **Fill the pantry** with each ingredient (up to `MaxBatches` batches). Unload takes them back.
4. **Feed the fire** with `resource_wood` or `resource_coal`. Fuel burns only while a batch cooks; if it runs out the batch pauses.
5. **Wait.** A batch starts when the pantry holds a full batch and the fire is lit; the next queues automatically.
6. **Collect** finished food from the serving tray (up to `OutputCap`). Collecting gives the food and cooking XP.

To change recipe, the pantry, current batch and tray must be empty.

| Station | Where | Notes |
|---|---|---|
| `stove` | stove props in `WorldStations.models` | Private pot per character (`WorldStations.private = false` shares one pot) |
| `campfire` | `campfire` item or `/setupcampfire` | Owned by the placer; only the owner can put it out (must be empty) and the kit is returned |

## 3. Configuration
`shared/config.lua`:
| Option | Default | Meaning |
|---|---|---|
| `InteractDist` | `3.0` | Server-side max distance |
| `SpawnDist` | `120.0` | Campfire prop spawn distance |
| `MaxBatches` | `10` | Pantry capacity per ingredient (in batches) |
| `OutputCap` | `100` | Tray capacity before cooking stops |
| `TickInterval` | `15` | Seconds between server ticks |
| `ImagePath` | `nui://rsg-inventory/html/images/` | Item images |
| `StationTypes` | table | `fuel = true/false` per type |
| `WorldStations` | table | `enabled`, `private`, `distance`, `models` |
| `Campfire` | table | `Command`, `Item`, `ReturnItem`, `Model`, `PlaceDistance`, `MinSpacing`, `MaxPerPlayer`, `SetupTime`, `OwnerOnly` |
| `Fuels` | table | Fuel item → `burnTime` seconds |
| `Levels` | `{0, 10, 50, 150, 400, 1000}` | XP needed per cooking level |
| `Recipes` | table | Recipes, inputs, outputs, level, category |

Webhook URLs are in `server/sv_config.lua`.

## 4. Exports and events
| Name | Side | Notes |
|---|---|---|
| `GetPlayerCookingXP(src)` | server export | |
| `GetPlayerCookingLevel(src)` | server export | |
| `GivePlayerCookingXP(src, amount)` | server export | |
| `GetCookingRecipes()` | server / client export | Recipe table (client takes an optional category) |
| `GetRecipesByCookingType(stype)` | client export | |
| `CanCookItem(itemName)` | server export | |
| `AddCustomRecipe(recipe)` | server export | Register a recipe from another resource |
| `rsg-cooking:server:getStations` | callback | All stations |
| `rsg-cooking:server:getState` | callback | `(id)` |
| `rsg-cooking:server:action` | callback | `(id, action, data)` pantry, fuel, recipe, collect |
| `rsg-cooking:server:getWorldStation` | callback | `(coords, stype)` |
| `rsg-cooking:server:requestCampfire` / `placeCampfire` | server events | `(coords, heading)` for placement |
| `rsg-cooking:client:syncStation` / `removeStation` | client events | Station updates |
| `rsg-cooking:client:placeCampfire` | client event | Start placement |

Command: `/setupcampfire` (name from `Campfire.Command`).

## 5. Database
`rsg_cooking_stations`: `id`, `citizenid`, `world`, `stype`, `x`, `y`, `z`, `heading`, `recipe`, `hopper`, `output`, `fuel`, `batch_left`, `last_tick`. Created automatically on start; `installation/rsg-cooking.sql` is optional.

## 6. Security
The server validates distance, ownership, pantry contents, fuel and level for every action. Cooking runs on server ticks. Clients can't set output or XP.

## 7. How-tos
- Add a recipe: add it to `Config.Recipes` (or call `AddCustomRecipe`), and make sure all items exist in `items.lua`.
- Items: wood and coal are `resource_wood` and `resource_coal`.
- Language: `setr rsg:locale "de"` in server.cfg.

## 8. Troubleshooting
| Problem | Fix |
|---|---|
| No stove option | Check `WorldStations.enabled` and that rsg-target runs |
| Batch won't start | Pantry needs a full batch and the fire needs fuel |
| Can't change recipe | Empty the pantry, batch and tray first |
| Campfire won't place | `MinSpacing`, `MaxPerPlayer`, or the item is missing |

## rsg-skills integration

`Config.Skills = { Enabled, Skill, XPScale }`. When food is collected (`rsg-cooking` collect callback) the server calls `AddXP(src, 'cooking', xp * XPScale, 'cooking')` next to the existing `AddRep`. `GivePlayerCookingXP` mirrors its XP the same way. Recipe level gates still use the rep value (`Config.XpName`). Skipped when rsg-skills is not started.


Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-cooking 3.3.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`, `rsg-target`, `oxmysql`

### Database

Tables: `rsg_cooking_stations`.

Tables are created automatically on start while `Config.AutoDatabase = true` (default). Nothing is ever dropped or overwritten.
For a manual install set `Config.AutoDatabase = false` and import `installation/rsg-cooking.sql` once.

```lua
-- shared/config.lua
Config.AutoDatabase = true -- false = import the SQL file yourself
```

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.AutoDatabase` | `true` | build the database tables automatically on start (set false and import the SQL file for a manual install) |
| `Config.InteractDist` | `3.0` | server side max distance for actions |
| `Config.SpawnDist` | `120.0` | placed campfires only spawn as props within this distance |
| `Config.MaxBatches` | `10` | the pantry holds this many batches worth of each ingredient |
| `Config.OutputCap` | `100` | max items the serving tray can hold before cooking stops |
| `Config.TickInterval` | `15` | seconds between server cooking ticks |
| `Config.ImagePath` | `'nui://rsg-inventory/html/images/'` |  |
| `Config.StationTypes` | `table` |  |
| `Config.WorldStations` | `table` | private = false -> one shared pot per stove, like rsg-moonshine world stills |
| `Config.Campfire` | `table` |  |
| `Config.Command` | `'setupcampfire'` |  |
| `Config.Item` | `'campfire'` |  |
| `Config.ReturnItem` | `true` |  |
| `Config.Model` | ``p_campfirecombined01x`` |  |
| `Config.PlaceDistance` | `5.0` |  |
| `Config.MinSpacing` | `3.0` |  |
| `Config.MaxPerPlayer` | `1` |  |
| `Config.SetupTime` | `5000` |  |
| `Config.OwnerOnly` | `false` |  |
| `Config.Fuels` | `table` |  |
| `Config.MaxFuel` | `3600` | max seconds of fuel the firebox can hold |
| `Config.CookFx` | `table` | optional particle effects on a station while it is cooking (offsets relative to the prop) |
| `Config.XpName` | `'cooking'` |  |
| `Config.XpPerItem` | `1` | xp for each item collected (recipes can override with xp) |
| `Config.Levels` | `{ 0, 10, 50, 150, 400, 1000 }` | total xp needed to reach each level (index = level) |
| `Config.Recipes` | `table` |  |
| `Config.Skills` | `table` | The cooking XP above keeps working; this also awards XP to the shared rsg-skills skill. |
| `Config.Enabled` | `true` |  |
| `Config.Skill` | `'cooking'` |  |
| `Config.XPScale` | `1` |  |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `GetPlayerCookingXP` | `src` | `server/server.lua` |
| `GetPlayerCookingLevel` | `src` | `server/server.lua` |
| `GivePlayerCookingXP` | `src, amount` | `server/server.lua` |
| `GetCookingRecipes` | `` | `server/server.lua` |
| `CanCookItem` | `itemName` | `server/server.lua` |
| `AddCustomRecipe` | `recipe` | `server/server.lua` |

**Client**

| Export | Arguments | File |
|---|---|---|
| `GetCookingRecipes` | `category` | `client/client.lua` |
| `GetRecipesByCookingType` | `stype` | `client/client.lua` |

```lua
-- example
local result = exports['rsg-cooking']:GetPlayerCookingXP(src)
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-cooking:server:getStations` | server | `_, cb` | `server/server.lua` |
| `rsg-cooking:server:getState` | server | `src, cb, id` | `server/server.lua` |
| `rsg-cooking:server:action` | server | `src, cb, id, action, data` | `server/server.lua` |
| `rsg-cooking:server:getWorldStation` | server | `src, cb, coords, stype` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-cooking:server:getStations', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnPlayerUnload` | client | `` | `client/client.lua` |
| `rsg-cooking:client:syncStation` | client | `s` | `client/client.lua` |
| `rsg-cooking:client:removeStation` | client | `id` | `client/client.lua` |
| `rsg-cooking:client:placeCampfire` | client | `` | `client/client.lua` |
| `rsg-cooking:server:requestCampfire` | server | `` | `server/server.lua` |
| `rsg-cooking:server:placeCampfire` | server | `coords, heading` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-cooking:server:requestCampfire')
-- from a server script
TriggerClientEvent('RSGCore:Client:OnPlayerLoaded', source)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/cooking_unfocus` |  | `client/client.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
