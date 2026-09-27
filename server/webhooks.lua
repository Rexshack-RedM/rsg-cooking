local RSGCore = exports['rsg-core']:GetCoreObject()
local Cfg = WebhookConfig

Webhooks = {}

---------------------------------
-- rate limiting (counted when sent, not when Discord replies)
---------------------------------
local sentThisWindow, windowStart = 0, os.time()

local function canSend()
    if not Cfg.RateLimit.Enabled then return true end
    local now = os.time()
    if now - windowStart >= 60 then
        sentThisWindow, windowStart = 0, now
    end
    return sentThisWindow < Cfg.RateLimit.MaxPerMinute
end

local function send(url, embed)
    if not url or url == '' then return end
    if not canSend() then
        print('^3[rsg-cooking] Webhook rate limit reached, skipping webhook^7')
        return
    end
    sentThisWindow = sentThisWindow + 1

    PerformHttpRequest(url, function(status)
        if status ~= 200 and status ~= 204 then
            print('^1[rsg-cooking] Webhook error: ' .. tostring(status) .. '^7')
        end
    end, 'POST', json.encode({ username = Cfg.Username, embeds = { embed } }), { ['Content-Type'] = 'application/json' })
end

---------------------------------
-- formatting helpers
---------------------------------
local function itemLabel(item)
    local data = RSGCore.Shared.Items[item]
    return data and data.label or tostring(item)
end

