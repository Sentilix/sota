--[[
--	SotA - State of the Art DKP Addon
--	By Mimma <VanillaGaming.org>
--
--	Unit: sota-transactionlog.lua
--	Transactions can be seen in the transaction UI. Simple DKP handling
--	in the UI is also possible, like swapping DKP for two people.
--]]



--  Transaction log: Contains a list of { timestamp, tid, author, description, state, { names, dkp } }
--	Transaction state: 0=Rolled back, 1=Active (default), 
SOTA_transactionLog				= { }

---- Max # of transaction logs shown in UI (excluding Header)
SOTA_MAX_TRANSACTIONS_DISPLAYED	= 18;

--	Current transactionID, starts out as 0 (=none).
SOTA_currentTransactionID		= 0;
SOTA_selectedTransactionID		= nil;

TRANSACTION_STATE_ROLLEDBACK	= 0;
TRANSACTION_STATE_ACTIVE		= 1;

--	# of transactions displayed in /gdlog
local TRANSACTION_LIST_SIZE		= 5;
--	# of player names displayed per line when posting transaction log into guild chat
local TRANSACTION_PLAYERS_PER_LINE	= 8;
--	Setting for transaction details screen:
local TRANSACTION_DETAILS_ROWS		= 18;
local TRANSACTION_DETAILS_COLUMNS	= 4;


local currentTransactionPage	= 1;	-- Current page shown (1=first page)
local TransactionUIOpen			= false;
local TransactionDetailsOpen	= false;
local DKPHistoryPageOpen		= false;

-- Used for alternating "colours" in DKP History view.
local ALPHA_1 = 1.0;
local ALPHA_2 = 0.7;



function SOTA_RefreshLogElements()
	if TransactionUIOpen then
		SOTA_RefreshTransactionElements();		
	elseif TransactionDetailsOpen then
		SOTA_RefreshTransactionDetails();	
	elseif DKPHistoryPageOpen then
		SOTA_RefreshHistoryElements();
	end
end


function SOTA_OpenTransauctionUI()
	TransactionUIOpen = true;
	TransactionDetailsOpen = false;
	DKPHistoryPageOpen = false;
	PurgeDKPHistoryButton:Hide();

	getglobal("TransactionUIFrameTableList"):Show();
	getglobal("PrevTransactionPageButton"):Show();
	getglobal("NextTransactionPageButton"):Show();
	getglobal("TransactionUIFramePlayerList"):Hide();
	getglobal("BackToTransactionLogButton"):Hide();
	getglobal("UndoTransactionButton"):Hide();
	
	SOTA_RefreshLogElements();

	TransactionUIFrame:Show();	
end

function SOTA_CloseTransactionUI()
	TransactionUIOpen = false;
	TransactionDetailsOpen = false;
	DKPHistoryPageOpen = false;
	TransactionUIFrame:Hide();
end

function SOTA_ViewTransactionLog()
	currentTransactionPage = 1;
	TransactionUIOpen = true;
	TransactionDetailsOpen = false;
	DKPHistoryPageOpen = false;
	PurgeDKPHistoryButton:Hide();
	SOTA_RefreshLogElements();
	SOTA_UpdatePageControls();
end;

function SOTA_ViewDKPHistory()
	currentTransactionPage = 1;
	TransactionUIOpen = false;
	TransactionDetailsOpen = false;
	DKPHistoryPageOpen = true;
	PurgeDKPHistoryButton:Show();
	SOTA_RefreshLogElements();
	SOTA_UpdatePageControls();
end;

function SOTA_PurgeDKPHistory()

	StaticPopupDialogs["SOTA_POPUP_PURGE_DKPHISTORY"] = {
		text = "Are you sure you want to reset the DKP History?",
		button1 = "Yes",
		button2 = "No",
		OnAccept = function() SOTA_PurgeDKPHistoryNow(playername) end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}

	StaticPopup_Show("SOTA_POPUP_PURGE_DKPHISTORY");
end;

function SOTA_PurgeDKPHistoryNow()
	SOTA_HISTORY_DKP = {};

	SOTA_RefreshLogElements();
end;

