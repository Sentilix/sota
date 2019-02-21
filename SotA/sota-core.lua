--[[
--	SotA - State of the Art DKP Addon
--	By Mimma <VanillaGaming.org>
--
--	Unit: sota-core.lua
--	This unit contains the core functionality such as DKP handling,
--	utility functions and frame text output.
--	The sota-core.xml file contains templates used across all UI's.
--]]

SOTA_MESSAGE_PREFIX				= "SOTAv1"
SOTA_ID							= "SOTA"
SOTA_TITLE						= "SotA"
SOTA_TITAN_TITLE				= "SotA - DKP Distribution"

local SOTA_DEBUG_ENABLED		= false;

SOTA_CHAT_END					= "|r"
SOTA_COLOUR_INTRO				= "|c80F0F0F0"
SOTA_COLOUR_CHAT				= "|c8040A0F8"

local WARN_CHANNEL				= "RAID_WARNING"
local RAID_CHANNEL				= "RAID"
local PARTY_CHANNEL				= "PARTY"
local YELL_CHANNEL				= "YELL"
local SAY_CHANNEL				= "SAY"
local GUILD_CHANNEL				= "GUILD"
local WHISPER_CHANNEL			= "WHISPER"

-- Max # of lines for class dkp displayed locally when using "/sota class":
local MAX_CLASS_DKP_DISPLAYED	= 10;

-- Max # of lines for class dkp	sent by whisper:
local MAX_CLASS_DKP_WHISPERED	= 5;

-- true if a DKP job is already running
local JobIsRunning				= false

-- Guild Roster: table of guild players:	{ Name, DKP, Class, Rank(text), Online, Zone, Rank(value) }
local GuildRosterTable			= { }

-- Raid Roster: table of raid players:		{ Name, DKP, Class, Rank, Online }
local RaidRosterTable			= { }
local RaidRosterLazyUpdate		= false;

-- Table of Queued raid members:			{ Name, QueueID, Role, Class, Guild rank, Offline time }
SOTA_RaidQueue					= { }


SOTA_CHANNELS = {
	{ 'Raid Warning (/rw)',			WARN_CHANNEL },
	{ 'Raid channel (/raid)',		RAID_CHANNEL },
	{ 'Yell (/yell)',				YELL_CHANNEL },
	{ 'Say (/say)',					SAY_CHANNEL },
	{ 'Guild chat (/guild)',		GUILD_CHANNEL },
}

SOTA_QUALITY_COLORS = {
	{0, "Poor",				{ 157,157,157 } },	--9d9d9d
	{1, "Common",			{ 255,255,255 } },	--ffffff
	{2, "Uncommon",			{  30,255,  0 } },	--1eff00
	{3, "Rare",				{   0,112,255 } },	--0070ff
	{4, "Epic",				{ 163, 53,238 } },	--a335ee
	{5, "Legendary",		{ 255,128,  0 } }	--ff8000
}

SOTA_CLASS_COLORS = {
	{ "Druid",				{ 255,125, 10 } },	--255 	125 	10		1.00 	0.49 	0.04 	#FF7D0A
	{ "Hunter",				{ 171,212,115 } },	--171 	212 	115 	0.67 	0.83 	0.45 	#ABD473 
	{ "Mage",				{ 105,204,240 } },	--105 	204 	240 	0.41 	0.80 	0.94 	#69CCF0 
	{ "Paladin",			{ 245,140,186 } },	--245 	140 	186 	0.96 	0.55 	0.73 	#F58CBA
	{ "Priest",				{ 255,255,255 } },	--255 	255 	255 	1.00 	1.00 	1.00 	#FFFFFF
	{ "Rogue",				{ 255,245,105 } },	--255 	245 	105 	1.00 	0.96 	0.41 	#FFF569
	{ "Shaman",				{ 245,140,186 } },	--245 	140 	186 	0.96 	0.55 	0.73 	#F58CBA
	{ "Warlock",			{ 148,130,201 } },	--148 	130 	201 	0.58 	0.51 	0.79 	#9482C9
	{ "Warrior",			{ 199,156,110 } }	--199 	156 	110 	0.78 	0.61 	0.43 	#C79C6E
}


SOTA_MSG_OnAnnounceBid		= "OnAnnounceBid";
SOTA_MSG_OnAnnounceMinBid	= "OnAnnounceMinBid";	-- Deprecated; add "\n" to break lines!
SOTA_MSG_On10SecondsLeft	= "On10SecondsLeft";
SOTA_MSG_On9SecondsLeft		= "On9SecondsLeft";
SOTA_MSG_On8SecondsLeft		= "On8SecondsLeft";
SOTA_MSG_On7SecondsLeft		= "On7SecondsLeft";
SOTA_MSG_On6SecondsLeft		= "On6SecondsLeft";
SOTA_MSG_On5SecondsLeft		= "On5SecondsLeft";
SOTA_MSG_On4SecondsLeft		= "On4SecondsLeft";
SOTA_MSG_On3SecondsLeft		= "On3SecondsLeft";
SOTA_MSG_On2SecondsLeft		= "On2SecondsLeft";
SOTA_MSG_On1SecondLeft		= "On1SecondLeft";
SOTA_MSG_OnMainspecBid		= "OnMainspecBid";
SOTA_MSG_OnOffspecBid		= "OnOffspecBid";
SOTA_MSG_OnMainspecMaxBid	= "OnMainspecMaxBid";
SOTA_MSG_OnOffspecMaxBid	= "OnOffspecMaxBid";
SOTA_MSG_OnOpen				= "OnAuctionOpened";
SOTA_MSG_OnComplete			= "OnComplete";
SOTA_MSG_OnPause			= "OnPause";
SOTA_MSG_OnResume			= "OnResume";
SOTA_MSG_OnClose			= "OnEnd";
SOTA_MSG_OnCancel			= "OnCancel";
SOTA_MSG_OnDKPAdded			= "OnDKPAddedPlayer";
SOTA_MSG_OnDKPAddedRaid		= "OnDKPAddedRaid";
SOTA_MSG_OnDKPAddedRange	= "OnDKPAddedRange";
SOTA_MSG_OnDKPAddedQueue	= "OnDKPAddedQueue";
SOTA_MSG_OnDKPSubtract		= "OnDKPSubtractedPlayer";
SOTA_MSG_OnDKPSubtractRaid	= "OnDKPSubtractedRaid";
SOTA_MSG_OnDKPPercent		= "OnDKPSubtractedPercent";
SOTA_MSG_OnDKPShared		= "OnDKPShared";
SOTA_MSG_OnDKPSharedQueue	= "OnDKPSharedQueue";
SOTA_MSG_OnDKPSharedRange	= "OnDKPSharedRange";
SOTA_MSG_OnDKPSharedRangeQ	= "OnDKPSharedRangeQueue";
SOTA_MSG_OnDKPReplaced		= "OnDKPReplaced";



--	Settings (persisted)
-- Pane 1:
SOTA_CONFIG_AuctionTime			= 20
SOTA_CONFIG_AuctionExtension	= 8
SOTA_CONFIG_EnableOSBidding		= 1;	-- Enable MS bidding over OS
SOTA_CONFIG_EnableZoneCheck		= 1;	-- Enable zone check when doing raid queue DKP
SOTA_CONFIG_EnableOnlineCheck	= 1;	-- Enable online check when doing raid queue DKP
SOTA_CONFIG_AllowPlayerPass     = 1;	-- 0: No pass, 1: can pass latest bid
SOTA_CONFIG_DisableDashboard	= 0;	-- Disable Dashboard in UI (hide it)
SOTA_CONFIG_OutputChannel		= WARN_CHANNEL;
SOTA_CONFIG_Messages			= { }	-- Contains configurable raid messages (if any)
SOTA_CONFIG_VersionNumber		= nil;	-- Increases for every change!
SOTA_CONFIG_VersionDate			= nil;	-- Date of last change!


