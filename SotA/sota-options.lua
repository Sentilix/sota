--[[
--	SotA - State of the Art DKP Addon
--	By Mimma <VanillaGaming.org>
--
--	Unit: sota-options.lua
--	This holds the options (configuration) dialogue of SotA plus
--	underlying functionality to support changing the options.
--]]

local SOTA_MAX_MESSAGES			= 15
local ConfigurationDialogOpen	= false;



function SOTA_EchoEvent(msgKey, item, dkp, bidder, rank)
	local msgInfo = SOTA_getConfigurableMessage(msgKey, item, dkp, bidder, rank);
	publicEcho(msgInfo);			
end;


function SOTA_GetEventText(eventName)
	local messages = SOTA_GetConfigurableTextMessages();

	for n = 1, table.getn(messages), 1 do
		if(messages[n][1] == eventName) then
			return messages[n];
		end;
	end

	return nil;
end;


--[[
--	Get configurable message and fill out placeholders:
--	Parameters:
--	%i: Item, %d: DKP, %b: Bidder, %r: Rank
--	Automatic gathered:
--	%m: Min DKP, %s: SotA master
--]]
function SOTA_getConfigurableMessage(msgKey, item, dkp, bidder, rank)

	local msgInfo = SOTA_GetEventText(msgKey);

	if(not msgInfo) then
		localEcho("*** Oops, SOTA_CONFIG_Messages[".. msgKey .."] was not found");
		return nil;
	end;

	if not(item)	then item = ""; end;
	if not(dkp)		then dkp = ""; end;
	if not(bidder)	then bidder = ""; end;
	if not(rank)	then rank = ""; end;

	local msg = msgInfo[3];
	msg = string.gsub(msg, "$i", ""..item);
	msg = string.gsub(msg, "$d", ""..dkp);
	msg = string.gsub(msg, "$b", ""..bidder);
	msg = string.gsub(msg, "$r", ""..rank);
	msg = string.gsub(msg, "$m", ""..SOTA_GetMinimumBid());
	msg = string.gsub(msg, "$s", UnitName("player"));
	
	return { msgInfo[1], msgInfo[2], msg };
end;

function SOTA_SetConfigurableMessage(event, channel, message)
	--echo("Saving new message: Event: "..event..", Channel: "..channel..", Message: "..message);
	local messages = SOTA_GetConfigurableTextMessages();

	for n=1,table.getn(messages),1 do
		if(messages[n][1] == event) then
			messages[n] = { event, channel, message };
			SOTA_SetConfigurableTextMessages(messages);
			return;
		end;
	end;
end;

--[[
--	Copy the updated frame pos to frame siblings.
--	Since: 1.2.0
--]]
function SOTA_UpdateFramePos(frame)
	local framename = frame:GetName();

	if(framename ~= "FrameConfigBidding") then
		FrameConfigBidding:SetAllPoints(frame);
	end
	if(framename ~= "FrameConfigBossDkp") then
		FrameConfigBossDkp:SetAllPoints(frame);
	end
	if(framename ~= "FrameConfigMiscDkp") then
		FrameConfigMiscDkp:SetAllPoints(frame);
	end
	if(framename ~= "FrameConfigMessage") then
		FrameConfigMessage:SetAllPoints(frame);
	end
	if(framename ~= "FrameConfigBidRules") then
		FrameConfigBidRules:SetAllPoints(frame);
	end
	if(framename ~= "FrameConfigSyncCfg") then
		FrameConfigSyncCfg:SetAllPoints(frame);
	end
end;

function SOTA_OpenConfigurationUI()
	ConfigurationDialogOpen = true;
	SOTA_RefreshBossDKPValues();

	SOTA_OpenBiddingConfig();
end

function SOTA_CloseConfigurationUI()
	SOTA_CloseAllConfig();

	ConfigurationDialogOpen = false;
end

