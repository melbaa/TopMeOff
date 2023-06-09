local function info(msg)
    local colored = "|cffffff00<TopMeOff> " .. msg .. "|r"
    DEFAULT_CHAT_FRAME:AddMessage(colored);
end

local function print_usage()
    info('usage: ')
    info('tmo add <itemlink> <amount> - shift-click an item to get a link')
    info('tmo ls - see all configured items')
    info('tmo reset - delete all items from the list')
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

            local addstring = table.concat(commandlist, " ", 2, table.getn(commandlist))

            -- info(addstring)
            -- local _, _, itemLink = string.find(addstring, "(item:%d+:%d+:%d+:%d+)")
            -- addstring = "|cffffffff|Hitem:13356:0:0:0|h[Somatic Intensifier]|h|r"
            local _, _, itemLink = string.find(addstring, "(|c%x+|Hitem:%d+:%d+:%d+:%d+|h%[.-%]|h|r)")
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
        elseif commandlist[1] == 'reset' then
            reagentsWanted = {}
            info('removed all items')
        elseif commandlist[1] == 'ls' then
            local count = 0
            local reagentsOwned = CountReagents(reagentsWanted)
            for k, v in pairs(reagentsWanted) do
                local color = '|cff1eff00' -- green
                if reagentsOwned[k] < v then
                    color = '|cffff5179' -- red
                end
                info(k .. ' ' .. v .. ' have ' .. color .. reagentsOwned[k])
                count = count + 1
            end
            if not count then
                info('nothing added yet')
                return
            end
        else
            print_usage()
        end
    end
end

function TopMeOff_OnLoad()
    this:RegisterEvent("MERCHANT_SHOW");
end

function TopMeOff_OnEvent()
    if( event == "MERCHANT_SHOW" ) then
        BuyReagents();
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
