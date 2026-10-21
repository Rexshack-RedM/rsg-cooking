lib.locale()

local Stations = {}  -- [id] = public data
local Objects  = {}  -- [id] = spawned campfire entity
local WorldObj = {}  -- [id] = map stove entity (never deleted by us)
local Fx       = {}  -- [id] = { particle handles }
local uiOpen   = nil -- station id while the NUI is open
local uiReady  = false

---------------------------------
-- particle effects while cooking
---------------------------------
local function stopFx(id)
    if not Fx[id] then return end
    for _, h in ipairs(Fx[id]) do StopParticleFxLooped(h, false) end
    Fx[id] = nil
end

local function startFx(id)
    local obj = Objects[id] or WorldObj[id]
    if Fx[id] or not obj or not Config.CookFx.enabled then return end
    local dict = Config.CookFx.dict
    local hash = joaat(dict)
    if not HasNamedPtfxAssetLoaded(hash) then
        RequestNamedPtfxAsset(hash)
        local t = GetGameTimer() + 5000
        while not HasNamedPtfxAssetLoaded(hash) and GetGameTimer() < t do Wait(10) end
        if not HasNamedPtfxAssetLoaded(hash) then return end
    end
    local handles = {}
    for _, e in ipairs(Config.CookFx.effects) do
        UseParticleFxAsset(dict)
        local h = StartParticleFxLoopedOnEntity(e.name, obj, e.offset.x, e.offset.y, e.offset.z, 0.0, 0.0, 0.0, e.scale, false, false, false)
        if h and h ~= 0 then handles[#handles + 1] = h end
    end
    Fx[id] = handles
end

local function updateFx(id)
    local s = Stations[id]
    if s and s.cooking then startFx(id) else stopFx(id) end
end

---------------------------------
-- campfire props
---------------------------------
local openStationMenu, closeUi

local function despawnCampfire(id)
    stopFx(id)
    local obj = Objects[id]
    if obj and DoesEntityExist(obj) then
        exports.ox_target:removeLocalEntity(obj)
        DeleteObject(obj)
    end
    Objects[id] = nil
end

local function spawnCampfire(s)
    if Objects[s.id] then return end
    if not lib.requestModel(Config.Campfire.Model, 5000) then return end
    if not Stations[s.id] or Objects[s.id] then return end
    local obj = CreateObject(Config.Campfire.Model, s.coords.x, s.coords.y, s.coords.z, false, false, false)
    SetModelAsNoLongerNeeded(Config.Campfire.Model)
    SetEntityHeading(obj, s.heading)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    Objects[s.id] = obj

    exports.ox_target:addLocalEntity(obj, {
        {
            name = 'rsg_cooking_campfire_' .. s.id,
            icon = 'fa-solid fa-fire',
            label = locale('target_campfire'),
            distance = 2.5,
            onSelect = function() openStationMenu(s.id) end,
        },
    })
end

local function findStoveProp(coords)
    for _, m in ipairs(Config.WorldStations.models) do
        local e = GetClosestObjectOfType(coords.x, coords.y, coords.z, 1.5, m, false, false, false)
        if e and e ~= 0 then return e end
    end
end

local function refreshNearby()
    local pos = GetEntityCoords(cache.ped)
    for id, s in pairs(Stations) do
        local near = #(pos - s.coords) <= Config.SpawnDist
        if s.world then
            -- map props are only tracked for particle effects
            if s.stype == 'stove' and Config.CookFx.enabled then
                if near and not (WorldObj[id] and DoesEntityExist(WorldObj[id])) then
                    stopFx(id)
                    WorldObj[id] = findStoveProp(s.coords)
                    updateFx(id)
                elseif not near and WorldObj[id] then
                    stopFx(id)
                    WorldObj[id] = nil
                end
            end
        elseif near and not Objects[id] then
            spawnCampfire(s)
            updateFx(id)
        elseif not near and Objects[id] then
            despawnCampfire(id)
        end
    end
end

local streaming = false
local function startStreaming()
    if streaming then return end
    streaming = true
    CreateThread(function()
        while streaming do
            refreshNearby()
            Wait(2000)
        end
    end)
end

local function clearAll()
    for id in pairs(Objects) do despawnCampfire(id) end
    for id in pairs(WorldObj) do stopFx(id) end
    WorldObj, Stations = {}, {}
end

local function loadStations()
    local list = lib.callback.await('rsg-cooking:server:getStations', false)
    clearAll()
    for _, s in ipairs(list or {}) do Stations[s.id] = s end
    refreshNearby()
    startStreaming()
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', loadStations)
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function()
    streaming = false
    closeUi()
    clearAll()
end)
AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() and LocalPlayer.state.isLoggedIn then loadStations() end
end)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    streaming = false
    closeUi()
    clearAll()
    if Config.WorldStations.enabled then exports.ox_target:removeModel(Config.WorldStations.models, 'rsg_cooking_stove') end
