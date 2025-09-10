-- ######################################################
-- GuildBankLogger (Fixed MoP Classic Deduplication)
-- Logs guild bank deposits, withdrawals, and gold transactions
-- ######################################################

-- Saved variables
GBL_Data = GBL_Data or {}
GBL_Export = GBL_Export or ""
GBL_NextIndex = GBL_NextIndex or 1
GBL_SeenKeys = GBL_SeenKeys or {} -- fast lookup for duplicates

----------------------------------------------------------
-- Helpers
----------------------------------------------------------

-- Generate a unique key from actual transaction details
local function MakeKey(entry)
    -- Using tab, player, item/gold, count/amount, action, and scan line
    -- Line number ensures multiple identical deposits are recorded
    return string.format("%s|%s|%s|%s|%s|%s|%s",
        entry.tab or "MONEY",
        entry.player or "-",
        entry.item or (entry.gold or 0),
        entry.count or (entry.gold or 0),
        entry.action or "-",
        entry.scanLine or "-",
        entry.extra or "-"
    )
end

-- Add an entry if it's new
local function AddEntry(entry)
    local key = MakeKey(entry)

    if GBL_SeenKeys[key] then
        return false -- duplicate entry
    end

    GBL_SeenKeys[key] = true
    entry.index = GBL_NextIndex
    GBL_NextIndex = GBL_NextIndex + 1
    table.insert(GBL_Data, entry)
    return true
end

-- Rebuild seen keys from saved data (persists across sessions)
local function RebuildSeenKeys()
    GBL_SeenKeys = {}
    for _, entry in ipairs(GBL_Data) do
        local key = MakeKey(entry)
        GBL_SeenKeys[key] = true
    end
end

-- Automatically rebuild keys on login
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    RebuildSeenKeys()
end)

----------------------------------------------------------
-- Export
----------------------------------------------------------

function GBL_ExportToCSV()
    local text = "Player\tType\tGold_Dep_G\tGold_Dep_S\tGold_Dep_C\tGold_Wit_G\tGold_Wit_S\tGold_Wit_C\tItem\tCount\tIndex\tTab\n"

    for _, entry in ipairs(GBL_Data) do
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

    GBL_Export = text
    return text
end

----------------------------------------------------------
-- Scan
----------------------------------------------------------

local function PrintResult(tabName, newCount, skippedCount)
    print(string.format("GBL: %s scanned! %d new, %d skipped.", tabName, newCount, skippedCount))
end

local function ScanCurrentLog()
    if not GuildBankFrame or not GuildBankFrame:IsVisible() then
        print("GBL: Guild bank must be open to scan.")
        return
    end

    local tab = GetCurrentGuildBankTab()
    local tabName, newCount, skippedCount = "", 0, 0

    if GuildBankFrame.mode == "moneylog" then
        tabName = "Money Log"
        local num = GetNumGuildBankMoneyTransactions()
        for i = 1, num do
            local type, name, amount, years, months, days, hours = GetGuildBankMoneyTransaction(i)
            if type and name then
                local entry = {
                    tab = "MONEY",
                    player = name,
                    action = type,
                    gold = amount or 0,
                    scanLine = i
                }
                if AddEntry(entry) then newCount = newCount + 1 else skippedCount = skippedCount + 1 end
            end
        end
    else
        tabName = GetGuildBankTabInfo(tab) or ("Tab"..tab)
        local num = GetNumGuildBankTransactions(tab)
        for i = 1, num do
            local type, name, itemLink, count, _, _, _, _, _, _ = GetGuildBankTransaction(tab, i)
            if type and name then
                local entry = {
                    tab = "Tab"..tab,
                    player = name,
                    action = type,
                    item = itemLink,
                    count = count or 0,
                    scanLine = i
                }
                if AddEntry(entry) then newCount = newCount + 1 else skippedCount = skippedCount + 1 end
            end
        end
    end

    PrintResult(tabName, newCount, skippedCount)
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
