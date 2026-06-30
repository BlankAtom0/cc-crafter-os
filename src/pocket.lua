local STOCK_CHANNEL  = 53321
local ORDER_CHANNEL  = 53322
local CHANNEL        = 53323
local STALE_SECS     = 15

local W, H           = term.getSize()
local LIST_TOP       = 4
local LIST_BOT       = H - 2
local LIST_H         = LIST_BOT - LIST_TOP + 1
local ADDR_ROW       = H - 1
local STAT_ROW       = H

local allItems       = {}
local filtered       = {}
local order          = {}

local tab            = "search"
local query          = ""
local queryFocus     = false

local addrText       = ""
local addrFocus      = false

local qtyBuffer      = ""
local selectedIdx    = nil

local editIdx        = nil

local scroll         = 0
local lastUpdate     = 0

local pendingRequest = nil
local modem

local function col(c) if term.isColour() then term.setTextColour(c) end end
local function bcol(c) if term.isColour() then term.setBackgroundColour(c) end end
local function rst()
    col(colours.white)
    bcol(colours.black)
end

local function uuid()
    return tostring(os.epoch("utc")) .. "-" .. tostring(math.random(1, 99999))
end

local function drawTitle()
    bcol(colours.blue); col(colours.white)
    term.setCursorPos(1, 1); term.clearLine()

    local searchTab = (tab == "search") and "[Search]" or " Search "
    local orderTab = (tab == "order") and "[Order]" or " Order "
    local orderCount = "(" .. #order .. ")"
    local orderLabel = orderTab .. (#order > 0 and orderCount or "")

    term.write(" \x07 Storage Terminal")
    local counts = tostring(#filtered) .. "/" .. tostring(#allItems)
    term.setCursorPos(W - #counts, 1)
    term.write(counts)
    term.setCursorPos(1, 2)
    rst()
    term.clearLine()
    term.write(" ")
    if tab == "search" then
        bcol(colours.blue); col(colours.white)
        term.write(searchTab)
        bcol(colours.grey)
        term.write(orderLabel)
    else
        bcol(colours.grey); col(colours.white)
        term.write(searchTab)
        bcol(colours.blue)
        term.write(orderLabel)
    end
    rst()
end

local function drawSecondRow()
    if tab == "search" then
        if searchFocus then
            bcol(colours.white); col(colours.black)
        else
            bcol(colours.grey); col(colours.lightGrey)
        end
        term.setCursorPos(1, 3); term.clearLine()
        local text = (query == "" and not searchFocus) and " Tab to search..." or (" > " .. query)
        term.write(text)
        rst()
    else
        bcol(colours.grey); col(colours.white)
        term.setCursorPos(1, 3); term.clearLine()
        local total = 0
        for _, it in ipairs(order) do total = total + it.count end
        term.write(string.format(" %d item types, %d total qty", #order, total))
        rst()
    end
end

local function drawSearchList()
    for row = 0, LIST_H - 1 do
        local idx = row + scroll + 1
        local item = filtered[idx]
        term.setCursorPos(1, LIST_TOP + row)
        term.clearLine()

        if item then
            local isSelected = (selectedIdx == idx)
            if isSelected then
                bcol(colours.cyan); col(colours.black)
            elseif row % 2 == 0 then
                bcol(colours.black); col(colours.white)
            else
                bcol(colours.grey); col(colours.white)
            end

            local countStr = "x" .. tostring(item.count)
            local nameW    = W - 1 - #countStr
            local name     = item.displayName
            if #name > nameW - 1 then name = name:sub(1, nameW - 2) .. "\xbb" end

            term.write((" %-" .. (nameW - 1) .. "s"):format(name))
            if not isSelected then col(colours.yellow) end
            term.write(countStr); term.write(" ")
        else
            bcol(colours.black)
        end
    end
    rst()

    if selectedIdx and filtered[selectedIdx] then
        bcol(colours.cyan); col(colours.black)
        term.setCursorPos(1, LIST_BOT); term.clearLine()
        local label = "Qty: " .. qtyBuffer .. "_ [Ent=Add Esc=Cancel]"
        term.write(" " .. label:sub(1, W - 2))
        rst()
    end
end

local function drawOrderList()
    for row = 0, LIST_H - 1 do
        local idx = row + scroll + 1
        local item = order[idx]
        term.setCursorPos(1, LIST_TOP + row)
        term.clearLine()

        if item then
            local isEditing = (editIdx == idx)
            if isEditing then
                bcol(colours.orange); col(colours.black)
            elseif row % 2 == 0 then
                bcol(colours.black); col(colours.white)
            else
                bcol(colours.grey); col(colours.white)
            end

            local qtyStr = isEditing and ("x" .. qtyBuffer .. "_") or ("x" .. tostring(item.count))
            local nameW = W - 1 - #qtyStr - 6
            local name = item.displayName
            if #name > nameW - 1 then name = name:sub(1, nameW - 2) .. "\xbb" end

            term.write((" %-" .. (nameW - 1) .. "s"):format(name))
            if not isEditing then col(colours.yellow) end
            term.write(qtyStr)
            col(colours.lightGrey)
            term.write(" \x5b\x45\x5d\x5b\x44\x5d")
        else
            bcol(colours.black)
        end
        rst()
    end

    if editIdx then
        bcol(colours.orange); col(colours.black)
        term.setCursorPos(1, LIST_BOT); term.clearLine()
        term.write(" Editing qty: " .. qtyBuffer .. "_ [Enter=Save Esc=Cancel]")
        rst()
    elseif #order > 0 then
        bcol(colours.green); col(colours.black)
        term.setCursorPos(1, LIST_BOT); term.clearLine()
        term.write(" [Enter] Submit [C] Clear")
        rst()
    else
        term.setCursorPos(1, LIST_BOT); term.clearLine()
        col(colours.lightGrey)
        term.write(" Order empty")
        rst()
    end
end

local function drawAddressBar()
    if addrFocus then
        bcol(colours.white); col(colours.black)
    else
        bcol(colours.grey); col(colours.lightGrey)
    end
    term.setCursorPos(1, ADDR_ROW); term.clearLine()

    local text = " Addr: " .. addrText
    term.write(text:sub(1, W))
    rst()
end

local function drawScrollbar()
    if #filtered <= LIST_H then return end
    local thumb = math.max(1, math.floor(LIST_H * LIST_H / #filtered))
    local pos = math.floor((LIST_H - thumb) * scroll / math.max(1, #filtered - LIST_H))
    for row = 0, LIST_H - 1 do
        term.setCursorPos(W, LIST_TOP + row)
        if row >= pos and row < pos + thumb then
            col(colours.lightGrey)
        else
            col(colours.grey)
        end
        term.write("\x95")
    end
    rst()
end

local function drawStatus()
    local age = math.floor((os.epoch("utc") - lastUpdate) / 1000)
    local stale = lastUpdate == 0 or age > STALE_SECS
    term.setCursorPos(1, H); term.clearLine()

    if pendingRequest then
        bcol(colours.orange); col(colours.black)
        term.write(" Submitting order...")
    elseif lastUpdate == 0 then
        bcol(colours.orange); col(colours.black)
        term.write(" Waiting for server... ")
    elseif stale then
        bcol(colours.red); col(colours.white)
        term.write(string.format(" No signal (%ds ago) ", age))
    else
        bcol(colours.green); col(colours.black)
        term.write(string.format(" OK \xb7 %ds ago ", age))
    end
    rst()
end

local function positionCursor()
    if searchFocus and tab == "search" and not selectedIdx then
        term.setCursorPos(4 + #query, 2)
    elseif addrFocus then
        term.setCursorPos(7 + math.min(#addrText, W - 8), ADDR_ROW)
    else
        term.setCursorPos(W, STAT_ROW)
    end
end

local function redraw()
    drawTitle()
    drawSecondRow()
    if tab == "search" then
        drawSearchList()
    else
        drawOrderList()
    end
    drawAddressBar()
    drawStatus()
    positionCursor()
end

local function applyFilter()
    scroll = 0
    if query == "" then
        filtered = allItems
        return
    end
    local q = query:lower()
    filtered = {}
    for _, item in ipairs(allItems) do
        if item.displayName:lower():find(q, 1, true) or item.name:lower():find(q, 1, true) then
            filtered[#filtered + 1] = item
        end
    end
end

local function currentListLen()
    return (tab == "search") and #filtered or #order
end

local function clampScroll()
    local len = currentListLen()
    scroll = math.max(0, math.min(scroll, math.max(0, len - LIST_H)))
end

local function scrollBy(n)
    scroll = scroll + n; clampScroll()
end

local function addToOrder(item, count)
    for _, existing in ipairs(order) do
        if existing.name == item.name then
            existing.count = existing.count + count
            return
        end
    end
    table.insert(order, {
        name = item.name,
        displayName = item.displayName,
        count = count
    })
end

local function removeFromOrder(idx)
    table.remove(order, idx)
end

local function openModem()
    modem = peripheral.find("modem")
    if modem then
        modem.open(CHANNEL)
        modem.open(STOCK_CHANNEL)
        return true
    end
    return false
end

local function submitOrder()
    if #order == 0 then return end

    local address = addrText
    if address == "" then
        address = os.getComputerLabel() or ""
    end

    local reqId = uuid()
    local items = {}
    for _, it in ipairs(order) do
        table.insert(items, { name = it.name, count = it.count })
    end

    local payload = textutils.serialize({
        type = "order_request",
        requestId = reqId,
        address = address,
        senderLabel = os.getComputerLabel() or "UNKNOWN",
        items = items,
        timestamp = os.epoch("utc"),
        channel = CHANNEL
    })

    modem.transmit(ORDER_CHANNEL, CHANNEL, payload)
    pendingRequest = reqId
end

local function handleSearchTabChar(c)
    if selectedIdx then
        if c:match("%d") then qtyBuffer = qtyBuffer .. c end
    elseif searchFocus then
        query = query .. c
        applyFilter()
    end
end

local function handleSearchTabKey(k)
    if selectedIdx then
        if k == keys.enter then
            local qty = tonumber(qtyBuffer)
            if qty and qty > 0 then
                addToOrder(filtered[selectedIdx], qty)
            end
            selectedIdx = nil
            qtyBuffer = ""
        elseif k == keys.backspace then
            qtyBuffer = qtyBuffer:sub(1, -2)
        elseif k == keys.escape then
            selectedIdx = nil
            qtyBuffer = ""
        end
        redraw()
        return
    end

    if searchFocus then
        if k == keys.backspace then
            query = query:sub(1, -2); applyFilter()
        elseif k == keys.enter then
            local idx = scroll + 1
            if filtered[idx] then
                selectedIdx = idx
                qtyBuffer = ""
            end
        elseif k == keys.escape then
            searchFocus = false
        elseif k == keys.down then
            scrollBy(1)
        elseif k == keys.up then
            scrollBy(-1)
        end
    else
        if k == keys.down then
            scrollBy(1)
        elseif k == keys.up then
            scrollBy(-1)
        elseif k == keys.pageDown then
            scrollBy(LIST_H)
        elseif k == keys.pageUp then
            scrollBy(-LIST_H)
        end
    end
    redraw()
end

local function handleOrderTabKey(k)
    if editIdx then
        if k == keys.enter then
            local qty = tonumber(qtyBuffer)
            if qty and qty > 0 and order[editIdx] then
                order[editIdx].count = qty
            end
            editIdx = nil; qtyBuffer = ""
        elseif k == keys.backspace then
            qtyBuffer = qtyBuffer:sub(1, -2)
        elseif k == keys.escape then
            editIdx = nil; qtyBuffer = ""
        end
        redraw()
        return
    end

    if k == keys.down then
        scrollBy(1)
    elseif k == keys.up then
        scrollBy(-1)
    elseif k == keys.pageDown then
        scrollBy(LIST_H)
    elseif k == keys.pageUp then
        scrollBy(-LIST_H)
    elseif k == keys.enter then
        submitOrder()
    elseif k == keys.c then
        order = {}
        clampScroll()
    end
    redraw()
end

local function handleClick(x, y)
    if y == 2 then
        if x >= 2 and x <= 9 then
            tab = "search"; searchFocus = false; addrFocus = false; scroll = 0
        elseif x >= 10 and x <= 17 then
            tab = "order"; searchFocus = false; scroll = 0
        end
        return
    end

    if y == 3 then
        if tab == "search" then
            searchFocus = true
            addrFocus = false
        end
        return
    end

    if y == ADDR_ROW then
        addrFocus = true
        searchFocus = false
        selectedIdx = nil
        editIdx = nil
        return
    end

    if y >= LIST_TOP and y <= LIST_BOT then
        local row = y - LIST_TOP
        local idx = row + scroll + 1

        if tab == "search" then
            if filtered[idx] then
                selectedIdx = idx
                qtyBuffer = ""
                searchFocus = false
            end
        else
            if order[idx] then
                if x >= W - 4 and x <= W - 3 then
                    editIdx = idx
                    qtyBuffer = tostring(order[idx].count)
                elseif x >= W - 2 and x <= W - 1 then
                    removeFromOrder(idx)
                    clampScroll()
                end
            end
        end
        return
    end
end

local function main()
    math.randomseed(os.epoch("utc"))
    term.clear()
    if not openModem() then
        term.setCursorPos(1, 1)
        print("ERROR: No modem found.")
        return
    end

    applyFilter()
    redraw()

    local function ticker()
        while true do
            sleep(1); drawStatus(); positionCursor()
        end
    end

    local function events()
        while true do
            local ev = table.pack(os.pullEvent())
            local e = ev[1]

            if e == "modem_message" then
                local ch, msg = ev[3], ev[5]
                if ch == STOCK_CHANNEL or ch == CHANNEL then
                    local ok, payload = pcall(textutils.unserialize, msg)
                    if ok and payload then
                        if payload.type == "stock_update" then
                            allItems = payload.items or {}
                            lastUpdate = payload.timestamp or os.epoch("utc")
                            applyFilter()
                            redraw()
                        elseif payload.type == "order_response" and payload.requestId == pendingRequest then
                            pendingRequest = nil
                            if payload.success then
                                order = {}
                            end
                            clampScroll()
                            redraw()
                        end
                    end
                end
            elseif e == "char" then
                local c = ev[2]
                if addrFocus then
                    addrText = addrText .. c
                elseif tab == "search" then
                    handleSearchTabChar(c)
                end
                redraw()
            elseif e == "key" then
                local k = ev[2]
                if addrFocus then
                    if k == keys.backspace then
                        addrText = addrText:sub(1, -2)
                    elseif k == keys.enter or k == keys.escape then
                        addrFocus = false
                    end
                    redraw()
                elseif tab == "search" then
                    handleSearchTabKey(k)
                else
                    handleOrderTabKey(k)
                end
            elseif e == "mouse_click" or e == "mouse_up" then
                local x, y = ev[3], ev[4]
                handleClick(x, y)
                redraw()
            elseif e == "mouse_scroll" then
                scrollBy(ev[2]); redraw()
            elseif e == "term_resize" then
                W, H = term.getSize()
                LIST_BOT = H - 2; LIST_H = LIST_BOT - LIST_TOP + 1
                ADDR_ROW = H - 1; STAT_ROW = H
                clampScroll(); term.clear(); redraw()
            end
        end
    end

    parallel.waitForAny(ticker, events)
end

main()
