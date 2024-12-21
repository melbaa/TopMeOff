local verbose = nil

local function info(msg)
    local colored = "|cffffff00<TopMeOff> " .. msg .. "|r"
    DEFAULT_CHAT_FRAME:AddMessage(colored);
end

local function print_usage()
    info('usage: ')
    info('tmo add <itemlink> <amount> - shift-click an item for an item link')
    info('tmo ls - see all configured items')
    info('tmo ls need - see the items needed off the buy list')
    info('tmo ls have - see the items you have from the buy list')
    info('tmo del <itemlink> - remove 1 item from the list. shift-click an item for an item link.')
    info('tmo reset - delete all items from the list')
end

local function compare_item_names(linka, linkb)
    local _, _, namea = string.find(linka, "|c%x+|Hitem:%d+:%d+:%d+:%d+|h%[(.-)%]|h|r")
    local _, _, nameb = string.find(linkb, "|c%x+|Hitem:%d+:%d+:%d+:%d+|h%[(.-)%]|h|r")
    return namea < nameb
end

local function is_table_empty(table)
    local next = next
    return next(table) == nil
end

reagentsWanted = reagentsWanted or {}

local gfind = string.gmatch or string.gfind

do
    SLASH_TOPMEOFF1 = '/tmo'
    SlashCmdList["TOPMEOFF"] = function(message)
        local commandlist = { }
        local command

        for command in gfind(message, "[^ ]+") do
            table.insert(commandlist, command)
        end

        if commandlist[1] == nil then
            print_usage()
            return
        end

        commandlist[1] = string.lower(commandlist[1])

        if commandlist[1] == 'add' then

            local cmdstring = table.concat(commandlist, " ", 2, table.getn(commandlist))

            -- info(cmdstring)
            -- local _, _, itemLink = string.find(cmdstring, "(item:%d+:%d+:%d+:%d+)")
            -- cmdstring = "|cffffffff|Hitem:13356:0:0:0|h[Somatic Intensifier]|h|r"
            local _, _, itemLink = string.find(cmdstring, "(|c%x+|Hitem:%d+:%d+:%d+:%d+|h%[.-%]|h|r)")
            if not itemLink then
                info('an item link is required. use shift-click')
                return
            end

            local amount = tonumber(commandlist[table.getn(commandlist)])
            if amount == nil then
                info('the amount should be a number')
                return
            end
            reagentsWanted[itemLink] = amount
            info('added ' .. itemLink .. ' ' .. amount)
        elseif commandlist[1] == 'del' then
            local cmdstring = table.concat(commandlist, " ", 2, table.getn(commandlist))

            local _, _, itemLink = string.find(cmdstring, "(|c%x+|Hitem:%d+:%d+:%d+:%d+|h%[.-%]|h|r)")
            if not itemLink then
                info('an item link is required. use shift-click')
                return
            end

            reagentsWanted[itemLink] = nil
        elseif commandlist[1] == 'reset' then
            reagentsWanted = {}
            info('removed all items')
        elseif commandlist[1] == 'ls' then
            if is_table_empty(reagentsWanted) then
                info('nothing added yet')
                return
            end
            local showNeed = not (string.lower(commandlist[2] or '') == 'have')
            local showHave = not (string.lower(commandlist[2] or '') == 'need')
            local reagentsOwned = CountReagents(reagentsWanted)

            local sortedKeys = {}
            for k in pairs(reagentsWanted) do
                table.insert(sortedKeys, k)
            end
            table.sort(sortedKeys, compare_item_names)

            local count = 0
            local red = '|cffff5179'
            local green = '|cff1eff00'
            for _, k in ipairs(sortedKeys) do
                local v = reagentsWanted[k]
                local need = reagentsOwned[k] < v
                if need and showNeed then
                    info(k .. ' ' .. v .. ' have ' .. red .. reagentsOwned[k])
                    count = count + 1
                elseif not need and showHave then
                    info(k .. ' ' .. v .. ' have ' .. green .. reagentsOwned[k])
                    count = count + 1
                end
            end
            if count == 0 then
                info('You do not ' .. (showNeed and 'need anything from' or 'have anything on') .. ' your list!')
            end
        else
            print_usage()
        end
    end
end

