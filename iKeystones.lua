local addon = CreateFrame('Frame');
addon:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)
addon:RegisterEvent('ADDON_LOADED')
addon:RegisterEvent('CHALLENGE_MODE_MAPS_UPDATE')
addon:RegisterEvent('PLAYER_LOGIN')
addon:RegisterEvent('BAG_UPDATE')
addon:RegisterEvent('CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN')
local iKS = {}
local player = UnitGUID('player')
iKS.weeklyChestItemLevels = {
	[2] = 875,
	[3] = 880,
	[4] = 885,
	[5] = 890,
	[6] = 890,
	[7] = 895,
	[8] = 895,
	[9] = 900,
	[10] = 905,
}
iKS.keystonesToMapIDs = {
	[197] = 1456, -- Eye of Azhara
	[198] = 1466, -- Darkhearth Thicket
	[199] = 1501, -- Blackrook Hold
	[200] = 1477, -- Halls of Valor
	[206] = 1458, -- Neltharion's Lair
	[207] = 1493, -- Vault of the Wardens
	[208] = 1492, -- Maw of Souls
	[209] = 1516, -- The Arcway
	[210] = 1571, -- Court of Stars
	[227] = 1651, -- Return to Karazhan: Lower
	[233] = 1677, -- Cathedral of Eternal Night
	[234] = 1651, -- Return to Karazhan: Upper
}
function iKS:weeklyReset()
	for guid,data in pairs(iKeystonesDB) do
		iKeystonesDB[guid].key = {}
		iKeystonesDB[guid].maxCompleted = 0
	end
	iKS:scanInventory()
end
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
	if iKeystonesDB[player].maxCompleted and iKeystonesDB[player].maxCompleted > maxCompleted then
		iKS:weeklyReset()
	end
	iKeystonesDB[player].maxCompleted = maxCompleted
end
function iKS:scanInventory(requestingSlots)
	if not iKS:createPlayer() then return end
	for bagID = 0, 4 do
		for invID = 1, GetContainerNumSlots(bagID) do
			local itemID = GetContainerItemID(bagID, invID)
			if itemID and itemID == 138019 then
				if requestingSlots then
					return bagID, invID
				end
				local itemLink = GetContainerItemLink(bagID, invID)
				-- debug
				--tempKeyTable = {strsplit(':', itemLink)}
				--iKeystoneT = tempKeyTable
				-- end-of-debug
				-- mapid, level,1 active/0 depleted,level4, level7, level10(?) 
				local map, keyLevel, d, l4,l7,l10 = string.match(itemLink, 'keystone:(%d+):(%d+):(%d+):(%d+):(%d+):(%d+)')
				iKeystonesDB[player].key = {
					['map'] = tonumber(map),
					['level'] = tonumber(keyLevel),
					['depleted'] = tonumber(d),
					['affix4'] = tonumber(l4),
					['affix7'] = tonumber(l7),
					['affix10'] = tonumber(l10),
				}
				keyLevel = tonumber(keyLevel)
				if iKS.keyLevel and iKS.keyLevel < keyLevel then
					local itemLink = string.format('%s|Hkeystone:%d:%d:%d:%d:%d:%d|h[%s (%s)]|h|r', iKS:getItemColor(data.key.level, data.key.depleted), data.key.map, data.key.level,data.key.depleted, data.key.affix4, data.key.affix7, data.key.affix10,iKS:getZoneInfo(data.key.map), data.key.level)
					print('iKS: New keystone - ' .. itemLink)
				end
				iKS.keyLevel = keyLevel
				iKS.mapID = iKeystonesDB[player].key.map
				return
			end
		end
	end
	
end
function iKS:getItemColor(level, depleted)
	if depleted == 4063232 then
		return '|cff9d9d9d'
	elseif level < 4 then	-- Epic
		return '|cffa335ee'
	elseif level < 7 then	-- Green
		return '|cff3fbf3f'
	elseif level < 10 then	-- Yellow
		return '|cffffd100'
	elseif level < 15 then	-- orange
		return '|cffff7f3f'
	else	-- Red
		return '|cffff1919'
	end	
