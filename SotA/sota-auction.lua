--[[
--	SotA - State of the Art DKP Addon
--	By Mimma <VanillaGaming.org>
--
--	Unit: sota-auction.lua
--	The Auction UI is controlled by this unit, which includes the Bidding
--	framework, timing and overall DKP control.
--]]



--	State machine:
local STATE_NONE				= 0
local STATE_AUCTION_RUNNING		= 10
local STATE_AUCTION_PAUSED		= 20
local STATE_AUCTION_COMPLETE	= 30
local STATE_PAUSED				= 90

local RAID_STATE_DISABLED		= 0
local RAID_STATE_ENABLED		= 1

-- Max # of bids shown in the AuctionUI
local MAX_BIDS					= 10
-- List of valid bids: { Name, DKP, BidType(MS=1,OS=2), Class, RankName, RankIndex }
local IncomingBidsTable			= { };

-- Working variables:
local RaidState					= RAID_STATE_DISABLED
local AuctionedItemLink			= ""
local AuctionState				= STATE_NONE



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



--[[
--	Start the auction, and set state to STATE_STARTING
--	Parameters:
--	itemLink: a Blizzard itemlink to auction.
--	Since 0.0.1
--]]
function SOTA_StartAuction(itemLink)
	local rank = SOTA_GetRaidRank(UnitName("player"));
	if rank < 1 then
		localEcho("You need to be Raid Assistant or Raid Leader to start auctions.");
		return;
	end


	AuctionedItemLink = itemLink;
	
	--	Poor player, not only must be handle the bidding round but he is now also handling Invites!
	SOTA_RequestMaster();
	
	-- Extract ItemId from itemLink string:
	local _, _, itemId = string.find(itemLink, "item:(%d+):")
	if not itemId then
		localEcho("Item was not found: ".. itemLink);
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



--[[
--	The big SOTA state machine.
--	Since 0.0.1
--]]
function SOTA_CheckAuctionState()
	local state = SOTA_GetAuctionState();
	
	debugEcho(string.format("SOTA_CheckAuctionState called, state = %d", STATE_AUCTION_PAUSED));

	if state == STATE_NONE or state == STATE_AUCTION_PAUSED then
		return;
	end
		
	if state == STATE_AUCTION_RUNNING then
		local secs = SOTA_GetSecondCounter();
		
		if secs == SOTA_CONFIG_AuctionTime then
--			publicEcho(string.format("Auction open for %s", AuctionedItemLink));
--			publicEcho(string.format("/w %s bid <your bid>", UnitName("Player")))
--			publicEcho(string.format("Minimum bid: %d DKP", SOTA_GetMinimumBid()));

			--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_OnOpen, AuctionedItemLink, SOTA_GetMinimumBid()));
			--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_OnAnnounceBid, AuctionedItemLink, SOTA_GetMinimumBid()));
			--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_OnAnnounceMinBid, AuctionedItemLink, SOTA_GetMinimumBid()));
			SOTA_EchoEvent(SOTA_MSG_OnOpen, AuctionedItemLink, SOTA_GetMinimumBid());
			SOTA_EchoEvent(SOTA_MSG_OnAnnounceBid, AuctionedItemLink, SOTA_GetMinimumBid());
			SOTA_EchoEvent(SOTA_MSG_OnAnnounceMinBid, AuctionedItemLink, SOTA_GetMinimumBid());
		end

--[[
local SOTA_MSG_AUCTION_auctionOpened		= "AUCTION_auctionOpened";
local SOTA_MSG_AUCTION_announceBid			= "AUCTION_announceBid";
local SOTA_MSG_AUCTION_minimumBid			= "AUCTION_minimumBid";
local SOTA_MSG_AUCTION_10secondsLeft		= "AUCTION_10secondsLeft";
local SOTA_MSG_AUCTION_3secondsLeft			= "AUCTION_3secondsLeft";
local SOTA_MSG_AUCTION_2secondsLeft			= "AUCTION_2secondsLeft";
local SOTA_MSG_AUCTION_1secondLeft			= "AUCTION_1secondsLeft";
local SOTA_MSG_AUCTION_bidMainSpec			= "AUCTION_bidMainspec";
local SOTA_MSG_AUCTION_bidOffspec			= "AUCTION_bidOffspec";
local SOTA_MSG_AUCTION_bidMaxMainspec		= "AUCTION_bidMaxMainspec";
local SOTA_MSG_AUCTION_bidMaxOffspec		= "AUCTION_bidMaxOffspec";
local SOTA_MSG_AUCTION_complete				= "AUCTION_complete";
local SOTA_MSG_AUCTION_paused				= "AUCTION_paused";
local SOTA_MSG_AUCTION_resumed				= "AUCTION_resumed";
local SOTA_MSG_AUCTION_ended				= "AUCTION_ended";
local SOTA_MSG_AUCTION_cancelled			= "AUCTION_cancelled";
--]]


		if SOTA_CONFIG_AuctionTime > 0 then
			if secs == 10 then
