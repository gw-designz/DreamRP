-- Browser app: iframe navigation to explicit http(s) URLs only (no embedded search provider).
-- Use `UrlAllowSubstrings` / `UrlDenySubstrings` to restrict which hosts players may open.
-- Optional: sites you control can keep the in-game address bar in sync on SPA navigations by posting:
--   window.parent.postMessage({ source: 'yseries-browser', href: window.location.href }, '*')
-- (from the tab that is embedded in the phone browser).

Config = Config or {}

Config.Browser = Config.Browser or {}

--- Optional home / quick links merged into the app when local storage is empty.
--- URLs must be http(s). Titles and URLs are trusted server config, not player input.
---@type { title: string, url: string }[]
Config.Browser.DefaultBookmarks = {
    { title = 'Example', url = 'https://teamsgg.dev' },
}

--- If non-empty, a navigable https URL must contain at least one of these substrings (case-insensitive).
--- Leave empty to allow all hosts (still restricted to http/https).
--- Examples (fragments work anywhere in the URL): `"teamsgg.dev"`, `"wiki.my-city.rp"`.
---@type string[]
Config.Browser.UrlAllowSubstrings = {
    -- 'example.com',
}

--- Substrings that block navigation when matched in the URL (case-insensitive).
--- Examples: shorteners / risky paths — `"bit.ly"`, `"tinyurl.com"`, `"discord.com/api"` (tune to your policy).
---@type string[]
Config.Browser.UrlDenySubstrings = {
    -- 'bit.ly',
    -- 'discord.gg/',
}

--- When true, disclaimer copy from UI locales (`browser.disclaimerBody`) is shown once per device and remembered in localStorage.
---@type boolean
Config.Browser.ShowDisclaimerOnce = true
