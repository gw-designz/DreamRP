-- Fantasy Scripts protection loader.
-- Runs inside a protected resource (new builds ship their own copy as protected/loader.lua,
-- older builds use '@fantasy_license/loader.lua'). It decrypts protected/<side>.fsp with
-- this resource's unlock key and runs the original files in their original order — so the
-- script behaves exactly as if it had been installed unprotected.
--
-- Server: uses the key from fantasy_license when it opens this copy; otherwise asks the
-- license server itself (license/version read from this copy's own fxmanifest.lua on disk)
-- and keeps retrying until it gets in. It then shares the client key via GlobalState.
-- Client: waits for a GlobalState key that opens this copy.

local RES = GetCurrentResourceName()
local SERVER = IsDuplicityVersion()
local SIDE = SERVER and 'server' or 'client'
local PORTAL = 'https://fantasyscripts.com/account/licenses'
local STATE = ('fsl:%s'):format(RES)

local cryptoSrc = LoadResourceFile('fantasy_license', 'shared/crypto.lua')
if not cryptoSrc then
  print(('^1[fantasy_license] %s needs the fantasy_license resource. Download it from %s and start it before this resource.^0'):format(RES, PORTAL))
  return
end
local FSCrypto = load(cryptoSrc, '@fantasy_license/shared/crypto.lua', 't')()

local function say(color, msg)
  print(('%s[fantasy_license] %s: %s^0'):format(color, RES, msg))
end

local function sealedFile(side)
  local blob = LoadResourceFile(RES, ('protected/%s.fsp'):format(side))
  if not blob or blob:sub(1, 4) ~= 'FSP1' then return nil, blob ~= nil end
  return { nonce = blob:sub(5, 16), data = blob:sub(17) }
end

local sealed, damaged = sealedFile(SIDE)
if not sealed then
  if damaged then say('^1', ('protected/%s.fsp is damaged — download the resource again.'):format(SIDE)) end
  return -- nothing protected on this side
end

local function opens(file, key)
  if type(key) ~= 'string' or (#key ~= 64 and #key ~= 32) or #file.nonce ~= 12 then return nil end
  local ok, plain = pcall(FSCrypto.chacha20, key, file.nonce, file.data)
  return ok and plain:sub(1, 4) == 'FSOK' and plain or nil
end

local function execute(plain)
  local pos = 5
  while pos <= #plain do
    local name, code, kind
    name, code, kind, pos = string.unpack('<s4s4B', plain, pos)
    if kind == 1 then
      -- Editable file (config/locales): kept readable, run at its original position.
      code = LoadResourceFile(RES, name)
      if not code then return say('^1', ('missing %s'):format(name)) end
    end
    local fn, err = load(code, ('@%s/%s'):format(RES, name), 't')
    if not fn then
      say('^1', err)
    else
      -- Like FiveM: an error in one file is reported and the next files still load.
      local ok, runErr = xpcall(fn, debug.traceback)
      if not ok then print(('^1SCRIPT ERROR: %s^0'):format(tostring(runErr))) end
    end
  end
end

--- Runs this copy when `key` opens it; returns true on success.
local function try(key)
  local plain = opens(sealed, key)
  if not plain then return false end
  execute(plain)
  return true
end

local function runtimeKey()
  if SERVER then
    local ok, k = pcall(function() return exports.fantasy_license:getKey(RES, SIDE) end)
    return ok and k or nil
  end
  return GlobalState[STATE]
end

if try(runtimeKey()) then return end

if not SERVER then
  -- Client: the server side publishes the key; wait for one that opens this copy.
  CreateThread(function()
    local last, waited = nil, 0
    while true do
      local k = GlobalState[STATE]
      if k and k ~= last then
        if try(k) then return end
        last = k
      end
      local step = waited < 120000 and 500 or 5000
      Wait(step)
      waited = waited + step
    end
  end)
  return
end

-- Server: fantasy_license didn't have a key that opens this copy (first start, an update,
-- or it couldn't reach the license server yet). Ask the license server directly.
local API = GetConvar('fantasy_license_api', 'https://fantasyscripts.com/api/license/v1/unlock')

--- Value of a fantasy_* directive, from this copy's fxmanifest.lua on disk (FiveM's cached
--- metadata can still describe the previous version until `refresh` or a restart).
local function manifestValue(name)
  local manifest = LoadResourceFile(RES, 'fxmanifest.lua')
  local value = manifest and ('\n' .. manifest):match('\n%s*' .. name .. '%s*[\'"]([^\'"\n]+)[\'"]')
  return value or GetResourceMetadata(RES, name, 0)
end

local function askLicenseServer(done)
  -- Same normalisation as fantasy_license (stray spaces/quotes in server.cfg).
  local cfxKey = (GetConvar('fantasy_cfx_key', '') or ''):gsub('^[%s"\']+', ''):gsub('[%s"\']+$', '')
  if cfxKey == '' then
    return done(nil, ('fantasy_cfx_key is not set. Add  set fantasy_cfx_key "cfxk_..."  (your sv_licenseKey) to server.cfg and lock it at %s'):format(PORTAL))
  end
  local body = json.encode({
    cfx = FSCrypto.sha256(cfxKey),
    hostname = GetConvar('sv_hostname', ''),
    runtime = 'loader-2',
    reason = 'loader',
    resources = { {
      name = RES,
      product = manifestValue('fantasy_product'),
      license = manifestValue('fantasy_license'),
      version = manifestValue('fantasy_version'),
    } },
  })
  PerformHttpRequest(API, function(status, response)
    if status ~= 200 or not response then return done(nil, nil) end
    local ok, data = pcall(json.decode, response)
    if not ok or type(data) ~= 'table' then return done(nil, nil) end
    local k = type(data.keys) == 'table' and data.keys[RES] or nil
    if type(k) == 'table' then return done(k, nil) end
    done(nil, (type(data.denied) == 'table' and data.denied[RES]) or data.message or 'the license server did not unlock this resource.')
  end, 'POST', body, { ['Content-Type'] = 'application/json', ['User-Agent'] = 'fantasy_loader/2' })
end

CreateThread(function()
  local RETRY = { 0, 3, 6, 10, 20, 30 } -- seconds between attempts, then every 60s
  local last, waited, attempt, nextAt = nil, 0, 1, 0
  local pending, answer, reported = false, nil, nil
  local clientKey

  while true do
    -- 1) fantasy_license may get a fresh key on its own.
    local k = runtimeKey()
    if k and k ~= last then
      last = k
      if try(k) then break end
    end
    -- 2) Our own request came back.
    if answer then
      local got = answer
      answer = nil
      if got.keys and try(got.keys.server) then
        clientKey = got.keys.client
        break
      end
      local why = got.keys and ('this copy does not match your license. Download it again from ' .. PORTAL) or got.why
      if why and why ~= reported then
        reported = why
        say('^1', why)
      end
    end
    -- 3) Ask again (backing off) until it works — a network blip or a slow boot never leaves it locked.
    if not pending and waited >= nextAt then
      pending = true
      askLicenseServer(function(keys, why)
        pending = false
        if keys or why then answer = { keys = keys, why = why } end
      end)
      nextAt = waited + (RETRY[attempt + 1] or 60) * 1000
      attempt = attempt + 1
    end
    if waited == 60000 and not reported then
      say('^3', 'still waiting for the license server — check that this server can reach fantasyscripts.com.')
    end
    local step = waited < 120000 and 500 or 2000
    Wait(step)
    waited = waited + step
  end

  if reported or waited >= 60000 then say('^5', 'unlocked.') end
  if not clientKey then return end
  -- Players get the client key via GlobalState. Keep it right even if fantasy_license
  -- later publishes an outdated one.
  GlobalState[STATE] = clientKey
  while true do
    Wait(10000)
    if GlobalState[STATE] ~= clientKey then GlobalState[STATE] = clientKey end
  end
end)
