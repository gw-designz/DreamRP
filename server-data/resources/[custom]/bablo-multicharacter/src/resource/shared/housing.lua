-- Hot-reload safety: preserve an existing Housing table across resource restarts.
if not Housing then Housing = {} end

-- makeStub: returns a function that logs "[Housing] <methodName> is not implemented
-- for housing=<Config.Housing>" when called. Used as a placeholder until the
-- active housing bridge overwrites the method.
local function makeStub(methodName)
    return function(self, ...)
        Trace(("[Housing] %s is not implemented for housing=%s"):format(
            methodName, tostring(Config.Housing)))
    end
end

-- Stub methods — each is overwritten by the housing bridge that loads after this file.
Housing.GetOwned      = makeStub("GetOwned")
Housing.EnterInterior = makeStub("EnterInterior")
