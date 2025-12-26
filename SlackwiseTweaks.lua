local Self = LibStub("AceAddon-3.0"):NewAddon("SlackwiseTweaks", "AceConsole-3.0", "AceEvent-3.0")
Self.config = LibStub("AceConfig-3.0")
Self.frame = CreateFrame("Frame", "SlackwiseTweaks")
Self.itemBindingFrame = CreateFrame("Frame", "SlackwiseTweaks Item Bindings")
_G.SlackwiseTweaks = Self
Self.Self = Self
setmetatable(Self, {__index = _G})
setfenv(1, Self)
__fnl_global__addon_2dname, __fnl_global__addon_2dtable = ...
__fnl_global__db_2ddefaults = {global = {log = {}, isDebugging = false}, profile = {mounts = {ground = nil, ["ground-passenger"] = nil, ["ground-passenger-showoff"] = nil, ["ground-showoff"] = nil, skyriding = nil, ["skyriding-passenger"] = nil, ["skyriding-passenger-showoff"] = nil, ["skyriding-showoff"] = nil, steadyflight = nil, ["steadyflight-passenger"] = nil, ["steadyflight-passenger-showoff"] = nil, ["steadyflight-showoff"] = nil, water = nil, ["water-showoff"] = nil}}}
local function get_battletag()
  return select(2, BNGetInfo())
end
local function is_slackwise()
  return (get_battletag() == "Slackwise#1121")
end
local function is_tester()
  return is_slackwise()
