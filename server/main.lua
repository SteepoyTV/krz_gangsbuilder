ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

local BusyList = {
	['PlayersSearched'] = {
		serverId = true,
		identifiers = {}
	}
}

RegisterServerEvent('GangsBuilderJob:confiscatePlayerItem')
AddEventHandler('GangsBuilderJob:confiscatePlayerItem', function(target, itemType, itemName, amount)
	local sourceXPlayer = ESX.GetPlayerFromId(source)
	local targetXPlayer = ESX.GetPlayerFromId(target)

	if sourceXPlayer ~= nil and targetXPlayer ~= nil then
		if itemType == 'item_standard' then
			local sourceItem = sourceXPlayer.getInventoryItem(itemName)
			local targetItem = targetXPlayer.getInventoryItem(itemName)
	
			if targetItem.count > 0 and targetItem.count <= amount then
				if sourceItem.limit ~= -1 and (sourceItem.count + amount) > sourceItem.limit then
					TriggerClientEvent('esx:showNotification', sourceXPlayer.source, _U('quantity_invalid'))
				else
					targetXPlayer.removeInventoryItem(itemName, amount)
					sourceXPlayer.addInventoryItem(itemName, amount)

					TriggerClientEvent('esx:showNotification', sourceXPlayer.source, _U('you_confiscated', amount, sourceItem.label, targetXPlayer.name))
					TriggerClientEvent('esx:showNotification', target, _U('got_confiscated', amount, sourceItem.label, sourceXPlayer.name))
				end
			else
				TriggerClientEvent('esx:showNotification', sourceXPlayer.source, _U('quantity_invalid'))
			end
		end

		if itemType == 'item_account' then
			targetXPlayer.removeAccountMoney(itemName, amount)
			sourceXPlayer.addAccountMoney(itemName, amount)

			TriggerClientEvent('esx:showNotification', sourceXPlayer.source, _U('you_confiscated_account', amount, itemName, targetXPlayer.name))
			TriggerClientEvent('esx:showNotification', target, _U('got_confiscated_account', amount, itemName, sourceXPlayer.name))
		end

		if itemType == 'item_weapon' then
			targetXPlayer.removeWeapon(itemName)
			sourceXPlayer.addWeapon(itemName, amount)

			TriggerClientEvent('esx:showNotification', sourceXPlayer.source, _U('you_confiscated_weapon', ESX.GetWeaponLabel(itemName), targetXPlayer.name, amount))
			TriggerClientEvent('esx:showNotification', target, _U('got_confiscated_weapon', ESX.GetWeaponLabel(itemName), amount, sourceXPlayer.name))
		end
	end
end)

RegisterServerEvent('GangsBuilderJob:putInVehicle')
AddEventHandler('GangsBuilderJob:putInVehicle', function(target)
	local xPlayerTarget = ESX.GetPlayerFromId(target)

	if xPlayerTarget ~= nil then
		local cuffState = xPlayerTarget.get('cuffState')

		if cuffState.isCuffed then
			TriggerClientEvent('GangsBuilderJob:putInVehicle', target)
		end
	end
end)

RegisterServerEvent('GangsBuilderJob:OutVehicle')
AddEventHandler('GangsBuilderJob:OutVehicle', function(target)
	local xPlayerTarget = ESX.GetPlayerFromId(target)

	if xPlayerTarget ~= nil then
		local cuffState = xPlayerTarget.get('cuffState')

		if cuffState.isCuffed then
			TriggerClientEvent('GangsBuilderJob:OutVehicle', target)
		end
	end
end)

RegisterServerEvent('GangsBuilderJob:getStockItem')
AddEventHandler('GangsBuilderJob:getStockItem', function(itemName, count)
	local xPlayer = ESX.GetPlayerFromId(source)

	TriggerEvent('esx_addoninventory:getSharedInventory', 'society_' .. xPlayer.job2.name, function(inventory)
		local item = inventory.getItem(itemName)

    if item.count >= count then
      inventory.removeItem(itemName, count)
      xPlayer.addInventoryItem(itemName, count)
    else
      TriggerClientEvent('esx:showNotification', xPlayer.source, _U('quantity_invalid'))
    end

    TriggerClientEvent('esx:showNotification', xPlayer.source, _U('have_withdrawn') .. count .. ' ' .. item.label)

  end)

end)

ESX.RegisterServerCallback('GangsBuilderJob:getStockItems', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)

	TriggerEvent('esx_addoninventory:getSharedInventory', 'society_' .. xPlayer.job2.name, function(inventory)
		cb(inventory.items)
	end)
end)

RegisterServerEvent('GangsBuilderJob:putStockItems')
AddEventHandler('GangsBuilderJob:putStockItems', function(itemName, count)
	local xPlayer = ESX.GetPlayerFromId(source)

	TriggerEvent('esx_addoninventory:getSharedInventory', 'society_' .. xPlayer.job2.name, function(inventory)
		local sourceItem = xPlayer.getInventoryItem(itemName)

		if sourceItem.count >= count and count > 0 then
			xPlayer.removeInventoryItem(itemName, count)
			inventory.addItem(itemName, count)
			TriggerClientEvent('esx:showNotification', xPlayer.source, _U('have_deposited', count, sourceItem.label))
		else
			TriggerClientEvent('esx:showNotification', xPlayer.source, _U('quantity_invalid'))
		end
	end)
end)

ESX.RegisterServerCallback('GangsBuilderJob:getPlayerInventory', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)
	cb({items = xPlayer.inventory})
end)

