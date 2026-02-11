-- === NIPAYA COMMANDER TABLET V6.2 ===
-- [FIFO Logs + Duplicate Fix Support]

local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem!") end
rednet.open(peripheral.getName(modem))

local serverID = nil 
local myCallsign = ""
local targetSquad = "" 

if fs.exists("cmd_id.txt") then
    local f = fs.open("cmd_id.txt", "r")
    myCallsign = f.readAll()
    f.close()
else
    term.clear()
    write("Commander ID (e.g. K7): ")
    myCallsign = string.upper(read())
    local f = fs.open("cmd_id.txt", "w")
    f.write(myCallsign)
    f.close()
end

local function login()
    local msgText = "" 
    while true do
        term.setBackgroundColor(colors.black)
        term.clear()
        term.setCursorPos(1,1)
        print("--- CMD LOGIN ---")
        if msgText ~= "" then print(msgText) end
        
        write("Command Squad (ALPHA): ")
        targetSquad = string.upper(read()) 
        write("Password: ")
        local pass = read("*")
        
        serverID = rednet.lookup("nipaya_net", "central_core")
        if not serverID then serverID = os.getComputerID() end 
        
        rednet.send(serverID, {type="LOGIN", squad=targetSquad, pass=pass, role="COMMANDER"}, "nipaya_net")
        local id, msg = rednet.receive("nipaya_net", 3)
        if msg and msg.type == "AUTH" and msg.res then return msg.obj else msgText = "Access Denied" end
    end
end

local currentObj = login()

-- === СИСТЕМА ЛОГОВ (FIFO) ===
local squadLogs = {} 
local cmdLogs = {}   
local activeTab = "SQUAD" 

-- Функция добавления: удаляет старое, если больше 11 сообщений
local function addLog(targetTable, text, color)
    table.insert(targetTable, {text=text, color=color})
    if #targetTable > 11 then 
        table.remove(targetTable, 1) -- Удаляем самое верхнее
    end
end

local function drawUI()
    term.setBackgroundColor(colors.black)
    term.clear()
    local w, h = term.getSize()
    
    -- ВКЛАДКИ
    term.setCursorPos(1,1)
    if activeTab == "SQUAD" then
        term.setBackgroundColor(colors.green)
        term.setTextColor(colors.black)
        write(" SQD: " .. targetSquad .. " ")
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.gray)
        write(" CMD CHAT ")
    else
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.gray)
        write(" SQD: " .. targetSquad .. " ")
        term.setBackgroundColor(colors.blue)
        term.setTextColor(colors.white)
        write(" CMD CHAT ")
    end
    
    -- ПРИКАЗ
    term.setBackgroundColor(colors.black)
    term.setCursorPos(1, 3)
    term.setTextColor(colors.yellow)
    print("OBJ: " .. currentObj)
    
    -- ЧАТ (ОТРИСОВКА)
    local list = (activeTab == "SQUAD") and squadLogs or cmdLogs
    local y = 5 -- Начало чата
    
    for _, msg in ipairs(list) do
        if y < h-2 then
            term.setCursorPos(1, y)
            term.setTextColor(msg.color)
            print(msg.text)
            y = y + 1
        end
    end
    
    -- ФУТЕР
    term.setCursorPos(1, h-1)
    term.setTextColor(colors.gray)
    print(string.rep("=", w))
    term.setTextColor(colors.white)
    
    if activeTab == "SQUAD" then
        write("[Enter]Msg  [O]rders  [Tab]Switch")
    else
        write("[Enter]Secure Msg  [Tab]Switch")
    end
end

local function netLoop()
    while true do
        local id, msg = rednet.receive("nipaya_net")
        if msg and msg.type == "CHAT_LINE" then
            
            -- Звук входящего сообщения
            if (activeTab == "CMD" and msg.channel ~= "CMD") or 
               (activeTab == "SQUAD" and msg.channel == "CMD") then
                local s = peripheral.find("speaker")
                if s then s.playNote("hat", 1, 15) end
            end

            -- Распределение по вкладкам
            if msg.channel == "CMD" then
                addLog(cmdLogs, msg.text, msg.color)
            elseif msg.channel == "GLOBAL" then
                addLog(squadLogs, msg.text, msg.color) 
            elseif msg.channel == "SQUAD" and msg.targetSquad == targetSquad then
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
            if activeTab == "SQUAD" then activeTab = "CMD" else activeTab = "SQUAD" end
            drawUI()
            
        elseif key == keys.o and activeTab == "SQUAD" then
            term.setCursorPos(1, 13)
            term.setTextColor(colors.yellow)
            write("SET OBJ: ")
            local txt = read()
            if txt ~= "" then
                rednet.send(serverID, {type="SET_OBJ", text=txt, key="Freedom"}, "nipaya_net")
            end
            drawUI()
            
        elseif key == keys.enter then
            term.setCursorPos(1, 13)
            if activeTab == "SQUAD" then
                term.setTextColor(colors.green)
                write("TO " .. targetSquad .. ": ")
                local txt = read()
                if txt ~= "" then
                    rednet.send(serverID, {type="SQUAD_CMD", text=txt, callsign=myCallsign, squad=targetSquad}, "nipaya_net")
                end
            else
                term.setTextColor(colors.cyan)
                write("TO COMMAND: ")
                local txt = read()
                if txt ~= "" then
                    rednet.send(serverID, {type="CMD_CHAT", text=txt, callsign=myCallsign}, "nipaya_net")
                end
            end
            drawUI()
        end
    end
end

drawUI()
parallel.waitForAny(netLoop, inputLoop)