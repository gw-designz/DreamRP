local root = (... and ... ~= '') and ... or '.'

Config = {
    currency = { code = 'USD', symbol = '$', precision = 0 },
    security = {
        minimumTransactionAmount = 1,
        maximumTransactionAmount = 100000000,
        minimumAccountIdLength = 3,
        maximumAccountIdLength = 50,
        accountIdPattern = '^[a-z0-9][a-z0-9_-]*$',
        reservedAccountIds = { personal = true }
    }
}

dofile(root .. '/shared/constants.lua')
dofile(root .. '/shared/result.lua')
dofile(root .. '/shared/money.lua')
dofile(root .. '/shared/validation.lua')

local RB = RenewedBanking
local count = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then io.stderr:write(('FAIL %s: %s\n'):format(name, err)); os.exit(1) end
    count = count + 1
    print('PASS ' .. name)
end

local function equal(actual, expected)
    assert(actual == expected, ('expected %s, got %s'):format(tostring(expected), tostring(actual)))
end

test('whole amount parses', function() local value = RB.Money.parse('1250'); equal(value, 1250) end)
test('zero rejected', function() local value, code = RB.Money.parse('0'); equal(value, nil); equal(code, RB.Errors.INVALID_AMOUNT) end)
test('negative rejected', function() local value = RB.Money.parse('-1'); equal(value, nil) end)
test('fraction rejected at zero precision', function() local value = RB.Money.parse('1.50'); equal(value, nil) end)
test('maximum enforced', function() local value, code = RB.Money.parse('100000001'); equal(value, nil); equal(code, RB.Errors.AMOUNT_TOO_LARGE) end)
test('account key normalized', function() local value = RB.Validation.accountKey('Family_Savings'); equal(value, 'family_savings') end)
test('reserved account rejected', function() local value = RB.Validation.accountKey('personal'); equal(value, nil) end)
test('invalid account characters rejected', function() local value = RB.Validation.accountKey('bad account!'); equal(value, nil) end)
test('request id accepted', function() local value = RB.Validation.requestId('request-1234'); equal(value, 'request-1234') end)
test('control characters removed from text', function() local value = RB.Validation.text('hello\1world', 20, false); equal(value, 'helloworld') end)

dofile(root .. '/shared/atm_screen.lua')
local function near(actual, expected) assert(math.abs(actual - expected) < 1e-6, ('expected %s, got %s'):format(expected, actual)) end
-- A 0.4 x 0.3 m glass facing -Y, one metre in front of a camera at the origin looking along +Y.
local glass = { { x = -0.2, y = 1, z = 0.15 }, { x = 0.2, y = 1, z = 0.15 }, { x = 0.2, y = 1, z = -0.15 }, { x = -0.2, y = 1, z = -0.15 } }
local origin = { x = 0, y = 0, z = 0 }
test('atm ray through the middle hits the middle', function()
    local u, v = RB.AtmScreen.uvFromRay(origin, RB.AtmScreen.rayFrom({ x = 0, z = 0 }, 40, 16 / 9, 0.5, 0.5), glass); near(u, 0.5); near(v, 0.5)
end)
test('atm ray reaches the corners', function()
    local u, v = RB.AtmScreen.uvFromRay(origin, { x = 0.2, y = 1, z = -0.15 }, glass); near(u, 1); near(v, 1)
    u, v = RB.AtmScreen.uvFromRay(origin, { x = -0.2, y = 1, z = 0.15 }, glass); near(u, 0); near(v, 0)
end)
test('atm ray beside the glass lands outside it', function()
    local u = RB.AtmScreen.uvFromRay(origin, { x = -0.25, y = 1, z = 0 }, glass); near(u, -0.125)
end)
test('atm ray from the right of the monitor goes right', function()
    local ray = RB.AtmScreen.rayFrom({ x = 0, z = 0 }, 40, 16 / 9, 1, 0.5)
    assert(ray.x > 0 and math.abs(ray.z) < 1e-9, 'right and level')
    ray = RB.AtmScreen.rayFrom({ x = 0, z = 0 }, 40, 16 / 9, 0.5, 0)
    assert(ray.z > 0, 'top of monitor looks up')
end)
test('atm screen corners keep their size', function()
    local c = RB.AtmScreen.corners({ x = 0, y = -0.1, z = 1.2, width = 0.32, height = 0.24, tilt = 10 })
    near(c[2].x - c[1].x, 0.32)
    near(math.sqrt((c[1].y - c[4].y) ^ 2 + (c[1].z - c[4].z) ^ 2), 0.24)
    assert(c[1].y > c[4].y, 'top leans back')
end)
test('atm side buttons hit by row and side', function()
    local keys = { rows = { 0.2, 0.4 }, height = 0.1, left = { -0.15, -0.02 }, right = { 1.02, 1.15 } }
    local side, row = RB.AtmScreen.keyAt(keys, -0.1, 0.42); equal(side, 'left'); equal(row, 2)
    side, row = RB.AtmScreen.keyAt(keys, 1.1, 0.18); equal(side, 'right'); equal(row, 1)
    equal(RB.AtmScreen.keyAt(keys, 0.5, 0.2), nil)
    equal(RB.AtmScreen.keyAt(keys, -0.1, 0.3), nil)
end)

print(('Completed %d shared unit tests.'):format(count))
