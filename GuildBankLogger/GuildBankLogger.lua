-- ... [existing code above] ...

----------------------------------------------------------
-- Enhanced Panel UI Integration (/gbl panel)
----------------------------------------------------------

local PANEL_WIDTH, PANEL_HEIGHT = 660, 480

local function GetUniqueCharacterNames_GBL(logs)
    local names, seen = {}, {}
    for _, log in ipairs(logs or {}) do
        if log.player and not seen[log.player] then
            table.insert(names, log.player)
            seen[log.player] = true
        end
    end
    return names
end

local function FilterLogs_GBL(logs, character, typeFilter)
    local filtered = {}
    for _, log in ipairs(logs or {}) do
        if (not character or log.player == character) and (not typeFilter or log.action == typeFilter or typeFilter == "All") then
            table.insert(filtered, log)
        end
    end
    return filtered
end

local function FormatLogEntry_GBL(log)
    return string.format("[%s] %s: %s (%s)", 
        log.date or "-", 
        log.player or "-", 
        log.action or "-", 
        log.item or log.gold or "-"
    )
end

local function DeleteLogEntry_GBL(entryIndex)
    for i, log in ipairs(GBL_Data) do
        if log.index == entryIndex then
            table.remove(GBL_Data, i)
            break
        end
    end
end

local function ClearAllLogs_GBL()
    GBL_Data = {}
    GBL_SeenKeys = {}
    GBL_NextIndex = 1
end

local function ImportLogs_GBL(importText)
    local imported = 0
    for line in importText:gmatch("[^\n]+") do
        if not line:match("^Player") then
            local fields = {}
            for field in line:gmatch("([^	]+)") do
                table.insert(fields, field)
            end
            if #fields >= 12 then
                local entry = {
                    player = fields[1],
                    action = fields[2]:find("Deposit") and "deposit" or "withdraw",
                    gold = tonumber(fields[3]) * 10000 + tonumber(fields[4]) * 100 + tonumber(fields[5]) or 0,
                    item = fields[8] ~= "-" and fields[8] or nil,
                    count = tonumber(fields[9]) or nil,
                    index = tonumber(fields[10]) or nil,
                    tab = fields[11]
                }
                table.insert(GBL_Data, entry)
                imported = imported + 1
            end
        end
    end
    return imported
end

