-- ChargeBarColors Settings UI
-- Opens with /cbc – zero deprecated templates

local WHITE = "Interface\\Buttons\\WHITE8X8"
local settingsFrame = nil
local colorBtns = {}
local selectedRes = nil

------------------------------------------------------------
-- RESOURCE TABLE
------------------------------------------------------------
local RES_LIST = {
    {key = "combo",         name = "Combo Points",    max = 7},
    {key = "chi",           name = "Chi",             max = 6},
    {key = "holypower",     name = "Holy Power",      max = 5},
    {key = "soulshards",    name = "Soul Shards",     max = 5},
    {key = "rune",          name = "Runes",           max = 6},
    {key = "essence",       name = "Essence",         max = 6},
    {key = "whirlwind",     name = "Whirlwind",       max = 4},
    {key = "arcanecharges", name = "Arcane Charges",  max = 4},
    {key = "maelstrom",     name = "Maelstrom",       max = 10},
    {key = "soulfragments", name = "Soul Fragments",  max = 6},
    {key = "tipofthespear", name = "Tip of Spear",    max = 3},
}

------------------------------------------------------------
-- TEXTURE LIST (built-in + LibSharedMedia if available)
------------------------------------------------------------
local BUILTIN_TEXTURES = {
    {key = "flat",      label = "Flat (Solid)"},
    {key = "smooth",    label = "Smooth"},
    {key = "gradient",  label = "Gradient"},
    {key = "blizzard",  label = "Blizzard"},
    {key = "highlight", label = "Highlight"},
    {key = "tooltip",   label = "Tooltip"},
}

-- Build the full texture list (called once when settings open)
local function BuildTextureList()
    local list = {}
    -- Add built-ins first
    for _, t in ipairs(BUILTIN_TEXTURES) do
        table.insert(list, t)
    end
    -- Add LSM textures if available
    if LibStub then
        local ok, lsm = pcall(LibStub, "LibSharedMedia-3.0", true)
        if ok and lsm then
            local hash = lsm:HashTable("statusbar")
            if hash then
                -- Collect and sort names
                local names = {}
                local builtinKeys = {}
                for _, bt in ipairs(BUILTIN_TEXTURES) do builtinKeys[bt.key] = true end
                for name, _ in pairs(hash) do
                    if not builtinKeys[name] then
                        table.insert(names, name)
                    end
                end
                table.sort(names)
                -- Add separator label
                if #names > 0 then
                    table.insert(list, {key = "_sep", label = "── LibSharedMedia ──", disabled = true})
                end
                for _, name in ipairs(names) do
                    table.insert(list, {key = name, label = name})
                end
            end
        end
    end
    return list
end

------------------------------------------------------------
-- SERIALIZATION (import / export)
------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_REV = {}
for i = 1, #B64 do B64_REV[B64:sub(i, i)] = i - 1 end