function SOTA_OpenTransactionDetails()
	TransactionUIOpen = false;
	TransactionDetailsOpen = true;
	DKPHistoryPageOpen = false;
	--TransactionUIFrameTableList:Hide();
	--PrevTransactionPageButton:Hide();
	--NextTransactionPageButton:Hide();
	--TransactionUIFramePlayerList:Show();
	--BackToTransactionLogButton:Show();
	--UndoTransactionButton:Show();
	SOTA_UpdatePageControls();
end

function SOTA_CloseTransactionDetails()
	SOTA_OpenTransauctionUI();
end

function SOTA_RefreshTransactionElements()
	if not TransactionUIOpen then
		return;
	end

	local timestamp, tid, description, state, trInfo;
	local name, dkp, playerCount;
	
	local trLog = SOTA_CloneTable(SOTA_transactionLog);
	SOTA_SortTableDescending(trLog, 2);
	
	local numTransactions = table.getn(trLog);
	for n=0, SOTA_MAX_TRANSACTIONS_DISPLAYED, 1 do
		if n == 0 then
			timestamp = "Time";
			tid = "ID";
			description = "Command";
			trInfo = nil;
			name = "Player(s)";
			dkp = "DKP";
		else
			local index = n + ((currentTransactionPage - 1) * SOTA_MAX_TRANSACTIONS_DISPLAYED);
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

	SOTA_UpdatePageControls();
end


--[[
--	Get transactions splitted up, so each line contains one player+dkp
--	Added in 1.1.0
--]]
function SOTA_GetIndividuelDKPHistory()
	local hrLog = { };

	-- Generate array with all entries:
	local index = 1;
	for n=1, table.getn(SOTA_HISTORY_DKP), 1 do
		-- DKP is stored as { timestamp, tid, author, description, state, { names, dkp }, zone }
		local entry = SOTA_HISTORY_DKP[n];		
		for f=1, table.getn(entry[6]), 1 do
			local info = entry[6][f];
			-- Remap into { timestamp, tid, description, name, dkp, zone }
			hrLog[index] = { entry[1], entry[2], entry[4], info[1], info[2], entry[7] };
			index = index + 1;
		end;
	end

	return hrLog;
end;


--[[
--	Show last <n> History entries:
--	Added in: 1.1.0
--]]
function SOTA_RefreshHistoryElements()
	if not DKPHistoryPageOpen then
		return;
	end

	local timestamp, tid, description, name, dkp, zone;

	local hrLog = SOTA_GetIndividuelDKPHistory();
	SOTA_SortTableDescending(hrLog, 1);


	local lastTimestamp = "";
	local lastTID = 0;
	local currentAlpha = ALPHA_1;
	local numTransactions = table.getn(hrLog);
	for n=0, SOTA_MAX_TRANSACTIONS_DISPLAYED, 1 do
		if n == 0 then
			timestamp = "Time";
			tid = "ID";
			name = "Player";
			description = "Command";
			dkp = "DKP";
			zone = "";
		else
			local index = n + ((currentTransactionPage - 1) * SOTA_MAX_TRANSACTIONS_DISPLAYED);
			if numTransactions < index then
				timestamp = "";
				tid = "";
				name = "";
				description = "";
				dkp = "";
				zone = "";
			else
				local hr = hrLog[index];
				timestamp = hr[1];
				tid = hr[2];
				description = hr[3];
				name = hr[4];
				dkp = 1 * hr[5];
				zone = hr[6];
			end
		end

		if (lastTimestamp == timestamp) and (lastTID == tid) then
		else
			if currentAlpha == ALPHA_1 then
				currentAlpha = ALPHA_2;
			else
				currentAlpha = ALPHA_1;
			end;
			lastTimestamp = timestamp;
			lastTID = tid;
		end;


		local icon = "";
		if tonumber(dkp) then
			if dkp > 0 then
				icon = "Interface\\ICONS\\Spell_ChargePositive";
			elseif dkp < 0 then
				icon = "Interface\\ICONS\\Spell_ChargeNegative";
			end
		end

		local frame = getglobal("TransactionUIFrameDKPHistoryEntry"..n);
		getglobal(frame:GetName().."Time"):SetText(timestamp);
		getglobal(frame:GetName().."Icon"):SetTexture(icon);
		getglobal(frame:GetName().."Name"):SetText(name);
		getglobal(frame:GetName().."DKP"):SetText(dkp);

		if (n > 0) then
			local color = { 128, 128, 128 };
			local guildInfo = SOTA_GetGuildPlayerInfo(name);
			if guildInfo then
				color = SOTA_GetClassColorCodes(guildInfo[3]);
			end
			getglobal(frame:GetName().."Name"):SetTextColor((color[1]/255), (color[2]/255), (color[3]/255), 255);

			-- TODO: I can't change the background color (why?), so use Alpha instead. A hack, indeed ... :-(
			frame:SetAlpha(currentAlpha);
			frame:Enable();
		else
			frame:Disable();
		end

		frame:Show();
	end

	SOTA_UpdatePageControls();