function SOTA_CloseAllConfig()
	FrameConfigBidding:Hide();
	FrameConfigBossDkp:Hide();
	FrameConfigMiscDkp:Hide();
	FrameConfigMessage:Hide();
	FrameConfigBidRules:Hide();
	FrameConfigSyncCfg:Hide();
end;

function SOTA_ToggleConfigurationUI()
	if ConfigurationDialogOpen then
		SOTA_CloseConfigurationUI();
	else
		SOTA_OpenConfigurationUI();
	end;
end;

function SOTA_OpenBiddingConfig()
	SOTA_CloseAllConfig();
	FrameConfigBidding:Show();
end

function SOTA_OpenBossDkpConfig()
	SOTA_CloseAllConfig();
	FrameConfigBossDkp:Show();
end

function SOTA_OpenMiscDkpConfig()
	SOTA_CloseAllConfig();
	FrameConfigMiscDkp:Show();
end

function SOTA_OpenMessageConfig()
	SOTA_CloseAllConfig();
	FrameConfigMessage:Show();
end

function SOTA_OpenBidRulesConfig()
	SOTA_CloseAllConfig();
	FrameConfigBidRules:Show();
end;

function SOTA_OpenSyncCfgConfig()
	SOTA_CloseAllConfig();
	FrameConfigSyncCfg:Show();
end;

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

function SOTA_RefreshBossDKPValues()
	getglobal("FrameConfigBossDkp_20Mans"):SetValue(SOTA_GetBossDKPValue("20Mans"));
	getglobal("FrameConfigBossDkp_MoltenCore"):SetValue(SOTA_GetBossDKPValue("MoltenCore"));
	getglobal("FrameConfigBossDkp_Onyxia"):SetValue(SOTA_GetBossDKPValue("Onyxia"));
	getglobal("FrameConfigBossDkp_BlackwingLair"):SetValue(SOTA_GetBossDKPValue("BlackwingLair"));
	getglobal("FrameConfigBossDkp_AQ40"):SetValue(SOTA_GetBossDKPValue("AQ40"));
	getglobal("FrameConfigBossDkp_Naxxramas"):SetValue(SOTA_GetBossDKPValue("Naxxramas"));
	getglobal("FrameConfigBossDkp_WorldBosses"):SetValue(SOTA_GetBossDKPValue("WorldBosses"));
end