local quest_found = nil -- will contain the itemlink to get
local function buy_spirit_zanza()
    local quest_found_candidate = nil
    -- is spirit zanza in our buy list?
    for k, v in pairs(reagentsWanted) do
        if string.find(k, 'Spirit of Zanza') then
            quest_found_candidate = k
        end
    end
    if not quest_found_candidate then return end

    -- is the quest available at the npc?
    local qidx = -1
    local active_qs = {GetGossipActiveQuests()}
    local iteration = 1
    for i=1, table.getn(active_qs), 2 do
        if active_qs[i] == "Zanza's Potent Potables" then
            qidx = iteration
            info(active_qs[i] .. ' ' .. iteration)
        end
        iteration = iteration + 1
    end
    if qidx == -1 then return end

    -- do we have less than needed?
    local reagentsOwned = CountReagents(reagentsWanted)
    if reagentsOwned[quest_found_candidate] >= reagentsWanted[quest_found_candidate] then
        return
    end

    -- do we have a honor token?
    local honor_token_itemlink = "|cff1eff00|Hitem:19858:0:0:0|h[Zandalar Honor Token]|h|r"
    local honorTokensOwned = CountReagents({[honor_token_itemlink]=1})
    if honorTokensOwned[honor_token_itemlink] < 1 then
        info('missing ' .. honor_token_itemlink .. ' for ' .. quest_found_candidate)
        return
    end

    quest_found = quest_found_candidate

    -- ready to activate the quest
    SelectGossipActiveQuest(qidx)
end

local function find_qidx(questname, qlist)
    local qidx = -1

    if table.getn(qlist) == 0 then
        if verbose then info('no quests found') end
        return qidx
    end

    local iteration = 1
    for i=1, table.getn(qlist), 2 do
        info(qlist[i])
        if qlist[i] == questname then
            qidx = iteration
            info(qlist[i] .. ' ' .. iteration)
        end
        iteration = iteration + 1
    end
    return qidx
end

local function get_quests()
    active_qs = {}
    avail_qs = {}
    for i=1, GetNumActiveQuests() do
        table.insert(active_qs, GetActiveTitle(i))
        table.insert(active_qs, GetActiveLevel(i))
    end
    for i=1, GetNumAvailableQuests() do
        table.insert(avail_qs, GetAvailableTitle(i))
        table.insert(avail_qs, GetAvailableLevel(i))
    end
    return active_qs, avail_qs
end

local function buy_quest_item(itemname, questname, reagents_itemlinks)
    local quest_found_candidate
    for k, v in pairs(reagentsWanted) do
        if string.find(k, itemname) then
            quest_found_candidate = k
            if verbose then info('buy_quest_item needs ' .. quest_found_candidate) end
        end
    end
    if not quest_found_candidate then return end

    local qidx_active = find_qidx(questname, {GetGossipActiveQuests()})
    local qidx_avail = find_qidx(questname, {GetGossipAvailableQuests()})
    if qidx_active == -1 and qidx_avail == -1 then
        if verbose then info('buy_quest_item did not find ' .. quest_found_candidate .. ' in active or available quests in the NPC') end
        return
    end

    local reagentsOwned = CountReagents(reagentsWanted)
    if reagentsOwned[quest_found_candidate] >= reagentsWanted[quest_found_candidate] then
        return
    end

    local reagentsOwned = CountReagents(reagents_itemlinks)
    for reagent_itemlink, reagent_needed in pairs(reagents_itemlinks) do
        if reagentsOwned[reagent_itemlink] < reagent_needed then
            info('missing ' .. reagent_itemlink .. ' for ' .. quest_found_candidate)
            return
        end
    end

    quest_found = quest_found_candidate

    if qidx_active ~= -1 then SelectGossipActiveQuest(qidx_active) end
    if qidx_avail ~= -1 then SelectGossipAvailableQuest(qidx_avail) end
end

function TopMeOff_OnLoad()
    this:RegisterEvent("MERCHANT_SHOW");

    this:RegisterEvent("QUEST_GREETING");
    this:RegisterEvent("QUEST_PROGRESS");
    this:RegisterEvent("QUEST_DETAIL");
    this:RegisterEvent("QUEST_COMPLETE");
    this:RegisterEvent("GOSSIP_SHOW");
end

