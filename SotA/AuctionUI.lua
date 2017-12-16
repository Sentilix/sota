--[[
	Author      : Mimma VanillaGaming>
	Create Date : 03-04-2017 11:53:48
	
	SotA - State of the Art DKP Addon
--]]

local SOTA_MESSAGE_PREFIX		= "SOTAv1"
local SOTA_TITLE				= "SotA"

local SOTA_DEBUG_ENABLED		= false;

local CHAT_END					= "|r"
local COLOUR_INTRO				= "|c80F0F0F0"
local COLOUR_CHAT				= "|c8040A0F8"

local PARTY_CHANNEL				= "PARTY"
local RAID_CHANNEL				= "RAID"
local YELL_CHANNEL				= "YELL"
local SAY_CHANNEL				= "SAY"
local WARN_CHANNEL				= "RAID_WARNING"
local GUILD_CHANNEL				= "GUILD"
local WHISPER_CHANNEL			= "WHISPER"


--	Settings (persisted)
-- Pane 1:
SOTA_CONFIG_AuctionTime			= 20
SOTA_CONFIG_AuctionExtension	= 8
SOTA_CONFIG_EnableOSBidding		= 1;	-- Enable MS bidding over OS
SOTA_CONFIG_EnableZonecheck		= 1;	-- Enable zone check when doing raid queue DKP
SOTA_CONFIG_DisableDashboard	= 0;	-- Disable Dashboard in UI (hide it)

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
SOTA_CONFIG_UseGuildNotes		= 0;
SOTA_CONFIG_MinimumBidStrategy	= 1;	-- 0: No strategy, 1: +10 DKP, 2: +10 %, 3: GGC rules
SOTA_CONFIG_DKPStringLength		= 5;
SOTA_CONFIG_MinimumDKPPenalty	= 50;	-- Minimum DKP withdrawn when doing percent DKP


--	State machine:
local STATE_NONE				= 0
local STATE_AUCTION_RUNNING		= 10
local STATE_AUCTION_PAUSED		= 20
local STATE_AUCTION_COMPLETE	= 30
local STATE_PAUSED				= 90

-- An action runs for a minimum of 20 seconds, and minimum 5 seconds after a new bid is received
local GUILD_REFRESH_TIMER		= 5;		-- Check guild update every 5th second

local RAID_STATE_DISABLED		= 0
local RAID_STATE_ENABLED		= 1
-- UI Status: True = Open, False = Closed - use to prevent update of UI elements when closed.
local RaidQueueUIOpen			= false;
local TransactionUIOpen			= false;
local TransactionDetailsOpen	= false;

-- Max # of bids shown in the AuctionUI
local MAX_BIDS					= 10
-- List of valid bids: { Name, DKP, BidType(MS=1,OS=2), Class, Rank }
local IncomingBidsTable			= { };

-- true if a job is already running
local JobIsRunning				= false


