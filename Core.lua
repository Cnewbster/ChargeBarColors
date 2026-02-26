-- ChargeBarColors Core
local addonName = "ChargeBarColors"
local CBC = CreateFrame("Frame")
CBC:RegisterEvent("ADDON_LOADED")
CBC:RegisterEvent("PLAYER_LOGIN")
CBC:RegisterEvent("PLAYER_ENTERING_WORLD")
CBC:RegisterEvent("UNIT_POWER_UPDATE")
CBC:RegisterEvent("UNIT_POWER_FREQUENT")
CBC:RegisterEvent("UNIT_AURA")
CBC:RegisterEvent("RUNE_POWER_UPDATE")
CBC:RegisterEvent("SPELL_UPDATE_USABLE")
CBC:RegisterEvent("PLAYER_REGEN_DISABLED")
CBC:RegisterEvent("PLAYER_REGEN_ENABLED")
CBC:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
CBC:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")

local WHITE = "Interface\\Buttons\\WHITE8X8"

------------------------------------------------------------
-- WHIRLWIND MODULE (exact copy of SenseiClassResourceBar)
------------------------------------------------------------
local WW = {}
WW.IW_MAX_STACKS = 4
local iwStacks         = 0
local iwExpiresAt      = nil
local IW_DURATION      = 20
local noConsumeUntil   = 0
local seenCastGUID     = {}
local hasRequiredTalent = false