function TopMeOff_OnEvent()
    if verbose then info('saw event ' .. event) end
    if( event == "MERCHANT_SHOW" ) then
        BuyReagents();
    end

    if event == "QUEST_GREETING" then
    end
    if event == "GOSSIP_SHOW" then
        quest_found = nil
        buy_spirit_zanza()
        buy_quest_item("Zandalar Honor Token", "Gurubashi, Vilebranch, and Witherbark Coins", {
            ["|cff1eff00|Hitem:19701:0:0:0|h[Gurubashi Coin]|h|r"]=1,
            ["|cff1eff00|Hitem:19702:0:0:0|h[Vilebranch Coin]|h|r"]=1,
            ["|cff1eff00|Hitem:19703:0:0:0|h[Witherbark Coin]|h|r"]=1,
        })
        buy_quest_item('R.O.I.D.S.', 'Rage of Ages', {
            ["|cffffffff|Hitem:8391:0:0:0|h[Snickerfang Jowl]|h|r"]=3,
            ["|cffffffff|Hitem:8392:0:0:0|h[Blasted Boar Lung]|h|r"]=2,
            ["|cffffffff|Hitem:8393:0:0:0|h[Scorpok Pincer]|h|r"]=1,
        })
        buy_quest_item('Juju Flurry', "Frostsaber E'ko", {
            ["|cffffffff|Hitem:12430:0:0:0|h[Frostsaber E'ko]|h|r"]=3,
        })
        buy_quest_item('Juju Power', "Winterfall E'ko", {
            ["|cffffffff|Hitem:12431:0:0:0|h[Winterfall E'ko]|h|r"]=3,
        })
    end
    if event == "QUEST_PROGRESS" then
        if quest_found then
            if verbose then info("QUEST_PROGRESS " .. tostring(quest_found)) end
            CompleteQuest()
        end
    end
    -- which quest is it?
    --if event == 'QUEST_DETAIL' then
    --    if quest_found then AcceptQuest() end
    --end
    if event == "QUEST_COMPLETE" then
        -- no quest, nothing to do
        if quest_found == nil then return end

        if verbose and quest_found then info("QUEST_COMPLETE searching for " .. tostring(quest_found)) end

        -- find the correct choice id
        local num_choices = GetNumQuestChoices()
        for i=1, num_choices do
            local link = GetQuestItemLink("choice", i)
            if link == quest_found then
                info('QUEST_COMPLETE getting reward ' .. quest_found)
                --CompleteQuest()
                GetQuestReward(i)
                quest_found = nil
            end
        end

        -- no choice
        if num_choices and num_choices == 0 then
            info('QUEST_COMPLETE getting reward ' .. quest_found)
            --CompleteQuest()
            GetQuestReward(1)
            quest_found = nil
        end
    end
end


function CountReagents(reagentsWanted)

    local reagentsOwned = {};
    for name, value in pairs(reagentsWanted) do
        reagentsOwned[name] = 0
    end

    for bagID = 0, 4 do
        for slot = 1, GetContainerNumSlots(bagID) do
            local itemLink, itemCount = GetBagItemAndCount(bagID, slot);

            if itemLink then
                local debug = 'found ' .. itemLink .. ' ' .. itemCount
                -- info(debug)
                if reagentsOwned[itemLink] ~= nil then
                    -- count this item
                    reagentsOwned[itemLink] = reagentsOwned[itemLink] + itemCount
                end
            end
        end
    end
    for k, v in pairs(reagentsOwned) do
        -- info(k .. ' have ' .. v)
    end
    return reagentsOwned
end

function BuyReagents()
    local shoppingList = {};

    local reagentsOwned = CountReagents(reagentsWanted)


    for merchantIndex = 1, GetMerchantNumItems() do
        local itemLink = GetMerchantItemLink(merchantIndex)

        if reagentsWanted[itemLink]
        and reagentsOwned[itemLink] < reagentsWanted[itemLink] then
            -- we care about this item, how many should we buy
            local name, texture, price, batchSize, numAvailable, isUsable, extendedCost = GetMerchantItemInfo(merchantIndex)
            local neededCount = reagentsWanted[itemLink] - reagentsOwned[itemLink]
            neededCount = math.ceil(neededCount / batchSize)  -- some things sell in batches of 5
            if neededCount then
                -- 0 buys a stack, so we prevent it
                info(itemLink .. ' buying ' .. neededCount * batchSize)
                BuyMerchantItem(merchantIndex, neededCount)
            end
        end
    end
end

function GetBagItemAndCount(bag, slot)

    local texture, itemCount = GetContainerItemInfo(bag, slot);

    if not itemCount then
        itemCount = 0
    end

    local itemLink = GetContainerItemLink(bag, slot)

    return itemLink, itemCount
end