ESX.RegisterServerCallback('GangsBuilderJob:getOtherPlayerData', function(source, cb, target)
	local xPlayer = ESX.GetPlayerFromId(target)

	if xPlayer ~= nil then
		cb({
			foundPlayer = true,
			inventory = xPlayer.inventory,
			weapons = xPlayer.loadout,
			accounts = xPlayer.accounts
		})
	else
		cb({foundPlayer = false})
	end
end)

ESX.RegisterServerCallback('GangsBuilderJob:getVehicleInfos', function(source, cb, plate)
	MySQL.Async.fetchAll('SELECT * FROM owned_vehicles', {}, function(result)
		local foundIdentifier = nil

		for i = 1, #result, 1 do
			local vehicleData = json.decode(result[i].vehicle)

			if vehicleData.plate == plate then
				foundIdentifier = result[i].owner
				break
			end
		end

		if foundIdentifier ~= nil then
			MySQL.Async.fetchAll('SELECT * FROM users WHERE identifier = @identifier', {
				['@identifier'] = foundIdentifier
			}, function(result)
				local infos = {
					plate = plate,
					owner = result[1].firstname .. ' ' .. result[1].lastname
				}

				cb(infos)
			end)
		else
			local infos = {
				plate = plate
			}

			cb(infos)
		end
	end)
end)

ESX.RegisterServerCallback('GangsBuilderJob:getArmoryWeapons', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)

	TriggerEvent('esx_datastore:getSharedDataStore', 'society_' .. xPlayer.job2.name, function(store)
		local weapons = store.get('weapons') or {}
		cb(weapons)
	end)
end)

ESX.RegisterServerCallback('GangsBuilderJob:addArmoryWeapon', function(source, cb, weaponName, weaponAmmo)
	local xPlayer = ESX.GetPlayerFromId(source)

	if xPlayer.hasWeapon(weaponName) then
		TriggerEvent('esx_datastore:getSharedDataStore', 'society_' .. xPlayer.job2.name, function(store)
			local weapons = store.get('weapons') or {}
			weaponName = string.upper(weaponName)

			table.insert(weapons, {
				name = weaponName,
				ammo = weaponAmmo
			})

			xPlayer.removeWeapon(weaponName)
			store.set('weapons', weapons)
			cb()
		end)
	else
		xPlayer.showNotification('Vous ne poss�dez pas cette arme !')
		cb()
	end
end)

ESX.RegisterServerCallback('GangsBuilderJob:removeArmoryWeapon', function(source, cb, weaponName, weaponAmmo)
	local xPlayer = ESX.GetPlayerFromId(source)

	if not xPlayer.hasWeapon(weaponName) then
		TriggerEvent('esx_datastore:getSharedDataStore', 'society_' .. xPlayer.job2.name, function(store)
			local weapons = store.get('weapons') or {}
			weaponName = string.upper(weaponName)

			for i = 1, #weapons, 1 do
				if weapons[i].name == weaponName and weapons[i].ammo == weaponAmmo then
					table.remove(weapons, i)

					store.set('weapons', weapons)
					xPlayer.addWeapon(weaponName, weaponAmmo)
					break
				end
			end

			cb()
		end)
	else
		xPlayer.showNotification('Vous poss�dez d�j� cette arme !')
		cb()
	end
end)

ESX.RegisterServerCallback('GangsBuilderJob:buyWeapon', function(source, cb, weaponName)
	local xPlayer = ESX.GetPlayerFromId(source)
	local plyGang = GetGang(xPlayer.job2)
	local weaponPrice = 0

	for i = 1, #plyGang.Weapons, 1 do
		if plyGang.Weapons[i].name == weaponName then
			weaponPrice = plyGang.Weapons[i].price
			break
		end
	end

	TriggerEvent('esx_addonaccount:getSharedAccount', 'society_' .. xPlayer.job2.name, function(account)
		if account.money >= weaponPrice then
			TriggerEvent('esx_datastore:getSharedDataStore', 'society_' .. xPlayer.job2.name, function(store)
				local weapons = store.get('weapons') or {}

				table.insert(weapons, {
					name = weaponName,
					ammo = 500
				})

				account.removeMoney(weaponPrice)
				store.set('weapons', weapons)
				xPlayer.showNotification('Arme achet� !')
				cb(true)
			end)
		else
			xPlayer.showNotification(_U('not_enough_money'))
			cb(false)
		end
	end)
end)

ESX.RegisterServerCallback('GangsBuilderJob:isBusy', function(source, cb, type, identifier)
	if BusyList[type].serverId then
		identifier = source
	end

	local found = false

	for i = 1, #BusyList[type].identifiers, 1 do
		if identifier == BusyList[type].identifiers[i] then
			found = true
			break
		end
	end

	cb(found)
end)

ESX.RegisterServerCallback('GangsBuilderJob:AddBusyList', function(source, cb, type, identifier)
	if BusyList[type].serverId then
		identifier = source
	end

	local found = false

	for i = 1, #BusyList[type].identifiers, 1 do
		if identifier == BusyList[type].identifiers[i] then
			found = true
			break
		end
	end

	if not found then
		table.insert(BusyList[type].identifiers, identifier)
	end

	cb(found)
end)

ESX.RegisterServerCallback('GangsBuilderJob:RemoveBusyList', function(source, cb, type, identifier)
	if BusyList[type].serverId then
		identifier = source
	end

	local found = false

	for i = 1, #BusyList[type].identifiers, 1 do
		if identifier == BusyList[type].identifiers[i] then
			table.remove(BusyList[type].identifiers, i)
			found = true
			break
		end
	end

	cb(found)
end)
