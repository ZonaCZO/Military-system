-- === GENERAL TERMINAL V14.2 (RC4 + INTEL) ===
-- [HIGH COMMAND ACCESS]

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
    term.clear(); term.setCursorPos(1,1)
    print("--- GENERAL LINK SETUP ---")
    write("Network ID: "); local input = read()
    if input ~= "" then PROTOCOL = input end
    write("Encryption Key: "); local kInp = read()
    if kInp ~= "" then KEY = kInp end
    local f = fs.open(netFile, "w"); f.writeLine(PROTOCOL); f.writeLine(KEY); f.close()
end

local serverID = rednet.lookup(PROTOCOL, "central_core")
local myProfile = nil
local myToken = nil -- Токен сессии для доступа к БД
local currentObj = "Wait..."

-- === СЕТЕВЫЕ ОБЕРТКИ ===
local function sendEncrypted(data)
    local payload = textutils.serialize(data)
    local encrypted = crypt(payload, KEY)
    rednet.send(serverID, encrypted, PROTOCOL)
end

local function receiveEncrypted(timeout)
    local id, msg = rednet.receive(PROTOCOL, timeout)
    if type(msg) == "string" then
        local decrypted = crypt(msg, KEY)
        return id, textutils.unserialize(decrypted)
    end
    return id, nil
end

-- === ЛОГИН ===
local function login()
    local msgText = ""
    while true do
        term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
        term.setTextColor(colors.red); print("/// HIGH COMMAND TERMINAL ///"); term.setTextColor(colors.white)
        
        if msgText ~= "" then term.setTextColor(colors.red); print(msgText); term.setTextColor(colors.white) end
        
        write("General ID: "); local inputID = string.upper(read())
        write("Password: "); local inputPass = read("*")
        
        if not serverID then serverID = rednet.lookup(PROTOCOL, "central_core") end
        
        sendEncrypted({type="LOGIN", userID=inputID, userPass=inputPass, role="GENERAL"})
        local id, msg = receiveEncrypted(3)
        
        if msg and msg.type == "AUTH_OK" then
            myProfile = msg.profile
            myToken = msg.token
            -- currentObj = msg.obj -- Если сервер все еще шлет obj
            return 
        elseif msg and msg.type == "AUTH_FAIL" then
            msgText = "ACCESS DENIED: " .. (msg.reason or "Unknown")
        else
            msgText = "ERROR: Server Unreachable or Key Mismatch"
        end
    end
end

login()

-- === СОСТОЯНИЕ UI ===
local cmdLogs = {}
local globalLogs = {}
local archiveLogs = {} -- Загруженные из БД логи
local currentArchiveChannel = "NONE"
local activeTab = "CMD" 

local function addLog(targetTable, text, color)
    table.insert(targetTable, {text=text, color=color})
    if #targetTable > 12 then table.remove(targetTable, 1) end
end

