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

-- Генератор иконок (Hex-коды цветов CC: 7=Gray, e=Red, b=Blue, etc.)
local iconsData = {
    ["sys/general.nfp"] = { -- Красная звезда
        "777e777",
        "77eee77",
        "7eeeee7",
        "77eee77",
        "777e777"
    },
    ["sys/commander.nfp"] = { -- Синий шевро
        "777b777",
        "77bbb77",
        "7bbbbb7",
        "77bbb77",
        "777b777"
    },
    ["sys/burn.nfp"] = { -- Огонь (Оранжевый/Желтый)
        "7774777",
        "7741477",
        "7411147",
        "7111117",
        "7711177"
    },
    ["sys/deaddrop.nfp"] = { -- Зеленая дискета
        "7777777",
        "7ddddd7",
        "7dfffd7",
        "7ddddd7",
        "7777777"
    },
    ["sys/pda.nfp"] = { -- Голубой КПК
        "7999997",
        "79ff997",
        "7999997",
        "7999997",
        "7999997"
    }
}

local function install_icons()
    print("\nGenerating Icons...")
    for path, lines in pairs(iconsData) do
        local f = fs.open(path, "w")
        for _, line in ipairs(lines) do
            f.writeLine(line)
        end
        f.close()
        print("Created: "..path)
    end
end

if choice == "1" then
    -- Создаем папки
    if not fs.exists("pr") then fs.makeDir("pr") end
    if not fs.exists("sys") then fs.makeDir("sys") end

    -- Загрузка программ
    download("server/general.lua", "pr/general.lua")
    download("server/leader.lua", "pr/commander.lua")
    download("data/burn.lua", "pr/burn.lua")
    download("data/deaddrop.lua", "pr/deaddrop.lua")
    download("install/pda_patcher.lua", "pr/pda.lua")
    
    -- Генерируем иконки локально
    install_icons()

    -- Загружаем саму систему (меню)
    -- Если на GitHub старая версия, замените её вручную кодом ниже!
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