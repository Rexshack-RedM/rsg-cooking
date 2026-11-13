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
| `locales/*.json` | en, de, el, es, fr, ja, nl, pl, pt-br, ro |

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

Support the Project : https://rexshack.tebex.store/
