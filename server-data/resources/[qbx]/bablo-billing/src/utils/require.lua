
local L0_1, L1_1, L2_1, L3_1, L4_1, L5_1, L6_1, L7_1, L8_1, L9_1, L10_1, L11_1, L12_1
L0_1 = {}
L1_1 = require
function L2_1()
  local L0_2, L1_2
end
function L3_1()
  local L0_2, L1_2, L2_2, L3_2
  L0_2 = debug
  L0_2 = L0_2.getinfo
  L1_2 = 2
  L2_2 = "S"
  L0_2 = L0_2(L1_2, L2_2)
  if L0_2 then
    L1_2 = L0_2.source
    if L1_2 then
      L1_2 = L0_2.source
      L2_2 = L1_2
      L1_2 = L1_2.match
      L3_2 = "^@@([^/]+)/"
      return L1_2(L2_2, L3_2)
    end
  end
  L1_2 = GetCurrentResourceName
  return L1_2()
end
function L4_1(A0_2)
  local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2
  L1_2 = pairs
  L2_2 = A0_2
  L1_2, L2_2, L3_2, L4_2 = L1_2(L2_2)
  for L5_2 in L1_2, L2_2, L3_2, L4_2 do
    A0_2[L5_2] = nil
  end
end
L5_1 = {}
lib = L5_1
L5_1 = {}
L5_1.path = "./?.lua;./?/init.lua;./src/?.lua;./src/?/init.lua"
L6_1 = {}
L5_1.preload = L6_1
L6_1 = setmetatable
L7_1 = {}
L8_1 = {}
L8_1.__index = L0_1
L8_1.__newindex = L2_1
L8_1.__metatable = false
L6_1 = L6_1(L7_1, L8_1)
L5_1.loaded = L6_1
package = L5_1
function L5_1(A0_2)
  local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2
  L2_2 = A0_2
  L1_2 = A0_2.match
  L3_2 = "^@(.-)/.+"
  L1_2 = L1_2(L2_2, L3_2)
  if L1_2 then
    L2_2 = L1_2
    L4_2 = A0_2
    L3_2 = A0_2.sub
    L5_2 = #L1_2
    L5_2 = L5_2 + 3
    L3_2, L4_2, L5_2, L6_2, L7_2 = L3_2(L4_2, L5_2)
    return L2_2, L3_2, L4_2, L5_2, L6_2, L7_2
  end
  L2_2 = 4
  while true do
    L3_2 = debug
    L3_2 = L3_2.getinfo
    L4_2 = L2_2
    L5_2 = "S"
    L3_2 = L3_2(L4_2, L5_2)
    if L3_2 then
      L4_2 = L3_2.source
      if L4_2 then
        goto lbl_25
      end
    end
    L4_2 = nil
    ::lbl_25::
    if not L4_2 then
      L5_2 = L3_1
      L5_2 = L5_2()
      L6_2 = A0_2
      return L5_2, L6_2
    end
    L6_2 = L4_2
    L5_2 = L4_2.match
    L7_2 = "^@@([^/]+)/.+"
    L5_2 = L5_2(L6_2, L7_2)
    L1_2 = L5_2
    if L1_2 then
      L6_2 = L4_2
      L5_2 = L4_2.find
      L7_2 = "^@@ox_lib/imports/require"
      L5_2 = L5_2(L6_2, L7_2)
      if not L5_2 then
        L5_2 = L1_2
        L6_2 = A0_2
        return L5_2, L6_2
      end
    end
    L2_2 = L2_2 + 1
  end
end
L6_1 = {}
L7_1 = package
function L8_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2
  L2_2 = L5_1
  L4_2 = A0_2
  L3_2 = A0_2.gsub
  L5_2 = "%."
  L6_2 = "/"
  L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2 = L3_2(L4_2, L5_2, L6_2)
  L2_2, L3_2 = L2_2(L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2)
  L4_2 = {}
  L6_2 = A1_2
  L5_2 = A1_2.gmatch
  L7_2 = "[^;]+"
  L5_2, L6_2, L7_2, L8_2 = L5_2(L6_2, L7_2)
  for L9_2 in L5_2, L6_2, L7_2, L8_2 do
    L11_2 = L9_2
    L10_2 = L9_2.gsub
    L12_2 = "^%./"
    L13_2 = ""
    L10_2 = L10_2(L11_2, L12_2, L13_2)
    L11_2 = L10_2
    L10_2 = L10_2.gsub
    L12_2 = "?"
    L13_2 = L3_2
    L10_2 = L10_2(L11_2, L12_2, L13_2)
    L11_2 = LoadResourceFile
    L12_2 = L2_2
    L13_2 = L10_2
    L11_2 = L11_2(L12_2, L13_2)
    if L11_2 then
      L12_2 = L6_1
      L12_2[1] = L11_2
      L12_2 = L6_1
      L12_2[2] = L2_2
      return L10_2
    end
    L12_2 = #L4_2
    L12_2 = L12_2 + 1
    L13_2 = "no file '@%s/%s'"
    L14_2 = L13_2
    L13_2 = L13_2.format
    L15_2 = L2_2
    L16_2 = L10_2
    L13_2 = L13_2(L14_2, L15_2, L16_2)
    L4_2[L12_2] = L13_2
  end
  L5_2 = nil
  L6_2 = table
  L6_2 = L6_2.concat
  L7_2 = L4_2
  L8_2 = [[

	]]
  L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2 = L6_2(L7_2, L8_2)
  return L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2, L13_2, L14_2, L15_2, L16_2
