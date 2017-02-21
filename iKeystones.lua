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
	[2] = 850,
	[3] = 855,
	[4] = 860,
	[5] = 865,
	[6] = 865,
	[7] = 870,
	[8] = 870,
	[9] = 875,
	[10] = 880,
	[11] = 880,
	[12] = 885,
	[13] = 890,
	[14] = 895,
	[15] = 900,
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
				local tempTable = {strsplit(':', itemLink)}
				-- debug
				--tempKeyTable = {strsplit(':', itemLink)}
				--iKeystoneT = tempKeyTable
				-- end-of-debug
				local keyLevel = tonumber(tempTable[16])
				iKeystonesDB[player].key = {
					map = tonumber(tempTable[15]),
					level = keyLevel,
					--depleted = (tonumber(tempTable[12]) == 4063232 and true) or nil, -- 4063232 == depleted, 8257536 active
					depleted = tonumber(tempTable[12]),
					affix4 = tonumber(tempTable[17]),
					affix7 = tonumber(tempTable[18]),
					affix10 = tonumber(tempTable[19]),
					arg20 = tonumber(tempTable[20]), -- some kind of depleted check ??
				}
				if iKS.keyLevel and iKS.keyLevel < keyLevel then
					local itemLinkTable = {
						[1] = iKS:getItemColor(iKeystonesDB[player].key.level, iKeystonesDB[player].key.depleted),
						[2] = 138019,
						[10] = 110,
						[11] = 250,
						[12] = iKeystonesDB[player].key.depleted,
						[15] = iKeystonesDB[player].key.map,
						[16] = iKeystonesDB[player].key.level,
						[17] = iKeystonesDB[player].key.affix4,
						[18] = iKeystonesDB[player].key.affix7,
						[19] = iKeystonesDB[player].key.affix10,
						[20] = iKeystonesDB[player].key.arg20,
						[23] = string.format('|h[%s (%s)]|h|r',GetRealZoneText(iKeystonesDB[player].key.map), iKeystonesDB[player].key.level),
					}
					for i = 1, 22 do
						if not itemLinkTable[i] then
							itemLinkTable[i] = ''
						end
					end
					local itemLinkToPrint = table.concat(itemLinkTable, ':')
					print('iKS: New keystone - ' .. itemLinkToPrint)
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
		return '|cff9d9d9d|Hitem'
	elseif level < 4 then	-- Epic
		return '|cffa335ee|Hitem'
	elseif level < 7 then	-- Green
		return '|cff3fbf3f|Hitem'
	elseif level < 10 then	-- Yellow
		return '|cffffd100|Hitem'
	elseif level < 15 then	-- orange
		return '|cffff7f3f|Hitem'
	else	-- Red
		return '|cffff1919|Hitem'
	end	
end
function iKS:printKeystones()
	local allCharacters = {}
	for guid,data in pairs(iKeystonesDB) do
		local itemLink = ''
		if data.key.map then
			local itemLinkTable = {
				[1] = iKS:getItemColor(data.key.level, data.key.depleted),
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
			itemLink = UNKNOWN
		end
		local str = ''
		if data.server == GetRealmName() then
			str = string.format('|c%s%s\124r: %s M:%s', RAID_CLASS_COLORS[data.class].colorStr, data.name, itemLink, (data.maxCompleted >= 15 and '|cff00ff00' .. data.maxCompleted) or data.maxCompleted)
		else
			str = string.format('|c%s%s-%s\124r: %s M:%s', RAID_CLASS_COLORS[data.class].colorStr, data.name, data.server,itemLink,(data.maxCompleted >= 15 and '|cff00ff00' .. data.maxCompleted) or data.maxCompleted)
		end
		if data.maxCompleted > 0 then
			str = str.. string.format('|r (%d)', iKS.weeklyChestItemLevels[data.maxCompleted] or 900)
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
	if iKS.mapID and iKS.mapID == mapID then
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
	local linkStart = msg:find('Hitem:138019')
	if linkStart then
		local preLink = msg:sub(1, linkStart-12)
		local linkStuff = msg:sub(math.max(linkStart-11, 0))
		local tempTable = {strsplit(':', linkStuff)}
		tempTable[1] = iKS:getItemColor(tonumber(tempTable[16]), tonumber(tempTable[12]))
		for k,v in pairs(tempTable) do
			if v and v:match('%[.-%]') then
				tempTable[k] = string.gsub(tempTable[k], '%[.-%]', string.format('[%s (%s)]',GetRealZoneText(tonumber(tempTable[15])), tonumber(tempTable[16])), 1)
				break
			end
		end
		return false, preLink..table.concat(tempTable, ':'), ...
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