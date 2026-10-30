local isServer      = IsDuplicityVersion()
local tableUnpack   = table.unpack
local getInfo       = debug.getinfo
local msgpackPack   = msgpack.pack
local msgpackUnpack = msgpack.unpack
local msgpackPackArgs = msgpack.pack_args

-- Promise state constants (FiveM promise internals)
local PROMISE_PENDING   = 0
local PROMISE_RESOLVED  = 1  -- ⚠️ value 1 not directly referenced but kept for clarity
local PROMISE_REJECTED  = 2
local PROMISE_CANCELLED = 4

-- Event name prefixes
local PREFIX_SERVER_CB          = "bablo_pettycrimes_callbacks__server_callback:"
local PREFIX_CLIENT_CB          = "bablo_pettycrimes_callbacks__client_callback:"
local PREFIX_CLIENT_CB_RESPONSE = "bablo_pettycrimes_callbacks__client_callback_response:%s:%s"
local PREFIX_CB_RETVAL          = "bablo_pettycrimes_callbacks__callback_retval:%s:%s:%s"

-- ─────────────────────────────────────────────────────────────────────────────
-- Internal helpers
-- ─────────────────────────────────────────────────────────────────────────────

-- Unpacks a msgpack-encoded binary blob into normal Lua values
local function unpackArgs(packed)
    return tableUnpack(msgpackUnpack(packed))
end

