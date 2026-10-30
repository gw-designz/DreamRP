-- Hot-reload safety: preserve an existing Framework table across resource restarts.
if not Framework then Framework = {} end

-- makeStub: returns a function that logs "[Framework] <methodName> is not implemented
-- for framework=<Config.Framework>" when called. Used as a placeholder until the
-- active framework's bridge file overwrites the method.
local function makeStub(methodName)
    return function(self, ...)
        Trace(("[Framework] %s is not implemented for framework=%s"):format(
            methodName, tostring(Config.Framework)))
    end
end

-- registeredCallbacks: guard table so lib.callback.register is never called
-- twice for the same event name (some framework bridges share callback names).
local registeredCallbacks = {}

-- RegisterCallback: register a lib.callback once, deduplicated by name.
function Framework:RegisterCallback(name, handler)
    if registeredCallbacks[name] then
        Trace(("[Framework] RegisterCallback skipped — '%s' already registered"):format(name))
        return
    end
    registeredCallbacks[name] = true
    lib.callback.register(name, handler)
end

-- Stub methods — each will be overwritten by the framework bridge that loads after
-- this file. If a bridge does not overwrite a method, calling it will log a warning
-- instead of raising an error.
Framework.FetchCharacters    = makeStub("FetchCharacters")
Framework.LoadCharacter      = makeStub("LoadCharacter")
Framework.CreateCharacter    = makeStub("CreateCharacter")
Framework.DeleteCharacter    = makeStub("DeleteCharacter")
Framework.GetPlaytime        = makeStub("GetPlaytime")
Framework.AddPlaytime        = makeStub("AddPlaytime")
Framework.GetCharacters      = makeStub("GetCharacters")
Framework.GetCharactersSync  = makeStub("GetCharactersSync")
Framework.NotifyPlayerLoaded = makeStub("NotifyPlayerLoaded")
Framework.IsAdmin            = makeStub("IsAdmin")
Framework.LogoutCharacter    = makeStub("LogoutCharacter")
