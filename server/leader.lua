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
-- === COMMANDER TABLET V14.3 (Tactical Markers) ===
-- [ENCRYPTION CLIENT]
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
    PROTOCOL = f.readLine(); KEY = f.readLine(); f.close()
end

local serverID = rednet.lookup(PROTOCOL, "central_core")
local myProfile = nil
local myToken = nil
local currentObj = "Wait..."

local function sendEncrypted(data)
    if not serverID then return false end
    local payload = textutils.serialize(data)
    rednet.send(serverID, crypt(payload, KEY), PROTOCOL)
    return true
end

local function receiveEncrypted(timeout)
    local id, msg = rednet.receive(PROTOCOL, timeout)
    if type(msg) == "string" then
        return id, textutils.unserialize(crypt(msg, KEY))
    end
    return id, nil
end

local function login()
    local msgText = ""
    while true do
        term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
        term.setTextColor(colors.cyan); print("--- COMMAND LINK V14.3 ---"); term.setTextColor(colors.white)
        
        if msgText ~= "" then term.setTextColor(colors.red); print(msgText); term.setTextColor(colors.white) end
        
        write("Commander ID: "); local inputID = string.upper(read())
        write("Password: "); local inputPass = read("*")
        
        serverID = rednet.lookup(PROTOCOL, "central_core")
        
        if serverID then
            sendEncrypted({type="LOGIN", userID=inputID, userPass=inputPass, role="COMMANDER"})
            local id, msg = receiveEncrypted(3)
            
            if msg and msg.type == "AUTH_OK" then
                myProfile = msg.profile
                myToken = msg.token
                return 
            elseif msg and msg.type == "AUTH_FAIL" then
                msgText = "DENIED: " .. (msg.reason or "Unknown")
            else
                msgText = "ERROR: HQ No Response"
            end
        else
            msgText = "ERROR: Server Offline"
        end
    end
end

login()

local squadLogs = {} 
local cmdLogs = {}   
local activeTab = "SQUAD" 

local function addLog(targetTable, text, color)
    table.insert(targetTable, {text=text, color=color})
    if #targetTable > 12 then table.remove(targetTable, 1) end
end

local function drawUI()
    local w, h = term.getSize()
    term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
    
    local function drawTab(name, mode)
        if activeTab == mode then term.setBackgroundColor(colors.blue); term.setTextColor(colors.white)
        else term.setBackgroundColor(colors.gray); term.setTextColor(colors.lightGray) end
        write(" " .. name .. " ")
    end
    
    drawTab("SQD:"..(myProfile.squad or "???"), "SQUAD")
    drawTab("CMD CHAT", "CMD")
    drawTab("PROFILE", "PROFILE")
    term.setBackgroundColor(colors.black) 
    
    if activeTab == "PROFILE" then
        term.setTextColor(colors.white)
        paintutils.drawFilledBox(2, 3, w-1, h-2, colors.gray)
        paintutils.drawFilledBox(3, 4, w-2, h-3, colors.black)
        term.setCursorPos(4, 5); print("NAME:   " .. myProfile.name)
        term.setCursorPos(4, 6); print("RANK:   " .. myProfile.rank)
        term.setCursorPos(4, 9); print("ID:     " .. myProfile.id)
        term.setCursorPos(3, h-2); term.setTextColor(colors.red); print(" [L] LOGOUT ")
        
    else
        term.setCursorPos(1, 2); term.setTextColor(colors.yellow); print("OBJ: " .. currentObj)
        local list = (activeTab == "SQUAD") and squadLogs or cmdLogs
        local y = 4
        for _, msg in ipairs(list) do
            if y < h-1 then
                term.setCursorPos(1, y); term.setTextColor(msg.color); print(msg.text)
                y = y + 1
            end
        end
        term.setCursorPos(1, h); term.setTextColor(colors.gray); write(string.rep("=", w))
        term.setCursorPos(1, h); term.setTextColor(colors.white)
        if activeTab == "SQUAD" then write("[Enter]Msg  [O]rders  [M]arker  [Tab]Next")
        else write("[Enter]Secure Msg  [Tab]Next") end
    end
end

local function netLoop()
    while true do
        local id, msg = receiveEncrypted()
        if msg and msg.type == "CHAT_LINE" then
            if msg.channel == "CMD" then addLog(cmdLogs, msg.from..": "..msg.text, msg.color)
            elseif msg.channel == "GLOBAL" then addLog(squadLogs, "[ALL] "..msg.from..": "..msg.text, msg.color) 
            elseif msg.channel == "SQUAD" and msg.targetSquad == myProfile.squad then
                addLog(squadLogs, msg.from..": "..msg.text, msg.color)
            end
            drawUI()
        end
    end
end

local function inputLoop()
    while true do
        local event, key = os.pullEvent("key")

        if key == keys.tab then
            if activeTab == "SQUAD" then activeTab = "CMD"
            elseif activeTab == "CMD" then activeTab = "PROFILE"
            else activeTab = "SQUAD" end
            drawUI()
            
        elseif activeTab == "PROFILE" and key == keys.l then
            os.reboot()
            
        elseif key == keys.o and activeTab == "SQUAD" then
            term.setCursorPos(1, 12); term.setTextColor(colors.yellow)
            write("SET OBJ: ")
            local txt = read()
            if txt ~= "" then
                sendEncrypted({type="SET_OBJ", userID=myProfile.id, token=myToken, text=txt})
            end
            drawUI()
            
        -- === НОВАЯ ЛОГИКА МАРКЕРОВ ===
        elseif key == keys.m and activeTab == "SQUAD" then
            term.setCursorPos(1, 12); term.setTextColor(colors.magenta)
            write("Front ID: ")
            local fId = read()
            if fId ~= "" then
                write("X: "); local mX = tonumber(read()) or 0
                write("Z: "); local mZ = tonumber(read()) or 0
                write("Type (1=enemy, 2=ally, 3=obj): ")
                local tInp = read()
                local mType = "note"
                if tInp == "1" then mType = "enemy"
                elseif tInp == "2" then mType = "ally"
                elseif tInp == "3" then mType = "objective" end
                
                sendEncrypted({
                    type = "MAP_ADD_MARKER",
                    userID = myProfile.id,
                    token = myToken,
                    frontId = string.lower(fId),
                    x = mX, z = mZ,
                    markerType = mType,
                    label = "HQ Update"
                })
                addLog(cmdLogs, "MARKER SENT TO " .. string.upper(fId), colors.magenta)
            end
            drawUI()
            
        elseif key == keys.enter then
            term.setCursorPos(1, 12)
            if activeTab == "SQUAD" then
                term.setTextColor(colors.green)
                write("TO " .. myProfile.squad .. ": ")
                local txt = read()
                if txt ~= "" then
                    sendEncrypted({type="SQUAD_CMD", userID=myProfile.id, token=myToken, text=txt, squad=myProfile.squad})
                end
            elseif activeTab == "CMD" then
                term.setTextColor(colors.cyan)
                write("TO COMMAND: ")
                local txt = read()
                if txt ~= "" then
                    sendEncrypted({type="CMD_CHAT", userID=myProfile.id, token=myToken, text=txt})
                end
            end
            drawUI()
        end
    end
end

drawUI()
parallel.waitForAny(netLoop, inputLoop)