-- Type-check helper used by all public API functions.
-- Raises an error (at the caller's level) when `value` is not `expectedType` or `altType`.
local function assertType(value, expectedType, altType, customMsg)
    local actualType    = type(value)
    local callerInfo    = getInfo(2)
    local msg           = customMsg

    if not customMsg then
        if altType == nil then
            msg = callerInfo.name .. " expected %s, but got %s"
        else
            msg = callerInfo.name .. " expected %s or %s, but got %s"
        end
    end

    if expectedType == "function" then
        -- A CFX function reference is a table with __cfx_functionReference
        if actualType == "table" then
            if not rawget(value, "__cfx_functionReference") then
                error(msg:format(expectedType, altType, actualType))
            end
            return
        end
    end

    if actualType ~= expectedType and actualType ~= altType then
        error(msg:format(expectedType, altType, actualType))
    end
end

-- Resolves a promise with unpacked msgpack data and optionally fires a callback
local function resolveWithUnpack(prom, userCallback, packedData)
    if userCallback and prom.state == PROMISE_PENDING then
        userCallback(unpackArgs(packedData))
    end
    prom.resolve(prom, tableUnpack(msgpackUnpack(packedData)))
end

-- Sets up an optional timeout that calls `timedoutFn` and rejects `prom` if it
-- is still pending/rejected/cancelled when the timer fires.
local function setupTimeout(prom, timeoutSeconds, timedoutFn, eventHandler)
    if timeoutSeconds == nil or not timedoutFn then return end

    SetTimeout(timeoutSeconds * 1000, function()
        local state = prom.state
        if state ~= PROMISE_PENDING and state ~= PROMISE_CANCELLED and state ~= PROMISE_REJECTED then
            return
        end
        timedoutFn(prom.state)
        if prom.state == PROMISE_PENDING then
            prom.reject(prom)
        end
        if eventHandler then
            RemoveEventHandler(eventHandler)
        end
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- SERVER-SIDE
-- ─────────────────────────────────────────────────────────────────────────────

if isServer then

    -- Registers a named server-side callback that clients can invoke.
    -- opts = { eventName: string, eventCallback: function }
    function RegisterServerCallback(opts)
        assertType(opts,                "table")
        assertType(opts.eventName,      "string")
        assertType(opts.eventCallback,  "function")

        local userCallback  = opts.eventCallback
        local eventName     = opts.eventName
        local netEvent      = PREFIX_SERVER_CB .. eventName

        local handler = RegisterNetEvent(netEvent, function(packedArgs, requestId, rawCommand)
            local sourceId = tonumber(source)

            if not sourceId then
                -- ⚠️ sourceId is nil/non-numeric — this branch handles a local/server-internal trigger
                -- (rawCommand is used as a reply-callback fn here, which is unusual)
                rawCommand(msgpackPackArgs(userCallback(requestId, unpackArgs(packedArgs))))
            else
                -- Reply to the specific client that triggered this callback
                local responseEvent = ("bablo_pettycrimes_callbacks__client_callback_response:%s:%s"):format(eventName, sourceId)
                TriggerClientEvent(
                    responseEvent,
                    sourceId,
                    msgpackPackArgs(userCallback(sourceId, unpackArgs(packedArgs)))
                )
            end
        end)

        return handler
    end

    _G.RegisterServerCallback = RegisterServerCallback
    exports("RegisterServerCallback", RegisterServerCallback)

    function UnregisterServerCallback(handler)
        RemoveEventHandler(handler)
    end

    _G.UnregisterServerCallback = UnregisterServerCallback
    exports("UnregisterServerCallback", UnregisterServerCallback)

    -- Triggers a client-side callback from the server and awaits (or callbacks) the result.
    -- opts = { source, eventName, args?, timeout?, timedout?, callback? }
    function TriggerClientCallback(opts)
        assertType(opts,            "table")
        assertType(opts.source,     "string", "number")
        assertType(opts.eventName,  "string")
        assertType(opts.args,       "table",  "nil")
        assertType(opts.timeout,    "number", "nil")
        assertType(opts.timedout,   "function", "nil")
        assertType(opts.callback,   "function", "nil")

        local sourceId = tonumber(opts.source)
        if sourceId < 0 then
            error("source should be equal to or higher than 0")
        end

        local requestId     = tostring(opts.source) .. "x" .. tostring(GetGameTimer())
        local prom          = promise.new()
        local userCallback  = opts.callback
        local responseEvent = ("bablo_pettycrimes_callbacks__callback_retval:%s:%s:%s"):format(opts.source, opts.eventName, requestId)

        local handler = RegisterNetEvent(responseEvent, function(packedData)
            resolveWithUnpack(prom, userCallback, packedData)
        end)

        TriggerClientEvent(
            ("bablo_pettycrimes_callbacks__client_callback:%s"):format(opts.eventName),
            opts.source,
            msgpackPack(opts.args or {}),
            requestId
        )

        setupTimeout(prom, opts.timeout, opts.timedout, handler)

        if not userCallback then
            local result = Citizen.Await(prom)
            RemoveEventHandler(handler)
            return result
        end
    end

    _G.TriggerClientCallback = TriggerClientCallback
    exports("TriggerClientCallback", TriggerClientCallback)

    -- Triggers a server-side callback locally (server calling its own callback).
    -- opts = { source, eventName, args?, timeout?, timedout?, callback? }
    function TriggerServerCallback(opts)
        assertType(opts,            "table")
        assertType(opts.source,     "string", "number")
        assertType(opts.eventName,  "string")
        assertType(opts.args,       "table",  "nil")
        assertType(opts.timeout,    "number", "nil")
        assertType(opts.timedout,   "function", "nil")
        assertType(opts.callback,   "function", "nil")

        local prom          = promise.new()
        local userCallback  = opts.callback
        local sourceVal     = opts.source

        TriggerEvent(
            PREFIX_SERVER_CB .. opts.eventName,
            msgpackPack(opts.args or {}),
            sourceVal,
            function(packedData)
                resolveWithUnpack(prom, userCallback, packedData)
            end
        )

        setupTimeout(prom, opts.timeout, opts.timedout, nil)

        if not userCallback then
            return Citizen.Await(prom)
        end
    end

    _G.TriggerServerCallback = TriggerServerCallback
    exports("TriggerServerCallback", TriggerServerCallback)

end

-- ─────────────────────────────────────────────────────────────────────────────
-- CLIENT-SIDE
-- ─────────────────────────────────────────────────────────────────────────────

if not isServer then

    -- ⚠️ GetPlayerServerId(PlayerId()) is called at load time and stored as the
    -- local player's server-side source ID. Used when firing server-targeted retval events.
    local localServerId = GetPlayerServerId(PlayerId())

    -- Registers a named client-side callback that the server can invoke.
    -- opts = { eventName: string, eventCallback: function }
    function RegisterClientCallback(opts)
        assertType(opts,                "table")
        assertType(opts.eventName,      "string")
        assertType(opts.eventCallback,  "function")

        local userCallback  = opts.eventCallback
        local eventName     = opts.eventName
        local netEvent      = PREFIX_CLIENT_CB .. eventName

        local handler = RegisterNetEvent(netEvent, function(packedArgs, requestId)
            local replyType = type(requestId)

            if replyType == "function" then
                -- Local trigger: requestId is actually a reply callback function
                requestId(msgpackPackArgs(userCallback(localServerId, unpackArgs(packedArgs))))
            else
                -- Server trigger: reply via TriggerServerEvent retval event
                local retvalEvent = (PREFIX_CB_RETVAL):format(localServerId, eventName, requestId)
                TriggerServerEvent(
                    retvalEvent,
                    msgpackPackArgs(userCallback(localServerId, unpackArgs(packedArgs)))
                )
            end
        end)

        return handler
    end

    _G.RegisterClientCallback = RegisterClientCallback
    exports("RegisterClientCallback", RegisterClientCallback)

    function UnregisterClientCallback(handler)
        RemoveEventHandler(handler)
    end

    _G.UnregisterClientCallback = UnregisterClientCallback
    exports("UnregisterClientCallback", UnregisterClientCallback)

    -- Triggers a server-side callback from the client and awaits (or callbacks) the result.
    -- opts = { eventName, args?, timeout?, timedout?, callback? }
    function TriggerServerCallback(opts)
        assertType(opts,            "table")
        assertType(opts.eventName,  "string")
        assertType(opts.args,       "table",  "nil")
        assertType(opts.timeout,    "number", "nil")
        assertType(opts.timedout,   "function", "nil")
        assertType(opts.callback,   "function", "nil")

        local prom          = promise.new()
        local userCallback  = opts.callback
        local responseEvent = (PREFIX_CLIENT_CB_RESPONSE):format(opts.eventName, localServerId)

        local handler = RegisterNetEvent(responseEvent, function(packedData)
            resolveWithUnpack(prom, userCallback, packedData)
        end)

        TriggerServerEvent(
            PREFIX_SERVER_CB .. opts.eventName,
            msgpackPack(opts.args or {})
        )

        setupTimeout(prom, opts.timeout, opts.timedout, handler)

        if not userCallback then
            local result = Citizen.Await(prom)
            RemoveEventHandler(handler)
            return result
        end
    end

    _G.TriggerServerCallback = TriggerServerCallback
    exports("TriggerServerCallback", TriggerServerCallback)

    -- Triggers a client-side callback locally (client calling its own callback).
    -- opts = { eventName, args?, timeout?, timedout?, callback? }
    function TriggerClientCallback(opts)
        assertType(opts,            "table")
        assertType(opts.eventName,  "string")
        assertType(opts.args,       "table",  "nil")
        assertType(opts.timeout,    "number", "nil")
        assertType(opts.timedout,   "function", "nil")
        assertType(opts.callback,   "function", "nil")

        local prom          = promise.new()
        local userCallback  = opts.callback

        TriggerEvent(
            PREFIX_CLIENT_CB .. opts.eventName,
            msgpackPack(opts.args or {}),
            function(packedData)
                resolveWithUnpack(prom, userCallback, packedData)
            end
        )

        setupTimeout(prom, opts.timeout, opts.timedout, nil)

        if not userCallback then
            return Citizen.Await(prom)
        end
    end

    _G.TriggerClientCallback = TriggerClientCallback
    exports("TriggerClientCallback", TriggerClientCallback)

end
