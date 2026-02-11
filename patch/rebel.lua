-- === PDA V11.0 ===
-- [Advanced UI: Menus + Time + Custom Msg]

local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem!") end
rednet.open(peripheral.getName(modem))

local PROTOCOL = "default_net"
local netFile = "net_config.txt"

if fs.exists(netFile) then
    local f = fs.open(netFile, "r")
    PROTOCOL = f.readAll()
    f.close()
else
    term.clear()
    term.setCursorPos(1,1)
    print("--- SERVER SETUP ---")
    print("Create Network ID (e.g. SQUAD_1):")
    write("> ")
    local input = read()
    if input ~= "" then PROTOCOL = input end
    
    local f = fs.open(netFile, "w")
    f.write(PROTOCOL)
    f.close()
    print("Network ID saved: " .. PROTOCOL)
    sleep(1)
end

local myProfile = nil
local currentObj = "Connecting..."

-- === ЛОГИН ===
local function login()
    -- 1. Авто-вход
    if fs.exists("session.txt") then
        local f = fs.open("session.txt", "r")
        local savedData = textutils.unserialize(f.readAll())
        f.close()
        if savedData and savedData.id then
            myProfile = savedData
            if not serverID then serverID = rednet.lookup(PROTOCOL, "central_core") end
            if serverID then 
                rednet.send(serverID, {type="LOGIN", userID=myProfile.id, userPass=myProfile.pass, role="SOLDIER"}, PROTOCOL)
                local _, msg = rednet.receive(PROTOCOL, 2)
                if msg and msg.type=="AUTH_OK" then currentObj = msg.obj end
            end
            return
        end
    end

    -- 2. Ручной ввод
    while true do
        term.setBackgroundColor(colors.black)
        term.clear()
        term.setCursorPos(1,1)
        print("=== SYSTEM LOGIN ===")
        write("ID (e.g. J1): ")
        local inputID = string.upper(read())
        write("Password: ")
        local inputPass = read("*")
        
        print("Authenticating...")
        if not serverID then serverID = rednet.lookup(PROTOCOL, "central_core") end
        
        if serverID then
            rednet.send(serverID, {type="LOGIN", userID=inputID, userPass=inputPass, role="SOLDIER"}, PROTOCOL)
            local id, msg = rednet.receive(PROTOCOL, 3)
            
            if msg and msg.type == "AUTH_OK" then
                myProfile = msg.profile
                myProfile.pass = inputPass
                currentObj = msg.obj
                
                local f = fs.open("session.txt", "w")
                f.write(textutils.serialize(myProfile))
                f.close()
                return
            elseif msg and msg.type == "AUTH_FAIL" then
                print("Error: " .. (msg.reason or "Access Denied"))
                sleep(2)
            else
                print("Error: No Response")
                sleep(2)
            end
        else
            print("Server Offline")
            sleep(2)
        end
    end
end

login()

-- === UI STATE ===
local activeTab = "TACTICAL" -- "TACTICAL" или "PROFILE"
local menuState = "MAIN"     -- "MAIN" или "ALERTS" (внутри тактики)
local logHistory = {}

local function addLog(text, color)
    -- Время сообщения
    local t = textutils.formatTime(os.time(), true)
    table.insert(logHistory, {text=text, color=color or colors.green, time=t})
    if #logHistory > 8 then table.remove(logHistory, 1) end
end

-- Вспомогательная функция для ввода текста
local function promptInput(promptText)
    local w, h = term.getSize()
    -- Рисуем поле ввода поверх всего внизу
    paintutils.drawFilledBox(1, h-2, w, h, colors.black)
    term.setCursorPos(1, h-1)
    term.setTextColor(colors.yellow)
    write(promptText)
    term.setTextColor(colors.white)
    return read()
end

local function sendPacket(text, visualColor)
    rednet.send(serverID, {type = "REPORT", userID=myProfile.id, text = text}, PROTOCOL)
    addLog("ME: " .. text, colors.white)
end

