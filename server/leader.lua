-- === COMMANDER TABLET V10.1 ===
-- [LOGIN FIXED: USES DATABASE]

local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem!") end
rednet.open(peripheral.getName(modem))

local PROTOCOL = "default_net" -- Значение по умолчанию, если ничего не введут
local netFile = "net_config.txt"

if fs.exists(netFile) then
    -- Если конфиг есть — читаем его
    local f = fs.open(netFile, "r")
    PROTOCOL = f.readAll()
    f.close()
else
    -- Если конфига нет — СОЗДАЕМ
    term.clear()
    term.setCursorPos(1,1)
    print("--- SERVER SETUP ---")
    print("Enter ID (e.g. ALPHA_NET):")
    write("> ")
    local input = read()
    
    -- Если ввели текст, используем его. Если просто Enter — оставим дефолт.
    if input ~= "" then 
        PROTOCOL = input 
    end
    
    -- Сохраняем в файл
    local f = fs.open(netFile, "w")
    f.write(PROTOCOL)
    f.close()
    
    print("Network ID saved: " .. PROTOCOL)
    sleep(1)
end

rednet.host(PROTOCOL, "central_core")

local serverID = rednet.lookup(PROTOCOL, "central_core")
local myProfile = nil -- Профиль загрузится с сервера
local currentObj = "Wait..."

-- === ЛОГИН (НОВАЯ СИСТЕМА) ===
local function login()
    if fs.exists("cmd_id.txt") then fs.delete("cmd_id.txt") end
    
    local msgText = ""
    while true do
        term.setBackgroundColor(colors.black)
        term.clear()
        term.setCursorPos(1,1)
        term.setTextColor(colors.cyan)
        print("--- COMMAND LINK V10.1 ---")
        term.setTextColor(colors.white)
        
        if msgText ~= "" then 
            term.setTextColor(colors.red)
            print(msgText) 
            term.setTextColor(colors.white)
        end
        
        -- ТЕПЕРЬ СПРАШИВАЕМ ID, А НЕ ОТРЯД
        write("Commander ID (e.g. K7): ")
        local inputID = string.upper(read())
        write("Password: ")
        local inputPass = read("*")
        
        print("\nVerifying Clearance...")
        
        if not serverID then serverID = rednet.lookup(PROTOCOL, "central_core") end
        if not serverID then serverID = os.getComputerID() end 
        
        -- Отправляем запрос с ролью COMMANDER
        rednet.send(serverID, {
            type="LOGIN", 
            userID=inputID, 
            userPass=inputPass, 
            role="COMMANDER"
        }, PROTOCOL)
        
        local id, msg = rednet.receive(PROTOCOL, 3)
        
        if msg and msg.type == "AUTH_OK" then
            -- Сервер вернул нам профиль, в нем есть наш отряд (squad)
            myProfile = msg.profile
            currentObj = msg.obj
            return 
        elseif msg and msg.type == "AUTH_FAIL" then
            msgText = "DENIED: " .. (msg.reason or "Unknown")
        else
            msgText = "ERROR: HQ No Response"
        end
    end
end

login()

-- === ИНТЕРФЕЙС ===
local squadLogs = {} 
local cmdLogs = {}   
local activeTab = "SQUAD" 

local function addLog(targetTable, text, color)
    table.insert(targetTable, {text=text, color=color})
    if #targetTable > 12 then table.remove(targetTable, 1) end
end

