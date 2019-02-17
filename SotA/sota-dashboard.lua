--[[
--	SotA - State of the Art DKP Addon
--	By Mimma <VanillaGaming.org>
--
--	Unit: sota-dashboard.lua
--	This unit displays a minimal UI to control SotA operation.
--	Also the Slash Command handler is present in this unit, as this
--	is the controlling part of SotA.
--]]


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
--]]

--	For now the one issuing DKP or starting a BID round will be master. All other will be passive.
--	Helper is not supported.
local CLIENT_STATE_SLAVE		= 0;		-- Client is only listening
local CLIENT_STATE_MASTER		= 2;		-- Client issued a DKP command (active master)
local CLIENT_STATE				= CLIENT_STATE_SLAVE

local SOTA_Master				= nil;		-- Current master
local GUILD_REFRESH_TIMER		= 5;		-- Check guild update every 5th second

--	Holds current Zone name - used for checking for new Zones(Instances primarily)
local CurrentZoneName			= nil;

--	List of {jobname,name,dkp} tables
local JobQueue					= { }

--	Sync.state: 0=idle, 1=initializing, 2=synchronizing
local synchronizationState		= 0;

--	Hold RX_SYNCINIT responses when querying for a client to sync. { message, id/count }
local syncResults				= { };
local syncRQResults				= { };




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
-                   /SOTA rangeshare [+]<n>                 -                   sharerange and rangeshare (and the alias SR) do the same.
/gddecay <n>        /SOTA decay <n>[%]  -                   -                   Remove <n>% DKP from all guild members
-                   /SOTA decaytest     -                   -                   Test if DECAY operation will work (check for odd characters)

-                   /SOTA listqueue     !listqueue          /w <o> listqueue    List names of people in queue (by whisper or local if user have SOTA installed)
-                   /SOTA queue         !queue              /w <o> queue        Get queue status
-                   /SOTA queue <r>     !queue <r>          /w <o> queue <r>    Queue as role <r>: <r> can be tank, melee, ranged or healer
-                   /SOTA addqueue <p>  -                   -                   Add person <p> manually to the queue. Must be promoted.
-                   /SOTA leave         !leave              /w <o> leave        Leave the raid queue (can be done by players in raid)

-                   /SOTA <item>        -                   -                   Starts an auction for <item>
                    /startauction
-                   /SOTA bid <n>       !bid <n>            /w <o> bid <n>      Bid <n> DKP on item currently being auctioned
-                   /SOTA bid min       !bid min            /w <o> bid min      Bid the minimum bid on item currently being auctioned
-                   /SOTA bid max       !bid max            /w <o> bid max      Bid everyting (go all out) on item currently being auctioned
-                   /SOTA pass          !pass               /w <o> pass         Pass last bid

-                   /SOTA config        -                   -                   Open the configuration interface
-                   /SOTA log           -                   -                   Open the transaction log interface
-                   /SOTA version       -                   -                   Check the SOTA versions running
-                   /SOTA master        -                   -                   Force player to become Master (if he is raid leader or assistant)
-                   /SOTA clear         -                   -                   Clears the local history log (not the shared log).

