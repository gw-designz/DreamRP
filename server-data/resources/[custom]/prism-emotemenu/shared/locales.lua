Locales = {}

function Translate(str, ...)
    if not str then
        print(("[^1ERROR^7] Resource ^5%s^7 You did not specify a parameter for the Translate function or the value is nil!"):format(GetInvokingResource() or GetCurrentResourceName()))
        return "Unknown"
    end
    if Locales[Config.Lang] then
        if Locales[Config.Lang][str] then
            return string.format(Locales[Config.Lang][str], ...)
        elseif Config.MenuLanguage ~= "en" and Locales["en"] and Locales["en"][str] then
            return string.format(Locales["en"][str], ...)
        else
            return "Translation [" .. Config.Lang .. "][" .. str .. "] does not exist"
        end
    elseif Config.Lang ~= "en" and Locales["en"] and Locales["en"][str] then
        return string.format(Locales["en"][str], ...)
    else
        return "Locale [" .. Config.Lang .. "] does not exist"
    end
end

function TranslateCap(str, ...)
    return _(str, ...):gsub("^%l", string.upper)
end

_ = Translate
_U = TranslateCap