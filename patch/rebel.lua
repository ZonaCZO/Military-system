local textInput = require("system.text_input")
local function safeRead(mask, mode, maxLength)
    return textInput.read({mask=mask, mode=mode, maxLength=maxLength})
end

-- ==========================================
-- === PDA V14.2 (SECURE STORAGE + TOKENS) ===
-- ==========================================

local modem = peripheral.find("modem")
if not modem then
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(colors.red)
    print("FATAL ERROR: Wireless modem not found!")
    print("Please attach a modem and reboot.")
    term.setTextColor(colors.white)
    return
end
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

-- Функция для обфускации/хеширования ключа сети
local function hashNetKey(key)
    if not key or key == "" or key == "none" then return key end
    return textutils.serialize(key):gsub(".", function(c)
        return string.char((string.byte(c) * 7) % 256)
    end)
end

if fs.exists(netFile) then
    local f = fs.open(netFile, "r")
    PROTOCOL = f.readLine()
    KEY = f.readLine()
    f.close()
    if not KEY then KEY = "none" end
else
    term.clear(); term.setCursorPos(1,1)
    print("--- NETWORK SETUP ---")
    
    write("Network ID: "); local input = safeRead(nil, "EN", 48)
    if input ~= "" then PROTOCOL = input end
    
    write("Encryption Key: "); local kInp = safeRead("*", "EN", 64)
    if kInp ~= "" then 
        KEY = hashNetKey(kInp) -- Хешируем введенный пароль!
    end
    
    local f = fs.open(netFile, "w")
    f.writeLine(PROTOCOL)
    f.writeLine(KEY) -- В файл записывается уже хеш, а не чистый текст
    f.close()
    sleep(1)
end

local serverID = rednet.lookup(PROTOCOL, "central_core")
local myProfile = nil
local myToken = nil
local currentObj = "Awaiting Orders..."

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

local function promptInput(promptText)
    local w, h = term.getSize()
    paintutils.drawFilledBox(1, h-2, w, h, colors.black)
    term.setCursorPos(1, h-1); term.setTextColor(colors.yellow)
    write(promptText); term.setTextColor(colors.white)
    return safeRead(nil, nil, 160)
end

-- === ЛОГИН ===
local function login()
    -- АВТОЛОГИН
    if fs.exists("session.dat") then
        local f = fs.open("session.dat", "r")
        local rawData = f.readAll()
        f.close()
        
        local decryptedJson = crypt(rawData, KEY)
        local savedData = textutils.unserialize(decryptedJson)
        
        if savedData and savedData.id and savedData.pass then
            if not serverID then serverID = rednet.lookup(PROTOCOL, "central_core") end
            if serverID then 
                sendEncrypted({type="LOGIN", userID=savedData.id, userPass=savedData.pass, role="soldier"})
                local _, msg = receiveEncrypted(3)
                if msg and msg.type=="AUTH_OK" then 
                    myProfile = msg.profile
                    myToken = msg.token
                    return
                end
            end
        end
        -- Если не вышло (сменился ключ, пароль или сервер оффлайн)
        print("Session expired or Server Offline.")
        fs.delete("session.dat")
        sleep(1)
    end

    -- РУЧНОЙ ЛОГИН
    while true do
        term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
        print("=== SOLDIER LOGIN ===")
        write("ID (e.g. ST): "); local inputID = string.upper(safeRead(nil, "EN", 24))
        write("Password: "); local inputPass = safeRead("*", "EN", 64)
        
        if not serverID then serverID = rednet.lookup(PROTOCOL, "central_core") end
        
        if serverID then
            sendEncrypted({type="LOGIN", userID=inputID, userPass=inputPass, role="soldier"})
            local _, msg = receiveEncrypted(3)
            
            if msg and msg.type == "AUTH_OK" then
                myProfile = msg.profile
                myToken = msg.token
                
                -- Сохраняем только креды для автологина
                local cleanJson = textutils.serialize({id=inputID, pass=inputPass})
                local encryptedData = crypt(cleanJson, KEY)
                local f = fs.open("session.dat", "w")
                f.write(encryptedData)
                f.close()
                return
            else
                print("Error: Access Denied")
                sleep(2)
            end
        else
            print("Server Offline")
            sleep(2)
        end
    end
end

login()

-- === UI ===
local activeTab = "TASK"
local tabs = {"TASK", "COMMS", "ALERT", "PROFILE"}
local logHistory = {}
local unread = 0
local linkOnline = serverID ~= nil

local function addLog(text, color)
    local t = textutils.formatTime(os.time(), true)
    table.insert(logHistory, {text=text, color=color or colors.green, time=t})
    if #logHistory > 8 then table.remove(logHistory, 1) end
end

local function sendPacket(text)
    -- Отправляем как SQUAD_REPORT с токеном
    sendEncrypted({
        type = "SQUAD_REPORT", 
        userID = myProfile.id, 
        token = myToken, 
        squad = myProfile.squad,
        text = text
    })
    addLog("ME: " .. text, colors.white)
end

