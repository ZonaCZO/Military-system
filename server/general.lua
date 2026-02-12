-- === GENERAL TERMINAL V1.0 (RC4) ===
-- [HIGH COMMAND ACCESS]

local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem!") end
rednet.open(peripheral.getName(modem))

-- === КРИПТОГРАФИЯ (RC4) ===
-- [Используем ту же функцию шифрования для совместимости]
local function crypt(text, key)
    if not key or key == "" or key == "none" then return text end
    local S = {}; for i = 0, 255 do S[i] = i end
    local j = 0
    for i = 0, 255 do
        j = (j + S[i] + string.byte(key, (i % #key) + 1)) % 256
        S[i], S[j] = S[j], S[i]
    end
    local i, j = 0, 0; local output = {}
    for k = 1, #text do
        i = (i + 1) % 256; j = (j + S[i]) % 256
        S[i], S[j] = S[j], S[i]
        local K = S[(S[i] + S[j]) % 256]
        table.insert(output, string.char(bit.bxor(string.byte(text, k), K)))
    end
    return table.concat(output)
end

-- === НАСТРОЙКА ===
local PROTOCOL = "default_net"
local KEY = "none"
local netFile = ".net_config.txt"

if fs.exists(netFile) then
    local f = fs.open(netFile, "r")
    PROTOCOL = f.readLine()
    KEY = f.readLine()
    f.close()
    if not KEY then KEY = "none" end
else
    term.clear()
    term.setCursorPos(1,1)
    print("--- GENERAL LINK SETUP ---")
    
    write("Network ID: ")
    local input = read()
    if input ~= "" then PROTOCOL = input end
    
    write("Encryption Key: ")
    local kInp = read()
    if kInp ~= "" then KEY = kInp end
    
    local f = fs.open(netFile, "w")
    f.writeLine(PROTOCOL)
    f.writeLine(KEY)
    f.close()
    print("Config Saved.")
    sleep(1)
end

local serverID = rednet.lookup(PROTOCOL, "central_core")
local myProfile = nil
local currentObj = "Wait..."

-- === ЛОГИН (Только для GENERAL) ===
local function login()
    local msgText = ""
    while true do
        term.setBackgroundColor(colors.black)
        term.clear()
        term.setCursorPos(1,1)
        term.setTextColor(colors.red) -- Отличительный цвет генерала
        print("/// HIGH COMMAND TERMINAL ///")
        term.setTextColor(colors.white)
        
        if msgText ~= "" then 
            term.setTextColor(colors.red)
            print(msgText) 
            term.setTextColor(colors.white)
        end
        
        write("General ID: ")
        local inputID = string.upper(read())
        write("Password: ")
        local inputPass = read("*")
        
        if not serverID then serverID = rednet.lookup(PROTOCOL, "central_core") end
        
        -- Запрашиваем роль GENERAL
        rednet.send(serverID, {
            type="LOGIN", 
            userID=inputID, 
            userPass=inputPass, 
            role="GENERAL"
        }, PROTOCOL)
        
        local id, msg = rednet.receive(PROTOCOL, 3)
        
        if msg and msg.type == "AUTH_OK" then
            myProfile = msg.profile
            currentObj = crypt(msg.obj, KEY)
            return 
        elseif msg and msg.type == "AUTH_FAIL" then
            msgText = "ACCESS DENIED: " .. (msg.reason or "Unknown")
        else
            msgText = "ERROR: Server Unreachable"
        end
    end
end

login()

-- === ИНТЕРФЕЙС ===
local cmdLogs = {}   -- Чат командиров
local globalLogs = {} -- Все глобальные сообщения
local activeTab = "CMD" 

local function addLog(targetTable, text, color)
    table.insert(targetTable, {text=text, color=color})
    if #targetTable > 12 then table.remove(targetTable, 1) end
end

local function drawUI()
    local w, h = term.getSize()
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1,1)
    
    -- Отрисовка вкладок
    local function drawTab(name, mode)
        if activeTab == mode then
            term.setBackgroundColor(colors.red); term.setTextColor(colors.white)
        else
            term.setBackgroundColor(colors.gray); term.setTextColor(colors.lightGray)
        end
        write(" " .. name .. " ")
    end
    
    drawTab("WAR ROOM", "CMD")
    drawTab("GLOBAL LOG", "GLOBAL")
    drawTab("CONTROL", "CONTROL")
    
    term.setBackgroundColor(colors.black) 
    
    -- Вкладка CONTROL (Управление)
    if activeTab == "CONTROL" then
        term.setTextColor(colors.white)
        paintutils.drawFilledBox(2, 3, w-1, h-2, colors.gray)
        paintutils.drawFilledBox(3, 4, w-2, h-3, colors.black)
        
        term.setCursorPos(4, 5); print("GENERAL: " .. myProfile.name)
        term.setCursorPos(4, 6); print("STATUS:  ACTIVE COMMAND")
        term.setCursorPos(4, 8); term.setTextColor(colors.yellow); print("[O] CHANGE OBJECTIVE")
        term.setCursorPos(4, 10); term.setTextColor(colors.red); print("[A] BROADCAST ALERT (ALL UNITS)")
        term.setCursorPos(4, 12); term.setTextColor(colors.blue); print("[G] GLOBAL MESSAGE (ALL UNITS)")
        
        term.setCursorPos(3, h-2); term.setTextColor(colors.red); print(" [L] LOGOUT ")
    
    -- Вкладки чатов
    else
        term.setCursorPos(1, 2); term.setTextColor(colors.red); print("OBJ: " .. currentObj)
        
        local list = (activeTab == "CMD") and cmdLogs or globalLogs
        local y = 4
        
        if #list == 0 then
            term.setCursorPos(1, 4); term.setTextColor(colors.gray); print("<No Data>")
        end

        for _, msg in ipairs(list) do
            if y < h-1 then
                term.setCursorPos(1, y); term.setTextColor(msg.color); print(msg.text)
                y = y + 1
            end
        end
        
        term.setCursorPos(1, h); term.setTextColor(colors.red); write(string.rep("=", w))
        term.setCursorPos(1, h); term.setTextColor(colors.white)
        if activeTab == "CMD" then write("[Enter] Command Chat  [Tab] Switch")
        else write("monitor only...   [Tab] Switch") end
    end
end

-- === СЕТЕВОЙ ЦИКЛ ===
local function netLoop()
    while true do
        local id, msg = rednet.receive(PROTOCOL)
        if msg and msg.type == "CHAT_LINE" then
            local decrypted = crypt(msg.text, KEY)
            
            -- Звуковое уведомление
            if msg.channel == "CMD" or msg.alert then
                local s = peripheral.find("speaker"); if s then s.playNote("hat", 1, 10) end
            end

            -- Логика распределения сообщений
            if msg.channel == "CMD" then 
                addLog(cmdLogs, decrypted, msg.color)
            else
                -- Все остальное (GLOBAL, SQUAD) идет в глобальный лог генерала
                addLog(globalLogs, decrypted, msg.color)
            end
            
            drawUI()
        end
    end
end

-- === ВВОД ДАННЫХ ===
local function inputLoop()
    while true do
        local event, key = os.pullEvent("key")
        if not serverID then serverID = os.getComputerID() end

        if key == keys.tab then
            if activeTab == "CMD" then activeTab = "GLOBAL"
            elseif activeTab == "GLOBAL" then activeTab = "CONTROL"
            else activeTab = "CMD" end
            drawUI()
            
        elseif activeTab == "CONTROL" then
            if key == keys.l then
                os.reboot()
                
            elseif key == keys.o then -- Смена задачи
                term.setCursorPos(1, h-1)
                term.setTextColor(colors.yellow)
                write("NEW OBJ: ")
                local txt = read()
                if txt ~= "" then
                    local encTxt = crypt(txt, KEY)
                    rednet.send(serverID, {type="SET_OBJ", text=encTxt}, PROTOCOL)
                end
                drawUI()
                
            elseif key == keys.a then -- ТРЕВОГА (Только генерал)
                term.setCursorPos(1, h-1)
                term.setBackgroundColor(colors.red); term.setTextColor(colors.white)
                write(" ALERT MESSAGE: ")
                local txt = read()
                term.setBackgroundColor(colors.black)
                if txt ~= "" then
                    local encTxt = crypt(txt, KEY)
                    rednet.send(serverID, {type="GLOBAL_ALERT", text=encTxt, callsign=myProfile.id}, PROTOCOL)
                end
                drawUI()
                
            elseif key == keys.g then -- Обычное глобальное сообщение
                term.setCursorPos(1, h-1)
                term.setTextColor(colors.blue)
                write(" GLOBAL MSG: ")
                local txt = read()
                if txt ~= "" then
                     -- Отправляем как SQUAD_CMD но с пустым сквадом, сервер отправит в broadcast? 
                     -- Нет, используем SET_OBJ или добавим логику.
                     -- Для простоты используем SET_OBJ (желтый текст) или просто крик в CMD
                     -- Но лучше всего использовать механику CMD чата, но пометить как BROADCAST.
                     -- В текущей версии сервера нет типа "GLOBAL_CHAT", используем ALERT или CMD.
                     -- Используем CMD канал для общения.
                end
                drawUI()
            end

        elseif key == keys.enter and activeTab == "CMD" then
            term.setCursorPos(1, 12)
            term.setTextColor(colors.red)
            write("COMMAND: ")
            local txt = read()
            if txt ~= "" then
                local encTxt = crypt(txt, KEY)
                rednet.send(serverID, {type="CMD_CHAT", text=encTxt, callsign=myProfile.id}, PROTOCOL)
            end
            drawUI()
        end
    end
end

drawUI()
parallel.waitForAny(netLoop, inputLoop)