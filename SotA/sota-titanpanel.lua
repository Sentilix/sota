--[[
--	SotA - State of the Art DKP Addon
--	By Mimma <VanillaGaming.org>
--
--	Unit: sota-titanpanel.lua
--	If Titan Panel is installed, this unit will hook into Titan Panel
--	and add an icon under the General menmu option, which can then be
--	enabled in the Titan Panel menu bar.
--]]


function TitanPanelSOTAButton_OnLoad()
    this.registry = {
        id = SOTA_ID,
        menuText = SOTA_TITAN_TITLE,
        buttonTextFunction = nil,
        tooltipTitle = "State of the Art [SotA] Options",
        tooltipTextFunction = "TitanPanelSOTAButton_GetTooltipText",
        frequency = 0,
	    icon = "Interface\\ICONS\\INV_Misc_Coin_02"
    };
end

function TitanPanelSOTAButton_GetTooltipText()
    return "Click to toggle option panel";
end



