-- ==========================================
-- === CYRILLIC KEYBOARD DRIVER ===
-- ==========================================
local LOCALE = 'RU'

local function handle_keypress()
  local evt, key
  repeat
    repeat evt, key = os.pullEvent() until evt == "key" or evt == "key_up"
    if evt == "key_up" then return -key end
    os.queueEvent("placeholder")
    local char_queued = false
    parallel.waitForAny(
      function() os.pullEvent("char"); char_queued = true end,
      function() os.pullEvent("placeholder") end
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
  locale_map[31] = string.char(0xB3); locale_map[39] = string.char(0xBA); locale_map[93] = string.char(0xBF); locale_map[43] = string.char(0xB4)
  locale_map_shifted[31] = string.char(0xB2); locale_map_shifted[39] = string.char(0xAA); locale_map_shifted[93] = string.char(0xAF); locale_map_shifted[43] = string.char(0xA5)
elseif string.lower(LOCALE) == 'by' then
  locale_map[31] = string.char(0xB3); locale_map[24] = string.char(0xA2); locale_map[93] = "'"
  locale_map_shifted[31] = string.char(0xB2); locale_map_shifted[24] = string.char(0xA1); locale_map_shifted[93] = "'"
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
    if env.__redrun_coroutines then coroutines = env.__redrun_coroutines
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
    local id = #coroutines+1; coroutines[id] = {coro = coroutine.create(func), name = name}; return id
end
redrun.init()
redrun.start(cyrrun, 'cyrrun')

-- ==========================================
-- === GENERAL TERMINAL V14.2 (RC4 + INTEL) ===
-- [HIGH COMMAND ACCESS]
-- ==========================================

local modem = peripheral.find("modem")
if not modem then error("No Wireless Modem!") end
rednet.open(peripheral.getName(modem))

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

local PROTOCOL = "default_net"
local KEY = "none"
local netFile = ".net_config.txt"

if fs.exists(netFile) then
    local f = fs.open(netFile, "r")
    PROTOCOL = f.readLine(); KEY = f.readLine(); f.close()
    if not KEY then KEY = "none" end
else
    term.clear(); term.setCursorPos(1,1)
    print("--- GENERAL LINK SETUP ---")
    write("Network ID: "); local input = read()
    if input ~= "" then PROTOCOL = input end
    write("Encryption Key: "); local kInp = read()
    if kInp ~= "" then KEY = kInp end
    local f = fs.open(netFile, "w"); f.writeLine(PROTOCOL); f.writeLine(KEY); f.close()
end

local serverID = rednet.lookup(PROTOCOL, "central_core")
local myProfile = nil
local myToken = nil
local currentObj = "Wait..."

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

local function login()
    local msgText = ""
    while true do
        term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
        term.setTextColor(colors.red); print("/// HIGH COMMAND TERMINAL ///"); term.setTextColor(colors.white)
        
        if msgText ~= "" then term.setTextColor(colors.red); print(msgText); term.setTextColor(colors.white) end
        
        write("General ID: "); local inputID = string.upper(read())
        write("Password: "); local inputPass = read("*")
        
        if not serverID then serverID = rednet.lookup(PROTOCOL, "central_core") end
        
        sendEncrypted({type="LOGIN", userID=inputID, userPass=inputPass, role="GENERAL"})
        local id, msg = receiveEncrypted(3)
        
        if msg and msg.type == "AUTH_OK" then
            myProfile = msg.profile
            myToken = msg.token
            return 
        elseif msg and msg.type == "AUTH_FAIL" then
            msgText = "ACCESS DENIED: " .. (msg.reason or "Unknown")
        else
            msgText = "ERROR: Server Unreachable or Key Mismatch"
        end
    end
end

login()

local cmdLogs = {}
local globalLogs = {}
local archiveLogs = {}
local currentArchiveChannel = "NONE"
local activeTab = "CMD" 

local function addLog(targetTable, text, color)
    table.insert(targetTable, {text=text, color=color})
    if #targetTable > 12 then table.remove(targetTable, 1) end
end

local function drawUI()
    local w, h = term.getSize()
    term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
    
    local function drawTab(name, mode)
        if activeTab == mode then
            term.setBackgroundColor(colors.red); term.setTextColor(colors.white)
        else
            term.setBackgroundColor(colors.gray); term.setTextColor(colors.lightGray)
        end
        write(" " .. name .. " ")
    end
    
    drawTab("WAR ROOM", "CMD")
    drawTab("LIVE FEED", "GLOBAL")
    drawTab("INTEL", "INTEL")
    drawTab("CONTROL", "CONTROL")
    term.setBackgroundColor(colors.black) 
    
    if activeTab == "CONTROL" then
        term.setTextColor(colors.white)
        paintutils.drawFilledBox(2, 3, w-1, h-2, colors.gray)
        paintutils.drawFilledBox(3, 4, w-2, h-3, colors.black)
        term.setCursorPos(4, 5); print("GENERAL: " .. myProfile.name)
        term.setCursorPos(4, 6); print("STATUS:  ACTIVE COMMAND")
        term.setCursorPos(4, 8); term.setTextColor(colors.yellow); print("[O] CHANGE OBJECTIVE")
        term.setCursorPos(4, 10); term.setTextColor(colors.red); print("[A] BROADCAST ALERT")
        term.setCursorPos(3, h-2); term.setTextColor(colors.red); print(" [L] LOGOUT ")
        
    elseif activeTab == "INTEL" then
        term.setCursorPos(1, 2); term.setTextColor(colors.cyan); print("DATABASE: " .. currentArchiveChannel)
        local y = 4
        if #archiveLogs == 0 then
            term.setCursorPos(1, y); term.setTextColor(colors.gray); print("< No Data or Awaiting Sync >")
        end
        for _, msg in ipairs(archiveLogs) do
            if y < h-1 then
                term.setCursorPos(1, y); term.setTextColor(colors.lightGray)
                local timeStr = os.date("%H:%M", math.floor((msg.time or 0) / 1000))
                write("["..timeStr.."] ")
                term.setTextColor(colors.white)
                print(msg.from .. ": " .. msg.text)
                y = y + 1
            end
        end
        term.setCursorPos(1, h); term.setTextColor(colors.red); write(string.rep("=", w))
        term.setCursorPos(1, h); term.setTextColor(colors.white)
        write("[Enter] Query Channel  [Tab] Switch")

    else
        term.setCursorPos(1, 2); term.setTextColor(colors.red); print("OBJ: " .. currentObj)
        local list = (activeTab == "CMD") and cmdLogs or globalLogs
        local y = 4
        if #list == 0 then term.setCursorPos(1, 4); term.setTextColor(colors.gray); print("<No Data>") end
        for _, msg in ipairs(list) do
            if y < h-1 then
                term.setCursorPos(1, y); term.setTextColor(msg.color); print(msg.text)
                y = y + 1
            end
        end
        term.setCursorPos(1, h); term.setTextColor(colors.red); write(string.rep("=", w))
        term.setCursorPos(1, h); term.setTextColor(colors.white)
        if activeTab == "CMD" then write("[Enter] Command Chat  [Tab] Switch")
        else write("Monitoring only...    [Tab] Switch") end
    end
end

local function netLoop()
    while true do
        local id, msg = receiveEncrypted()
        if msg then
            if msg.type == "CHAT_LINE" then
                if msg.channel == "CMD" or msg.alert then
                    local s = peripheral.find("speaker"); if s then s.playNote("hat", 1, 10) end
                end
                if msg.channel == "CMD" then 
                    addLog(cmdLogs, msg.from .. ": " .. msg.text, msg.color)
                else
                    addLog(globalLogs, "[".. (msg.targetSquad or "ALL") .."] " .. msg.from .. ": " .. msg.text, msg.color)
                end
                drawUI()
                
            elseif msg.type == "LOG_DATA" then
                currentArchiveChannel = msg.channel
                archiveLogs = msg.data.messages or {}
                drawUI()
            end
        end
    end
end

local function inputLoop()
    while true do
        local event, key = os.pullEvent("key")
        local w, h = term.getSize()

        if key == keys.tab then
            if activeTab == "CMD" then activeTab = "GLOBAL"
            elseif activeTab == "GLOBAL" then activeTab = "INTEL"
            elseif activeTab == "INTEL" then activeTab = "CONTROL"
            else activeTab = "CMD" end
            drawUI()
            
        elseif activeTab == "CONTROL" then
            if key == keys.l then
                os.reboot()
            end

        elseif activeTab == "INTEL" and key == keys.enter then
            term.setCursorPos(1, h-1); term.setBackgroundColor(colors.black); term.setTextColor(colors.yellow)
            write(" CHANNEL (e.g. SQD_ALPHA or CMD): ")
            local chan = read()
            if chan ~= "" then
                archiveLogs = {} 
                sendEncrypted({
                    type = "GET_LOGS",
                    userID = myProfile.id,
                    token = myToken,
                    channel = string.upper(chan)
                })
            end
            drawUI()

        elseif activeTab == "CMD" and key == keys.enter then
            term.setCursorPos(1, h-1); term.setTextColor(colors.red)
            write(" COMMAND: ")
            local txt = read()
            if txt ~= "" then
                sendEncrypted({type="CMD_CHAT", userID=myProfile.id, token=myToken, text=txt})
            end
            drawUI()
        end
    end
end

drawUI()
parallel.waitForAny(netLoop, inputLoop)