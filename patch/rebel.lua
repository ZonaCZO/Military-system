-- === TACTICAL PDA V8.0 ===
-- [GUI UPGRADE: Buttons & Status Bars]

local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem!") end
rednet.open(peripheral.getName(modem))

-- === СЕТЕВЫЕ НАСТРОЙКИ ===
local PROTOCOL = "nipaya_net"
local netFile = "net_config.txt"

if fs.exists(netFile) then
    local f = fs.open(netFile, "r")
    PROTOCOL = f.readAll()
    f.close()
else
    term.clear()
    term.setCursorPos(1,1)
    print("--- NETWORK SETUP ---")
    write("Net ID: ")
    local input = read()
    if input ~= "" then PROTOCOL = input end
    local f = fs.open(netFile, "w")
    f.write(PROTOCOL)
    f.close()
end

-- === ПРОФИЛЬ ===
local serverID = rednet.lookup(PROTOCOL, "central_core")
local profile = {}
local mySquad = ""

local function setupProfile()
    if fs.exists("profile.txt") then
        local file = fs.open("profile.txt", "r")
        profile = textutils.unserialize(file.readAll())
        file.close()
    else
        term.clear()
        print("--- ID SETUP ---")
        write("Rank: ") profile.rank = read()
        write("Name: ") profile.name = read()
        write("Callsign: ") profile.callsign = string.upper(string.sub(read(), 1, 2))
        profile.nation = "NPY"
        local file = fs.open("profile.txt", "w")
        file.write(textutils.serialize(profile))
        file.close()
    end
end

-- === ЛОГИН ===
local function login()
    setupProfile()
    if not serverID then 
        serverID = rednet.lookup(PROTOCOL, "central_core")
        if not serverID then serverID = os.getComputerID() end 
    end

    local msgError = ""
    while true do
        term.setBackgroundColor(colors.black)
        term.clear()
        term.setCursorPos(1,1)
        term.setTextColor(colors.blue)
        print("=== NIPAYA OS v8.0 ===")
        term.setTextColor(colors.white)
        print("User: " .. profile.callsign)
        
        if msgError ~= "" then
            term.setTextColor(colors.red)
            print(msgError)
            term.setTextColor(colors.white)
        end
        
        write("Squad: ")
        local sName = string.upper(read())
        write("Pass: ")
        local sPass = read("*")
        
        term.setTextColor(colors.yellow)
        print("\nConnecting...")
        rednet.send(serverID, {type="LOGIN", squad=sName, pass=sPass, role="SOLDIER"}, PROTOCOL)
        local id, response = rednet.receive(PROTOCOL, 3)
        if response and response.type == "AUTH" and response.res then
            mySquad = sName
            return response.obj
        else
            msgError = "ACCESS DENIED"
        end
    end
end

local currentObj = login()
local logHistory = {} 

local function addLog(text, color)
    local time = textutils.formatTime(os.time(), true)
    table.insert(logHistory, {text = text, color = color or colors.green, time = time})
    if #logHistory > 8 then table.remove(logHistory, 1) end
end