-- Pane 2:
SOTA_CONFIG_BossDKP				= { }
local SOTA_CONFIG_DEFAULT_BossDKP = {
	{ "20Mans",			200 },
	{ "MoltenCore",		600 },
	{ "Onyxia",			600 },
	{ "BlackwingLair",	600 },
	{ "AQ40",			800 },
	{ "Naxxramas",		1200 },
	{ "WorldBosses",	400 }
}
-- Pane 3:
SOTA_CONFIG_Modified			= false;	-- If TRUE, then config number has been updated; FALSE: not.
SOTA_CONFIG_UseGuildNotes		= 0;
SOTA_CONFIG_MinimumBidStrategy	= 1;	-- 0: No strategy, 1: +10 DKP, 2: +10 %, 3: GGC rules, 4: DejaVu rules, 5: Custom rules
SOTA_CONFIG_DKPStringLength		= 5;
SOTA_CONFIG_MinimumDKPPenalty	= 50;	-- Minimum DKP withdrawn when doing percent DKP
-- History: (basically a copy of the transaction log, but not shared with others)
SOTA_HISTORY_DKP				= { }	-- { timestamp, tid, author, description, state, { names, dkp } }

-- Pane 4: (Messages)
-- Pane 5: (Bid rules)



--[[
--	ECHO functions:
--]]
function echo(msg)
	if msg then
		DEFAULT_CHAT_FRAME:AddMessage(SOTA_COLOUR_CHAT .. msg .. SOTA_CHAT_END)
	end
end

function debugEcho(msg)
	if SOTA_DEBUG_ENABLED and msg then
		DEFAULT_CHAT_FRAME:AddMessage(SOTA_COLOUR_CHAT .. "DEBUG: ".. msg .. SOTA_CHAT_END)
	end
end

function publicEcho(msgInfo)

	if(msgInfo) and (msgInfo[3] ~= "") then
		local channelName;

		if msgInfo[2] == 0 then
			-- Message has been disabled!
			return;
		elseif msgInfo[2] == 1 then
			channelName = WARN_CHANNEL;
		elseif msgInfo[2] == 2 then
			channelName = RAID_CHANNEL;
		elseif msgInfo[2] == 3 then
			channelName = GUILD_CHANNEL;
		elseif msgInfo[2] == 4 then
			channelName = YELL_CHANNEL;
		elseif msgInfo[2] == 5 then
			channelName = SAY_CHANNEL;
		else
			-- Unknown channel
			localEcho("Unknown channel: ".. msgInfo[2]..", msg: "..msgInfo[3]);
			return;
		end;

		SendChatMessage(string.format("[%s] %s", SOTA_TITLE, msgInfo[3]), channelName);
	end;
end;

function localEcho(msg)
	echo("<"..SOTA_COLOUR_INTRO..SOTA_TITLE..SOTA_COLOUR_CHAT.."> "..msg);
end;

function raidEcho(msg)
	SendChatMessage(msg, RAID_CHANNEL);
end

function guildEcho(msg)
	SendChatMessage(msg, GUILD_CHANNEL)
end

function addonEcho(msg)
	SendAddonMessage(SOTA_MESSAGE_PREFIX, msg, "RAID")
end

function SOTA_whisper(receiver, msg)
	if receiver == UnitName("player") then
		localEcho(msg);
	else
		SendChatMessage(msg, WHISPER_CHANNEL, nil, receiver);
	end
end


--[[
--	Misc. utility functions:
--]]
function SOTA_GetTimestamp()
	return date("%H:%M:%S", time());
end

function SOTA_GetDateTimestamp()
	return date("%Y/%m/%d %H:%M:%S", time());
end


--[[
--	Convert a msg so first letter is uppercase, and rest as lower case.
--]]
function SOTA_UCFirst(msg)
	if not msg then
		return ""
	end	

	local f = string.sub(msg, 1, 1)
	local r = string.sub(msg, 2)
	return string.upper(f) .. string.lower(r)
end

function SOTA_GetQualityColor(quality)
	for n=1, table.getn(SOTA_QUALITY_COLORS), 1 do
		local q = SOTA_QUALITY_COLORS[n];
		if q[1] == quality then
			return q[3]
		end
	end
	
	-- Unknown quality code; can't happen! Let's just return poor quality!
	return SOTA_QUALITY_COLORS[1][3];
end

function SOTA_GetClassColorCodes(classname)
	local colors = { 128,128,128 }
	classname = SOTA_UCFirst(classname);

	local cc;
	for n=1, table.getn(SOTA_CLASS_COLORS), 1 do
		cc = SOTA_CLASS_COLORS[n];
		if cc[1] == classname then
			return cc[2];
		end
	end

	return colors;
end


--[[
--	Returns:
--	0: If player was not found or not assistant/leader
--	1: If player is assistant
--	2: If player is leader
--]]
function SOTA_GetRaidRank(playername)	
	if(SOTA_IsInRaid(true)) then	
		for n=1, GetNumRaidMembers(), 1 do
			local name, rank = GetRaidRosterInfo(n);
			if name == playername then
				return rank;
			end
		end
	end	
	return 0;
end

function SOTA_IsInRaid(silentMode)
	local result = ( GetNumRaidMembers() > 0 )
	if not silentMode and not result then
		localEcho("You must be in a raid!");
	end
	return result
end

function SOTA_CanReadNotes()
	if SOTA_CONFIG_UseGuildNotes == 1 then
		-- Guild notes can always be read; there is no WOW setting for that.
		result = true;
	else
		result = CanViewOfficerNote();
	end	
	return result
end

function SOTA_CanWriteNotes()
	if SOTA_CONFIG_UseGuildNotes == 1 then
		result = CanEditPublicNote();
	else
		result = CanViewOfficerNote() and CanEditOfficerNote();
	end
	return result
end


function SOTA_GetUnitIDFromGroup(playerName)
	playerName = SOTA_UCFirst(playerName);

	if SOTA_IsInRaid(false) then
		for n=1, GetNumRaidMembers(), 1 do
			if UnitName("raid"..n) == playerName then
				return "raid"..n;
			end
		end
	else
		for n=1, GetNumPartyMembers(), 1 do
			if UnitName("party"..n) == playerName then
				return "party"..n;
			end
		end				
	end
	
	return nil;	
end


--[[
--	Table functions:
--]]
function SOTA_RenumberTable(sourcetable)
	local index = 1;
	local temptable = { };
	for key,value in ipairs(sourcetable) do
		if value and table.getn(value) > 0 then
			temptable[index] = value;
			index = index + 1
		end
	end
	return temptable;
end

function SOTA_SortTableAscending(sourcetable, index)
	local doSort = true
	while doSort do
		doSort = false
		for n=table.getn(sourcetable), 2, -1 do
			local a = sourcetable[n - 1];
			local b = sourcetable[n];
			if (a[index]) > (b[index]) then
				sourcetable[n - 1] = b;
				sourcetable[n] = a;
				doSort = true;
			end
		end
	end
	return sourcetable;
end

function SOTA_SortTableDescending(sourcetable, index)
	local doSort = true
	while doSort do
		doSort = false
		for n=1,table.getn(sourcetable) - 1, 1 do
			local a = sourcetable[n]
			local b = sourcetable[n + 1]
			if (a[index]) < (b[index]) then
				sourcetable[n] = b
				sourcetable[n + 1] = a
				doSort = true
			end
		end
	end
	return sourcetable;
end

function SOTA_CloneTable(sourcetable)
	local destinationtable = { };
	for n=1, table.getn(sourcetable), 1 do
		destinationtable[n] = sourcetable[n];
	end
	return destinationtable;
end



--
--	Guild Roster Functions
--
function SOTA_RequestUpdateGuildRoster()
	GuildRoster();
end

