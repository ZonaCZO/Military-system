-- === COMMANDER TABLET V12.0 (RC4) ===
-- [ENCRYPTION CLIENT]

local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem!") end
rednet.open(peripheral.getName(modem))

-- === КРИПТОГРАФИЯ (RC4) ===
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
    print("--- SERVER CONNECTING ---")
    
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

local function login()
    if fs.exists("cmd_id.txt") then fs.delete("cmd_id.txt") end
    
    local msgText = ""
    while true do
        term.setBackgroundColor(colors.black)
        term.clear()
        term.setCursorPos(1,1)
        term.setTextColor(colors.cyan)
        print("--- COMMAND LINK V12.0 ---")
        term.setTextColor(colors.white)
        
        if msgText ~= "" then 
            term.setTextColor(colors.red)
            print(msgText) 
            term.setTextColor(colors.white)
        end
        
        write("Commander ID (e.g. K7): ")
        local inputID = string.upper(read())
        write("Password: ")
        local inputPass = read("*")
        
        if not serverID then serverID = rednet.lookup(PROTOCOL, "central_core") end
        if not serverID then serverID = os.getComputerID() end 
        
        rednet.send(serverID, {
            type="LOGIN", 
            userID=inputID, 
            userPass=inputPass, 
            role="COMMANDER"
        }, PROTOCOL)
        
        local id, msg = rednet.receive(PROTOCOL, 3)
        
        if msg and msg.type == "AUTH_OK" then
            myProfile = msg.profile
            currentObj = crypt(msg.obj, KEY) -- Дешифровка задачи
            return 
        elseif msg and msg.type == "AUTH_FAIL" then
            msgText = "DENIED: " .. (msg.reason or "Unknown")
        else
            msgText = "ERROR: HQ No Response"
        end
    end
end

login()

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
    term.setCursorPos(1,1)
    
    local function drawTab(name, mode)
        if activeTab == mode then
            term.setBackgroundColor(colors.blue); term.setTextColor(colors.white)
        else
            term.setBackgroundColor(colors.gray); term.setTextColor(colors.lightGray)
        end
        write(" " .. name .. " ")
    end
    
    drawTab("SQD:"..(myProfile.squad or "???"), "SQUAD")
    drawTab("CMD CHAT", "CMD")
    drawTab("PROFILE", "PROFILE")
    term.setBackgroundColor(colors.black) 
    
    if activeTab == "PROFILE" then
        term.setTextColor(colors.white)
        paintutils.drawFilledBox(2, 3, w-1, h-2, colors.gray)
        paintutils.drawFilledBox(3, 4, w-2, h-3, colors.black)
        term.setCursorPos(4, 5); print("NAME:   " .. myProfile.name)
        term.setCursorPos(4, 6); print("RANK:   " .. myProfile.rank)
        term.setCursorPos(4, 7); print("NATION: " .. myProfile.nation)
        term.setCursorPos(4, 9); print("ID:     " .. myProfile.id)
        term.setCursorPos(4, 10); print("UNIT:   " .. myProfile.squad)
        term.setCursorPos(3, h-2); term.setTextColor(colors.red); print(" [L] LOGOUT (NO SAVE) ")
        
    else
        term.setCursorPos(1, 2); term.setTextColor(colors.yellow); print("OBJ: " .. currentObj)
        local list = (activeTab == "SQUAD") and squadLogs or cmdLogs
        local y = 4
        for _, msg in ipairs(list) do
            if y < h-1 then
                term.setCursorPos(1, y); term.setTextColor(msg.color); print(msg.text)
                y = y + 1
            end
        end
        term.setCursorPos(1, h); term.setTextColor(colors.gray); write(string.rep("=", w))
        term.setCursorPos(1, h); term.setTextColor(colors.white)
        if activeTab == "SQUAD" then write("[Enter]Msg  [O]rders  [Tab]Next")
        else write("[Enter]Secure Msg  [Tab]Next") end
    end
end

local function netLoop()
    while true do
        local id, msg = rednet.receive(PROTOCOL)
        if msg and msg.type == "CHAT_LINE" then
            if (activeTab ~= "CMD" and msg.channel == "CMD") then
                local s = peripheral.find("speaker"); if s then s.playNote("hat", 1, 15) end
            end

            -- Дешифруем входящее
            local decrypted = crypt(msg.text, KEY)
            
            if msg.channel == "CMD" then addLog(cmdLogs, decrypted, msg.color)
            elseif msg.channel == "GLOBAL" then addLog(squadLogs, decrypted, msg.color) 
            elseif msg.channel == "SQUAD" and msg.targetSquad == myProfile.squad then
                addLog(squadLogs, decrypted, msg.color)
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
            
        elseif activeTab == "PROFILE" and key == keys.l then
            os.reboot()
            
        elseif key == keys.o and activeTab == "SQUAD" then
            term.setCursorPos(1, 12)
            term.setTextColor(colors.yellow)
            write("SET OBJ: ")
            local txt = read()
            if txt ~= "" then
                -- Шифруем приказ
                local encTxt = crypt(txt, KEY)
                rednet.send(serverID, {type="SET_OBJ", text=encTxt, key="Freedom"}, PROTOCOL)
            end
            drawUI()
            
        elseif key == keys.enter then
            term.setCursorPos(1, 12)
            if activeTab == "SQUAD" then
                term.setTextColor(colors.green)
                write("TO " .. myProfile.squad .. ": ")
                local txt = read()
                if txt ~= "" then
                    local encTxt = crypt(txt, KEY)
                    rednet.send(serverID, {type="SQUAD_CMD", text=encTxt, callsign=myProfile.id, squad=myProfile.squad}, PROTOCOL)
                end
            elseif activeTab == "CMD" then
                term.setTextColor(colors.cyan)
                write("TO COMMAND: ")
                local txt = read()
                if txt ~= "" then
                    local encTxt = crypt(txt, KEY)
                    rednet.send(serverID, {type="CMD_CHAT", text=encTxt, callsign=myProfile.id}, PROTOCOL)
                end
            end
            drawUI()
        end
    end
end

drawUI()
parallel.waitForAny(netLoop, inputLoop)