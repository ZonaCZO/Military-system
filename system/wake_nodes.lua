-- Optional CC Wake Nodes manager. Safe when the mod/peripheral is absent.
local selected, nodes, message = 1, {}, ''
local function controller()
  return peripheral.find('wake_controller')
end
local function call(method,...)
  local ctl=controller()
  if not ctl then return false,'Wake Controller unavailable (optional mod)' end
  local fn=ctl[method]
  if type(fn)~='function' then return false,'Unsupported controller API: '..method end
  local result=table.pack(pcall(fn,...))
  if not result[1] then return false,tostring(result[2]) end
  return true,table.unpack(result,2,result.n)
end
local function refresh(keepMessage)
  local ok,result=call('listNodes')
  if not ok then nodes={}; selected=1; message=result; return end
  nodes=type(result)=='table' and result or {}
  table.sort(nodes,function(a,b)return tostring(a)<tostring(b)end)
  selected=math.max(1,math.min(selected,#nodes))
  if not keepMessage then message=#nodes==0 and 'No authorized wake nodes.' or 'Ready.' end
end
local function line(y,text,fg,bg)
  local w=term.getSize(); term.setCursorPos(1,y); term.setTextColor(fg or colors.white)
  term.setBackgroundColor(bg or colors.black); term.write((text..string.rep(' ',w)):sub(1,w))
end
local function draw()
  local w,h=term.getSize(); term.setBackgroundColor(colors.black); term.clear()
  line(1,'WAKE NODES | OPTIONAL',colors.yellow)
  if not controller() then
    line(3,'CC Wake Nodes not installed or no',colors.lightGray)
    line(4,'Wake Controller attached.',colors.lightGray)
    line(6,'MSOS continues to work normally.',colors.green)
  else
    for i,id in ipairs(nodes) do
      if i>h-5 then break end
      local ok,info=call('getNodeInfo',id)
      local state=ok and info.loaded and 'LOADED' or 'sleeping'
      local suffix=ok and info.expires_at and (' '..tostring(info.expires_at)..'s') or ''
      line(i+2,(i==selected and '> ' or '  ')..tostring(id)..' ['..state..suffix..']',
        i==selected and colors.black or colors.white,i==selected and colors.white or colors.black)
    end
  end
  line(h-2,message,colors.lightGray)
  line(h,'Up/Down select  L wake  U unload  R refresh  Q exit',colors.lightGray)
end
local function wakeSelected()
  local id=nodes[selected]; if not id then return end
  term.setBackgroundColor(colors.black); term.clear(); term.setCursorPos(1,1)
  print('Wake '..tostring(id)..' for seconds (1-120):')
  local seconds=tonumber(read())
  if not seconds or seconds<1 or seconds>120 then message='Duration must be 1-120 seconds.'; return end
  local ok,result=call('loadFor',id,math.floor(seconds))
  message=ok and ('Woke '..tostring(id)..' for '..math.floor(seconds)..'s') or result
end
refresh()
while true do
  draw()
  local event,key=os.pullEvent()
  if event=='key' then
    if key==keys.up then selected=math.max(1,selected-1)
    elseif key==keys.down then selected=math.min(#nodes,selected+1)
    elseif key==keys.r then refresh()
    elseif key==keys.l then wakeSelected(); refresh(true)
    elseif key==keys.u then
      local id=nodes[selected]
      if id then local ok,result=call('unloadNode',id); message=ok and ('Unloaded '..id) or result; refresh(true) end
    elseif key==keys.q then term.setBackgroundColor(colors.black);term.clear();term.setCursorPos(1,1);return end
  end
end
