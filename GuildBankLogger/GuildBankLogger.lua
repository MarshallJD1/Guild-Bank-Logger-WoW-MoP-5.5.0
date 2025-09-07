-- ######################################################
-- GuildBankLogger
-- Logs guild bank deposits, withdrawals, and gold transactions
-- Each transaction is a separate row with a unique monotonic index
-- ######################################################

GBL_Data = GBL_Data or {}
GBL_NextIndex = GBL_NextIndex or 1 -- global counter for unique IDs
GBL_Export = GBL_Export or ""      -- export string for Python script

----------------------------------------------------------
-- Helpers
----------------------------------------------------------
local function IsGuildBankOpen()
    return GuildBankFrame and GuildBankFrame:IsShown()
end

-- Assign a unique incremental index to every new entry
local function assignUniqueIndex(entry)
    entry.gblIndex = GBL_NextIndex
    GBL_NextIndex = GBL_NextIndex + 1
end

-- Generate a unique key to check for duplicates (based on tab/index for items, or gold index)
local function generateKey(entry)
    if entry.gold then
        return string.format("GOLD|%d", entry.index or -1)
    elseif entry.item and entry.item ~= "" then
        return string.format("ITEM|%d|%d", entry.tab or -1, entry.index or -1)
    end
    return nil
end

-- Check if entry is duplicate (uses game’s own tab/index to avoid re-logging same session entries)
local function isDuplicate(entry)
    local key = generateKey(entry)
    if not key then return false end
    for _, e in ipairs(GBL_Data) do
        if generateKey(e) == key then
            return true
        end
    end
    return false
end

----------------------------------------------------------
-- Logging functions
----------------------------------------------------------
local function MakeItemEntry(tab, index)
    local type, name, itemLink, count, _, _, year, month, day, hour =
        GetGuildBankTransaction(tab, index)
    if not type or not name then return nil end
    return {
        time   = string.format("%04d-%02d-%02d %02d:00", year, month, day, hour),
        player = name,
        action = type,
        item   = itemLink or "",
        count  = count or 0,
        tab    = tab,
        index  = index, -- in-game index (not exported anymore)
    }
end

local function MakeMoneyEntry(index)
    local type, name, amount, year, month, day, hour, minute, second =
        GetGuildBankMoneyTransaction(index)
    if not type or not name then return nil end

    local g = math.floor(amount / 10000)
    local s = math.floor((amount % 10000) / 100)
    local c = amount % 100

    return {
        time   = string.format("%04d-%02d-%02d %02d:%02d:%02d",
                    year, month, day, hour or 0, minute or 0, second or 0),
        player = name,
        action = type,
        gold   = g,
        silver = s,
        copper = c,
        index  = index, -- in-game index (not exported anymore)
    }
end

----------------------------------------------------------
-- Log loading tracker
----------------------------------------------------------
local GBL_LogsLoaded = {}
local GBL_MoneyLogLoaded = false
local GBL_PendingScan = false

local function RequestAllLogs()
    local numTabs = GetNumGuildBankTabs() or 0
    GBL_LogsLoaded = {}
    GBL_MoneyLogLoaded = false
    GBL_PendingScan = true
    for tab = 1, numTabs do
        QueryGuildBankLog(tab)
        GBL_LogsLoaded[tab] = false
    end
    QueryGuildBankMoneyLog()
end

local function AllLogsLoaded()
    for _, loaded in pairs(GBL_LogsLoaded) do
        if not loaded then return false end
    end
    return GBL_MoneyLogLoaded
end