--[[
--	Master / Slave setup
--	--------------------
--	In order to use the "!" commands in gchat and raid chat correctly only one SOTA client
--	should respond to those commands. If not, a queue command would result in multiple
--	whispers: one for each SOTA client!
--
--	When a new client joins the raid, the client must issue a "WHO_IS_MASTER" request if client
--	is eligible to be Helper or Master (see pre-requisites).
--	The master (or helper) must respond back with "I_AM_MASTER" (see below), which will stop the
--	client for further requests.
--	
--	Should the Helper or Master log out / disconnect, another "master" must be found. Therefore
--	the client must issue a "WHO_IS_MASTER" (all eligible clients will do that), and each client
--	eligible for being master must respons back with their current state (which for now is SLAVE,
--	and a unique identifier (the logon time?). The client with the lowest identifier will be
--	promoted as Helper.
--	If no answer is received within <n> seconds, the client must promote himself to "HELPER"
--	(state=1).
--
--	Should a client issue a DKP command or start a bidding round, he will be promoted to Master
--	instantly. He must then send a "I_AM_MASTER" to all clients, thus demoting all other clients
--	to slave (state=0) - including an eventual Helper.
--
--	Pre-requisites to become promoted (and master):
--	* Can invite to Raid (raid leader/promoted)
--	* (can read notes? is that needed? Doubt so)
local CLIENT_STATE_SLAVE		= 0;		-- Client is only listening
local CLIENT_STATE_HELPER		= 1;		-- Client was promoted (passive master)
local CLIENT_STATE_MASTER		= 2;		-- Client issued a DKP command (active master)
local CLIENT_IDENTIFIER			= time();	-- Unique client identifier: current time.
local CLIENT_STATE				= CLIENT_STATE_SLAVE
--]]

--	For now the one issuing DKP or starting a BID round will be master. All other will be passive.
--	Helper is not supported.
local CLIENT_STATE_SLAVE		= 0;		-- Client is only listening
local CLIENT_STATE_MASTER		= 2;		-- Client issued a DKP command (active master)
local CLIENT_STATE				= CLIENT_STATE_SLAVE

local SOTA_Master				= nil;		-- Current master




-- Working variables:
local RaidState					= RAID_STATE_DISABLED
local AuctionedItemLink			= ""
local AuctionState				= STATE_NONE

-- Raid Roster: table of raid players:		{ Name, DKP, Class, Rank, Online }
local RaidRosterTable			= { }
-- Guild Roster: table of guild players:	{ Name, DKP, Class, Rank, Online, Zone }
local GuildRosterTable			= { }
local RaidRosterLazyUpdate		= false;
-- Max # of characters displayes per role in the Raid Queue UI. A caption will be inserted in top.
local MAX_RAID_QUEUE_SIZE		= 8;
-- Max # of transaction logs shown in UI (excluding Header)
local MAX_TRANSACTIONS_DISPLAYED= 18;
-- Max # of lines for class dkp displayed locally:
local MAX_CLASS_DKP_DISPLAYED	= 10;
-- Max # of lines for class dkp sent by whisper:
local MAX_CLASS_DKP_WHISPERED	= 5;

--	List of {jobname,name,dkp} tables
local JobQueue					= { }
--	Holds current Zone name - used for checking for new Zones(Instances primarily)
local CurrentZoneName			= nil;
-- Unique number for each queued raid member. Used for Sorting.
local QueueID					= 1;
-- Queued raid members: { Name, QueueID, Role , Class }
local RaidQueue					= { }

--  Transaction log: Contains a list of { timestamp, tid, author, description, state, { names, dkp } }
--	Transaction state: 0=Rolled back, 1=Active (default), 
local transactionLog			= { }
--	Current transactionID, starts out as 0 (=none).
local currentTransactionID		= 0;
local currentTransactionPage	= 1;	-- Current page shown (1=first page)
local selectedTransactionID		= nil;
--	Sync.state: 0=idle, 1=initializing, 2=synchronizing
local synchronizationState		= 0;
--	Hold RX_SYNCINIT responses when querying for a client to sync. { message, id/count }
local syncResults				= { };
local syncRQResults				= { };

--	# of transactions displayed in /gdlog
local TRANSACTION_LIST_SIZE		= 5;
--	# of player names displayed per line when posting transaction log into guild chat
local TRANSACTION_PLAYERS_PER_LINE	= 8;
local TRANSACTION_STATE_ROLLEDBACK	= 0;
local TRANSACTION_STATE_ACTIVE		= 1;
--	Setting for transaction details screen:
local TRANSACTION_DETAILS_ROWS		= 18;
local TRANSACTION_DETAILS_COLUMNS	= 4;




local QUALITY_COLORS = {
	{0, "Poor",			{ 157,157,157 } },	--9d9d9d
	{1, "Common",		{ 255,255,255 } },	--ffffff
	{2, "Uncommon",		{  30,255,  0 } },	--1eff00
	{3, "Rare",			{   0,112,255 } },	--0070ff
	{4, "Epic",			{ 163, 53,238 } },	--a335ee
	{5, "Legendary",	{ 255,128,  0 } }	--ff8000
}

local CLASS_COLORS = {
	{ "Druid",			{ 255,125, 10 } },	--255 	125 	10		1.00 	0.49 	0.04 	#FF7D0A
	{ "Hunter",			{ 171,212,115 } },	--171 	212 	115 	0.67 	0.83 	0.45 	#ABD473 
	{ "Mage",			{ 105,204,240 } },	--105 	204 	240 	0.41 	0.80 	0.94 	#69CCF0 
	{ "Paladin",		{ 245,140,186 } },	--245 	140 	186 	0.96 	0.55 	0.73 	#F58CBA
	{ "Priest",			{ 255,255,255 } },	--255 	255 	255 	1.00 	1.00 	1.00 	#FFFFFF
	{ "Rogue",			{ 255,245,105 } },	--255 	245 	105 	1.00 	0.96 	0.41 	#FFF569
	{ "Shaman",			{ 245,140,186 } },	--245 	140 	186 	0.96 	0.55 	0.73 	#F58CBA
	{ "Warlock",		{ 148,130,201 } },	--148 	130 	201 	0.58 	0.51 	0.79 	#9482C9
	{ "Warrior",		{ 199,156,110 } }	--199 	156 	110 	0.78 	0.61 	0.43 	#C79C6E
}


--[[
	Echo a message for the local user only, including "logo"
]]
local function echo(msg)
	if msg then
		DEFAULT_CHAT_FRAME:AddMessage(COLOUR_CHAT .. msg .. CHAT_END)
	end
end

local function debugEcho(msg)
	if SOTA_DEBUG_ENABLED and msg then
		DEFAULT_CHAT_FRAME:AddMessage(COLOUR_CHAT .. "DEBUG: ".. msg .. CHAT_END)
	end
end

local function gEcho(msg)
	echo("<"..COLOUR_INTRO..SOTA_TITLE..COLOUR_CHAT.."> "..msg);
end

local function rwEcho(msg)
	SendChatMessage(msg, WARN_CHANNEL);
end

--[[
	SOTA specific RW: Apply <SotA> to message
]]
local function SOTA_rwEcho(msg)
	rwEcho(string.format("[%s] %s", SOTA_TITLE, msg));
end

local function raidEcho(msg)
	SendChatMessage(msg, RAID_CHANNEL);
end

function guildEcho(msg)
	SendChatMessage(msg, GUILD_CHANNEL)
end

local function addonEcho(msg)
	SendAddonMessage(SOTA_MESSAGE_PREFIX, msg, "RAID")
end

local function whisper(receiver, msg)
	if receiver == UnitName("player") then
		gEcho(msg);
	else
		SendChatMessage(msg, WHISPER_CHANNEL, nil, receiver);
	end
end



--
--	SLASH COMMANDS
--

--[[
Commands:

Note that "!" commands are only executed by the client with MASTER or HELPER status to avoid
spamming multiple whispers to target.

GuildDKP            SOTA /command       SOTA !command       SOTA /w command     Comment
------------------- ------------------- ------------------- ------------------- ------------------- 
/dkp                /SOTA dkp [player]  -                   /w <o> dkp [<p>]    Current DKP status for player
/classdkp           /SOTA class [class] -                   /w <o> class [<c>]  Current DKP status for class (gdclass)

/gdplus <n> <p>     /SOTA +<n> <p>      -                   -                   Add <n> DKP to player <p>
/gdminus <n> <p>    /SOTA -<n> <p>      -                   -                   Subtract <n> DKP from player <p>
/gdminuspct <n> <p> /SOTA [-]<n>% <p>   -                   -                   Subtract <n>% DKP from player (+<n>% does not exist)

/addraid <n>        /SOTA raid +<n>     -                   -                   Add <n> DKP to all players in raid (SOTA: and queue)
/subtractraid <n>   /SOTA raid -<n>     -                   -                   Subtract <n> DKP from players in raid (SOTA: and queue)
/addrange <n>       /SOTA range [+]<n>  -                   -                   Add <n> DKP to all players in range (SOTA: and queue)
/shareraid <n>      /SOTA share [+]<n>  -                   -                   Share <n> DKP across all members in raid (SOTA: and queue)
/sharerange <n>     /SOTA sharerange [+]<n>                 -                   Share <n> DKP across all members in range (SOTA: and queue)
					/SOTA rangeshare [+]<n>					-					sharerange and rangeshare (and the alias SR) so the same.
/gddecay <n>        /SOTA decay <n>[%]  -                   -                   Remove <n>% DKP from all guild members

-                   /SOTA queue         !queue              /w <o> queue        Get queue status
-                   /SOTA queue <r>     !queue <r>          /w <o> queue <r>    Queue as role <r>: <r> can be tank, melee, ranged or healer
-                   /SOTA addqueue <p>  -                   -                   Add person <p> manually to the queue. Must be promoted.
-                   /SOTA leave         !leave              /w <o> leave        Leave the raid queue (can be done by players in raid)

-                   /SOTA <item>        -                   -                   Starts an auction for <item>
                    /startauction
-                   /SOTA bid <n>       !bid <n>            /w <o> bid <n>      Bid <n> DKP on item currently being auctioned
-                   /SOTA bid min       !bid min            /w <o> bid min      Bid the minimum bid on item currently being auctioned
-                   /SOTA bid max       !bid max            /w <o> bid max      Bid everyting (go all out) on item currently being auctioned

-					/SOTA config		-					-					Open the configuration interface
-					/SOTA log			-					-					Open the transaction log interface
-					/SOTA version		-					-					Check the SOTA versions running
-					/SOTA master		-					-					Force player to become Master (if he is raid leader or assistant)

/gdhelp				/SOTA help			-					-					Show HELP page (more or less this page!)
]]


--[[
--	/SOTA - main command entry handler
--]]
SLASH_SOTA_DEFAULT_COMMAND1 = "/SOTA"
SlashCmdList["SOTA_DEFAULT_COMMAND"] = function(msg)
	SOTA_HandleSOTACommand(msg);
end




function SOTA_HandleSOTACommand(msg)
	local playername = UnitName("player");
	local sign;

	--	Command: <item>
	--	Syntax: "<itemlink>"
	local _, _, itemId = string.find(msg, "item:(%d+):")
	if itemId then
		return SOTA_StartAuction(msg);
	end

		
	-- Split command into cmd (mandatory) and arg (optional)
	msg = string.lower(msg);
	local cmd, arg;
	local playerclass, playerrole;
	
	local spacepos = string.find(msg, "%s");
	if spacepos then
		_, _, cmd, arg = string.find(msg, "(%S+)%s+(.+)");
	else
		cmd = msg;
	end
	


	-- if cmd == "test" then
		-- local zonetext = GetRealZoneText();
		-- local subzone = GetSubZoneText();
		-- if subzone and not subzone == "" then
			-- gEcho(string.format("Zone: <%s> - sub zone: <%s>", zonetext, subzone));
		-- else
			-- gEcho(string.format("Zone: <%s>", zonetext));
		-- end
		-- return;	
	-- end



	--	Command: help
	--	Syntax: "config"	
	if cmd == "help" or cmd == "?" or cmd == "" then
		SOTA_DisplayHelp();
		return;	
	end


	--	Command: config
	--	Syntax: "config"	
	if cmd == "cfg" or cmd == "config" then
		SOTA_DisplayConfigurationScreen();
		return;	
	end


	--	Command: master
	--	Syntax: "master"	
	if cmd == "master" then
		SOTA_RequestMaster(false);
		return;	
	end


	-- --	Command: sync
	-- --	Syntax: "sync"	
	-- --	Currently not working due to Timer not set up.
	-- if cmd == "sync" then
		-- if synchronizationState == 0 then
			-- SOTA_Synchronize();
		-- else
			-- gEcho("A synchronization task is already running!");
		-- end
		-- return;	
	-- end
	-- 
	
	--	Command: version
	--	Syntax: "version"
	if cmd == "version" then
		if SOTA_IsInRaid(true) then
			addonEcho("TX_VERSION##");
		else
			gEcho(string.format("%s is using SOTA version %s", UnitName("player"), GetAddOnMetadata("SOTA", "Version")));
		end
		return;
	end
	
	
	--	Command: log
	--	Syntax: "log"
	if cmd == "log" then
		if arg and tonumber(arg) then
			selectedTransactionID = arg;
			SOTA_RefreshTransactionDetails();
			SOTA_OpenTransactionDetails();
		else	
			SOTA_OpenTransauctionUI();
		end
		return;
	end
	

	--	Command: dkp
	--	Syntax: "dkp [<playername>]"
	if cmd == "dkp" then
		return SOTA_Call_CheckPlayerDKP(arg);
	end

	--	Command: class
	--	Syntax: "class [<classname>]"
	if cmd == "class" then
		return SOTA_Call_CheckClassDKP(arg);
	end

	--	Command: queue
	--	Syntax: "queue [<role>]", "queue leave" (will fallback to "leave" below)
	if cmd == "queue" then
		if arg == "leave" then
			cmd = arg;
			arg = nil;
		else
			return SOTA_HandleQueueRequest(playername, msg);
		end
	end
	
	--	Command: addqueue
	--	Syntax: "addqueue"
	if cmd == "addqueue" then
		if SOTA_IsPromoted then
			if not SOTA_Master then
				SOTA_RequestMaster();
			end
			return SOTA_AddToRaidQueueByName(arg);
		end
		return;
	end
	
	
	--	Command: leave
	--	Syntax: "leave"
	if cmd == "leave" then
		return SOTA_RemoveFromRaidQueue(playername);
	end
	
	--	Command: bid, os, ms
	--	Syntax: "bid <%d>", "bid min", "bid max"
	if cmd == "bid" or cmd == "ms" or cmd == "os" then
		return SOTA_HandlePlayerBid(playername, msg);
	end
	
	
	if cmd == "raid" then
		sign = string.sub(arg, 1, 1);
		--	Command: raid
		--	Syntax: "raid -<%d>"
		if sign == "-" then
			arg = string.sub(arg, 2);
			return SOTA_Call_SubtractRaidDKP(arg);
		--	Command: raid
		--	Syntax: "raid +<%d>"
		elseif sign == "+" then
			arg = string.sub(arg, 2);
			return SOTA_Call_AddRaidDKP(arg);
		else
			gEcho("DKP must be written as +999 or -999");
			return;
		end
	end

	if cmd == "range" then
		sign = string.sub(arg, 1, 1);
		--	Command: range
		--	Syntax: "range [+]<%d>"
		--	Plus is optional (default)
		if sign == "+" then
			arg = string.sub(arg, 2);
		end
		return SOTA_Call_AddRangedDKP(arg);
	end

	if cmd == "share" then
		--	Command: share
		--	Syntax: "share [[+]<%d>]"
		--	Parameter is optional; if omitted, current Boss DKP will be shared.
		--	Plus is optional (default, undocumented)
		if not arg or arg == "" then
			arg = SOTA_GetMinimumBid() * 10;
			if arg == 0 then
				gEcho("Boss DKP value could not be calculated - DKP was not shared.");
				return;
			end
		else
			sign = string.sub(arg, 1, 1);
			if sign == "+" then
				arg = string.sub(arg, 2);
			end
		end
		return SOTA_Call_ShareDKP(arg);
	end	

	if cmd == "sharerange" or
	   cmd == "rangeshare" or
	   cmd == "sr" then
		--	Command: sharerange / rangeshare / sr
		--	Syntax: "sharerange [[+]<%d>]"
		--	Parameter is optional; if omitted, current Boss DKP will be shared.
		--	Plus is optional (default, undocumented)
		if not arg or arg == "" then
			arg = SOTA_GetMinimumBid() * 10;
			if arg == 0 then
				gEcho("Boss DKP value could not be calculated - DKP was not shared.");
				return;
			end
		else
			sign = string.sub(arg, 1, 1);
			if sign == "+" then
				arg = string.sub(arg, 2);
			end
		end
		return SOTA_Call_ShareRangedDKP(arg);
	end	

	--	Command: decay
	--	Syntax: "decay <%d>[%]"
	if cmd == "decay" then
		return SOTA_Call_DecayDKP(arg);		
	end


	--	Ok, the <cmd> is not a known command; we assume it is a "/SOTA [+-]<dkp>" command.
	-- TODO: Add some regex check: something like "[+-]%d+[%]"
	sign = string.sub(cmd, 1, 1);


	--	Command: +
	--	Syntax: "+<%d> <playername>"
	if sign == "+" then
		local cmd = string.sub(cmd, 2);
		return SOTA_Call_AddPlayerDKP(arg, cmd);
	end
	

	if sign == "-" then
		cmd = string.sub(cmd, 2);		
		local percent = string.sub(cmd, string.len(cmd), string.len(cmd));
		if percent == "%" then
			--	Command: -
			--	Syntax: "-<%d>% <playername>" (note the percent in the end of the numeric value!)
			cmd = string.sub(cmd, 1, string.len(cmd) - 1)
			return SOTA_Call_SubtractPlayerDKPPercent(arg, cmd);
		else
			--	Command: -
			--	Syntax: "-<%d> <playername>"
			return SOTA_Call_SubtractPlayerDKP(arg, cmd);
		end
	end
	
	gEcho("Unknown command: ".. msg);
end


function SOTA_DisplayHelp()
	gEcho(string.format("SOTA version %s options:", GetAddOnMetadata("SOTA", "Version")));
	gEcho("Syntax: /sota [option], where options are:");
	--	DKP request options:
	gEcho("DKP Requests:");
	echo("  DKP <p>    Show how much DKP the player <p> currently have. Default is current player.");
	echo("  Class <c>    Show top 10 DKP for the class <c>. Default is the current player's class.");
	echo("");
	--	Player DKP:
	gEcho("Player DKP:");
	echo("  +<dkp> <p>    Add <dkp> to the player <p>.");
	echo("  -<dkp> <p>    Subtract <dkp> from the player <p>.");
	echo("  -<pct>% <p>    Subtract <pct> % DKP from the player <p>. A minimum subtracted amount can be configured in the DKP options.");
	echo("");
	--	Raid DKP:
	gEcho("Raid DKP:");
	echo("  raid +<dkp>    Add <dkp> to all players in raid and in raid queue.");
	echo("  raid -<dkp>    Subtract <dkp> from all players in raid and in raid queue.");
	echo("  range +<dkp>    Add <dkp> to all players in 100 yards range.");
	echo("  share +<dkp>    Share <dkp> to all players in raid and in raid queue. Every player gets (<dkp> / <number of players in raid>) DKP.");
	echo("  decay <pct>%    Remove <pct> percent DKP from every player in the guild.");
	echo("");
	--	Queue options:
	gEcho("Raid Queue:");
	echo("  queue    Get current queue status (number of people in queue)");
	echo("  addqueue <p> <r>    Manually add the player <p> to the raid queue with role <r>.");
	echo("");
	--	Misc:
	gEcho("Miscellaneous:");
	echo("  Config    Open the SotA configuration screen.");
	echo("  Log    Open the SotA transaction log screen.");
	echo("  Master    Request SotA master status.");
	echo("  <item>    Start an auction for <item>.");
	echo("  Version    Display the SotA client version.");
	echo("  Help    (default) This help!");
	echo("");
	--	Chat options (Guild chat and Raid chat):
	gEcho("Guild/Raid chat commands:");
	echo("  !queue    Get current queue status (number of people in queue)");
	echo("  !queue <r>    Queue as role <r>; <r> can be tank, melee, ranged or healer");
	echo("  !leave    Leave the raid queue.");
	echo("  !bid <dkp>    Bid <dkp> for item currently being on auction.");
	echo("  !bid min    Bid the minimum bid on item currently being on auction.");
	echo("  !bid max    Bid everyting (go all out) on item currently being on auction");	
	return false;
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
			whisper(sender, string.format("%s have %d DKP.", playername, dkp));
		else
			gEcho(string.format("%s have %d DKP.", playername, dkp));
		end
	else
		if sender then
			whisper(sender, string.format("There are no DKP information for %s.", playername));
		else
			gEcho(string.format("There are no DKP information for %s.", playername));
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
		whisper(sender, string.format("Top %d DKP for %ss:", MAX_CLASS_DKP_WHISPERED, playerclass));
		for n=1, table.getn(classtable), 1 do
			if n <= MAX_CLASS_DKP_WHISPERED then
				whisper(sender, string.format("%d - %s: %d DKP", n, classtable[n][1], 1*(classtable[n][2])));
			end
		end
	else
		gEcho(string.format("Top %d DKP for %ss:", MAX_CLASS_DKP_DISPLAYED, playerclass));
		for n=1, table.getn(classtable), 1 do
			if n <= MAX_CLASS_DKP_DISPLAYED then
				gEcho(string.format("%d - %s: %d DKP", n, classtable[n][1], 1*(classtable[n][2])));
			end
		end
	end
end




function SOTA_GetQualityColor(quality)
	for n=1, table.getn(QUALITY_COLORS), 1 do
		local q = QUALITY_COLORS[n];
		if q[1] == quality then
			return q[3]
		end
	end
	
	-- Unknown quality code; can't happen! Let's just return poor quality!
	return QUALITY_COLORS[1][3];
end



--[[
	Convert a msg so first letter is uppercase, and rest as lower case.
]]
local function UCFirst(msg)
	if not msg then
		return ""
	end	

	local f = string.sub(msg, 1, 1)
	local r = string.sub(msg, 2)
	return string.upper(f) .. string.lower(r)
end




--
--	Slave / Master functions
--

--[[
--	Request MASTER status unconditionally.
--	This is to be called when a DKP command is executed or a bidding round is started.
--	Other clients are notified, and must immediately demote themselves to SLAVE.
--	Since 0.5.2
--]]
function SOTA_RequestSOTAMaster()
	if CLIENT_STATE == CLIENT_STATE_MASTER then
		gEcho("You are already SOTA Master.");
	else
		SOTA_RequestMaster();
	end
end

function SOTA_RequestMaster(silentmode)
	local playername = UnitName("player")
	local rank = SOTA_GetRaidRank(playername);
	--	Requires at least Assistant!
	if rank < 1 then
		if silentmode then
			debugEcho(string.format("Player %s have raid rank %d", playername, rank));
		else
			gEcho("You must be promoted before you can be a SOTA Master!");
		end
		return;
	end

	addonEcho("TX_SETMASTER#"..playername.."#");

	if not silentmode then
		if not CLIENT_STATE == CLIENT_STATE_MASTER then
			gEcho("You are now SOTA Master.");
		end	
	end
	
	SOTA_SetMasterState(playername, CLIENT_STATE_MASTER);
end


function SOTA_SetMasterState(mastername, masterstate)
	SOTA_Master = mastername;
	CLIENT_STATE = masterstate;

	if not mastername then
		mastername = "(none)";
	end

	--echo(string.format("Master: %s, state= %d", mastername, CLIENT_STATE));

	getglobal("SOTA_MasterName"):SetText(mastername);
end

--[[
--	This will validate that the current SOTA master is still in raid (and online).
--	If not, master will be cleared.
--]]
function SOTA_ValidateMaster()
	if SOTA_Master then
		local pinfo = SOTA_GetRaidInfoForPlayer(SOTA_Master);
		
		-- Check if he is offline:
		if not pinfo or pinfo[5] == 0 then
			SOTA_ClearMaster();
		end
	end
end

--[[
--	Reset the current SOTA master.
--]]
function SOTA_ClearMaster()
	SOTA_SetMasterState(nil, CLIENT_STATE_SLAVE);
end


--[[
--	Returns TRUE if client is Master (or HELPER), FALSE if not.
--	Since 0.5.2
--]]
function SOTA_IsMaster()
	return not(CLIENT_STATE == CLIENT_STATE_SLAVE);
end


--[[
-- This promoted the current player to Master if none is set!
--]]
function SOTA_CheckForMaster()
	if not SOTA_Master then
		SOTA_RequestMaster();
	end
end


--[[
--	Handle a TX_SETMASTER message.
--	Client must set itself as slave.
--	No response is needed.
--	Since 0.5.2
--]]
function SOTA_HandleTXMaster(message, sender)
	local playername = UnitName("player")
	--echo(string.format("TX_MASTER: msg=%s, sender=%s", message, sender));

	if sender == playername then
		return;
	end

	SOTA_Master = message;
	if message == playername then
		SOTA_SetMasterState(message, CLIENT_STATE_MASTER);
	else
		SOTA_SetMasterState(message, CLIENT_STATE_SLAVE);
	end
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




--
--	PROPERTIES
--

function SOTA_GetSecondCounter()
	return Seconds;
end

function SOTA_GetAuctionState()
	return AuctionState;
end

function SOTA_SetAuctionState(auctionState, seconds)
	if not seconds then
		seconds = 0;
	end
	AuctionState = auctionState;
	SOTA_setSecondCounter(seconds);
end





function SOTA_OpenDashboard()
	DashboardUIFrame:Show();
end

function SOTA_CloseDashboard()
	DashboardUIFrame:Hide();
end

function SOTA_ShowDashboardToolTip(object, message)
	GameTooltip:SetOwner(object, "ANCHOR_PRESERVE");
	GameTooltip:AddLine(message, 1, 1, 1);
	GameTooltip:Show();
end

function SOTA_HideDashboardToolTip()
	GameTooltip:Hide();
end




--
--	CONFIGURATION
--

function SOTA_DisplayConfigurationScreen()
	SOTA_OpenConfigurationUI();
end



--[[
	Start the auction, and set state to STATE_STARTING
	Parameters:
	itemLink: a Blizzard itemlink to auction.
	Since 0.0.1
]]
function SOTA_StartAuction(itemLink)
	local rank = SOTA_GetRaidRank(UnitName("player"));
	if rank < 1 then
		gEcho("You need to be Raid Assistant or Raid Leader to start auctions.");
		return;
	end


	AuctionedItemLink = itemLink;
	
	--	Poor player, not only must be handle the bidding round but he is now also handling Invites!
	SOTA_RequestMaster();
	
	-- Extract ItemId from itemLink string:
	local _, _, itemId = string.find(itemLink, "item:(%d+):")
	if not itemId then
		gEcho("Item was not found: ".. itemLink);
		return;
	end

	local itemName, _, itemQuality, _, _, _, _, _, itemTexture = GetItemInfo(itemId);	
	
	local frame = getglobal("AuctionUIFrameItem");
	if frame then
		local rgb = SOTA_GetQualityColor(itemQuality);	
		local inf = getglobal(frame:GetName().."ItemName");
		inf:SetText(itemName);
		inf:SetTextColor( (rgb[1]/255), (rgb[2]/255), (rgb[3]/255), 1);
		
		local tf = getglobal(frame:GetName().."ItemTexture");
		if tf then
			tf:SetTexture(itemTexture);
		end
	end
	
	IncomingBidsTable = { };
	SOTA_UpdateBidElements();
	SOTA_OpenAuctionUI();
	
	SOTA_SetAuctionState(STATE_AUCTION_RUNNING, SOTA_CONFIG_AuctionTime);
end



local GuildRefreshTimer = 0;
local EventTime = 0;
local SOTA_TimerTick = 0;
local SecondTimer = 0;
local Secounds = 0;

--	Timer job: { method, duration }
local SOTA_GeneralTimers = { }

function SOTA_setSecondCounter(seconds)
	Seconds = seconds;
end

function SOTA_AddTimer( method, duration )
	SOTA_GeneralTimers[table.getn(SOTA_GeneralTimers) + 1] = { method, SOTA_TimerTick + duration }
end

function SOTA_OnTimer(elapsed)
	SOTA_TimerTick = SOTA_TimerTick + elapsed

	if floor(EventTime) < floor(SOTA_TimerTick) then
		SOTA_CheckAuctionState();
		EventTime = SOTA_TimerTick;
	end
	
	if floor(GuildRefreshTimer) < floor(SOTA_TimerTick) then
		GuildRefreshTimer = SOTA_TimerTick + GUILD_REFRESH_TIMER;
		SOTA_RequestUpdateGuildRoster();
	end
	
	if floor(SecondTimer) < floor(SOTA_TimerTick) then
		SOTA_OnSecondTimer();
		SecondTimer = SOTA_TimerTick;
	end
	
	local timer;
	for n=1, table.getn(SOTA_GeneralTimers), 1 do
		timer = SOTA_GeneralTimers[n];
		if (SOTA_TimerTick > timer[2]) then
			SOTA_GeneralTimers[n] = nil;
			timer[1]();
		end
	end
	
end

function SOTA_OnSecondTimer()
	local zonetext = GetRealZoneText();
	if not CurrentZoneName or not(zonetext == CurrentZoneName) then
		CurrentZoneName = zonetext;
		SOTA_OnZoneChanged();
	end
	
	if SOTA_IsInRaid(true) then
		if SOTA_CONFIG_DisableDashboard == 0 then
			SOTA_OpenDashboard();
		end
		
		SOTA_ValidateMaster();		
	else
		if SOTA_CONFIG_DisableDashboard == 0 then
			SOTA_CloseDashboard();
		end
	end
	
end



--[[
	The big SOTA state machine.
	Since 0.0.1
]]
function SOTA_CheckAuctionState()
	local state = SOTA_GetAuctionState();
	
	--debugEcho(string.format("SOTA_CheckAuctionState called, state = %d", STATE_AUCTION_PAUSED));
	if state == STATE_NONE or state == STATE_AUCTION_PAUSED then
		return;
	end
		
	if state == STATE_AUCTION_RUNNING then
		local secs = SOTA_GetSecondCounter();
		if secs == SOTA_CONFIG_AuctionTime then
			SOTA_rwEcho(string.format("Auction open for %s", AuctionedItemLink));
			SOTA_rwEcho(string.format("/w %s bid <your bid>", UnitName("Player")))
			SOTA_rwEcho(string.format("Minimum bid: %d DKP", SOTA_GetMinimumBid()));
		end
		
		if secs == 10 then
			SOTA_rwEcho(string.format("10 seconds left for %s", AuctionedItemLink));
			SOTA_rwEcho(string.format("/w %s bid <your bid>", UnitName("Player")));
		end
		if secs == 3 then
			SOTA_rwEcho("3 seconds left");
		end
		if secs == 2 then
			SOTA_rwEcho("2 seconds left");
		end
		if secs == 1 then
			SOTA_rwEcho("1 second left");
		end
		if secs < 1 then
			-- Time is up - complete the auction:
			SOTA_FinishAuction(sender, dkp);	
		end
				
		Seconds = Seconds - 1;
	end
	
	if state == STATE_COMPLETE then
		--	 We're idle
		state = STATE_NONE;
	end

	SOTA_RefreshButtonStates();
end






--[[
--	There's a message in the Guild channel - investigate that!
--]]
function SOTA_HandleGuildChatMessage(event, message, sender)
	if not message or message == "" or not string.sub(message, 1, 1) == "!" then
		return;
	end

	-- Only respond if you are master, or no master has yet been assigned:
	if SOTA_IsMaster() or (not SOTA_master and SOTA_IsPromoted()) then
		local command = string.sub(message, 2)
		debugEcho("Master: Processing GChat command: ".. command);
		SOTA_OnChatWhisper(event, command, sender);
	end
end

--[[
--	There's a message in the Raid channel - investigate that!
--]]
function SOTA_HandleRaidChatMessage(event, message, sender)
	if not message or message == "" or not string.sub(message, 1, 1) == "!" then
		return;
	end
	
	if SOTA_IsMaster() then
		local command = string.sub(message, 2)
		debugEcho("Master: Processing RChat command: ".. command);
		SOTA_OnChatWhisper(event, command, sender);
	end
end


--[[
--	Handle incoming chat whisper.
--	Guild and Raid "!" commands are redirected here too with the "raw" command line.
--	Since 0.1.0
--]]
function SOTA_OnChatWhisper(event, message, sender)	
	if not message then
		return
	end
	
	local _, _, cmd = string.find(message, "(%a+)");	
	if not cmd then
		return
	end
	cmd = string.lower(cmd);
	
	if cmd == "bid" or cmd == "os" or cmd == "ms" then
		SOTA_HandlePlayerBid(sender, message);
		
	elseif cmd == "queue" then
		SOTA_HandleQueueRequest(sender, message);
		
	elseif cmd == "leave" then		
		if SOTA_RemoveFromRaidQueue(sender) then
			local guildInfo = SOTA_GetGuildPlayerInfo(sender);
			if (guildInfo and guildInfo[5] == 1) then
				whisper(sender, "You have left the Raid Queue.")
			end
		end
	end
end	



--[[
--	Handle incoming bid request.
--	Syntax: /sota bid|ms|os <dkp>|min|max
--	Since 0.0.1
--]]
function SOTA_HandlePlayerBid(sender, message)
	local playerInfo = SOTA_GetGuildPlayerInfo(sender);
	if not playerInfo then
		whisper(sender, "You need to be in the guild to do bidding!");
		return;
	end

	local unitId = SOTA_GetUnitIDFromGroup(sender);
	if not unitId then
		-- The sender of the message was not in the raid; must be a normal whisper.
		return;
	end

	local availableDkp = 1 * (playerInfo[2]);
	
	local cmd, arg
	local spacepos = string.find(message, "%s");
	if spacepos then
		_, _, cmd, arg = string.find(string.lower(message), "(%S+)%s+(.+)");
	else
		return;
	end	

	-- Default is MS - if OS bidding is enabled, check bidtype:
	local bidtype = nil;
	
	if SOTA_CONFIG_EnableOSBidding == 1 then
		bidtype = 1;
		if cmd == "os" then
			bidtype = 2;
		end
	end

	local minimumBid = SOTA_GetMinimumBid(bidtype);
	if not minimumBid then
		whisper(sender, "You cannot OS bid if an MS bid is already made.");
		return;
	end
	
	--echo(string.format("Min.Bid=%d for bidtype=%s", minimumBid, bidtype));
	
	local dkp = tonumber(arg)	
	if not dkp then
		if arg == "min" then
			dkp = minimumBid;
		elseif arg == "max" then
			dkp = availableDkp;
		else
			-- This was not following a legal format; skip message
			return;
		end
	end	

	if not (AuctionState == STATE_AUCTION_RUNNING) then
		whisper(sender, "There is currently no auction running - bid was ignored.");
		return;
	end	

	dkp = 1 * dkp
	if dkp < minimumBid then
		whisper(sender, string.format("You must bid at least %s DKP - bid was ignored.", minimumBid));
		return;
	end

	if availableDkp < dkp then
		whisper(sender, string.format("You only have %d DKP - bid was ignored.", availableDkp));
		return
	end
	
	if Seconds < SOTA_CONFIG_AuctionExtension then
		Seconds = SOTA_CONFIG_AuctionExtension;
	end
	
	local bidderClass = playerInfo[3];
	local bidderRank  = playerInfo[4];
	
	if bidtype == 2 then
		SOTA_rwEcho(string.format("%s is bidding %d Off-spec for %s", sender, dkp, AuctionedItemLink));
	else
		SOTA_rwEcho(string.format("%s is bidding %d DKP for %s", sender, dkp, AuctionedItemLink));
	end
	

	SOTA_RegisterBid(sender, dkp, bidtype, bidderClass, bidderRank);
	
		
	-- Checks to perform now:
	-- * Do user have enough DKP?	(Done)
	-- * Do user bid <minimum dkp>? (Done)
	--		* exception: if he goes all out he is allowed to go below minimum dkp
	-- * Is user already the highest bidder? (should we let users screw up? I personally think so!)

	-- OS/MS:
	--	- Check if MS>OS is enabled
	--	- MS bid: Check for highest MS bid (not OS bid)
	--	- OS bid: check of any MS bid was made previous, and skip if so!


	-- TODO:
	-- Hide incoming whispers for local player (how?)		
end



function SOTA_RegisterBid(playername, bid, bidtype, playerclass, rank)
	if bidtype == 2 then
		whisper(playername, string.format("Your Off-spec bid of %d DKP has been registered.", bid) );
	else
		whisper(playername, string.format("Your bid of %d DKP has been registered.", bid) );
	end

	IncomingBidsTable = SOTA_RenumberTable(IncomingBidsTable);
	
	IncomingBidsTable[table.getn(IncomingBidsTable) + 1] = { playername, bid, bidtype, playerclass, rank };

	-- Sort by DKP, then BidType (so MS bids are before OS bids)
	SOTA_SortTableDescending(IncomingBidsTable, 2);
	if SOTA_CONFIG_EnableOSBidding == 1 then
		SOTA_SortTableAscending(IncomingBidsTable, 3);
	end
	
	--Debug output:
	--for n=1, table.getn(IncomingBidsTable), 1 do
	--	local cbid = IncomingBidsTable[n];
	--	local name = cbid[1];
	--	local dkp  = cbid[2];
	--	local type = cbid[3];
	--	local clss = cbid[4];
	--	local rank = cbid[5];
	--	echo(string.format("%d - %s bid %d DKP, Type=%d, class=%s, rank=%s", n, name, dkp, type, clss, rank));
	--end
 
	SOTA_UpdateBidElements();
end


function SOTA_UnregisterBid(playername, bid)
	playername = SOTA_UCFirst(playername);
	bid = 1 * bid;

	local bidInfo;
	for n=1,table.getn(IncomingBidsTable), 1 do
		bidInfo = IncomingBidsTable[n];
		if bidInfo[1] == playername and 1*(bidInfo[2]) == bid then
			table.remove(IncomingBidsTable, n);

			IncomingBidsTable = SOTA_RenumberTable(IncomingBidsTable);
			
			SOTA_UpdateBidElements();
			SOTA_ShowSelectedPlayer();
			return;
		end
	end
end

function SOTA_GetBidInfo(playername, bid)
	playername = SOTA_UCFirst(playername);
	bid = 1 * bid;

	local bidInfo;
	for n=1,table.getn(IncomingBidsTable), 1 do
		bidInfo = IncomingBidsTable[n];
		if bidInfo[1] == playername and 1*(bidInfo[2]) == bid then
			return bidInfo;
		end
	end

	return nil;
end

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

function SOTA_AcceptBid(playername, bid)
	if playername and bid then
		playername = SOTA_UCFirst(playername);
		bid = 1 * bid;
	
		AuctionUIFrame:Hide();
		
		SOTA_rwEcho(string.format("%s sold to %s for %d DKP.", AuctionedItemLink, playername, bid));
		
		SOTA_SubtractPlayerDKP(playername, bid);		
	end
end





--
--	Player Raid Queue functions
--

--[[
--	Invite all of one role type (e.g. all Tanks)
--]]
function SOTA_InviteQueuedPlayerGroup(rolename, roleidentifier)

	StaticPopupDialogs["SOTA_POPUP_INVITE_PLAYER"] = {
		text = string.format("Do you want to invite all %s into the raid?", rolename),
		button1 = "Yes",
		button2 = "No",
		OnAccept = function() SOTA_InviteQueuedPlayerGroupNow(roleidentifier)  end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
	}
	
	StaticPopup_Show("SOTA_POPUP_INVITE_PLAYER");
end

function SOTA_InviteQueuedPlayerGroupNow(role)
	if not SOTA_IsInRaid(true) then
		return;
	end

	for n=1, table.getn(RaidQueue), 1 do
		if RaidQueue[n][3] == role then
			InviteByName(RaidQueue[n][1]);
		end
	end
end

function SOTA_InviteQueuedPlayer(playername)
	if not SOTA_IsInRaid(true) then
		return;
	end
	
	local qInfo = SOTA_GetQueuedPlayer(playername);

	if not qInfo then
		gEcho("Player "..playername.." is not queued!");
		return;
	end

	StaticPopupDialogs["SOTA_POPUP_INVITE_PLAYER"] = {
		text = string.format("Do you want to invite %s into the raid?", playername),
		button1 = "Yes",
		button2 = "No",
		OnAccept = function() InviteByName(playername) end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
	}
	
	StaticPopup_Show("SOTA_POPUP_INVITE_PLAYER");
end

-- Remove queued player from queue
function SOTA_RemoveQueuedPlayerGroupNow(playername)
	if not SOTA_IsInRaid(true) then
		return;
	end

	gEcho("Removing ".. playername .." from queue");

	SOTA_RemoveFromRaidQueue(playername);

	local guildInfo = SOTA_GetGuildPlayerInfo(playername);
	if (guildInfo and guildInfo[5] == 1) then
		whisper(playername, "You were removed from the Raid Queue.")
	end
end

function SOTA_GetQueuedPlayer(playername)
	local queueInfo = nil;
	for n=1, table.getn(RaidQueue), 1 do
		queueInfo = RaidQueue[n];
		if queueInfo[1] == playername then
			return queueInfo;
		end
	end
	
	return queueInfo;
end


--[[
--	Handle incoming /queue or !queue command
--	Since: 0.1.1
--]]
function SOTA_HandleQueueRequest(sender, message)
	local _, _, queueparam = string.find(string.lower(message), "queue (%a+)")
	if not queueparam then
		if sender == UnitName("player") then
			SOTA_OpenRaidQueueUI();
		else
			-- { Name, QueueID, Role , Class }
			local t = 0
			local m = 0
			local r = 0
			local h = 0;
			for n=1, table.getn(RaidQueue), 1 do
				if RaidQueue[n][3] == "tank" then
					t = t + 1
				elseif RaidQueue[n][3] == "melee" then
					m = m + 1
				elseif RaidQueue[n][3] == "ranged" then
					r = r + 1
				elseif RaidQueue[n][3] == "healer" then
					h = h + 1
				end
			end
			whisper(sender, string.format("Currently queued: %d tanks, %d melee, %d ranged, %d healers", t, m, r, h));
		end
		return;
	end
	
	local queuetype = nil;
	
	queueparam = string.lower(queueparam);	
	if queueparam == "tank" or queueparam == "t" then
		queuetype = "tank";
	elseif queueparam == "melee" or queueparam == "m" then
		queuetype = "melee";
	elseif queueparam == "ranged" or queueparam == "r" then
		queuetype = "ranged";
	elseif queueparam == "healer" or queueparam == "h" then
		queuetype = "healer";
	elseif queueparam == "sheyliny" or queueparam == "noob" then
		whisper(sender, "Sorry, raid is currently filled with Noobs ;-)");
		return;
	end
	
	if queuetype then
		SOTA_CheckForMaster();
		if SOTA_IsMaster() then
			SOTA_AddToRaidQueue(sender, queuetype);
		end
	else
		whisper(sender, "Type !queue <role>, where role is tank, melee, ranged or healer.");		
	end
end



function SOTA_AddToRaidQueueByName(args)
	if not SOTA_IsMaster() then
		return;
	end

	if args then
		local _, _, playername, playerrole = string.find(args, "(%S+) (%S+)")		
		if not playername or not playerrole then	
			gEcho("Syntax: /sota addqueue <playername> <playerrole>");
			
		else
			if SOTA_AddToRaidQueue(playername, playerrole, true) then
				SOTA_BroadcastJoinQueue(playername, playerrole);
			end
		end
	end
end

--[[
--	Add a player to the raid queue
--	Since: 0.1.1
--]]
function SOTA_AddToRaidQueue(playername, playerrole, silentmode)
	if not silentmode then
		silentmode = false;
	end
	
	playername = SOTA_UCFirst(playername);

	local playerInfo = SOTA_GetGuildPlayerInfo(playername);
	if not playerInfo then
		if not silentmode then	
			whisper(playername, "You need to be in the guild to join the raid queue!");
		end
		return false;
	end
		
	local raidRoster = SOTA_GetRaidRoster();

	-- Check if player is already in the raid:
	for n=1, table.getn(raidRoster), 1 do
		if raidRoster[n][1] == playername then
			if not silentmode then	
				whisper(playername, "You are already in the raid.");
			end
			return false;
		end
	end

	-- Check if player is already queued:
	for n=1, table.getn(RaidQueue), 1 do
		local rq = RaidQueue[n];
		if rq[1] == playername and rq[3] == playerrole then
			if not silentmode then
				whisper(playername, string.format("You are already queued as %s.", playerrole));
			end
			return false;
		end
	end

	-- Remove if already queued - that way you can change role.
	SOTA_RemoveFromRaidQueue(playername, silentmode);

	-- Playername / queueId / Role / Class / Guild rank
	RaidQueue[table.getn(RaidQueue) + 1] = { playername, QueueID, playerrole, playerInfo[3], playerInfo[4] };
	QueueID = QueueID + 1;

	if not silentmode then
		SOTA_BroadcastJoinQueue(playername, playerrole);
		whisper(playername, string.format("You are now queued as %s - Queue number: %d", SOTA_UCFirst(playerrole), table.getn(RaidQueue)));
	end

	SOTA_RefreshRaidQueue();
	
	return true;
end



--[[
--	Remove a player from the raid queue
--]]
function SOTA_RemoveFromRaidQueue(playername, silentmode)
	if not silentmode then
		silentmode = false;
	end

	for n=1, table.getn(RaidQueue), 1 do
		if RaidQueue[n][1] == playername then		
			RaidQueue[n] = { };			
			RaidQueue = SOTA_RenumberTable(RaidQueue);

			if not silentmode then
				SOTA_BroadcastLeaveQueue(playername);
			end
			SOTA_RefreshRaidQueue();
			return true;
		end
	end

	SOTA_RefreshRaidQueue();
	return false;
end


function SOTA_BroadcastJoinQueue(playername, playerrole)
	addonEcho("TX_JOINQUEUE#".. string.format("%s/%s", playername, playerrole) .."#");
end

function SOTA_BroadcastLeaveQueue(playername)
	addonEcho("TX_LEAVEQUEUE#".. playername .."#");
end

function SOTA_HandleTXJoinQueue(message, sender)
	local _, _, playername, playerrole = string.find(message, "([^/]*)/([^/]*)")	
	SOTA_AddToRaidQueue(playername, playerrole, true);
end

function SOTA_HandleTXLeaveQueue(message, sender)
	SOTA_RemoveFromRaidQueue(message, true);	
end



--
--	UI functions
--


function SOTA_OpenAuctionUI()
	SOTA_ClearSelectedPlayer();
	AuctionUIFrame:Show();
end

function SOTA_OpenRaidQueueUI()
	RaidQueueUIOpen = true;	
	SOTA_RefreshRaidQueue();
	
	RaidQueueFrame:Show();
end

function SOTA_CloseRaidQueueUI()
	RaidQueueUIOpen = false;	
	RaidQueueFrame:Hide();
end

function SOTA_OpenTransauctionUI()
	TransactionUIOpen = true;
	TransactionDetailsOpen = false;
	
	getglobal("TransactionUIFrameTableList"):Show();
	getglobal("PrevTransactionPageButton"):Show();
	getglobal("NextTransactionPageButton"):Show();
	getglobal("TransactionUIFramePlayerList"):Hide();
	getglobal("BackToTransactionLogButton"):Hide();
	getglobal("UndoTransactionButton"):Hide();
	
	SOTA_RefreshTransactionElements();
	TransactionUIFrame:Show();	
end

function SOTA_CloseTransactionUI()
	TransactionUIOpen = false;
	TransactionDetailsOpen = false;
	TransactionUIFrame:Hide();
end

function SOTA_OpenTransactionDetails()
	TransactionUIOpen = false;
	TransactionDetailsOpen = true;
	getglobal("TransactionUIFrameTableList"):Hide();
	getglobal("PrevTransactionPageButton"):Hide();
	getglobal("NextTransactionPageButton"):Hide();
	getglobal("TransactionUIFramePlayerList"):Show();
	getglobal("BackToTransactionLogButton"):Show();
	getglobal("UndoTransactionButton"):Show();
end

function SOTA_CloseTransactionDetails()
	SOTA_OpenTransauctionUI();
end

function SOTA_OpenConfigurationUI()
	SOTA_RefreshBossDKPValues();
	SOTA_OpenConfigurationFrame1()
end

function SOTA_CloseConfigurationElements(headline)
	-- ConfigurationFrame1:
	ConfigurationFrameOptionAuctionTime:Hide();
	ConfigurationFrameOptionAuctionExtension:Hide();
	ConfigurationFrameOptionMSoverOSPriority:Hide();
	ConfigurationFrameOptionEnableZonecheck:Hide();
	ConfigurationFrameOptionDisableDashboard:Hide();
	-- ConfigurationFrame2:
	ConfigurationFrameOption_20Mans:Hide();
	ConfigurationFrameOption_MoltenCore:Hide();
	ConfigurationFrameOption_Onyxia:Hide();
	ConfigurationFrameOption_BlackwingLair:Hide();
	ConfigurationFrameOption_AQ40:Hide();
	ConfigurationFrameOption_Naxxramas:Hide();
	ConfigurationFrameOption_WorldBosses:Hide();
	-- ConfigurationFrame3:
	ConfigurationFrameOptionPublicNotes:Hide();
	ConfigurationFrameOptionMinBidStrategy0:Hide();
	ConfigurationFrameOptionMinBidStrategy1:Hide();
	ConfigurationFrameOptionMinBidStrategy2:Hide();
	ConfigurationFrameOptionMinBidStrategy3:Hide();
	ConfigurationFrameOptionDKPStringLength:Hide();
	ConfigurationFrameOptionMinimumDKPPenalty:Hide();
	
	ConfigurationFrameTopText:SetText(headline);
end


function SOTA_OpenConfigurationFrame1()
	SOTA_CloseConfigurationElements("Auction Timers");
	-- ConfigurationFrame1:
	ConfigurationFrameOptionAuctionTime:Show();
	ConfigurationFrameOptionAuctionExtension:Show();
	ConfigurationFrameOptionMSoverOSPriority:Show();
	ConfigurationFrameOptionEnableZonecheck:Show();
	ConfigurationFrameOptionDisableDashboard:Show();
	
	ConfigurationFrame:Show();	
end

function SOTA_OpenConfigurationFrame2()
	SOTA_CloseConfigurationElements("Shared DKP per Boss Kill");
	-- ConfigurationFrame2:
	ConfigurationFrameOption_20Mans:Show();
	ConfigurationFrameOption_MoltenCore:Show();
	ConfigurationFrameOption_Onyxia:Show();
	ConfigurationFrameOption_BlackwingLair:Show();
	ConfigurationFrameOption_AQ40:Show();	
	ConfigurationFrameOption_Naxxramas:Show();
	ConfigurationFrameOption_WorldBosses:Show();
end

function SOTA_OpenConfigurationFrame3()
	SOTA_CloseConfigurationElements("Misc. DKP Settings");
	-- ConfigurationFrame3:
	ConfigurationFrameOptionPublicNotes:Show();
	ConfigurationFrameOptionMinBidStrategy0:Show();
	ConfigurationFrameOptionMinBidStrategy1:Show();
	ConfigurationFrameOptionMinBidStrategy2:Show();
	ConfigurationFrameOptionMinBidStrategy3:Show();
	ConfigurationFrameOptionDKPStringLength:Show();
	ConfigurationFrameOptionMinimumDKPPenalty:Show();
end

function SOTA_CloseConfigurationUI()
	ConfigurationFrame:Hide();
end





--[[
--	Initialize all UI table elements.
--]]
function SOTA_InitializeTableElements()
	--	Initialize top <n> bids
	for n=1, MAX_BIDS, 1 do
		local entry = CreateFrame("Button", "$parentEntry"..n, AuctionUIFrameTableList, "SOTA_BidTemplate");
		entry:SetID(n);
		if n == 1 then
			entry:SetPoint("TOPLEFT", 4, -4);
		else
			entry:SetPoint("TOP", "$parentEntry"..(n-1), "BOTTOM");
		end
	end
	
	--	Initialize Raid Queues
	for n=1, MAX_RAID_QUEUE_SIZE + 1, 1 do
		local tList = CreateFrame("Button", "$parentEntry"..n, RaidQueueFrameTankList,   "SOTA_PlayerTemplate");
		local mList = CreateFrame("Button", "$parentEntry"..n, RaidQueueFrameMeleeList,  "SOTA_PlayerTemplate");
		local rList = CreateFrame("Button", "$parentEntry"..n, RaidQueueFrameRangedList, "SOTA_PlayerTemplate");
		local hList = CreateFrame("Button", "$parentEntry"..n, RaidQueueFrameHealerList, "SOTA_PlayerTemplate");
		tList:SetID(n);
		mList:SetID(n);
		rList:SetID(n);
		hList:SetID(n);
		if(n == 1) then
			tList:SetPoint("TOPLEFT", 4, -4);
			mList:SetPoint("TOPLEFT", 4, -4);
			rList:SetPoint("TOPLEFT", 4, -4);
			hList:SetPoint("TOPLEFT", 4, -4);
		else
			tList:SetPoint("TOP", "$parentEntry"..(n-1), "BOTTOM");
			mList:SetPoint("TOP", "$parentEntry"..(n-1), "BOTTOM");
			rList:SetPoint("TOP", "$parentEntry"..(n-1), "BOTTOM");
			hList:SetPoint("TOP", "$parentEntry"..(n-1), "BOTTOM");
		end		
	end
	
	--	Initalize Transaction Log
	for n=0,MAX_TRANSACTIONS_DISPLAYED, 1 do
		local entry = CreateFrame("Button", "$parentEntry"..n, TransactionUIFrameTableList, "SOTA_LogTemplate");
		entry:SetID(n);
		if n == 0 then
			entry:SetPoint("TOPLEFT", 4, -4);
		else
			entry:SetPoint("TOP", "$parentEntry"..(n-1), "BOTTOM");
		end	
	end
	
	--	Initialize Player buttons in TransactionDetails
	local id = 1;
	for row=1, TRANSACTION_DETAILS_ROWS, 1 do
		for col=1, TRANSACTION_DETAILS_COLUMNS, 1 do
			local entry = CreateFrame("Button", "$parentEntry_"..col.."_"..row, TransactionUIFramePlayerList, "SOTA_PlayerLogTemplate");			
			entry:SetID(id);
			
			if col == 1 then
				if row == 1 then
					-- Top Left button
					entry:SetPoint("TOPLEFT", 4, -4);
				else
					-- Left button: relative to above button
					entry:SetPoint("TOP", "$parentEntry_1_"..(row-1), "BOTTOM");
				end
			else
				-- Relative to previous (left) button
				entry:SetPoint("LEFT", "$parentEntry_"..(col-1).."_"..row, "RIGHT");
			end
			
			id = id + 1;
		end
	end	
end

--	Show top <n> in bid window
function SOTA_UpdateBidElements()
	local bidder, bid, playerclass, rank;
	for n=1, MAX_BIDS, 1 do
		if table.getn(IncomingBidsTable) < n then
			bidder = "";
			bid = "";
			bidcolor = { 64, 255, 64 };
			playerclass = "";
			rank = "";
		else
			local cbid = IncomingBidsTable[n];
			bidder = cbid[1];
			bidcolor = { 64, 255, 64 };
			if cbid[3] == 2 then
				bidcolor = { 255, 255, 96 };
			end
			bid = string.format("%d", cbid[2]);
			playerclass = cbid[4];
			rank = cbid[5];
		end

		local color = SOTA_GetClassColorCodes(playerclass);

		local frame = getglobal("AuctionUIFrameTableListEntry"..n);
		getglobal(frame:GetName().."Bidder"):SetText(bidder);
		getglobal(frame:GetName().."Bidder"):SetTextColor((color[1]/255), (color[2]/255), (color[3]/255), 255);
		getglobal(frame:GetName().."Bid"):SetTextColor((bidcolor[1]/255), (bidcolor[2]/255), (bidcolor[3]/255), 255);
		getglobal(frame:GetName().."Bid"):SetText(bid);
		getglobal(frame:GetName().."Rank"):SetText(rank);

		SOTA_RefreshButtonStates();
		frame:Show();
	end
end


function SOTA_GetSelectedBid()
	local selectedBid = nil;
	
	local frame = getglobal("AuctionUIFrameSelected");
	local bidder = getglobal(frame:GetName().."Bidder"):GetText();
	local bid = getglobal(frame:GetName().."Bid"):GetText();

	if bidder and bid then
		selectedBid = { bidder, bid };
	end

	return selectedBid;
end

--[[
--	Refresh button states
--]]
function SOTA_RefreshButtonStates()
	local isAuctionRunning = (SOTA_GetAuctionState() == STATE_AUCTION_RUNNING);
	local isAuctionPaused = (SOTA_GetAuctionState() == STATE_AUCTION_PAUSED);

	local isBidderSelected = true;
	local selectedBid = SOTA_GetSelectedBid();
	if not selectedBid then
		isBidderSelected = false;
	end	

	if isBidderSelected then
		if isAuctionRunning or isAuctionPaused then
			getglobal("AcceptBidButton"):Disable();
		else
			getglobal("AcceptBidButton"):Enable();
		end		
		getglobal("CancelBidButton"):Enable();
	else
		getglobal("AcceptBidButton"):Disable();
		getglobal("CancelBidButton"):Disable();
	end
	
	if isAuctionRunning or isAuctionPaused then
		getglobal("CancelAuctionButton"):Enable();
		getglobal("RestartAuctionButton"):Enable();
		getglobal("FinishAuctionButton"):Enable();
		if isAuctionPaused then
			getglobal("PauseAuctionButton"):Enable();
			getglobal("PauseAuctionButton"):SetText("Resume Auction");
		else
			getglobal("PauseAuctionButton"):Enable();
			getglobal("PauseAuctionButton"):SetText("Pause Auction");
		end
	else
		getglobal("CancelAuctionButton"):Enable();
		getglobal("RestartAuctionButton"):Enable();
		getglobal("FinishAuctionButton"):Disable();
		getglobal("PauseAuctionButton"):Disable();
		getglobal("PauseAuctionButton"):SetText("Pause Auction");
	end	
end


--[[
--	Refresh the Raid Queue UI.
--	If a role is given, only the queue for that role is refreshed.
--	A role of nil will refresh all roles.
--]]
function SOTA_RefreshRaidQueue(role)
	-- UI not open; no need to update controls yet.
	-- This is used to allow GuildRosterUpdates to update UI when needed.
	if not RaidQueueUIOpen then
		return;
	end
	
	local raidRoster = SOTA_GetRaidRoster();
	
	local playersAlsoInRaid = { }
	
	local tQueue = { }
	local mQueue = { }
	local rQueue = { }
	local hQueue = { }
	for n=1, table.getn(RaidQueue), 1 do
		local playername = RaidQueue[n][1];
		
		local found = false;
		for f=1, table.getn(raidRoster), 1 do
			if (raidRoster[f][1] == playername) then
				found = true;
				f = table.getn(raidRoster);
			end
		end
		
		if found then
			playersAlsoInRaid[ table.getn(playersAlsoInRaid) + 1 ] = playername;
		else
			local role = RaidQueue[n][3];		
			if(role == "tank") then
				tQueue[table.getn(tQueue) + 1] = RaidQueue[n];
			elseif(role == "melee") then
				mQueue[table.getn(mQueue) + 1] = RaidQueue[n];
			elseif(role == "ranged") then
				rQueue[table.getn(rQueue) + 1] = RaidQueue[n];
			elseif(role == "healer") then
				hQueue[table.getn(hQueue) + 1] = RaidQueue[n];
			end
		end
	end
		
	--	TODO: Sort the raid tables

	local playername, playerrole, playerclass, queueid;
	
	SOTA_UpdateRaidQueueTable("Tanks",   "RaidQueueFrameTankListEntry",   tQueue);
	SOTA_UpdateRaidQueueTable("Melee",   "RaidQueueFrameMeleeListEntry",  mQueue);
	SOTA_UpdateRaidQueueTable("Ranged",  "RaidQueueFrameRangedListEntry", rQueue);
	SOTA_UpdateRaidQueueTable("Healers", "RaidQueueFrameHealerListEntry", hQueue);
	
	-- Remove players from queue who are also in Raid
	for n=1, table.getn(playersAlsoInRaid), 1 do
		SOTA_RemoveFromRaidQueue(playersAlsoInRaid[n]);
	end
	
end



function SOTA_UpdateRaidQueueTable(caption, framename, sourcetable)

	local playername, playerrole, playerclass, queueid;
	for n=0, MAX_RAID_QUEUE_SIZE, 1 do
		if n == 0 or table.getn(sourcetable) < n then
			playername	= "";
			playerrole	= "";
			queueid		= "";
			playerclass	= "";
			playerrank	= "";
		else
			playername	= sourcetable[n][1];
			queueid		= sourcetable[n][2];
			playerrole	= sourcetable[n][3];
			playerclass = sourcetable[n][4];
			playerrank	= sourcetable[n][5];
		end

		local color = { 128, 128, 128 }
		if not(playername == "") then
			local guildInfo = SOTA_GetGuildPlayerInfo(playername);
			if guildInfo then
				if guildInfo[5] == 1 then
					color = SOTA_GetClassColorCodes(playerclass);
				end
			end
		end
		
		local frame = getglobal(framename .. (n+1));		
		if n == 0 then
			local color = { 240, 200, 40 }	
			getglobal(frame:GetName().."Name"):SetText(caption);
			getglobal(frame:GetName().."Name"):SetTextColor((color[1]/255), (color[2]/255), (color[3]/255), 255);
			getglobal(frame:GetName().."Rank"):SetText("Queue: ".. table.getn(sourcetable));
		else
			getglobal(frame:GetName().."Name"):SetText(playername);
			getglobal(frame:GetName().."Name"):SetTextColor((color[1]/255), (color[2]/255), (color[3]/255), 255);
			getglobal(frame:GetName().."Rank"):SetText(playerrank);			
		end
		
		frame:Show();
	end
end

function SOTA_RefreshTransactionLog()
	if TransactionUIOpen then
		SOTA_RefreshTransactionElements();		
	elseif TransactionDetailsOpen then
		SOTA_RefreshTransactionDetails();	
	end
end

--[[
--	Show last <n> transactions:
--]]
function SOTA_RefreshTransactionElements()
	if not TransactionUIOpen then
		return;
	end

	local timestamp, tid, description, state, trInfo;
	local name, dkp, playerCount;
	
	local trLog = SOTA_CloneTable(transactionLog);
	SOTA_SortTableDescending(trLog, 2);
	
	local numTransactions = table.getn(trLog);
	for n=0, MAX_TRANSACTIONS_DISPLAYED, 1 do
		if n == 0 then
			timestamp = "Time";
			tid = "ID";
			description = "Command";
			trInfo = nil;
			name = "Player(s)";
			dkp = "DKP";
		else
			local index = n + ((currentTransactionPage - 1) * MAX_TRANSACTIONS_DISPLAYED);
			if numTransactions < index then
				timestamp = "";
				tid = "";
				description = "";
				state = 0;
				trInfo = nil;
				name = "";
				dkp = "";
			else
				local tr = trLog[index];
				timestamp = tr[1];
				tid = tr[2];
				description = tr[4];
				state = tr[5];
				trInfo = tr[6];
				if trInfo and table.getn(trInfo) == 1 then
					name = trInfo[1][1];
					dkp = 1 * (trInfo[1][2]);
				else
					playerCount = table.getn(trInfo);
					dkp = 0;
					for f=1, playerCount, 1 do
						dkp = dkp + 1*(trInfo[f][2]);
					end
					dkp = ceil(dkp / playerCount);
					name = string.format("(%d players)", playerCount);
				end
			end
		end

		local icon = "";
		if tonumber(dkp) then
			if dkp > 0 then
				icon = "Interface\\ICONS\\Spell_ChargePositive";
			elseif dkp < 0 then
				icon = "Interface\\ICONS\\Spell_ChargeNegative";
			end
		end

		local frame = getglobal("TransactionUIFrameTableListEntry"..n);
		getglobal(frame:GetName().."Time"):SetText(timestamp);
		getglobal(frame:GetName().."Icon"):SetTexture(icon);
		getglobal(frame:GetName().."TID"):SetText(tid);
		getglobal(frame:GetName().."Name"):SetText(name);
		getglobal(frame:GetName().."Command"):SetText(description);
		getglobal(frame:GetName().."DKP"):SetText(dkp);

		if (n > 0) and SOTA_CanReadNotes() then		
			local color = { 128, 128, 128 };
			-- state=1: only for active transactions
			if state == 1 then
				local guildInfo = SOTA_GetGuildPlayerInfo(name);
				if guildInfo then
					color = SOTA_GetClassColorCodes(guildInfo[3]);
				end
			end
			getglobal(frame:GetName().."Name"):SetTextColor((color[1]/255), (color[2]/255), (color[3]/255), 255);
			frame:Enable();
		else
			frame:Disable();
		end

		frame:Show();
	end
	
	
	-- Refresh Transaction Buttons
	local numPages = ceil(numTransactions / MAX_TRANSACTIONS_DISPLAYED);

	if currentTransactionPage > 1 then
		getglobal("PrevTransactionPageButton"):Enable();
	else
		getglobal("PrevTransactionPageButton"):Disable();
	end
	
	if numPages > currentTransactionPage then
		getglobal("NextTransactionPageButton"):Enable();
	else
		getglobal("NextTransactionPageButton"):Disable();
	end
end

function SOTA_PreviousTransactionUIPage()
	if currentTransactionPage > 1 then
		currentTransactionPage = currentTransactionPage - 1;
	end
	SOTA_RefreshTransactionElements();
end

function SOTA_NextTransactionUIPage()
	local numTransactions = table.getn(transactionLog);
	local numPages = ceil(numTransactions / MAX_TRANSACTIONS_DISPLAYED);
	
	if numPages > currentTransactionPage then
		currentTransactionPage = currentTransactionPage + 1;
	end
	SOTA_RefreshTransactionElements();
end


function SOTA_RefreshTransactionDetails()
	selectedTransactionID = 1 * selectedTransactionID;

	local tInfo = transactionLog[selectedTransactionID];
	if not tInfo then
		return;
	end

	local playerInfo = tInfo[6];

	local totalCount = 0;	
	local totalPlayers = { };
	local found;

	local raidRoster = SOTA_GetRaidRoster();
	for n=1, table.getn(raidRoster), 1 do
		totalCount = totalCount + 1
		totalPlayers[totalCount] = { raidRoster[n][1], raidRoster[n][3] };
	end	

	for n=1, table.getn(RaidQueue), 1 do
		totalCount = totalCount + 1
		totalPlayers[totalCount] = { RaidQueue[n][1], RaidQueue[n][4] };
	end	

	totalPlayers = SOTA_SortTableAscending(totalPlayers, 1);



	local name, class, enabled;
	local row = 1;
	local col = 1;
	for n=1, TRANSACTION_DETAILS_COLUMNS * TRANSACTION_DETAILS_ROWS, 1 do
		if n > totalCount then
			name = "";
			class = "";
			enabled = false;
		else
			name = totalPlayers[n][1];
			class = totalPlayers[n][2];
			
			enabled = false;
			if tInfo[5] == 1 then
				for f=1, table.getn(playerInfo), 1 do
					if playerInfo[f][1] == totalPlayers[n][1] then
						enabled = true;
						break;
					end
				end
			end
		end	


		local color = { 128, 128, 128 };
		if enabled then
			color = SOTA_GetClassColorCodes(class);			
		end


		local frame = getglobal("TransactionUIFramePlayerListEntry_"..col.."_"..row);
		-- getglobal(frame:GetName().."Player"..col):SetText(name);
		-- getglobal(frame:GetName().."Player"..col):SetTextColor((color[1]/255), (color[2]/255), (color[3]/255), 255);
		getglobal(frame:GetName().."PlayerButton"):SetText(name);
		getglobal(frame:GetName().."PlayerButton"):SetTextColor((color[1]/255), (color[2]/255), (color[3]/255), 255);

		frame:Show();

		row = row + 1;
		if row > TRANSACTION_DETAILS_ROWS then
			row = 1;
			col = col + 1;
			if col > TRANSACTION_DETAILS_COLUMNS then
				break;
			end;
		end
	end
	
end


--[[
--	Accept a player bid
--	Since 0.0.3
--]]
function SOTA_AcceptSelectedPlayerBid()
	local selectedBid = SOTA_GetSelectedBid();
	if not selectedBid then
		return;
	end

	SOTA_AcceptBid(selectedBid[1], selectedBid[2]);
end


--[[
--	Cancel a player bid
--	Since 0.0.3
--]]
function SOTA_CancelSelectedPlayerBid()
	local selectedBid = SOTA_GetSelectedBid();
	if not selectedBid then
		return;
	end
	
	local previousBid = SOTA_GetHighestBid();
	
	SOTA_UnregisterBid(selectedBid[1], selectedBid[2]);
	
	local highestBid = SOTA_GetHighestBid();
	local bid = 0;
	if highestBid[2] then
		bid = highestBid[2]
	end
	
	if not (previousBid[2] == bid) then
		if bid == 0 then
			bid = SOTA_GetMinimumBid();
		end
		SOTA_rwEcho(string.format("Minimum bid: %d DKP", bid));
	end
end




--[[
--	Pause the Auction
--	Since 0.0.3
--]]
function SOTA_PauseAuction()
	local state = SOTA_GetAuctionState();	
	local secs = SOTA_GetSecondCounter();
	
	if state == STATE_AUCTION_RUNNING then
		SOTA_SetAuctionState(STATE_AUCTION_PAUSED, secs);
		SOTA_rwEcho("Auction have been Paused");
	end
	
	if state == STATE_AUCTION_PAUSED then
		SOTA_SetAuctionState(STATE_AUCTION_RUNNING, secs + SOTA_CONFIG_AuctionExtension);
		SOTA_rwEcho("Auction have been Resumed");
	end

	SOTA_RefreshButtonStates();
end


--[[
--	Finish the Auction
--	Since 0.0.3
--]]
function SOTA_FinishAuction()
	local state = SOTA_GetAuctionState();
	if state == STATE_AUCTION_RUNNING or state == STATE_AUCTION_PAUSED then
		SOTA_rwEcho(string.format("Auction for %s is over", AuctionedItemLink));
		SOTA_SetAuctionState(STATE_AUCTION_COMPLETE);
		
		-- Check if a player was selected; if not, select highest bid:
		if table.getn(IncomingBidsTable) > 0 then
			local selectedBid = SOTA_GetSelectedBid();
			if not selectedBid then
				SOTA_ShowSelectedPlayer(IncomingBidsTable[1][1], IncomingBidsTable[1][2]);
			end
		end
	end
	
	SOTA_RefreshButtonStates();
end

--[[
--	Cancel the Auction
--	Since 0.0.3
--]]
function SOTA_CancelAuction()
	local state = SOTA_GetAuctionState();
	if state == STATE_AUCTION_RUNNING or state == STATE_AUCTION_PAUSED then
		IncomingBidsTable = { }
		SOTA_SetAuctionState(STATE_AUCTION_NONE);
		SOTA_rwEcho("Auction was Cancelled");		
	end
	
	AuctionUIFrame:Hide();
end


--[[
--	Restart the Auction
--	Since 0.0.3
--]]
function SOTA_RestartAuction()
	SOTA_SetAuctionState(STATE_NONE);		
	SOTA_StartAuction(AuctionedItemLink);
end



--[[
--	Show the selected (clicked) bidder information in AuctionUI.
--	Since 0.0.2
--]]
function SOTA_ShowSelectedPlayer(playername, bid)
	local bidInfo = nil
	if playername and bid then
		bidInfo = SOTA_GetBidInfo(playername, bid);	
	end
	
	local bidder, bid, playerclass, rank;
	if not bidInfo then
		bidder = "";
		bid = "";
		playerclass = "";
		rank = "";
	else
		bidder = bidInfo[1];
		bid = string.format("%d", bidInfo[2]);
		playerclass = bidInfo[3];
		rank = bidInfo[4];
	end
	
	local color = SOTA_GetClassColorCodes(playerclass);

	local frame = getglobal("AuctionUIFrameSelected");
	getglobal(frame:GetName().."Bidder"):SetText(bidder);
	getglobal(frame:GetName().."Bidder"):SetTextColor((color[1]/255), (color[2]/255), (color[3]/255), 255);
	getglobal(frame:GetName().."Bid"):SetText(bid);
	getglobal(frame:GetName().."Rank"):SetText(rank);

	SOTA_RefreshButtonStates();
end

function SOTA_ClearSelectedPlayer()
	local frame = getglobal("AuctionUIFrameSelected");
	getglobal(frame:GetName().."Bidder"):SetText("");
	getglobal(frame:GetName().."Bid"):SetText("");
	getglobal(frame:GetName().."Rank"):SetText("");
end

function SOTA_GetClassColorCodes(classname)
	local colors = { 128,128,128 }
	classname = SOTA_UCFirst(classname);

	local cc;
	for n=1, table.getn(CLASS_COLORS), 1 do
		cc = CLASS_COLORS[n];
		if cc[1] == classname then
			return cc[2];
		end
	end

	return colors;
end


--[[
	Convert a msg so first letter is uppercase, and rest as lower case.
]]
function SOTA_UCFirst(msg)
	if not msg then
		return ""
	end	

	local f = string.sub(msg, 1, 1)
	local r = string.sub(msg, 2)
	return string.upper(f) .. string.lower(r)
end




--	****************************************************************************
--
--	DKP functions
--	Most DKP functions will also trigger a Master request.
--
--	****************************************************************************

function SOTA_IsPromoted()
	if not SOTA_IsInRaid(true) then
		return false;
	end 

	local playername = UnitName("player");

	local members = GetNumRaidMembers();
	for n=1, members, 1 do
		local name, rank = GetRaidRosterInfo(n);
		--echo(string.format("Player %s (%s) rank is %d", name, playername, rank))
		
		if(name == playername and rank > 0) then
			return true;
		end
	end
	return false;
end		


function SOTA_CanDoDKP(silentmode)

	if not SOTA_IsInRaid() then
		return false;
	end 

	if not SOTA_CanWriteNotes() then
		if not silentmode then
			gEcho("You do not have access to change notes!");
		end
		return false;
	end

	if not SOTA_IsPromoted() then
		if not silentmode then
			gEcho("You are not promoted!");
		end
		return false;
	end

	return true;
end


--[[
	Get DKP belonging to a specific player.
	Returns NIL if player was not found. Players with no DKP will return 0.
]]
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
			SOTA_rwEcho(string.format("%d DKP was added to %s", dkpValue, playername));
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
			
			SOTA_rwEcho(string.format("%s was replaced with %s (%d DKP)", originalPlayer, newPlayer, dkpValue));
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
			SOTA_rwEcho(string.format("%d DKP was subtracted from %s", abs(dkpValue), playername));
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
			SOTA_rwEcho(string.format("%d %% (%d DKP) was subtracted from %s", percent, minus, playername));
		end

		SOTA_LogSingleTransaction("%Player", playername, -1 * abs(minus));
	else
		if not silentmode then
			gEcho(string.format("Player %s was not found", playername));
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
function SOTA_AddRaidDKP(dkp, silentmode, callMethod)
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
		local zonecheck = SOTA_CONFIG_EnableZonecheck;
		if zonecheck == 1 then
			instance, zonename = SOTA_GetValidDKPZones();
			if not instance then
				zonecheck = 0;
			end
		end
		
		for n=1, table.getn(RaidQueue), 1 do
			local guildInfo = SOTA_GetGuildPlayerInfo(RaidQueue[n][1]);
			if guildInfo and guildInfo[5] == 1 then
				if zonecheck == 0 or (guildInfo[6] == instance or guildInfo[6] == zonename) then			
					--echo(string.format("Applying DKP: %s, zone=%s", RaidQueue[n][1], guildInfo[6]));
					SOTA_ApplyPlayerDKP(RaidQueue[n][1], dkp);				
					tidChanges[tidIndex] = { RaidQueue[n][1], dkp };
					tidIndex = tidIndex + 1;
				else
					gEcho(string.format("No queue DKP for %s (location: %s)", RaidQueue[n][1], guildInfo[6]));
				end
			else
				gEcho(string.format("No queue DKP for %s (Offline)", RaidQueue[n][1]));
			end
		end
		
		if not silentmode then
			SOTA_rwEcho(string.format("%d DKP was added to all players in raid", dkp));
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

		for n=1, table.getn(RaidQueue), 1 do
			local guildInfo = SOTA_GetGuildPlayerInfo(RaidQueue[n][1]);
			if guildInfo and guildInfo[5] == 1 then
				SOTA_ApplyPlayerDKP(RaidQueue[n][1], dkp);
				
				tidChanges[tidIndex] = { RaidQueue[n][1], dkp };
				tidIndex = tidIndex + 1;
			end
		end
		
		if not silentmode then
			SOTA_rwEcho(string.format("%d DKP was subtracted from all players in raid", abs(dkp)));
		end

		SOTA_LogMultipleTransactions(callMethod, tidChanges)
		return true;
	end
	return false;
end

--[[
--	Add <n> DKP to all in 100 yard range.
--	1.0.2: result is number of people affected, and not true/false
--]]
function SOTA_Call_AddRangedDKP(dkp)
	if SOTA_IsInRaid(true) then
		RaidState = RAID_STATE_ENABLED;
		SOTA_RequestMaster();
		SOTA_AddJob( function(job) SOTA_AddRangedDKP(job[2]) end, dkp, "_" )
		SOTA_RequestUpdateGuildRoster();
	end
end
function SOTA_AddRangedDKP(dkp, silentmode, dkpLabel)
	dkp = 1 * dkp;

	local raidUpdateCount = 0;
	local tidIndex = 1;
	local tidChanges = { };
	
	if not dkpLabel then
		dkpLabel = "+Range";
	end
	
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
	
	for n=1, table.getn(RaidQueue), 1 do
		local guildInfo = SOTA_GetGuildPlayerInfo(RaidQueue[n][1]);
		if guildInfo and guildInfo[5] == 1 then
			SOTA_ApplyPlayerDKP(RaidQueue[n][1], dkp);
			
			tidChanges[tidIndex] = { RaidQueue[n][1], dkp };
			tidIndex = tidIndex + 1;
		end;
	end
	
	if not silentmode then
		SOTA_rwEcho(string.format("%d DKP has been added for %d players in range.", dkp, raidUpdateCount));
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
			OnAccept = function() SOTA_ExcludePlayerFromTransaction(selectedTransactionID, playername)  end,
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
			SOTA_rwEcho(string.format("%d DKP was shared (%s DKP per player)", sharedDkp, dkp));
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
		
		local inRange = SOTA_AddRangedDKP(sharedDkp, true, "+ShRange");
		if inRange > 0 then
			local dkp = ceil(sharedDkp / inRange);
			SOTA_rwEcho(string.format("%d DKP was shared for %d players in range (%s DKP per player)", sharedDkp, inRange, dkp));
		end
		return true;
	end
	return false;
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
			gEcho("Guild Decay cancelled: Percent is not a valid number: ".. percent);
		end
		return false;
	end
	
	percent = abs(1 * percent);

	--	This ensure the guild roster also contains Offline members.
	--	Otherwise offline members will not get decayed!
	if not GetGuildRosterShowOffline() == 1 then
		if not silentmode then
			gEcho("Guild Decay cancelled: You need to enable Offline Guild Members in the guild roster first.")
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

			gEcho(string.format("%s was included in transaction %d for %d DKP", playername, transactionID, dkpValue));
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
			gEcho(string.format("%s was excluded from transaction %d for %d DKP", playername, transactionID, dkpValue));
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
   		gEcho(string.format("%s was not found in the guild; DKP was not updated.", playername));
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
	if not playername or not selectedTransactionID then
		return;
	end

	local transaction = SOTA_GetTransaction(selectedTransactionID);
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

	local tInfo = transactionLog[selectedTransactionID];
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
				OnAccept = function() SOTA_ExcludePlayerFromTransaction(selectedTransactionID, playername)  end,
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
				OnAccept = function() SOTA_ReplacePlayerInTransaction(selectedTransactionID, currentPlayername, playername)  end,
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
				OnAccept = function() SOTA_IncludePlayerInTransaction(selectedTransactionID, playername)  end,
				timeout = 0,
				whileDead = true,
				hideOnEscape = true,
				preferredIndex = 3,
			}
			StaticPopup_Show("SOTA_POPUP_TRANSACTION_PLAYER");	
		end	
	end	
