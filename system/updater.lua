-- Unified updater for MSOS command computers and the Central Server.
local args={...}
local INSTALLER_URL='https://raw.githubusercontent.com/ZonaCZO/Military-system/main/install/install.lua'
local INSTALLER_FILE='.msos-update-installer.lua'
local function detectTarget()
  if args[1]=='os' or args[1]=='1' then return '1','MSOS Command OS' end
  if args[1]=='server' or args[1]=='2' then return '2','Central Server Core' end
  local hasOS=fs.exists('system.lua') and fs.exists('pr')
  local hasServer=fs.exists('server.lua') and fs.exists('server/modules')
  if hasOS and not hasServer then return '1','MSOS Command OS' end
  if hasServer and not hasOS then return '2','Central Server Core' end
  return nil,nil
end
term.setBackgroundColor(colors.black);term.clear();term.setCursorPos(1,1)
term.setTextColor(colors.yellow);print('=== MILITARY SYSTEM UPDATER ===')
local choice,label=detectTarget()
if not choice then
  term.setTextColor(colors.white)
  print('Cannot safely detect this installation.')
  print('Run: updater os')
  print(' or: updater server')
  return
end
term.setTextColor(colors.white)
print('Target: '..label)
print('Programs and icons will be replaced.')
print('Network config and saved data will remain.')
write('Continue? y/N: ')
if read():lower()~='y' then print('Cancelled.');return end
if not http then
  term.setTextColor(colors.red);print('HTTP API is disabled in CC:Tweaked config.');return
end
if fs.exists(INSTALLER_FILE) then fs.delete(INSTALLER_FILE) end
print('Downloading current installer...')
local ok=shell.run('wget',INSTALLER_URL,INSTALLER_FILE)
if not ok or not fs.exists(INSTALLER_FILE) or fs.getSize(INSTALLER_FILE)==0 then
  if fs.exists(INSTALLER_FILE) then fs.delete(INSTALLER_FILE) end
  term.setTextColor(colors.red);print('Update download failed. Existing installation was not changed.');return
end
print('Starting '..label..' update...')
local installed=shell.run(INSTALLER_FILE,choice)
if not installed then
  term.setTextColor(colors.red);print('Installer stopped with an error. Check the message above.')
end
