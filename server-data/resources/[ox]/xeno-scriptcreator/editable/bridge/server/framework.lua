DTreeFw = {}

local cachedQBCore = nil

function DTreeFw.getQBCore()
	if cachedQBCore then
		return cachedQBCore
	end

	if GetResourceState("qb-core") ~= "started" then
		return nil
	end

	local ok, obj = pcall(function()
		return exports["qb-core"]:GetCoreObject()
	end)

	if ok then
		cachedQBCore = obj
		return cachedQBCore
	end

	return nil
end

function DTreeFw.getQBPlayer(playerId)
	local core = DTreeFw.getQBCore()
	if not core or not core.Functions then
		return nil
	end

	return core.Functions.GetPlayer(playerId)
end

function DTreeFw.getQBXPlayer(playerId)
	if GetResourceState("qbx_core") ~= "started" then
		return nil
	end

	local ok, player = pcall(function()
		return exports["qbx_core"]:GetPlayer(playerId)
	end)

	if ok then
		return player
	end

	return nil
end

function DTreeFw.getESXPlayer(playerId)
	if GetResourceState("es_extended") ~= "started" then
		return nil
	end

	if ESX and ESX.GetPlayerFromId then
		return ESX.GetPlayerFromId(playerId)
	end

	local ok, shared = pcall(function()
		return exports["es_extended"]:getSharedObject()
	end)

	if ok and shared and shared.GetPlayerFromId then
		ESX = shared
		return ESX.GetPlayerFromId(playerId)
	end

	return nil
end

function DTreeFw.getSelectedFramework(context)
	local selected =
		context and context.runtime and context.runtime.framework or Config.Runtime.Framework
	return tostring(selected or "auto")
end

function DTreeFw.getPlayerJob(context, playerId)
	local framework = DTreeFw.getSelectedFramework(context)

	if framework == "qbx-core" then
		local qbxPlayer = DTreeFw.getQBXPlayer(playerId)
		local job =
			qbxPlayer and qbxPlayer.PlayerData and qbxPlayer.PlayerData.job
		if job then
			return tostring(job.name or ""), tonumber(
				job.grade and (job.grade.level or job.grade) or 0
			) or 0
		end
	end

	if framework == "qb-core" or framework == "auto" then
		local qbPlayer = DTreeFw.getQBPlayer(playerId)
		local job = qbPlayer and qbPlayer.PlayerData and qbPlayer.PlayerData.job
		if job then
			return tostring(job.name or ""), tonumber(
				job.grade and (job.grade.level or job.grade) or 0
			) or 0
		end
	end

	if framework == "es_extended" or framework == "auto" then
		local esxPlayer = DTreeFw.getESXPlayer(playerId)
		local job = esxPlayer and esxPlayer.job
		if job then
			return tostring(job.name or ""), tonumber(job.grade or 0) or 0
		end
	end

	return "", 0
end

function DTreeFw.getPlayerJobName(context, playerId)
	local framework = DTreeFw.getSelectedFramework(context)

	if framework == "qbx-core" or framework == "auto" then
		local qbxPlayer = DTreeFw.getQBXPlayer(playerId)
		local job =
			qbxPlayer and qbxPlayer.PlayerData and qbxPlayer.PlayerData.job
		if job and job.name then
			return tostring(job.name)
		end
	end

	if framework == "qb-core" or framework == "auto" then
		local qbPlayer = DTreeFw.getQBPlayer(playerId)
		local job = qbPlayer and qbPlayer.PlayerData and qbPlayer.PlayerData.job
		if job and job.name then
			return tostring(job.name)
		end
	end

	if framework == "es_extended" or framework == "auto" then
		local esxPlayer = DTreeFw.getESXPlayer(playerId)
		local job = esxPlayer and esxPlayer.job
		if job and job.name then
			return tostring(job.name)
		end
	end

	return ""
end