local function drawUI()
    local w, h = term.getSize()
    term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
    term.setBackgroundColor(colors.gray); term.setTextColor(colors.yellow); write(" MSOS PDA ")
    term.setTextColor(linkOnline and colors.lime or colors.red)
    write(linkOnline and " ONLINE" or " OFFLINE")
    local lang=textInput.getLanguage()
    term.setCursorPos(math.max(1,w-#lang-1),1); term.setTextColor(colors.white); write(lang)

    paintutils.drawFilledBox(1,2,w,2,colors.lightGray)
    local labels={TASK="TASK",COMMS="COMMS",ALERT="ALERT",PROFILE="ID"}
    local x=1
    for _,name in ipairs(tabs) do
        local label=labels[name]..(name=="COMMS" and unread>0 and ("("..unread..")") or "")
        term.setCursorPos(x,2); term.setBackgroundColor(name==activeTab and colors.blue or colors.lightGray)
        term.setTextColor(name==activeTab and colors.white or colors.black); write(" "..label.." ")
        x=x+#label+2
    end

    term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
    if activeTab == "TASK" then
        term.setCursorPos(2,4); term.setTextColor(colors.yellow); print("CURRENT ORDER")
        term.setTextColor(colors.white)
        local text=tostring(currentObj or "No active order")
        for i=1,#text,w-2 do term.setCursorPos(2,5+math.floor((i-1)/(w-2))); print(text:sub(i,i+w-3)) end
        term.setCursorPos(2,h-3); term.setTextColor(colors.cyan); print("[C] Open communications")
        term.setCursorPos(2,h-2); term.setTextColor(colors.red); print("[A] Send field alert")
    elseif activeTab == "COMMS" then
        local first=math.max(1,#logHistory-(h-6))
        local y=4
        for i=first,#logHistory do
            local item=logHistory[i]; term.setCursorPos(1,y); term.setTextColor(item.color)
            print(item.text:sub(1,w)); y=y+1
        end
        term.setCursorPos(2,h-2); term.setTextColor(colors.cyan); print("[ENTER] New message")
    elseif activeTab == "ALERT" then
        term.setCursorPos(2,4); term.setTextColor(colors.white); print("FIELD REPORT")
        term.setTextColor(colors.cyan); term.setCursorPos(2,6); print("[1] Request supplies")
        term.setTextColor(colors.magenta); term.setCursorPos(2,7); print("[2] Injury / S.O.S")
        term.setTextColor(colors.orange); term.setCursorPos(2,8); print("[3] Sector captured")
        term.setTextColor(colors.red); term.setCursorPos(2,9); print("[4] Enemy contact")
    else
        paintutils.drawFilledBox(1, 3, w, h-1, colors.white)
        term.setTextColor(colors.black); term.setBackgroundColor(colors.white)
        term.setCursorPos(2, 4); print("NAME:   " .. myProfile.name)
        term.setCursorPos(2, 5); print("RANK:   " .. myProfile.rank)
        term.setCursorPos(2, 6); print("NATION: " .. myProfile.nation)
        term.setCursorPos(2, 8); print("ID:     " .. myProfile.id)
        term.setCursorPos(2, 9); print("SQUAD:  " .. myProfile.squad)
        term.setCursorPos(2, h-1); term.setTextColor(colors.red); print("[L] LOGOUT")
    end
    term.setBackgroundColor(colors.gray); term.setTextColor(colors.white); term.setCursorPos(1,h)
    write("TAB pages | F2 language"..string.rep(" ",math.max(0,w-23)))
end

local function inputLoop()
    while true do
        local event, key, mx, my = os.pullEvent()
        if event=="key" then
            if key == keys.tab then
                local index=1; for i,name in ipairs(tabs) do if name==activeTab then index=i end end
                activeTab=tabs[index % #tabs + 1]; if activeTab=="COMMS" then unread=0 end
            elseif key==keys.f2 then textInput.nextLanguage()
            elseif key==keys.c then activeTab="COMMS"; unread=0
            elseif key==keys.a then activeTab="ALERT"
            elseif activeTab=="COMMS" and key==keys.enter then
                local txt=promptInput("MSG: "); if txt~="" then sendPacket(txt) end
            elseif activeTab=="ALERT" then
                if key==keys.one then local t=promptInput("REQ: "); if t~="" then sendPacket("REQ: "..t) end
                elseif key==keys.two then sendPacket("CRITICAL INJURY!")
                elseif key==keys.three then local t=promptInput("CAP: "); if t~="" then sendPacket("CAPTURING "..t) end
                elseif key==keys.four then local t=promptInput("LOC: "); if t~="" then sendPacket("CONTACT: "..t) end end
            elseif activeTab=="PROFILE" and key==keys.l then fs.delete("session.dat"); os.reboot() end
            drawUI()
        elseif event=="mouse_click" then
            if my==2 then
                local w=select(1,term.getSize()); local part=math.max(1,math.ceil(w/4)); local index=math.min(4,math.floor((mx-1)/part)+1)
                activeTab=tabs[index]; if activeTab=="COMMS" then unread=0 end; drawUI()
            end
        end
    end
end

local function netLoop()
    while true do
        local id, msg = receiveEncrypted(1)
        if msg and msg.type == "CHAT_LINE" then
            local show = false
            if msg.channel == "GLOBAL" then show = true end
            if msg.channel == "SQUAD" and msg.targetSquad == myProfile.squad then show = true end
            
            if show then
                linkOnline=true
                if msg.channel == "GLOBAL" and msg.color == colors.yellow then
                     currentObj = string.gsub(msg.text, "NEW ORDERS: ", "")
                     local s = peripheral.find("speaker"); if s then s.playNote("pling", 3, 24) end
                end
                -- Добавляем префикс от кого пришло сообщение
                local prefix = (msg.from == myProfile.id) and "" or (msg.from .. ": ")
                addLog(prefix .. msg.text, msg.color)
                if activeTab~="COMMS" then unread=math.min(99,unread+1) end
                drawUI()
            end
        elseif not msg then
            drawUI() -- Обновляем часы
        end
    end
end

drawUI()
parallel.waitForAny(inputLoop, netLoop)
