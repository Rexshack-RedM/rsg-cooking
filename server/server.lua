local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local XP_TYPE = 'cooking'
local LATENCY_GRACE = 1500   -- ms of tolerance for network delay on finish
local SESSION_TIMEOUT = 30000 -- ms after the cook time before an abandoned session is discarded
local Inventory = exports['rsg-inventory']

-- [source] = { index, qty, cooktime, startedAt, cookingType }
local activeSessions = {}

---------------------------------------------
-- helpers
---------------------------------------------
local function notify(src, title, description, ntype, duration)
    TriggerClientEvent('rsg-cooking:client:notify', src, {
        title = title,
        description = description,
        type = ntype or 'inform',
        duration = duration or 5000,
    })
end

local function itemLabel(item)
    local data = RSGCore.Shared.Items[item]
    return data and data.label or item
end

local function hasRequiredJob(Player, requiredJob)
    if not requiredJob then return true end
    local job = Player.PlayerData.job
    return job ~= nil and (job.type == requiredJob or job.name == requiredJob)
end

local function getXP(Player, xpType)
    return Player.Functions.GetRep(xpType or XP_TYPE) or 0
end

-- validate a recipe definition (config, custom or external)
local function isValidRecipe(recipe)
    if type(recipe) ~= 'table' then return false, 'recipe must be a table' end
    if not RSGCore.Shared.Items[recipe.receive] then return false, 'unknown item: ' .. tostring(recipe.receive) end
    if type(recipe.giveamount) ~= 'number' or recipe.giveamount < 1 then return false, 'invalid giveamount' end
    if type(recipe.ingredients) ~= 'table' or #recipe.ingredients == 0 then return false, 'no ingredients' end
    for _, ing in ipairs(recipe.ingredients) do
        if not RSGCore.Shared.Items[ing.item] then return false, 'unknown ingredient: ' .. tostring(ing.item) end
        if type(ing.amount) ~= 'number' or ing.amount < 1 then return false, 'invalid amount for ' .. ing.item end
    end
    return true
end

local function getMissingIngredients(src, ingredients)
    local missing = {}
    for _, ing in ipairs(ingredients) do
        local have = Inventory:GetItemCount(src, ing.item) or 0
        if have < ing.amount then
            missing[#missing + 1] = {
                item = ing.item,
                label = itemLabel(ing.item),
                have = have,
                need = ing.amount,
                missing = ing.amount - have,
            }
        end
    end
    return missing
end

local function IncreasePlayerXP(src, Player, xpGain, xpType)
    xpType = xpType or XP_TYPE
    Player.Functions.AddRep(xpType, xpGain)
    notify(src, locale('notify_title'), locale('xp_gained', xpGain, xpType), 'inform', 5000)
    return true
end

-- stations the server can verify: campfires are tracked by server/campfire.lua
local function isAtStation(src, cookingType)
    if cookingType == Config.CookingTypes.CAMPFIRE and CampfireServer then
        return CampfireServer.IsNear(src, 3.0)
    end
    return true
end

-- the only place items/XP are granted. Returns ok, reason, extra
local function cookRecipe(src, Player, recipe, reason)
    local missing = getMissingIngredients(src, recipe.ingredients)
    if #missing > 0 then return false, 'missing', missing end

    if not Inventory:CanAddItem(src, recipe.receive, recipe.giveamount) then
        return false, 'inventory_full'
    end

    local removed = {}
    for _, ing in ipairs(recipe.ingredients) do
        if not Inventory:RemoveItem(src, ing.item, ing.amount, nil, reason) then
            for _, r in ipairs(removed) do
                Inventory:AddItem(src, r.item, r.amount, nil, nil, reason .. '-refund')
            end
            return false, 'error'
        end
        removed[#removed + 1] = ing
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[ing.item], 'remove', ing.amount)
    end

    if not Inventory:AddItem(src, recipe.receive, recipe.giveamount, nil, nil, reason) then
        for _, r in ipairs(removed) do
            Inventory:AddItem(src, r.item, r.amount, nil, nil, reason .. '-refund')
        end
        return false, 'error'
    end
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[recipe.receive], 'add', recipe.giveamount)

    local xpGain = tonumber(recipe.xpreward) or 0
    if xpGain > 0 then IncreasePlayerXP(src, Player, xpGain, XP_TYPE) end

    local charinfo = Player.PlayerData.charinfo
    TriggerEvent('rsg-log:server:CreateLog', 'cooking', locale('log_title'), 'green',
        locale('log_message', charinfo.firstname .. ' ' .. charinfo.lastname, Player.PlayerData.citizenid,
            recipe.giveamount, itemLabel(recipe.receive)))

    return true
