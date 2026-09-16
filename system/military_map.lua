-- Military-system launcher application. Read-only KubeJS frontier + local points.
local args = {...}
local original = term.current()
local screen = args[1] == 'monitor' and peripheral.find('monitor') or original
if not screen then error('Attach a monitor or run without the monitor argument') end
if screen ~= original then screen.setTextScale(0.5) end
local data, selected, message = nil, nil, ''
local points = {}
local areaIndex, left, top, zoom = 1, 0, 0, 1
local fitted = false
local hitCells = {}
-- CC has 16 palette entries: reserve custom blended terrain colours.
local bases={{0.18,0.65,0.22},{0.95,0.82,0.12},{0.80,0.18,0.16}}
local statusColors={colors.green,colors.yellow,colors.red}
local waterColors={colors.cyan,colors.blue,colors.purple}
local mountainColors={colors.lime,colors.orange,colors.pink}
local mixedColors={colors.lightBlue,colors.brown,colors.magenta}
local savedPalette={}
local function blend(a,b,f)
  return {a[1]*(1-f)+b[1]*f,a[2]*(1-f)+b[2]*f,a[3]*(1-f)+b[3]*f}
end
local function palette(color,rgb)
  savedPalette[color]={screen.getPaletteColor(color)}
  screen.setPaletteColor(color,table.unpack(rgb))
end
for i=1,3 do
  palette(statusColors[i],bases[i])
  palette(waterColors[i],blend(bases[i],{0.12,0.35,1},0.45))
  palette(mountainColors[i],blend(bases[i],{1,1,1},0.45))
  palette(mixedColors[i],blend(blend(bases[i],{0.12,0.35,1},0.45),{1,1,1},0.35))
end
palette(colors.lightGray,{0.55,0.90,0.65}) -- safe-zone mint
local pointFile = 'front_points.json'
local cacheFile = 'front_snapshot.json'
local function loadJSON(path)
  if not fs.exists(path) then return nil end
  local f = fs.open(path, 'r')
  if not f then return nil end
  local text = f.readAll(); f.close()
  local ok, value = pcall(textutils.unserialiseJSON, text)
  return ok and value or nil
end
local function saveJSON(path, value)
  local f = assert(fs.open(path, 'w'), 'Cannot write '..path)
  f.write(textutils.serialiseJSON(value)); f.close()
end
points = loadJSON(pointFile) or {}
data = loadJSON(cacheFile)
local function validSnapshot(value)
  return type(value)=='table' and value.version==1 and type(value.areas)=='table'
    and type(value.sector_size)=='number' and value.sector_size>0
end
if not validSnapshot(data) then data=nil end
if type(points)~='table' then points={} end
for i=#points,1,-1 do
  if type(points[i])~='table' or type(points[i].x)~='number' or type(points[i].z)~='number' then table.remove(points,i) end
end
if data then data.controls=data.controls or {}; data.terrain=data.terrain or {}; data.garrisons=data.garrisons or {} end
local function bounds()
  local area = data and data.areas and data.areas[areaIndex]
  if not area then return nil end
  local s = data.sector_size
  return math.floor(math.min(area.x1,area.x2)/s), math.floor(math.min(area.z1,area.z2)/s),
    math.floor(math.max(area.x1,area.x2)/s), math.floor(math.max(area.z1,area.z2)/s)
end
local function fit()
  local x1,z1,x2,z2 = bounds()
  if not x1 then return end
  local w,h = screen.getSize()
  zoom = math.min(16,math.max(1, math.ceil((x2-x1+1)/w), math.ceil((z2-z1+1)/math.max(1,h-5))))
  left=x1-math.floor((w*zoom-(x2-x1+1))/2)
  top=z1-math.floor((math.max(1,h-5)*zoom-(z2-z1+1))/2)
  fitted = true
end
local function refresh()
  local port = peripheral.find('front_map')
  if not port then message = 'OFFLINE: connect a lectern (front_map)'; return end
  local ok, raw = pcall(port.getMapJSON)
  if not ok or type(raw)~='string' or raw=='' then message = 'Waiting for KubeJS snapshot'; return end
  local parsedOK, snapshot = pcall(textutils.unserialiseJSON, raw)
  if not parsedOK or not validSnapshot(snapshot) then
    message='Unsupported snapshot'; return
  end
  data=snapshot
  data.controls=data.controls or {}; data.terrain=data.terrain or {}; data.garrisons=data.garrisons or {}
  if areaIndex>#data.areas then areaIndex=1; fitted=false end
  saveJSON(cacheFile,data)
  if not fitted then fit() end
  message='Green: own  Yellow: front  Red: occupied'
