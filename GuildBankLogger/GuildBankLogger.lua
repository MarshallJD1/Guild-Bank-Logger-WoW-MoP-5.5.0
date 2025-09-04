-- ######################################################
-- GuildBankLogger
-- Logs guild bank deposits, withdrawals, and gold transactions
-- Provides per-player summary and manual scan
-- ######################################################

-- Saved variables
GBL_Data = GBL_Data or {}

----------------------------------------------------------
-- Helpers
----------------------------------------------------------
local function IsGuildBankOpen()
    return GuildBankFrame and GuildBankFrame:IsShown()
end

-- Check if entry is duplicate
local function entriesEqual(a, b)
    return a.time == b.time
        and a.player == b.player
        and a.action == b.action
        and (a.item or "") == (b.item or "")
        and (a.count or 0) == (b.count or 0)
        and (a.gold or 0) == (b.gold or 0)
        and (a.tab or 0) == (b.tab or 0)
end

local function isDuplicate(entry)
    for _, e in ipairs(GBL_Data) do
        if entriesEqual(e, entry) then return true end
    end
    return false
end

----------------------------------------------------------
-- Logging functions
----------------------------------------------------------
local function MakeItemEntry(tab, index)
    local type, name, itemLink, count, tab1, tab2, year, month, day, hour =
        GetGuildBankTransaction(tab, index)
    if not type or not name then return nil end
    return {
        time   = string.format("%04d-%02d-%02d %02d:00", year, month, day, hour),
        player = name,
        action = type,
        item   = itemLink or "",
        count  = count or 0,
        tab    = tab,
    }
end

local function MakeMoneyEntry(index)
    local type, name, amount, year, month, day, hour =
        GetGuildBankMoneyTransaction(index)
    if not type or not name then return nil end
    return {
        time   = string.format("%04d-%02d-%02d %02d:00", year, month, day, hour),
        player = name,
        action = type,
        gold   = (amount or 0) / 10000,
    }
end

-- Global function so slash commands can call it
function ScanLogs()
    if not IsGuildBankOpen() then
        print("|cff33ff99GuildBankLogger:|r Open the Guild Bank first to scan logs.")
        return
    end

    local added = 0

    for tab = 1, GetNumGuildBankTabs() or 0 do
        for i = 1, GetNumGuildBankTransactions(tab) or 0 do
            local entry = MakeItemEntry(tab, i)
            if entry and not isDuplicate(entry) then
                table.insert(GBL_Data, entry)
                added = added + 1
            end
        end
    end

    for i = 1, GetNumGuildBankMoneyTransactions() or 0 do
        local entry = MakeMoneyEntry(i)
        if entry and not isDuplicate(entry) then
            table.insert(GBL_Data, entry)
            added = added + 1
        end
    end

    print(string.format("|cff33ff99GuildBankLogger:|r Scan complete. %d new entry(s) added.", added))
end

----------------------------------------------------------
-- Summary Window
----------------------------------------------------------
local summaryFrame = CreateFrame("Frame", "GBL_SummaryFrame", UIParent, "BackdropTemplate")
summaryFrame:SetSize(500, 400)
summaryFrame:SetPoint("CENTER")
summaryFrame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
summaryFrame:SetBackdropColor(0, 0, 0, 0.8)
summaryFrame:Hide()

local closeSummary = CreateFrame("Button", nil, summaryFrame, "UIPanelCloseButton")
closeSummary:SetPoint("TOPRIGHT", summaryFrame, "TOPRIGHT")

local summaryScroll = CreateFrame("ScrollFrame", nil, summaryFrame, "UIPanelScrollFrameTemplate")
summaryScroll:SetPoint("TOPLEFT", 10, -10)
summaryScroll:SetPoint("BOTTOMRIGHT", -30, 10)

local summaryBox = CreateFrame("EditBox", nil, summaryScroll)
summaryBox:SetMultiLine(true)
summaryBox:SetFontObject(ChatFontNormal)
summaryBox:SetWidth(450)
summaryBox:SetAutoFocus(false)
summaryScroll:SetScrollChild(summaryBox)

function ShowSummaryWindow()
    -- Build Excel-friendly tab-delimited text with Date
    local text = "Date\tPlayer\tGoldDeposit\tGoldWithdraw\tItem\tItemDeposit\tItemWithdraw\n"

    for _, entry in ipairs(GBL_Data) do
        local dateStr = entry.time or "-"
        local goldDeposit = (entry.gold and entry.action == "deposit") and entry.gold or 0
        local goldWithdraw = (entry.gold and entry.action == "withdraw") and entry.gold or 0
        local item = entry.item ~= "" and entry.item or "-"
        local itemDeposit = (entry.item ~= "" and entry.action == "deposit") and entry.count or 0
        local itemWithdraw = (entry.item ~= "" and entry.action == "withdraw") and entry.count or 0

        text = text .. string.format("%s\t%s\t%.2f\t%.2f\t%s\t%d\t%d\n",
            dateStr,
            entry.player,
            goldDeposit,
            goldWithdraw,
            item,
            itemDeposit,
            itemWithdraw
        )
    end

    summaryBox:SetText(text)
    summaryBox:HighlightText()
    summaryFrame:Show()
end


----------------------------------------------------------
-- Auto-scan when Guild Bank is opened
----------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("GUILDBANKFRAME_OPENED")
f:SetScript("OnEvent", function(self, event)
    if event == "GUILDBANKFRAME_OPENED" then
        local before = #GBL_Data
        ScanLogs()
        local added = #GBL_Data - before
        print(string.format("|cff33ff99GuildBankLogger:|r Auto-scan complete, %d new entry(s) added.", added))
    end
end)

----------------------------------------------------------
-- Slash Commands
----------------------------------------------------------
SLASH_GBL1 = "/gbl"
SlashCmdList["GBL"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "summary" then
        ShowSummaryWindow()
    elseif msg == "scan" then
        ScanLogs()
    elseif msg == "clear" then
        GBL_Data = {}
        print("|cff33ff99GuildBankLogger:|r Data cleared.")
    else
        print("|cff33ff99GuildBankLogger commands:|r")
        print(" - /gbl scan    → Scan logs (bank must be open)")
        print(" - /gbl summary → Open per-player summary window")
        print(" - /gbl clear   → Clear stored data")
        print(" - /gblscanall  → Scan all Logs for new entries")
    end
end

-- /gbl scanall → scan all tabs and money logs, ignoring duplicates
SlashCmdList["GBL_SCANALL"] = function()
    if not IsGuildBankOpen() then
        print("|cff33ff99GuildBankLogger:|r Open the Guild Bank first to scan logs.")
        return
    end

    local before = #GBL_Data
    -- Scan every tab
    for tab = 1, GetNumGuildBankTabs() or 0 do
        for i = 1, GetNumGuildBankTransactions(tab) or 0 do
            local entry = MakeItemEntry(tab, i)
            if entry and not isDuplicate(entry) then
                table.insert(GBL_Data, entry)
            end
        end
    end
    -- Scan money logs
    for i = 1, GetNumGuildBankMoneyTransactions() or 0 do
        local entry = MakeMoneyEntry(i)
        if entry and not isDuplicate(entry) then
            table.insert(GBL_Data, entry)
        end
    end
    local added = #GBL_Data - before
    print(string.format("|cff33ff99GuildBankLogger:|r Full scan complete. %d new entry(s) added.", added))
end

-- Register the slash command
SLASH_GBL_SCANALL1 = "/gblscanall"

