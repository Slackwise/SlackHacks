-- Run with Lua 5.1 from the addon root: lua tests/friends_list_tooltip.lua
local forever = false
SlackHacks = setmetatable({}, { __index = _G })
SlackHacks.Self = SlackHacks
--- Create the Friends List module without the game UI.
---@return table module
function SlackHacks:NewModule() return {} end
--- Report the simulated client flavor.
---@return boolean forever
function SlackHacks.isForever() return forever end
--- Supply stand-in atlas markup.
---@param atlas string Atlas name.
---@return string markup
function CreateAtlasMarkup(atlas) return atlas end
--- Supply the friend's account name.
---@return string name
function BNet_GetBNetAccountName() return "Friend" end

NORTH_AMERICA, KOREA, EUROPE, TAIWAN, CHINA = "America", "Korea", "Europe", "Taiwan", "China"
UNKNOWN = "Unknown"
FRIENDS_TOOLTIP_WOW_TOON_TEMPLATE = "%s, %d %s %s"
BNET_FRIEND_TOOLTIP_ZONE_AND_REALM = "%s - %s"
BNET_FRIEND_TOOLTIP_ZONE_AND_REGION = "%s - %s"
PLAYER_FACTION_GROUP, FACTION_LABELS = {}, {}
local color = { GetRGB = function() return 1, 1, 1 end }
HIGHLIGHT_FONT_COLOR, FRIENDS_BNET_NAME_COLOR = color, color
GameTooltip = { lines = {} }
--- Start a new tooltip.
function GameTooltip:SetOwner() self.lines = {} end
--- Capture the tooltip heading.
---@param text string Heading.
function GameTooltip:SetText(text) self.heading = text end
--- Capture one tooltip line.
---@param text string Line text.
function GameTooltip:AddLine(text) self.lines[#self.lines + 1] = text end
--- Finish displaying the tooltip.
function GameTooltip:Show() end

assert(loadfile("FriendsList.lua"))()
local game = { characterName = "Aster Dawn", characterLevel = 60, raceName = "Human",
  className = "Warrior", isInCurrentRegion = true, regionID = 3 }
setmetatable(game, {
  __index = function(_, key)
    if key == "realmDisplayName" then
      assert(not forever, "Forever must not read the friend's realm")
      return "Some Realm"
    end
  end,
})
local friend = { accountInfo = { gameAccountInfo = game }, inThisGame = true, status = 0, zone = "Stormwind" }
SlackHacks.FriendsList:ShowTooltip({}, friend)
assert(GameTooltip.lines[1] == "Aster Dawn, 60 Human Warrior")
assert(GameTooltip.lines[2] == "Stormwind - Some Realm")

forever = true
SlackHacks.FriendsList:ShowTooltip({}, friend)
assert(GameTooltip.lines[1] == "Aster Dawn, 60 Human Warrior")
assert(GameTooltip.lines[2] == "Stormwind")
game.isInCurrentRegion = false
SlackHacks.FriendsList:ShowTooltip({}, friend)
assert(GameTooltip.lines[2] == "Stormwind - Europe")

print("Friends List tooltip tests passed")