end
L7_1.searchpath = L8_1
function L7_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2, L11_2, L12_2
  L2_2 = package
  L2_2 = L2_2.searchpath
  L3_2 = A0_2
  L4_2 = package
  L4_2 = L4_2.path
  L2_2, L3_2 = L2_2(L3_2, L4_2)
  if L2_2 then
    L4_2 = L6_1
    L4_2 = L4_2[1]
    L5_2 = L6_1
    L5_2 = L5_2[2]
    L6_2 = L4_1
    L7_2 = L6_1
    L6_2(L7_2)
    L6_2 = assert
    L7_2 = load
    L8_2 = L4_2
    L9_2 = "@@%s/%s"
    L10_2 = L9_2
    L9_2 = L9_2.format
    L11_2 = L5_2
    L12_2 = L2_2
    L9_2 = L9_2(L10_2, L11_2, L12_2)
    L10_2 = "t"
    L11_2 = A1_2 or L11_2
    if not A1_2 then
      L11_2 = _ENV
    end
    L7_2, L8_2, L9_2, L10_2, L11_2, L12_2 = L7_2(L8_2, L9_2, L10_2, L11_2)
    return L6_2(L7_2, L8_2, L9_2, L10_2, L11_2, L12_2)
  end
  L4_2 = nil
  L5_2 = L3_2 or L5_2
  if not L3_2 then
    L5_2 = "unknown error"
  end
  return L4_2, L5_2
end
L8_1 = package
L9_1 = {}
function L10_1(A0_2)
  local L1_2, L2_2, L3_2, L4_2
  L1_2 = pcall
  L2_2 = L1_1
  L3_2 = A0_2
  L1_2, L2_2 = L1_2(L2_2, L3_2)
  if L1_2 then
    return L2_2
  end
  L3_2 = nil
  L4_2 = L2_2
  return L3_2, L4_2
end
function L11_1(A0_2)
  local L1_2, L2_2, L3_2, L4_2
  L1_2 = package
  L1_2 = L1_2.preload
  L1_2 = L1_2[A0_2]
  if nil ~= L1_2 then
    L1_2 = package
    L1_2 = L1_2.preload
    L1_2 = L1_2[A0_2]
    return L1_2
  end
  L1_2 = nil
  L2_2 = "no field package.preload['%s']"
  L3_2 = L2_2
  L2_2 = L2_2.format
  L4_2 = A0_2
  L2_2, L3_2, L4_2 = L2_2(L3_2, L4_2)
  return L1_2, L2_2, L3_2, L4_2
end
function L12_1(A0_2)
  local L1_2, L2_2
  L1_2 = L7_1
  L2_2 = A0_2
  return L1_2(L2_2)
end
L9_1[1] = L10_1
L9_1[2] = L11_1
L9_1[3] = L12_1
L8_1.searchers = L9_1
L8_1 = lib
function L9_1(A0_2, A1_2)
  local L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2
  L2_2 = type
  L3_2 = A0_2
  L2_2 = L2_2(L3_2)
  if "string" ~= L2_2 then
    L2_2 = error
    L3_2 = "file path must be a string (received '%s')"
    L4_2 = L3_2
    L3_2 = L3_2.format
    L5_2 = A0_2
    L3_2 = L3_2(L4_2, L5_2)
    L4_2 = 2
    L2_2(L3_2, L4_2)
  end
  L2_2 = L7_1
  L3_2 = A0_2
  L4_2 = A1_2
  L2_2, L3_2 = L2_2(L3_2, L4_2)
  if L2_2 then
    L4_2 = L2_2
    return L4_2()
  end
  L4_2 = error
  L5_2 = [[
file '%s' not found
	%s]]
  L6_2 = L5_2
  L5_2 = L5_2.format
  L7_2 = A0_2
  L8_2 = L3_2
  L5_2, L6_2, L7_2, L8_2 = L5_2(L6_2, L7_2, L8_2)
  L4_2(L5_2, L6_2, L7_2, L8_2)
