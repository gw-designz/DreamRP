
local L0_1, L1_1, L2_1, L3_1, L4_1, L5_1, L6_1, L7_1, L8_1, L9_1, L10_1, L11_1, L12_1
L0_1 = {}
Debug = L0_1
L0_1 = Debug
L1_1 = Debug
L0_1.__index = L1_1
L0_1 = true
L1_1 = nil
L2_1 = {}
L3_1 = IsDuplicityVersion
L3_1 = L3_1()
if L3_1 then
  L3_1 = "SERVER"
  if L3_1 then
    goto lbl_20
  end
end
L3_1 = "CLIENT"
::lbl_20::
L4_1 = {}
L4_1.reset = "^7"
L4_1.red = "^1"
L4_1.green = "^2"
L4_1.yellow = "^3"
L4_1.blue = "^4"
L4_1.purple = "^5"
L4_1.cyan = "^6"
L4_1.gray = "^8"
L4_1.white = "^7"
function L5_1()
  local L0_2, L1_2
  L0_2 = L3_1
  if "CLIENT" == L0_2 then
    L0_2 = "NOW"
    if L0_2 then
      goto lbl_11
    end
  end
  L0_2 = os
  L0_2 = L0_2.date
  L1_2 = "%H:%M:%S"
  L0_2 = L0_2(L1_2)
  ::lbl_11::
  return L0_2
end
function L6_1(A0_2, A1_2, A2_2)
  local L3_2, L4_2, L5_2, L6_2, L7_2, L8_2
  L3_2 = string
  L3_2 = L3_2.format
  L4_2 = "%s[%s][%s][%s]"
  L5_2 = A1_2
  L6_2 = L5_1
  L6_2 = L6_2()
  L7_2 = L3_1
  L8_2 = A0_2
  L3_2 = L3_2(L4_2, L5_2, L6_2, L7_2, L8_2)
  L4_2 = L1_1
  if L4_2 then
    L4_2 = L3_2
    L5_2 = string
    L5_2 = L5_2.format
    L6_2 = " [%s]"
    L7_2 = L1_1
    L5_2 = L5_2(L6_2, L7_2)
    L4_2 = L4_2 .. L5_2
    L3_2 = L4_2
  end
  if A2_2 then
    L4_2 = L3_2
    L5_2 = string
    L5_2 = L5_2.format
    L6_2 = " (%s)"
    L7_2 = A2_2
    L5_2 = L5_2(L6_2, L7_2)
    L4_2 = L4_2 .. L5_2
    L3_2 = L4_2
  end
  return L3_2
end
function L7_1(A0_2)
  local L1_2
  if not A0_2 then
    L1_2 = true
    return L1_2
  end
  L1_2 = L2_1
  L1_2 = L1_2[A0_2]
  L1_2 = true == L1_2
  return L1_2
end
function L8_1(...)
  local L0_2, L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2
  L0_2 = {}
  L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2 = ...
  L0_2[1] = L1_2
  L0_2[2] = L2_2
  L0_2[3] = L3_2
  L0_2[4] = L4_2
  L0_2[5] = L5_2
  L0_2[6] = L6_2
  L0_2[7] = L7_2
  L0_2[8] = L8_2
  L1_2 = 1
  L2_2 = #L0_2
  L3_2 = 1
  for L4_2 = L1_2, L2_2, L3_2 do
    L5_2 = L0_2[L4_2]
    L6_2 = type
    L7_2 = L5_2
    L6_2 = L6_2(L7_2)
    if "table" == L6_2 then
      L6_2 = pcall
      L7_2 = json
      L7_2 = L7_2.encode
      L8_2 = L5_2
      L6_2, L7_2 = L6_2(L7_2, L8_2)
      L8_2 = L7_2 or L8_2
      if not L6_2 or not L7_2 then
        L8_2 = "<table>"
      end
      L0_2[L4_2] = L8_2
    else
      L6_2 = tostring
      L7_2 = L5_2
      L6_2 = L6_2(L7_2)
      L0_2[L4_2] = L6_2
    end
  end
  L1_2 = table
  L1_2 = L1_2.concat
  L2_2 = L0_2
  L3_2 = " "
  return L1_2(L2_2, L3_2)
end
function L9_1(A0_2, A1_2, A2_2, ...)
  local L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2
  L3_2 = Config
  L3_2 = L3_2.DEBUG
  if not L3_2 then
    return
  end
  if A2_2 then
    L3_2 = L7_1
    L4_2 = A2_2
    L3_2 = L3_2(L4_2)
    if not L3_2 then
      return
    end
  end
  L3_2 = L6_1
  L4_2 = A0_2
  L5_2 = A1_2
  L6_2 = A2_2
  L3_2 = L3_2(L4_2, L5_2, L6_2)
  L4_2 = L8_1
  L5_2, L6_2, L7_2, L8_2, L9_2, L10_2 = ...
  L4_2 = L4_2(L5_2, L6_2, L7_2, L8_2, L9_2, L10_2)
  L5_2 = print
  L6_2 = "%s %s%s"
  L7_2 = L6_2
  L6_2 = L6_2.format
  L8_2 = L3_2
  L9_2 = L4_2
  L10_2 = L4_1.reset
  L6_2, L7_2, L8_2, L9_2, L10_2 = L6_2(L7_2, L8_2, L9_2, L10_2)
  L5_2(L6_2, L7_2, L8_2, L9_2, L10_2)
