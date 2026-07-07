local configFile = fs.open("config.lua", "r")

local config = textutils.unserialiseJSON(configFile.readAll())

return config
