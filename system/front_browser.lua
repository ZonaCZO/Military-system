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
-- === FRONT COMMAND CENTER V14.2 ===
-- [SECURE PC INTERFACE]
-- ==========================================

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
    term.setBackgroundColor(colors.gray); term.clear()
    
    paintutils.drawFilledBox(1, 1, w, 1, colors.black)
    term.setCursorPos(2, 1); term.setTextColor(colors.yellow)
    write("STRATEGIC MAP: FRONTS")
    
    if isLoading then
        term.setCursorPos(w/2 - 5, h/2); term.setTextColor(colors.white); term.setBackgroundColor(colors.gray)
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
                        term.setBackgroundColor(colors.blue); term.setTextColor(colors.white)
                    else
                        term.setBackgroundColor(colors.gray); term.setTextColor(colors.lightGray)
                    end
                    term.setCursorPos(2, y)
                    local line = string.format("[%s] %s (%s)", front.id, front.name, front.type)
                    write(line .. string.rep(" ", w - #line - 1))
                end
            end
        end
        
        term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
        term.setCursorPos(1, h); write(string.rep(" ", w))
        term.setCursorPos(2, h); write("[Up/Down] Select   [Enter] Details   [R] Refresh   [Q] Exit")
        
    elseif mode == "DETAILS" then
        local front = fronts[selectedIndex]
        if not front then mode = "LIST"; return end
        
        paintutils.drawFilledBox(2, 3, w-1, h-2, colors.black)
        term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
        
        term.setCursorPos(3, 4); term.setTextColor(colors.cyan); write("FRONT: " .. front.name)
        term.setCursorPos(3, 5); term.setTextColor(colors.lightGray); write("ID: " .. front.id .. " | TYPE: " .. front.type)
        
        term.setCursorPos(3, 7); term.setTextColor(colors.yellow); write("DESCRIPTION:")
        term.setCursorPos(3, 8); term.setTextColor(colors.white); write(front.description ~= "" and front.description or "No description provided.")
        
        term.setCursorPos(3, 10); term.setTextColor(colors.orange); write("MARKERS: " .. #(front.markers or {}))
        term.setCursorPos(3, 11); term.setTextColor(colors.green); write("PLANS ATTACHED: " .. #(front.plans or {}))
        
        term.setBackgroundColor(colors.black); term.setTextColor(colors.white)
        term.setCursorPos(1, h); write(string.rep(" ", w))
        term.setCursorPos(2, h); write("[Backspace] Back to List   [Q] Exit")
    end
end

-- === INPUT LOOP ===
local function inputLoop()
    while true do
        local event, key = os.pullEvent("key")
        local w, h = term.getSize()
        
        if mode == "LIST" then
            if key == keys.up and selectedIndex > 1 then
                selectedIndex = selectedIndex - 1; drawUI()
            elseif key == keys.down and selectedIndex < #fronts then
                selectedIndex = selectedIndex + 1; drawUI()
            elseif key == keys.enter and #fronts > 0 then
                mode = "DETAILS"; drawUI()
            elseif key == keys.r then
                fetchFronts(); drawUI()
            elseif key == keys.q then
                term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
                return 
            end
        elseif mode == "DETAILS" then
            if key == keys.backspace then
                mode = "LIST"; drawUI()
            elseif key == keys.q then
                term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
                return
            end
        end
    end
end

term.clear()
fetchFronts()
drawUI()
inputLoop()