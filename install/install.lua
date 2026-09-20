local args = {...}
local BASE = "https://raw.githubusercontent.com/ZonaCZO/Military-system/main/"

term.clear()
term.setCursorPos(1,1)
term.setTextColor(colors.green)
print("=== MILITARY SYSTEM V14.3 ===")
term.setTextColor(colors.white)
print("1 - Command PC (HQ / MSOS)")
print("2 - Central Server (Core)")
print(string.rep("-", 29))
local choice = args[1]
if choice ~= "1" and choice ~= "2" then
    write("Select installation (1-2): ")
    choice = read()
end
print('Programs will be replaced. Network settings and saved data are preserved.')

local function backupProgram(path)
    if fs.exists(path) then
        if fs.isDir(path) then error('Expected program file: ' .. path) end
        fs.delete(path)
    end
    local dir = fs.getDir(path)
    local base = fs.getName(path) .. '.msos-backup'
    if not fs.exists(dir) then return end
    for _,name in ipairs(fs.list(dir)) do
        local numbered = name:sub(1,#base+1)==base..'-' and name:sub(#base+2):match('^%d+$')
        local candidate = fs.combine(dir,name)
        if (name==base or numbered) and not fs.isDir(candidate) then fs.delete(candidate) end
    end
end

-- === SAFE DOWNLOAD ===
local function download(url, path)
    local temporary = path .. '.msos-new'
    if fs.exists(temporary) then fs.delete(temporary) end
    local dir = fs.getDir(path)
    if dir ~= '' then fs.makeDir(dir) end
    print("Downloading " .. path .. "...")
    local ok = shell.run("wget", BASE .. url, temporary)
    if not ok or not fs.exists(temporary) or fs.getSize(temporary) == 0 then
        term.setTextColor(colors.red)
        print("ERROR downloading: " .. url)
        term.setTextColor(colors.white)
        error('Installation stopped; previous file preserved: ' .. path, 0)
    end
    backupProgram(path)
    fs.move(temporary, path)
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
    mkdir("pr/system")
    
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
    download("system/military_map.lua", "pr/military_map.lua")
    download("system/wake_nodes.lua", "pr/wake_nodes.lua")
    download("system/updater.lua", "pr/updater.lua")
    download("ballistix/nuke_center.lua", "pr/rocket.lua")

    print("\nDownloading Icons...")
    download("system/icons/general.nfp", "sys/icon/general.nfp")
    download("system/icons/commander.nfp", "sys/icon/commander.nfp")
    download("system/icons/burn.nfp", "sys/icon/burn.nfp")
    download("system/icons/deaddrop.nfp", "sys/icon/deaddrop.nfp")
    download("system/icons/pda.nfp", "sys/icon/pda.nfp")
    download("system/icons/front_browser.nfp", "sys/icon/front_browser.nfp")
    download("system/icons/plan_browser.nfp", "sys/icon/plan_browser.nfp")
    download("system/icons/radar.nfp", "sys/icon/radar.nfp")
    download("system/icons/military_map.nfp", "sys/icon/military_map.nfp")
    download("system/icons/wake_nodes.nfp", "sys/icon/wake_nodes.nfp")
    download("system/icons/updater.nfp", "sys/icon/updater.nfp")
    download("system/icons/rocket.nfp", "sys/icon/rocket.nfp")
    
    print("\nInstalling Base System...")
    download("system/system.lua", "system.lua")
    download("system/cyrillic_driver.lua", "pr/system/cyrillic_driver.lua")
    -- Applications start the driver themselves. Do not install a second startup driver.

    if not fs.exists('startup.lua') then
    local f = fs.open("startup.lua", "w")
    f.write('shell.run("system")')
    f.close()
    else print('Existing startup.lua preserved.') end
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
    download("system/updater.lua", "update.lua")
    download("system/wake_server.lua", "wake.lua")

    print("\nInstalling Keyboard Driver...")
    mkdir("startup")
    -- The central core already starts its own keyboard driver.
    
    print("Downloading Core Modules...")
    download("server/modules/front_live_map.lua", "server/modules/front_live_map.lua")
    download("server/modules/auth.lua", "server/modules/auth.lua")
    download("server/modules/storage.lua", "server/modules/storage.lua")
    download("server/modules/fronts.lua", "server/modules/fronts.lua")
    download("server/modules/map.lua", "server/modules/map.lua")
    download("server/modules/archive.lua", "server/modules/archive.lua")

    if not fs.exists('startup.lua') then
    local f = fs.open("startup.lua", "w")
    f.write('shell.run("server")')
    f.close()
    else print('Existing startup.lua preserved.') end
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
