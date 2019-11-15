local event = require("event")
local computer = require("computer")
local admins = {} --Те, кто смогут закрыть программу.
for admin = 1, #admins do 
	computer.addUser(admins[admin])
    admins[admins[admin]], admins[admin] = true, nil
end 
os.execute("shop.lua")

require("process").info().data.signal = function() end
print("Произошла ошибка. Ожидайте администрацию для решения проблемы.")


local users = {computer.users()}
for user = 1, #users do
    if not admins[users[user]] then
    	computer.removeUser(users[user])
    end
end

while true do
  	local user = select(5, event.pull("key_down"))

  	if admins[user] then
  		os.exit()
  	end
end
