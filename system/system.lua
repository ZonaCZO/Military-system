-- === MSOS V1.5 ===
-- [GRAPHICAL LAUNCHER]

local bgCol = colors.gray
local barCol = colors.black
local txtCol = colors.white

-- === НАСТРОЙКИ ===
local sysDir = "sys"
local iconDir = fs.combine(sysDir, "icon") -- Папка иконок
local prDir = "pr"

if not fs.exists(sysDir) then fs.makeDir(sysDir) end
if not fs.exists(iconDir) then fs.makeDir(iconDir) end
if not fs.exists(prDir) then fs.makeDir(prDir) end

local programFile = fs.combine(sysDir, "programs.db")

-- Файлы для игнора
local blacklist = {
    ["resistance_core.lua"] = true,
    ["leader.lua"] = true,
    ["startup.lua"] = true,
    ["menu.lua"] = true,
    ["system.lua"] = true,
    ["install.lua"] = true,
    ["rom"] = true,
    [".net_config.txt"] = true,
    [sysDir] = true,
    [prDir] = true
}

local mode = "HOME"
local programs = {}
local shopItems = {
    {name="Worm", code="4YqH58kM", desc="Tunnel Digger"},
    {name="Chat", code="8i7WjZ6b", desc="Simple Chat"},
    {name="Paint", code="f2819231", desc="Official Paint"}
}

-- === УПРАВЛЕНИЕ ===

local function savePrograms()
    local f = fs.open(programFile, "w")
    f.write(textutils.serialize(programs))
    f.close()
end

local function generateEntry(filepath)
    local fullName = fs.getName(filepath)
    -- Убираем расширение .lua для чистого имени
    local rawName = fullName:gsub("%.lua$", "") 
    
    -- Ищем иконку в папке sys/icon/ с таким же именем + .nfp
    local iconPath = fs.combine(iconDir, rawName .. ".nfp")
    local hasIcon = fs.exists(iconPath)

    -- Стандартная генерация (цвета для квадратов, если нет иконки)
    local label = rawName:sub(1,2):upper()
    local color = colors.lightBlue
    if rawName:find("general") then color = colors.red end
    if rawName:find("relay") then color = colors.green end
    
    return {
        name = filepath,    -- Полный путь (pr/general.lua)
        shortName = rawName, -- Чистое имя (general)
        label = label,
        color = color,
        icon = hasIcon and iconPath or nil -- Путь к иконке (sys/icon/general.nfp)
    }
end

local function autoScan()
    programs = {}
    
    -- 1. Корень
    local rootFiles = fs.list("/")
    for _, file in ipairs(rootFiles) do
        if not blacklist[file] and not fs.isDir(file) and file:find(".lua") then
            table.insert(programs, generateEntry(file))
        end
    end
    
    -- 2. Папка PR
    if fs.exists(prDir) then
        local prFiles = fs.list(prDir)
        for _, file in ipairs(prFiles) do
            local fullPath = fs.combine(prDir, file)
            if not fs.isDir(fullPath) and file:find(".lua") then
                table.insert(programs, generateEntry(fullPath))
            end
        end
    end
    
    savePrograms()
end

local function loadPrograms()
    if fs.exists(programFile) then
        local f = fs.open(programFile, "r")
        local data = f.readAll()
        f.close()
        programs = textutils.unserialize(data)
        if not programs then autoScan() end
    else
        autoScan()
    end
end

-- === ЗАГРУЗКА (BOOT SCREEN) ===
local function playBootSequence()
    local w, h = term.getSize()
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- Логотип
    term.setCursorPos(w/2 - 2, h/2 - 2)
    term.setTextColor(colors.yellow)
    write("MSOS")
    
    -- Рамка прогресса
    local barW = 14
    local startX = w/2 - barW/2
    term.setCursorPos(startX, h/2)
    term.setTextColor(colors.gray)
    write("[" .. string.rep("-", barW-2) .. "]")
    
    -- Анимация заполнения
    term.setTextColor(colors.blue)
    for i = 1, barW-2 do
        term.setCursorPos(startX + i, h/2)
        write("#")
        sleep(0.05)
    end
    
    term.setCursorPos(w/2 - 3, h/2 + 2)
    term.setTextColor(colors.green)
    write("ONLINE")
    sleep(0.5)
end