function SOTA_OnOptionBossDKPChanged(object)
	local slider = object:GetName();
	local value = tonumber( getglobal(object:GetName()):GetValue() );
	local valueString = "";
	
	if slider == "FrameConfigBossDkp_20Mans" then
		SOTA_SetBossDKPValue("20Mans", value);
		valueString = string.format("20 mans (ZG, AQ20): %d DKP", value);
	elseif slider == "FrameConfigBossDkp_MoltenCore" then
		SOTA_SetBossDKPValue("Molten Core", value);
		valueString = string.format("Molten Core: %d DKP", value);
	elseif slider == "FrameConfigBossDkp_Onyxia" then
		SOTA_SetBossDKPValue("Onyxia", value);
		valueString = string.format("Onyxia: %d DKP", value);
	elseif slider == "FrameConfigBossDkp_BlackwingLair" then
		SOTA_SetBossDKPValue("BlackwingLair", value);
		valueString = string.format("Blackwing Lair: %d DKP", value);
	elseif slider == "FrameConfigBossDkp_AQ40" then
		SOTA_SetBossDKPValue("AQ40", value);
		valueString = string.format("Temple of Ahn'Qiraj: %d DKP", value);
	elseif slider == "FrameConfigBossDkp_Naxxramas" then
		SOTA_SetBossDKPValue("Naxxramas", value);
		valueString = string.format("Naxxramas: %d DKP", value);
	elseif slider == "FrameConfigBossDkp_WorldBosses" then
		SOTA_SetBossDKPValue("WorldBosses", value);
		valueString = string.format("World Bosses: %d DKP", value);
	end

	getglobal(slider.."Text"):SetText(valueString);
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
	if not SOTA_CONFIG_EnableZoneCheck then
		SOTA_CONFIG_EnableZoneCheck = 1;
	end
	if not SOTA_CONFIG_EnableOnlineCheck then
		SOTA_CONFIG_EnableOnlineCheck = 1;
	end
	if not SOTA_CONFIG_AllowPlayerPass then
		SOTA_CONFIG_AllowPlayerPass = 1;
	end;
	if not SOTA_CONFIG_DisableDashboard then
		SOTA_CONFIG_DisableDashboard = 1;
	end
	if not SOTA_CONFIG_OutputChannel then
		SOTA_CONFIG_OutputChannel = WARN_CHANNEL;
	end
	if not SOTA_HISTORY_DKP then
		SOTA_HISTORY_DKP = { };
	end

	
	getglobal("FrameConfigBiddingMSoverOSPriority"):SetChecked(SOTA_CONFIG_EnableOSBidding);
	getglobal("FrameConfigBiddingEnableZonecheck"):SetChecked(SOTA_CONFIG_EnableZoneCheck);
	getglobal("FrameConfigBiddingEnableOnlinecheck"):SetChecked(SOTA_CONFIG_EnableOnlineCheck);
	getglobal("FrameConfigBiddingAllowPlayerPass"):SetChecked(SOTA_CONFIG_AllowPlayerPass);
	getglobal("FrameConfigBiddingDisableDashboard"):SetChecked(SOTA_CONFIG_DisableDashboard);

	if SOTA_CONFIG_UseGuildNotes == 1 then
		getglobal("FrameConfigMiscDkpPublicNotes"):SetChecked(1)
	end

	getglobal("FrameConfigMiscDkpMinBidStrategy".. SOTA_CONFIG_MinimumBidStrategy):SetChecked(1)
	getglobal("FrameConfigMiscDkpDKPStringLength"):SetValue(SOTA_CONFIG_DKPStringLength);
	getglobal("FrameConfigMiscDkpMinimumDKPPenalty"):SetValue(SOTA_CONFIG_MinimumDKPPenalty);
	getglobal("FrameConfigBiddingAuctionTime"):SetValue(SOTA_CONFIG_AuctionTime);
	getglobal("FrameConfigBiddingAuctionExtension"):SetValue(SOTA_CONFIG_AuctionExtension);
	
	SOTA_RefreshBossDKPValues();

	SOTA_VerifyEventMessages();
end


function SOTA_VerifyEventMessages()

	-- Syntax: [index] = { EVENT_NAME, CHANNEL, TEXT }
	-- Channel value: 0: Off, 1: RW, 2: Raid, 3: Guild, 4: Yell, 5: Say
	local defaultMessages = { 
		{ SOTA_MSG_OnOpen			, 1, "Auction open for $i" },
		{ SOTA_MSG_OnAnnounceBid	, 2, "/w $s bid <your bid>" },
		{ SOTA_MSG_OnAnnounceMinBid	, 2, "Minimum bid: $m DKP" },
		{ SOTA_MSG_On10SecondsLeft	, 2, "10 seconds left for $i" },
		{ SOTA_MSG_On9SecondsLeft	, 2, "9 seconds left" },
		{ SOTA_MSG_On8SecondsLeft	, 0, "8 seconds left" },
		{ SOTA_MSG_On7SecondsLeft	, 0, "7 seconds left" },
		{ SOTA_MSG_On6SecondsLeft	, 0, "6 seconds left" },
		{ SOTA_MSG_On5SecondsLeft	, 0, "5 seconds left" },
		{ SOTA_MSG_On4SecondsLeft	, 0, "4 seconds left" },
		{ SOTA_MSG_On3SecondsLeft	, 2, "3 seconds left" },
		{ SOTA_MSG_On2SecondsLeft	, 2, "2 seconds left" },
		{ SOTA_MSG_On1SecondLeft	, 2, "1 second left" },
		{ SOTA_MSG_OnMainspecBid	, 1, "$b ($r) is bidding $d DKP for $i" },
		{ SOTA_MSG_OnOffspecBid		, 1, "$b is bidding $d Off-spec for $i" },
		{ SOTA_MSG_OnMainspecMaxBid	, 1, "$b ($r) went all in ($d DKP) for $i" },
		{ SOTA_MSG_OnOffspecMaxBid	, 1, "$b went all in ($d) Off-spec for $i" },
		{ SOTA_MSG_OnComplete		, 2, "$i sold to $b for $d DKP." },
		{ SOTA_MSG_OnPause			, 2, "Auction has been Paused" },
		{ SOTA_MSG_OnResume			, 2, "Auction has been Resumed" },
		{ SOTA_MSG_OnClose			, 1, "Auction for $i is over" },
		{ SOTA_MSG_OnCancel			, 1, "Auction was Cancelled" }
	}

	-- Merge default messages into saved messages; in case we added some new event names.
	local messages = SOTA_GetConfigurableTextMessages();
	if not messages then
		messages = { }
	end;

	for n=1,table.getn(defaultMessages), 1 do
		local foundMessage = false;
		for f=1,table.getn(messages), 1 do
			if(messages[f][1] == defaultMessages[n][1]) then
				foundMessage = true;
				echo("Found!");
				break;
			end;
		end;

		if(not foundMessage) then
			echo("Adding message: ".. defaultMessages[n][1]);
			messages[table.getn(messages)+1] = defaultMessages[n];
		end;
	end

	SOTA_SetConfigurableTextMessages(messages);