end


function SOTA_RequestUndoTransaction(transactionID)
	if not transactionID then
		transactionID = selectedTransactionID
	end

	StaticPopupDialogs["SOTA_POPUP_TRANSACTION_PLAYER"] = {
		text = "Do you want to undo this transaction?",
		button1 = "Yes",
		button2 = "No",
		OnAccept = function() SOTA_UndoTransaction(SOTA_RequestUndoTransaction)  end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopup_Show("SOTA_POPUP_TRANSACTION_PLAYER");	
end

function SOTA_UndoTransaction(transactionID)
	if not transactionID then
		return;
	end

	local tInfo = transactionLog[selectedTransactionID];
	if not tInfo then
		return;
	end
	
	if tInfo[5] == 1 then
		-- Revert DKP
		local playerinfo = tInfo[6];
		local playername, dkp
		for n=1, table.getn(playerinfo), 1 do
			playername = playerinfo[n][1]
			dkp = playerinfo[n][2]
			
			SOTA_ApplyPlayerDKP(playername, -1 * dkp)
		end
		
		-- Roll back
		tInfo[5] = 0;
		transactionLog[selectedTransactionID] = tInfo;
		
		-- Refresh UI
		SOTA_RefreshTransactionDetails();
	end
	
--  Transaction log: Contains a list of { timestamp, tid, author, description, state, { names, dkp } }
--	Transaction state: 0=Rolled back, 1=Active (default), 	

end

function SOTA_ReplacePlayerInTransaction(transactionID, currentPlayer, newPlayer)
	if not currentPlayer or not newPlayer or not transactionID then
		return;
	end

	local transaction = SOTA_GetTransaction(transactionID);
	if not transaction then
		return;
	end
		
	SOTA_Call_SwapPlayersInTransaction(transactionID, newPlayer);
	SOTA_OpenTransauctionUI();
end

function SOTA_IncludePlayerInTransaction(transactionID, playername)
	if not playername or not transactionID then
		return;
	end
	SOTA_Call_IncludePlayer(transactionID, playername);
end

function SOTA_ExcludePlayerFromTransaction(transactionID, playername)
	if not playername or not transactionID then
		return;
	end
	SOTA_Call_ExcludePlayer(transactionID, playername);
end


--[[
--	Get transaction with id=<tid>
--]]
function SOTA_GetTransaction(transactionID)
	transactionID = 1 * transactionID;

	for n=1, table.getn(transactionLog), 1 do
		if (1 * transactionLog[n][2]) == transactionID then
			return transactionLog[n];
		end
	end
	return nil;
end



--[[
	Get information belonging to a specific player in the guild.
	Returns NIL if player was not found.
]]
function SOTA_GetGuildPlayerInfo(player)
	player = SOTA_UCFirst(player);

	for n=1, table.getn(GuildRosterTable), 1 do
		if GuildRosterTable[n][1] == player then
			return GuildRosterTable[n];
		end
	end
	
	return nil;

	-- local memberCount = GetNumGuildMembers()
	-- local playerInfo = nil
-- 
	-- for n=1,memberCount,1 do
		-- --	TODO: Cache the GuildRoster just like the RaidRoster
		-- local dkpValue = 0;
		-- local name, rank, _, _, playerclass, _, publicNote, officerNote = GetGuildRosterInfo(n)
		-- if name == player then
			-- echo("Found guilded player: ".. name);
			-- local note = officerNote
			-- if SOTA_CONFIG_UseGuildNotes then
				-- note = publicNote
			-- end
			-- local _, _, dkp = string.find(note, "<(-?%d*)>")
-- 
			-- if dkp and tonumber(dkp)  then
				-- dkpValue = (1 * dkp)
			-- end
			-- 
			-- playerInfo = { player, dkpValue, playerclass, rank }
		-- end
   	-- end
   	-- 
   	-- return playerInfo;
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


function SOTA_GetHighestBid(bidtype)
	if bidtype and bidtype == 1 then
		-- Find highest MS bid:
		for n=1, table.getn(IncomingBidsTable), 1 do
			if IncomingBidsTable[n][3] == 1 then
				return IncomingBidsTable[n];
			end
		end	
	else
		--	Find highest bid regardless of type.
		--	Note: This might be an MS bid - OS bidders will have to ignore this!
		if table.getn(IncomingBidsTable) > 0 then
			return IncomingBidsTable[1];
		end
	end

	return nil;
end


function SOTA_GetStartingDKP()
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
	
	-- AQ20 and AQ40 share name outside the instance.
	-- Check the X coordinate to see if we are in AQ20 or AQ40:
	--SetMapToCurrentZone();
	--local posX, posY = GetPlayerMapPosition("player");
	--echo("Y: ".. posY);
	
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
	Get current minimum bid.
	Bidtype is set if specific bid type is wanted. If nil (default), then all bid types are accepted.
	bidtype 1 = MS
	bidtype 2 = OS
]]
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
	else
		-- Fallback strategy (no strategy)
		minimumBid = minimumBid + 1;
	end

	return floor(minimumBid);
