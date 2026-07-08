local configFile = fs.open("config.json", "r")
local configJS = configFile.readAll()
local config = textutils.unserialiseJSON(configJS)

return { config = config }
