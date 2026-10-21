local RSGCore = exports['rsg-core']:GetCoreObject()
local W = SvConfig.Webhooks

---------------------------------
-- queue: Discord allows ~30 requests/min per webhook, so send one at a time and honour 429s
---------------------------------
local queue, busy = {}, false

local function pump()
    if busy or #queue == 0 then return end
    busy = true
    local job = table.remove(queue, 1)
    PerformHttpRequest(job.url, function(status, _, headers)
        local delay = 1000
        if status == 429 then
            table.insert(queue, 1, job) -- retry
            local retry = headers and (headers['retry-after'] or headers['Retry-After'])
            delay = math.floor((tonumber(retry) or 2) * 1000) + 250
        elseif status < 200 or status >= 300 then
            print(('^3[rsg-cooking] webhook failed (HTTP %s)^7'):format(status))
        end
        SetTimeout(delay, function() busy = false pump() end)
    end, 'POST', json.encode(job.payload), { ['Content-Type'] = 'application/json' })
end

---------------------------------
-- player info
---------------------------------
local function identifier(src, prefix)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, #prefix) == prefix then return id end
    end
end

local function playerFields(src)
    if not src or src <= 0 then return {} end
    local Player = RSGCore.Functions.GetPlayer(src)
    local fields = {}
    if Player then
        local ci = Player.PlayerData.charinfo or {}
        fields[#fields + 1] = { name = 'Character', value = ('%s %s'):format(ci.firstname or '?', ci.lastname or '?'), inline = true }
        fields[#fields + 1] = { name = 'Citizen ID', value = Player.PlayerData.citizenid, inline = true }
        local job = Player.PlayerData.job
        if job then fields[#fields + 1] = { name = 'Job', value = ('%s (%s)'):format(job.label or job.name, job.grade and job.grade.name or '?'), inline = true } end
    end
    local discord = identifier(src, 'discord:')
    fields[#fields + 1] = { name = 'Player', value = ('%s [ID %s]'):format(GetPlayerName(src) or 'unknown', src), inline = true }
    fields[#fields + 1] = { name = 'Discord', value = discord and ('<@%s>'):format(discord:sub(9)) or 'n/a', inline = true }
    fields[#fields + 1] = { name = 'License', value = identifier(src, 'license:') or 'n/a', inline = false }
    return fields
end

---------------------------------
-- WebhookLog(event, src, title, description, extraFields)   extraFields = { { name, value, inline? }, ... }
---------------------------------
function WebhookLog(event, src, title, description, extra)
    if not W.enabled then return end
    local ev = W.events[event]
    if not ev or not ev.enabled then return end

    if W.mirrorRsgLog then
        TriggerEvent('rsg-log:server:CreateLog', 'cooking', title, 'default', description)
    end

    local url = (ev.url ~= '' and ev.url) or W.default
    if not url or url == '' then return end

    local fields = playerFields(src)
    for _, f in ipairs(extra or {}) do
        fields[#fields + 1] = { name = f[1], value = tostring(f[2]), inline = f[3] ~= false }
    end

    queue[#queue + 1] = {
        url = url,
        payload = {
            username = W.username,
            avatar_url = W.avatar ~= '' and W.avatar or nil,
            embeds = { {
                title = title, description = description, color = ev.color, fields = fields,
                footer = { text = W.footer }, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            } },
        },
    }
    pump()
end

function CoordsField(c)
    return { 'Location', ('`%.2f, %.2f, %.2f`'):format(c.x, c.y, c.z), false }
end