end


function SOTA_UpdatePageControls()
	PrevTransactionPageButton:Disable();
	NextTransactionPageButton:Disable();
	TransactionUIFramePlayerList:Hide();
	BackToTransactionLogButton:Hide();
	UndoTransactionButton:Hide();
	TransactionUIFrameTableList:Hide();

	if DKPHistoryPageOpen then
		-- DKP History log page:
		DKPHistoryButton:Hide();
		TransactionLogButton:Show();

		-- Refresh navigation Buttons
		local hrLog = SOTA_GetIndividuelDKPHistory();
		local numTransactions = table.getn(hrLog);
		local numPages = ceil(numTransactions / SOTA_MAX_TRANSACTIONS_DISPLAYED);

		if currentTransactionPage > 1 then
			PrevTransactionPageButton:Enable();
		end
	
		if numPages > currentTransactionPage then
			NextTransactionPageButton:Enable();
		end

		TransactionUIFrameTitle:SetText("DKP History Log");
		TransactionUIFrameDKPHistory:Show();
	else
		-- Transaction log/details page:
		-- Refresh navigation Buttons
		local numTransactions = table.getn(SOTA_transactionLog);
		local numPages = ceil(numTransactions / SOTA_MAX_TRANSACTIONS_DISPLAYED);

		if currentTransactionPage > 1 then
			PrevTransactionPageButton:Enable();
		end
	
		if numPages > currentTransactionPage then
			NextTransactionPageButton:Enable();
		end

		DKPHistoryButton:Show();

		TransactionUIFrameTitle:SetText("Transaction Log");
		TransactionLogButton:Hide();
		TransactionUIFrameDKPHistory:Hide();

		if TransactionDetailsOpen then
			PrevTransactionPageButton:Hide();
			NextTransactionPageButton:Hide();
			TransactionUIFramePlayerList:Show();
			BackToTransactionLogButton:Show();
			UndoTransactionButton:Show();
		else
			TransactionUIFrameTableList:Show();
		end;

	end
end;

function SOTA_PreviousTransactionUIPage()
	if currentTransactionPage > 1 then
		currentTransactionPage = currentTransactionPage - 1;
	end
	SOTA_RefreshLogElements();
end

function SOTA_NextTransactionUIPage()
	local numTransactions;
	if DKPHistoryPageOpen then
		local hrLog = SOTA_GetIndividuelDKPHistory();
		numTransactions = table.getn(hrLog);
	else
		numTransactions = table.getn(SOTA_transactionLog);
	end;

	local numPages = ceil(numTransactions / SOTA_MAX_TRANSACTIONS_DISPLAYED);
	
	if numPages > currentTransactionPage then
		currentTransactionPage = currentTransactionPage + 1;
	end
	SOTA_RefreshLogElements();
end

function SOTA_GetNextTransactionID()
	SOTA_currentTransactionID = SOTA_currentTransactionID + 1;
	return SOTA_currentTransactionID;
end

