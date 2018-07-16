--[[
--	SotA - State of the Art DKP Addon
--	By Mimma <VanillaGaming.org>
--
--	Unit: sota-options.lua
--	This holds the options (configuration) dialogue of SotA plus
--	underlying functionality to support changing the options.
--]]


local ConfigurationDialogOpen	= false;



function SOTA_DisplayConfigurationScreen()
	SOTA_OpenConfigurationUI();
end

function SOTA_OpenConfigurationUI()
	ConfigurationDialogOpen = true;
	SOTA_RefreshBossDKPValues();
	SOTA_OpenConfigurationFrame1()
end

function SOTA_CloseConfigurationUI()
	ConfigurationFrame:Hide();
	ConfigurationDialogOpen = false;
end

function SOTA_ToggleConfigurationUI()
	if ConfigurationDialogOpen then
		SOTA_CloseConfigurationUI();
	else
		SOTA_OpenConfigurationUI();
	end;
end;

function SOTA_CloseConfigurationElements(headline)
	-- ConfigurationFrame1:
	ConfigurationFrameOptionAuctionTime:Hide();
	ConfigurationFrameOptionAuctionExtension:Hide();
	ConfigurationFrameOptionMSoverOSPriority:Hide();
	ConfigurationFrameOptionEnableZonecheck:Hide();
	ConfigurationFrameOptionEnableOnlinecheck:Hide();
	ConfigurationFrameOptionAllowPlayerPass:Hide();
	ConfigurationFrameOptionDisableDashboard:Hide();
	ConfigurationFrameOptionChannel:Hide();
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
	ConfigurationFrameOptionMinBidStrategy4:Hide();
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
	ConfigurationFrameOptionEnableOnlinecheck:Show();
	ConfigurationFrameOptionAllowPlayerPass:Show();
	ConfigurationFrameOptionDisableDashboard:Show();
	ConfigurationFrameOptionChannel:Show();
	
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
	ConfigurationFrameOptionMinBidStrategy4:Show();
	ConfigurationFrameOptionDKPStringLength:Show();
	ConfigurationFrameOptionMinimumDKPPenalty:Show();
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

function SOTA_RefreshBossDKPValues()
	getglobal("ConfigurationFrameOption_20Mans"):SetValue(SOTA_GetBossDKPValue("20Mans"));
	getglobal("ConfigurationFrameOption_MoltenCore"):SetValue(SOTA_GetBossDKPValue("MoltenCore"));
	getglobal("ConfigurationFrameOption_Onyxia"):SetValue(SOTA_GetBossDKPValue("Onyxia"));
	getglobal("ConfigurationFrameOption_BlackwingLair"):SetValue(SOTA_GetBossDKPValue("BlackwingLair"));
	getglobal("ConfigurationFrameOption_AQ40"):SetValue(SOTA_GetBossDKPValue("AQ40"));
	getglobal("ConfigurationFrameOption_Naxxramas"):SetValue(SOTA_GetBossDKPValue("Naxxramas"));
	getglobal("ConfigurationFrameOption_WorldBosses"):SetValue(SOTA_GetBossDKPValue("WorldBosses"));
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

function SOTA_DropDown_OnLoad(object)
	local msg = object:GetName();
	local msgID = string.sub(msg, string.len(msg), string.len(msg));
	 
	UIDropDownMenu_Initialize(this, function() SOTA_InitializeDropDown(tonumber(msgID)) end );
end

function SOTA_InitChannelOptionCombobox()
	local plrEntry = CreateFrame("Frame", "$parentCombobox", ConfigurationFrameOptionChannel, "SOTA_DropdownTemplate");
	plrEntry:SetID(1);
	plrEntry:SetPoint("TOPLEFT", 128, 0);
	
	local plrFrame = getglobal("ConfigurationFrameOptionChannelCombobox");
	UIDropDownMenu_SetWidth(128, plrFrame);
	plrFrame:Show();	
	
	SOTA_RefreshDropDownBoxes();
end;

function SOTA_OnDropDownClick(info)	
	SOTA_CONFIG_OutputChannel = info.channelId;
	localEcho(string.format("Output channel changed to %s.", info.text));
	
	SOTA_RefreshDropDownBoxes();	
end;

function SOTA_InitializeDropDown(msgID)
	local dropdown, info;
	
	if ( UIDROPDOWNMENU_OPEN_MENU ) then
		dropdown = getglobal(UIDROPDOWNMENU_OPEN_MENU);
	else
		dropdown = this;
	end
	
	local playername;
	for n=1, table.getn(SOTA_CHANNELS), 1 do	-- { Channel name, Channel Identifier }	
		local info = { };
		info.msgID = msgID;
		info.text = SOTA_CHANNELS[n][1];
		info.channelId = SOTA_CHANNELS[n][2];
		info.checked = (SOTA_CONFIG_OutputChannel == SOTA_CHANNELS[n][2])
		info.func = function() SOTA_OnDropDownClick(info) end;
		UIDropDownMenu_AddButton(info);
	end
