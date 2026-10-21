local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

-- [id] = { id, citizenid, world, stype, coords, heading, recipe, hopper = {item=count}, output, fuel, batch_left, last_tick }
local Stations = {}
local Recipes = {}
for _, r in ipairs(Config.Recipes) do Recipes[r.key] = r end
local Fuels = {}
for _, f in ipairs(Config.Fuels) do Fuels[f.item] = f end

local canPlaceCampfire -- defined further down, used by the campfire item
local SHARED = 'world' -- citizenid used for shared (non private) world stations
local Inv = exports['rsg-inventory']

---------------------------------
-- helpers
---------------------------------
local function notify(src, desc, ntype)
    TriggerClientEvent('ox_lib:notify', src, { title = locale('notify_title'), description = desc, type = ntype or 'inform', duration = 5000 })
end

local function needsFuel(s)
    local t = Config.StationTypes[s.stype]
    return not t or t.fuel ~= false
end

local function isCooking(s) return s.batch_left ~= nil and (not needsFuel(s) or s.fuel > 0) end

local function publicStation(s)
    return { id = s.id, coords = s.coords, heading = s.heading, stype = s.stype, cooking = isCooking(s), world = s.world or nil }
end

local function itemInfo(name)
    local i = RSGCore.Shared.Items[name]
    return (i and i.label or name), (i and i.image or (name .. '.png'))
end

local function recipeLabel(r) return (itemInfo(r.output.item)) end

local function getXp(Player)
    local rep = Player.PlayerData.metadata.rep or {}
    return tonumber(rep[Config.XpName]) or 0
end

local function getLevel(xp)
    local level = 1
    for lvl, need in ipairs(Config.Levels) do
        if xp >= need then level = lvl end
    end
    return level
end

local function hasJob(Player, job)
    if not job then return true end
    local j = Player.PlayerData.job
    return j ~= nil and (j.name == job or j.type == job)
end

local function isNear(src, coords, dist)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    return #(GetEntityCoords(ped) - coords) <= (dist or Config.InteractDist)
end

-- per-player throttles: throttled('action', src, 300) is true if called again within 300ms
local Throttle = { action = {}, state = {}, world = {} }
local function throttled(bucket, src, ms)
    local now, last = GetGameTimer(), Throttle[bucket][src]
    if last and now - last < ms then return true end
    Throttle[bucket][src] = now
    return false
end
AddEventHandler('playerDropped', function()
    for _, b in pairs(Throttle) do b[source] = nil end
end)

local function canUse(Player, s)
    if s.citizenid == SHARED then return true end
    if s.world then return s.citizenid == Player.PlayerData.citizenid end -- private world pot
    return (not Config.Campfire.OwnerOnly) or s.citizenid == Player.PlayerData.citizenid
end

local function countCampfires(cid)
    local n = 0
    for _, s in pairs(Stations) do if not s.world and s.citizenid == cid then n = n + 1 end end
    return n
end

local function hopperEmpty(s)
    for _, c in pairs(s.hopper) do if c > 0 then return false end end
    return true
end

local function isEmpty(s) return hopperEmpty(s) and not s.batch_left and s.output <= 0 end

local function saveStation(s)
    MySQL.update('UPDATE rsg_cooking_stations SET recipe = ?, hopper = ?, output = ?, fuel = ?, batch_left = ?, last_tick = ? WHERE id = ?',
        { s.recipe, json.encode(s.hopper), s.output, s.fuel, s.batch_left, s.last_tick, s.id })
end

---------------------------------
-- cooking logic (lazy, restart safe - same model as rsg-moonshine)
---------------------------------
local function canStartBatch(s, r)
    if s.output + r.output.amount > Config.OutputCap then return false end
    for _, ing in ipairs(r.ingredients) do
        if (s.hopper[ing.item] or 0) < ing.amount then return false end
    end
    return true
end

local function consumeBatch(s, r)
    for _, ing in ipairs(r.ingredients) do
        s.hopper[ing.item] = s.hopper[ing.item] - ing.amount
        if s.hopper[ing.item] <= 0 then s.hopper[ing.item] = nil end
    end