function SOTA_RefreshTransactionDetails()
	SOTA_selectedTransactionID = 1 * SOTA_selectedTransactionID;

	local tInfo = SOTA_transactionLog[SOTA_selectedTransactionID];
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

	for n=1, table.getn(SOTA_RaidQueue), 1 do
		totalCount = totalCount + 1
		totalPlayers[totalCount] = { SOTA_RaidQueue[n][1], SOTA_RaidQueue[n][4] };
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
--	Initalize Transaction Log UI elements
--]]
function SOTA_TransactionLogUIInit()
	for n=0,SOTA_MAX_TRANSACTIONS_DISPLAYED, 1 do
		local lgEntry = CreateFrame("Button", "$parentEntry"..n, TransactionUIFrameTableList, "SOTA_LogTemplate");
		local dhEntry = CreateFrame("Button", "$parentEntry"..n, TransactionUIFrameDKPHistory, "SOTA_DKPTemplate");
		lgEntry:SetID(n);
		dhEntry:SetID(n);
		if n == 0 then
			lgEntry:SetPoint("TOPLEFT", 4, -4);
			dhEntry:SetPoint("TOPLEFT", 4, -4);
		else
			lgEntry:SetPoint("TOP", "$parentEntry"..(n-1), "BOTTOM");
			dhEntry:SetPoint("TOP", "$parentEntry"..(n-1), "BOTTOM");
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
end;


--
--	Transaction Log handling
--
function SOTA_LogIncludeExcludeTransaction(transactioncmd, name, tid, dkp)
	local author = UnitName("Player");
	local transactions = { };
	transactions[1] = { name, dkp };
	
	local tidData = { SOTA_GetTimestamp(), tid, author, transactioncmd, TRANSACTION_STATE_ACTIVE, transactions };
	
	SOTA_RefreshLogElements();

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

	SOTA_transactionLog[tid] = { SOTA_GetTimestamp(), tid, author, transactioncmd, TRANSACTION_STATE_ACTIVE, transactions };
	SOTA_RefreshLogElements();

	SOTA_BroadcastTransaction(SOTA_transactionLog[tid]);

	SOTA_CopyTransactionToHistory(SOTA_transactionLog[tid]);
end


--[[
--	Insert transaction (including Zone) into DKP history log.
--	Will merge with existing transaction (timestamp + TID) if found
--	Added in 1.1.0
--]]
function SOTA_CopyTransactionToHistory(transaction)
	local tr = SOTA_CloneTable(transaction);

	tr[1] = SOTA_GetDateTimestamp();
	tr[7] = GetRealZoneText();

	local timestamp = tr[1];
	local tid = tr[2];

	for n=1, table.getn(SOTA_HISTORY_DKP), 1 do
		local entry = SOTA_HISTORY_DKP[n];
		-- Same transaction found; replace player data with the current one:
		if (entry[1] == timestamp) and (entry[2] == tid) then
			-- However, verify the new array is larger than the old one (it should be!)
			if(table.getn(tr[6]) > table.getn(SOTA_HISTORY_DKP[n][6])) then
				SOTA_HISTORY_DKP[n][6] = tr[6];
			end;
			return;
		end;
	end;

	table.insert(SOTA_HISTORY_DKP, tr);
end;


--[[
--	Clear the local DKP history.
--	Added in 1.1.0
--]]
function SOTA_ClearLocalHistory()
	SOTA_HISTORY_DKP = { };
	localEcho("Local history was cleared.");
end;


function SOTA_RequestUndoTransaction(transactionID)
	if not SOTA_CanWriteNotes() then
		localEcho("Sorry, you do not have access to the DKP notes.");
		return;
	end;
	

	if not transactionID then
		transactionID = SOTA_selectedTransactionID
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

	local tInfo = SOTA_transactionLog[SOTA_selectedTransactionID];
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
		SOTA_transactionLog[SOTA_selectedTransactionID] = tInfo;
		
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

	for n=1, table.getn(SOTA_transactionLog), 1 do
		if (1 * SOTA_transactionLog[n][2]) == transactionID then
			return SOTA_transactionLog[n];
		end
	end
	return nil;
end


function SOTA_OnTransactionLogClick(object)
	local msgID = object:GetID();
	SOTA_selectedTransactionID = getglobal(object:GetName().."TID"):GetText();
	if not SOTA_selectedTransactionID then
		return;
	end

	if SOTA_CanWriteNotes() then
		UndoTransactionButton:Enable();
	else
		UndoTransactionButton:Disable();
	end;
	
	SOTA_RefreshTransactionDetails();
	SOTA_OpenTransactionDetails();