end

-- a copy of the recipe multiplied by qty (ingredients, output and xp)
local function scaleRecipe(recipe, qty)
    local ingredients = {}
    for _, ing in ipairs(recipe.ingredients) do
        ingredients[#ingredients + 1] = { item = ing.item, amount = ing.amount * qty }
    end
    return {
        receive = recipe.receive,
        giveamount = recipe.giveamount * qty,
        xpreward = (tonumber(recipe.xpreward) or 0) * qty,
        cooktime = (recipe.cooktime or 10000) * qty,
        cookingtype = recipe.cookingtype,
        ingredients = ingredients,
    }
end

local function sanitizeQty(qty)
    qty = math.floor(tonumber(qty) or 1)
    if qty < 1 or qty > (Config.MaxBatch or 10) then return nil end
    return qty
end

---------------------------------------------
-- validate config on start
---------------------------------------------
CreateThread(function()
    for i, recipe in ipairs(Config.Cooking) do
        local ok, err = isValidRecipe(recipe)
        if not ok then
            print(('^1[rsg-cooking] Config.Cooking[%d] is invalid: %s^7'):format(i, err))
        end
    end
end)

---------------------------------------------
-- recipe list for the menu (server decides what the player can see)
---------------------------------------------
lib.callback.register('rsg-cooking:server:getRecipes', function(src, cookingType)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not CookingUtils.IsValidType(cookingType) then return nil end

    local xp = getXP(Player)
    local list = {}

    for index, recipe in ipairs(Config.Cooking) do
        if hasRequiredJob(Player, recipe.requiredjob)
            and CookingUtils.MatchesType(recipe, cookingType)
            and isValidRecipe(recipe) then
            local ingredients = {}
            local maxCraftable = Config.MaxBatch or 10
            for _, ing in ipairs(recipe.ingredients) do
                local have = Inventory:GetItemCount(src, ing.item) or 0
                local data = RSGCore.Shared.Items[ing.item]
                ingredients[#ingredients + 1] = {
                    item = ing.item, label = itemLabel(ing.item), image = data and data.image,
                    amount = ing.amount, have = have,
                }
                maxCraftable = math.min(maxCraftable, math.floor(have / ing.amount))
            end
            local item = RSGCore.Shared.Items[recipe.receive]
            list[#list + 1] = {
                id = index,
                category = recipe.category or locale('category_other'),
                label = item.label,
                image = item.image,
                giveamount = recipe.giveamount,
                cooktime = recipe.cooktime or 10000,
                requiredxp = recipe.requiredxp or 0,
                xpreward = recipe.xpreward or 0,
                requiredjob = recipe.requiredjob,
                ingredients = ingredients,
                locked = xp < (recipe.requiredxp or 0),
                maxCraftable = maxCraftable,
            }
        end
    end

    return { xp = xp, recipes = list }
end)

---------------------------------------------
-- start cooking: validates and opens a timed session
---------------------------------------------
lib.callback.register('rsg-cooking:server:startCooking', function(src, index, cookingType, qty)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return { ok = false, reason = 'error' } end

    local existing = activeSessions[src]
    if existing then
        if GetGameTimer() - existing.startedAt < existing.cooktime + SESSION_TIMEOUT then
            return { ok = false, reason = 'busy' }
        end
        activeSessions[src] = nil -- abandoned session (client crashed / never reported back)
    end

    local recipe = type(index) == 'number' and Config.Cooking[index]
    if not recipe or not isValidRecipe(recipe) then return { ok = false, reason = 'error' } end
    qty = sanitizeQty(qty)
    if not qty then return { ok = false, reason = 'error' } end
    if not CookingUtils.IsValidType(cookingType) or not CookingUtils.MatchesType(recipe, cookingType) then
        return { ok = false, reason = 'error' }
    end
    if not isAtStation(src, cookingType) then return { ok = false, reason = 'too_far' } end

    if not hasRequiredJob(Player, recipe.requiredjob) then
        if Webhooks then Webhooks.JobRestricted(src, recipe, recipe.requiredjob) end
        return { ok = false, reason = 'job', requiredJob = recipe.requiredjob }
    end

    local xp = getXP(Player)
    if xp < (recipe.requiredxp or 0) then
        return { ok = false, reason = 'xp', requiredXP = recipe.requiredxp, currentXP = xp }
    end

    local scaled = scaleRecipe(recipe, qty)
    local missing = getMissingIngredients(src, scaled.ingredients)
    if #missing > 0 then
        if Webhooks then Webhooks.CookingFailed(src, recipe, missing) end
        return { ok = false, reason = 'missing', missing = missing }
    end

    if not Inventory:CanAddItem(src, scaled.receive, scaled.giveamount) then
        return { ok = false, reason = 'inventory_full', label = itemLabel(recipe.receive) }
    end

    activeSessions[src] = {
        index = index, qty = qty, cooktime = scaled.cooktime, startedAt = GetGameTimer(), cookingType = cookingType,
    }
    if Webhooks then Webhooks.CookingStarted(src, scaled) end

    return { ok = true, cooktime = scaled.cooktime, label = itemLabel(recipe.receive), qty = qty }
end)

---------------------------------------------
-- finish cooking: only the server decides the reward
---------------------------------------------
lib.callback.register('rsg-cooking:server:finishCooking', function(src, index)
    local session = activeSessions[src]
    activeSessions[src] = nil
    if not session or session.index ~= index then return { ok = false, reason = 'error' } end

    local Player = RSGCore.Functions.GetPlayer(src)
    local recipe = Config.Cooking[session.index]
    if not Player or not recipe then return { ok = false, reason = 'error' } end

    local elapsed = GetGameTimer() - session.startedAt
    if elapsed + LATENCY_GRACE < session.cooktime then
        print(('^1[rsg-cooking] Player %s finished cooking too fast (%dms of %dms)^7'):format(src, elapsed, session.cooktime))
        if Webhooks then Webhooks.Suspicious(src, 'Cooking finished too fast',
            ('Finished %s in %dms (needs %dms)'):format(recipe.receive, elapsed, session.cooktime)) end
        return { ok = false, reason = 'error' }
    end

    -- job or position may have changed while cooking
    if not hasRequiredJob(Player, recipe.requiredjob) then
        return { ok = false, reason = 'job', requiredJob = recipe.requiredjob }
    end
    if not isAtStation(src, session.cookingType) then return { ok = false, reason = 'too_far' } end

    local scaled = scaleRecipe(recipe, session.qty)
    local ok, reason = cookRecipe(src, Player, scaled, 'rsg-cooking')
    if not ok then
        return { ok = false, reason = reason, label = itemLabel(recipe.receive) }
    end

    if Webhooks then
        local currentXP = getXP(Player)
        Webhooks.CookingCompleted(src, scaled)
        if scaled.xpreward > 0 then
            Webhooks.XPGained(src, scaled.xpreward, currentXP)
            Webhooks.CheckMilestones(src, scaled.xpreward, currentXP)
            Webhooks.CheckHighXP(src, scaled.xpreward)
        end
    end

    return { ok = true, amount = scaled.giveamount, label = itemLabel(recipe.receive) }
end)

RegisterNetEvent('rsg-cooking:server:cancelCooking', function()
    local src = source
    local session = activeSessions[src]
    if not session then return end
    activeSessions[src] = nil
    if Webhooks then Webhooks.CookingCancelled(src, Config.Cooking[session.index]) end
end)

AddEventHandler('playerDropped', function()
    activeSessions[source] = nil
end)

---------------------------------------------
-- SERVER EXPORTS (for trusted server-side resources)
---------------------------------------------
exports('CheckPlayerIngredients', function(src, ingredients)
    if not RSGCore.Functions.GetPlayer(src) or type(ingredients) ~= 'table' or #ingredients == 0 then
        return { success = false, missingItems = {} }
    end
    local missing = getMissingIngredients(src, ingredients)
    return { success = #missing == 0, missingItems = missing }
end)

exports('GetPlayerCookingXP', function(src, xpType)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player and getXP(Player, xpType) or 0
end)

exports('GivePlayerCookingXP', function(src, xpGain, xpType)
    local Player = RSGCore.Functions.GetPlayer(src)
    xpGain = tonumber(xpGain)
    if not Player or not xpGain or xpGain <= 0 then return false end
    return IncreasePlayerXP(src, Player, math.floor(xpGain), xpType)
end)

exports('ProcessCooking', function(src, cookData)
    local valid, err = isValidRecipe(cookData)
    if not valid then return { success = false, error = err } end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return { success = false, error = 'Player not found' } end

    local ok, reason, missing = cookRecipe(src, Player, cookData, 'rsg-cooking-external')
    if not ok then return { success = false, error = reason, missingItems = missing } end
    return { success = true }
end)

exports('ProcessCookingWithJobCheck', function(src, cookData)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return { success = false, error = 'Player not found' } end
    if type(cookData) == 'table' and not hasRequiredJob(Player, cookData.requiredjob) then
        return {
            success = false,
            error = 'Job requirement not met',
            requiredJob = cookData.requiredjob,
            playerJob = Player.PlayerData.job.type,
        }
    end
    return exports[GetCurrentResourceName()]:ProcessCooking(src, cookData)
end)

exports('GetCookingRecipes', function() return Config.Cooking end)

exports('CanCookItem', function(itemName)
    local recipe = CookingUtils.FindRecipeByItem(itemName)
    return recipe ~= nil, recipe
end)

exports('CheckPlayerJob', function(src, requiredJob)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player ~= nil and hasRequiredJob(Player, requiredJob)
end)

exports('GetPlayerJob', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    return Player and Player.PlayerData.job.type or nil
end)

exports('GetRecipeJobRequirement', function(itemName)
    local recipe = CookingUtils.FindRecipeByItem(itemName)
    return recipe and recipe.requiredjob or nil
end)

exports('GetRecipesByJob', function(jobName)
    local list = {}
    for _, recipe in ipairs(Config.Cooking) do
        if not recipe.requiredjob or recipe.requiredjob == jobName then
            list[#list + 1] = recipe
        end
    end
    return list
end)

-- added recipes show up in every player's menu automatically (menus are served by the server)
exports('AddCustomRecipe', function(recipe)
    if type(recipe) ~= 'table' then return false, 'Recipe must be a table' end
    if recipe.cookingxp then -- backwards compatibility
        recipe.xpreward = recipe.xpreward or recipe.cookingxp
        recipe.requiredxp = recipe.requiredxp or recipe.cookingxp
    end
    if not recipe.category or not recipe.cooktime then return false, 'Missing category or cooktime' end

    local ok, err = isValidRecipe(recipe)
    if not ok then return false, err end
    if CookingUtils.FindRecipeByItem(recipe.receive) then
        return false, 'Recipe already exists for item: ' .. recipe.receive
    end

    Config.Cooking[#Config.Cooking + 1] = recipe
    return true, 'Recipe added successfully'
end)