end

function SOTA_RefreshDropDownBoxes()	
	local channelName = SOTA_CHANNELS[1][1];
	
	for n=1, table.getn(SOTA_CHANNELS), 1 do
		if (SOTA_CHANNELS[n][2] == SOTA_CONFIG_OutputChannel) then
			channelName = SOTA_CHANNELS[n][1];
			break;
		end;
	end;

	local dropdown = getglobal("ConfigurationFrameOptionChannelCombobox");	
	UIDropDownMenu_SetSelectedName(dropdown, channelName);
	
	local dropdown = getglobal("ConfigurationFrameOptionChannelCaption");
	dropdown:SetText("Output channel");	
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

	
	getglobal("ConfigurationFrameOptionMSoverOSPriority"):SetChecked(SOTA_CONFIG_EnableOSBidding);
	getglobal("ConfigurationFrameOptionEnableZonecheck"):SetChecked(SOTA_CONFIG_EnableZoneCheck);
	getglobal("ConfigurationFrameOptionEnableOnlinecheck"):SetChecked(SOTA_CONFIG_EnableOnlineCheck);
	getglobal("ConfigurationFrameOptionAllowPlayerPass"):SetChecked(SOTA_CONFIG_AllowPlayerPass);
	getglobal("ConfigurationFrameOptionDisableDashboard"):SetChecked(SOTA_CONFIG_DisableDashboard);
	SOTA_RefreshDropDownBoxes();

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

function SOTA_HandleCheckbox(checkbox)
	local checkboxname = checkbox:GetName();

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
			SOTA_CONFIG_EnableZoneCheck = 1;
		else
			SOTA_CONFIG_EnableZoneCheck = 0;
		end
		return;
	end

	--	Enable RQ Onlinecheck:		
	if checkboxname == "ConfigurationFrameOptionEnableOnlinecheck" then
		if checkbox:GetChecked() then
			SOTA_CONFIG_EnableOnlineCheck = 1;
		else
			SOTA_CONFIG_EnableOnlineCheck = 0;
		end
		return;
	end

	--	Allow Player Pass:
	if checkboxname == "ConfigurationFrameOptionAllowPlayerPass" then
		if checkbox:GetChecked() then
			SOTA_CONFIG_AllowPlayerPass = 1;
		else
			SOTA_CONFIG_AllowPlayerPass = 0;
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
			getglobal("ConfigurationFrameOptionMinBidStrategy4"):SetChecked(0);
			SOTA_CONFIG_MinimumBidStrategy = 0;
		elseif checkboxname == "ConfigurationFrameOptionMinBidStrategy1" then
			getglobal("ConfigurationFrameOptionMinBidStrategy0"):SetChecked(0);
			getglobal("ConfigurationFrameOptionMinBidStrategy2"):SetChecked(0);
			getglobal("ConfigurationFrameOptionMinBidStrategy3"):SetChecked(0);
			getglobal("ConfigurationFrameOptionMinBidStrategy4"):SetChecked(0);
			SOTA_CONFIG_MinimumBidStrategy = 1;
		elseif checkboxname == "ConfigurationFrameOptionMinBidStrategy2" then
			getglobal("ConfigurationFrameOptionMinBidStrategy0"):SetChecked(0);
			getglobal("ConfigurationFrameOptionMinBidStrategy1"):SetChecked(0);
			getglobal("ConfigurationFrameOptionMinBidStrategy3"):SetChecked(0);
			getglobal("ConfigurationFrameOptionMinBidStrategy4"):SetChecked(0);
			SOTA_CONFIG_MinimumBidStrategy = 2;
		elseif checkboxname == "ConfigurationFrameOptionMinBidStrategy3" then
			getglobal("ConfigurationFrameOptionMinBidStrategy0"):SetChecked(0);
			getglobal("ConfigurationFrameOptionMinBidStrategy1"):SetChecked(0);
			getglobal("ConfigurationFrameOptionMinBidStrategy2"):SetChecked(0);
			getglobal("ConfigurationFrameOptionMinBidStrategy4"):SetChecked(0);
			SOTA_CONFIG_MinimumBidStrategy = 3;			
		elseif checkboxname == "ConfigurationFrameOptionMinBidStrategy4" then
			getglobal("ConfigurationFrameOptionMinBidStrategy0"):SetChecked(0);
			getglobal("ConfigurationFrameOptionMinBidStrategy1"):SetChecked(0);
			getglobal("ConfigurationFrameOptionMinBidStrategy2"):SetChecked(0);
			getglobal("ConfigurationFrameOptionMinBidStrategy3"):SetChecked(0);
			SOTA_CONFIG_MinimumBidStrategy = 4;
		end
	end
end

