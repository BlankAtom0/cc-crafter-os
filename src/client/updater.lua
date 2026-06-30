local clientpastebin =
"PwPVMVXT"

local function printHeader(text)
    print()
    print(("=== %s ==="):format(text))
end

if shell.dir() ~= "client" then
    if not fs.isDir("client") then
        fs.makeDir("client")
    end
    shell.setDir("client")
end

printHeader("Updater")
if fs.exists("client.lua") then
    os.remove("client.lua")
end

shell.run("pastebin get", clientpastebin, "client.lua")

print("Client updated.")

print("Restarting computer...")
os.reboot()