end;

function SOTA_HandleCheckbox(checkbox)
	local checkboxname = checkbox:GetName();

	--	Enable MS>OS priority:		
	if checkboxname == "FrameConfigBiddingMSoverOSPriority" then
		if checkbox:GetChecked() then
			SOTA_CONFIG_EnableOSBidding = 1;
		else
			SOTA_CONFIG_EnableOSBidding = 0;
		end
		return;
	end
		
	--	Enable RQ Zonecheck:		
	if checkboxname == "FrameConfigBiddingEnableZonecheck" then
		if checkbox:GetChecked() then
			SOTA_CONFIG_EnableZoneCheck = 1;
		else
			SOTA_CONFIG_EnableZoneCheck = 0;
		end
		return;
	end

	--	Enable RQ Onlinecheck:		
	if checkboxname == "FrameConfigBiddingEnableOnlinecheck" then
		if checkbox:GetChecked() then
			SOTA_CONFIG_EnableOnlineCheck = 1;
		else
			SOTA_CONFIG_EnableOnlineCheck = 0;
		end
		return;
	end

	--	Allow Player Pass:
	if checkboxname == "FrameConfigBiddingAllowPlayerPass" then
		if checkbox:GetChecked() then
			SOTA_CONFIG_AllowPlayerPass = 1;
		else
			SOTA_CONFIG_AllowPlayerPass = 0;
		end
		return;
	end

	--	Disable Dashboard:		
	if checkboxname == "FrameConfigBiddingDisableDashboard" then
		if checkbox:GetChecked() then
			SOTA_CONFIG_DisableDashboard = 1;
			SOTA_CloseDashboard();
		else
			SOTA_CONFIG_DisableDashboard = 0;
		end
		return;
	end

	
	--	Store DKP in Public Notes:		
	if checkboxname == "FrameConfigMiscDkpPublicNotes" then
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
		if checkboxname == "FrameConfigMiscDkpMinBidStrategy0" then
			getglobal("FrameConfigMiscDkpMinBidStrategy1"):SetChecked(0);
			getglobal("FrameConfigMiscDkpMinBidStrategy2"):SetChecked(0);
			getglobal("FrameConfigMiscDkpMinBidStrategy3"):SetChecked(0);
			getglobal("FrameConfigMiscDkpMinBidStrategy4"):SetChecked(0);
			SOTA_CONFIG_MinimumBidStrategy = 0;
		elseif checkboxname == "FrameConfigBossDkpMinBidStrategy1" then
			getglobal("FrameConfigMiscDkpMinBidStrategy0"):SetChecked(0);
			getglobal("FrameConfigMiscDkpMinBidStrategy2"):SetChecked(0);
			getglobal("FrameConfigMiscDkpMinBidStrategy3"):SetChecked(0);
			getglobal("FrameConfigMiscDkpMinBidStrategy4"):SetChecked(0);
			SOTA_CONFIG_MinimumBidStrategy = 1;
		elseif checkboxname == "FrameConfigMiscDkpMinBidStrategy2" then
			getglobal("FrameConfigMiscDkpMinBidStrategy0"):SetChecked(0);
			getglobal("FrameConfigMiscDkpMinBidStrategy1"):SetChecked(0);
			getglobal("FrameConfigMiscDkpMinBidStrategy3"):SetChecked(0);
			getglobal("FrameConfigMiscDkpMinBidStrategy4"):SetChecked(0);
			SOTA_CONFIG_MinimumBidStrategy = 2;
		elseif checkboxname == "FrameConfigMiscDkpMinBidStrategy3" then
			getglobal("FrameConfigMiscDkpMinBidStrategy0"):SetChecked(0);
			getglobal("FrameConfigMiscDkpMinBidStrategy1"):SetChecked(0);
			getglobal("FrameConfigMiscDkpMinBidStrategy2"):SetChecked(0);
			getglobal("FrameConfigMiscDkpMinBidStrategy4"):SetChecked(0);
			SOTA_CONFIG_MinimumBidStrategy = 3;			
		elseif checkboxname == "FrameConfigMiscDkpMinBidStrategy4" then
			getglobal("FrameConfigMiscDkpMinBidStrategy0"):SetChecked(0);
			getglobal("FrameConfigMiscDkpMinBidStrategy1"):SetChecked(0);
			getglobal("FrameConfigMiscDkpMinBidStrategy2"):SetChecked(0);
			getglobal("FrameConfigMiscDkpMinBidStrategy3"):SetChecked(0);
			SOTA_CONFIG_MinimumBidStrategy = 4;
		end
	end