local panelFrame_GBL
local importFrame_GBL
local function ShowPanel_GBL()
    if not panelFrame_GBL then
        panelFrame_GBL = CreateFrame("Frame", "GBLPanelFrame", UIParent, "BasicFrameTemplateWithInset")
        panelFrame_GBL:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
        panelFrame_GBL:SetPoint("CENTER")
        panelFrame_GBL:SetMovable(true)
        panelFrame_GBL:EnableMouse(true)
        panelFrame_GBL:RegisterForDrag("LeftButton")
        panelFrame_GBL:SetScript("OnDragStart", panelFrame_GBL.StartMoving)
        panelFrame_GBL:SetScript("OnDragStop", panelFrame_GBL.StopMovingOrSizing)
        panelFrame_GBL.title = panelFrame_GBL:CreateFontString(nil, "OVERLAY")
        panelFrame_GBL.title:SetFontObject("GameFontHighlight")
        panelFrame_GBL.title:SetPoint("LEFT", panelFrame_GBL.TitleBg, "LEFT", 5, 0)
        panelFrame_GBL.title:SetText("Guild Bank Logger Panel")

        local dropdownChar = CreateFrame("Frame", "GBLPanelDropdownChar", panelFrame_GBL, "UIDropDownMenuTemplate")
        dropdownChar:SetPoint("TOPLEFT", panelFrame_GBL, "TOPLEFT", 10, -40)
        UIDropDownMenu_SetWidth(dropdownChar, 180)
        panelFrame_GBL.dropdownChar = dropdownChar

        local dropdownType = CreateFrame("Frame", "GBLPanelDropdownType", panelFrame_GBL, "UIDropDownMenuTemplate")
        dropdownType:SetPoint("LEFT", dropdownChar, "RIGHT", 30, 0)
        UIDropDownMenu_SetWidth(dropdownType, 120)
        panelFrame_GBL.dropdownType = dropdownType

        local exportBtn = CreateFrame("Button", nil, panelFrame_GBL, "GameMenuButtonTemplate")
        exportBtn:SetPoint("TOPRIGHT", panelFrame_GBL, "TOPRIGHT", -30, -40)
        exportBtn:SetSize(100, 30)
        exportBtn:SetText("Export")
        exportBtn:SetNormalFontObject("GameFontNormalLarge")
        exportBtn:SetScript("OnClick", function()
            GBL_ShowExportWindow()
        end)
        exportBtn.tooltipText = "Export logs to CSV. Opens copy window."
        exportBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText)
        end)
        exportBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local scanBtn = CreateFrame("Button", nil, panelFrame_GBL, "GameMenuButtonTemplate")
        scanBtn:SetPoint("RIGHT", exportBtn, "LEFT", -10, 0)
        scanBtn:SetSize(120, 30)
        scanBtn:SetText("Scan")
        scanBtn:SetNormalFontObject("GameFontNormalLarge")
        scanBtn:SetScript("OnClick", function()
            print("GBL: Before scanning, make sure you've opened the log pane of each guild bank tab and the money tab. Then click Scan for each!")
            ScanCurrentLog()
        end)
        scanBtn.tooltipText = "Scan current visible log (see chat for guidance)."
        scanBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText)
        end)
        scanBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local importBtn = CreateFrame("Button", nil, panelFrame_GBL, "GameMenuButtonTemplate")
        importBtn:SetPoint("RIGHT", scanBtn, "LEFT", -10, 0)
        importBtn:SetSize(120, 30)
        importBtn:SetText("Import")
        importBtn:SetNormalFontObject("GameFontNormalLarge")
        importBtn:SetScript("OnClick", function()
            if not importFrame_GBL then
                importFrame_GBL = CreateFrame("Frame", "GBLImportFrame", UIParent, "BasicFrameTemplateWithInset")
                importFrame_GBL:SetSize(700, 400)
                importFrame_GBL:SetPoint("CENTER")
                importFrame_GBL:SetFrameStrata("DIALOG")
                importFrame_GBL.title = importFrame_GBL:CreateFontString(nil, "OVERLAY")
                importFrame_GBL.title:SetFontObject("GameFontHighlight")
                importFrame_GBL.title:SetPoint("LEFT", importFrame_GBL.TitleBg, "LEFT", 5, 0)
                importFrame_GBL.title:SetText("Paste Exported Log Data Here")

                local scrollFrame = CreateFrame("ScrollFrame", nil, importFrame_GBL, "UIPanelScrollFrameTemplate")
                scrollFrame:SetPoint("TOPLEFT", importFrame_GBL, "TOPLEFT", 10, -30)
                scrollFrame:SetPoint("BOTTOMRIGHT", importFrame_GBL, "BOTTOMRIGHT", -30, 50)

                local editBox = CreateFrame("EditBox", nil, scrollFrame)
                editBox:SetMultiLine(true)
                editBox:SetFontObject(ChatFontNormal)
                editBox:SetWidth(640)
                editBox:SetAutoFocus(true)
                scrollFrame:SetScrollChild(editBox)
                importFrame_GBL.editBox = editBox

                local doImportBtn = CreateFrame("Button", nil, importFrame_GBL, "GameMenuButtonTemplate")
                doImportBtn:SetPoint("BOTTOMRIGHT", importFrame_GBL, "BOTTOMRIGHT", -30, 10)
                doImportBtn:SetSize(120, 30)
                doImportBtn:SetText("Import")
                doImportBtn:SetNormalFontObject("GameFontNormalLarge")
                doImportBtn:SetScript("OnClick", function()
                    local imported = ImportLogs_GBL(importFrame_GBL.editBox:GetText())
                    print("GBL: Imported " .. imported .. " log entries.")
                    importFrame_GBL:Hide()
                    panelFrame_GBL:RefreshLogs()
                end)

                local closeBtn = CreateFrame("Button", nil, importFrame_GBL, "GameMenuButtonTemplate")
                closeBtn:SetPoint("RIGHT", doImportBtn, "LEFT", -10, 0)
                closeBtn:SetSize(100, 30)
                closeBtn:SetText("Cancel")
                closeBtn:SetNormalFontObject("GameFontNormalLarge")
                closeBtn:SetScript("OnClick", function()
                    importFrame_GBL:Hide()
                end)
            end
            importFrame_GBL.editBox:SetText("")
            importFrame_GBL:Show()
        end)
        importBtn.tooltipText = "Import logs by pasting CSV exported data."
        importBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText)
        end)
        importBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local clearBtn = CreateFrame("Button", nil, panelFrame_GBL, "GameMenuButtonTemplate")
        clearBtn:SetPoint("RIGHT", importBtn, "LEFT", -10, 0)
        clearBtn:SetSize(100, 30)
        clearBtn:SetText("Clear Logs")
        clearBtn:SetNormalFontObject("GameFontNormalLarge")
        clearBtn:SetScript("OnClick", function()
            StaticPopupDialogs["GBL_CLEAR_CONFIRM"] = {
                text = "Are you sure you want to clear ALL logs? This cannot be undone.",
                button1 = "Yes",
                button2 = "No",
                OnAccept = function()
                    ClearAllLogs_GBL()
                    print("GBL: All logs cleared.")
                    panelFrame_GBL:RefreshLogs()
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                exclusive = true,
            }
            StaticPopup_Show("GBL_CLEAR_CONFIRM")
        end)
        clearBtn.tooltipText = "Clear all logs (cannot be undone)."
        clearBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipText)
        end)
        clearBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local scrollFrame = CreateFrame("ScrollFrame", "GBLPanelScrollFrame", panelFrame_GBL, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", dropdownChar, "BOTTOMLEFT", 0, -10)
        scrollFrame:SetPoint("BOTTOMRIGHT", panelFrame_GBL, "BOTTOMRIGHT", -30, 10)
        panelFrame_GBL.scrollFrame = scrollFrame

        local logContent = CreateFrame("Frame", "GBLPanelLogContent", scrollFrame)
        logContent:SetSize(PANEL_WIDTH-60, PANEL_HEIGHT-70)
        scrollFrame:SetScrollChild(logContent)
        panelFrame_GBL.logContent = logContent

        panelFrame_GBL.selectedCharacter = nil
        panelFrame_GBL.selectedType = "All"

        function panelFrame_GBL:RefreshLogs()
            local logs = GBL_Data or {}
            local filtered = FilterLogs_GBL(logs, self.selectedCharacter, self.selectedType)
            for _, child in ipairs({self.logContent:GetChildren()}) do
                child:Hide()
            end
            local y = -5
            for _, log in ipairs(filtered) do
                local entry = self.logContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                entry:SetPoint("TOPLEFT", self.logContent, "TOPLEFT", 5, y)
                entry:SetText(FormatLogEntry_GBL(log))
                entry:Show()

                local delBtn = CreateFrame("Button", nil, self.logContent, "UIPanelButtonTemplate")
                delBtn:SetPoint("LEFT", entry, "RIGHT", 10, 0)
                delBtn:SetSize(50, 16)
                delBtn:SetText("Delete")
                delBtn:SetScript("OnClick", function()
                    StaticPopupDialogs["GBL_DELETE_CONFIRM"] = {
                        text = "Are you sure you want to delete this log entry? This cannot be undone.",
                        button1 = "Yes",
                        button2 = "No",
                        OnAccept = function()
                            DeleteLogEntry_GBL(log.index)
                            print("GBL: Log entry deleted.")
                            panelFrame_GBL:RefreshLogs()
                        end,
                        timeout = 0,
                        whileDead = true,
                        hideOnEscape = true,
                        exclusive = true,
                    }
                    StaticPopup_Show("GBL_DELETE_CONFIRM")
                end)
                y = y - 20
            end
        end

        local function OnCharacterSelected(_, arg1)
            panelFrame_GBL.selectedCharacter = arg1
            panelFrame_GBL:RefreshLogs()
        end

        local function InitializeDropdownChar(self, level)
            local logs = GBL_Data or {}
            for _, name in ipairs(GetUniqueCharacterNames_GBL(logs)) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.value = name
                info.func = OnCharacterSelected
                UIDropDownMenu_AddButton(info)
            end
        end
        UIDropDownMenu_Initialize(dropdownChar, InitializeDropdownChar)

        local function OnTypeSelected(_, arg1)
            panelFrame_GBL.selectedType = arg1
            panelFrame_GBL:RefreshLogs()
        end

        local function InitializeDropdownType(self, level)
            local types = {"All", "deposit", "withdraw"}
            for _, t in ipairs(types) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = (t == "deposit" and "Deposit") or (t == "withdraw" and "Withdraw") or t
                info.value = t
                info.func = OnTypeSelected
                UIDropDownMenu_AddButton(info)
            end
        end
        UIDropDownMenu_Initialize(dropdownType, InitializeDropdownType)
    end
    panelFrame_GBL:Show()
    panelFrame_GBL:RefreshLogs()
end

SLASH_GBLPANEL1 = "/gblpanel"
SLASH_GBLPANEL2 = "/gbl panel"
SlashCmdList["GBLPANEL"] = ShowPanel_GBL
