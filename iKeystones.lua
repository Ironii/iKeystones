local addon = CreateFrame('Frame');
addon:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)
addon:RegisterEvent('ADDON_LOADED')
addon:RegisterEvent('CHALLENGE_MODE_MAPS_UPDATE')
addon:RegisterEvent('PLAYER_LOGIN')
addon:RegisterEvent('BAG_UPDATE')
addon:RegisterEvent('CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN')

--Chat events
addon:RegisterEvent('CHAT_MSG_INSTANCE')
addon:RegisterEvent('CHAT_MSG_INSTANCE_LEADER')
addon:RegisterEvent('CHAT_MSG_PARTY')
addon:RegisterEvent('CHAT_MSG_PARTY_LEADER')
addon:RegisterEvent('CHAT_MSG_RAID')
addon:RegisterEvent('CHAT_MSG_RAID_LEADER')
addon:RegisterEvent('CHAT_MSG_GUILD')
addon:RegisterEvent('CHAT_MSG_GUILD_LEADER')
addon:RegisterEvent('CHAT_MSG_OFFICER')


local iKS = {}
iKS.frames = {}
local player = UnitGUID('player')
iKS.currentMax = 15
iKS.weeklyChestItemLevels = {
	[2] = 905,
	[3] = 910,
	[4] = 915,
	[5] = 920,
	[6] = 920,
	[7] = 925,
	[8] = 925,
	[9] = 930,
	[10] = 935,
	[11] = 940,
	[12] = 945,
	[13] = 950,
	[14] = 955,
	[15] = 960,
}
iKS.itemLevels = {
	[2] = 890,
	[3] = 890,
	[4] = 895,
	[5] = 900,
	[6] = 905,
	[7] = 905,
	[8] = 910,
	[9] = 910,
	[10] = 915,
	[11] = 920,
	[12] = 925,
	[13] = 930,
	[14] = 935,
	[15] = 940,
}
iKS.apFromDungeons = {
	[1] = { -- Lesser
		['p'] = 175, -- Lesser Pathfinder's Symbol
		['a'] = 290, -- Lesser Adventurer's Symbol
		['h'] = 325, -- Lesser Hero's Symbol
		['c'] = 465, -- Lesser Champion's Symbol
		['m'] = 725, -- Lesser Master's Symbol
		['b'] = 50, -- Lesser Adept's Spoils
	},
	[2] = { -- Normal
		['p'] = 300, -- Pathfinder's Symbol
		['a'] = 475, -- Adventurer's Symbol
		['h'] = 540, -- Hero's Symbol
		['c'] = 775, -- Champion's Symbol
		['m'] = 1200, -- Master's Symbol
		['b'] = 100, -- Adept's Spoils
	},
	[3] = { -- Greater
		['p'] = 375, -- Greater Pathfinder's Symbol
		['a'] = 600, -- Greater Adventurer's Symbol
		['h'] = 675, -- Greater Hero's Symbol
		['c'] = 1000, -- Greater Champion's Symbol
		['m'] = 1500, -- Greater Master's Symbol
		['b'] = 125, -- Greater Adept's Spoils
	},
	dif = {
		[197] = 2, -- Eye of Azhara
		[198] = 2, -- Darkhearth Thicket
		[199] = 2, -- Blackrook Hold
		[200] = 3, -- Halls of Valor
		[206] = 2, -- Neltharion's Lair
		[207] = 2, -- Vault of the Wardens
		[208] = 1, -- Maw of Souls
		[209] = 3, -- The Arcway
		[210] = 2, -- Court of Stars
		[227] = 2, -- Return to Karazhan: Lower
		[233] = 2, -- Cathedral of Eternal Night
		[234] = 2, -- Return to Karazhan: Upper
		[239] = 2, -- The Seat of the Triumvirate
	},
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
	[239] = 1753, -- The Seat of the Triumvirate
}
--[[ Current affixes
Level4:
Bolstering 7
Raging 6
Sanguine 8
Teeming 5
Bursting 11

Level7:
Necrotic 4
Skittish 2
Volcanic 3
Explosive 13
Quaking 14
Grievous 12

Level10:
Fortified 10
Tyrannical 9
--]]
iKS.affixCycles = {
	{6,3,9}, -- Raging, Volcanic, Tyrannical
	{5,13,10}, -- Teeming, Explosive, Fortified
	{7,12,9}, -- Bolstering, Grievous, Tyrannical
	{8,3,10}, -- Sanguine, Volcanic, Fortified
	{11,2,9}, -- Bursting, Skittish, Tyrannical
	{5,14,10}, -- Teeming, Quaking, Fortified
	{6,4,9}, -- Raging, Necrotic, Tyrannical
	{7,2,10}, -- Bolstering, Skittish, Fortified
	{5,3,9}, -- Teeming, Volanic, Tyrannical
	{8,12,10}, -- Sanguine, Grievous, Fortified
	{7,13,9}, -- Bolstering, Explosive, Tyrannical
	{11,14,10}, -- Bursting, Quaking, Fortified
}
iKS.akMod = 630000100/100

