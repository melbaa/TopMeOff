reagentsWanted = reagentsWanted or {}

function TopMeOff_OnLoad()
    this:RegisterEvent("MERCHANT_SHOW");
end

function TopMeOff_OnEvent()
    if( event == "MERCHANT_SHOW" ) then
        BuyReagents();
    end
end

local function info(msg)
    local colored = "|cffffff00<TopMeOff> " .. msg .. "|r"
    DEFAULT_CHAT_FRAME:AddMessage(colored);
end

function CountReagents(reagentsWanted)

    local reagentsOwned = {};
    for name, value in pairs(reagentsWanted) do
        reagentsOwned[name] = 0
    end

    for bagID = 0, 4 do
        for slot = 1, GetContainerNumSlots(bagID) do
            local itemName, itemCount = GetBagItemNameAndCount(bagID, slot);

            if itemName ~= nil then
                local debug = 'found ' .. itemName .. ' ' .. itemCount
                info(debug)
                if reagentsOwned[itemName] ~= nil then
                    -- count this item
                    reagentsOwned[itemName] = reagentsOwned[itemName] + itemCount
                end
            end
        end
    end
    for k, v in pairs(reagentsOwned) do
        info(k .. ' have ' .. v)
    end
    return reagentsOwned
end

function BuyReagents()
    local shoppingList = {};

    local reagentsOwned = CountReagents(reagentsWanted)


    for merchantIndex = 1, GetMerchantNumItems() do
        local name, texture, price, quantity = GetMerchantItemInfo(merchantIndex)
        -- info(name)

        if reagentsOwned[name] ~= nil and reagentsOwned[name] < reagentsWanted[name] then
            -- we care about this item, how many should we buy
            local neededCount = reagentsWanted[name] - reagentsOwned[name]
            info(name .. ' buying ' .. neededCount)
            -- BuyMerchantItem(merchantIndex, neededCount)
        end
    end 
end

function GetBagItemNameAndCount(bag, slot)

    local texture, itemCount = GetContainerItemInfo(bag, slot);

    if not itemCount then
        itemCount = 0
    end

    local itemLink = GetContainerItemLink(bag, slot)

    local itemName = nil
    if itemLink then
        -- info(itemLink)
        itemName = GetItemInfo(itemLink)
    end

    return itemName, itemCount
end
