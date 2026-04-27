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
-- === STRATEGIC PLAN BROWSER V1.0 ===
-- [SECURE HQ TERMINAL]
-- ==========================================

local modem = peripheral.find("modem")
if not modem then error("No wireless modem found!") end
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

if fs.exists(".net_config.txt") then
    local f = fs.open(".net_config.txt", "r")
    PROTOCOL = f.readLine(); KEY = f.readLine(); f.close()
end

local serverID = rednet.lookup(PROTOCOL, "central_core")
local myProfile = nil
local myToken = nil

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

local plans = {}
local currentPlan = nil
local mode = "LIST" 
local listIndex = 1
local stageIndex = 1
local isLoading = false
local statusMsg = ""

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

local function drawUI()
    local w, h = term.getSize()
    term.setBackgroundColor(colors.gray); term.clear()
    
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