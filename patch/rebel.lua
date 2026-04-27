-- ==========================================
-- === CYRILLIC KEYBOARD DRIVER ===
-- ==========================================
-- Set LOCALE to RU, UA or BY to select corresponding keyboard layout
local LOCALE = 'RU'

local function handle_keypress()
  local evt, key
  repeat
    repeat evt, key = os.pullEvent() until evt == "key" or evt == "key_up"
    if evt == "key_up" then return -key end
    os.queueEvent("placeholder")
    local char_queued = false
    parallel.waitForAny(
      function()
        os.pullEvent("char")
        char_queued = true
      end,
      function()
        os.pullEvent("placeholder")
      end
    )
  until not char_queued

  return key
end

local locale_map = {
  [ 93 ] = string.char(0xFA), [ 90 ] = string.char(0xFF), [ 75 ] = string.char(0xEB), [ 65 ] = string.char(0xF4), [ 66 ] = string.char(0xE8), [ 67 ] = string.char(0xF1), [ 68 ] = string.char(0xE2), [ 69 ] = string.char(0xF3), [ 39 ] = string.char(0xFD), [ 71 ] = string.char(0xEF), [ 72 ] = string.char(0xF0), [ 73 ] = string.char(0xF8), [ 74 ] = string.char(0xEE), [ 44 ] = string.char(0xE1), [ 76 ] = string.char(0xE4), [ 77 ] = string.char(0xFC), [ 78 ] = string.char(0xF2), [ 79 ] = string.char(0xF9), [ 80 ] = string.char(0xE7), [ 81 ] = string.char(0xE9), [ 82 ] = string.char(0xEA), [ 83 ] = string.char(0xFB), [ 84 ] = string.char(0xE5), [ 85 ] = string.char(0xE3), [ 86 ] = string.char(0xEC), [ 87 ] = string.char(0xF6), [ 88 ] = string.char(0xF7), [ 89 ] = string.char(0xED), [ 59 ] = string.char(0xE6), [ 91 ] = string.char(0xF5), [ 70 ] = string.char(0xE0), [ 46 ] = string.char(0xFE)
}

local locale_map_shifted = {
  [ 93 ] = string.char(0xDA), [ 90 ] = string.char(0xDF), [ 75 ] = string.char(0xCB), [ 65 ] = string.char(0xD4), [ 66 ] = string.char(0xC8), [ 67 ] = string.char(0xD1), [ 68 ] = string.char(0xC2), [ 69 ] = string.char(0xD3), [ 39 ] = string.char(0xDD), [ 71 ] = string.char(0xCF), [ 72 ] = string.char(0xD0), [ 73 ] = string.char(0xD8), [ 74 ] = string.char(0xCE), [ 44 ] = string.char(0xC1), [ 76 ] = string.char(0xC4), [ 77 ] = string.char(0xDC), [ 78 ] = string.char(0xD2), [ 79 ] = string.char(0xD9), [ 80 ] = string.char(0xC7), [ 81 ] = string.char(0xC9), [ 82 ] = string.char(0xCA), [ 83 ] = string.char(0xDB), [ 84 ] = string.char(0xC5), [ 85 ] = string.char(0xC3), [ 86 ] = string.char(0xCC), [ 87 ] = string.char(0xD6), [ 88 ] = string.char(0xD7), [ 89 ] = string.char(0xCD), [ 59 ] = string.char(0xC6), [ 91 ] = string.char(0xD5), [ 70 ] = string.char(0xC0), [ 46 ] = string.char(0xDE)
}

if string.lower(LOCALE) == 'ua' then
  locale_map[31] = string.char(0xB3)
  locale_map[39] = string.char(0xBA)
  locale_map[93] = string.char(0xBF)
  locale_map[43] = string.char(0xB4)
  locale_map_shifted[31] = string.char(0xB2)
  locale_map_shifted[39] = string.char(0xAA)
  locale_map_shifted[93] = string.char(0xAF)
  locale_map_shifted[43] = string.char(0xA5)
elseif string.lower(LOCALE) == 'by' then
  locale_map[31] = string.char(0xB3)
  locale_map[24] = string.char(0xA2)
  locale_map[93] = "'"
  locale_map_shifted[31] = string.char(0xB2)
  locale_map_shifted[24] = string.char(0xA1)
  locale_map_shifted[93] = "'"
end

local function cyrrun()
  local shift_pressed = false
  while true do
    local key_pressed = handle_keypress()
    if key_pressed == 340 then shift_pressed = true end
    if key_pressed == -340 then shift_pressed = false end
    if locale_map[key_pressed] then
      if shift_pressed then os.queueEvent('char', locale_map_shifted[key_pressed])
      else os.queueEvent('char', locale_map[key_pressed]) end
    end
  end
end

