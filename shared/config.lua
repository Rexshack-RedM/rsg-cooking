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
	-- snack recipes
    ------------------------------------------
    {
        category = 'Snacks',
        cooktime = 10000,
        requiredxp = 0,      -- XP required to cook this item
        xpreward = 1,        -- XP gained after successful cooking
        requiredjob = nil,   -- nil means no job restriction (anyone can cook)
        cookingtype = 'all', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'raw_fish',    amount = 1 },
        },
        receive = 'cooked_fish',
        giveamount = 1
    },
    {
        category = 'Snacks',
        cooktime = 10000,
        requiredxp = 0,
        xpreward = 1,
        requiredjob = nil,
        cookingtype = 'all', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'raw_meat',    amount = 1 },
        },
        receive = 'cooked_meat',
        giveamount = 1
    },
    {
        category = 'Snacks',
        cooktime = 10000,
        requiredxp = 0,      -- XP required to cook this item
        xpreward = 1,        -- XP gained after successful cooking
        requiredjob = nil,   -- nil means no job restriction (anyone can cook)
        cookingtype = 'all', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'bread_loaf',    amount = 1 },
        },
        receive = 'bread_toast',
        giveamount = 5
    },
    {
        category = 'Snacks',
        cooktime = 10000,
        requiredxp = 0,      -- XP required to cook this item
        xpreward = 1,        -- XP gained after successful cooking
        requiredjob = nil,   -- nil means no job restriction (anyone can cook)
        cookingtype = 'all', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'bread_toast',    amount = 5 },
            { item = 'jelly_apple',    amount = 1 },

        },
        receive = 'toast_apple',
        giveamount = 5
    },
    {
        category = 'Snacks',
        cooktime = 10000,
        requiredxp = 0,      -- XP required to cook this item
        xpreward = 1,        -- XP gained after successful cooking
        requiredjob = nil,   -- nil means no job restriction (anyone can cook)
        cookingtype = 'all', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'bread_toast',    amount = 5 },
            { item = 'jelly_apple',    amount = 1 },

        },
        receive = 'toast_apple','emptybottle',
        giveamount = 5
    },
    {
        category = 'Snacks',
        cooktime = 10000,
        requiredxp = 0,
        xpreward = 1,
        requiredjob = nil,
        cookingtype = 'all', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'raw_meat',            amount = 1 },
            { item = 'resource_salt',       amount = 5 },
        },
        receive = 'jerky_meat',
        giveamount = 1
    },
    {
        category = 'Snacks',
        cooktime = 10000,
        requiredxp = 0,
        xpreward = 1,
        requiredjob = nil,
        cookingtype = 'all', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'raw_fish',            amount = 1 },
            { item = 'resource_salt',       amount = 5 },
        },
        receive = 'jerky_fish',
        giveamount = 1
    },
    ------------------------------------------
	-- Meal recipes
    ------------------------------------------
    {
        category = 'Meals',
        cooktime = 10000,
        requiredxp = 0,
        xpreward = 1,
        requiredjob = nil,
        cookingtype = 'all', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'canned_beans', amount = 1 },
        },
        receive = 'bakedbeans',
        giveamount = 1
    },
    {
        category = 'Meals',
        cooktime = 10000,
        requiredxp = 0,
        xpreward = 1,
        requiredjob = nil,
        cookingtype = 'all', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'raw_meat',            amount = 1 },
            { item = 'potato',              amount = 1 },
            { item = 'herb_crows_garlic',   amount = 1 },
            { item = 'water',               amount = 1 },
        },
        receive = 'stew',
        giveamount = 1
    },
    {
        category = 'Meals',
        cooktime = 10000,
        requiredxp = 0,
        xpreward = 1,
        requiredjob = nil,
        cookingtype = 'all', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'raw_fish',            amount = 1 },
            { item = 'potato',              amount = 1 },
            { item = 'herb_crows_garlic',   amount = 1 },
            { item = 'water',               amount = 1 },
        },
        receive = 'stew_fish',
        giveamount = 1
    },
    {
        category = 'Meals',
        cooktime = 10000,
        requiredxp = 0,
        xpreward = 1,
        requiredjob = nil,
        cookingtype = 'all', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'carrot',              amount = 1 },
            { item = 'potato',              amount = 1 },
            { item = 'herb_creeping_thyme', amount = 1 },
            { item = 'water',               amount = 1 },
        },
        receive = 'stew_veg',
        giveamount = 1
    },
    {
        category = 'Meals',
        cooktime = 10000,
        requiredxp = 0,
        xpreward = 1,
        requiredjob = nil,
        cookingtype = 'all', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'raw_fish',    amount = 1 },
            { item = 'potato',      amount = 1 },
        },
        receive = 'fish_n_chips',
        giveamount = 1
    },
    ------------------------------------------
	-- Drink recipes
    ------------------------------------------
    {
        category = 'Brewing',
        cooktime = 10000,
        requiredxp = 0,
        xpreward = 1,
        requiredjob = nil,
        cookingtype = 'all', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'coffee_beanspkg', amount = 1 },
            { item = 'water',        amount = 2 },
        },
        receive = 'coffee',
        giveamount = 2
    },
    {
        category = 'Brewing',
        cooktime = 10000,
        requiredxp = 0,
        xpreward = 1,
        requiredjob = nil,
        cookingtype = 'all', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'teabag', amount = 1 },
            { item = 'water',  amount = 1 },
        },
        receive = 'tea',
        giveamount = 1
    },
    {
        category = 'Brewing',
        cooktime = 10000,
        requiredxp = 0,
        xpreward = 1,
        requiredjob = nil,
        cookingtype = 'all', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'herb_wild_mint', amount = 1 },
            { item = 'water',          amount = 1 },
        },
        receive = 'tea_mint',
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
        receive = 'bread',
        giveamount = 4
    },
    {
        category = 'Bread',
        cooktime = 25000,
        requiredxp = 10,
        xpreward = 2,
        requiredjob = nil,
        cookingtype = 'stove', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'flour_wheat', amount = 2 },
            { item = 'yeast',       amount = 1 },
            { item = 'milk',        amount = 1 },
            { item = 'egg',         amount = 1 },
        },
        receive = 'bread_sour',
        giveamount = 1
    },
        {
        category = 'Bread',
        cooktime = 25000,
        requiredxp = 10,
        xpreward = 2,
        requiredjob = nil,
        cookingtype = 'stove', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'flour_wheat', amount = 2 },
            { item = 'yeast',       amount = 1 },
            { item = 'milk',        amount = 1 },
            { item = 'egg',         amount = 1 },
        },
        receive = 'bread_loaf',
        giveamount = 1
    },
    ------------------------------------------
	-- Canning (stove only - stove)
    ------------------------------------------
    {
        category = 'Canning',
        cooktime = 25000,
        requiredxp = 10,
        xpreward = 2,
        requiredjob = nil,
        cookingtype = 'stove', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'emptybottle', amount = 1 },
            { item = 'apple',       amount = 2 },
        },
        receive = 'jelly_apple',
        giveamount = 1
    },
    {
        category = 'Canning',
        cooktime = 25000,
        requiredxp = 10,
        xpreward = 2,
        requiredjob = nil,
        cookingtype = 'stove', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'emptybottle', amount = 1 },
            { item = 'blackberry',  amount = 5 },
        },
        receive = 'jelly_blackberry',
        giveamount = 1
    },
    {
        category = 'Canning',
        cooktime = 25000,
        requiredxp = 10,
        xpreward = 2,
        requiredjob = nil,
        cookingtype = 'stove', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'emptybottle', amount = 1 },
            { item = 'raspberry',   amount = 5 },
        },
        receive = 'jelly_raspberry',
        giveamount = 1
    },
    {
        category = 'Canning',
        cooktime = 25000,
        requiredxp = 10,
        xpreward = 2,
        requiredjob = nil,
        cookingtype = 'stove', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'emptybottle', amount = 1 },
            { item = 'orange', amount = 2 },
        },
        receive = 'jelly_orange',
        giveamount = 1
    },
    ------------------------------------------
	-- Desert recipes (stove only - requires oven)
    ------------------------------------------
    {
        category = 'Deserts',
        cooktime = 25000,
        requiredxp = 10,
        xpreward = 2,
        requiredjob = nil,
        cookingtype = 'stove', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'flour_wheat',         amount = 2 },
            { item = 'sugar',               amount = 1 },
            { item = 'canned_peaches',      amount = 1 },
            { item = 'egg',                 amount = 1 },
        },
        receive = 'pie_peach',
        giveamount = 1
    },
    {
        category = 'Deserts',
        cooktime = 25000,
        requiredxp = 10,
        xpreward = 2,
        requiredjob = nil,
        cookingtype = 'stove', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'flour_wheat',         amount = 2 },
            { item = 'sugar',               amount = 1 },
            { item = 'raspberry',           amount = 10 },
            { item = 'egg',                 amount = 1 },
        },
        receive = 'pie_raspberry',
        giveamount = 1
    },
    {
        category = 'Deserts',
        cooktime = 25000,
        requiredxp = 10,
        xpreward = 2,
        requiredjob = nil,
        cookingtype = 'stove', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'flour_wheat',           amount = 2 },
            { item = 'sugar',                 amount = 1 },
            { item = 'apple',                 amount = 1 },
            { item = 'egg',                   amount = 1 },
        },
        receive = 'cobbler_apple',
        giveamount = 1
    },
    ------------------------------------------
	-- Ingredient recipes (stove only - for stove recipes)
    ------------------------------------------
    {
        category = 'Ingredients',
        cooktime = 25000,
        requiredxp = 10,
        xpreward = 2,
        requiredjob = nil,
        cookingtype = 'all', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'coffee_beans', amount = 5 },
        },
        receive = 'coffee_beanspkg',
        giveamount = 1
    },
    {
        category = 'Ingredients',
        cooktime = 25000,
        requiredxp = 10,
        xpreward = 2,
        requiredjob = nil,
        cookingtype = 'stove', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'wheat', amount = 2 },
        },
        receive = 'flour_wheat',
        giveamount = 1
    },
    {
        category = 'Ingredients',
        cooktime = 25000,
        requiredxp = 10,
        xpreward = 2,
        requiredjob = nil,
        cookingtype = 'all', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'resource_salt_rock', amount = 1 },
        },
        receive = 'resource_salt',
        giveamount = 10
    },
    {
        category = 'Ingredients',
        cooktime = 25000,
        requiredxp = 10,
        xpreward = 2,
        requiredjob = nil,
        cookingtype = 'stove', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'sugarcane', amount = 1 },
        },
        receive = 'sugar',
        giveamount = 1
    },
    {
        category = 'Ingredients',
        cooktime = 25000,
        requiredxp = 10,
        xpreward = 2,
        requiredjob = nil,
        cookingtype = 'stove', -- 'stove', 'campfire', 'campsite', 'cookjob', or 'all'
        ingredients = {
            { item = 'flour_wheat', amount = 2 },
            { item = 'water',       amount = 1 },
        },
        receive = 'yeast',
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
