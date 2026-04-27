-- === CENTRAL DB V14 (Modular Core) ===
-- [ENCRYPTION: RC4 STREAM CIPHER]

-- 1. Подключаем твои новые модули
local auth = require("server.modules.auth")
local fronts = require("server.modules.fronts")
-- local archive = require("server.modules.archive") -- Раскоментируешь, когда возьмемся за планы
-- local map = require("server.modules.map")

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
print("[OK] Core Server Hosted (" .. PROTOCOL .. ")")

-- === SESSION MANAGEMENT ===
local activeSessions = {} -- userID -> token

local function generateToken()
    return tostring(math.random(100000, 999999))
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
            
            -- =====================================
            -- 1. АВТОРИЗАЦИЯ
            -- =====================================
            if msg.type == "LOGIN" then
                -- Используем твой новый auth.lua
                local success, profile, err = auth.login(msg.userID, msg.userPass, msg.role)
                
                if success then
                    local token = generateToken()
                    activeSessions[msg.userID] = token
                    sendEncrypted(id, {type="AUTH_OK", profile=profile, token=token})
                    print("[AUTH] User " .. msg.userID .. " logged in.")
                else
                    sendEncrypted(id, {type="AUTH_FAIL", reason=err})
                    print("[AUTH] Denied " .. tostring(msg.userID) .. ": " .. tostring(err))
                end
            
            -- =====================================
            -- 2. ФРОНТЫ (Чтение)
            -- =====================================
            elseif msg.type == "FRONT_LIST" then
                -- Чтение доступно всем, кто знает ключ сети (RC4)
                local frontData = fronts.list()
                sendEncrypted(id, {type="FRONT_LIST", data=frontData})
                print("[NET] Sent FRONT_LIST to PC ID:" .. id)
                
            elseif msg.type == "FRONT_GET" then
                local frontDetails = fronts.get(msg.id)
                sendEncrypted(id, {type="FRONT_GET", data=frontDetails})

            -- =====================================
            -- 3. ФРОНТЫ (Запись/Изменение)
            -- =====================================
            elseif msg.type == "FRONT_SAVE" then
                -- Для изменений обязательно проверяем токен сессии и права Командира
                local profile = auth.get(msg.userID)
                
                if profile and activeSessions[msg.userID] == msg.token then
                    if auth.hasAccess(profile, "commander") then
                        fronts.save(msg.front)
                        sendEncrypted(id, {type="SAVE_OK"})
                        print("[DB] Front updated by " .. msg.userID)
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

-- Запуск
netLoop()