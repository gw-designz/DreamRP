---@meta

---@class OwnedVehicle : VehicleData
---@field id? string | number
---@field owner? string | number
---@field plate string

---@class FWContextMenuItem
---@field title? string
---@field menu? string
---@field icon? string | {[1]: IconProp, [2]: string};
---@field iconColor? string
---@field image? string
---@field progress? number
---@field onSelect? fun(args: any)
---@field arrow? boolean
---@field description? string
---@field metadata? string | { [string]: any } | string[]
---@field disabled? boolean
---@field readOnly? boolean
---@field event? string
---@field serverEvent? string
---@field args? any

---@class FWContextMenuArrayItem : FWContextMenuItem
---@field title string

---@class FWContextMenuProps
---@field id string
---@field title string
---@field menu? string
---@field onExit? fun()
---@field onBack? fun()
---@field canClose? boolean
---@field options { [string]: FWContextMenuItem } | FWContextMenuArrayItem[]

---@class FWProgressBarDisablers
---@field disableMovement? boolean
---@field disableCarMovement? boolean
---@field disableMouse? boolean
---@field disableCombat? boolean
---@field disableSprint? boolean

---@class FWProgressBarAnimation
---@field animDict? string
---@field animClip? string
---@field animFlag? number
---@field scenario? string

---@class FWProgressBar
---@field duration number
---@field label string
---@field useWhileDead? boolean
---@field allowRagdoll? boolean
---@field allowSwimming? boolean
---@field allowCuffed? boolean
---@field allowFalling? boolean
---@field canCancel? boolean
---@field controlDisables? FWProgressBarDisablers
---@field animation? FWProgressBarAnimation