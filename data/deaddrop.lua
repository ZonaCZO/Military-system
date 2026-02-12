-- === DEAD DROP V2.1 (RC4) ===
-- [ENCRYPTED STORAGE]

-- === 1. CRYPTO ENGINE (RC4) ===
local function toHex(str)
    return (str:gsub('.', function (c)
        return string.format('%02X', string.byte(c))
    end))
end

local function fromHex(str)
    return (str:gsub('..', function (cc)
        return string.char(tonumber(cc, 16))
    end))
end

-- Алгоритм RC4 (потоковый шифр)
local function rc4(text, key)
    if not key or key == "" then return text end
    
    -- 1. Инициализация (Key-Scheduling Algorithm)
    local S = {}
    for i = 0, 255 do S[i] = i end
    
    local j = 0
    for i = 0, 255 do
        j = (j + S[i] + string.byte(key, (i % #key) + 1)) % 256
        S[i], S[j] = S[j], S[i]
    end
    
    -- 2. Генерация потока (PRGA)
    local i = 0
    j = 0
    local output = {}
    
    for k = 1, #text do
        i = (i + 1) % 256
        j = (j + S[i]) % 256
        S[i], S[j] = S[j], S[i]
        
        local K = S[(S[i] + S[j]) % 256]
        -- XOR байта текста с сгенерированным байтом ключа
        table.insert(output, string.char(bit.bxor(string.byte(text, k), K)))
    end
    
    return table.concat(output)
end

-- === 2. INTERFACE ===
local diskPath = "disk/system_log.dat" -- Маскировка под лог

while true do
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1,1)
    print("--- DEAD DROP TERMINAL (RC4) ---")
    print("Waiting for Disk...")

    -- Ждем вставки диска
    while not fs.exists("disk") do
        sleep(0.5)
    end
    
    term.clear()
    term.setCursorPos(1,1)
    print("DISK DETECTED.")
    print("------------------")
    print("1. READ MESSAGE")
    print("2. WRITE NEW MESSAGE")
    print("3. WIPE DISK (Format)")
    print("4. EJECT")
    
    write("\nSelect: ")
    local choice = read()
    
    if choice == "1" then
        -- ЧТЕНИЕ
        if fs.exists(diskPath) then
            write("\nEnter Decryption Key: ")
            local key = read("*")
            
            if key == "" then
                print("Key required!")
                sleep(1)
            else
                local f = fs.open(diskPath, "r")
                local content = f.readAll()
                f.close()
                
                -- Пытаемся расшифровать
                -- RC4 симметричен: для расшифровки прогоняем зашифрованное через ту же функцию
                local status, result = pcall(function()
                    local decoded = fromHex(content) -- Сначала из HEX в байты
                    return rc4(decoded, key)         -- Потом RC4
                end)
                
                print("\n--- CONTENT START ---")
                term.setTextColor(colors.green)
                if status then
                    print(result)
                else
                    print("DATA CORRUPTED OR WRONG KEY")
                end
                term.setTextColor(colors.white)
                print("--- CONTENT END ---")
            end
        else
            print("Disk is empty (No logs found).")
        end
        print("\nPress Enter to continue...")
        read()

    elseif choice == "2" then
        -- ЗАПИСЬ
        print("\nEnter Secret Message:")
        local msg = read()
        
        write("Set Encryption Key: ")
        local key = read("*")
        
        if key == "" or msg == "" then
            print("Error: Empty fields.")
            sleep(1)
        else
            print("Encrypting...")
            local encrypted = rc4(msg, key) -- Шифруем RC4
            local hexData = toHex(encrypted) -- Переводим в HEX для сохранения
            
            local f = fs.open(diskPath, "w")
            f.write(hexData)
            f.close()
            
            print("Data saved as 'system_log.dat'.")
            sleep(1)
        end
        
    elseif choice == "3" then
        -- УДАЛЕНИЕ
        if fs.exists(diskPath) then
            fs.delete(diskPath)
            print("Disk wiped.")
        else
            print("Disk already empty.")
        end
        sleep(1)

    elseif choice == "4" then
        local drive = peripheral.find("drive")
        if drive then
            drive.ejectDisk()
            print("Ejected.")
            sleep(2)
        end
    end
end