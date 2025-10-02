-- ######################################################
-- GuildBankLogger (MoP Classic: Robust Export + 20-Key Marker Deduplication)
-- Logs guild bank deposits, withdrawals, and gold transactions
-- ######################################################

GBL_Data = GBL_Data or {}
GBL_Export = GBL_Export or ""
GBL_NextIndex = GBL_NextIndex or 1
GBL_SeenKeys = GBL_SeenKeys or {}
GBL_Last20Markers = GBL_Last20Markers or {}

----------------------------------------------------------
-- Helpers
----------------------------------------------------------

-- Key construction: deduplication (strict) vs marker matching (stable)
local function MakeKey(entry, forMarker)
    if forMarker then
        -- Use only stable fields (omit scanLine)
        return string.format("%s|%s|%s|%s|%s",
            entry.tab or "MONEY",
            entry.player or "-",
            entry.item or (entry.gold or 0),
            entry.count or (entry.gold or 0),
            entry.action or "-"
        )
    else
        -- For deduplication, include scanLine for max strictness
        return string.format("%s|%s|%s|%s|%s|%s",
            entry.tab or "MONEY",
            entry.player or "-",
            entry.item or (entry.gold or 0),
            entry.count or (entry.gold or 0),
            entry.action or "-",
            entry.scanLine or "-"
        )
    end
end

local function AddEntry(entry)
    local key = MakeKey(entry, false)
    if GBL_SeenKeys[key] then
        return false
    end
    GBL_SeenKeys[key] = true
    entry.index = GBL_NextIndex
    GBL_NextIndex = GBL_NextIndex + 1
    table.insert(GBL_Data, entry)
    return true
end

local function RebuildSeenKeys()
    GBL_SeenKeys = {}
    for _, entry in ipairs(GBL_Data) do
        local key = MakeKey(entry, false)
        GBL_SeenKeys[key] = true
    end
end

local function GetLastNKeys(tab, N)
    local marker = GBL_Last20Markers[tab]
    if marker and #marker > 0 then
        return marker
    end
    return {}
end

local function SetLastNKeys(tab, keys)
    GBL_Last20Markers[tab] = keys
end

-- Find the marker sequence in the scanned log; require at least 10/20 in order
local function FindMarkerInLog(markerKeys, scannedEntries)
    local markerLen = #markerKeys
    if markerLen == 0 then return 0 end
    local minMatch = math.min(10, markerLen)
    for i = 1, #scannedEntries - markerLen + 1 do
        local matchCount = 0
        for j = 1, markerLen do
            if MakeKey(scannedEntries[i + j - 1], true) == markerKeys[j] then
                matchCount = matchCount + 1
            else
                break
            end
        end
        if matchCount >= minMatch then
            return i + markerLen - 1
        end
    end
    return nil
end

----------------------------------------------------------
-- Export (full history, updates marker after export)
----------------------------------------------------------

function GBL_ExportToCSV()
    local text = "Player\tType\tGold_Dep_G\tGold_Dep_S\tGold_Dep_C\tGold_Wit_G\tGold_Wit_S\tGold_Wit_C\tItem\tCount\tIndex\tTab\n"

    local byTab = {}
    for _, entry in ipairs(GBL_Data) do
        local tab = entry.tab or "MONEY"
        byTab[tab] = byTab[tab] or {}
        table.insert(byTab[tab], entry)
    end

    for _, entries in pairs(byTab) do
        table.sort(entries, function(a, b) return (a.index or 0) < (b.index or 0) end)
    end

    local newMarkers = {}
    for tab, entries in pairs(byTab) do
        for _, entry in ipairs(entries) do
            local typeStr = "-"
            local gd, gs, gc, gw, ws, wc = 0, 0, 0, 0, 0, 0
            local itemName, count = "-", 0

            if entry.gold and entry.gold ~= 0 then
                typeStr = entry.action == "deposit" and "Gold Deposit" or "Gold Withdraw"
                local total = tonumber(entry.gold) or 0
                local gold_units   = math.floor(total / 10000)
                local silver_units = math.floor((total % 10000) / 100)
                local copper_units = total % 100

                if entry.action == "deposit" then
                    gd, gs, gc = gold_units, silver_units, copper_units
                else
                    gw, ws, wc = gold_units, silver_units, copper_units
                end
            elseif entry.item and entry.item ~= "" then
                typeStr = entry.action == "deposit" and "Item Deposit" or "Item Withdraw"
                itemName = entry.item
                count = entry.count or 0
            end

            text = text .. string.format(
                "%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%d\t%d\t%s\n",
                entry.player or "-",
                typeStr,
                gd, gs, gc,
                gw, ws, wc,
                itemName,
                count,
                entry.index or -1,
                entry.tab or "MONEY"
            )
        end
        -- After export, update last 20 marker for this tab (using marker keys!)
        if #entries > 0 then
            local keys = {}
            for i = #entries, math.max(1, #entries - 19), -1 do
                table.insert(keys, 1, MakeKey(entries[i], true))
            end
            newMarkers[tab] = keys
        end
    end

    for tab, keys in pairs(newMarkers) do
        SetLastNKeys(tab, keys)
    end

    GBL_Export = text
    return text
