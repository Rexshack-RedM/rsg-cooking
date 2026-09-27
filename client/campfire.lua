local RSGCore = exports['rsg-core']:GetCoreObject()
local cfg = Config.Campfire

-- [id] = { point = lib.point, entity = handle|nil, owner = citizenid, coords = vec3, heading = number }
local campfires = {}
local placing = false
local myCitizenId = nil

-- RedM control hashes
local KEY_PLACE  = 0xC7B5340A -- ENTER
local KEY_CANCEL = 0x156F7119 -- BACKSPACE
local KEY_ROT_L  = 0xA65EBAB4 -- LEFT ARROW
local KEY_ROT_R  = 0xDEB34313 -- RIGHT ARROW

local function notify(desc, ntype)
    lib.notify({ title = locale('campfire_title'), description = desc, type = ntype or 'inform', duration = 4000 })
end

local function refreshCitizenId()
    local pd = RSGCore.Functions.GetPlayerData()
    myCitizenId = pd and pd.citizenid
end

---------------------------------------------
-- streaming: objects only exist while a player is nearby
---------------------------------------------
local function createObject(id)
    local c = campfires[id]
    if not c or c.entity then return end
    if not lib.requestModel(cfg.Model, 5000) then return end
    if not campfires[id] then return end -- removed while the model loaded

    local obj = CreateObject(cfg.Model, c.coords.x, c.coords.y, c.coords.z, false, false, false)
    SetModelAsNoLongerNeeded(cfg.Model)
    SetEntityHeading(obj, c.heading)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)

    exports.ox_target:addLocalEntity(obj, {
        {
            name = 'rsg_cooking_campfire_cook',
            icon = 'fa-solid fa-fire',
            label = locale('campfire_cook'),
            distance = 2.5,
            onSelect = function() exports[GetCurrentResourceName()]:OpenCookingMenu(Config.CookingTypes.CAMPFIRE) end,
        },
        {
            name = 'rsg_cooking_campfire_remove',
            icon = 'fa-solid fa-fire-extinguisher',
            label = locale('campfire_remove'),
            distance = 2.5,
            canInteract = function() return c.owner == myCitizenId end,
            onSelect = function() TriggerServerEvent('rsg-cooking:server:removeCampfire', id) end,
        },
    })
    c.entity = obj
end

local function deleteObject(c)
    if c.entity and DoesEntityExist(c.entity) then
        exports.ox_target:removeLocalEntity(c.entity)
        DeleteEntity(c.entity)
    end
    c.entity = nil
end

local function addCampfire(id, data)
    if campfires[id] or type(data) ~= 'table' then return end
    local c = { owner = data.owner, coords = data.coords, heading = data.heading }
    campfires[id] = c
    c.point = lib.points.new({
        coords = data.coords,
        distance = cfg.SpawnDistance,
        onEnter = function() CreateThread(function() createObject(id) end) end,
        onExit = function() deleteObject(c) end,
    })
end

local function removeCampfire(id)
    local c = campfires[id]
    if not c then return end
    campfires[id] = nil
    c.point:remove()
    deleteObject(c)
end

RegisterNetEvent('rsg-cooking:client:campfireAdded', addCampfire)
RegisterNetEvent('rsg-cooking:client:campfireRemoved', removeCampfire)

local function loadCampfires()
    refreshCitizenId()
    local list = lib.callback.await('rsg-cooking:server:getCampfires', false)
    for id, data in pairs(list or {}) do addCampfire(id, data) end
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', loadCampfires)
CreateThread(function()
    if LocalPlayer.state.isLoggedIn then loadCampfires() end
end)

---------------------------------------------
-- placement gizmo
---------------------------------------------
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

local function startPlacement()
    if not lib.requestModel(cfg.Model, 5000) then return end
    placing = true

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

        if hit then
            SetEntityCoords(ghost, coords.x, coords.y, coords.z, false, false, false, false)
            PlaceObjectOnGroundProperly(ghost)
        end
        SetEntityHeading(ghost, heading)
        SetEntityAlpha(ghost, valid and 200 or 70, false)

        if IsDisabledControlPressed(0, KEY_ROT_L) then heading = (heading + 2.0) % 360 end
        if IsDisabledControlPressed(0, KEY_ROT_R) then heading = (heading - 2.0) % 360 end

        if IsDisabledControlJustPressed(0, KEY_CANCEL) then
            placing = false
            notify(locale('campfire_cancelled'))
        elseif IsDisabledControlJustPressed(0, KEY_PLACE) then
            if valid then
                final = GetEntityCoords(ghost)
                placing = false
            else
                notify(locale('campfire_invalid'), 'error')
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
        TriggerServerEvent('rsg-cooking:server:placeCampfire', final, heading)
    end
    ClearPedTasks(ped)
end

local function tryStartPlacement()
    if placing or LocalPlayer.state.inv_busy then return end
    CreateThread(startPlacement)
end

RegisterCommand(cfg.Command, tryStartPlacement, false)

-- triggered by using the campfire item (item is only consumed server-side once placed)
RegisterNetEvent('rsg-cooking:client:useCampfireItem', tryStartPlacement)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    placing = false
    lib.hideTextUI()
    for id in pairs(campfires) do removeCampfire(id) end
end)
