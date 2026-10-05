-- SavedVariables initialization
BiggestHitsDB = BiggestHitsDB or {}
BiggestHitsUIState = BiggestHitsUIState or { collapsedChars = {}, collapsedCats = {}, width = 420, height = 480 }

local playerFullName = ""
local mainFrame = nil

-- Order of display for sub-categories
local CATEGORY_ORDER = {
    { key = "DIRECT_DMG", name = "Direct Damage", color = "|cffff4444", showCrit = true },
    { key = "DOT_DMG",    name = "DoT Damage",    color = "|cffffaa44", showCrit = false },
    { key = "HEAL",       name = "Direct Healing", color = "|cff44ff44", showCrit = true },
    { key = "HOT",        name = "HoT Healing",    color = "|cff88ffff", showCrit = false },
}

----------------------------------------------------
-- 1. HELPER & DATA HANDLING
----------------------------------------------------
local function GetPlayerKey()
    if not playerFullName or playerFullName == "" then
        local name, realm = UnitName("player"), GetRealmName()
        if name and realm and name ~= "" and realm ~= "" then
            playerFullName = name .. " - " .. realm
        else
            playerFullName = "Unknown Character"
        end
    end
    return playerFullName
end

local function ClearStoredData(allCharacters)
    if allCharacters then
        BiggestHitsDB = {}
        print("|cffffd100[BiggestHits]|r All stored records have been cleared.")
    else
        local charKey = GetPlayerKey()
        BiggestHitsDB[charKey] = nil
        print("|cffffd100[BiggestHits]|r Records cleared for |cffffffff" .. charKey .. "|r.")
    end

    if mainFrame and mainFrame:IsShown() then
        mainFrame:UpdateList()
    end
end