end
L10_1 = Debug
function L11_1(A0_2, ...)
  local L1_2, L2_2, L3_2, L4_2, L5_2
  L1_2 = L9_1
  L2_2 = "INFO"
  L3_2 = L4_1.blue
  L4_2 = nil
  L5_2 = ...
  L1_2(L2_2, L3_2, L4_2, L5_2)
end
L10_1.info = L11_1
L10_1 = Debug
function L11_1(A0_2, ...)
  local L1_2, L2_2, L3_2, L4_2, L5_2
  L1_2 = L9_1
  L2_2 = "SUCCESS"
  L3_2 = L4_1.green
  L4_2 = nil
  L5_2 = ...
  L1_2(L2_2, L3_2, L4_2, L5_2)
end
L10_1.success = L11_1
L10_1 = Debug
function L11_1(A0_2, ...)
  local L1_2, L2_2, L3_2, L4_2, L5_2
  L1_2 = L9_1
  L2_2 = "WARN"
  L3_2 = L4_1.yellow
  L4_2 = nil
  L5_2 = ...
  L1_2(L2_2, L3_2, L4_2, L5_2)
end
L10_1.warn = L11_1
L10_1 = Debug
function L11_1(A0_2, ...)
  local L1_2, L2_2, L3_2, L4_2, L5_2
  L1_2 = L9_1
  L2_2 = "ERROR"
  L3_2 = L4_1.red
  L4_2 = nil
  L5_2 = ...
  L1_2(L2_2, L3_2, L4_2, L5_2)
end
L10_1.error = L11_1
L10_1 = Debug
function L11_1(A0_2, ...)
  local L1_2, L2_2, L3_2, L4_2, L5_2
  L1_2 = L0_1
  if not L1_2 then
    return
  end
  L1_2 = L9_1
  L2_2 = "DEBUG"
  L3_2 = L4_1.cyan
  L4_2 = nil
  L5_2 = ...
  L1_2(L2_2, L3_2, L4_2, L5_2)
end
L10_1.debug = L11_1
L10_1 = Debug
function L11_1(A0_2, ...)
  local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2
  L1_2 = debug
  L1_2 = L1_2.getinfo
  L2_2 = 2
  L3_2 = "Sl"
  L1_2 = L1_2(L2_2, L3_2)
  L2_2 = string
  L2_2 = L2_2.format
  L3_2 = "%s:%d"
  L4_2 = L1_2.short_src
  if not L4_2 then
    L4_2 = "unknown"
  end
  L5_2 = L1_2.currentline
  if not L5_2 then
    L5_2 = 0
  end
  L2_2 = L2_2(L3_2, L4_2, L5_2)
  L4_2 = A0_2
  L3_2 = A0_2.debug
  L5_2 = L2_2
  L6_2 = " \226\134\146"
  L5_2 = L5_2 .. L6_2
  L6_2 = ...
  L3_2(L4_2, L5_2, L6_2)
end
L10_1.trace = L11_1
L10_1 = Debug
function L11_1(A0_2, A1_2)
  L1_1 = A1_2
end
L10_1.setTitle = L11_1
L10_1 = Debug
function L11_1(A0_2)
  local L1_2
  L1_2 = nil
  L1_1 = L1_2
end
L10_1.clearTitle = L11_1
L10_1 = Debug
function L11_1(A0_2, A1_2)
  L0_1 = A1_2
end
L10_1.enableDebug = L11_1
L10_1 = Debug
function L11_1(A0_2, A1_2)
  local L2_2
  L2_2 = L2_1
  L2_2[A1_2] = true
end
L10_1.enableZone = L11_1
L10_1 = Debug
function L11_1(A0_2, A1_2)
  local L2_2
  L2_2 = L2_1
  L2_2[A1_2] = nil
end
L10_1.disableZone = L11_1
L10_1 = Debug
function L11_1(A0_2, A1_2, ...)
  local L2_2, L3_2, L4_2, L5_2, L6_2
  L2_2 = L9_1
  L3_2 = "INFO"
  L4_2 = L4_1.blue
  L5_2 = A1_2
  L6_2 = ...
  L2_2(L3_2, L4_2, L5_2, L6_2)
end
L10_1.infoZone = L11_1
L10_1 = Debug
function L11_1(A0_2, A1_2, ...)
  local L2_2, L3_2, L4_2, L5_2, L6_2
  L2_2 = L9_1
  L3_2 = "SUCCESS"
  L4_2 = L4_1.green
  L5_2 = A1_2
  L6_2 = ...
  L2_2(L3_2, L4_2, L5_2, L6_2)