function SOTA_OnGuildRosterUpdate()
	SOTA_RefreshGuildRoster();
	SOTA_UpdateQueueOfflineTimers();

	if SOTA_CanReadNotes() then
		if not JobIsRunning then	
			JobIsRunning = true
			
			local job = SOTA_GetNextJob()
			while job do
				job[1](job)				
				job = SOTA_GetNextJob()
			end
			
			if SOTA_IsInRaid(true) then
				SOTA_RefreshRaidRoster()
			end
 
			JobIsRunning = false
		end
	end
	
	SOTA_RefreshRaidQueue();
	SOTA_RefreshLogElements();
end


--[[
--	Update the guild roster status cache: members and DKP.
--	Used to display DKP values for non-raiding members
--	(/gdclass and /gdstat)
--]]
function SOTA_RefreshGuildRoster()
	
	if not SOTA_CanReadNotes() then
		return;
	end

	local memberCount = GetNumGuildMembers();
	local note
	local NewGuildRosterTable = { }
	
	for n=1,memberCount,1 do
		local name, rank, rankIndex, _, class, zone, publicnote, officernote, online = GetGuildRosterInfo(n)

		if not zone then
			zone = "";
		end

		if SOTA_CONFIG_UseGuildNotes == 1 then		
			note = publicnote
		else
			note = officernote
		end
		
		if not note or note == "" then
			note = "<0>";
		end
		
		if not online then
			online = 0;
		end
		
		local _, _, dkp = string.find(note, "<(-?%d*)>")
		if not dkp or not tonumber(dkp) then
			dkp = 0;
		end
		
		--echo(string.format("Added %s (%s)", name, online));
		
		NewGuildRosterTable[n] = { name, (1 * dkp), class, rank, online, zone, rankIndex };
	end
	
	GuildRosterTable = NewGuildRosterTable;
end


--
--	Raid Roster Functions
--

--[[
--	Get information belonging to a specific player in the guild.
--	Returns NIL if player was not found.
--]]
function SOTA_GetGuildPlayerInfo(player)
	player = SOTA_UCFirst(player);

	for n=1, table.getn(GuildRosterTable), 1 do
		if GuildRosterTable[n][1] == player then
			return GuildRosterTable[n];
		end
	end
	
	return nil;
end


function SOTA_OnRaidRosterUpdate(event, arg1, arg2, arg3, arg4, arg5)
	RaidRosterLazyUpdate = true;

	SOTA_RefreshRaidQueue();
	SOTA_RefreshLogElements();
	
	if SOTA_IsInRaid(true) then
		SOTA_Synchronize();
	else
		SOTA_transactionLog = { };
		SOTA_RaidQueue = { };
		
		SOTA_ClearMaster();		
	end	
end

function SOTA_GetRaidRoster()
	if RaidRosterLazyUpdate then
		SOTA_RefreshRaidRoster();
	end
	return RaidRosterTable;
end


--[[
--	Return raid info for specific player.
--	{ Name, DKP, Class, Rank, Online }
--]]
function SOTA_GetRaidInfoForPlayer(playername)
	if SOTA_IsInRaid(true) and playername then
		playername = SOTA_UCFirst(playername);
		
		local raid = SOTA_GetRaidRoster();		
		for n=1, table.getn(raid), 1 do
			if raid[n][1] == playername then
				return raid[n];
			end			
		end	
	end
	return nil;
end


--[[
--	Re-read the raid status and namely the DKP values.
--	Should be called after each roster update.
--]]
function SOTA_RefreshRaidRoster()
	local playerCount = GetNumRaidMembers()
	
	if playerCount then
		RaidRosterTable = { }
		local index = 1
		local memberCount = table.getn(GuildRosterTable);
		for n=1,playerCount,1 do
			local name, _, _, _, class = GetRaidRosterInfo(n);

			for m=1,memberCount,1 do
				local info = GuildRosterTable[m]
				if name == info[1] then
					RaidRosterTable[index] = info;
					index = index + 1
				end
			end
		end
	end
	
	RaidRosterLazyUpdate = false;
	
	for n=1,table.getn(RaidRosterTable), 1 do
		local rr = RaidRosterTable[n];
--		echo("RaidRosterUpdate:");
--		echo(string.format("Name=%s, DKP=%d, Class=%s, Rank=%s", rr[1], rr[2], rr[3], rr[4]));
	end
end


--
--	DKP handling
--


function SOTA_GetBossDKPValue(instancename)
	local bossDkpList = SOTA_GetBossDKPList();

	for n=1, table.getn(bossDkpList), 1 do
		if bossDkpList[n][1] == instancename then
			return tonumber(bossDkpList[n][2]);
		end
	end
	return 0;
end

function SOTA_SetBossDKPValue(instancename, bossDkp)
	SOTA_GetBossDKPList();
	
	for n=1, table.getn(SOTA_CONFIG_BossDKP), 1 do
		if SOTA_CONFIG_BossDKP[n][1] == instancename then
			SOTA_CONFIG_BossDKP[n][2] = bossDkp;
			break;
		end
	end
end

function SOTA_GetBossDKPList()
	if not SOTA_CONFIG_BossDKP or table.getn(SOTA_CONFIG_BossDKP) == 0 then
		SOTA_CONFIG_BossDKP = SOTA_CONFIG_DEFAULT_BossDKP;
	end
	return SOTA_CONFIG_BossDKP;
end

function SOTA_Call_CheckPlayerDKP(playername, sender)
	if playername then
		playername = SOTA_UCFirst(playername);
	else
		playername = UnitName("player");
	end		

	local dkp = SOTA_GetDKP(playername);
	if dkp then
		dkp = 1 * dkp;
		if sender then
			SOTA_whisper(sender, string.format("%s have %d DKP.", playername, dkp));
		else
			localEcho(string.format("%s have %d DKP.", playername, dkp));
		end
	else
		if sender then
			SOTA_whisper(sender, string.format("There are no DKP information for %s.", playername));
		else
			localEcho(string.format("There are no DKP information for %s.", playername));
		end
	end
end


function SOTA_Call_CheckClassDKP(playerclass, sender)
	if playerclass then
		playerclass = SOTA_UCFirst(playerclass);
	else
		playerclass = UnitClass("player");
	end		

	local classtable = { }
	for n=1, table.getn(GuildRosterTable), 1 do
		if GuildRosterTable[n][3] == playerclass then
			classtable[ table.getn(classtable) + 1] = GuildRosterTable[n];
		end
	end

	SOTA_SortTableDescending(classtable, 2);
	
	if sender then
		SOTA_whisper(sender, string.format("Top %d DKP for %ss:", MAX_CLASS_DKP_WHISPERED, playerclass));
		for n=1, table.getn(classtable), 1 do
			if n <= MAX_CLASS_DKP_WHISPERED then
				SOTA_whisper(sender, string.format("%d - %s: %d DKP", n, classtable[n][1], 1*(classtable[n][2])));
			end
		end
	else
		localEcho(string.format("Top %d DKP for %ss:", MAX_CLASS_DKP_DISPLAYED, playerclass));
		for n=1, table.getn(classtable), 1 do
			if n <= MAX_CLASS_DKP_DISPLAYED then
				localEcho(string.format("%d - %s: %d DKP", n, classtable[n][1], 1*(classtable[n][2])));
			end
		end
	end
end


--[[
--	Get DKP belonging to a specific player.
--	Returns NIL if player was not found. Players with no DKP will return 0.
--]]
function SOTA_GetDKP(playername)
	local dkp = nil;
	local playerInfo = SOTA_GetGuildPlayerInfo(playername);
	if playerInfo then
		dkp = 1 * (playerInfo[2]);
	end
	
	return dkp;
 end


--[[
--	Add <dkp> DKP to <playername>
--]]
function SOTA_Call_AddPlayerDKP(playername, dkp)
	if SOTA_CanDoDKP() then
		RaidState = RAID_STATE_ENABLED;
		SOTA_RequestMaster();
		SOTA_AddJob( function(job) SOTA_AddPlayerDKP(job[2], job[3]) end, playername, dkp )
		SOTA_RequestUpdateGuildRoster();
	end