--				publicEcho(string.format("10 seconds left for %s", AuctionedItemLink));
--				publicEcho(string.format("/w %s bid <your bid>", UnitName("Player")));
				--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_On10SecondsLeft, AuctionedItemLink));
				--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_OnAnnounceBid, AuctionedItemLink));
				SOTA_EchoEvent(SOTA_MSG_On10SecondsLeft, AuctionedItemLink);
--				SOTA_EventEcho(SOTA_MSG_OnAnnounceBid, AuctionedItemLink);
			end

			if secs == 9 then
				--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_On9SecondsLeft, AuctionedItemLink));
				SOTA_EchoEvent(SOTA_MSG_On9SecondsLeft, AuctionedItemLink);
			end
			if secs == 8 then
				--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_On8SecondsLeft, AuctionedItemLink));
				SOTA_EchoEvent(SOTA_MSG_On8SecondsLeft, AuctionedItemLink);
			end
			if secs == 7 then
				--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_On7SecondsLeft, AuctionedItemLink));
				SOTA_EchoEvent(SOTA_MSG_On7SecondsLeft, AuctionedItemLink);
			end
			if secs == 6 then
				--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_On6SecondsLeft, AuctionedItemLink));
				SOTA_EchoEvent(SOTA_MSG_On6SecondsLeft, AuctionedItemLink);
			end
			if secs == 5 then
				--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_On5SecondsLeft, AuctionedItemLink));
				SOTA_EchoEvent(SOTA_MSG_On5SecondsLeft, AuctionedItemLink);
			end
			if secs == 4 then
				--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_On4SecondsLeft, AuctionedItemLink));
				SOTA_EchoEvent(SOTA_MSG_On4SecondsLeft, AuctionedItemLink);
			end
			if secs == 3 then
				--publicEcho("3 seconds left");
				--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_On3SecondsLeft, AuctionedItemLink));
				SOTA_EchoEvent(SOTA_MSG_On3SecondsLeft, AuctionedItemLink);
			end
			if secs == 2 then
				--publicEcho("2 seconds left");
				--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_On2SecondsLeft, AuctionedItemLink));
				SOTA_EchoEvent(SOTA_MSG_On2SecondsLeft, AuctionedItemLink);
			end
			if secs == 1 then
				--publicEcho("1 second left");
				--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_On1SecondLeft, AuctionedItemLink));
				SOTA_EchoEvent(SOTA_MSG_On1SecondLeft, AuctionedItemLink);
			end
			if secs < 1 then
				-- Time is up - complete the auction:
				SOTA_FinishAuction(sender, dkp);	
			end
			
			Seconds = Seconds - 1;
		else
			-- "endless" timer: set second to 1, so we dont keep triggering Auction Open event!
			Seconds = 1;
		end;
		
	end
	
	if state == STATE_COMPLETE then
		--	 We're idle
		state = STATE_NONE;
	end

	SOTA_RefreshButtonStates();
end