----------------------------------------------------
-- 2. CONFIRMATION DIALOG SETUP
----------------------------------------------------
StaticPopupDialogs["BIGGESTHITS_CONFIRM_CLEAR"] = {
    text = "Are you sure you want to clear stored records?",
    button1 = "Current Char",
    button2 = "Cancel",
    button3 = "All Chars",
    OnAccept = function()
        ClearStoredData(false)
    end,
    OnAlt = function()
        ClearStoredData(true)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

----------------------------------------------------
-- 3. UI DISPLAY FRAME
----------------------------------------------------
local function CreateTrackerUI()
    if mainFrame then return mainFrame end

    local f = CreateFrame("Frame", "BiggestHitsFrame", UIParent, "BackdropTemplate")
    
    -- Load saved dimensions or use default min size
    local savedWidth = math.max(BiggestHitsUIState.width or 420, 320)
    local savedHeight = math.max(BiggestHitsUIState.height or 480, 250)
    f:SetSize(savedWidth, savedHeight)

    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()

    -- Enable ESC key to close window
    tinsert(UISpecialFrames, "BiggestHitsFrame")

    -- Enable Resizing
    f:SetResizable(true)
    f:SetMinResize(320, 250)
    f:SetMaxResize(800, 1000)

    local resizeButton = CreateFrame("Button", nil, f)
    resizeButton:SetSize(16, 16)
    resizeButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)
    resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    resizeButton:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            f:StartSizing("BOTTOMRIGHT")
        end
    end)

    resizeButton:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            f:StopMovingOrSizing()
            BiggestHitsUIState.width = f:GetWidth()
            BiggestHitsUIState.height = f:GetHeight()
            if f.UpdateList then
                f:UpdateList()
            end
        end
    end)

    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    -- Header Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", f, "TOP", 0, -18)
    title:SetText("Biggest Hits")

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)

    -- Clear Data Button
    local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    clearBtn:SetSize(90, 22)
    clearBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -25, 15)
    clearBtn:SetText("Clear Data")
    clearBtn:SetScript("OnClick", function()
        StaticPopup_Show("BIGGESTHITS_CONFIRM_CLEAR")
    end)

    -- Scroll Area Setup
    local scrollFrame = CreateFrame("ScrollFrame", "BiggestHitsScrollFrame", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -50)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -35, 45)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(355, 1)
    scrollFrame:SetScrollChild(scrollChild)

    f.scrollChild = scrollChild
    f.rowPool = {}

    -- Helper to get or create a row frame
    local function GetRow(index)
        if not f.rowPool[index] then
            local row = CreateFrame("Frame", nil, f.scrollChild)
            row:SetHeight(24)

            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.text:SetPoint("LEFT", row, "LEFT", 0, 0)

            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(20, 20)
            row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)

            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
            row.nameText:SetJustifyH("LEFT")

            row.valText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.valText:SetPoint("RIGHT", row, "RIGHT", -5, 0)
            row.valText:SetJustifyH("RIGHT")

            row.clickBtn = CreateFrame("Button", nil, row)
            row.clickBtn:SetAllPoints(row)

            f.rowPool[index] = row
        end

        local row = f.rowPool[index]
        row.text:Hide()
        row.text:SetText("")
        row.icon:Hide()
        row.nameText:Hide()
        row.nameText:SetText("")
        row.valText:Hide()
        row.valText:SetText("")
        row.clickBtn:Hide()
        row.clickBtn:SetScript("OnClick", nil)
        row:Hide()

        return row
    end

    -- Render/Update List Content
    function f:UpdateList()
        local contentWidth = scrollFrame:GetWidth() - 10
        scrollChild:SetWidth(contentWidth)

        -- Hide all existing frame objects in pool
        for _, row in ipairs(self.rowPool) do
            row.text:Hide()
            row.icon:Hide()
            row.nameText:Hide()
            row.valText:Hide()
            row.clickBtn:Hide()
            row.clickBtn:SetScript("OnClick", nil)
            row:Hide()
        end

        local yOffset = 5
        local rowIndex = 1
        local hasEntries = false

        for charName, records in pairs(BiggestHitsDB) do
            if records and next(records) ~= nil then
                hasEntries = true

                local isCharCollapsed = BiggestHitsUIState.collapsedChars[charName]

                -- 1. Character Header
                local header = GetRow(rowIndex)
                header:SetSize(contentWidth, 22)
                header:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, -yOffset)

                local charPrefix = isCharCollapsed and "[+] " or "[-] "
                header.text:SetFontObject("GameFontNormal")
                header.text:SetText("|cffffd100" .. charPrefix .. "=== " .. charName .. " ===|r")
                header.text:Show()
                
                header.clickBtn:SetScript("OnClick", function()
                    BiggestHitsUIState.collapsedChars[charName] = not isCharCollapsed
                    f:UpdateList()
                end)
                header.clickBtn:Show()
                header:Show()

                rowIndex = rowIndex + 1
                yOffset = yOffset + 24

                -- Render categories and spells only if character is expanded
                if not isCharCollapsed then
                    local grouped = { DIRECT_DMG = {}, DOT_DMG = {}, HEAL = {}, HOT = {} }
                    for recKey, data in pairs(records) do
                        if type(data) == "table" then
                            local cat = data.category or "DIRECT_DMG"
                            if not grouped[cat] then grouped[cat] = {} end
                            table.insert(grouped[cat], data)
                        end
                    end

                    -- 2. Sub-Category Render
                    for _, catDef in ipairs(CATEGORY_ORDER) do
                        local list = grouped[catDef.key]
                        if list and #list > 0 then
                            local catStateKey = charName .. "_" .. catDef.key
                            local isCatCollapsed = BiggestHitsUIState.collapsedCats[catStateKey]

                            local subHeader = GetRow(rowIndex)
                            subHeader:SetSize(contentWidth - 10, 20)
                            subHeader:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 10, -yOffset)

                            local catPrefix = isCatCollapsed and "[+] " or "[-] "
                            subHeader.text:SetFontObject("GameFontNormalSmall")
                            subHeader.text:SetText(catDef.color .. catPrefix .. catDef.name .. "|r")
                            subHeader.text:Show()

                            subHeader.clickBtn:SetScript("OnClick", function()
                                BiggestHitsUIState.collapsedCats[catStateKey] = not isCatCollapsed
                                f:UpdateList()
                            end)
                            subHeader.clickBtn:Show()
                            subHeader:Show()

                            rowIndex = rowIndex + 1
                            yOffset = yOffset + 22

                            -- Render spell items only if category is expanded
                            if not isCatCollapsed then
                                for _, data in ipairs(list) do
                                    local row = GetRow(rowIndex)
                                    row:SetSize(contentWidth - 25, 26)
                                    row:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 25, -yOffset)

                                    row.nameText:SetWidth(math.max(contentWidth - 170, 80))

                                    local spellTexture = data.spellId and GetSpellTexture(data.spellId) or "Interface\\Icons\\INV_Misc_QuestionMark"
                                    row.icon:SetTexture(data.icon or spellTexture)
                                    row.icon:Show()

                                    row.nameText:SetText(data.name or "Unknown Spell")
                                    row.nameText:Show()

                                    local hitVal = (data.highestHit and data.highestHit > 0) and data.highestHit or "-"

                                    if catDef.showCrit then
                                        local critVal = (data.highestCrit and data.highestCrit > 0) and ("*" .. data.highestCrit .. "*") or "-"
                                        row.valText:SetText("|cff44ff44Hit:|r " .. hitVal .. "   |cffff4444Crit:|r " .. critVal)
                                    else
                                        row.valText:SetText("|cff44ff44Hit:|r " .. hitVal)
                                    end
                                    row.valText:Show()

                                    row:Show()
                                    rowIndex = rowIndex + 1
                                    yOffset = yOffset + 28
                                end
                            end

                            yOffset = yOffset + 4
                        end
                    end
                end

                yOffset = yOffset + 8
            end
        end

        if not hasEntries then
            local emptyRow = GetRow(1)
            emptyRow:SetSize(contentWidth, 30)
            emptyRow:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, -10)
            emptyRow.text:SetFontObject("GameFontDisable")
            emptyRow.text:SetText("No damage or healing records saved.")
            emptyRow.text:Show()
            emptyRow:Show()
            yOffset = 40
        end

        self.scrollChild:SetHeight(math.max(yOffset, scrollFrame:GetHeight()))
    end

    mainFrame = f
    return f