end




--
--	Raid functions
--

function SOTA_IsInRaid(silentMode)
	local result = ( GetNumRaidMembers() > 0 )
	if not silentMode and not result then
		gEcho("You must be in a raid!");
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
	playerName = UCFirst(playerName);

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
--	Button handlers:
--]]

function SOTA_HandleCheckbox(checkbox)
	local checkboxname = checkbox:GetName();
	--echo(string.format("Checkbox: %s", checkboxname))

	--	Enable MS>OS priority:		
	if checkboxname == "ConfigurationFrameOptionMSoverOSPriority" then
		if checkbox:GetChecked() then
			SOTA_CONFIG_EnableOSBidding = 1;
		else
			SOTA_CONFIG_EnableOSBidding = 0;
		end
		return;
	end
		
	--	Enable RQ Zonecheck:		
	if checkboxname == "ConfigurationFrameOptionEnableZonecheck" then
		if checkbox:GetChecked() then
			SOTA_CONFIG_EnableZonecheck = 1;
		else
			SOTA_CONFIG_EnableZonecheck = 0;
		end
		return;
	end

	--	Disable Dashboard:		
	if checkboxname == "ConfigurationFrameOptionDisableDashboard" then
		if checkbox:GetChecked() then
			SOTA_CONFIG_DisableDashboard = 1;
			SOTA_CloseDashboard();
		else
			SOTA_CONFIG_DisableDashboard = 0;
		end
		return;
	end

	
	--	Store DKP in Public Notes:		
	if checkboxname == "ConfigurationFrameOptionPublicNotes" then
		if checkbox:GetChecked() then
			SOTA_CONFIG_UseGuildNotes = 1;
		else
			SOTA_CONFIG_UseGuildNotes = 0;
		end
		return;
	end
	
	if checkbox:GetChecked() then		
		--	Bid type:
		--	If checked, then we need to uncheck others in same group:
		if checkboxname == "ConfigurationFrameOptionMinBidStrategy0" then
			getglobal("ConfigurationFrameOptionMinBidStrategy1"):SetChecked(0);
			getglobal("ConfigurationFrameOptionMinBidStrategy2"):SetChecked(0);
			getglobal("ConfigurationFrameOptionMinBidStrategy3"):SetChecked(0);
			SOTA_CONFIG_MinimumBidStrategy = 0;
		elseif checkboxname == "ConfigurationFrameOptionMinBidStrategy1" then
			getglobal("ConfigurationFrameOptionMinBidStrategy0"):SetChecked(0);
			getglobal("ConfigurationFrameOptionMinBidStrategy2"):SetChecked(0);
			getglobal("ConfigurationFrameOptionMinBidStrategy3"):SetChecked(0);
			SOTA_CONFIG_MinimumBidStrategy = 1;
		elseif checkboxname == "ConfigurationFrameOptionMinBidStrategy2" then
			getglobal("ConfigurationFrameOptionMinBidStrategy0"):SetChecked(0);
			getglobal("ConfigurationFrameOptionMinBidStrategy1"):SetChecked(0);
			getglobal("ConfigurationFrameOptionMinBidStrategy3"):SetChecked(0);
			SOTA_CONFIG_MinimumBidStrategy = 2;
		elseif checkboxname == "ConfigurationFrameOptionMinBidStrategy3" then
			getglobal("ConfigurationFrameOptionMinBidStrategy0"):SetChecked(0);
			getglobal("ConfigurationFrameOptionMinBidStrategy1"):SetChecked(0);
			getglobal("ConfigurationFrameOptionMinBidStrategy2"):SetChecked(0);
			SOTA_CONFIG_MinimumBidStrategy = 3;			
		end
	end