/gdhelp             /SOTA help          -                   -                   Show HELP page (more or less this page!)
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
	

	--	Command: rule
	--	Syntax: "rule"
	--	Added for rule engine testing.
	if cmd == "rule" then
		return SOTA_PerformSampleRuleTest();
	end;


	--	Command: help
	--	Syntax: "config"	
	if cmd == "help" or cmd == "?" or cmd == "" then
		SOTA_DisplayHelp();
		return;	
	end


	--	Command: config
	--	Syntax: "config"	
	if cmd == "cfg" or cmd == "config" then
		SOTA_OpenConfigurationUI();
		return;	
	end


	--	Command: master
	--	Syntax: "master"	
	if cmd == "master" then
		SOTA_RequestMaster(false);
		return;	
	end


	--	Command: version
	--	Syntax: "version"
	if cmd == "version" then
		if SOTA_IsInRaid(true) then
			addonEcho("TX_VERSION##");
		else
			localEcho(string.format("%s is using SOTA version %s", UnitName("player"), GetAddOnMetadata("SOTA", "Version")));
		end
		return;
	end
	
	
	--	Command: log
	--	Syntax: "log"
	if cmd == "log" then
		if arg and tonumber(arg) then
			SOTA_selectedTransactionID = arg;
			SOTA_RefreshTransactionDetails();
			SOTA_OpenTransactionDetails();
		else	
			SOTA_OpenTransauctionUI();
		end
		return;
	end

	--	Command: clearhistory
	--	Syntax: "clear", "clearhistory"
	if (cmd == "clear") or (cmd == "clearhistory") then
		return SOTA_ClearLocalHistory(arg);
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

	-- Command: listqueue
	--	Syntax: "listqueue"
	if cmd == "listqueue" then
		return SOTA_Call_ListQueue(playername);
	end

	
	--	Command: addqueue
	--	Syntax: "addqueue"
	if cmd == "addqueue" then
		if SOTA_IsPromoted() then
			if not SOTA_Master then
				SOTA_RequestMaster();
			end
			return SOTA_AddToRaidQueueByName(arg);
		else
			localEcho("You must be promoted for adding people to the raid queue.");
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

	--	Command: pass
	--	Syntax: "pass"
	if cmd == "pass" then
		return SOTA_HandlePlayerPass(playername);
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
			localEcho("DKP must be written as +999 or -999");
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
				localEcho("Boss DKP value could not be calculated - DKP was not shared.");
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
				localEcho("Boss DKP value could not be calculated - DKP was not shared.");
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


	--	Command: decaytest
	--	Syntax: "decaytest <%d>[%]"
	if cmd == "decaytest" then
		return SOTA_Call_Decaytest(arg);		
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
	
	localEcho("Unknown command: ".. msg);
end


function SOTA_DisplayHelp()
	localEcho(string.format("SOTA version %s options:", GetAddOnMetadata("SOTA", "Version")));
	localEcho("Syntax: /sota [option], where options are:");
	--	DKP request options:
	localEcho("DKP Requests:");
	echo("  DKP <p>    Show how much DKP the player <p> currently have. Default is current player.");
	echo("  Class <c>    Show top 10 DKP for the class <c>. Default is the current player's class.");
	echo("");
	--	Player DKP:
	localEcho("Player DKP:");
	echo("  +<dkp> <p>    Add <dkp> to the player <p>.");
	echo("  -<dkp> <p>    Subtract <dkp> from the player <p>.");
	echo("  -<pct>% <p>   Subtract <pct> % DKP from the player <p>. A minimum subtracted amount can be configured in the DKP options.");
	echo("");
	--	Raid DKP:
	localEcho("Raid DKP:");
	echo("  raid +<dkp>    Add <dkp> to all players in raid and in raid queue.");
	echo("  raid -<dkp>    Subtract <dkp> from all players in raid and in raid queue.");
	echo("  range +<dkp>    Add <dkp> to all players in 100 yards range.");
	echo("  share +<dkp>    Share <dkp> to all players in raid and in raid queue. Every player gets (<dkp> / <number of players in raid>) DKP.");
	echo("  decay <pct>%    Remove <pct> percent DKP from every player in the guild.");
	echo("");
	--	Queue options:
	localEcho("Raid Queue:");
	echo("  queue    Get current queue status (number of people in queue)");
	echo("  addqueue <p> <r>    Manually add the player <p> to the raid queue with role <r>.");
	echo("");
	--	Misc:
	localEcho("Miscellaneous:");
	echo("  Config    Open the SotA configuration screen.");
	echo("  Log    Open the SotA transaction log screen.");
	echo("  Master    Request SotA master status.");
	echo("  <item>    Start an auction for <item>.");
	echo("  Version    Display the SotA client version.");
	echo("  Help    (default) This help!");
	echo("");
	--	Chat options (Guild chat and Raid chat):
	localEcho("Guild/Raid chat commands:");
	echo("  !queue    Get current queue status (number of people in queue)");
	echo("  !queue <r>    Queue as role <r>; <r> can be tank, melee, ranged or healer");
	echo("  !leave    Leave the raid queue.");
	echo("  !listqueue    Returns a list of people who are currently in queue.");
	echo("  !bid <dkp>    Bid <dkp> for item currently being on auction.");
	echo("  !bid min    Bid the minimum bid on item currently being on auction.");
	echo("  !bid max    Bid everything (go all out) on item currently being on auction");	
	echo("  !Pass    Cancel a bid. Only allowed if the cancelled bid is the current active bid.");	
	return false;
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
--	Timer Functions
--
	SOTA_TimerTick = 0;
