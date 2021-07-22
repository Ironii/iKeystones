--upvalues
local _sformat, GetQuestObjectiveInfo, IsQuestFlaggedCompleted, _sgsub, _sgmatch, _smatch, _slower, SendChatMessage, _SendAddonMessage = string.format, GetQuestObjectiveInfo, C_QuestLog.IsQuestFlaggedCompleted, string.gsub, string.gmatch, string.match, string.lower, SendChatMessage, C_ChatInfo.SendAddonMessage
local vaultThresholds = {
	{1,4,10},
	{1250,2500,6250},
	{3,6,9},
}
local addon = CreateFrame('Frame');
addon:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)
addon:RegisterEvent('ADDON_LOADED')
addon:RegisterEvent('PLAYER_LOGIN')
addon:RegisterEvent('CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN')
addon:RegisterEvent('MYTHIC_PLUS_CURRENT_AFFIX_UPDATE')
addon:RegisterEvent('ITEM_PUSH')
addon:RegisterEvent('BAG_UPDATE')
addon:RegisterEvent('QUEST_LOG_UPDATE')
addon:RegisterEvent('CHAT_MSG_ADDON')
addon:RegisterEvent("WEEKLY_REWARDS_UPDATE")
C_ChatInfo.RegisterAddonMessagePrefix('iKeystones')
--C_ChatInfo.RegisterAddonMessagePrefix('AstralKeys') -- AstralKeys guild support
addon:RegisterEvent('CHAT_MSG_PARTY')
addon:RegisterEvent('CHAT_MSG_PARTY_LEADER')
addon:RegisterEvent('CHALLENGE_MODE_COMPLETED')
addon:RegisterEvent('ENCOUNTER_END')
addon:RegisterEvent('WEEKLY_REWARDS_HIDE')

local iKS = {}
iKS.currentMax = 0
iKS.frames = {}
local shouldBeCorrectInfoForWeekly = false
local player = UnitGUID('player')
local unitName = UnitName('player')
local playerFaction = UnitFactionGroup('player')
local font = GameFontNormal:GetFont()
local currentMaxLevel = 60


-- popup for loading the first time

StaticPopupDialogs["IKS_MIDWEEKFIRSTLOAD"] = {
  text = "You are logging in for the first time on this character, iKeystones might have incorrect data for the first reset.\r (missing runs and/or raid kills)",
  button1 = OKAY,
  hideOnEscape = true,
}

function iKS:ShowTooltip(str)
	GameTooltip:SetOwner(iKeystonesWindowAnchor, "ANCHOR_NONE")
	GameTooltip:SetPoint("TOPLEFT", iKeystonesWindowAnchor, "TOPRIGHT", 0, 0)
	GameTooltip:ClearLines()
	GameTooltip:SetText(str)
	GameTooltip:Show()
end

iKS.keystonesToMapIDs = {
	--[[
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

--]]
	[375] = 2290, -- Mists of Tirna Scithe
	[376] = 2286, -- The Necrotic Wake
	[377] = 2291, -- De Other Side
	[378] = 2287, -- Halls of Atonement
	[379] = 2289, -- Plaguefall
	[380] = 2284, -- Sanguine Depths
	[381] = 2285, -- Spires of Ascension
	[382] = 2293, -- Theater of Pain
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
	[16] = 4, --Infested, BFA S1
	[117] = 4, --Reaping, BFA S2
	[119] = 4, -- Beguiling, BFA S3
	[120] = 4, -- Awekened, BFA S4
	[121] = 4, -- Prideful, SL S1
	[128] = 4, -- Tormented SL S2
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
		STORMING = 124,
	}