end)

RegisterNetEvent('rsg-cooking:client:syncStation', function(s)
    Stations[s.id] = s
    if Objects[s.id] or WorldObj[s.id] then
        updateFx(s.id)
    elseif s.world then
        refreshNearby()
    elseif #(GetEntityCoords(cache.ped) - s.coords) <= Config.SpawnDist then
        spawnCampfire(s)
        updateFx(s.id)
    end
end)

RegisterNetEvent('rsg-cooking:client:removeStation', function(id)
    if uiOpen == id then closeUi() end
    Stations[id] = nil
    WorldObj[id] = nil
    despawnCampfire(id)
end)

---------------------------------
-- NUI
---------------------------------
local UiLocale = {
    'ui_subtitle', 'ui_recipe', 'ui_choose_recipe', 'ui_hopper', 'ui_per_batch', 'ui_loaded', 'ui_have',
    'ui_load', 'ui_load_all', 'ui_unload', 'ui_status', 'ui_idle', 'ui_cooking', 'ui_waiting', 'ui_full',
    'ui_current_batch', 'ui_queued', 'ui_tank', 'ui_collect', 'ui_pickup', 'ui_change_recipe', 'ui_batch_time',
    'ui_makes', 'ui_close', 'ui_locked', 'ui_select', 'ui_all',
    'ui_firebox', 'ui_fuel_left', 'ui_burns', 'ui_each', 'ui_nofuel', 'ui_paused', 'ui_add', 'ui_level',
    'ui_requires', 'ui_max_level', 'ui_xp',
}

closeUi = function()
    if not uiOpen then return end
    uiOpen, uiReady = nil, false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

openStationMenu = function(id)
    if uiOpen then return end
    local state = lib.callback.await('rsg-cooking:server:getState', false, id)
    if not state then return end
    uiOpen = id

    local strings = {}
    for _, k in ipairs(UiLocale) do strings[k] = locale(k) end
    strings.ui_title = locale('station_' .. (state.stype or 'stove'))
    Wait(150) -- let ox_target finish closing and release its own focus first
    if uiOpen ~= id then return end
    SendNUIMessage({ action = 'open', state = state, locale = strings, imagePath = Config.ImagePath })
    SetTimeout(2000, function()
        if uiOpen == id and not uiReady then
            print('^1[rsg-cooking] NUI did not respond - check the html files are on the server and run "refresh" then "ensure rsg-cooking"^7')
            uiOpen = nil
            SetNuiFocus(false, false)
        end
    end)

    -- refresh loop + auto close when walking away / dying
    CreateThread(function()
        local ticks = 0
        while uiOpen == id do
            Wait(500)
            ticks = ticks + 1
            local ped = cache.ped
            local s = Stations[id]
            if not s or IsEntityDead(ped) or #(GetEntityCoords(ped) - s.coords) > Config.InteractDist then
                closeUi()
                break
            end
            if ticks % 6 == 0 then
                local st = lib.callback.await('rsg-cooking:server:getState', false, id)
                if uiOpen == id and st then SendNUIMessage({ action = 'update', state = st }) end
            end
        end
    end)
end

RegisterNUICallback('opened', function(_, cb)
    if uiOpen then
        uiReady = true
        SetNuiFocus(true, true)
    end
    cb('ok')
end)

