--upvalues
local _sformat, GetQuestObjectiveInfo, IsQuestFlaggedCompleted, _sgsub, _sgmatch, _smatch, _slower, SendChatMessage, _SendAddonMessage = string.format, GetQuestObjectiveInfo, C_QuestLog.IsQuestFlaggedCompleted, string.gsub, string.gmatch, string.match, string.lower, SendChatMessage, C_ChatInfo.SendAddonMessage

local addon = CreateFrame('Frame');
addon:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)
addon:RegisterEvent('ADDON_LOADED')
addon:RegisterEvent('CHALLENGE_MODE_MAPS_UPDATE')
addon:RegisterEvent('PLAYER_LOGIN')
addon:RegisterEvent('CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN')
addon:RegisterEvent('MYTHIC_PLUS_CURRENT_AFFIX_UPDATE')
addon:RegisterEvent('MYTHIC_PLUS_NEW_WEEKLY_RECORD')
addon:RegisterEvent('ITEM_PUSH')
addon:RegisterEvent('BAG_UPDATE')
--addon:RegisterEvent('CRITERIA_UPDATE')
--addon:RegisterEvent('QUEST_LOG_UPDATE')
addon:RegisterEvent('ENCOUNTER_LOOT_RECEIVED')
addon:RegisterEvent('CHAT_MSG_ADDON')
C_ChatInfo.RegisterAddonMessagePrefix('iKeystones')
--C_ChatInfo.RegisterAddonMessagePrefix('AstralKeys') -- AstralKeys guild support
addon:RegisterEvent('CHAT_MSG_PARTY')
addon:RegisterEvent('CHAT_MSG_PARTY_LEADER')

local iKS = {}
iKS.currentMax = 0
iKS.frames = {}
local shouldBeCorrectInfoForWeekly = false
local player = UnitGUID('player')
local unitName = UnitName('player')
local playerFaction = UnitFactionGroup('player')
local maxPlayerLevel = GetMaxLevelForLatestExpansion()
--[[
iKS.apFromDungeons = {
	-- Fast
	[244] = 420, -- Atal'Dazar
	[245] = 420, -- Freehold
	[251] = 420, -- The Underrot

	-- Medium
	[246] = 540, -- Tol Dagor
	[247] = 540, -- The Motherlode
	[248] = 540, -- Waycrest Manor
	[250] = 540, -- Temple of Sethraliss
	[353] = 540, -- Siege of Boralus

	--Slow
	[249] = 660, -- King's Rest
	[252] = 660, -- Shrine of the Storm
}
--]]
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

	[244] = 1763, -- Atal'Dazar
	[245] = 1754, -- Freehold
	[246] = 1771, -- Tol Dagor
	[247] = 1594, -- The Motherlode
	[248] = 1862, -- Waycrest Manor
	[249] = 1762, -- King's Rest
	[250] = 1877, -- Temple of Sethraliss
	[251] = 1841, -- The Underrot
	[252] = 1864, -- Shrine of the Storm
	[353] = 1822, -- Siege of Boralus
	[369] = 2097, -- Operation Mechagon - Junkyard
	[370] = 2097, -- Operation Mechagon - Workshop
}
iKS.IsleQuests = {
	['Horde'] = 53435,
	['Alliance'] = 53436,
}
iKS.currentAffixes = {0,0,0,0}
local sortedAffixes = {
	[10] = 1, --Fortified
	[9] = 1, --Tyrannical

	[7] = 2, --Bolstering
	[6] = 2, --Raging
	[8] = 2, --Sanguine
	[5] = 2, --Teeming
	[11] = 2, --Bursting
	[122] = 2, -- Inspiring
	[123] = 2, -- Spiteful

	[4] = 3, --Necrotic
	[2] = 3, --Skittish
	[3] = 3, --Volcanic
	[13] = 3, --Explosive
	[14] = 3, --Quaking
	[12] = 3, --Grievous
	[124] = 3, -- Storming

	--[15] = ?, --Relentless
	[16] = 4, --Infested, S1
	[117] = 4, --Reaping, S2
	[119] = 4, -- Beguiling, S3
	[120] = 4, -- Awekened, S4
	[121] = 4, -- Prideful, S5
}
do
	local affixIDS = {
		FORTIFIED = 10,
		TYRANNICAL = 9,
		BOLSTERING = 7,
		RAGING = 6,
		SANGUINE = 8,
		TEEMING = 5,
		BURSTING = 11,
		INSPIRING = 122,
		SPITEFUL = 123,
		NECROTIC = 4,
		SKITTISH = 2,
		VOLCANIC = 3,
		EXPLOSIVE = 13,
		QUAKING = 14,
		GRIEVOUS = 12,
		STORMING = 123,
	}
iKS.affixCycles = {
	{affixIDS.FORTIFIED, affixIDS.BURSTRING, affixIDS.STORMING},
	{affixIDS.TYRANNICAL, affixIDS.SANGUINE, affixIDS.GRIEVOUS},
	{affixIDS.FORTIFIED, affixIDS.INSPIRING, affixIDS.EXPLOSIVE},
	{affixIDS.TYRANNICAL, affixIDS.RAGING, affixIDS.QUAKING},
	{affixIDS.FORTIFIED, affixIDS.BURSTING, affixIDS.VOLCANIC},
	{affixIDS.TYRANNICAL, affixIDS.SPITEFUL, affixIDS.GRIEVOUS},
	{affixIDS.FORTIFIED, affixIDS.BOLSTERING, affixIDS.STORMING},
	{affixIDS.TYRANNICAL, affixIDS.INSPIRING, affixIDS.NECROTIC},
	{affixIDS.FORTIFIED, affixIDS.SANGUINE, affixIDS.QUAKING},
	{affixIDS.TYRANNICAL, affixIDS.RAGING, affixIDS.EXPLOSIVE},
	{affixIDS.FORTIFIED, affixIDS.SPITEFUL, affixIDS.VOLCANIC},
	{affixIDS.TYRANNICAL, affixIDS.BOLSTERING, affixIDS.NECROTIC}
}
end
--C_MythicPlus.GetLastWeeklyBestInformation();
--[[
	2 = 1000
	3 = 1050
	4 = 1100
	5 = 1150
	6 = 1200,
	7 = 1250,
	8 = 1300,
	9 = 1350,
	10 = 1400,
]]
local function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
	-- otherwise just sort the keys
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end
function iKS:weeklyReset()
	for guid,data in pairs(iKeystonesDB) do
		if iKeystonesDB[guid].maxCompleted and iKeystonesDB[guid].maxCompleted > 0 then
			iKeystonesDB[guid].canLoot = true
		end
		if iKeystonesDB[guid].isle and iKeystonesDB[guid].isle.done then
			iKeystonesDB[guid].isle = {
				progress = 0,
				done = false,
			}
		end
		if iKeystonesDB[guid].pvp.done then
			iKeystonesDB[guid].pvp.canLoot = true
			iKeystonesDB[guid].pvp.done = false
		end
		iKeystonesDB[guid].key = {}
		iKeystonesDB[guid].maxCompleted = 0
	end

	iKS:scanInventory()