local GuildRefreshTimer = 0;
local EventTime = 0;
local SecondTimer = 0;
local Secounds = 0;

--	Timer job: { method, duration }
local SOTA_GeneralTimers = { }

function SOTA_setSecondCounter(seconds)
	Seconds = seconds;
end;

function SOTA_AddTimer( method, duration )
	SOTA_GeneralTimers[table.getn(SOTA_GeneralTimers) + 1] = { method, SOTA_TimerTick + duration }
end

function SOTA_OnTimer(elapsed)
	SOTA_TimerTick = SOTA_TimerTick + elapsed

	if floor(EventTime) < floor(SOTA_TimerTick) then
		SOTA_CheckAuctionState();
		SOTA_CheckOfflineStatus();
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




--
--	Job Control
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
		localEcho("You are already SOTA Master.");
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
			localEcho("You must be promoted before you can be a SOTA Master!");
		end
		return;
	end

	addonEcho("TX_SETMASTER#"..playername.."#");

	if not silentmode then
		if not CLIENT_STATE == CLIENT_STATE_MASTER then
			localEcho("You are now SOTA Master.");
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
			localEcho("You do not have access to change notes!");
		end
		return false;
	end

	if not SOTA_IsPromoted() then
		if not silentmode then
			localEcho("You are not promoted!");
		end
		return false;
	end

	return true;
end




--[[
--	Addon communication
--]]

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
	a raid to make sure SOTA_transactionLog is always updated.
]]
function SOTA_Synchronize()
	--	This initiates step 1: send a TX_SYNCINIT to all clients.
	
	synchronizationState = 1	-- Step 1: Initialize
	
	addonEcho("TX_SYNCINIT##");
	
	SOTA_AddTimer(SOTA_HandleRXSyncInitDone, 3);
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
	localEcho(string.format("%s is using %s version %s", sender, SOTA_TITLE, message));
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
	
	local transaction = SOTA_transactionLog[tid];
	if not transaction then
		transaction = { timestamp, tid, author, description, transstatus, { } };
	end
	
	--	List of transaction lines contained in this transaction ("name=dkp" entries)
	local transactions = transaction[6];
	transactions[table.getn(transactions) + 1] = { name, dkp }
	transaction[6] = transactions;

	SOTA_transactionLog[tid] = transaction;

	-- Make sure to update next transactionid
	if SOTA_currentTransactionID < tid then
		SOTA_currentTransactionID = tid;
	end

	SOTA_CopyTransactionToHistory(transaction);

	SOTA_RefreshLogElements();
end