end

function SOTA_OnTransactionLogDetailPlayer(object)
	if SOTA_CanWriteNotes() then
		local msgID = object:GetID();
		local playername = getglobal(object:GetName().."PlayerButton"):GetText();
	
		SOTA_ToggleIncludePlayerInTransaction(playername);
	end;
end

--[[
--	Output DKP details from DKP History.
--	Added in 1.1.0
--]]
function SOTA_OnDKPHistoryClick(object)
	StaticPopupDialogs["SOTA_POPUP_TRANSACTION_DETAILS"] = {
		text = "Display information for transaction in:",
		button1 = "Raid chat",
		button2 = "Local",
		OnAccept = function() SOTA_DisplayDKPDetails(object,true)  end,
		OnCancel = function() SOTA_DisplayDKPDetails(object,false)  end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopup_Show("SOTA_POPUP_TRANSACTION_DETAILS");	
end;

function SOTA_DisplayDKPDetails(object,showInRaidChat)
	local msgID = object:GetID();
	local timestamp = getglobal(object:GetName().."Time"):GetText();
	local name = getglobal(object:GetName().."Name"):GetText();

	local entry, info, dkp;
	for n=1, table.getn(SOTA_HISTORY_DKP), 1 do
		entry = SOTA_HISTORY_DKP[n];
		if (entry[1] == timestamp) then
			for f=1, table.getn(entry[6]), 1 do
				info = entry[6][f];
				if (info[1] == name) then
					dkp = 1*info[2];
					if showInRaidChat then
						-- Show details in Raid chat:
						raidEcho("----- DKP details -----");
						raidEcho(string.format(" - Player: %s, Zone: %s", info[1], entry[7]));
						raidEcho(string.format(" - Date/time: %s, TransactionID: %d", entry[1], 1*entry[2]));
						if dkp < 0 then
							raidEcho(string.format(" - DKP subtracted: %d, Total players involved: %d", math.abs(dkp), table.getn(entry[6])));
						else
							raidEcho(string.format(" - DKP added: %d, Total players involved: %d", math.abs(dkp), table.getn(entry[6])));
						end;
						raidEcho(string.format(' - Command: "%s", DKP Officer: %s', string.lower(entry[4]), entry[3]));
					else
						--- Show details in Local chat:
						localEcho("----- DKP details -----");
						localEcho(string.format(" - Player: "..SOTA_COLOUR_INTRO.."%s"..SOTA_COLOUR_CHAT..", Zone: "..SOTA_COLOUR_INTRO.."%s"..SOTA_COLOUR_CHAT.."", info[1], entry[7]));
						localEcho(string.format(" - Date/time: "..SOTA_COLOUR_INTRO.."%s"..SOTA_COLOUR_CHAT..", TransactionID: "..SOTA_COLOUR_INTRO.."%d"..SOTA_COLOUR_CHAT.."", entry[1], 1*entry[2]));
						if dkp < 0 then
							localEcho(string.format(" - DKP subtracted: "..SOTA_COLOUR_INTRO.."%d"..SOTA_COLOUR_CHAT..", Total players involved: "..SOTA_COLOUR_INTRO.."%d"..SOTA_COLOUR_CHAT.."", math.abs(dkp), table.getn(entry[6])));
						else
							localEcho(string.format(" - DKP added: "..SOTA_COLOUR_INTRO.."%d"..SOTA_COLOUR_CHAT..", Total players involved: "..SOTA_COLOUR_INTRO.."%d"..SOTA_COLOUR_CHAT.."", math.abs(dkp), table.getn(entry[6])));
						end;
						localEcho(string.format(" - Command: "..SOTA_COLOUR_INTRO.."%s"..SOTA_COLOUR_CHAT..", DKP Officer: "..SOTA_COLOUR_INTRO.."%s"..SOTA_COLOUR_CHAT.."", entry[4], entry[3]));
					end

					return;
				end;
			end;
		end;
	end;
end;