end

function SOTA_OnCancelBidClick(object)
	SOTA_CancelSelectedPlayerBid();
end

function SOTA_OnPauseAuctionClick(object)
	SOTA_PauseAuction();
end

function SOTA_OnFinishAuctionClick(object)
	SOTA_FinishAuction();
end

function SOTA_OnRestartAuctionClick(object)
	SOTA_RestartAuction();
end

function SOTA_OnAcceptBidClick(object)
	SOTA_AcceptSelectedPlayerBid();
end

function SOTA_OnCancelAuctionClick(object)
	SOTA_CancelAuction();
end

function SOTA_OnBidClick(object)
	local msgID = object:GetID();
	
	local bidder = getglobal(object:GetName().."Bidder"):GetText();
	if not bidder or bidder == "" then
		return;
	end	
	local bid = 1 * (getglobal(object:GetName().."Bid"):GetText());

	SOTA_ShowSelectedPlayer(bidder, bid);
end

function SOTA_OnQueuedPlayerClick(object, buttonname)
	local msgID = object:GetID();
	
	local playername = getglobal(object:GetName().."Name"):GetText();
	if not playername or playername == "" then
		return;
	end

	if not SOTA_IsPromoted(true) then
		return;
	end

	-- Promote player to Master if none is currently set
	SOTA_CheckForMaster();	

	
	if buttonname == "RightButton" then
		StaticPopupDialogs["SOTA_POPUP_REMOVE_PLAYER"] = {
			text = string.format("Remove %s from the raid queue?", playername),
			button1 = "Yes",
			button2 = "No",
			OnAccept = function() SOTA_RemoveQueuedPlayerGroupNow(playername)  end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3,  -- avoid some UI taint, see http://www.wowace.com/announcements/how-to-avoid-some-ui-taint/
		}
		
		StaticPopup_Show("SOTA_POPUP_REMOVE_PLAYER");
	else
		local playerrank = getglobal(object:GetName().."Rank"):GetText();
		if (string.len(playerrank) > 7) and (string.sub(playerrank, 1, 7) == "Queue: ") then
			if playername == "Tanks" then
				SOTA_InviteQueuedPlayerGroup(playername, "tank");
			elseif playername == "Melee" then
				SOTA_InviteQueuedPlayerGroup(playername, "melee");
			elseif playername == "Ranged" then
				SOTA_InviteQueuedPlayerGroup(playername, "ranged");
			elseif playername == "Healers" then
				SOTA_InviteQueuedPlayerGroup(playername, "healer");
			end
			
			return;
		end
		
		SOTA_InviteQueuedPlayer(playername);	
	end
