-- === MSOS V1.6 (TABLET READY) ===
-- [GRAPHICAL LAUNCHER]

local bgCol = colors.gray
local barCol = colors.black
local txtCol = colors.white

local sysDir = "sys"
local iconDir = fs.combine(sysDir, "icon")
local prDir = "pr"

if not fs.exists(sysDir) then fs.makeDir(sysDir) end
if not fs.exists(iconDir) then fs.makeDir(iconDir) end
if not fs.exists(prDir) then fs.makeDir(prDir) end

local blacklist = {
    ["resistance_core.lua"] = true, ["leader.lua"] = true, ["startup.lua"] = true,
    ["menu.lua"] = true, ["system.lua"] = true, ["install.lua"] = true,
    ["rom"] = true, [".net_config.txt"] = true, [sysDir] = true, [prDir] = true
}

local mode = "HOME"
local programs = {}
local shopItems = {
    {name="Worm", code="4YqH58kM", desc="Tunnel Digger"},
    {name="Chat", code="8i7WjZ6b", desc="Simple Chat"},
    {name="Paint", code="f2819231", desc="Official Paint"}
}

local function generateEntry(filepath)
    local fullName = fs.getName(filepath)
    local rawName = fullName:gsub("%.lua$", "") 
    local iconPath = fs.combine(iconDir, rawName .. ".nfp")
    local hasIcon = fs.exists(iconPath)

    local label = rawName:sub(1,2):upper()
    local color = colors.lightBlue
    if rawName:find("general") then color = colors.red end
    if rawName:find("relay") then color = colors.green end
    
    return {
        name = filepath, shortName = rawName, label = label,
        color = color, icon = hasIcon and iconPath or nil
    }
end

local function autoScan()
    programs = {}
    local rootFiles = fs.list("/")
    for _, file in ipairs(rootFiles) do
        if not blacklist[file] and not fs.isDir(file) and file:find(".lua") then
            table.insert(programs, generateEntry(file))
        end
    end
    if fs.exists(prDir) then
        local prFiles = fs.list(prDir)
        for _, file in ipairs(prFiles) do
            local fullPath = fs.combine(prDir, file)
            if not fs.isDir(fullPath) and file:find(".lua") then
                table.insert(programs, generateEntry(fullPath))
            end
        end
    end
end

local function playBootSequence()
    local w, h = term.getSize()
    term.setBackgroundColor(colors.black); term.clear()
    
    term.setCursorPos(math.floor(w/2) - 2, math.floor(h/2) - 2)
    term.setTextColor(colors.yellow); write("MSOS")
    
    local barW = 14
    local startX = math.floor(w/2) - math.floor(barW/2)
    term.setCursorPos(startX, math.floor(h/2))
    term.setTextColor(colors.gray); write("[" .. string.rep("-", barW-2) .. "]")
    
    term.setTextColor(colors.blue)
    for i = 1, barW-2 do
        term.setCursorPos(startX + i, math.floor(h/2))
        write("#"); sleep(0.05)
    end
    term.setCursorPos(math.floor(w/2) - 3, math.floor(h/2) + 2)
    term.setTextColor(colors.green); write("ONLINE"); sleep(0.5)
end

local function drawHeader()
    local w, h = term.getSize()
    local mid = math.floor(w/2)
    paintutils.drawFilledBox(1, 1, w, 1, barCol)
    term.setCursorPos(2, 1); term.setTextColor(colors.yellow); write("MSOS")
    
    if w >= 35 then
        term.setCursorPos(w-8, 1); term.setTextColor(colors.lightGray)
        write(textutils.formatTime(os.time(), true))
    end
    
    paintutils.drawFilledBox(1, h, mid, h, (mode=="HOME" and colors.blue or colors.gray))
    term.setCursorPos(math.floor(w/4) - 1, h); term.setTextColor(colors.white); write("HOME")
    
    paintutils.drawFilledBox(mid+1, h, w, h, (mode=="SHOP" and colors.green or colors.gray))
    term.setCursorPos(math.floor(w*0.75) - 2, h); write("STORE")
