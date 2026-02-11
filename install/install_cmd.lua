-- === COMMANDER SYSTEM INSTALLER ===
local files = {
    {name = "deaddrop.lua", id = "qpa76f0g"},
    {name = "burn.lua",     id = "yAJCvSEV"},
    {name = "leader.lua",   id = "v6qUtKDW"}
}

term.clear()
term.setCursorPos(1,1)
textutils.slowPrint("INITIALIZING INSTALLATION SEQUENCE...", 15)
print("-----------------------------------")

for _, file in ipairs(files) do
    write("[*] Downloading " .. file.name .. "... ")
    if fs.exists(file.name) then fs.delete(file.name) end
    shell.run("pastebin", "get", file.id, file.name)
    
    if fs.exists(file.name) then
        term.setTextColor(colors.green)
        print("OK")
    else
        term.setTextColor(colors.red)
        print("FAIL")
    end
    term.setTextColor(colors.white)
    sleep(0.2)
end

print("-----------------------------------")
write("Set 'leader.lua' as startup? (y/n): ")
local input = read()
if input == "y" or input == "Y" then
    local f = fs.open("startup.lua", "w")
    f.write('shell.run("fg leader.lua")')
    f.close()
    print("Startup created.")
end

print("\nSYSTEM READY. Rebooting in 3...")
sleep(3)
os.reboot()