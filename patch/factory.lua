-- === NIPAYA PDA FLASHER (DATA SAFE) ===
-- Wipes OS but KEEPS user data (profile.txt)

-- 1. НАСТРОЙКИ (Пути к файлам на ТВОЕМ компьютере)
local sourceFiles = {
    "/patch/rebel.lua",   -- Убедись, что пути верные
    "/patch/tracker.lua"
}

-- Проверка файлов перед началом
for _, path in pairs(sourceFiles) do
    if not fs.exists(path) then
        print("ERROR: Missing source file: " .. path)
        return
    end
end

-- Функция ожидания и прошивки
while true do
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1,1)
    print("--- NIPAYA FLASH STATION v2 ---")
    print("INSERT PDA TO UPDATE...")
    
    -- Ждем появления устройства
    while not fs.exists("disk") do
        sleep(0.5)
    end
    
    term.setTextColor(colors.yellow)
    print("\nPDA Detected! Starting update...")
    term.setTextColor(colors.white)
    sleep(0.5)

    -- 2. ОЧИСТКА ПАМЯТИ (С ЗАЩИТОЙ ДАННЫХ)
    print("> Cleaning system...")
    local list = fs.list("disk")
    for _, file in pairs(list) do
        -- !!! ГЛАВНОЕ ИЗМЕНЕНИЕ ЗДЕСЬ !!!
        -- Мы проверяем имя файла. Если это профиль — не удаляем.
        if file == "profile.txt" or file == "callsign.txt" or file == "cmd_id.txt" or file == "cmd_profile.txt" then
            term.setTextColor(colors.green)
            print(" * Kept user data: " .. file)
            term.setTextColor(colors.white)
        else
            -- Всё остальное (старые программы, логи) удаляем
            fs.delete("disk/" .. file)
        end
    end
    
    -- 3. КОПИРОВАНИЕ ФАЙЛОВ ВНУТРЬ КПК
    print("> Installing New OS...")
    for _, path in pairs(sourceFiles) do
        local filename = fs.getName(path)
        local cleanName = string.gsub(filename, ".lua", "") -- Убираем .lua
        
        -- На всякий случай удаляем целевой файл, если он вдруг остался
        if fs.exists("disk/" .. cleanName) then
            fs.delete("disk/" .. cleanName)
        end
        
        fs.copy(path, "disk/" .. cleanName)
        print(" + Installed: " .. cleanName)
    end
    
    -- 4. СОЗДАНИЕ STARTUP
    -- Startup мы перезаписываем всегда, чтобы гарантировать правильный запуск
    print("> Writing Boot Sector...")
    local f = fs.open("disk/startup", "w")
    f.writeLine('-- Nipaya OS Boot')
    f.writeLine('shell.run("bg tracker")')
    f.writeLine('shell.run("rebel")')
    f.close()
    
    term.setTextColor(colors.green)
    print("\nSUCCESS! REMOVE PDA.")
    term.setTextColor(colors.white)
    
    -- Метка диска
    if disk.getLabel("disk") == nil then
        disk.setLabel("disk", "Nipaya Unit")
    end
    
    -- Ждем, пока игрок заберет КПК
    while fs.exists("disk") do
        sleep(0.5)
    end
end