end
L10_1.successZone = L11_1
L10_1 = Debug
function L11_1(A0_2, A1_2, ...)
  local L2_2, L3_2, L4_2, L5_2, L6_2
  L2_2 = L9_1
  L3_2 = "WARN"
  L4_2 = L4_1.yellow
  L5_2 = A1_2
  L6_2 = ...
  L2_2(L3_2, L4_2, L5_2, L6_2)
end
L10_1.warnZone = L11_1
L10_1 = Debug
function L11_1(A0_2, A1_2, ...)
  local L2_2, L3_2, L4_2, L5_2, L6_2
  L2_2 = L9_1
  L3_2 = "ERROR"
  L4_2 = L4_1.red
  L5_2 = A1_2
  L6_2 = ...
  L2_2(L3_2, L4_2, L5_2, L6_2)
end
L10_1.errorZone = L11_1
L10_1 = Debug
function L11_1(A0_2, A1_2, ...)
  local L2_2, L3_2, L4_2, L5_2, L6_2
  L2_2 = L0_1
  if not L2_2 then
    return
  end
  L2_2 = L9_1
  L3_2 = "DEBUG"
  L4_2 = L4_1.cyan
  L5_2 = A1_2
  L6_2 = ...
  L2_2(L3_2, L4_2, L5_2, L6_2)
end
L10_1.debugZone = L11_1
L10_1 = IsDuplicityVersion
L10_1 = L10_1()
if not L10_1 then
  function L10_1(A0_2, A1_2, A2_2, A3_2)
    local L4_2, L5_2, L6_2, L7_2, L8_2
    L4_2 = SetTextScale
    L5_2 = 0.35
    L6_2 = 0.35
    L4_2(L5_2, L6_2)
    L4_2 = SetTextFont
    L5_2 = 4
    L4_2(L5_2)
    L4_2 = SetTextProportional
    L5_2 = true
    L4_2(L5_2)
    L4_2 = SetTextColour
    L5_2 = 255
    L6_2 = 255
    L7_2 = 255
    L8_2 = 215
    L4_2(L5_2, L6_2, L7_2, L8_2)
    L4_2 = SetTextEntry
    L5_2 = "STRING"
    L4_2(L5_2)
    L4_2 = SetTextCentre
    L5_2 = true
    L4_2(L5_2)
    L4_2 = AddTextComponentString
    L5_2 = A3_2
    L4_2(L5_2)
    L4_2 = SetDrawOrigin
    L5_2 = A0_2
    L6_2 = A1_2
    L7_2 = A2_2
    L8_2 = 0
    L4_2(L5_2, L6_2, L7_2, L8_2)
    L4_2 = DrawText
    L5_2 = 0.0
    L6_2 = 0.0
    L4_2(L5_2, L6_2)
    L4_2 = ClearDrawOrigin
    L4_2()
  end
  L11_1 = Debug
  function L12_1(A0_2, A1_2, A2_2)
    local L3_2, L4_2, L5_2, L6_2, L7_2
    L3_2 = type
    L4_2 = A1_2
    L3_2 = L3_2(L4_2)
    if "table" ~= L3_2 then
      L3_2 = type
      L4_2 = A1_2
      L3_2 = L3_2(L4_2)
      if "vector3" ~= L3_2 then
        goto lbl_18
      end
    end
    L3_2 = L10_1
    L4_2 = A1_2.x
    L5_2 = A1_2.y
    L6_2 = A1_2.z
    L7_2 = A2_2
    L3_2(L4_2, L5_2, L6_2, L7_2)
    goto lbl_21
    ::lbl_18::
    L3_2 = error
    L4_2 = "Invalid position format for draw3D"
    L3_2(L4_2)
    ::lbl_21::
  end
  L11_1.draw3D = L12_1
  L11_1 = Debug
  function L12_1(A0_2, A1_2, A2_2, A3_2)
    local L4_2, L5_2, L6_2, L7_2, L8_2
    L4_2 = SetTextFont
    L5_2 = 0
    L4_2(L5_2)
    L4_2 = SetTextProportional
    L5_2 = true
    L4_2(L5_2)
    L4_2 = SetTextScale
    L5_2 = 0.35
    L6_2 = 0.35
    L4_2(L5_2, L6_2)
    L4_2 = SetTextColour
    L5_2 = 255
    L6_2 = 255
    L7_2 = 255
    L8_2 = 255
    L4_2(L5_2, L6_2, L7_2, L8_2)
    L4_2 = SetTextEntry
    L5_2 = "STRING"
    L4_2(L5_2)
    L4_2 = AddTextComponentString
    L5_2 = A3_2
    L4_2(L5_2)
    L4_2 = DrawText
    L5_2 = A1_2
    L6_2 = A2_2
    L4_2(L5_2, L6_2)
  end
  L11_1.drawText = L12_1
end
