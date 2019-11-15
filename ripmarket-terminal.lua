local component = require("component")
local unicode = require("unicode")
local serialization = require("serialization")
local keyboard = require("keyboard")
local term = require("term")
local filesystem = require("filesystem")
local event = require("event")
local computer = require("computer")
local gpu, pim, me, internet = component.gpu, component.pim, component.me_interface, component.internet
local admins = {} --Те, кто могут администрировать программу(Закрывать её, вводить в тех-работы, обновлять список товаров.)
local dev = false --Режим "Разработки". Только администрация может войти, если включен.
local key, server = "Токен(Указывать в сервере)", "Имя сервера(Игрового)"
local terminal = unicode.sub(internet.address, 1, 15)

local me_side = "DOWN"
local pim_side = "UP"
local pimX = 23
local pimY = 8
local restoreDrawX = 18
local restoreDrawY = 8

local active = true
local itemsUpdateTimer = computer.uptime() + 600
local input = ""
local gui = "login"
local oldGui = false
local focus = false
local restoreDrawActive = false
local guiPage = 1 
local guiScroll = 1
local oreScan = false
local sellScan = false
local activeItem = false
local banned = false

local color = {
    pattern = "%[0x(%x%x%x%x%x%x)]",
    background = 0x0a0a0a,
    pim = 0x46c8e3,

    gray = 0x303030,
    lightGray = 0x999999,
    blackGray = 0x1a1a1a,
    lime = 0x68f029,
    blackLime = 0x4cb01e,
    orange = 0xf2b233,
    blackOrange = 0xc49029,
    blue = 0x4260f5,
    blackBlue = 0x273ba1,
    red = 0xff0000,
}

local listIn = {
    "buy",
    "sell"
}

local INFO = [[
[0x68f029]1. [0xffffff]Что это такое? Ответ — Это магазин/обменник. Как угодно.
[0x68f029]2. [0xffffff]Как обменять товар на рипы? Ответ — нужно выбрать товар и положить его в 1 слот.
[0x68f029]3. [0xffffff]Как купить товар? Ответ — выбираете товар, набираете кол-во товара, и товар будет добавлен в ваш инвентарь. Если денег недостаточно - товар нельзя купить.
[0x68f029]4. [0xffffff]Как обменять руду? Ответ — происходит сканирование 1 слота. Если руда будет найдена — руда обменяется.
[0x68f029]5. [0xffffff]Как получить бесплатную еду? Ответ — нажимаете кнопку "Бесплатная еда" и вам выдаётся стак случайной еды(В данный момент — арбузы).
[0x68f029]6. [0xffffff]Что такое R.I.P? Ответ — это вымышленная валюта — RIPкоин(aka рип, рипы).
[0x68f029]7. [0xffffff]Как сыграть в лотерею? Ответ — нажимаете кнопку "Сыграть" и узнаёте свой выигрыш.
]]

local infoList, session, items, screen, allItemsList, itemsList, thumb = {{}}, {}, {}, {}, {}, {}, {}

local function set(x, y, str, background, foreground, vertical)
    if background and gpu.getBackground() ~= background then
        gpu.setBackground(background)
    end

    if foreground and gpu.getForeground() ~= foreground then
        gpu.setForeground(foreground)
    end

    gpu.set(x or math.floor(31 - unicode.len(str) / 2), y, str, vertical)
end

local function setColorText(x, y, str)
    if not x then
        x = math.floor(31 - unicode.len(str:gsub("%[%w+]", "")) / 2)
    end

    local begin = 1

    while true do
        local b, e, color = str:find(color.pattern, begin)
        local precedingString = str:sub(begin, b and (b - 1))

        if precedingString then
            gpu.set(x, y, precedingString)
            x = x + unicode.len(precedingString)
        end

        if not color then
            break
        end

        gpu.setForeground(tonumber(color, 16))
        begin = e + 1
    end
end

local function fill(x, y, w, h, symbol, background, foreground)
    if background and gpu.getBackground() ~= background then
        gpu.setBackground(background)
    end

    if foreground and gpu.getForeground() ~= foreground then
        gpu.setForeground(foreground)
    end

    gpu.fill(x, y, w, h, symbol)
end

local function clear()
    fill(1, 1, 60, 19, " ", color.background)
end

local function outOfService(reason)
    active = false

    clear()
    set(8, 7, "Магазин не работает, приносим свои извинения за", color.background, color.lime)
    set(18, 8, "предоставленные неудобства", color.background, color.lime)
    set(23, 13, "OUT OF SERVICE!", color.background, color.red)
    if reason then
        set(nil, 16, "Причина: " .. reason, color.background, color.gray)
    end
    setColorText(6, 18, "[0x303030]По любым проблемам пишите в Discord: [0x337d11]BrightYC#0604")
end

local function time(raw)
    local file = io.open("/tmp/time", "w")
    file:write("time")
    file:close() 
    local timestamp = filesystem.lastModified("/tmp/time") / 1000 + 3600 * 3

    return raw and timestamp or os.date("%d.%m.%Y %H:%M:%S", timestamp)
end

local function log(data, name)
    local timestamp = time(true)
    local path = "/home/logs/" .. os.date("%d.%m.%Y", timestamp)
    local oldPath = "/home/logs/" .. os.date("%d.%m.%Y", timestamp - 259200)
    local file 

    if filesystem.exists(oldPath) then
        filesystem.remove(oldPath)
    end
    if not filesystem.exists(path) then
        filesystem.makeDirectory(path)
    end

    if name then
        file = io.open(path .. "/" .. name .. ".log", "a")
    else
        file = io.open(path .. "/terminal.log", "a")
    end

    file:write("[" .. os.date("%H:%M:%S", timestamp) .. "] " .. tostring(data) .. "\n")
    file:close()
end

local function sort(a, b)
    if type(a) ~= "table" and type(b) ~= "table" then
        return a < b
    elseif a.text then
        return a.text < b.text
    elseif a.user then
        return a.user < b.user
    end
end

local function loadInfo()
    local tag, str, symbols, words, page = false, "", 0, 0, 1

    for sym = 1, unicode.len(INFO) do 
        local symbol = unicode.sub(INFO, sym, sym)

        if not ((symbols == 0 or symbols == 60) and symbol == " ") then
            if symbol == "\n" and symbols >= 1 then
                table.insert(infoList[page], str)
                table.insert(infoList[page], "\n")
                str, symbols, words = "", 0, words + 1
            elseif symbol == "[" then
                tag = ""

                if str ~= "" then
                    table.insert(infoList[page], str)
                    str = ""
                end
            elseif symbol == "]" then
                table.insert(infoList[page], {tonumber(tag)})
                tag = false
            elseif tag then
                tag = tag .. symbol 
            else 
                if symbols == 60 then
                    table.insert(infoList[page], str)
                    table.insert(infoList[page], "\n")
                    str, symbols, words = "", 0, words + 1
                end

                str = str .. symbol
                symbols = symbols + 1 
            end

            if sym == unicode.len(INFO) and str ~= "" then
                table.insert(infoList[page], str)
            end

            if words == 13 then
                page, words = page + 1, 0
                infoList[page] = {}
            end
        end
    end