-- === ОТРИСОВКА ИНТЕРФЕЙСА ===
local function drawUI()
    local w, h = term.getSize()
    
    -- 1. ВЕРХНИЙ БАР (Синий)
    paintutils.drawFilledBox(1, 1, w, 1, colors.blue)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.blue)
    term.setCursorPos(1,1)
    write(mySquad .. "-" .. profile.callsign)
    
    -- Правая часть бара (Время и "Сигнал")
    local status = "ON " .. textutils.formatTime(os.time(), true)
    term.setCursorPos(w - #status + 1, 1)
    write(status)

    -- 2. ПАНЕЛЬ ЗАДАЧИ (Серый)
    paintutils.drawFilledBox(1, 2, w, 3, colors.gray)
    term.setCursorPos(1, 2)
    term.setTextColor(colors.lightGray)
    write(" CURRENT OBJECTIVE:")
    term.setCursorPos(1, 3)
    term.setTextColor(colors.yellow)
    write(" > " .. string.sub(currentObj, 1, w-3))

    -- 3. ОСНОВНОЙ ЭКРАН (Черный)
    paintutils.drawFilledBox(1, 4, w, h-4, colors.black)
    
    -- Отрисовка логов
    local y = 4
    for _, item in ipairs(logHistory) do
        if y < h-3 then -- Оставляем место под кнопки
            term.setCursorPos(1, y)
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.gray)
            write(item.time .. " ")
            term.setTextColor(item.color)
            write(item.text)
            y = y + 1
        end
    end

    -- 4. НИЖНЯЯ ПАНЕЛЬ КНОПОК
    -- Рисуем цветные "кнопки" внизу экрана
    local btnY = h - 2
    local btnH = h
    
    -- Кнопка 1: CONTACT (Красная)
    paintutils.drawFilledBox(1, btnY, 7, btnH, colors.red)
    term.setCursorPos(2, btnY)
    term.setTextColor(colors.white)
    term.setBackgroundColor(colors.red)
    write("1.CNT")
    
    -- Кнопка 2: CLEAR (Зеленая)
    paintutils.drawFilledBox(9, btnY, 15, btnH, colors.green)
    term.setCursorPos(10, btnY)
    term.setBackgroundColor(colors.green)
    write("2.CLR")
    
    -- Кнопка 3: MEDIC (Розовая)
    paintutils.drawFilledBox(17, btnY, 23, btnH, colors.magenta)
    term.setCursorPos(18, btnY)
    term.setBackgroundColor(colors.magenta)
    write("3.MED")

    -- Кнопка 4: AMMO (Голубая) или MSG
    if w > 24 then
        paintutils.drawFilledBox(25, btnY, 31, btnH, colors.lightBlue)
        term.setCursorPos(26, btnY)
        term.setBackgroundColor(colors.lightBlue)
        write("4.AMO")
    end
    
    -- Подсказка про чат
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.gray)
    term.setCursorPos(1, h-3)
    write("[M]essage  [R]efresh")
end

local function sendPacket(text, visualColor)
    rednet.send(serverID, {type = "REPORT", squad = mySquad, callsign = profile.callsign, rank = profile.rank, text = text}, PROTOCOL)
    addLog("ME: " .. text, colors.white)
    drawUI()
    
    -- Визуальный "блик" отправки
    local w,h = term.getSize()
    paintutils.drawFilledBox(1, h-3, w, h-3, visualColor or colors.gray)
    sleep(0.1)
    drawUI()
end

local function promptInput(promptText)
    local w, h = term.getSize()
    -- Рисуем поле ввода поверх кнопок
    paintutils.drawFilledBox(1, h-2, w, h, colors.black)
    term.setCursorPos(1, h-1)
    term.setTextColor(colors.yellow)
    write(promptText)
    term.setTextColor(colors.white)
    return read()
end

local function mainLoop()
    while true do
        drawUI()
        local event, key = os.pullEvent("char")
        
        if key == "1" then sendPacket("CONTACT!", colors.red)
        elseif key == "2" then sendPacket("AREA CLEAR", colors.green)
        elseif key == "3" then sendPacket("MEDIC NEEDED!", colors.magenta)
        elseif key == "4" then sendPacket("NEED AMMO", colors.lightBlue)
        elseif key == "m" or key == "M" then 
            local msg = promptInput("MSG: ")
            if msg ~= "" then sendPacket(msg, colors.gray) end
        end
    end
end

local function netLoop()
    while true do
        local id, msg = rednet.receive(PROTOCOL)
        if msg and msg.type == "CHAT_LINE" then
            if msg.channel == "GLOBAL" then
                 if msg.color == colors.yellow then
                     currentObj = string.gsub(msg.text, "NEW ORDERS: ", "")
                     local s = peripheral.find("speaker")
                     if s then s.playNote("pling", 3, 24) end
                 end
                 addLog(msg.text, msg.color)
                 drawUI()
            elseif msg.channel == "SQUAD" and msg.targetSquad == mySquad then
                 addLog(msg.text, msg.color)
                 drawUI()
            end
        end
    end
end

parallel.waitForAny(mainLoop, netLoop)