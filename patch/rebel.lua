-- === PDA V10.1 (SOLDIER FIX) ===
-- [Role sending fix]

local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem!") end
rednet.open(peripheral.getName(modem))

local PROTOCOL = "nipaya_net"
if fs.exists("net_config.txt") then
    local f = fs.open("net_config.txt", "r")
    PROTOCOL = f.readAll()
    f.close()
end

local serverID = rednet.lookup(PROTOCOL, "central_core")
local myProfile = nil
local currentObj = "Connecting..."

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
                -- !FIX: Добавлено role="SOLDIER"
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
            -- !FIX: Добавлено role="SOLDIER" чтобы сервер не падал
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

-- === UI И ЛОГИКА ===
local activeTab = "TACTICAL"
local logHistory = {}

local function addLog(text, color)
    table.insert(logHistory, {text=text, color=color or colors.green})
    if #logHistory > 8 then table.remove(logHistory, 1) end
end

local function drawUI()
    local w, h = term.getSize()
    
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
    term.setBackgroundColor(colors.gray)
    write(string.rep(" ", w - 18))
    
    if activeTab == "TACTICAL" then
        paintutils.drawFilledBox(1, 2, w, h, colors.black)
        term.setCursorPos(1, 2)
        term.setTextColor(colors.yellow)
        print("OBJ: " .. string.sub(currentObj, 1, w-5))
        
        local y = 4
        for _, item in ipairs(logHistory) do
            term.setCursorPos(1, y)
            term.setTextColor(item.color)
            print(item.text)
            y = y + 1
        end
        
        local btnY = h
        paintutils.drawFilledBox(1, btnY, w/3, btnY, colors.red)
        term.setCursorPos(2, btnY) 
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.red)
        write("1.CONTACT")
        
        paintutils.drawFilledBox(w/3+1, btnY, w/3*2, btnY, colors.green)
        term.setCursorPos(w/3+2, btnY)
        term.setBackgroundColor(colors.green)
        write("2.CLEAR")
        
        paintutils.drawFilledBox(w/3*2+1, btnY, w, btnY, colors.magenta)
        term.setCursorPos(w/3*2+2, btnY)
        term.setBackgroundColor(colors.magenta)
        write("3.MEDIC")
        
    else
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
        paintutils.drawBox(px, 3, px+6, 7, colors.black)
        term.setCursorPos(px+1, 4) write(" O  ")
        term.setCursorPos(px+1, 5) write("/|\\ ")
        term.setCursorPos(px+1, 6) write("/ \\ ")
        
        term.setCursorPos(2, h-1)
        term.setTextColor(colors.red)
        print("[L] LOGOUT")
    end
end

local function inputLoop()
    while true do
        local event, key = os.pullEvent("key")
        
        if key == keys.tab then
            if activeTab == "TACTICAL" then activeTab = "PROFILE" else activeTab = "TACTICAL" end
            drawUI()
        elseif activeTab == "TACTICAL" then
            if key == keys.one then
                rednet.send(serverID, {type="REPORT", userID=myProfile.id, text="CONTACT!"}, PROTOCOL)
                addLog("SENT: CONTACT", colors.white)
            elseif key == keys.two then
                rednet.send(serverID, {type="REPORT", userID=myProfile.id, text="AREA CLEAR"}, PROTOCOL)
                addLog("SENT: CLEAR", colors.white)
            elseif key == keys.three then
                rednet.send(serverID, {type="REPORT", userID=myProfile.id, text="MEDIC!"}, PROTOCOL)
                addLog("SENT: MEDIC", colors.white)
            end
            drawUI()
        elseif activeTab == "PROFILE" and key == keys.l then
            fs.delete("session.txt")
            os.reboot()
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
    end
end

drawUI()
parallel.waitForAny(inputLoop, netLoop)