end

local function drawHome()
    local w, h = term.getSize()
    local x, y = 2, 3; local spacing = 8
    
    if #programs == 0 then
        term.setCursorPos(2, 3); term.setTextColor(colors.red); print("No programs found.")
        return
    end

    for i, prog in ipairs(programs) do
        if prog.icon then
            local img = paintutils.loadImage(prog.icon)
            if img then paintutils.drawImage(img, x, y)
            else paintutils.drawFilledBox(x, y, x+6, y+4, prog.color) end
        else
            paintutils.drawFilledBox(x, y, x+6, y+4, prog.color)
            term.setCursorPos(x+2, y+2); term.setBackgroundColor(prog.color)
            term.setTextColor(colors.white); write(prog.label)
        end
        
        term.setBackgroundColor(bgCol); term.setTextColor(txtCol)
        term.setCursorPos(x, y+5)
        write(prog.shortName:sub(1, 7))
        
        prog.clickBounds = {x1=x, y1=y, x2=x+6, y2=y+4}
        
        x = x + spacing
        if x + 6 > w then x = 2; y = y + 7 end
    end
end

local function drawShop()
    local w, h = term.getSize()
    local y = 3
    term.setCursorPos(2, y); term.setTextColor(colors.yellow); print(w < 35 and "STORE" or "MSOS NETWORK STORE")
    y = y + 2
    for i, item in ipairs(shopItems) do
        term.setCursorPos(2, y); term.setBackgroundColor(colors.white); term.setTextColor(colors.black)
        write(" GET ")
        term.setBackgroundColor(bgCol); term.setTextColor(colors.white)
        write(" " .. item.name)
        item.clickBounds = {x1=2, y1=y, x2=6, y2=y}
        y = y + 2
    end
end

local function runProgram(filename)
    if not fs.exists(filename) then return end
    term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
    shell.run("fg", filename)
    term.setBackgroundColor(bgCol); term.clear()
end

local function downloadProgram(item)
    local w, h = term.getSize()
    paintutils.drawFilledBox(5, math.floor(h/2)-2, w-5, math.floor(h/2)+2, colors.blue)
    term.setCursorPos(7, math.floor(h/2)); term.setTextColor(colors.white); term.setBackgroundColor(colors.blue)
    write("Downloading " .. item.name .. "...")
    if not http then return end
    
    local fileName = fs.combine(prDir, item.name..".lua")
    shell.run("pastebin", "get", item.code, fileName)
    autoScan(); sleep(1)
end

playBootSequence()
autoScan()

while true do
    term.setBackgroundColor(bgCol); term.clear()
    drawHeader()
    
    if mode == "HOME" then drawHome() elseif mode == "SHOP" then drawShop() end
    
    local event, button, x, y = os.pullEvent("mouse_click")
    local w, h = term.getSize()
    
    if y == h then
        if x <= math.floor(w/2) then mode = "HOME" else mode = "SHOP" end
    elseif mode == "HOME" then
        for _, prog in ipairs(programs) do
            if prog.clickBounds and x >= prog.clickBounds.x1 and x <= prog.clickBounds.x2 
               and y >= prog.clickBounds.y1 and y <= prog.clickBounds.y2 then
                paintutils.drawFilledBox(prog.clickBounds.x1, prog.clickBounds.y1, prog.clickBounds.x2, prog.clickBounds.y2, colors.white)
                sleep(0.1)
                runProgram(prog.name)
                break
            end
        end
    elseif mode == "SHOP" then
        for _, item in ipairs(shopItems) do
            if item.clickBounds and x >= item.clickBounds.x1 and x <= item.clickBounds.x2 and y == item.clickBounds.y1 then
               downloadProgram(item) 
            end
        end
    end
end