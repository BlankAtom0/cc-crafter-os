local ccexpect = require "cc.expect"
local base64 = require "cc.base64"
local expect, field = ccexpect.expect, ccexpect.field

local PROTOCOL = "cc-linklayer"

local function encode(data)
    expect(1, data, "table")
    local serialised = textutils.serialise(data)
    local encoded = base64.encode(serialised)
    return encoded
end

local function decode(encoded)
    expect(1, encoded, "string")
    local decoded = base64.decode(encoded)
    local data = textutils.unserialise(decoded)
    return data
end

local function sendData(modem, channel, returnChannel, data)
    -- expect(1, modem, "table")
    -- expect(2, channel, "number")
    -- expect(3, returnChannel, "number")
    -- expect(4, data, "table")

    local encoded = encode(data)
    local payload = {
        protocol = PROTOCOL,
        channel = channel,
        returnChannel = returnChannel,
        data = encoded
    }
    modem.transmit(channel, returnChannel, textutils.serialise(payload))
end

local function recievePayload(payload)
    -- expect(1, payload, "table")
    -- expect(field(payload, "protocol"), "string")
    -- expect(field(payload, "channel"), "number")
    -- expect(field(payload, "returnChannel"), "number")
    -- expect(field(payload, "data"), "string")

    if payload.protocol ~= PROTOCOL then
        return nil
    end
    return decode(payload.data)
end

return { encode = encode, decode = decode, sendData = sendData, recievePayload = recievePayload }