-- Talents
local REQUIRED_TALENT_ID = 12950    -- Improved Whirlwind (without this, tracker doesn't work)
local UNHINGED_TALENT_ID = 386628   -- Unhinged: BT won't consume stacks during Bladestorm

-- Generators → set stacks to max
local GENERATOR_IDS = {
    [190411] = true, -- Whirlwind
    [6343]   = true, -- Thunder Clap
    [435222] = true, -- Thunder Blast
}

-- Spenders → consume one stack
local SPENDER_IDS = {
    [23881]  = true, -- Bloodthirst
    [85288]  = true, -- Raging Blow
    [280735] = true, -- Execute
    [202168] = true, -- Impending Victory
    [184367] = true, -- Rampage
    [335096] = true, -- Bloodbath
    [335097] = true, -- Crushing Blow
    [5308]   = true, -- Execute (base)
}

local function HasUnhingedTalent()
    return C_SpellBook and C_SpellBook.IsSpellKnown(UNHINGED_TALENT_ID) or false
end

local function UpdateTalentState()
    hasRequiredTalent = (C_SpellBook and C_SpellBook.IsSpellKnown(REQUIRED_TALENT_ID)) or false
end

local function WW_OnSpellcast(unit, castGUID, spellID)
    if unit ~= "player" then return end
    if castGUID and seenCastGUID[castGUID] then return end
    if castGUID then seenCastGUID[castGUID] = true end

    -- Unhinged "no-consume window"
    if HasUnhingedTalent() and (
        spellID == 50622  or spellID == 46924  or
        spellID == 227847 or spellID == 184362 or
        spellID == 446035
    ) then
        noConsumeUntil = GetTime() + 2
    end

    -- Generator → award max stacks
    if GENERATOR_IDS[spellID] then
        C_Timer.After(0.15, function()
            if UnitAffectingCombat("player") then
                iwStacks = WW.IW_MAX_STACKS
                iwExpiresAt = GetTime() + IW_DURATION
            end
        end)
        return
    end

    -- Spender → consume one stack
    if SPENDER_IDS[spellID] then
        if (GetTime() < noConsumeUntil) and (spellID == 23881) then return end
        if (iwStacks or 0) <= 0 then return end
        iwStacks = math.max(0, (iwStacks or 0) - 1)
        if iwStacks == 0 then iwExpiresAt = nil end
        return
    end
end

function WW:GetStacks()
    if iwExpiresAt and GetTime() >= iwExpiresAt then
        iwStacks = 0
        iwExpiresAt = nil
    end
    return self.IW_MAX_STACKS, iwStacks
end

------------------------------------------------------------
-- DEFAULT COLORS (10 rainbow colors, cycle for any index)
------------------------------------------------------------
local DEFAULT_COLORS = {
    {r = 0.90, g = 0.10, b = 0.10},
    {r = 1.00, g = 0.50, b = 0.00},
    {r = 1.00, g = 1.00, b = 0.00},
    {r = 0.00, g = 0.90, b = 0.20},
    {r = 0.20, g = 0.50, b = 1.00},
    {r = 0.60, g = 0.20, b = 1.00},
    {r = 0.00, g = 0.90, b = 0.90},
    {r = 1.00, g = 0.40, b = 0.70},
    {r = 0.80, g = 0.80, b = 0.00},
    {r = 0.40, g = 1.00, b = 0.40},
}

------------------------------------------------------------
-- ESSENCE BURST TRACKING (spell activation overlay events)
------------------------------------------------------------
local ebOverlaySpells = {}
local ESSENCE_BURST_SPELL_ID = 359618

local function GetEssenceBurstStacks()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(ESSENCE_BURST_SPELL_ID)
    if aura then
        local count = aura.applications and aura.applications > 0 and aura.applications or 1
        -- In combat, GetPlayerAuraBySpellID often returns applications=0/1 even with 2 stacks; try other APIs
        if inCombat and count <= 1 then
            -- AuraUtil.ForEachAura (Blizzard) - callback gets auraData with spellId, applications/count
            if AuraUtil and AuraUtil.ForEachAura then
                local found = 0
                local ok = pcall(function()
                    AuraUtil.ForEachAura("player", "HELPFUL", nil, function(auraData)
                        if auraData and auraData.spellId == ESSENCE_BURST_SPELL_ID then
                            local s = auraData.applications or auraData.count
                            if s and s > 0 then found = math.max(found, s) end
                        end
                    end)
                end)
                if ok and found > count then count = math.min(2, found) end
            end
            -- Index-based C_UnitAuras (try both parameter orders)
            if count <= 1 and C_UnitAuras.GetAuraDataByIndex then
                local ok2, iterCount = pcall(function()
                    for i = 1, 60 do
                        local data = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
                        if not data then return count end
                        if data.spellId == ESSENCE_BURST_SPELL_ID then
                            local stacks = data.applications or data.count
                            return (stacks and stacks > 0) and math.min(2, stacks) or count
                        end
                    end
                    return count
                end)
                if ok2 and iterCount and iterCount > count then count = iterCount end
            end
        end
        return count
    end
    -- Only use overlay as fallback for Essence Burst spell itself; other Evoker overlays (Deep Breath, Time Spiral, etc.) must not show the effect
    if ebOverlaySpells[ESSENCE_BURST_SPELL_ID] then
        return 1
    end
    return 0
end

------------------------------------------------------------
-- DB INIT
------------------------------------------------------------
local function InitDB()
    if not ChargeBarColorsDB then ChargeBarColorsDB = {} end
    if ChargeBarColorsDB.enabled == nil then ChargeBarColorsDB.enabled = true end
    if not ChargeBarColorsDB.customBar then
        ChargeBarColorsDB.customBar = {}
    end
    local cb = ChargeBarColorsDB.customBar
    if cb.enabled == nil then cb.enabled = true end
    if not cb.point then cb.point = "CENTER" end
    if not cb.relativePoint then cb.relativePoint = "CENTER" end
    if not cb.x then cb.x = 0 end
    if not cb.y then cb.y = -100 end
    if not cb.width then cb.width = 220 end
    if not cb.height then cb.height = 28 end
    if not cb.scale then cb.scale = 1.0 end
    if not cb.spacing then cb.spacing = 2 end
    if cb.showText == nil then cb.showText = true end
    if not cb.depletedStyle then cb.depletedStyle = "faded" end
    if not cb.refillStyle then cb.refillStyle = "static" end
    if not cb.textColor then cb.textColor = {r = 1, g = 1, b = 1} end
    if not cb.textSize then cb.textSize = 16 end
    if cb.locked == nil then cb.locked = false end
    if not cb.texture then cb.texture = "flat" end
    if not cb.strata then cb.strata = "MEDIUM" end
    if not ChargeBarColorsDB.colors then ChargeBarColorsDB.colors = {} end
    if ChargeBarColorsDB.essenceBurstGlow == nil then ChargeBarColorsDB.essenceBurstGlow = true end
    if ChargeBarColorsDB.essenceBurstMarch == nil then ChargeBarColorsDB.essenceBurstMarch = true end
    if not ChargeBarColorsDB.essenceBurstGlowColor then
        ChargeBarColorsDB.essenceBurstGlowColor = {r = 1, g = 0.85, b = 0.3}
    end
    if not ChargeBarColorsDB.essenceBurstMarchColor then
        ChargeBarColorsDB.essenceBurstMarchColor = {r = 1, g = 0.85, b = 0.3}
    end
    if ChargeBarColorsDB.essenceBurstGlowSpeed == nil then ChargeBarColorsDB.essenceBurstGlowSpeed = 4 end
    if ChargeBarColorsDB.essenceBurstMarchSpeed == nil then ChargeBarColorsDB.essenceBurstMarchSpeed = 0.5 end
end

------------------------------------------------------------
-- TEXTURE MAP (built-in fallbacks)
------------------------------------------------------------
local TEXTURE_MAP = {
    flat      = "Interface\\Buttons\\WHITE8X8",
    smooth    = "Interface\\TargetingFrame\\UI-StatusBar",
    gradient  = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
    blizzard  = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
    highlight = "Interface\\Buttons\\UI-Listbox-Highlight2",
    tooltip   = "Interface\\Tooltips\\UI-Tooltip-Background",
}

-- Try to get LibSharedMedia if available (from Details, ElvUI, WeakAuras, etc.)
local LSM = nil
local function GetLSM()
    if LSM then return LSM end
    if LibStub then
        local ok, lib = pcall(LibStub, "LibSharedMedia-3.0", true)
        if ok and lib then LSM = lib end
    end
    return LSM
end

local function GetBarTexture()
    local key = ChargeBarColorsDB and ChargeBarColorsDB.customBar and ChargeBarColorsDB.customBar.texture or "flat"
    -- Check built-in first
    if TEXTURE_MAP[key] then return TEXTURE_MAP[key] end
    -- Check LSM
    local lsm = GetLSM()
    if lsm then
        local path = lsm:Fetch("statusbar", key, true)
        if path then return path end
    end
    return TEXTURE_MAP["flat"]
end

------------------------------------------------------------
-- COLOR FUNCTIONS
------------------------------------------------------------
local function DefaultColor(idx)
    local c = DEFAULT_COLORS[((idx - 1) % #DEFAULT_COLORS) + 1]
    return c.r, c.g, c.b
end

local function GetColor(resType, idx)
    if not ChargeBarColorsDB.colors then ChargeBarColorsDB.colors = {} end
    if not ChargeBarColorsDB.colors[resType] then ChargeBarColorsDB.colors[resType] = {} end
    local c = ChargeBarColorsDB.colors[resType][idx]
    if c and c.r and c.g and c.b and (c.r + c.g + c.b > 0.01) then
        return c.r, c.g, c.b
    end
    local r, g, b = DefaultColor(idx)
    ChargeBarColorsDB.colors[resType][idx] = {r = r, g = g, b = b}
    return r, g, b
end

local function SetColor(resType, idx, r, g, b)
    if not ChargeBarColorsDB.colors then ChargeBarColorsDB.colors = {} end
    if not ChargeBarColorsDB.colors[resType] then ChargeBarColorsDB.colors[resType] = {} end
    ChargeBarColorsDB.colors[resType][idx] = {r = r, g = g, b = b}
end

------------------------------------------------------------
-- RESOURCE DETECTION (SenseiClassResourceBar style)
------------------------------------------------------------
local function GetResource()
    local _, playerClass = UnitClass("player")
    if not playerClass then return nil end

    local spec = C_SpecializationInfo.GetSpecialization()
    local specID = spec and C_SpecializationInfo.GetSpecializationInfo(spec) or nil

    if playerClass == "DRUID" then
        local formID = GetShapeshiftFormID()
        if formID == 1 then return "combo" end          -- Cat Form
        if formID == 4 or formID == 27 then return nil end -- Moonkin
        if specID == 102 then return nil end              -- Balance caster
        return nil
    end

    local simple = {
        DEATHKNIGHT = "rune",
        EVOKER      = "essence",
        PALADIN     = "holypower",
        ROGUE       = "combo",
        WARLOCK     = "soulshards",
    }
    if simple[playerClass] then return simple[playerClass] end

    local bySpec = {
        DEMONHUNTER = {[581] = "soulfragments", [1480] = "soulfragments"},
        HUNTER      = {[255] = "tipofthespear"},
        MAGE        = {[62]  = "arcanecharges"},
        MONK        = {[268] = "stagger", [269] = "chi"},
        PRIEST      = {},
        SHAMAN      = {[263] = "maelstrom"},
        WARRIOR     = {[72]  = "whirlwind"},
    }
    if bySpec[playerClass] and specID then
        return bySpec[playerClass][specID]
    end
    return nil
end

------------------------------------------------------------
-- RESOURCE VALUES (SenseiClassResourceBar style)
------------------------------------------------------------
local function GetResourceValue(resType)
    if not resType then return 0, 0 end

    if resType == "rune" then
        local max = UnitPowerMax("player", Enum.PowerType.Runes)
        if not max or max <= 0 then return 6, 0 end
        local cur = 0
        for i = 1, max do
            local _, _, ready = GetRuneCooldown(i)
            if ready then cur = cur + 1 end
        end
        return max, cur

    elseif resType == "essence" then
        local max = UnitPowerMax("player", Enum.PowerType.Essence)
        if not max or max <= 0 then max = 6 end
        return max, UnitPower("player", Enum.PowerType.Essence) or 0

    elseif resType == "combo" then
        local max = UnitPowerMax("player", Enum.PowerType.ComboPoints)
        if not max or max <= 0 then max = 5 end
        return max, UnitPower("player", Enum.PowerType.ComboPoints) or 0

    elseif resType == "chi" then
        local max = UnitPowerMax("player", Enum.PowerType.Chi)
        if not max or max <= 0 then max = 6 end
        return max, UnitPower("player", Enum.PowerType.Chi) or 0

    elseif resType == "holypower" then
        local max = UnitPowerMax("player", Enum.PowerType.HolyPower)
        if not max or max <= 0 then max = 5 end
        return max, UnitPower("player", Enum.PowerType.HolyPower) or 0

    elseif resType == "soulshards" then
        local max = UnitPowerMax("player", Enum.PowerType.SoulShards)
        if not max or max <= 0 then max = 5 end
        return max, UnitPower("player", Enum.PowerType.SoulShards) or 0

    elseif resType == "arcanecharges" then
        local max = UnitPowerMax("player", Enum.PowerType.ArcaneCharges)
        if not max or max <= 0 then max = 4 end
        return max, UnitPower("player", Enum.PowerType.ArcaneCharges) or 0

    elseif resType == "whirlwind" then
        -- Use manual tracking module (exactly like SenseiClassResourceBar)
        return WW:GetStacks()

    elseif resType == "soulfragments" then
        local s = C_SpecializationInfo.GetSpecialization()
        local sid = s and C_SpecializationInfo.GetSpecializationInfo(s) or nil
        if sid == 581 and C_Spell and C_Spell.GetSpellCastCount then
            return 6, C_Spell.GetSpellCastCount(228477) or 0
        end
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(1225789)
        if not aura then aura = C_UnitAuras.GetPlayerAuraBySpellID(1227702) end
        return 6, aura and aura.applications or 0

    elseif resType == "maelstrom" then
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(344179)
        return 10, aura and aura.applications or 0

    elseif resType == "stagger" then
        return UnitHealthMax("player") or 1, UnitStagger("player") or 0

    elseif resType == "tipofthespear" then
        return 3, 0
    end

    return 0, 0
end

------------------------------------------------------------
-- CUSTOM CHARGE BAR
------------------------------------------------------------
local bar = nil
local segments = {}

local function CreateBar()
    if bar then return bar end

    bar = CreateFrame("Frame", "CBCBar", UIParent)
    bar:SetSize(220, 28)
    bar:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
    bar:SetMovable(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetClampedToScreen(true)
    local strata = (ChargeBarColorsDB and ChargeBarColorsDB.customBar and ChargeBarColorsDB.customBar.strata) or "MEDIUM"
    bar:SetFrameStrata(strata)
    bar:SetFrameLevel(10)
    bar:SetClipsChildren(false)

    bar:SetScript("OnDragStart", function(self)
        if ChargeBarColorsDB and ChargeBarColorsDB.customBar and ChargeBarColorsDB.customBar.locked then return end
        self.dragging = true
        self:StartMoving()
    end)
    bar:SetScript("OnDragStop", function(self)
        if not self.dragging then return end
        self.dragging = false
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        if ChargeBarColorsDB.customBar then
            ChargeBarColorsDB.customBar.point = p
            ChargeBarColorsDB.customBar.relativePoint = rp
            ChargeBarColorsDB.customBar.x = x
            ChargeBarColorsDB.customBar.y = y
        end
    end)

    -- Text overlay frame (higher level so text is ALWAYS in front)
    local textFrame = CreateFrame("Frame", nil, bar)
    textFrame:SetAllPoints()
    textFrame:SetFrameLevel(bar:GetFrameLevel() + 50)
    local text = textFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER")
    text:SetTextColor(1, 1, 1, 1)
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
    bar.text = text

    bar.positioned = false
    return bar
end

-- Reposition bar to exact X/Y (called from Options)
local function RepositionBar()
    if not bar then return end
    local cfg = ChargeBarColorsDB and ChargeBarColorsDB.customBar
    if not cfg then return end
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", UIParent, "CENTER", cfg.x or 0, cfg.y or -100)
    cfg.point = "CENTER"
    cfg.relativePoint = "CENTER"
    bar.positioned = true
end

------------------------------------------------------------
-- SEGMENT STYLE HELPERS
------------------------------------------------------------
local function StyleActive(seg, r, g, b)
    seg.fill:ClearAllPoints()
    seg.fill:SetAllPoints(seg)
    seg.fill:SetVertexColor(r, g, b, 1)
    seg.fill:Show()
    seg.bg:Hide()
    seg.border:Show()
    seg:SetAlpha(1)
end

local function StyleDepleted(seg, r, g, b, style)
    seg.fill:Hide()
    if style == "black" then
        seg.bg:SetVertexColor(0.06, 0.06, 0.06, 1)
        seg.bg:Show()
        seg.border:Show()
        seg:SetAlpha(1)
    elseif style == "clear" then
        -- Empty box: hide fill & background but keep the border outline visible
        seg.bg:Hide()
        seg.border:Show()
        seg:SetAlpha(1)
    else -- "faded"
        seg.bg:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, 1)
        seg.bg:Show()
        seg.border:Show()
        seg:SetAlpha(0.5)
    end
end

local function StyleFilling(seg, r, g, b, progress, style, direction)
    -- Depleted background behind partial fill
    if style == "black" then
        seg.bg:SetVertexColor(0.06, 0.06, 0.06, 1)
        seg.bg:Show()
    elseif style == "clear" then
        seg.bg:Hide()
    else -- "faded"
        seg.bg:SetVertexColor(r * 0.25, g * 0.25, b * 0.25, 1)
        seg.bg:Show()
    end
    seg.border:Show()
    seg:SetAlpha(1)

    local w = math.max(1, seg:GetWidth() * math.max(0, math.min(1, progress)))
    seg.fill:ClearAllPoints()
    if direction == "rl" then
        -- Fill from RIGHT to LEFT
        seg.fill:SetPoint("TOPRIGHT", seg, "TOPRIGHT", 0, 0)
        seg.fill:SetPoint("BOTTOMRIGHT", seg, "BOTTOMRIGHT", 0, 0)
    else
        -- Fill from LEFT to RIGHT (default)
        seg.fill:SetPoint("TOPLEFT", seg, "TOPLEFT", 0, 0)
        seg.fill:SetPoint("BOTTOMLEFT", seg, "BOTTOMLEFT", 0, 0)
    end
    seg.fill:SetWidth(w)
    seg.fill:SetVertexColor(r, g, b, 1)
    seg.fill:Show()
end

------------------------------------------------------------
-- MARCHING ANTS (entire bar outline, all rotate together)
------------------------------------------------------------
local DASH_LEN = 6
local DASH_GAP = 4
local DASH_CYCLE = DASH_LEN + DASH_GAP
local DASH_THICK = 2
local MARCH_PAD = 3

local function BuildBarMarchDashes(barFrame, w, h)
    local outerW = w + MARCH_PAD * 2
    local outerH = h + MARCH_PAD * 2
    local perimeter = 2 * (outerW + outerH)
    local dashCount = math.max(4, math.floor(perimeter / DASH_CYCLE))

    if barFrame.marchDashes and #barFrame.marchDashes == dashCount
       and barFrame._lastDashW == w and barFrame._lastDashH == h then
        return
    end
    barFrame._lastDashW = w
    barFrame._lastDashH = h

    if barFrame.marchDashes then
        for _, d in ipairs(barFrame.marchDashes) do d.tex:Hide() end
    end
    barFrame.marchDashes = {}
    barFrame._marchPerimeter = perimeter
    barFrame._marchOuterW = outerW
    barFrame._marchOuterH = outerH

    for idx = 0, dashCount - 1 do
        local tex = barFrame:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetTexture(WHITE)
        tex:Hide()
        table.insert(barFrame.marchDashes, {tex = tex, basePos = idx / dashCount})
    end
end

local function PositionDashOnPerimeter(tex, dist, perimeter, outerW, outerH, barFrame)
    dist = dist % perimeter
    tex:ClearAllPoints()
    if dist < outerW then
        local dw = math.min(DASH_LEN, outerW - dist)
        tex:SetSize(dw, DASH_THICK)
        tex:SetPoint("TOPLEFT", barFrame, "TOPLEFT", dist - MARCH_PAD, MARCH_PAD)
    elseif dist < outerW + outerH then
        local edgeDist = dist - outerW
        local dh = math.min(DASH_LEN, outerH - edgeDist)
        tex:SetSize(DASH_THICK, dh)
        tex:SetPoint("TOPRIGHT", barFrame, "TOPRIGHT", MARCH_PAD, -(edgeDist - MARCH_PAD))
    elseif dist < 2 * outerW + outerH then
        local edgeDist = dist - outerW - outerH
        local dw = math.min(DASH_LEN, outerW - edgeDist)
        tex:SetSize(dw, DASH_THICK)
        tex:SetPoint("BOTTOMRIGHT", barFrame, "BOTTOMRIGHT", -(edgeDist - MARCH_PAD), -MARCH_PAD)
    else
        local edgeDist = dist - 2 * outerW - outerH
        local dh = math.min(DASH_LEN, outerH - edgeDist)
        tex:SetSize(DASH_THICK, dh)
        tex:SetPoint("BOTTOMLEFT", barFrame, "BOTTOMLEFT", -MARCH_PAD, edgeDist - MARCH_PAD)
    end
end

------------------------------------------------------------
-- RECHARGE TRACKING (for Evoker Essence left-to-right fill)
------------------------------------------------------------
-- Only Essence uses the left-to-right single-slot recharge logic now.
-- Runes are handled per-slot (each rune fills independently in its own position).
local RECHARGING_TYPES = {
    essence = true,
}

local rechargeState = {
    lastCurrent     = nil,
    rechargeStart   = 0,
    measuredDur     = 5,
    rechargingIndex = nil,
}

local function UpdateRechargeTracking(resType, maxC, curC)
    -- Only Essence uses this; runes handled separately
    if not RECHARGING_TYPES[resType] then
        rechargeState.rechargingIndex = nil
        rechargeState.lastCurrent = curC
        return
    end

    local prev = rechargeState.lastCurrent
    local now = GetTime()

    if prev == nil then
        rechargeState.lastCurrent = curC
        if curC < maxC then
            rechargeState.rechargeStart = now
            rechargeState.rechargingIndex = curC + 1
        else
            rechargeState.rechargingIndex = nil
        end
        return
    end

    if curC > prev then
        local elapsed = now - rechargeState.rechargeStart
        if elapsed > 0.5 and elapsed < 30 then
            rechargeState.measuredDur = elapsed
        end
        if curC < maxC then
            rechargeState.rechargeStart = now
            rechargeState.rechargingIndex = curC + 1
        else
            rechargeState.rechargingIndex = nil
        end
    elseif curC < prev then
        if rechargeState.rechargingIndex == nil then
            rechargeState.rechargeStart = now
        end
        rechargeState.rechargingIndex = curC + 1
    end

    rechargeState.lastCurrent = curC
end

------------------------------------------------------------
-- UPDATE BAR
------------------------------------------------------------
local function UpdateBar()
    if not ChargeBarColorsDB or not ChargeBarColorsDB.customBar then
        InitDB()
    end
    local cfg = ChargeBarColorsDB.customBar
    if not cfg.enabled then
        if bar then bar:Hide() end
        return
    end

    local b = CreateBar()
    local resType = GetResource()
    if not resType then
        b:Hide()
        return
    end

    local maxC, curC = GetResourceValue(resType)
    if not maxC or maxC <= 0 then maxC = 5 end
    if not curC then curC = 0 end
    curC = tonumber(curC) or 0

    -- Track recharge progress for timed resources (Essence, etc.)
    UpdateRechargeTracking(resType, maxC, curC)

    b:SetScale(cfg.scale or 1.0)
    b:SetFrameStrata(cfg.strata or "MEDIUM")

    -- Position (once, unless dragged)
    if not b.dragging and not b.positioned then
        b:ClearAllPoints()
        b:SetPoint(cfg.point or "CENTER", UIParent, cfg.relativePoint or "CENTER", cfg.x or 0, cfg.y or -100)
        b.positioned = true
    end

    local totalW = cfg.width or 220
    local totalH = cfg.height or 28
    local sp     = cfg.spacing or 2
    local segW   = (totalW - sp * (maxC - 1)) / maxC
    if segW < 2 then segW = 2 end

    b:SetSize(totalW, totalH)

    if resType == "essence" then
        BuildBarMarchDashes(b, totalW, totalH)
    elseif b.marchDashes then
        for _, d in ipairs(b.marchDashes) do d.tex:Hide() end
    end

    local depStyle  = cfg.depletedStyle or "faded"
    local fillStyle = cfg.refillStyle or "static"
    -- "fill" = L->R, "fillrl" = R->L, anything else = static
    local isFillMode = (fillStyle == "fill" or fillStyle == "fillrl")
    local fillDir = (fillStyle == "fillrl") and "rl" or "lr"

    local barTex = GetBarTexture()

    for i = 1, maxC do
        local seg = segments[i]
        if not seg then
            seg = CreateFrame("Frame", nil, b)
            seg:SetFrameLevel(b:GetFrameLevel() + 2)

            -- Black border behind everything (BACKGROUND)
            local border = seg:CreateTexture(nil, "BACKGROUND")
            border:SetTexture(WHITE)
            border:SetVertexColor(0, 0, 0, 1)
            border:SetPoint("TOPLEFT", -1, 1)
            border:SetPoint("BOTTOMRIGHT", 1, -1)
            seg.border = border

            -- Depleted background (ARTWORK sublevel 0)
            local bg = seg:CreateTexture(nil, "ARTWORK", nil, 0)
            bg:SetTexture(barTex)
            bg:SetAllPoints()
            seg.bg = bg

            -- Active / fill color (ARTWORK sublevel 1, draws ON TOP of bg)
            local fill = seg:CreateTexture(nil, "ARTWORK", nil, 1)
            fill:SetTexture(barTex)
            fill:SetAllPoints()
            seg.fill = fill

            local glowOverlay = seg:CreateTexture(nil, "ARTWORK", nil, 2)
            glowOverlay:SetTexture(barTex)
            glowOverlay:SetAllPoints()
            glowOverlay:SetVertexColor(1, 1, 1, 1)
            glowOverlay:Hide()
            seg.glowOverlay = glowOverlay
            seg.glowing = false

            seg.wasActive = nil
            seg.animating = false
            seg.animStart = 0
            segments[i] = seg
        end

        -- Update texture on every refresh (in case user changed it)
        seg.bg:SetTexture(barTex)
        seg.fill:SetTexture(barTex)
        if seg.glowOverlay then seg.glowOverlay:SetTexture(barTex) end

        seg:ClearAllPoints()
        seg:SetSize(segW, totalH)
        seg:SetPoint("LEFT", b, "LEFT", (i - 1) * (segW + sp), 0)

        local r, g, b2 = GetColor(resType, i)

        if resType == "rune" and isFillMode then
            -- DK RUNES: each segment = real rune slot, fill independently
            local start, dur, ready = GetRuneCooldown(i)
            if ready then
                StyleActive(seg, r, g, b2)
                seg._runeRecharging = false
            else
                seg._runeRecharging = true
                seg._runeStart = start or 0
                seg._runeDur   = dur or 10
                StyleDepleted(seg, r, g, b2, depStyle)
            end
            seg.animating = false
            seg.wasActive = ready

        elseif isFillMode then
            local isActive = (i <= curC)
            local isRecharging = (rechargeState.rechargingIndex == i and RECHARGING_TYPES[resType])

            if isRecharging then
                seg.animating = false
                StyleDepleted(seg, r, g, b2, depStyle)
            elseif isActive and seg.wasActive == false and not RECHARGING_TYPES[resType] then
                seg.animating = true
                seg.animStart = GetTime()
            elseif isActive and not seg.animating then
                StyleActive(seg, r, g, b2)
            elseif not isActive and not isRecharging then
                seg.animating = false
                StyleDepleted(seg, r, g, b2, depStyle)
            end
            seg.wasActive = isActive
            seg._runeRecharging = false

        else
            -- Static mode
            local isActive = (i <= curC)
            if isActive then
                StyleActive(seg, r, g, b2)
            else
                StyleDepleted(seg, r, g, b2, depStyle)
            end
            seg.wasActive = isActive
            seg._runeRecharging = false
        end
        seg:Show()
    end

    -- Hide extra segments
    for i = maxC + 1, #segments do
        if segments[i] then segments[i]:Hide() end
    end

    -- Text
    -- Text size
    local fontSize = cfg.textSize or 16
    local fontPath, _, fontFlags = b.text:GetFont()
    if fontPath then
        b.text:SetFont(fontPath, fontSize, fontFlags)
    end

    -- Text color
    local tc = cfg.textColor or {r = 1, g = 1, b = 1}
    b.text:SetTextColor(tc.r or 1, tc.g or 1, tc.b or 1, 1)

    if cfg.showText then
        b.text:SetText(tostring(curC))
        b.text:Show()
    else
        b.text:Hide()
    end

    b:Show()
end

------------------------------------------------------------
-- FILL ANIMATION (OnUpdate)
------------------------------------------------------------
local animFrame = CreateFrame("Frame")
animFrame:SetScript("OnUpdate", function(self, elapsed)
    if not bar or not bar:IsShown() then return end
    local cfg = ChargeBarColorsDB and ChargeBarColorsDB.customBar
    if not cfg or not cfg.enabled then return end

    local resType = GetResource()
    if not resType then return end

    -- Fill animation (only in fill modes)
    local fillStyle = cfg.refillStyle or "static"
    if fillStyle == "fill" or fillStyle == "fillrl" then
        local depStyle = cfg.depletedStyle or "faded"
        local fillDir = (fillStyle == "fillrl") and "rl" or "lr"

        if resType == "rune" then
            local now = GetTime()
            for i = 1, #segments do
                local seg = segments[i]
                if not seg or not seg:IsShown() then break end
                if seg._runeRecharging and seg._runeDur and seg._runeDur > 0 then
                    local progress = (now - (seg._runeStart or 0)) / seg._runeDur
                    progress = math.max(0, math.min(1, progress))
                    local r, g, b = GetColor(resType, i)
                    if progress >= 1 then
                        StyleActive(seg, r, g, b)
                    else
                        StyleFilling(seg, r, g, b, progress, depStyle, fillDir)
                    end
                end
            end
        elseif RECHARGING_TYPES[resType] and rechargeState.rechargingIndex then
            local rIdx = rechargeState.rechargingIndex
            local dur = rechargeState.measuredDur
            if dur <= 0 then dur = 5 end
            local progress = (GetTime() - rechargeState.rechargeStart) / dur
            progress = math.max(0, math.min(1, progress))

            local seg = segments[rIdx]
            if seg and seg:IsShown() then
                local r, g, b = GetColor(resType, rIdx)
                if progress >= 1 then
                    StyleActive(seg, r, g, b)
                else
                    StyleFilling(seg, r, g, b, progress, depStyle, fillDir)
                end
            end
        else
            for i = 1, #segments do
                local seg = segments[i]
                if not seg or not seg:IsShown() then break end
                if seg.animating then
                    local progress = (GetTime() - seg.animStart) / 0.35
                    local r, g, b = GetColor(resType, i)
                    if progress >= 1 then
                        seg.animating = false
                        StyleActive(seg, r, g, b)
                    else
                        StyleFilling(seg, r, g, b, progress, depStyle, fillDir)
                    end
                end
            end
        end
    end

    -- Essence Burst effects (glow + marching ants), user-configurable color and speed
    local now = GetTime()
    local ebStacks = (resType == "essence") and GetEssenceBurstStacks() or 0
    local glowActive = ChargeBarColorsDB.essenceBurstGlow and (ebStacks > 0)
    local marchActive = ChargeBarColorsDB.essenceBurstMarch and (ebStacks > 0)
    local glowSpeed = (ChargeBarColorsDB.essenceBurstGlowSpeed and ChargeBarColorsDB.essenceBurstGlowSpeed > 0) and ChargeBarColorsDB.essenceBurstGlowSpeed or 4
    local marchSpeed = (ChargeBarColorsDB.essenceBurstMarchSpeed and ChargeBarColorsDB.essenceBurstMarchSpeed > 0) and ChargeBarColorsDB.essenceBurstMarchSpeed or 0.5
    local glowColor = ChargeBarColorsDB.essenceBurstGlowColor or {r = 1, g = 0.85, b = 0.3}
    local marchColor = ChargeBarColorsDB.essenceBurstMarchColor or {r = 1, g = 0.85, b = 0.3}
    local gr, gg, gb = glowColor.r or 1, glowColor.g or 0.85, glowColor.b or 0.3
    local mr, mg, mb = marchColor.r or 1, marchColor.g or 0.85, marchColor.b or 0.3

    for i = 1, #segments do
        local seg = segments[i]
        if not seg then break end

        -- Glow overlay + border tint (user color)
        if glowActive and seg:IsShown() then
            seg.glowing = true
            local pulse = 0.5 + 0.5 * math.sin(now * glowSpeed)
            if seg.glowOverlay then
                seg.glowOverlay:SetVertexColor(gr, gg, gb, 1)
                seg.glowOverlay:SetAlpha(0.15 + 0.3 * pulse)
                seg.glowOverlay:Show()
            end
            if not marchActive then
                local br = 0.5 + 0.5 * pulse
                seg.border:SetVertexColor(br * gr, br * gg, br * gb, 1)
            end
        elseif seg.glowing then
            seg.glowing = false
            if not marchActive then
                seg.border:SetVertexColor(0, 0, 0, 1)
            end
            if seg.glowOverlay then seg.glowOverlay:Hide() end
        end

        -- Segment border tint when marching ants active
        if marchActive and seg:IsShown() then
            seg.border:SetVertexColor(mr * 0.4, mg * 0.4, mb * 0.4, 1)
        elseif not marchActive and not seg.glowing then
            seg.border:SetVertexColor(0, 0, 0, 1)
        end
    end

    -- Border dashes: reposition every dash each frame so they all rotate together
    if bar and bar.marchDashes then
        if marchActive then
            local perim = bar._marchPerimeter or 1
            local oW = bar._marchOuterW or 1
            local oH = bar._marchOuterH or 1
            local timeOffset = (now * marchSpeed) % 1
            for _, d in ipairs(bar.marchDashes) do
                local dist = ((d.basePos + timeOffset) % 1) * perim
                PositionDashOnPerimeter(d.tex, dist, perim, oW, oH, bar)
                d.tex:SetVertexColor(mr, mg, mb, 1)
                d.tex:SetAlpha(0.9)
                d.tex:Show()
            end
        else
            for _, d in ipairs(bar.marchDashes) do
                d.tex:Hide()
            end
        end
    end
end)

------------------------------------------------------------
-- COMBAT STATE TRACKING
------------------------------------------------------------
local inCombat = false

------------------------------------------------------------
-- EVENTS
------------------------------------------------------------
CBC:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitDB()
        _G.ChargeBarColors = CBC
        self:UnregisterEvent("ADDON_LOADED")
        -- Register UNIT_SPELLCAST_SUCCEEDED for Warrior Whirlwind tracking
        local _, playerClass = UnitClass("player")
        if playerClass == "WARRIOR" then
            self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        end

    elseif event == "PLAYER_LOGIN" then
        InitDB()
        UpdateTalentState()
        C_Timer.After(1, function()
            print("|cFF00FF00Charge Bar Colors|r loaded! Type |cFFFFFF00/cbc|r to open settings.")
            UpdateBar()
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        wipe(ebOverlaySpells)
        C_Timer.After(0.3, UpdateBar)

    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true

    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        UpdateBar()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- Warrior Whirlwind: track generators/spenders (exactly like SenseiClassResourceBar)
        -- arg1 = unit, arg2 = castGUID, arg3 = spellID
        WW_OnSpellcast(arg1, arg2, arg3)
        UpdateBar()

    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" then
        if arg1 == "player" then UpdateBar() end

    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        -- Only track Essence Burst overlay; other Evoker spells (Deep Breath, Time Spiral, etc.) must not trigger glow/marching ants
        if arg1 == ESSENCE_BURST_SPELL_ID then
            ebOverlaySpells[arg1] = true
        end

    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        ebOverlaySpells[arg1] = nil

    elseif event == "UNIT_AURA" then
        if arg1 == "player" then UpdateBar() end

    elseif event == "RUNE_POWER_UPDATE" then
        UpdateBar()

    elseif event == "SPELL_UPDATE_USABLE" then
        UpdateBar()
    end
end)

------------------------------------------------------------
-- API
------------------------------------------------------------
CBC.GetResource      = GetResource
CBC.GetResourceValue = GetResourceValue
CBC.GetColor         = GetColor
CBC.SetColor = function(rt, idx, r, g, b)
    SetColor(rt, idx, r, g, b)
    UpdateBar()
end
CBC.UpdateBar      = UpdateBar
CBC.RepositionBar  = RepositionBar
CBC.GetBar         = function() return bar end

_G.ChargeBarColors = CBC
