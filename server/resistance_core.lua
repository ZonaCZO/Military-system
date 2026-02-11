-- === NIPAYA HUB SERVER V5.1 (FIXED) ===
-- [ROUTER + COMMAND CHANNEL]

local modem = peripheral.find("modem")
if not modem then error("No modem found") end
rednet.open(peripheral.getName(modem))
rednet.host("nipaya_net", "central_core")

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
    squads["HQ"] = "0000"
end

local function saveDB()
    local f = fs.open(dbFile, "w")
    f.write(textutils.serialize(squads))
    f.close()
end

local currentObjective = "STAND BY."

-- === КОНСОЛЬ ХОСТА (ИСПРАВЛЕННАЯ) ===
local function adminLoop()
    while true do
        term.setCursorPos(1, 1)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.green)
        print("/// HUB V5.1 ACTIVE ///")
        print("CMD Online: " .. #commanders)
        print("---------------------------")
        print("add <squad> <pass> | del <squad>")
        print("list               | show squads") 
        
        term.setCursorPos(1, 10)
        write("HOST> ")
        local input = read()
        
        -- !!! ИСПРАВЛЕНИЕ: Разбиваем строку на слова !!!
        local args = {}
        for word in input:gmatch("%S+") do table.insert(args, word) end
        
        local cmd = args[1]
        local arg1 = args[2]
        local arg2 = args[3]
        
        if cmd == "add" and arg1 and arg2 then
            squads[string.upper(arg1)] = arg2
            saveDB()
            print("Squad added: " .. string.upper(arg1))
            sleep(1)
            
        elseif cmd == "del" and arg1 then
            squads[string.upper(arg1)] = nil
            saveDB()
            print("Deleted: " .. string.upper(arg1))
            sleep(1)
            
        elseif cmd == "list" then
            print("\n--- SQUADS ---")
            for name, pass in pairs(squads) do
                print(name .. " : " .. pass)
            end
            print("--------------")
            print("Press Enter...")
            read()
            
        elseif cmd then
            print("Unknown command.")
            sleep(0.5)
        end
        term.clear()
    end
end

-- === СЕТЬ (ОСТАЛАСЬ БЕЗ ИЗМЕНЕНИЙ) ===
local function netLoop()
    while true do
        local id, msg = rednet.receive("nipaya_net")
        
        if type(msg) == "table" then
            if msg.type == "LOGIN" then
                local sName = string.upper(msg.squad or "")
                local role = msg.role or "SOLDIER"
                
                if squads[sName] and squads[sName] == msg.pass then
                    rednet.send(id, {type="AUTH", res=true, obj=currentObjective}, "nipaya_net")
                    print("[LOG] ID " .. id .. " joined " .. sName)
                    if role == "COMMANDER" then
                        local exists = false
                        for _, cid in pairs(commanders) do if cid == id then exists = true end end
                        if not exists then table.insert(commanders, id) end
                    end
                else
                    rednet.send(id, {type="AUTH", res=false, reason="WRONG PASS"}, "nipaya_net")
                    print("[WARN] Failed login: " .. sName)
                end

            elseif msg.type == "SET_OBJ" and msg.key == "Freedom" then
                currentObjective = msg.text
                rednet.broadcast({type="CHAT_LINE", text="NEW ORDERS: " .. currentObjective, color=colors.yellow, channel="GLOBAL"}, "nipaya_net")

            elseif msg.type == "REPORT" or msg.type == "BROADCAST" then
                local prefix = ""
                local color = colors.white
                if msg.type == "REPORT" then
                    prefix = (msg.rank or "") .. " " .. (msg.callsign or "?") .. ": "
                    if msg.text:find("CONTACT") then color = colors.red
                    elseif msg.text:find("MEDIC") then color = colors.magenta 
                    elseif msg.text:find("MSG") then color = colors.gray end
                else
                    prefix = "[CMD] " .. (msg.callsign or "HQ") .. ": "
                    color = colors.orange
                end
                rednet.broadcast({type="CHAT_LINE", text=prefix .. msg.text, color=color, channel="GLOBAL"}, "nipaya_net")

            elseif msg.type == "CMD_CHAT" then
                local txt = "[SECURE] " .. (msg.callsign or "HQ") .. ": " .. msg.text
                for _, cmdID in pairs(commanders) do
                    rednet.send(cmdID, {type="CHAT_LINE", text=txt, color=colors.cyan, channel="CMD"}, "nipaya_net")
                end
            end
        end
    end
end

term.clear()
parallel.waitForAny(netLoop, adminLoop)