-- === CENTRAL DB V12.1 (RC4+GEN) ===
-- [ENCRYPTION: RC4 STREAM CIPHER]

local modem = peripheral.find("modem")
if not modem then error("No modem found") end
rednet.open(peripheral.getName(modem))

-- === RC4 ===
local function crypt(text, key)
    if not key or key == "" or key == "none" then return text end
    
    local S = {}
    for i = 0, 255 do S[i] = i end
    
    local j = 0
    for i = 0, 255 do
        j = (j + S[i] + string.byte(key, (i % #key) + 1)) % 256
        S[i], S[j] = S[j], S[i]
    end
    
    local i = 0
    j = 0
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

-- === CONFIG ===
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
    print("SETUP")
    write("Network ID: ") PROTOCOL = read()
    write("Key: ") KEY = read()
    
    local f = fs.open(netFile, "w")
    f.writeLine(PROTOCOL)
    f.writeLine(KEY)
    f.close()
end

if rednet.lookup(PROTOCOL, "central_core") then
    error("Server duplicate detected")
end

rednet.host(PROTOCOL, "central_core")

-- === DB ===
local users = {}
local dbFile = "users.db"

local function loadDB()
    if fs.exists(dbFile) then
        local f = fs.open(dbFile, "r")
        users = textutils.unserialize(f.readAll())
        f.close()
    end
end

local function saveFile(path, data)
    local f = fs.open(path, "w")
    f.write(textutils.serialize(data))
    f.close()
end

local function loadFile(path)
    if not fs.exists(path) then return nil end
    local f = fs.open(path, "r")
    local d = textutils.unserialize(f.readAll())
    f.close()
    return d
end

loadDB()

-- === HELPERS ===
local function hasRole(u, role)
    local p = {SOLDIER=1, COMMANDER=2, GENERAL=3}
    return p[u.role] >= p[role]
end

-- === FRONT SYSTEM ===
local function getFront(id)
    return loadFile("data/map/fronts/"..id..".db")
end

local function saveFront(front)
    saveFile("data/map/fronts/"..front.id..".db", front)
end

local function listFronts()
    local out = {}
    if not fs.exists("data/map/fronts") then return out end
    
    for _,f in ipairs(fs.list("data/map/fronts")) do
        local d = loadFile("data/map/fronts/"..f)
        if d then table.insert(out, d) end
    end
    return out
end

-- === ARCHIVE ===
local function getPlan(id)
    return loadFile("data/archive/plans/"..id..".db")
end

local function savePlan(plan)
    saveFile("data/archive/plans/"..plan.id..".db", plan)
end

local function listPlans()
    local out = {}
    if not fs.exists("data/archive/plans") then return out end
    
    for _,f in ipairs(fs.list("data/archive/plans")) do
        local d = loadFile("data/archive/plans/"..f)
        if d then table.insert(out, d) end
    end
    return out
end

-- === NETWORK ===
local function netLoop()
    while true do
        local id, msg = rednet.receive(PROTOCOL)
        
        if type(msg) ~= "table" then goto continue end
        
        -- LOGIN
        if msg.type == "LOGIN" then
            local u = users[msg.userID]
            if u and u.pass == msg.userPass then
                rednet.send(id, {type="AUTH_OK", profile=u}, PROTOCOL)
            else
                rednet.send(id, {type="AUTH_FAIL"}, PROTOCOL)
            end
        end
        
        -- === FRONTS ===
        if msg.type == "FRONT_LIST" then
            rednet.send(id, {type="FRONT_LIST", data=listFronts()}, PROTOCOL)
        end
        
        if msg.type == "FRONT_GET" then
            rednet.send(id, {type="FRONT_GET", data=getFront(msg.id)}, PROTOCOL)
        end
        
        if msg.type == "FRONT_SAVE" then
            local u = users[msg.userID]
            if u and hasRole(u, "COMMANDER") then
                saveFront(msg.front)
                rednet.send(id, {ok=true}, PROTOCOL)
            end
        end
        
        -- === ARCHIVE ===
        if msg.type == "PLAN_LIST" then
            rednet.send(id, {type="PLAN_LIST", data=listPlans()}, PROTOCOL)
        end
        
        if msg.type == "PLAN_GET" then
            rednet.send(id, {type="PLAN_GET", data=getPlan(msg.id)}, PROTOCOL)
        end
        
        if msg.type == "PLAN_SAVE" then
            local u = users[msg.userID]
            if u and hasRole(u, "COMMANDER") then
                savePlan(msg.plan)
                rednet.send(id, {ok=true}, PROTOCOL)
            end
        end
        
        ::continue::
    end
end

parallel.waitForAny(netLoop)