local function drawUI()
    local w, h = term.getSize()
    
    -- === 1. ВЕРХНИЙ БАР (ОБЩИЙ) ===
    term.setCursorPos(1,1)
    if activeTab == "TACTICAL" then
        term.setBackgroundColor(colors.blue)
        term.setTextColor(colors.white)
        write(" TACTICAL ")
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.lightGray)
        write(" PROFILE ")
    else
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.lightGray)
        write(" TACTICAL ")
        term.setBackgroundColor(colors.blue)
        term.setTextColor(colors.white)
        write(" PROFILE ")
    end
    
    -- Заливка и время
    term.setBackgroundColor(colors.gray)
    local timeStr = textutils.formatTime(os.time(), true)
    local spaceLen = w - 18 - #timeStr
    if spaceLen < 0 then spaceLen = 0 end
    write(string.rep(" ", spaceLen))
    term.setTextColor(colors.white)
    write(timeStr)
    
    -- === 2. СОДЕРЖИМОЕ ===
    if activeTab == "TACTICAL" then
        paintutils.drawFilledBox(1, 2, w, h, colors.black)
        
        -- Задача
        term.setCursorPos(1, 2)
        term.setTextColor(colors.yellow)
        print("OBJ: " .. string.sub(currentObj, 1, w-5))
        
        -- Если мы в главном меню тактики - показываем логи
        if menuState == "MAIN" then
            local y = 4
            for _, item in ipairs(logHistory) do
                if y < h-3 then
                    term.setCursorPos(1, y)
                    term.setTextColor(item.color)
                    print(item.text)
                    y = y + 1
                end
            end
            
            -- Кнопки главного меню (внизу)
            local btnY = h-2
            -- Кнопка 1: Меню оповещений
            paintutils.drawFilledBox(1, btnY, w/2, h-1, colors.red)
            term.setCursorPos(2, btnY) 
            term.setTextColor(colors.white)
            term.setBackgroundColor(colors.red)
            write("1.ALERTS")
            
            -- Кнопка 2: Сообщение
            paintutils.drawFilledBox(w/2+1, btnY, w, h-1, colors.blue)
            term.setCursorPos(w/2+2, btnY)
            term.setBackgroundColor(colors.blue)
            write("2.MSG")
            
            -- Футер
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.gray)
            term.setCursorPos(1, h)
            write("TAB: Switch Tab")
            
        elseif menuState == "ALERTS" then
            -- МЕНЮ ВЫБОРА ОПОВЕЩЕНИЙ
            term.setCursorPos(1, 4)
            term.setTextColor(colors.white)
            print("SELECT ALERT TYPE:")
            
            term.setTextColor(colors.cyan)   print(" 1. REQUEST..")
            term.setTextColor(colors.magenta)print(" 2. INJURY (S.O.S)")
            term.setTextColor(colors.orange) print(" 3. CAPTURE..")
            term.setTextColor(colors.red)    print(" 4. CONTACT..")
            print("")
            term.setTextColor(colors.lightGray) print(" 5. < BACK")
            
            -- Футер
            term.setBackgroundColor(colors.black)
            term.setCursorPos(1, h)
            write("Select 1-5")
        end
        
    else
        -- === ПРОФИЛЬ ===
        paintutils.drawFilledBox(1, 2, w, h, colors.white)
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.white)
        
        term.setCursorPos(2, 4)
        print("NAME:   " .. myProfile.name)
        term.setCursorPos(2, 5)
        print("RANK:   " .. myProfile.rank)
        term.setCursorPos(2, 6)
        print("NATION: " .. myProfile.nation)
        
        term.setCursorPos(2, 8)
        print("ID:     " .. myProfile.id)
        term.setCursorPos(2, 9)
        print("SQUAD:  " .. myProfile.squad)
        
        local px = w - 8
        if px > 10 then -- Рисуем только если экран широкий
            paintutils.drawBox(px, 3, px+6, 7, colors.black)
            term.setCursorPos(px+1, 4) write(" O  ")
            term.setCursorPos(px+1, 5) write("/|\\ ")
            term.setCursorPos(px+1, 6) write("/ \\ ")
        end
        
        term.setCursorPos(2, h-1)
        term.setTextColor(colors.red)
        print("[L] LOGOUT")
        
        term.setCursorPos(w-10, h)
        term.setTextColor(colors.gray)
        write("TAB: Back")
    end
end

local function inputLoop()
    while true do
        local event, key = os.pullEvent("key")
        
        if key == keys.tab then
            -- Смена вкладок
            if activeTab == "TACTICAL" then activeTab = "PROFILE" else activeTab = "TACTICAL" end
            -- Сброс меню при смене вкладки
            if activeTab == "TACTICAL" then menuState = "MAIN" end
            drawUI()
            
        elseif activeTab == "TACTICAL" then
            if menuState == "MAIN" then
                if key == keys.one then
                    menuState = "ALERTS"
                    drawUI()
                elseif key == keys.two then
                    local txt = promptInput("MSG: ")
                    if txt ~= "" then sendPacket(txt) end
                    drawUI()
                end
                
            elseif menuState == "ALERTS" then
                if key == keys.one then
                    -- 1. REQUEST
                    local txt = promptInput("REQUEST: ")
                    if txt ~= "" then sendPacket("REQUESTING: " .. txt) end
                    menuState = "MAIN"
                    
                elseif key == keys.two then
                    -- 2. INJURY (Без ввода, сразу отправка)
                    sendPacket("CRITICAL INJURY! MEDIC!", colors.magenta)
                    menuState = "MAIN"
                    
                elseif key == keys.three then
                    -- 3. CAPTURE
                    local txt = promptInput("CAPTURING: ")
                    if txt ~= "" then sendPacket("CAPTURING " .. txt) end
                    menuState = "MAIN"
                    
                elseif key == keys.four then
                    -- 4. CONTACT
                    local txt = promptInput("CONTACT: ")
                    if txt ~= "" then sendPacket("CONTACT: " .. txt) end
                    menuState = "MAIN"
                    
                elseif key == keys.five then
                    -- 5. BACK
                    menuState = "MAIN"
                    drawUI()
                end
                drawUI()
            end
            
        elseif activeTab == "PROFILE" then
            if key == keys.l then
                fs.delete("session.txt")
                os.reboot()
            end
        end
    end
end

local function netLoop()
    while true do
        local id, msg = rednet.receive(PROTOCOL)
        if msg and msg.type == "CHAT_LINE" then
            local show = false
            if msg.channel == "GLOBAL" then show = true end
            if msg.channel == "SQUAD" and msg.targetSquad == myProfile.squad then show = true end
            
            if show then
                if msg.channel == "GLOBAL" and msg.color == colors.yellow then
                     currentObj = string.gsub(msg.text, "NEW ORDERS: ", "")
                     local s = peripheral.find("speaker")
                     if s then s.playNote("pling", 3, 24) end
                end
                addLog(msg.text, msg.color)
                drawUI()
            end
        end
        
        -- Таймер для обновления часов каждую секунду
        if not msg then
             local timer = os.startTimer(1)
             os.pullEvent("timer")
             drawUI()
        end
    end
end

drawUI()
parallel.waitForAny(inputLoop, netLoop)