function iKS:getAP(level, map, current, onlyNumber)
	if level and map then
		local dif = iKS.apFromDungeons.dif[map] or 2 -- default to normal
		if level >= 15 then
			ap = (iKS.apFromDungeons[dif].m+(level-15)*iKS.apFromDungeons[dif].b)*iKS.akMod
		elseif level >= 10 then
			ap = (iKS.apFromDungeons[dif].c+(level-10)*iKS.apFromDungeons[dif].b)*iKS.akMod
		elseif level >= 7 then
			ap = iKS.apFromDungeons[dif].h*iKS.akMod
		elseif level >= 4 then
			ap = iKS.apFromDungeons[dif].a*iKS.akMod
		else
			ap = iKS.apFromDungeons[dif].p*iKS.akMod
		end
		if onlyNumber then
			return ap/1e9
		else
			return string.format('%.2fB', ap/1e9)
		end
	elseif level then
		local ap
		if level >= 15 then
			ap = (5000+(level-15)*400)*iKS.akMod
		elseif level >= 10 then
			ap = (3125+(level-10)*400)*iKS.akMod
		elseif level >= 7 then
			ap = 2150*iKS.akMod
		elseif level >= 4 then
			ap = 1925*iKS.akMod
		elseif level > 0 then
			ap = 1250*iKS.akMod
		end
		if onlyNumber then
			return ap and ap/1e9 or 0
		else
			return ap and (string.format('%.2fB', ap/1e9)) or '-'
		end
	else
		if onlyNumber then
			return 0
		else
			return '-'
		end
	end
end
function iKS:weeklyReset()
	for guid,data in pairs(iKeystonesDB) do
		if iKeystonesDB[guid].maxCompleted and iKeystonesDB[guid].maxCompleted > 0 then
			iKeystonesDB[guid].canLoot = true
		end
		iKeystonesDB[guid].key = {}
		iKeystonesDB[guid].maxCompleted = 0
	end
	iKeystonesConfig.aff = {
		aff4 = {
			a = 0,
			t = false,
		},
		aff7 = {
			a = 0,
			t = false,
		},
		aff10 = {
			a = 0,
			t = false,
		},
	}
	iKS:scanInventory()
	addon:RegisterEvent('QUEST_LOG_UPDATE')
end
function iKS:createPlayer()
	if player and not iKeystonesDB[player] then
		if UnitLevel('player') >= 110 and not iKeystonesConfig.ignoreList[player] then
			iKeystonesDB[player] = {
				name = UnitName('player'),
				server = GetRealmName(),
				class = select(2, UnitClass('player')),
				maxCompleted = 0,
				key = {},
				canLoot = false,
				faction = UnitFactionGroup('player'),
			}
			return true
		else
			return false
		end
	elseif player and iKeystonesDB[player] then
		iKeystonesDB[player].name = UnitName('player') -- fix for name changing
		iKeystonesDB[player].faction = UnitFactionGroup('player') -- faction change (tbh i think guid would change) and update old DB
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
				local map, keyLevel, l4,l7,l10 = string.match(itemLink, 'keystone:(%d+):(%d+):(%d+):(%d+):(%d+)')
				l4 = tonumber(l4)
				l7 = tonumber(l7)
				l10 = tonumber(l10)
				iKS:checkAffs(l4,l7,l10,true)
				iKeystonesDB[player].key = {
					['map'] = tonumber(map),
					['level'] = tonumber(keyLevel),
					['affix4'] = l4,
					['affix7'] = l7,
					['affix10'] = l10,
				}
				keyLevel = tonumber(keyLevel)
				if iKS.keyLevel and iKS.keyLevel < keyLevel then
					local itemLink = string.format('%s|Hkeystone:%d:%d:%d:%d:%d|h[%s (%s)]|h|r', iKS:getItemColor(keyLevel), map, keyLevel, l4, l7, l10,iKS:getZoneInfo(map), keyLevel)
					print('iKS: New keystone - ' .. itemLink)
				end
				iKS.keyLevel = keyLevel
				iKS.mapID = iKeystonesDB[player].key.map
				return
			end
		end
	end