end
L8_1.load = L9_1
L8_1 = lib
function L9_1(A0_2)
  local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2
  L1_2 = type
  L2_2 = A0_2
  L1_2 = L1_2(L2_2)
  if "string" ~= L1_2 then
    L1_2 = error
    L2_2 = "file path must be a string (received '%s')"
    L3_2 = L2_2
    L2_2 = L2_2.format
    L4_2 = A0_2
    L2_2 = L2_2(L3_2, L4_2)
    L3_2 = 2
    L1_2(L2_2, L3_2)
  end
  L1_2 = L5_1
  L3_2 = A0_2
  L2_2 = A0_2.gsub
  L4_2 = "%."
  L5_2 = "/"
  L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2 = L2_2(L3_2, L4_2, L5_2)
  L1_2, L2_2 = L1_2(L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2)
  L3_2 = LoadResourceFile
  L4_2 = L1_2
  L5_2 = "%s.json"
  L6_2 = L5_2
  L5_2 = L5_2.format
  L7_2 = L2_2
  L5_2, L6_2, L7_2, L8_2, L9_2 = L5_2(L6_2, L7_2)
  L3_2 = L3_2(L4_2, L5_2, L6_2, L7_2, L8_2, L9_2)
  if L3_2 then
    L4_2 = json
    L4_2 = L4_2.decode
    L5_2 = L3_2
    return L4_2(L5_2)
  end
  L4_2 = error
  L5_2 = [[
json file '%s' not found
	no file '@%s/%s.json']]
  L6_2 = L5_2
  L5_2 = L5_2.format
  L7_2 = A0_2
  L8_2 = L1_2
  L9_2 = L2_2
  L5_2, L6_2, L7_2, L8_2, L9_2 = L5_2(L6_2, L7_2, L8_2, L9_2)
  L4_2(L5_2, L6_2, L7_2, L8_2, L9_2)
end
L8_1.loadJson = L9_1
L8_1 = lib
function L9_1(A0_2)
  local L1_2, L2_2, L3_2, L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2
  L1_2 = type
  L2_2 = A0_2
  L1_2 = L1_2(L2_2)
  if "string" ~= L1_2 then
    L1_2 = error
    L2_2 = "module name must be a string (received '%s')"
    L3_2 = L2_2
    L2_2 = L2_2.format
    L4_2 = A0_2
    L2_2 = L2_2(L3_2, L4_2)
    L3_2 = 3
    L1_2(L2_2, L3_2)
  end
  L1_2 = L0_1
  L1_2 = L1_2[A0_2]
  if "__loading" == L1_2 then
    L2_2 = error
    L3_2 = "^1circular-dependency occurred when loading module '%s'^0"
    L4_2 = L3_2
    L3_2 = L3_2.format
    L5_2 = A0_2
    L3_2 = L3_2(L4_2, L5_2)
    L4_2 = 2
    L2_2(L3_2, L4_2)
  end
  if nil ~= L1_2 then
    return L1_2
  end
  L2_2 = L0_1
  L2_2[A0_2] = "__loading"
  L2_2 = {}
  L3_2 = 1
  L4_2 = package
  L4_2 = L4_2.searchers
  L4_2 = #L4_2
  L5_2 = 1
  for L6_2 = L3_2, L4_2, L5_2 do
    L7_2 = package
    L7_2 = L7_2.searchers
    L7_2 = L7_2[L6_2]
    L8_2 = A0_2
    L7_2, L8_2 = L7_2(L8_2)
    if L7_2 then
      L9_2 = type
      L10_2 = L7_2
      L9_2 = L9_2(L10_2)
      if "function" == L9_2 then
        L9_2 = L7_2
        L9_2 = L9_2()
        L7_2 = L9_2
      end
      L9_2 = L0_1
      L10_2 = L7_2 or L10_2
      L10_2 = L7_2 or nil == L7_2
      L9_2[A0_2] = L10_2
      L9_2 = L0_1
      L9_2 = L9_2[A0_2]
      return L9_2
    end
    L9_2 = #L2_2
    L9_2 = L9_2 + 1
    L2_2[L9_2] = L8_2
  end
  L3_2 = error
  L4_2 = "%s"
  L5_2 = L4_2
  L4_2 = L4_2.format
  L6_2 = table
  L6_2 = L6_2.concat
  L7_2 = L2_2
  L8_2 = [[

	]]
  L6_2, L7_2, L8_2, L9_2, L10_2 = L6_2(L7_2, L8_2)
  L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2 = L4_2(L5_2, L6_2, L7_2, L8_2, L9_2, L10_2)
  L3_2(L4_2, L5_2, L6_2, L7_2, L8_2, L9_2, L10_2)
end
L8_1.require = L9_1
L8_1 = lib
L8_1 = L8_1.require
customRequire = L8_1
L8_1 = lib
return L8_1