--[[
--	Handle incoming bid request.
--	Syntax: /sota bid|ms|os <dkp>|min|max
--	Since 0.0.1
--]]
function SOTA_HandlePlayerBid(sender, message)
	local playerInfo = SOTA_GetGuildPlayerInfo(sender);
	if not playerInfo then
		SOTA_whisper(sender, "You need to be in the guild to do bidding!");
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
		SOTA_whisper(sender, "You cannot OS bid if an MS bid is already made.");
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
		SOTA_whisper(sender, "There is currently no auction running - bid was ignored.");
		return;
	end	

	dkp = 1 * dkp

	local userWentAllIn = false;
	local highestBid = SOTA_GetHighestBid(bidtype);

	local hiRankIndex = 0;
	local hiBid = SOTA_GetStartingDKP(bidtype);
	if highestBid then
		hiBid = highestBid[2];
		hiRankIndex = highestBid[6];
	end;



	local bidderClass = playerInfo[3];		-- Info for the player placing the bid.
	local bidderRank  = playerInfo[4];		-- This rank is by NAME
	local bidderRIdx  = playerInfo[7];		-- This rank is by NUMBER!
	
	-- Check bidding using Custom Bidding Strategy.
	-- This does currently NOT check the min. bid, but it handles player ranks.
	--[[
	if SOTA_CONFIG_MinimumBidStrategy == 5 then
		local variables = { }
		variables['bid'] = dkp;
		variables['min'] = hiBid;
		variables['bidrank'] = hiRankIndex;		--Rank for the current highest bid (idx)
		variables['currank'] = bidderRIdx;		--Rank for the player bidding (idx); Lower = better.

		local ruleInfo = SOTA_ParseRules(variables);

		if(ruleInfo['VALID']) and (ruleInfo['RESULT']) then
			if(ruleInfo['RULETYPE'] == SOTA_RULETYPE_SUCCESS) then
				-- A valid rule was found; continue with the bidding!
			else
				SOTA_whisper(sender, ruleInfo['MESSAGE']);
				return;
			end;
		end;
	end;
	--]]


	-- Check user at least did bid more than last bidder:
	if(dkp > hiBid) then
		-- He did, but he also bid less than the minimum DKP:
		if (availableDkp < dkp) then
			-- If he doesnt have enough DKP, then let him go all out:
			if(availableDkp < minimumBid) and (availableDkp > hiBid) then
				dkp = availableDkp;
				userWentAllIn = true;
			else
				SOTA_whisper(sender, string.format("You only have %d DKP - bid was ignored.", availableDkp));
				return;
			end;
		end
	end;

	if not(userWentAllIn) and (dkp < minimumBid) then
		SOTA_whisper(sender, string.format("You must bid at least %s DKP - bid was ignored.", minimumBid));
		return;
	end


	if Seconds < SOTA_CONFIG_AuctionExtension then
		Seconds = SOTA_CONFIG_AuctionExtension;
	end
	
	if userWentAllIn then
		if bidtype == 2 then
			--publicEcho(string.format("%s went all in (%d) Off-spec for %s", sender, dkp, AuctionedItemLink));
			--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_OnOffspecMaxBid, AuctionedItemLink, dkp, sender, bidderRank));
			SOTA_EchoEvent(SOTA_MSG_OnOffspecMaxBid, AuctionedItemLink, dkp, sender, bidderRank);
		else
			--publicEcho(string.format("%s (%s) went all in (%d DKP) for %s", sender, bidderRank, dkp, AuctionedItemLink));
			--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_OnMainspecMaxBid, AuctionedItemLink, dkp, sender, bidderRank));
			SOTA_EchoEvent(SOTA_MSG_OnMainspecMaxBid, AuctionedItemLink, dkp, sender, bidderRank);
		end;
	else
		if bidtype == 2 then
			--publicEcho(string.format("%s is bidding %d Off-spec for %s", sender, dkp, AuctionedItemLink));
			--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_OnOffspecBid, AuctionedItemLink, dkp, sender, bidderRank));
			SOTA_EchoEvent(SOTA_MSG_OnOffspecBid, AuctionedItemLink, dkp, sender, bidderRank);
		else
			--publicEcho(string.format("%s (%s) is bidding %d DKP for %s", sender, bidderRank, dkp, AuctionedItemLink));
			--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_OnMainspecBid, AuctionedItemLink, dkp, sender, bidderRank));
			SOTA_EchoEvent(SOTA_MSG_OnMainspecBid, AuctionedItemLink, dkp, sender, bidderRank);
		end;
	end;
	

	SOTA_RegisterBid(sender, dkp, bidtype, bidderClass, bidderRank, bidderRIdx);
	
		
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



