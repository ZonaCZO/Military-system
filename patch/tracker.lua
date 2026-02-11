-- === NIPAYA GPS TRACKER (Callsign Ed.) ===
-- Запускать: "bg tracker_v2"

local modem = peripheral.find("modem")
if not modem then error("No Modem") end
rednet.open(peripheral.getName(modem))

local protocol = "nipaya_radar"

-- 1. ЗАГРУЗКА ИЛИ СОЗДАНИЕ ПОЗЫВНОГО
local myCallsign = ""

if fs.exists("callsign.txt") then
    -- Если файл есть, читаем его
    local file = fs.open("callsign.txt", "r")
    myCallsign = file.readAll()
    file.close()
else
    -- Если файла нет, спрашиваем у бойца
    term.clear()
    term.setCursorPos(1,1)
    print("--- ID CONFIG ---")
    print("Enter Call Sign (2 letters):")
    write("> ")
    local input = read()
    
    -- Берем только первые 2 буквы и делаем их ЗАГЛАВНЫМИ
    myCallsign = string.upper(string.sub(input, 1, 2))
    
    -- Сохраняем, чтобы не спрашивать снова
    local file = fs.open("callsign.txt", "w")
    file.write(myCallsign)
    file.close()
    
    print("Callsign set: " .. myCallsign)
    sleep(1)
end

print("Tracker Active: [" .. myCallsign .. "]")

-- 2. ГЛАВНЫЙ ЦИКЛ
while true do
    local x, y, z = gps.locate(2)
    
    if x then
        -- Шлем не ID компьютера, а наш Позывной
        local payload = {
            callsign = myCallsign, -- <--- ВОТ ГЛАВНОЕ ИЗМЕНЕНИЕ
            x = math.floor(x),
            z = math.floor(z)
        }
        
        rednet.broadcast(payload, protocol)
    else
        print("GPS Lost!")
    end
    
    sleep(3) -- Обновление каждые 3 сек
end