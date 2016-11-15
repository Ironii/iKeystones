local addon = CreateFrame('Frame');
addon:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)
addon:RegisterEvent('ADDON_LOADED')
addon:RegisterEvent('CHALLENGE_MODE_MAPS_UPDATE')
addon:RegisterEvent('PLAYER_LOGIN')
addon:RegisterEvent('BAG_UPDATE')
local iKS = {}
local player = UnitGUID('player')
function iKS:createPlayer()
	if player and not iKeystonesDB[player] then
		if UnitLevel('player') >= 110 then
			iKeystonesDB[player] = {
				name = UnitName('player'),
				server = GetRealmName(),
				class = select(2, UnitClass('player')),
				maxCompleted = 0,
				key = {},
			}
			return true
		else
			return false
		end
	elseif player and iKeystonesDB[player] then
		return true
	else
		return false
	end
end
function iKS:scanCharacterMaps()
	if not iKS:createPlayer() then return end
	local maps = C_ChallengeMode.GetMapTable()
	local maxCompleted = 0
	for _, mapID in pairs(maps) do
		local _, _, level, affixes = C_ChallengeMode.GetMapPlayerStats(mapID)
		if level and level > maxCompleted then
			maxCompleted = level
		end
	end
	iKeystonesDB[player].maxCompleted = maxCompleted
end
function iKS:scanInventory()
	if not iKS:createPlayer() then return end
	for bagID = 0, 4 do
		for invID = 1, GetContainerNumSlots(bagID) do
			local itemID = GetContainerItemID(bagID, invID)
			if itemID and itemID == 138019 then
				local itemLink = GetContainerItemLink(bagID, invID)
				local tempTable = {strsplit(':', itemLink)}
				-- debug
				--tempKeyTable = {strsplit(':', itemLink)}
				--iKeystoneT = tempKeyTable
				-- end-of-debug
				iKeystonesDB[player].key = {
					map = tonumber(tempTable[15]),
					level = tonumber(tempTable[16]),
					--depleted = (tonumber(tempTable[12]) == 4063232 and true) or nil, -- 4063232 == depleted, 8257536 active
					depleted = tonumber(tempTable[12]),
					affix4 = tonumber(tempTable[17]),
					affix7 = tonumber(tempTable[18]),
					affix10 = tonumber(tempTable[19]),
					arg20 = tonumber(tempTable[20]), -- some kind of depleted check ??
				}
				return
			end
		end
	end
	
end
function iKS:printKeystones()
	local allCharacters = {}
	for guid,data in pairs(iKeystonesDB) do
		local itemLink = ''
		if data.key.map then
			local itemLinkTable = {
				[1] = (data.key.depleted == 8257536 and '|cffa335ee|Hitem') or '|cff9d9d9d|Hitem',
				[2] = 138019,
				[10] = 110,
				[11] = 250,
				[12] = data.key.depleted,
				[15] = data.key.map,
				[16] = data.key.level,
				[17] = data.key.affix4,
				[18] = data.key.affix7,
				[19] = data.key.affix10,
				[20] = data.key.arg20,
				[23] = string.format('|h[%s (%s)]|h|r',GetRealZoneText(data.key.map), data.key.level),
			}
			for i = 1, 22 do
				if not itemLinkTable[i] then
					itemLinkTable[i] = ''
				end
			end
			itemLink = table.concat(itemLinkTable, ':')
		else
			itemLink = 'NONE'
		end
		local str = string.format('|c%s%s\124r: %s M:%s', RAID_CLASS_COLORS[data.class].colorStr, data.name, itemLink, data.maxCompleted)
		print(str)
	end
end
function addon:PLAYER_LOGIN()
	player = UnitGUID('player')
	C_ChallengeMode.RequestMapInfo()
	iKS:scanInventory()
end
function addon:ADDON_LOADED(addonName)
	if addonName == 'iKeystones' then
		addon:UnregisterEvent('ADDON_LOADED')
		iKeystonesDB = iKeystonesDB or {}
	end
end
function addon:BAG_UPDATE()
	iKS:scanInventory()
end
function addon:CHALLENGE_MODE_MAPS_UPDATE()
	iKS:scanCharacterMaps()
end

SLASH_IKEYSTONES1 = "/ikeystones"
SLASH_IKEYSTONES2 = "/iks"
SlashCmdList["IKEYSTONES"] = function(msg)
	if msg and msg == 'reset' then
		iKeystonesDB = nil
		iKeystonesDB = {}
		iKS:scanInventory()
		iKS:scanCharacterMaps()
	end
	iKS:printKeystones()
end