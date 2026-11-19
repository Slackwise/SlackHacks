-- Run with Lua 5.1 from the addon root: lua tests/guildie_list_secret_members.lua

local secret = newproxy()
local memberIds = secret
local guid = "Player-1"
local settings = { showFactionIcons = true }
SlackHacks = setmetatable({ db = { profile = { infoDisplay = { guildieList = settings } } } }, { __index = _G })
SlackHacks.Self = SlackHacks
Enum = { ClubRoleIdentifier = { Owner = 1, Leader = 2, Moderator = 3 } }
C_Club = {}
C_ClassColor = {}

--- Return an empty addon module for the guild list to initialize.
---@return table module
function SlackHacks:NewModule() return {} end

--- Return the atlas name as stand-in for inline icon markup.
---@param atlas string
---@return string markup
function CreateAtlasMarkup(atlas) return atlas end

--- Return stand-in markup for rank icons.
---@return string markup
function CreateTextureMarkup() return "rank" end

--- Identify the restricted API response.
---@param value any
---@return boolean secretValue
function issecretvalue(value) return value == secret end

--- Supply the Communities club ID for the guild.
---@return number clubId
function C_Club.GetGuildClubId() return 1 end

--- Supply the current Communities member list or its restricted stand-in.
---@return table|userdata|nil members
function C_Club.GetClubMembers() return memberIds end

--- Supply the optional metadata when the Communities list is readable.
---@return table info
function C_Club.GetMemberInfo() return { guid = guid, faction = 1 } end

--- Omit class colors from the mocked client.
function C_ClassColor.GetClassColor() end

--- Report that the player is in a guild.
---@return boolean inGuild
function IsInGuild() return true end

--- Supply one legacy roster row.
---@return number count
function GetNumGuildMembers() return 1 end

--- Return the legacy roster fields for the online member.
---@return string name, string rank, number rankIndex, number level, string className, string zone, string note, string officerNote, boolean online, nil status, string classFile, nil achievementPoints, nil achievementRank, boolean isMobile, nil canSoR, nil reputation, string guid
function GetGuildRosterInfo()
  return "Guildie-Realm", "Member", 0, 80, "Mage", "Stormwind", "", "", true, nil, "MAGE", nil, nil, false, nil, nil, guid
end

--- Supply the player's faction.
---@return string faction
function UnitFactionGroup() return "Alliance" end

assert(loadfile("GuildieList.lua"))()
local list = SlackHacks.GuildieList

local entries = list:GetEntries()
assert(#entries == 1 and entries[1].name == "Guildie" and entries[1].zone == "Stormwind")

memberIds = nil
entries = list:GetEntries()
assert(#entries == 1 and entries[1].name == "Guildie")

memberIds = { 1 }
entries = list:GetEntries()
assert(#entries == 1 and entries[1].name == "Guildie questlog-questtypeicon-alliance")

print("Guildie List secret member list tests passed")
