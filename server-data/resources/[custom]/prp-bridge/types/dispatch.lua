---@meta

---@class AlertSound
---@field name? string sound file
---@field ref? string sound set
---@field alert? { sound: string } ogg sound file

---@class AlertData
---@field code? string
---@field icon? string
---@field title? string
---@field description string
---@field length? number
---@field sound? AlertSound

---@class AlertBlip
---@field sprite number
---@field scale number
---@field colour number
---@field text? string
---@field length? number How long it stays on the map in minutes.
---@field flash? boolean