-- Hot-reload safety: preserve an existing Appearance table across resource restarts.
if not Appearance then Appearance = {} end

-- makeStub: returns a function that logs "[Appearance] <methodName> is not implemented
-- for appearance=<Config.Appearance>" when called. Used as a placeholder until the
-- active appearance bridge overwrites the method.
local function makeStub(methodName)
    return function(self, ...)
        Trace(("[Appearance] %s is not implemented for appearance=%s"):format(
            methodName, tostring(Config.Appearance)))
    end
end

-- Stub methods — each is overwritten by the appearance bridge that loads after this file.
Appearance.FetchSkin  = makeStub("FetchSkin")
Appearance.Apply      = makeStub("Apply")
Appearance.GetCurrent = makeStub("GetCurrent")
Appearance.OpenEditor = makeStub("OpenEditor")
