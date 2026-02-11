local BASE = "https://raw.githubusercontent.com/ZonaCZO/Military-system/main/"

print("Military System Installer")
print("1 - Command Computer")
print("2 - Server")

write("Select type: ")
local choice = read()

local function download(url, path)
    print("Downloading "..path)
    shell.run("wget", BASE .. url, path)
end

if choice == "1" then
    download("server/leader.lua", "commander.lua")
    download("data/burn.lua", "burn.lua")
    download("data/deaddrop.lua", "deaddrop.lua")
    download("install/pda_patcher.lua", "pda.lua")
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
    f.write('shell.run("fg", "commander")')
    print("1")
elseif choice == "1" then
    f.write('shell.run("server")')
    print("2")
end
f.close()

term.setTextColor(colors.yellow)
print("\nINSTALLED.")
print("Press Enter to Reboot and Host.")
read()
os.reboot()