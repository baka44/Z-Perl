-- X-Perl UnitFrames
-- Author: Zek <Boodhoof-EU>
-- License: GNU GPL v3, 29 June 2007 (see LICENSE.txt)

local conf
XPerl_RequestConfig(function(new)
	conf = new
end, "$Revision: 938 $")

local XPerl_Usage = { }

local _G = _G
local collectgarbage = collectgarbage
local floor = floor
local format = format
local pairs = pairs
local print = print
local string = string
local strsplit = strsplit
local table = table
local tinsert = tinsert
local tonumber = tonumber
local tostring = tostring

local Ambiguate = Ambiguate
local GetFriendInfo = GetFriendInfo
local GetLocale = GetLocale
local GetNumSubgroupMembers = GetNumSubgroupMembers
local GetRealmName = GetRealmName
local GetTime = GetTime
local GetWhoInfo = GetWhoInfo
local IsAddOnLoaded = IsAddOnLoaded
local IsInInstance = IsInInstance
local IsInRaid = IsInRaid
local IsShiftKeyDown = IsShiftKeyDown
local SendAddonMessage = SendAddonMessage
local UnitFactionGroup = UnitFactionGroup
local UnitInParty = UnitInParty
local UnitIsConnected = UnitIsConnected
local UnitIsFriend = UnitIsFriend
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitName = UnitName

local UNKNOWN = UNKNOWN

local mod = CreateFrame("Frame")
mod:RegisterEvent("CHAT_MSG_ADDON")
mod:RegisterEvent("GROUP_ROSTER_UPDATE")

if type(RegisterAddonMessagePrefix) == "function" then
	RegisterAddonMessagePrefix("X-Perl")
end

local function modOnEvent(self, event, ...)
	local f = mod[event]
	if (f) then
		f(mod, ...)
	end
end

mod:SetScript("OnEvent", modOnEvent)

GameTooltip:HookScript("OnTooltipSetUnit", function(self)
	local name, unitid = self:GetUnit()
	if (not unitid) then
		unitid = "mouseover"
	end
	mod:TooltipInfo(self, unitid)
end)

local function UnitFullName(unit)
	local n, s = UnitName(unit)
	if (s and s ~= "") then
		return n.."-"..s
	end
	return n
end

-- TooltipInfo
function mod:TooltipInfo(tooltip, unitid)
	if (unitid and conf and conf.tooltip.xperlInfo and UnitIsPlayer(unitid) and UnitIsFriend(unitid, "player")) then
		local xpUsage = XPerl_GetUsage(UnitFullName(unitid), unitid)
		if (xpUsage) then
			local xp = "|cFFD00000Z-Perl|r "..(xpUsage.version or XPerl_VersionNumber)

			if (xpUsage.revision) then
				local r = "r"..xpUsage.revision
				xp = format("%s |cFF%s%s", xp, r == XPerl_GetRevision() and "80FF80" or "FF8080", r)
			elseif (UnitIsUnit("player", unitid)) then
				xp = xp.." |cFF80FF80"..XPerl_GetRevision()
			end

			if (xpUsage.mods and IsShiftKeyDown()) then
				local modList = self:DecodeModuleList(xpUsage.mods)
				if (modList) then
					xp = xp.." : |c00909090"..modList
				end
			end

			GameTooltip:AddLine(xp, 1, 1, 1, 1)
			GameTooltip:Show()
		end
	end
end

-- CheckForNewerVersion
function mod:CheckForNewerVersion(ver)
	if (not string.find(string.lower(ver), "beta")) then
		if (ver > XPerl_VersionNumber) then
			if (not self.notifiedVersion or self.notifiedVersion < ver) then
				self.notifiedVersion = ver
				print(format(XPERL_USAGE_AVAILABLE, XPerl_ProductName, ver))
			end
			return true
		end
	end
end