local redrun = {}
local coroutines = {}
function redrun.init()
    local env = getfenv(rednet.run)
    if env.__redrun_coroutines then
        coroutines = env.__redrun_coroutines
    else
        env.os = setmetatable({
            pullEventRaw = function()
                local ev = table.pack(coroutine.yield())
                local delete = {}
                for k,v in pairs(coroutines) do
                    if v.terminate or v.filter == nil or v.filter == ev[1] or ev[1] == "terminate" then
                        local ok
                        if v.terminate then ok, v.filter = coroutine.resume(v.coro, "terminate")
                        else ok, v.filter = coroutine.resume(v.coro, table.unpack(ev, 1, ev.n)) end
                        if not ok or coroutine.status(v.coro) ~= "suspended" or v.terminate then delete[#delete+1] = k end
                    end
                end
                for _,v in ipairs(delete) do coroutines[v] = nil end
                return table.unpack(ev, 1, ev.n)
            end
        }, {__index = os, __isredrun = true})
        env.__redrun_coroutines = coroutines
    end
end

function redrun.start(func, name)
    local id = #coroutines+1
    coroutines[id] = {coro = coroutine.create(func), name = name}
    return id
end
redrun.init()
redrun.start(cyrrun, 'cyrrun')

-- ==========================================
-- === PDA V14.2 (SECURE STORAGE + TOKENS) ===
-- ==========================================

local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem!") end
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
    term.clear(); term.setCursorPos(1,1)
    print("--- DEVICE SETUP ---")
    write("Network ID: "); local inp = read()
    if inp ~= "" then PROTOCOL = inp end
    write("Encryption Key: "); local kInp = read()
    if kInp ~= "" then KEY = kInp end
    local f = fs.open(netFile, "w"); f.writeLine(PROTOCOL); f.writeLine(KEY); f.close()
    sleep(1)
end

local serverID = rednet.lookup(PROTOCOL, "central_core")
local myProfile = nil
local myToken = nil
local currentObj = "Awaiting Orders..."

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

local function promptInput(promptText)
    local w, h = term.getSize()
    paintutils.drawFilledBox(1, h-2, w, h, colors.black)
    term.setCursorPos(1, h-1); term.setTextColor(colors.yellow)
    write(promptText); term.setTextColor(colors.white)
    return read()
end

-- === ЛОГИН ===
local function login()
    -- АВТОЛОГИН
    if fs.exists("session.dat") then
        local f = fs.open("session.dat", "r")
        local rawData = f.readAll()
        f.close()
        
        local decryptedJson = crypt(rawData, KEY)
        local savedData = textutils.unserialize(decryptedJson)
        
        if savedData and savedData.id and savedData.pass then
            if not serverID then serverID = rednet.lookup(PROTOCOL, "central_core") end
            if serverID then 
                sendEncrypted({type="LOGIN", userID=savedData.id, userPass=savedData.pass, role="soldier"})
                local _, msg = receiveEncrypted(3)
                if msg and msg.type=="AUTH_OK" then 
                    myProfile = msg.profile
                    myToken = msg.token
                    return
                end
            end
        end
        -- Если не вышло (сменился ключ, пароль или сервер оффлайн)
        print("Session expired or Server Offline.")
        fs.delete("session.dat")
        sleep(1)
    end

    -- РУЧНОЙ ЛОГИН
    while true do
        term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
        print("=== SOLDIER LOGIN ===")
        write("ID (e.g. ST): "); local inputID = string.upper(read())
        write("Password: "); local inputPass = read("*")
        
        if not serverID then serverID = rednet.lookup(PROTOCOL, "central_core") end
        
        if serverID then
            sendEncrypted({type="LOGIN", userID=inputID, userPass=inputPass, role="soldier"})
            local _, msg = receiveEncrypted(3)
            
            if msg and msg.type == "AUTH_OK" then
                myProfile = msg.profile
                myToken = msg.token
                
                -- Сохраняем только креды для автологина
                local cleanJson = textutils.serialize({id=inputID, pass=inputPass})
                local encryptedData = crypt(cleanJson, KEY)
                local f = fs.open("session.dat", "w")
                f.write(encryptedData)
                f.close()
                return
            else
                print("Error: Access Denied")
                sleep(2)
            end
        else
            print("Server Offline")
            sleep(2)
        end
    end
end

login()

-- === UI ===
local activeTab = "TACTICAL"
local menuState = "MAIN"
local logHistory = {}

local function addLog(text, color)
    local t = textutils.formatTime(os.time(), true)
    table.insert(logHistory, {text=text, color=color or colors.green, time=t})
    if #logHistory > 8 then table.remove(logHistory, 1) end
end

local function sendPacket(text)
    -- Отправляем как SQUAD_REPORT с токеном
    sendEncrypted({
        type = "SQUAD_REPORT", 
        userID = myProfile.id, 
        token = myToken, 
        squad = myProfile.squad,
        text = text
    })
    addLog("ME: " .. text, colors.white)
end

local function drawUI()
    local w, h = term.getSize()
    term.setCursorPos(1,1)
    if activeTab == "TACTICAL" then
        term.setBackgroundColor(colors.blue); term.setTextColor(colors.white); write(" TACTICAL ")
        term.setBackgroundColor(colors.gray); term.setTextColor(colors.lightGray); write(" PROFILE ")
    else
        term.setBackgroundColor(colors.gray); term.setTextColor(colors.lightGray); write(" TACTICAL ")
        term.setBackgroundColor(colors.blue); term.setTextColor(colors.white); write(" PROFILE ")
    end
    term.setBackgroundColor(colors.gray)
    write(string.rep(" ", w - 18))
    local timeStr = textutils.formatTime(os.time(), true)
    term.setCursorPos(w - #timeStr + 1, 1)
    term.setTextColor(colors.white); write(timeStr)
    
    if activeTab == "TACTICAL" then
        paintutils.drawFilledBox(1, 2, w, h, colors.black)
        term.setCursorPos(1, 2); term.setTextColor(colors.yellow)
        print("OBJ: " .. string.sub(currentObj, 1, w-5))
        
        if menuState == "MAIN" then
            local y = 4
            for _, item in ipairs(logHistory) do
                if y < h-3 then
                    term.setCursorPos(1, y); term.setTextColor(item.color)
                    print(item.text); y = y + 1
                end
            end
            local btnY = h-2
            paintutils.drawFilledBox(1, btnY, w/2, h-1, colors.red)
            term.setCursorPos(2, btnY); term.setTextColor(colors.white); term.setBackgroundColor(colors.red); write("1.ALERTS")
            paintutils.drawFilledBox(w/2+1, btnY, w, h-1, colors.blue)
            term.setCursorPos(w/2+2, btnY); term.setBackgroundColor(colors.blue); write("2.MSG")
            term.setBackgroundColor(colors.black); term.setTextColor(colors.gray); term.setCursorPos(1, h); write("TAB: Switch Tab")
            
        elseif menuState == "ALERTS" then
            term.setCursorPos(1, 4); term.setTextColor(colors.white); print("SELECT ALERT:")
            term.setTextColor(colors.cyan); print(" 1. REQUEST..")
            term.setTextColor(colors.magenta); print(" 2. INJURY (S.O.S)")
            term.setTextColor(colors.orange); print(" 3. CAPTURE..")
            term.setTextColor(colors.red); print(" 4. CONTACT..")
            print(""); term.setTextColor(colors.lightGray); print(" 5. < BACK")
        end
    else
        paintutils.drawFilledBox(1, 2, w, h, colors.white)
        term.setTextColor(colors.black); term.setBackgroundColor(colors.white)
        term.setCursorPos(2, 4); print("NAME:   " .. myProfile.name)
        term.setCursorPos(2, 5); print("RANK:   " .. myProfile.rank)
        term.setCursorPos(2, 6); print("NATION: " .. myProfile.nation)
        term.setCursorPos(2, 8); print("ID:     " .. myProfile.id)
        term.setCursorPos(2, 9); print("SQUAD:  " .. myProfile.squad)
        term.setCursorPos(2, h-1); term.setTextColor(colors.red); print("[L] LOGOUT")
    end
end

local function inputLoop()
    while true do
        local event, key = os.pullEvent("key")
        if key == keys.tab then
            if activeTab == "TACTICAL" then activeTab = "PROFILE" else activeTab = "TACTICAL" end
            if activeTab == "TACTICAL" then menuState = "MAIN" end
            drawUI()
        elseif activeTab == "TACTICAL" then
            if menuState == "MAIN" then
                if key == keys.one then menuState = "ALERTS"; drawUI()
                elseif key == keys.two then
                    local txt = promptInput("MSG: ")
                    if txt ~= "" then sendPacket(txt) end
                    drawUI()
                end
            elseif menuState == "ALERTS" then
                if key == keys.one then local t=promptInput("REQ: "); if t~="" then sendPacket("REQ: "..t) end; menuState="MAIN"
                elseif key == keys.two then sendPacket("CRITICAL INJURY!"); menuState="MAIN"
                elseif key == keys.three then local t=promptInput("CAP: "); if t~="" then sendPacket("CAPTURING "..t) end; menuState="MAIN"
                elseif key == keys.four then local t=promptInput("LOC: "); if t~="" then sendPacket("CONTACT: "..t) end; menuState="MAIN"
                elseif key == keys.five then menuState = "MAIN" end
                drawUI()
            end
        elseif activeTab == "PROFILE" and key == keys.l then
            fs.delete("session.dat"); os.reboot()
        end
    end
end

local function netLoop()
    while true do
        local id, msg = receiveEncrypted(1)
        if msg and msg.type == "CHAT_LINE" then
            local show = false
            if msg.channel == "GLOBAL" then show = true end
            if msg.channel == "SQUAD" and msg.targetSquad == myProfile.squad then show = true end
            
            if show then
                if msg.channel == "GLOBAL" and msg.color == colors.yellow then
                     currentObj = string.gsub(msg.text, "NEW ORDERS: ", "")
                     local s = peripheral.find("speaker"); if s then s.playNote("pling", 3, 24) end
                end
                -- Добавляем префикс от кого пришло сообщение
                local prefix = (msg.from == myProfile.id) and "" or (msg.from .. ": ")
                addLog(prefix .. msg.text, msg.color)
                drawUI()
            end
        elseif not msg then
            drawUI() -- Обновляем часы
        end
    end
end

drawUI()
parallel.waitForAny(inputLoop, netLoop)