end
function iKS:createPlayer()
	if player and not iKeystonesDB[player] then
		if UnitLevel('player') >= maxPlayerLevel and not iKeystonesConfig.ignoreList[player] then
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
	elseif player and UnitLevel('player') < maxPlayerLevel and iKeystonesDB[player] then
		iKeystonesDB[player] = nil
		return false
	elseif player and iKeystonesDB[player] then
		iKeystonesDB[player].name = UnitName('player') -- fix for name changing
		iKeystonesDB[player].faction = UnitFactionGroup('player') -- faction change (tbh i think guid would change) and update old DB
		return true
	else
		return false
	end
end
--C_MythicPlus.RequestCurrentAffixes();
--C_MythicPlus.RequestMapInfo();
--C_MythicPlus.RequestRewards();
--for i = 1, #self.maps do
--	C_ChallengeMode.RequestLeaders(self.maps[i]);
--end
local validDungeons
local function IsValidDungeon(dungeonID)
	dungeonID = tonumber(dungeonID)
	if not dungeonID then return end
	if not validDungeons then
		validDungeons = {}
		C_MythicPlus.RequestMapInfo()
		local t = C_ChallengeMode.GetMapTable()
		for _,v in pairs(t) do
			validDungeons[v] = true
		end
	end
	return validDungeons[dungeonID]
end
function iKS:scanCharacterMaps()
	if not iKS:createPlayer() then return end
	local maps = C_ChallengeMode.GetMapTable()
	local maxCompleted = 0
	for _, mapID in pairs(maps) do
		local _, level, _, affixes, members = C_MythicPlus.GetWeeklyBestForMap(mapID)
		if members then
			for _,member in pairs(members) do -- Avoid leaking from another char (wtf??, how is this even possible)
				if member.name == unitName then
					if level and level > maxCompleted then
						maxCompleted = level
					end
					break
				end
			end
		end
	end
	if iKeystonesDB[player].maxCompleted and iKeystonesDB[player].maxCompleted < maxCompleted then
		iKeystonesDB[player].maxCompleted = maxCompleted
	end
end

function iKS:scanInventory(requestingSlots, requestingItemLink)
	if not iKS:createPlayer() then return end
	local _map = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
	local _level = C_MythicPlus.GetOwnedKeystoneLevel()
	if not _map or not _level then return end
	if requestingSlots or requestingItemLink then
		for bagID = 0, 4 do
			for invID = 1, GetContainerNumSlots(bagID) do
				local itemID = GetContainerItemID(bagID, invID)
				if itemID and itemID == 180653 then
					if requestingSlots then
						return bagID, invID
					end
					return GetContainerItemLink(bagID, invID)
				end
			end
		end
	end
	iKeystonesDB[player].key = {
		['map'] = _map,
		['level'] = _level,
	}
	if (iKS.keyLevel and iKS.keyLevel < _level) or not iKS.keyLevel then
		local itemLink = iKS:getKeystoneLink(_level, _map)
		print('iKS: New keystone - ' .. itemLink)
	end
	iKS.keyLevel = _level
	iKS.mapID = _map
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
	local name, arg2, timeLimit = C_ChallengeMode.GetMapUIInfo(mapID)
	if zone then
		return iKS.keystonesToMapIDs[mapID]
	else
		return name
	end
end
function iKS:getKeystoneLink(keyLevel, map)
	return _sformat('%s|Hkeystone:%d:%d:%d:%d:%d:%d|h[%s (%s)]|h|r', iKS:getItemColor(keyLevel), map, keyLevel, (keyLevel >= 4 and iKS.currentAffixes[2] or 0), (keyLevel >= 7 and iKS.currentAffixes[3] or 0), iKS.currentAffixes[1],((keyLevel >= 10 and iKS.currentAffixes[4]) and iKS.currentAffixes[4] or 0), iKS:getZoneInfo(map), keyLevel)
end
function iKS:printKeystones()
	local allCharacters = {}
	for guid,data in pairs(iKeystonesDB) do
		local itemLink = ''
		if data.key.map then
			itemLink = iKS:getKeystoneLink(data.key.level,data.key.map)
		else
			itemLink = UNKNOWN
		end
		local str = ''
		if data.server == GetRealmName() then
			str = _sformat('|c%s%s\124r: %s M:%s', RAID_CLASS_COLORS[data.class].colorStr, data.name, itemLink, (data.maxCompleted >= iKS.currentMax and '|cff00ff00' .. data.maxCompleted) or data.maxCompleted)
		else
			str = _sformat('|c%s%s-%s\124r: %s M:%s', RAID_CLASS_COLORS[data.class].colorStr, data.name, data.server,itemLink,(data.maxCompleted >= iKS.currentMax and '|cff00ff00' .. data.maxCompleted) or data.maxCompleted)
		end
		if data.maxCompleted > 0 then
			local ilvl = C_MythicPlus.GetRewardLevelForDifficultyLevel(data.maxCompleted)
			str = str.. _sformat('|r (%d) AP: %s', ilvl, iKS:getAP(data.maxCompleted))
		end
		print(str)
	end
end
function iKS:shouldReportKey(KeyLevel, exactLevel, minLevel, maxLevel)
	if not KeyLevel then return false end
	if not exactLevel and not minLevel and not maxLevel then return true end
	if exactLevel then if KeyLevel == exactLevel then return true else return end end
	if minLevel then if KeyLevel >= minLevel and (not maxLevel or (maxLevel and KeyLevel <= maxLevel)) then return true else return end end
