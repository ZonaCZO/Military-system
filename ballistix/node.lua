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
-- === TACTICAL NODE DAEMON V1.0 ===
-- [SILO & RADAR NETWORK CLIENT]
-- ==========================================

local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem found!") end
rednet.open(peripheral.getName(modem))

local silo = peripheral.find("siloController")

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

-- === КОНФИГУРАЦИЯ УЗЛА ===
local PROTOCOL = "default_net"
local KEY = "none"
local NODE_ID = "UNKNOWN"
local NODE_TYPE = "SILO" -- Варианты: SILO, ABM, RADAR
local configFile = ".node_config.txt"

if fs.exists(configFile) and fs.exists(".net_config.txt") then
    local f = fs.open(".net_config.txt", "r")
    PROTOCOL = f.readLine(); KEY = f.readLine(); f.close()
    
    local f2 = fs.open(configFile, "r")
    NODE_ID = f2.readLine()
    NODE_TYPE = f2.readLine()
    f2.close()
else
    term.clear(); term.setCursorPos(1,1)
    term.setTextColor(colors.green)
    print("=== INITIAL NODE SETUP ===")
    term.setTextColor(colors.white)
    write("Network ID: "); PROTOCOL = read()
    write("Network Key: "); KEY = read()
    
    local f = fs.open(".net_config.txt", "w")
    f.writeLine(PROTOCOL); f.writeLine(KEY); f.close()
    
    print("\nSelect Node Type:")
    print("1. Standard Silo (Шахта)")
    print("2. Anti-Ballistic (ПРО)")
    print("3. Early Warning Radar (Радар)")
    write("> ")
    local sel = read()
    if sel == "2" then NODE_TYPE = "ABM"
    elseif sel == "3" then NODE_TYPE = "RADAR"
    else NODE_TYPE = "SILO" end
    
    write("\nEnter Node Designation (e.g. ALPHA-1): ")
    NODE_ID = string.upper(read())
    
    local f2 = fs.open(configFile, "w")
    f2.writeLine(NODE_ID); f2.writeLine(NODE_TYPE); f2.close()
    print("Setup complete. Rebooting...")
    sleep(1); os.reboot()
end

local serverID = rednet.lookup(PROTOCOL, "central_core")

local function sendEncrypted(data)
    if not serverID then serverID = rednet.lookup(PROTOCOL, "central_core") end
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

-- Вспомогательная функция проверки редстоуна (на всех сторонах компа)
local function isRadarTriggered()
    for _, side in ipairs(rs.getSides()) do
        if rs.getInput(side) then return true end
    end
    return false
end

local function getSiloData()
    local data = { status = "OFFLINE", power = 0, maxPower = 0, missile = "None", amount = 0 }
    if silo then
        pcall(function()
            data.power = silo.getPower() or 0
            data.maxPower = silo.getMaxPower() or 0
            data.missile = silo.getMissileType() or "None"
            data.amount = silo.getMissileAmount() or 0
            
            if data.power < data.maxPower * 0.1 then data.status = "LOW POWER"
            elseif data.amount == 0 then data.status = "EMPTY"
            else data.status = "READY" end
        end)
    end
    return data
end

-- === 1. ЦИКЛ ТРАНСЛЯЦИИ СТАТУСА ===
local function telemetryLoop()
    while true do
        term.clear(); term.setCursorPos(1,1)
        term.setTextColor(colors.green); print("=== TACTICAL NODE ACTIVE ===")
        term.setTextColor(colors.white); print("ID: " .. NODE_ID)
        print("TYPE: " .. NODE_TYPE)
        
        local payload = {
            type = "NODE_SYNC",
            nodeId = NODE_ID,
            nodeType = NODE_TYPE,
            telemetry = {}
        }
        
        if NODE_TYPE == "SILO" or NODE_TYPE == "ABM" then
            payload.telemetry = getSiloData()
            print("STATUS: " .. payload.telemetry.status)
            print("PAYLOAD: " .. payload.telemetry.missile .. " (x" .. payload.telemetry.amount .. ")")
        elseif NODE_TYPE == "RADAR" then
            if isRadarTriggered() then
                payload.telemetry.status = "ALERT"
                term.setTextColor(colors.red); print("STATUS: THREAT DETECTED")
            else
                payload.telemetry.status = "SCANNING"
                print("STATUS: CLEAR")
            end
        end
        
        if sendEncrypted(payload) then
            term.setTextColor(colors.green); print("\n[LINK] Connected to HQ")
        else
            term.setTextColor(colors.red); print("\n[LINK] Searching for HQ...")
        end
        
        sleep(5)
    end
end

-- === 2. МГНОВЕННОЕ ОБНАРУЖЕНИЕ (ДЛЯ РАДАРА) ===
local function radarLoop()
    if NODE_TYPE ~= "RADAR" then
        while true do sleep(3600) end -- Усыпляем поток, если это шахта
    end
    
    local wasAlert = isRadarTriggered()
    while true do
        os.pullEvent("redstone") -- Ждем изменения редстоун-сигнала
        local isAlert = isRadarTriggered()
        
        -- Если сигнал загорелся (а до этого его не было)
        if isAlert and not wasAlert then
            sendEncrypted({
                type = "RADAR_ALERT",
                nodeId = NODE_ID,
                text = "INCOMING MISSILE DETECTED BY " .. NODE_ID .. "!"
            })
        end
        wasAlert = isAlert
    end
end

-- === 3. ЦИКЛ ОЖИДАНИЯ ПРИКАЗОВ ===
local function commandLoop()
    while true do
        local id, msg = receiveEncrypted()
        if msg and msg.type == "SILO_FIRE_CMD" and msg.targetNode == NODE_ID then
            if silo and (NODE_TYPE == "SILO" or NODE_TYPE == "ABM") then
                local tx, ty, tz = msg.x, msg.y, msg.z
                local ok, err = pcall(function()
                    silo.launchWithPosition(tx, ty, tz)
                end)
                
                if ok then
                    sendEncrypted({ type = "NODE_REPORT", nodeId = NODE_ID, status = "LAUNCH SUCCESS", color = colors.red })
                else
                    sendEncrypted({ type = "NODE_REPORT", nodeId = NODE_ID, status = "LAUNCH FAILED", color = colors.orange })
                end
            end
        end
    end
end

parallel.waitForAny(telemetryLoop, radarLoop, commandLoop)