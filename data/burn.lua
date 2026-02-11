-- === DISK BURNER v2.0 ===
-- Создание установочных дискет

local function clearScreen()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1,1)
end

local function drawHeader()
    clearScreen()
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.clearLine()
    print(" DISK FACTORY ")
    term.setBackgroundColor(colors.black)
end

-- Получение списка файлов на дискете
local function listDisk()
    term.setCursorPos(1, 3)
    term.setTextColor(colors.yellow)
    print("--- DISK CONTENTS ---")
    term.setTextColor(colors.white)

    if not fs.exists("disk") then
        term.setTextColor(colors.red)
        print("NO DISK DETECTED!")
        return false
    end

    local files = fs.list("disk")
    if #files == 0 then
        print("(Empty)")
    else
        for _, file in pairs(files) do
            local label = "- " .. file
            if file == "startup" then label = label .. " (Auto-Run)" end
            if file == "install" then label = label .. " (Installer)" end
            print(label)
        end
    end
    
    -- Показать метку диска
    local label = disk.getLabel("disk")
    term.setCursorPos(1, 10)
    term.setTextColor(colors.gray)
    if label then 
        print("Label: " .. label) 
    else 
        print("Label: [None]") 
    end
    
    return true
end

-- Функция создания установщика (install) на дискете
local function createInstaller()
    local handle = fs.open("disk/install", "w")
    handle.writeLine("-- Installer Script")
    handle.writeLine("print('Installing...')")
    
    local files = fs.list("disk")
    for _, file in pairs(files) do
        if file ~= "install" and file ~= "startup" then
            -- Пишем код, который скопирует файл с диска на комп
            handle.writeLine("if fs.exists('"..file.."') then fs.delete('"..file.."') end")
            handle.writeLine("fs.copy('disk/"..file.."', '"..file.."')")
            handle.writeLine("print('+ Installed: "..file.."')")
        end
    end
    
    handle.writeLine("print('Done! Rebooting...')")
    handle.writeLine("sleep(1)")
    handle.writeLine("os.reboot()")
    handle.close()
    print("Installer script created at disk/install")
end

-- ГЛАВНЫЙ ЦИКЛ
while true do
    drawHeader()
    local hasDisk = listDisk()
    
    local w, h = term.getSize()
    term.setCursorPos(1, h-6)
    term.setTextColor(colors.gray)
    print("COMMANDS:")
    term.setTextColor(colors.white)
    print(" add <file>    - Copy file to disk")
    print(" label <name>  - Rename disk")
    print(" make install  - Create installer script")
    print(" wipe          - Format disk")
    print(" exit          - Quit")
    print("")
    
    term.setCursorPos(1, h-1)
    term.setTextColor(colors.yellow)
    write("> ")
    term.setTextColor(colors.white)
    
    local input = read()
    local cmd = string.match(input, "^(%S+)") -- Первое слово
    local arg = string.match(input, "^%S+%s+(.+)") -- Всё остальное после пробела
    
    if cmd == "exit" then
        break
        
    elseif cmd == "wipe" and hasDisk then
        print("Formatting...")
        local list = fs.list("disk")
        for _, f in pairs(list) do fs.delete("disk/"..f) end
        sleep(0.5)
        
    elseif cmd == "label" and hasDisk and arg then
        disk.setLabel("disk", arg)
        print("Label set.")
        sleep(0.5)
        
    elseif cmd == "add" and hasDisk and arg then
        if fs.exists(arg) then
            local dest = fs.getName(arg) -- Убирает путь, оставляет имя файла
            fs.copy(arg, "disk/"..dest)
            print("Copied.")
        else
            term.setTextColor(colors.red)
            print("File not found on PC!")
            term.setTextColor(colors.white)
            sleep(1)
        end
        sleep(0.5)
        
    elseif input == "make install" and hasDisk then
        createInstaller()
        sleep(1)
        
    elseif cmd then
        print("Unknown command.")
        sleep(0.5)
    end
end

clearScreen()