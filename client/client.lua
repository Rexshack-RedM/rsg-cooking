lib.locale()

local TYPE_LABELS = {
    stove = 'type_stove',
    campfire = 'type_campfire',
    campsite = 'type_campsite',
    cookjob = 'type_cookjob',
    all = 'type_all',
}

local ANIM_DICT = 'amb_work@world_human_bartender@serve_player'
local ANIM_CLIP = 'take_glass_trans_pour_beer_hold'

local UI_LOCALE_KEYS = {
    'menu_current_xp', 'recipe_locked', 'meta_cook_time', 'meta_xp_reward', 'meta_required_job', 'progress_cooking',
    'ui_locked', 'ui_makes', 'ui_each', 'ui_for', 'ui_total', 'ui_cook', 'ui_missing', 'ui_left', 'ui_select',
    'ui_quantity', 'ui_ingredients', 'ui_stop', 'cook_success', 'ui_close', 'ui_xp', 'seconds', 'minutes_seconds',
}

local uiOpen = false
local currentType = nil
local cooking = nil -- { id = recipeId, cancelled = bool }

---------------------------------------------
-- helpers
---------------------------------------------
-- ox_lib notifications, suppressed while the cooking UI is open (the UI shows its own status)
local function notify(title, description, ntype, duration)
    if uiOpen then return end
    lib.notify({ title = title, description = description, type = ntype or 'inform', duration = duration or 5000 })
end

RegisterNetEvent('rsg-cooking:client:notify', function(data)
    if type(data) ~= 'table' then return end
    notify(data.title, data.description, data.type, data.duration)
end)

local function uiLocale()
    local t = {}
    for _, k in ipairs(UI_LOCALE_KEYS) do t[k] = locale(k) end
    return t
end

local function fetchRecipes(cookingType)
    local data = lib.callback.await('rsg-cooking:server:getRecipes', false, cookingType)
    if not data or #data.recipes == 0 then return nil end
    return data
end

-- turns a failed server result into a short line shown inside the UI
local function failReason(result)
    local reason = result and result.reason
    if reason == 'busy' then return locale('busy_desc') end
    if reason == 'job' then return locale('job_required_desc', result.requiredJob) end
    if reason == 'xp' then return locale('xp_required_desc', result.requiredXP, result.currentXP) end
    if reason == 'missing' then return locale('ui_missing') end
    if reason == 'inventory_full' then return locale('inventory_full', result.label or '') end
    if reason == 'too_far' then return locale('too_far') end
    return locale('cook_error')
end

---------------------------------------------
-- NUI
---------------------------------------------
local function closeUI()
    if not uiOpen then return end
    if cooking then cooking.cancelled = true end
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function refreshUI()
    if not uiOpen then return end
    local data = fetchRecipes(currentType)
    if not data then return closeUI() end
    SendNUIMessage({ action = 'refresh', xp = data.xp, recipes = data.recipes })
end

local function OpenCookingMenu(cookingType)
    cookingType = cookingType or Config.CookingTypes.STOVE
    if cooking or uiOpen then return end

    local data = fetchRecipes(cookingType)
    if not data then
        return notify(locale('notify_title'), locale('no_recipes'), 'inform')
    end

    currentType = cookingType
    uiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        title = locale('menu_title', locale(TYPE_LABELS[cookingType] or 'type_stove')),
        imagePath = 'nui://' .. Config.Image,
        maxBatch = Config.MaxBatch,
        locale = uiLocale(),
        xp = data.xp,
        recipes = data.recipes,
    })
end