----------------------------------------------------------
-- Full scan
----------------------------------------------------------
local function FullScan()
    if not IsGuildBankOpen() then
        print("|cff33ff99GuildBankLogger:|r Open the Guild Bank first to scan logs.")
        return
    end

    local added = 0

    -- Item transactions
    for tab = 1, GetNumGuildBankTabs() or 0 do
        for i = 1, GetNumGuildBankTransactions(tab) or 0 do
            local entry = MakeItemEntry(tab, i)
            if entry and not isDuplicate(entry) then
                assignUniqueIndex(entry)
                table.insert(GBL_Data, entry)
                added = added + 1
            end
        end
    end

    -- Gold transactions
    for i = 1, GetNumGuildBankMoneyTransactions() or 0 do
        local entry = MakeMoneyEntry(i)
        if entry and not isDuplicate(entry) then
            assignUniqueIndex(entry)
            table.insert(GBL_Data, entry)
            added = added + 1
        end
    end

    print(string.format("|cff33ff99GuildBankLogger:|r Scan complete. %d new entr%s added.",
        added, added == 1 and "y" or "ies"))
    UpdateExportString()
end

----------------------------------------------------------
-- Export CSV string (one row per transaction)
----------------------------------------------------------
function UpdateExportString()
    local text = "Player\tType\tGold_G\tGold_S\tGold_C\tItem\tCount\tTimestamp\tIndex\n"

    for _, entry in ipairs(GBL_Data) do
        local typeStr = "-"
        local g, s, c = 0, 0, 0
        local itemName = "-"
        local count = 0

        if entry.gold then
            typeStr = entry.action == "deposit" and "Gold Deposit" or "Gold Withdraw"
            g, s, c = entry.gold, entry.silver, entry.copper
        elseif entry.item and entry.item ~= "" then
            typeStr = entry.action == "deposit" and "Item Deposit" or "Item Withdraw"
            itemName = entry.item
            count = entry.count
        end

        text = text .. string.format(
            "%s\t%s\t%d\t%d\t%d\t%s\t%d\t%s\t%d\n",
            entry.player or "-",
            typeStr,
            g, s, c,
            itemName,
            count,
            entry.time or "-",
            entry.gblIndex or -1 -- ✅ export unique index
        )
    end

    GBL_Export = text
end

----------------------------------------------------------
-- Auto-scan on open and log loading
----------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("GUILDBANKFRAME_OPENED")
f:RegisterEvent("GUILDBANKLOG_UPDATE")
f:SetScript("OnEvent", function(self, event, ...)
    if event == "GUILDBANKFRAME_OPENED" then
        RequestAllLogs()
    elseif event == "GUILDBANKLOG_UPDATE" and GBL_PendingScan then
        -- Figure out which log just updated
        local tab = ...
        if tab then
            GBL_LogsLoaded[tab] = true
        else
            GBL_MoneyLogLoaded = true
        end
        if AllLogsLoaded() then
            GBL_PendingScan = false
            local before = #GBL_Data
            FullScan()
            local added = #GBL_Data - before
            if added > 0 then
                print(string.format("|cff33ff99GuildBankLogger:|r Auto-scan logged %d new entr%s.",
                    added, added == 1 and "y" or "ies"))
            else
                print("|cff33ff99GuildBankLogger:|r Auto-scan found no new entries.")
            end
        end
    end
end)

----------------------------------------------------------
-- Slash commands
----------------------------------------------------------
SLASH_GBL1 = "/gbl"
SlashCmdList["GBL"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "clear" then
        GBL_Data = {}
        GBL_NextIndex = 1
        print("|cff33ff99GuildBankLogger:|r Data cleared.")
    elseif msg == "exportreset" then
        GBL_Export = ""
        print("|cff33ff99GuildBankLogger:|r Export string reset (Python will see empty export).")
    else
        print("|cff33ff99GuildBankLogger commands:|r")
        print(" - /gbl clear        → Clear stored data")
        print(" - /gbl exportreset  → Reset export string only")
        print(" - /gblscanall       → Scan all logs for new entries")
    end
end

SLASH_GBL_SCANALL1 = "/gblscanall"
SlashCmdList["GBL_SCANALL"] = function()
    if not IsGuildBankOpen() then
        print("|cff33ff99GuildBankLogger:|r Open the Guild Bank first to scan logs.")
        return
    end
    RequestAllLogs()
end