iKS.affixCycles = {
	{affixIDS.FORTIFIED, affixIDS.BURSTING, affixIDS.VOLCANIC}, -- Confirmed
	{affixIDS.TYRANNICAL, affixIDS.BOLSTERING, affixIDS.STORMING}, -- Confirmed
	{affixIDS.FORTIFIED, affixIDS.SPITEFUL, affixIDS.GRIEVOUS}, -- Confirmed
	{affixIDS.TYRANNICAL, affixIDS.INSPIRING, affixIDS.NECROTIC}, -- Confirmed
	{affixIDS.FORTIFIED, affixIDS.SANGUINE, affixIDS.QUAKING}, -- Confirmed
	{affixIDS.TYRANNICAL, affixIDS.RAGING, affixIDS.EXPLOSIVE}, -- Confirmed
	{affixIDS.FORTIFIED, affixIDS.SPITEFUL, affixIDS.VOLCANIC}, -- Confirmed
	{affixIDS.TYRANNICAL, affixIDS.BOLSTERING, affixIDS.NECROTIC}, -- Confirmed
	{affixIDS.FORTIFIED, affixIDS.INSPIRING, affixIDS.STORMING}, -- Confirmed
	{affixIDS.TYRANNICAL, affixIDS.BURSTING, affixIDS.EXPLOSIVE}, -- Confirmed
	{affixIDS.FORTIFIED, affixIDS.SANGUINE, affixIDS.GRIEVOUS}, -- Confirmed
	{affixIDS.TYRANNICAL, affixIDS.RAGING, affixIDS.QUAKING}, -- Confirmed
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
		if data.PvP.progress > vaultThresholds[2][1] then
			data.canLoot = true
		end
		if not data.canLoot and data.raidHistory then
			local c = 0
			for k,v in pairs(data.raidHistory) do
				if not tonumber(k) then -- ignore difids for now, change in 9.1
					c = c + v
				end
			end
			if c >= vaultThresholds[3][1] then
				data.canLoot = true
			end
		end
		if not data.canLoot and data.runHistory then
			local c = 0
			for k,v in pairs(data.runHistory) do
				c = c + v
			end
			if c >= vaultThresholds[1][1] then
				data.canLoot = true
			end
		end
		data.raidHistory = {}
		data.runHistory = {}
		data.torghast = {}
		data.key = {}
		data.PvP = {progress = 0, level = 0}
	end
	iKS:scanInventory()
	iKS:scanCharacterMaps()
end
do -- Torghast
	local questIDs = {
		{58198, 58199, 58200, 58201, 58202, 58203, 61975, 61976, 63880, 63881, 63882}, -- Coldhearth Insignia
		{58186, 58187, 58188, 58189, 58190, 58191, 61971, 61972, 63872, 63873}, -- Fracture Chambers
		{58205, 58205, 59326, 59334, 59335, 59336, 61977, 61978, 63884, 63885}, -- Mort'regar
		{58192, 58193, 58194, 58195, 58196, 58197, 61973, 61974, 63876, 63877, 63878, 63879}, -- The Soulforges
		{59337, 61101, 61131, 61132, 61133, 61134, 61979, 61980, 63888, 63889, 63890}, -- Upper Reaches
		{59328, 59329, 59330, 59331, 59332, 59333, 61969, 61970, 63868, 63869, 63870, 63871}, -- Skoldus Hall
	}
	function iKS:checkTorghast()
		if not iKS:createPlayer() then return end
		for zone, questIDs in pairs(questIDs) do
			local count = 0
			for _, id in pairs(questIDs) do
				if IsQuestFlaggedCompleted(id) then
					count = count + 1
				end
			end
			if count > 0 then
				iKeystonesDB[player].torghast[zone] = count
			end
		end
	end
end
function iKS:createPlayer(login)
	if player and not iKeystonesDB[player] then
		local realm = GetRealmName()
		local _r = realm:lower()
		if _r:match("mythic dungeons") or _r:match("arena champions") then
			return false
		end
		if UnitLevel('player') >= currentMaxLevel and not iKeystonesConfig.ignoreList[player] then
			iKeystonesDB[player] = {
				name = UnitName('player'),
				server = realm,
				class = select(2, UnitClass('player')),
				key = {},
				canLoot = C_WeeklyRewards.HasAvailableRewards(),
				faction = UnitFactionGroup('player'),
				PvP = {progress = 0, level = 0},
				torghast = {},
				runHistory = {},
			}
			iKS:scanCharacterMaps(true)
			return true
		else
			return false
		end
	elseif player and UnitLevel('player') < currentMaxLevel and iKeystonesDB[player] then
		iKeystonesDB[player] = nil
		return false
	elseif player and iKeystonesDB[player] then
		if login then
			iKeystonesDB[player].name = UnitName('player') -- fix for name changing
			iKeystonesDB[player].faction = UnitFactionGroup('player') -- faction change (tbh i think guid would change) and update old DB
		end
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
function iKS:scanCharacterMaps(newChar)
	if not newChar and not iKS:createPlayer() then return end
	--[[
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
	--]]
	
	-- type: 1 m+, 2 pvp, 3 raid
	local isFirstLogin = false
	if not iKeystonesDB[player].raidHistory or newChar then
		iKeystonesDB[player].raidHistory = {}
		isFirstLogin = true
		StaticPopup_Show("IKS_MIDWEEKFIRSTLOAD")
	end
	local t = C_WeeklyRewards.GetActivities() -- for pvp
	if not t then print("Error: Activities not found") return end
	if isFirstLogin then
		if t[3] then -- apparently sometimes data isn't loaded fast enough, cba to try catching it since it's only the first reset which will be messy anyway
			for k,v in pairs(t[3]) do
				if type(v) ~= "table" then break end -- hopefully fixes problems when reaching L60
				local dif = (v.level == 17 and "lfr") or (v.level == 14 and "normal") or (v.level == 15 and "heroic") or (v.level == 16 and "mythic") or "unknown"
				if v.progress >= v.threshold then
					if not iKeystonesDB[player].raidHistory[dif] or iKeystonesDB[player].raidHistory[dif] < v.threshold then
						iKeystonesDB[player].raidHistory[dif] = v.threshold
					end
				elseif v.progress > 0 then
					iKeystonesDB[player].raidHistory[dif] = v.progress
				end
			end
		end
	end
	if isFirstLogin then
		iKeystonesDB[player].runHistory = {}
		local history = C_MythicPlus.GetRunHistory(false, true);
		for k,v in pairs(history) do
			if v.thisWeek then -- is this necessery?
				iKeystonesDB[player].runHistory[v.level] = iKeystonesDB[player].runHistory[v.level] and iKeystonesDB[player].runHistory[v.level] + 1 or 1
			end
		end
	end
	if t[4] then -- first pvp box
		iKeystonesDB[player].PvP = {progress = t[4].progress, level = t[4].level}
	end
	if IsQuestFlaggedCompleted(62079) then -- collecting weekly rewards doesn't proc quest_log_update?
		iKeystonesDB[player].canLoot = false
	else
		iKeystonesDB[player].canLoot = C_WeeklyRewards.HasAvailableRewards()
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
		local maxCompleted = 0
		for k,v in pairs(data.runHistory) do
			if k > maxCompleted then
				maxCompleted = k
			end
		end
		if data.server == GetRealmName() then
			str = _sformat('|c%s%s\124r: %s M:%s', RAID_CLASS_COLORS[data.class].colorStr, data.name, itemLink, (maxCompleted >= iKS.currentMax and '|cff00ff00' .. maxCompleted) or maxCompleted)
		else
			str = _sformat('|c%s%s-%s\124r: %s M:%s', RAID_CLASS_COLORS[data.class].colorStr, data.name, data.server,itemLink,(maxCompleted >= iKS.currentMax and '|cff00ff00' .. maxCompleted) or maxCompleted)
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
				local maxCompleted = 0
				for k,v in pairs(data.runHistory) do
					if k > maxCompleted then
						maxCompleted = k
					end
				end
				if not requestingWeekly or (requestingWeekly and maxCompleted < iKS.currentMax) then
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
	iKS:scanCharacterMaps()
end
local version = 1.957
function addon:ADDON_LOADED(addonName)
	if addonName == 'iKeystones' then
		iKeystonesDB = iKeystonesDB or {}
		iKeystonesConfig = iKeystonesConfig or {
			version = version,
			ignoreList = {},
			affstring = "",
		}
		if not iKeystonesConfig.version or iKeystonesConfig.version < version then
			if iKeystonesConfig.version and iKeystonesConfig.version < 1.930 then -- reset data for new expansion (db doesn't have level data)
				iKeystonesDB = nil
				iKeystonesDB = {}
			end
			if iKeystonesConfig.version and iKeystonesConfig.version < 1.949 then -- remove tournament realms
				local guidsToDelete = {}
				for guid,data in pairs(iKeystonesDB) do
					local server = data.server:lower()
					if server:match("mythic dungeons") or server:match("arena champions") then
						guidsToDelete[guid] = true
					end
				end
				for k,v in pairs(guidsToDelete) do
					iKeystonesDB[k] = nil
				end
			end
			if not iKeystonesConfig.version or iKeystonesConfig.version <= 1.940 then
				for guid,data in pairs(iKeystonesDB) do
					data.torghast = {}
				end
			end
			if iKeystonesConfig.version and iKeystonesConfig.version < 1.943 then -- remove activities and convert it into .PvP
				for guid,data in pairs(iKeystonesDB) do
					local p = data.activities[2][1].progress
					local l = data.activities[2][1].level
					data.PvP = {progress = p or 0, level = l or 0}
					data.activities = nil
				end
			end
			if iKeystonesConfig.version and iKeystonesConfig.version < 1.946 then -- remove activities and convert it into .PvP
				for guid,data in pairs(iKeystonesDB) do
					if data.pvp then
						data.pvp = nil
					end
					if not data.PvP then
						data.PvP = {progress = p or 0, level = l or 0}
					end
				end
			end
			if iKeystonesConfig.version and iKeystonesConfig.version < 1.945 then
				for guid,data in pairs(iKeystonesDB) do
					if not data.runHistory then
						data.runHistory = {}
					end
				end
			end
			iKeystonesConfig.version = version
		end
		if not iKeystonesConfig.ignoreList then
			iKeystonesConfig.ignoreList = {}
		end
		if not iKeystonesConfig.affstring then --remove old stuff and reset chars
			iKeystonesDB = {}
			iKeystonesConfig.aff = nil
			iKeystonesConfig.affstring = ""
		end
		--LoadAddOn("Blizzard_ChallengesUI")
	elseif addonName == 'Blizzard_ChallengesUI' then
		addon:MYTHIC_PLUS_CURRENT_AFFIX_UPDATE()
	end
	iKS:checkTorghast()
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
	if iKeystonesConfig.affstring ~= affstring then
		iKeystonesConfig.affstring = affstring
		iKS:weeklyReset()
	end
	if not iKS:createPlayer(true) then return end
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
function addon:CHALLENGE_MODE_COMPLETED()
	if not iKS:createPlayer() then return end
	local activeKeystoneLevel = C_ChallengeMode.GetActiveKeystoneInfo()
	if not activeKeystoneLevel then return end
	iKeystonesDB[player].runHistory[activeKeystoneLevel] = iKeystonesDB[player].runHistory[activeKeystoneLevel] and iKeystonesDB[player].runHistory[activeKeystoneLevel] + 1 or 1
end
function addon:BAG_UPDATE()
	iKS:scanInventory()
end
function addon:ITEM_PUSH(bag, id)
	if id == 525134 then
		iKS:scanInventory()
	end
end
function addon:WEEKLY_REWARDS_UPDATE()
	iKS:scanCharacterMaps()
end
function addon:QUEST_LOG_UPDATE()
	if not iKS:createPlayer() then return end
	iKS:checkTorghast()
	if IsQuestFlaggedCompleted(62079) then
		iKeystonesDB[player].canLoot = false
	end
end
function addon:WEEKLY_REWARDS_HIDE()
	C_Timer.After(3, function()
		if IsQuestFlaggedCompleted(62079) then
			iKeystonesDB[player].canLoot = false
		end
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
	elseif msg == ".covenant" or msg == "!covenant" then
		local c = C_Covenants.GetActiveCovenantID()
		if not c then return end
		local covenantData = C_Covenants.GetCovenantData(c)
		if not covenantData then return end
		SendChatMessage(covenantData.name, channel)
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
do
	local validEncounters = {
		--[[ i don't think we need these anymore
		[2405] = true, -- Artificer Xy'mox
		[2383] = true, -- Hungering Destoyer
		[2418] = true, -- Huntsman Altimor
		[2406] = true, -- Lady Inerva Darkvein
		[2398] = true, -- Shriekwing
		[2407] = true, -- Sire Denathrius
		[2399] = true, -- Sludgefist
		[2417] = true, -- Stone Legion Generals
		[2402] = true, -- Sun King's Salvation
		[2412] = true, -- The Council of Blood
		--]]
		[2423] = true, -- The Tarragrue
		[2433] = true, -- The Eye of the Jailer
		[2429] = true, -- The Nine
		[2432] = true, -- Remnant of Ner'zhul
		[2430] = true, -- Painsmith Raznal
		[2434] = true, -- Soulrender Dormazain
		[2436] = true, -- Guardian of the First Ones
		[2431] = true, -- Fatescribe Roh-Kalo
		[2422] = true, -- Kel'Thuzad
		[2435] = true, -- Sylvanas Windrunner
	}
	function addon:ENCOUNTER_END(encounterID, encounterName, difficultyID, raidSize, kill)
		if not iKS:createPlayer() then return end
		if kill == 1 and validEncounters[encounterID] then
			if not iKeystonesDB[player].raidHistory then -- kill without first initiating history (level up to max and straigth to raid?)
				iKS:scanCharacterMaps()
			end
			if not iKeystonesDB[player].raidHistory[difficultyID] then
				iKeystonesDB[player].raidHistory[difficultyID] = {}
			end
			-- Track kill history, afaik killing boss multiple times on same difficulty doesn't count toward the vault
			if not iKeystonesDB[player].raidHistory[difficultyID][encounterID] then
				iKeystonesDB[player].raidHistory[difficultyID][encounterID] = true
			end
		end
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
		local linkStart = msg:find('Hitem:180653')
		if linkStart then
			--print(msg:gsub("|", "||")) -- DEBUG
			local preLink = msg:sub(1, linkStart-12)
			local linkStuff = msg:sub(math.max(linkStart-11, 0))
			local tempTable = {strsplit(':', linkStuff)}
			--[[
				1 |cffa335ee|Hitem:
				2 180653:
				3 :
				4 :
				5 :
				6 :
				7 :
				8 :
				9 :
				10 60:
				11 66:
				12 :
				13 :
				14 :
				15 4:
				16 28:
				17 1279:
				18 17:
				19 382:
				20 18:
				21 2:
				22 19:
				23 10:
				24 :
				25 :
				27 |h[Mythic Keystone]|h|r. 5 --]]
				 --/script SendChatMessage("\124cffa335ee\124Hitem:180653::::::::60:66::::4:28:1279:17:382:18:4:19:10:::\124h[Mythic Keystone]\124h\124r")
				 --                           strsplit("|cffa335ee \124Hitem:180653::::::::60:581::::5:17:380:18:9:19:9:20:7:21:124:::\124h[Mythic Keystone]|h|r.") 5 first box
				 --[[
					 
					 local str = {strsplit(":","||cffa335ee|||Hitem:180653::::::::60:581::::5:17:380:18:9:19:9:20:7:21:124:::||h[Mythic Keystone]||h||r. 5")};for k,v in pairs(str) do print(k,v) end
					 --dh first week 9
					 [10:50:20] 1 ||cffa335ee|||Hitem
					[10:50:20] 2 180653
					[10:50:20] 3 
					[10:50:20] 4 
					[10:50:20] 5 
					[10:50:20] 6 
					[10:50:20] 7 
					[10:50:20] 8 
					[10:50:20] 9 
					[10:50:20] 10 60
					[10:50:20] 11 581
					[10:50:20] 12 
					[10:50:20] 13 
					[10:50:20] 14 
					[10:50:20] 15 5
					[10:50:20] 16 17
					[10:50:20] 17 380
					[10:50:20] 18 18
					[10:50:20] 19 9
					[10:50:20] 20 19
					[10:50:20] 21 9
					[10:50:20] 22 20
					[10:50:20] 23 7
					[10:50:20] 24 21
					[10:50:20] 25 124

					-- paladin first week 2
					local str = {strsplit(":","|cffa335ee|Hitem:180653::::::::60:66::::3:17:381:18:2:19:9:::|h[Mythic Keystone]|h|r. 5")};for k,v in pairs(str) do print(k,v) end
					[10:56:34] 1 |cffa335ee|Hitem
					[10:56:34] 2 180653
					[10:56:34] 3 
					[10:56:34] 4 
					[10:56:34] 5 
					[10:56:34] 6 
					[10:56:34] 7 
					[10:56:34] 8 
					[10:56:34] 9 
					[10:56:34] 10 60
					[10:56:34] 11 66
					[10:56:34] 12 
					[10:56:34] 13 
					[10:56:34] 14 
					[10:56:34] 15 3
					[10:56:34] 16 17
					[10:56:34] 17 381
					[10:56:34] 18 18
					[10:56:34] 19 2
					[10:56:34] 20 19
					[10:56:34] 21 9
					[10:56:34] 22 
					[10:56:34] 23 
					[10:56:34] 24 |h[Mythic Keystone]|h|r. 5
					dk first week 13
					local str = {strsplit(":","|cffa335ee|Hitem:180653::::::::60:250::::6:17:381:18:13:19:9:20:7:21:124:22:121:::|h[Mythic Keystone]|h|r. 5")};for k,v in pairs(str) do print(k,v) end
					|cffa335ee|Hitem:180653::::::::60:250::::6:17:381:18:13:19:9:20:7:21:124:22:121:::|h[Mythic Keystone]|h|r. 5
					[11:18:31] 9 
					[11:18:31] 10 60
					[11:18:31] 11 250
					[11:18:31] 12 
					[11:18:31] 13 
					[11:18:31] 14 
					[11:18:31] 15 6
					[11:18:31] 16 17
					[11:18:31] 17 381
					[11:18:31] 18 18
					[11:18:31] 19 13
					[11:18:31] 20 19
					[11:18:31] 21 9
					[11:18:31] 22 20
					[11:18:31] 23 7
					[11:18:31] 24 21
					[11:18:31] 25 124
					[11:18:31] 26 22
					[11:18:31] 27 121
					[11:18:31] 28 
					[11:18:31] 29 
					[11:18:31] 30 |h[Mythic Keystone]|h|r. 5
				 ]]
			tempTable[1] = iKS:getItemColor(tonumber(tempTable[21])) .. '|Hitem'
			for k,v in pairs(tempTable) do
				if v and v:match('%[.-%]') then
					if iKS:getZoneInfo(tonumber(tempTable[19])) then -- sometimes its 19 and somtimes 17? something do with key level most likely
						tempTable[k] = _sgsub(tempTable[k], '%[.-%]', _sformat('[%s (%s)]',iKS:getZoneInfo(tonumber(tempTable[19])), tonumber(tempTable[21]), tonumber(tempTable[21])), 1)
					else
						tempTable[k] = _sgsub(tempTable[k], '%[.-%]', _sformat('[%s (%s)]',iKS:getZoneInfo(tonumber(tempTable[17])), tonumber(tempTable[19]), tonumber(tempTable[19])), 1)
					end
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
	local isDataLine = not (#iKS.frames == 1)
	f.name = CreateFrame('frame', nil , iKS.anchor, BackdropTemplateMixin and "BackdropTemplate")
	f.name:SetSize(100,20)
	f.name:SetBackdrop(iKS.bd)
	f.name:SetBackdropColor(.1,.1,.1,.9)
	f.name:SetBackdropBorderColor(0,0,0,1)
	f.name:SetPoint('TOPLEFT', (#iKS.frames == 1 and iKS.anchor or iKS.frames[#iKS.frames-1].name), 'BOTTOMLEFT', 0,1)

	f.name.text = f.name:CreateFontString()
	f.name.text:SetFont(font, 14, 'OUTLINE')
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
	f.key.text:SetFont(font, 14, 'OUTLINE')
	f.key.text:SetPoint('LEFT', f.key, 'LEFT', 2,0)
	f.key.text:SetText(#iKS.frames == 1 and 'Current key' or '')
	f.key.text:Show()

	f.maxCompleted = CreateFrame('frame', nil , iKS.anchor, BackdropTemplateMixin and "BackdropTemplate")
	f.maxCompleted:SetSize(150,20)
	f.maxCompleted:SetBackdrop(iKS.bd)
	f.maxCompleted:SetBackdropColor(.1,.1,.1,.9)
	f.maxCompleted:SetBackdropBorderColor(0,0,0,1)
	f.maxCompleted:SetPoint('TOPLEFT', f.key, 'TOPRIGHT', -1,0)

	f.maxCompleted.text = f.maxCompleted:CreateFontString()
	f.maxCompleted.text:SetFont(font, 14, 'OUTLINE')
	f.maxCompleted.text:SetPoint('CENTER', f.maxCompleted, 'CENTER', 0,0)
	f.maxCompleted.text:SetText(#iKS.frames == 1 and 'Max' or '')
	f.maxCompleted.text:Show()

	f.dungeon = CreateFrame('frame', nil , iKS.anchor, BackdropTemplateMixin and "BackdropTemplate")
	f.dungeon:SetSize(50,20)
	f.dungeon:SetBackdrop(iKS.bd)
	f.dungeon:SetBackdropColor(.1,.1,.1,.9)
	f.dungeon:SetBackdropBorderColor(0,0,0,1)
	f.dungeon:SetPoint('TOPLEFT', f.maxCompleted, 'TOPRIGHT', -1,0)

	f.dungeon.text = f.dungeon:CreateFontString()
	f.dungeon.text:SetFont(font, 14, 'OUTLINE')
	f.dungeon.text:SetPoint('CENTER', f.dungeon, 'CENTER', 0,0)
	f.dungeon.text:SetText(#iKS.frames == 1 and 'Mythic+' or '')
	f.dungeon.text:Show()

	if isDataLine then
		f.dungeon:EnableMouse()
		f.dungeon.data = ""
		f.dungeon:SetScript("OnEnter", function() iKS:ShowTooltip(f.dungeon.data)	end)
		f.dungeon:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end

	f.raid = CreateFrame('frame', nil , iKS.anchor, BackdropTemplateMixin and "BackdropTemplate")
	f.raid:SetSize(50,20)
	f.raid:SetBackdrop(iKS.bd)
	f.raid:SetBackdropColor(.1,.1,.1,.9)
	f.raid:SetBackdropBorderColor(0,0,0,1)
	f.raid:SetPoint('TOPLEFT', f.dungeon, 'TOPRIGHT', -1,0)

	f.raid.text = f.raid:CreateFontString()
	f.raid.text:SetFont(font, 14, 'OUTLINE')
	f.raid.text:SetPoint('CENTER', f.raid, 'CENTER', 0,0)
	f.raid.text:SetText(#iKS.frames == 1 and 'Raid' or '')
	f.raid.text:Show()

	if isDataLine then
		f.raid:EnableMouse()
		f.raid.data = ""
		f.raid:SetScript("OnEnter", function() iKS:ShowTooltip(f.raid.data)	end)
		f.raid:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end

	f.pvp = CreateFrame('frame', nil , iKS.anchor, BackdropTemplateMixin and "BackdropTemplate")
	f.pvp:SetSize(50,20)
	f.pvp:SetBackdrop(iKS.bd)
	f.pvp:SetBackdropColor(.1,.1,.1,.9)
	f.pvp:SetBackdropBorderColor(0,0,0,1)
	f.pvp:SetPoint('TOPLEFT', f.raid, 'TOPRIGHT', -1,0)

	f.pvp.text = f.pvp:CreateFontString()
	f.pvp.text:SetFont(font, 14, 'OUTLINE')
	f.pvp.text:SetPoint('CENTER', f.pvp, 'CENTER', 0,0)
	f.pvp.text:SetText(#iKS.frames == 1 and 'PvP' or '')
	f.pvp.text:Show()
--[[
	if isDataLine then
		f.pvp:EnableMouse()
		f.pvp.data = ""
		f.pvp:SetScript("OnEnter", function() iKS:ShowTooltip(f.pvp.data)	end)
		f.pvp:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
--]]
	f.torghast = CreateFrame('frame', nil , iKS.anchor, BackdropTemplateMixin and "BackdropTemplate")
	f.torghast:SetSize(50,20)
	f.torghast:SetBackdrop(iKS.bd)
	f.torghast:SetBackdropColor(.1,.1,.1,.9)
	f.torghast:SetBackdropBorderColor(0,0,0,1)
	f.torghast:SetPoint('TOPLEFT', f.pvp, 'TOPRIGHT', -1,0)

	f.torghast.text = f.torghast:CreateFontString()
	f.torghast.text:SetFont(font, 14, 'OUTLINE')
	f.torghast.text:SetPoint('CENTER', f.torghast, 'CENTER', 0,0)
	f.torghast.text:SetText(#iKS.frames == 1 and 'Torghast' or '')
	f.torghast.text:Show()
	
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
	f.maxCompleted:SetBackdropColor(r,g,b,.9)
	f.dungeon:SetBackdropColor(r,g,b,.9)
	f.raid:SetBackdropColor(r,g,b,.9)
	f.pvp:SetBackdropColor(r,g,b,.9)
	f.torghast:SetBackdropColor(r,g,b,.9)
end
local treasures = {
	pve = '|TInterface\\Icons\\inv_misc_treasurechest02b:16|t',
	pvp = {
		Alliance = "|TInterface\\Icons\\garrison_goldchestalliance:16|t",
		Horde = "|TInterface\\Icons\\garrison_goldchesthorde:16|t",
	}
}
local tempILvLstuff = {
	{ -- M+
		0,
		226, -- 2
		226, -- 3
		226, -- 4
		229, -- 5
		229, -- 6
		233, -- 7
		236, -- 8
		236, -- 9
		239, -- 10
		242, -- 11
		246, -- 12
		246, -- 13
		249, -- 14
		252, -- 15
	},
	{ -- PvP
		[0] = 220, -- Unranked
		[1] = 226, -- 1400-1599
		[2] = 233, -- 1600-1799
		[3] = 240, -- 1800-2099
		[4] = 246, -- 2100+
	},
	{ -- Raid
		lfr = 213,
		normal = 226,
		heroic = 239,
		mythic = 252,
	},
}
local function getItemLevelForWeekly(id, vaultType)
	if (vaultType == 1 or vaultType == 3) and id == 0 then return 0,1 end
	if vaultType == 1 and id >= 15 then -- m+
		id = 15
	elseif vaultType == 2 then
		if id > 4 then id = 4 end
	end
	return tempILvLstuff[vaultType][id], 252
	--[[ this isn't reliable right now, use hard coded shit
	if vaultType == 1 then
		return C_MythicPlus.GetRewardLevelFromKeystoneLevel(id), 226
	elseif vaultType == 2 then -- pvp this isn't fully working
		local itemLink, upgraded = C_WeeklyRewards.GetExampleRewardItemHyperlinks(id)
		if not itemLink then return 0,0 end
		local ilvl = GetDetailedItemLevelInfo(itemLink)
		local upgradedilvl = GetDetailedItemLevelInfo(upgraded)
		return ilvl or 0, upgradedilvl or 0
	elseif vaultType == 3 then -- raid
		return id == 14 and 200 or id == 15 and 213 or 226, 226
	end
	]]
end
local function getPvPVault(progress, threshold)
	if progress >= threshold then
		return 1, true
	end
	return progress/threshold, false, ""
end
local function getDungeonVault(d, threshold)
	local i = 0
	local str
	for level, amount in spairs(d, function(t,a,b) return a > b end) do
		if i + amount >= threshold then
			if not str then
				str = string.format("%s * %s",level, threshold-i)
			else
				str = string.format("%s\r%s * %s", str, level, threshold-i)
			end
			return level, str
		else
			i = i + amount
		end
		if not str then
			str = string.format("%s * %s", level, amount)
		else
			str = string.format("%s\r%s * %s", str, level, amount)
		end
		
	end
	return i/threshold, str or ""
end
local function count(t)
	if not t then return 0 end
	local i = 0
	for k,v in pairs(t) do
		if v then i = i + 1 end
	end
	return i
end
local function getRaidVault(data, threshold)
	if not data then return 0, string.format("0/%s", threshold) end
	local mythic = count(data[16])
	local heroic = count(data[15])
	local normal = count(data[14])
	local lfr = count(data[17])
	if not data then return 0, string.format("0/%s", threshold) end
	if mythic >= threshold then return "mythic", string.format("Mythic * %s", threshold) end
	if mythic + heroic >= threshold then return "heroic", string.format("Mythic: %s\rHeroic * %s", mythic, threshold-mythic) end
	if mythic + heroic + normal >= threshold then return "normal", string.format("Mythic * %s\rHeroic * %s\rNormal * %s", mythic, heroic, threshold-mythic-heroic) end
	if mythic + heroic + normal + lfr >= threshold then return "lfr", string.format("Mythic * %s\rHeroic * %s\rNormal * %s\rLFR * %s", mythic, heroic, normal, threshold-mythic-heroic-normal) end
	return (mythic+heroic+normal+lfr)/threshold, string.format("Mythic * %s\rHeroic * %s\rNormal * %s\rLFR * %s", mythic, heroic, normal, lfr)
end
local function getStringForVault(data, vaultType)
	if vaultType == "raid" then
		local t = {}
		local t2 = {}
		for i = 1, 3 do
			local threshold, tooltipData = getRaidVault(data.raidHistory, vaultThresholds[3][i])
			t2[i] = string.format("Loot %s - %s kills required.\r%s",i,vaultThresholds[3][i], tooltipData)
			if tonumber(threshold) and threshold < 1 then
				if threshold == 0 then
					t[i] = "-"
				else
					t[i] = _sformat("%.0f%%", threshold*100)
				end
			else
				local ilvl, upgraded = getItemLevelForWeekly(threshold, 3)
				t[i] = ilvl == upgraded and _sformat("|cff00ff00%s|r", ilvl) or ilvl
			end
		end
		return table.concat(t, "/"), table.concat(t2, "\r\r")
	elseif vaultType == "dungeon" then
		local t = {}
		local t2 = {}
		for i = 1, 3 do
			local threshold, tooltipData = getDungeonVault(data.runHistory, vaultThresholds[1][i])
			t2[i] = string.format("Loot %s - %s dungeons required.\r%s",i,vaultThresholds[1][i], tooltipData)
			if threshold < 1 then
				if threshold == 0 then
					t[i] = "-"
				else
					t[i] = _sformat("%.0f%%", threshold*100)
				end
			else
				local ilvl, upgraded = getItemLevelForWeekly(threshold, 1)
				t[i] = ilvl == upgraded and _sformat("|cff00ff00%s|r", ilvl) or ilvl
			end
		end
		return table.concat(t, "/"), table.concat(t2, "\r\r")
	elseif vaultType == "pvp" then
		local t = {}
		local t2 = {}
		for i = 1, 3 do
			local threshold, done, tooltipData = getPvPVault(data.PvP.progress, vaultThresholds[2][i])
			t2[i] = tooltipData
			if not done then
				if threshold == 0 then
					t[i] = "-"
				else
					t[i] = _sformat("%.0f%%", threshold*100)
				end
			else
				local ilvl, upgraded = getItemLevelForWeekly(data.PvP.level, 2)
				t[i] = ilvl == upgraded and _sformat("|cff00ff00%s|r", ilvl) or ilvl
			end
		end
		return table.concat(t, "/"), table.concat(t2, "\r\r")
	end
	iKS:print(_sformat("ERROR: vault ID %s not found", vaultType))
	return "??/??/??"
end
local function reSize(maxFrames)
	local maxSizes = {
		name = 96,
		key = 146,
		maxCompleted = 46,
		dungeon = 46,
		raid = 46,
		pvp = 46,
		torghast = 46,
	}
	for i,f in pairs(iKS.frames) do
		if f.name.text:GetWidth() > maxSizes.name then
			maxSizes.name = f.name.text:GetWidth()
		end
		if f.key.text:GetWidth() > maxSizes.key then
			maxSizes.key = f.key.text:GetWidth()
		end
		if f.maxCompleted.text:GetWidth() > maxSizes.maxCompleted then
			maxSizes.maxCompleted = f.maxCompleted.text:GetWidth()
		end
		if f.dungeon.text:GetWidth() > maxSizes.dungeon then
			maxSizes.dungeon = f.dungeon.text:GetWidth()
		end
		if f.raid.text:GetWidth() > maxSizes.raid then
			maxSizes.raid = f.raid.text:GetWidth()
		end
		if f.pvp.text:GetWidth() > maxSizes.pvp then
			maxSizes.pvp = f.pvp.text:GetWidth()
		end
		if f.torghast.text:GetWidth() > maxSizes.torghast then
			maxSizes.torghast = f.torghast.text:GetWidth()
		end
	end
	local w = 0
	for k,v in pairs(maxSizes) do
		local _size = math.floor(v)
		maxSizes[k] = math.floor(_size)
		w = w + _size + 6
	end
	for i,f in pairs(iKS.frames) do
		f.name:SetWidth(maxSizes.name+6)
		f.key:SetWidth(maxSizes.key+6)
		f.maxCompleted:SetWidth(maxSizes.maxCompleted+6)
		f.dungeon:SetWidth(maxSizes.dungeon+6)
		f.raid:SetWidth(maxSizes.raid+6)
		f.pvp:SetWidth(maxSizes.pvp+6)
		f.torghast:SetWidth(maxSizes.torghast+6)
	end
	
	if w % 2 == 1 then w = w + 1 end
	iKS.anchor:SetWidth(w)
	iKS.affixes.aff2:ClearAllPoints()
	iKS.affixes.aff2:SetPoint('TOPLEFT', iKS.frames[maxFrames].name, 'BOTTOMLEFT', 0,1)
	iKS.affixes.aff2:SetWidth(math.floor(w/3))
	iKS.affixes.aff2.text:SetText(C_ChallengeMode.GetAffixInfo(iKS.currentAffixes[1]))

	iKS.affixes.aff7:SetWidth(math.floor(w/3))
	iKS.affixes.aff7:ClearAllPoints()
	iKS.affixes.aff7:SetPoint('TOPRIGHT', iKS.frames[maxFrames].torghast, 'BOTTOMRIGHT', 0,1)
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
		f.aff2.text:SetFont(font, 14, 'OUTLINE')
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
		f.aff4.text:SetFont(font, 14, 'OUTLINE')
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
		f.aff7.text:SetFont(font, 14, 'OUTLINE')
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
		f.maxCompleted:Show()
		f.dungeon:Show()
		f.raid:Show()
		f.pvp:Show()
		if v.server == GetRealmName() then
			f.name.text:SetText(_sformat('%s|c%s%s\124r', (v.canLoot and treasures.pve or ''),RAID_CLASS_COLORS[v.class].colorStr, v.name))
		else
			f.name.text:SetText(_sformat('%s|c%s%s\124r - %s',(v.canLoot and treasures.pve or ''),RAID_CLASS_COLORS[v.class].colorStr, v.name, v.server))
		end
		f.key.text:SetText(v.key.level and _sformat('%s%s (%s)|r', iKS:getItemColor(v.key.level), iKS:getZoneInfo(v.key.map), v.key.level) or '-')
		do
			local m = 0
			for k,v in pairs(v.runHistory) do
				if k > m then
					m = k
				end
			end
			f.maxCompleted.text:SetText(m == 0 and "-" or m)
		end
		local dungeonData, dungeonTooltip = getStringForVault(v, "dungeon")
		f.dungeon.data = dungeonTooltip
		f.dungeon.text:SetText(dungeonData)
		
		local raidData, raidTooltip = getStringForVault(v, "raid")
		f.raid.data = raidTooltip
		f.raid.text:SetText(raidData)

		local pvpData, pvpTooltip = getStringForVault(v, "pvp")
		f.pvp.data = dungeonTooltip
		f.pvp.text:SetText(pvpData)

		local torghast
		do
			local count = 0
			for _,_v in spairs(v.torghast) do
				if _v >= 12 then
					if not torghast then
						torghast = _sformat("|cff00ff00%s|r", _v)
					else
						torghast = _sformat("%s/|cff00ff00%s|r", torghast, _v)
					end
				else
					if not torghast then
						torghast = _v
					else
						torghast = _sformat("%s/%s", torghast, _v)
					end
				end
				count = count + 1
			end
			if count == 0 then
				torghast = "-/-"
			elseif count == 1 then
				torghast = _sformat("%s/-", torghast)
			end
		end
		f.torghast.text:SetText(torghast or "")
		reColor(f, v.faction)
	end
	for j = i+1, #iKS.frames do
		local f = iKS.frames[j]
		f.name:Hide()
		f.key:Hide()
		f.maxCompleted:Hide()
		f.dungeon:Hide()
		f.raid:Hide()
		f.pvp:Hide()
		f.torghast:Hide()
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
					table.insert(keys, {guid = guid, class = data.class, name = data.name, map = data.key.map, level = data.key.level})
				end
			end
			
			if #keys == 0 then -- no keys
				_SendAddonMessage("iKeystones", "-", "GUILD")
				return
			end
			local str = ""
			for i = 1, #keys do
				str = str .. _sformat("{%s;%s;%s;%s;%s}", keys[i].guid, keys[i].name, keys[i].class, keys[i].map, keys[i].level)
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
					local guid, name, class, map, level = strsplit(";", v)
						if not iKS.guildKeysList[sender] then
							iKS.guildKeysList[sender] = {
								chars = {},
								other = {},
							}
						end
					iKS.guildKeysList[sender].chars[guid] = {name = name, class = class, map = map, level = tonumber(level)} -- use guid as key to avoid multiple entries for same character
				end
			end
		end
	elseif iKS.waitingForReplies and prefix == "AstralKeys" and chatType == "GUILD" then
		if msg and msg:find("sync5") then
			msg = msg:gsub("sync5 ", "")
			local chars = {strsplit("_", msg)}
			for _,v in pairs(chars) do
				local char, class, dungeonID, keyLevel, week, timeStamp = v:match('(.+):(%a+):(%d+):(%d+):(%d+):(%d)')
				local name = strsplit("-", name)
				if not iKS.guildKeysList[sender] then
					iKS.guildKeysList[sender] = {
						chars = {},
						other = {
							isExternal = true,
						},
					}
				end
				iKS.guildKeysList[sender][char] = {isExternal = true, name = name, class = class, map = dungeonID, level = tonumber(keyLevel)} -- use guid as key to avoid multiple entries for same character}
			end
		end
	end
end
local gkeysFilters = {
	minLevel = false,
	dungeon = false,
}
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
			iKS.guildKeys:SetPoint('TOP', UIParent, 'TOP', -width+1,-75)
		elseif iKeystonesConfig.windowPos == 2 then -- Screen two
			local width = math.floor(UIParent:GetWidth()/4)
			iKS.guildKeys:SetPoint('TOP', UIParent, 'TOP', width,-75)
		else
			iKS.guildKeys:SetPoint('TOP', UIParent, 'TOP', 0,-75)
		end
		iKS.guildKeys:SetFont(font, 13)
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

		-- Filtering GUI
	
		iKS.filteringBG = CreateFrame('frame', nil , iKS.guildKeys, "BackdropTemplate")
		iKS.filteringBG:SetSize(500,20)
		iKS.filteringBG:SetBackdrop(iKS.bd)
		iKS.filteringBG:SetBackdropColor(.1,.1,.1,.9)
		iKS.filteringBG:SetBackdropBorderColor(0,0,0,1)
		iKS.filteringBG:SetPoint('bottom', iKS.guildKeys, 'top', 0,1)

		iKS.filteringMinLvLText = iKS.filteringBG:CreateFontString()
		iKS.filteringMinLvLText:SetFont(font, 12, 'OUTLINE')
		iKS.filteringMinLvLText:SetPoint('left', iKS.filteringBG, 'left', 50,0)
		iKS.filteringMinLvLText:SetText('Min key level')

		iKS.filteringMinLvL = CreateFrame("EditBox", nil, iKS.filteringBG, "BackdropTemplate")
		iKS.filteringMinLvL:SetBackdrop(iKS.bd)
		iKS.filteringMinLvL:SetBackdropColor(.1,.1,.1,.8)
		iKS.filteringMinLvL:SetBackdropBorderColor(1,0,0,1)
		iKS.filteringMinLvL:SetScript("OnTextChanged", function(self)
			local lvl = self:GetNumber()
			gkeysFilters.minLevel = lvl > 0 and lvl or false
			iKS:updateGuildKeys(true)
		end)
		iKS.filteringMinLvL:SetScript('OnEnterPressed', function()
			iKS.filteringMinLvL:ClearFocus()
		end)
		--]]
		iKS.filteringMinLvL:SetWidth(30)
		iKS.filteringMinLvL:SetHeight(18)
		iKS.filteringMinLvL:SetTextInsets(2, 2, 1, 0)
		iKS.filteringMinLvL:SetPoint('left', iKS.filteringMinLvLText, 'right', 5,0)
		iKS.filteringMinLvL:SetText("")
		iKS.filteringMinLvL:SetFont(font, 12)
		iKS.filteringMinLvL:SetAutoFocus(false)
		iKS.filteringMinLvL:SetNumeric(true)
		iKS.filteringMinLvL:SetMaxLetters(2)

		iKS.guildKeysChooseDungeon = CreateFrame('frame', nil , iKS.filteringBG, "BackdropTemplate")
		iKS.guildKeysChooseDungeon:SetSize(200,18)
		iKS.guildKeysChooseDungeon:SetFrameStrata("HIGH")
		iKS.guildKeysChooseDungeon:SetBackdrop(iKS.bd)
		iKS.guildKeysChooseDungeon:SetBackdropColor(.1,.1,.1,.9)
		iKS.guildKeysChooseDungeon:SetBackdropBorderColor(1,0,0,1)
		iKS.guildKeysChooseDungeon:SetPoint('right', iKS.filteringBG, 'right', -50,0)
		iKS.guildKeysChooseDungeon:EnableMouse(true)
		iKS.guildKeysChooseDungeon.text = iKS.guildKeysChooseDungeon:CreateFontString()
		iKS.guildKeysChooseDungeon.text:SetFont(font, 12, 'OUTLINE')
		iKS.guildKeysChooseDungeon.text:SetPoint('center', iKS.guildKeysChooseDungeon, 'center', 0,0)
		iKS.guildKeysChooseDungeon.text:SetText('Dungeon')
		iKS.guildKeysChooseDungeonMenuFrame = CreateFrame('Frame', 'IKSguildKeysChooseDungeonMenuFrame', UIParent, 'UIDropDownMenuTemplate')
		local dungeonMenuList = {{text = "Any", keepShownOnClick = false, notCheckable = true, func = function() 
			gkeysFilters.dungeon = false
			iKS.guildKeysChooseDungeon.text:SetText("Dungeon")
			iKS:updateGuildKeys(true)
		end}}
		do
			local t = C_ChallengeMode.GetMapTable()
			for k,v in pairs(t) do
				local n = C_ChallengeMode.GetMapUIInfo(v)
				tinsert(dungeonMenuList, {
					text = n,
					keepShownOnClick = false,
					notCheckable = true,
					func = function() 
						gkeysFilters.dungeon = v
						iKS.guildKeysChooseDungeon.text:SetText(n)
						iKS:updateGuildKeys(true)
					end})
			end
		end
		iKS.guildKeysChooseDungeon:SetScript("OnMouseDown", function() 
				EasyMenu(dungeonMenuList, iKS.guildKeysChooseDungeonMenuFrame, iKS.guildKeysChooseDungeon, 0 , 0, 'MENU')
		end)

		--Title
		iKS.guildKeysTitle = CreateFrame('frame', nil , iKS.guildKeys, BackdropTemplateMixin and "BackdropTemplate")
		iKS.guildKeysTitle:SetSize(500,20)
		iKS.guildKeysTitle:SetBackdrop(iKS.bd)
		iKS.guildKeysTitle:SetBackdropColor(.1,.1,.1,.9)
		iKS.guildKeysTitle:SetBackdropBorderColor(0,0,0,1)
		iKS.guildKeysTitle:SetPoint('bottom', iKS.filteringBG, 'top', 0,1)

		iKS.guildKeysTitle.text = iKS.guildKeysTitle:CreateFontString()
		iKS.guildKeysTitle.text:SetFont(font, 14, 'OUTLINE')
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
		iKS.guildKeysTitle.exit.text:SetFont(font, 14, 'OUTLINE')
		iKS.guildKeysTitle.exit.text:SetPoint('center', iKS.guildKeysTitle.exit, 'center', 0,0)
		iKS.guildKeysTitle.exit.text:SetText('x')

		--Loading
		iKS.guildKeysLoadingText = iKS.guildKeysTitle:CreateFontString()
		iKS.guildKeysLoadingText:SetFont(font, 18, 'OUTLINE')
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
function iKS:updateGuildKeys(localUpdate)
	if not localUpdate then
		iKS.waitingForReplies = false
		iKS.guildKeysLoadingText:Hide()
	else
		iKS.guildKeys:Clear()
	end
	local _mapName
	if gkeysFilters.dungeon then 
		_mapName = C_ChallengeMode.GetMapUIInfo(gkeysFilters.dungeon)
	end
	local maps = {}
	for sender,d in spairs(iKS.guildKeysList) do
		sender = sender:gsub("-(.*)", "")
		sender =  iCN_GetName and iCN_GetName(sender) or sender
		iKS.guildKeys:AddMessage(_sformat("%s %s", sender, d.other.isExternal and "*" or ""))
		if d.chars.noKeystones then
			iKS.guildKeys:AddMessage("    No keystones")
		else
			local empty = true
			for _, data in spairs(d.chars, function(t,a,b) return t[b].level < t[a].level end) do
				if (not gkeysFilters.minLevel or (gkeysFilters.minLevel and data.level >= gkeysFilters.minLevel)) and (not gkeysFilters.dungeon or gkeysFilters.dungeon == tonumber(data.map)) then
				--if iKS:shouldReportKey(data.level, exactLevel, _min, _max) then
					--if not _map or (_map and data.map and tonumber(data.map) == _map) then
						empty = false
						local mapName = C_ChallengeMode.GetMapUIInfo(data.map)
						iKS.guildKeys:AddMessage(_sformat("    |c%s%s|r - %s%s|r %s", RAID_CLASS_COLORS[data.class].colorStr, data.name,iKS:getItemColor(data.level), data.level, mapName))
					--end
				end
			end
			if empty then
				if gkeysFilters.minLevel and gkeysFilters.dungeon then
					iKS.guildKeys:AddMessage("    No keystones at or above " .. gkeysFilters.minLevel .. " for " .. _mapName)
				elseif gkeysFilters.minLevel then
					iKS.guildKeys:AddMessage("    No keystones at or above " .. gkeysFilters.minLevel)
				elseif gkeysFilters.dungeon then
					iKS.guildKeys:AddMessage("    No keystones for ".. _mapName)
				end
			end
		end
		iKS.guildKeys:AddMessage("----------")
	end
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
				iKS.waitingForReplies = true
				_SendAddonMessage("iKeystones", "keyCheck", "GUILD")
				C_Timer.After(2, function() iKS:updateGuildKeys() end)
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
