local BASE = "https://raw.githubusercontent.com/ZonaCZO/Military-system/MSOS-2.0/" -- Change to main before merge

print("Military System Installer v2.0")
print("1 - Command Computer (MSOS)")
print("2 - Server (Core)")

write("Select type: ")
local choice = read()

-- === SAFE DOWNLOAD ===
local function download(url, path)
    -- Удаляем файл, если он уже есть, чтобы wget не завис с вопросом об перезаписи
    if fs.exists(path) then fs.delete(path) end 
    
    print("Downloading " .. path .. "...")
    local ok = shell.run("wget", BASE .. url, path)
    if not ok then
        print("ERROR downloading: " .. url)
        return false
    end
    return true
end

local function mkdir(path)
    if not fs.exists(path) then
        fs.makeDir(path)
    end
end

-- =========================
-- CLIENT INSTALL
-- =========================
if choice == "1" then
    
    print("\nCreating directories...")
    mkdir("pr")
    mkdir("sys")
    mkdir("sys/icon")
    mkdir("startup")
    
    print("\nDownloading software...")
    download("server/general.lua", "pr/general.lua")
    download("server/leader.lua", "pr/commander.lua")
    download("data/burn.lua", "pr/burn.lua")
    download("data/deaddrop.lua", "pr/deaddrop.lua")
    download("install/pda_patcher.lua", "pr/pda.lua")

    print("\nDownloading icons...")
    download("system/icons/general.nfp", "sys/icon/general.nfp")
    download("system/icons/commander.nfp", "sys/icon/commander.nfp")
    download("system/icons/burn.nfp", "sys/icon/burn.nfp")
    download("system/icons/deaddrop.nfp", "sys/icon/deaddrop.nfp")
    download("system/icons/pda.nfp", "sys/icon/pda.nfp")

    print("\nInstalling system...")
    download("system/system.lua", "system.lua")
    download("system/cyrillic.lua", "startup/cyrillic.lua")

    print("\nCommand system installed.")

-- =========================
-- SERVER INSTALL
-- =========================
elseif choice == "2" then
    
    print("\nCreating server directories...")
    mkdir("data")
    mkdir("data/archive")
    mkdir("data/archive/plans")
    mkdir("data/archive/logs")
    mkdir("data/map")
    mkdir("data/map/fronts")
    mkdir("data/map/sectors")
    
    -- СОЗДАЁМ ПАПКИ ДЛЯ МОДУЛЕЙ СЕРВЕРА
    mkdir("server")
    mkdir("server/modules")

    print("\nDownloading core & modules...")
    -- Скачиваем ядро в корень
    download("server/resistance_core.lua", "server.lua")
    
    -- Скачиваем модули строго по путям, которые ожидает require()
    download("server/auth.lua", "server/modules/auth.lua")
    download("server/storage.lua", "server/modules/storage.lua")
    download("server/fronts.lua", "server/modules/fronts.lua")
    download("server/map.lua", "server/modules/map.lua")
    download("server/archive.lua", "server/modules/archive.lua")

    print("\nServer installed.")

else
    print("Invalid choice.")
    return
end

-- =========================
-- AUTOBOOT
-- =========================
print("\nConfiguring auto-boot...")

local f = fs.open("startup.lua", "w")

if choice == "1" then
    f.write('shell.run("system")')
    print("Auto-boot → MSOS")
else
    f.write('shell.run("server")')
    print("Auto-boot → Server")
end

f.close()

-- =========================
-- FINISH
-- =========================
term.setTextColor(colors.green)
print("\nINSTALL COMPLETE")

term.setTextColor(colors.yellow)
print("Press Enter to reboot...")
read()
os.reboot()