-- ProcessXPerlMessage
function mod:ProcessXPerlMessage(sender, msg, channel)
	if string.find(sender, string.gsub(GetRealmName(), " ", "")) then
		sender = Ambiguate(sender, "none")
	end
	local myUsage = XPerl_Usage[sender]

	if (string.sub(msg, 1, 4) == "VER ") then
		if (not myUsage) then
			myUsage = { }
			XPerl_Usage[sender] = myUsage
		end

		myUsage.old = nil
		local ver = string.sub(msg, 5)

		if (ver == XPerl_VersionNumber) then
			myUsage.version = nil
		else
			myUsage.version = ver
			self:CheckForNewerVersion(ver)
		end

		if (channel ~= "WHISPER" and sender and sender ~= UnitName("player")) then
			self:SendModules("WHISPER", sender)
		end
	elseif (string.sub(msg, 1, 4) == "REV ") then
		if (myUsage) then
			local temp = string.match(string.sub(msg, 5), "(%d+)")
			if (temp) then
				myUsage.revision = tonumber(temp)
			end
		end
	elseif (string.sub(msg, 1, 7) == "MAXVER ") then
		local ver = string.sub(msg, 8)
		if (ver >= XPerl_VersionNumber) then
			self:CheckForNewerVersion(ver)
		end
	elseif (msg == "S") then
		if (channel == "WHISPER") then
			-- Version only sent, so ask for rest
			SendAddonMessage("X-Perl", "ASK", channel, sender)
		end
	elseif (msg == "ASK") then
		if (channel == "WHISPER") then
			-- Details asked for
			self:SendModules("WHISPER", sender)
		end
	elseif (string.sub(msg, 1, 4) == "MOD ") then
		if (myUsage) then
			myUsage.mods = string.sub(msg, 5)
		end
	elseif (string.sub(msg, 1, 4) == "LOC ") then
		if (myUsage) then
			local loc = string.sub(msg, 5)
			if (loc ~= GetLocale()) then
				myUsage.locale = loc
			end
		end
	elseif (string.sub(msg, 1, 3) == "GC ") then
		if (myUsage) then
			myUsage.gc = tonumber(string.sub(msg, 4))
		end
	end
end

-- GeneralTooltip
function mod:GeneralTooltip(name, anchor)
	if (name) then
		local xpUsage = XPerl_Usage[name]
		if (xpUsage) then
			local ver
			if (xpUsage.version) then
				ver = xpUsage.version
			else
				ver = XPerl_VersionNumber
			end

			GameTooltip:SetOwner(anchor, "ANCHOR_BOTTOMRIGHT")
			GameTooltip:ClearLines()

			local str
			if (xpUsage.revision) then
				local r = "r"..xpUsage.revision
				str = format("%s %s |cFF%s%s", XPerl_ProductName, ver, r == XPerl_GetRevision() and "80FF80" or "FF8080", r)
			elseif (name == UnitName("player")) then
				str = format("%s %s |cFF80FF80%s", XPerl_ProductName, ver, XPerl_GetRevision())
			else
				str = format("%s %s", XPerl_ProductName, ver)
			end

			if (xpUsage.locale) then
				GameTooltip:AddDoubleLine(str, xpUsage.locale, 1, 1, 1, 0.5, 0.5, 0.5)
			else
				GameTooltip:SetText(str, 1, 1, 1)
			end

			if (xpUsage.version and self:CheckForNewerVersion(xpUsage.version)) then
				GameTooltip:AddLine(XPERL_USAGE_NEWVERSION, 0.5, 1, 0.5)
			end

			if (xpUsage.mods) then
				local modList = self:DecodeModuleList(xpUsage.mods)
				if (modList) then
					GameTooltip:AddLine(XPERL_USAGE_MODULES..modList, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)
				end
			end

			if (xpUsage.gc and IsShiftKeyDown()) then
				GameTooltip:AddLine(format(XPERL_USAGE_MEMMAX, xpUsage.gc), 0.8, 0.2, 0.2)
			end

			GameTooltip:Show()
			return
		end
	end

	GameTooltip:Hide()
end

-- GROUP_ROSTER_UPDATE
function mod:GROUP_ROSTER_UPDATE()
	if (IsInRaid()) then
		if (not self.inRaid) then
			self.inRaid = true
			self:SendModules()
		end
	else
		self.inRaid = nil
	end
	
	if (UnitInParty("player")) then
		if (not self.inParty and not self.inRaid) then
			self.inParty = true
			self:SendModules("PARTY") -- Let other X-Perl users know which version we're running
		end
	else
		self.inParty = nil
	end
