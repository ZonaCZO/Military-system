-- ==========================================
-- === CYRILLIC KEYBOARD DRIVER ===
-- ==========================================
local cyrdrv = require("system.cyrillic_driver")
cyrdrv.start("RU")

-- ==========================================
-- === TACTICAL ASCII RADAR V1.1 ===
-- [HQ VISUALIZATION SYSTEM]
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

local PROTOCOL = "default_net"
local KEY = "none"

if fs.exists(".net_config.txt") then
    local f = fs.open(".net_config.txt", "r")
    PROTOCOL = f.readLine(); KEY = f.readLine(); f.close()
end

local serverID = rednet.lookup(PROTOCOL, "central_core")
local myProfile = nil
local myToken = nil
local currentFrontId = ""
local mapData = nil
local isLoading = false

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
        term.setTextColor(colors.green); print("=== RADAR LOGIN ===")
        
        if msgText ~= "" then 
            term.setTextColor(colors.red); print(msgText) 
        end
        
        term.setTextColor(colors.white)
        write("Command ID: "); local id = string.upper(read())
        write("Password: "); local pass = read("*")
        
        serverID = rednet.lookup(PROTOCOL, "central_core")
        
        if serverID then
            sendEncrypted({type="LOGIN", userID=id, userPass=pass, role="commander"})
            local _, msg = receiveEncrypted(3)
            
            if msg and msg.type == "AUTH_OK" then
                myProfile = msg.profile; myToken = msg.token
                return 
            elseif msg and msg.type == "AUTH_FAIL" then
                msgText = "Access Denied: " .. tostring(msg.reason)
            else
                msgText = "Error: Server timeout (No response in 3s)."
            end
        else
            msgText = "Error: HQ Server not found on network."
        end
    end
end

login()

term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
term.setTextColor(colors.yellow)
write("Enter Front ID to scan (e.g. 'tokmak'): ")
currentFrontId = string.lower(read())

local markerIcons = {
    ally = {char="A", color=colors.green},
    enemy = {char="X", color=colors.red},
    objective = {char="O", color=colors.yellow},
    note = {char="?", color=colors.lightGray}
}

local function drawMap()
    local w, h = term.getSize()
    term.setBackgroundColor(colors.black); term.clear()
    
    if isLoading then
        term.setCursorPos(w/2-5, h/2); term.setTextColor(colors.yellow); write("SCANNING...")
        return
    end
    
    if not mapData or not mapData.front then
        term.setCursorPos(2, 2); term.setTextColor(colors.red); write("ERROR: No map data received.")
        term.setCursorPos(2, h); term.setTextColor(colors.white); write("[Q] Exit  [R] Retry")
        return
    end

    local front = mapData.front
    local bounds = front.bounds or {x1=0, z1=0, x2=0, z2=0}
    
    local mapW, mapH = w - 4, h - 4 
    local minX, maxX = math.min(bounds.x1, bounds.x2), math.max(bounds.x1, bounds.x2)
    local minZ, maxZ = math.min(bounds.z1, bounds.z2), math.max(bounds.z1, bounds.z2)
    
    local rangeX = math.max(maxX - minX, 1)
    local rangeZ = math.max(maxZ - minZ, 1)
    
    local function worldToScreen(worldX, worldZ)
        local pctX = math.max(0, math.min(1, (worldX - minX) / rangeX))
        local pctZ = math.max(0, math.min(1, (worldZ - minZ) / rangeZ))
        return 2 + math.floor(pctX * mapW), 3 + math.floor(pctZ * mapH)
    end

    paintutils.drawBox(2, 3, w-2, h-1, colors.green)

    local markers = front.markers or {}
    for _, m in ipairs(markers) do
        local sx, sy = worldToScreen(m.x, m.z)
        local iconData = markerIcons[m.type or "note"] or markerIcons.note
        
        term.setCursorPos(sx, sy)
        term.setBackgroundColor(colors.black)
        term.setTextColor(iconData.color)
        write(iconData.char)
    end

    term.setCursorPos(1, 1); term.setBackgroundColor(colors.gray); term.setTextColor(colors.white)
    write(string.rep(" ", w))
    term.setCursorPos(2, 1); write("RADAR SCAN: " .. front.name:upper() .. " | MARKERS: " .. #markers)
    
    term.setBackgroundColor(colors.black); term.setTextColor(colors.lightGray)
    term.setCursorPos(2, h); write("[R] Refresh Scan   [Q] Exit")
end

local function fetchSnapshot()
    isLoading = true; drawMap()
    sendEncrypted({
        type = "MAP_FRONT_GET",
        userID = myProfile.id,
        token = myToken,
        frontId = currentFrontId
    })
end

local function netLoop()
    fetchSnapshot()
    while true do
        local id, msg = receiveEncrypted(3) -- Таймаут 3 секунды
        
        if msg and msg.type == "MAP_FRONT_DATA" then
            mapData = msg.data
            isLoading = false
            drawMap()
        elseif msg and msg.type == "ERROR" then
            isLoading = false
            term.setCursorPos(1, 2); term.setTextColor(colors.red)
            print("SERVER ERROR: " .. tostring(msg.reason))
            sleep(2)
            drawMap()
        elseif not msg and isLoading then
            isLoading = false
            term.setCursorPos(1, 2); term.setTextColor(colors.red)
            print("CONNECTION TIMEOUT: HQ didn't send map.")
            sleep(2)
            drawMap()
        end
    end
end

local function inputLoop()
    while true do
        local e, key = os.pullEvent("key")
        if key == keys.r then
            fetchSnapshot()
        elseif key == keys.q then
            term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
            return
        end
    end
end

parallel.waitForAny(netLoop, inputLoop)