end
local function is_retail()
  return (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
end
local function is_classic()
  return (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
end
local function get_game_type()
  if is_retail() then
    return "RETAIL"
  elseif is_classic() then
    return "CLASSIC"
  else
    return "UNKNOWN"
  end
end
local function is_debugging()
  if __fnl_global__is_2dinitialized() then
    return Self.db.global.isDebugging
  else
    return is_slackwise()
  end
end
COLOR_START = "|c"
COLOR_END = "|r"
local function color(color0)
  local function _3_(text)
    return (COLOR_START .. "FF" .. color0 .. text .. COLOR_END)
  end
  return _3_
end
grey = color("AAAAAA")
local function log(message, ...)
  if is_debugging() then
    print((grey(date()) .. "  " .. message))
    if __fnl_global__is_2dinitialized() then
      table.insert(Self.db.global.log, (date() .. "  " .. message))
      if arg then
        for i, v in ipairs(arg) do
          print(("Arg " .. i .. " = " .. v))
          table.insert(Self.db.global.log, ("Arg " .. i .. " = " .. v))
        end
        return nil
      else
        return nil
      end
    else
      return nil
    end
  else
    return nil
  end
end
Self.OnInitialize = function(self)
  Self.db = __fnl_global__Lib_2dstub("AceDB-3.0"):New("SlackwiseTweaksDB", __fnl_global__db_2ddefaults)
  config:RegisterOptionsTable("SlackwiseTweaks", options, "slack")
  Self.configDialog = __fnl_global__Lib_2dstub("AceConfigDialog-3.0"):AddToBlizOptions("SlackwiseTweaks")
  return nil
end
local function is_initialized()
  return not not Self.configDialog
end
return is_initialized
setfenv(1, SlackwiseTweaks)
MOUNT_IDS = {["Algarian Stormrider"] = 1792, ["Ashes of Al'ar"] = 183, ["Auspicious Arborwyrm"] = 1795, ["Celestial Steed"] = 376, ["Chaos-Forged Gryphon"] = 2304, Charger = 84, ["Grand Expedition Yak"] = 460, ["Grotto Netherwing Drake"] = 1744, ["Highland Drake"] = 1563, ["Highlord's Golden Charger"] = 885, ["Ironbound Proto-Drake"] = 306, ["Mekgineer's Chopper"] = 275, ["Renewed Proto-Drake"] = 1589, ["Sandstone Drake"] = 407, ["Sea Turtle"] = 312, ["Sky Golem"] = 522, ["Swift Razzashi Raptor"] = 110, ["Time-Lost Proto-Drake"] = 265, ["Trader's Gilded Brutosaur"] = 2265, ["Tyrael's Charger"] = 439, ["Winding Slitherdrake"] = 1588, ["X-45 Heartbreaker"] = 352}
ACTUALLY_FLYABLE_MAP_IDS = {CONTINENTS = {619}, MAPS = {627}, ZONES = {}}
NOT_ACTUALLY_FLYABLE_MAP_IDS = {CONTINENTS = {905}, MAPS = {715, 747, 1478}, ZONES = {94, 95, 97, 103, 106, 110, 122, 747, 946, 1334, 1543, 1961}}
ALCHEMIST_VALUE_OFFSET = 1000
BEST_ITEMS = {BEST_BANDAGES = {[1251] = 66, [2581] = 114, [3530] = 161, [3531] = 301, [6450] = 400, [6451] = 640, [8544] = 800, [8545] = 1104, [14529] = 1360, [14530] = 2000, [194048] = 37376, [194049] = 43560, [194050] = 50768, [224440] = 1669500, [224441] = 2504250, [224442] = 3339000, BINDING_NAME = "SLACKWISETWEAKS_BEST_BANDAGE"}, BEST_HEALING_POTIONS = {[118] = 90, [858] = 180, [929] = 360, [1710] = 585, [3928] = 900, [13446] = 1750, [191378] = 118000, [191379] = 137550, [191380] = 160300, [207021] = 228992, [207022] = 266709, [207023] = 310592, [211878] = 3530600, [211879] = 3681800, [211880] = 3839450, [212242] = 2574760, [212243] = 2685000, [212244] = 2799950, [212942] = (3530600 + ALCHEMIST_VALUE_OFFSET), [212943] = (3681800 + ALCHEMIST_VALUE_OFFSET), [212944] = (3839450 + ALCHEMIST_VALUE_OFFSET), [212948] = (2574760 + ALCHEMIST_VALUE_OFFSET), [212949] = (2685000 + ALCHEMIST_VALUE_OFFSET), [212950] = (2799950 + ALCHEMIST_VALUE_OFFSET), BINDING_NAME = "SLACKWISETWEAKS_BEST_HEALING_POTION"}, BEST_MANA_POTIONS = {[2455] = 180, [3385] = 360, [3827] = 585, [6149] = 900, [13443] = 1500, [13444] = 2250, [191384] = 20870, [191385] = 24000, [191386] = 27600, [212239] = 204159, [212240] = 234783, [212241] = 270000, [212242] = 153119, [212243] = 176087, [212244] = 202500, [212945] = (204159 + ALCHEMIST_VALUE_OFFSET), [212946] = (234783 + ALCHEMIST_VALUE_OFFSET), [212947] = (270000 + ALCHEMIST_VALUE_OFFSET), [212948] = (153119 + ALCHEMIST_VALUE_OFFSET), [212949] = (176087 + ALCHEMIST_VALUE_OFFSET), [212950] = (202500 + ALCHEMIST_VALUE_OFFSET), BINDING_NAME = "SLACKWISETWEAKS_BEST_MANA_POTION"}}
return nil
Self.OnEnable = function(self)
  __fnl_global__set_2dcVars()
  self:RegisterEvent("MERCHANT_SHOW")
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:RegisterEvent("UNIT_AURA")
  self:RegisterEvent("PLAYER_REGEN_ENABLED")
  self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
  return self:RegisterEvent("BAG_UPDATE_DELAYED")
end
Self.OnDisable = function(self)
end
Self.BAG_UPDATE_DELAYED = function(self)
  return __fnl_global__bind_2dbest_2duse_2ditems()
end
Self.PLAYER_ENTERING_WORLD = function(self, event_name, is_login, is_reload)
  __fnl_global__setup_2dekil()
  return __fnl_global__handle_2ddragonriding()
end
Self.MERCHANT_SHOW = function(self, event_name)
  __fnl_global__repair_2dall_2ditems()
  return __fnl_global__sell_2dgrey_2ditems()
end
Self.PLAYER_REGEN_ENABLED = function(self, event_name)
  __fnl_global__handle_2ddragonriding()
  return __fnl_global__run_2dafter_2dcombat_2dactions()
end
Self.PLAYER_REGEN_DISABLED = function(self, event_name)
end
Self.ACTIVE_TALENT_GROUP_CHANGED = function(self, current_spec_iD, previous_spec_iD)
  return __fnl_global__set_2dbindings()
end
Self.UNIT_AURA = function(self, event_name, unit_target, update_info)
  if (unit_target == "player") then
    return __fnl_global__handle_2ddragonriding()
  else
    return nil
  end
end
__fnl_global__after_2dcombat_2dactions = {}
local function run_after_combat(f)
  return table.insert(__fnl_global__after_2dcombat_2dactions, f)
end
local function run_after_combat_actions()
  while (#__fnl_global__after_2dcombat_2dactions > 0) do
    if not InCombatLockdown() then
      table.remove(__fnl_global__after_2dcombat_2dactions)()
    else
    end
  end
  return nil
end
local function in_vehicle()
  return __fnl_global__Unit_2dhas_2dvehicle_2duI("player")
end
local function is_ekil()
  return ((__fnl_global__get_2dbattletag() == "ekil#1612") or false)
end
local function get_class_name()
  return select(2, __fnl_global__Unit_2dclass("player"))
end
local function get_spec_name()
  local spec_index = __fnl_global__Get_2dspecialization()
  if spec_index then
    log(("specIndex = " .. (spec_index or "nil")))
    local spec_iD, spec_name = __fnl_global__Get_2dspecialization_2dinfo(spec_index)
    log(("specID = " .. (spec_iD or "nil")))
    log(("specName = " .. (spec_name or "nil")))
    if spec_name then
      local ___antifnl_rtns_1___ = {strupper(spec_name)}
      return (table.unpack or unpack)(___antifnl_rtns_1___)
    else
    end
  else
  end
  return nil
end
local function set_cVars()
  __fnl_global__Set_2dcVar("cameraDistanceMaxZoomFactor", 2.6)
  return __fnl_global__Set_2dcVar("minimapTrackingShowAll", 1)
end
local function repair_all_items()
  if __fnl_global__Can_2dmerchant_2drepair() then
    return __fnl_global__Repair_2dall_2ditems()
  else
    return nil
  end
end
local function can_collect_transmog(item_info)
  if __fnl_global__is_2dclassic() then
    return false
  else
  end
  local item_appearance_iD, source_iD = __fnl_global__C_5fTransmog_2dcollection.GetItemInfo(item_info)
  if source_iD then
    local category_iD, visual_iD, can_enchant, icon, is_collected, item_link, transmog_link, unknown1, item_sub_type_index = __fnl_global__C_5fTransmog_2dcollection.GetAppearanceSourceInfo(source_iD)
    local ___antifnl_rtn_1___ = not is_collected
    return ___antifnl_rtn_1___
  else
  end
  return false
end
ITEM_QUALITY_GREY = 0
local function sell_grey_items()
  for bag = 0, NUM_BAG_SLOTS do
    for slot = 0, C_Container.GetContainerNumSlots(bag) do
      local link = C_Container.GetContainerItemLink(bag, slot)
      if link then
        local item_name, item_link, item_quality = C_Item.GetItemInfo(link)
        if (item_quality == ITEM_QUALITY_GREY) then
          if can_collect_transmog(item_link) then
            print(("[SlackwiseTweaks] Not selling transmog-able item: " .. item_link))
          else
            C_Container.UseContainerItem(bag, slot)
          end
        else
        end
      else
      end
    end
  end
  return nil
end
local function is_spell_known(spell_name)
  local link, spell_iD = __fnl_global__Get_2dspell_2dlink(spell_name)
  if spell_iD then
    local ___antifnl_rtns_1___ = {__fnl_global__Is_2dspell_2dknown(spell_iD)}
    return (table.unpack or unpack)(___antifnl_rtns_1___)
  else
  end
  return false
end
local function get_key_by_value(target_table, target_value)
  for key, value in pairs(target_table) do
    if (value == target_value) then
      return key
    else
    end
  end
  return nil
end
local function keys(target_table)
  local collected_keys = {}
  for key, value in pairs(target_table) do
    table.insert(collected_keys, key)
  end
  return collected_keys
end
local function find_first_element(target_table, kv_predicate)
  for key, value in pairs(target_table) do
    if kv_predicate(key, value) then
      return key, value
    else
    end
  end
  return nil, nil
end
local function find_elements(target_table, kv_predicate)
  local found = {}
  for key, value in pairs(target_table) do
    if kv_predicate(key, value) then
      found[key] = value
    else
    end
  end
  return found
end
local function find_items_by_item_iDs(item_iDs)
  local found = {}
  for bag = 0, NUM_BAG_SLOTS do
    for slot = 0, C_Container.GetContainerNumSlots(bag) do
      local container_item_info = C_Container.GetContainerItemInfo(bag, slot)
      if container_item_info then
        local item_name = C_Item.GetItemInfo(container_item_info.hyperlink)
        if (item_name and __fnl_global__t_2dcontains(item_iDs, container_item_info.itemID)) then
          table.insert(found, container_item_info)
        else
        end
      else
      end
    end
  end
  return found
end
local function find_items_by_regex(regex)
  local found = {}
  for bag = 0, NUM_BAG_SLOTS do
    for slot = 0, C_Container.GetContainerNumSlots(bag) do
      local container_item_info = C_Container.GetContainerItemInfo(bag, slot)
      if container_item_info then
        local item_name = C_Item.GetItemInfo(container_item_info.hyperlink)
        if (item_name and string.match(item_name, regex)) then
          table.insert(found, container_item_info)
        else
        end
      else
      end
    end
  end
  return found
end
local function group_by(array, grouping_function)
  local grouped = {}
  for key, value in pairs(array) do
    local grouping_key, new_value = grouping_function(value)
    if grouped[value] then
      table.insert(grouped[grouping_key], new_value)
    else
      grouped[grouping_key] = {new_value}
    end
  end
  return grouped
end
local function find_largest_index(array)
  local largest_index = 0
  for key, value in pairs(array) do
    if (tonumber(key) and (key >= largest_index)) then
      largest_index = key
    else
    end
  end
  return largest_index
end
local function find_parent_map_by_type(map, ui_map_type)
  if not map then
    return nil
  else
  end
  if ((map.mapType == ui_map_type) or (map.mapType == Enum.UIMapType.Cosmic)) then
    return map
  else
  end
  return find_parent_map_by_type(C_Map.GetMapInfo(map.parentMapID), ui_map_type)
end
local function get_current_map()
  return C_Map.GetMapInfo((C_Map.GetBestMapForUnit("player") or 0))
end
local function get_current_continent()
  local map = get_current_map()
  if map then
    local ___antifnl_rtns_1___ = {find_parent_map_by_type(map, Enum.UIMapType.Continent)}
    return (table.unpack or unpack)(___antifnl_rtns_1___)
  else
  end
  return nil
end
local function get_current_zone()
  local map = get_current_map()
  if map then
    local ___antifnl_rtns_1___ = {find_parent_map_by_type(map, Enum.UIMapType.Zone)}
    return (table.unpack or unpack)(___antifnl_rtns_1___)
  else
  end
  return nil
end
local function is_actually_flyable_area()
  local continent = get_current_continent()
  local continent_iD = ((continent and continent.mapID) or 0)
  local zone = get_current_zone()
  local zone_iD = ((zone and zone.mapID) or 0)
  local map = get_current_map()
  local map_iD = ((map and map.mapID) or 0)
  local listed_flyable_continent = not not __fnl_global__t_2dcontains(ACTUALLY_FLYABLE_MAP_IDS.CONTINENTS, continent_iD)
  local listed_flyable_zone = not not __fnl_global__t_2dcontains(ACTUALLY_FLYABLE_MAP_IDS.ZONES, zone_iD)
  local listed_flyable_map = not not __fnl_global__t_2dcontains(ACTUALLY_FLYABLE_MAP_IDS.MAPS, map_iD)
  local listed_non_flyable_continent = not not __fnl_global__t_2dcontains(NOT_ACTUALLY_FLYABLE_MAP_IDS.CONTINENTS, continent_iD)
  local listed_non_flyable_zone = not not __fnl_global__t_2dcontains(NOT_ACTUALLY_FLYABLE_MAP_IDS.ZONES, zone_iD)
  local listed_non_flyable_map = not not __fnl_global__t_2dcontains(NOT_ACTUALLY_FLYABLE_MAP_IDS.MAPS, map_iD)
  if listed_flyable_map then
    return true
  else
  end
  if listed_non_flyable_map then
    return false
  else
  end
  if listed_flyable_zone then
    return true
  else
  end
  if listed_non_flyable_zone then
    return false
  else
  end
  if listed_flyable_continent then
    return true
  else
  end
  if listed_non_flyable_continent then
    return false
  else
  end
  return __fnl_global__Is_2dflyable_2darea()
end
local function print_debug_map_info()
  local map = get_current_map()
  local zone = get_current_zone()
  local continent = get_current_continent()
  local parent_map = (C_Map.GetMapInfo(map.parentMapID) or "nil")
  if __fnl_global__is_2ddebugging() then
    p = log
  else
    p = print
  end
  p("===============================")
  p((map.name .. ", " .. (parent_map.name or "nil")))
  p(("Zone: " .. zone.name .. " (" .. zone.mapID .. ")"))
  if continent then
    p(("Continent: " .. continent.name .. " (" .. continent.mapID .. ")"))
  else
  end
  p("-------------------------------------------------------")
  p(("mapID: " .. map.mapID))
  p(("parentMapID: " .. map.parentMapID))
  p(("mapType: " .. (get_key_by_value(Enum.UIMapType, map.mapType) or "nil") .. " (" .. (map.mapType or "nil") .. ")"))
  p(("Outdoor: " .. tostring(__fnl_global__Is_2doutdoors())))
  p(("Submerged: " .. tostring(__fnl_global__Is_2dsubmerged())))
  p(("Flyable: " .. tostring(__fnl_global__Is_2dflyable_2darea())))
  p(("AdvancedFlyable: " .. tostring(__fnl_global__Is_2dadvanced_2dflyable_2darea())))
  p(("ActuallyFlyable: " .. tostring(is_actually_flyable_area())))
  return p("===============================")
end
DRUID_RARE_MOBS = {"Keen-eyed Cian", "Matriarch Keevah", "Moragh the Slothful", "Mosa Umbramane", "Ristar the Rabid", "Talthonei Ashwhisper"}
local function find_druid_rare_mobs(vignette_gUID)
  if (get_class_name() ~= "DRUID") then
    return 
  else
  end
  log(("VIGNETTE ID: " .. vignette_gUID))
  local vignette_info = __fnl_global__C_5fVignette_2dinfo.GetVignetteInfo(vignette_gUID)
  if not vignette_info then
    return 
  else
  end
  local name = vignette_info.name
  log(("VIGNETTE NAME: " .. (name or "")))
  if __fnl_global__t_2dcontains(DRUID_RARE_MOBS, name) then
    return __fnl_global__found_2ddruid_2drare(name)
  else
    return nil
  end
end
__fnl_global__found_2ddruid_2drares = {}
local function found_druid_rare(name)
  local current_unix_timestamp = __fnl_global__Get_2dserver_2dtime()
  local current_hour, current_minute = __fnl_global__Get_2dgame_2dtime()
  local last_time_found = __fnl_global__found_2ddruid_2drares[name]
  if (not last_time_found or __fnl_global__is_2dtime_2dwithin(last_time_found, (5 * 60), __fnl_global__Get_2dserver_2dtime())) then
    __fnl_global__found_2ddruid_2drares[name] = {current_unix_timestamp, current_hour, current_minute}
    return nil
  else
    return nil
  end
end
local function announce_found_druid_rare(name)
  log(("Found druid rare: " .. name))
  return __fnl_global__Send_2dchat_2dmessage(name(".. spotted!"), "CHANNEL", nil, 5)
end
local function is_time_within(origin_unix_timestamp, seconds_to_be_within, current_unix_timestamp)
  return (current_unix_timestamp >= (origin_unix_timestamp + (seconds_to_be_within * 1000)))
end
return is_time_within
BINDING_HEADER_SLACKWISETWEAKS = "SlackwiseTweaks"
BINDING_NAME_SLACKWISETWEAKS_RESTART_SOUND = "Restart Sound"
BINDING_NAME_SLACKWISETWEAKS_RELOADUI = "Reload UI"
BINDING_NAME_SLACKWISETWEAKS_MOUNT = "Mount"
BINDING_NAME_SLACKWISETWEAKS_SETBINDINGS = "Load Keybindings"
BINDING_HEADER_SLACKWISETWEAKS = "SlackwiseTweaks"
BINDING_NAME_SLACKWISETWEAKS_RESTART_SOUND = "Restart Sound"
BINDING_NAME_SLACKWISETWEAKS_RELOADUI = "Reload UI"
BINDING_NAME_SLACKWISETWEAKS_MOUNT = "Mount"
BINDING_NAME_SLACKWISETWEAKS_SETBINDINGS = "Load Keybindings"
BINDING_NAME_SLACKWISETWEAKS_BEST_HEALING_POTION = "Use Best Healing Potion"
BINDING_NAME_SLACKWISETWEAKS_BEST_MANA_POTION = "Use Best Mana Potion"
BINDING_NAME_SLACKWISETWEAKS_BEST_BANDAGE = "Use Best Bandage"
BINDINGS = {}
BINDING_TYPE = {ACCOUNT_BINDINGS = 1, CHARACTER_BINDINGS = 2, DEFAULT_BINDINGS = 0}
BINDINGS_FUNCTIONS = {command = __fnl_global__Set_2dbinding, item = __fnl_global__Set_2dbinding_2ditem, macro = __fnl_global__Set_2dbinding_2dmacro, spell = __fnl_global__Set_2dbinding_2dspell}
local function set_binding(binding)
  local key, type, name = unpack(binding)
  return BINDINGS_FUNCTIONS[type](key, name)
end
local function get_binding_description(binding_name)
  return (_G[("BINDING_NAME_" .. binding_name)] or "")
end
local function unbind_unwanted_defaults()
  return __fnl_global__Set_2dbinding("SHIFT-T")
end
local function bind_best_use_items()
  if InCombatLockdown() then
    __fnl_global__run_2dafter_2dcombat(bind_best_use_items)
    return 
  else
  end
  __fnl_global__Clear_2doverride_2dbindings(Self.itemBindingFrame)
  for item_type, item_map in pairs(BEST_ITEMS) do
    log(("Binding " .. get_binding_description(item_map.BINDING_NAME) .. "..."))
    __fnl_global__bind_2dbest_2duse_2ditem(item_map)
  end
  return nil
end
local function bind_best_use_item(best_item_map)
  local container_item_infos = __fnl_global__find_2ditems_2dby_2ditem_2diDs(keys(best_item_map))
  if (__fnl_global__is_2ddebugging() and container_item_infos) then
    log((get_binding_description(best_item_map.BINDING_NAME) .. ": found items:"))
    for i, item in ipairs(container_item_infos) do
      log(("    " .. item.stackCount .. "x of " .. item.itemID .. " " .. item.hyperlink))
    end
  else
  end
  local items_by_best_strength
  local function _3_(item)
    return best_item_map[item.itemID], {item.itemID, item.stackCount}
  end
  items_by_best_strength = __fnl_global__group_2dby(container_item_infos, _3_)
  local best_items = items_by_best_strength[__fnl_global__find_2dlargest_2dindex(items_by_best_strength)]
  if best_items then
    local smallest_stack = 9999
    local best_item_iD = nil
    for i, item_stack in ipairs(best_items) do
      local item_iD, stack_count = unpack(item_stack)
      if (stack_count < smallest_stack) then
        smallest_stack = stack_count
        best_item_iD = item_iD
      else
      end
    end
    log(("Best found smallest stack itemID: " .. best_item_iD))
    if best_item_iD then
      local desired_binding_keys = {__fnl_global__Get_2dbinding_2dkey(best_item_map.BINDING_NAME)}
      if (#desired_binding_keys > 0) then
        for i, key in ipairs(desired_binding_keys) do
          log(("Binding ID " .. best_item_iD .. " " .. C_Item.GetItemNameByID(best_item_iD) .. " to " .. key))
          __fnl_global__Set_2doverride_2dbinding_2ditem(Self.itemBindingFrame, true, key, ("item:" .. best_item_iD))
        end
        return nil
      else
        return nil
      end
    else
      return nil
    end
  else
    return nil
  end
end
local function set_bindings()
  if not __fnl_global__is_2dtester() then
    print("SlackwiseTweaks Bindings: Work in progress. Cannot bind currently.")
    return 
  else
  end
  if InCombatLockdown() then
    __fnl_global__run_2dafter_2dcombat(set_bindings)
    return 
  else
  end
  __fnl_global__Load_2dbindings(BINDING_TYPE.DEFAULT_BINDINGS)
  unbind_unwanted_defaults()
  for _, binding in ipairs(BINDINGS.GLOBAL) do
    set_binding(binding)
  end
  local game = __fnl_global__get_2dgame_2dtype()
  local class = __fnl_global__get_2dclass_2dname()
  local bindings = BINDINGS[game][class]
  if __fnl_global__is_2dretail() then
    local spec = __fnl_global__get_2dspec_2dname()
    if not spec then
      print("SlackwiseTweaks Binding: No spec currently to bind!")
    else
    end
    if (bindings.CLASS ~= nil) then
      if bindings.CLASS.PRE_SCRIPT then
        bindings.CLASS.PRE_SCRIPT()
      else
      end
      for _, binding in ipairs(bindings.CLASS) do
        local key, type, name = unpack(binding)
        if not ((type == "spell") and not C_Spell.DoesSpellExist(name)) then
          set_binding(binding)
        else
        end
      end
      if bindings.CLASS.POST_SCRIPT then
        bindings.CLASS.POST_SCRIPT()
      else
      end
    else
    end
    if (spec and (spec ~= "")) then
      if bindings[spec].PRE_SCRIPT then
        bindings[spec].PRE_SCRIPT()
      else
      end
      local spec_bindings = bindings[spec]
      if (spec_bindings ~= nil) then
        for _, binding in ipairs(spec_bindings) do
          if not ((binding[2] == "spell") and not C_Spell.DoesSpellExist(binding[3])) then
            set_binding(binding)
          else
          end
        end
      else
      end
      if bindings[spec].POST_SCRIPT then
        bindings[spec].POST_SCRIPT()
      else
      end
    else
    end
    __fnl_global__Save_2dbindings(BINDING_TYPE.CHARACTER_BINDINGS)
    return print(((spec or "CLASS-ONLY") .. " " .. class .. " binding presets loaded!"))
  elseif __fnl_global__is_2dclassic() then
    if bindings.PRE_SCRIPT then
      bindings.PRE_SCRIPT()
    else
    end
    for _, binding in ipairs(bindings) do
      local key, type, name = unpack(binding)
      if not ((type == "spell") and not C_Spell.DoesSpellExist(name)) then
        set_binding(binding)
      else
      end
    end
    if bindings.POST_SCRIPT then
      bindings.POST_SCRIPT()
    else
    end
    __fnl_global__Save_2dbindings(BINDING_TYPE.CHARACTER_BINDINGS)
    return print((class .. " binding presets loaded!"))
  else
    return print("Unknown game type! Cannot rebind.")
  end
end
return set_bindings
local function _1_()
  return __fnl_global__set_2dbindings()
end
local function _2_()
  return db.global.isDebugging
end
local function _3_()
  db.global.isDebugging = not db.global.isDebugging
  if db.global.isDebugging then
    return print("SlackwiseTweaks Debugging ON")
  else
    return print("SlackwiseTweaks Debugging OFF")
  end
end
local function _5_()
  return Self:IsEnabled()
end
local function _6_()
  if Self:IsEnabled() then
    return Self:Disable()
  else
    return Self:Enable()
  end
end
local function _8_()
  db:ResetDB()
  return print("SlackwiseTweaks: ALL DATA WIPED")
end
options = {args = {bind = {desc = "Set binding presets for current character's class and spec.", func = _1_, hidden = true, name = "Set Bindings", type = "execute"}, debug = {desc = "Enable debugging logs and stuff", get = _2_, name = "Enable Debugging", set = _3_, type = "toggle"}, enable = {desc = ("Enable/disable " .. __fnl_global__addon_2dname), get = _5_, name = "Enabled", order = 0, set = _6_, type = "toggle"}, reset = {confirm = true, desc = "DANGER: Wipes all settings! Cannot be undone!", func = _8_, name = "Reset All Data", type = "execute"}}, type = "group"}
return nil
