-- SERVER ONLY - never move this into shared/, webhook urls would be sent to every client
SvConfig = {}

---------------------------------
-- discord webhooks
---------------------------------
SvConfig.Webhooks = {
    enabled      = true,
    username     = 'Cooking Logs',
    avatar       = '',                -- optional avatar image url
    footer       = 'rsg-cooking',
    mirrorRsgLog = false,             -- also send each log to rsg-log (TriggerEvent 'rsg-log:server:CreateLog')

    -- fallback url used by any event whose own url is empty
    default = '',

    -- per event: enabled, own url (blank = default), embed colour (decimal)
    events = {
        campfire   = { enabled = true,  url = '', color = 5763719  },  -- green  (campfire placed / put out)
        collect    = { enabled = true,  url = '', color = 15844367 },  -- gold
        recipe     = { enabled = false, url = '', color = 10181046 },  -- purple
        load       = { enabled = false, url = '', color = 9807270  },  -- grey (noisy)
        fuel       = { enabled = false, url = '', color = 15105570 },  -- orange (noisy)
        unload     = { enabled = false, url = '', color = 9807270  },
        levelup    = { enabled = true,  url = '', color = 16776960 },  -- yellow
        suspicious = { enabled = true,  url = '', color = 10038562 },  -- dark red (failed server checks)
    },
}
