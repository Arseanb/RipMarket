local pim, me, selector, tmpfs = proxy("pim"), proxy("me_interface"), proxy("openperipheral_selector"), component.proxy(computer.tmpAddress())
local terminal = unicode.sub(internet.address, 1, 15)

local server, key = "SuperTechnoServer", read("/key.lua")
local me_side = "DOWN"
local pim_side = "UP"
local pimX = 23
local pimY = 8
local restoreDrawX = 18
local restoreDrawY = 8

local priceLottery = 150
local superPrize = 10000
local freeFoodCount = 16

local INFO = [[
[0x68f029]1. [0xffffff]Что это такое? Ответ — Это магазин/обменник. Как угодно.
[0x68f029]2. [0xffffff]Как обменять товар на рипы? Ответ — нужно выбрать товар и выбрать режим поиска предметов.
[0x68f029]3. [0xffffff]Как купить товар? Ответ — выбираете товар, набираете кол-во товара, и товар будет добавлен в ваш инвентарь. Если денег недостаточно - товар нельзя купить.
[0x68f029]4. [0xffffff]Как обменять руду? Выбираете режим поиска предметов, и руда будет обменена на слитки.
[0x68f029]5. [0xffffff]Что такое R.I.P? Ответ — это вымышленная валюта. [0xff0000]Это не серверная валюта!
[0x68f029]6. [0xffffff]Что за режим поиска предметов? Ответ — нажимая на "1 слот" магазин ищет предмет в 1 слоте вашего инвентаря. [0xff0000]Внимание![0xffffff] "Весь инвентарь" — означает что ВЕСЬ ваш инвентарь будет просканирован. Любой предмет выбранный вами(Допустим — алмаз) будет продан из всех слотов!
[0x68f029]7. [0xffffff]Что будет, если я продам зачарованный(переименованный, заряженный, и т.д) меч/гравик/нано-трусы? Ответ — цена таких вещей равняется стандартному предмету. Будьте внимательны!
]]

local active = true
local itemsUpdateTimer = computer.uptime() + 600
local input = ""
local gui = "login"
local oldGui = false
local focus = false
local restoreDrawActive = false
local guiPage = 1 
local guiScroll = 1
local itemScan = false
local activeIndex = false
local unAuth = false

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

local infoList, session, userAdmin, items, itemsInMe, screen, list, scrollList, bar = {{}}, {}, {}, {}, {}, {}, {}, {}, {}

local function set(x, y, str, background, foreground)
    if background and gpu.getBackground() ~= background then
        gpu.setBackground(background)
    end

    if foreground and gpu.getForeground() ~= foreground then
        gpu.setForeground(foreground)
    end

    gpu.set(x or math.floor(31 - unicode.len(str) / 2), y, str)
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

local function drawButton(button, active)
    fill(buttons[button].x, buttons[button].y, buttons[button].width, buttons[button].height, " ", active and buttons[button].activeBackground or buttons[button].disabled and buttons[button].disabledBackground or buttons[button].background)
    set(buttons[button].textPosX + buttons[button].x, buttons[button].textPosY, buttons[button].text, active and buttons[button].activeBackground or buttons[button].disabled and buttons[button].disabledBackground or buttons[button].background, active and buttons[button].activeForeground or buttons[button].disabled and buttons[button].disabledForeground or buttons[button].foreground)
end

local function clickDrawButton(button)
    drawButton(button, true)
    sleep(.1)
    drawButton(button, false)
end

local function drawButtons()
    for button in pairs(buttons) do 
        if buttons[button].buttonIn and buttons[button].buttonIn[gui] and not buttons[button].notVisible then
            buttons[button].active = false
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

    sleep(.1)
end

local function discord()
    setColorText(6, 18, "[0x303030]По любым проблемам пишите в Discord: [0x337d11]BrightYC#0604")
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
    discord()
end

local function time(raw)
    local handle = tmpfs.open("/time", "w")
    tmpfs.write(handle, "time")
    tmpfs.close(handle)
    local timestamp = tmpfs.lastModified("/time") / 1000 + 3600 * 3 

    return raw and timestamp or os.date("%d.%m.%Y %H:%M:%S", timestamp)
end

local function log(data, name)
    local timestamp = time(true)

    local date = os.date("%d.%m.%Y", timestamp)
    local path = "/logs/" .. date .. "/"
    local days = {date .. "/", os.date("%d.%m.%Y", timestamp - 86400) .. "/", os.date("%d.%m.%Y", timestamp - 172800) .. "/", os.date("%d.%m.%Y", timestamp - 259200) .. "/"}
    local data = "[" .. os.date("%H:%M:%S", timestamp) .. "] " .. tostring(data) .. "\n"

    for day = 1, #days do 
        days[days[day]], days[day] = true, nil
    end
    if not filesystem.exists(path) then
        filesystem.makeDirectory(path)
    end

    local paths = filesystem.list("/logs/")
    for oldPath = 1, paths.n do 
        local checkPath = "/logs/" .. paths[oldPath]

        if not days[paths[oldPath]] and filesystem.isDirectory(checkPath) then
            filesystem.remove(checkPath)
        end
    end

    if name then
        write(path .. name .. ".log", "a", data)
    else
        write(path .. "terminal.log", "a", data)
    end
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

local function encode(path)
    return (path:gsub("[^A-Za-z0-9_.~-]", function(c) return ("%%%02X"):format(c:byte()) end))
end

local function keyRequest(path)
    return request("https://АДРЕС-СЕРВЕРА/?key=" .. key .. "&server=" .. server .. "&terminal=" .. terminal .. path)
end

local function downloadItems()
    local data = request("https://raw.githubusercontent.com/BrightYC/RipMarket/master/items.lua")
    local chunk, err = load("return " .. data, "=items.lua", "t")
    if not chunk then 
        error("Неправильно сконфигурирован файл вещей! " .. err)
    else
        items = chunk()
    end

    table.sort(items.market, sort)
end

local function updateUser(msgToLog)
    keyRequest((msgToLog and "&log=" .. encode(msgToLog) .. "&" or "&") .. "method=update&user=" .. encode(session.name) .. "&balance=" .. session.balance .. "&transactions=" .. session.transactions .. "&feedback=" .. encode(session.feedback) .. "&foodTime=" .. session.foodTime .. "&eula=" .. session.eula)
end

local function block(nick)
    local timer = 15
    log("Другой игрок(" .. nick .. ") встал на PIM, блокирую магазин на 15 секунд...", session.name)
    restoreDraw("Автомат работает", "строго по одному")

    for i = 1, timer do  
        set(nil, restoreDrawY + 3, "Осталось: " .. timer, 0xffffff, color.blackGray)
        sleep(1)
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

