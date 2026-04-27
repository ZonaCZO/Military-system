-- === STRATEGIC PLAN BROWSER V1.0 ===
-- [SECURE HQ TERMINAL]

local modem = peripheral.find("modem")
if not modem then error("No wireless modem found!") end
rednet.open(peripheral.getName(modem))

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

-- === НАСТРОЙКИ СЕТИ ===
local PROTOCOL = "default_net"
local KEY = "none"

if fs.exists(".net_config.txt") then
    local f = fs.open(".net_config.txt", "r")
    PROTOCOL = f.readLine()
    KEY = f.readLine()
    f.close()
end

local serverID = rednet.lookup(PROTOCOL, "central_core")
local myProfile = nil
local myToken = nil

-- === СЕТЕВЫЕ ОБЕРТКИ ===
local function sendEncrypted(data)
    local payload = textutils.serialize(data)
    local encrypted = crypt(payload, KEY)
    rednet.send(serverID, encrypted, PROTOCOL)
end

local function receiveEncrypted(timeout)
    local id, msg = rednet.receive(PROTOCOL, timeout)
    if type(msg) == "string" then
        local decrypted = crypt(msg, KEY)
        return id, textutils.unserialize(decrypted)
    end
    return id, nil
end

-- === АВТОРИЗАЦИЯ ===
local function login()
    local msgText = ""
    while true do
        term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
        term.setTextColor(colors.cyan); print("=== HQ AUTHENTICATION ==="); term.setTextColor(colors.white)
        
        if msgText ~= "" then term.setTextColor(colors.red); print(msgText); term.setTextColor(colors.white) end
        
        write("Command ID: "); local inputID = string.upper(read())
        write("Password: "); local inputPass = read("*")
        
        if not serverID then serverID = rednet.lookup(PROTOCOL, "central_core") end
        
        sendEncrypted({type="LOGIN", userID=inputID, userPass=inputPass, role="commander"})
        local id, msg = receiveEncrypted(3)
        
        if msg and msg.type == "AUTH_OK" then
            myProfile = msg.profile
            myToken = msg.token
            return 
        elseif msg and msg.type == "AUTH_FAIL" then
            msgText = "ACCESS DENIED: " .. (msg.reason or "Unknown")
        else
            msgText = "ERROR: Server Unreachable"
        end
    end
end

login()

-- === СОСТОЯНИЕ UI ===
local plans = {}
local currentPlan = nil
local mode = "LIST" -- "LIST", "DETAILS"
local listIndex = 1
local stageIndex = 1
local isLoading = false
local statusMsg = ""

-- === ЗАПРОСЫ К СЕРВЕРУ ===
local function fetchPlans()
    isLoading = true
    sendEncrypted({type="PLAN_LIST"})
end

local function fetchPlanDetails(planId)
    isLoading = true
    sendEncrypted({type="PLAN_GET", id=planId})
end

local function saveCurrentPlan()
    if not currentPlan then return end
    statusMsg = "Saving..."
    sendEncrypted({
        type = "PLAN_SAVE",
        userID = myProfile.id,
        token = myToken,
        plan = currentPlan
    })
end

