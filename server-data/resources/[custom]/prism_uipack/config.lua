
return {
    useConvars = false, -- if set to true, it will use the convars set through server.cfg instead of these settings # https://docs.prismscripts.net/prismui/config
    primaryColor = "#BEEE11",
    locale = "en", -- The language to use for the UI (check locales/ folder for available languages)
    debug = 0, -- 0 or 1. If 1, it adds additional prints in the console that will help with support with potential bugs
    notificationDuration = 3000, -- Duration (in ms) for which notifications are displayed (default duration, you can set a custom one through code)
    progressCancelKey = "X", -- Key to cancel progress bars
    notificationPosition = "top-center", -- Default notify position (default position, you can set a custom one through code)
    textUIPosition = "center-left", -- Default TextUI position (default position, you can set a custom one through code)
    progressBar = "primary", -- ProgressBar variant. primary or secondary
    radialOpenMode = "press", -- "press" or "hold" to open the radial menu. If "hold", it will stay open until key has been released
    radialOpenKey = "z",
    skillcheckVariant = "circle", -- "circle" or "rect" skillcheck style
    secondaryProgressMinimal = false, -- false or true. If you use the secondary progressBar, and want it to be more minimalistic, set this to true.
    contextMenuPosition = "right", -- "right" or "left". Context menu position
}
