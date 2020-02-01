function proxy(componentType) return component.proxy(component.list(componentType)()) end
function clear() gpu.setBackground(0x000000) gpu.fill(1, 1, 60, 19, " ") end
local eeprom = proxy("eeprom")
gpu = proxy("gpu")
internet = proxy("internet")

gpu.bind(component.list("screen")(), true)
gpu.setResolution(60, 19)
gpu.setForeground(0x68f029)
clear()
gpu.set(23, 9, "Инициализация...")

local running = false

local users = {computer.users()}
admins = {}

for admin = 1, #admins do 
    computer.addUser(admins[admin])
    admins[admins[admin]], admins[admin] = true, nil
end 
for user = 1, #users do 
    if not admins[users[user]] then
        computer.removeUser(users[user])
    end
end
if eeprom.getData() == "true" then 
    dev = true
else 
    dev = false 
end

local function help() 
    clear() 
    gpu.set(18, 8, "CTRL+A — режим разработки") 
    gpu.set(18, 9, "CTRL+S — запуск программы") 
    gpu.set(16, 10, "CTRL+D — обновление программы") 
    gpu.set(12, 11, "CTRL+ALT+C — принудительная остановка") 
end

local function customError(err)
    clear()
    gpu.setForeground(0xff0000)
    gpu.set(23, 1, "Фатальная ошибка!")
    gpu.setForeground(0x68f029)

    local lines, y = {}

    for line in err:gmatch("[^\r\n]+") do
        line = line:gsub("\t", "")
        if unicode.len(line) > 60 then
            for i = 1, math.ceil(unicode.len(line) / 60) do
                local before = i * 60
                lines[#lines + 1] = unicode.sub(line, before - 59, before)
            end
        else
            lines[#lines + 1] = line
        end
    end

    local y = 11 - #lines / 2

    for i = 1, #lines do
        gpu.set(math.floor(31 - unicode.len(lines[i]) / 2), y, lines[i])
        y = y + 1
    end
end

local function findFilesystem()
    for address in component.list("filesystem") do 
        if address ~= computer.tmpAddress() and not component.invoke(address, "isReadOnly") then
            filesystem = component.proxy(address)
            return true
        end
    end

    if not filesystem then
        customError("Файловая система не найдена!")
    end
end

local function develop() 
    clear() 
    if not dev then 
        gpu.set(16, 9, "Включение режима разработки...") 
        eeprom.setData("true") 
        dev = true
    else
        gpu.set(15, 9, "Выключение режима разработки...") 
        eeprom.setData("false") 
        dev = false
    end
    help()
end

local function update()
    clear()
    gpu.set(20, 9, "Обновление программы...")
    write("/shop.lua", "w", request("https://raw.githubusercontent.com/BrightYC/RipMarket/master/terminal.lua"))
end

local function run()
    if not filesystem.exists("/shop.lua") then
        update()
    end

    if filesystem.exists("/shop.lua") then
        clear()
        gpu.set(25, 9, "Загрузка...")
        running = true
        execute(read("/shop.lua"), "=shop.lua")
        running = false
    end
end

local pullSignal = computer.pullSignal
computer.pullSignal = function(...)
    local signal = {pullSignal(...)}

    if signal[1] == "key_down" then
        if signal[4] == 29 then
            isControlDown = true
        elseif signal[4] == 42 then
            ifShiftDown = true
        elseif signal[4] == 56 then 
            isAltDown = true
        elseif isControlDown and admins[signal[5]] and filesystem then
            if running then
                if signal[4] == 46 and isAltDown then
                    error("interrupted")
                end
            else
                if signal[4] == 30 then
                    develop()
                elseif signal[4] == 31 then
                    run()
                elseif signal[4] == 32 then       
                    update()
                    run()
                end
            end
        end
    elseif signal[1] == "key_up" then
        if signal[4] == 29 then
            isControlDown = false
        elseif signal[4] == 42 then
            ifShiftDown = false
        elseif signal[4] == 56 then 
            isAltDown = false
        end
    end

    return table.unpack(signal)
end

function execute(data, stdin)
    local chunk, err = load(data, stdin, "t")

    if not chunk and err then
        customError(err)
    else
        local data = table.pack(xpcall(chunk, debug.traceback))
        if data[1] then
            if data.n > 1 then
                return table.unpack(data, 2, data.n)
            end
        else
            customError(data[2])
        end
    end
end

function read(path)
    local handle = filesystem.open(path, "r")
    local data = ""

    while true do 
        local chunk = filesystem.read(handle, 2048)

        if chunk then
            data = data .. chunk 
        else
            break
        end
    end

    filesystem.close(handle)
    return data
end

function require(name)
    local path = "/lib/" .. name .. ".lua"

    if not filesystem.exists(path) then
        customError("Library " .. name .. " doesn't exists!")
    else
        return execute(read(path), "=" .. name .. ".lua")
    end
end

function write(path, mode, data)
    local handle = filesystem.open(path, mode)
    filesystem.write(handle, data)
    filesystem.close(handle)
end

function request(path)
    handle, data, chunk = internet.request(path), ""

    while true do
        chunk = handle.read(math.huge)

        if chunk then
            data = data .. chunk
        else
            break
        end
    end
     
    return data
end

function sleep(timeout)
    local deadline = computer.uptime() + (timeout or math.huge)

    repeat
        computer.pullSignal(deadline - computer.uptime())
    until computer.uptime() >= deadline
end

findFilesystem()
if filesystem then
    help()
end

while true do 
    computer.pullSignal(math.huge)
end