end
function iKS:checkAffs(aff4,aff7,aff10,trusted)
	if trusted then
		if aff4 > 0 then
			iKeystonesConfig.aff.aff4 = {
				a = aff4,
				t = true,
			}
		end
		if aff7 > 0 then
			iKeystonesConfig.aff.aff7 = {
				a = aff7,
				t = true,
			}
		end
		if aff10 > 0 then
			iKeystonesConfig.aff.aff10 = {
				a = aff10,
				t = true,
			}
		end
	else
		if iKeystonesConfig.aff.aff4.a == 0 and not iKeystonesConfig.aff.aff4.t then
			iKeystonesConfig.aff.aff4.a = aff4
		end
		if iKeystonesConfig.aff.aff7.a == 0 and not iKeystonesConfig.aff.aff7.t then
			iKeystonesConfig.aff.aff7.a = aff7
		end
		if iKeystonesConfig.aff.aff10.a == 0 and not iKeystonesConfig.aff.aff10.t then
			iKeystonesConfig.aff.aff10.a = aff10
		end
	end
end
function iKS:getItemColor(level)
	if level < 4 then	-- Epic
		return '|cffa335ee'
	elseif level < 7 then	-- Green
		return '|cff3fbf3f'
	elseif level < 10 then	-- Yellow
		return '|cffffd100'
	elseif level < 15 then	-- orange
		return '|cffff7f3f'
	else -- Red
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
			itemLink = string.format('%s|Hkeystone:%d:%d:%d:%d:%d|h[%s (%s)]|h|r', iKS:getItemColor(data.key.level), data.key.map, data.key.level, data.key.affix4, data.key.affix7, data.key.affix10,iKS:getZoneInfo(data.key.map), data.key.level)
		else
			itemLink = UNKNOWN
		end
		local str = ''
		if data.server == GetRealmName() then
			str = string.format('|c%s%s\124r: %s M:%s', RAID_CLASS_COLORS[data.class].colorStr, data.name, itemLink, (data.maxCompleted >= iKS.currentMax and '|cff00ff00' .. data.maxCompleted) or data.maxCompleted)
		else
			str = string.format('|c%s%s-%s\124r: %s M:%s', RAID_CLASS_COLORS[data.class].colorStr, data.name, data.server,itemLink,(data.maxCompleted >= iKS.currentMax and '|cff00ff00' .. data.maxCompleted) or data.maxCompleted)
		end
		if data.maxCompleted > 0 then
			str = str.. string.format('|r (%d) AP: %s', iKS.weeklyChestItemLevels[data.maxCompleted] or iKS.weeklyChestItemLevels[iKS.currentMax], iKS:getAP(data.maxCompleted))
		end
		print(str)
	end
end
function iKS:PasteKeysToChat(all,channel)
	if all then -- All keys for this faction
		local i = 0
		local str = ''
		local faction = UnitFactionGroup('player')
		local msgs = {}
		for guid,data in pairs(iKeystonesDB) do
			if i == 3 then
				SendChatMessage(str, channel)
				str = ''
				i = 0
			end
			if data.faction == faction then
				if i > 0 then
					str = str .. ' - '
				end
				local itemLink = ''
				if data.key.map then
					itemLink = string.format('%s (%s)', iKS:getZoneInfo(data.key.map), data.key.level)
				else
					itemLink = UNKNOWN
				end
				str = str..string.format('%s: %s', data.name, itemLink)
				i = i + 1
			end
		end
		SendChatMessage(str, channel)
	else -- Only this char
		local data = iKeystonesDB[player]
		if data then
			if data.key.map then
				itemLink = string.format('%s|Hkeystone:%d:%d:%d:%d:%d|h[%s (%s)]|h|r', iKS:getItemColor(data.key.level), data.key.map, data.key.level, data.key.affix4, data.key.affix7, data.key.affix10,iKS:getZoneInfo(data.key.map), data.key.level)
			else
				itemLink = UNKNOWN
			end
			SendChatMessage(itemLink, channel)
		end
	end