local function drawUI()
    local w, h = term.getSize()
    term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
    
    local function drawTab(name, mode)
        if activeTab == mode then
            term.setBackgroundColor(colors.red); term.setTextColor(colors.white)
        else
            term.setBackgroundColor(colors.gray); term.setTextColor(colors.lightGray)
        end
        write(" " .. name .. " ")
    end
    
    drawTab("WAR ROOM", "CMD")
    drawTab("LIVE FEED", "GLOBAL")
    drawTab("INTEL", "INTEL")
    drawTab("CONTROL", "CONTROL")
    term.setBackgroundColor(colors.black) 
    
    if activeTab == "CONTROL" then
        term.setTextColor(colors.white)
        paintutils.drawFilledBox(2, 3, w-1, h-2, colors.gray)
        paintutils.drawFilledBox(3, 4, w-2, h-3, colors.black)
        term.setCursorPos(4, 5); print("GENERAL: " .. myProfile.name)
        term.setCursorPos(4, 6); print("STATUS:  ACTIVE COMMAND")
        term.setCursorPos(4, 8); term.setTextColor(colors.yellow); print("[O] CHANGE OBJECTIVE")
        term.setCursorPos(4, 10); term.setTextColor(colors.red); print("[A] BROADCAST ALERT")
        term.setCursorPos(3, h-2); term.setTextColor(colors.red); print(" [L] LOGOUT ")
        
    elseif activeTab == "INTEL" then
        term.setCursorPos(1, 2); term.setTextColor(colors.cyan); print("DATABASE: " .. currentArchiveChannel)
        local y = 4
        if #archiveLogs == 0 then
            term.setCursorPos(1, y); term.setTextColor(colors.gray); print("< No Data or Awaiting Sync >")
        end
        for _, msg in ipairs(archiveLogs) do
            if y < h-1 then
                term.setCursorPos(1, y); term.setTextColor(colors.lightGray)
                local timeStr = os.date("%H:%M", math.floor((msg.time or 0) / 1000))
                write("["..timeStr.."] ")
                term.setTextColor(colors.white)
                print(msg.from .. ": " .. msg.text)
                y = y + 1
            end
        end
        term.setCursorPos(1, h); term.setTextColor(colors.red); write(string.rep("=", w))
        term.setCursorPos(1, h); term.setTextColor(colors.white)
        write("[Enter] Query Channel  [Tab] Switch")

    else
        term.setCursorPos(1, 2); term.setTextColor(colors.red); print("OBJ: " .. currentObj)
        local list = (activeTab == "CMD") and cmdLogs or globalLogs
        local y = 4
        if #list == 0 then term.setCursorPos(1, 4); term.setTextColor(colors.gray); print("<No Data>") end
        for _, msg in ipairs(list) do
            if y < h-1 then
                term.setCursorPos(1, y); term.setTextColor(msg.color); print(msg.text)
                y = y + 1
            end
        end
        term.setCursorPos(1, h); term.setTextColor(colors.red); write(string.rep("=", w))
        term.setCursorPos(1, h); term.setTextColor(colors.white)
        if activeTab == "CMD" then write("[Enter] Command Chat  [Tab] Switch")
        else write("Monitoring only...    [Tab] Switch") end
    end
end

-- === СЕТЕВОЙ ЦИКЛ ===
local function netLoop()
    while true do
        local id, msg = receiveEncrypted()
        if msg then
            if msg.type == "CHAT_LINE" then
                if msg.channel == "CMD" or msg.alert then
                    local s = peripheral.find("speaker"); if s then s.playNote("hat", 1, 10) end
                end
                if msg.channel == "CMD" then 
                    addLog(cmdLogs, msg.from .. ": " .. msg.text, msg.color)
                else
                    addLog(globalLogs, "[".. (msg.targetSquad or "ALL") .."] " .. msg.from .. ": " .. msg.text, msg.color)
                end
                drawUI()
                
            elseif msg.type == "LOG_DATA" then
                currentArchiveChannel = msg.channel
                archiveLogs = msg.data.messages or {}
                drawUI()
            end
        end
    end
end

-- === ВВОД ДАННЫХ ===
local function inputLoop()
    while true do
        local event, key = os.pullEvent("key")
        local w, h = term.getSize()

        if key == keys.tab then
            if activeTab == "CMD" then activeTab = "GLOBAL"
            elseif activeTab == "GLOBAL" then activeTab = "INTEL"
            elseif activeTab == "INTEL" then activeTab = "CONTROL"
            else activeTab = "CMD" end
            drawUI()
            
        elseif activeTab == "CONTROL" then
            if key == keys.l then
                os.reboot()
            end

        elseif activeTab == "INTEL" and key == keys.enter then
            term.setCursorPos(1, h-1); term.setBackgroundColor(colors.black); term.setTextColor(colors.yellow)
            write(" CHANNEL (e.g. SQD_ALPHA or CMD): ")
            local chan = read()
            if chan ~= "" then
                archiveLogs = {} -- Очищаем старые данные пока грузим
                sendEncrypted({
                    type = "GET_LOGS",
                    userID = myProfile.id,
                    token = myToken,
                    channel = string.upper(chan)
                })
            end
            drawUI()

        elseif activeTab == "CMD" and key == keys.enter then
            term.setCursorPos(1, h-1); term.setTextColor(colors.red)
            write(" COMMAND: ")
            local txt = read()
            if txt ~= "" then
                -- Отправляем зашифрованный пакет на сервер, сервер сам разошлет его как CHAT_LINE
                sendEncrypted({type="CMD_CHAT", userID=myProfile.id, token=myToken, text=txt})
            end
            drawUI()
        end
    end
end

drawUI()
parallel.waitForAny(netLoop, inputLoop)