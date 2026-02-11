-- === TACTICAL PDA DEPLOYMENT TOOL ===
-- [Installs Tracker & Rebel via Network]

local pdaFiles = {
    {name = "tracker.lua", id = "bWqPWJjc"},
    {name = "rebel.lua",   id = "yXnA1kc2"}
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
    -- Если дисковода нет, ставим на само устройство (для ручного обновления)
    print("No Disk Drive found. Installing to local system...")
    print("Proceed? (y/n)")
    if read() ~= "y" then error("Aborted.") end
    
    for _, file in ipairs(pdaFiles) do
        print("Downloading " .. file.name .. "...")
        shell.run("pastebin", "get", file.id, file.name)
    end
    
    -- Создаем стартап для солдата
    local f = fs.open("startup.lua", "w")
    s.write('shell.run("background tracker.lua")')
    f.write('shell.run("rebel.lua")')
    f.close()
    
    print("Done. Rebooting.")
    sleep(1)
    os.reboot()
else
    -- Режим "Фабрики КПК" (через дисковод)
    while true do
        term.clear()
        print("=== PDA FACTORY (NET-INSTALL) ===")
        print("Insert Disk/PDA into drive...")
        
        while not disk.isPresent(driveSide) do sleep(0.5) end
        
        local path = disk.getMountPath(driveSide)
        print("Drive detected at: " .. path)
        print("Wiping old data...")
        
        -- Очистка диска
        local list = fs.list(path)
        for _, file in ipairs(list) do
            fs.delete(fs.combine(path, file))
        end
        
        -- Скачивание файлов прямо на диск
        print("Installing firmware...")
        for _, file in ipairs(pdaFiles) do
            local fullPath = fs.combine(path, file.name)
            print(" -> " .. file.name)
            -- Используем shell.run, но перемещаем файл после скачивания
            -- Или скачиваем во временную папку и копируем
            shell.run("pastebin", "get", file.id, "temp_file")
            fs.move("temp_file", fullPath)
        end
        
        -- Создание startup на диске
        local s = fs.open(fs.combine(path, "startup.lua"), "w")
        s.write('shell.run("background tracker.lua")')
        s.write('shell.run("rebel.lua")')
        s.close()
        
        disk.setLabel(driveSide, "NIPAYA PDA")
        term.setTextColor(colors.green)
        print("\nINSTALLATION COMPLETE.")
        term.setTextColor(colors.white)
        print("Ejecting...")
        disk.eject(driveSide)
        sleep(2)
    end
end