end
function SOTA_AddPlayerDKP(playername, dkpValue, silentmode)
	dkpValue = 1 * dkpValue;
	if SOTA_ApplyPlayerDKP(playername, dkpValue) then
		playername = SOTA_UCFirst(playername);
		if not silentmode then
			--publicEcho(string.format("%d DKP was added to %s", dkpValue, playername));
			SOTA_EchoEvent(SOTA_MSG_OnDKPAdded, "", dkpValue, playername);
		end
		SOTA_LogSingleTransaction("+Player", playername, dkpValue);
	end
end

--[[
--	Swap players in a transaction: Remove dkp from <p> and add to <r> instead
--]]
function SOTA_Call_SwapPlayersInTransaction(transactionID, newPlayer)
	if SOTA_CanDoDKP(true) then
		RaidState = RAID_STATE_ENABLED;
		SOTA_RequestMaster();
		SOTA_AddJob( function(job) SOTA_SwapPlayersInTransaction(job[2], job[3]) end, transactionID, newPlayer )
		SOTA_RequestUpdateGuildRoster();
	end
end
function SOTA_SwapPlayersInTransaction(transactionID, newPlayer, silentmode)
	local transaction = SOTA_GetTransaction(transactionID);
	if not transaction then
		--	Transaction not found!
		return;
	end
	
	if not table.getn(transaction[6]) == 1 then
		-- Not a single-player transaction!
		return;	
	end
	
	local originalPlayer = transaction[6][1][1];
	local dkpValue = 1 * (transaction[6][1][2]);

	if SOTA_ApplyPlayerDKP(newPlayer, dkpValue) then
		newPlayer = SOTA_UCFirst(newPlayer);
		SOTA_LogSingleTransaction("+Swap", newPlayer, dkpValue);
		
		if SOTA_ApplyPlayerDKP(originalPlayer, -1 * dkpValue) then
			originalPlayer = SOTA_UCFirst(originalPlayer);
			SOTA_LogSingleTransaction("-Swap", originalPlayer, -1 * dkpValue);
			
--			publicEcho(string.format("%s was replaced with %s (%d DKP)", originalPlayer, newPlayer, dkpValue));
			SOTA_EchoEvent(SOTA_MSG_OnDKPReplaced, "", dkpValue, "", "", originalPlayer, newPlayer);
		end
	end
end

--[[
--	Subtract <dkp> DKP from <playername>
--]]
function SOTA_Call_SubtractPlayerDKP(playername, dkp)
	if SOTA_CanDoDKP() and tonumber(dkp) then
		RaidState = RAID_STATE_ENABLED;
		SOTA_RequestMaster();
		SOTA_AddJob( function(job) SOTA_SubtractPlayerDKP(job[2], job[3]) end, playername, dkp )
		SOTA_RequestUpdateGuildRoster();
	end
end
function SOTA_SubtractPlayerDKP(playername, dkpValue, silentmode)
	dkpValue = -1 * dkpValue;
	if SOTA_ApplyPlayerDKP(playername, dkpValue) then
		playername = SOTA_UCFirst(playername);
		if not silentmode then
--			publicEcho(string.format("%d DKP was subtracted from %s", abs(dkpValue), playername));
			SOTA_EchoEvent(SOTA_MSG_OnDKPSubtract, "", abs(dkpValue), playername);
		end
		SOTA_LogSingleTransaction("-Player", playername, dkpValue);
	end
end

function SOTA_Call_SubtractPlayerDKPPercent(playername, percent)
	if SOTA_IsInRaid(true) then
		RaidState = RAID_STATE_ENABLED;
		SOTA_RequestMaster();
		SOTA_AddJob( function(job) SOTA_SubtractPlayerDKPPercent(job[2], job[3]) end, playername, percent )
		SOTA_RequestUpdateGuildRoster();
	end
end
function SOTA_SubtractPlayerDKPPercent(playername, percent, silentmode)
	playername = SOTA_UCFirst(playername);
	local playerInfo = SOTA_GetGuildPlayerInfo(playername);
	if playerInfo then
		percent = 1 * percent;
		local dkp = 1 * (playerInfo[2]);
		local minus = floor(dkp * percent / 100);
		if minus < SOTA_CONFIG_MinimumDKPPenalty then
			minus = SOTA_CONFIG_MinimumDKPPenalty;
		end
		
		SOTA_ApplyPlayerDKP(playername, -1 * minus, true);
		
		if not silentmode then
--			publicEcho(string.format("%d %% (%d DKP) was subtracted from %s", percent, minus, playername));
			SOTA_EchoEvent(SOTA_MSG_OnDKPPercent, "", minus, playername, "", percent);
		end

		SOTA_LogSingleTransaction("%Player", playername, -1 * abs(minus));
	else
		if not silentmode then
			localEcho(string.format("Player %s was not found", playername));
		end
	end
end

--[[
--	Add <n> DKP to all players in raid and in queue
--]]
function SOTA_Call_AddRaidDKP(dkp)
	if SOTA_IsInRaid(true) then
		RaidState = RAID_STATE_ENABLED;
		SOTA_RequestMaster();
		SOTA_AddJob( function(job) SOTA_AddRaidDKP(job[2]) end, dkp, "_" )
		SOTA_RequestUpdateGuildRoster();
	end
end
local SOTA_QueuedPlayersImpacted;
function SOTA_AddRaidDKP(dkp, silentmode, callMethod)
	SOTA_QueuedPlayersImpacteded = 0;

	if SOTA_IsInRaid(true) then	
		dkp = 1 * dkp;
		
		if not callMethod then
			callMethod = "+Raid";
		end
		
		local tidIndex = 1
		local tidChanges = { }

		local raidRoster = SOTA_GetRaidRoster();
		for n=1, table.getn(raidRoster), 1 do
			SOTA_ApplyPlayerDKP(raidRoster[n][1], dkp);
			
			tidChanges[tidIndex] = { raidRoster[n][1], dkp };
			tidIndex = tidIndex + 1;
		end
		
		local instance, zonename;
		local zonecheck = SOTA_CONFIG_EnableZoneCheck;
		local onlinecheck = SOTA_CONFIG_EnableOnlineCheck;
		if zonecheck == 1 then
			instance, zonename = SOTA_GetValidDKPZones();
			if not instance then
				zonecheck = 0;
			end
		end
		
		for n=1, table.getn(SOTA_RaidQueue), 1 do
			local guildInfo = SOTA_GetGuildPlayerInfo(SOTA_RaidQueue[n][1]);

			if guildInfo then
				local eligibleForDKP = true;
	
				-- Player is OFFLINE, skip if not allowed
				if guildInfo[5] == 0 and onlinecheck == 1 then
					localEcho(string.format("No queue DKP for %s (Offline)", SOTA_RaidQueue[n][1]));
					eligibleForDKP = false;
				end
				
				-- Player is not in raid zone
				if eligibleForDKP and guildInfo[5] == 1 and zonecheck == 1 then
						if not(guildInfo[6] == instance or guildInfo[6] == zonename) then
							localEcho(string.format("No queue DKP for %s (location: %s)", SOTA_RaidQueue[n][1], guildInfo[6]));
							eligibleForDKP = false;
						end;
				end;
								
				if eligibleForDKP then				   
					SOTA_ApplyPlayerDKP(SOTA_RaidQueue[n][1], dkp);				
					tidChanges[tidIndex] = { SOTA_RaidQueue[n][1], dkp };
					tidIndex = tidIndex + 1;
					SOTA_QueuedPlayersImpacteded = SOTA_QueuedPlayersImpacteded + 1;
				end
			end
		end
		
		if not silentmode then
--			publicEcho(string.format("%d DKP was added to all players in raid", dkp));
			SOTA_EchoEvent(SOTA_MSG_OnDKPAddedRaid, "", dkp);
		end
		
		SOTA_LogMultipleTransactions(callMethod, tidChanges)				
		return true;
	end
	return false;
end