end

local function ToggleTrackerUI()
    local ui = CreateTrackerUI()
    if ui:IsShown() then
        ui:Hide()
    else
        ui:UpdateList()
        ui:Show()
    end
end

----------------------------------------------------
-- 4. RECORD SAVING
----------------------------------------------------
local function SaveSpellRecord(spellId, spellName, amount, isCrit, category)
    if not amount or amount <= 0 then return end

    local charKey = GetPlayerKey()
    BiggestHitsDB[charKey] = BiggestHitsDB[charKey] or {}

    spellId = spellId or 6603
    spellName = spellName or "Melee"
    local icon = GetSpellTexture(spellId) or "Interface\\Icons\\INV_Hand_1H_Swing"

    local recordKey = spellId .. "_" .. category
    local records = BiggestHitsDB[charKey]

    if not records[recordKey] then
        records[recordKey] = {
            spellId = spellId,
            name = spellName,
            category = category,
            highestHit = 0,
            highestCrit = 0,
            icon = icon
        }
    end

    local rec = records[recordKey]
    rec.category = category
    rec.name = spellName
    local updated = false

    if category == "DOT_DMG" or category == "HOT" then
        if amount > (rec.highestHit or 0) then
            rec.highestHit = amount
            updated = true
        end
    else
        if isCrit then
            if amount > (rec.highestCrit or 0) then
                rec.highestCrit = amount
                updated = true
            end
        else
            if amount > (rec.highestHit or 0) then
                rec.highestHit = amount
                updated = true
            end
        end
    end

    if updated and mainFrame and mainFrame:IsShown() then
        mainFrame:UpdateList()
    end
end

----------------------------------------------------
-- 5. MINIMAP BUTTON
----------------------------------------------------
local function CreateMinimapButton()
    if BiggestHitsMinimapButton then return end

    local btn = CreateFrame("Button", "BiggestHitsMinimapButton", Minimap)
    btn:SetSize(33, 33)
    btn:SetFrameStrata("MEDIUM")
    btn:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -15, 0)
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(21, 21)
    icon:SetTexture("Interface\\Icons\\Spell_Holy_MagicalSentry")
    icon:SetPoint("CENTER", btn, "CENTER", 0, 1)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(52, 52)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("BiggestHits", 1, 1, 1)
        GameTooltip:AddLine("Click to toggle records window.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", function()
        ToggleTrackerUI()
    end)
end

----------------------------------------------------
-- 6. COMBAT LOG & EVENT HANDLER
----------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        GetPlayerKey()
        CreateMinimapButton()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, arg12, arg13, arg14, arg15, arg16, arg17, arg18, arg19, arg20, arg21 = CombatLogGetCurrentEventInfo()

        local playerGUID = UnitGUID("player")
        if sourceGUID and playerGUID and sourceGUID == playerGUID then
            local spellId, spellName, amount, critical, category

            -- Auto-Attacks
            if subEvent == "SWING_DAMAGE" then
                spellId = 6603
                spellName = "Melee"
                amount = arg12
                critical = arg18
                category = "DIRECT_DMG"

            -- Direct Damage
            elseif subEvent == "SPELL_DAMAGE" or subEvent == "RANGE_DAMAGE" then
                spellId, spellName = arg12, arg13
                amount = arg15
                critical = arg21
                category = "DIRECT_DMG"

            -- DoT Damage
            elseif subEvent == "SPELL_PERIODIC_DAMAGE" then
                spellId, spellName = arg12, arg13
                amount = arg15
                critical = arg21
                category = "DOT_DMG"

            -- Direct Healing
            elseif subEvent == "SPELL_HEAL" then
                spellId, spellName = arg12, arg13
                amount = arg15
                critical = arg18
                category = "HEAL"

            -- HoT Healing
            elseif subEvent == "SPELL_PERIODIC_HEAL" then
                spellId, spellName = arg12, arg13
                amount = arg15
                critical = arg18
                category = "HOT"
            end

            if amount and category then
                local isCrit = (critical == true or critical == 1)
                SaveSpellRecord(spellId, spellName, amount, isCrit, category)
            end
        end
    end
end)

----------------------------------------------------
-- 7. SLASH COMMANDS
----------------------------------------------------
SLASH_BIGGESTHITS1 = "/bh"
SLASH_BIGGESTHITS2 = "/biggesthits"
SlashCmdList["BIGGESTHITS"] = function(msg)
    local cmd = string.lower(msg or "")
    if cmd == "clear" or cmd == "reset" then
        StaticPopup_Show("BIGGESTHITS_CONFIRM_CLEAR")
    else
        ToggleTrackerUI()
    end
end