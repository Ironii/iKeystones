local addon = CreateFrame('Frame');
addon:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)
addon:RegisterEvent('ADDON_LOADED')
addon:RegisterEvent('CHALLENGE_MODE_MAPS_UPDATE')
addon:RegisterEvent('PLAYER_LOGIN')
addon:RegisterEvent('BAG_UPDATE')
addon:RegisterEvent('CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN')
addon:RegisterEvent('ARTIFACT_UPDATE')
local iKS = {}
iKS.frames = {}
local player = UnitGUID('player')
iKS.currentMax = 10
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
	--[11] = 910,
	--[12] = 915,
	--[13] = 920,
	--[14] = 925,
	--[15] = 930,
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
iKS.akMods = {
	[41] = 16000100,
	[42] = 20800100,
	[43] = 27040100,
	[44] = 35150100,
	[45] = 45700100,
	[46] = 59400100,
	[47] = 77250100,
	[48] = 100400100,
	[49] = 130500100,
	[50] = 169650100,
	[51] = 220550100,
	[52] = 286750100,
	[53] = 372750100,
	[54] = 484600100,
	[55] = 630000100,
}
function iKS:getAP(level)
	if iKeystonesConfig.ak and level then
		local akMod = iKS.akMods[(iKeystonesConfig.ak <55 and iKeystonesConfig.ak+1) or 55]/100
		local ap
		if level >= 15 then
			ap = (5000+(level-15)*400)*akMod
		elseif level >= 10 then
			ap = (3125+(level-10)*400)*akMod
		elseif level >= 7 then
			ap = 2150*akMod
		elseif level >= 4 then
			ap = 1925*akMod
		elseif level > 0 then
			ap = 1250*akMod
		end
		return ap and (string.format('%.2fB', ap/1e9)) or '-'
	else
		return '-'
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
		if UnitLevel('player') >= 110 then
			iKeystonesDB[player] = {
				name = UnitName('player'),
				server = GetRealmName(),
				class = select(2, UnitClass('player')),
				maxCompleted = 0,
				key = {},
				canLoot = false,
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
function addon:PLAYER_LOGIN()
	player = UnitGUID('player')
	C_ChallengeMode.RequestMapInfo()
	iKS:scanInventory()
	if iKeystonesDB[player].canLoot then
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
function addon:ARTIFACT_UPDATE()
    local c = C_ArtifactUI.GetArtifactKnowledgeLevel()
    if c then
		iKeystonesConfig.ak = c
	end
end
function addon:QUEST_LOG_UPDATE()
	if IsQuestFlaggedCompleted(44554) then
		iKeystonesDB[player].canLoot = false
		addon:UnregisterEvent('QUEST_LOG_UPDATE')
	end
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
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", chatFiltering)
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

SLASH_IKEYSTONES1 = "/ikeystones"
SLASH_IKEYSTONES2 = "/iks"
SlashCmdList["IKEYSTONES"] = function(msg)
	if msg and msg == 'reset' then
		iKeystonesDB = nil
		iKeystonesDB = {}
		iKS:scanInventory()
		iKS:scanCharacterMaps()
	elseif msg and (msg == 'start' or msg == 's') then
		if C_ChallengeMode.GetSlottedKeystoneInfo() then
			C_ChallengeMode.StartChallengeMode()
		end
	elseif msg and (msg == 'force' or msg == 'f') then
		local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
		local bagID, slotID = iKS:scanInventory(true)
		PickupContainerItem(bagID, slotID)
		C_Timer.After(0.1, function()
			if CursorHasItem() then
				C_ChallengeMode.SlotKeystone()
			end
		end)
	else
		iKS:printKeystones()
	end
end
