
Interaction = Interaction or {}

CreateThread(function()
    if Config.Interaction == "ox_lib" then
        ---@class InteractionOptions
        ---@field position? '"right-center"' | '"left-center"' | '"top-center"' | '"bottom-center"' @ Default: "right-center"
        ---@field icon? string | table                                       @ Ikon som sträng eller array.
        ---@field iconColor? string                                          @ Färg på ikonen (t.ex. "#ffffff").
        ---@field iconAnimation? '"spin"' | '"spinPulse"' | '"spinReverse"' |
        ---                            '"pulse"' | '"beat"' | '"fade"' |
        ---                            '"beatFade"' | '"bounce"' | '"shake"' @ Animeringstyp på ikonen.
        ---@field style? table                                               @ CSS-liknande stildefinition.
        ---@field alignIcon? '"top"' | '"center"'                           @ Default: "center"

        ---@param text string
        ---@param options InteractionOptions
        function Interaction.ShowTextUI(text, options)
            lib.showTextUI(text, options)
        end

        function Interaction.HideTextUI()
            lib.hideTextUI()
        end

        function Interaction.IsOpen()
            return lib.isTextUIOpen()
        end
    else
        -- Standalone fallback using native GTA text display
        local isShowing = false
        local currentText = ""

        function Interaction.ShowTextUI(text, options)
            currentText = text
            if not isShowing then
                isShowing = true
                CreateThread(function()
                    while isShowing do
                        SetTextComponentFormat("STRING")
                        AddTextComponentSubstringPlayerName(currentText)
                        DisplayHelpTextFromStringLabel(0, false, true, -1)
                        Wait(0)
                    end
                end)
            end
        end

        function Interaction.HideTextUI()
            isShowing = false
            currentText = ""
        end

        function Interaction.IsOpen()
            return isShowing
        end
    end
end)
