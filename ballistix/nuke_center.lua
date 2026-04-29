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
-- === STRATEGIC COMMAND CENTER V1.0 ===
-- [GLOBAL MISSILE & RADAR CONTROL]
-- ==========================================

local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem!") end
rednet.open(peripheral.getName(modem))

local function crypt(text, key)
    if not key or key == "" or key == "none" then return text end
    local S = {}; for i = 0, 255 do S[i] = i end
    local j = 0; for i = 0, 255 do
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

local function sendEncrypted(data)
    if not serverID then serverID = rednet.lookup(PROTOCOL, "central_core") end
    if not serverID then return false end
    local payload = textutils.serialize(data)
    rednet.send(serverID, crypt(payload, KEY), PROTOCOL)
    return true
end

local function receiveEncrypted(timeout)
    local id, msg = rednet.receive(PROTOCOL, timeout)
    if type(msg) == "string" then return id, textutils.unserialize(crypt(msg, KEY)) end
    return id, nil
end

local function login()
    local msgText = ""
    while true do
        term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
        term.setTextColor(colors.red); print("=== NUCLEAR COMMAND CENTER ==="); term.setTextColor(colors.white)
        if msgText ~= "" then term.setTextColor(colors.red); print(msgText); term.setTextColor(colors.white) end
        
        write("Commander ID: "); local inputID = string.upper(read())
        write("Password: "); local inputPass = read("*")
        
        if sendEncrypted({type="LOGIN", userID=inputID, userPass=inputPass, role="commander"}) then
            local id, msg = receiveEncrypted(3)
            if msg and msg.type == "AUTH_OK" then
                myProfile = msg.profile; myToken = msg.token; return 
            elseif msg and msg.type == "AUTH_FAIL" then msgText = "ACCESS DENIED: " .. (msg.reason or "Unknown")
            else msgText = "ERROR: No response from HQ." end
        else msgText = "ERROR: Server Offline." end
    end
end

login()

local activeNodes = {}
local nodeIds = {}
local selectedIdx = 1
local alerts = {}
local statusMsg = ""

local function fetchNodes()
    sendEncrypted({type="GET_NODES", userID=myProfile.id, token=myToken})
end

