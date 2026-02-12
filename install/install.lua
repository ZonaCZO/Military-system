local BASE = "https://raw.githubusercontent.com/ZonaCZO/Military-system/main/"

print("Military System Installer")
print("1 - Command Computer (MSOS)")
print("2 - Server (Core)")

write("Select type: ")
local choice = read()

local function download(url, path)
    print("Downloading "..path.."...")
    shell.run("wget", BASE .. url, path)
end

if choice == "1" then
    -- Создаем необходимые папки для MSOS
    if not fs.exists("pr") then fs.makeDir("pr") end
    if not fs.exists("sys") then fs.makeDir("sys") end

    -- Загрузка программ в папку pr
    download("server/leader.lua", "pr/commander.lua")
    download("data/burn.lua", "pr/burn.lua")
    download("data/deaddrop.lua", "pr/deaddrop.lua")
    download("install/pda_patcher.lua", "pr/pda.lua")
    
    -- Загрузка самой системы в корень
    -- ВАЖНО: Убедитесь, что на GitHub файл меню называется 'server/menu.lua'
    download("server/menu.lua", "system.lua")
    
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
    -- Запускаем систему (меню)
    f.write('shell.run("system")')
    print("Auto-boot set to MSOS (system.lua)")
elseif choice == "2" then -- Исправлена ошибка (было choice == "1")
    -- Запускаем сервер
    f.write('shell.run("server")')
    print("Auto-boot set to Server")
end
f.close()

term.setTextColor(colors.yellow)
print("\nINSTALLED.")
print("Press Enter to Reboot.")
read()
os.reboot()