-- === CENTRAL DB V12.0 (RC4) ===
-- [ENCRYPTION: RC4 STREAM CIPHER]

local modem = peripheral.find("modem")
if not modem then error("No modem found") end
rednet.open(peripheral.getName(modem))

-- === КРИПТОГРАФИЯ (RC4) ===
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

-- === НАСТРОЙКА ===
local PROTOCOL = "default_net"
local KEY = "none"
local netFile = ".net_config.txt"

if fs.exists(netFile) then
    local f = fs.open(netFile, "r")
    PROTOCOL = f.readLine()
    KEY = f.readLine()
    f.close()
    if not KEY then KEY = "none" end
else
    term.clear()
    term.setCursorPos(1,1)
    print("--- SECURE SERVER SETUP ---")
    
    write("Network ID (e.g. SQUAD_1): ")
    local inp = read()
    if inp ~= "" then PROTOCOL = inp end
    
    write("Encryption Key (any text): ")
    local kInp = read()
    if kInp ~= "" then KEY = kInp end
    
    local f = fs.open(netFile, "w")
    f.writeLine(PROTOCOL)
    f.writeLine(KEY)
    f.close()
    print("Config Saved.")
    sleep(1)
end

-- Защита от дубликатов
if rednet.lookup(PROTOCOL, "central_core") then
    error("CRITICAL: Server duplicate detected in " .. PROTOCOL)
end

rednet.host(PROTOCOL, "central_core")

-- === БАЗА ДАННЫХ ===
local users = {} 
local squads = {}
local dbFile = "users.db"
local sqFile = "squads.db"
local commandersOnline = {} 

local function loadDB()
    if fs.exists(dbFile) then
        local f = fs.open(dbFile, "r")
        users = textutils.unserialize(f.readAll())
        f.close()
    end
    if fs.exists(sqFile) then
        local f = fs.open(sqFile, "r")
        squads = textutils.unserialize(f.readAll())
        f.close()
    else
        squads["ALPHA"] = true
        squads["HQ"] = true
    end
end

local function saveDB()
    local f = fs.open(dbFile, "w")
    f.write(textutils.serialize(users))
    f.close()
    local f2 = fs.open(sqFile, "w")
    f2.write(textutils.serialize(squads))
    f2.close()
end

loadDB()
local currentObjective = "HOLD POSITION"

-- === АДМИНКА ===
local function adminLoop()
    while true do
        term.clear()
        term.setCursorPos(1,1)
        term.setTextColor(colors.green)
        print("/// SERVER V12.0 ["..PROTOCOL.."] ///")
        print("KEY: " .. (KEY=="none" and "OFF" or "RC4 ACTIVE"))
        print("----------------------------------")
        print("mksq <name>       - Register Squad")
        print("rmsq <name>       - Delete Squad")
        print("add               - Add Soldier/Cmd")
        print("del <ID>          - Delete User")
        print("list              - Show Database")
        
        term.setCursorPos(1, 10)
        write("ADM> ")
        local input = read()
        local args = {}
        for w in input:gmatch("%S+") do table.insert(args, w) end
        local cmd = args[1]
        
        if cmd == "mksq" and args[2] then
            squads[string.upper(args[2])] = true
            saveDB()
            print("Squad Registered.")
            sleep(1)
        elseif cmd == "rmsq" and args[2] then
            squads[string.upper(args[2])] = nil
            saveDB()
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
                print("Role: 1.SOLDIER 2.COMMANDER")
                write("> ")
                local rl = (read() == "2") and "COMMANDER" or "SOLDIER"
                users[id] = {pass=pass, squad=sq, rank=rk, name=nm, nation=nat, role=rl}
                saveDB()
                print("User Saved.")
                sleep(1)
            end
        elseif cmd == "del" and args[2] then
            users[string.upper(args[2])] = nil
            saveDB()
            print("Deleted.")
            sleep(1)
        elseif cmd == "list" then
            print("\nID | SQD | ROLE | NAME")
            for id, u in pairs(users) do
                print(id .. " | " .. u.squad .. " | " .. u.role:sub(1,3) .. " | " .. u.name)
            end
            print("Press Enter...")
            read()
        end
    end
