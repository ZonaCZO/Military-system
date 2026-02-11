-- === COMMANDER TABLET V7.0 ===
-- [Universal Network Support]

local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem!") end
rednet.open(peripheral.getName(modem))

-- === НАСТРОЙКА СЕТИ ===
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
    print("Enter Network ID (Must match Server):")
    write("> ")
    local input = read()
    if input ~= "" then PROTOCOL = input end
    local f = fs.open(netFile, "w")
    f.write(PROTOCOL)
    f.close()
end

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
        print("--- CMD LOGIN ["..PROTOCOL.."] ---")
        if msgText ~= "" then print(msgText) end
        
        write("Command Squad (ALPHA): ")
        targetSquad = string.upper(read()) 
        write("Password: ")
        local pass = read("*")
        
        serverID = rednet.lookup(PROTOCOL, "central_core")
        if not serverID then serverID = os.getComputerID() end 
        
        rednet.send(serverID, {type="LOGIN", squad=targetSquad, pass=pass, role="COMMANDER"}, PROTOCOL)
        local id, msg = rednet.receive(PROTOCOL, 3)
        if msg and msg.type == "AUTH" and msg.res then return msg.obj else msgText = "Access Denied" end
    end
end

local currentObj = login()

-- === ЛОГИ ===
local squadLogs = {} 
local cmdLogs = {}   
local activeTab = "SQUAD" 

local function addLog(targetTable, text, color)
    table.insert(targetTable, {text=text, color=color})
    if #targetTable > 11 then table.remove(targetTable, 1) end
end

local function drawUI()
    term.setBackgroundColor(colors.black)
    term.clear()
    local w, h = term.getSize()
    
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
    
    term.setBackgroundColor(colors.black)
    term.setCursorPos(1, 3)
    term.setTextColor(colors.yellow)
    print("OBJ: " .. currentObj)
    
    local list = (activeTab == "SQUAD") and squadLogs or cmdLogs
    local y = 5
    for _, msg in ipairs(list) do
        if y < h-2 then
            term.setCursorPos(1, y)
            term.setTextColor(msg.color)
            print(msg.text)
            y = y + 1
        end
    end
    
    term.setCursorPos(1, h-1)
    term.setTextColor(colors.gray)
    print(string.rep("=", w))
    term.setTextColor(colors.white)
    
    if activeTab == "SQUAD" then write("[Enter]Msg  [O]rders  [Tab]Switch")
    else write("[Enter]Secure Msg  [Tab]Switch") end
end

local function netLoop()
    while true do
        local id, msg = rednet.receive(PROTOCOL)
        if msg and msg.type == "CHAT_LINE" then
            if (activeTab == "CMD" and msg.channel ~= "CMD") or 
               (activeTab == "SQUAD" and msg.channel == "CMD") then
                local s = peripheral.find("speaker")
                if s then s.playNote("hat", 1, 15) end
            end

            if msg.channel == "CMD" then addLog(cmdLogs, msg.text, msg.color)
            elseif msg.channel == "GLOBAL" then addLog(squadLogs, msg.text, msg.color) 
            elseif msg.channel == "SQUAD" and msg.targetSquad == targetSquad then addLog(squadLogs, msg.text, msg.color)
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
                rednet.send(serverID, {type="SET_OBJ", text=txt, key="Freedom"}, PROTOCOL)
            end
            drawUI()
            
        elseif key == keys.enter then
            term.setCursorPos(1, 13)
            if activeTab == "SQUAD" then
                term.setTextColor(colors.green)
                write("TO " .. targetSquad .. ": ")
                local txt = read()
                if txt ~= "" then
                    rednet.send(serverID, {type="SQUAD_CMD", text=txt, callsign=myCallsign, squad=targetSquad}, PROTOCOL)
                end
            else
                term.setTextColor(colors.cyan)
                write("TO COMMAND: ")
                local txt = read()
                if txt ~= "" then
                    rednet.send(serverID, {type="CMD_CHAT", text=txt, callsign=myCallsign}, PROTOCOL)
                end
            end
            drawUI()
        end
    end
end

drawUI()
parallel.waitForAny(netLoop, inputLoop)