end
local function control(sx,sz) return tonumber(data.controls[sx..','..sz]) or 0 end
local function inRect(x,z,r)
  return x>=math.min(r.x1,r.x2) and x<=math.max(r.x1,r.x2) and z>=math.min(r.z1,r.z2) and z<=math.max(r.z1,r.z2)
end
local function war(sx,sz)
  local s=data.sector_size
  local r=data.areas[areaIndex]
  return r and sx*s<=math.max(r.x1,r.x2) and (sx+1)*s>math.min(r.x1,r.x2)
    and sz*s<=math.max(r.z1,r.z2) and (sz+1)*s>math.min(r.z1,r.z2) or false
end
local function safe(sx,sz)
  if not war(sx,sz) then return false end
  local s=data.sector_size
  for _,r in ipairs(data.safe_zones or {}) do
    if sx*s<=math.max(r.x1,r.x2) and (sx+1)*s>math.min(r.x1,r.x2)
      and sz*s<=math.max(r.z1,r.z2) and (sz+1)*s>math.min(r.z1,r.z2) then return true end
  end
  return false
end
local function visible(sx,sz)
  if not war(sx,sz) then return false end
  local t=data.terrain[sx..','..sz]
  return not (t and (t.ocean or t.terrain=='ocean'))
end
local function status(sx,sz)
  if safe(sx,sz) then return 1 end
  local c=control(sx,sz)
  for _,n in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
    local nx,nz=sx+n[1],sz+n[2]
    if visible(nx,nz) and ((c>0)~=(control(nx,nz)>0)) then return 2 end
  end
  if c>0 then return 3 end
  return 1
end
local function tile(sx,sz)
  local key=sx..','..sz
  local c=control(sx,sz)
  local terrain=data.terrain[key]
  if not visible(sx,sz) then return ' ',colors.white,colors.black end
  local state=status(sx,sz)
  local wet=terrain and (terrain.river or terrain.terrain=='river' or (terrain.water_fraction or 0)>0)
  local high=terrain and (terrain.mountain or terrain.terrain=='mountain')
  local bg=statusColors[state]
  if wet and high then bg=mixedColors[state]
  elseif wet then bg=waterColors[state]
  elseif high then bg=mountainColors[state] end
  if safe(sx,sz) then bg=colors.lightGray end
  return ' ',colors.white,bg
end
local function line(y,text,fg,bg)
  local w=screen.getSize()
  screen.setCursorPos(1,y); screen.setBackgroundColor(bg or colors.black)
  screen.setTextColor(fg or colors.white); screen.write((text..string.rep(' ',w)):sub(1,w))
