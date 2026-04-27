-- === COMMANDER TABLET V14.3 (Tactical Markers) ===
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
    PROTOCOL = f.readLine(); KEY = f.readLine(); f.close()
end

local serverID = rednet.lookup(PROTOCOL, "central_core")
local myProfile = nil
local myToken = nil
local currentObj = "Wait..."

local function sendEncrypted(data)
    if not serverID then return false end
    local payload = textutils.serialize(data)
    rednet.send(serverID, crypt(payload, KEY), PROTOCOL)
    return true
end

local function receiveEncrypted(timeout)
    local id, msg = rednet.receive(PROTOCOL, timeout)
    if type(msg) == "string" then
        return id, textutils.unserialize(crypt(msg, KEY))
    end
    return id, nil
end

local function login()
    local msgText = ""
    while true do
        term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
        term.setTextColor(colors.cyan); print("--- COMMAND LINK V14.3 ---"); term.setTextColor(colors.white)
        
        if msgText ~= "" then term.setTextColor(colors.red); print(msgText); term.setTextColor(colors.white) end
        
        write("Commander ID: "); local inputID = string.upper(read())
        write("Password: "); local inputPass = read("*")
        
        serverID = rednet.lookup(PROTOCOL, "central_core")
        
        if serverID then
            sendEncrypted({type="LOGIN", userID=inputID, userPass=inputPass, role="COMMANDER"})
            local id, msg = receiveEncrypted(3)
            
            if msg and msg.type == "AUTH_OK" then
                myProfile = msg.profile
                myToken = msg.token
                return 
            elseif msg and msg.type == "AUTH_FAIL" then
                msgText = "DENIED: " .. (msg.reason or "Unknown")
            else
                msgText = "ERROR: HQ No Response"
            end
        else
            msgText = "ERROR: Server Offline"
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
    term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
    
    local function drawTab(name, mode)
        if activeTab == mode then term.setBackgroundColor(colors.blue); term.setTextColor(colors.white)
        else term.setBackgroundColor(colors.gray); term.setTextColor(colors.lightGray) end
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
        term.setCursorPos(4, 9); print("ID:     " .. myProfile.id)
        term.setCursorPos(3, h-2); term.setTextColor(colors.red); print(" [L] LOGOUT ")
        
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
        if activeTab == "SQUAD" then write("[Enter]Msg  [O]rders  [M]arker  [Tab]Next")
        else write("[Enter]Secure Msg  [Tab]Next") end
    end
end

local function netLoop()
    while true do
        local id, msg = receiveEncrypted()
        if msg and msg.type == "CHAT_LINE" then
            if msg.channel == "CMD" then addLog(cmdLogs, msg.from..": "..msg.text, msg.color)
            elseif msg.channel == "GLOBAL" then addLog(squadLogs, "[ALL] "..msg.from..": "..msg.text, msg.color) 
            elseif msg.channel == "SQUAD" and msg.targetSquad == myProfile.squad then
                addLog(squadLogs, msg.from..": "..msg.text, msg.color)
            end
            drawUI()
        end
    end
end

local function inputLoop()
    while true do
        local event, key = os.pullEvent("key")

        if key == keys.tab then
            if activeTab == "SQUAD" then activeTab = "CMD"
            elseif activeTab == "CMD" then activeTab = "PROFILE"
            else activeTab = "SQUAD" end
            drawUI()
            
        elseif activeTab == "PROFILE" and key == keys.l then
            os.reboot()
            
        elseif key == keys.o and activeTab == "SQUAD" then
            term.setCursorPos(1, 12); term.setTextColor(colors.yellow)
            write("SET OBJ: ")
            local txt = read()
            if txt ~= "" then
                sendEncrypted({type="SET_OBJ", userID=myProfile.id, token=myToken, text=txt})
            end
            drawUI()
            
        -- === НОВАЯ ЛОГИКА МАРКЕРОВ ===
        elseif key == keys.m and activeTab == "SQUAD" then
            term.setCursorPos(1, 12); term.setTextColor(colors.magenta)
            write("Front ID: ")
            local fId = read()
            if fId ~= "" then
                write("X: "); local mX = tonumber(read()) or 0
                write("Z: "); local mZ = tonumber(read()) or 0
                write("Type (1=enemy, 2=ally, 3=obj): ")
                local tInp = read()
                local mType = "note"
                if tInp == "1" then mType = "enemy"
                elseif tInp == "2" then mType = "ally"
                elseif tInp == "3" then mType = "objective" end
                
                sendEncrypted({
                    type = "MAP_ADD_MARKER",
                    userID = myProfile.id,
                    token = myToken,
                    frontId = string.lower(fId),
                    x = mX, z = mZ,
                    markerType = mType,
                    label = "HQ Update"
                })
                addLog(cmdLogs, "MARKER SENT TO " .. string.upper(fId), colors.magenta)
            end
            drawUI()
            
        elseif key == keys.enter then
            term.setCursorPos(1, 12)
            if activeTab == "SQUAD" then
                term.setTextColor(colors.green)
                write("TO " .. myProfile.squad .. ": ")
                local txt = read()
                if txt ~= "" then
                    sendEncrypted({type="SQUAD_CMD", userID=myProfile.id, token=myToken, text=txt, squad=myProfile.squad})
                end
            elseif activeTab == "CMD" then
                term.setTextColor(colors.cyan)
                write("TO COMMAND: ")
                local txt = read()
                if txt ~= "" then
                    sendEncrypted({type="CMD_CHAT", userID=myProfile.id, token=myToken, text=txt})
                end
            end
            drawUI()
        end
    end
end

drawUI()
parallel.waitForAny(netLoop, inputLoop)