end


local currentEvent;
function SOTA_OnEventMessageClick(object)	
	local event = getglobal(object:GetName().."Event"):GetText();
	local channel = 1*getglobal(object:GetName().."Channel"):GetText();
	local message = getglobal(object:GetName().."Message"):GetText();

	currentEvent = event;

	if not message then
		message = "";
	end

--	echo("** Event: "..event..", Channel: "..channel..", Message: "..message);

	local frame = getglobal("FrameEventEditor");
	getglobal(frame:GetName().."Message"):SetText(message);

	getglobal(frame:GetName().."CheckbuttonRW"):SetChecked(0);		
	getglobal(frame:GetName().."CheckbuttonRaid"):SetChecked(0);		
	getglobal(frame:GetName().."CheckbuttonGuild"):SetChecked(0);		
	getglobal(frame:GetName().."CheckbuttonYell"):SetChecked(0);		
	getglobal(frame:GetName().."CheckbuttonSay"):SetChecked(0);		

	if channel == 1 then
		getglobal(frame:GetName().."CheckbuttonRW"):SetChecked(1);		
	elseif channel == 2 then
		getglobal(frame:GetName().."CheckbuttonRaid"):SetChecked(1);		
	elseif channel == 3 then
		getglobal(frame:GetName().."CheckbuttonGuild"):SetChecked(1);		
	elseif channel == 4 then
		getglobal(frame:GetName().."CheckbuttonYell"):SetChecked(1);		
	elseif channel == 5 then
		getglobal(frame:GetName().."CheckbuttonSay"):SetChecked(1);		
	end
	-- Yes, channel can be disabled (0) = nothing is written.
	
	FrameEventEditor:Show();
	FrameEventEditorMessage:SetFocus();
end

