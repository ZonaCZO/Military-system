-- === NIPAYA DEAD DROP V2.0 ===
-- [ENCRYPTED STORAGE]

-- === 1. CRYPTO ENGINE (XOR) ===
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

local function xor_cipher(text, key)
    local output = {}
    for i = 1, #text do
        local textByte = string.byte(text, i)
        local keyPos = (i - 1) % #key + 1
        local keyByte = string.byte(key, keyPos)
        
        -- Битовая магия
        local resultByte = bit.bxor(textByte, keyByte)
        table.insert(output, string.char(resultByte))
    end
    return table.concat(output)
end

-- === 2. INTERFACE ===
local diskPath = "disk/system_log.dat" -- Маскировка под лог

while true do
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1,1)
    print("--- DEAD DROP TERMINAL ---")
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
                -- pcall нужен, чтобы программа не вылетела, если на диске мусор
                local status, result = pcall(function()
                    local decoded = fromHex(content)
                    return xor_cipher(decoded, key)
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
            local encrypted = xor_cipher(msg, key)
            local hexData = toHex(encrypted)
            
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