function DTreeFw.getPlayerStateData(playerId)
	local data = {
		playerName = GetPlayerName(playerId) or "Player",
		firstName = "",
		lastName = "",
		birthdate = "",
		gender = "",
		nationality = "",
		phone = "",
		account = "",
		citizenid = "",
		id = playerId,
		cash = 0,
		bank = 0,
		crypto = 0,
		health = 100,
		armor = 0,
		hunger = 100,
		job = "",
		jobGrade = 0,
		isDead = false,
		isCuffed = false,
	}

	local ped = GetPlayerPed(playerId)
	if ped and ped > 0 then
		local maxHealth = GetEntityMaxHealth(ped)
		local curHealth = GetEntityHealth(ped)
		if maxHealth > 100 then
			data.health =
				math.max(
					0,
					math.floor(((curHealth - 100) / (maxHealth - 100)) * 100)
				)
		else
			data.health =
				math.max(0, math.floor((curHealth / (maxHealth or 100)) * 100))
		end
		data.armor = math.max(0, math.min(100, GetPedArmour(ped) or 0))
	end

	local framework = DTreeFw.getSelectedFramework(nil)

	if framework == "qbx-core" or framework == "auto" then
		local qbxPlayer = DTreeFw.getQBXPlayer(playerId)
		if qbxPlayer and qbxPlayer.PlayerData then
			local pd = qbxPlayer.PlayerData
			if pd.charinfo then
				data.firstName = pd.charinfo.firstname or ""
				data.lastName = pd.charinfo.lastname or ""
				data.playerName =
					("%s %s"):format(data.firstName, data.lastName)
				data.birthdate = pd.charinfo.birthdate or ""
				data.gender =
					pd.charinfo.gender == 0 and "Male" or (pd.charinfo.gender == 1 and "Female" or tostring(
						pd.charinfo.gender or ""
					))
				data.nationality = pd.charinfo.nationality or ""
				data.phone = pd.charinfo.phone or ""
				data.account = pd.charinfo.account or ""
			end
			if pd.citizenid then
				data.citizenid = pd.citizenid
			end
			if pd.money then
				data.cash = pd.money.cash or 0
				data.bank = pd.money.bank or 0
				data.crypto = pd.money.crypto or 0
			end
			if pd.job then
				data.job = pd.job.name or ""
				data.jobGrade =
					tonumber(
						pd.job.grade and (pd.job.grade.level or pd.job.grade) or 0
					) or 0
			end
			if pd.metadata then
				data.hunger = math.floor(pd.metadata.hunger or 100)
				if pd.metadata.health and data.health == 0 then
					data.health = pd.metadata.health
				end
				if pd.metadata.armor and data.armor == 0 then
					data.armor = pd.metadata.armor
				end
				if pd.metadata.isdead ~= nil then
					data.isDead = pd.metadata.isdead
				end
				if pd.metadata.inlaststand ~= nil and pd.metadata.inlaststand then
					data.isDead = true
				end
				if pd.metadata.iscuffed ~= nil then
					data.isCuffed = pd.metadata.iscuffed
				end
			end
			return data
		end
	end

	if framework == "qb-core" or framework == "auto" then
		local qbPlayer = DTreeFw.getQBPlayer(playerId)
		if qbPlayer and qbPlayer.PlayerData then
			local pd = qbPlayer.PlayerData
			if pd.charinfo then
				data.firstName = pd.charinfo.firstname or ""
				data.lastName = pd.charinfo.lastname or ""
				data.playerName =
					("%s %s"):format(data.firstName, data.lastName)
				data.birthdate = pd.charinfo.birthdate or ""
				data.gender =
					pd.charinfo.gender == 0 and "Male" or (pd.charinfo.gender == 1 and "Female" or tostring(
						pd.charinfo.gender or ""
					))
				data.nationality = pd.charinfo.nationality or ""
				data.phone = pd.charinfo.phone or ""
				data.account = pd.charinfo.account or ""
			end
			if pd.citizenid then
				data.citizenid = pd.citizenid
			end
			if pd.money then
				data.cash = pd.money.cash or 0
				data.bank = pd.money.bank or 0
				data.crypto = pd.money.crypto or 0
			end
			if pd.job then
				data.job = pd.job.name or ""
				data.jobGrade =
					tonumber(
						pd.job.grade and (pd.job.grade.level or pd.job.grade) or 0
					) or 0
			end
			if pd.metadata then
				data.hunger = math.floor(pd.metadata.hunger or 100)
				if pd.metadata.health and data.health == 0 then
					data.health = pd.metadata.health
				end
				if pd.metadata.armor and data.armor == 0 then
					data.armor = pd.metadata.armor
				end
				if pd.metadata.isdead ~= nil then
					data.isDead = pd.metadata.isdead
				end
				if pd.metadata.inlaststand ~= nil and pd.metadata.inlaststand then
					data.isDead = true
				end
				if pd.metadata.iscuffed ~= nil then
					data.isCuffed = pd.metadata.iscuffed
				end
			end
			return data
		end
	end

	if framework == "es_extended" or framework == "auto" then
		local esxPlayer = DTreeFw.getESXPlayer(playerId)
		if esxPlayer then
			if esxPlayer.getName then
				data.playerName = esxPlayer.getName()
				data.firstName = esxPlayer.get("firstName") or ""
				data.lastName = esxPlayer.get("lastName") or ""
				data.birthdate = esxPlayer.get("dateofbirth") or ""
				data.gender = esxPlayer.get("sex") or ""
			end

			data.citizenid = esxPlayer.identifier or ""

			if esxPlayer.getAccount then
				local cashAcc = esxPlayer.getAccount("money")
				data.cash = cashAcc and cashAcc.money or 0
				local bankAcc = esxPlayer.getAccount("bank")
				data.bank = bankAcc and bankAcc.money or 0
				local cryptoAcc = esxPlayer.getAccount("crypto")
				data.crypto = cryptoAcc and cryptoAcc.money or 0
			elseif esxPlayer.getMoney then
				data.cash = esxPlayer.getMoney() or 0
			end

			if esxPlayer.job then
				data.job = esxPlayer.job.name or ""
				data.jobGrade = tonumber(esxPlayer.job.grade or 0) or 0
			end

			local ok, status = pcall(function()
				local val = 100
				TriggerEvent("esx_status:getStatus", playerId, "hunger", function(status) if status then val = status.val end end)
				return val
			end)
			if ok then
				data.hunger = status
			end

			return data
		end
	end

	return data
end

function DTreeFw.getIdentifier(playerId)
	local data = DTreeFw.getPlayerStateData(playerId)
	if data and data.citizenid and data.citizenid ~= "" then
		return data.citizenid
	end
	
	for i = 0, GetNumPlayerIdentifiers(playerId) - 1 do
		local id = GetPlayerIdentifier(playerId, i)
		if string.find(id, "license:") then
			return id
		end
	end
	
	return "license:" .. tostring(playerId)
end
