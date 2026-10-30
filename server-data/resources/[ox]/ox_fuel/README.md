# ox_fuel

Fuel resource for ox_inventory, with NoPixel V style pumps: take the nozzle, put it in the car yourself, and pay on a screen built into the pump.

## How fueling works

Prompts come from the `interact` resource by default (`config.interaction`). Make sure `interact` starts before ox_fuel.
You can also use `'ox_target'`, or `'helptext'` for E / G keybinds.

1. At a pump, choose **Take nozzle**. A hose connects it to the pump.
2. At your vehicle's filler, choose **Insert nozzle**.
3. Back at the pump, choose **Use pump**. The camera moves up to the faceplate and you click its buttons with your mouse.
4. Press the side button next to your fuel. Type litres on the keypad (or 10 L / 20 L / FULL), then pick cash or card.
5. Press **STOP FUELING** at any time. You're only charged for what went in, and the rest is refunded.
6. Choose **Remove nozzle** at the filler, then **Hang up nozzle** at the pump.

- Leave the engine running while fueling and the car catches fire.
- Drive off with the nozzle in and the hose snaps. The nozzle goes back on the pump.
- Every pump shows its screen. A pump that's in use shows FUELING IN PROGRESS to everyone.
- Electric vehicles (`config.electricVehicles`) never run dry and can't be fueled.
- Fuel burns faster at higher RPM (`config.fuelUsage`, `config.classUsage`).
- Card payments use the bank account of Qbox, QBCore or ESX. Cash uses the ox_inventory `money` item.
- Change the screen colors in `web/colors.css`.

## Tuning the pump screen placement

The faceplate is drawn over each pump's dark front panel, sized from the model's bounding box.
To fit it exactly, start object_gizmo v3 or newer, stand at a pump, face the side you want to edit and run `/fuelscreen`:

- **W** moves the faceplate and **S** resizes it. The height follows the faceplate's aspect ratio, so dragging either the width or the height handle works. The faceplate updates live while you drag.
- **Q** switches between local and world axes, and **X** toggles snap. Rotation is turned off so the faceplate stays flat on the pump.
- **Enter** saves, and **Esc** cancels and puts it back.

The placement applies to every pump of that model, on both sides. It's saved to `data/screens.json` and synced to all players straight away.
Only players in the Qbox permission group `config.screen.editPermission` (default `admin`) can use it. This is the same check the Qbox admin panel uses.
Saved placements override `config.screen.models`.
The nozzle offsets in hand and in the vehicle are in `config.nozzle`.

## setRefundMethod (server)

When you replace the payment method with `setPaymentMethod`, also replace the cash refund:

```lua
exports.ox_fuel:setRefundMethod(function(playerId, amount)
	ESX.GetPlayerFromId(playerId).addAccountMoney('money', amount)
end)
```

## Get vehicle fuel level

This is an incredibly complicated task for some people, and they often ask for exports to do it.
You use the native function [GetVehicleFuelLevel](https://docs.fivem.net/natives/?_0x5F739BB8), or you can use a statebag.

```lua
Entity(entity).state.fuel
```

## Set vehicle fuel level

```lua
Entity(entity).state.fuel = fuelAmount
```

## setPaymentMethod (server)

Replaces the standard payment method using "money" as an item.

```lua
exports.ox_fuel:setPaymentMethod(function(playerId, amount)
    local xPlayer = ESX.GetPlayerFromId(playerId)
	local bankAmount = xPlayer.getAccount('bank').money

	if bankAmount >= amount then
		xPlayer.removeAccountMoney('bank', amount)
		return true
	end

	TriggerClientEvent('ox_lib:notify', source, {
		type = 'error',
		description = locale('not_enough_money', amount - bankAmount)
	})
end)
```

## setMoneyCheck (client)

Replaces the standard inventory search for "money".

```lua
exports.ox_fuel:setMoneyCheck(function()
	local accounts = ESX.GetPlayerData().accounts

	for i = 1, #accounts do
		if accounts[i].name == 'bank' then
		    return accounts[i].money
		end
	end

	return 0
end)
```
