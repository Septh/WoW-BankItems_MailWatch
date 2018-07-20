
-- Upvalues
-- GLOBALS: LibStub
local CreateFrame = CreateFrame
local SecondsToTime = SecondsToTime
local UIParent = UIParent
local NORMAL_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE = NORMAL_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE
local RED_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, ORANGE_FONT_COLOR_CODE = RED_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, ORANGE_FONT_COLOR_CODE
local FONT_COLOR_CODE_CLOSE = FONT_COLOR_CODE_CLOSE

-- LDB lib and Object
local LDBObj = LibStub('LibDataBroker-1.1'):NewDataObject("BankItems_MailWatch", {
    type = "data source",
    icon = "Interface\\Icons\\INV_Letter_15",
    text = "Mail",
})
if not LDBObj then return end

-- Highlighting texture
local highlightTexture = UIParent:CreateTexture(nil, 'OVERLAY')
highlightTexture:SetTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight')
highlightTexture:SetBlendMode('ADD')

-- Misc
local BI_MAIL_BAG = "Bag101"

local tth = select(2, GameTooltipText:GetFontObject():GetFont())
local factionIcons = {
    Alliance = ([[|TInterface\AddOns\BankItems_MailWatch\Faction-Alliance:%d:%d:0|t]]):format(tth, tth),
    Horde = ([[|TInterface\AddOns\BankItems_MailWatch\Faction-Horde:%d:%d:0|t]]):format(tth, tth)
}

------------------------------------------------------------------------
-- Table Pool for recycling tables - borrowed from BankItems.lua
------------------------------------------------------------------------
local tablePool = setmetatable({}, { __mode = "kv" }) -- Weak table

-- Get a new table
local function newTable()
    local t = next(tablePool) or {}
    tablePool[t] = nil
    return t
end

-- Delete table and add it back to pool
local function delTable(t)
    if type(t) == "table" then
        for k, v in pairs(t) do
            if type(v) == "table" then
                delTable(v)
            end
            t[k] = nil
        end
        setmetatable(t, nil)
        t[true] = true
        t[true] = nil
        tablePool[t] = true
    end
    return nil
end

local emptyTable = {}

------------------------------------------------------------------------
-- Tooltip handling
------------------------------------------------------------------------
local libqtip = LibStub('LibQTip-1.0')
local tooltip

function LDBObj:OnLeave()
    highlightTexture:Hide()
    highlightTexture:SetParent(UIParent)

    tooltip:Hide()
    libqtip:Release(tooltip)
end

function LDBObj:OnEnter()

    -- Highlight the LDB frame if not Bazook
    local fname = self:GetName() or ''
    if not fname:find('Bazooka', 1) then
        highlightTexture:SetParent(self)
        highlightTexture:SetAllPoints(self)
        highlightTexture:Show()
    end

    -- Read data from BankItems' SavedVariables
    local data = newTable()
    local BI   = _G.BankItems_Save or emptyTable
    for toon, items in pairs(BI) do
        if type(items) == "table" and type(items[BI_MAIL_BAG]) == "table" then
            local name, realm = strsplit("|", toon)

            local mails = items[BI_MAIL_BAG]
            local count = #mails
            if count > 0 then
                local entry = newTable()
                entry['rlm'] = realm
                entry['who'] = name
                entry['fct'] = items['faction']
                entry['num'] = count
                entry['exp'] = time() + 60*60*24*30;	-- 30 days

                for i = 1, count do
                    if type(mails[i]['link']) == 'string' then
                        -- Un ou plusieurs objets
                        entry['exp'] = math.min(entry['exp'], mails[i]['expiry'] or 0)
                    end
                end
                table.insert(data, entry)
            end
        end
    end

    -- Trie le tout
    table.sort(data, function(c1, c2)
        -- Par royaume d'abord, dates ensuite
        if c1['rlm'] == c2['rlm'] then
            return c1['exp'] < c2['exp']
        else
            return c1['rlm'] < c2['rlm']
        end
    end)

    -- Remplit le tooltip
    tooltip = libqtip:Acquire('BIMWTooltip', 3, "LEFT", "CENTER", "RIGHT")
    tooltip:SmartAnchorTo(self)
    tooltip:Hide()
    tooltip:Clear()
    tooltip:SetCellMarginV(2)

    -- Titre
    tooltip:AddHeader()
    tooltip:SetCell(1, 1, NORMAL_FONT_COLOR_CODE .. 'BI MailWatch' .. FONT_COLOR_CODE_CLOSE, nil, "CENTER", 3)

    -- Contenu
    if #data > 0 then
        tooltip:AddLine('')
        tooltip:AddLine("Name", "# objects", "Delay")
        tooltip:AddSeparator(); tooltip:AddLine('')

        local rlm
        for _,v in ipairs(data) do
            if rlm ~= v['rlm'] then
                rlm = v['rlm']
                tooltip:AddLine(' ')
                tooltip:AddLine(rlm)
            end

            local lft = v['exp'] - time()
            local txt
            if lft < 0 then
                txt = RED_FONT_COLOR_CODE .. "Lost mail!" .. FONT_COLOR_CODE_CLOSE
            else
                txt = (lft < 24*60*60*5 and ORANGE_FONT_COLOR_CODE or GREEN_FONT_COLOR_CODE) .. SecondsToTime(lft, true) .. FONT_COLOR_CODE_CLOSE
            end

            tooltip:AddLine(' ' .. factionIcons[v['fct']] .. ' ' .. NORMAL_FONT_COLOR_CODE .. v['who'] .. FONT_COLOR_CODE_CLOSE, v['num'], txt)
        end
    else
        tooltip:AddLine('')
        tooltip:SetCell(2, 1, HIGHLIGHT_FONT_COLOR_CODE .. 'No pending mail.' .. FONT_COLOR_CODE_CLOSE, nil, "CENTER", 3)
    end

    tooltip:Show()
    delTable(data)
end
