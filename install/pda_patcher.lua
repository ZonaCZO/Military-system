-- === TACTICAL PDA DEPLOYMENT TOOL (GITHUB) ===
-- [Installs Tracker & Rebel via GitHub]

-- Используем RAW ссылки, чтобы скачать чистый код, а не веб-страницу
local pdaFiles = {
    {
        name = "tracker.lua", 
        url = "https://raw.githubusercontent.com/ZonaCZO/Military-system/main/patch/tracker.lua"
    },
    {
        name = "rebel.lua",   
        url = "https://raw.githubusercontent.com/ZonaCZO/Military-system/main/patch/rebel.lua"
    }
}

local driveSide = nil

-- Поиск дисковода
for _, side in ipairs(rs.getSides()) do
    if peripheral.getType(side) == "drive" then
        driveSide = side
        break
    end
end

if not driveSide then
    -- === ЛОКАЛЬНАЯ УСТАНОВКА (ЕСЛИ НЕТ ДИСКОВОДА) ===
    term.clear()
    term.setCursorPos(1,1)
    print("No Disk Drive found.")
    print("Installing to THIS device...")
    print("Proceed? (y/n)")
    if read() ~= "y" then error("Aborted.") end
    
    for _, file in ipairs(pdaFiles) do
        print("Downloading " .. file.name .. "...")
        -- Удаляем старый файл, если есть
        if fs.exists(file.name) then fs.delete(file.name) end
        -- Скачиваем новый через wget
        shell.run("wget", file.url, file.name)
    end
    
    -- Создаем стартап локально
    print("Configuring startup...")
    local f = fs.open("startup.lua", "w")
    f.writeLine('shell.run("bg tracker.lua")') -- Запуск трекера в фоне
    f.writeLine('shell.run("rebel.lua")')      -- Запуск основной программы
    f.close()
    
    print("Done. Rebooting...")
    sleep(1)
    os.reboot()
else
    -- === ФАБРИКА КПК (ЧЕРЕЗ ДИСКОВОД) ===
    while true do
        term.clear()
        term.setCursorPos(1,1)
        print("=== PDA FACTORY (GITHUB) ===")
        print("Source: ZonaCZO/Military-system")
        print("-----------------------------")
        print("Insert Disk/PDA into drive...")
        
        -- Ждем диск
        while not disk.isPresent(driveSide) do sleep(0.5) end
        
        local path = disk.getMountPath(driveSide)
        print("Drive detected at: " .. path)
        print("Wiping old data...")
        
        -- Полная очистка диска
        local list = fs.list(path)
        for _, file in ipairs(list) do
            fs.delete(fs.combine(path, file))
        end
        
        -- Скачивание файлов
        print("Installing firmware...")
        for _, file in ipairs(pdaFiles) do
            local fullPath = fs.combine(path, file.name)
            print(" -> " .. file.name)
            
            -- Скачиваем во временный файл, потом перемещаем на диск
            -- Это надежнее, чем качать напрямую на диск иногда
            shell.run("wget", file.url, "temp_download")
            
            if fs.exists("temp_download") then
                fs.move("temp_download", fullPath)
            else
                term.setTextColor(colors.red)
                print("Download FAILED for " .. file.name)
                term.setTextColor(colors.white)
                sleep(2)
            end
        end
        
        -- Создание startup на диске
        local s = fs.open(fs.combine(path, "startup.lua"), "w")
        s.writeLine('shell.run("bg tracker.lua")')
        s.writeLine('shell.run("rebel.lua")')
        s.close()
        
        disk.setLabel(driveSide, "NIPAYA PDA")
        term.setTextColor(colors.green)
        print("\nINSTALLATION COMPLETE.")
        term.setTextColor(colors.white)
        print("You may eject the device.")
        
        -- Ждем, пока диск вытащат (или выкидываем сами)
        disk.eject(driveSide)
        sleep(2)
    end
end