local function Base64Encode(data)
    local out = {}
    for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        b = b or 0; c = c or 0
        local n = a * 65536 + b * 256 + c
        out[#out + 1] = B64:sub(math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
        out[#out + 1] = B64:sub(math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
        out[#out + 1] = (i + 1 <= #data) and B64:sub(math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1) or "="
        out[#out + 1] = (i + 2 <= #data) and B64:sub(n % 64 + 1, n % 64 + 1) or "="
    end
    return table.concat(out)
end

local function Base64Decode(data)
    data = data:gsub("[^A-Za-z0-9+/=]", "")
    local out = {}
    for i = 1, #data, 4 do
        local a = B64_REV[data:sub(i, i)] or 0
        local b = B64_REV[data:sub(i + 1, i + 1)] or 0
        local c = B64_REV[data:sub(i + 2, i + 2)] or 0
        local d = B64_REV[data:sub(i + 3, i + 3)] or 0
        local n = a * 262144 + b * 4096 + c * 64 + d
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if data:sub(i + 2, i + 2) ~= "=" then
            out[#out + 1] = string.char(math.floor(n / 256) % 256)
        end
        if data:sub(i + 3, i + 3) ~= "=" then
            out[#out + 1] = string.char(n % 256)
        end
    end
    return table.concat(out)
end

local function SerializeValue(val)
    local t = type(val)
    if t == "table" then
        local parts = {}
        for k, v in pairs(val) do
            local ks = '"' .. tostring(k):gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
            parts[#parts + 1] = ks .. ":" .. SerializeValue(v)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif t == "string" then
        return '"' .. val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r') .. '"'
    elseif t == "number" then
        return string.format("%.6g", val)
    elseif t == "boolean" then
        return val and "true" or "false"
    end
    return "null"
end

local function DeserializeValue(str, pos)
    while pos <= #str and str:sub(pos, pos):match("%s") do pos = pos + 1 end
    local ch = str:sub(pos, pos)

    if ch == "{" then
        pos = pos + 1
        local result = {}
        while pos <= #str do
            while pos <= #str and str:sub(pos, pos):match("%s") do pos = pos + 1 end
            if str:sub(pos, pos) == "}" then return result, pos + 1 end
            if str:sub(pos, pos) == "," then pos = pos + 1 end
            while pos <= #str and str:sub(pos, pos):match("%s") do pos = pos + 1 end
            if str:sub(pos, pos) == "}" then return result, pos + 1 end
            local key
            key, pos = DeserializeValue(str, pos)
            while pos <= #str and str:sub(pos, pos):match("%s") do pos = pos + 1 end
            if str:sub(pos, pos) == ":" then pos = pos + 1 end
            local val
            val, pos = DeserializeValue(str, pos)
            local numKey = tonumber(key)
            result[numKey or key] = val
        end
        return result, pos

    elseif ch == '"' then
        pos = pos + 1
        local parts = {}
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c == '"' then return table.concat(parts), pos + 1
            elseif c == '\\' then
                pos = pos + 1
                local esc = str:sub(pos, pos)
                if esc == 'n' then parts[#parts + 1] = '\n'
                elseif esc == 'r' then parts[#parts + 1] = '\r'
                elseif esc == 't' then parts[#parts + 1] = '\t'
                else parts[#parts + 1] = esc end
            else
                parts[#parts + 1] = c
            end
            pos = pos + 1
        end
        return table.concat(parts), pos

    elseif ch == 't' then return true, pos + 4
    elseif ch == 'f' then return false, pos + 5
    elseif ch == 'n' then return nil, pos + 4
    else
        local start = pos
        if str:sub(pos, pos) == '-' then pos = pos + 1 end
        while pos <= #str and str:sub(pos, pos):match("[0-9]") do pos = pos + 1 end
        if pos <= #str and str:sub(pos, pos) == '.' then
            pos = pos + 1
            while pos <= #str and str:sub(pos, pos):match("[0-9]") do pos = pos + 1 end
        end
        if pos <= #str and str:sub(pos, pos):match("[eE]") then
            pos = pos + 1
            if pos <= #str and str:sub(pos, pos):match("[+-]") then pos = pos + 1 end
            while pos <= #str and str:sub(pos, pos):match("[0-9]") do pos = pos + 1 end
        end
        return tonumber(str:sub(start, pos - 1)), pos
    end
end

local function ExportSettings()
    return "!CBC1!" .. Base64Encode(SerializeValue(ChargeBarColorsDB))
end

local function ImportSettings(str)
    str = str:match("^%s*(.-)%s*$")
    if not str or str == "" then return false, "No data to import." end
    local prefix, b64 = str:match("^(!CBC%d+!)(.+)$")
    if not prefix then return false, "Invalid format – not a CBC export string." end
    local decoded = Base64Decode(b64)
    if not decoded or decoded == "" then return false, "Failed to decode data." end
    local ok, data = pcall(DeserializeValue, decoded, 1)
    if not ok or type(data) ~= "table" then return false, "Failed to parse settings data." end
    for k, v in pairs(data) do
        ChargeBarColorsDB[k] = v
    end
    local CBC = _G.ChargeBarColors
    if CBC then
        CBC.RepositionBar()
        CBC.UpdateBar()
    end
    return true, "Settings imported successfully!"
end

------------------------------------------------------------
-- WIDGET HELPERS (no templates)
------------------------------------------------------------
local function Checkbox(parent, x, y, label, checked, onClick)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    cb:SetChecked(checked)
    cb:SetScript("OnClick", function(self) onClick(self:GetChecked()) end)
    local t = cb:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    t:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    t:SetText(label)
    cb.label = t
    return cb
end

local function EditBox(parent, x, y, label, value, w, onEnter)
    local lbl = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetText(label)
    local eb = CreateFrame("EditBox", nil, parent)
    eb:SetSize(w or 55, 20)
    eb:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetText(tostring(value))
    local bg = eb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetTexture(WHITE); bg:SetVertexColor(0.12, 0.12, 0.12, 1)
    local function edge(p1, p2, horiz)
        local e = eb:CreateTexture(nil, "BORDER"); e:SetTexture(WHITE); e:SetVertexColor(0.3, 0.3, 0.3, 1)
        if horiz then e:SetHeight(1) else e:SetWidth(1) end
        e:SetPoint(p1); e:SetPoint(p2)
    end
    edge("TOPLEFT", "TOPRIGHT", true); edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    edge("TOPLEFT", "BOTTOMLEFT", false); edge("TOPRIGHT", "BOTTOMRIGHT", false)
    eb:SetScript("OnEnterPressed", function(self) onEnter(self:GetText()); self:ClearFocus() end)
    eb:SetScript("OnEditFocusLost", function(self) onEnter(self:GetText()) end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetTextInsets(4, 4, 0, 0)
    return eb, lbl
end

-- Custom slider with label, draggable thumb, AND type-in edit box
local function Slider(parent, x, y, label, minVal, maxVal, curVal, width, onChange)
    local lbl = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetText(label)

    local sliderW = width or 200
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(sliderW, 16)
    frame:SetPoint("LEFT", lbl, "RIGHT", 8, 0)

    -- Track background
    local track = frame:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(WHITE); track:SetVertexColor(0.15, 0.15, 0.15, 1)
    track:SetHeight(6); track:SetPoint("LEFT", 0, 0); track:SetPoint("RIGHT", 0, 0)

    -- Track border
    local tBorderT = frame:CreateTexture(nil, "BORDER"); tBorderT:SetTexture(WHITE); tBorderT:SetVertexColor(0.3,0.3,0.3,1)
    tBorderT:SetHeight(1); tBorderT:SetPoint("TOPLEFT", track, "TOPLEFT"); tBorderT:SetPoint("TOPRIGHT", track, "TOPRIGHT")
    local tBorderB = frame:CreateTexture(nil, "BORDER"); tBorderB:SetTexture(WHITE); tBorderB:SetVertexColor(0.3,0.3,0.3,1)
    tBorderB:SetHeight(1); tBorderB:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT"); tBorderB:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT")

    -- Thumb
    local thumb = CreateFrame("Frame", nil, frame)
    thumb:SetSize(12, 16)
    thumb:SetFrameLevel(frame:GetFrameLevel() + 2)
    local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
    thumbTex:SetAllPoints(); thumbTex:SetTexture(WHITE); thumbTex:SetVertexColor(0.4, 0.6, 0.9, 1)

    -- Editable value box (right of slider)
    local eb = CreateFrame("EditBox", nil, parent)
    eb:SetSize(50, 18)
    eb:SetPoint("LEFT", frame, "RIGHT", 6, 0)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetText(tostring(math.floor(curVal + 0.5)))
    eb:SetJustifyH("CENTER")
    local ebBg = eb:CreateTexture(nil, "BACKGROUND"); ebBg:SetAllPoints(); ebBg:SetTexture(WHITE); ebBg:SetVertexColor(0.12, 0.12, 0.12, 1)
    local function ebEdge(p1, p2, horiz)
        local e = eb:CreateTexture(nil, "BORDER"); e:SetTexture(WHITE); e:SetVertexColor(0.3, 0.3, 0.3, 1)
        if horiz then e:SetHeight(1) else e:SetWidth(1) end
        e:SetPoint(p1); e:SetPoint(p2)
    end
    ebEdge("TOPLEFT", "TOPRIGHT", true); ebEdge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    ebEdge("TOPLEFT", "BOTTOMLEFT", false); ebEdge("TOPRIGHT", "BOTTOMRIGHT", false)
    eb:SetTextInsets(4, 4, 0, 0)

    local function SetThumbFromValue(val)
        val = math.max(minVal, math.min(maxVal, val))
        local pct = (maxVal ~= minVal) and ((val - minVal) / (maxVal - minVal)) or 0
        local xOff = pct * (sliderW - 12)
        thumb:ClearAllPoints()
        thumb:SetPoint("LEFT", frame, "LEFT", xOff, 0)
        eb:SetText(tostring(math.floor(val + 0.5)))
    end
    SetThumbFromValue(curVal)

    -- Edit box submit
    eb:SetScript("OnEnterPressed", function(self)
        local n = tonumber(self:GetText())
        if n then
            n = math.max(minVal, math.min(maxVal, math.floor(n + 0.5)))
            SetThumbFromValue(n)
            onChange(n)
        end
        self:ClearFocus()
    end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Drag
    frame:EnableMouse(true)
    local dragging = false
    local function UpdateFromMouse()
        local cx = GetCursorPosition() / (parent:GetEffectiveScale() or 1)
        local fl = frame:GetLeft() or 0
        local pct = math.max(0, math.min(1, (cx - fl - 6) / (sliderW - 12)))
        local val = math.floor(minVal + pct * (maxVal - minVal) + 0.5)
        SetThumbFromValue(val)
        onChange(val)
    end
    frame:SetScript("OnMouseDown", function() dragging = true; UpdateFromMouse() end)
    frame:SetScript("OnMouseUp", function() dragging = false end)
    frame:SetScript("OnUpdate", function()
        if dragging and IsMouseButtonDown("LeftButton") then UpdateFromMouse()
        else dragging = false end
    end)

    frame._setVal = SetThumbFromValue
    return frame, lbl
end

-- Toggle button group (radio-style)
local function ToggleGroup(parent, x, y, label, options, current, onChange)
    local lbl = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetText(label)
    local btns = {}
    local bx = 0
    for _, opt in ipairs(options) do
        local btn = CreateFrame("Button", nil, parent)
        local btnW = 8 * #opt.label + 20
        btn:SetSize(btnW, 22)
        btn:SetPoint("LEFT", lbl, "RIGHT", 8 + bx, 0)
        bx = bx + btnW + 4
        local bbg = btn:CreateTexture(nil, "BACKGROUND"); bbg:SetAllPoints(); bbg:SetTexture(WHITE)
        btn._bg = bbg
        local btxt = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); btxt:SetPoint("CENTER"); btxt:SetText(opt.label)
        btn._text = btxt; btn._key = opt.key
        if opt.key == current then
            bbg:SetVertexColor(0.20, 0.35, 0.55, 1); btxt:SetTextColor(1, 1, 0.3, 1)
        else
            bbg:SetVertexColor(0.14, 0.14, 0.14, 1); btxt:SetTextColor(0.7, 0.7, 0.7, 1)
        end
        btn:SetScript("OnClick", function()
            onChange(opt.key)
            for _, b in ipairs(btns) do
                if b._key == opt.key then
                    b._bg:SetVertexColor(0.20, 0.35, 0.55, 1); b._text:SetTextColor(1, 1, 0.3, 1)
                else
                    b._bg:SetVertexColor(0.14, 0.14, 0.14, 1); b._text:SetTextColor(0.7, 0.7, 0.7, 1)
                end
            end
        end)
        btn:SetScript("OnEnter", function(self)
            if self._key ~= current then self._bg:SetVertexColor(0.20, 0.20, 0.30, 1) end
        end)
        btn:SetScript("OnLeave", function(self)
            if self._key ~= current then self._bg:SetVertexColor(0.14, 0.14, 0.14, 1) end
        end)
        table.insert(btns, btn)
    end
    return btns, lbl
end

-- Dropdown (click to open, select from list)
local function Dropdown(parent, x, y, label, options, currentKey, width, onChange)
    local lbl = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetText(label)

    local ddW = width or 180
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(ddW, 22)
    btn:SetPoint("LEFT", lbl, "RIGHT", 8, 0)

    local bbg = btn:CreateTexture(nil, "BACKGROUND"); bbg:SetAllPoints(); bbg:SetTexture(WHITE); bbg:SetVertexColor(0.12, 0.12, 0.12, 1)
    -- Border
    local function edge(p1, p2, horiz)
        local e = btn:CreateTexture(nil, "BORDER"); e:SetTexture(WHITE); e:SetVertexColor(0.3, 0.3, 0.3, 1)
        if horiz then e:SetHeight(1) else e:SetWidth(1) end
        e:SetPoint(p1); e:SetPoint(p2)
    end
    edge("TOPLEFT", "TOPRIGHT", true); edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    edge("TOPLEFT", "BOTTOMLEFT", false); edge("TOPRIGHT", "BOTTOMRIGHT", false)

    -- Arrow
    local arrow = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    arrow:SetText("v")
    arrow:SetTextColor(0.7, 0.7, 0.7, 1)

    -- Selected text
    local selText = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    selText:SetPoint("LEFT", btn, "LEFT", 6, 0)
    selText:SetPoint("RIGHT", arrow, "LEFT", -4, 0)
    selText:SetJustifyH("LEFT")
    selText:SetTextColor(1, 1, 1, 1)
    -- Find current label
    for _, opt in ipairs(options) do
        if opt.key == currentKey then selText:SetText(opt.label); break end
    end

    -- Dropdown list frame
    local listFrame = CreateFrame("Frame", nil, btn)
    listFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    listFrame:SetFrameLevel(200)
    local listH = math.min(#options * 20 + 4, 320)
    listFrame:SetSize(ddW, listH)
    listFrame:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    local lbg = listFrame:CreateTexture(nil, "BACKGROUND"); lbg:SetAllPoints(); lbg:SetTexture(WHITE); lbg:SetVertexColor(0.08, 0.08, 0.08, 0.98)
    local lbT = listFrame:CreateTexture(nil, "BORDER"); lbT:SetTexture(WHITE); lbT:SetVertexColor(0.3,0.3,0.3,1); lbT:SetHeight(1); lbT:SetPoint("TOPLEFT"); lbT:SetPoint("TOPRIGHT")
    local lbB = listFrame:CreateTexture(nil, "BORDER"); lbB:SetTexture(WHITE); lbB:SetVertexColor(0.3,0.3,0.3,1); lbB:SetHeight(1); lbB:SetPoint("BOTTOMLEFT"); lbB:SetPoint("BOTTOMRIGHT")
    local lbL = listFrame:CreateTexture(nil, "BORDER"); lbL:SetTexture(WHITE); lbL:SetVertexColor(0.3,0.3,0.3,1); lbL:SetWidth(1); lbL:SetPoint("TOPLEFT"); lbL:SetPoint("BOTTOMLEFT")
    local lbR = listFrame:CreateTexture(nil, "BORDER"); lbR:SetTexture(WHITE); lbR:SetVertexColor(0.3,0.3,0.3,1); lbR:SetWidth(1); lbR:SetPoint("TOPRIGHT"); lbR:SetPoint("BOTTOMRIGHT")

    -- Scroll if many items
    local scroll = CreateFrame("ScrollFrame", nil, listFrame)
    scroll:SetPoint("TOPLEFT", 2, -2); scroll:SetPoint("BOTTOMRIGHT", -2, 2)
    scroll:EnableMouseWheel(true)
    local scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetSize(ddW - 4, #options * 20)
    scroll:SetScrollChild(scrollChild)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxS = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0, math.min(maxS, cur - delta * 40)))
    end)

    for idx, opt in ipairs(options) do
        local item = CreateFrame("Button", nil, scrollChild)
        item:SetSize(ddW - 4, 20)
        item:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -((idx - 1) * 20))
        local ibg = item:CreateTexture(nil, "BACKGROUND"); ibg:SetAllPoints(); ibg:SetTexture(WHITE); ibg:SetVertexColor(0.08, 0.08, 0.08, 0)
        local itx = item:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); itx:SetPoint("LEFT", 6, 0); itx:SetText(opt.label)
        if opt.disabled then
            -- Separator / header — non-clickable, dimmed text
            itx:SetTextColor(0.5, 0.5, 0.3, 1)
            item:Disable()
        else
            itx:SetTextColor(0.9, 0.9, 0.9, 1)
            item:SetScript("OnEnter", function() ibg:SetVertexColor(0.20, 0.35, 0.55, 0.6) end)
            item:SetScript("OnLeave", function() ibg:SetVertexColor(0.08, 0.08, 0.08, 0) end)
            item:SetScript("OnClick", function()
                selText:SetText(opt.label)
                onChange(opt.key)
                listFrame:Hide()
            end)
        end
    end
    listFrame:Hide()

    btn:SetScript("OnClick", function()
        if listFrame:IsShown() then listFrame:Hide() else listFrame:Show() end
    end)
    -- Close dropdown when clicking elsewhere
    listFrame:SetScript("OnShow", function()
        listFrame:SetScript("OnUpdate", function()
            if not IsMouseButtonDown("LeftButton") then return end
            if listFrame:IsMouseOver() or btn:IsMouseOver() then return end
            listFrame:Hide()
        end)
    end)
    listFrame:SetScript("OnHide", function() listFrame:SetScript("OnUpdate", nil) end)

    return btn, lbl
end

------------------------------------------------------------
-- COLOR PICKER
------------------------------------------------------------
local function OpenPicker(resType, idx, swatch)
    local CBC = _G.ChargeBarColors
    if not CBC then return end
    local r, g, b = CBC.GetColor(resType, idx)
    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame.previousValues = {r = r, g = g, b = b}
    local function Apply()
        local nr, ng, nb
        if ColorPickerFrame.GetColorRGB then
            nr, ng, nb = ColorPickerFrame:GetColorRGB()
        else
            nr, ng, nb = r, g, b
        end
        CBC.SetColor(resType, idx, nr, ng, nb)
        if swatch then swatch:SetVertexColor(nr, ng, nb, 1) end
    end
    ColorPickerFrame.swatchFunc = Apply
    ColorPickerFrame.func = Apply
    ColorPickerFrame.cancelFunc = function()
        local p = ColorPickerFrame.previousValues
        CBC.SetColor(resType, idx, p.r, p.g, p.b)
        if swatch then swatch:SetVertexColor(p.r, p.g, p.b, 1) end
    end
    if ColorPickerFrame.SetColorRGB then
        ColorPickerFrame:SetColorRGB(r, g, b)
    end
    ColorPickerFrame:Show()
end

------------------------------------------------------------
-- REFRESH CHARGE COLOR BUTTONS
------------------------------------------------------------
local function RefreshColors()
    if not settingsFrame then return end
    local CBC = _G.ChargeBarColors
    if not CBC then return end
    for _, b in ipairs(colorBtns) do b:Hide(); b:SetParent(nil) end
    wipe(colorBtns)
    if not selectedRes then return end

    local resKey = selectedRes.key
    local maxC   = selectedRes.max
    local child  = settingsFrame.scrollChild
    -- Fixed inner width = panel width (820) minus padding (40)
    local innerW = 780
    local swatchW = 148
    local gap = 4
    local cols = math.max(1, math.floor(innerW / (swatchW + gap)))

    -- Resource-specific options (shown above color swatches)
    local optionsH = 0
    if not settingsFrame._ebGlowCB then
        local cbFrame = CreateFrame("CheckButton", nil, child)
        cbFrame:SetSize(22, 22)
        cbFrame:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        cbFrame:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        cbFrame:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
        cbFrame:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        local cbLabel = cbFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        cbLabel:SetPoint("LEFT", cbFrame, "RIGHT", 4, 0)
        cbLabel:SetText("Glow on Essence Burst")
        cbFrame:SetScript("OnClick", function(self)
            ChargeBarColorsDB.essenceBurstGlow = self:GetChecked()
            local cbc = _G.ChargeBarColors; if cbc then cbc.UpdateBar() end
        end)
        settingsFrame._ebGlowCB = cbFrame
    end
    if not settingsFrame._ebMarchCB then
        local cbFrame3 = CreateFrame("CheckButton", nil, child)
        cbFrame3:SetSize(22, 22)
        cbFrame3:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
        cbFrame3:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
        cbFrame3:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
        cbFrame3:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
        local cbLabel3 = cbFrame3:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        cbLabel3:SetPoint("LEFT", cbFrame3, "RIGHT", 4, 0)
        cbLabel3:SetText("Marching Ants Border")
        cbFrame3:SetScript("OnClick", function(self)
            ChargeBarColorsDB.essenceBurstMarch = self:GetChecked()
            local cbc = _G.ChargeBarColors; if cbc then cbc.UpdateBar() end
        end)
        settingsFrame._ebMarchCB = cbFrame3
    end
    -- Essence: glow/march color and speed (created once)
    if not settingsFrame._ebGlowColorBtn then
        local lbl = child:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -32)
        lbl:SetText("Glow color:")
        settingsFrame._ebGlowColorLbl = lbl
        local btn = CreateFrame("Button", nil, child)
        btn:SetSize(28, 20); btn:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
        local border = btn:CreateTexture(nil, "BACKGROUND")
        border:SetTexture(WHITE); border:SetVertexColor(0.18, 0.18, 0.18, 1)
        border:SetSize(28, 20); border:SetAllPoints(btn)
        local swatch = btn:CreateTexture(nil, "ARTWORK")
        swatch:SetTexture(WHITE); swatch:SetSize(24, 16)
        swatch:SetPoint("CENTER", btn, "CENTER")
        btn:SetScript("OnClick", function()
            local c = ChargeBarColorsDB.essenceBurstGlowColor or {r=1,g=0.85,b=0.3}
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame.previousValues = {r=c.r,g=c.g,b=c.b}
            local function applyGlow()
                local r, g, b = c.r, c.g, c.b
                if ColorPickerFrame.GetColorRGB then r, g, b = ColorPickerFrame:GetColorRGB() end
                ChargeBarColorsDB.essenceBurstGlowColor = {r=r,g=g,b=b}
                swatch:SetVertexColor(r,g,b,1)
                local cbc = _G.ChargeBarColors; if cbc then cbc.UpdateBar() end
            end
            ColorPickerFrame.swatchFunc = applyGlow
            ColorPickerFrame.func = applyGlow
            ColorPickerFrame.cancelFunc = function()
                local p = ColorPickerFrame.previousValues
                ChargeBarColorsDB.essenceBurstGlowColor = {r=p.r,g=p.g,b=p.b}
                swatch:SetVertexColor(p.r,p.g,p.b,1)
            end
            if ColorPickerFrame.SetColorRGB then ColorPickerFrame:SetColorRGB(c.r,c.g,c.b) end
            ColorPickerFrame:Show()
        end)
        settingsFrame._ebGlowColorBtn = btn
        settingsFrame._ebGlowColorSwatch = swatch
    end
    if not settingsFrame._ebMarchColorBtn then
        local lbl = child:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", child, "TOPLEFT", 230, -32)
        lbl:SetText("Ants color:")
        settingsFrame._ebMarchColorLbl = lbl
        local btn = CreateFrame("Button", nil, child)
        btn:SetSize(28, 20); btn:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
        local border = btn:CreateTexture(nil, "BACKGROUND")
        border:SetTexture(WHITE); border:SetVertexColor(0.18, 0.18, 0.18, 1)
        border:SetSize(28, 20); border:SetAllPoints(btn)
        local swatch = btn:CreateTexture(nil, "ARTWORK")
        swatch:SetTexture(WHITE); swatch:SetSize(24, 16)
        swatch:SetPoint("CENTER", btn, "CENTER")
        btn:SetScript("OnClick", function()
            local c = ChargeBarColorsDB.essenceBurstMarchColor or {r=1,g=0.85,b=0.3}
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame.previousValues = {r=c.r,g=c.g,b=c.b}
            local function applyMarch()
                local r, g, b = c.r, c.g, c.b
                if ColorPickerFrame.GetColorRGB then r, g, b = ColorPickerFrame:GetColorRGB() end
                ChargeBarColorsDB.essenceBurstMarchColor = {r=r,g=g,b=b}
                swatch:SetVertexColor(r,g,b,1)
                local cbc = _G.ChargeBarColors; if cbc then cbc.UpdateBar() end
            end
            ColorPickerFrame.swatchFunc = applyMarch
            ColorPickerFrame.func = applyMarch
            ColorPickerFrame.cancelFunc = function()
                local p = ColorPickerFrame.previousValues
                ChargeBarColorsDB.essenceBurstMarchColor = {r=p.r,g=p.g,b=p.b}
                swatch:SetVertexColor(p.r,p.g,p.b,1)
            end
            if ColorPickerFrame.SetColorRGB then ColorPickerFrame:SetColorRGB(c.r,c.g,c.b) end
            ColorPickerFrame:Show()
        end)
        settingsFrame._ebMarchColorBtn = btn
        settingsFrame._ebMarchColorSwatch = swatch
    end
    if not settingsFrame._ebGlowSpeedEB then
        local eb, lbl = EditBox(child, 4, -56, "Glow speed:", ChargeBarColorsDB.essenceBurstGlowSpeed or 4, 50, function(text)
            local n = tonumber(text)
            if n and n > 0 then
                ChargeBarColorsDB.essenceBurstGlowSpeed = n
                local cbc = _G.ChargeBarColors; if cbc then cbc.UpdateBar() end
            end
        end)
        settingsFrame._ebGlowSpeedEB = eb
        settingsFrame._ebGlowSpeedLbl = lbl
    end
    if not settingsFrame._ebMarchSpeedEB then
        local eb, lbl = EditBox(child, 230, -56, "Ants speed:", ChargeBarColorsDB.essenceBurstMarchSpeed or 0.5, 50, function(text)
            local n = tonumber(text)
            if n and n > 0 then
                ChargeBarColorsDB.essenceBurstMarchSpeed = n
                local cbc = _G.ChargeBarColors; if cbc then cbc.UpdateBar() end
            end
        end)
        settingsFrame._ebMarchSpeedEB = eb
        settingsFrame._ebMarchSpeedLbl = lbl
    end
    if resKey == "essence" then
        settingsFrame._ebGlowCB:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -4)
        settingsFrame._ebGlowCB:SetChecked(ChargeBarColorsDB.essenceBurstGlow ~= false)
        settingsFrame._ebGlowCB:Show()
        settingsFrame._ebMarchCB:SetPoint("TOPLEFT", child, "TOPLEFT", 230, -4)
        settingsFrame._ebMarchCB:SetChecked(ChargeBarColorsDB.essenceBurstMarch ~= false)
        settingsFrame._ebMarchCB:Show()
        -- Row 2: Glow color, Ants color
        local gc = ChargeBarColorsDB.essenceBurstGlowColor or {r=1,g=0.85,b=0.3}
        settingsFrame._ebGlowColorLbl:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -32)
        settingsFrame._ebGlowColorSwatch:SetVertexColor(gc.r, gc.g, gc.b, 1)
        settingsFrame._ebGlowColorBtn:Show()
        local mc = ChargeBarColorsDB.essenceBurstMarchColor or {r=1,g=0.85,b=0.3}
        settingsFrame._ebMarchColorLbl:SetPoint("TOPLEFT", child, "TOPLEFT", 230, -32)
        settingsFrame._ebMarchColorSwatch:SetVertexColor(mc.r, mc.g, mc.b, 1)
        settingsFrame._ebMarchColorBtn:Show()
        -- Row 3: Glow speed, Ants speed (number boxes)
        settingsFrame._ebGlowSpeedLbl:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -56)
        settingsFrame._ebGlowSpeedEB:SetText(tostring(ChargeBarColorsDB.essenceBurstGlowSpeed or 4))
        settingsFrame._ebGlowSpeedEB:Show()
        settingsFrame._ebMarchSpeedLbl:SetPoint("TOPLEFT", child, "TOPLEFT", 230, -56)
        settingsFrame._ebMarchSpeedEB:SetText(tostring(ChargeBarColorsDB.essenceBurstMarchSpeed or 0.5))
        settingsFrame._ebMarchSpeedEB:Show()
        settingsFrame._ebGlowColorLbl:Show()
        settingsFrame._ebMarchColorLbl:Show()
        settingsFrame._ebGlowSpeedLbl:Show()
        settingsFrame._ebMarchSpeedLbl:Show()
        optionsH = 82
    else
        settingsFrame._ebGlowCB:Hide()
        settingsFrame._ebMarchCB:Hide()
        settingsFrame._ebGlowColorBtn:Hide()
        settingsFrame._ebMarchColorBtn:Hide()
        settingsFrame._ebGlowSpeedEB:Hide()
        settingsFrame._ebMarchSpeedEB:Hide()
        settingsFrame._ebGlowColorLbl:Hide()
        settingsFrame._ebMarchColorLbl:Hide()
        settingsFrame._ebGlowSpeedLbl:Hide()
        settingsFrame._ebMarchSpeedLbl:Hide()
    end

    local rows = math.ceil(maxC / cols)
    child:SetSize(innerW, rows * 36 + 12 + optionsH)

    for i = 1, maxC do
        local btn = CreateFrame("Button", nil, child)
        btn:SetSize(swatchW, 28)
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        btn:SetPoint("TOPLEFT", child, "TOPLEFT", 4 + col * (swatchW + gap), -(4 + row * 34 + optionsH))

        local swBorder = btn:CreateTexture(nil, "BACKGROUND")
        swBorder:SetTexture(WHITE); swBorder:SetVertexColor(0.18, 0.18, 0.18, 1)
        swBorder:SetSize(28, 28); swBorder:SetPoint("LEFT", btn, "LEFT", 0, 0)

        local swatch = btn:CreateTexture(nil, "ARTWORK")
        swatch:SetTexture(WHITE); swatch:SetSize(24, 24)
        swatch:SetPoint("CENTER", swBorder, "CENTER", 0, 0)
        local cr, cg, cb = CBC.GetColor(resKey, i)
        swatch:SetVertexColor(cr, cg, cb, 1)

        local lbl = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        lbl:SetPoint("LEFT", swBorder, "RIGHT", 6, 0)
        lbl:SetText("Charge " .. i)
        lbl:SetTextColor(1, 1, 1, 1)

        btn:SetScript("OnClick", function() OpenPicker(resKey, i, swatch) end)
        btn:SetScript("OnEnter", function() swBorder:SetVertexColor(0.5, 0.5, 0.5, 1) end)
        btn:SetScript("OnLeave", function() swBorder:SetVertexColor(0.18, 0.18, 0.18, 1) end)
        btn:Show()
        table.insert(colorBtns, btn)
    end
end

------------------------------------------------------------
-- IMPORT / EXPORT POPUP
------------------------------------------------------------
local ieFrame = nil

local function ShowImportExport(mode)
    if not ieFrame then
        local f = CreateFrame("Frame", "CBCImportExport", UIParent)
        f:SetSize(600, 400)
        f:SetPoint("CENTER")
        f:SetMovable(true); f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetClampedToScreen(true)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetFrameLevel(200)

        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(WHITE); bg:SetVertexColor(0.05, 0.05, 0.05, 0.97); bg:SetAllPoints()
        local bT = f:CreateTexture(nil, "BORDER"); bT:SetTexture(WHITE); bT:SetVertexColor(0.35,0.35,0.35,1); bT:SetHeight(2); bT:SetPoint("TOPLEFT"); bT:SetPoint("TOPRIGHT")
        local bB = f:CreateTexture(nil, "BORDER"); bB:SetTexture(WHITE); bB:SetVertexColor(0.35,0.35,0.35,1); bB:SetHeight(2); bB:SetPoint("BOTTOMLEFT"); bB:SetPoint("BOTTOMRIGHT")
        local bL = f:CreateTexture(nil, "BORDER"); bL:SetTexture(WHITE); bL:SetVertexColor(0.35,0.35,0.35,1); bL:SetWidth(2); bL:SetPoint("TOPLEFT"); bL:SetPoint("BOTTOMLEFT")
        local bR = f:CreateTexture(nil, "BORDER"); bR:SetTexture(WHITE); bR:SetVertexColor(0.35,0.35,0.35,1); bR:SetWidth(2); bR:SetPoint("TOPRIGHT"); bR:SetPoint("BOTTOMRIGHT")

        local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -14)
        f.titleText = title

        local closeX = CreateFrame("Button", nil, f)
        closeX:SetSize(20, 20); closeX:SetPoint("TOPRIGHT", -6, -6)
        local cTxt = closeX:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        cTxt:SetPoint("CENTER"); cTxt:SetText("X"); cTxt:SetTextColor(0.8, 0.2, 0.2, 1)
        closeX:SetScript("OnClick", function() f:Hide() end)
        closeX:SetScript("OnEnter", function() cTxt:SetTextColor(1, 0.4, 0.4, 1) end)
        closeX:SetScript("OnLeave", function() cTxt:SetTextColor(0.8, 0.2, 0.2, 1) end)

        local sf = CreateFrame("ScrollFrame", nil, f)
        sf:SetPoint("TOPLEFT", 16, -40)
        sf:SetPoint("BOTTOMRIGHT", -16, 50)
        sf:EnableMouseWheel(true)
        sf:SetScript("OnMouseWheel", function(self, delta)
            local cur = self:GetVerticalScroll()
            local mx = self:GetVerticalScrollRange() or 0
            self:SetVerticalScroll(math.max(0, math.min(mx, cur - delta * 30)))
        end)
        local sfBg = sf:CreateTexture(nil, "BACKGROUND")
        sfBg:SetTexture(WHITE); sfBg:SetVertexColor(0.08, 0.08, 0.08, 1); sfBg:SetAllPoints()
        local sfBorderT = sf:CreateTexture(nil, "BORDER"); sfBorderT:SetTexture(WHITE); sfBorderT:SetVertexColor(0.3,0.3,0.3,1); sfBorderT:SetHeight(1); sfBorderT:SetPoint("TOPLEFT"); sfBorderT:SetPoint("TOPRIGHT")
        local sfBorderB = sf:CreateTexture(nil, "BORDER"); sfBorderB:SetTexture(WHITE); sfBorderB:SetVertexColor(0.3,0.3,0.3,1); sfBorderB:SetHeight(1); sfBorderB:SetPoint("BOTTOMLEFT"); sfBorderB:SetPoint("BOTTOMRIGHT")
        local sfBorderL = sf:CreateTexture(nil, "BORDER"); sfBorderL:SetTexture(WHITE); sfBorderL:SetVertexColor(0.3,0.3,0.3,1); sfBorderL:SetWidth(1); sfBorderL:SetPoint("TOPLEFT"); sfBorderL:SetPoint("BOTTOMLEFT")
        local sfBorderR = sf:CreateTexture(nil, "BORDER"); sfBorderR:SetTexture(WHITE); sfBorderR:SetVertexColor(0.3,0.3,0.3,1); sfBorderR:SetWidth(1); sfBorderR:SetPoint("TOPRIGHT"); sfBorderR:SetPoint("BOTTOMRIGHT")

        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(560)
        eb:SetTextInsets(8, 8, 4, 4)
        sf:SetScrollChild(eb)
        eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        eb:SetScript("OnCursorChanged", function(self, _, y, _, cursorH)
            local vs = sf:GetVerticalScroll()
            local h = sf:GetHeight()
            y = -y
            if y < vs then sf:SetVerticalScroll(y)
            elseif y + cursorH > vs + h then sf:SetVerticalScroll(y + cursorH - h) end
        end)
        f.editBox = eb

        local applyBtn = CreateFrame("Button", nil, f)
        applyBtn:SetSize(100, 28); applyBtn:SetPoint("BOTTOMRIGHT", -130, 12)
        local aBg = applyBtn:CreateTexture(nil, "BACKGROUND"); aBg:SetAllPoints(); aBg:SetTexture(WHITE); aBg:SetVertexColor(0.15, 0.35, 0.15, 1)
        local aTxt = applyBtn:CreateFontString(nil, "ARTWORK", "GameFontNormal"); aTxt:SetPoint("CENTER"); aTxt:SetText("Apply")
        applyBtn:SetScript("OnEnter", function() aBg:SetVertexColor(0.20, 0.45, 0.20, 1) end)
        applyBtn:SetScript("OnLeave", function() aBg:SetVertexColor(0.15, 0.35, 0.15, 1) end)
        applyBtn:SetScript("OnClick", function()
            local text = f.editBox:GetText()
            local success, msg = ImportSettings(text)
            f.status:SetText(msg)
            if success then
                f.status:SetTextColor(0.3, 1, 0.3, 1)
                if settingsFrame then settingsFrame:Hide(); settingsFrame = nil end
                C_Timer.After(1.0, function()
                    f:Hide()
                    SlashCmdList["CBC"]()
                end)
            else
                f.status:SetTextColor(1, 0.3, 0.3, 1)
            end
        end)
        f.applyBtn = applyBtn

        local closeBtn = CreateFrame("Button", nil, f)
        closeBtn:SetSize(100, 28); closeBtn:SetPoint("BOTTOMRIGHT", -16, 12)
        local clBg = closeBtn:CreateTexture(nil, "BACKGROUND"); clBg:SetAllPoints(); clBg:SetTexture(WHITE); clBg:SetVertexColor(0.25, 0.25, 0.25, 1)
        local clTxt = closeBtn:CreateFontString(nil, "ARTWORK", "GameFontNormal"); clTxt:SetPoint("CENTER"); clTxt:SetText("Close")
        closeBtn:SetScript("OnClick", function() f:Hide() end)
        closeBtn:SetScript("OnEnter", function() clBg:SetVertexColor(0.35, 0.35, 0.35, 1) end)
        closeBtn:SetScript("OnLeave", function() clBg:SetVertexColor(0.25, 0.25, 0.25, 1) end)

        local status = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        status:SetPoint("BOTTOMLEFT", 16, 18)
        status:SetTextColor(0.7, 0.7, 0.7, 1)
        f.status = status

        ieFrame = f
    end

    ieFrame.status:SetText("")
    if mode == "export" then
        ieFrame.titleText:SetText("|cFF00FF00Export Settings|r")
        ieFrame.editBox:SetText(ExportSettings())
        ieFrame.editBox:HighlightText()
        ieFrame.editBox:SetFocus()
        ieFrame.applyBtn:Hide()
        ieFrame.status:SetText("Press Ctrl+C to copy, then share the string.")
        ieFrame.status:SetTextColor(0.7, 0.7, 0.7, 1)
    else
        ieFrame.titleText:SetText("|cFF00FF00Import Settings|r")
        ieFrame.editBox:SetText("")
        ieFrame.editBox:SetFocus()
        ieFrame.applyBtn:Show()
        ieFrame.status:SetText("Paste an export string above, then click Apply.")
        ieFrame.status:SetTextColor(0.7, 0.7, 0.7, 1)
    end
    ieFrame:Show()
end

------------------------------------------------------------
-- SETTINGS FRAME
------------------------------------------------------------
local function CreateSettings()
    if settingsFrame then return settingsFrame end

    local f = CreateFrame("Frame", "CBCSettings", UIParent)
    f:SetSize(820, 740)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)

    -- Manual backdrop
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(WHITE); bg:SetVertexColor(0.05, 0.05, 0.05, 0.97); bg:SetAllPoints()

    local borderT = f:CreateTexture(nil, "BORDER"); borderT:SetTexture(WHITE); borderT:SetVertexColor(0.35,0.35,0.35,1)
    borderT:SetHeight(2); borderT:SetPoint("TOPLEFT"); borderT:SetPoint("TOPRIGHT")
    local borderB = f:CreateTexture(nil, "BORDER"); borderB:SetTexture(WHITE); borderB:SetVertexColor(0.35,0.35,0.35,1)
    borderB:SetHeight(2); borderB:SetPoint("BOTTOMLEFT"); borderB:SetPoint("BOTTOMRIGHT")
    local borderL = f:CreateTexture(nil, "BORDER"); borderL:SetTexture(WHITE); borderL:SetVertexColor(0.35,0.35,0.35,1)
    borderL:SetWidth(2); borderL:SetPoint("TOPLEFT"); borderL:SetPoint("BOTTOMLEFT")
    local borderR = f:CreateTexture(nil, "BORDER"); borderR:SetTexture(WHITE); borderR:SetVertexColor(0.35,0.35,0.35,1)
    borderR:SetWidth(2); borderR:SetPoint("TOPRIGHT"); borderR:SetPoint("BOTTOMRIGHT")

    -- Title
    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("|cFF00FF00Charge Bar Colors|r")

    -- Close button
    local close = CreateFrame("Button", nil, f)
    close:SetSize(20, 20); close:SetPoint("TOPRIGHT", -6, -6)
    local closeTxt = close:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    closeTxt:SetPoint("CENTER"); closeTxt:SetText("X"); closeTxt:SetTextColor(0.8, 0.2, 0.2, 1)
    close:SetScript("OnClick", function() f:Hide() end)
    close:SetScript("OnEnter", function() closeTxt:SetTextColor(1, 0.4, 0.4, 1) end)
    close:SetScript("OnLeave", function() closeTxt:SetTextColor(0.8, 0.2, 0.2, 1) end)

    -- Export button
    local exportBtn = CreateFrame("Button", nil, f)
    exportBtn:SetSize(70, 22); exportBtn:SetPoint("RIGHT", close, "LEFT", -10, 0)
    local exBg = exportBtn:CreateTexture(nil, "BACKGROUND"); exBg:SetAllPoints(); exBg:SetTexture(WHITE); exBg:SetVertexColor(0.14, 0.14, 0.14, 1)
    local exTxt = exportBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); exTxt:SetPoint("CENTER"); exTxt:SetText("Export"); exTxt:SetTextColor(0.7, 0.7, 0.7, 1)
    exportBtn:SetScript("OnClick", function() ShowImportExport("export") end)
    exportBtn:SetScript("OnEnter", function() exBg:SetVertexColor(0.20, 0.35, 0.55, 1); exTxt:SetTextColor(1, 1, 1, 1) end)
    exportBtn:SetScript("OnLeave", function() exBg:SetVertexColor(0.14, 0.14, 0.14, 1); exTxt:SetTextColor(0.7, 0.7, 0.7, 1) end)
    local function exEdge(p1, p2, horiz)
        local e = exportBtn:CreateTexture(nil, "BORDER"); e:SetTexture(WHITE); e:SetVertexColor(0.3,0.3,0.3,1)
        if horiz then e:SetHeight(1) else e:SetWidth(1) end; e:SetPoint(p1); e:SetPoint(p2)
    end
    exEdge("TOPLEFT", "TOPRIGHT", true); exEdge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    exEdge("TOPLEFT", "BOTTOMLEFT", false); exEdge("TOPRIGHT", "BOTTOMRIGHT", false)

    -- Import button
    local importBtn = CreateFrame("Button", nil, f)
    importBtn:SetSize(70, 22); importBtn:SetPoint("RIGHT", exportBtn, "LEFT", -6, 0)
    local imBg = importBtn:CreateTexture(nil, "BACKGROUND"); imBg:SetAllPoints(); imBg:SetTexture(WHITE); imBg:SetVertexColor(0.14, 0.14, 0.14, 1)
    local imTxt = importBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); imTxt:SetPoint("CENTER"); imTxt:SetText("Import"); imTxt:SetTextColor(0.7, 0.7, 0.7, 1)
    importBtn:SetScript("OnClick", function() ShowImportExport("import") end)
    importBtn:SetScript("OnEnter", function() imBg:SetVertexColor(0.20, 0.35, 0.55, 1); imTxt:SetTextColor(1, 1, 1, 1) end)
    importBtn:SetScript("OnLeave", function() imBg:SetVertexColor(0.14, 0.14, 0.14, 1); imTxt:SetTextColor(0.7, 0.7, 0.7, 1) end)
    local function imEdge(p1, p2, horiz)
        local e = importBtn:CreateTexture(nil, "BORDER"); e:SetTexture(WHITE); e:SetVertexColor(0.3,0.3,0.3,1)
        if horiz then e:SetHeight(1) else e:SetWidth(1) end; e:SetPoint(p1); e:SetPoint(p2)
    end
    imEdge("TOPLEFT", "TOPRIGHT", true); imEdge("BOTTOMLEFT", "BOTTOMRIGHT", true)
    imEdge("TOPLEFT", "BOTTOMLEFT", false); imEdge("TOPRIGHT", "BOTTOMRIGHT", false)

    local y = -44

    -- ============ ROW: Enable / Lock ============
    Checkbox(f, 16, y, "Enable Addon", ChargeBarColorsDB.enabled ~= false, function(v)
        ChargeBarColorsDB.enabled = v
    end)
    y = y - 26

    Checkbox(f, 16, y, "Show Custom Charge Bar", ChargeBarColorsDB.customBar.enabled, function(v)
        ChargeBarColorsDB.customBar.enabled = v
        local CBC = _G.ChargeBarColors; if CBC then CBC.UpdateBar() end
    end)
    Checkbox(f, 280, y, "Lock Bar Position", ChargeBarColorsDB.customBar.locked or false, function(v)
        ChargeBarColorsDB.customBar.locked = v
    end)
    y = y - 26

    -- ============ ROW: Show Text + Text Color ============
    Checkbox(f, 16, y, "Show Charge Count", ChargeBarColorsDB.customBar.showText ~= false, function(v)
        ChargeBarColorsDB.customBar.showText = v
        local CBC = _G.ChargeBarColors; if CBC then CBC.UpdateBar() end
    end)

    local tcLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    tcLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 230, y + 2); tcLabel:SetText("Text Color:")
    local tcBorder = f:CreateTexture(nil, "BACKGROUND")
    tcBorder:SetTexture(WHITE); tcBorder:SetVertexColor(0.18, 0.18, 0.18, 1)
    tcBorder:SetSize(28, 20); tcBorder:SetPoint("LEFT", tcLabel, "RIGHT", 6, 0); tcBorder:SetParent(f)
    local tcSwatch = f:CreateTexture(nil, "ARTWORK")
    tcSwatch:SetTexture(WHITE); tcSwatch:SetSize(24, 16)
    tcSwatch:SetPoint("CENTER", tcBorder, "CENTER", 0, 0)
    local tc = ChargeBarColorsDB.customBar.textColor or {r = 1, g = 1, b = 1}
    tcSwatch:SetVertexColor(tc.r, tc.g, tc.b, 1)
    local tcBtn = CreateFrame("Button", nil, f)
    tcBtn:SetSize(28, 20); tcBtn:SetPoint("CENTER", tcBorder, "CENTER", 0, 0)
    tcBtn:SetScript("OnEnter", function() tcBorder:SetVertexColor(0.5, 0.5, 0.5, 1) end)
    tcBtn:SetScript("OnLeave", function() tcBorder:SetVertexColor(0.18, 0.18, 0.18, 1) end)
    tcBtn:SetScript("OnClick", function()
        local cur = ChargeBarColorsDB.customBar.textColor or {r = 1, g = 1, b = 1}
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = {r = cur.r, g = cur.g, b = cur.b}
        local function ApplyTextColor()
            local nr, ng, nb
            if ColorPickerFrame.GetColorRGB then nr, ng, nb = ColorPickerFrame:GetColorRGB()
            else nr, ng, nb = cur.r, cur.g, cur.b end
            ChargeBarColorsDB.customBar.textColor = {r = nr, g = ng, b = nb}
            tcSwatch:SetVertexColor(nr, ng, nb, 1)
            local CBC = _G.ChargeBarColors; if CBC then CBC.UpdateBar() end
        end
        ColorPickerFrame.swatchFunc = ApplyTextColor
        ColorPickerFrame.func = ApplyTextColor
        ColorPickerFrame.cancelFunc = function()
            local p = ColorPickerFrame.previousValues
            ChargeBarColorsDB.customBar.textColor = {r = p.r, g = p.g, b = p.b}
            tcSwatch:SetVertexColor(p.r, p.g, p.b, 1)
            local CBC = _G.ChargeBarColors; if CBC then CBC.UpdateBar() end
        end
        if ColorPickerFrame.SetColorRGB then ColorPickerFrame:SetColorRGB(cur.r, cur.g, cur.b) end
        ColorPickerFrame:Show()
    end)

    -- Text Size slider (same row, right of text color)
    Slider(f, 400, y, "Text Size:", 8, 40,
        ChargeBarColorsDB.customBar.textSize or 16, 160, function(val)
        ChargeBarColorsDB.customBar.textSize = val
        local CBC = _G.ChargeBarColors; if CBC then CBC.UpdateBar() end
    end)
    y = y - 30

    -- ============ ROW: Scale / Width / Height / Gap ============
    EditBox(f, 16, y, "Scale:", ChargeBarColorsDB.customBar.scale or 1.0, 40, function(v)
        local n = tonumber(v); if n then ChargeBarColorsDB.customBar.scale = math.max(0.3, math.min(3, n)) end
        local CBC = _G.ChargeBarColors; if CBC then CBC.UpdateBar() end
    end)
    EditBox(f, 160, y, "Width:", ChargeBarColorsDB.customBar.width or 220, 45, function(v)
        local n = tonumber(v); if n then ChargeBarColorsDB.customBar.width = math.max(50, math.min(1000, n)) end
        local CBC = _G.ChargeBarColors; if CBC then CBC.UpdateBar() end
    end)
    EditBox(f, 320, y, "Height:", ChargeBarColorsDB.customBar.height or 28, 40, function(v)
        local n = tonumber(v); if n then ChargeBarColorsDB.customBar.height = math.max(8, math.min(200, n)) end
        local CBC = _G.ChargeBarColors; if CBC then CBC.UpdateBar() end
    end)
    EditBox(f, 480, y, "Gap:", ChargeBarColorsDB.customBar.spacing or 2, 35, function(v)
        local n = tonumber(v); if n then ChargeBarColorsDB.customBar.spacing = math.max(0, math.min(20, n)) end
        local CBC = _G.ChargeBarColors; if CBC then CBC.UpdateBar() end
    end)
    y = y - 28

    -- ============ ROW: X Position Slider ============
    local screenW = math.floor(GetScreenWidth() / 2)
    Slider(f, 16, y, "X Pos:", -screenW, screenW,
        math.floor((ChargeBarColorsDB.customBar.x or 0) + 0.5), 250, function(val)
        ChargeBarColorsDB.customBar.x = val
        local CBC = _G.ChargeBarColors; if CBC then CBC.RepositionBar(); CBC.UpdateBar() end
    end)

    -- Strata (same row, right side)
    local strataCurrent = ChargeBarColorsDB.customBar.strata or "MEDIUM"
    ToggleGroup(f, 470, y, "Strata:", {
        {key = "BACKGROUND", label = "BG"},
        {key = "LOW",        label = "Low"},
        {key = "MEDIUM",     label = "Med"},
        {key = "HIGH",       label = "High"},
        {key = "DIALOG",     label = "Dlg"},
    }, strataCurrent, function(k)
        ChargeBarColorsDB.customBar.strata = k
        local CBC = _G.ChargeBarColors; if CBC then CBC.UpdateBar() end
    end)
    y = y - 26

    -- ============ ROW: Y Position Slider ============
    local screenH = math.floor(GetScreenHeight() / 2)
    Slider(f, 16, y, "Y Pos:", -screenH, screenH,
        math.floor((ChargeBarColorsDB.customBar.y or -100) + 0.5), 250, function(val)
        ChargeBarColorsDB.customBar.y = val
        local CBC = _G.ChargeBarColors; if CBC then CBC.RepositionBar(); CBC.UpdateBar() end
    end)
    y = y - 28

    -- ============ ROW: Texture Dropdown ============
    Dropdown(f, 16, y, "Texture:", BuildTextureList(), ChargeBarColorsDB.customBar.texture or "flat", 220, function(k)
        ChargeBarColorsDB.customBar.texture = k
        local CBC = _G.ChargeBarColors; if CBC then CBC.UpdateBar() end
    end)
    y = y - 28

    -- ============ ROW: Depleted Style ============
    ToggleGroup(f, 16, y, "Depleted:", {
        {key = "faded", label = "Faded"},
        {key = "black", label = "Black"},
    }, ChargeBarColorsDB.customBar.depletedStyle or "faded", function(k)
        ChargeBarColorsDB.customBar.depletedStyle = k
        local CBC = _G.ChargeBarColors; if CBC then CBC.UpdateBar() end
    end)

    -- Refill (same row, right side)
    ToggleGroup(f, 340, y, "Refill:", {
        {key = "static", label = "Static"},
        {key = "fill",   label = "Fill L->R"},
        {key = "fillrl", label = "Fill R->L"},
    }, ChargeBarColorsDB.customBar.refillStyle or "static", function(k)
        ChargeBarColorsDB.customBar.refillStyle = k
        local CBC = _G.ChargeBarColors; if CBC then CBC.UpdateBar() end
    end)
    y = y - 30

    -- ============ SEPARATOR ============
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetTexture(WHITE); sep:SetVertexColor(0.3, 0.3, 0.3, 1)
    sep:SetSize(780, 1); sep:SetPoint("TOPLEFT", f, "TOPLEFT", 16, y)
    y = y - 12

    -- ============ Per-Charge Colors ============
    local colTitle = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    colTitle:SetPoint("TOPLEFT", f, "TOPLEFT", 16, y)
    colTitle:SetText("Per-Charge Colors  (click swatch to change)")
    y = y - 22

    -- Resource type tabs (use shorter labels to fit in one row)
    local TAB_LABELS = {
        combo = "Combo", chi = "Chi", holypower = "Holy", soulshards = "Shards",
        rune = "Runes", essence = "Essence", whirlwind = "WW",
        arcanecharges = "Arcane", maelstrom = "Mael", soulfragments = "Soul Frag",
        tipofthespear = "TotS",
    }
    local tabFrames = {}
    local tabX = 16
    local tabY = y
    for _, res in ipairs(RES_LIST) do
        local tab = CreateFrame("Button", nil, f)
        local shortName = TAB_LABELS[res.key] or res.name
        local tw = 6 * #shortName + 16
        tab:SetSize(tw, 20)
        tab:SetPoint("TOPLEFT", f, "TOPLEFT", tabX, tabY)
        local tbg = tab:CreateTexture(nil, "BACKGROUND"); tbg:SetAllPoints(); tbg:SetTexture(WHITE)
        tab._bg = tbg
        local ttx = tab:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall"); ttx:SetPoint("CENTER"); ttx:SetText(shortName)
        tab._text = ttx; tab._res = res
        tbg:SetVertexColor(0.14, 0.14, 0.14, 1); ttx:SetTextColor(0.7, 0.7, 0.7, 1)
        tab:SetScript("OnClick", function()
            selectedRes = res
            for _, t in ipairs(tabFrames) do
                t._bg:SetVertexColor(0.14, 0.14, 0.14, 1); t._text:SetTextColor(0.7, 0.7, 0.7, 1)
            end
            tbg:SetVertexColor(0.20, 0.35, 0.55, 1); ttx:SetTextColor(1, 1, 0.3, 1)
            RefreshColors()
        end)
        tab:SetScript("OnEnter", function(self)
            if self._res ~= selectedRes then self._bg:SetVertexColor(0.20, 0.20, 0.30, 1) end
        end)
        tab:SetScript("OnLeave", function(self)
            if self._res ~= selectedRes then self._bg:SetVertexColor(0.14, 0.14, 0.14, 1) end
        end)
        table.insert(tabFrames, tab)
        tabX = tabX + tw + 3
        if tabX > 790 then tabX = 16; tabY = tabY - 24 end
    end
    y = tabY - 28

    -- Scroll area for charge swatches
    local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 10, y)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0, math.min(maxScroll, cur - (delta * 30))))
    end)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(780, 200)
    scroll:SetScrollChild(child)
    f.scrollChild = child

    -- Auto-select current class resource
    local CBC = _G.ChargeBarColors
    if CBC then
        local cur = CBC.GetResource()
        if cur then
            for i, res in ipairs(RES_LIST) do
                if res.key == cur then
                    selectedRes = res
                    if tabFrames[i] then
                        tabFrames[i]._bg:SetVertexColor(0.20, 0.35, 0.55, 1)
                        tabFrames[i]._text:SetTextColor(1, 1, 0.3, 1)
                    end
                    break
                end
            end
        end
    end
    if not selectedRes then
        selectedRes = RES_LIST[1]
        if tabFrames[1] then
            tabFrames[1]._bg:SetVertexColor(0.20, 0.35, 0.55, 1)
            tabFrames[1]._text:SetTextColor(1, 1, 0.3, 1)
        end
    end

    f:SetScript("OnShow", RefreshColors)
    settingsFrame = f
    f:Hide()
    return f
end

------------------------------------------------------------
-- SLASH COMMANDS
------------------------------------------------------------
SLASH_CBC1 = "/cbc"
SLASH_CBC2 = "/chargecolors"
SlashCmdList["CBC"] = function()
    local f = CreateSettings()
    if f:IsShown() then f:Hide() else RefreshColors(); f:Show() end
end

-- Settings are opened via /cbc command only (no Blizzard Settings API to avoid taint)
