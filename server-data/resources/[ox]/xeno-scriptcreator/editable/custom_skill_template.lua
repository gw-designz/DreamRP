-- ==============================================================================
-- 🌟 Xeno Script Creator - Custom Skill Integration Template
-- ==============================================================================
-- This file is a ready-to-use template that demonstrates how you can create and
-- integrate custom skills into your own resources, or write custom logic
-- for the server and client sides.
-- ==============================================================================

local IS_SERVER = IsDuplicityVersion()

if IS_SERVER then
    -- ==========================================================
    -- 💻 SERVER-SIDE LOGIC
    -- ==========================================================

    -- 1. Example: Listening for an event (Custom Action -> Server Event)
    -- When a player unlocks a skill, you can configure the UI (Effect Builder -> Custom Action) 
    -- to trigger the event 'myResource:onSkillUnlocked'
    RegisterNetEvent('myResource:onSkillUnlocked', function(data)
        local src = source
        -- 'data' usually contains { skillId = "name_of_the_skill", level = 1 }
        local skillId = data.skillId or "unknown_skill"
        local newLevel = data.level or 1

        print(('[Server] Player %s just unlocked the skill %s (Level: %s)'):format(src, skillId, newLevel))

        -- Here you can give items, money, or save something to your database
        if skillId == "my_custom_skill" then
            -- Example: Giving an item (QBCore / ESX)
            -- local Player = QBCore.Functions.GetPlayer(src)
            -- Player.Functions.AddItem('weapon_pistol', 1)
        end
    end)

    -- 2. Example: Checking if a player has a specific skill (Export)
    -- You can use this export in ANY of your resources!
    RegisterCommand('checkmyskill', function(source, args)
        local skillId = args[1] or "my_custom_skill"
        
        -- Export: HasSkill(playerId, skillId, minLevel)
        local hasSkill = exports['xeno-scriptcreator']:HasSkill(source, skillId, 1)

        if hasSkill then
            print("You HAVE this skill!")
        else
            print("You DO NOT have this skill!")
        end
    end, false)

    -- 3. Example: Giving XP for skills
    -- You can reward players with XP when they do something useful!
    RegisterCommand('givemxp', function(source, args)
        local amount = tonumber(args[1]) or 100
        
        -- Export: AddSkillXP(playerId, amount)
        local success = exports['xeno-scriptcreator']:AddSkillXP(source, amount)

        if success then
            print("Successfully gave " .. amount .. " XP to the player!")
        end
    end, true) -- 'true' means only admins can use the command

else
    -- ==========================================================
    -- 🎮 CLIENT-SIDE LOGIC
    -- ==========================================================

    -- 1. Example: Listening for a client event (Custom Action -> Client Event)
    -- In the UI, set the Client Event to: 'myResource:clientSkillEffect'
    RegisterNetEvent('myResource:clientSkillEffect', function(data)
        local skillId = data.skillId or "unknown_skill"
        local newLevel = data.level or 1

        print(('[Client] Unlocked skill: %s at level %s'):format(skillId, newLevel))

        -- Here you can play an animation, sound, particles (ptfx), or show a custom UI
        if skillId == "ninja_jump" then
            -- Example: Showing a chat notification
            TriggerEvent('chat:addMessage', {
                color = { 0, 255, 0},
                multiline = true,
                args = {"System", "You unlocked Ninja Jump!"}
            })
        end
    end)

    -- 2. Example: Getting the skill level from the client
    -- This can be used to unlock client-side features (e.g., faster mining)
    CreateThread(function()
        while true do
            Wait(0)
            
            -- Check if the player pressed a button (e.g., E)
            if IsControlJustPressed(0, 38) then
                -- Client export (synchronized with the player's data automatically)
                local skillLevel = exports['xeno-scriptcreator']:GetSkillLevel("master_miner")
                
                if skillLevel > 0 then
                    -- Make mining 2 times faster
                    -- print("Mining fast!")
                else
                    -- Normal mining speed
                    -- print("Mining normally...")
                end
            end
        end
    end)
    
    -- 3. Example: Opening the Skill Tree via code
    RegisterCommand('openskills', function()
        -- Export: OpenSkillTree(treeId)
        exports['xeno-scriptcreator']:OpenSkillTree('default_skill_tree')
    end, false)

    -- 4. Example: Using Custom Abilities from the UI
    -- If you selected "✨ Add Custom Ability (Type Key)" in the UI
    -- and entered a custom ability key (e.g. "fishing_speed_boost"), 
    -- you can simply check if the player has unlocked the specific skill
    -- node that provides this ability.
    CreateThread(function()
        while true do
            Wait(1000)
            -- For example, if your skill node ID is "fishing_mastery"
            local level = exports['xeno-scriptcreator']:GetSkillLevel("fishing_mastery")
            if level > 0 then
                -- Apply your custom "fishing_speed_boost" logic here
            end
        end
    end)

end
