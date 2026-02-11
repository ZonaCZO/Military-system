-- === PDA V12.0 (RC4) ===
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
local netFile = "net_config.txt"

if fs.exists(netFile) then
    local f = fs.open(netFile, "r")
    PROTOCOL = f.readLine()
    KEY = f.readLine()
    f.close()
    if not KEY then KEY = "none" end
else
    term.clear()
    term.setCursorPos(1,1)
    print("--- DEVICE SETUP ---")
    write("Network ID: ")
    local inp = read()
    if inp ~= "" then PROTOCOL = inp end
    
    write("Encryption Key: ")
    local kInp = read()
    if kInp ~= "" then KEY = kInp end
    
    local f = fs.open(netFile, "w")
    f.writeLine(PROTOCOL)
    f.writeLine(KEY)
    f.close()
    sleep(1)
end

local serverID = rednet.lookup(PROTOCOL, "central_core")
local myProfile = nil
local currentObj = "Connecting..."

local function promptInput(promptText)
    local w, h = term.getSize()
    paintutils.drawFilledBox(1, h-2, w, h, colors.black)
    term.setCursorPos(1, h-1)
    term.setTextColor(colors.yellow)
    write(promptText)
    term.setTextColor(colors.white)
    return read()
end

local function login()
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
                if msg and msg.type=="AUTH_OK" then 
                    currentObj = crypt(msg.obj, KEY)
                end
            end
            return
        end
    end

    while true do
        term.setBackgroundColor(colors.black)
        term.clear()
        term.setCursorPos(1,1)
        print("=== SOLDIER LOGIN ===")
        write("ID (e.g. J1): ")
        local inputID = string.upper(read())
        write("Password: ")
        local inputPass = read("*")
        
        if not serverID then serverID = rednet.lookup(PROTOCOL, "central_core") end
        
        if serverID then
            rednet.send(serverID, {type="LOGIN", userID=inputID, userPass=inputPass, role="SOLDIER"}, PROTOCOL)
            local _, msg = rednet.receive(PROTOCOL, 3)
            
            if msg and msg.type == "AUTH_OK" then
                myProfile = msg.profile
                myProfile.pass = inputPass
                currentObj = crypt(msg.obj, KEY)
                
                local f = fs.open("session.txt", "w")
                f.write(textutils.serialize(myProfile))
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
local activeTab = "TACTICAL"
local menuState = "MAIN"
local logHistory = {}

local function addLog(text, color)
    local t = textutils.formatTime(os.time(), true)
    table.insert(logHistory, {text=text, color=color or colors.green, time=t})
    if #logHistory > 8 then table.remove(logHistory, 1) end
end

local function sendPacket(text)
    local encText = crypt(text, KEY) -- Шифруем
    rednet.send(serverID, {type = "REPORT", userID=myProfile.id, text = encText}, PROTOCOL)
    addLog("ME: " .. text, colors.white)
end

