-- Fantasy Scripts license runtime (server).
--
-- server.cfg:
--   set fantasy_cfx_key "cfxk_..."   # the same key as sv_licenseKey (resources can't read sv_licenseKey)
--   ensure fantasy_license           # before your Fantasy Scripts resources
--
-- Only a SHA-256 of the Cfx.re key ever leaves this server.
--
-- Built to never get in the way of a running server: nothing here can throw (every step
-- is guarded), a damaged cache is ignored, failed checks retry with backoff, and a denial
-- never stops a resource that is already running — it only won't unlock on its next start.

local VERSION = '1.3.0'
local RES_NAME = GetCurrentResourceName()
local API = GetConvar('fantasy_license_api', 'https://fantasyscripts.com/api/license/v1/unlock')
local PORTAL = 'https://fantasyscripts.com/account/licenses'
local CHECK_EVERY = 10 * 60 -- seconds between regular checks
local RETRY = { 5, 10, 20, 30, 60 } -- seconds between retries after a failed check, then every 60s
local OFFLINE_GRACE = 7 * 24 * 3600 -- keep working this long if the license server can't be reached
local CACHE_FILE = 'cache.dat'

local function log(msg, ...) print(('^5[fantasy_license]^0 ' .. msg):format(...)) end
local function warn(msg, ...) print(('^1[fantasy_license] ' .. msg .. '^0'):format(...)) end

local FSCrypto = load(LoadResourceFile(RES_NAME, 'shared/crypto.lua'), '@fantasy_license/shared/crypto.lua', 't')()