end
function iKS:getZoneInfo(mapID, zone)
	local name, arg2, timelimit = C_ChallengeMode.GetMapInfo(mapID)
	if zone then
		return iKS.keystonesToMapIDs[mapID]
		
	else
		return name
	end
end
function iKS:printKeystones()
	local allCharacters = {}
	for guid,data in pairs(iKeystonesDB) do
		local itemLink = ''
		if data.key.map then
			itemLink = string.format('%s|Hkeystone:%d:%d:%d:%d:%d:%d|h[%s (%s)]|h|r', iKS:getItemColor(data.key.level, data.key.depleted), data.key.map, data.key.level,data.key.depleted, data.key.affix4, data.key.affix7, data.key.affix10,iKS:getZoneInfo(data.key.map), data.key.level)
		else
			itemLink = UNKNOWN
		end
		local str = ''
		if data.server == GetRealmName() then
			str = string.format('|c%s%s\124r: %s M:%s', RAID_CLASS_COLORS[data.class].colorStr, data.name, itemLink, (data.maxCompleted >= 10 and '|cff00ff00' .. data.maxCompleted) or data.maxCompleted)
		else
			str = string.format('|c%s%s-%s\124r: %s M:%s', RAID_CLASS_COLORS[data.class].colorStr, data.name, data.server,itemLink,(data.maxCompleted >= 10 and '|cff00ff00' .. data.maxCompleted) or data.maxCompleted)
		end
		if data.maxCompleted > 0 then
			str = str.. string.format('|r (%d)', iKS.weeklyChestItemLevels[data.maxCompleted] or 905)
		end
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
function addon:CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN()
	local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
	if iKS.mapID and iKS.keystonesToMapIDs[iKS.mapID] == mapID then
		local bagID, slotID = iKS:scanInventory(true)
		PickupContainerItem(bagID, slotID)
		C_Timer.After(0.1, function()
			if CursorHasItem() then
				C_ChallengeMode.SlotKeystone()
			end
		end)
	end
end

local function chatFiltering(self, event, msg, ...)
	local linkStart = msg:find('Hkeystone')
	if linkStart then
		if event == 'CHAT_MSG_BN_WHISPER_INFORM' or event == "CHAT_MSG_BN_WHISPER" then
			linkStart = linkStart + 10
			msg = msg:gsub('|Hkeystone:', '|cffa335ee|Hkeystone:')
			local m = msg:sub(math.max(linkStart-1, 0))
			local keystoneName = m:match('%[(.-)%]')
			msg = msg:gsub(keystoneName..'%]|h', keystoneName..']|h|r', 1)
		end
		local preLink = msg:sub(1, linkStart-12)
		local linkStuff = msg:sub(math.max(linkStart-11, 0))
		local tempTable = {strsplit(':', linkStuff)}
		tempTable[1] = iKS:getItemColor(tonumber(tempTable[3]), tonumber(tempTable[4])) .. '|Hkeystone'
		local fullString = table.concat(tempTable, ':')
		fullString = string.gsub(fullString, '%[.-%]', string.format('[%s (%s)]',iKS:getZoneInfo(tonumber(tempTable[2])), tonumber(tempTable[3])), 1)
		return false, preLink..fullString, ...
	end
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD_LEADER", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_OFFICER", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_LEADER", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", chatFiltering)

SLASH_IKEYSTONES1 = "/ikeystones"
SLASH_IKEYSTONES2 = "/iks"
SlashCmdList["IKEYSTONES"] = function(msg)
	if msg and msg == 'reset' then
		iKeystonesDB = nil
		iKeystonesDB = {}
		iKS:scanInventory()
		iKS:scanCharacterMaps()
	elseif msg and msg == 'start' then
		if C_ChallengeMode.GetSlottedKeystoneInfo() then
			C_ChallengeMode.StartChallengeMode()
		end
	else
		iKS:printKeystones()
	end
end