local function drawUI()
    local w, h = term.getSize()
    term.setCursorPos(1,1)
    if activeTab == "TACTICAL" then
        term.setBackgroundColor(colors.blue); term.setTextColor(colors.white); write(" TACTICAL ")
        term.setBackgroundColor(colors.gray); term.setTextColor(colors.lightGray); write(" PROFILE ")
    else
        term.setBackgroundColor(colors.gray); term.setTextColor(colors.lightGray); write(" TACTICAL ")
        term.setBackgroundColor(colors.blue); term.setTextColor(colors.white); write(" PROFILE ")
    end
    term.setBackgroundColor(colors.gray)
    write(string.rep(" ", w - 18))
    local timeStr = textutils.formatTime(os.time(), true)
    term.setCursorPos(w - #timeStr + 1, 1)
    term.setTextColor(colors.white)
    write(timeStr)
    
    if activeTab == "TACTICAL" then
        paintutils.drawFilledBox(1, 2, w, h, colors.black)
        term.setCursorPos(1, 2)
        term.setTextColor(colors.yellow)
        print("OBJ: " .. string.sub(currentObj, 1, w-5))
        
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
            local btnY = h-2
            paintutils.drawFilledBox(1, btnY, w/2, h-1, colors.red)
            term.setCursorPos(2, btnY); term.setTextColor(colors.white); term.setBackgroundColor(colors.red); write("1.ALERTS")
            paintutils.drawFilledBox(w/2+1, btnY, w, h-1, colors.blue)
            term.setCursorPos(w/2+2, btnY); term.setBackgroundColor(colors.blue); write("2.MSG")
            term.setBackgroundColor(colors.black); term.setTextColor(colors.gray); term.setCursorPos(1, h); write("TAB: Switch Tab")
            
        elseif menuState == "ALERTS" then
            term.setCursorPos(1, 4); term.setTextColor(colors.white); print("SELECT ALERT:")
            term.setTextColor(colors.cyan); print(" 1. REQUEST..")
            term.setTextColor(colors.magenta); print(" 2. INJURY (S.O.S)")
            term.setTextColor(colors.orange); print(" 3. CAPTURE..")
            term.setTextColor(colors.red); print(" 4. CONTACT..")
            print(""); term.setTextColor(colors.lightGray); print(" 5. < BACK")
        end
    else
        paintutils.drawFilledBox(1, 2, w, h, colors.white)
        term.setTextColor(colors.black); term.setBackgroundColor(colors.white)
        term.setCursorPos(2, 4); print("NAME:   " .. myProfile.name)
        term.setCursorPos(2, 5); print("RANK:   " .. myProfile.rank)
        term.setCursorPos(2, 6); print("NATION: " .. myProfile.nation)
        term.setCursorPos(2, 8); print("ID:     " .. myProfile.id)
        term.setCursorPos(2, 9); print("SQUAD:  " .. myProfile.squad)
        term.setCursorPos(2, h-1); term.setTextColor(colors.red); print("[L] LOGOUT")
    end
end

local function inputLoop()
    while true do
        local event, key = os.pullEvent("key")
        if key == keys.tab then
            if activeTab == "TACTICAL" then activeTab = "PROFILE" else activeTab = "TACTICAL" end
            if activeTab == "TACTICAL" then menuState = "MAIN" end
            drawUI()
        elseif activeTab == "TACTICAL" then
            if menuState == "MAIN" then
                if key == keys.one then menuState = "ALERTS"; drawUI()
                elseif key == keys.two then
                    local txt = promptInput("MSG: ")
                    if txt ~= "" then sendPacket(txt) end
                    drawUI()
                end
            elseif menuState == "ALERTS" then
                if key == keys.one then local t=promptInput("REQ: "); if t~="" then sendPacket("REQ: "..t) end; menuState="MAIN"
                elseif key == keys.two then sendPacket("CRITICAL INJURY!"); menuState="MAIN"
                elseif key == keys.three then local t=promptInput("CAP: "); if t~="" then sendPacket("CAPTURING "..t) end; menuState="MAIN"
                elseif key == keys.four then local t=promptInput("LOC: "); if t~="" then sendPacket("CONTACT: "..t) end; menuState="MAIN"
                elseif key == keys.five then menuState = "MAIN" end
                drawUI()
            end
        elseif activeTab == "PROFILE" and key == keys.l then
            fs.delete("session.txt"); os.reboot()
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
                -- Дешифруем входящее
                local decryptedText = crypt(msg.text, KEY)
                
                if msg.channel == "GLOBAL" and msg.color == colors.yellow then
                     currentObj = string.gsub(decryptedText, "NEW ORDERS: ", "")
                     local s = peripheral.find("speaker"); if s then s.playNote("pling", 3, 24) end
                end
                addLog(decryptedText, msg.color)
                drawUI()
            end
        end
        if not msg then local timer = os.startTimer(1); os.pullEvent("timer"); drawUI() end
    end
end

drawUI()
parallel.waitForAny(inputLoop, netLoop)