local function guarded(what, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then warn('%s failed: %s', what, tostring(err)) end
  return ok, err
end

-- Tolerate stray spaces/quotes around the key in server.cfg.
local cfxKey = (GetConvar('fantasy_cfx_key', '') or ''):gsub('^[%s"\']+', ''):gsub('[%s"\']+$', '')
local cfxHash = cfxKey ~= '' and FSCrypto.sha256(cfxKey) or nil
local keys = {} -- [resource] = { server = hex, client = hex, v = fantasy_version it was issued for }
local lastOk = 0

local function publish(res)
  local k = keys[res]
  GlobalState[('fsl:%s'):format(res)] = k and k.client or nil
end

-- Cache: unlock keys from the last successful check, encrypted with the Cfx.re key, so
-- protected resources start instantly after a restart. Stored as hex text: FiveM's
-- SaveResourceFile cuts binary data at the first zero byte.
local function cacheKey() return FSCrypto.sha256(cfxKey .. '|fsl-cache') end

local function saveCache()
  if not cfxHash then return end
  local nonce = {}
  for i = 1, 12 do nonce[i] = string.char(math.random(0, 255)) end
  nonce = table.concat(nonce)
  local data = 'FSC2' .. FSCrypto.toHex(nonce) .. FSCrypto.toHex(FSCrypto.chacha20(cacheKey(), nonce, json.encode({ keys = keys, at = lastOk })))
  SaveResourceFile(RES_NAME, CACHE_FILE, data, #data)
end

local function loadCache()
  if not cfxHash then return end
  local blob = LoadResourceFile(RES_NAME, CACHE_FILE)
  -- Anything else (missing, older format, damaged) is ignored; the first check rewrites it.
  if not blob or blob:sub(1, 4) ~= 'FSC2' or #blob < 4 + 24 + 2 or #blob % 2 ~= 0 or blob:find('[^%x]', 5) then return end
  local nonce = FSCrypto.hexToBytes(blob:sub(5, 28))
  local ok, data = pcall(json.decode, FSCrypto.chacha20(cacheKey(), nonce, FSCrypto.hexToBytes(blob:sub(29))))
  if not ok or type(data) ~= 'table' or type(data.keys) ~= 'table' then return end
  if os.time() - (tonumber(data.at) or 0) > OFFLINE_GRACE then return end
  for res, k in pairs(data.keys) do
    if type(res) == 'string' and type(k) == 'table' and type(k.server) == 'string' and type(k.client) == 'string' then keys[res] = k end
  end
  lastOk = tonumber(data.at) or 0
end

--- A fantasy_* value of a resource, read from its fxmanifest.lua on disk: FiveM's cached
--- metadata can still describe the previous version after a resource folder was replaced.
local function manifestValue(res, name)
  local manifest = LoadResourceFile(res, 'fxmanifest.lua')
  local value = manifest and ('\n' .. manifest):match('\n%s*' .. name .. '%s*[\'"]([^\'"\n]+)[\'"]')
  return value or GetResourceMetadata(res, name, 0)
end

local function protectedResources()
  local list = {}
  for i = 0, GetNumResources() - 1 do
    local res = GetResourceByFindIndex(i)
    if res and GetResourceMetadata(res, 'fantasy_protected', 0) == 'yes' then
      local license, version = manifestValue(res, 'fantasy_license'), manifestValue(res, 'fantasy_version')
      if license and version then
        list[#list + 1] = { name = res, product = manifestValue(res, 'fantasy_product'), license = license, version = version }
      end
    end
  end
  return list
end

local checking, checkStarted, failures, nextCheck, checks = false, 0, 0, 0, 0
local reported = {}

local function handle(resources, status, body)
  if status ~= 200 or not body then
    failures = failures + 1
    nextCheck = os.time() + (RETRY[failures] or 60)
    if os.time() - lastOk > OFFLINE_GRACE then
      warn('license server unreachable (HTTP %s) and no recent check — retrying.', tostring(status))
    elseif failures == 1 then
      log('license server unreachable (HTTP %s) — using the last successful check, retrying.', tostring(status))
    end
    return
  end
  local ok, data = pcall(json.decode, body)
  if not ok or type(data) ~= 'table' then
    failures = failures + 1
    nextCheck = os.time() + (RETRY[failures] or 60)
    return
  end
  failures = 0
  nextCheck = os.time() + CHECK_EVERY
  if data.message and reported.message ~= data.message then
    reported.message = data.message
    warn('%s', data.message)
  end
  local sent = {}
  for _, r in ipairs(resources) do sent[r.name] = r.version end
  for res, k in pairs(type(data.keys) == 'table' and data.keys or {}) do
    if type(k) == 'table' and type(k.server) == 'string' and type(k.client) == 'string' then
      keys[res] = { server = k.server, client = k.client, v = sent[res] }
      reported[res] = nil
      publish(res)
    end
  end
  for res, why in pairs(type(data.denied) == 'table' and data.denied or {}) do
    if reported[res] ~= why then
      reported[res] = why
      warn('%s: %s', res, tostring(why))
    end
    -- A running resource keeps running; it just won't unlock on its next start.
    if GetResourceState(res) ~= 'started' then
      keys[res] = nil
      publish(res)
    end
  end
  lastOk = os.time()
  guarded('saving the key cache', saveCache)
end

local function check(reason)
  if checking then return end
  if not cfxHash then
    if not reported.cfx then
      reported.cfx = true
      warn('fantasy_cfx_key is not set. Add  set fantasy_cfx_key "cfxk_..."  (your sv_licenseKey) to server.cfg and lock it at %s', PORTAL)
    end
    return
  end
  local resources = protectedResources()
  if #resources == 0 then
    nextCheck = os.time() + CHECK_EVERY
    return
  end
  checking, checkStarted = true, os.time()
  local payload = json.encode({ cfx = cfxHash, hostname = GetConvar('sv_hostname', ''), runtime = VERSION, reason = reason, resources = resources })
  local started = checkStarted
  PerformHttpRequest(API, function(status, body)
    if checkStarted == started then checking = false end
    guarded('license check', handle, resources, status, body)
  end, 'POST', payload, { ['Content-Type'] = 'application/json', ['User-Agent'] = 'fantasy_license/' .. VERSION })
end

--- Unlock key for a protected resource — only the resource itself may ask for its own key.
exports('getKey', function(res, side)
  if GetInvokingResource() ~= res then return nil end
  local k = keys[res]
  return k and k[side] or nil
end)

--- Called by a protected resource whose key doesn't open its files (e.g. right after an update).
exports('refresh', function(res)
  if GetInvokingResource() ~= res then return end
  nextCheck = math.min(nextCheck, os.time())
end)

-- A newly started or updated protected resource (e.g. after `ensure`) gets checked right away.
AddEventHandler('onResourceStarting', function(res)
  if GetResourceMetadata(res, 'fantasy_protected', 0) ~= 'yes' then return end
  local k = keys[res]
  if not k or k.v ~= manifestValue(res, 'fantasy_version') then nextCheck = math.min(nextCheck, os.time()) end
end)

math.randomseed(os.time())
guarded('reading the key cache', loadCache)
for res in pairs(keys) do publish(res) end

CreateThread(function()
  while true do
    -- A request that never answers must not block later checks.
    if checking and os.time() - checkStarted > 60 then checking = false end
    if not checking and os.time() >= nextCheck then
      checks = checks + 1
      nextCheck = os.time() + CHECK_EVERY -- replaced by the result (or retry) once the check returns
      guarded('license check', check, checks == 1 and 'start' or 'heartbeat')
    end
    Wait(1000)
  end
end)

log('v%s ready — %s', VERSION, cfxHash and 'Cfx.re key set' or 'fantasy_cfx_key missing')