end
function iKS:help()
	print([[iKeystones:
/iks reset - reset all characters
/iks start (s) - start dungeon
/iks next (n) - print affixes for next reset
/iks ignore (i) - ignore this character
/iks whitelist (w) - enable tracking for this character (remove ignore)
/iks help (h) - show this help
/iks delete (d) characterName serverName - delete specific character]])
end
function addon:PLAYER_LOGIN()
	player = UnitGUID('player')
	C_ChallengeMode.RequestMapInfo()
	iKS:scanInventory()
	if iKeystonesDB[player] and iKeystonesDB[player].canLoot then
		addon:RegisterEvent('QUEST_LOG_UPDATE')
	elseif not IsQuestFlaggedCompleted(44554) then
		addon:RegisterEvent('ADDON_LOADED')
	end
	GarrisonLandingPageMinimapButton:HookScript('OnEnter', function()
		if IsShiftKeyDown() then
			iKS:createMainWindow()
		else
			GameTooltip:AddLine('Shift-Hover to show iKeystones')
		end
		GameTooltip:Show() -- force refresh to resize
	end)
	GarrisonLandingPageMinimapButton:HookScript('OnLeave', function()
		if iKS.anchor then
			iKS.anchor:Hide()
		end
	end)
end
function addon:ADDON_LOADED(addonName)
	if addonName == 'iKeystones' then
		addon:UnregisterEvent('ADDON_LOADED')
		iKeystonesDB = iKeystonesDB or {}
		iKeystonesConfig = iKeystonesConfig or {}
		if not iKeystonesConfig.ignoreList then
			iKeystonesConfig.ignoreList = {}
		end
		if not iKeystonesConfig.aff then
			iKeystonesConfig.aff = {
				aff4 = {
					a = 0,
					t = false,
				},
				aff7 = {
					a = 0,
					t = false,
				},
				aff10 = {
					a = 0,
					t = false,
				},
			}
		end
		if iKeystonesConfig.ak then -- remove old ak stuff from wtf file
			iKeystonesConfig.ak = nil
		end
	elseif addonName == 'Blizzard_ChallengesUI' then
		addon:UnregisterEvent('ADDON_LOADED')
		local q = C_ChallengeMode.IsWeeklyRewardAvailable()
		iKeystonesDB[player].canLoot = q
		if q then
			addon:RegisterEvent('QUEST_LOG_UPDATE')
		end
	end
end
function addon:BAG_UPDATE()
	iKS:scanInventory()
end
function addon:CHALLENGE_MODE_MAPS_UPDATE()
	iKS:scanCharacterMaps()
end
function addon:QUEST_LOG_UPDATE()
	if IsQuestFlaggedCompleted(44554) then
		iKeystonesDB[player].canLoot = false
		addon:UnregisterEvent('QUEST_LOG_UPDATE')
	end
end
local function ChatHandling(msg, channel)
	if msg and (string.lower(msg) == '.allkeys' or string.lower(msg) == '.keys') then
		if string.lower(msg) == '.allkeys' then
			iKS:PasteKeysToChat(true,channel)
		else
			iKS:PasteKeysToChat(false,channel)
		end
	end
end
function addon:CHAT_MSG_GUILD(msg)
	ChatHandling(msg, 'guild')
end
function addon:CHAT_MSG_GUILD_LEADER(msg)
	ChatHandling(msg, 'guild')
end
function addon:CHAT_MSG_OFFICER(msg)
	ChatHandling(msg, 'officer')
end
function addon:CHAT_MSG_INSTANCE(msg)
	ChatHandling(msg, 'instance')
end
function addon:CHAT_MSG_INSTANCE_LEADER(msg)
	ChatHandling(msg, 'instance')
end
function addon:CHAT_MSG_PARTY(msg)
	ChatHandling(msg, 'party')
end
function addon:CHAT_MSG_PARTY_LEADER(msg)
	ChatHandling(msg, 'party')
end
function addon:CHAT_MSG_RAID(msg)
	ChatHandling(msg, 'raid')