-- === ОТРИСОВКА ===
local function drawUI()
    local w, h = term.getSize()
    term.setBackgroundColor(colors.gray)
    term.clear()
    
    -- Шапка
    paintutils.drawFilledBox(1, 1, w, 1, colors.black)
    term.setCursorPos(2, 1); term.setTextColor(colors.yellow)
    write("OPERATIONAL PLANS ARCHIVE")
    term.setCursorPos(w - #myProfile.id - 5, 1); term.setTextColor(colors.white)
    write("USER: " .. myProfile.id)
    
    if isLoading then
        term.setCursorPos(w/2 - 5, h/2); term.setBackgroundColor(colors.gray); term.setTextColor(colors.white)
        write("LOADING...")
        return
    end

    if mode == "LIST" then
        if #plans == 0 then
            term.setCursorPos(2, 3); term.setTextColor(colors.red); write("No active plans found.")
        else
            for i, p in ipairs(plans) do
                local y = i + 2
                if y < h then
                    if i == listIndex then
                        term.setBackgroundColor(colors.blue); term.setTextColor(colors.white)
                    else
                        term.setBackgroundColor(colors.gray); term.setTextColor(colors.lightGray)
                    end
                    term.setCursorPos(2, y)
                    local statusFormat = p.status == "active" and "[ACTIVE]" or "[ENDED]"
                    local line = string.format("%s %s (Front: %s)", statusFormat, p.title, p.front_id or "N/A")
                    write(line .. string.rep(" ", w - #line - 1))
                end
            end
        end
        
        term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
        term.setCursorPos(1, h); write(string.rep(" ", w))
        term.setCursorPos(2, h); write("[Up/Down] Select   [Enter] Open   [R] Refresh   [Q] Exit")
        
    elseif mode == "DETAILS" and currentPlan then
        paintutils.drawFilledBox(2, 3, w-1, h-2, colors.black)
        term.setBackgroundColor(colors.black)
        
        term.setCursorPos(3, 4); term.setTextColor(colors.cyan); write("PLAN: " .. currentPlan.title)
        term.setCursorPos(3, 5); term.setTextColor(colors.lightGray)
        write(string.format("AUTHOR: %s | STATUS: %s", currentPlan.author, string.upper(currentPlan.status)))
        
        term.setCursorPos(3, 7); term.setTextColor(colors.yellow); write("STAGES:")
        
        local stages = currentPlan.stages or {}
        if #stages == 0 then
            term.setCursorPos(5, 8); term.setTextColor(colors.gray); write("No stages defined.")
        else
            for i, stage in ipairs(stages) do
                local y = 7 + i
                if y < h - 2 then
                    term.setCursorPos(3, y)
                    if i == stageIndex then term.setTextColor(colors.white); write("> ") 
                    else write("  ") end
                    
                    if stage.done then term.setTextColor(colors.green); write("[X] ")
                    else term.setTextColor(colors.red); write("[ ] ") end
                    
                    term.setTextColor(colors.white)
                    write(stage.text or ("Stage " .. stage.id))
                end
            end
        end
        
        if statusMsg ~= "" then
            term.setCursorPos(3, h-3); term.setTextColor(colors.orange); write(statusMsg)
        end
        
        term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
        term.setCursorPos(1, h); write(string.rep(" ", w))
        term.setCursorPos(2, h); write("[Up/Down] Select Stage  [Enter] Toggle  [S] Save  [Bksp] Back")
    end
end

-- === СЕТЕВОЙ ЦИКЛ ===
local function netLoop()
    fetchPlans()
    while true do
        local id, msg = receiveEncrypted()
        if msg then
            if msg.type == "PLAN_LIST" then
                plans = msg.data or {}
                isLoading = false
                drawUI()
            elseif msg.type == "PLAN_GET" then
                currentPlan = msg.data
                stageIndex = 1
                isLoading = false
                statusMsg = ""
                drawUI()
            elseif msg.type == "SAVE_OK" then
                statusMsg = "Saved successfully!"
                drawUI()
                sleep(2)
                statusMsg = ""
                drawUI()
            elseif msg.type == "ERROR" then
                statusMsg = "Error: " .. (msg.reason or "Unknown")
                drawUI()
            end
        end
    end
end

-- === ЦИКЛ ВВОДА ===
local function inputLoop()
    while true do
        local event, key = os.pullEvent("key")
        
        if mode == "LIST" and not isLoading then
            if key == keys.up and listIndex > 1 then
                listIndex = listIndex - 1; drawUI()
            elseif key == keys.down and listIndex < #plans then
                listIndex = listIndex + 1; drawUI()
            elseif key == keys.enter and #plans > 0 then
                mode = "DETAILS"
                fetchPlanDetails(plans[listIndex].id)
                drawUI()
            elseif key == keys.r then
                fetchPlans()
            elseif key == keys.q then
                term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
                return
            end
            
        elseif mode == "DETAILS" and not isLoading then
            local stages = currentPlan.stages or {}
            if key == keys.up and stageIndex > 1 then
                stageIndex = stageIndex - 1; drawUI()
            elseif key == keys.down and stageIndex < #stages then
                stageIndex = stageIndex + 1; drawUI()
            elseif key == keys.enter and #stages > 0 then
                -- Переключение статуса стадии
                stages[stageIndex].done = not stages[stageIndex].done
                statusMsg = "Unsaved changes (*)"
                drawUI()
            elseif key == keys.s then
                saveCurrentPlan()
            elseif key == keys.backspace then
                mode = "LIST"
                currentPlan = nil
                statusMsg = ""
                drawUI()
            end
        end
    end
end

parallel.waitForAny(netLoop, inputLoop)