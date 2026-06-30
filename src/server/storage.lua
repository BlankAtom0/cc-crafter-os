local pretty = require("cc.pretty")
local logFile
local items
local STOCK_CHANNEL = 53321
local ORDER_CHANNEL = 53322

local function findTicker()
    local t = peripheral.find("Create_StockTicker")
    if not t then
        error("No Create Stock Ticker found.", 0)
    end
    return t
end

local function findModem()
    local m = peripheral.find("modem")
    if not m then
        error("No modem found.", 0)
    end
    return m
end

local function openLog()
    if logFile then
        logFile:close()
    end
    logFile = io.open(string.format("log%s.txt", os.date("%F")), 'a')
end

local function log(msg)
    logFile:write(string.format("[%s] %s\n", os.date("%H:%M:%S"), msg))
end

local function listStock(ticker)
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

local function broadcastStock(modem, ticker)
    local list = listStock(ticker)
    if not list then return end
    local payload = textutils.serialize({
        type      = "stock_update",
        timestamp = os.epoch("utc"),
        items     = list
    })
    modem.transmit(STOCK_CHANNEL, STOCK_CHANNEL, payload)
    log(string.format("Broadcast: %d unique items (%d bytes)", #list, #payload))
end

local function processOrder(modem, ticker, order)
    local address = order.address
    if not address or address == "" then
        address = order.senderLabel or ""
    end

    local results = {}
    local anyFailed = false

    for _, item in ipairs(order.items or {}) do
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

    local response = textutils.serialize({
        type = "order_response",
        requestId = order.requestId,
        address = address,
        results = results,
        success = not anyFailed
    })
    modem.transmit(order.channel, ORDER_CHANNEL, response)
end

local function main()
    openLog()
    log("Server starting...")
    local ticker = findTicker()
    local modem = findModem()
    modem.open(ORDER_CHANNEL)
    log("Modem opened on channel " .. ORDER_CHANNEL)
    log("Sending stock to channel " .. STOCK_CHANNEL)
    log("Ticker found: " .. peripheral.getName(ticker))

    local function broadcastLoop()
        while true do
            broadcastStock(modem, ticker)
            sleep(config.SCAN_DELAY)
        end
    end

    local function orderLoop()
        while true do
            local _, _, ch, _, msg = os.pullEvent("modem_message")
            if ch == config.ORDER_CHANNEL then
                local ok, payload = pcall(textutils.unserialize, msg)
                if ok and payload and payload.type == "order_request" then
                    log("Recieved order request: " .. tostring(payload.requestId))
                    processOrder(modem, ticker, payload)
                    broadcastStock(modem, ticker)
                end
            end
            sleep(5)
        end
    end

    parallel.waitForAny(broadcastLoop, orderLoop)
end

main()