--[[
--	Subtract <n> DKP from each raid and queue member.
--]]
function SOTA_Call_SubtractRaidDKP(dkp)
	if SOTA_IsInRaid(true) then
		RaidState = RAID_STATE_ENABLED;
		SOTA_RequestMaster();
		SOTA_AddJob( function(job) SOTA_SubtractRaidDKP(job[2]) end, dkp, "_" )
		SOTA_RequestUpdateGuildRoster();
	end
end
function SOTA_SubtractRaidDKP(dkp, silentmode, callMethod)
	if SOTA_IsInRaid(true) then	
		dkp = -1 * dkp;

		if not callMethod then
			callMethod = "-Raid";
		end

		local tidIndex = 1
		local tidChanges = { }
		
		local raidRoster = SOTA_GetRaidRoster();
		for n=1, table.getn(raidRoster), 1 do
			SOTA_ApplyPlayerDKP(raidRoster[n][1], dkp);
			
			tidChanges[tidIndex] = { raidRoster[n][1], dkp };
			tidIndex = tidIndex + 1;
		end

		for n=1, table.getn(SOTA_RaidQueue), 1 do
			local guildInfo = SOTA_GetGuildPlayerInfo(SOTA_RaidQueue[n][1]);
			if guildInfo and guildInfo[5] == 1 then
				SOTA_ApplyPlayerDKP(SOTA_RaidQueue[n][1], dkp);
				
				tidChanges[tidIndex] = { SOTA_RaidQueue[n][1], dkp };
				tidIndex = tidIndex + 1;
			end
		end
		
		if not silentmode then
--			publicEcho(string.format("%d DKP was subtracted from all players in raid", abs(dkp)));
			SOTA_EchoEvent(SOTA_MSG_OnDKPSubtractRaid, "", dkp);
		end

		SOTA_LogMultipleTransactions(callMethod, tidChanges)
		return true;
	end
	return false;
end


--[[
--	Add <n> DKP to all in 100 yard range.
--	1.0.2: result is number of people affected, and not true/false.
--]]
function SOTA_Call_AddRangedDKP(dkp)
	if SOTA_IsInRaid(true) then
		RaidState = RAID_STATE_ENABLED;
		SOTA_RequestMaster();
		SOTA_AddJob( function(job) SOTA_AddRangedDKP(job[2]) end, dkp, "_" )
		SOTA_RequestUpdateGuildRoster();
	end
end
function SOTA_AddRangedDKP(dkp, silentmode, dkpLabel, shareTheDKP)
	dkp = 1 * dkp;

	SOTA_QueuedPlayersImpacted = 0;
	local raidUpdateCount = 0;
	local tidIndex = 1;
	local tidChanges = { };
	
	if not dkpLabel then
		dkpLabel = "+Range";
	end

	-- If true, we must share the dkp across all players, so do a player count to calculate the avg dkp:
	if shareTheDKP then
		local playerCount = 0;
		for n=1, 40, 1 do
			local unitid = "raid"..n;
			local player = UnitName(unitid);

			if player then
				if UnitIsConnected(unitid) and UnitIsVisible(unitid) then
					playerCount = playerCount + 1;
				end
			end
		end

		if playerCount > 0 then
			dkp = math.ceil(dkp / playerCount);
		else
			dkp = 0;
		end;
	end;
	

	for n=1, 40, 1 do
		local unitid = "raid"..n;
		local player = UnitName(unitid);

		if player then
			if UnitIsConnected(unitid) and UnitIsVisible(unitid) then
				SOTA_ApplyPlayerDKP(player, dkp, true);
				
				tidChanges[tidIndex] = { player, dkp };
				tidIndex = tidIndex + 1;
				raidUpdateCount = raidUpdateCount + 1;
			end
		end
	end
	
	for n=1, table.getn(SOTA_RaidQueue), 1 do
		local guildInfo = SOTA_GetGuildPlayerInfo(SOTA_RaidQueue[n][1]);
		if guildInfo and (SOTA_CONFIG_EnableOnlineCheck == 0 or guildInfo[5] == 1) then
			SOTA_ApplyPlayerDKP(SOTA_RaidQueue[n][1], dkp);
			
			tidChanges[tidIndex] = { SOTA_RaidQueue[n][1], dkp };
			tidIndex = tidIndex + 1;
			SOTA_QueuedPlayersImpacted = SOTA_QueuedPlayersImpacted + 1;
		end;
	end
	
	if not silentmode then
		if SOTA_QueuedPlayersImpacted == 0 then
--			publicEcho(string.format("%d DKP has been added for %d players in range.", dkp, raidUpdateCount));
			SOTA_EchoEvent(SOTA_MSG_OnDKPAddedRange, "", dkp, "", "", raidUpdateCount);
		else
--			publicEcho(string.format("%d DKP has been added for %d players in range (plus %d in queue).", dkp, raidUpdateCount, SOTA_QueuedPlayersImpacted));
			SOTA_EchoEvent(SOTA_MSG_OnDKPAddedQueue, "", dkp, "", "", raidUpdateCount, SOTA_QueuedPlayersImpacted);
		end;
	end
	
	SOTA_LogMultipleTransactions(dkpLabel, tidChanges)	
	return raidUpdateCount;
end


function SOTA_ShareBossDKP()
	local bossDkp = "".. (SOTA_GetMinimumBid() * 10);
	
	if SOTA_CanDoDKP(true) then		
		StaticPopupDialogs["SOTA_POPUP_SHARE_DKP"] = {
			text = "Share the following DKP across raid:",
			hasEditBox = true,
			maxLetters = 6,
			button1 = "Share",
			button2 = "Cancel",
			OnAccept = function() SOTA_ExcludePlayerFromTransaction(SOTA_selectedTransactionID, playername)  end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,			
			OnShow = function()	
				local c = getglobal(this:GetName().."EditBox");
				c:SetText(bossDkp);
			end,
			OnAccept = function(self, data)
				local c = getglobal(this:GetParent():GetName().."EditBox");			
				SOTA_ShareSelectedBossDKP(c:GetText());
			end			
		}
		StaticPopup_Show("SOTA_POPUP_SHARE_DKP");		
	end
end

function SOTA_ShareSelectedBossDKP(text)
	local dkp = tonumber(text);
	if dkp then
		SOTA_Call_ShareDKP(dkp);
	end
end


--[[
--	Share <n> DKP to all members in raid and queue
--]]
function SOTA_Call_ShareDKP(dkp)
	if SOTA_IsInRaid(true) then
		RaidState = RAID_STATE_ENABLED;
		SOTA_RequestMaster();
		SOTA_AddJob( function(job) SOTA_ShareDKP(job[2]) end, dkp, "_");
		SOTA_RequestUpdateGuildRoster();
	end
end
function SOTA_ShareDKP(sharedDkp)
	if SOTA_IsInRaid(true) then	
		sharedDkp = abs(1 * sharedDkp);

		local tidIndex = 1;
		local tidChanges = { };
		
		local dkp = 0;
		local raidRoster = SOTA_GetRaidRoster();
		local count = table.getn(raidRoster);
		if count > 0 then
			dkp = ceil(sharedDkp / count);
		end
		
		if SOTA_AddRaidDKP(dkp, true, "+Share") then
			if SOTA_QueuedPlayersImpacteded == 0 then
--				publicEcho(string.format("%d DKP was shared (%s DKP per player)", sharedDkp, dkp));
				SOTA_EchoEvent(SOTA_MSG_OnDKPShared, "", dkp, "", "", sharedDkp);
			else
--				publicEcho(string.format("%d DKP was shared (%s DKP per player plus %d in queue)", sharedDkp, dkp, SOTA_QueuedPlayersImpacteded));
				SOTA_EchoEvent(SOTA_MSG_OnDKPSharedQueue, "", dkp, "", "", sharedDkp, SOTA_QueuedPlayersImpacteded);
			end;
		end
		return true;
	end
	return false;
end

