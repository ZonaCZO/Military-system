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
-- === CENTRAL DB V14.1 (Modular Core + Admin) ===
-- [ENCRYPTION: RC4 STREAM CIPHER]
-- ==========================================

local auth = require("server.modules.auth")
local fronts = require("server.modules.fronts")
local archive = require("server.modules.archive")
local storage = require("server.modules.storage") 

local modem = peripheral.find("modem")
if not modem then error("No modem found! Please attach a wireless modem.") end
rednet.open(peripheral.getName(modem))

-- === RC4 CRYPTO ===
local function crypt(text, key)
    if not key or key == "" or key == "none" then return text end
    local S = {}
    for i = 0, 255 do S[i] = i end
    local j = 0
    for i = 0, 255 do
        j = (j + S[i] + string.byte(key, (i % #key) + 1)) % 256
        S[i], S[j] = S[j], S[i]
    end
    local i, j = 0, 0
    local output = {}
    for k = 1, #text do
        i = (i + 1) % 256
        j = (j + S[i]) % 256
        S[i], S[j] = S[j], S[i]
        local K = S[(S[i] + S[j]) % 256]
        table.insert(output, string.char(bit.bxor(string.byte(text, k), K)))
    end
    return table.concat(output)
end

-- === NETWORK CONFIG ===
local PROTOCOL = "default_net"
local KEY = "none"
local netFile = ".net_config.txt"

if fs.exists(netFile) then
    local f = fs.open(netFile, "r")
    PROTOCOL = f.readLine()
    KEY = f.readLine()
    f.close()
else
    term.clear()
    print("=== SERVER SETUP ===")
    write("Network ID: ") PROTOCOL = read()
    write("Encryption Key: ") KEY = read()
    local f = fs.open(netFile, "w")
    f.writeLine(PROTOCOL)
    f.writeLine(KEY)
    f.close()
end

if rednet.lookup(PROTOCOL, "central_core") then
    error("Server duplicate detected on protocol: " .. PROTOCOL)
end

rednet.host(PROTOCOL, "central_core")

-- === SESSION & SQUADS MANAGEMENT ===
local activeSessions = {} -- userID -> token
local SQUADS_FILE = "data/squads.lua"
local squads = storage.load(SQUADS_FILE, {ALPHA=true, HQ=true})

local function generateToken()
    return tostring(math.random(100000, 999999))
end

local function saveSquads()
    storage.save(SQUADS_FILE, squads)
end

-- === NET WRAPPERS ===
local function sendEncrypted(id, data)
    local payload = textutils.serialize(data)
    local encrypted = crypt(payload, KEY)
    rednet.send(id, encrypted, PROTOCOL)
end

local function receiveEncrypted()
    local id, msg = rednet.receive(PROTOCOL)
    if type(msg) == "string" then
        local decrypted = crypt(msg, KEY)
        local data = textutils.unserialize(decrypted)
        return id, data
    end
    return id, nil
end

-- === MAIN SERVER LOOP ===
local function netLoop()
    print("[OK] Listening for secure packets...")
    
    while true do
        local id, msg = receiveEncrypted()
        if type(msg) == "table" then
            
            -- === 1. АВТОРИЗАЦИЯ ===
            if msg.type == "LOGIN" then
                local success, profile, err = auth.login(msg.userID, msg.userPass, msg.role)
                if success then
                    local token = generateToken()
                    activeSessions[msg.userID] = token
                    sendEncrypted(id, {type="AUTH_OK", profile=profile, token=token})
                    print("[AUTH] User " .. msg.userID .. " logged in.")
                else
                    sendEncrypted(id, {type="AUTH_FAIL", reason=err})
                end

            -- === 2. ФРОНТЫ ===
            elseif msg.type == "FRONT_LIST" then
                sendEncrypted(id, {type="FRONT_LIST", data=fronts.list()})
            elseif msg.type == "FRONT_GET" then
                sendEncrypted(id, {type="FRONT_GET", data=fronts.get(msg.id)})

            -- === 3. АРХИВ (ПЛАНЫ ОПЕРАЦИЙ) ===
            elseif msg.type == "PLAN_LIST" then
                local plans = archive.listPlans()
                sendEncrypted(id, {type="PLAN_LIST", data=plans})
            elseif msg.type == "PLAN_GET" then
                local plan = archive.getPlan(msg.id)
                if plan then
                    sendEncrypted(id, {type="PLAN_GET", data=plan})
                else
                    sendEncrypted(id, {type="ERROR", reason="Plan not found"})
                end
            elseif msg.type == "PLAN_SAVE" then
                local profile = auth.get(msg.userID)
                if profile and activeSessions[msg.userID] == msg.token and auth.hasAccess(profile, "commander") then
                    local ok, err = archive.savePlan(msg.plan)
                    if ok then
                        sendEncrypted(id, {type="SAVE_OK"})
                        print("[ARCHIVE] Plan '" .. msg.plan.id .. "' updated.")
                    else
                        sendEncrypted(id, {type="ERROR", reason=err})
                    end
                end

            -- === 4. ЧАТЫ И ЛОГИРОВАНИЕ ===
            elseif msg.type == "CMD_CHAT" then
                local profile = auth.get(msg.userID)
                if profile and activeSessions[msg.userID] == msg.token and auth.hasAccess(profile, "commander") then
                    archive.appendLog("CMD", {from = msg.userID, text = msg.text})
                    local response = {type = "CHAT_LINE", channel = "CMD", text = msg.text, from = msg.userID, color = (profile.role == "general") and colors.red or colors.cyan}
                    rednet.broadcast(crypt(textutils.serialize(response), KEY), PROTOCOL)
                    print("[CHAT] CMD: " .. msg.userID .. ": " .. msg.text)
                end

            elseif msg.type == "SQUAD_CMD" then
                local profile = auth.get(msg.userID)
                if profile and activeSessions[msg.userID] == msg.token and auth.hasAccess(profile, "commander") then
                    archive.appendLog("SQD_" .. tostring(msg.squad), {from = msg.userID, text = msg.text})
                    local response = {type = "CHAT_LINE", channel = "SQUAD", targetSquad = msg.squad, text = msg.text, from = msg.userID, color = colors.green}
                    rednet.broadcast(crypt(textutils.serialize(response), KEY), PROTOCOL)
                    print("[CHAT] SQUAD [" .. tostring(msg.squad) .. "]: " .. msg.userID .. ": " .. msg.text)
                end
            
            elseif msg.type == "SQUAD_REPORT" then
                local profile = auth.get(msg.userID)
                if profile and activeSessions[msg.userID] == msg.token then
                    if msg.squad == profile.squad then
                        archive.appendLog("SQD_" .. tostring(msg.squad), {from = msg.userID, text = msg.text})
                        local response = {type = "CHAT_LINE", channel = "SQUAD", targetSquad = msg.squad, text = msg.text, from = msg.userID, color = colors.lightGray}
                        rednet.broadcast(crypt(textutils.serialize(response), KEY), PROTOCOL)
                        print("[CHAT] REPORT [" .. tostring(msg.squad) .. "]: " .. msg.userID .. ": " .. msg.text)
                    end
                end

            -- === 5. ЧТЕНИЕ ЛОГОВ (INTEL) ===
            elseif msg.type == "GET_LOGS" then
                local profile = auth.get(msg.userID)
                if profile and activeSessions[msg.userID] == msg.token and auth.hasAccess(profile, "commander") then
                    local logData = archive.getLog(msg.channel)
                    sendEncrypted(id, {type = "LOG_DATA", channel = msg.channel, data = logData})
                    print("[ARCHIVE] Sent log '" .. msg.channel .. "' to ID:" .. id)
                end
                
            -- === 6. СМЕНА ЗАДАЧИ (SET_OBJ) ===
            elseif msg.type == "SET_OBJ" then
                local profile = auth.get(msg.userID)
                if profile and activeSessions[msg.userID] == msg.token and auth.hasAccess(profile, "commander") then
                    local response = {type = "CHAT_LINE", channel = "GLOBAL", text = "NEW ORDERS: " .. msg.text, from = "HQ", color = colors.yellow}
                    rednet.broadcast(crypt(textutils.serialize(response), KEY), PROTOCOL)
                    print("[OBJ] Updated by " .. msg.userID)
                end

            -- === 7. КАРТА И РАДАР ===
            elseif msg.type == "MAP_FRONT_GET" then
                local profile = auth.get(msg.userID)
                if profile and activeSessions[msg.userID] == msg.token then
                    local map = require("server.modules.map") 
                    local snapshot, err = map.getFrontSnapshot(msg.frontId)
                    if snapshot then
                        sendEncrypted(id, {type="MAP_FRONT_DATA", data=snapshot})
                    else
                        sendEncrypted(id, {type="ERROR", reason=err or "Snapshot failed"})
                    end
                end

            -- === 8. УСТАНОВКА МАРКЕРА ===
            elseif msg.type == "MAP_ADD_MARKER" then
                local profile = auth.get(msg.userID)
                if profile and activeSessions[msg.userID] == msg.token and auth.hasAccess(profile, "commander") then
                    local ok, err = fronts.addMarker(msg.frontId, {
                        type = msg.markerType,
                        label = msg.label,
                        x = tonumber(msg.x) or 0,
                        z = tonumber(msg.z) or 0
                    })
                    if ok then
                        sendEncrypted(id, {type="SAVE_OK"})
                        print("[MAP] Marker added to " .. tostring(msg.frontId) .. " by " .. msg.userID)
                    else
                        sendEncrypted(id, {type="ERROR", reason=err or "Failed to add marker"})
                    end
                end
            end
        end
    end
end

-- === ADMIN CLI LOOP ===
local function adminLoop()
    while true do
        term.clear()
        term.setCursorPos(1,1)
        term.setTextColor(colors.green)
        print("/// SERVER V14.1 ["..PROTOCOL.."] ///")
        print("KEY: " .. (KEY=="none" and "OFF" or "RC4 ACTIVE"))
        print("----------------------------------")
        print("mksq <name>       - Register Squad")
        print("rmsq <name>       - Delete Squad")
        print("add               - Add User")
        print("del <ID>          - Delete User")
        print("list              - Show Database")
        
        term.setCursorPos(1, 10)
        term.setTextColor(colors.white)
        write("ADM> ")
        local input = read()
        local args = {}
        for w in input:gmatch("%S+") do table.insert(args, w) end
        local cmd = args[1]
        
        if cmd == "mksq" and args[2] then
            squads[string.upper(args[2])] = true
            saveSquads()
            print("Squad Registered.")
            sleep(1)
        elseif cmd == "rmsq" and args[2] then
            squads[string.upper(args[2])] = nil
            saveSquads()
            print("Squad Removed.")
            sleep(1)
        elseif cmd == "add" then
            write("ID: ") local id = string.upper(read())
            write("Pass: ") local pass = read()
            print("--- SQUADS ---")
            for sq, _ in pairs(squads) do write(sq.." ") end
            print("\n--------------")
            write("Squad: ") local sq = string.upper(read())
            
            if not squads[sq] then
                print("Squad not found! Use 'mksq' first.")
                sleep(2)
            else
                write("Rank: ") local rk = read()
                write("Name: ") local nm = read()
                write("Nation: ") local nat = read()
                print("Role: 1.SOLDIER 2.COMMANDER 3.GENERAL")
                write("> ")
                local rInput = read()
                local rl = "soldier"
                if rInput == "2" then rl = "commander"
                elseif rInput == "3" then rl = "general" end
                
                -- Сохраняем через новый модуль auth
                auth.save({
                    id = id,
                    password = pass,
                    squad = sq,
                    rank = rk,
                    name = nm,
                    nation = nat,
                    role = rl
                })
                print("User Saved as " .. string.upper(rl))
                sleep(1)
            end
        elseif cmd == "del" and args[2] then
            local targetId = string.upper(args[2])
            local path = "data/users/" .. targetId .. ".lua"
            if fs.exists(path) then
                fs.delete(path)
                print("Deleted.")
            else
                print("User not found.")
            end
            sleep(1)
        elseif cmd == "list" then
            print("\nID | SQD | ROLE | NAME")
            local userIds = auth.list()
            for _, uid in ipairs(userIds) do
                local u = auth.get(uid)
                if u then
                    local r = string.upper(u.role or "SOL"):sub(1,3)
                    local sq = u.squad or "NONE"
                    print(u.id .. " | " .. sq .. " | " .. r .. " | " .. (u.name or "Unknown"))
                end
            end
            print("Press Enter...")
            read()
        end
    end
end

-- Запускаем оба цикла параллельно
parallel.waitForAny(netLoop, adminLoop)