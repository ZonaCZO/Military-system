-- MSOS focused text input. It never queues global "char" events.
-- This prevents a hotkey from leaking a Cyrillic character into the next prompt.
local input = {}

local layouts = {
  RU = {
    [93]=0xFA,[90]=0xFF,[75]=0xEB,[65]=0xF4,[66]=0xE8,[67]=0xF1,[68]=0xE2,[69]=0xF3,
    [39]=0xFD,[71]=0xEF,[72]=0xF0,[73]=0xF8,[74]=0xEE,[44]=0xE1,[76]=0xE4,[77]=0xFC,
    [78]=0xF2,[79]=0xF9,[80]=0xE7,[81]=0xE9,[82]=0xEA,[83]=0xFB,[84]=0xE5,[85]=0xE3,
    [86]=0xEC,[87]=0xF6,[88]=0xF7,[89]=0xED,[59]=0xE6,[91]=0xF5,[70]=0xE0,[46]=0xFE
  },
  UA = {
    [93]=0xBF,[90]=0xFF,[75]=0xEB,[65]=0xF4,[66]=0xE8,[67]=0xF1,[68]=0xE2,[69]=0xF3,
    [39]=0xBA,[71]=0xEF,[72]=0xF0,[73]=0xF8,[74]=0xEE,[44]=0xE1,[76]=0xE4,[77]=0xFC,
    [78]=0xF2,[79]=0xF9,[80]=0xE7,[81]=0xE9,[82]=0xEA,[83]=0xFB,[84]=0xE5,[85]=0xE3,
    [86]=0xEC,[87]=0xF6,[88]=0xF7,[89]=0xED,[59]=0xE6,[91]=0xF5,[70]=0xE0,[46]=0xFE,
    [31]=0xB3,[43]=0xB4
  }
}
local shifted = {}
for name,map in pairs(layouts) do
  shifted[name]={}
  for key,byte in pairs(map) do shifted[name][key]=byte>=0xE0 and byte-0x20 or byte end
end
shifted.UA[31]=0xB2; shifted.UA[39]=0xAA; shifted.UA[93]=0xAF; shifted.UA[43]=0xA5

local configFile = '.msos_language'
local language = 'EN'
if fs.exists(configFile) then
  local f=fs.open(configFile,'r'); language=(f.readLine() or 'EN'):upper(); f.close()
end
if language~='EN' and language~='RU' and language~='UA' then language='EN' end

local function saveLanguage()
  local f=fs.open(configFile,'w'); if f then f.writeLine(language); f.close() end
end
function input.getLanguage() return language end
function input.setLanguage(value)
  value=tostring(value or ''):upper()
  if value=='EN' or value=='RU' or value=='UA' then language=value; saveLanguage(); return true end
  return false
end
function input.nextLanguage()
  language=language=='EN' and 'RU' or (language=='RU' and 'UA' or 'EN')
  saveLanguage(); return language
end

function input.read(options)
  options=options or {}
  local mode=(options.mode or language):upper()
  local mask=options.mask
  local maxLength=options.maxLength or 128
  local value=''
  local startX,startY=term.getCursorPos()
  local width=select(1,term.getSize())-startX+1
  local ignoreChar=false
  local shiftDown=false

  local function redraw()
    local shown=mask and string.rep(mask,#value) or value
    if #shown>width then shown=shown:sub(#shown-width+1) end
    term.setCursorPos(startX,startY); write(string.rep(' ',width)); term.setCursorPos(startX,startY); write(shown)
    term.setCursorBlink(true)
  end
  redraw()
  while true do
    local event,a=os.pullEvent()
    if event=='key' then
      if a==keys.enter then term.setCursorBlink(false); print(); return value
      elseif a==keys.backspace then value=value:sub(1,-2); redraw()
      elseif a==keys.leftShift or a==keys.rightShift then shiftDown=true
      elseif a==keys.f2 and not options.lockLanguage then mode=input.nextLanguage(); redraw()
      elseif mode~='EN' and layouts[mode] and layouts[mode][a] and #value<maxLength then
        local byte=(shiftDown and shifted[mode] or layouts[mode])[a]
        value=value..string.char(byte); ignoreChar=true; redraw()
      end
    elseif event=='key_up' and (a==keys.leftShift or a==keys.rightShift) then shiftDown=false
    elseif event=='char' then
      if ignoreChar then ignoreChar=false
      elseif mode=='EN' and #value<maxLength then value=value..a; redraw() end
    elseif event=='paste' and mode=='EN' then
      value=(value..a):sub(1,maxLength); redraw()
    end
  end
end

return input
