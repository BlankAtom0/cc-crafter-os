local clientURL =
"https://raw.githubusercontent.com/BlankAtom0/cc-crafter-os/refs/heads/main/src/client/client.lua?token=GHSAT0AAAAAAEAEZXJG33P3LBRHOUKYP6EW2SD2LWQ"

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