end

local function updateBuy()
    if items.buy then
        for item = 1, #items.buy do 
            items.buy[item].count = 0
            for fingerprint = 1, #items.buy[item].fingerprint do 
                local checkItem = me.getItemDetail(items.buy[item].fingerprint[fingerprint])

                if checkItem then
                    local itemBuy = checkItem.basic()
                    local count = math.floor(itemBuy.qty)
                    items.buy[item].count = items.buy[item].count and items.buy[item].count + count or count
                    items.buy[item].notVisible = false
                else
                    items.buy[item].count = items.buy[item].count or 0
                    items.buy[item].notVisible = fingerprint == #items.buy[item].fingerprint and true or false
                end
            end
        end
    end
end

local function encode(path)
    return (path:gsub("[^A-Za-z0-9_.~-]", function(c) return ("%%%02X"):format(c:byte()) end))
end

local function request(url)
    local handle, data, chunk = internet.request(url), ""    

    while true do
        chunk = handle.read(math.huge)
        if chunk then
            data = data .. chunk
        else
            break
        end
    end
     
    handle.close()

    return data
end

local function keyRequest(path)
    local data = request("https://aдрес-сервера/?key=" .. key .. "&server=" .. server .. "&terminal=" .. terminal .. path)

    if data == "Invalid server" then
        outOfService("неверный сервер")
    elseif data == "Invalid key" then
        outOfService("неверный ключ")
    elseif data == "Invalid method" then
        outOfService("неверный метод")
    elseif data == "Invalid user" then
        outOfService("неверный пользователь")
    else
        return data
    end
end

local function updateItems()
    if not filesystem.exists("/home/logs") then
        filesystem.makeDirectory("/home/logs")
    end

    local data = request("https://адрес-сервера/items.lua")
    items = serialization.unserialize(data) 

    table.sort(items.buy, sort)
    table.sort(items.sell, sort)
end

local function updateUser(log)
    keyRequest((log and "&log=" .. encode(log) .. "&" or "&") .. "method=update&user=" .. encode(session.name) .. "&balance=" .. session.balance .. "&transactions=" .. session.transactions .. "&feedback=" .. encode(session.feedback) .. "&foodTime=" .. session.foodTime)
end

local function drawButton(button, active)
    fill(buttons[button].x, buttons[button].y, buttons[button].width, buttons[button].height, " ", active and buttons[button].activeBackground or buttons[button].disabled and buttons[button].disabledBackground or buttons[button].background)
    set(buttons[button].textPosX + buttons[button].x, buttons[button].textPosY, buttons[button].text, active and buttons[button].activeBackground or buttons[button].disabled and buttons[button].disabledBackground or buttons[button].background, active and buttons[button].activeForeground or buttons[button].disabled and buttons[button].disabledForeground or buttons[button].foreground)
end

local function clickDrawButton(button)
    drawButton(button, true)
    os.sleep(.1)
    drawButton(button, false)
end

local function drawButtons()
    for button in pairs(buttons) do 
        if buttons[button].buttonIn and buttons[button].buttonIn[gui] and not buttons[button].notVisible then
            if buttons[button].withoutDraw then
                buttons[button].action(false)
            else
                drawButton(button, false)
            end
        end
    end
end

local function drawPim(active)
    gpu.setBackground(active and color.blackGray or 0x000000)
    gpu.setForeground(color.pim)

    gpu.set(pimX, pimY, "⡏")
    gpu.set(pimX, pimY + 7, "⣇")
    gpu.set(pimX + 15, pimY, "⢹")
    gpu.set(pimX + 15, pimY + 7, "⣸")

    gpu.fill(pimX, pimY + 1, 1, 6, "⡇")
    gpu.fill(pimX + 15, pimY + 1, 1, 6, "⢸")
    gpu.fill(pimX + 1, pimY, 14, 1, "⠉")
    gpu.fill(pimX + 1, pimY + 7, 14, 1, "⣀")
    gpu.fill(pimX + 1, pimY + 1, 14, 6, " ")

    os.sleep(.1)
end

local function block(nick)
    local timer = 15
    log("Другой игрок(" .. nick .. ") встал на PIM, блокирую магазин на 15 секунд...", session.name)
    restoreDraw("Автомат работает", "строго по одному")

    for i = 1, timer do  
        set(nil, restoreDrawY + 3, "Осталось: " .. timer, 0xffffff, color.blackGray)
        os.sleep(1)
        timer = timer - 1
        set(nil, restoreDrawY + 3, "               ", 0xffffff)
    end
    
    login()
end

local function checkPlayer(reason)
    local nick = pim.getInventoryName()

    if nick ~= session.name then
        if nick ~= "pim" then 
            if reason then
                log(reason, session.name)
            end

            block(nick)
        end
    else
        return true
    end
end

local function pushItem(slot, count)
    local item = pim.getStackInSlot(slot)

    if item then
        if checkPlayer("Был обнаружен игрок при попытке забрать предмет: ".. item.display_name .. "|id=" .. item.id) then
            if pim.pushItem(me_side, slot, count) >= 1 then
                log("Забираю предмет(" .. count .. " шт): display_name=" .. item.display_name .. "|id=" .. item.id, session.name)

                return true
            else
                log("Кончилось место в МЭ системе. Останавливаю работу...")
                outOfService("кончилось место в МЭ системе")

                return false
            end
        end
    end
end

local function findSlot()
    for slot = 1, 36 do 
        local success, err = pim.getStackInSlot(slot)

        if not success and not err then
            return slot
        elseif err then
            log("Игрок встал с PIM при поиске слота", session.name)
            login()
            return false, err
        end
    end
end

