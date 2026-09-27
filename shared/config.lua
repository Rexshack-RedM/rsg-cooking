Config = {}

---------------------------------
-- settings
---------------------------------
Config.Image = "rsg-inventory/html/images/"
Config.MaxBatch = 10 -- max number of the same recipe that can be cooked in one go (cook time scales with quantity)

---------------------------------
-- cooking props
---------------------------------
Config.CookingProps = {
    `p_stove01x`,
    `p_stove04x`,
    `p_stove05x`,
    `p_stove06x`,
    `p_stove07x`,
    `p_stove09x`,
}

---------------------------------
-- player campfires (/setupcampfire)
---------------------------------
Config.Campfire = {
    Command       = 'setupcampfire',
    Model         = `p_campfirecombined01x`,
    SpawnDistance = 75.0,   -- campfire props are only spawned for players within this range
    PlaceDistance = 5.0,    -- max distance from the player the campfire can be placed
    MinSpacing    = 3.0,    -- min distance between two campfires
    MaxPerPlayer  = 1,      -- campfires a player can have at once
    SetupTime     = 5000,   -- ms to build the fire after placing
    Duration      = 30,     -- minutes before the fire burns out (0 = permanent until put out). Saved in the database, survives restarts
    RequiredItem  = 'campfire', -- e.g. 'campfire' to consume an item when placing, nil = free
}

---------------------------------
-- cooking types
---------------------------------
Config.CookingTypes = {
    STOVE = 'stove',        -- Cooking at stove props (Config.CookingProps)
    CAMPFIRE = 'campfire',  -- Player campfires (/setupcampfire)
    CAMPSITE = 'campsite',  -- Cooking at campsite (external script)
    COOKJOB = 'cookjob',    -- Job-specific cooking location (uses requiredjob)
    ALL = 'all'             -- Can cook at any location
}

---------------------------------
-- cooking items
---------------------------------
Config.Cooking = {

    ------------------------------------------
	-- fish recipes
    ------------------------------------------
    {
        category = 'Fish',
        cooktime = 10000,
        requiredxp = 0,      -- XP required to cook this item
        xpreward = 1,        -- XP gained after successful cooking
        requiredjob = nil,   -- nil means no job restriction (anyone can cook)
        cookingtype = 'all', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'raw_fish', amount = 1 },
        },
        receive = 'cooked_fish',
        giveamount = 1
    },
    ------------------------------------------
	-- meat recipes
    ------------------------------------------
    {
        category = 'Meat',
        cooktime = 10000,
        requiredxp = 0,
        xpreward = 1,
        requiredjob = nil,
        cookingtype = 'all', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'raw_meat', amount = 1 },
        },
        receive = 'cooked_meat',
        giveamount = 1
    },
    ------------------------------------------
	-- bread recipes (stove only - requires oven)
    ------------------------------------------
    {
        category = 'Bread',
        cooktime = 25000,
        requiredxp = 10,
        xpreward = 2,
        requiredjob = nil,
        cookingtype = 'stove', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'flour_wheat', amount = 2 },
            { item = 'milk',        amount = 1 },
            { item = 'egg',         amount = 1 },
        },
        receive = 'bread_sour',
        giveamount = 1
    },
    ------------------------------------------
	-- job-specific recipes (cookjob example)
    ------------------------------------------
    -- {
    --     category = 'Professional',
    --     cooktime = 30000,
    --     requiredxp = 50,
    --     xpreward = 10,
    --     requiredjob = 'cook',  -- Only 'cook' job can make this
    --     cookingtype = 'cookjob', -- Only at job-specific cooking locations
    --     ingredients = {
    --         { item = 'raw_meat',    amount = 2 },
    --         { item = 'flour_wheat', amount = 1 },
    --         { item = 'egg',         amount = 2 },
    --     },
    --     receive = 'gourmet_meal',
    --     giveamount = 1
    -- },
    ------------------------------------------
	-- mixed cooking type examples (multiple types)
    ------------------------------------------
    -- You can use a table of cooking types instead of a single string
    -- This allows recipes to be cooked at multiple specific locations
    -- {
    --     category = 'Mixed',
    --     cooktime = 15000,
    --     requiredxp = 0,
    --     xpreward = 3,
    --     requiredjob = nil,
    --     cookingtype = {'stove', 'campfire'}, -- Can cook at stoves OR campfires (but not campsites)
    --     ingredients = {
    --         { item = 'raw_meat', amount = 1 },
    --     },
    --     receive = 'cooked_steak',
    --     giveamount = 1
    -- },
    -- {
    --     category = 'Mixed',
    --     cooktime = 20000,
    --     requiredxp = 25,
    --     xpreward = 5,
    --     requiredjob = 'cook',
    --     cookingtype = {'stove', 'cookjob'}, -- Can cook at regular stoves OR job-specific kitchens
    --     ingredients = {
    --         { item = 'raw_fish',    amount = 2 },
    --         { item = 'flour_wheat', amount = 1 },
    --     },
    --     receive = 'fish_pie',
    --     giveamount = 1
    -- },

}