--[[
--	Share <n> DKP to all members in range in raid and queue.
--	Added in 1.0.2.
--]]
function SOTA_Call_ShareRangedDKP(dkp)
	if SOTA_IsInRaid(true) then
		RaidState = RAID_STATE_ENABLED;
		SOTA_RequestMaster();
		SOTA_AddJob( function(job) SOTA_ShareRangedDKP(job[2]) end, dkp, "_");
		SOTA_RequestUpdateGuildRoster();
	end
end
function SOTA_ShareRangedDKP(sharedDkp)
	if SOTA_IsInRaid(true) then	
		sharedDkp = abs(1 * sharedDkp);
		
		local inRange = SOTA_AddRangedDKP(sharedDkp, true, "+ShRange", true);
		if inRange > 0 then
			local dkp = ceil(sharedDkp / inRange);
			if SOTA_QueuedPlayersImpacted == 0 then
--				publicEcho(string.format("%d DKP was shared for %d players in range (%s DKP per player)", sharedDkp, inRange, dkp));
				SOTA_EchoEvent(SOTA_MSG_OnDKPSharedRange, "", dkp, "", "", sharedDkp, inRange);
			else
--				publicEcho(string.format("%d DKP was shared for %d players in range (%s DKP per player plus %d in queue)", sharedDkp, inRange, dkp, SOTA_QueuedPlayersImpacted));
				SOTA_EchoEvent(SOTA_MSG_OnDKPSharedRangeQ, "", dkp, "", "", sharedDkp, inRange, SOTA_QueuedPlayersImpacted);
			end;
		end
		return true;
	end
	return false;
end


--[[
--	Perform a DKP decay without really removing DKP. Result is echoed out locally.
--	Added in 1.1.0
--]]
function SOTA_Call_Decaytest(percent)
	SOTA_AddJob( function(job) SOTA_Decaytest(job[2]) end, percent, "_" )
	SOTA_RequestUpdateGuildRoster();
end
function SOTA_Decaytest(percent, silentmode)
	--	Note: arg may contain a percent sign; remove this first:
	if not tonumber(percent) then
		local pctSign = string.sub(percent, string.len(percent), string.len(percent));
		if pctSign == "%" then
			percent = string.sub(percent, 1, string.len(percent) - 1);
		end
	end
	
	if not tonumber(percent) then
		localEcho("Guild Decay test cancelled: Percent is not a valid number: ".. percent);
		return false;
	end
	
	percent = abs(1 * percent);

	local tidIndex = 1;
	local tidChanges = { };

	local reducedDkp = 0;
	local playerCount = 0;

	--	Iterate over all guilded players - online or not
	local name, publicNote, officerNote
	local memberCount = GetNumGuildMembers();
	for n=1,memberCount,1 do
		name, _, _, _, _, _, publicNote, officerNote = GetGuildRosterInfo(n);
		local note = officerNote;
		if SOTA_CONFIG_UseGuildNotes == 1 then
			note = publicNote;
		end

		local _, _, dkp = string.find(note, "<(-?%d*)>");
		if dkp and tonumber(dkp) then
			local minus = floor(dkp * percent / 100)
			tidChanges[tidIndex] = { name, (-1 * minus) }
			tidIndex = tidIndex + 1
			
			dkp = dkp - minus;
			reducedDkp = reducedDkp + minus;
			playerCount = playerCount + 1;
			note = string.gsub(note, "<(-?%d*)>", SOTA_CreateDkpString(dkp), 1);
		else
			dkp = 0;
			note = note..SOTA_CreateDkpString(dkp);
		end
	end
	
	localEcho("Testing Guild DKP decay using a "..percent.."% decay value.");
	localEcho("Decay will remove a total of "..reducedDkp.." DKP from ".. playerCount .." players.")
	
	return true;
end


--[[
--	Perform Guild Decay of <n>% DKP
--	This function requires Show Offline Members to be enabled.
--]]
function SOTA_Call_DecayDKP(percent)
	SOTA_AddJob( function(job) SOTA_DecayDKP(job[2]) end, percent, "_" )
	SOTA_RequestUpdateGuildRoster();
end
function SOTA_DecayDKP(percent, silentmode)
	--	Note: arg may contain a percent sign; remove this first:
	if not tonumber(percent) then
		local pctSign = string.sub(percent, string.len(percent), string.len(percent));
		if pctSign == "%" then
			percent = string.sub(percent, 1, string.len(percent) - 1);
		end
	end
	
	if not tonumber(percent) then
		if not silentmode then
			localEcho("Guild Decay cancelled: Percent is not a valid number: ".. percent);
		end
		return false;
	end
	
	percent = abs(1 * percent);

	--	This ensure the guild roster also contains Offline members.
	--	Otherwise offline members will not get decayed!
	if not GetGuildRosterShowOffline() == 1 then
		if not silentmode then
			localEcho("Guild Decay cancelled: You need to enable Offline Guild Members in the guild roster first.")
		end
		return false;
	end

	local tidIndex = 1;
	local tidChanges = { };

	local reducedDkp = 0;
	local playerCount = 0;

	--	Iterate over all guilded players - online or not
	local name, publicNote, officerNote
	local memberCount = GetNumGuildMembers();
	for n=1,memberCount,1 do
		name, _, _, _, _, _, publicNote, officerNote = GetGuildRosterInfo(n);
		local note = officerNote;
		if SOTA_CONFIG_UseGuildNotes == 1 then
			note = publicNote;
		end

		local _, _, dkp = string.find(note, "<(-?%d*)>");
		if dkp and tonumber(dkp) then
			local minus = floor(dkp * percent / 100)
			tidChanges[tidIndex] = { name, (-1 * minus) }
			tidIndex = tidIndex + 1
			
			dkp = dkp - minus;
			reducedDkp = reducedDkp + minus;
			playerCount = playerCount + 1;
			note = string.gsub(note, "<(-?%d*)>", SOTA_CreateDkpString(dkp), 1);
		else
			dkp = 0;
			note = note..SOTA_CreateDkpString(dkp);
		end
		
		if SOTA_CONFIG_UseGuildNotes == 1 then
			GuildRosterSetPublicNote(n, note);
		else
			GuildRosterSetOfficerNote(n, note);
		end
		
		SOTA_UpdateLocalDKP(name, dkp);
	end
	
	if not silentmode then
		guildEcho("Guild DKP decay by "..percent.."% was performed by ".. UnitName("player") ..".")
		guildEcho("Guild DKP removed a total of "..reducedDkp.." DKP from ".. playerCount .." players.")
	end
	
	SOTA_LogMultipleTransactions("-Decay", tidChanges)
	
	return true;
end


--[[
--	Include <player> in an existing (multi-line) transaction
--]]
function SOTA_Call_IncludePlayer(transactionID, playername)
	if SOTA_IsInRaid(true) then
		RaidState = RAID_STATE_ENABLED;
		SOTA_AddJob( function(job) SOTA_IncludePlayer(job[2], job[3]) end, transactionID, playername )
		SOTA_RequestUpdateGuildRoster();
	end
end
function SOTA_IncludePlayer(transactionID, playername, silentmode, skipApplyDkp)
	local transaction = SOTA_GetTransaction(transactionID);
	if not transaction then
		debugEcho(string.format("SOTA_IncludePlayer: Transaction not found, TID=%s", transactionID));
		return;
	end

	if not (table.getn(transaction[6]) > 0) then
		debugEcho(string.format("SOTA_IncludePlayer: There must be at least one person already, since DKP value is stored there! TID=%s", transactionID));
		return;	
	end

	-- Fetch the first valid DKP value:
	local dkpValue = 1 * (transaction[6][1][2]);	
	playername = SOTA_UCFirst(playername);


	-- Check type: It must be a Multi-line type, except for Decay:
	local trType = transaction[4];
	local validTypes = { "-Raid", "+Raid", "+Share", "+Range" }
	local found = false;
	for n=1, table.getn(validTypes), 1 do
		if validTypes[n] == trType then
			found = 1;
			break;
		end
	end
	if not found then
		debugEcho(string.format("SOTA_IncludePlayer: Invalid transaction type in TID=%s : %s", transactionID, trType));
		return;
	end
	
	-- Check player is not in the transaction already:
	for n=1, table.getn(transaction[6]), 1 do
		if transaction[6][n][1] == playername then
			debugEcho(string.format("SOTA_IncludePlayer: Player %s already exists in transaction TID=%s", playername, transactionID));
			return;
		end
	end

	transaction[6][ table.getn(transaction[6]) + 1] = { playername, dkpValue };
	debugEcho(string.format("SOTA_IncludePlayer: Player %s included in TID=%s", playername, transactionID));

	if not skipApplyDkp then	
		if SOTA_ApplyPlayerDKP(playername, dkpValue) then
			SOTA_LogIncludeExcludeTransaction("Include", playername, transactionID, dkpValue);

			localEcho(string.format("%s was included in transaction %d for %d DKP", playername, transactionID, dkpValue));
		end
	end
