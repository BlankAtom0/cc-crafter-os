local itemLayerAddress =
"https://raw.githubusercontent.com/BlankAtom0/cc-crafter-os/refs/heads/main/src-basalt/itemLayer.lua"
local linkLayerAddress =
"https://raw.githubusercontent.com/BlankAtom0/cc-crafter-os/refs/heads/main/src-basalt/linkLayer.lua"
local clientAddress = "https://raw.githubusercontent.com/BlankAtom0/cc-crafter-os/refs/heads/main/src-basalt/client.lua"
local configAddress = "https://raw.githubusercontent.com/BlankAtom0/cc-crafter-os/refs/heads/main/src-basalt/config.lua"

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
    printHeader("Client Installer")
    printHeader("Installing dependencies")

    print("Installing basalt")
    shell.run("wget run https://raw.githubusercontent.com/Pyroxenium/Basalt2/main/install.lua -f")

    print("Installing layers")
    shell.run("wget", linkLayerAddress)
    shell.run("wget", itemLayerAddress)

    print("Installing client")
    shell.run("wget", clientAddress)

    printHeader("Creating Config.")
    local stockChannel = askNumber("Enter the stock channel number", 1)
    local orderChannel = askNumber("Enter the order channel number", 1)
    local clientNo = askNumber("Enter the client number", 1)
    local staleTimeout = askNumber("Enter stale timeout", 15)

    local config = {
        STOCK_CHANNEL = stockChannel,
        ORDER_CHANNEL = orderChannel,
        CLIENT_CHANNEL = orderChannel + clientNo + 1,
        STALE_TIMEOUT = staleTimeout
    }

    local configJson = textutils.serialiseJSON(config)

    if fs.exists("config.json") then
        fs.delete("config.json")
    end

    local configFile = fs.open("config.json", "w")
    configFile.write(configJson)
    configFile.close()

    print("Installing config")
    shell.run("wget", configAddress)
end

main()