-- runs the timed cook; the server has already validated and opened a session
local function runCooking(recipeId, duration)
    cooking = { id = recipeId, cancelled = false }
    LocalPlayer.state:set('inv_busy', true, true)

    local ped = cache.ped
    if lib.requestAnimDict(ANIM_DICT, 5000) then
        TaskPlayAnim(ped, ANIM_DICT, ANIM_CLIP, 8.0, -8.0, -1, 1, 0, false, false, false)
    end

    local endsAt = GetGameTimer() + duration
    while GetGameTimer() < endsAt and not cooking.cancelled and not IsEntityDead(ped) do
        Wait(100)
    end

    local finished = not cooking.cancelled and not IsEntityDead(ped)
    ClearPedTasks(ped)
    RemoveAnimDict(ANIM_DICT)

    if finished then
        local result = lib.callback.await('rsg-cooking:server:finishCooking', false, recipeId)
        SendNUIMessage({
            action = 'finished',
            ok = result and result.ok,
            message = result and result.ok and locale('cook_success', result.amount, result.label) or failReason(result),
        })
    else
        TriggerServerEvent('rsg-cooking:server:cancelCooking')
        SendNUIMessage({ action = 'cancelled' })
    end

    LocalPlayer.state:set('inv_busy', false, true)
    cooking = nil
    refreshUI()
end

RegisterNUICallback('cook', function(data, cb)
    if cooking or not uiOpen or type(data) ~= 'table' then return cb({ ok = false }) end
    local id = tonumber(data.id)

    local result = lib.callback.await('rsg-cooking:server:startCooking', false, id, currentType, tonumber(data.qty))
    if not result or not result.ok then
        cb({ ok = false, error = failReason(result) })
        return refreshUI()
    end

    cb({ ok = true, cooktime = result.cooktime, label = result.label, qty = result.qty })
    CreateThread(function() runCooking(id, result.cooktime) end)
end)

RegisterNUICallback('cancel', function(_, cb)
    if cooking then cooking.cancelled = true end
    cb({})
end)

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb({})
end)

-- for other client scripts: TriggerEvent('rsg-cooking:client:cookingmenu', { cookingType = 'campfire' })
AddEventHandler('rsg-cooking:client:cookingmenu', function(data)
    OpenCookingMenu(type(data) == 'table' and data.cookingType or nil)
end)

---------------------------------------------
-- target cooking props
---------------------------------------------
exports.ox_target:addModel(Config.CookingProps, {
    {
        name = 'rsg_cooking_props',
        icon = 'fa-solid fa-fire-burner',
        label = locale('target_open_cooking'),
        distance = 2.0,
        onSelect = function() OpenCookingMenu(Config.CookingTypes.STOVE) end,
    },
})

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    exports.ox_target:removeModel(Config.CookingProps, 'rsg_cooking_props')
    if cooking then
        LocalPlayer.state:set('inv_busy', false, true)
        ClearPedTasks(cache.ped)
    end
    if uiOpen then SetNuiFocus(false, false) end
end)

---------------------------------------------
-- CLIENT EXPORTS
---------------------------------------------
exports('OpenCookingMenu', OpenCookingMenu)

exports('GetCookingRecipes', function(category)
    if not category then return Config.Cooking end
    local list = {}
    for _, recipe in ipairs(Config.Cooking) do
        if recipe.category == category then list[#list + 1] = recipe end
    end
    return list
end)

exports('GetCookingCategories', function()
    local list, seen = {}, {}
    for _, recipe in ipairs(Config.Cooking) do
        if not seen[recipe.category] then
            seen[recipe.category] = true
            list[#list + 1] = recipe.category
        end
    end
    return list
end)

exports('GetRecipeByItem', function(itemName)
    return (CookingUtils.FindRecipeByItem(itemName))
end)

exports('GetRecipeIngredients', function(itemName)
    local recipe = CookingUtils.FindRecipeByItem(itemName)
    if not recipe then return nil end
    local items = exports['rsg-core']:GetCoreObject().Shared.Items
    local list = {}
    for _, ing in ipairs(recipe.ingredients) do
        local data = items[ing.item]
        list[#list + 1] = { item = ing.item, amount = ing.amount, label = data and data.label or ing.item }
    end
    return list
end)

exports('GetRecipesByCookingType', function(cookingType)
    if not cookingType then return Config.Cooking end
    local list = {}
    for _, recipe in ipairs(Config.Cooking) do
        if CookingUtils.MatchesType(recipe, cookingType) then list[#list + 1] = recipe end
    end
    return list
end)