--[[
--	Clients must return the highest transaction ID they own in RX_SYNCINIT
--	AND the number of records in SOTA_RaidQueue.
--]]
function SOTA_HandleTXSyncInit(message, sender)
	--	Message was from SELF, no need to return RX_SYNCINIT
	if (sender == UnitName("player")) then
		return;
	end

	syncResults = { };
	syncRQResults = { };

	-- Transaction Log:	
	addonEcho("RX_SYNCINIT#"..SOTA_currentTransactionID.."#"..sender)
	-- Raid queue: (kept in two messages for backwards compability)
	addonEcho("RX_SYNCRQINIT#".. table.getn(SOTA_RaidQueue) .."#"..sender)
	
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
		if maxTid > SOTA_currentTransactionID then
			SOTA_currentTransactionID = maxTid
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
	for n = 1, table.getn(SOTA_transactionLog), 1 do
		local rec = SOTA_transactionLog[n]
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
	for n=1, table.getn(SOTA_RaidQueue), 1 do
		local name = SOTA_RaidQueue[n][1];
		local role = SOTA_RaidQueue[n][3];
		local clss = SOTA_RaidQueue[n][4];
		
		-- TODO:
		--	OFFLINE state is not broadcasted. That is not a problem wince the
		--	receiving client will set this.
		--	However, the offline timer will be wrong for that client, since it
		--	will start from 0 (seconds).
		--	We could add the offline timer, but this will break compatibility with
		--	older (pre 1.2) SOTA clients.

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

	local transaction = SOTA_transactionLog[tid];
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
	SOTA_transactionLog[tid] = transaction;
end


--[[
--	Received a SOTA_RaidQueue sync record - merge with existing queue.
--]]
function SOTA_HandleRXSyncRaidQueue(message, sender)
	if message == "EOF" then
		synchronizationState = 0;
		return;
	end

	local _, _, name, role, clss = string.find(message, "([^/]*)/([^/]*)/([^/]*)")
	SOTA_AddToRaidQueue(name, role, true);
end

--[[
--	Send a RequestCfgSyncVersion to all clients and await response.
--	Since: 1.2.0
--]]
function SOTA_RequestUpdateConfigVersion()
--	echo("In SOTA_RequestUpdateConfigVersion");
	addonEcho("TX_CFGSYNCREQ##");
end;

--[[
--	Return current Cfg version to [sender]
--]]
function SOTA_HandleTXConfigSyncRequest(message, sender)
--	echo("In SOTA_HandleTXConfigSyncRequest");

	if not SOTA_CONFIG_VersionNumber then
		SOTA_CONFIG_VersionNumber = -1;
	end;
	if not SOTA_CONFIG_VersionDate then
		SOTA_CONFIG_VersionDate = "nil";
	end;

	addonEcho("RX_CFGSYNCREQ#"..SOTA_CONFIG_VersionNumber..","..SOTA_CONFIG_VersionDate.."#"..sender);
end;

function SOTA_HandleRXConfigSyncRequest(message, sender)
	echo("In SOTA_HandleRXConfigSyncRequest");

	local _, _, senderVersion, senderDate = string.find(message, "([^,]*),([^,]*)")

	-- TODO: Add this message to list of known versions:
	echo(string.format("Sender=%s, version=%s, date=%s", sender, senderVersion, senderDate));
end;



function SOTA_OnChatMsgAddon(event, prefix, msg, channel, sender)
	--echo(string.format("Prefix=%s, MSG=%s", prefix, msg));

	if (prefix == SOTA_MESSAGE_PREFIX) or (prefix == "GuildDKPv1") then	
		--	Split incoming message in Command, Payload (message) and Recipient
		local _, _, cmd, message, recipient = string.find(msg, "([^#]*)#([^#]*)#([^#]*)")

		if not cmd then
			return	-- cmd is mandatory, remaining parameters are optional.
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
		elseif cmd == "TX_CFGSYNCREQ" then
			SOTA_HandleTXConfigSyncRequest(message, sender)
		elseif cmd == "RX_CFGSYNCREQ" then
			SOTA_HandleRXConfigSyncRequest(message, sender)
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


--[[
--	Broadcast a transaction to other clients
--]]
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




--[[
--	Initialize all UI table elements.
--	This is a general handler for all UI frames.
--]]
function SOTA_InitializeUI()
	SOTA_AuctionUIInit();
	SOTA_RaidQueueUIInit()
	SOTA_TransactionLogUIInit();