function SOTA_RegisterBid(playername, bid, bidtype, playerclass, rankname, rankindex)
	if bidtype == 2 then
		SOTA_whisper(playername, string.format("Your Off-spec bid of %d DKP has been registered.", bid) );
	else
		SOTA_whisper(playername, string.format("Your bid of %d DKP has been registered.", bid) );
	end

	IncomingBidsTable = SOTA_RenumberTable(IncomingBidsTable);
	
	IncomingBidsTable[table.getn(IncomingBidsTable) + 1] = { playername, bid, bidtype, playerclass, rankname, rankindex };

	-- Sort by DKP, then BidType (so MS bids are before OS bids)
	SOTA_SortTableDescending(IncomingBidsTable, 2);
	if SOTA_CONFIG_EnableOSBidding == 1 then
		SOTA_SortTableAscending(IncomingBidsTable, 3);
	end
	
	--Debug output:
	--[[
	for n=1, table.getn(IncomingBidsTable), 1 do
		local cbid = IncomingBidsTable[n];
		local name = cbid[1];
		local dkp  = cbid[2];
		local type = cbid[3];
		local clss = cbid[4];
		local rank = cbid[5];
		local indx = cbid[6];
		if(indx == nil) then
			indx = -1;
		end;
		echo(string.format("%d - %s bid %d DKP, Type=%d, class=%s, rank=%s, index=%d", n, name, dkp, type, clss, rank, indx));
	end
	--]]
 
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


function SOTA_AcceptBid(playername, bid)
	if playername and bid then
		playername = SOTA_UCFirst(playername);
		bid = 1 * bid;
	
		AuctionUIFrame:Hide();
		
		--publicEcho(string.format("%s sold to %s for %d DKP.", AuctionedItemLink, playername, bid));
		--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_OnComplete, AuctionedItemLink, bid, playername));
		SOTA_EchoEvent(SOTA_MSG_OnComplete, AuctionedItemLink, bid, playername);
		
		SOTA_SubtractPlayerDKP(playername, bid);		
	end
end


--[[
--	Pass a player's bid.
--	Passing is a configurable option via SOTA_CONFIG_AllowPlayerPass:
--		0: No passing allowed
--		1: Only pass latest bid
--	Added in 1.1.0
--]]
function SOTA_HandlePlayerPass(playername)
	if (SOTA_CONFIG_AllowPlayerPass == 0) then
		SOTA_whisper(playername, "Sorry, but you cannot pass once you've made a bid!");
		return;
	end;

	if not(AuctionState == STATE_AUCTION_RUNNING) then
		SOTA_whisper(playername, "There is currently no auction running - pass was ignored.");
		return;
	end;


	IncomingBidsTable = SOTA_RenumberTable(IncomingBidsTable);
	local size = table.getn(IncomingBidsTable);

	if (size == 0) then
		SOTA_whisper(playername, "There are no bids for this action to pass.");
		return;
	end;

	local lastbid = IncomingBidsTable[1];
	if not(playername == lastbid[1]) then
		SOTA_whisper(playername, "You can only pass if you have the latest bid!");
		return;
	end;

	if (size > 1) then
		local nextbid = IncomingBidsTable[2];
		raidEcho(string.format("%s passed; highest bid is now by %s for %d DKP", playername, nextbid[1], nextbid[2]));
	else
		raidEcho(string.format("%s passed; there are currently no active bids.", playername));
	end;

	SOTA_UnregisterBid(lastbid[1], lastbid[2]);		
end;



--
--	UI functions
--
function SOTA_OpenAuctionUI()
	SOTA_ClearSelectedPlayer();
	AuctionUIFrame:Show();
end


function SOTA_AuctionUIInit()
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
end;


--[[
--	Show top <n> in bid window
--]]
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
		--publicEcho(string.format("Minimum bid: %d DKP", bid));
		--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_OnAnnounceMinBid, AuctionedItemLink));
		SOTA_EchoEvent(SOTA_MSG_OnAnnounceMinBid, AuctionedItemLink);
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
		--publicEcho("Auction has been Paused");
		--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_OnPause, AuctionedItemLink));
		SOTA_EchoEvent(SOTA_MSG_OnPause, AuctionedItemLink);
	end
	
	if state == STATE_AUCTION_PAUSED then
		SOTA_SetAuctionState(STATE_AUCTION_RUNNING, secs + SOTA_CONFIG_AuctionExtension);
		--publicEcho("Auction has been Resumed");
		--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_OnResume, AuctionedItemLink));
		SOTA_EchoEvent(SOTA_MSG_OnResume, AuctionedItemLink);
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
		--publicEcho(string.format("Auction for %s is over", AuctionedItemLink));
		--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_OnClose, AuctionedItemLink));
		SOTA_EchoEvent(SOTA_MSG_OnClose, AuctionedItemLink);

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
		--publicEcho("Auction was Cancelled");		
		--publicEcho(SOTA_getConfigurableMessage(SOTA_MSG_OnCancel, AuctionedItemLink));
		SOTA_EchoEvent(SOTA_MSG_OnCancel, AuctionedItemLink);
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