end

-- advances a station to "now". Time only counts while the fire has fuel (fuel stations).
local function simulate(s, now)
    local elapsed = math.max(0, now - (s.last_tick or now))
    s.last_tick = now

    local r = s.recipe and Recipes[s.recipe]
    if not r then
        s.batch_left = nil
        return
    end

    local burn = needsFuel(s)
    while true do
        local fuel = burn and s.fuel or math.huge
        if not s.batch_left then
            if fuel <= 0 or not canStartBatch(s, r) then break end
            consumeBatch(s, r)
            s.batch_left = r.time
        end
        if elapsed <= 0 or fuel <= 0 then break end

        local step = math.min(elapsed, s.batch_left, fuel)
        s.batch_left = s.batch_left - step
        if burn then s.fuel = s.fuel - step end
        elapsed = elapsed - step

        if s.batch_left <= 0 then
            s.output = math.min(Config.OutputCap, s.output + r.output.amount)
            s.batch_left = nil
        end
    end
end

local function processStation(s, now)
    local was = isCooking(s)
    simulate(s, now)
    if isCooking(s) ~= was then
        TriggerClientEvent('rsg-cooking:client:syncStation', -1, publicStation(s))
    end
end

local function queuedBatches(s, r)
    local n = math.huge
    for _, ing in ipairs(r.ingredients) do
        n = math.min(n, (s.hopper[ing.item] or 0) // ing.amount)
    end
    return n == math.huge and 0 or n
end

---------------------------------
-- state for the NUI
---------------------------------
local function buildState(src, s)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil end
    processStation(s, os.time())

    local counts = {}
    local function have(item)
        if not counts[item] then counts[item] = Inv:GetItemCount(src, item) or 0 end
        return counts[item]
    end
    local xp = getXp(Player)

    local state = {
        id = s.id,
        stype = s.stype,
        isOwner = not s.world and s.citizenid == Player.PlayerData.citizenid,
        canUse = canUse(Player, s),
        recipe = s.recipe,
        output = s.output,
        outputCap = Config.OutputCap,
        maxBatches = Config.MaxBatches,
        hopperEmpty = hopperEmpty(s),
        usesFuel = needsFuel(s),
        fuel = s.fuel,
        maxFuel = Config.MaxFuel,
        xp = xp,
        level = getLevel(xp),
        maxLevel = #Config.Levels,
        fuels = {},
        recipes = {},
    }
    state.levelXp = Config.Levels[state.level] or 0
    state.nextXp = Config.Levels[state.level + 1] -- nil at max level

    for _, f in ipairs(Config.Fuels) do
        local label, img = itemInfo(f.item)
        state.fuels[#state.fuels + 1] = { item = f.item, label = label, image = img, burnTime = f.burnTime, have = have(f.item) }
    end

    for _, r in ipairs(Config.Recipes) do
        if Config.RecipeAllowed(r, s.stype) and hasJob(Player, r.job) and RSGCore.Shared.Items[r.output.item] then
            local outLabel, outImg = itemInfo(r.output.item)
            local rec = {
                key = r.key, label = outLabel, category = r.category or locale('ui_other'), time = r.time, level = r.level or 1,
                output = { item = r.output.item, label = outLabel, image = outImg, amount = r.output.amount },
                ingredients = {},
            }
            for _, ing in ipairs(r.ingredients) do
                local label, img = itemInfo(ing.item)
                rec.ingredients[#rec.ingredients + 1] = {
                    item = ing.item, label = label, image = img, perBatch = ing.amount,
                    loaded = (r.key == s.recipe) and (s.hopper[ing.item] or 0) or 0,
                    capacity = ing.amount * Config.MaxBatches,
                    have = have(ing.item),
                }
            end
            state.recipes[#state.recipes + 1] = rec
        end
    end

    local r = s.recipe and Recipes[s.recipe]
    if r then
        -- active recipe always shown, even if the player can't select it themselves
        local found = false
        for _, rec in ipairs(state.recipes) do if rec.key == r.key then found = true break end end
        if not found then
            local outLabel, outImg = itemInfo(r.output.item)
            local rec = { key = r.key, label = outLabel, category = r.category, time = r.time, level = r.level or 1,
                output = { item = r.output.item, label = outLabel, image = outImg, amount = r.output.amount }, ingredients = {} }
            for _, ing in ipairs(r.ingredients) do
                local label, img = itemInfo(ing.item)
                rec.ingredients[#rec.ingredients + 1] = { item = ing.item, label = label, image = img, perBatch = ing.amount,
                    loaded = s.hopper[ing.item] or 0, capacity = ing.amount * Config.MaxBatches, have = have(ing.item) }
            end
            state.recipes[#state.recipes + 1] = rec
        end

        local fueled = not needsFuel(s) or s.fuel > 0
        state.queued = queuedBatches(s, r)
        if s.batch_left then
            state.batch = { remaining = s.batch_left, total = r.time, running = fueled }
            state.status = fueled and 'cooking' or 'nofuel'
        elseif s.output + r.output.amount > Config.OutputCap then
            state.status = 'full'
        elseif canStartBatch(s, r) and not fueled then
            state.status = 'nofuel'
        else
            state.status = 'waiting'
        end
    else
        state.status = 'idle'
    end
    return state
end

---------------------------------
-- startup
---------------------------------
CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `rsg_cooking_stations` (
            `id` INT NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `world` TINYINT(1) NOT NULL DEFAULT 0,
            `stype` VARCHAR(20) NOT NULL DEFAULT 'campfire',
            `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
            `heading` FLOAT NOT NULL DEFAULT 0,
            `recipe` VARCHAR(50) DEFAULT NULL,
            `hopper` LONGTEXT DEFAULT NULL,
            `output` INT NOT NULL DEFAULT 0,
            `fuel` INT NOT NULL DEFAULT 0,
            `batch_left` INT DEFAULT NULL,
            `last_tick` INT DEFAULT NULL,
            PRIMARY KEY (`id`),
            INDEX `idx_citizenid` (`citizenid`)
        )
    ]])
    -- unused world pots are recreated on demand, don't keep them around
    MySQL.update.await([[DELETE FROM rsg_cooking_stations WHERE world = 1 AND recipe IS NULL AND output = 0 AND fuel = 0
        AND batch_left IS NULL AND (hopper IS NULL OR hopper = '[]' OR hopper = '{}')]])

    local rows = MySQL.query.await('SELECT * FROM rsg_cooking_stations') or {}
    for _, r in ipairs(rows) do
        Stations[r.id] = {
            id = r.id, citizenid = r.citizenid, world = r.world == 1 or r.world == true, stype = r.stype,
            coords = vector3(r.x, r.y, r.z), heading = r.heading, recipe = r.recipe,
            hopper = (r.hopper and json.decode(r.hopper)) or {}, output = r.output or 0, fuel = r.fuel or 0,
            batch_left = r.batch_left, last_tick = r.last_tick,
        }
        local s = Stations[r.id]
        -- recipe removed from the config: reset it so the station isn't stuck (pantry stays, can be unloaded)
        if s.recipe and not Recipes[s.recipe] then
            print(('^3[rsg-cooking] station #%s used removed recipe "%s", recipe cleared^7'):format(s.id, s.recipe))
            s.recipe, s.batch_left, s.output = nil, nil, 0
            saveStation(s)
        end
    end
    print(('[rsg-cooking] loaded %d cooking stations'):format(#rows))

    if Config.Campfire.Item then
        RSGCore.Functions.CreateUseableItem(Config.Campfire.Item, function(source)
            local Player = RSGCore.Functions.GetPlayer(source)
            if Player and canPlaceCampfire(source, Player) then
                TriggerClientEvent('rsg-cooking:client:placeCampfire', source)
            end
        end)
    end

    -- keep stations cooking while nobody is looking at them
    while true do
        Wait(Config.TickInterval * 1000)
        local now = os.time()
        for _, s in pairs(Stations) do processStation(s, now) end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    local now = os.time()
    for _, s in pairs(Stations) do processStation(s, now) saveStation(s) end
end)

lib.callback.register('rsg-cooking:server:getStations', function()
    local list = {}
    for _, s in pairs(Stations) do list[#list + 1] = publicStation(s) end
    return list
end)

lib.callback.register('rsg-cooking:server:getState', function(src, id)
    local s = Stations[id]
    if not s or throttled('state', src, 250) or not isNear(src, s.coords) then return nil end
    return buildState(src, s)
end)

---------------------------------
-- NUI actions
---------------------------------
local Actions = {}

Actions.selectRecipe = function(src, Player, s, data)
    local r = Recipes[data.recipe]
    if not r or not Config.RecipeAllowed(r, s.stype) then return notify(src, locale('sv_wrong_station'), 'error') end
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    if s.recipe == r.key then return end
    if not hasJob(Player, r.job) then return notify(src, locale('sv_job'), 'error') end
    if getLevel(getXp(Player)) < (r.level or 1) then return notify(src, locale('sv_level_low'):format(r.level or 1), 'error') end
    if not isEmpty(s) then return notify(src, locale('sv_empty_first'), 'error') end
    s.recipe = r.key
    saveStation(s)
    WebhookLog('recipe', src, 'Recipe Selected', ('Station #%s set to **%s**'):format(s.id, recipeLabel(r)), { { 'Station', s.id }, CoordsField(s.coords) })
end

Actions.load = function(src, Player, s, data)
    local r = s.recipe and Recipes[s.recipe]
    if not r then return end
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    if not hasJob(Player, r.job) then return notify(src, locale('sv_job'), 'error') end
    local ing
    for _, i in ipairs(r.ingredients) do if i.item == data.item then ing = i break end end
    if not ing then return end

    local space = ing.amount * Config.MaxBatches - (s.hopper[ing.item] or 0)
    local have = Inv:GetItemCount(src, ing.item) or 0
    local amount = math.min(math.floor(tonumber(data.amount) or 0), space, have)
    if amount <= 0 then return notify(src, locale(space <= 0 and 'sv_hopper_full' or 'sv_missing'), 'error') end

    if not Inv:RemoveItem(src, ing.item, amount, nil, 'cooking-load') then return end
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[ing.item], 'remove', amount)
    s.hopper[ing.item] = (s.hopper[ing.item] or 0) + amount
    processStation(s, os.time())
    saveStation(s)
    local label = itemInfo(ing.item)
    notify(src, locale('sv_loaded'):format(amount, label), 'success')
    WebhookLog('load', src, 'Ingredients Loaded', ('%sx %s loaded into station #%s'):format(amount, label, s.id), { { 'Station', s.id } })
end

Actions.loadFuel = function(src, Player, s, data)
    if not needsFuel(s) then return end
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    local f = Fuels[data.item]
    if not f then return end
    local room = (Config.MaxFuel - s.fuel) // f.burnTime
    local have = Inv:GetItemCount(src, f.item) or 0
    local amount = math.min(math.floor(tonumber(data.amount) or 0), room, have)
    if amount <= 0 then return notify(src, locale(room <= 0 and 'sv_fuel_full' or 'sv_missing'), 'error') end
    if not Inv:RemoveItem(src, f.item, amount, nil, 'cooking-fuel') then return end
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[f.item], 'remove', amount)
    s.fuel = s.fuel + amount * f.burnTime
    processStation(s, os.time())
    saveStation(s)
    local label = itemInfo(f.item)
    notify(src, locale('sv_fuel_loaded'):format(amount, label), 'success')
    WebhookLog('fuel', src, 'Fuel Added', ('%sx %s added to station #%s'):format(amount, label, s.id), { { 'Station', s.id } })
end

Actions.unload = function(src, Player, s, data)
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    if type(data.item) ~= 'string' then return end
    local amount = s.hopper[data.item] or 0
    if amount <= 0 then return end
    -- give first, only empty the pantry once the items are really in the inventory
    if not Inv:CanAddItem(src, data.item, amount) or not Inv:AddItem(src, data.item, amount, nil, nil, 'cooking-unload') then
        return notify(src, locale('sv_no_space'), 'error')
    end
    s.hopper[data.item] = nil
    saveStation(s)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[data.item], 'add', amount)
    local label = itemInfo(data.item)
    notify(src, locale('sv_unloaded'):format(amount, label), 'success')
    WebhookLog('unload', src, 'Pantry Unloaded', ('%sx %s taken from station #%s'):format(amount, label, s.id), { { 'Station', s.id } })
end

Actions.collect = function(src, Player, s)
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    local r = s.recipe and Recipes[s.recipe]
    if not r or s.output <= 0 then return notify(src, locale('sv_not_ready'), 'error') end

    -- take as much as fits in the inventory (binary search instead of one CanAddItem per item)
    local amount = s.output
    if not Inv:CanAddItem(src, r.output.item, amount) then
        local lo, hi = 0, amount - 1
        while lo < hi do
            local mid = (lo + hi + 1) // 2
            if Inv:CanAddItem(src, r.output.item, mid) then lo = mid else hi = mid - 1 end
        end
        amount = lo
    end
    if amount <= 0 then return notify(src, locale('sv_no_space'), 'error') end
    if not Inv:AddItem(src, r.output.item, amount, nil, nil, 'cooking-collect') then return notify(src, locale('sv_no_space'), 'error') end
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[r.output.item], 'add', amount)

    s.output = s.output - amount
    processStation(s, os.time()) -- tray had room freed, may start the next batch
    saveStation(s)
    local label = itemInfo(r.output.item)
    notify(src, locale('sv_collected'):format(amount, label), 'success')
    WebhookLog('collect', src, 'Food Collected', ('%sx %s collected from station #%s'):format(amount, label, s.id),
        { { 'Station', s.id }, { 'Type', s.stype }, { 'Left on tray', s.output }, CoordsField(s.coords) })

    local before = getLevel(getXp(Player))
    local xp = amount * (r.xp or Config.XpPerItem)
    if xp > 0 then
        Player.Functions.AddRep(Config.XpName, xp)
        local after = getLevel(getXp(Player))
        if after > before then
            notify(src, locale('sv_level_up'):format(after), 'success')
            WebhookLog('levelup', src, 'Cooking Level Up', ('Reached cooking level **%s**'):format(after), { { 'Total XP', getXp(Player) } })
        else
            notify(src, locale('sv_xp_gain'):format(xp), 'inform')
        end
    end
end

Actions.clearRecipe = function(src, Player, s)
    if not canUse(Player, s) then return notify(src, locale('sv_not_owner'), 'error') end
    if not isEmpty(s) then return notify(src, locale('sv_empty_first'), 'error') end
    s.recipe = nil
    saveStation(s)
end

Actions.pickup = function(src, Player, s)
    if s.world or s.citizenid ~= Player.PlayerData.citizenid then return notify(src, locale('sv_not_owner'), 'error') end
    if not isEmpty(s) then return notify(src, locale('sv_empty_first'), 'error') end
    local item = Config.Campfire.ReturnItem and Config.Campfire.Item
    if item and not Inv:CanAddItem(src, item, 1) then return notify(src, locale('sv_no_space'), 'error') end
    Stations[s.id] = nil
    MySQL.query('DELETE FROM rsg_cooking_stations WHERE id = ?', { s.id })
    TriggerClientEvent('rsg-cooking:client:removeStation', -1, s.id)
    if item then
        Inv:AddItem(src, item, 1, nil, nil, 'cooking-campfire-pickup')
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'add', 1)
    end
    notify(src, locale('sv_put_out'), 'success')
    WebhookLog('campfire', src, 'Campfire Put Out', ('Campfire #%s put out by its owner'):format(s.id), { CoordsField(s.coords) })
    return 'closed'
end

lib.callback.register('rsg-cooking:server:action', function(src, id, action, data)
    local Player = RSGCore.Functions.GetPlayer(src)
    local s = Stations[id]
    if not Player or not s or type(action) ~= 'string' or not Actions[action] then return nil end
    if not isNear(src, s.coords) then
        notify(src, locale('sv_too_far'), 'error')
        WebhookLog('suspicious', src, 'Out of Range Action', ('Tried `%s` on station #%s while not near it'):format(action, s.id), { CoordsField(s.coords) })
        return nil
    end
    if throttled('action', src, 300) then return buildState(src, s) end
    processStation(s, os.time())
    if Actions[action](src, Player, s, type(data) == 'table' and data or {}) == 'closed' then return nil end
    return buildState(src, s)
end)

---------------------------------
-- world stations (stove props + external scripts) - find or create the saved pot
---------------------------------
local creatingWorld = {}
lib.callback.register('rsg-cooking:server:getWorldStation', function(src, coords, stype)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(coords) ~= 'vector3' or type(stype) ~= 'string' or not Config.StationTypes[stype] then return nil end
    if stype ~= 'stove' or not Config.WorldStations.enabled then return nil end -- campfires are placed, never created this way
    if not isNear(src, coords) then return nil end

    local owner = Config.WorldStations.private and Player.PlayerData.citizenid or SHARED
    local radius = 1.5
    for _, s in pairs(Stations) do
        if s.world and s.stype == stype and s.citizenid == owner and #(s.coords - coords) < radius then return publicStation(s) end
    end
    if creatingWorld[owner] or throttled('world', src, 1000) then return nil end
    -- private pots: a character keeps at most one unused pot, so spamming new spots can't flood the database
    if owner ~= SHARED then
        for id, s in pairs(Stations) do
            if s.world and s.citizenid == owner and not s.recipe and isEmpty(s) and s.fuel <= 0 then
                Stations[id] = nil
                MySQL.query('DELETE FROM rsg_cooking_stations WHERE id = ?', { id })
                TriggerClientEvent('rsg-cooking:client:removeStation', -1, id)
            end
        end
    end
    creatingWorld[owner] = true
    local id = MySQL.insert.await('INSERT INTO rsg_cooking_stations (citizenid, world, stype, x, y, z, heading, hopper, output) VALUES (?, 1, ?, ?, ?, ?, 0, ?, 0)',
        { owner, stype, coords.x, coords.y, coords.z, '{}' })
    creatingWorld[owner] = nil
    if not id then return nil end
    Stations[id] = { id = id, citizenid = owner, world = true, stype = stype, coords = coords, heading = 0.0, hopper = {}, output = 0, fuel = 0, last_tick = os.time() }
    TriggerClientEvent('rsg-cooking:client:syncStation', -1, publicStation(Stations[id]))
    return publicStation(Stations[id])
end)

---------------------------------
-- campfire placement
---------------------------------
local placing = {}

-- checked before the placement preview opens, so players aren't sent through placement + progress bar for nothing
canPlaceCampfire = function(src, Player)
    local cfg = Config.Campfire
    if countCampfires(Player.PlayerData.citizenid) >= cfg.MaxPerPlayer then
        notify(src, locale('campfire_limit'):format(cfg.MaxPerPlayer), 'error')
        return false
    end
    if cfg.Item and (Inv:GetItemCount(src, cfg.Item) or 0) < 1 then
        notify(src, locale('campfire_need_item'):format((itemInfo(cfg.Item))), 'error')
        return false
    end
    return true
end

RegisterNetEvent('rsg-cooking:server:requestCampfire', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or throttled('world', src, 1000) then return end
    if canPlaceCampfire(src, Player) then TriggerClientEvent('rsg-cooking:client:placeCampfire', src) end
end)

RegisterNetEvent('rsg-cooking:server:placeCampfire', function(coords, heading)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or type(coords) ~= 'vector3' or type(heading) ~= 'number' or heading ~= heading then return end
    heading = heading % 360.0
    local cfg = Config.Campfire
    local cid = Player.PlayerData.citizenid
    if placing[cid] then return end

    if not isNear(src, coords, cfg.PlaceDistance + 2.0) then
        WebhookLog('suspicious', src, 'Remote Placement', 'Tried to place a campfire away from their position', { CoordsField(coords) })
        return notify(src, locale('sv_too_far'), 'error')
    end
    if countCampfires(cid) >= cfg.MaxPerPlayer then return notify(src, locale('campfire_limit'):format(cfg.MaxPerPlayer), 'error') end
    for _, s in pairs(Stations) do
        if #(coords - s.coords) < cfg.MinSpacing then return notify(src, locale('campfire_too_close'), 'error') end
    end
    if cfg.Item and not Inv:RemoveItem(src, cfg.Item, 1, nil, 'cooking-campfire-place') then
        return notify(src, locale('campfire_need_item'):format((itemInfo(cfg.Item))), 'error')
    end
    if cfg.Item then TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[cfg.Item], 'remove', 1) end

    placing[cid] = true
    local id = MySQL.insert.await('INSERT INTO rsg_cooking_stations (citizenid, world, stype, x, y, z, heading, hopper, output) VALUES (?, 0, ?, ?, ?, ?, ?, ?, 0)',
        { cid, 'campfire', coords.x, coords.y, coords.z, heading, '{}' })
    placing[cid] = nil
    if not id then
        if cfg.Item then Inv:AddItem(src, cfg.Item, 1, nil, nil, 'cooking-campfire-refund') end
        return
    end
    Stations[id] = { id = id, citizenid = cid, world = false, stype = 'campfire', coords = coords, heading = heading, hopper = {}, output = 0, fuel = 0, last_tick = os.time() }
    TriggerClientEvent('rsg-cooking:client:syncStation', -1, publicStation(Stations[id]))
    notify(src, locale('campfire_placed'), 'success')
    WebhookLog('campfire', src, 'Campfire Placed', ('Campfire #%s placed'):format(id), { CoordsField(coords) })
end)

---------------------------------
-- SERVER EXPORTS
---------------------------------
exports('GetPlayerCookingXP', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player and getXp(Player) or 0
end)

exports('GetPlayerCookingLevel', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player and getLevel(getXp(Player)) or 1
end)

exports('GivePlayerCookingXP', function(src, amount)
    local Player = RSGCore.Functions.GetPlayer(src)
    amount = math.floor(tonumber(amount) or 0)
    if not Player or amount <= 0 then return false end
    Player.Functions.AddRep(Config.XpName, amount)
    return true
end)

exports('GetCookingRecipes', function() return Config.Recipes end)

exports('CanCookItem', function(itemName)
    local r = Recipes[itemName]
    if r then return true, r end
    for _, rec in ipairs(Config.Recipes) do
        if rec.output.item == itemName then return true, rec end
    end
    return false
end)

-- add a recipe at runtime (same format as Config.Recipes). Shows up in every station menu straight away.
exports('AddCustomRecipe', function(recipe)
    if type(recipe) ~= 'table' or type(recipe.key) ~= 'string' then return false, 'recipe needs a key' end
    if Recipes[recipe.key] then return false, 'recipe already exists: ' .. recipe.key end
    if type(recipe.output) ~= 'table' or not RSGCore.Shared.Items[recipe.output.item] then return false, 'unknown output item' end
    if type(recipe.ingredients) ~= 'table' or #recipe.ingredients == 0 then return false, 'no ingredients' end
    for _, ing in ipairs(recipe.ingredients) do
        if not RSGCore.Shared.Items[ing.item] or (tonumber(ing.amount) or 0) < 1 then return false, 'bad ingredient: ' .. tostring(ing.item) end
    end
    recipe.time = tonumber(recipe.time) or 60
    recipe.output.amount = tonumber(recipe.output.amount) or 1
    Config.Recipes[#Config.Recipes + 1] = recipe
    Recipes[recipe.key] = recipe
    return true
end)

---------------------------------
-- validate config on start
---------------------------------
CreateThread(function()
    Wait(1000)
    for _, r in ipairs(Config.Recipes) do
        if not RSGCore.Shared.Items[r.output.item] then print(('^3[rsg-cooking] recipe %s: unknown output item %s^7'):format(r.key, r.output.item)) end
        for _, ing in ipairs(r.ingredients) do
            if not RSGCore.Shared.Items[ing.item] then print(('^3[rsg-cooking] recipe %s: unknown ingredient %s^7'):format(r.key, ing.item)) end
        end
    end
end)