end



--
--	Events
--
function SOTA_OnZoneChanged()
	if SOTA_IsInRaid(true) then
		local dkp = SOTA_GetBossDKPValue("WorldBosses");
		local min = SOTA_GetStartingDKP();
		if dkp > 0 then
			local zonetext = GetRealZoneText();
			if zonetext == "Azshara" then
				zonetext = zonetext .." (Azuregos)";
			elseif zonetext == "Blasted Lands" then
				zonetext = zonetext .." (Lord Kazzak)";
			elseif zonetext == "Ashenvale" then
				zonetext = zonetext .." (Emerald Dream: Taerar)";
			elseif zonetext == "Duskwood" then
				zonetext = zonetext .." (Emerald Dream: Lethon)";
			elseif zonetext == "The Hinterlands" then
				zonetext = zonetext .." (Emerald Dream: Emeriss)";
			elseif zonetext == "Feralas" then
				zonetext = zonetext .." (Emerald Dream: Ysondre)";
			else
				return;
			end
			
			localEcho(string.format("Instance: "..SOTA_COLOUR_INTRO.."%s"..SOTA_COLOUR_CHAT, zonetext));
			localEcho(string.format("Boss value: "..SOTA_COLOUR_INTRO.."%s"..SOTA_COLOUR_CHAT.." DKP", dkp*10));
			localEcho(string.format("Minimum bid: "..SOTA_COLOUR_INTRO.."%s"..SOTA_COLOUR_CHAT.." DKP", min));
		end
	end
end


--[[
--	There's a message in the Guild channel - investigate that!
--]]
function SOTA_HandleGuildChatMessage(event, message, sender)
	if not message or message == "" or not string.sub(message, 1, 1) == "!" then
		return;
	end

	-- Only respond if you are master, or no master has yet been assigned:
	if SOTA_IsMaster() or (not(SOTA_Master) and SOTA_IsPromoted()) then
		local command = string.sub(message, 2)
		debugEcho("Master: Processing GChat command: ".. command);
		SOTA_OnChatWhisper(event, command, sender);
	end
end

--[[
--	There's a message in the Raid channel - investigate that!
--]]
function SOTA_HandleRaidChatMessage(event, message, sender)
	if (not message) or (message == "") or (string.sub(message, 1, 1) ~= "!") then
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

	elseif cmd == "pass" then
		SOTA_HandlePlayerPass(sender);
		
	elseif cmd == "queue" then
		SOTA_HandleQueueRequest(sender, message);

	elseif cmd == "listqueue" then
		SOTA_Call_ListQueue(sender);
		
	elseif cmd == "leave" then		
		if SOTA_RemoveFromRaidQueue(sender) then
			local guildInfo = SOTA_GetGuildPlayerInfo(sender);
			if (guildInfo and guildInfo[5] == 1) then
				SOTA_whisper(sender, "You have left the Raid Queue.")
			end
		end
	end
end	


function SOTA_OnEvent(event, arg1, arg2, arg3, arg4, arg5)
	if (event == "ADDON_LOADED") then
		if arg1 == SOTA_TITLE then
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
	localEcho(string.format("Loot Distribution Addon version %s by %s", GetAddOnMetadata("SOTA", "Version"), GetAddOnMetadata("SOTA", "Author")));
    
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
	SOTA_InitializeUI(); 
	
	SOTA_RequestUpdateGuildRoster()
	
	SOTA_SetMasterState(SOTA_Master, CLIENT_STATE);
	
	if SOTA_IsInRaid(true) then	
		SOTA_Synchronize();
	end
	
	if not SOTA_CONFIG_VersionNumber then
		SOTA_CONFIG_VersionNumber = 1;
	end;
	if not SOTA_CONFIG_VersionDate then
		SOTA_CONFIG_VersionDate = SOTA_GetDateTimestamp();
	end;
	SOTA_CONFIG_Modified = false;

	SOTA_InitializeTextElements();
end


