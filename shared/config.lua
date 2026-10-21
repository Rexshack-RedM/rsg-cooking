Config = {}

---------------------------------
-- general
---------------------------------
Config.InteractDist = 3.0                         -- server side max distance for actions
Config.SpawnDist    = 120.0                       -- placed campfires only spawn as props within this distance
Config.MaxBatches   = 10                          -- the pantry holds this many batches worth of each ingredient
Config.OutputCap    = 100                         -- max items the serving tray can hold before cooking stops
Config.TickInterval = 15                          -- seconds between server cooking ticks
Config.ImagePath    = 'nui://rsg-inventory/html/images/'

---------------------------------
-- station types
-- fuel = true  -> the station has a firebox and only cooks while it has fuel
-- fuel = false -> always lit, no firebox
---------------------------------
Config.StationTypes = {
    stove    = { fuel = true },
    campfire = { fuel = true },
}

-- stove props already placed around the map: target them to open the cooking UI
-- private = true  -> every character gets their own pot at each stove (nobody can take your food)
-- private = false -> one shared pot per stove, like rsg-moonshine world stills
Config.WorldStations = {
    enabled  = true,
    private  = true,
    distance = 2.0, -- ox_target distance
    models   = {
        `p_stove01x`,
        `p_stove04x`,
        `p_stove05x`,
        `p_stove06x`,
        `p_stove07x`,
        `p_stove09x`,
    },
}

---------------------------------
-- player campfires (campfire item or /setupcampfire)
---------------------------------
Config.Campfire = {
    Command       = 'setupcampfire',
    Item          = 'campfire',             -- item used to place a campfire (nil = free via command)
    ReturnItem    = true,                   -- give the item back when the owner puts the fire out
    Model         = `p_campfirecombined01x`,
    PlaceDistance = 5.0,                    -- max distance from the player the campfire can be placed
    MinSpacing    = 3.0,                    -- min distance between two cooking stations
    MaxPerPlayer  = 1,                      -- campfires a character can have at once
    SetupTime     = 5000,                   -- ms to build the fire after placing
    OwnerOnly     = false,                  -- true = only the owner can cook at / collect from their campfire
}

---------------------------------
-- fuel for the firebox: burnTime = seconds of cooking one item provides
-- fuel only burns while a batch is cooking; when it runs out the batch pauses
---------------------------------
Config.Fuels = {
    { item = 'resource_wood', burnTime = 300 },
    { item = 'resource_coal', burnTime = 900 },
}
Config.MaxFuel = 3600 -- max seconds of fuel the firebox can hold

-- optional particle effects on a station while it is cooking (offsets relative to the prop)
Config.CookFx = {
    enabled = false,
    dict = 'core',
    effects = {
        { name = 'ent_amb_smoke_moon_still', offset = vector3(0.0, 0.0, 1.0), scale = 0.6 },
    },
}

---------------------------------
-- cooking xp (stored as RSG rep 'cooking' in player metadata - same rep as before, so existing xp carries over)
---------------------------------
Config.XpName    = 'cooking'
Config.XpPerItem = 1                        -- xp for each item collected (recipes can override with xp)
-- total xp needed to reach each level (index = level)
Config.Levels = { 0, 10, 50, 150, 400, 1000 }