end


--[[
--	Exclude <player> from an existing (multi-line) transaction
--]]
function SOTA_Call_ExcludePlayer(transactionID, playername)
	if SOTA_IsInRaid(true) then
		RaidState = RAID_STATE_ENABLED;
		SOTA_AddJob( function(job) SOTA_ExcludePlayer(job[2], job[3]) end, transactionID, playername )
		SOTA_RequestUpdateGuildRoster();
	end
end
function SOTA_ExcludePlayer(transactionID, playername, silentmode, skipApplyDkp)
	local transaction = SOTA_GetTransaction(transactionID);
	if not transaction then
		if not transactionID then
			transactionID = "(NIL)";
		end
		debugEcho(string.format("Transaction with TID=%s was not found; cannot exclude player", transactionID));
		return;
	end

	playername = SOTA_UCFirst(playername);
	
	-- Check type: It must be a Multi-line type, except for Decay:
	local trType = transaction[4];
	local validTypes = { "-Raid", "+Raid", "+Share", "+Range" }
	local found = false;
	for n=1, table.getn(validTypes), 1 do
		if validTypes[n] == trType then
			found = 1;
			break;
		end
	end	
	if not found then
		debugEcho("Invalid transaction type: ".. trType);
		return;
	end

	-- Find player in the transaction:
	local dkpValue = nil;
	local newtable = { };
	for n=1, table.getn(transaction[6]), 1 do
		if transaction[6][n][1] == playername then
			dkpValue = transaction[6][n][2];
		else
			newtable[ table.getn(newtable) + 1] = transaction[6][n];
		end
	end
	transaction[6] = newtable;

	if not dkpValue then
		if not playername then
			playername = "(NIL)";
		end
		if not transactionID then
			transactionID = "(NIL)";
		end		
		debugEcho(string.format("The player %s was not found in the transaction with TID=%s; cannot exclude player", playername, transactionID));
		return;
	end
	
	if not skipApplyDkp then
		if SOTA_ApplyPlayerDKP(playername, -1 * dkpValue) then
			SOTA_LogIncludeExcludeTransaction("Exclude", playername, transactionID, dkpValue);			
			localEcho(string.format("%s was excluded from transaction %d for %d DKP", playername, transactionID, dkpValue));
		end
	end
end


--[[
--	Generic function to add(or remove) DKP from a player.
--]]
function SOTA_ApplyPlayerDKP(playername, dkpValue, silentmode)
	dkpValue = 1 * dkpValue;
	
	playername = SOTA_UCFirst(playername);
	
	local memberCount = GetNumGuildMembers()
	for n=1,memberCount,1 do
		name, _, _, _, _, _, publicNote, officerNote = GetGuildRosterInfo(n);
		if name == playername then
			local note = officerNote;
			if SOTA_CONFIG_UseGuildNotes == 1 then
				note = publicNote;
			end
		
			local _, _, dkp = string.find(note, "<(-?%d*)>");

			if dkp and tonumber(dkp)  then
				dkp = (1 * dkp) + dkpValue;
				note = string.gsub(note, "<(-?%d*)>", SOTA_CreateDkpString(dkp), 1);
			else
				dkp = dkpValue;
				note = note..SOTA_CreateDkpString(dkp);
			end
			
			if SOTA_CONFIG_UseGuildNotes == 1 then
				GuildRosterSetPublicNote(n, note);
			else
				GuildRosterSetOfficerNote(n, note);
			end
			
			SOTA_UpdateLocalDKP(name, dkp);			
			return true;
		end
   	end
   	
   	if not silentmode then
   		localEcho(string.format("%s was not found in the guild; DKP was not updated.", playername));
   	end
   	return false;
end


--[[
--	Update local stored DKP
--	Input: receiver, dkpadded
]]
function SOTA_UpdateLocalDKP(receiver, dkpAdded)

	local raidRoster = SOTA_GetRaidRoster();	--{ Name, DKP, Class, Rank, Online }
	for n=1, table.getn(raidRoster),1 do
		local player = raidRoster[n];
		local name = player[1];
		local dkp = player[2];
		local class = player[3];
		local rank = player[4];
		local online = player[5];

		if receiver == name then
			if dkp then
				dkp = dkp + dkpAdded;
			else
				dkp = dkpAdded;
			end
			
			raidRoster[n] = {name, dkp, class, rank, online};
			return;
		end
	end
end

function SOTA_CreateDkpString(dkp)
	local result;
	
	if not dkp or dkp == "" or not tonumber(dkp) then
		dkp = 0;
	end
	dkp = tonumber(dkp);
	
	local dkpLen = tonumber(SOTA_CONFIG_DKPStringLength);
	if dkpLen > 0 then
		local dkpStr = "".. abs(dkp)
		while string.len(dkpStr) < dkpLen do
			dkpStr = "0"..dkpStr;
		end
		if dkp < 0 then
			dkpStr = "-"..dkpStr;
		end				
		result = "<"..dkpStr..">";
	else
		result = "<"..dkp..">";
	end
	
	return result;
end

function SOTA_ToggleIncludePlayerInTransaction(playername)
	if not playername or not SOTA_selectedTransactionID then
		return;
	end

	local transaction = SOTA_GetTransaction(SOTA_selectedTransactionID);
	if not transaction then
		return;
	end

	-- See if the player is included in the transaction already:
	local currentPlayername = "";
	local includedInTransaction = false;
	local trInfo = transaction[6];
	local trSize = table.getn(trInfo);
	for n=1, trSize, 1 do
		currentPlayername = trInfo[n][1];
		if currentPlayername == playername then
			includedInTransaction = true;
			break;
		end
	end
	
	
	-- Check transaction types:
	local singlePlayerTransaction = false;
	local multiPlayerTransaction = false;
	local trType = transaction[4];

	local validTypes = { "-Player", "+Player", "%Player" }
	for n=1, table.getn(validTypes), 1 do
		if validTypes[n] == trType then
			singlePlayerTransaction = true;
			break;
		end
	end	

	local validTypes = { "-Raid", "+Raid", "+Share", "+Range" }
	for n=1, table.getn(validTypes), 1 do
		if validTypes[n] == trType then
			multiPlayerTransaction = true;
			break;
		end
	end	

	local tInfo = SOTA_transactionLog[SOTA_selectedTransactionID];
	if not tInfo then
		return;
	end
	-- Already undone:
	if tInfo[5] == 0 then
		return;
	end
	
	if includedInTransaction then
		if singlePlayerTransaction then
			--	Single-player transaction, clicked on Current player; offer to cancel transaction:
			SOTA_RequestUndoTransaction(transactionID);
		elseif multiPlayerTransaction then
			--	Multiplayer transaction, clicked on current player. Offer to exclude player:
			StaticPopupDialogs["SOTA_POPUP_TRANSACTION_PLAYER"] = {
				text = string.format("Do you want to exclude %s from this transaction?", playername),
				button1 = "Yes",
				button2 = "No",
				OnAccept = function() SOTA_ExcludePlayerFromTransaction(SOTA_selectedTransactionID, playername)  end,
				timeout = 0,
				whileDead = true,
				hideOnEscape = true,
				preferredIndex = 3,
			}
			StaticPopup_Show("SOTA_POPUP_TRANSACTION_PLAYER");	
		end	
	else
		if singlePlayerTransaction then		
			--	Single-player transaction, clicked on Other player; offer to replace player:
			StaticPopupDialogs["SOTA_POPUP_TRANSACTION_PLAYER"] = {
				text = string.format("Do you want to replace %s with %s ?", currentPlayername, playername),
				button1 = "Yes",
				button2 = "No",
				OnAccept = function() SOTA_ReplacePlayerInTransaction(SOTA_selectedTransactionID, currentPlayername, playername)  end,
				timeout = 0,
				whileDead = true,
				hideOnEscape = true,
				preferredIndex = 3,
			}
			StaticPopup_Show("SOTA_POPUP_TRANSACTION_PLAYER");	
		elseif multiPlayerTransaction then
			--	Multiplayer transaction, clicked on current player. Offer to exclude player:
			StaticPopupDialogs["SOTA_POPUP_TRANSACTION_PLAYER"] = {
				text = string.format("Do you want to include %s to this transaction?", playername),
				button1 = "Yes",
				button2 = "No",
				OnAccept = function() SOTA_IncludePlayerInTransaction(SOTA_selectedTransactionID, playername)  end,
				timeout = 0,
				whileDead = true,
				hideOnEscape = true,
				preferredIndex = 3,
			}
			StaticPopup_Show("SOTA_POPUP_TRANSACTION_PLAYER");	
		end	
	end	