end

----------------------------------------------------------
-- Scan (NO marker update here!)
----------------------------------------------------------

local function PrintResult(tabName, newCount, skippedCount, markerWarn)
    print(string.format("GBL: %s scanned! %d new, %d skipped.", tabName, newCount, skippedCount))
    if markerWarn then
        print("GBL: WARNING! Previous marker sequence not found in this log. Possible loss of entries due to log rollover.")
    end
end

local function ScanCurrentLog()
    if not GuildBankFrame or not GuildBankFrame:IsVisible() then
        print("GBL: Guild bank must be open to scan.")
        return
    end

    local tab = GetCurrentGuildBankTab()
    local tabKey, tabName, newCount, skippedCount = "", "", 0, 0
    local markerWarn = false
    local scannedEntries = {}

    if GuildBankFrame.mode == "moneylog" then
        tabKey = "MONEY"
        tabName = "Money Log"
        local num = GetNumGuildBankMoneyTransactions()
        for i = 1, num do
            local type, name, amount, years, months, days, hours = GetGuildBankMoneyTransaction(i)
            if type and name then
                local entry = {
                    tab = tabKey,
                    player = name,
                    action = type,
                    gold = amount or 0,
                    scanLine = i
                }
                table.insert(scannedEntries, entry)
            end
        end
    else
        tabKey = "Tab"..tab
        tabName = GetGuildBankTabInfo(tab) or ("Tab"..tab)
        local num = GetNumGuildBankTransactions(tab)
        for i = 1, num do
            local type, name, itemLink, count, _, _, _, _, _, _ = GetGuildBankTransaction(tab, i)
            if type and name then
                local entry = {
                    tab = tabKey,
                    player = name,
                    action = type,
                    item = itemLink,
                    count = count or 0,
                    scanLine = i
                }
                table.insert(scannedEntries, entry)
            end
        end
    end

    -- Marker matching: Find where previous marker ends (using stable keys!)
    local markerKeys = GetLastNKeys(tabKey, 20)
    local markerEndIndex = FindMarkerInLog(markerKeys, scannedEntries)
    if not markerEndIndex then
        markerWarn = true
        markerEndIndex = 0
    end

    for i = markerEndIndex + 1, #scannedEntries do
        if AddEntry(scannedEntries[i]) then
            newCount = newCount + 1
        else
            skippedCount = skippedCount + 1
        end
    end

    PrintResult(tabName, newCount, skippedCount, markerWarn)
end

----------------------------------------------------------
-- Export window
----------------------------------------------------------

local function GBL_ShowExportWindow()
    local exportText = GBL_ExportToCSV()

    if not GBL_ExportFrame then
        local f = CreateFrame("Frame", "GBL_ExportFrame", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(700, 400)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")

        f.title = f:CreateFontString(nil, "OVERLAY")
        f.title:SetFontObject("GameFontHighlight")
        f.title:SetPoint("LEFT", f.TitleBg, "LEFT", 5, 0)
        f.title:SetText("Guild Bank Logger Export")

        local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -30)
        scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 10)

        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetFontObject(ChatFontNormal)
        editBox:SetWidth(640)
        editBox:SetAutoFocus(false)

        scrollFrame:SetScrollChild(editBox)
        f.editBox = editBox

        editBox:SetScript("OnEscapePressed", function() f:Hide() end)
        editBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

        GBL_ExportFrame = f
    end

    GBL_ExportFrame.editBox:SetText(exportText)
    GBL_ExportFrame.editBox:HighlightText()
    GBL_ExportFrame:Show()
end

----------------------------------------------------------
-- On login: re-init
----------------------------------------------------------

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    RebuildSeenKeys()
    GBL_Last20Markers = GBL_Last20Markers or {}
end)

----------------------------------------------------------
-- Slash command
----------------------------------------------------------

SLASH_GBL1 = "/gbl"
SlashCmdList["GBL"] = function(msg)
    msg = msg:lower()
    if msg == "scan" then
        ScanCurrentLog()
    elseif msg == "export" then
        GBL_ShowExportWindow()
    else
        print("GuildBankLogger commands:")
        print("  /gbl scan   -> Scan current visible log (tab or money log)")
        print("  /gbl export -> Show export window (copy CSV)")
    end
end

print("GuildBankLogger loaded! Type /gbl for commands.")