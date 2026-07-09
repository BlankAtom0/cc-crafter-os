local config      = require "config"
local basalt      = require "basalt"
local itemLayer   = require "itemLayer"

local allItems    = {}
local filtered    = {}
local order       = {}

local selectedIdx = nil
local maxAmount   = 0
local lastUpdated = 0
local lastQuery   = ""

basalt.LOGGER.setEnabled(true)
basalt.LOGGER.setLogToFile(true)

local function formatNumber(num)
    if not num then return "0" end
    if num < 1000 then return tostring(num) end

    local suffixes = { "k", "m", "b", "t" }
    local index = 0
    local value = num

    while value >= 1000 and index < #suffixes do
        value = value / 1000
        index = index + 1
    end

    local str = tostring(value)
    local i, j = str:find('%.')
    if i and i < 3 then
        str = str:sub(1, i + 1)
    else
        str = tostring(math.floor(value))
    end

    -- Math.floor prevents unwanted rounding up (e.g., 53.9k staying 53k)
    return str .. suffixes[index]
end

local function unformatNumber(str)
    if not str then return 0 end
    return tonumber(str:gsub("[kmbt]", "")) * (1000 ^ str:find("[kmbt]"))
end

local main = basalt.getMainFrame()

local tabControl = main:addTabControl({
    x = 1,
    y = 1,
    width = "{parent.width}",
    height = "{parent.height - 2}",
    tabHeight = 1,
    scrollableTab = true
})

main:addLabel({
    x = 1,
    y = "{parent.height - 1}",
    width = #"Addr: ",
    height = 1,
    text = "Addr: "
})
local addressInput = main:addInput({
    x = #"Addr: " + 1,
    y = "{parent.height - 1}",
    width = "{parent.width}",
    height = 1,
    placeholder = "Enter address"
})

local statusLabel  = main:addLabel({
    x = 1,
    y = "{parent.height}",
    width = "{parent.width}",
    height = 1,
    text = "Waiting for Connection"
})

local title        = "\x07 Storage Terminal"

local searchTab    = tabControl:newTab("Search")
local orderTab     = tabControl:newTab("Order")
local historyTab   = tabControl:newTab("History")
local craftingTab  = tabControl:newTab("Crafting")

---- Search Tab ----
searchTab:addLabel({
    x = 2,
    y = 1,
    width = #title,
    height = 1,
    text = title
})
local searchCounts = tostring(#filtered) .. "/" .. tostring(#allItems)
local searchCountsLabel = searchTab:addLabel({
    x = "{parent.width - 5}",
    y = 1,
    width = #searchCounts,
    height = 1,
    text = searchCounts
})

local searchInput = searchTab:addInput({
    x = 1,
    y = 2,
    width = "{parent.width}",
    height = 1,
    placeholder = "Click to search"
})

local searchList = searchTab:addList({
    x = 1,
    y = 3,
    width = "{parent.width}",
    height = "{parent.height - 3}"
})

local searchListInputCount = searchTab:addInput({
    x = 1,
    y = "{parent.height - 1}",
    width = 18,
    height = 1,
    placeholder = "Enter Amount",
    visible = false
})

local searchListInputCancel = searchTab:addButton({
    x = 20,
    y = "{parent.height - 1}",
    width = 6,
    height = 1,
    text = "Cancel",
    visible = false,
    background = colours.red,
    foreground = colours.white
})

local function updateSearchList(items)
    local scroll = searchList.offset
    searchList:clear()
    for _, i in ipairs(items) do
        local item = ""
        item = i.displayName .. item.rep(" ", searchList.width)
        count = "x" .. formatNumber(i.count)
        item = item:sub(1, searchList.width - 6) .. count
        searchList:addItem(item)
    end
    searchList.offset = scroll
    if selectedIdx then
        searchList.items[selectedIdx].selected = true
    end
end

local function applyFilter(items)
    local subset = {}
    if searchInput.text == "" then
        subset = allItems
        return subset
    end
    local q = searchInput.text:lower()
    for _, item in ipairs(allItems) do
        if item.displayName:lower():find(q, 1, true) or item.name:lower():find(q, 1, true) then
            subset[#subset + 1] = item
        end
    end
    return subset
end

local function onStockEvent(data)
    lastUpdated = data.timestamp or os.epoch("utc")
    allItems = data.items or {}
    filtered = applyFilter(allItems)
    updateSearchList(filtered)
end

local function addToOrder(item, count)
    table.insert(order, { item = item, count = count })
end

local function onSearchInput()
    filtered = applyFilter(allItems)
    updateSearchList(filtered)
end

local function onSearchListSelect(item, index)
    maxAmount = filtered[index].count
    selectedIdx = index
    searchListInputCount.visible = true
    searchListInputCancel.visible = true
    searchList:setHeight("{parent.height - 4}")
end

local function onSearchListSubmit()
    if maxAmount == nil then return end
    if searchCounts.text == "" then return end
    local count = tonumber(searchListInputCount.text)
    if count == nil then return end
    if count > maxAmount then count = maxAmount end
    searchListInputCount.text = ""

    addToOrder(filtered[selectedIdx], count)

    searchListInputCount.visible = false
    searchListInputCancel.visible = false
    searchList:setHeight("{parent.height - 3}")
    if selectedIdx then
        searchList.items[selectedIdx].selected = false
        selectedIdx = 0
    end
end

local function onSearchListCancel()
    selectedIdx = 0
    searchListInputCount.visible = false
    searchListInputCancel.visible = false
    searchList:setHeight("{parent.height - 3}")
end

searchInput:onChange("text", onSearchInput)
searchList:onSelect(onSearchListSelect)
searchListInputCount:onSubmit(onSearchListSubmit)
searchListInputCancel:onClick(onSearchListCancel)

---- Order Tab ----
orderTab:addLabel({
    x = 2,
    y = 1,
    width = #title,
    height = 1,
    text = title
})

local orderCount = "x" .. #order

local orderCountLabel = orderTab:addLabel({
    x = "{parent.width - #orderCount - 1}",
    y = 1,
    width = #orderCount,
    height = 1,
    text = orderCount
})

local orderList = orderTab:addList({
    x = 1,
    y = 3,
    width = "{parent.width}",
    height = "{parent.height - 3}"
})

local function tick()
    local delta = (os.epoch("utc") - lastUpdated) / 1000
    if lastUpdated == 0 then
        statusLabel.text = "Waiting for connection..."
    elseif delta > config.STALE_TIMEOUT then
        statusLabel.text = string.format("No signal (%ds ago)", delta)
    else
        statusLabel.text = string.format("OK \xb7 %ds ago", delta)
    end
end

local timer = main:addTimer()
timer.action = tick
timer:start()

basalt.onEvent(itemLayer.stockUpdate, onStockEvent)
basalt.onEvent("send_order", itemLayer.sendOrder)
basalt.onEvent("modem_message", itemLayer.handleModemEvent)

tabControl:onChange("activeTab", function() basalt.LOGGER.info("activeTab: ", tabControl.activeTab) basalt.LOGGER.info(tabControl.tabs[tabControl.activeTab]) end)

local modem = peripheral.find("modem")
modem.open(config.STOCK_CHANNEL)

basalt.run()
