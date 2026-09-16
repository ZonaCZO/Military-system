-- Downloads are staged before installed files change. Never wipes the disk.
local BASE='https://raw.githubusercontent.com/ZonaCZO/Military-system/main/'
local files={{'patch/tracker.lua','tracker.lua'},{'patch/rebel.lua','Soldier.lua'},
  {'patch/PDAOS.lua','PDAOS.lua'},{'system/cyrillic_driver.lua','system/cyrillic_driver.lua'}}
local function install(root)
  local function backupProgram(path)
    if fs.exists(path) then
      if fs.isDir(path) then error('Expected program file: '..path) end
      fs.delete(path)
    end
    local dir=fs.getDir(path)
    local base=fs.getName(path)..'.msos-backup'
    for _,name in ipairs(fs.list(dir)) do
      local numbered=name:sub(1,#base+1)==base..'-' and name:sub(#base+2):match('^%d+$')
      local candidate=fs.combine(dir,name)
      if (name==base or numbered) and not fs.isDir(candidate) then fs.delete(candidate) end
    end
  end
  local startup=fs.combine(root,'startup.lua')
  for _,entry in ipairs(files) do
    local path=fs.combine(root,entry[2])
    local staging=path..'.msos-new'
    fs.makeDir(fs.getDir(path))
    if fs.exists(staging) then fs.delete(staging) end
    if not shell.run('wget',BASE..entry[1],staging) or not fs.exists(staging) or fs.getSize(staging)==0 then
      error('Download failed; installed files unchanged: '..entry[1])
    end
  end
  for _,entry in ipairs(files) do
    local path=fs.combine(root,entry[2])
    backupProgram(path)
    fs.move(path..'.msos-new',path)
  end
  if fs.exists(startup) then print('Existing startup.lua preserved.'); return end
  local f=assert(fs.open(startup,'w'))
  f.writeLine('parallel.waitForAny(function() shell.run("tracker.lua") end, function() shell.run("PDAOS.lua") end)')
  f.close()
end
local drive=peripheral.find('drive')
if not drive then
  print('Install PDA on THIS computer? y/n')
  if read()~='y' then return end
  install('/')
  print('Installed. Reboot when ready.')
  return
end
while true do
  print('Insert writable data disk. Unrelated files are preserved.')
  while not drive.isDiskPresent() do sleep(0.5) end
  local root=drive.getMountPath()
  if not root then print('Not a data disk.')
  else
    print('Install to '..root..'? y/n')
    if read()=='y' then
      local ok,err=pcall(install,root)
      print(ok and 'Installation complete.' or tostring(err))
    end
  end
  drive.ejectDisk(); sleep(1)
end