local function setItemsMarket()
    for item = 1, #items.market do
        items.market[item].notVisibleBuy = true
        items.market[item].notVisibleSell = true

        if items.market[item].buyPrice and items.market[item].count > 0 then
            items.market[item].notVisibleBuy = false
        end
        if items.market[item].sellPrice then
            items.market[item].notVisibleSell = false
        end

        if items.market[item].count < items.market[item].minCount then
            items.market[item].notVisibleBuy = true
        end
        if items.market[item].count > items.market[item].maxCount then
            items.market[item].notVisibleSell = true
        end
    end
end

local function getFingerprint(fingerprint, strictHash)
    for item = 1, #itemsInMe do 
        if itemsInMe[item].fingerprint.id == fingerprint.id and itemsInMe[item].fingerprint.dmg == fingerprint.dmg and (strictHash and itemsInMe[item].fingerprint.nbt_hash == fingerprint.nbt_hash or not strictHash) then
            return itemsInMe[item].size, itemsInMe[item].fingerprint
        end
    end
end

local function pushItem(slot, count)
    local item = pim.getStackInSlot(slot)

    if item then
        local itemToLog = "id=" .. item.id .. "|display_name=" .. item.display_name
        if checkPlayer("Был обнаружен игрок при попытке забрать предмет: ".. itemToLog) then
            if pim.pushItem(me_side, slot, count) >= 1 then
                log("Забираю предмет(" .. count .. " шт): " .. itemToLog, session.name)

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

local function scanSlot(slot, raws)
    local item = pim.getStackInSlot(slot)

    if item then
        for raw = 1, #raws do
            if item and (item.raw_name == raws[raw]) then
                return item.qty
            end
        end
    end
end

local function scanSlots(raws)
    for slot = 1, 36 do 
        local count = scanSlot(slot, raws)

        if count then
            return slot, count
        end
    end
end

local function getAllItemCount(fingerprints, needed, strictHash)
    local allCount, availableItems = 0, {}

    for i = 1, #fingerprints do
        local count, fingerprint = getFingerprint(fingerprints[i], strictHash)

        if count then
            if needed and (count >= needed) then
                table.insert(availableItems, {fingerprint = fingerprint, count = needed})
                allCount = needed
                break
            end

            if needed and (count + allCount > needed) then
                table.insert(availableItems, {fingerprint = fingerprint, count = count - allCount})
                allCount = allCount + (count - allCount)
                break
            else
                table.insert(availableItems, {fingerprint = fingerprint, count = count})
                allCount = allCount + count
            end
        end
    end

    return allCount, availableItems
end

local function scanMe()
    itemsInMe = me.getAvailableItems()

    for item = 1, #items.market do 
        items.market[item].count = math.floor(getAllItemCount(items.market[item].fingerprint, items.market[item].strictHash))
    end

    setItemsMarket()
end

local function insertItem(fingerprint, count)
    local itemToLog = "id=" .. fingerprint.id .. "|dmg=" .. fingerprint.dmg

    if checkPlayer("Был обнаружен другой игрок при попытке вставить предмет: " .. itemToLog) then
        local slot, err = findSlot()

        if err then 
            return false
        elseif slot then
            local checkItem = me.getItemDetail(fingerprint)

            if checkItem then
                local item = checkItem.basic()

                if item.qty >= count then
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
                        log("Достаю предмет(" .. math.floor(count) .. " шт, всего: " ..  math.floor(item.qty) .."): " .. itemToLog, session.name)
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

                sleep(0)
            until false or timer < computer.uptime()

            log("Не было свободных слотов - предмет не выдан: " .. itemToLog, session.name)
            restoreDrawBack()
        end
    end
end

local function autoInsert(fingerprint, count)
    if #fingerprint == 1 then
        return insertItem(fingerprint[1], count)
    else
        local allCount, fingerprints = getAllItemCount(fingerprint, count)

        if count > allCount then
            return false
        else
            for fingerprint = 1, #fingerprints do
                if not insertItem(fingerprints[fingerprint].fingerprint, fingerprints[fingerprint].count) then
                    return false
                end
            end
        end
    end

    return true
end

local function scroll()
    if bar.active and math.floor(bar.pos) ~= math.floor(bar.oldPos or 0) then
        fill(58, 4, 1, 13, " ", color.blue)
        fill(58, 3 + bar.pos, 1, bar.length, " ", color.blackBlue)
        bar.posY = bar.pos
    else
        fill(58, 4, 1, 13, " ", color.blackBlue)
    end
end

