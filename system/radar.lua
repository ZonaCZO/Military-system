-- === TACTICAL ASCII RADAR V1.0 ===
-- [HQ VISUALIZATION SYSTEM]

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

-- === НАСТРОЙКИ СЕТИ И АВТОРИЗАЦИИ ===
local PROTOCOL = "default_net"
local KEY = "none"

if fs.exists(".net_config.txt") then
    local f = fs.open(".net_config.txt", "r")
    PROTOCOL = f.readLine(); KEY = f.readLine(); f.close()
end

local serverID = rednet.lookup(PROTOCOL, "central_core")
local myProfile = nil
local myToken = nil
local currentFrontId = ""
local mapData = nil
local isLoading = false

-- === СЕТЕВЫЕ ОБЕРТКИ ===
local function sendEncrypted(data)
    local payload = textutils.serialize(data)
    rednet.send(serverID, crypt(payload, KEY), PROTOCOL)
end

local function receiveEncrypted(timeout)
    local id, msg = rednet.receive(PROTOCOL, timeout)
    if type(msg) == "string" then
        return id, textutils.unserialize(crypt(msg, KEY))
    end
    return id, nil
end

-- === АВТОРИЗАЦИЯ ===
local function login()
    term.clear(); term.setCursorPos(1,1); term.setTextColor(colors.green)
    print("=== RADAR LOGIN ===")
    write("Command ID: "); local id = string.upper(read())
    write("Password: "); local pass = read("*")
    if not serverID then serverID = rednet.lookup(PROTOCOL, "central_core") end
    
    sendEncrypted({type="LOGIN", userID=id, userPass=pass, role="commander"})
    local _, msg = receiveEncrypted(3)
    if msg and msg.type == "AUTH_OK" then
        myProfile = msg.profile; myToken = msg.token
    else
        error("Access Denied or Server Offline")
    end
end

login()

-- === ВЫБОР ФРОНТА ===
term.clear(); term.setCursorPos(1,1); term.setTextColor(colors.yellow)
write("Enter Front ID to scan (e.g. 'tokmak'): ")
currentFrontId = string.lower(read())

-- === ЛОГИКА ОТРИСОВКИ КАРТЫ ===

-- Символы для разных типов маркеров
local markerIcons = {
    ally = {char="A", color=colors.green},
    enemy = {char="X", color=colors.red},
    objective = {char="O", color=colors.yellow},
    note = {char="?", color=colors.lightGray}
}

local function drawMap()
    local w, h = term.getSize()
    term.setBackgroundColor(colors.black); term.clear()
    
    if isLoading then
        term.setCursorPos(w/2-5, h/2); term.setTextColor(colors.yellow); write("SCANNING...")
        return
    end
    
    if not mapData or not mapData.front then
        term.setCursorPos(2, 2); term.setTextColor(colors.red); write("ERROR: No map data received.")
        term.setCursorPos(2, h); term.setTextColor(colors.white); write("[Q] Exit  [R] Retry")
        return
    end

    local front = mapData.front
    local bounds = front.bounds or {x1=0, z1=0, x2=0, z2=0}
    
    -- Вычисляем масштаб (чтобы карта влезла в экран)
    -- Оставляем место для шапки и футера
    local mapW, mapH = w - 4, h - 4 
    
    local minX = math.min(bounds.x1, bounds.x2)
    local maxX = math.max(bounds.x1, bounds.x2)
    local minZ = math.min(bounds.z1, bounds.z2)
    local maxZ = math.max(bounds.z1, bounds.z2)
    
    local rangeX = math.max(maxX - minX, 1) -- Защита от деления на 0
    local rangeZ = math.max(maxZ - minZ, 1)
    
    -- Функция перевода реальных координат в координаты экрана
    local function worldToScreen(worldX, worldZ)
        local pctX = (worldX - minX) / rangeX
        local pctZ = (worldZ - minZ) / rangeZ
        -- Ограничиваем от 0 до 1, чтобы не вылезало за экран
        pctX = math.max(0, math.min(1, pctX))
        pctZ = math.max(0, math.min(1, pctZ))
        
        local screenX = 2 + math.floor(pctX * mapW)
        local screenY = 3 + math.floor(pctZ * mapH)
        return screenX, screenY
    end

    -- 1. Рисуем рамку фронта (зеленая сетка)
    paintutils.drawBox(2, 3, w-2, h-1, colors.green)

    -- 2. Рисуем маркеры
    local markers = front.markers or {}
    for _, m in ipairs(markers) do
        local sx, sy = worldToScreen(m.x, m.z)
        local iconData = markerIcons[m.type or "note"] or markerIcons.note
        
        term.setCursorPos(sx, sy)
        term.setBackgroundColor(colors.black)
        term.setTextColor(iconData.color)
        write(iconData.char)
    end

    -- Шапка
    term.setCursorPos(1, 1); term.setBackgroundColor(colors.gray); term.setTextColor(colors.white)
    write(string.rep(" ", w))
    term.setCursorPos(2, 1); write("RADAR SCAN: " .. front.name:upper() .. " | MARKERS: " .. #markers)
    
    -- Футер
    term.setBackgroundColor(colors.black); term.setTextColor(colors.lightGray)
    term.setCursorPos(2, h); write("[R] Refresh Scan   [Q] Exit")
end

-- === ЦИКЛЫ ===
local function fetchSnapshot()
    isLoading = true; drawUI()
    sendEncrypted({
        type = "MAP_FRONT_GET",
        userID = myProfile.id,
        token = myToken,
        frontId = currentFrontId
    })
end

local function netLoop()
    fetchSnapshot()
    while true do
        -- Ждем ответа максимум 3 секунды
        local id, msg = receiveEncrypted(3) 
        
        if msg and msg.type == "MAP_FRONT_DATA" then
            mapData = msg.data
            isLoading = false
            drawUI()
        elseif msg and msg.type == "ERROR" then
            isLoading = false
            -- Выводим ошибку от сервера прямо на экран
            term.setCursorPos(1, 2); term.setTextColor(colors.red)
            print("SERVER ERROR: " .. tostring(msg.reason))
            sleep(2)
            drawUI()
        elseif not msg and isLoading then
            -- Если прошло 3 секунды, а мы все еще грузимся
            isLoading = false
            term.setCursorPos(1, 2); term.setTextColor(colors.red)
            print("CONNECTION TIMEOUT: No response from HQ.")
            sleep(2)
            drawUI()
        end
    end
end

local function inputLoop()
    while true do
        local e, key = os.pullEvent("key")
        if key == keys.r then
            fetchSnapshot()
        elseif key == keys.q then
            term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
            return
        end
    end
end

-- Вспомогательная функция для обновления экрана изнутри fetch
function drawUI() drawMap() end 

parallel.waitForAny(netLoop, inputLoop)