end

function SOTA_OnTransactionLogClick(object)
	local msgID = object:GetID();
	selectedTransactionID = getglobal(object:GetName().."TID"):GetText();
	if not selectedTransactionID then
		return;
	end
	
	SOTA_RefreshTransactionDetails();
	SOTA_OpenTransactionDetails();
end

function SOTA_OnTransactionLogDetailPlayer(object)
	local msgID = object:GetID();
	local playername = getglobal(object:GetName().."PlayerButton"):GetText();
	
	SOTA_ToggleIncludePlayerInTransaction(playername);
end

function SOTA_OnOptionAuctionTimeChanged(object)
	SOTA_CONFIG_AuctionTime = tonumber( getglobal(object:GetName()):GetValue() );
	
	local valueString = "".. SOTA_CONFIG_AuctionTime;
	if SOTA_CONFIG_AuctionTime == 0 then
		valueString = "(No timer)";
	end
		
	getglobal(object:GetName().."Text"):SetText(string.format("Auction Time: %s seconds", valueString))
end

function SOTA_OnOptionAuctionExtensionChanged(object)
	SOTA_CONFIG_AuctionExtension = tonumber( getglobal(object:GetName()):GetValue() );
	
	local valueString = "".. SOTA_CONFIG_AuctionExtension;
	if SOTA_CONFIG_AuctionExtension == 0 then
		valueString = "(No extension)";
	end
		
	getglobal(object:GetName().."Text"):SetText(string.format("Auction Extension: %s seconds", valueString))