local function drawUI()
    local w, h = term.getSize()
    term.setBackgroundColor(colors.black); term.clear()
    
    -- ШАПКА
    paintutils.drawFilledBox(1, 1, w, 1, colors.red)
    term.setCursorPos(2, 1); term.setTextColor(colors.white); term.setBackgroundColor(colors.red)
    write(" DEFCON COMMAND CENTER | USER: " .. myProfile.id)
    
    -- СПИСОК УЗЛОВ (ЛЕВАЯ ЧАСТЬ)
    term.setBackgroundColor(colors.black)
    local listW = math.floor(w * 0.4)
    for i = 2, h-3 do
        term.setCursorPos(listW, i); term.setTextColor(colors.gray); write("|")
    end
    
    term.setCursorPos(2, 2); term.setTextColor(colors.yellow); write("ACTIVE NODES:")
    if #nodeIds == 0 then
        term.setCursorPos(2, 4); term.setTextColor(colors.red); write("No nodes.")
    else
        for i, nid in ipairs(nodeIds) do
            if i + 2 < h - 3 then
                term.setCursorPos(2, i + 3)
                if i == selectedIdx then term.setBackgroundColor(colors.blue); term.setTextColor(colors.white)
                else term.setBackgroundColor(colors.black); term.setTextColor(colors.lightGray) end
                
                local nType = activeNodes[nid].type
                local prefix = (nType == "SILO") and "[S]" or (nType == "RADAR" and "[R]" or "[P]")
                local line = prefix .. " " .. nid
                write(line .. string.rep(" ", listW - #line - 1))
            end
        end
    end
    
    -- ИНФОРМАЦИЯ ОБ УЗЛЕ (ПРАВАЯ ЧАСТЬ)
    term.setBackgroundColor(colors.black)
    if #nodeIds > 0 and nodeIds[selectedIdx] then
        local nid = nodeIds[selectedIdx]
        local node = activeNodes[nid]
        local tel = node.telemetry
        local x = listW + 2
        
        term.setCursorPos(x, 2); term.setTextColor(colors.cyan); write("NODE: " .. nid)
        term.setCursorPos(x, 3); term.setTextColor(colors.lightGray); write("TYPE: " .. node.type)
        
        term.setCursorPos(x, 5); term.setTextColor(colors.yellow); write("STATUS: ")
        if tel.status == "READY" or tel.status == "SCANNING" then term.setTextColor(colors.green)
        elseif tel.status == "ALERT" then term.setTextColor(colors.red)
        else term.setTextColor(colors.orange) end
        write(tel.status or "UNKNOWN")
        
        if node.type == "SILO" or node.type == "ABM" then
            term.setCursorPos(x, 7); term.setTextColor(colors.yellow); write("POWER: ")
            term.setTextColor(colors.white); write((tel.power or 0) .. "/" .. (tel.maxPower or 0))
            
            term.setCursorPos(x, 8); term.setTextColor(colors.yellow); write("PAYLOAD: ")
            term.setTextColor(colors.white); write(tel.missile .. " (x" .. (tel.amount or 0) .. ")")
            
            term.setCursorPos(x, 10); term.setTextColor(colors.red); write("[L] REMOTE LAUNCH")
        end
    end
    
    -- ПАНЕЛЬ ТРЕВОГ (НИЗ)
    paintutils.drawFilledBox(1, h-2, w, h, colors.gray)
    term.setCursorPos(2, h-2); term.setTextColor(colors.yellow); term.setBackgroundColor(colors.gray); write("ALERTS:")
    term.setCursorPos(2, h-1); term.setTextColor(colors.white)
    if statusMsg ~= "" then
        term.setTextColor(colors.orange); write(statusMsg)
    elseif #alerts > 0 then
        term.setTextColor(colors.red); write(alerts[#alerts])
    else
        term.setTextColor(colors.lightGray); write("All systems nominal.")
    end
    
    term.setCursorPos(w - 20, h); term.setTextColor(colors.black); write("[Up/Dn]  [Q] Exit")
end

local function netLoop()
    while true do
        fetchNodes()
        local id, msg = receiveEncrypted(2)
        if msg then
            if msg.type == "NODE_LIST" then
                activeNodes = msg.data
                nodeIds = {}
                for k, _ in pairs(activeNodes) do table.insert(nodeIds, k) end
                table.sort(nodeIds)
                if selectedIdx > #nodeIds and #nodeIds > 0 then selectedIdx = #nodeIds end
                drawUI()
                
            elseif msg.type == "CHAT_LINE" and msg.alert then
                table.insert(alerts, os.date("%H:%M:%S ") .. msg.text)
                if #alerts > 3 then table.remove(alerts, 1) end
                local s = peripheral.find("speaker"); if s then s.playNote("bit", 3, 10) end
                drawUI()
            end
        else
            drawUI() -- Redraw to animate ping
        end
    end
end

local function inputLoop()
    while true do
        local event, key = os.pullEvent("key")
        
        if key == keys.up and selectedIdx > 1 then
            selectedIdx = selectedIdx - 1; statusMsg = ""; drawUI()
        elseif key == keys.down and selectedIdx < #nodeIds then
            selectedIdx = selectedIdx + 1; statusMsg = ""; drawUI()
            
        elseif key == keys.l and #nodeIds > 0 then
            local nid = nodeIds[selectedIdx]
            local node = activeNodes[nid]
            if node and (node.type == "SILO" or node.type == "ABM") then
                term.setCursorPos(2, 14); term.setBackgroundColor(colors.black); term.setTextColor(colors.yellow)
                write("Target X: "); local tx = tonumber(read())
                write(" Target Y: "); local ty = tonumber(read())
                write(" Target Z: "); local tz = tonumber(read())
                
                if tx and ty and tz then
                    term.setTextColor(colors.red)
                    write("CONFIRM LAUNCH (YES): ")
                    if read() == "YES" then
                        sendEncrypted({
                            type = "SILO_FIRE_CMD",
                            userID = myProfile.id,
                            token = myToken,
                            targetNode = nid,
                            x = tx, y = ty, z = tz
                        })
                        statusMsg = "LAUNCH COMMAND TRANSMITTED TO " .. nid
                    else statusMsg = "Aborted." end
                else statusMsg = "Invalid coordinates." end
                drawUI()
            end
            
        elseif key == keys.q then
            term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1); return
        end
    end
end

parallel.waitForAny(netLoop, inputLoop)