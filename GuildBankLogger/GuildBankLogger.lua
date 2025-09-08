-- ######################################################
-- GuildBankLogger (Persistent Deduplication)
-- Logs guild bank deposits, withdrawals, and gold transactions
-- Scans the currently visible guild bank log (tab or money log)
-- ######################################################

-- Saved variables
GBL_Data = GBL_Data or {}
GBL_Export = GBL_Export or ""
GBL_NextIndex = GBL_NextIndex or 1
GBL_SeenKeys = GBL_SeenKeys or {} -- fast lookup for duplicates

----------------------------------------------------------
-- Helpers
----------------------------------------------------------

-- Generate a unique key for each transaction
local function MakeKey(entry)
    return table.concat({
        entry.tab or "MONEY",
        entry.time or "0",
        entry.player or "UNKNOWN",
        entry.action or "??",
        entry.item or entry.currency or entry.gold or "NONE",
        entry.count or 0,
        entry.amount or 0,
    }, "|")
end

-- Add an entry if it's new (persistent-safe)
local function AddEntry(entry)
    -- Make unique key
    local key = MakeKey(entry)

    -- Check if key already exists in GBL_SeenKeys or in GBL_Data
    if GBL_SeenKeys[key] then
        return false -- already added
    end

    -- Mark as seen
    GBL_SeenKeys[key] = true

    -- Assign index
    entry.index = GBL_NextIndex
    GBL_NextIndex = GBL_NextIndex + 1

    -- Store in table
    table.insert(GBL_Data, entry)

    -- Incremental export line
    local line = string.format(
        "%d,%s,%s,%s,%s,%d,%d",
        entry.index,
        entry.tab or "MONEY",
        entry.time or "0",
        entry.player or "UNKNOWN",
        entry.action or "??",
        entry.count or entry.amount or 0,
        entry.gold or 0
    )
    if GBL_Export == "" then
        GBL_Export = line
    else
        GBL_Export = GBL_Export .. "\n" .. line
    end

    return true
end

-- Generate the full export string (tab-separated)
function UpdateExportString()
    local text = "Player\tType\tGold_G\tGold_S\tGold_C\tItem\tCount\tTimestamp\tIndex\tTab\n"
    for _, entry in ipairs(GBL_Data) do
        local typeStr, g, s, c, itemName, count = "-", 0, 0, 0, "-", 0
        if entry.gold then
            typeStr = entry.action == "deposit" and "Gold Deposit" or "Gold Withdraw"
            g, s, c = entry.gold, entry.silver or 0, entry.copper or 0
        elseif entry.item and entry.item ~= "" then
            typeStr = entry.action == "deposit" and "Item Deposit" or "Item Withdraw"
            itemName, count = entry.item, entry.count
        end

        text = text .. string.format(
            "%s\t%s\t%d\t%d\t%d\t%s\t%d\t%s\t%d\t%s\n",
            entry.player or "-",
            typeStr,
            g, s, c,
            itemName,
            count,
            entry.time or "-",
            entry.index or -1,
            entry.tab or "MONEY"
        )
    end
    GBL_Export = text
end

-- Show scan confirmation
local function PrintResult(tabName, newCount, skippedCount)
    print(string.format("GBL: %s scanned! %d new, %d skipped.", tabName, newCount, skippedCount))
end

----------------------------------------------------------
-- Scan current log
----------------------------------------------------------

local function ScanCurrentLog()
    if not GuildBankFrame or not GuildBankFrame:IsVisible() then
        print("GBL: Guild bank must be open to scan.")
        return
    end

    local tab = GetCurrentGuildBankTab()
    local logType, tabName
    local newCount, skippedCount = 0, 0

    -- Money log?
    if GuildBankFrame.mode == "moneylog" then
        logType = "MONEY"
        tabName = "Money Log"
        local num = GetNumGuildBankMoneyTransactions()
        for i = 1, num do
            local type, name, amount, years, months, days, hours = GetGuildBankMoneyTransaction(i)
            if type and name then
                local entry = {
                    tab = "MONEY",
                    time = string.format("%02d-%02d-%02d %02d", years or 0, months or 0, days or 0, hours or 0),
                    player = name,
                    action = type,
                    amount = amount or 0,
                    gold = amount or 0,
                }
                if AddEntry(entry) then newCount = newCount + 1 else skippedCount = skippedCount + 1 end
            end
        end
    else
        tabName = GetGuildBankTabInfo(tab)
        logType = "TAB"
        local num = GetNumGuildBankTransactions(tab)
        for i = 1, num do
            local type, name, itemLink, count, tab1, tab2, year, month, day, hour = GetGuildBankTransaction(tab, i)
            if type and name then
                local entry = {
                    tab = "Tab" .. tab,
                    time = string.format("%02d-%02d-%02d %02d", year or 0, month or 0, day or 0, hour or 0),
                    player = name,
                    action = type,
                    item = itemLink,
                    count = count or 0,
                }
                if AddEntry(entry) then newCount = newCount + 1 else skippedCount = skippedCount + 1 end
            end
        end
    end

    PrintResult(tabName or logType, newCount, skippedCount)
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
        print("----- GBL Export Start -----")
        print(GBL_Export)
        print("----- GBL Export End -----")
    else
        print("GuildBankLogger commands:")
        print("  /gbl scan   -> Scan current visible log (tab or money log)")
        print("  /gbl export -> Print export string")
    end
end