-- === ОТРИСОВКА ===
local function drawHeader()
    local w, h = term.getSize()
    paintutils.drawFilledBox(1, 1, w, 1, barCol)
    term.setCursorPos(2, 1)
    term.setTextColor(colors.yellow)
    write("MSOS")
    
    term.setCursorPos(w-8, 1)
    term.setTextColor(colors.lightGray)
    write(textutils.formatTime(os.time(), true))
    
    paintutils.drawFilledBox(1, h, w/2, h, (mode=="HOME" and colors.blue or colors.gray))
    term.setCursorPos(w/4 - 2, h)
    term.setTextColor(colors.white)
    write("HOME")
    
    paintutils.drawFilledBox(w/2+1, h, w, h, (mode=="SHOP" and colors.green or colors.gray))
    term.setCursorPos(w*0.75 - 2, h)
    write("STORE")
end

local function drawHome()
    local w, h = term.getSize()
    local x, y = 2, 3
    local spacing = 8
    
    if #programs == 0 then
        term.setCursorPos(2, 3); term.setTextColor(colors.red); print("No programs found.")
        return
    end

    for i, prog in ipairs(programs) do
        -- ЕСЛИ ЕСТЬ ИКОНКА - РИСУЕМ ЕЁ
        if prog.icon then
            local img = paintutils.loadImage(prog.icon)
            if img then
                paintutils.drawImage(img, x, y)
            else
                -- Если файл картинки поврежден
                paintutils.drawFilledBox(x, y, x+6, y+4, prog.color)
            end
        else
            -- ИНАЧЕ РИСУЕМ ОБЫЧНЫЙ КВАДРАТ
            paintutils.drawFilledBox(x, y, x+6, y+4, prog.color)
            term.setCursorPos(x+2, y+2)
            term.setBackgroundColor(prog.color)
            term.setTextColor(colors.white)
            write(prog.label)
        end
        
        -- Подпись (без .lua)
        term.setBackgroundColor(bgCol)
        term.setTextColor(txtCol)
        term.setCursorPos(x, y+5)
        local displayName = prog.shortName:sub(1, 7) -- Показываем до 7 букв
        write(displayName)
        
        prog.clickBounds = {x1=x, y1=y, x2=x+6, y2=y+4}
        
        x = x + spacing
        if x + 6 > w then x = 2; y = y + 7 end
    end
end

local function drawShop()
    local w, h = term.getSize()
    local y = 3
    term.setCursorPos(2, y); term.setTextColor(colors.yellow); print("MSOS NETWORK STORE")
    y = y + 2
    for i, item in ipairs(shopItems) do
        term.setCursorPos(2, y); term.setBackgroundColor(colors.white); term.setTextColor(colors.black)
        write(" GET ")
        term.setBackgroundColor(bgCol); term.setTextColor(colors.white)
        write(" " .. item.name .. " - " .. item.desc)
        item.clickBounds = {x1=2, y1=y, x2=6, y2=y}
        y = y + 2
    end
end

-- === ЛОГИКА ===
local function runProgram(filename)
    if not fs.exists(filename) then
        term.setBackgroundColor(bgCol); term.clear(); print("File missing!"); sleep(1); autoScan(); return
    end
    term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
    shell.run("fg", filename)
    term.setBackgroundColor(bgCol); term.clear()
end

local function downloadProgram(item)
    local w, h = term.getSize()
    paintutils.drawFilledBox(5, h/2-2, w-5, h/2+2, colors.blue)
    term.setCursorPos(7, h/2); term.setTextColor(colors.white); term.setBackgroundColor(colors.blue)
    write("Downloading " .. item.name .. "...")
    if not http then return end
    
    local fileName = fs.combine(prDir, item.name..".lua")
    shell.run("pastebin", "get", item.code, fileName)
    
    autoScan() -- Обновляем, чтобы найти и программу, и (если повезет) иконку
    sleep(1)
end

-- === MAIN LOOP ===
playBootSequence()
loadPrograms()

while true do
    term.setBackgroundColor(bgCol)
    term.clear()
    drawHeader()
    
    if mode == "HOME" then drawHome()
    elseif mode == "SHOP" then drawShop() end
    
    local event, button, x, y = os.pullEvent("mouse_click")
    local w, h = term.getSize()
    
    if y == h then
        if x < w/2 then mode = "HOME" else mode = "SHOP" end
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