local function drawUI()
    local w, h = term.getSize()
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- ВЕРХНИЙ ТАБ-БАР
    term.setCursorPos(1,1)
    
    local function drawTab(name, mode)
        if activeTab == mode then
            term.setBackgroundColor(colors.blue)
            term.setTextColor(colors.white)
        else
            term.setBackgroundColor(colors.gray)
            term.setTextColor(colors.lightGray)
        end
        write(" " .. name .. " ")
    end
    
    -- Рисуем вкладки. Отряд берем из загруженного профиля
    drawTab("SQD:"..(myProfile.squad or "???"), "SQUAD")
    drawTab("CMD CHAT", "CMD")
    drawTab("PROFILE", "PROFILE")
    
    term.setBackgroundColor(colors.black) 
    
    if activeTab == "PROFILE" then
        -- ДОСЬЕ КОМАНДИРА
        term.setTextColor(colors.white)
        paintutils.drawFilledBox(2, 3, w-1, h-2, colors.gray)
        paintutils.drawFilledBox(3, 4, w-2, h-3, colors.black)
        
        term.setCursorPos(4, 5)
        print("NAME:   " .. myProfile.name)
        term.setCursorPos(4, 6)
        print("RANK:   " .. myProfile.rank)
        term.setCursorPos(4, 7)
        print("NATION: " .. myProfile.nation)
        term.setCursorPos(4, 9)
        print("ID:     " .. myProfile.id)
        term.setCursorPos(4, 10)
        print("UNIT:   " .. myProfile.squad)
        term.setCursorPos(4, 11)
        term.setTextColor(colors.yellow)
        print("CLEARANCE: COMMANDER")
        
        term.setCursorPos(3, h-2)
        term.setTextColor(colors.red)
        print(" [L] LOGOUT (NO SAVE) ")
        
    else
        -- ЧАТЫ
        term.setCursorPos(1, 2)
        term.setTextColor(colors.yellow)
        print("OBJ: " .. currentObj)
        
        local list = (activeTab == "SQUAD") and squadLogs or cmdLogs
        local y = 4
        for _, msg in ipairs(list) do
            if y < h-1 then
                term.setCursorPos(1, y)
                term.setTextColor(msg.color)
                print(msg.text)
                y = y + 1
            end
        end
        
        -- Футер
        term.setCursorPos(1, h)
        term.setTextColor(colors.gray)
        write(string.rep("=", w))
        term.setCursorPos(1, h)
        term.setTextColor(colors.white)
        
        if activeTab == "SQUAD" then
            write("[Enter]Msg  [O]rders  [Tab]Next")
        else
            write("[Enter]Secure Msg  [Tab]Next")
        end
    end
end

local function netLoop()
    while true do
        local id, msg = rednet.receive(PROTOCOL)
        if msg and msg.type == "CHAT_LINE" then
            
            -- Звук
            if (activeTab ~= "CMD" and msg.channel == "CMD") then
                local s = peripheral.find("speaker")
                if s then s.playNote("hat", 1, 15) end
            end

            if msg.channel == "CMD" then
                addLog(cmdLogs, msg.text, msg.color)
            elseif msg.channel == "GLOBAL" then
                addLog(squadLogs, msg.text, msg.color) 
            elseif msg.channel == "SQUAD" and msg.targetSquad == myProfile.squad then
                addLog(squadLogs, msg.text, msg.color)
            end
            drawUI()
        end
    end
end

local function inputLoop()
    while true do
        local event, key = os.pullEvent("key")
        if not serverID then serverID = os.getComputerID() end

        if key == keys.tab then
            if activeTab == "SQUAD" then activeTab = "CMD"
            elseif activeTab == "CMD" then activeTab = "PROFILE"
            else activeTab = "SQUAD" end
            drawUI()
            
        elseif activeTab == "PROFILE" then
            if key == keys.l then
                os.reboot()
            end
            
        elseif key == keys.o and activeTab == "SQUAD" then
            term.setCursorPos(1, 12)
            term.setTextColor(colors.yellow)
            write("SET OBJ: ")
            local txt = read()
            if txt ~= "" then
                rednet.send(serverID, {type="SET_OBJ", text=txt, key="Freedom"}, PROTOCOL)
            end
            drawUI()
            
        elseif key == keys.enter then
            term.setCursorPos(1, 12)
            if activeTab == "SQUAD" then
                term.setTextColor(colors.green)
                write("TO " .. myProfile.squad .. ": ")
                local txt = read()
                if txt ~= "" then
                    rednet.send(serverID, {type="SQUAD_CMD", text=txt, callsign=myProfile.id, squad=myProfile.squad}, PROTOCOL)
                end
            elseif activeTab == "CMD" then
                term.setTextColor(colors.cyan)
                write("TO COMMAND: ")
                local txt = read()
                if txt ~= "" then
                    rednet.send(serverID, {type="CMD_CHAT", text=txt, callsign=myProfile.id}, PROTOCOL)
                end
            end
            drawUI()
        end
    end
end

drawUI()
parallel.waitForAny(netLoop, inputLoop)