RegisterNUICallback('uiError', function(data, cb)
    print(('^1[rsg-cooking] NUI error: %s^7'):format(tostring(data and data.msg)))
    uiReady, uiOpen = false, nil
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('close', function(_, cb)
    closeUi()
    cb('ok')
end)

RegisterNUICallback('action', function(data, cb)
    if not uiOpen then return cb('ok') end
    local state = lib.callback.await('rsg-cooking:server:action', false, uiOpen, data.action, data.data)
    if state then
        SendNUIMessage({ action = 'update', state = state })
    elseif data.action == 'pickup' then
        closeUi()
    end
    cb('ok')
end)

-- emergency release if the cursor ever gets stuck
RegisterCommand('cooking_unfocus', function()
    uiOpen, uiReady = nil, false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end, false)

---------------------------------
-- world stations
---------------------------------
local function openWorld(coords, stype, entity)
    local s = lib.callback.await('rsg-cooking:server:getWorldStation', false, coords, stype)
    if not s then return end
    Stations[s.id] = s
    if entity then WorldObj[s.id] = entity end
    updateFx(s.id)
    openStationMenu(s.id)
end

if Config.WorldStations.enabled then
    exports.ox_target:addModel(Config.WorldStations.models, {
        {
            name = 'rsg_cooking_stove',
            icon = 'fa-solid fa-fire-burner',
            label = locale('target_stove'),
            distance = Config.WorldStations.distance or 2.0,
            onSelect = function(data) openWorld(GetEntityCoords(data.entity), 'stove', data.entity) end,
        },
    })
end

exports('GetCookingRecipes', function(category)
    if not category then return Config.Recipes end
    local list = {}
    for _, r in ipairs(Config.Recipes) do if r.category == category then list[#list + 1] = r end end
    return list
end)

exports('GetRecipesByCookingType', function(stype)
    if not stype then return Config.Recipes end
    local list = {}
    for _, r in ipairs(Config.Recipes) do if Config.RecipeAllowed(r, stype) then list[#list + 1] = r end end
    return list
end)

---------------------------------
-- campfire placement (camera preview)
---------------------------------
local KEY_PLACE  = 0xC7B5340A -- ENTER
local KEY_CANCEL = 0x156F7119 -- BACKSPACE
local KEY_ROT_L  = 0xA65EBAB4 -- LEFT ARROW
local KEY_ROT_R  = 0xDEB34313 -- RIGHT ARROW
local placing = false

local function rotToDir(rot)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function cameraRaycast(ignore, dist)
    local camPos = GetGameplayCamCoord()
    local dest = camPos + rotToDir(GetGameplayCamRot(2)) * dist
    local ray = StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, 1 | 16, ignore, 0)
    local _, hit, coords = GetShapeTestResult(ray)
    return hit == 1, coords
end

local function campNotify(desc, ntype)
    lib.notify({ title = locale('station_campfire'), description = desc, type = ntype or 'inform', duration = 4000 })
end

local function startPlacement()
    local cfg = Config.Campfire
    if not lib.requestModel(cfg.Model, 5000) then placing = false return end

    local ped = cache.ped
    local pc = GetEntityCoords(ped)
    local ghost = CreateObject(cfg.Model, pc.x, pc.y, pc.z, false, false, false)
    SetModelAsNoLongerNeeded(cfg.Model)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)

    local heading = GetEntityHeading(ped)
    local final
    lib.showTextUI(locale('campfire_controls'), { position = 'left-center' })

    while placing do
        Wait(0)
        DisableControlAction(0, KEY_PLACE, true)
        DisableControlAction(0, KEY_CANCEL, true)
        DisableControlAction(0, KEY_ROT_L, true)
        DisableControlAction(0, KEY_ROT_R, true)

        local hit, coords = cameraRaycast(ghost, cfg.PlaceDistance + 5.0)
        local valid = hit and #(coords - GetEntityCoords(ped)) <= cfg.PlaceDistance and not IsPedInAnyVehicle(ped, false)
        if valid then
            for _, s in pairs(Stations) do
                if #(coords - s.coords) < cfg.MinSpacing then valid = false break end
            end
        end

        if hit then
            SetEntityCoords(ghost, coords.x, coords.y, coords.z, false, false, false, false)
            PlaceObjectOnGroundProperly(ghost)
        end
        SetEntityHeading(ghost, heading)
        SetEntityAlpha(ghost, valid and 200 or 70, false)

        if IsDisabledControlPressed(0, KEY_ROT_L) then heading = (heading + 2.0) % 360 end
        if IsDisabledControlPressed(0, KEY_ROT_R) then heading = (heading - 2.0) % 360 end

        if IsDisabledControlJustPressed(0, KEY_CANCEL) or IsEntityDead(ped) then
            placing = false
            campNotify(locale('campfire_cancelled'))
        elseif IsDisabledControlJustPressed(0, KEY_PLACE) then
            if valid then
                final = GetEntityCoords(ghost)
                placing = false
            else
                campNotify(locale('campfire_invalid'), 'error')
            end
        end
    end

    DeleteEntity(ghost)
    lib.hideTextUI()
    if not final then return end

    if lib.progressBar({
        duration = cfg.SetupTime,
        label = locale('campfire_setting_up'),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, combat = true },
        anim = { scenario = 'WORLD_HUMAN_CROUCH_INSPECT' },
    }) then
        TriggerServerEvent('rsg-cooking:server:placeCampfire', final, heading + 0.0)
    end
    ClearPedTasks(ped)
end

local function tryStartPlacement()
    if placing or uiOpen or LocalPlayer.state.inv_busy or IsEntityDead(cache.ped) then return end
    placing = true
    CreateThread(startPlacement)
end

RegisterNetEvent('rsg-cooking:client:placeCampfire', tryStartPlacement)
if Config.Campfire.Command then
    -- the server checks the item and campfire limit first, then starts the placement preview
    RegisterCommand(Config.Campfire.Command, function()
        if placing or uiOpen then return end
        TriggerServerEvent('rsg-cooking:server:requestCampfire')
    end, false)
end