end
local function draw()
  local w,h=screen.getSize()
  if w<20 or h<9 then line(1,'Screen too small'); return end
  screen.setBackgroundColor(colors.black); screen.clear()
  line(1,'MILITARY MAP | '..(data and tostring(data.enemy) or 'OFFLINE'),colors.yellow)
  if not data then line(3,message); return end
  line(2,'N ^ (-Z)  W < (-X)  E > (+X)  S v (+Z) | Area '..areaIndex)
  hitCells={}
  for row=1,h-5 do
    local text,fgs,bgs={},{},{}
    for col=1,w do
      local sx,sz=left+(col-1)*zoom,top+(row-1)*zoom
      local char,fg,bg=' ',colors.white,colors.black
      local bestScore=-1
      local chosen=nil
      -- Only eligible war cells participate. Front takes priority at low detail.
      for dx=0,zoom-1 do for dz=0,zoom-1 do
        local nx,nz=sx+dx,sz+dz
        if visible(nx,nz) then
          local state=status(nx,nz)
          local score=state==2 and 3 or (state==3 and 2 or 1)
          if score>bestScore then
            bestScore=score; chosen={sx=nx,sz=nz}; char,fg,bg=tile(nx,nz)
          end
        end
      end end
      for _,p in ipairs(points) do
        local psx,psz=math.floor(p.x/data.sector_size),math.floor(p.z/data.sector_size)
        if visible(psx,psz) and psx>=sx and psx<sx+zoom and psz>=sz and psz<sz+zoom then
          char=tostring(p.symbol or p.kind or 'M'):sub(1,1); fg=colors.white
          chosen={sx=psx,sz=psz}
        end
      end
      if chosen then hitCells[col..','..(row+2)]=chosen end
      if chosen and selected and selected.sx>=sx and selected.sx<sx+zoom and selected.sz>=sz and selected.sz<sz+zoom and char==' ' then char='+' end
      text[col]=char; fgs[col]=colors.toBlit(fg); bgs[col]=colors.toBlit(bg)
    end
    screen.setCursorPos(1,row+2); screen.blit(table.concat(text),table.concat(fgs),table.concat(bgs))
  end
  if selected then
    local key=selected.sx..','..selected.sz
    local terrain=data.terrain[key]
    local s=data.sector_size
    line(h-2,'Sector '..key..' X/Z '..math.floor((selected.sx+.5)*s)..' '..math.floor((selected.sz+.5)*s)..' C:'..control(selected.sx,selected.sz)..'%')
    line(h-1,(safe(selected.sx,selected.sz) and 'SAFE overlap | ' or '')..(terrain and (terrain.terrain..' water '..math.floor(terrain.water_fraction*100)..'% probes '..terrain.known..'/5') or 'Terrain not surveyed'))
    for _,p in ipairs(points) do
      if math.floor(p.x/s)==selected.sx and math.floor(p.z/s)==selected.sz then line(h-1,(p.kind or 'N')..': '..tostring(p.label or 'Point'),colors.yellow) end
    end
  else
    line(h-2,'Green own | Yellow front | Red occupied | zoom '..zoom)
    line(h-1,message)
  end
  line(h,'Arrows pan +/- zoom Tab area R refresh A point D delete Q exit',colors.lightGray)
end
local function addPoint()
  if not selected or not data then return end
  if #points>=256 then message='Point limit: 256. Delete old points first.'; return end
  -- Prompts are entered on the computer even when the map is on a monitor.
  term.redirect(original); term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1)
  print('Point name (ASCII recommended):'); local name=read()
  if name=='' then return end
  print('Symbol: one Latin letter or digit (A-Z / 0-9)'); local kind=read():upper()
  if not kind:match('^[A-Z0-9]$') then message='Invalid symbol: use one letter or digit'; return end
  local s=data.sector_size
  points[#points+1]={id=tostring(os.epoch('utc')),label=name:sub(1,48),kind=kind,symbol=kind,x=math.floor((selected.sx+.5)*s),z=math.floor((selected.sz+.5)*s)}
  saveJSON(pointFile,points)
end
local function deletePoint()
  if not selected or not data then return end
  for i=#points,1,-1 do
    if math.floor(points[i].x/data.sector_size)==selected.sx and math.floor(points[i].z/data.sector_size)==selected.sz then table.remove(points,i) end
  end
  saveJSON(pointFile,points)
end
local function run()
  refresh(); if data and not fitted then fit() end
  local timer=os.startTimer(20)
  while true do
    draw()
    local e,a,b,c=os.pullEvent()
    if e=='timer' and a==timer then refresh(); timer=os.startTimer(20)
    elseif e=='term_resize' or e=='monitor_resize' then fit()
    elseif (e=='mouse_click' and screen==original) or (e=='monitor_touch' and screen~=original and a==peripheral.getName(screen)) then
      local w,h=screen.getSize()
      if b and c then selected=hitCells[b..','..c] end
    elseif e=='key' then
      if a==keys.left then left=left-zoom elseif a==keys.right then left=left+zoom
      elseif a==keys.up then top=top-zoom elseif a==keys.down then top=top+zoom
      elseif a==keys.tab and data and #data.areas>0 then areaIndex=areaIndex%#data.areas+1; fit(); selected=nil end
    elseif e=='char' then
      if a=='q' then break elseif a=='r' then refresh() elseif a=='a' then addPoint()
      elseif a=='d' then deletePoint() elseif a=='+' or a=='=' then zoom=math.max(1,zoom-1)
      elseif a=='-' then zoom=math.min(16,zoom+1) end
    end
  end
end
local ok,err=pcall(run)
for color,rgb in pairs(savedPalette) do screen.setPaletteColor(color,table.unpack(rgb)) end
term.redirect(original); term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1)
if not ok then print(err) end