end
function addon:CHAT_MSG_RAID_LEADER(msg)
	ChatHandling(msg, 'raid')
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
	if event == 'CHAT_MSG_LOOT' then
		local linkStart = msg:find('Hitem:138019')
		if linkStart then
			local preLink = msg:sub(1, linkStart-12)
			local linkStuff = msg:sub(math.max(linkStart-11, 0))
			local tempTable = {strsplit(':', linkStuff)}
			tempTable[1] = iKS:getItemColor(tonumber(tempTable[16])) .. '|Hitem'
			for k,v in pairs(tempTable) do
				if v and v:match('%[.-%]') then
					tempTable[k] = string.gsub(tempTable[k], '%[.-%]', string.format('[%s (%s)]',iKS:getZoneInfo(tonumber(tempTable[15])), tonumber(tempTable[16]), tonumber(tempTable[16])), 1)
					break
				end
			end
			return false, preLink..table.concat(tempTable, ':'), ...
		end
	else
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
			local _, _, aff4,aff7,aff10 = string.match(linkStuff, 'keystone:(%d+):(%d+):(%d+):(%d+):(%d+)')
			iKS:checkAffs(tonumber(aff4),tonumber(aff7),tonumber(aff10))
			local fullString = table.concat(tempTable, ':')
			fullString = string.gsub(fullString, '%[.-%]', string.format('[%s (%s)]',iKS:getZoneInfo(tonumber(tempTable[2])), tonumber(tempTable[3])), 1)
			return false, preLink..fullString, ...
		end
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
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", chatFiltering)
ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", chatFiltering)

