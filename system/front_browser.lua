-- === FRONT COMMAND CENTER V14.2 ===
-- [SECURE PC INTERFACE]

local modem = peripheral.find("modem")
if not modem then error("No modem found!") end
rednet.open(peripheral.getName(modem))

-- === CONFIG & CRYPTO ===
local PROTOCOL = "default_net"
local KEY = "none"

if fs.exists(".net_config.txt") then
    local f = fs.open(".net_config.txt", "r")
    PROTOCOL = f.readLine()
    KEY = f.readLine()
    f.close()
end

local serverID = rednet.lookup(PROTOCOL, "central_core")

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

-- === SECURE NETWORKING WRAPPERS ===
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

-- === DATA & STATE ===
local fronts = {}
local selectedIndex = 1
local mode = "LIST" 
local isLoading = true

local function fetchFronts()
    isLoading = true
    -- Отрисовываем UI перед запросом, функция drawUI будет вызвана ниже
    if not serverID then serverID = rednet.lookup(PROTOCOL, "central_core") end
    
    if serverID then
        sendEncrypted({type = "FRONT_LIST"})
        local id, msg = receiveEncrypted(3)
        
        if msg and msg.type == "FRONT_LIST" then
            fronts = msg.data or {}
        end
    end
    isLoading = false
end

-- === UI DRAWING ===
local function drawUI()
    local w, h = term.getSize()
    term.setBackgroundColor(colors.gray)
    term.clear()
    
    paintutils.drawFilledBox(1, 1, w, 1, colors.black)
    term.setCursorPos(2, 1)
    term.setTextColor(colors.yellow)
    write("STRATEGIC MAP: FRONTS")
    
    if isLoading then
        term.setCursorPos(w/2 - 5, h/2)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.gray)
        write("LOADING...")
        return
    end

    if mode == "LIST" then
        if #fronts == 0 then
            term.setCursorPos(2, 3); term.setTextColor(colors.red); write("No active fronts found.")
        else
            for i, front in ipairs(fronts) do
                local y = i + 2
                if y < h then
                    if i == selectedIndex then
                        term.setBackgroundColor(colors.blue)
                        term.setTextColor(colors.white)
                    else
                        term.setBackgroundColor(colors.gray)
                        term.setTextColor(colors.lightGray)
                    end
                    term.setCursorPos(2, y)
                    local line = string.format("[%s] %s (%s)", front.id, front.name, front.type)
                    write(line .. string.rep(" ", w - #line - 1))
                end
            end
        end
        
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.setCursorPos(1, h)
        write(string.rep(" ", w))
        term.setCursorPos(2, h)
        write("[Up/Down] Select   [Enter] Details   [R] Refresh   [Q] Exit")
        
    elseif mode == "DETAILS" then
        local front = fronts[selectedIndex]
        if not front then mode = "LIST"; return end
        
        paintutils.drawFilledBox(2, 3, w-1, h-2, colors.black)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        
        term.setCursorPos(3, 4); term.setTextColor(colors.cyan); write("FRONT: " .. front.name)
        term.setCursorPos(3, 5); term.setTextColor(colors.lightGray); write("ID: " .. front.id .. " | TYPE: " .. front.type)
        
        term.setCursorPos(3, 7); term.setTextColor(colors.yellow); write("DESCRIPTION:")
        term.setCursorPos(3, 8); term.setTextColor(colors.white); write(front.description ~= "" and front.description or "No description provided.")
        
        term.setCursorPos(3, 10); term.setTextColor(colors.orange); write("MARKERS: " .. #(front.markers or {}))
        term.setCursorPos(3, 11); term.setTextColor(colors.green); write("PLANS ATTACHED: " .. #(front.plans or {}))
        
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.setCursorPos(1, h)
        write(string.rep(" ", w))
        term.setCursorPos(2, h)
        write("[Backspace] Back to List   [Q] Exit")
    end
end

-- === INPUT LOOP ===
local function inputLoop()
    while true do
        local event, key = os.pullEvent("key")
        local w, h = term.getSize()
        
        if mode == "LIST" then
            if key == keys.up and selectedIndex > 1 then
                selectedIndex = selectedIndex - 1
                drawUI()
            elseif key == keys.down and selectedIndex < #fronts then
                selectedIndex = selectedIndex + 1
                drawUI()
            elseif key == keys.enter and #fronts > 0 then
                mode = "DETAILS"
                drawUI()
            elseif key == keys.r then
                fetchFronts()
                drawUI()
            elseif key == keys.q then
                term.setBackgroundColor(colors.black)
                term.clear()
                term.setCursorPos(1,1)
                return 
            end
        elseif mode == "DETAILS" then
            if key == keys.backspace then
                mode = "LIST"
                drawUI()
            elseif key == keys.q then
                term.setBackgroundColor(colors.black)
                term.clear()
                term.setCursorPos(1,1)
                return
            end
        end
    end
end

-- ЗАПУСК
term.clear()
fetchFronts()
drawUI()
inputLoop()