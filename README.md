# rsg-cooking

A cooking system for **RSG-Core (RedM)**. Players cook food through a full-screen NUI, cook several of the same recipe at once, and can set up their own campfires anywhere in the world.

---

## Features

- **Cooking UI**: recipes grouped by category tabs, with item images, cook time, XP reward and a lock for recipes that need more XP.
- **Ingredient images and amounts**: each ingredient shows its picture and `have / need` in green or red. The amounts update with the chosen quantity.
- **Batch cooking**: cook 1 to `Config.MaxBatch` of the same recipe in one go. Ingredients, output, cook time and XP all scale with the quantity.
- **Progress bar**: shows the percentage and time left, with a Stop Cooking button. The result or any error is shown inside the UI, with no pop-ups while it is open.
- **Stove cooking**: target any stove prop listed in `Config.CookingProps`.
- **Player campfires**: `/setupcampfire` places `p_campfirecombined01x` with a placement preview (rotate, place, cancel). Campfires can be targeted for campfire cooking and are saved to the database, so they survive restarts.
- **Cooking XP**: required XP per recipe, XP rewards, and optional job-restricted recipes.
- **Server-side checks**: the server checks every ingredient, the amount, the XP and the job, plus a minimum cook time and campfire distance. The client never decides a reward.
- **Discord webhooks**: optional logs for cooking, XP milestones and admin alerts for suspicious activity.
- **Translations**: ox_lib locales in en, de, el, es, fr, ja, nl, pl, pt-br and ro.

