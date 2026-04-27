-- ==========================================
-- === CYRILLIC KEYBOARD DRIVER ===
-- ==========================================
local LOCALE = 'RU'

local function handle_keypress()
  local evt, key
  repeat
    repeat evt, key = os.pullEvent() until evt == "key" or evt == "key_up"
    if evt == "key_up" then return -key end
    os.queueEvent("placeholder")
    local char_queued = false
    parallel.waitForAny(
      function() os.pullEvent("char"); char_queued = true end,
      function() os.pullEvent("placeholder") end
    )
  until not char_queued
  return key
end

local locale_map = {
  [ 93 ] = string.char(0xFA), [ 90 ] = string.char(0xFF), [ 75 ] = string.char(0xEB), [ 65 ] = string.char(0xF4), [ 66 ] = string.char(0xE8), [ 67 ] = string.char(0xF1), [ 68 ] = string.char(0xE2), [ 69 ] = string.char(0xF3), [ 39 ] = string.char(0xFD), [ 71 ] = string.char(0xEF), [ 72 ] = string.char(0xF0), [ 73 ] = string.char(0xF8), [ 74 ] = string.char(0xEE), [ 44 ] = string.char(0xE1), [ 76 ] = string.char(0xE4), [ 77 ] = string.char(0xFC), [ 78 ] = string.char(0xF2), [ 79 ] = string.char(0xF9), [ 80 ] = string.char(0xE7), [ 81 ] = string.char(0xE9), [ 82 ] = string.char(0xEA), [ 83 ] = string.char(0xFB), [ 84 ] = string.char(0xE5), [ 85 ] = string.char(0xE3), [ 86 ] = string.char(0xEC), [ 87 ] = string.char(0xF6), [ 88 ] = string.char(0xF7), [ 89 ] = string.char(0xED), [ 59 ] = string.char(0xE6), [ 91 ] = string.char(0xF5), [ 70 ] = string.char(0xE0), [ 46 ] = string.char(0xFE)
}
local locale_map_shifted = {
  [ 93 ] = string.char(0xDA), [ 90 ] = string.char(0xDF), [ 75 ] = string.char(0xCB), [ 65 ] = string.char(0xD4), [ 66 ] = string.char(0xC8), [ 67 ] = string.char(0xD1), [ 68 ] = string.char(0xC2), [ 69 ] = string.char(0xD3), [ 39 ] = string.char(0xDD), [ 71 ] = string.char(0xCF), [ 72 ] = string.char(0xD0), [ 73 ] = string.char(0xD8), [ 74 ] = string.char(0xCE), [ 44 ] = string.char(0xC1), [ 76 ] = string.char(0xC4), [ 77 ] = string.char(0xDC), [ 78 ] = string.char(0xD2), [ 79 ] = string.char(0xD9), [ 80 ] = string.char(0xC7), [ 81 ] = string.char(0xC9), [ 82 ] = string.char(0xCA), [ 83 ] = string.char(0xDB), [ 84 ] = string.char(0xC5), [ 85 ] = string.char(0xC3), [ 86 ] = string.char(0xCC), [ 87 ] = string.char(0xD6), [ 88 ] = string.char(0xD7), [ 89 ] = string.char(0xCD), [ 59 ] = string.char(0xC6), [ 91 ] = string.char(0xD5), [ 70 ] = string.char(0xC0), [ 46 ] = string.char(0xDE)
}

if string.lower(LOCALE) == 'ua' then
  locale_map[31] = string.char(0xB3); locale_map[39] = string.char(0xBA); locale_map[93] = string.char(0xBF); locale_map[43] = string.char(0xB4)
  locale_map_shifted[31] = string.char(0xB2); locale_map_shifted[39] = string.char(0xAA); locale_map_shifted[93] = string.char(0xAF); locale_map_shifted[43] = string.char(0xA5)
elseif string.lower(LOCALE) == 'by' then
  locale_map[31] = string.char(0xB3); locale_map[24] = string.char(0xA2); locale_map[93] = "'"
  locale_map_shifted[31] = string.char(0xB2); locale_map_shifted[24] = string.char(0xA1); locale_map_shifted[93] = "'"
end

local function cyrrun()
  local shift_pressed = false
  while true do
    local key_pressed = handle_keypress()
    if key_pressed == 340 then shift_pressed = true end
    if key_pressed == -340 then shift_pressed = false end
    if locale_map[key_pressed] then
      if shift_pressed then os.queueEvent('char', locale_map_shifted[key_pressed])
      else os.queueEvent('char', locale_map[key_pressed]) end
    end
  end
end

local redrun = {}
local coroutines = {}
function redrun.init()
    local env = getfenv(rednet.run)
    if env.__redrun_coroutines then coroutines = env.__redrun_coroutines
    else
        env.os = setmetatable({
            pullEventRaw = function()
                local ev = table.pack(coroutine.yield())
                local delete = {}
                for k,v in pairs(coroutines) do
                    if v.terminate or v.filter == nil or v.filter == ev[1] or ev[1] == "terminate" then
                        local ok
                        if v.terminate then ok, v.filter = coroutine.resume(v.coro, "terminate")
                        else ok, v.filter = coroutine.resume(v.coro, table.unpack(ev, 1, ev.n)) end
                        if not ok or coroutine.status(v.coro) ~= "suspended" or v.terminate then delete[#delete+1] = k end
                    end
                end
                for _,v in ipairs(delete) do coroutines[v] = nil end
                return table.unpack(ev, 1, ev.n)
            end
        }, {__index = os, __isredrun = true})
        env.__redrun_coroutines = coroutines
    end
end
function redrun.start(func, name)
    local id = #coroutines+1; coroutines[id] = {coro = coroutine.create(func), name = name}; return id
end
redrun.init()
redrun.start(cyrrun, 'cyrrun')

-- ==========================================
-- === TACTICAL ASCII RADAR V1.1 ===
-- [HQ VISUALIZATION SYSTEM]
-- ==========================================

local modem = peripheral.find("modem")
if not modem then error("No wireless modem found!") end
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
        local id, msg = receiveEncrypted(3) 
        
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