end



--
--	MinBidStrategy
--
local function strategy10DKP(dkp)
	return 10 + dkp;
end

local function strategy10Percent(dkp)
	return 1.10 * dkp;
end

--	Goldshire Golfclub rules:
--	0-200: +10 DKP
--	200-1K: +50 DKP
--	1K+: 100 DKP
local function strategyGGCRules(dkp)
	if dkp < 200 then
		dkp = dkp + 10;
	elseif dkp < 1000 then
		dkp = dkp + 50;
	else
		dkp = dkp + 100;
	end
	
	return dkp;
end

-- Deja Vu rules:
-- Minimum bid: 100 DKP
--	100-4999: +100 DKP
-- 5000+: 1000 DKP
--
local function strategyDejaVuRules(dkp)
	if dkp < 100 then
		dkp = 100;
	elseif dkp < 5000 then
		dkp = dkp + 100;
	else 
		dkp = dkp + 1000;
	end;
	return dkp;
end;


function SOTA_GetStartingDKP()
	-- Deja Vu rules: starting bid is always 100 DKP
	if SOTA_CONFIG_MinimumBidStrategy == 4 then
		return 100;
	end;


	-- TODO: Detect current instance (if any) and calculate starting DKP.
	local startingDKP = 0;
	local zonetext = GetRealZoneText();
	local subzone = GetSubZoneText();
	if not zonetext then
		zonetext = "";
	end
	if not subzone then
		subzone = ""
	end
	
	if zonetext == "Zul'Gurub" or zonetext == "Ruins of Ahn'Qiraj" --[[or (zonetext == "Gates of Ahn'Qiraj" and posX >= 0.422)]] then
		startingDKP = SOTA_GetBossDKPValue("20Mans") / 10;				-- Verified
	elseif zonetext == "Molten Core" then
		startingDKP = SOTA_GetBossDKPValue("MoltenCore") / 10;			-- Verified
	elseif zonetext == "Onyxia's Lair" --[[or (zonetext == "Dustwallow Marsh" and subzone == "Wyrmbog")]] then
		startingDKP = SOTA_GetBossDKPValue("Onyxia") / 10;				-- Verified
	elseif zonetext == "Blackwing Lair" then
		startingDKP = SOTA_GetBossDKPValue("BlackwingLair") / 10;
	elseif zonetext == "Ahn'Qiraj" --[[or (zonetext == "Gates of Ahn'Qiraj" and posX < 0.422)]] then
		startingDKP = SOTA_GetBossDKPValue("AQ40") / 10;				-- Verified
	elseif zonetext == "Naxxramas" then
		startingDKP = SOTA_GetBossDKPValue("Naxxramas") / 10;
	elseif	zonetext == "Feralas" or zonetext == "Ashenvale" or zonetext == "Azshara" or 
			zonetext == "Duskwood" or zonetext == "Blasted Lands" or zonetext == "The Hinterlands" then
		startingDKP = SOTA_GetBossDKPValue("WorldBosses") / 10;
	else
		-- Debug:
		--echo("Unknown zone: ".. zonetext)
	end	

	return startingDKP;
end


--[[
--	Return Instance and Outsize zone for which shared DKP will be given.
--	If NIL values, then no zone was found.
--]]
function SOTA_GetValidDKPZones()
	local validZones = { nil, nil };

	local zonetext = GetRealZoneText();
	if not zonetext then
		zonetext = "";
	elseif zonetext == "Zul'Gurub" then
		validZones = { zonetext, "Stranglethorn Vale" };
	elseif zonetext == "Ruins of Ahn'Qiraj" then 
		validZones = { zonetext, "Gates of Ahn'Qiraj" };
	elseif zonetext == "Molten Core" then 
		validZones = { zonetext, "Blackrock Mountain" };
	elseif zonetext == "Onyxia's Lair" then 
		validZones = { zonetext, "Dustwallow Marsh" };
	elseif zonetext == "Blackwing Lair" then 
		validZones = { zonetext, "Blackrock Mountain" };
	elseif zonetext == "Ahn'Qiraj" then 
		validZones = { zonetext, "Gates of Ahn'Qiraj" };
	elseif zonetext == "Naxxramas" then 
		validZones = { zonetext, "Eastern Plaguelands" };
	elseif zonetext == "Feralas" or zonetext == "Ashenvale" or zonetext == "Azshara" or 
		zonetext == "Duskwood" or zonetext == "Blasted Lands" or zonetext == "The Hinterlands" then
		validZones = { zonetext, zonetext };
	end
	
	return validZones[1], validZones[2];
end


--[[
--	Get current minimum bid.
--	Bidtype is set if specific bid type is wanted. If nil (default), then all bid types are accepted.
--	bidtype 1 = MS
--	bidtype 2 = OS
--]]
function SOTA_GetMinimumBid(bidtype)
	local minimumBid = SOTA_GetStartingDKP();
	if minimumBid == 0 then
		minimumBid = 10;
	end

	local highestBid = SOTA_GetHighestBid(bidtype);
	if not highestBid then
		-- This is first bid = the minimum
		return minimumBid;
	end
	
	--	OS bidders cannot bid if a MS bid is already placed!
	if bidtype == 2 and highestBid[3] == 1 then
		return nil
	end
	
	minimumBid = 1 * (highestBid[2]);

	--echo("BidType="..bidtype ..", MinBid=".. minimumBid ..", strategy=".. SOTA_CONFIG_MinimumBidStrategy);

	if SOTA_CONFIG_MinimumBidStrategy == 1 then
		minimumBid = strategy10DKP(minimumBid);
	elseif SOTA_CONFIG_MinimumBidStrategy == 2 then
		minimumBid = strategy10Percent(minimumBid);
	elseif SOTA_CONFIG_MinimumBidStrategy == 3 then
		minimumBid = strategyGGCRules(minimumBid);
	elseif SOTA_CONFIG_MinimumBidStrategy == 4 then
		minimumBid = strategyDejaVuRules(minimumBid);
	elseif SOTA_CONFIG_MinimumBidStrategy == 5 then
		-- TODO: Custom bidding currently does not define any custom min.bid strategy
		minimumBid = strategyDejaVuRules(minimumBid);
	else
		-- Fallback strategy (no strategy)
		minimumBid = minimumBid + 1;
	end

	return floor(minimumBid);
end;


function SOTA_GetConfigurableTextMessages()
	return SOTA_CONFIG_Messages;
end;

function SOTA_SetConfigurableTextMessages(messages)
	SOTA_CONFIG_Messages = messages;
end;