---

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_target](https://github.com/overextended/ox_target)
- [oxmysql](https://github.com/overextended/oxmysql)

---

## Installation

1. Put `rsg-cooking` in your `resources` folder.
2. **Items**: add the entries from `installation/shared_items.lua` to `rsg-core/shared/items.lua`.
3. **Images**: copy `installation/images/*.png` to `rsg-inventory/html/images/`.
4. **Database**: run `installation/rsg-cooking.sql`. The table is also created automatically on first start.
5. Add the resource to your `server.cfg` **after** its dependencies:
   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure rsg-core
   ensure ox_target
   ensure rsg-inventory
   ensure rsg-cooking
   ```
6. *(Optional)* Set the language:
   ```cfg
   setr ox:locale "en"   # en, de, el, es, fr, ja, nl, pl, pt-br, ro
   ```

---

## How to use

### Cooking at a stove
1. Walk up to a stove and use **ox_target**: **Open Cooking Menu**.
2. Pick a category tab and click a recipe.
3. Check the ingredients panel. Green means you have enough, red means you don't.
4. Set the quantity with `−` / `+`, `«` (min) / `»` (max) or by typing a number.
5. Press **Cook x N**. The progress bar fills and your character plays the cooking animation.
6. When it's done, the food goes into your inventory and the result shows in the panel.
   **Stop Cooking**, **Esc** or closing the window cancels the cook, and you keep your ingredients.

### Setting up a campfire
1. Type **`/setupcampfire`**.
2. Look where you want the fire to go. A preview follows your camera and fades out where it can't be placed.
   | Key | Action |
   |---|---|
   | `← / →` | Rotate |
   | `ENTER` | Place |
   | `BACKSPACE` | Cancel |
3. After a short setup animation, the campfire appears for everyone.
4. Target the fire and choose **Cook at Campfire** to open the cooking UI with campfire recipes.
5. The owner can target it and choose **Put Out Campfire** to remove it. Fires also burn out after `Config.Campfire.Duration` minutes.

---

## Configuration (`shared/config.lua`)

### General
| Option | Default | Description |
|---|---|---|
| `Config.Image` | `rsg-inventory/html/images/` | Where item images are loaded from |
| `Config.MaxBatch` | `10` | Max quantity of one recipe per cook |
| `Config.CookingProps` | stove models | Props that open stove cooking via ox_target |

### Campfires (`Config.Campfire`)
| Option | Default | Description |
|---|---|---|
| `Command` | `setupcampfire` | Command name |
| `Model` | `p_campfirecombined01x` | Campfire prop |
| `SpawnDistance` | `75.0` | Props only spawn for players within this range |
| `PlaceDistance` | `5.0` | Max distance from the player when placing |
| `MinSpacing` | `3.0` | Min distance between two campfires |
| `MaxPerPlayer` | `1` | Campfires a player can own at once |
| `SetupTime` | `5000` | Setup animation length (ms) |
| `Duration` | `30` | Minutes before the fire burns out (`0` = until put out) |
| `RequiredItem` | `nil` | Item used up when placing, e.g. `'campfire'` (`nil` = free) |

### Cooking types (`Config.CookingTypes`)
| Type | Used by |
|---|---|
| `stove` | Stove props |
| `campfire` | Player campfires |
| `campsite` | External scripts |
| `cookjob` | Job kitchens (external scripts) |
| `all` | Recipe can be cooked at every type |

### Recipes (`Config.Cooking`)
```lua
{
    category    = 'Bread',          -- tab name in the UI
    cooktime    = 25000,            -- ms for ONE item (multiplied by quantity)
    requiredxp  = 0,                -- cooking XP needed to unlock
    xpreward    = 2,                -- XP per item cooked
    requiredjob = nil,              -- job name/type, or nil for everyone
    cookingtype = 'stove',          -- a type above, or a list: { 'stove', 'campfire' }
    ingredients = {
        { item = 'flour_wheat', amount = 2 },
        { item = 'milk',        amount = 1 },
        { item = 'egg',         amount = 1 },
    },
    receive     = 'bread_sour',     -- item given
    giveamount  = 2,                -- amount given per cook
},
```
Every item must exist in `RSGCore.Shared.Items`. Invalid recipes are reported in the server console on start.

### Webhooks (`shared/webhook_config.lua`)
Set `WebhookConfig.WebhookURL`, then toggle events in `WebhookConfig.Events` and the details shown in `WebhookConfig.DetailedInfo`. You can also set XP milestone ranks and turn on admin alerts (`AdminNotifications`) for suspicious activity and high XP gains.

---

## Developer API

### Client
```lua
-- open the cooking UI for a cooking type
exports['rsg-cooking']:OpenCookingMenu('campsite')
TriggerEvent('rsg-cooking:client:cookingmenu', { cookingType = 'campsite' })

exports['rsg-cooking']:GetCookingRecipes(category?)
exports['rsg-cooking']:GetCookingCategories()
exports['rsg-cooking']:GetRecipeByItem(itemName)
exports['rsg-cooking']:GetRecipeIngredients(itemName)
exports['rsg-cooking']:GetRecipesByCookingType(cookingType?)
```

### Server
```lua
exports['rsg-cooking']:ProcessCooking(src, recipe)              -- cook a recipe table directly
exports['rsg-cooking']:ProcessCookingWithJobCheck(src, recipe)
exports['rsg-cooking']:CheckPlayerIngredients(src, ingredients)
exports['rsg-cooking']:GetPlayerCookingXP(src)
exports['rsg-cooking']:GivePlayerCookingXP(src, amount)
exports['rsg-cooking']:AddCustomRecipe(recipe)                  -- shows in the UI straight away
exports['rsg-cooking']:GetCookingRecipes()
exports['rsg-cooking']:CanCookItem(itemName)
exports['rsg-cooking']:CheckPlayerJob(src, job)
exports['rsg-cooking']:GetPlayerJob(src)
exports['rsg-cooking']:GetRecipeJobRequirement(itemName)
exports['rsg-cooking']:GetRecipesByJob(jobName)
```

---

## Translations

Locale files live in `locales/*.json` and use ox_lib's `locale()`. To add a language, copy `en.json` to `<code>.json`, translate the values (keep every `%s`) and set `setr ox:locale "<code>"`.
