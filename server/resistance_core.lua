-- === CENTRAL DB V14.1 (Modular Core + Admin) ===
-- [ENCRYPTION: RC4 STREAM CIPHER]

local auth = require("server.modules.auth")
local fronts = require("server.modules.fronts")
local storage = require("server.modules.storage") -- Добавили для сохранения отрядов

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
    while true do
        local id, msg = receiveEncrypted()
        if type(msg) == "table" then
            
            -- 1. АВТОРИЗАЦИЯ
            if msg.type == "LOGIN" then
                local success, profile, err = auth.login(msg.userID, msg.userPass, msg.role)
                if success then
                    local token = generateToken()
                    activeSessions[msg.userID] = token
                    sendEncrypted(id, {type="AUTH_OK", profile=profile, token=token})
                else
                    sendEncrypted(id, {type="AUTH_FAIL", reason=err})
                end
            
            -- 2. ФРОНТЫ (Чтение)
            elseif msg.type == "FRONT_LIST" then
                sendEncrypted(id, {type="FRONT_LIST", data=fronts.list()})
                
            elseif msg.type == "FRONT_GET" then
                sendEncrypted(id, {type="FRONT_GET", data=fronts.get(msg.id)})

            -- 3. ФРОНТЫ (Запись)
            elseif msg.type == "FRONT_SAVE" then
                local profile = auth.get(msg.userID)
                if profile and activeSessions[msg.userID] == msg.token then
                    if auth.hasAccess(profile, "commander") then
                        fronts.save(msg.front)
                        sendEncrypted(id, {type="SAVE_OK"})
                    else
                        sendEncrypted(id, {type="ERROR", reason="Insufficient Role"})
                    end
                else
                    sendEncrypted(id, {type="ERROR", reason="Invalid Session Token"})
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