local function getPlayerInfo(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return nil end
    local pd = Player.PlayerData
    local coords = GetEntityCoords(GetPlayerPed(src))
    return {
        name = pd.charinfo.firstname .. ' ' .. pd.charinfo.lastname,
        citizenid = pd.citizenid,
        job = (pd.job.label or 'Unemployed') .. ' (' .. (pd.job.grade and pd.job.grade.name or 'N/A') .. ')',
        location = ('X: %.2f, Y: %.2f, Z: %.2f'):format(coords.x, coords.y, coords.z),
    }
end

local function formatIngredients(ingredients)
    local list = {}
    for _, ing in ipairs(ingredients or {}) do
        list[#list + 1] = ('%sx %s'):format(ing.amount, itemLabel(ing.item))
    end
    return #list > 0 and table.concat(list, ', ') or 'N/A'
end

local function capitalise(s) return s:sub(1, 1):upper() .. s:sub(2) end

local function formatCookingType(t)
    if type(t) == 'table' then
        local list = {}
        for _, v in ipairs(t) do list[#list + 1] = capitalise(v) end
        return table.concat(list, ' / ')
    end
    return capitalise(t or 'all')
end

local function formatTime(ms)
    local seconds = math.floor((ms or 0) / 1000)
    if seconds < 60 then return seconds .. ' seconds' end
    return ('%d min %d sec'):format(seconds // 60, seconds % 60)
end

local function field(name, value, inline)
    return { name = name, value = tostring(value), inline = inline ~= false }
end

local function baseFields(info)
    return { field('Player', info.name), field('Citizen ID', info.citizenid) }
end

local function buildEmbed(template, fields, description)
    local embed = {
        title = template.title,
        color = template.color,
        description = description,
        fields = fields,
        timestamp = Cfg.DetailedInfo.ShowTimestamp and os.date('!%Y-%m-%dT%H:%M:%SZ') or nil,
        footer = { text = Cfg.Footer.Text, icon_url = Cfg.Footer.IconURL ~= '' and Cfg.Footer.IconURL or nil },
    }
    if Cfg.Thumbnail.Enabled and Cfg.Thumbnail.DefaultURL ~= '' then
        embed.thumbnail = { url = Cfg.Thumbnail.DefaultURL }
    end
    return embed
end

-- common guard: returns player info when this event should be logged
local function prepare(event, src)
    if not Cfg.Enabled or not Cfg.Events[event] then return nil end
    return getPlayerInfo(src)
end

---------------------------------
-- events
---------------------------------
function Webhooks.CookingStarted(src, recipe)
    local info = prepare('CookingStarted', src)
    if not info then return end
    local item = itemLabel(recipe.receive)
    local fields = baseFields(info)
    fields[#fields + 1] = field('Item', item)
    if Cfg.DetailedInfo.ShowPlayerJob then fields[#fields + 1] = field('Job', info.job) end
    if Cfg.DetailedInfo.ShowCookingType then fields[#fields + 1] = field('Cooking Type', formatCookingType(recipe.cookingtype)) end
    if Cfg.DetailedInfo.ShowCookingTime then fields[#fields + 1] = field('Cook Time', formatTime(recipe.cooktime)) end
    if Cfg.DetailedInfo.ShowIngredients then fields[#fields + 1] = field('Ingredients', formatIngredients(recipe.ingredients), false) end
    if Cfg.DetailedInfo.ShowLocation then fields[#fields + 1] = field('Location', info.location, false) end
    send(Cfg.WebhookURL, buildEmbed(Cfg.Templates.CookingStarted, fields,
        ('**%s** started cooking **%s**'):format(info.name, item)))
end

function Webhooks.CookingCompleted(src, recipe)
    local info = prepare('CookingCompleted', src)
    if not info then return end
    local item = itemLabel(recipe.receive)
    local fields = baseFields(info)
    fields[#fields + 1] = field('Item Received', ('%sx %s'):format(recipe.giveamount, item))
    if Cfg.DetailedInfo.ShowPlayerJob then fields[#fields + 1] = field('Job', info.job) end
    if Cfg.DetailedInfo.ShowXPReward and recipe.xpreward then fields[#fields + 1] = field('XP Gained', '+' .. recipe.xpreward .. ' XP') end
    if Cfg.DetailedInfo.ShowCookingType then fields[#fields + 1] = field('Cooking Type', formatCookingType(recipe.cookingtype)) end
    if Cfg.DetailedInfo.ShowLocation then fields[#fields + 1] = field('Location', info.location, false) end
    send(Cfg.WebhookURL, buildEmbed(Cfg.Templates.CookingCompleted, fields,
        ('**%s** successfully cooked **%sx %s**'):format(info.name, recipe.giveamount, item)))
end

function Webhooks.CookingCancelled(src, recipe)
    local info = recipe and prepare('CookingCancelled', src)
    if not info then return end
    local item = itemLabel(recipe.receive)
    local fields = baseFields(info)
    fields[#fields + 1] = field('Item', item)
    if Cfg.DetailedInfo.ShowLocation then fields[#fields + 1] = field('Location', info.location, false) end
    send(Cfg.WebhookURL, buildEmbed(Cfg.Templates.CookingCancelled, fields,
        ('**%s** cancelled cooking **%s**'):format(info.name, item)))
end

function Webhooks.CookingFailed(src, recipe, missingItems)
    local info = prepare('CookingFailed', src)
    if not info then return end
    local item = itemLabel(recipe.receive)
    local missing = {}
    for _, m in ipairs(missingItems or {}) do missing[#missing + 1] = ('%sx %s'):format(m.missing, m.label) end
    local fields = baseFields(info)
    fields[#fields + 1] = field('Attempted Item', item)
    fields[#fields + 1] = field('Missing Items', table.concat(missing, ', '), false)
    if Cfg.DetailedInfo.ShowLocation then fields[#fields + 1] = field('Location', info.location, false) end
    send(Cfg.WebhookURL, buildEmbed(Cfg.Templates.CookingFailed, fields,
        ('**%s** failed to cook **%s** - Missing ingredients'):format(info.name, item)))
end

function Webhooks.JobRestricted(src, recipe, requiredJob)
    local info = prepare('JobRestricted', src)
    if not info then return end
    local item = itemLabel(recipe.receive)
    local fields = baseFields(info)
    fields[#fields + 1] = field('Player Job', info.job)
    fields[#fields + 1] = field('Required Job', requiredJob)
    fields[#fields + 1] = field('Attempted Item', item)
    if Cfg.DetailedInfo.ShowLocation then fields[#fields + 1] = field('Location', info.location, false) end
    send(Cfg.WebhookURL, buildEmbed(Cfg.Templates.JobRestricted, fields,
        ('**%s** tried to cook **%s** but lacks required job: **%s**'):format(info.name, item, requiredJob)))
end

function Webhooks.XPGained(src, xpGained, newTotal)
    local info = prepare('XPGained', src)
    if not info then return end
    local fields = baseFields(info)
    fields[#fields + 1] = field('XP Gained', '+' .. xpGained .. ' XP')
    fields[#fields + 1] = field('Total XP', newTotal .. ' XP')
    if Cfg.Events.LevelUpSimulated then
        local oldLevel, newLevel = (newTotal - xpGained) // 50, newTotal // 50
        if newLevel > oldLevel then fields[#fields + 1] = field('Level Up!', ('Level %d → Level %d'):format(oldLevel, newLevel)) end
    end
    send(Cfg.WebhookURL, buildEmbed(Cfg.Templates.XPGained, fields,
        ('**%s** gained **%s XP** in cooking'):format(info.name, xpGained)))
end

-- fires once when a player's XP crosses a milestone
function Webhooks.CheckMilestones(src, xpGained, newTotal)
    for milestone, rank in pairs(Cfg.XPMilestones) do
        if newTotal >= milestone and newTotal - xpGained < milestone then
            local info = prepare('XPMilestone', src)
            if not info then return end
            local fields = baseFields(info)
            fields[#fields + 1] = field('Milestone', milestone .. ' XP')
            fields[#fields + 1] = field('Rank Achieved', rank)
            fields[#fields + 1] = field('Total XP', newTotal .. ' XP')
            send(Cfg.WebhookURL, buildEmbed(Cfg.Templates.XPMilestone, fields,
                ('🎉 **%s** reached **%d XP** and became a **%s**!'):format(info.name, milestone, rank)))
        end
    end
end

---------------------------------
-- admin alerts
---------------------------------
local function adminAlert(title, description, fields)
    local admin = Cfg.AdminNotifications
    if not admin.Enabled or admin.WebhookURL == '' then return end
    send(admin.WebhookURL, {
        title = '⚠️ ' .. title,
        color = Cfg.Colors.Warning,
        description = description,
        fields = fields,
        timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        footer = { text = Cfg.Username .. ' - Admin Alert' },
    })
end

function Webhooks.CheckHighXP(src, xpGained)
    if not Cfg.AdminNotifications.NotifyOnHighXP or xpGained < Cfg.AdminNotifications.HighXPThreshold then return end
    local info = getPlayerInfo(src)
    if not info then return end
    local fields = baseFields(info)
    fields[#fields + 1] = field('XP Gained', xpGained .. ' XP')
    fields[#fields + 1] = field('Location', info.location, false)
    adminAlert('High XP Gain Detected',
        ('Player **%s** gained **%s XP** in a single cooking action'):format(info.name, xpGained), fields)
end

function Webhooks.Suspicious(src, title, detail)
    if not Cfg.AdminNotifications.NotifyOnSuspicious then return end
    local info = getPlayerInfo(src)
    if not info then return end
    local fields = baseFields(info)
    fields[#fields + 1] = field('Server ID', src)
    fields[#fields + 1] = field('Location', info.location, false)
    adminAlert(title, detail, fields)
end