---------------------------------
-- recipes
-- key         unique id (use the output item name)
-- category    tab shown in the recipe picker
-- level       cooking level needed to select it
-- time        seconds per batch (real time - keeps cooking while you're away and survives restarts)
-- types       station types it can be cooked at: 'all' or a table e.g. { 'stove', 'campfire' }
-- job         optional job name / job type required (nil = anyone)
-- xp          xp per item collected (optional, defaults to Config.XpPerItem)
---------------------------------
Config.Recipes = {
    ------------------------------------------
    -- snacks
    ------------------------------------------
    { key = 'cooked_fish', category = 'Snacks', level = 1, time = 60, types = 'all',
      ingredients = { { item = 'raw_fish', amount = 1 } },
      output = { item = 'cooked_fish', amount = 1 } },
    { key = 'cooked_meat', category = 'Snacks', level = 1, time = 60, types = 'all',
      ingredients = { { item = 'raw_meat', amount = 1 } },
      output = { item = 'cooked_meat', amount = 1 } },
    { key = 'bread_toast', category = 'Snacks', level = 1, time = 60, types = 'all',
      ingredients = { { item = 'bread_loaf', amount = 1 } },
      output = { item = 'bread_toast', amount = 5 } },
    { key = 'toast_apple', category = 'Snacks', level = 1, time = 60, types = 'all',
      ingredients = { { item = 'bread_toast', amount = 5 }, { item = 'jelly_apple', amount = 1 } },
      output = { item = 'toast_apple', amount = 5 } },
    { key = 'jerky_meat', category = 'Snacks', level = 1, time = 90, types = 'all',
      ingredients = { { item = 'raw_meat', amount = 1 }, { item = 'resource_salt', amount = 5 } },
      output = { item = 'jerky_meat', amount = 1 } },
    { key = 'jerky_fish', category = 'Snacks', level = 1, time = 90, types = 'all',
      ingredients = { { item = 'raw_fish', amount = 1 }, { item = 'resource_salt', amount = 5 } },
      output = { item = 'jerky_fish', amount = 1 } },

    ------------------------------------------
    -- meals
    ------------------------------------------
    { key = 'bakedbeans', category = 'Meals', level = 1, time = 60, types = 'all',
      ingredients = { { item = 'canned_beans', amount = 1 } },
      output = { item = 'bakedbeans', amount = 1 } },
    { key = 'stew', category = 'Meals', level = 1, time = 120, types = 'all',
      ingredients = { { item = 'raw_meat', amount = 1 }, { item = 'potato', amount = 1 }, { item = 'herb_crows_garlic', amount = 1 }, { item = 'water', amount = 1 } },
      output = { item = 'stew', amount = 1 } },
    { key = 'stew_fish', category = 'Meals', level = 1, time = 120, types = 'all',
      ingredients = { { item = 'raw_fish', amount = 1 }, { item = 'potato', amount = 1 }, { item = 'herb_crows_garlic', amount = 1 }, { item = 'water', amount = 1 } },
      output = { item = 'stew_fish', amount = 1 } },
    { key = 'stew_veg', category = 'Meals', level = 1, time = 120, types = 'all',
      ingredients = { { item = 'carrot', amount = 1 }, { item = 'potato', amount = 1 }, { item = 'herb_creeping_thyme', amount = 1 }, { item = 'water', amount = 1 } },
      output = { item = 'stew_veg', amount = 1 } },
    { key = 'fish_n_chips', category = 'Meals', level = 1, time = 120, types = 'all',
      ingredients = { { item = 'raw_fish', amount = 1 }, { item = 'potato', amount = 1 } },
      output = { item = 'fish_n_chips', amount = 1 } },

    ------------------------------------------
    -- brewing
    ------------------------------------------
    { key = 'coffee', category = 'Brewing', level = 1, time = 60, types = 'all',
      ingredients = { { item = 'coffee_beanspkg', amount = 1 }, { item = 'water', amount = 2 } },
      output = { item = 'coffee', amount = 2 } },
    { key = 'tea', category = 'Brewing', level = 1, time = 60, types = 'all',
      ingredients = { { item = 'teabag', amount = 1 }, { item = 'water', amount = 1 } },
      output = { item = 'tea', amount = 1 } },
    { key = 'tea_mint', category = 'Brewing', level = 1, time = 60, types = 'all',
      ingredients = { { item = 'herb_wild_mint', amount = 1 }, { item = 'water', amount = 1 } },
      output = { item = 'tea_mint', amount = 1 } },

    ------------------------------------------
    -- bread (stove only - needs an oven)
    ------------------------------------------
    { key = 'bread', category = 'Bread', level = 2, time = 300, types = { 'stove' }, xp = 2,
      ingredients = { { item = 'flour_wheat', amount = 2 }, { item = 'milk', amount = 1 }, { item = 'egg', amount = 1 } },
      output = { item = 'bread', amount = 4 } },
    { key = 'bread_sour', category = 'Bread', level = 2, time = 300, types = { 'stove' }, xp = 2,
      ingredients = { { item = 'flour_wheat', amount = 2 }, { item = 'yeast', amount = 1 }, { item = 'milk', amount = 1 }, { item = 'egg', amount = 1 } },
      output = { item = 'bread_sour', amount = 1 } },
    { key = 'bread_loaf', category = 'Bread', level = 2, time = 300, types = { 'stove' }, xp = 2,
      ingredients = { { item = 'flour_wheat', amount = 2 }, { item = 'yeast', amount = 1 }, { item = 'milk', amount = 1 }, { item = 'egg', amount = 1 } },
      output = { item = 'bread_loaf', amount = 1 } },

    ------------------------------------------
    -- canning (stove only)
    ------------------------------------------
    { key = 'jelly_apple', category = 'Canning', level = 2, time = 180, types = { 'stove' }, xp = 2,
      ingredients = { { item = 'emptybottle', amount = 1 }, { item = 'apple', amount = 2 } },
      output = { item = 'jelly_apple', amount = 1 } },
    { key = 'jelly_blackberry', category = 'Canning', level = 2, time = 180, types = { 'stove' }, xp = 2,
      ingredients = { { item = 'emptybottle', amount = 1 }, { item = 'blackberry', amount = 5 } },
      output = { item = 'jelly_blackberry', amount = 1 } },
    { key = 'jelly_raspberry', category = 'Canning', level = 2, time = 180, types = { 'stove' }, xp = 2,
      ingredients = { { item = 'emptybottle', amount = 1 }, { item = 'raspberry', amount = 5 } },
      output = { item = 'jelly_raspberry', amount = 1 } },
    { key = 'jelly_orange', category = 'Canning', level = 2, time = 180, types = { 'stove' }, xp = 2,
      ingredients = { { item = 'emptybottle', amount = 1 }, { item = 'orange', amount = 2 } },
      output = { item = 'jelly_orange', amount = 1 } },

    ------------------------------------------
    -- desserts (stove only - needs an oven)
    ------------------------------------------
    { key = 'pie_peach', category = 'Desserts', level = 2, time = 300, types = { 'stove' }, xp = 2,
      ingredients = { { item = 'flour_wheat', amount = 2 }, { item = 'sugar', amount = 1 }, { item = 'canned_peaches', amount = 1 }, { item = 'egg', amount = 1 } },
      output = { item = 'pie_peach', amount = 1 } },
    { key = 'pie_raspberry', category = 'Desserts', level = 2, time = 300, types = { 'stove' }, xp = 2,
      ingredients = { { item = 'flour_wheat', amount = 2 }, { item = 'sugar', amount = 1 }, { item = 'raspberry', amount = 10 }, { item = 'egg', amount = 1 } },
      output = { item = 'pie_raspberry', amount = 1 } },
    { key = 'cobbler_apple', category = 'Desserts', level = 2, time = 300, types = { 'stove' }, xp = 2,
      ingredients = { { item = 'flour_wheat', amount = 2 }, { item = 'sugar', amount = 1 }, { item = 'apple', amount = 1 }, { item = 'egg', amount = 1 } },
      output = { item = 'cobbler_apple', amount = 1 } },

    ------------------------------------------
    -- ingredients
    ------------------------------------------
    { key = 'coffee_beanspkg', category = 'Ingredients', level = 2, time = 120, types = 'all', xp = 2,
      ingredients = { { item = 'coffee_beans', amount = 5 } },
      output = { item = 'coffee_beanspkg', amount = 1 } },
    { key = 'flour_wheat', category = 'Ingredients', level = 2, time = 120, types = { 'stove' }, xp = 2,
      ingredients = { { item = 'wheat', amount = 2 } },
      output = { item = 'flour_wheat', amount = 1 } },
    { key = 'resource_salt', category = 'Ingredients', level = 2, time = 120, types = 'all',
      ingredients = { { item = 'resource_salt_rock', amount = 1 } },
      output = { item = 'resource_salt', amount = 10 } },
    { key = 'sugar', category = 'Ingredients', level = 2, time = 120, types = { 'stove' }, xp = 2,
      ingredients = { { item = 'sugarcane', amount = 1 } },
      output = { item = 'sugar', amount = 1 } },
    { key = 'yeast', category = 'Ingredients', level = 2, time = 120, types = { 'stove' }, xp = 2,
      ingredients = { { item = 'flour_wheat', amount = 2 }, { item = 'water', amount = 1 } },
      output = { item = 'yeast', amount = 1 } },

    ------------------------------------------
    -- job-only example
    ------------------------------------------
    -- { key = 'gourmet_meal', category = 'Professional', level = 3, time = 300, types = { 'stove' }, job = 'cook', xp = 5,
    --   ingredients = { { item = 'raw_meat', amount = 2 }, { item = 'flour_wheat', amount = 1 }, { item = 'egg', amount = 2 } },
    --   output = { item = 'gourmet_meal', amount = 1 } },
}

---------------------------------
-- helpers (shared)
---------------------------------
function Config.RecipeAllowed(recipe, stationType)
    local t = recipe.types or 'all'
    if type(t) == 'string' then return t == 'all' or t == stationType end
    for _, v in ipairs(t) do
        if v == 'all' or v == stationType then return true end
    end
    return false
end
