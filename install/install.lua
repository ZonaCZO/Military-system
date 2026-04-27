local BASE = "https://raw.githubusercontent.com/ZonaCZO/Military-system/main/"

term.clear()
term.setCursorPos(1,1)
term.setTextColor(colors.green)
print("=== MILITARY SYSTEM V14.3 ===")
term.setTextColor(colors.white)
print("1 - Command PC (HQ / MSOS)")
print("2 - Central Server (Core)")
print(string.rep("-", 29))
write("Select installation (1-2): ")
local choice = read()

-- === SAFE DOWNLOAD ===
local function download(url, path)
    if fs.exists(path) then fs.delete(path) end 
    print("Downloading " .. path .. "...")
    local ok = shell.run("wget", BASE .. url, path)
    if not ok then
        term.setTextColor(colors.red)
        print("ERROR downloading: " .. url)
        term.setTextColor(colors.white)
        return false
    end
    return true
end

local function mkdir(path)
    if not fs.exists(path) then fs.makeDir(path) end
end

-- =========================
-- 1. COMMAND PC (MSOS)
-- =========================
if choice == "1" then
    print("\nCreating directories...")
    mkdir("pr")
    mkdir("sys")
    mkdir("sys/icon")
    mkdir("startup")
    
    print("\nDownloading Command Software...")
    download("server/general.lua", "pr/general.lua")
    download("server/leader.lua", "pr/commander.lua")
    download("data/burn.lua", "pr/burn.lua")
    download("data/deaddrop.lua", "pr/deaddrop.lua")
    download("install/pda_patcher.lua", "pr/pda.lua")
    
    print("\nDownloading Strategic Modules...")
    download("system/front_browser.lua", "pr/front_browser.lua")
    download("system/plan_browser.lua", "pr/plan_browser.lua")
    download("system/radar.lua", "pr/radar.lua")

    print("\nDownloading Icons...")
    download("system/icons/general.nfp", "sys/icon/general.nfp")
    download("system/icons/commander.nfp", "sys/icon/commander.nfp")
    download("system/icons/burn.nfp", "sys/icon/burn.nfp")
    download("system/icons/deaddrop.nfp", "sys/icon/deaddrop.nfp")
    download("system/icons/pda.nfp", "sys/icon/pda.nfp")
    
    print("\nInstalling Base System...")
    download("system/system.lua", "system.lua")
    download("system/cyrillic.lua", "startup/cyrillic.lua")

    local f = fs.open("startup.lua", "w")
    f.write('shell.run("system")')
    f.close()
    print("\nAuto-boot configured for MSOS.")

-- =========================
-- 2. CENTRAL SERVER
-- =========================
elseif choice == "2" then
    print("\nCreating Server Directories...")
    mkdir("data")
    mkdir("data/archive")
    mkdir("data/archive/plans")
    mkdir("data/archive/logs")
    mkdir("data/map")
    mkdir("data/map/fronts")
    mkdir("data/map/sectors")
    mkdir("server")
    mkdir("server/modules")

    print("\nDownloading Server Core...")
    download("server/resistance_core.lua", "server.lua")
    
    print("Downloading Core Modules...")
    download("server/modules/auth.lua", "server/modules/auth.lua")
    download("server/modules/storage.lua", "server/modules/storage.lua")
    download("server/modules/fronts.lua", "server/modules/fronts.lua")
    download("server/modules/map.lua", "server/modules/map.lua")
    download("server/modules/archive.lua", "server/modules/archive.lua")

    local f = fs.open("startup.lua", "w")
    f.write('shell.run("server")')
    f.close()
    print("\nAuto-boot configured for Server.")

else
    term.setTextColor(colors.red)
    print("Invalid choice. Installation aborted.")
    term.setTextColor(colors.white)
    return
end

-- =========================
-- FINISH
-- =========================
term.setTextColor(colors.green)
print("\n=== INSTALL COMPLETE ===")
term.setTextColor(colors.yellow)
print("Press Enter to reboot device...")
read()
os.reboot()