local function insertItem(fingerprint, count)
    local serialize = serialization.serialize(fingerprint)

    if checkPlayer("Был обнаружен другой игрок при попытке передать предмет: fingerprint=" .. serialize) then
        local slot, err = findSlot()

        if err then 
            return false
        elseif slot then
            local checkItem = me.getItemDetail(fingerprint)

            if checkItem then
                local item = checkItem.basic()

                if item.qty >= count then
                    log("Достаю предмет(" .. math.floor(count) .. " шт, всего: " ..  math.floor(item.qty) .."): fingerprint=" .. serialize, session.name)

                    if count > item.max_size then
                        for stack = 1, math.ceil(count / item.max_size) do
                            local stack = count > item.max_size

                            if not insertItem(fingerprint, stack and item.max_size or count) then
                                return false
                            end

                            count = stack and count - item.max_size or count
                        end

                        return true
                    else
                        local success, returnValue = pcall(me.exportItem, fingerprint, pim_side, count, slot)

                        if success then
                            if returnValue.size == 0 then
                                log("Предмет не выдан", session.name)
                            else
                                return true
                            end
                        else
                            log("Предмет не выдан, ошибка: " .. returnValue, session.name)
                        end
                    end
                end
            end
        else
            local timer = computer.uptime() + 20
            restoreDraw("Освободите любой слот", "Осталось: 20")

            repeat 
                local slot, err = findSlot()

                if err then 
                    return false
                elseif slot then
                    insertItem(fingerprint, count)
                    restoreDrawBack()

                    return true
                end

                set(22, restoreDrawY + 2, "               ", 0xffffff)
                set(nil, restoreDrawY + 2, "Осталось: " .. math.floor(timer - computer.uptime()), 0xffffff, color.blackGray)

                os.sleep(0)
            until false or timer < computer.uptime()

            log("Не было свободных слотов - предмет не выдан: fingerprint=" .. serialize, session.name)
            restoreDrawBack()
        end
    end

    return false
end

local function autoInsert(fingerprint, count)
    if #fingerprint == 1 then
        return insertItem(fingerprint[1], count)
    else
        local allCount, fingerprints = 0, {}

        for i = 1, #fingerprint do 
            local checkItem = me.getItemDetail(fingerprint[i])

            if checkItem then
                local itemCount = checkItem.basic().qty

                if itemCount >= count then
                    return insertItem(fingerprint[i], count)
                else
                    if itemCount + allCount > count then
                        table.insert(fingerprints, {fingerprint = fingerprint[i], count = itemCount - allCount})
                        allCount = allCount + (itemCount - allCount)
                        break
                    else
                        table.insert(fingerprints, {fingerprint = fingerprint[i], count = itemCount})
                        allCount = allCount + itemCount
                    end
                end
            end
        end

        if allCount == 0 then
            return false
        elseif allCount < count then
            return false
        else
            for i = 1, #fingerprints do
                if not insertItem(fingerprints[i].fingerprint, fingerprints[i].count) then
                    return false
                end
            end
        end
    end

    return true
end

local function scroll()
    if thumb.pos ~= thumb.oldPos then
        fill(58, 4, 1, 13, " ", color.blue)
        fill(58, 3 + math.ceil(thumb.pos / 2), 1, thumb.length, " ", color.blackBlue)
        thumb.oldPos = thumb.pos
    end
end

