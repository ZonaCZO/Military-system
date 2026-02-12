local BASE = "https://raw.githubusercontent.com/ZonaCZO/Military-system/main/"

print("Military System Installer v1.6")
print("1 - Command Computer (MSOS)")
print("2 - Server (Core)")

write("Select type: ")
local choice = read()

local function download(url, path)
    print("Downloading "..path.."...")
    shell.run("wget", BASE .. url, path)
end

if choice == "1" then
    -- Создаем папки
    if not fs.exists("pr") then fs.makeDir("pr") end
    if not fs.exists("sys") then fs.makeDir("sys") end
    if not fs.exists("sys/icon") then fs.makeDir("sys/icon") end

    -- Загрузка программ
    print("\nDownloading Software...")
    download("server/general.lua", "pr/general.lua")
    download("server/leader.lua", "pr/commander.lua")
    download("data/burn.lua", "pr/burn.lua")
    download("data/deaddrop.lua", "pr/deaddrop.lua")
    download("install/pda_patcher.lua", "pr/pda.lua")
    
    -- Загрузка иконок с GitHub
    print("\nDownloading Icons...")
    -- Скачиваем из system/icons (GitHub) в sys/icon (Local)
    download("system/icons/general.nfp", "sys/icon/general.nfp")
    download("system/icons/commander.nfp", "sys/icon/commander.nfp")
    download("system/icons/burn.nfp", "sys/icon/burn.nfp")
    download("system/icons/deaddrop.nfp", "sys/icon/deaddrop.nfp")
    download("system/icons/pda.nfp", "sys/icon/pda.nfp")

    -- Загружаем саму систему
    print("\nInstalling System...")
    download("system/system.lua", "system.lua")
    
    print("Command system installed.")
    
elseif choice == "2" then
    download("server/resistance_core.lua", "server.lua")
    print("Server system installed.")
else
    print("Invalid choice.")
end

print("Installation complete.")

print("Configuring auto-boot...")
local f = fs.open("startup.lua", "w")
if choice == "1" then
    f.write('shell.run("system")')
    print("Auto-boot set to MSOS")
elseif choice == "2" then
    f.write('shell.run("server")')
    print("Auto-boot set to Server")
end
f.close()

term.setTextColor(colors.yellow)
print("\nINSTALLED.")
print("Press Enter to Reboot.")
read()
os.reboot()