end

function SOTA_OnOptionDKPStringLengthChanged(object)
	SOTA_CONFIG_DKPStringLength = tonumber( getglobal(object:GetName()):GetValue() );
	
	local valueString = "".. SOTA_CONFIG_DKPStringLength;
	if SOTA_CONFIG_DKPStringLength == 0 then
		valueString = "(No limit)";
	end
		
	getglobal(object:GetName().."Text"):SetText(string.format("DKP String Length: %s", valueString))
end

function SOTA_OnOptionMinimumDKPPenaltyChanged(object)
	SOTA_CONFIG_MinimumDKPPenalty = tonumber( getglobal(object:GetName()):GetValue() );
	
	local valueString = "".. SOTA_CONFIG_MinimumDKPPenalty;
	if SOTA_CONFIG_MinimumDKPPenalty == 0 then
		valueString = "(None)";
	end
	
	getglobal(object:GetName().."Text"):SetText(string.format("Minimum DKP penalty: %s", valueString))
end

function SOTA_OnOptionBossDKPChanged(object)
	local slider = object:GetName();
	local value = tonumber( getglobal(object:GetName()):GetValue() );
	local valueString = "";
	
	if slider == "ConfigurationFrameOption_20Mans" then
		SOTA_SetBossDKPValue("20Mans", value);
		valueString = string.format("20 mans (ZG, AQ20): %d DKP", value);
	elseif slider == "ConfigurationFrameOption_MoltenCore" then
		SOTA_SetBossDKPValue("Molten Core", value);
		valueString = string.format("Molten Core: %d DKP", value);
	elseif slider == "ConfigurationFrameOption_Onyxia" then
		SOTA_SetBossDKPValue("Onyxia", value);
		valueString = string.format("Onyxia: %d DKP", value);
	elseif slider == "ConfigurationFrameOption_BlackwingLair" then
		SOTA_SetBossDKPValue("BlackwingLair", value);
		valueString = string.format("Blackwing Lair: %d DKP", value);
	elseif slider == "ConfigurationFrameOption_AQ40" then
		SOTA_SetBossDKPValue("AQ40", value);
		valueString = string.format("Temple of Ahn'Qiraj: %d DKP", value);
	elseif slider == "ConfigurationFrameOption_Naxxramas" then
		SOTA_SetBossDKPValue("Naxxramas", value);
		valueString = string.format("Naxxramas: %d DKP", value);
	elseif slider == "ConfigurationFrameOption_WorldBosses" then
		SOTA_SetBossDKPValue("WorldBosses", value);
		valueString = string.format("World Bosses: %d DKP", value);
	end

	getglobal(slider.."Text"):SetText(valueString);
end

function SOTA_RefreshBossDKPValues()
	getglobal("ConfigurationFrameOption_20Mans"):SetValue(SOTA_GetBossDKPValue("20Mans"));
	getglobal("ConfigurationFrameOption_MoltenCore"):SetValue(SOTA_GetBossDKPValue("MoltenCore"));
	getglobal("ConfigurationFrameOption_Onyxia"):SetValue(SOTA_GetBossDKPValue("Onyxia"));
	getglobal("ConfigurationFrameOption_BlackwingLair"):SetValue(SOTA_GetBossDKPValue("BlackwingLair"));
	getglobal("ConfigurationFrameOption_AQ40"):SetValue(SOTA_GetBossDKPValue("AQ40"));
	getglobal("ConfigurationFrameOption_Naxxramas"):SetValue(SOTA_GetBossDKPValue("Naxxramas"));
	getglobal("ConfigurationFrameOption_WorldBosses"):SetValue(SOTA_GetBossDKPValue("WorldBosses"));
end

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




--
--	Transaction Log handling
--
function SOTA_LogIncludeExcludeTransaction(transactioncmd, name, tid, dkp)
	local author = UnitName("Player");
	local transactions = { };
	transactions[1] = { name, dkp };
	
	local tidData = { SOTA_GetTimestamp(), tid, author, transactioncmd, TRANSACTION_STATE_ACTIVE, transactions };
	
	SOTA_RefreshTransactionElements();
	SOTA_BroadcastTransaction(tidData);
end



function SOTA_LogSingleTransaction(transactioncmd, name, dkp)
	local transactions = { };
	transactions[1] = { name, dkp };
	
	SOTA_LogMultipleTransactions(transactioncmd, transactions);
end


--[[
--	Add transaction and broadcast to other clients.
--]]
function SOTA_LogMultipleTransactions(transactioncmd, transactions)
	local author = UnitName("Player");
	local tid = SOTA_GetNextTransactionID();
	transactionLog[tid] = { SOTA_GetTimestamp(), tid, author, transactioncmd, TRANSACTION_STATE_ACTIVE, transactions };

	SOTA_RefreshTransactionElements();
	SOTA_BroadcastTransaction(transactionLog[tid]);
end

--[[
	Broadcast a transaction to other clients
]]
function SOTA_BroadcastTransaction(transaction)
	if SOTA_IsInRaid(true) then
		local timestamp = transaction[1];
		local tid = transaction[2];
		local author = transaction[3];
		local description = transaction[4];
		local transstate = transaction[5];
		local transactions = transaction[6];

		local rec, name, dkp, payload;
		for n = 1, table.getn(transactions), 1 do
			rec = transactions[n];
			name = rec[1];
			dkp = rec[2];
			--	TID plus NAME combo is unique.
			payload = timestamp .."/".. tid .."/".. author .."/".. description .."/".. transstate .."/".. name .."/".. dkp;
			addonEcho("TX_UPDATE#"..payload.."#");
		end
	end
end

function SOTA_GetNextTransactionID()
	currentTransactionID = currentTransactionID + 1;
	return currentTransactionID;
end

function SOTA_GetTimestamp()
	return date("%H:%M:%S", time());
end

--[[
	Synchronize the local transaction log with other clients.
	This is done in a two-step approach:
	- step 1:
		A TX_SYNCINIT is sent to all clients. Each clients now responds
		back (RX_SYNCINIT) with lowest and hignest TID.
		This shows how many transactions each client contains.
	- step 2:
		The client picks the response with most transactions in it,
		and will ask that client for all transactions.
		Note that step 2 will require a delay to allow all clients to
		respond back (a 2 second delay should be fine).

	Transactions are merged into existing transaction log, there is therefore
	no need to delete log fiest.
	This method should be called when GuildDKP is launched, or player enters
	a raid to make sure transactionlog is always updated.
]]
function SOTA_Synchronize()
	--	This initiates step 1: send a TX_SYNCINIT to all clients.
	
	synchronizationState = 1	-- Step 1: Initialize
	
	addonEcho("TX_SYNCINIT##");
	
	SOTA_AddTimer(SOTA_HandleRXSyncInitDone, 3);
end





--
--	Message Handling
--

--[[
	Respond to a TX_VERSION command.
	Input:
		msg is the raw message
		sender is the name of the message sender.
	We should whisper this guy back with our current version number.
	We therefore generate a response back (RX) in raid with the syntax:
	GuildDKP:<sender (which is actually the receiver!)>:<version number>
]]
local function SOTA_HandleTXVersion(message, sender)
	addonEcho(string.format("RX_VERSION#%s#%s", GetAddOnMetadata("SOTA", "Version"), sender));
end

--[[
--	A version response (RX) was received. The version information is displayed locally.
--]]
local function SOTA_HandleRXVersion(message, sender)
	gEcho(string.format("%s is using %s version %s", sender, SOTA_TITLE, message));
end


--[[
--	TX_UPDATE: A transaction was broadcasted. Add transaction details to transactions list.
--]]
local function SOTA_HandleTXUpdate(message, sender)
	--	Message was from SELF, no need to update transactions since I made them already!
	if (sender == UnitName("player")) then
		--echo(string.format("Message from self, skipping - Msg=%s", message));
		return
	end

	local _, _, timestamp, tid, author, description, transstatus, name, dkp = string.find(message, "([^/]*)/([0-9]*)/([^/]*)/([^/]*)/([0-9]*)/([^/]*)/([^/]*)")

	tid = tonumber(tid);


	-- "Include" and "Exclude" does not have transactions, and should not be stored in the transaction log.
	-- Therefore we "catch" them here and perform the include/exclude operation as needed.
	-- These operations only update the local transaction log; no DKP is actually moved since this was
	-- already done by the master.
	if description == "Include" then
		SOTA_IncludePlayer(tid, name, true, true);
		SOTA_RefreshTransactionElements();	
		return;
	elseif description == "Exclude" then
		SOTA_ExcludePlayer(tid, name, true, true);		
		SOTA_RefreshTransactionElements();
		return;
	end
	
	local transaction = transactionLog[tid];
	if not transaction then
		transaction = { timestamp, tid, author, description, transstatus, { } };
	end
	
	--	List of transaction lines contained in this transaction ("name=dkp" entries)
	local transactions = transaction[6];
	transactions[table.getn(transactions) + 1] = { name, dkp }
	transaction[6] = transactions;

	transactionLog[tid] = transaction;

	-- Make sure to update next transactionid
	if currentTransactionID < tid then
		currentTransactionID = tid;
	end

	SOTA_RefreshTransactionLog();
end


--[[
--	Clients must return the highest transaction ID they own in RX_SYNCINIT
--	AND the number of records in RaidQueue.
--]]
function SOTA_HandleTXSyncInit(message, sender)
	--	Message was from SELF, no need to return RX_SYNCINIT
	if (sender == UnitName("player")) then
		return;
	end

	syncResults = { };
	syncRQResults = { };

	-- Transaction Log:	
	addonEcho("RX_SYNCINIT#"..currentTransactionID.."#"..sender)
	-- Raid queue: (kept in two messages for backwards compability)
	addonEcho("RX_SYNCRQINIT#".. table.getn(RaidQueue) .."#"..sender)
	
	-- If this is the MASTER, we should also tell this to the requester.
	if SOTA_Master then
		addonEcho("TX_SETMASTER#".. SOTA_Master .."#"..sender);	
	end
	
end


--Handle RX_SYNCINIT responses from clients
function SOTA_HandleRXSyncInit(message, sender)
	--	Check we are still in TX_SYNCINIT state
	if not (synchronizationState == 1) then
		return
	end

	local maxTid = tonumber(message);
	local syncIndex = table.getn(syncResults) + 1;
	
	syncResults[syncIndex] = { sender, maxTid };
end

--Handle RX_SYNCRQINIT responses from clients
function SOTA_HandleRXSyncRQInit(message, sender)
	--	Check we are still in TX_SYNCINIT state
	if not (synchronizationState == 1) then
		return
	end

	local qCount = tonumber(message);
	local syncIndex = table.getn(syncRQResults) + 1;
	
	syncRQResults[syncIndex] = { sender, qCount };