end

-- CHAT_MSG_ADDON
function mod:CHAT_MSG_ADDON(prefix, msg, channel, sender)
	if (prefix == "X-Perl") then
		self:ParseCTRA(sender, msg, channel)
	end
end

-- XPerl_ParseCTRA
function mod:ParseCTRA(sender, msg, channel)
	local arr = {strsplit("#", msg)}
	for i, subMsg in pairs(arr) do
		self:ProcessXPerlMessage(sender, subMsg, channel)
	end
end

local xpModList = {
	"ZPerl",
	"ZPerl_Player",
	"ZPerl_PlayerPet",
	"ZPerl_Target",
	"ZPerl_TargetTarget",
	"ZPerl_Party",
	"ZPerl_PartyPet",
	"ZPerl_RaidFrames",
	"ZPerl_RaidHelper",
	"ZPerl_RaidAdmin",
	"XPerl_TeamSpeak",
	"ZPerl_RaidMonitor",
	"ZPerl_RaidPets",
	"ZPerl_ArcaneBar",
	"ZPerl_PlayerBuffs",
	"XPerl_GrimReaper"
}

-- XPerl_SendModules
mod.throttle = { }
function mod:SendModules(chan, target)
	if (not chan) then
		if (IsInRaid()) then
			local inInstance, instanceType = IsInInstance()
			if (instanceType == "pvp") then
				chan = "INSTANCE_CHAT"
			else
				chan = "RAID"
			end
		elseif (UnitInParty("player")) then
			chan = "PARTY"
		end
	end

	if (chan) then
		if (chan == "PARTY" or chan == "RAID") then
			-- Cope with WoW 3.2 bug which says party members exist, when in BGs in fake raid
			local inInstance, instanceType = IsInInstance()
			if (instanceType == "arena" or instanceType == "pvp") then
				return
			end
		end

		if (chan == "WHISPER") then
			local t = self.throttle[target]
			if (t and GetTime() < t + 15) then
				return
			end
			self.throttle[target] = GetTime()
		end

		local packet = self:MakePacket(chan == "WHISPER")
		SendAddonMessage("X-Perl", packet, chan, target)
	end
end

-- MakePacket
function mod:MakePacket(response, versionOnly)
	local resp
	if (response) then
		resp = "R#S#"
	else
		resp = ""
	end

	if (versionOnly) then
		return format("%sVER %s#REV %s", resp, XPerl_VersionNumber, XPerl_GetRevision())
	else
		local modules = ""
		for k, v in pairs(xpModList) do
			local loaded
			if IsAddOnLoaded(v) then
				loaded = 1
			else
				loaded = 0
			end
			modules = modules..(tostring(loaded))
		end
		local gc = floor(collectgarbage("count"))

		local s = format("%sVER %s#REV %s#GC %d#LOC %s#MOD %s", resp, XPerl_VersionNumber, XPerl_GetRevision(), gc, GetLocale(), modules)
		if (self.notifiedVersion and self.notifiedVersion > XPerl_VersionNumber) then
			s = format("%s#MAXVER %s", s, self.notifiedVersion)
		end
		return s
	end
end

-- XPerl_DecodeModuleList
function mod:DecodeModuleList(modList)
	local ret = { }
	for k, v in pairs(xpModList) do
		if (string.sub(modList, k, k) == "1") then
			if (XPerlUsageNameList[v]) then
				tinsert(ret, XPerlUsageNameList[v])
			else
				tinsert(ret, v)
			end
		end
	end
	local tmp = table.concat(ret, ", ")
	return tmp
end

-- XPerl_GetUsage
function XPerl_GetUsage(unitName, unitID)
	local ver = XPerl_Usage[unitName]
	if (not ver) then
		if (unitID and unitName ~= UNKNOWN and (UnitIsPlayer(unitID) and UnitFactionGroup("player") == UnitFactionGroup(unitID) and UnitIsConnected(unitID))) then
			if (not mod.directQueries) then
				mod.directQueries = {}
			end
			if (not mod.directQueries[unitName]) then
				mod.directQueries[unitName] = true
				SendAddonMessage("X-Perl", mod:MakePacket(nil, true), "WHISPER", unitName)
			end
		end
	end

	return ver
end