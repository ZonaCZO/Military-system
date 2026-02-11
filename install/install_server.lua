-- === RESISTANCE CORE INSTALLER ===
local files = {
    {name = "resistance_core.lua", id = "MZcMsfa0"}
    -- Сюда можно добавить другие файлы сервера в будущем
}

term.clear()
term.setCursorPos(1,1)
textutils.slowPrint("CONNECTING TO REPOSITORY...", 15)
print("Target: CENTRAL SERVER NODE")
print("-----------------------------------")

for _, file in ipairs(files) do
    write("Fetching " .. file.name .. " ["..file.id.."]... ")
    if fs.exists(file.name) then fs.delete(file.name) end
    shell.run("pastebin", "get", file.id, file.name)
    
    if fs.exists(file.name) then
        term.setTextColor(colors.green)
        print("SUCCESS")
    else
        term.setTextColor(colors.red)
        print("ERROR")
    end
    term.setTextColor(colors.white)
end

-- Автоматическое создание startup для сервера
print("Configuring auto-boot...")
local f = fs.open("startup.lua", "w")
f.write('shell.run("resistance_core.lua")')
f.close()

term.setTextColor(colors.yellow)
print("\nSERVER INSTALLED.")
print("Press Enter to Reboot and Host.")
read()
os.reboot()