setfenv(1, _G.SlackHacks)

function handleDragonriding()
  -- log("Aura handling dragonriding...")
  if isTester() then
    if isDragonriding() then
      -- log("BINDING dragonriding")
      bindDragonriding()
    else
      -- log("UNBINDING dragonriding")
      unbindDragonriding()
    end
  end
end

isDragonridingBound = false

function bindDragonriding()
  if not InCombatLockdown() and not isDragonridingBound then
    SetOverrideBindingSpell(Self.frame, true, "BUTTON3",       "Skyward Ascent")   -- Fly up
    SetOverrideBindingSpell(Self.frame, true, "SHIFT-BUTTON3", "Surge Forward")    -- Fly forward
    SetOverrideBindingSpell(Self.frame, true, "CTRL-BUTTON3",  "Whirling Surge")   -- Fly forward x3
    SetOverrideBindingSpell(Self.frame, true, "BUTTON5",       "Aerial Halt")      -- Brake
    SetOverrideBindingSpell(Self.frame, true, "SHIFT-X",       "Second Wind")      -- Regen Vigor
    SetOverrideBindingSpell(Self.frame, true, "CTRL-X",        "Bronze Timelock")  -- Rewind Time
    if getClassName() == "DRUID" then
      SetOverrideBindingMacro(Self.frame, true, "X",             "X")      -- Moonkin or Brake
    else
      SetOverrideBindingSpell(Self.frame, true, "X",             "Aerial Halt")      -- Brake
    end
    isDragonridingBound = true
    -- log("Dragonriding keys BOUND")
  end 
end

function unbindDragonriding()
  if not InCombatLockdown() and isDragonridingBound then
    ClearOverrideBindings(Self.frame)
    isDragonridingBound = false
    -- log("Dragonriding keys CLEARED")
  end
end

SKYRIDING_SPELLID = 404464
function isDragonriding()
  -- log("Checking if dragonriding...")
  local dragonridingSpellIds = C_MountJournal.GetCollectedDragonridingMounts()
  if C_UnitAuras.GetPlayerAuraBySpellID(SKYRIDING_SPELLID) and isActuallyFlyableArea() then
    if GetShapeshiftForm() == 3 then
      return true
    elseif IsMounted() then
      for _, mountId in ipairs(dragonridingSpellIds) do
        local spellId = select(2, C_MountJournal.GetMountInfoByID(mountId))
        if C_UnitAuras.GetPlayerAuraBySpellID(spellId) then
          return true
        end
      end
    end
  end
  return false
end

MOUNTS_BY_USAGE = { }

function setupEkil()
  if isEkil() then
    MOUNTS_BY_USAGE = {
      DEFAULT = {
        ['GROUND']           = MOUNT_IDS["Ironbound Proto-Drake"],
        ['FLYING']           = MOUNT_IDS["Ironbound Proto-Drake"],
        ['WATER']            = MOUNT_IDS["Ironbound Proto-Drake"],
        ['GROUND_PASSENGER'] = MOUNT_IDS["Renewed Proto-Drake"],
        ['FLYING_PASSENGER'] = MOUNT_IDS["Renewed Proto-Drake"],
        ['GROUND_SHOWOFF']   = MOUNT_IDS["Ironbound Proto-Drake"],
        ['FLYING_SHOWOFF']   = MOUNT_IDS["Ironbound Proto-Drake"],
      }
    }
  end
end

function mountByUsage(usage)
  if isDebugging() then
    printDebugMapInfo()
  end
  local classMounts = MOUNTS_BY_USAGE[getClassName()] or MOUNTS_BY_USAGE["DEFAULT"]
  C_MountJournal.SummonByID(classMounts[usage])
end

function mountByName(mountName)
  C_MountJournal.SummonByID(MOUNT_IDS[mountName])
end

function isAlternativeMountRequested()
  -- return IsControlKeyDown()
  return IsModifierKeyDown() -- This will ignore any modifiers used to trigger off a keybinding!
end

function mount()  
  if IsMounted() then
    Dismount()
    return
  end

  if UnitUsingVehicle("player") then
    VehicleExit()
    return
  end

  if IsOutdoors() then
    if isActuallyFlyableArea() and not IsSubmerged() then -- Summon flying mount
      log("FLYING AREA")
      if isAlternativeMountRequested() then -- But we may want to show off our ground mount
        mountByUsage("FLYING_SHOWOFF")
        return
      end
      if IsInGroup() then
        mountByUsage("FLYING_PASSENGER")
        return
      else
        mountByUsage("FLYING")
        return
      end
      return
    elseif IsSubmerged() then -- Summon water mount
      if isAlternativeMountRequested() then -- But we may want to fly out of the water
        mountByUsage("FLYING")
        return
      end
      mountByUsage("WATER")
      return
    else -- Summon ground mount
      if IsInGroup() then
        if isAlternativeMountRequested() then -- But we may want to show off
          mountByUsage("GROUND_SHOWOFF")
          return
        end
        mountByUsage("GROUND_PASSENGER")
        return
      else
        if isAlternativeMountRequested() then -- But we may want to show off
          mountByUsage("GROUND_SHOWOFF")
          return
        end
        mountByUsage("GROUND")
        return
      end
    end
  end
end