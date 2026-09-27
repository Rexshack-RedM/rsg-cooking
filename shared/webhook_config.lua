WebhookConfig = {}

---------------------------------
-- webhook settings
---------------------------------
WebhookConfig.Enabled = true -- Set to true to enable webhooks
WebhookConfig.WebhookURL = '' -- Your Discord webhook URL
WebhookConfig.Username = 'RSG Cooking'

---------------------------------
-- webhook colors (decimal format)
---------------------------------
WebhookConfig.Colors = {
    Success = 65280,   -- Green
    Info = 3447003,    -- Blue
    Warning = 16776960, -- Yellow
    Error = 16711680,  -- Red
    XP = 9442302,      -- Purple
    Job = 15158332,    -- Orange
}

---------------------------------
-- webhook event toggles
---------------------------------
WebhookConfig.Events = {
    CookingStarted = true,      -- Log when player starts cooking
    CookingCompleted = true,    -- Log when player completes cooking
    CookingCancelled = true,    -- Log when player cancels cooking
    CookingFailed = true,       -- Log when cooking fails (missing ingredients)
    XPGained = true,            -- Log when player gains cooking XP
    XPMilestone = true,         -- Log when player reaches XP milestones (see XPMilestones)
    JobRestricted = true,       -- Log when player tries to cook job-restricted recipes
    LevelUpSimulated = false,   -- Log simulated level ups (every 50 XP = 1 level)
}

---------------------------------
-- detailed logging options
---------------------------------
WebhookConfig.DetailedInfo = {
    ShowIngredients = true,     -- Show ingredients used in cooking logs
    ShowCookingType = true,     -- Show cooking type (stove, campfire, etc.)
    ShowCookingTime = true,     -- Show how long the recipe takes
    ShowXPReward = true,        -- Show XP gained from recipe
    ShowPlayerJob = true,       -- Show player's current job
    ShowLocation = true,        -- Show approximate player location
    ShowTimestamp = true,       -- Show server timestamp
}

---------------------------------
-- webhook rate limiting
---------------------------------
WebhookConfig.RateLimit = {
    Enabled = true,             -- Enable rate limiting to prevent spam
    MaxPerMinute = 30,          -- Maximum webhooks per minute
}

---------------------------------
-- XP milestone tracking
---------------------------------
WebhookConfig.XPMilestones = {
    [50]   = 'Beginner Cook',
    [100]  = 'Amateur Cook',
    [250]  = 'Skilled Cook',
    [500]  = 'Expert Cook',
    [1000] = 'Master Cook',
    [2500] = 'Grand Master Cook',
}

---------------------------------
-- webhook footer
---------------------------------
WebhookConfig.Footer = {
    Text = 'RSG Cooking System',
    IconURL = '' -- Optional: URL to footer icon
}

---------------------------------
-- webhook thumbnail (optional)
---------------------------------
WebhookConfig.Thumbnail = {
    Enabled = false,
    DefaultURL = '', -- Default thumbnail for cooking events
}

---------------------------------
-- admin notifications
---------------------------------
WebhookConfig.AdminNotifications = {
    Enabled = false,            -- Enable admin-specific notifications
    WebhookURL = '',            -- Separate webhook for admin notifications
    NotifyOnSuspicious = true,  -- Notify on suspicious activity (e.g. finishing cooking faster than the cook time)
    NotifyOnHighXP = true,      -- Notify when player gains unusually high XP
    HighXPThreshold = 100,      -- XP threshold for notifications
}

---------------------------------
-- webhook templates
---------------------------------
WebhookConfig.Templates = {
    CookingStarted = {
        title = '🔥 Cooking Started',
        color = WebhookConfig.Colors.Info,
    },
    CookingCompleted = {
        title = '✅ Cooking Completed',
        color = WebhookConfig.Colors.Success,
    },
    CookingCancelled = {
        title = '❌ Cooking Cancelled',
        color = WebhookConfig.Colors.Warning,
    },
    CookingFailed = {
        title = '⛔ Cooking Failed',
        color = WebhookConfig.Colors.Error,
    },
    XPGained = {
        title = '⭐ XP Gained',
        color = WebhookConfig.Colors.XP,
    },
    XPMilestone = {
        title = '🎉 XP Milestone Reached',
        color = WebhookConfig.Colors.Success,
    },
    JobRestricted = {
        title = '🚫 Job Restriction',
        color = WebhookConfig.Colors.Warning,
    },
}