end
function iKS:PasteKeysToChat(all,channel, exactLevel, minLevel, maxLevel, requestingWeekly, mapID)
	if all then -- All keys for this faction
		local i = 0
		local totalCounter = 0
		local str = ''
		local faction = UnitFactionGroup('player')
		local msgs = {}
		for guid,data in pairs(iKeystonesDB) do
			if i == 3 then
				SendChatMessage(str, channel)
				str = ''
				i = 0
			end
			if data.faction == faction and (mapID == data.key.map or not mapID) then
				--if not level or (level and data.key.level and data.key.level >= level) then
				if not requestingWeekly or (requestingWeekly and data.maxCompleted < iKS.currentMax) then
					if iKS:shouldReportKey(data.key.level, exactLevel, minLevel, maxLevel) then
						local itemLink = ''
						if data.key.map then
							if i > 0 then
								str = str .. ' - '
							end
							itemLink = _sformat('%s (%s)', iKS:getZoneInfo(data.key.map), data.key.level)
							str = str.._sformat('%s: %s', data.name, itemLink)
							i = i + 1
							totalCounter = totalCounter + 1
						end
					end
				end
			end
		end
		if totalCounter > 0 then
			if i > 0 then
				SendChatMessage(str, channel)
			end
		elseif exactLevel and not requestingWeekly then
			SendChatMessage("No keystones at " .. exactLevel..".", channel)
		elseif minLevel and not maxLevel and not requestingWeekly  then
			SendChatMessage("No keystones at or above " .. minLevel..".", channel)
		elseif minLevel and maxLevel and not requestingWeekly  then
			SendChatMessage("No keystones between "..minLevel.." and "..maxLevel..".", channel)
		elseif mapID then
			local n = C_ChallengeMode.GetMapUIInfo(mapID)
			SendChatMessage("No keystones for "..n..".", channel)
		elseif not requestingWeekly then
			SendChatMessage("No keystones.", channel)
		end
	else -- Only this char
		local data = iKeystonesDB[player]
		if data then
			if data.key.map then
				local itemLink = iKS:scanInventory(false, true)
				if itemLink then -- nil check
					SendChatMessage(itemLink, channel)
				else
					SendChatMessage(UNKNOWN, channel)
				end
			else
				SendChatMessage("No keystones.", channel)
			end
		else
			SendChatMessage("No keystones.", channel)
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
/iks delete (d) characterName serverName - delete specific character
/iks list (i) - paste all dungeon ids
/iks guild (g) - request keys from guild]])
end
function addon:PLAYER_LOGIN()
	player = UnitGUID('player')
	C_MythicPlus.RequestCurrentAffixes()
	C_MythicPlus.RequestMapInfo()
  C_MythicPlus.RequestRewards()
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
local version = 1.921
function addon:ADDON_LOADED(addonName)
	if addonName == 'iKeystones' then
		iKeystonesDB = iKeystonesDB or {}
		iKeystonesConfig = iKeystonesConfig or {}
		if iKeystonesConfig.version < 1.921 then -- reset data for new expansion (db doesn't have level data)
			iKeystonesDB = nil
			iKeystonesDB = {}
		end
		if not iKeystonesConfig.version or iKeystonesConfig.version < version then
			iKeystonesConfig.version = version
			for guid,data in pairs(iKeystonesDB) do
				if data.isle then
					data.isle = nil
				end
				if data.pvp then
					data.pvp = nil
				end
			end
		end
		if not iKeystonesConfig.ignoreList then
			iKeystonesConfig.ignoreList = {}
		end
		if not iKeystonesConfig.affstring then --remove old stuff and reset chars
			iKeystonesDB = {}
			iKeystonesConfig.aff = nil
			iKeystonesConfig.affstring = ""
		end
		if iKeystonesConfig.ak then -- remove old ak stuff from wtf file
			iKeystonesConfig.ak = nil
		end
		--LoadAddOn("Blizzard_ChallengesUI")
	elseif addonName == 'Blizzard_ChallengesUI' then
		addon:MYTHIC_PLUS_CURRENT_AFFIX_UPDATE()
	end
end

--Fix for Blizzard_ChallengesUI gving errors from 9.0.1 when loaded during loading screens
addon:RegisterEvent("LOADING_SCREEN_DISABLED")
function addon:LOADING_SCREEN_DISABLED()
	if not IsAddOnLoaded("Blizzard_ChallengesUI") then
		LoadAddOn("Blizzard_ChallengesUI")
	end
	addon:UnregisterEvent("LOADING_SCREEN_DISABLED")
end

local delayLoadingTimer
function addon:MYTHIC_PLUS_CURRENT_AFFIX_UPDATE()
	local temp = C_MythicPlus.GetCurrentAffixes()
	if not temp then
		if not delayLoadingTimer then
			delayLoadingTimer = C_Timer.NewTimer(2, function()
				addon:MYTHIC_PLUS_CURRENT_AFFIX_UPDATE()
			end)
		end
		return
	end
	if temp[1] then
		iKS.currentAffixes[sortedAffixes[temp[1].id]] = temp[1].id
	end
	if temp[2] then
		iKS.currentAffixes[sortedAffixes[temp[2].id]] = temp[2].id
	end
	if temp[3] then
		iKS.currentAffixes[sortedAffixes[temp[3].id]] = temp[3].id
	end
	if temp[4] then
		iKS.currentAffixes[sortedAffixes[temp[4].id]] = temp[4].id
	end
	if iKeystonesDB[player] then
		iKeystonesDB[player].canLoot = C_WeeklyRewards.HasAvailableRewards()
	end
	local affstring = _sformat("%d%d%d%d", iKS.currentAffixes[1], iKS.currentAffixes[2],iKS.currentAffixes[3],iKS.currentAffixes[4])
	--print("affixes:",affstring) -- debug
	if iKeystonesConfig.affstring ~= affstring then
		iKeystonesConfig.affstring = affstring
		iKS:weeklyReset()
	end
	if not iKS:createPlayer() then return end
	local key = C_MythicPlus.GetOwnedKeystoneLevel()
	local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
	iKS.keyLevel = key
	iKS.mapID = mapID
	iKeystonesDB[player].key = {
		['map'] = mapID,
		['level'] = key,
	}
	--Get max dynamically
	local lastMax = 0
	local currentMaxLevel = 0
	for i = 2, 30 do
		local ilvl = C_MythicPlus.GetRewardLevelForDifficultyLevel(i)
		if lastMax < ilvl then
			lastMax = ilvl
			iKS.currentMax = i
		end
	end
end
function addon:MYTHIC_PLUS_NEW_WEEKLY_RECORD(mapChallengeModeID, completionMilliseconds, level)
	if not iKS:createPlayer() or not level or not IsValidDungeon(mapChallengeModeID) then return end
	if level > iKeystonesDB[player].maxCompleted then
		iKeystonesDB[player].maxCompleted = level
	end
end
function addon:BAG_UPDATE()
	iKS:scanInventory()
end
function addon:ITEM_PUSH(bag, id)
	if id == 525134 then
		iKS:scanInventory()
	end
end
function addon:CHALLENGE_MODE_MAPS_UPDATE()
	iKS:scanCharacterMaps()
end
function addon:QUEST_LOG_UPDATE()
	if not iKeystonesDB[player] then return end
-- /dump GetQuestObjectiveInfo(53435, 1, false)
--
-- 57065 (pvp chest)
-- 55432 conquest reward
	--conquest quest
	do
		--local rewardAchieved, lastWeekRewardAchieved, lastWeekRewardClaimed, pvpTierMaxFromWins = C_PvP.GetWeeklyChestInfo();
		--iKeystonesDB[player].pvp.done = rewardAchieved
		--iKeystonesDB[player].pvp.progress = (conqProgress and conqMax) and conqProgress/conqMax or 0
		--iKeystonesDB[player].pvp.lootTier = pvpTierMaxFromWins
		--if lastWeekRewardClaimed then
			--iKeystonesDB[player].pvp.canLoot = false
		--end
	end
	if IsQuestFlaggedCompleted(44554) or IsQuestFlaggedCompleted(51363) then -- added back mid patch? O.o, use it to make weekly chest registering faster
		iKeystonesDB[player].canLoot = false
	end
end
function addon:CRITERIA_UPDATE()
	addon:QUEST_LOG_UPDATE()
end
function addon:ENCOUNTER_LOOT_RECEIVED(_, itemid)
	if itemid ~= 180653 then return end
	C_Timer.After(5, function()
		iKeystonesDB[player].canLoot = C_MythicPlus.IsWeeklyRewardAvailable()
	end)

end
local function ChatHandling(msg, channel)
	if not msg then return end -- not sure if this can even happen, maybe?
	msg = msg:lower()
	if msg == '.keys' or msg == "!keys" then
		iKS:PasteKeysToChat(false,channel)
	elseif msg == '.weekly' or msg == "!weekly" then
		iKS:PasteKeysToChat(true,channel,nil,iKS.currentMax,nil, true)
	elseif msg:find('^[!%.]allkeys') then
		if msg:find('^[!%.]allkeys s') then
			local mapID = msg:match('^[!%.]allkeys s (%d*)')
			mapID = tonumber(mapID)
			if iKS.keystonesToMapIDs[mapID] then
				iKS:PasteKeysToChat(true,channel,nil,nil,nil,nil,mapID)
			end
		else
			local level = msg:match('^[!%.]allkeys (%d*)')
			if msg:match('^[!%.]allkeys (%d*)%+$') then -- .allkeys x+
				local level = msg:match('^[!%.]allkeys (%d*)%+$')
				iKS:PasteKeysToChat(true,channel,nil,tonumber(level))
			elseif msg:match('^[!%.]allkeys (%d*)%-(%d*)$') then -- .allkeys x-y
				local minlevel, maxlevel = msg:match('^[!%.]allkeys (%d*)%-(%d*)$')
				iKS:PasteKeysToChat(true,channel,nil, tonumber(minlevel), tonumber(maxlevel))
			elseif msg:match('^[!%.]allkeys (%d*)') then -- .allkeys 15
				local level = msg:match('^[!%.]allkeys (%d*)')
				iKS:PasteKeysToChat(true,channel,tonumber(level))
			else
				iKS:PasteKeysToChat(true,channel)
			end
		end
	end
end
function addon:CHAT_MSG_GUILD(msg)
	ChatHandling(msg, 'guild')
end
function addon:CHAT_MSG_GUILD_LEADER(msg)
	ChatHandling(msg, 'guild')
end
function addon:CHAT_MSG_OFFICER(msg,...)
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
		local linkStart = msg:find('Hitem:180653')
		if linkStart then
			local preLink = msg:sub(1, linkStart-12)
			local linkStuff = msg:sub(math.max(linkStart-11, 0))
			local tempTable = {strsplit(':', linkStuff)}
			tempTable[1] = iKS:getItemColor(tonumber(tempTable[19])) .. '|Hitem'
			for k,v in pairs(tempTable) do
				if v and v:match('%[.-%]') then
					tempTable[k] = _sgsub(tempTable[k], '%[.-%]', _sformat('[%s (%s)]',iKS:getZoneInfo(tonumber(tempTable[17])), tonumber(tempTable[19]), tonumber(tempTable[19])), 1)
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

			local fullString = table.concat(tempTable, ':')
			fullString = _sgsub(fullString, '%[.-%]', _sformat('[%s (%s)]',iKS:getZoneInfo(tonumber(tempTable[3])), tonumber(tempTable[4])), 1)
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
		left = 0,
		right = 0,
		top = 0,
		bottom = 0,
	},
}
function iKS:createNewLine()
	--char -- key -- highest -- ap gain
	iKS.frames[#iKS.frames+1] = {}
	local f = iKS.frames[#iKS.frames]
	f.name = CreateFrame('frame', nil , iKS.anchor, BackdropTemplateMixin and "BackdropTemplate")
	f.name:SetSize(100,20)
	f.name:SetBackdrop(iKS.bd)
	f.name:SetBackdropColor(.1,.1,.1,.9)
	f.name:SetBackdropBorderColor(0,0,0,1)
	f.name:SetPoint('TOPLEFT', (#iKS.frames == 1 and iKS.anchor or iKS.frames[#iKS.frames-1].name), 'BOTTOMLEFT', 0,1)

	f.name.text = f.name:CreateFontString()
	f.name.text:SetFont('Interface\\AddOns\\iKeystones\\FiraMono-Regular.otf', 14, 'OUTLINE')
	f.name.text:SetPoint('LEFT', f.name, 'LEFT', 2,0)
	f.name.text:SetText(#iKS.frames == 1 and 'Character' or '')
	f.name.text:Show()

	f.key = CreateFrame('frame', nil , iKS.anchor, BackdropTemplateMixin and "BackdropTemplate")
	f.key:SetSize(150,20)
	f.key:SetBackdrop(iKS.bd)
	f.key:SetBackdropColor(.1,.1,.1,.9)
	f.key:SetBackdropBorderColor(0,0,0,1)
	f.key:SetPoint('TOPLEFT', f.name, 'TOPRIGHT', -1,0)

	f.key.text = f.key:CreateFontString()
	f.key.text:SetFont('Interface\\AddOns\\iKeystones\\FiraMono-Regular.otf', 14, 'OUTLINE')
	f.key.text:SetPoint('LEFT', f.key, 'LEFT', 2,0)
	f.key.text:SetText(#iKS.frames == 1 and 'Current key' or '')
	f.key.text:Show()

	f.max = CreateFrame('frame', nil , iKS.anchor, BackdropTemplateMixin and "BackdropTemplate")
	f.max:SetSize(50,20)
	f.max:SetBackdrop(iKS.bd)
	f.max:SetBackdropColor(.1,.1,.1,.9)
	f.max:SetBackdropBorderColor(0,0,0,1)
	f.max:SetPoint('TOPLEFT', f.key, 'TOPRIGHT', -1,0)

	f.max.text = f.max:CreateFontString()
	f.max.text:SetFont('Interface\\AddOns\\iKeystones\\FiraMono-Regular.otf', 14, 'OUTLINE')
	f.max.text:SetPoint('CENTER', f.max, 'CENTER', 0,0)
	f.max.text:SetText(#iKS.frames == 1 and 'Max' or '')
	f.max.text:Show()

	f.ilvl = CreateFrame('frame', nil , iKS.anchor, BackdropTemplateMixin and "BackdropTemplate")
	f.ilvl:SetSize(50,20)
	f.ilvl:SetBackdrop(iKS.bd)
	f.ilvl:SetBackdropColor(.1,.1,.1,.9)
	f.ilvl:SetBackdropBorderColor(0,0,0,1)
	f.ilvl:SetPoint('TOPLEFT', f.max, 'TOPRIGHT', -1,0)

	f.ilvl.text = f.ilvl:CreateFontString()
	f.ilvl.text:SetFont('Interface\\AddOns\\iKeystones\\FiraMono-Regular.otf', 14, 'OUTLINE')
	f.ilvl.text:SetPoint('CENTER', f.ilvl, 'CENTER', 0,0)
	f.ilvl.text:SetText(#iKS.frames == 1 and 'iLvL' or '')
	f.ilvl.text:Show()
	--[[
	f.pvp = CreateFrame('frame', nil , iKS.anchor, BackdropTemplateMixin and "BackdropTemplate")
	f.pvp:SetSize(50,20)
	f.pvp:SetBackdrop(iKS.bd)
	f.pvp:SetBackdropColor(.1,.1,.1,.9)
	f.pvp:SetBackdropBorderColor(0,0,0,1)
	f.pvp:SetPoint('TOPLEFT', f.isle, 'TOPRIGHT', -1,0)

	f.pvp.text = f.pvp:CreateFontString()
	f.pvp.text:SetFont('Interface\\AddOns\\iKeystones\\FiraMono-Regular.otf', 14, 'OUTLINE')
	f.pvp.text:SetPoint('CENTER', f.pvp, 'CENTER', 0,0)
	f.pvp.text:SetText(#iKS.frames == 1 and 'PvP' or '')
	f.pvp.text:Show() --]]
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
	--f.pvp:SetBackdropColor(r,g,b,.9)
end
local treasures = {
	pve = '|TInterface\\Icons\\inv_misc_treasurechest02b:16|t',
	pvp = {
		Alliance = "|TInterface\\Icons\\garrison_goldchestalliance:16|t",
		Horde = "|TInterface\\Icons\\garrison_goldchesthorde:16|t",
	}
}
local function reSize(maxFrames)
	local maxSizes = {
		name = 96,
		key = 146,
		pvp = 46,
	}
	for i,f in pairs(iKS.frames) do
		if f.name.text:GetWidth() > maxSizes.name then
			maxSizes.name = f.name.text:GetWidth()
		end
		if f.key.text:GetWidth() > maxSizes.key then
			maxSizes.key = f.key.text:GetWidth()
		end
		--if f.pvp.text:GetWidth() > maxSizes.pvp then
			--maxSizes.pvp = f.pvp.text:GetWidth()
		--end
	end
	for k,v in pairs(maxSizes) do
		maxSizes[k] = math.floor(v)
	end
	for i,f in pairs(iKS.frames) do
		f.name:SetWidth(maxSizes.name+4)
		f.key:SetWidth(maxSizes.key+4)
		--f.pvp:SetWidth(maxSizes.pvp+4)
	end
	local w = maxSizes.name+maxSizes.key+100-5 --+max(50)+ilvl(50) -- +maxSizes.pvp
	if w % 2 == 1 then w = w + 1 end
	iKS.anchor:SetWidth(w)
	iKS.affixes.aff2:ClearAllPoints()
	iKS.affixes.aff2:SetPoint('TOPLEFT', iKS.frames[maxFrames].name, 'BOTTOMLEFT', 0,1)
	iKS.affixes.aff2:SetWidth(math.floor(w/3))
	iKS.affixes.aff2.text:SetText(C_ChallengeMode.GetAffixInfo(iKS.currentAffixes[1]))

	iKS.affixes.aff7:SetWidth(math.floor(w/3))
	iKS.affixes.aff7:ClearAllPoints()
	iKS.affixes.aff7:SetPoint('TOPRIGHT', iKS.frames[maxFrames].ilvl, 'BOTTOMRIGHT', 0,1)
	iKS.affixes.aff7.text:SetText(C_ChallengeMode.GetAffixInfo(iKS.currentAffixes[3]))

	iKS.affixes.aff4:ClearAllPoints()
	iKS.affixes.aff4:SetPoint('LEFT', iKS.affixes.aff2, 'RIGHT', -1,0)
	iKS.affixes.aff4:SetPoint('RIGHT', iKS.affixes.aff7, 'LEFT', 1,0)
	iKS.affixes.aff4.text:SetText(C_ChallengeMode.GetAffixInfo(iKS.currentAffixes[2]))
end
function iKS:createMainWindow()
	if not iKS.anchor then
		iKS.anchor = CreateFrame('frame', "iKeystonesWindowAnchor", UIParent)
		tinsert(UISpecialFrames,"iKeystonesWindowAnchor")
		iKS.anchor:SetSize(2,2)
	end
	if iKeystonesConfig.windowPos == 1 then -- Screen one
		local width = math.floor(UIParent:GetWidth()/4)
		iKS.anchor:SetPoint('TOP', UIParent, 'TOP', -width+1,-50)
	elseif iKeystonesConfig.windowPos == 2 then -- Screen two
		local width = math.floor(UIParent:GetWidth()/4)
		iKS.anchor:SetPoint('TOP', UIParent, 'TOP', width,-50)
	else
		iKS.anchor:SetPoint('TOP', UIParent, 'TOP', 0,-50)
	end

	iKS.anchor:Show()
	if #iKS.frames == 0 then
		iKS:createNewLine()
		--Create affix slots
		iKS.affixes = {}
		local f = iKS.affixes
		f.aff2 = CreateFrame('frame', nil , iKS.anchor, BackdropTemplateMixin and "BackdropTemplate")
		f.aff2:SetSize(150,20)
		f.aff2:SetBackdrop(iKS.bd)
		f.aff2:SetBackdropColor(.1,.1,.1,.9)
		f.aff2:SetBackdropBorderColor(0,0,0,1)
		--f.aff4:SetPoint('TOPLEFT', iKS.anchor, 'BOTTOMLEFT', 0,0)

		f.aff2.text = f.aff2:CreateFontString()
		f.aff2.text:SetFont('Interface\\AddOns\\iKeystones\\FiraMono-Regular.otf', 14, 'OUTLINE')
		f.aff2.text:SetPoint('CENTER', f.aff2, 'CENTER', 0,0)
		f.aff2.text:SetText('Tyrannical')
		--f.aff4.text:Show()

		f.aff4 = CreateFrame('frame', nil , iKS.anchor, BackdropTemplateMixin and "BackdropTemplate")
		f.aff4:SetSize(150,20)
		f.aff4:SetBackdrop(iKS.bd)
		f.aff4:SetBackdropColor(.1,.1,.1,.9)
		f.aff4:SetBackdropBorderColor(0,0,0,1)
		f.aff4:SetPoint('TOPLEFT', f.aff2, 'TOPRIGHT', 0,0)

		f.aff4.text = f.aff4:CreateFontString()
		f.aff4.text:SetFont('Interface\\AddOns\\iKeystones\\FiraMono-Regular.otf', 14, 'OUTLINE')
		f.aff4.text:SetPoint('CENTER', f.aff4, 'CENTER', 0,0)
		f.aff4.text:SetText('Teeming')
		--f.aff7.text:Show()

		f.aff7 = CreateFrame('frame', nil , iKS.anchor, BackdropTemplateMixin and "BackdropTemplate")
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
	end
	local i = 1
	for k,v in spairs(iKeystonesDB, function(t,a,b) return t[b].name > t[a].name end) do
		i = i + 1
		if not iKS.frames[i] then
			iKS:createNewLine()
		end
		local f = iKS.frames[i]
		f.name:Show()
		f.key:Show()
		f.max:Show()
		f.ilvl:Show()
		--f.pvp:Show()
		if v.server == GetRealmName() then
			f.name.text:SetText(_sformat('%s|c%s%s\124r', (v.canLoot and treasures.pve or ''),RAID_CLASS_COLORS[v.class].colorStr, v.name))
		else
			f.name.text:SetText(_sformat('%s|c%s%s\124r - %s',(v.canLoot and treasure.pve or ''),RAID_CLASS_COLORS[v.class].colorStr, v.name, v.server))
		end
		f.key.text:SetText(v.key.level and _sformat('%s%s (%s)|r', iKS:getItemColor(v.key.level), iKS:getZoneInfo(v.key.map), v.key.level) or '-')
		f.max.text:SetText((not v.maxCompleted or v.maxCompleted == 0 and "-") or (v.maxCompleted >= iKS.currentMax and '|cff00ff00' .. v.maxCompleted) or (v.maxCompleted > 0 and v.maxCompleted))
		local ilvl = C_MythicPlus.GetRewardLevelForDifficultyLevel(v.maxCompleted)
		f.ilvl.text:SetText(v.maxCompleted > 0 and ilvl or '-')
		--f.pvp.text:SetText(v.pvp.done and _sformat("|cff00ff00%d|r(%0.f%%)",select(2,C_PvP.GetRewardItemLevelsByTierEnum(math.max(v.pvp.lootTier, 0))), v.pvp.progress*100) or _sformat("%0.f%%", v.pvp.progress*100))
		reColor(f, v.faction)
	end
	for j = i+1, #iKS.frames do
		local f = iKS.frames[j]
		f.name:Hide()
		f.key:Hide()
		f.max:Hide()
		f.ilvl:Hide()
		--f.pvp:Hide()
	end
	C_Timer.After(0, function() reSize(i) end)
end
function iKS:addToTooltip(self, map, keyLevel)
	map = tonumber(map)
	keyLevel = tonumber(keyLevel)
	local wIlvl, ilvl = C_MythicPlus.GetRewardLevelForDifficultyLevel(keyLevel)
	self:AddLine(' ')
	self:AddDoubleLine(_sformat('Items: %s |cff00ff00+1|r', (keyLevel > iKS.currentMax and (2+(keyLevel-iKS.currentMax)*.4) or 2)), 'ilvl: ' .. ilvl)
end
iKS.waitingForReplies = false
iKS.guildKeysList = {}
function addon:CHAT_MSG_ADDON(prefix,msg,chatType,sender)
	if prefix == 'iKeystones' and chatType == "GUILD" then
		if msg == 'keyCheck' then
			local faction = UnitFactionGroup('player')
			local keys = {}
			for guid,data in pairs(iKeystonesDB) do
				if data.faction == faction and data.key.map then
					table.insert(keys, {guid = guid, class = data.class, name = data.name, map = data.key.map, level = data.key.level, weeklyMax = data.maxCompleted})
				end
			end
			
			if #keys == 0 then -- no keys
				_SendAddonMessage("iKeystones", "-", "GUILD")
				return
			end
			local str = ""
			for i = 1, #keys do
				str = str .. _sformat("{%s;%s;%s;%s;%s;%s}", keys[i].guid, keys[i].name, keys[i].class, keys[i].map, keys[i].level, keys[i].weeklyMax)
				if i % 3 == 0 or i == #keys then
					_SendAddonMessage("iKeystones", str, "GUILD")
					str = ""
				end
			end
		elseif iKS.waitingForReplies and msg then
			if msg == "-" then
				iKS.guildKeysList[sender] = {
					chars = {noKeystones = true},
					other = {},
				}
			else
				for v in _sgmatch(msg, '{(.-)}') do
					local guid, name, class, map, level, weeklyMax = strsplit(";", v)
						if not iKS.guildKeysList[sender] then
							iKS.guildKeysList[sender] = {
								chars = {},
								other = {},
							}
						end
					iKS.guildKeysList[sender].chars[guid] = {name = name, class = class, map = map, level = tonumber(level), weeklyMax = tonumber(weeklyMax)} -- use guid as key to avoid multiple entries for same character
				end
			end
		end
	elseif iKS.waitingForReplies and prefix == "AstralKeys" and chatType == "GUILD" then
		if msg and msg:find("sync5") then
			msg = msg:gsub("sync5 ", "")
			local chars = {strsplit("_", msg)}
			for _,v in pairs(chars) do
				local char, class, dungeonID, keyLevel, weekly_best, week, timeStamp = v:match('(.+):(%a+):(%d+):(%d+):(%d+):(%d+):(%d)')
				local name = strsplit("-", name)
				if not iKS.guildKeysList[sender] then
					iKS.guildKeysList[sender] = {
						chars = {},
						other = {
							isExternal = true,
						},
					}
				end
				iKS.guildKeysList[sender][char] = {isExternal = true, name = name, class = class, map = dungeonID, level = tonumber(keyLevel), weeklyMax = tonumber(weekly_best)} -- use guid as key to avoid multiple entries for same character}
			end
		end
	end
end
function iKS:showGuildKeys()
	if iKS.guildKeys and iKS.guildKeys:IsShown() then
		iKS.guildKeys:Hide()
		return true
	end
	if not iKS.guildKeys then
		iKS.guildKeys = CreateFrame('ScrollingMessageFrame', "iKeystonesGuildWindow", UIParent, BackdropTemplateMixin and "BackdropTemplate")
		tinsert(UISpecialFrames,"iKeystonesGuildWindow")
		iKS.guildKeys:SetSize(500,600)
		iKS.guildKeys:SetBackdrop(iKS.bd)
		iKS.guildKeys:SetBackdropColor(.1,.1,.1,.9)
		iKS.guildKeys:SetBackdropBorderColor(0,0,0,1)
		if iKeystonesConfig.windowPos == 1 then -- Screen one
			local width = math.floor(UIParent:GetWidth()/4)
			iKS.guildKeys:SetPoint('TOP', UIParent, 'TOP', -width+1,-50)
		elseif iKeystonesConfig.windowPos == 2 then -- Screen two
			local width = math.floor(UIParent:GetWidth()/4)
			iKS.guildKeys:SetPoint('TOP', UIParent, 'TOP', width,-50)
		else
			iKS.guildKeys:SetPoint('TOP', UIParent, 'TOP', 0,-50)
		end
		iKS.guildKeys:SetFont('Interface\\AddOns\\iKeystones\\FiraMono-Regular.otf', 13)
		iKS.guildKeys:SetFading(false)
		iKS.guildKeys:SetInsertMode("BOTTOM")
		iKS.guildKeys:SetJustifyH("LEFT")
		iKS.guildKeys:SetIndentedWordWrap(false)
		iKS.guildKeys:SetMaxLines(3000)
		iKS.guildKeys:SetSpacing(2)
		iKS.guildKeys:EnableMouseWheel(true)
		iKS.guildKeys:SetScript("OnMouseWheel", function(self, delta)
			--iEET:ScrollContent(delta)
			if delta == -1 then
				local offSet
				if IsShiftKeyDown() then
					offSet = self:GetScrollOffset()-20
				else
					offSet = self:GetScrollOffset()-1
				end
					self:SetScrollOffset(offSet)
				--iEET.mainFrameSlider:SetValue(iEET.maxScrollRange-offSet)
			else
				local offSet
				if IsShiftKeyDown() then
					offSet = self:GetScrollOffset()+20
				else
					offSet = self:GetScrollOffset()+1
				end
					self:SetScrollOffset(offSet)
				--iEET.mainFrameSlider:SetValue(iEET.maxScrollRange-offSet)
			end
		end)
		iKS.guildKeys:SetFrameStrata('HIGH')
		iKS.guildKeys:SetFrameLevel(2)
		iKS.guildKeys:EnableMouse(true)
		--Title
		iKS.guildKeysTitle = CreateFrame('frame', nil , iKS.guildKeys, BackdropTemplateMixin and "BackdropTemplate")
		iKS.guildKeysTitle:SetSize(500,20)
		iKS.guildKeysTitle:SetBackdrop(iKS.bd)
		iKS.guildKeysTitle:SetBackdropColor(.1,.1,.1,.9)
		iKS.guildKeysTitle:SetBackdropBorderColor(0,0,0,1)
		iKS.guildKeysTitle:SetPoint('bottom', iKS.guildKeys, 'top', 0,1)

		iKS.guildKeysTitle.text = iKS.guildKeysTitle:CreateFontString()
		iKS.guildKeysTitle.text:SetFont('Interface\\AddOns\\iKeystones\\FiraMono-Regular.otf', 14, 'OUTLINE')
		iKS.guildKeysTitle.text:SetPoint('center', iKS.guildKeysTitle, 'center', 0,0)
		iKS.guildKeysTitle.text:SetText('Guild keystones')
		--Exit
		iKS.guildKeysTitle.exit = CreateFrame('frame', nil , iKS.guildKeys, BackdropTemplateMixin and "BackdropTemplate")
		iKS.guildKeysTitle.exit:SetSize(20,20)
		iKS.guildKeysTitle.exit:SetFrameStrata("DIALOG")
		iKS.guildKeysTitle.exit:SetBackdrop(iKS.bd)
		iKS.guildKeysTitle.exit:SetBackdropColor(.1,.1,.1,.9)
		iKS.guildKeysTitle.exit:SetBackdropBorderColor(1,0,0,1)
		iKS.guildKeysTitle.exit:SetPoint('topright', iKS.guildKeysTitle, 'topright', 0,0)
		iKS.guildKeysTitle.exit:EnableMouse(true)
		iKS.guildKeysTitle.exit:SetScript("OnMouseDown", function() iKS:showGuildKeys() end)

		iKS.guildKeysTitle.exit.text = iKS.guildKeysTitle.exit:CreateFontString()
		iKS.guildKeysTitle.exit.text:SetFont('Interface\\AddOns\\iKeystones\\FiraMono-Regular.otf', 14, 'OUTLINE')
		iKS.guildKeysTitle.exit.text:SetPoint('center', iKS.guildKeysTitle.exit, 'center', 0,0)
		iKS.guildKeysTitle.exit.text:SetText('x')
		--Loading
		iKS.guildKeysLoadingText = iKS.guildKeysTitle:CreateFontString()
		iKS.guildKeysLoadingText:SetFont('Interface\\AddOns\\iKeystones\\FiraMono-Regular.otf', 18, 'OUTLINE')
		iKS.guildKeysLoadingText:SetPoint('center', iKS.guildKeys, 'center', 0,0)
		iKS.guildKeysLoadingText:SetText('Loading...')
		iKS.guildKeys:SetScript("OnShow", function()
			iKS.guildKeysLoadingText:Show()
		end)
	else
		iKS.guildKeys:Clear()
		iKS.guildKeys:Show()
	end
end
function iKS:updateGuildKeys(_min,_max,_map)
	iKS.waitingForReplies = false
	iKS.guildKeysLoadingText:Hide()
	local exactLevel = (_min and _max and _min == _max and _min) or false
	for sender,d in spairs(iKS.guildKeysList) do
		sender = sender:gsub("-(.*)", "")
		sender =  iCN_GetName and iCN_GetName(sender) or sender
		iKS.guildKeys:AddMessage(_sformat("%s %s", sender, d.other.isExternal and "*" or ""))
		if d.chars.noKeystones then
			iKS.guildKeys:AddMessage("    No keystones")
		else
			local empty = true
			for _, data in spairs(d.chars, function(t,a,b) return t[b].level < t[a].level end) do
				if iKS:shouldReportKey(data.level, exactLevel, _min, _max) then
					if not _map or (_map and data.map == _map) then
						empty = false
						local mapName = C_ChallengeMode.GetMapUIInfo(data.map)
						iKS.guildKeys:AddMessage(_sformat("    |c%s%s|r (%s) - %s%s|r %s", RAID_CLASS_COLORS[data.class].colorStr, data.name, ((not data.weeklyMax and "?") or (data.weeklyMax == 0 and "-") or (data.weeklyMax >= iKS.currentMax and "|cff00ff00"..data.weeklyMax.."|r") or data.weeklyMax),iKS:getItemColor(data.level), data.level, mapName))
					end
				end
			end
			if empty then
				if exactLevel then
					iKS.guildKeys:AddMessage("    No keystones at " .. exactLevel)
				elseif _min and not _max then
					iKS.guildKeys:AddMessage("    No keystones at or above " .. _min)
				elseif _min and _max then
					iKS.guildKeys:AddMessage("    No keystones between ".._min.." and ".._max)
				elseif _map then
					local n = C_ChallengeMode.GetMapUIInfo(_map)
					iKS.guildKeys:AddMessage("    No keystones for "..n)
				end
			end
		end
		iKS.guildKeys:AddMessage("----------")
	end
	iKS.guildKeysList = nil
	iKS.guildKeysList = {}
end
local function gameTooltipScanning(self)
	local itemName, itemLink = self:GetItem()
	if not (itemLink and itemLink:find('Hkeystone')) then
		return
	end
	local itemId, map, keyLevel,l4,l7,l10 = _smatch(itemLink, 'keystone:(%d+):(%d+):(%d+):(%d+):(%d+):(%d+):(%d+)')
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
		msg = _slower(msg)
		if msg == 'reset' then
			iKeystonesDB = nil
			iKeystonesDB = {}
			iKS:scanInventory()
			iKS:scanCharacterMaps()
		elseif msg == 'print' then
			iKS:printKeystones()
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
				if iKS.affixCycles[i][1] == iKS.currentAffixes[1] and iKS.affixCycles[i][2] == iKS.currentAffixes[2] and iKS.affixCycles[i][3] == iKS.currentAffixes[3] then
					local nextCycle = i+1 <= #iKS.affixCycles and i+1 or 1
					local aff1 = C_ChallengeMode.GetAffixInfo(iKS.affixCycles[nextCycle][1])
					local aff2 = C_ChallengeMode.GetAffixInfo(iKS.affixCycles[nextCycle][2])
					local aff3 = C_ChallengeMode.GetAffixInfo(iKS.affixCycles[nextCycle][3])
					print(_sformat('iKS: Next cycle : %s, %s, %s.',aff1, aff2, aff3))
					return
				end
			end
			print(_sformat('iKS: Unknown cycle, contact author'))
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
		elseif msg:match('^completed (%d+)$') or msg:match('^c (%d+)$') then
			local level = msg:match('^completed (%d+)$')
			if not level then
				level = msg:match('^c (%d+)$')
			end
			if not iKS:createPlayer() then return end
			iKeystonesDB[player].maxCompleted = tonumber(level)
		elseif msg:match('delete') or msg:match('d') then
			local _,char,server = msg:match("^(.-) (.-) (.*)$")
			if not (char and server) then
				print('iKS: ' .. msg .. ' is not a valid format, please use /iks delete characterName serverName, eg /iks delete ironi stormreaver')
				return
			end
			for guid,data in pairs(iKeystonesDB) do
				if server == _slower(data.server) and char == _slower(data.name) then
					iKeystonesDB[guid] = nil
					print('iKS: Succesfully deleted:' ..char..'-'..server..'.')
					return
				end
			end
			print('iKS: cannot find ' ..char..'-'..server..'.')
		elseif msg == 'screen1' then
			iKeystonesConfig.windowPos = 1
		elseif msg == 'screen2' then
			iKeystonesConfig.windowPos = 2
		elseif msg == "screennormal" then
			iKeystonesConfig.windowPos = 0
		elseif msg == "g" or msg == "guild" or msg:find("g ") or msg:find("guild ") then
			if not iKS.waitingForReplies then -- wait for old request to finish
				iKS.guildKeysList = nil
				iKS.guildKeysList = {}
				local hide = iKS:showGuildKeys()
				if hide then return end
				local _min, _max, _map = false, false, false
				if not (msg == "g" or msg == "guild") then
					if msg:find('^g s') then
						local mapID = msg:match('^g s (%d*)')
						_map = tonumber(mapID)
					else
						if msg:match('^g (%d*)%+$') then -- .allkeys x+
							local level = msg:match('^g (%d*)%+$')
							_min = tonumber(level)
						elseif msg:match('^g (%d*)%-(%d*)$') then -- .allkeys x-y
							local minlevel, maxlevel = msg:match('^g (%d*)%-(%d*)$')
							_min = tonumber(minlevel)
							_max = tonumber(maxlevel)
						elseif msg:match('^g (%d*)') then -- .allkeys 15
							local level = msg:match('^g (%d*)')
							_min = tonumber(level)
							_max = _min
						end
					end	
				end
				iKS.waitingForReplies = true
				_SendAddonMessage("iKeystones", "keyCheck", "GUILD")
				--_SendAddonMessage("AstralKeys", "request", "GUILD") -- AstralKeys support
				C_Timer.After(2, function() iKS:updateGuildKeys(_min, _max, _map) end)
			end		
		elseif msg == "list" or msg == "l" then
			local t = C_ChallengeMode.GetMapTable()
			for k,v in pairs(t) do
				local n = C_ChallengeMode.GetMapUIInfo(v)
				print(v, n)
			end
		elseif msg:match("^(%d-)$") then
			local lvl = msg:match("^(%d-)$")
			local health, damage = C_ChallengeMode.GetPowerLevelDamageHealthMod(lvl)
			local wIlvl, ilvl = C_MythicPlus.GetRewardLevelForDifficultyLevel(lvl)
			if not ilvl then
				ilvl = UNKNOWN
			end
			if not health or not damage then
				print("iKS: No data for level: " .. lvl)
			elseif not iKS.currentAffixes[1] then
				print(_sformat("iKS: Didn't find Fortified orTyrannical affix\nBase Multipliers: Health %.2f - Damage %.2f\ndungeon iLvL: %s - Weekly iLvL: %s", 1+health/100, 1+damage/100, ilvl, wIlvl))
			elseif iKS.currentAffixes[1] == 9 then -- Tyrannical
				print(_sformat("iKS: Multipliers this week for level %d\nBosses: Health %.2f - Damage %.2f\nTrash: Health %.2f - Damage %.2f\ndungeon iLvL: %s - Weekly iLvL: %s", lvl, (1+health/100)*1.4, (1+damage/100)*1.15, 1+health/100, 1+damage/100, ilvl, wIlvl))
			else -- Fortified
				print(_sformat("iKS: Multipliers this week for level %d\nBosses: Health %.2f - Damage %.2f\nTrash: Health %.2f - Damage %.2f\ndungeon iLvL: %s - Weekly iLvL: %s", lvl, 1+health/100, 1+damage/100, (1+health/100)*1.2, (1+damage/100)*1.3, ilvl, wIlvl))
			end
		elseif msg:match("^(%d-) (%d-)$") then
			local lvl, lvl2 = msg:match("^(%d-) (%d-)$")
			local health, damage = C_ChallengeMode.GetPowerLevelDamageHealthMod(lvl)
			local health2, damage2 = C_ChallengeMode.GetPowerLevelDamageHealthMod(lvl2)
			if not health or not damage then
				print("iKS: No data for level: " .. lvl)
			elseif not health2 or not damage2 then
				print("iKS: No data for level: " .. lvl2)
			else
				local function getDifference(arg1, arg2)
					if arg1 > arg2 then
						return (arg1/arg2*100-100)*-1
					else
						return arg2/arg1*100-100
					end
				end
				print(_sformat("iKS: Difference in health %.2f%% and in damage %.2f%%", getDifference(health, health2), getDifference(damage, damage2)))
			end
		else
			iKS:help()
		end
	else
		if iKS.anchor and iKS.anchor:IsShown() then
			iKS.anchor:Hide()
		else
			iKS:createMainWindow()
		end
	end
end