local function scrollCalculate()
    if #scrollList <= 13 then
        bar.active = false
    else
        local length = 13 / #scrollList * 13
        local differrence = 13 - length
        bar.active = true
        bar.shift = differrence / (#scrollList - 12)
        bar.pos = 1
        bar.posY = 1
        bar.oldPos = false
        bar.touched = false
        bar.touchedMove = false
        bar.down = false
        bar.length = math.ceil(length)

        scroll()
    end
end

local function drawItem(item, active, y)
    local background = active and color.gray or color.blackGray
    fill(3, y, 55, 1, " ", background)

    for str = 1, #scrollList[item] do
        set(scrollList[item][str].x, y, scrollList[item][str].text, background, color.lime)
    end
end

local function drawList()
    scroll()

    if #scrollList <= 12 then
        fill(3, 4, 55, 13, " ", color.blackGray)
    end

    if #scrollList >= 1 then
        local counter = 1

        for item = guiScroll, #scrollList do 
            if counter <= 13 then 
                drawItem(item, item == activeIndex and true or false, counter + 3)
                counter = counter + 1
            else
                break
            end
        end
    end

    if focus == "find" then
        gpu.setBackground(buttons.find.background)
        gpu.setForeground(buttons.find.activeForeground)
    end
end

local function scrollMove(shift)
    guiScroll = guiScroll + shift
    bar.pos = math.ceil(bar.shift * guiScroll)
    drawList()
end

local function scrollTouched(y)
    if bar.active then
        local borderStart = bar.pos + 3
        local borderEnd = borderStart + bar.length - 1

        if y >= borderStart and y <= borderEnd then
            bar.touched = y
        else
            if y >= 4 and y <= 16 then
                bar.touchedMove = y - 3
            else
                if y < 4 then 
                    bar.touchedMove = 1
                else 
                    bar.touchedMove = 13
                end
            end
            if bar.touchedMove > bar.posY then
                bar.down = true
            end
        end
    end
end

local function calculateList()
    local counter = 1
    scrollList = {}

    for str = 1, #list do 
        if not list[str].notVisible then
            if input == "" or (input ~= "" and unicode.lower(list[str][1].text):match(unicode.lower(input))) then
                scrollList[counter] = list[str]
                counter = counter + 1
            end
        end
    end

    scrollCalculate()
    drawList()
end

local function setList()
    list = {}

    if gui == "buy" then
        set(3, 3, "Имя предмета                   Кол-во          Цена", color.background, color.orange)

        for item = 1, #items.market do 
            list[item] = {}

            list[item][1] = {x = items.market.coords.text, text = items.market[item].text}
            list[item][2] = {x = items.market.coords.count, text = tostring(math.floor(items.market[item].count))}
            list[item][3] = {x = items.market.coords.buyPrice, text = tostring(items.market[item].buyPrice)}
            list[item].fingerprint = items.market[item].fingerprint
            list[item].raw_name = items.market[item].raw_name

            list[item].notVisible = items.market[item].notVisibleBuy
            list[item].index = item
        end
    elseif gui == "sell" then
        set(3, 3, "Имя предмета                       Цена(На пополнение)", color.background, color.orange)

        for item = 1, #items.market do 
            list[item] = {}

            list[item][1] = {x = items.market.coords.text, text = items.market[item].text}
            list[item][2] = {x = items.market.coords.sellPrice, text = tostring(items.market[item].sellPrice)}
            list[item].fingerprint = items.market[item].fingerprint
            list[item].raw_name = items.market[item].raw_name

            list[item].notVisible = items.market[item].notVisibleSell
            list[item].index = item
        end
    end

    calculateList()
end

local function inputField(x, y, char, number, limit)
    if number and char >= 48 and char <= 57 or char >= 32 and unicode.len(input) + 1 ~= limit then 
        local symbol = unicode.char(char)
        gpu.set(x + unicode.len(input), y, symbol .. "_")

        input = input .. symbol

        if listIn[gui] then
            buttons.nextStep.disabled = true
            guiScroll = 1
            activeIndex = false
            drawButton("nextStep")
            calculateList()
        end
    elseif char == 8 and unicode.len(input) - 1 ~= -1 then
        gpu.set(x + unicode.len(input) - 1, y, "_ ")

        input = unicode.sub(input, 1, unicode.len(input) - 1)

        if listIn[gui] then
            buttons.nextStep.disabled = true
            guiScroll = 1
            activeIndex = false
            drawButton("nextStep")
            calculateList(true)
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
        fill(buttons.find.x, buttons.find.y, buttons.find.width, 1, " ", buttons.find.background)
        set(buttons.find.x, buttons.find.y, input .. "_", buttons.find.background, buttons.find.activeForeground)
    else
        if #input == 0 then
            drawButton("find")
        else
            set(buttons.find.x, buttons.find.y, input .. "_", buttons.find.background, buttons.find.foreground)
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

    if items.market[scrollList[activeIndex].index].amount <= session.balance then
        local msgToLog = "Игрок покупает предмет(" .. count .. " шт на сумму " .. items.market[scrollList[activeIndex].index].amount .. "): " .. items.market[scrollList[activeIndex].index].text
        log(msgToLog, session.name)
        local success = autoInsert(items.market[scrollList[activeIndex].index].fingerprint, count)

        if success then
            session.balance = math.floor(session.balance - items.market[scrollList[activeIndex].index].amount)
            session.transactions = session.transactions + 1
            updateUser(msgToLog)
        else
            log("Товар не куплен", session.name)
        end
        
        scanMe()

        if gui ~= "login" then
            back()

            if not success then
                restoreDraw("Товар не куплен", nil, "OK")
            end
        end
    else
        restoreDraw("Недостаточно средств", nil, "OK")
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
        if number and number <= items.market[scrollList[activeIndex].index].count or not number and input == "" then
            input = input .. key
            set(9 + unicode.len(input), 7, tostring(key), color.background, 0xffffff)
        else
            notWrite = true
        end
    end

    if not notWrite and number or input == "" or key == "<" then
        if input ~= "" then
            number = key == "<" and tonumber(input) or number
            items.market[scrollList[activeIndex].index].amount = math.floor(number * items.market[scrollList[activeIndex].index].buyPrice) 
            set(12, 5, tostring(items.market[scrollList[activeIndex].index].amount) .. "       ", color.background, items.market[scrollList[activeIndex].index].amount <= session.balance and 0xffffff or color.red)
        end

        if input ~= "" and items.market[scrollList[activeIndex].index].amount <= session.balance then
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
    selector.setSlot(1, items.market[scrollList[activeIndex].index].fingerprint[1])
    clear()
    balance(1)
    setColorText(2, 3, "[0x68f029]Имя предмета: [0xffffff]" .. items.market[scrollList[activeIndex].index].text , color.background, color.lime)
    setColorText(44, 3, "[0x68f029]Доступно: [0xffffff]" .. items.market[scrollList[activeIndex].index].count, color.background, color.lime)
    setColorText(48, 5, "[0x68f029]Цена: [0xffffff]" .. items.market[scrollList[activeIndex].index].buyPrice, color.background, color.lime)
    setColorText(2, 5, "[0x68f029]На сумму: [0xffffff]0", color.background, color.lime)
    setColorText(2, 7, "[0x68f029]Кол-во: [0xffffff]0", color.background, color.lime)
    drawButtons()
end

local function buy()
    gui = "buy"
    clear()
    balance(1)
    setList()
    drawButtons()
end

local function sellGui()
    oldGui = gui
    gui = "sellItem"
    selector.setSlot(1, items.market[scrollList[activeIndex].index].fingerprint[1])
    clear()
    balance(1)
    setColorText(2, 3, "[0x68f029]Имя предмета: [0xffffff]" .. items.market[scrollList[activeIndex].index].text, color.background, color.lime)
    setColorText(48, 3, "[0x68f029]Цена: [0xffffff]" .. items.market[scrollList[activeIndex].index].sellPrice, color.background, color.lime)
    set(15, 7, "Сканировать на наличие предмета:", color.background, color.orange)
    drawButtons()
end

local function sell()
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
    if gui == "ore" then
        local counter = 1
        fill(13, 9, 35, 8, " ", color.background)

        for item = 1, #items.ore do 
            local ingots = getAllItemCount(items.ore[item].fingerprint)

            if ingots >= 1 then
                setColorText(nil, counter + 9, "[0x4260f5]" .. items.ore[item].text .. "([0xffffff]x" .. items.ore[item].ratio .. "[0x4260f5]): [0xffffff]" .. math.floor(ingots / items.ore[item].ratio) .. " шт")
                counter = counter + 1
            end
        end
    end
end

local function ore()
    gui = "ore"
    clear()
    drawButtons()
    set(18, 2, "Сканировать на наличие руды:", color.background, color.orange)
    set(20, 8, "Доступно для обработки: ", color.background, color.lime)
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
    if autoInsert(items.food, freeFoodCount) then
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
            sleep(0)
        end
    end
end

local function lottery()
    gui = "lottery"
    clear()
    balance(1)
    setColorText(nil, 3, "[0x68f029]Мгновенная беспроигрышная лотерея. Цена билета — [0xffffff]" .. priceLottery .. " [0x68f029]рипов", color.background, color.lime)
    setColorText(19, 4, "[0x68f029]Супер-приз — [0xffffff]" .. superPrize .. " [0x68f029]рипов!")
    field()
    drawButtons()
end

local function playLottery()
    if session.balance >= priceLottery then
        session.balance = session.balance - priceLottery
        balance(1)
        field(true)

        local rips = math.random(50, 350)

        if math.random(3000) == 3000 then
            rips = superPrize
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
        sleep(.5)
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
    setColorText(nil, 7, "[0x68f029]" .. session.name .. ":")
    balance(9)
    setColorText(nil, 10, "[0x68f029]Совершенно транзакций: [0xffffff]" .. session.transactions)
    setColorText(14, 11, "[0x68f029]Последний вход: [0xffffff]" .. session.lastLogin)
    setColorText(13, 12, "[0x68f029]Дата регистрации: [0xffffff]" .. session.regTime)
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
        if session.eula == "false" then
            buttons.eula.disabled = false
            drawButton("eula")
        end
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
    local x, y = 1, 2

    for str = 1, #infoList[page] do 
        if type(infoList[page][str]) == "table" then
            gpu.setForeground(infoList[page][str][1])
        else
            if infoList[page][str] == "\n" then
                x, y = 1, y + 1
            else
                gpu.set(x, y, infoList[page][str])
                x = x + unicode.len(infoList[page][str])
            end
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
            fill(buttons.leaveFeedback.x, buttons.leaveFeedback.y, buttons.leaveFeedback.width, 1, " ", buttons.leaveFeedback.background)
            set(buttons.leaveFeedback.x, buttons.leaveFeedback.y, input .. "_", buttons.leaveFeedback.background, buttons.leaveFeedback.activeForeground)
        else
            if #input == 0 then
                drawButton("leaveFeedback")
            else
                set(buttons.leaveFeedback.x, buttons.leaveFeedback.y, input .. "_", color.blackGray, color.lightGray)
            end
        end
    end
end

local function acceptFeedback()
    if input ~= "" and input ~= "none" then
        local msgToLog = "Игрок оставил отзыв: " .. input
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

local function userInfo(user)
    oldGui = "userInfo"
    gui = "userInfoData" 
    local timestamp = time(true)
    clear()
    setColorText(28, 1, "[0x68f029]Отзыв:[0xffffff]")
    set(nil, 2, user.feedback == "none" and "нет" or user.feedback, color.background, 0xffffff)
    setColorText(nil, 3, "[0x68f029]Ник: [0xffffff]" .. user.name)
    setColorText(25, 4, "[0x68f029]В бане: [0xffffff]" .. (user.banned and "да" or "нет"))
    setColorText(nil, 5, "[0x68f029]Баланс: [0xffffff]" .. user.balance)
    setColorText(19, 6, "[0x68f029]Прочитал соглашение: [0xffffff]" .. (user.eula == "true" and "да" or "нет"))
    setColorText(nil, 7, "[0x68f029]Совершенно транзакций: [0xffffff]" .. user.transactions)
    setColorText(14, 8, "[0x68f029]Последний вход: [0xffffff]" .. user.lastLogin)
    setColorText(13, 9, "[0x68f029]Дата регистрации: [0xffffff]" .. user.regTime)
    setColorText(nil, 10, "[0x68f029]Время до еды: [0xffffff]" .. os.date("%H часов %M Минут %S Секунд", (user.foodTime > timestamp and user.foodTime - timestamp or 0)))
    buttons.balanceChange.notVisible = false
    buttons.delete.notVisible = false
    buttons.delFeedback.notVisible = false
    buttons.clearEula.notVisible = false
    buttons.pardon.notVisible = false
    buttons.ban.notVisible = false
    buttons.setBalance.notVisible = true
    buttons.setBalanceAccept.notVisible = true
    drawButtons()
end

local function userInfoWrite()
    gui = "userInfoWrite"
    clear()
    set(18, 6, "Введите имя пользователя:", color.background, color.lime)
    drawButtons()
end

local function userInfoInput(active)
    if active then
        fill(buttons.userInfoWrite.x, buttons.userInfoWrite.y, buttons.userInfoWrite.width, 1, " ", buttons.userInfoWrite.background)
        set(buttons.userInfoWrite.x, buttons.userInfoWrite.y, input .. "_", buttons.userInfoWrite.background, buttons.userInfoWrite.activeForeground)
    else
        if #input == 0 then
            drawButton("userInfoWrite")
        else
            set(buttons.userInfoWrite.x, buttons.userInfoWrite.y, input .. "_", color.blackGray, color.lightGray)
        end
    end
end

local function userInfoAccept()
    local response = keyRequest("&method=get&user=" .. encode(input))
    focus = false
    userAdmin = {}
    userAdmin.name = input
    userAdmin.balance = response:match("balance=(%d+)")
    userAdmin.transactions = tonumber(response:match("transactions=(%d+)"))
    userAdmin.lastLogin = response:match("lastLogin=([%d%s.:]+)")
    userAdmin.regTime = response:match("regTime=([%d%s.:]+)")
    userAdmin.feedback = response:match("feedback=(.-);")
    userAdmin.foodTime = tonumber(response:match("foodTime=(%d+)"))
    userAdmin.banned = response:match("banned=true") and true or false
    userAdmin.eula = response:match("eula=(%w+)")

    if userAdmin.balance then 
        userInfo(userAdmin)
    else
        set(nil, 13, response, color.background, color.red)
    end
end

local function userSetBalance(active) 
    if active then
        fill(1, 11, 60, 6, " ", color.background)
        set(19, 12, "Введите желаемый баланс", color.background, color.lime)
        input = ""
        buttons.balanceChange.notVisible = true
        buttons.delete.notVisible = true
        buttons.delFeedback.notVisible = true
        buttons.clearEula.notVisible = true
        buttons.pardon.notVisible = true
        buttons.ban.notVisible = true
        buttons.setBalance.notVisible = false
        buttons.setBalanceAccept.notVisible = false
        drawButtons()
        drawButton("setBalance")
    else
        local balance = input:match("(%d+)")

        if balance then
            local encodedName = encode(userAdmin.name)
            local response = keyRequest("&method=update&user=" .. encodedName .. "&balance=" .. balance .. "&transactions=" .. userAdmin.transactions .. "&feedback=" .. encode(userAdmin.feedback) .. "&foodTime=" .. userAdmin.foodTime .. "&eula=" .. userAdmin.eula)

            if response and response == "Update successful" then
                userAdmin.balance = balance
                fill(1, 5, 60, 1, " ", color.background)
                setColorText(nil, 5, "[0x68f029]Баланс: [0xffffff]" .. userAdmin.balance)
            end
        end
        fill(1, 11, 60, 6, " ", color.background)
        buttons.balanceChange.notVisible = false
        buttons.delete.notVisible = false
        buttons.delFeedback.notVisible = false
        buttons.clearEula.notVisible = false
        buttons.pardon.notVisible = false
        buttons.ban.notVisible = false
        buttons.setBalance.notVisible = true
        buttons.setBalanceAccept.notVisible = true
        drawButtons()
    end
end

local function setBalanceInput(active)
    if active then
        fill(buttons.setBalance.x, buttons.setBalance.y, buttons.setBalance.width, 1, " ", buttons.setBalance.background)
        set(buttons.setBalance.x, buttons.setBalance.y, input .. "_", buttons.setBalance.background, buttons.setBalance.activeForeground)
    else
        if #input == 0 then
            drawButton("setBalance")
        else
            set(buttons.setBalance.x, buttons.setBalance.y, input .. "_", color.blackGray, color.lightGray)
        end
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
    unAuth = true
    clear()
    setColorText(nil, 7, "[0x68f029](Не)уважаемый [0xffffff]" .. nick)
    set(10, 8, "Вы внесены в чёрный список этого магазина", color.background, color.lime)
    set(28, 13, "Удачи!", color.background, color.red)
    discord()
end

local function inDev(nick)
    unAuth = true
    clear()
    setColorText(nil, 8, "[0x68f029]Уважаемый [0xffffff]" .. nick)
    setColorText(11, 9, "[0x68f029]Этот терминал только для разработчиков!")
    discord()
end

local function insertKey()
    fill(1, 9, 60, 1, " ", color.background)
    set(15, 9, "Вставьте ключ через буфер обмена", color.background, color.lime)
end

local function checkKey()
    if key == "" then
        insertKey()

        while true do 
            local signal = {computer.pullSignal(0)}
            key = signal[3]

            if signal[1] == "clipboard" then
                fill(1, 9, 60, 1, " ", color.background)
                set(12, 9, "Проверка ключа на действительность...")

                if keyRequest("&method=test") == "OK" then
                    write("/key.lua", "w", signal[3])
                    login()
                    break
                else
                    fill(1, 9, 60, 1, " ", color.background)
                    set(24, 9, "Неверный ключ", color.background, color.lime)
                    sleep(2)
                    insertKey()
                end
            end
        end
    else
        login()
    end
end

function clearVariables()
    input = ""
    guiPage = 1
    guiScroll = 1
    activeIndex = false
    itemScan = false
    focus = false
    buttons.nextStep.disabled = true
end

function back()
    if gui == "buyItem" or gui == "sellItem" or gui == "buy" or gui == "sell" then
        selector.setSlot(1)
    end
    gui = oldGui or (buttons[gui] and buttons[gui].oldGui) or "main"
    oldGui = false
    clearVariables()

    if buttons[gui] and buttons[gui].onBack then
        buttons[gui].action(false)
    else
        clear()
        drawButtons()
    end
end

function login(nick)
    if nick then
        if not unAuth then
            if dev and admins[nick] or not dev then
                local response = keyRequest("&method=login&user=" .. encode(nick))

                if response ~= "" then
                    log("Авторизация игрока " .. nick)

                    if response:match("banned=true") then
                        blackList(nick)
                        unAuth = true
                    else
                        gui = "main"
                        computer.addUser(nick)
                        session = {feedbacks = {}}
                        session.name = nick
                        restoreDrawActive = false
                        clearVariables()

                        session.balance = tonumber(response:match("balance=(%d+)"))
                        session.transactions = tonumber(response:match("transactions=(%d+)"))
                        session.lastLogin = response:match("lastLogin=([%d%s.:]+)")
                        session.regTime = response:match("regTime=([%d%s.:]+)")
                        session.feedback = response:match("feedback=(.-);")
                        session.foodTime = tonumber(response:match("foodTime=(%d+)"))
                        session.eula = response:match("eula=(%w+)")

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

                        if admins[nick] then
                            buttons.adminButton.notVisible = false
                        else
                            buttons.adminButton.notVisible = true
                        end

                        if focus then
                            buttons[focus].active = false
                            focus = false
                        end

                        if session.balance then
                            scanMe()
                            drawPim(true)
                            main()
                            if session.eula == "false" then
                                buttons.eula.disabled = true
                                buttons.eula.notVisible = false
                                buttons.back.notVisible = true
                                info()
                            else
                                buttons.eula.notVisible = true
                                buttons.back.notVisible = false
                            end
                        else
                            if response == "Invalid key" then 
                                key = ""
                                checkKey()
                            else
                                outOfService("неверный ответ от сервера")
                            end
                        end
                    end
                else
                    log("Игрок " .. nick .. " хотел авторизоваться, но сервер не отвечает")
                    set(11, 17, "Сервер не отвечает. Попробуйте ещё раз.", color.background, color.gray)
                end
            else
                inDev(nick)
            end
        end
    else
        if session.name then
            log("Деавторизация игрока " .. session.name)
        end
        if not admins[session.name] and session.name then
            computer.removeUser(session.name)
        end
        gui = "login"
        session.name = false
        restoreDrawActive = false
        unAuth = false
        buttons.adminButton.notVisible = true
        selector.setSlot(1)
        clearVariables()

        if active then
            clear()
            setColorText(18, 2, "[0xffffff]Приветствуем в [0x68f029]РипМаркете[0xffffff]!")
            setColorText(17, 5, "[0xffffff]Встаньте на [0x46c8e3]PIM[0xffffff], чтобы войти")
            discord()
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
    adminButton = {buttonIn = {"main"}, admin = true, background = color.background, activeBackground = color.background, foreground = color.lime, activeForeground = color.blackLime, text = "[Админ-панель]", x = 24, y = 19, width = 14, height = 1, action = function() gui = "admin" clear() clearVariables() drawButtons() end},
    scanMe = {buttonIn = {"admin"}, admin = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Просканировать МЭ сеть", x = 19, y = 4, width = 24, height = 1, action = function() scanMe() end},
    downloadItems = {buttonIn = {"admin"}, admin = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Обновить БД предметов", x = 19, y = 6, width = 24, height = 1, action = function() downloadItems() scanMe() end},
    userInfo = {buttonIn = {"admin"}, admin = true, onBack = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Информация о игроке", x = 19, y = 8, width = 24, height = 1, action = function() userInfoWrite() end},
    userInfoWrite = {buttonIn = {"userInfoWrite"}, admin = true, oldGui = "admin", switch = true, active = false, focus = true, withoutDraw = true, background = color.blackGray, activeBackground = color.blackGray, foreground = color.lightGray, activeForeground = 0xffffff, text = "Ник игрока", x = 21, y = 8, width = 20, height = 1, action = function(active) userInfoInput(active) end},
    userInfoAccept = {buttonIn = {"userInfoWrite"}, admin = true, background = color.background, activeBackground = color.background, foreground = color.lime, activeForeground = color.blackLime, text = "[Подтвердить]", x = 24, y = 10, width = 13, height = 1, action = function() userInfoAccept() end},
    balanceChange = {buttonIn = {"userInfoData"}, admin = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Установить баланс", x = 6, y = 12, width = 24, height = 1, action = function() userSetBalance(true) end},
    setBalance = {buttonIn = {"userInfoData"}, admin = true, switch = true, active = false, focus = true, withoutDraw = true, notVisible = true, background = color.blackGray, activeBackground = color.blackGray, foreground = color.lightGray, activeForeground = 0xffffff, text = "Баланс", x = 21, y = 14, width = 20, height = 1, action = function(active) setBalanceInput(active) end},
    setBalanceAccept = {buttonIn = {"userInfoData"}, admin = true, notVisible = true, background = color.background, activeBackground = color.background, foreground = color.lime, activeForeground = color.blackLime, text = "[Подтвердить]", x = 24, y = 16, width = 13, height = 1, action = function() userSetBalance(false) end},
    delete = {buttonIn = {"userInfoData"}, admin = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Удалить аккаунт", x = 6, y = 14, width = 24, height = 1, action = function() keyRequest("&method=delete&user=" .. encode(userAdmin.name)) if session.name == userAdmin.name then login() else back() end end},
    delFeedback = {buttonIn = {"userInfoData"}, admin = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Удалить отзыв", x = 6, y = 16, width = 24, height = 1, action = function() fill(1, 2, 60, 1, " ", color.background) set(29, 2, "нет", color.background, 0xffffff) keyRequest("&method=delFeedback&user=" .. encode(userAdmin.name)) end},
    clearEula = {buttonIn = {"userInfoData"}, admin = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Стереть соглашение", x = 32, y = 12, width = 24, height = 1, action = function() set(40, 6, "нет", color.background, 0xffffff) keyRequest("&method=update&user=" .. encode(userAdmin.name) .. "&balance=" .. userAdmin.balance .. "&transactions=" .. userAdmin.transactions .. "&feedback=" .. userAdmin.feedback .. "&foodTime=" .. userAdmin.foodTime .. "&eula=false") end},
    pardon = {buttonIn = {"userInfoData"}, admin = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Разбанить", x = 32, y = 14, width = 24, height = 1, action = function() set(33, 4, "нет", color.background, 0xffffff) keyRequest("&user=" .. encode(userAdmin.name) .. "&method=pardon") end},
    ban = {buttonIn = {"userInfoData"}, admin = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Забанить", x = 32, y = 16, width = 24, height = 1, action = function() set(33, 4, "да ", color.background, 0xffffff) keyRequest("&user=" .. encode(userAdmin.name) .. "&method=ban") end},
    outOfService = {buttonIn = {"admin"}, admin = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Тех. работы", x = 19, y = 10, width = 24, height = 1, action = function() gui = "login" outOfService() end},
    deleteKey = {buttonIn = {"admin"}, admin = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Удалить ключ", x = 19, y = 12, width = 24, height = 1, action = function() filesystem.remove("/key.lua") key = "" clear() checkKey() end},
    backAdmin = {buttonIn = {"admin", "userInfoData", "userInfoWrite"}, admin = true, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "   Назад   ", x = 25, y = 18, width = 11, height = 1, action = function() back() end},

    restoreDraw = {notVisible = true, ignoreActive = true, background = 0xffffff, activeBackground = 0xffffff, foreground = color.lightGray, activeForeground = 0x000000, text = "", x = 25, y = 12, width = 1, height = 1, action = function() restoreDrawBack() end},
    back = {buttonIn = {"shop", "buyItem", "sellItem", "other", "ore", "freeFood", "lottery", "account", "info", "feedbacks"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "   Назад   ", x = 25, y = 18, width = 11, height = 1, action = function() back() end},
    backShop = {buttonIn = {"buy", "sell"}, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "   Назад   ", x = 31, y = 18, width = 11, height = 1, action = function() back() end},
    eula = {buttonIn = {"info"}, disabled = true, disabledBackground = color.blackGray, disabledForeground = color.blackOrange, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "  Я прочитал и соглашаюсь со всем  ", x = 13, y = 18, width = 35, height = 1, action = function() session.eula = "true" buttons.eula.notVisible = true buttons.back.notVisible = false updateUser() main() end},

    shop = {buttonIn = {"main"}, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Магазин", x = 19, y = 5, width = 24, height = 3, action = function() shop() end},
    other = {buttonIn = {"main"}, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Полезности", x = 19, y = 9, width = 24, height = 3, action = function() other() end},
    account = {buttonIn = {"main"}, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Аккаунт", x = 19, y = 13, width = 24, height = 3, action = function() account() end},

    info = {buttonIn = {"main"}, background = color.background, activeBackground = color.background, foreground = color.lime, activeForeground = color.blackLime, text = "[Помощь]", x = 1, y = 19, width = 8, height = 1, action = function() info() end},
    feedbacks = {buttonIn = {"main"},background = color.background, activeBackground = color.background, foreground = color.lime, activeForeground = color.blackLime, text = "[Отзывы]", x = 53, y = 19, width = 8, height = 1, action = function() feedbacks() end},

    nextStep = {buttonIn = {"buy", "sell"}, disabled = true, disabledBackground = color.blackGray, disabledForeground = color.blackOrange, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "  Далее  ", x = 50, y = 18, width = 9, height = 1, action = function() if gui == "buy" then buyItem() elseif gui == "sell" then sellGui() end end},
    find = {buttonIn = {"buy", "sell"}, switch = true, active = false, focus = true, withoutDraw = true, background = color.gray, activeBackground = color.gay, foreground = color.lightGray, activeForeground = 0xffffff, text = "Поиск...", x = 3, y = 18, width = 20, height = 1, action = function(active) find(active) end},
    buy = {buttonIn = {"shop"}, oldGui = "shop", onBack = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Покупка", x = 19, y = 6, width = 24, height = 3, action = function() buy() end},
    
    purchase = {buttonIn = {"buyItem"}, disabled = true, disabledBackground = color.blackGray, disabledForeground = color.blackOrange, background = color.gray, activeBackground = color.blackGray, foreground = color.orange, activeForeground = color.blackOrange, text = "  Купить  ", x = 46, y = 18, width = 10, height = 1, action = function() purchase() end},
    sell = {buttonIn = {"shop"}, oldGui = "shop", onBack = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Продажа", x = 19, y = 10, width = 24, height = 3, action = function() sell() end},

    sellScanOne = {buttonIn = {"sellItem"}, switch = true, active = false, focus = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "      1 слот      ", x = 22, y = 9, width = 18, height = 1, action = function(active) if active then itemScan = "one" else itemScan = false end end},
    sellScanMulti = {buttonIn = {"sellItem"}, switch = true, active = false, focus = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "  Весь инвентарь  ", x = 22, y = 11, width = 18, height = 1, action = function(active) if active then itemScan = "multi" else itemScan = false end end},

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

    ore = {buttonIn = {"other"}, oldGui = "other", background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Обработка руды", x = 19, y = 4, width = 24, height = 3, action = function() ore() end},
    oreScanOne = {buttonIn = {"ore"}, switch = true, active = false, focus = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "      1 слот      ", x = 22, y = 4, width = 18, height = 1, action = function(active) if active then itemScan = "one" else itemScan = false end end},
    oreScanMulti = {buttonIn = {"ore"}, switch = true, active = false, focus = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "  Весь инвентарь  ", x = 22, y = 6, width = 18, height = 1, action = function(active) if active then itemScan = "multi" else itemScan = false end end},

    freeFood = {buttonIn = {"other"}, oldGui = "other", background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Бесплатная еда", x = 19, y = 8, width = 24, height = 3, action = function() freeFood() end},
    getFood = {buttonIn = {"freeFood"}, disabled = true, disabledBackground = color.blackGray, disabledForeground = color.blackLime, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Получить еду", x = 19, y = 9, width = 24, height = 3, action = function() getFood() end},
    
    lottery = {buttonIn = {"other"}, oldGui = "other", onBack = true, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Лотерея", x = 19, y = 12, width = 24, height = 3, action = function() lottery() end},
    playLottery = {buttonIn = {"lottery"}, background = color.gray, activeBackground = color.blackGray, foreground = color.lime, activeForeground = color.blackLime, text = "Купить билет", x = 19, y = 13, width = 24, height = 3, action = function() playLottery() end},

    prevInfo = {buttonIn = {"info"}, disabled = true, disabledBackground = color.background, disabledForeground = color.blackBlue, background = color.background, activeBackground = background, foreground = color.blue, activeForeground = color.blackBlue, text = "<───", x = 21, y = 16, width = 4, height = 1, action = function() drawInfo(guiPage - 1) end},
    nextInfo = {buttonIn = {"info"}, disabled = true, disabledBackground = color.background, disabledForeground = color.blackBlue, background = color.background, activeBackground = background, foreground = color.blue, activeForeground = color.blackBlue, text = "───>", x = 36, y = 16, width = 4, height = 1, action = function() drawInfo(guiPage + 1) end},

    leaveFeedback = {buttonIn = {"feedbacks"}, notVisible = true, switch = true, active = false, focus = true, withoutDraw = true, background = color.blackGray, activeBackground = color.blackGray, foreground = color.lightGray, activeForeground = 0xffffff, text = "Оставьте свой отзыв=)", x = 2, y = 12, width = 58, height = 1, action = function(active) leaveFeedback(active) end},
    acceptFeedback = {buttonIn = {"feedbacks"}, notVisible = true, background = color.background, activeBackground = color.background, foreground = color.lime, activeForeground = color.blackLime, text = "[Подтвердить]", x = 24, y = 14, width = 13, height = 1, action = function() acceptFeedback() end},

    prevFeedback = {buttonIn = {"feedbacks"}, disabled = true, disabledBackground = color.background, disabledForeground = color.blackBlue, background = color.background, activeBackground = background, foreground = color.blue, activeForeground = color.blackBlue, text = "<───", x = 21, y = 16, width = 4, height = 1, action = function() drawFeedback(guiPage - 1) end},
    nextFeedback = {buttonIn = {"feedbacks"}, disabled = true, disabledBackground = color.background, disabledForeground = color.blackBlue, background = color.background, activeBackground = background, foreground = color.blue, activeForeground = color.blackBlue, text = "───>", x = 36, y = 16, width = 4, height = 1, action = function() drawFeedback(guiPage + 1) end}
}

for list = 1, #listIn do 
    listIn[listIn[list]], listIn[list] = true, nil
end
loadInfo()
downloadItems()
scanMe()
log("Запуск программы")
initButtons()
checkKey()

while true do
    local signal = {computer.pullSignal(0)}

    if signal[1] == "key_down" then
        if active and not restoreDrawActive then
            if gui == "buyItem" then
                if signal[3] >= 48 and signal[3] <= 57 or signal[3] == 8 then
                    if signal[3] == 48 then
                        clickDrawButton("zero")
                    elseif signal[3] == 49 then
                        clickDrawButton("one")
                    elseif signal[3] == 50 then
                        clickDrawButton("two")
                    elseif signal[3] == 51 then
                        clickDrawButton("three")
                    elseif signal[3] == 52 then
                        clickDrawButton("four")
                    elseif signal[3] == 53 then
                        clickDrawButton("five")
                    elseif signal[3] == 54 then
                        clickDrawButton("six")
                    elseif signal[3] == 55 then
                        clickDrawButton("seven")
                    elseif signal[3] == 56 then
                        clickDrawButton("eight")
                    elseif signal[3] == 57 then
                        clickDrawButton("nine")
                    elseif signal[3] == 8 then
                        clickDrawButton("backspace")
                    end

                    if signal[3] == 8 then
                        keys("<")
                    else
                        keys(math.floor(signal[3] - 48))
                    end
                elseif signal[3] == 13 and not buttons.purchase.disabled then
                    clickDrawButton("purchase")
                    purchase()
                end
            elseif focus and signal[4] == 28 then
                if focus == "find" then 
                    buttons.find.action(false)
                elseif focus == "leaveFeedback" then
                    acceptFeedback()
                elseif focus == "userInfoWrite" then
                    userInfoAccept()
                elseif focus == "setBalance" then
                    userSetBalance(false)
                end

                focus = false
            elseif focus == "find" then
                inputField(buttons.find.x, buttons.find.y, signal[3], false, buttons.find.width)
            elseif focus == "leaveFeedback" and signal[3] ~= 59 then
                inputField(buttons.leaveFeedback.x, buttons.leaveFeedback.y, signal[3], false, buttons.leaveFeedback.width)
            elseif focus == "userInfoWrite" then 
                inputField(buttons.userInfoWrite.x, buttons.userInfoWrite.y, signal[3], false, buttons.userInfoWrite.width)
            elseif focus == "setBalance" then
                inputField(buttons.setBalance.x, buttons.setBalance.y, signal[3], false, buttons.setBalance.width)
            end
        end
    elseif signal[1] == "touch" then
        if focus then
            if buttons[focus] then
                buttons[focus].active = false

                buttons[focus].action(false)
                if not buttons[focus].withoutDraw then
                    drawButton(focus, false)
                end
            end

            focus = false
        end
        local buttonFound = false

        for button in pairs(buttons) do
            if signal[3] >= buttons[button].x and signal[3] <= buttons[button].x + buttons[button].width - 1 and signal[4] >= buttons[button].y and signal[4] <= buttons[button].y + buttons[button].height - 1 and (buttons[button].buttonIn and buttons[button].buttonIn[gui] or not buttons[button].buttonIn) and not buttons[button].notVisible and not buttons[button].disabled and (restoreDrawActive and buttons[button].ignoreActive or not restoreDrawActive) and (active or not active and buttons[button].ignoreActive) and (buttons[button].admin and admins[signal[6]] or not buttons[button].admin) then
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

        if not buttonFound and (not restoreDrawActive and active) then
            if listIn[gui] then
                if activeIndex and activeIndex >= guiScroll then
                    local index = activeIndex - guiScroll
                    local y = index + 4

                    if guiScroll + index < guiScroll + 13 then
                        drawItem(activeIndex, false, y)
                    end

                    buttons.nextStep.disabled = true
                    activeIndex = false
                    drawButton("nextStep")
                    selector.setSlot(1)
                end

                if #scrollList >= 1 and signal[3] >= 3 and signal[3] <= 57 and signal[4] >= 4 and signal[4] <= 16 and signal[3] >= 3 and signal[3] <= 57 and signal[4] >= 4 and signal[4] <= 16 then
                    local index = guiScroll + (signal[4] - 4)

                    if scrollList[index] then
                        activeIndex = index
                        buttons.nextStep.disabled = false
                        drawButton("nextStep")
                        drawItem(index, true, signal[4])
                        selector.setSlot(1, items.market[scrollList[activeIndex].index].fingerprint[1])
                    end
                elseif signal[3] == 58 then
                    scrollTouched(signal[4])
                end
            end
        end
    elseif listIn[gui] and not restoreDrawActive then
        if bar.active then
            if signal[1] == "drop" then
                bar.touched = false
                bar.touchedMove = false
                bar.down = false
            elseif signal[1] == "scroll" or signal[1] == "drag" and not bar.touchedMove then
                if signal[1] == "scroll" then
                    if signal[5] == -1 and scrollList[guiScroll + 13] then
                        scrollMove(1)
                    elseif signal[5] == 1 and scrollList[guiScroll - 1] then
                        scrollMove(-1) 
                    end
                elseif signal[1] == "drag" and bar.touched then
                    local down = signal[4] - bar.touched >= 1 and true
                    local endBar = bar.posY + bar.length - 1

                    if down and scrollList[guiScroll + 13] then
                        scrollMove(1)
                    elseif not down and scrollList[guiScroll - 1] then
                        scrollMove(-1)
                    elseif (bar.posY ~= 1 or signal[4] > bar.posY) and (endBar ~= 13 or signal[4] < bar.posY) then
                        bar.touched = signal[4]
                    end

                    scrollTouched(signal[4])
                end
            elseif bar.touchedMove then
                local endBar = bar.posY + bar.length - 1

                if bar.down and bar.touchedMove == endBar or not bar.down and bar.touchedMove == bar.posY then
                    bar.down = false
                    bar.touched = bar.posY + 3
                    bar.touchedMove = false

                    if bar.posY == 1 then
                        guiScroll = 1
                        drawList()
                    elseif endBar == 13 then
                        guiScroll = #scrollList - 12
                        drawList()
                    end
                elseif bar.down and scrollList[guiScroll + 13] then
                    scrollMove(1)
                elseif not bar.down and scrollList[guiScroll - 1] then
                    scrollMove(-1)
                end
            end
        end
    end

    if active then
        if signal[1] == "player_on" then
            login(signal[2])
        elseif signal[1] == "player_off" then
            login()
        end

        if itemScan then
            if gui == "sellItem" then
                local slot, count 

                if itemScan == "multi" then
                    slot, count = scanSlots(items.market[scrollList[activeIndex].index].raw_name)
                else
                    slot, count = 1, scanSlot(1, items.market[scrollList[activeIndex].index].raw_name)
                end

                if count and pushItem(slot, count) then
                    local addMoney = count * items.market[scrollList[activeIndex].index].sellPrice
                    local msgToLog = "Игрок продаёт предмет(" .. math.floor(count) .. " шт на сумму " .. addMoney.. "): " .. items.market[scrollList[activeIndex].index].text
                    log(msgToLog, session.name)
                    session.balance = session.balance + addMoney
                    session.transactions = session.transactions + 1
                    fill(1, 14, 60, 1, " ", color.background)
                    setColorText(nil, 14, "[0x68f029]Баланс успешно пополнен на [0xffffff]" .. math.floor(addMoney) .. " [0x68f029]рипов!")
                    updateUser(msgToLog)
                    balance(1)
                    scanMe()
                    fill(1, 14, 60, 1, " ", color.background)
                    if items.market[scrollList[activeIndex].index].count > items.market[scrollList[activeIndex].index].maxCount then
                        back()
                    end
                end
            elseif gui == "ore" then
                for item = 1, #items.ore do
                    local slot, count 

                    if itemScan == "multi" then
                        slot, count = scanSlots(items.ore[item].raw_name)
                    else
                        slot, count = 1, scanSlot(1, items.ore[item].raw_name)
                    end

                    if count then
                        local needIngots = math.floor(count * items.ore[item].ratio)
                        local ingots, fingerprints = getAllItemCount(items.ore[item].fingerprint, needIngots)

                        if ingots < count then
                            itemScan = false
                            drawButton("oreScanOne")
                            drawButton("oreScanMulti")
                            restoreDraw("Недостаточно слитков,", "зайдите позже", "OK")
                        else
                            if pushItem(slot, 64) then
                                for fingerprint = 1, #fingerprints do 
                                    insertItem(fingerprints[fingerprint].fingerprint, fingerprints[fingerprint].count)
                                    if active then
                                        scanMe()
                                        drawOreList()
                                    end
                                end
                            end
                        end

                        break
                    end
                end
            end
        elseif itemsUpdateTimer <= computer.uptime() then
            scanMe()
            itemsUpdateTimer = computer.uptime() + 600
        end

        if signal[1] ~= "player_on" and signal[1] ~= "player_off" then
            local name = pim.getInventoryName()

            if session.name ~= name and name ~= "pim" then
                login(name)
            elseif name == "pim" and session.name then
                login()
            end
        end
    end
end
