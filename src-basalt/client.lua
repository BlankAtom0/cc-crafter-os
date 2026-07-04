-- local config     = require("config")
local basalt            = require("basalt")

local allItems          = {}
local filtered          = {}
local searchListStrings = {}
local order             = {}

local main              = basalt.getMainFrame()

local tabControl        = main:addTabControl({
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

local function updateSearchList()
    for _, item in ipairs(filtered) do
        local string = ""
        string = item.displayName .. string.rep(" ", searchList.width)
        count = "x" .. tostring(item.count)
        string = string:sub(1, searchList.width - #count) .. count
        table.insert(searchListStrings, string)
    end
end

---- Order Tab ----
orderTab:addLabel({
    x = 2,
    y = 1,
    width = #title,
    height = 1,
    text = title
})

local orderCount = "x" .. tostring(function()
    local tot = 0
    for _, i in order do tot = tot + i.count end
    return tot
end)
local orderCountLabel = orderTab:addLabel({
    x = "{parent.width}" - #orderCount - 1,
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

basalt.run()