end

-- === СЕТЬ ===
local function netLoop()
    while true do
        local id, msg = rednet.receive(PROTOCOL)
        
        if msg and type(msg) == "table" then
            
            -- LOGIN
            if msg.type == "LOGIN" then
                local userID = string.upper(msg.userID or "")
                local userPass = msg.userPass
                local reqRole = msg.role or "SOLDIER"
                local u = users[userID]
                
                if u and u.pass == userPass then
                    if u.role == reqRole then
                        print("[LOG] Auth: " .. userID)
                        
                        -- Шифруем задачу перед отправкой
                        local encObj = crypt(currentObjective, KEY)
                        
                        rednet.send(id, {
                            type="AUTH_OK",
                            profile={
                                id=userID, squad=u.squad, rank=u.rank, 
                                name=u.name, nation=u.nation, role=u.role
                            },
                            obj=encObj
                        }, PROTOCOL)
                        
                        if u.role == "COMMANDER" then commandersOnline[userID] = id end
                    else
                        print("[WARN] Role Mismatch: " .. userID)
                        rednet.send(id, {type="AUTH_FAIL", reason="Restricted Device"}, PROTOCOL)
                    end
                else
                    rednet.send(id, {type="AUTH_FAIL", reason="Invalid ID/Pass"}, PROTOCOL)
                end

            -- REPORT (Входящий от солдата)
            elseif msg.type == "REPORT" then
                local u = users[msg.userID]
                if u then
                    -- 1. Дешифруем входящее
                    local cleanText = crypt(msg.text, KEY) 
                    
                    local color = colors.green
                    if cleanText:find("CONTACT") then color = colors.red
                    elseif cleanText:find("MEDIC") then color = colors.magenta end
                    
                    local finalTxt = u.rank.." "..u.name.." ("..msg.userID.."): "..cleanText
                    
                    -- 2. Шифруем исходящее
                    local encTxt = crypt(finalTxt, KEY)
                    
                    rednet.broadcast({
                        type="CHAT_LINE", 
                        text=encTxt, 
                        color=color, 
                        channel="SQUAD", 
                        targetSquad=u.squad
                    }, PROTOCOL)
                end
            
            -- CMD CHAT
            elseif msg.type == "CMD_CHAT" then
                local cleanText = crypt(msg.text, KEY)
                local finalTxt = "[SECURE] "..msg.callsign..": "..cleanText
                local encTxt = crypt(finalTxt, KEY)
                
                for _, cmdID in pairs(commandersOnline) do
                    rednet.send(cmdID, {type="CHAT_LINE", text=encTxt, color=colors.cyan, channel="CMD"}, PROTOCOL)
                end
                
            -- SET OBJ
            elseif msg.type == "SET_OBJ" then
                 local cleanObj = crypt(msg.text, KEY)
                 currentObjective = cleanObj
                 
                 local finalTxt = "NEW ORDERS: "..currentObjective
                 local encTxt = crypt(finalTxt, KEY)
                 
                 rednet.broadcast({type="CHAT_LINE", text=encTxt, color=colors.yellow, channel="GLOBAL"}, PROTOCOL)
            
            elseif msg.type == "SQUAD_CMD" then
                 local cleanText = crypt(msg.text, KEY)
                 local finalTxt = "[CMD] "..msg.callsign..": "..cleanText
                 local encTxt = crypt(finalTxt, KEY)
                 
                 rednet.broadcast({type="CHAT_LINE", text=encTxt, color=colors.orange, channel="SQUAD", targetSquad=msg.squad}, PROTOCOL)
            end
        end
    end
end

term.clear()
parallel.waitForAny(adminLoop, netLoop)