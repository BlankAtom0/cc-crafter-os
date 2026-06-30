local clientURL =
"https://raw.githubusercontent.com/BlankAtom0/cc-crafter-os/refs/heads/main/src/pocket.lua?token=GHSAT0AAAAAAEAEZXJHQF3FM7RV7S5YDIJE2SDYYSA"

local function printHeader(text)
    print()
    print(("=== %s ==="):format(text))
end

printHeader("Updater")
local response = http.get(clientURL)
if not response then
    print("Failed to download client.")
    return
end
if fs.exists("client.lua") then
    os.remove("client.lua")
end

local clientFile = io.open("client.lua", "w")
if not clientFile then
    print("Failed to open client file.")
    return
end
clientFile:write(response.readAll())
clientFile:close()

print("Client updated.")

print("Restarting computer...")
os.reboot()