function SOTA_OnEventCheckboxClick(checkbox)
	local checkboxname = checkbox:GetName();
	local frame = getglobal("FrameEventEditor");

	if checkboxname == "FrameEventEditorCheckbuttonRW" then
		if checkbox:GetChecked() then
			getglobal(frame:GetName().."CheckbuttonRaid"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonGuild"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonYell"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonSay"):SetChecked(0);		
		end;
	elseif checkboxname == "FrameEventEditorCheckbuttonRaid" then
		if checkbox:GetChecked() then
			getglobal(frame:GetName().."CheckbuttonRW"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonGuild"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonYell"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonSay"):SetChecked(0);		
		end;
	elseif checkboxname == "FrameEventEditorCheckbuttonGuild" then
		if checkbox:GetChecked() then
			getglobal(frame:GetName().."CheckbuttonRW"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonRaid"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonYell"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonSay"):SetChecked(0);		
		end;
	elseif checkboxname == "FrameEventEditorCheckbuttonYell" then
		if checkbox:GetChecked() then
			getglobal(frame:GetName().."CheckbuttonRW"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonRaid"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonGuild"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonSay"):SetChecked(0);		
		end;
	elseif checkboxname == "FrameEventEditorCheckbuttonSay" then
		if checkbox:GetChecked() then
			getglobal(frame:GetName().."CheckbuttonRW"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonRaid"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonGuild"):SetChecked(0);		
			getglobal(frame:GetName().."CheckbuttonYell"):SetChecked(0);		
		end;
	end;
end;

function SOTA_OnEventEditorSave()
	local event = currentEvent;
	local message = FrameEventEditorMessage:GetText();
	local channel = 0;

	local frame = getglobal("FrameEventEditor");
	
	if getglobal(frame:GetName().."CheckbuttonRW"):GetChecked() then
		channel = 1
	elseif getglobal(frame:GetName().."CheckbuttonRaid"):GetChecked() then
		channel = 2
	elseif getglobal(frame:GetName().."CheckbuttonGuild"):GetChecked() then
		channel = 3
	elseif getglobal(frame:GetName().."CheckbuttonYell"):GetChecked() then
		channel = 4
	elseif getglobal(frame:GetName().."CheckbuttonSay"):GetChecked() then
		channel = 5
	end;

	SOTA_SetConfigurableMessage(event, channel, message);

	SOTA_UpdateTextList();

	FrameEventEditor:Hide();
end;

function SOTA_OnEventEditorClose()
	FrameEventEditor:Hide();
end;

function SOTA_RefreshVisibleTextList(offset)
	--echo(string.format("Offset=%d", offset));
	local messages = SOTA_GetConfigurableTextMessages();
	local msgInfo;

	for n=1, SOTA_MAX_MESSAGES, 1 do
		msgInfo = messages[n + offset]
		if not msgInfo then
			msgInfo = { "", 0, "" }
		end
		
		local event = msgInfo[1];
		local channel = msgInfo[2];
		local message = msgInfo[3];
		
		--echo(string.format("-> Event=%s, Channel=%d, Text=%s", event, 1*channel, message));
		
		local frame = getglobal("FrameConfigMessageTableListEntry"..n);
		if(not frame) then
			echo("*** Oops, frame is nil");
			return;
		end;

		getglobal(frame:GetName().."Event"):SetText(event);
		getglobal(frame:GetName().."Channel"):SetText(channel);
		getglobal(frame:GetName().."Message"):SetText(message);
		
		frame:Show();
	end
end

function SOTA_UpdateTextList(frame)
	FauxScrollFrame_Update(FrameConfigMessageTableList, SOTA_MAX_MESSAGES, 10, 20);
	local offset = FauxScrollFrame_GetOffset(FrameConfigMessageTableList);
	
	SOTA_RefreshVisibleTextList(offset);
end

function SOTA_InitializeTextElements()
	local entry = CreateFrame("Button", "$parentEntry1", FrameConfigMessageTableList, "SOTA_TextTemplate");
	entry:SetID(1);
	entry:SetPoint("TOPLEFT", 4, -4);
	for n=2, SOTA_MAX_MESSAGES, 1 do
		local entry = CreateFrame("Button", "$parentEntry"..n, FrameConfigMessageTableList, "SOTA_TextTemplate");
		entry:SetID(n);
		entry:SetPoint("TOP", "$parentEntry"..(n-1), "BOTTOM");
	end
end



--[[
--	RULE ENGINE SECTION
--]]



--[[
Each rule is set up as a statement which can yield TRUE or FALSE.
If a statement yields TRUE, it will perform one of the following:
* Exit with success (the person can bid)
* Exit with error (custom text is returned).
This means that a rule must have a type: is it an INCLUSIVE (=success) rule or an EXCLUSIVE (=error) rule?

A rule is build up as:
[Result] = [Parameter] [Operator] [Parameter] [And Operator]

[Result] can be "SUCCESS" or "FAIL".
[Parameter] can be:
* "DKP" or "dkp"
* "RANK" or "rank"
When uppercase is used, parameter refers to the current highest bid.
When lowercase is used, parameter refers to the current bidder.

[Operator] can be:
* ">", ">=", "<=", "<>" and "=".
* "+", "-" is considers and likely to be added as well.
* "!" was considered, but currently not part of syntax.

[And Operator] can be:
* "&" (AND). "OR" is not supported, since this can be made as the next rule in the chain.
*	It is possible that the "AND" operator simply ties the next rule in the chain, so each rule contains
	exactly two parameters and one operator plus an optional AND operator.

Some examples:
	"SUCCESS = RANK > 3"
means if RANK is > 3 the bid is accepted, otherwise next rule in the chain will be checked.

	"ERROR = RANK <= 3"
means if RANK <= 3 the bid is rejected with a customized error message.


Sample setup:

// FAIL if 
[0]	"FAIL = DKP >= 1000 & rank < 5 & RANK < 5 & rank < RANK" -> "You cannot bid more than 5000 DKP as a Trial against a Member+"



--]]

function SOTA_PerformSampleRuleTest()
	-- "FAIL = DKP >= 1000 & rank < 5 & RANK < 5 & rank < RANK"
	-- RANK/rank --> R/R, DKP/dkp --> D/d
	local rule = "FAIL=D>=1000&r<5&R<5&r<R";

	SOTA_ParseRule(rule);
end;


SOTA_RULETYPE_FAIL = "FAIL";
SOTA_RULETYPE_SUCCESS = "SUCCESS";

function SOTA_ParseRule(rule)
	local RuleInfo = { }

	RuleInfo["RULETYPE"]	= '';		-- Current ruletype. Possible values: 'SUCCESS' and 'FAIL'
	RuleInfo["VALID"]		= false;	-- TRUE if rule has been passed as valid (i.e. have a result)
	RuleInfo["RESULT"]		= false;	-- Rule result: TRUE (action is to be taken) or FALSE (continue)
	RuleInfo["MESSAGE"]		= '';		-- Custom message; used when FAIL returns TRUE (message to the user why he cannot bid)
	RuleInfo["ERROR"]		= '';		-- Error message; used when VALID returns FALSE.
	

	-- TODO:
	-- * Remove all spaces in the rule. Not needed if rule is auto-generated.

	--	1: Split by the "="; that way we know if this is a SUCCESS or FAIL rule:
	local _, _, ruletype, ruleoper = string.find(rule, "(%a+)=(.+)");

	if(string.upper(ruletype) == SOTA_RULETYPE_FAIL) then
		RuleInfo["RULETYPE"] = SOTA_RULETYPE_FAIL;
	elseif(string.upper(ruletype) == SOTA_RULETYPE_SUCCESS) then
		RuleInfo["RULETYPE"] = SOTA_RULETYPE_SUCCESS;
	else
		RuleInfo["ERROR"] = string.format("Unknown rule type: '%s'", ruletype);
		localEcho(RuleInfo["ERROR"]);
		return RuleInfo;
	end

	--	2: Split by the "&"; this will split the individual operations.
	local operations = SOTA_StringSplit(ruleoper, '\&');

	--	2.1: Prioritize each operation:
	--	(not needed as long we don't support "+" and "-")

	--	2.2: Validate each operation and substitute values
	local statementResult = true;
	for n=1,table.getn(operations),1 do
		local _, _, p1, operator, p2 = string.find(operations[n], "([%a%d]+)([><=]+)([%a%d]+)");
		--echo(string.format("%d: P1='%s', Oper='%s', P2='%s'", n, p1, operator, p2));

		local v1 = SOTA_SubstituteParameter(p1);
		local v2 = SOTA_SubstituteParameter(p2);
		--echo(string.format("%d: V1='%d', Oper='%s', V2='%d'", n, v1, operator, v2));

		-- Do the calculation of each statement: As long they yield TRUE, the entire statement is TRUE as well.
		statementResult = SOTA_CalculateOperation(v1, operator, v2);
		
		if not(statementResult) then
			-- FALSE cannot skip a rule, but it will skip the loop: entire statement is FALSE.
			if RuleInfo["RULETYPE"] == SOTA_RULETYPE_FAIL then
				RuleInfo["VALID"] = true;
				RuleInfo["RESULT"] = false;
				localEcho("Rule is INVALID; move to next rule");
				return RuleInfo;
			end;
		end;
	end;

	if(statementResult) then
		-- If entire statement is TRUE, then we are done!
		if RuleInfo["RULETYPE"] = SOTA_RULETYPE_FAIL then
			RuleInfo["MESSAGE"] = "(A custom message for this rule)";
		end;
		RuleInfo["VALID"] = true;
		RuleInfo["RESULT"] = true;
		localEcho(string.format("Rule is VALID; %s = %s", RuleInfo["RULETYPE"], operations[n]));
		return RuleInfo;
	end;

	-- Undefined result; we need a flag to pick next
	RuleInfo["VALID"] = false;
	RuleInfo["RESULT"] = true;
	localEcho(string.format("Rule is VALID; %s = (All passed)", RuleInfo["RULETYPE"]));
	return RuleInfo;
	
	--[[
	-- 3. Pick next rule (not part of this)
	-- 4. End with SUCCESS.
	-- If enture statement is TRUE, then we are done!
	RuleInfo["VALID"] = true;
	RuleInfo["RESULT"] = true;
	localEcho(string.format("Rule is VALID; %s = (All passed)", RuleInfo["RULETYPE"]));
	return RuleInfo;
	--]]
end;


function SOTA_CalculateOperation(param1, operator, param2)
	local statementResult;

	if(operator == ">") then
		statementResult = (param1 > param2);
	elseif(operator == ">=") then
		statementResult = (param1 >= param2);
	elseif(operator == "<=") then
		statementResult = (param1 <= param2);
	elseif(operator == "<") then
		statementResult = (param1 < param2);
	elseif(operator == "<>") then
		statementResult = (param1 ~= param2);
	elseif(operator == "=") then
		statementResult = (param1 == param2);
	else
		localEcho(string.format("Unknown operator: '%s'", operator));
		return nil;
	end;

	if(statementResult) then
		localEcho(string.format("%d %s %d = TRUE", param1, operator, param2));
	else
		localEcho(string.format("%d %s %d = FALSE", param1, operator, param2));
	end;

	return statementResult;
end;

function SOTA_SubstituteParameter(parameter)
	local value = nil;
	if(parameter == "r") then
		value = 5;
	elseif(parameter == "R") then
		value = 4;
	elseif(parameter == "d") then
		value = 1200;
	elseif(parameter == "D") then
		value = 1100;
	else
		value = tonumber(parameter);
		if value == nil then
			localEcho(string.format("Parameter '%s' is not a supported parameter.", parameter));
		end;
	end;

	return value;
end;




function SOTA_StringSplit(inputstring, separator)
	if not separator then
		separator = "%s"
	end

	local stringlist = {};
	local index = 1
	for str in string.gmatch(inputstring, "([^"..separator.."]+)") do
		stringlist[index] = str
		index = index + 1
	end

	return stringlist;
end
