local config = require "config"

local itemLayerAddress =
"https://raw.githubusercontent.com/BlankAtom0/cc-crafter-os/refs/heads/main/src-basalt/itemLayer.lua"
local linkLayerAddress =
"https://raw.githubusercontent.com/BlankAtom0/cc-crafter-os/refs/heads/main/src-basalt/linkLayer.lua"
local clientAddress = "https://raw.githubusercontent.com/BlankAtom0/cc-crafter-os/refs/heads/main/src-basalt/client.lua"
local serverAddress = "https://raw.githubusercontent.com/BlankAtom0/cc-crafter-os/refs/heads/main/src-basalt/server.lua"

local function update()
    fs.delete("itemLayer.lua")
    fs.delete("linkLayer.lua")

    shell.run("wget", itemLayerAddress)
    shell.run("wget", linkLayerAddress)
    if config.TYPE == "client" then
        fs.delete("client.lua")
        shell.run("wget", clientAddress)
    elseif config.TYPE == "server" then
        fs.delete("server.lua")
        shell.run("wget", serverAddress)
    end
end
