local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()
local cfg = Config.Campfire

local campfires = {} -- [id] = { coords, heading, owner, expires }  (id = database id)
local placingLock = {} -- [citizenid] = true while a placement is being saved
local loaded = false

-- shared with server/server.lua to verify campfire cooking
CampfireServer = {}
function CampfireServer.IsNear(src, maxDist)
    local pcoords = GetEntityCoords(GetPlayerPed(src))
    for _, c in pairs(campfires) do
        if #(pcoords - c.coords) <= maxDist then return true end
    end
    return false
end

local function notify(src, desc, ntype)
    TriggerClientEvent('rsg-cooking:client:notify', src, { title = locale('campfire_title'), description = desc, type = ntype or 'inform' })
end

local function countOwned(citizenid)
    local n = 0
    for _, c in pairs(campfires) do
        if c.owner == citizenid then n = n + 1 end
    end
    return n
end

local function removeCampfire(id)
    if not campfires[id] then return end
    campfires[id] = nil
    MySQL.update('DELETE FROM rsg_cooking_campfires WHERE id = ?', { id })
    TriggerClientEvent('rsg-cooking:client:campfireRemoved', -1, id)
end

---------------------------------------------
-- load saved campfires on resource start
---------------------------------------------
MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `rsg_cooking_campfires` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `x` FLOAT NOT NULL, `y` FLOAT NOT NULL, `z` FLOAT NOT NULL,
            `heading` FLOAT NOT NULL DEFAULT 0,
            `expires` INT UNSIGNED NULL DEFAULT NULL,
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`), INDEX `idx_citizenid` (`citizenid`)
        )
    ]])
    MySQL.update.await('DELETE FROM rsg_cooking_campfires WHERE expires IS NOT NULL AND expires <= ?', { os.time() })

    local rows = MySQL.query.await('SELECT * FROM rsg_cooking_campfires') or {}
    for _, r in ipairs(rows) do
        campfires[r.id] = {
            coords = vector3(r.x, r.y, r.z), heading = r.heading, owner = r.citizenid, expires = r.expires,
        }
        TriggerClientEvent('rsg-cooking:client:campfireAdded', -1, r.id,
            { coords = campfires[r.id].coords, heading = r.heading, owner = r.citizenid })
    end
    loaded = true
    print(('[rsg-cooking] loaded %d campfire(s)'):format(#rows))
end)

lib.callback.register('rsg-cooking:server:getCampfires', function()
    local list = {}
    for id, c in pairs(campfires) do
        list[id] = { coords = c.coords, heading = c.heading, owner = c.owner }
    end
    return list
end)

RegisterNetEvent('rsg-cooking:server:placeCampfire', function(coords, heading)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not loaded or not Player or type(coords) ~= 'vector3' then return end
    heading = tonumber(heading) or 0.0

    -- must be placed close to the player
    local pcoords = GetEntityCoords(GetPlayerPed(src))
    if #(pcoords - coords) > cfg.PlaceDistance + 2.0 then return end

    local citizenid = Player.PlayerData.citizenid
    if placingLock[citizenid] then return end
    if countOwned(citizenid) >= cfg.MaxPerPlayer then
        return notify(src, locale('campfire_limit', cfg.MaxPerPlayer), 'error')
    end

    for _, c in pairs(campfires) do
        if #(c.coords - coords) < cfg.MinSpacing then
            return notify(src, locale('campfire_too_close'), 'error')
        end
    end

    local Inventory = exports['rsg-inventory']
    local item = cfg.RequiredItem
    local itemData = item and RSGCore.Shared.Items[item]
    if item and (Inventory:GetItemCount(src, item) or 0) < 1 then
        return notify(src, locale('campfire_need_item', itemData and itemData.label or item), 'error')
    end

    placingLock[citizenid] = true
    local expires = cfg.Duration > 0 and (os.time() + cfg.Duration * 60) or nil
    local id = MySQL.insert.await(
        'INSERT INTO rsg_cooking_campfires (citizenid, x, y, z, heading, expires) VALUES (?, ?, ?, ?, ?, ?)',
        { citizenid, coords.x, coords.y, coords.z, heading, expires })
    if not id then
        placingLock[citizenid] = nil
        return notify(src, locale('cook_error'), 'error')
    end

    -- only take the item once the campfire is safely saved
    if item then
        if not Inventory:RemoveItem(src, item, 1, nil, 'rsg-cooking-campfire') then
            MySQL.update('DELETE FROM rsg_cooking_campfires WHERE id = ?', { id })
            placingLock[citizenid] = nil
            return notify(src, locale('campfire_need_item', itemData and itemData.label or item), 'error')
        end
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, itemData, 'remove', 1)
    end

    placingLock[citizenid] = nil
    campfires[id] = { coords = coords, heading = heading, owner = citizenid, expires = expires }
    TriggerClientEvent('rsg-cooking:client:campfireAdded', -1, id, { coords = coords, heading = heading, owner = citizenid })
    notify(src, locale('campfire_placed'), 'success')
end)

RegisterNetEvent('rsg-cooking:server:removeCampfire', function(id)
    local src = source
    id = tonumber(id)
    local Player = RSGCore.Functions.GetPlayer(src)
    local c = campfires[id]
    if not Player or not c or c.owner ~= Player.PlayerData.citizenid then return end
    if #(GetEntityCoords(GetPlayerPed(src)) - c.coords) > 5.0 then return end
    removeCampfire(id)
    notify(src, locale('campfire_removed'), 'inform')
end)

-- burn out old campfires
CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for id, c in pairs(campfires) do
            if c.expires and now >= c.expires then removeCampfire(id) end
        end
    end
end)
