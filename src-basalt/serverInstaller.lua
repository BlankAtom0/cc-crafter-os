local itemLayerAddress =
"https://raw.githubusercontent.com/BlankAtom0/cc-crafter-os/refs/heads/main/src-basalt/itemLayer.lua"
local linkLayerAddress =
"https://raw.githubusercontent.com/BlankAtom0/cc-crafter-os/refs/heads/main/src-basalt/linkLayer.lua"
local serverAddress = "https://raw.githubusercontent.com/BlankAtom0/cc-crafter-os/refs/heads/main/src-basalt/server.lua"

local function printHeader(text)
    print()
    print(("=== %s ==="):format(text))
end

local function ask(prompt, default)
    write(prompt)
    if default ~= nil then write(" [" .. tostring(default) .. "]") end
    write(": ")
    local input = read()
    if input == "" and default ~= nil then return default end
    return input
end

local function askNumber(prompt, default)
    while true do
        local raw = ask(prompt, default)
        local n = tonumber(raw)
        if n then return n end
        print("Please enter a number.")
    end
end

local function main()
    printHeader("Server Installer")
    printHeader("Installing dependencies")

    print("Installing layers")
    shell.run("wget", linkLayerAddress)
    shell.run("wget", itemLayerAddress)

    print("Installing server")
    shell.run("wget", serverAddress)

    printHeader("Creating Config.")
    local stockChannel = askNumber("Enter the stock channel number", 1)
    local orderChannel = askNumber("Enter the order channel number", 1)
    local scanDelay = askNumber("Enter scan delay", 5)

    local config = {
        STOCK_CHANNEL = stockChannel,
        ORDER_CHANNEL = orderChannel,
        SCAN_DELAY = scanDelay
    }

    local configJson = textutils.serialiseJSON(config)

    if fs.exists("config.json") then
        fs.delete("config.json")
    end

    local configFile = fs.open("config.json", "w")
    configFile.write(configJson)
    configFile.close()
end

main()
