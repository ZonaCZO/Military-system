-- === FIELD TERMINAL V7.0 ===
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

local serverID = rednet.lookup(PROTOCOL, "central_core")
local profile = {}
local mySquad = ""

local function setupProfile()
    if fs.exists("profile.txt") then
        local file = fs.open("profile.txt", "r")
        profile = textutils.unserialize(file.readAll())
        file.close()
    else
        term.clear()
        term.setCursorPos(1,1)
        print("--- IDENTITY SETUP ---")
        write("Rank (e.g. Sgt): ") profile.rank = read()
        write("Name (e.g. Doe): ") profile.name = read()
        write("Nation (e.g. NPY): ") profile.nation = read()
        write("Callsign (2 char): ") profile.callsign = string.upper(string.sub(read(), 1, 2))
        local file = fs.open("profile.txt", "w")
        file.write(textutils.serialize(profile))
        file.close()
    end
end

local function login()
    setupProfile()
    if not serverID then 
        serverID = rednet.lookup(PROTOCOL, "central_core")
        if not serverID then serverID = os.getComputerID() end 
    end

    local msgError = ""
    while true do
        term.setBackgroundColor(colors.black)
        term.clear()
        term.setCursorPos(1,1)
        print("--- SQUAD LOGIN ["..PROTOCOL.."] ---")
        print("User: " .. profile.rank .. " " .. profile.callsign)
        if msgError ~= "" then
            term.setTextColor(colors.red)
            print(msgError)
            term.setTextColor(colors.white)
        end
        
        write("Squad (ALPHA): ")
        local sName = string.upper(read())
        write("Password: ")
        local sPass = read("*")
        
        print("Connecting...")
        rednet.send(serverID, {type="LOGIN", squad=sName, pass=sPass, role="SOLDIER"}, PROTOCOL)
        local id, response = rednet.receive(PROTOCOL, 3)
        if response and response.type == "AUTH" and response.res then
            mySquad = sName
            return response.obj
        else
            msgError = "Access Denied"
        end
    end
end

local currentObj = login()
local logHistory = {} 

local function addLog(text, color)
    table.insert(logHistory, {text = text, color = color or colors.green})
    if #logHistory > 6 then table.remove(logHistory, 1) end
end

local function drawUI()
    term.setBackgroundColor(colors.black)
    term.clear()
    local w, h = term.getSize()
    
    term.setCursorPos(1,1)
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.clearLine()
    print(profile.rank .. " " .. profile.name .. " \"" .. profile.callsign .. "\"")
    
    term.setCursorPos(1,2)
    term.clearLine()
    local time = textutils.formatTime(os.time(), true)
    print(profile.nation .. " | SQD: " .. mySquad .. " | " .. time)
    
    term.setBackgroundColor(colors.black)
    term.setCursorPos(1, 4)
    term.setTextColor(colors.yellow)
    print("OBJ: " .. currentObj)
    
    term.setCursorPos(1, 6)
    term.setTextColor(colors.gray)
    print("--- SQUAD FEED ---")
    local y = 7
    for _, item in ipairs(logHistory) do
        term.setCursorPos(1, y)
        term.setTextColor(item.color)
        print(item.text)
        y = y + 1
    end

    term.setCursorPos(1, h-3)
    term.setTextColor(colors.gray)
    print("----------------------------")
    term.setTextColor(colors.white)
    print("1. CONTACT  2. CLEAR  3. MEDIC")
    print("4. SUPPLY   M. MSG    R. UPDATE")
end

local function sendPacket(text)
    rednet.send(serverID, {type = "REPORT", squad = mySquad, callsign = profile.callsign, rank = profile.rank, text = text}, PROTOCOL)
    addLog("SENT: " .. text, colors.gray)
    drawUI()
end

local function promptInput(promptText)
    local w, h = term.getSize()
    term.setCursorPos(1, h)
    term.clearLine()
    term.setTextColor(colors.yellow)
    write(promptText)
    term.setTextColor(colors.white)
    return read()
end

local function mainLoop()
    while true do
        drawUI()
        local event, key = os.pullEvent("char")
        if key == "1" then sendPacket("CONTACT: " .. promptInput("Loc: "))
        elseif key == "2" then sendPacket("ZONE SECURED")
        elseif key == "3" then sendPacket("MEDIC NEEDED")
        elseif key == "4" then sendPacket("SUPPLY: " .. promptInput("Item: "))
        elseif key == "m" then 
            local msg = promptInput("Msg: ")
            if msg ~= "" then sendPacket("MSG: " .. msg) end
        end
    end
end

local function netLoop()
    while true do
        local id, msg = rednet.receive(PROTOCOL)
        if msg and msg.type == "CHAT_LINE" then
            if msg.channel == "GLOBAL" then
                 if msg.color == colors.yellow then
                     currentObj = string.gsub(msg.text, "NEW ORDERS: ", "")
                     local s = peripheral.find("speaker")
                     if s then s.playNote("pling", 3, 24) end
                 end
                 addLog(msg.text, msg.color)
                 drawUI()
            elseif msg.channel == "SQUAD" and msg.targetSquad == mySquad then
                 addLog(msg.text, msg.color)
                 drawUI()
            end
        end
    end
end

parallel.waitForAny(mainLoop, netLoop)