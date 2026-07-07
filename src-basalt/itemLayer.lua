local ccexpect = require "cc.expect"
local expect, field = ccexpect.expect, ccexpect.field
local config = require("config").config
local linkLayer = require "linkLayer"

local PROTOCOL = "itemLayer"
local stockUpdate = "stock_update"
local orderRequest = "order_request"
local orderResponse = "order_response"
local eventList = {
    stockUpdate,
    orderRequest,
    orderResponse
}
--
local function tableContains(table, value)
    local i = 1
    repeat
        if (table[i] == value) then return true end
    until i == #table
    return false
end

local function handleData(data)
    -- expect(1, "data", "table", "nil")
    -- expect(field(data, "protocol"), "string")
    -- expect(field(data, "type"), "string")

    if data == nil then return nil end

    if data.protocol ~= PROTOCOL then
        return nil
    end

    if not tableContains(eventList, data.type) then
        return nil
    end

    os.queueEvent(data.type, data)
end

local function handleModemEvent(event)
    -- expect(1, "event", "table")

    if event[1] ~= "modem_message" then
        return nil
    end

    local payload = event[5]
    local data = linkLayer.recievePayload(payload)
    handleData(data)
end

local function packStock(items)
    -- expect(1, "items", "table")

    local data = {
        protocol = PROTOCOL,
        type = stockUpdate,
        timestamp = os.epoch("utc"),
        items = items
    }

    return data
end

local function sendStock(modem, channel, returnChannel, items)
    -- expect(1, "modem", "table")
    -- expect(2, "channel", "number")
    -- expect(3, "returnChannel", "number")
    -- expect(4, "items", "table")

    local data = packStock(items)
    linkLayer.sendData(modem, channel, returnChannel, data)
end

local function packOrder(items, requestId, address, channel)
    -- expect(1, "items", "table")
    -- expect(2, "requestID", "string")
    -- expect(3, "address", "string")
    -- expect(4, "channel", "number")

    local data = {
        protocol = PROTOCOL,
        type = orderRequest,
        requestId = requestId,
        address = address,
        senderLabel = os.getComputerLabel() or "UNKNOWN",
        items = items,
        timestamp = os.epoch("utc"),
        channel = channel
    }

    return data
end

local function sendOrder(modem, channel, returnChannel, items, requestId, address)
    -- expect(1, "modem", "table")
    -- expect(2, "channel", "number")
    -- expect(3, "returnChannel", "number")
    -- expect(4, "items", "table")
    -- expect(5, "requestId", "string")
    -- expect(6, "address", "string")

    local data = packOrder(items, requestId, address, channel)
    linkLayer.sendData(modem, channel, returnChannel, data)
end

local function packOrderResponse(requestId, address, result, success, channel)
    -- expect(1, "requestId", "string")
    -- expect(2, "address", "string")
    -- expect(3, "result", "table")
    -- expect(4, "success", "boolean")
    -- expect(5, "channel", "number")

    local data = {
        protocol = PROTOCOL,
        type = orderResponse,
        requestId = requestId,
        address = address,
        result = result,
        success = success,
        channel = channel
    }

    return data
end

local function sendOrderResponse(modem, channel, returnChannel, requestId, address, result, success)
    -- expect(1, "modem", "table")
    -- expect(2, "channel", "number")
    -- expect(3, "returnChannel", "number")
    -- expect(4, "requestId", "string")
    -- expect(5, "address", "string")
    -- expect(6, "result", "table")
    -- expect(7, "success", "boolean")

    local data = packOrderResponse(requestId, address, result, success, channel)
    linkLayer.sendData(modem, channel, returnChannel, data)
end

return {
    handleModemEvent = handleModemEvent,
    sendStock = sendStock,
    sendOrder = sendOrder,
    sendOrderResponse = sendOrderResponse,
    stockUpdate = stockUpdate,
    orderRequest = orderRequest,
    orderResponse = orderResponse
}
