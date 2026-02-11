-- === CENTRAL DB V10.1 ===
-- [CRASH FIX + DUPLICATE FIX]

local modem = peripheral.find("modem")
if not modem then error("No modem found") end
rednet.open(peripheral.getName(modem))

local PROTOCOL = "default_net" -- Значение по умолчанию, если ничего не введут
local netFile = "net_config.txt"

if fs.exists(netFile) then
    -- Если конфиг есть — читаем его
    local f = fs.open(netFile, "r")
    PROTOCOL = f.readAll()
    f.close()
else
    -- Если конфига нет — СОЗДАЕМ
    term.clear()
    term.setCursorPos(1,1)
    print("--- SERVER SETUP ---")
    print("Create Network ID (e.g. ALPHA_NET):")
    write("> ")
    local input = read()
    
    -- Если ввели текст, используем его. Если просто Enter — оставим дефолт.
    if input ~= "" then 
        PROTOCOL = input 
    end
    
    -- Сохраняем в файл
    local f = fs.open(netFile, "w")
    f.write(PROTOCOL)
    f.close()
    
    print("Network ID saved: " .. PROTOCOL)
    sleep(1)
end

rednet.host(PROTOCOL, "central_core")

-- === ДАННЫЕ ===
local users = {} 
local squads = {}
local dbFile = "users.db"
local sqFile = "squads.db"
local commandersOnline = {} -- Таблица для онлайн командиров

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

-- === КОНСОЛЬ АДМИНА ===
local function adminLoop()
    while true do
        term.clear()
        term.setCursorPos(1,1)
        term.setTextColor(colors.green)
        print("/// SERVER V10.1 ["..PROTOCOL.."] ///")
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
            write("ID (e.g. K7): ") local id = string.upper(read())
            write("Pass: ") local pass = read()
            
            print("--- SQUADS ---")
            for sq, _ in pairs(squads) do write(sq.." ") end
            print("\n--------------")
            write("Squad: ") local sq = string.upper(read())
            if not squads[sq] then
                print("ERROR: Squad not registered! Use 'mksq' first.")
                sleep(2)
            else
                write("Rank (Sgt): ") local rk = read()
                write("Name (Doe): ") local nm = read()
                write("Nation (NPY): ") local nat = read()
                
                print("Role: 1.SOLDIER  2.COMMANDER")
                write("> ")
                local rInput = read()
                local rl = (rInput == "2") and "COMMANDER" or "SOLDIER"
                
                users[id] = {pass=pass, squad=sq, rank=rk, name=nm, nation=nat, role=rl}
                saveDB()
                print("User saved as " .. rl)
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
                local rShort = (u.role=="COMMANDER") and "CMD" or "SLD"
                print(id .. " | " .. u.squad .. " | " .. rShort .. " | " .. u.name)
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
            
            -- 1. АВТОРИЗАЦИЯ
            if msg.type == "LOGIN" then
                local userID = string.upper(msg.userID or "")
                local userPass = msg.userPass
                -- Если роль не указана, считаем что это SOLDIER (для совместимости)
                local reqRole = msg.role or "SOLDIER"
                
                local u = users[userID]
                
                if u and u.pass == userPass then
                    if u.role == reqRole then
                        print("[LOG] Auth OK: " .. userID .. " as " .. reqRole)
                        rednet.send(id, {
                            type="AUTH_OK",
                            profile={
                                id=userID,
                                squad=u.squad,
                                rank=u.rank,
                                name=u.name,
                                nation=u.nation,
                                role=u.role
                            },
                            obj=currentObjective
                        }, PROTOCOL)
                        
                        -- Обновляем ID командира (перезаписываем старый, чтобы не было дублей)
                        if u.role == "COMMANDER" then
                            commandersOnline[userID] = id
                        end
                    else
                        -- !FIX: Добавлена проверка на nil в принте, чтобы сервер не падал
                        print("[WARN] Role Mismatch: " .. userID .. " tried " .. (reqRole or "NIL"))
                        rednet.send(id, {type="AUTH_FAIL", reason="Restricted Device"}, PROTOCOL)
                    end
                else
                    rednet.send(id, {type="AUTH_FAIL", reason="Invalid ID/Pass"}, PROTOCOL)
                end

            -- 2. ОТЧЕТЫ
            elseif msg.type == "REPORT" then
                local u = users[msg.userID]
                if u then
                    local color = colors.green
                    if msg.text:find("CONTACT") then color = colors.red
                    elseif msg.text:find("MEDIC") then color = colors.magenta end
                    
                    local txt = u.rank.." "..u.name.." ("..msg.userID.."): "..msg.text
                    
                    rednet.broadcast({
                        type="CHAT_LINE", 
                        text=txt, 
                        color=color, 
                        channel="SQUAD", 
                        targetSquad=u.squad
                    }, PROTOCOL)
                end
            
            -- 3. КОМАНДНЫЙ ЧАТ
            elseif msg.type == "CMD_CHAT" then
                local txt = "[SECURE] "..msg.callsign..": "..msg.text
                -- Отправляем строго по списку уникальных ID
                for _, cmdID in pairs(commandersOnline) do
                    rednet.send(cmdID, {type="CHAT_LINE", text=txt, color=colors.cyan, channel="CMD"}, PROTOCOL)
                end
                
            -- 4. ПРИКАЗЫ
            elseif msg.type == "SET_OBJ" then
                 currentObjective = msg.text
                 rednet.broadcast({type="CHAT_LINE", text="NEW ORDERS: "..currentObjective, color=colors.yellow, channel="GLOBAL"}, PROTOCOL)
            
            elseif msg.type == "SQUAD_CMD" then
                 local txt = "[CMD] "..msg.callsign..": "..msg.text
                 rednet.broadcast({type="CHAT_LINE", text=txt, color=colors.orange, channel="SQUAD", targetSquad=msg.squad}, PROTOCOL)
            end
        end
    end
end

term.clear()
parallel.waitForAny(adminLoop, netLoop)