local function scrollCalc()
    if #itemsList <= 13 then
        fill(58, 4, 1, 13, " ", color.blackBlue)
    else
        local length = 13 / #itemsList * 13 * 2 + 1
        local check = length % 2
        length = length < 1 and 1 or (check >= 0 and check < .5 and math.floor(length) or math.ceil(length))
        local differrence = 13 * 2 - 1 - length
        thumb.shift = differrence / (#itemsList - 14)
        thumb.pos = 1
        thumb.oldPos = false
        thumb.length = length / 2 

        scroll()
    end
end

local function drawList()
    fill(3, 4, 55, 13, " ", color.blackGray)
    scroll()

    if #itemsList >= 1 then
        local counter = 1
        gpu.setBackground(color.blackGray)
        gpu.setForeground(color.lime)

        for i = guiScroll, #itemsList do 
            if counter <= 13 then 
                for str = 1, 3 do 
                    if itemsList[i][str] then
                        gpu.set(itemsList[i][str].x, 3 + counter, itemsList[i][str].text)
                    end
                end

                counter = counter + 1
            else
                break
            end
        end
    end

    if focus == "find" then
        gpu.setBackground(0xffffff)
        gpu.setForeground(0x000000)
    end
end

local function calcList()
    local counter = 1
    itemsList = {}

    for i = 1, #allItemsList do 
        if not allItemsList[i].notVisible then
            if input == "" or (input ~= "" and unicode.lower(allItemsList[i][1].text):match(unicode.lower(input))) then
                itemsList[counter] = allItemsList[i]

                counter = counter + 1
            end
        end
    end

    scrollCalc()
    drawList()
end

local function setList()
    allItemsList = {}

    if gui == "buy" then
        set(3, 3, "Имя предмета                   Кол-во          Цена", color.background, color.orange)

        for item = 1, #items.buy do 
            allItemsList[item] = {}

            allItemsList[item][1] = {x = items.buy.coords["text"], text = items.buy[item].text}
            allItemsList[item][2] = {x = items.buy.coords["count"], text = tostring(math.floor(items.buy[item].count))}
            allItemsList[item][3] = {x = items.buy.coords["cost"], text = tostring(items.buy[item].cost)}
            allItemsList[item].fingerprint = items.buy[item].fingerprint

            allItemsList[item].notVisible = items.buy[item].notVisible
            allItemsList[item].index = item
        end
    elseif gui == "sell" then
        set(3, 3, "Имя предмета                       Цена(На пополнение)", color.background, color.orange)

        for item = 1, #items.sell do 
            allItemsList[item] = {}

            allItemsList[item][1] = {x = items.sell.coords["text"], text = items.sell[item].text}
            allItemsList[item][2] = {x = items.sell.coords["cost"], text = tostring(items.sell[item].cost)}
            allItemsList[item].raw_name = items.sell[item].raw_name

            allItemsList[item].notVisible = items.sell[item].notVisible
            allItemsList[item].index = item
        end
    end

    calcList()
end

local function write(x, y, char, number, limit)
    if number and char >= 48 and char <= 57 or char >= 32 and unicode.len(input) + 1 ~= limit then 
        local symbol = unicode.char(char)
        set(x + unicode.len(input), y, symbol .. "_")

        input = input .. symbol

        if listIn[gui] then
            guiScroll = 1
            calcList()
        end
    elseif char == 8 and unicode.len(input) - 1 ~= -1 then
        set(x + unicode.len(input) - 1, y, "_ ")

        input = unicode.sub(input, 1, unicode.len(input) - 1)

        if listIn[gui] then
            guiScroll = 1
            calcList(true)
        end
    end
end

local function balance(y)
    gpu.setBackground(color.background)
    setColorText(nil, y, "[0x68f029]Баланс: [0xffffff]" .. math.floor(session.balance) .. " R.I.P'ов")
end

local function main()
    gui = "main"
    clear()
    drawButtons()
end

local function find(active)
    if active then
        fill(1, 19, 20, 1, " ", 0xffffff, 0x000000)
        set(1, 19, input .. "_", 0xffffff, 0x000000)
    else
        if #input == 0 then
            drawButton("find")
        else
            set(1, 19, input .. "_", 0xffffff, color.lightGray)
        end
    end
end

local function shop()
    gui = "shop"
    clear()
    drawButtons()
end

local function purchase()
    local count = tonumber(input)
    local amount = tonumber(input) * items.buy[activeItem].cost
    local msgToLog = "Игрок покупает предмет(" .. count .. " шт на сумму " .. amount .. "): " .. items.buy[activeItem].text
    log(msgToLog, session.name)
    local success = autoInsert(items.buy[activeItem].fingerprint, count)

    if success then
        session.balance = math.floor(session.balance - amount)
        session.transactions = session.transactions + 1
        updateUser(msgToLog)
    else
        log("Товар не куплен", session.name)
    end
    
    updateBuy()

    if gui ~= "login" then
        back()

        if not success then
            restoreDraw("Товар не куплен", false, "OK")
        end
    end
end

local function keys(key)
    local number = tonumber(input .. key)
    local notWrite = false

    if key == "<" then
        input = unicode.sub(input, 1, unicode.len(input) - 1)
        set(input == "" and 10 or 10 + unicode.len(input), 7, input == "" and "0" or " ", color.background, 0xffffff)

        if input == "" then
            set(12, 5, "0          ", color.background, 0xffffff)
        end
    elseif key == "C" then
        input = ""
        fill(10, 7, 10, 1, " ", color.background)
        fill(12, 5, 20, 1, " ", color.background)
        set(12, 5, "0          ", color.background, 0xffffff)
        set(10, 7, "0          ", color.background, 0xffffff)
    elseif unicode.len(input) <= 10 and not (input == "" and key == 0) then
        if number and number <= items.buy[activeItem].count or not number and input == "" then
            input = input .. key
            set(9 + unicode.len(input), 7, tostring(key), color.background, 0xffffff)
        else
            notWrite = true
        end
    end

    if not notWrite and number or input == "" or key == "<" then
        local amount 

        if input ~= "" then
            number = key == "<" and tonumber(input) or number
            amount = math.floor(number * items.buy[activeItem].cost) 
            set(12, 5, tostring(amount) .. "       ", color.background, amount <= session.balance and 0xffffff or color.red)
        end

        if input ~= "" and amount <= session.balance then
            if buttons.purchase.disabled then
                buttons.purchase.disabled = false
                drawButton("purchase")
            end
        else
            if not buttons.purchase.disabled then
                buttons.purchase.disabled = true
                drawButton("purchase")
            end
        end
    end
end

local function buyItem()
    oldGui = gui
    gui = "buyItem"
    input = ""
    buttons.purchase.disabled = true
    clear()
    balance(1)
    setColorText(2, 3, "[0x68f029]Имя предмета: [0xffffff]" .. items.buy[activeItem].text , color.background, color.lime)
    setColorText(44, 3, "[0x68f029]Доступно: [0xffffff]" .. items.buy[activeItem].count, color.background, color.lime)
    setColorText(48, 5, "[0x68f029]Цена: [0xffffff]" .. items.buy[activeItem].cost, color.background, color.lime)
    setColorText(2, 5, "[0x68f029]На сумму: [0xffffff]0", color.background, color.lime)
    setColorText(2, 7, "[0x68f029]Кол-во: [0xffffff]0", color.background, color.lime)
    drawButtons()
end

function buy()
    gui = "buy"
    clear()
    balance(1)
    setList()
    drawButtons()
end

local function sellItem()
    oldGui = gui
    gui = "sellItem"
    sellScan = true
    clear()
    balance(1)
    setColorText(2, 3, "[0x68f029]Имя предмета: [0xffffff]" .. items.sell[activeItem].text, color.background, color.lime)
    setColorText(48, 3, "[0x68f029]Цена: [0xffffff]" .. items.sell[activeItem].cost, color.background, color.lime)
    set(13, 9, "Для продажи положите предмет в 1 слот", color.background, color.orange)
    drawButtons()
end

function sell()
    gui = "sell"
    clear()
    balance(1)
    setList()
    drawButtons()
end

local function other()
    gui = "other"
    clear()
    drawButtons()
end

local function drawOreList()
    local counter = 1
    fill(13, 7, 35, 10, " ", color.background)

    for item = 1, #items.ore do 
        local ingots = 0 

        for ingot = 1, #items.ore[item].fingerprint.ingot do 
            test = items.ore[item].fingerprint.ingot 
            checkItem = me.getItemDetail(items.ore[item].fingerprint.ingot[ingot])

            if checkItem then
                ingots = ingots + checkItem.basic().qty
            end
        end

        if ingots >= 1 then
            setColorText(nil, counter + 6, "[0x4260f5]" .. items.ore[item].text .. ": [0xffffff]" .. math.floor(ingots / items.ore[item].ratio) .. " шт")
            counter = counter + 1
        end
    end
end

local function ore()
    gui = "ore"
    oreScan = true
    clear()
    drawButtons()
    set(13, 4, "Для обработки положите руду в 1 слот", color.background, color.lime)
    set(20, 5, "Доступно для обработки: ", color.background, color.lime)
    drawOreList()
end

local function nextFood()
    if session.foodTime > time(true) then
        buttons.getFood.disabled = true
        set(15, 5, "Вы сможете получить еду через:", color.background, color.lime) 
        set(nil, 6, os.date("%H Часов %M Минут %S Секунд", session.foodTime - time(true)), color.background, 0xffffff)
    else
        buttons.getFood.disabled = false
    end
end

local function getFood()
    if autoInsert(items.food, 16) then
        log("Выдаю бесплатную еду", session.name)
        session.foodTime = time(true) + 7200
        haveFood = true
        updateUser("Выдаю бесплатную еду")
        fill(18, 7, 26, 1, " ", color.background)
        set(21, 7, "Приятного аппетита!", color.background, 0xffffff)
        nextFood()
        drawButton("getFood")
    else
        set(18, 7, "Еда кончилась, извините :(", color.background, color.lime)
    end
end

local function freeFood()
    gui = "freeFood"
    clear()
    nextFood()
    drawButtons()
end

local function field(win)
    for i = 1, 30 do
        fill(15 + i, 6, 1, 5, " ", win and color.background or i % 2 == 0 and color.blackGray or color.gray) 
        if win then
            os.sleep()
        end
    end
end

local function lottery()
    gui = "lottery"
    clear()
    balance(1)
    setColorText(2, 3, "[0x68f029]Мгновенная беспроигрышная лотерея. Цена билета - [0xffffff]150 [0x68f029]рипов", color.background, color.lime)
    setColorText(19, 4, "[0x68f029]Супер-приз - [0xffffff]10000 [0x68f029]рипов!")
    field()
    drawButtons()
end

local function playLottery()
    if session.balance >= 150 then
        log("Игрок покупает лотерейный билет", session.name)
        session.balance = session.balance - 150
        balance(1)
        field(true)

        local rips = math.random(50, 350)
        local superWin = math.random(3000)

        if superWin == 3000 then
            rips = 10000
        else
            if rips >= 200 then
                rips = rips - (math.random(rips) + (rips >= 250 and 70 or 40))

                if rips < 0 then
                    rips = math.random(30, 65)
                end
            end
        end
        rips = math.floor(rips)
        setColorText(nil, 8, "[0x68f029]Вы выиграли: [0xffffff]" .. rips .. " [0x68f029]рипов", color.background, color.lime)
        local msgToLog = "Игрок выиграл в лотерее " .. rips .. " рипов"
        log(msgToLog, session.name)
        session.balance = session.balance + rips

        updateUser(msgToLog)
        os.sleep(.5)
        balance(1)
        fill(1, 10, 60, 1, " ", color.background)
        field()
    else
        restoreDraw("Недостаточно средств", nil, "OK")
    end
end

local function account()
    gui = "account"
    clear()
    setColorText(nil, 6, "[0x68f029]" .. session.name .. ":")
    balance(8)
    setColorText(nil, 9, "[0x68f029]Совершенно транзакций: [0xffffff]" .. session.transactions)
    setColorText(14, 10, "[0x68f029]Последний вход: [0xffffff]" .. session.lastLogin)
    setColorText(13, 11, "[0x68f029]Дата регистрации: [0xffffff]" .. session.regTime)
    drawButtons()
end

local function drawPage()
    fill(24, 16, 9, 1, " ", color.background)
    set(nil, 16, tostring(guiPage), color.background, color.blue)
end

local function drawInfo(page)
    guiPage = page
    drawPage() 

    if page == #infoList then
        buttons.nextInfo.disabled = true
        drawButton("nextInfo")
    else
        buttons.nextInfo.disabled = false
        drawButton("nextInfo")
    end
    if page ~= 1 then
        buttons.prevInfo.disabled = false
        drawButton("prevInfo")
    else
        buttons.prevInfo.disabled = true
        drawButton("prevInfo")
    end

    fill(1, 2, 60, 13, " ", color.background)
    gpu.setForeground(0xffffff)
    term.setCursor(1, 2)

    for str = 1, #infoList[page] do 
        if type(infoList[page][str]) == "table" then
            gpu.setForeground(infoList[page][str][1])
        else
            io.write(infoList[page][str])
        end
    end
end

local function info()
    oldGui = gui
    gui = "info"
    clear()
    set(20, 1, "Информация об магазине", color.backgroung, color.orange)
    drawButtons()
    drawInfo(1)
end

local function drawFeedback(page)
    guiPage = page
    drawPage()

    if page == #session.feedbacks then
        buttons.nextFeedback.disabled = true
        drawButton("nextFeedback")
    else
        buttons.nextFeedback.disabled = false
        drawButton("nextFeedback")
    end
    if page ~= 1 then
        buttons.prevFeedback.disabled = false
        drawButton("prevFeedback")
    else
        buttons.prevFeedback.disabled = true
        drawButton("prevFeedback")
    end 

    fill(1, 8, 60, 2, " ", color.background)
    set(nil, 8, session.feedbacks[page].user .. ":", color.background, color.lime)
    set(nil, 9, session.feedbacks[page].feedback, color.background, color.orange)
end

local function feedbacks()
    gui = "feedbacks"
    guiPage = 1
    clear()
    set(27, 1, "Отзывы", color.background, color.orange)
    drawPage()
    drawButtons()
    if #session.feedbacks == 0 then
        set(8, 8, "Отзывов нет. Будьте первым, кто его оставит=)", color.background, color.lime)
    else
        drawFeedback(1)
    end
end

local function leaveFeedback(active)
    if session.feedback == "none" then
        if active then
            fill(2, 12, 40, 1, " ", color.blackGray)
            set(2, 12, input .. "_", color.blackGray, 0xffffff)
        else
            if #input == 0 then
                drawButton("leaveFeedback")
            else
                set(2, 12, input .. "_", color.blackGray, color.lightGray)
            end
        end
    end
end

local function acceptFeedback()
    if input ~= "" and input ~= "none" then
        msgToLog = "Игрок оставил отзыв: " .. input
        log(msgToLog, session.name)
        table.insert(session.feedbacks, {user = session.name, feedback = input})
        table.sort(session.feedbacks, sort)
        session.feedback, input = input, ""
        updateUser(msgToLog)
        buttons.leaveFeedback.notVisible = true
        buttons.acceptFeedback.notVisible = true

        fill(1, 2, 60, 15, " ", color.background)
        drawFeedback(1)
        drawButtons()
    end
end

function restoreDrawBack()
    restoreDrawActive = false
    buttons.restoreDraw.notVisible = true

    for y = 8, 12 do 
        for x = 18, 43 do
            set(x, y, screen[y][x].symbol, screen[y][x].background, screen[y][x].foreground)
        end
    end
end

function restoreDraw(text1, text2, buttonText, funcOnButton) 
    if restoreDrawActive then
        restoreDrawBack()
    end

    restoreDrawActive = true

    screen = {}

    for y = 8, 12 do
        screen[y] = {}

        for x = 18, 43 do
            local symbol, foreground, background = gpu.get(x, y)
            screen[y][x] = {symbol = symbol, background = background, foreground = foreground} 
        end
    end

    local y = text2 and restoreDrawY + 1 or restoreDrawY + 2

    fill(restoreDrawX, restoreDrawY, 26, 5, " ", 0xffffff)

    set(restoreDrawX, restoreDrawY, screen[restoreDrawY][restoreDrawX].symbol, screen[restoreDrawY][restoreDrawX].background, screen[restoreDrawY][restoreDrawX].foreground)
    set(restoreDrawX + 25, restoreDrawY, screen[restoreDrawY][restoreDrawX + 25].symbol, screen[restoreDrawY][restoreDrawX + 25].background, screen[restoreDrawY][restoreDrawX + 25].foreground)
    set(restoreDrawX, restoreDrawY + 4, screen[restoreDrawY + 4][restoreDrawX].symbol, screen[restoreDrawY + 4][restoreDrawX].background, screen[restoreDrawY + 4][restoreDrawX].foreground)
    set(restoreDrawX + 25, restoreDrawY + 4, screen[restoreDrawY + 4][restoreDrawX + 25].symbol, screen[restoreDrawY + 4][restoreDrawX + 25].background, screen[restoreDrawY + 4][restoreDrawX + 25].foreground)

    set(nil, y, text1, 0xffffff, color.blackGray)

    if text2 then
        set(nil, y + 1, text2, 0xffffff, color.blackGray)
    end
    if buttonText then  
        buttons.restoreDraw.text = buttonText
        buttons.restoreDraw.x = math.floor(31 - unicode.len(buttonText) / 2)
        buttons.restoreDraw.notVisible = false
        buttons.restoreDraw.width = unicode.len(buttonText)
        buttons.restoreDraw.textPosX = math.floor(buttons.restoreDraw.width / 2 - unicode.len(buttons.restoreDraw.text) / 2) 
        buttons.restoreDraw.action = funcOnButton or restoreDrawBack
    end

    drawButton("restoreDraw")
end

local function blackList(nick)
    clear()
    setColorText(nil, 7, "[0x68f029](Не)уважаемый [0xffffff]" .. nick .. "[0x68f029], Вы внесены в чёрный список")
    set(24, 8, "этого магазина")
    set(27, 13, "Удачи!", color.background, color.red)
    setColorText(6, 18, "[0x303030]По любым проблемам пишите в Discord: [0x337d11]BrightYC#0604")
end

local function inDev(nick)
    unauth = true
    clear()
    setColorText(3, 7, "[0xff0000]Уважаемый [0x68f029]" .. nick .. "[0xff0000], этот терминал только для разработчиков!", color.red, color.background)
end

function back()
    gui = oldGui or buttons[gui].oldGui or "main"
    oldGui = false
    input = ""
    guiPage = 1
    guiScroll = 1
    oreScan = false
    sellScan = false

    if buttons[gui] and buttons[gui].onBack then
        buttons[gui].action(false)
    else
        clear()
        drawButtons()
    end
end

function login(nick)
    if nick then
        if dev and admins[nick] or not dev then
            if not unauth then
                log("Авторизация игрока " .. nick)

                local response = keyRequest("&method=login&user=" .. encode(nick))

                if response ~= "" then 
                    if response:match("banned=true") then
                        blackList(nick)
                        unauth = true
                    else
                        if not admins[nick] then
                            computer.addUser(nick)
                        end

                        session = {feedbacks = {}}
                        session.name = nick
                        gui = "main"
                        input = ""
                        restoreDrawActive = false
                        guiPage = 1
                        guiScroll = 1
                        activeItem = false
                        session.balance = tonumber(response:match("balance=(%d+)"))
                        session.transactions = tonumber(response:match("transactions=(%d+)"))
                        session.lastLogin = response:match("lastLogin=([%d%s.:]+)")
                        session.regTime = response:match("regTime=([%d%s.:]+)")
                        session.feedback = response:match("feedback=(.-);")
                        session.foodTime = tonumber(response:match("foodTime=(%d+)"))

                        local data = {}
                        local feedbacksString = response:match("feedbacks=(.+)")

                        if feedbacksString then
                            for part in feedbacksString:gsub("^(.-)%s*$", "%1"):gmatch("%s*([^;]+)") do 
                                data[#data+1]=("%q"):format(part) 
                            end

                            for feedback = 1, #data do 
                                session.feedbacks[feedback] = {user = data[feedback]:match("user=(.+)&"), feedback = data[feedback]:match("feedback=(.+)]")}
                            end

                            table.sort(session.feedbacks, sort)
                        end

                        if session.feedback == "none" then
                            buttons.leaveFeedback.notVisible = false
                            buttons.acceptFeedback.notVisible = false
                        else
                            buttons.leaveFeedback.notVisible = true
                            buttons.acceptFeedback.notVisible = true
                        end

                        if focus then
                            buttons[focus].active = false
                            focus = false
                        end

                        if session.balance then
                            drawPim(true)
                            main()
                        else
                            outOfService("неверный ответ от сервера")
                        end
                    end
                else
                    log("Игрок " .. nick .. " хотел авторизоваться, но сервер не отвечает")
                    set(11, 17, "Сервер не отвечает. Попробуйте ещё раз.", color.background, color.gray)
                end
            end
        else
            inDev(nick)
        end
    else
        if session.name then
            log("Деавторизация игрока " .. session.name)
        end
        if not admins[session.name] and session.name then
            computer.removeUser(session.name)
        end
        session.name = false
        unauth = false
        gui = "login"
        oldGui = false
        focus = false
        oreScan = false
        sellScan = false

        if active then
            clear()
            setColorText(18, 2, "[0xffffff]Приветствуем в [0x68f029]РипМаркете[0xffffff]!")
            setColorText(17, 5, "[0xffffff]Встаньте на [0x46c8e3]PIM[0xffffff], чтобы войти")
            setColorText(6, 18, "[0x303030]По любым проблемам пишите в Discord: [0x337d11]BrightYC#0604")
            drawPim(true)
            drawPim(false)
        end
    end
end


local function initButtons()
    for button in pairs(buttons) do 
        if buttons[button].buttonIn then
            for i = 1, #buttons[button].buttonIn do 
                buttons[button].buttonIn[buttons[button].buttonIn[i]], buttons[button].buttonIn[i] = true, nil
            end
        end

        buttons[button].x = buttons[button].x or math.floor(31 - unicode.len(buttons[button].text) / 2)
        buttons[button].width = buttons[button].width or unicode.len(buttons[button].text)
        buttons[button].textPosY = buttons[button].textPosY

        if not buttons[button].textPosY then
            if buttons[button].height == 1 then
                buttons[button].textPosY = buttons[button].y
            elseif buttons[button].height % 2 == 0 then
                buttons[button].textPosY = buttons[button].height / 2 - 1 + buttons[button].y
            else 
                buttons[button].textPosY = math.ceil(buttons[button].height / 2) - 1 + buttons[button].y
            end
        end

        buttons[button].textPosX = buttons[button].textPosX or buttons[button].width / 2 - unicode.len(buttons[button].text) / 2
    end
end

buttons = {
    restoreDraw = {notVisible = true, background = 0xffffff, activeBackground = 0xffffff, foreground = color.lightGray, activeForeground = 0x000000, text = "", x = 25, y = 12, width = 1, height = 1, action = function() restoreDrawBack() end},
    back = {buttonIn = {"shop", "buyItem", "buy", "sellItem", "sell", "other", "ore", "freeFood", "lottery", "account", "info", "feedbacks"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "   Назад   ", x = 25, y = 18, width = 11, height = 1, action = function() back() end},

    shop = {buttonIn = {"main"}, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Магазин", x = 18, y = 2, width = 26, height = 5, action = function() shop() end},
    other = {buttonIn = {"main"}, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Полезности", x = 18, y = 8, width = 26, height = 5, action = function() other() end},
    account = {buttonIn = {"main"}, onBack = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Инфо & Отзывы", x = 18, y = 14, width = 26, height = 5, action = function() account() end},

    find = {buttonIn = {"buy", "sell"}, switch = true, active = false, focus = true, withoutDraw = true, background = 0xffffff, activeBackground = 0xffffff, foreground = color.lightGray, activeForeground = color.lightGray, text = "Поиск...", x = 1, y = 19, width = 20, height = 1, action = function(active) find(active) end},
    buy = {buttonIn = {"shop"}, oldGui = "shop", onBack = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Покупка", x = 18, y = 4, width = 26, height = 5, action = function() buy() end},
    purchase = {buttonIn = {"buyItem"}, disabled = true, disabledBackground = color.blackGray, disabledForeground = color.blackOrange, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "  Купить  ", x = 46, y = 18, width = 10, height = 1, action = function() purchase() end},
    sell = {buttonIn = {"shop"}, oldGui = "shop", onBack = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Продажа", x = 18, y = 10, width = 26, height = 5, action = function() sell() end},

    one = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "1", x = 24, y = 9, width = 3, height = 1, action = function() keys(1) end},
    two = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "2", x = 29, y = 9, width = 3, height = 1, action = function() keys(2) end},
    three = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "3", x = 34, y = 9, width = 3, height = 1, action = function() keys(3) end},

    four = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "4", x = 24, y = 11, width = 3, height = 1, action = function() keys(4) end},
    five = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "5", x = 29, y = 11, width = 3, height = 1, action = function() keys(5) end},
    six = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "6", x = 34, y = 11, width = 3, height = 1, action = function() keys(6) end},

    seven = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "7", x = 24, y = 13, width = 3, height = 1, action = function() keys(7) end},
    eight = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "8", x = 29, y = 13, width = 3, height = 1, action = function() keys(8) end},
    nine = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "9", x = 34, y = 13, width = 3, height = 1, action = function() keys(9) end},

    backspace = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "<", x = 24, y = 15, width = 3, height = 1, action = function() keys("<") end},
    zero = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "0", x = 29, y = 15, width = 3, height = 1, action = function() keys(0) end},
    clear = {buttonIn = {"buyItem"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "C", x = 34, y = 15, width = 3, height = 1, action = function() keys("C") end},

    ore = {buttonIn = {"other"}, oldGui = "other", background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Обработка руды[x2]", x = 19, y = 4, width = 24, height = 3, action = function() ore() end},
    freeFood = {buttonIn = {"other"}, oldGui = "other", background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Бесплатная еда", x = 19, y = 8, width = 24, height = 3, action = function() freeFood() end},
    getFood = {buttonIn = {"freeFood"}, disabled = true, disabledBackground = color.blackGray, disabledForeground = color.blackLime, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Получить еду", x = 19, y = 9, width = 24, height = 3, action = function() getFood() end},
    
    lottery = {buttonIn = {"other"}, oldGui = "other", onBack = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Лотерея", x = 19, y = 12, width = 24, height = 3, action = function() lottery() end},
    playLottery = {buttonIn = {"lottery"}, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Купить билет", x = 19, y = 13, width = 24, height = 3, action = function() playLottery() end},
    
    helpInAccount = {buttonIn = {"account"}, oldGui = "account", background = color.background, activeBackground = background, foreground = color.blue, activeForeground = color.blackBlue, text = "[Инфо]", x = 23, y = 14, width = 7, height = 1, action = function() info() end},
    feedbacks = {buttonIn = {"account"}, oldGui = "account", background = color.background, activeBackground = background, foreground = color.blue, activeForeground = color.blackBlue, text = "[Отзывы]", x = 31, y = 14, width = 8, height = 1, action = function() feedbacks() end},

    prevInfo = {buttonIn = {"info"}, disabled = true, disabledBackground = color.background, disabledForeground = color.blackBlue, background = color.background, activeBackground = background, foreground = color.blue, activeForeground = color.blackBlue, text = "<───", x = 23, y = 16, width = 4, height = 1, action = function() drawInfo(guiPage - 1) end},
    nextInfo = {buttonIn = {"info"}, disabled = true, disabledBackground = color.background, disabledForeground = color.blackBlue, background = color.background, activeBackground = background, foreground = color.blue, activeForeground = color.blackBlue, text = "───>", x = 34, y = 16, width = 4, height = 1, action = function() drawInfo(guiPage + 1) end},

    leaveFeedback = {buttonIn = {"feedbacks"}, notVisible = true, switch = true, active = false, focus = true, withoutDraw = true, background = color.blackGray, activeBackground = color.blackGray, foreground = color.lightGray, activeForeground = 0xffffff, text = "Оставьте свой отзыв=)", x = 2, y = 12, width = 58, height = 1, action = function(active) leaveFeedback(active) end},
    acceptFeedback = {buttonIn = {"feedbacks"}, notVisible = true, background = color.background, activeBackground = color.background, foreground = color.blue, activeForeground = color.blackBlue, text = "[Подтвердить]", x = 24, y = 14, width = 13, height = 1, action = function() acceptFeedback() end},

    prevFeedback = {buttonIn = {"feedbacks"}, disabled = true, disabledBackground = color.background, disabledForeground = color.blackBlue, background = color.background, activeBackground = background, foreground = color.blue, activeForeground = color.blackBlue, text = "<───", x = 23, y = 16, width = 4, height = 1, action = function() drawFeedback(guiPage - 1) end},
    nextFeedback = {buttonIn = {"feedbacks"}, disabled = true, disabledBackground = color.background, disabledForeground = color.blackBlue, background = color.background, activeBackground = background, foreground = color.blue, activeForeground = color.blackBlue, text = "───>", x = 34, y = 16, width = 4, height = 1, action = function() drawFeedback(guiPage + 1) end}
}

for admin = 1, #admins do 
    computer.addUser(admins[admin])
    admins[admins[admin]], admins[admin] = true, nil
end 
for list = 1, #listIn do 
    listIn[listIn[list]], listIn[list] = true, nil
end

gpu.setResolution(60, 19)
loadInfo()
updateItems()
updateBuy()
log("###Запуск программы###")
initButtons()
login()

require("process").info().data.signal = function() end

while true do
    local evt = {event.pull(1)}

    if evt[1] == "key_down" then
        if active and not restoreDrawActive then
            if gui == "buyItem" then
                if evt[3] >= 48 and evt[3] <= 57 or evt[3] == 8 then
                    if evt[3] == 48 then
                        clickDrawButton("zero")
                    elseif evt[3] == 49 then
                        clickDrawButton("one")
                    elseif evt[3] == 50 then
                        clickDrawButton("two")
                    elseif evt[3] == 51 then
                        clickDrawButton("three")
                    elseif evt[3] == 52 then
                        clickDrawButton("four")
                    elseif evt[3] == 53 then
                        clickDrawButton("five")
                    elseif evt[3] == 54 then
                        clickDrawButton("six")
                    elseif evt[3] == 55 then
                        clickDrawButton("seven")
                    elseif evt[3] == 56 then
                        clickDrawButton("eight")
                    elseif evt[3] == 57 then
                        clickDrawButton("nine")
                    elseif evt[3] == 8 then
                        clickDrawButton("backspace")
                    end

                    if evt[3] == 8 then
                        keys("<")
                    else
                        keys(math.floor(evt[3] - 48))
                    end
                elseif evt[3] == 13 and not buttons.purchase.disabled then
                    clickDrawButton("purchase")
                    purchase()
                end
            elseif focus == "find" then
                write(1, 19, evt[3], false, 20)
            elseif focus == "leaveFeedback" and evt[3] ~= 59 then
                write(2, 12, evt[3], false, 58)
            end
        end

        if evt[4] == 41 and admins[evt[5]] then
            if keyboard.isControlDown() then
                login()
                outOfService()
            elseif keyboard.isAltDown() then
                active = true
                login()
            end
        elseif evt[4] == 16 and keyboard.isControlDown() and admins[evt[5]] then
            log("###Выход из программы###(" .. evt[5] .. ")")
            local users = {computer.users()}
            for user = 1, #users do
                if not admins[users[user]] then
                    computer.removeUser(users[user])
                end
            end
            gpu.setResolution(80, 25)
            gpu.setBackground(0x000000)
            gpu.setForeground(0xffffff)
            term.clear()
            os.exit()
        elseif evt[4] == 16 and keyboard.isShiftDown() and admins[evt[5]] then
            computer.beep(2000)
            login(session.nick)
            updateItems()
            updateBuy()
        end
    end

    if active then
        if evt[1] == "player_on" then
            login(evt[2])
        elseif evt[1] == "player_off" then
            login()
        elseif evt[1] == "touch" then
            if focus then
                buttons[focus].active = false

                buttons[focus].action(false)
                if not buttons[focus].withoutDraw then
                    drawButton(focus, false)
                end

                focus = false
            else
                local buttonFound = false

                for button in pairs(buttons) do
                    if evt[3] >= buttons[button].x and evt[3] <= buttons[button].x + buttons[button].width - 1 and evt[4] >= buttons[button].y and evt[4] <= buttons[button].y + buttons[button].height - 1 and (buttons[button].buttonIn and buttons[button].buttonIn[gui] or not buttons[button].buttonIn) and not buttons[button].notVisible and not buttons[button].disabled and (restoreDrawActive and button == "restoreDraw" or not restoreDrawActive) then
                        if buttons[button].switch then
                            if buttons[button].focus then
                                focus = button
                            end

                            buttons[button].active = not buttons[button].active

                            if not buttons[button].withoutDraw then
                                drawButton(button, buttons[button].active)
                            end
                        elseif not buttons[button].withoutDraw then
                            clickDrawButton(button)
                        end

                        buttons[button].action(buttons[button].active)
                        buttonFound = true
                        break
                    end
                end

                if not buttonFound and not restoreDrawActive then
                    if listIn[gui] and #itemsList >= 1 and evt[3] >= 3 and evt[3] <= 57 and evt[4] >= 4 and evt[4] <= 16 and evt[3] >= 3 and evt[3] <= 57 and evt[4] >= 4 and evt[4] <= 16 then
                        local str = itemsList[guiScroll + evt[4] - 4]

                        if str then
                            for clr = 1, 2 do
                                fill(3, evt[4], 55, 1, " ", clr == 1 and color.gray or color.blackGray)

                                for i = 1, 3 do
                                    if str[i] then
                                        set(str[i].x, evt[4], str[i].text, clr == 1 and color.gray or color.blackGray, color.lime)
                                    end
                                end

                                os.sleep(.1)
                            end

                            activeItem = str.index
                            if gui == "buy" then
                                buyItem()
                            elseif gui == "sell" then
                                sellItem()
                            end
                        end
                    end
                end
            end
        elseif evt[1] == "scroll" and listIn[gui] and not restoreDrawActive then
            local scroll = evt[5] == -1 and itemsList[guiScroll + 13] and -evt[5] or evt[5] == 1 and guiScroll - 1 ~= 0 and -evt[5]

            if scroll then
                guiScroll = guiScroll + scroll
                thumb.pos = math.ceil(thumb.shift * guiScroll)
                drawList()
            end
        end

        if oreScan then
            local itemInSlot = pim.getStackInSlot(1)

            if itemInSlot then
                local oreCount = itemInSlot.qty

                for item = 1, #items.ore do
                    for raw = 1, #items.ore[item].raw_name do
                        if items.ore[item].raw_name[raw] == itemInSlot.raw_name then
                            local needIngots = math.floor(itemInSlot.qty * items.ore[item].ratio)
                            local ingots = 0

                            for ingot = 1, #items.ore[item].fingerprint.ingot do
                                local checkItem = me.getItemDetail(items.ore[item].fingerprint.ingot[ingot])

                                if checkItem then
                                    local ingotsInMe = checkItem.basic().qty
                                    ingots = ingots + ingotsInMe
                                end
                            end

                            if ingots < needIngots then
                                if not restoreDrawActive then
                                    restoreDraw("Недостаточно", "слитков", "OK")
                                end
                            else
                                if pushItem(1, 64) then
                                    if active and autoInsert(items.ore[item].fingerprint.ingot, needIngots) then
                                        drawOreList()
                                    end
                                end
                            end

                            break
                        end
                    end
                end
            end
        elseif sellScan then
            local itemInSlot = pim.getStackInSlot(1)

            for raw = 1, #items.sell[activeItem].raw_name do
                if itemInSlot and itemInSlot.raw_name == items.sell[activeItem].raw_name[raw] then
                    if pushItem(1, 64) then
                        local addMoney = math.floor(items.sell[activeItem].cost * itemInSlot.qty)
                        local msgToLog = "Игрок продаёт предмет(" .. math.floor(itemInSlot.qty) .. " шт на сумму " .. addMoney.. "): " .. items.sell[activeItem].text
                        log(msgToLog, session.name)
                        session.balance = session.balance + addMoney
                        session.transactions = session.transactions + 1
                        set(19, 12, "Баланс успешно пополнен!", color.background, color.lime)
                        updateUser(msgToLog)
                        balance(1)
                        updateBuy()
                        fill(19, 12, 24, 1, " ", color.background)
                    end
                end
            end
        elseif itemsUpdateTimer <= computer.uptime() then
            updateBuy()
            itemsUpdateTimer = computer.uptime() + 600
        end

        if evt[1] ~= "player_on" and evt[1] ~= "player_off" then
            local name = pim.getInventoryName()

            if session.name ~= name and name ~= "pim" then
                login(name)
            elseif name == "pim" and session.name then
                login()
            end
        end
    end
end