end



--[[
--	This is called by the timer when responses are no longer accepted
--	After this, responses must be investigated and a source can be selected.
--]]
function SOTA_HandleRXSyncInitDone()
	synchronizationState = 2;
	
	-- Sync transactions:
	local maxTid = 0;
	local maxName = "";
	for n = 1, table.getn(syncResults), 1 do
		local res = syncResults[n];
		local tid = tonumber(res[2]);
		if(tid > maxTid) then
			maxTid = tid;
			maxName = res[1];
		end
	end

	--	No transactions was found, nothing to sync.
	if maxTid == 0 then
		synchronizationState = 0
	else
		if maxTid > currentTransactionID then
			currentTransactionID = maxTid
		end
		--	Now request transaction synchronization from selected target
		addonEcho("TX_SYNCTRAC##"..maxName);	
	end


	-- Raid queue:
	local maxQueue = 0;
	local maxSource = "";
	for n=1, table.getn(syncRQResults), 1 do
		if(tonumber(syncRQResults[n][2]) > maxQueue) then
			maxQueue = syncRQResults[n][2];
			maxSource = syncRQResults[n][1];
		end
	end

	if maxQueue > 0 then
		addonEcho("TX_SYNCRAIDQ##"..maxSource);
	end	
end


--	Client is requested to sync transaction log with <sender>
function SOTA_HandleTXSyncTransaction(message, sender)
	--	Iterate over transactions
	for n = 1, table.getn(transactionLog), 1 do
		local rec = transactionLog[n]
		local timestamp = rec[1]
		local tid = rec[2]
		local author = rec[3]
		local desc = rec[4]
		local state = rec[5]
		local tidChanges = rec[6]

		--	Iterate over transaction lines
		for f = 1, table.getn(tidChanges), 1 do
			local change = tidChanges[f]
			local name = change[1]
			local dkp = change[2]
			
			local response = timestamp.."/"..tid.."/"..author.."/"..desc.."/"..state.."/"..name.."/"..dkp;
			
			addonEcho("RX_SYNCTRAC#"..response.."#"..sender);
		end
	end
	
	--	Last, send an EOF to signal all transactions were sent.
	addonEcho("RX_SYNCTRAC#EOF#"..sender);
end

--[[
--	Sync all elements in raid queue to sender.
--]]
function SOTA_HandleTXSyncRaidQueue(message, sender)

	--{ Name, QueueID, Role , Class }
	for n=1, table.getn(RaidQueue), 1 do
		local name = RaidQueue[n][1];
		local role = RaidQueue[n][3];
		local clss = RaidQueue[n][4];

		local response = name.."/"..role.."/"..clss;
		addonEcho("RX_SYNCRAIDQ#"..response.."#"..sender);
	end

	--	Last, send an EOF to signal all records were sent.
	addonEcho("RX_SYNCRAIDQ#EOF#"..sender);
end


--	Received a sync'ed transaction - merge this with existing transaction log.
function SOTA_HandleRXSyncTransaction(message, sender)
	if message == "EOF" then
		synchronizationState = 0;
		return;
	end

	local _, _, timestamp, tid, author, description, transstatus, name, dkp = string.find(message, "([^/]*)/([0-9]*)/([^/]*)/([^/]*)/([0-9]*)/([^/]*)/([^/]*)")

	tid = tonumber(tid);

	local transaction = transactionLog[tid];
	if not transaction then
		transaction = { timestamp, tid, author, description, transstatus, {} };
	end

	local transactions = transaction[6];
	local tracCount = table.getn(transactions);

	--	Check if this transaction line does already exist in transaction
	for f = 1, tracCount, 1 do
		local trac = transactions[f];
		local currentName = trac[1];
		local currentDkp = trac[2];

		--	This entry already exists - no need to process further.
		if currentName == name then
			return;
		end
	end

	--	If we end here, then the transaction does not exist in our transaction log.
	--	Create entry:
	transactions[tracCount + 1] = { name, dkp };
	transaction[6] = transactions;
	transactionLog[tid] = transaction;
end


--[[
--	Received a RaidQueue sync record - merge with existing queue.
--]]
function SOTA_HandleRXSyncRaidQueue(message, sender)
	if message == "EOF" then
		synchronizationState = 0;
		return;
	end

	local _, _, name, role, clss = string.find(message, "([^/]*)/([^/]*)/([^/]*)")
	SOTA_AddToRaidQueue(name, role, true);
end





--
--	Job Handling
--
function SOTA_AddJob( method, arg1, arg2 )
	JobQueue[table.getn(JobQueue) + 1] = { method, arg1, arg2 }
end

function SOTA_GetNextJob()
	local job
	local cnt = table.getn(JobQueue)
	
	if cnt > 0 then
		job = JobQueue[1]
		for n=2,cnt,1 do
			JobQueue[n-1] = JobQueue[n]			
		end
		JobQueue[cnt] = nil
	end

	return job
end




--
--	Guild and Raid Roster Event Handling
--
--	RaidRoster will update internal raid roster table.
--	GuildRoster will update guild roster table and check job queue
--

function SOTA_RequestUpdateGuildRoster()
	GuildRoster()
end

function SOTA_OnGuildRosterUpdate()
	SOTA_RefreshGuildRoster();

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
	SOTA_RefreshTransactionLog();
end


--[[
	Update the guild roster status cache: members and DKP.
	Used to display DKP values for non-raiding members
	(/gdclass and /gdstat)
]]
function SOTA_RefreshGuildRoster()
	--echo("Refreshing GuildRoster");

	GuildRosterTable = { }
	
	if not SOTA_CanReadNotes() then
		return;
	end

	local memberCount = GetNumGuildMembers();
	local note
	for n=1,memberCount,1 do
		local name, rank, _, _, class, zone, publicnote, officernote, online = GetGuildRosterInfo(n)

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
		if not dkp then
			dkp = 0;
		end
		
		--echo(string.format("Added %s (%s)", name, online));
		
		GuildRosterTable[n] = { name, (1 * dkp), class, rank, online, zone }
	end
end


function SOTA_OnRaidRosterUpdate(event, arg1, arg2, arg3, arg4, arg5)
	RaidRosterLazyUpdate = true;

	SOTA_RefreshRaidQueue();
	SOTA_RefreshTransactionLog();
	
	if SOTA_IsInRaid(true) then
		SOTA_Synchronize();
	else
		transactionLog = { };
		RaidQueue = { };
		
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
	Re-read the raid status and namely the DKP values.
	Should be called after each roster update.
]]
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


function SOTA_OnChatMsgAddon(event, prefix, msg, channel, sender)
	--echo(string.format("Prefix=%s, MSG=%s", prefix, msg));

	if (prefix == SOTA_MESSAGE_PREFIX) or (prefix == "GuildDKPv1") then	
		--	Split incoming message in Command, Payload (message) and Recipient
		local _, _, cmd, message, recipient = string.find(msg, "([^#]*)#([^#]*)#([^#]*)")

		if not cmd then
			return	-- cmd is mandatory, remaining parameters are optionel.
		end

		--	Ignore message if it is not for me. Receipient can be blank, which means it is for everyone.
		if not (recipient == "") then
			if not (recipient == UnitName("player")) then
				return
			end
		end
		
		if not message then
			message = ""
		end
		
		--echo(string.format("Incoming: CMD=%s, MSG=%s, Sender=%s, Recipient: %s", cmd, message, sender, recipient));
	
		if cmd == "TX_VERSION" then
			if prefix == "GuildDKPv1" then
				return;
			end
			SOTA_HandleTXVersion(message, sender)
		elseif cmd == "RX_VERSION" then
			if prefix == "GuildDKPv1" then
				return;
			end
			SOTA_HandleRXVersion(message, sender)
		elseif cmd == "TX_UPDATE" then
			SOTA_HandleTXUpdate(message, sender)
		elseif cmd == "TX_SYNCINIT" then
			SOTA_HandleTXSyncInit(message, sender)
		elseif cmd == "RX_SYNCINIT" then
			SOTA_HandleRXSyncInit(message, sender)
		elseif cmd == "RX_SYNCRQINIT" then
			SOTA_HandleRXSyncRQInit(message, sender)
		elseif cmd == "TX_SYNCTRAC" then
			SOTA_HandleTXSyncTransaction(message, sender)
		elseif cmd == "RX_SYNCTRAC" then
			SOTA_HandleRXSyncTransaction(message, sender)
		elseif cmd == "TX_SYNCRAIDQ" then
			SOTA_HandleTXSyncRaidQueue(message, sender)		
		elseif cmd == "RX_SYNCRAIDQ" then
			SOTA_HandleRXSyncRaidQueue(message, sender)
		elseif cmd == "TX_SYNCRQINIT" then
			SOTA_HandleTXSyncRaidQueueInit(message, sender)
		elseif cmd == "RX_SYNCRQINIT" then
			SOTA_HandleRXSyncRaidQueueInit(message, sender)
		elseif cmd == "TX_SETMASTER" then
			SOTA_HandleTXMaster(message, sender)		
		elseif cmd == "TX_JOINQUEUE" then
			SOTA_HandleTXJoinQueue(message, sender)		
		elseif cmd == "TX_LEAVEQUEUE" then
			SOTA_HandleTXLeaveQueue(message, sender)		
		else
			--gEcho("Unknown command, raw msg="..msg)
		end
	end
end


function SOTA_OnZoneChanged()
	if SOTA_IsInRaid(true) then
		local dkp = SOTA_GetStartingDKP();
		if dkp > 0 then
			local zonetext = GetRealZoneText();			
			if zonetext == "Azshara" then
				zonetext = zonetext .." (Azuregos)";
			elseif zonetext == "Blasted Lands" then
				zonetext = zonetext .." (Lord Kazzak)";
			elseif zonetext == "Ashenvale" or zonetext == "Duskwood" or zonetext == "The Hinterlands" or zonetext == "Feralas" then
				zonetext = zonetext .." (Emerald Dream)";
			end
			
			gEcho(string.format("Instance: "..COLOUR_INTRO.."%s"..COLOUR_CHAT, zonetext));
			gEcho(string.format("Boss value: "..COLOUR_INTRO.."%s"..COLOUR_CHAT.." DKP", dkp*10));
			gEcho(string.format("Minimum bid: "..COLOUR_INTRO.."%s"..COLOUR_CHAT.." DKP", dkp));
		end

		-- -- debugging:
		-- SetMapToCurrentZone();
		-- local posX, posY = GetPlayerMapPosition("player");
		-- echo("X: ".. posX ..", Y: ".. posY);


		-- local subzone = GetSubZoneText();
		-- if subzone then
			-- debugEcho(string.format("Entering %s - sub zone %s", zonetext, subzone));
		-- else
			-- debugEcho(string.format("Entering %s", zonetext));
		-- end
	end
end




function SOTA_InitializeConfigSettings()
    if not SOTA_CONFIG_UseGuildNotes then
		SOTA_CONFIG_UseGuildNotes = 0;
    end
    if not SOTA_CONFIG_MinimumBidStrategy then
		SOTA_CONFIG_MinimumBidStrategy = 0;
    end
	if not SOTA_CONFIG_DKPStringLength then
		SOTA_CONFIG_DKPStringLength = 5;
	end
	if not SOTA_CONFIG_MinimumDKPPenalty then
		SOTA_CONFIG_MinimumDKPPenalty = 50;
	end

	-- Update GUI:
	if not SOTA_CONFIG_EnableOSBidding then
		SOTA_CONFIG_EnableOSBidding = 1;
	end
	if not SOTA_CONFIG_EnableZonecheck then
		SOTA_CONFIG_EnableZonecheck = 1;
	end
	if not SOTA_CONFIG_DisableDashboard then
		SOTA_CONFIG_DisableDashboard = 1;
	end
	
	getglobal("ConfigurationFrameOptionMSoverOSPriority"):SetChecked(SOTA_CONFIG_EnableOSBidding);
	getglobal("ConfigurationFrameOptionEnableZonecheck"):SetChecked(SOTA_CONFIG_EnableZonecheck);
	getglobal("ConfigurationFrameOptionDisableDashboard"):SetChecked(SOTA_CONFIG_DisableDashboard);


	if SOTA_CONFIG_UseGuildNotes == 1 then
		getglobal("ConfigurationFrameOptionPublicNotes"):SetChecked(1)
	end

	getglobal("ConfigurationFrameOptionMinBidStrategy".. SOTA_CONFIG_MinimumBidStrategy):SetChecked(1)
	getglobal("ConfigurationFrameOptionDKPStringLength"):SetValue(SOTA_CONFIG_DKPStringLength);
	getglobal("ConfigurationFrameOptionMinimumDKPPenalty"):SetValue(SOTA_CONFIG_MinimumDKPPenalty);
	getglobal("ConfigurationFrameOptionAuctionTime"):SetValue(SOTA_CONFIG_AuctionTime);
	getglobal("ConfigurationFrameOptionAuctionExtension"):SetValue(SOTA_CONFIG_AuctionExtension);
	
	SOTA_RefreshBossDKPValues();
end


--
--	Events
--
function SOTA_OnEvent(event, arg1, arg2, arg3, arg4, arg5)
	if (event == "ADDON_LOADED") then
		if arg1 == "SOTA" then
		    SOTA_InitializeConfigSettings();
		end
	elseif (event == "CHAT_MSG_GUILD") then
		SOTA_HandleGuildChatMessage(event, arg1, arg2, arg3, arg4, arg5);
	elseif (event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER") then
		SOTA_HandleRaidChatMessage(event, arg1, arg2, arg3, arg4, arg5);
	elseif (event == "CHAT_MSG_WHISPER") then
		SOTA_OnChatWhisper(event, arg1, arg2, arg3, arg4, arg5);
	elseif (event == "CHAT_MSG_ADDON") then
		SOTA_OnChatMsgAddon(event, arg1, arg2, arg3, arg4, arg5)
	elseif (event == "GUILD_ROSTER_UPDATE") then
		SOTA_OnGuildRosterUpdate(event, arg1, arg2, arg3, arg4, arg5)
	elseif (event == "RAID_ROSTER_UPDATE") then
		SOTA_OnRaidRosterUpdate(event, arg1, arg2, arg3, arg4, arg5)
	end
end

function SOTA_OnLoad()
	gEcho(string.format("Loot Distribution Addon version %s by %s", GetAddOnMetadata("SOTA", "Version"), GetAddOnMetadata("SOTA", "Author")));
    
    this:RegisterEvent("ADDON_LOADED");
    this:RegisterEvent("GUILD_ROSTER_UPDATE");
    this:RegisterEvent("RAID_ROSTER_UPDATE");
	this:RegisterEvent("CHAT_MSG_GUILD");
	this:RegisterEvent("CHAT_MSG_RAID");
	this:RegisterEvent("CHAT_MSG_RAID_LEADER");
    this:RegisterEvent("CHAT_MSG_WHISPER");
    this:RegisterEvent("CHAT_MSG_ADDON");

    
    SOTA_SetAuctionState(STATE_NONE);
    SOTA_RefreshRaidRoster();
	SOTA_InitializeTableElements(); 
	
	SOTA_RequestUpdateGuildRoster()
	
	SOTA_SetMasterState(SOTA_Master, CLIENT_STATE);
	
	if SOTA_IsInRaid(true) then	
		SOTA_Synchronize();
	end	
end