iKS.bd = {
	bgFile = "Interface\\Buttons\\WHITE8x8",
	edgeFile = "Interface\\Buttons\\WHITE8x8",
	edgeSize = 1,
	insets = {
		left = -1,
		right = -1,
		top = -1,
		bottom = -1,
	},
}
function iKS:createNewLine()
	--char -- key -- highest -- ap gain
	iKS.frames[#iKS.frames+1] = {}
	local f = iKS.frames[#iKS.frames]
	f.name = CreateFrame('frame', nil , iKS.anchor)
	f.name:SetSize(100,20)
	f.name:SetBackdrop(iKS.bd)
	f.name:SetBackdropColor(.1,.1,.1,.9)
	f.name:SetBackdropBorderColor(0,0,0,1)
	f.name:SetPoint('TOPLEFT', (#iKS.frames == 1 and iKS.anchor or iKS.frames[#iKS.frames-1].name), 'BOTTOMLEFT', 0,0)

	f.name.text = f.name:CreateFontString()
	f.name.text:SetFont('Interface\\AddOns\\iKeystones\\FiraMono-Regular.otf', 14, 'OUTLINE')
	f.name.text:SetPoint('LEFT', f.name, 'LEFT', 2,0)
	f.name.text:SetText(#iKS.frames == 1 and 'Character' or '')
	f.name.text:Show()

	f.key = CreateFrame('frame', nil , iKS.anchor)
	f.key:SetSize(150,20)
	f.key:SetBackdrop(iKS.bd)
	f.key:SetBackdropColor(.1,.1,.1,.9)
	f.key:SetBackdropBorderColor(0,0,0,1)
	f.key:SetPoint('TOPLEFT', f.name, 'TOPRIGHT', 0,0)

	f.key.text = f.key:CreateFontString()
	f.key.text:SetFont('Interface\\AddOns\\iKeystones\\FiraMono-Regular.otf', 14, 'OUTLINE')
	f.key.text:SetPoint('LEFT', f.key, 'LEFT', 2,0)
	f.key.text:SetText(#iKS.frames == 1 and 'Current key' or '')
	f.key.text:Show()

	f.max = CreateFrame('frame', nil , iKS.anchor)
	f.max:SetSize(50,20)
	f.max:SetBackdrop(iKS.bd)
	f.max:SetBackdropColor(.1,.1,.1,.9)
	f.max:SetBackdropBorderColor(0,0,0,1)
	f.max:SetPoint('TOPLEFT', f.key, 'TOPRIGHT', 0,0)

	f.max.text = f.max:CreateFontString()
	f.max.text:SetFont('Interface\\AddOns\\iKeystones\\FiraMono-Regular.otf', 14, 'OUTLINE')
	f.max.text:SetPoint('CENTER', f.max, 'CENTER', 0,0)
	f.max.text:SetText(#iKS.frames == 1 and 'Max' or '')
	f.max.text:Show()

	f.ilvl = CreateFrame('frame', nil , iKS.anchor)
	f.ilvl:SetSize(50,20)
	f.ilvl:SetBackdrop(iKS.bd)
	f.ilvl:SetBackdropColor(.1,.1,.1,.9)
	f.ilvl:SetBackdropBorderColor(0,0,0,1)
	f.ilvl:SetPoint('TOPLEFT', f.max, 'TOPRIGHT', 0,0)

	f.ilvl.text = f.key:CreateFontString()
	f.ilvl.text:SetFont('Interface\\AddOns\\iKeystones\\FiraMono-Regular.otf', 14, 'OUTLINE')
	f.ilvl.text:SetPoint('CENTER', f.ilvl, 'CENTER', 0,0)
	f.ilvl.text:SetText(#iKS.frames == 1 and 'iLvL' or '')
	f.ilvl.text:Show()

	f.ap = CreateFrame('frame', nil , iKS.anchor)
	f.ap:SetSize(50,20)
	f.ap:SetBackdrop(iKS.bd)
	f.ap:SetBackdropColor(.1,.1,.1,.9)
	f.ap:SetBackdropBorderColor(0,0,0,1)
	f.ap:SetPoint('TOPLEFT', f.ilvl, 'TOPRIGHT', 0,0)

	f.ap.text = f.ap:CreateFontString()
	f.ap.text:SetFont('Interface\\AddOns\\iKeystones\\FiraMono-Regular.otf', 14, 'OUTLINE')
	f.ap.text:SetPoint('CENTER', f.ap, 'CENTER', 0,0)
	f.ap.text:SetText(#iKS.frames == 1 and 'AP' or '')
	f.ap.text:Show()
end
local function reColor(f, faction)
	local r,g,b = .1,.1,.1
	if faction and faction == 'Horde' then
		r = .20
	elseif faction and faction == 'Alliance' then
		b = .20
	end
	f.name:SetBackdropColor(r,g,b,.9)
	f.key:SetBackdropColor(r,g,b,.9)
	f.max:SetBackdropColor(r,g,b,.9)
	f.ilvl:SetBackdropColor(r,g,b,.9)
	f.ap:SetBackdropColor(r,g,b,.9)
end
function iKS:createMainWindow()
	if not iKS.anchor then
		iKS.anchor = CreateFrame('frame', nil, UIParent)
		iKS.anchor:SetSize(5,5)
	end
	iKS.anchor:SetPoint('TOP', UIParent, 'TOP', 0,-50)
	iKS.anchor:Show()
	if #iKS.frames == 0 then
		iKS:createNewLine()
		--Create affix slots
		iKS.affixes = {}
		local f = iKS.affixes
		f.aff4 = CreateFrame('frame', nil , iKS.anchor)
		f.aff4:SetSize(150,20)
		f.aff4:SetBackdrop(iKS.bd)
		f.aff4:SetBackdropColor(.1,.1,.1,.9)
		f.aff4:SetBackdropBorderColor(0,0,0,1)
		--f.aff4:SetPoint('TOPLEFT', iKS.anchor, 'BOTTOMLEFT', 0,0)

		f.aff4.text = f.aff4:CreateFontString()
		f.aff4.text:SetFont('Interface\\AddOns\\iKeystones\\FiraMono-Regular.otf', 14, 'OUTLINE')
		f.aff4.text:SetPoint('CENTER', f.aff4, 'CENTER', 0,0)
		f.aff4.text:SetText('Sanguine')
		--f.aff4.text:Show()

		f.aff7 = CreateFrame('frame', nil , iKS.anchor)
		f.aff7:SetSize(150,20)
		f.aff7:SetBackdrop(iKS.bd)
		f.aff7:SetBackdropColor(.1,.1,.1,.9)
		f.aff7:SetBackdropBorderColor(0,0,0,1)
		f.aff7:SetPoint('TOPLEFT', f.aff4, 'TOPRIGHT', 0,0)

		f.aff7.text = f.aff7:CreateFontString()
		f.aff7.text:SetFont('Interface\\AddOns\\iKeystones\\FiraMono-Regular.otf', 14, 'OUTLINE')
		f.aff7.text:SetPoint('CENTER', f.aff7, 'CENTER', 0,0)
		f.aff7.text:SetText('Volcanic')
		--f.aff7.text:Show()

		f.aff10 = CreateFrame('frame', nil , iKS.anchor)
		f.aff10:SetSize(150,20)
		f.aff10:SetBackdrop(iKS.bd)
		f.aff10:SetBackdropColor(.1,.1,.1,.9)
		f.aff10:SetBackdropBorderColor(0,0,0,1)
		f.aff10:SetPoint('TOPLEFT', f.aff7, 'TOPRIGHT', 0,0)

		f.aff10.text = f.aff10:CreateFontString()
		f.aff10.text:SetFont('Interface\\AddOns\\iKeystones\\FiraMono-Regular.otf', 14, 'OUTLINE')
		f.aff10.text:SetPoint('CENTER', f.aff10, 'CENTER', 0,0)
		f.aff10.text:SetText('Tyrannical')
		--f.aff7.text:Show()
	end
	local i = 1
	local maxSizes = {
		name = 96,
		key = 146,
		ap = 46,
	}
	local treasure = '|TInterface\\Icons\\inv_misc_treasurechest02b:16|t'
	for k,v in pairs(iKeystonesDB) do
		i = i + 1
		if not iKS.frames[i] then
			iKS:createNewLine()
		end
		local f = iKS.frames[i]
		if v.server == GetRealmName() then
			f.name.text:SetText(string.format('%s|c%s%s\124r', (v.canLoot and treasure or ''),RAID_CLASS_COLORS[v.class].colorStr, v.name))
		else
			f.name.text:SetText(string.format('%s|c%s%s\124r - %s',(v.canLoot and treasure or ''),RAID_CLASS_COLORS[v.class].colorStr, v.name, v.server))
		end
		f.key.text:SetText(v.key.level and string.format('%s%s (%s)|r', iKS:getItemColor(v.key.level), iKS:getZoneInfo(v.key.map), v.key.level) or '-')
		f.max.text:SetText((v.maxCompleted >= iKS.currentMax and '|cff00ff00' .. v.maxCompleted) or (v.maxCompleted > 0 and v.maxCompleted) or '-')
		f.ilvl.text:SetText(v.maxCompleted > 0 and (iKS.weeklyChestItemLevels[v.maxCompleted] or iKS.weeklyChestItemLevels[iKS.currentMax]) or '-')
		f.ap.text:SetText(iKS:getAP(v.maxCompleted))
		if f.name.text:GetWidth() > maxSizes.name then
			maxSizes.name = f.name.text:GetWidth()
		end
		if f.key.text:GetWidth() > maxSizes.key then
			maxSizes.key = f.key.text:GetWidth()
		end
		if f.ap.text:GetWidth() > maxSizes.ap then
			maxSizes.ap = f.ap.text:GetWidth()
		end
		reColor(f, v.faction)
		f.name:Show()
		f.key:Show()
		f.max:Show()
		f.ilvl:Show()
		f.ap:Show()
	end
	for id = 1, i do
		local f = iKS.frames[id]
		f.name:SetWidth(maxSizes.name+4)
		f.key:SetWidth(maxSizes.key+4)
		f.ap:SetWidth(maxSizes.ap+4)
	end
	for j = i+1, #iKS.frames do
		local f = iKS.frames[j]
		f.name:Hide()
		f.key:Hide()
		f.max:Hide()
		f.ilvl:Hide()
		f.ap:Hide()
	end
	local w = maxSizes.name+maxSizes.key+maxSizes.ap+100 --+max(50)+ilvl(50)
	iKS.anchor:SetWidth(w)

	iKS.affixes.aff4:ClearAllPoints()
	iKS.affixes.aff4:SetPoint('TOPLEFT', iKS.frames[i].name, 'BOTTOMLEFT', 0,0)
	iKS.affixes.aff4:SetWidth(w/3)
	iKS.affixes.aff4.text:SetText(C_ChallengeMode.GetAffixInfo(iKeystonesConfig.aff.aff4.a) or UNKNOWN)

	iKS.affixes.aff10:SetWidth(w/3)
	iKS.affixes.aff10:ClearAllPoints()
	iKS.affixes.aff10:SetPoint('TOPRIGHT', iKS.frames[i].ap, 'BOTTOMRIGHT', 0,0)
	iKS.affixes.aff10.text:SetText(C_ChallengeMode.GetAffixInfo(iKeystonesConfig.aff.aff10.a) or UNKNOWN)

	iKS.affixes.aff7:ClearAllPoints()
	iKS.affixes.aff7:SetPoint('LEFT', iKS.affixes.aff4, 'RIGHT', 0,0)
	iKS.affixes.aff7:SetPoint('RIGHT', iKS.affixes.aff10, 'LEFT', 0,0)
	iKS.affixes.aff7.text:SetText(C_ChallengeMode.GetAffixInfo(iKeystonesConfig.aff.aff7.a) or UNKNOWN)
end
function iKS:addToTooltip(self, map, keyLevel)
	map = tonumber(map)
	keyLevel = tonumber(keyLevel)
	self:AddLine(' ')
	self:AddDoubleLine(string.format('Items: %s |cff00ff00+1|r', (keyLevel > iKS.currentMax and 2+(keyLevel-iKS.currentMax)*.4 or 2)), 'ilvl: ' .. (iKS.itemLevels[keyLevel] or iKS.itemLevels[iKS.currentMax]))
	if keyLevel > iKeystonesDB[player].maxCompleted then
		local weeklyDif = iKS:getAP(keyLevel, nil, nil, true) - iKS:getAP(iKeystonesDB[player].maxCompleted, nil, nil, true)
		self:AddDoubleLine(string.format('AP: |cff00ff00%.2f|rB', iKS:getAP(keyLevel, map,nil,true)), string.format('Weekly: |cff00ff00+%.2f|rB', weeklyDif))
	else
		self:AddLine(string.format('AP: |cff00ff00%.2f|rB', iKS:getAP(keyLevel, map,nil,true)))
	end
end
local function gameTooltipScanning(self)
	local itemName, itemLink = self:GetItem()
	if not (itemLink and itemLink:find('Hkeystone')) then
		return
	end
	local map, keyLevel, l4,l7,l10 = string.match(itemLink, 'keystone:(%d+):(%d+):(%d+):(%d+):(%d+)')
	iKS:addToTooltip(self, map, keyLevel)
end
local function itemRefScanning(self)
	local itemName, itemLink = self:GetItem()
	if not (itemLink and itemLink:find('Hitem:138019')) then
		return
	end
	local tempTable = {strsplit(':', itemLink)}
	local map = tempTable[15]
	local level = tempTable[16]
	iKS:addToTooltip(self, map, level)
end
GameTooltip:HookScript('OnTooltipSetItem', gameTooltipScanning)
ItemRefTooltip:HookScript('OnTooltipSetItem', itemRefScanning)

SLASH_IKEYSTONES1 = "/ikeystones"
SLASH_IKEYSTONES2 = "/iks"
SlashCmdList["IKEYSTONES"] = function(msg)
	if msg and msg:len() > 0 then
		msg = string.lower(msg)
		if msg == 'reset' then
			iKeystonesDB = nil
			iKeystonesDB = {}
			iKS:scanInventory()
			iKS:scanCharacterMaps()
		elseif msg == 'start' or msg == 's' then
			if C_ChallengeMode.GetSlottedKeystoneInfo() then
				C_ChallengeMode.StartChallengeMode()
			end
		elseif msg == 'force' or msg == 'f' then
			local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
			local bagID, slotID = iKS:scanInventory(true)
			PickupContainerItem(bagID, slotID)
			C_Timer.After(0.1, function()
				if CursorHasItem() then
					C_ChallengeMode.SlotKeystone()
				end
			end)
		elseif msg == 'next' or msg == 'n' then
			for i = 1, #iKS.affixCycles do
				if iKS.affixCycles[i][1] == iKeystonesConfig.aff.aff4.a and iKS.affixCycles[i][2] == iKeystonesConfig.aff.aff7.a and iKS.affixCycles[i][3] == iKeystonesConfig.aff.aff10.a then
					local nextCycle = i+1 <= #iKS.affixCycles and i+1 or 1
					local aff1 = C_ChallengeMode.GetAffixInfo(iKS.affixCycles[nextCycle][1])
					local aff2 = C_ChallengeMode.GetAffixInfo(iKS.affixCycles[nextCycle][2])
					local aff3 = C_ChallengeMode.GetAffixInfo(iKS.affixCycles[nextCycle][3])
					print(string.format('iKS: Next cycle : %s, %s, %s.',aff1, aff2, aff3))
					break
				end
			end
			print(string.format('iKS: Uknown cycle, contact author'))
		elseif msg == 'ignore' or msg == 'i' then
			iKeystonesConfig.ignoreList[player] = true
			iKeystonesDB[player] = nil
			print('iKS: This character will now be ignored.')
		elseif msg == 'whitelist' or msg == 'w' then
			iKeystonesConfig.ignoreList[player] = nil
			iKS:scanCharacterMaps()
			iKS:scanInventory()
			print('iKS: This character is now whitelisted.')
		elseif msg == 'help' or msg == 'h' then
			iKS:help()
		elseif msg:match('delete') or msg:match('d') then
			local _,char,server = msg:match("^(.*) (.*) (.*)$")
			if not (char and server) then
				print('iKS: ' .. msg .. ' is not a valid format, please use /iks delete characterName serverName, eg /iks delete ironi stormreaver')
				return
			end
			for guid,data in pairs(iKeystonesDB) do
				if server == string.lower(data.server) and char == string.lower(data.name) then
					iKeystonesDB[guid] = nil
					print('iKS: Succesfully deleted:' ..char..'-'..server..'.')
					return
				end
			end
			print('iKS: cannot find ' ..char..'-'..server..'.')
		else
			iKS:help()
		end
	else
		iKS:printKeystones()
	end
end
