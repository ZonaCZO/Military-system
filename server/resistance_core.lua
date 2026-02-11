-- === HUB SERVER V7.0 ===
-- [Universal Network Support]

local modem = peripheral.find("modem")
if not modem then error("No modem found") end
rednet.open(peripheral.getName(modem))

-- === НАСТРОЙКА СЕТИ (НОВОЕ) ===
local PROTOCOL = "first_net" -- Значение по умолчанию
local netFile = "net_config.txt"

if fs.exists(netFile) then
    local f = fs.open(netFile, "r")
    PROTOCOL = f.readAll()
    f.close()
else
    term.clear()
    term.setCursorPos(1,1)
    print("--- SERVER SETUP ---")
    print("Enter Unique Network ID")
    print("(e.g. BLUE_TEAM, SQUAD_1):")
    write("> ")
    local input = read()
    if input ~= "" then PROTOCOL = input end
    
    local f = fs.open(netFile, "w")
    f.write(PROTOCOL)
    f.close()
end

rednet.host(PROTOCOL, "central_core") -- Хостим в выбранной сети

-- === БАЗА ДАННЫХ ===
local squads = {}
local dbFile = "squads.db"
local commanders = {} 

if fs.exists(dbFile) then
    local f = fs.open(dbFile, "r")
    squads = textutils.unserialize(f.readAll())
    f.close()
else
    squads["ALPHA"] = "1234"
    squads["BRAVO"] = "1234"
    squads["HQ"] = "0000"
end

local function saveDB()
    local f = fs.open(dbFile, "w")
    f.write(textutils.serialize(squads))
    f.close()
end

local currentObjective = "STAND BY."

-- === КОНСОЛЬ АДМИНА ===
local function adminLoop()
    while true do
        term.clear()
        term.setCursorPos(1, 1)
        term.setTextColor(colors.green)
        print("/// HUB V7.0 (" .. PROTOCOL .. ") ///")
        print("Cmds: add <sq> <pass> | del <sq> | list")
        
        term.setCursorPos(1, 10)
        write("HOST> ")
        local input = read()
        
        local args = {}
        for word in input:gmatch("%S+") do table.insert(args, word) end
        local cmd = args[1]
        
        if cmd == "add" and args[2] and args[3] then
            squads[string.upper(args[2])] = args[3]
            saveDB()
            print("Saved.")
            sleep(1)
        elseif cmd == "del" and args[2] then
            squads[string.upper(args[2])] = nil
            saveDB()
            print("Deleted.")
            sleep(1)
        elseif cmd == "list" then
            print("\n--- SQUADS ---")
            for k,v in pairs(squads) do print(k..": "..v) end
            print("--- COMMANDERS ---")
            for _,v in pairs(commanders) do write(v.." ") end
            print("\nPress Enter...")
            read()
        end
    end
end

-- === СЕТЬ ===
local function netLoop()
    while true do
        -- Слушаем только нашу сеть (PROTOCOL)
        local id, msg = rednet.receive(PROTOCOL)
        
        if msg and type(msg) == "table" then
            if msg.type == "LOGIN" then
                local sName = string.upper(msg.squad or "")
                
                if squads[sName] and squads[sName] == msg.pass then
                    rednet.send(id, {type="AUTH", res=true, obj=currentObjective}, PROTOCOL)
                    print("[LOG] Login: " .. sName .. " (" .. id .. ")")
                    
                    if msg.role == "COMMANDER" then 
                        local exists = false
                        for _, cid in pairs(commanders) do
                            if cid == id then exists = true break end
                        end
                        if not exists then table.insert(commanders, id) end
                    end
                else
                    rednet.send(id, {type="AUTH", res=false, reason="Wrong Pass"}, PROTOCOL)
                end

            elseif msg.type == "SET_OBJ" and msg.key == "Freedom" then
                currentObjective = msg.text
                rednet.broadcast({type="CHAT_LINE", text="NEW ORDERS: " .. currentObjective, color=colors.yellow, channel="GLOBAL"}, PROTOCOL)

            elseif msg.type == "REPORT" then
                local prefix = (msg.rank or "") .. " " .. (msg.callsign or "?") .. ": "
                local color = colors.green
                if msg.text:find("CONTACT") then color = colors.red
                elseif msg.text:find("MEDIC") then color = colors.magenta 
                elseif msg.text:find("MSG") then color = colors.gray end
                
                rednet.broadcast({type="CHAT_LINE", text=prefix .. msg.text, color=color, channel="SQUAD", targetSquad=string.upper(msg.squad)}, PROTOCOL)

            elseif msg.type == "SQUAD_CMD" then
                local prefix = "[CMD] " .. (msg.callsign or "HQ") .. ": "
                rednet.broadcast({type="CHAT_LINE", text=prefix .. msg.text, color=colors.orange, channel="SQUAD", targetSquad=string.upper(msg.squad)}, PROTOCOL)

            elseif msg.type == "BROADCAST" then
                 local prefix = "[ALL] " .. (msg.callsign or "HQ") .. ": "
                 rednet.broadcast({type="CHAT_LINE", text=prefix .. msg.text, color=colors.white, channel="GLOBAL"}, PROTOCOL)

            elseif msg.type == "CMD_CHAT" then
                local txt = "[SECURE] " .. (msg.callsign or "HQ") .. ": " .. msg.text
                for _, cmdID in pairs(commanders) do
                    rednet.send(cmdID, {type="CHAT_LINE", text=txt, color=colors.cyan, channel="CMD"}, PROTOCOL)
                end
            end
        end
    end
end

term.clear()
parallel.waitForAny(adminLoop, netLoop)