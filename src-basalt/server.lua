local itemLayer = require "itemLayer"
local config = require "config"

local ticker, modem

local items = {}
local logFile

local function openLog()
    if logFile then
        logFile:close()
    end
    logFile = io.open(string.format("log%s.txt", os.date("%F")), 'a')
end

local function log(msg)
    logFile:write(string.format("[%s] %s\n", os.date("%H:%M:%S"), msg))
end

local function findTicker()
    local t = peripheral.find("Create_StockTicker")
    if not t then
        error("No Create Stock Ticker found.", 0)
    end
    ticker = t
end

local function findModem()
    local m = peripheral.find("modem")
    if not m then
        error("No Modem found.", 0)
    end
    modem = m
end

local function listStock()
    local ok
    ok, items = pcall(ticker.stock, true)
    if not ok or not items then
        log("Warning: stock() call failed")
        return nil
    end

    table.sort(items, function(a, b)
        local an = (a.displayName or a.name):lower()
        local bn = (b.displayName or b.name):lower()
        return an < bn
    end)

    local list = {}
    for _, item in ipairs(items) do
        table.insert(list, {
            name        = item.name,
            displayName = item.displayName or item.name,
            count       = item.count
        })
    end
    return list
end

local function onOrder(data)
    local address = data.address
    if not address or address == "" then
        address = data.senderLabel
    end

    local results = {}
    local anyFailed = false

    for _, item in ipairs(data.items or {}) do
        local filter = {
            _requestCount = item.count,
            name = item.name
        }

        local ok, err = pcall(ticker.requestFiltered, address, filter)
        table.insert(results, {
            name = item.name,
            count = item.count,
            succ = ok,
            err = err or nil
        })

        if not ok then
            anyFailed = true
            log(string.format("Order item FAILED: %s x%d -> %s (%s)", item.name, item.count, address, tostring(err)))
        else
            log(string.format("Order item sent: %s x%d -> %s", item.name, item.count, address))
        end
    end

    itemLayer.sendOrderResponse(
        modem,
        data.channel,
        data.channel,
        data.requestId,
        data.address,
        results,
        not anyFailed
    )
end

local function main()
    openLog()
    log("Server starting...")
    findTicker()
    findModem()
    modem.open(config.ORDER_CHANNEL)

    local function broadcastLoop()
        while true do
            itemLayer.sendStock(
                modem,
                config.STOCK_CHANNEL,
                config.STOCK_CHANNEL,
                listStock()
            )
            sleep(config.SCAN_DELAY)
        end
    end

    local function eventLoop()
        while true do
            local ev = os.pullEvent()
            local e = ev[1]
            if e == "modem_message" then
                handleModemEvent(ev)
            elseif e == itemLayer.orderRequest then
                onOrder(ev[2])
            end
            sleep(1)
        end
    end

    parallel.waitForAny(broadcastLoop, eventLoop)
end

main()
