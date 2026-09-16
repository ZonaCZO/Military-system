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
  left,top = x1,z1
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
  message='Updated. Water is sampled, ? means unknown.'
end
local function control(sx,sz) return tonumber(data.controls[sx..','..sz]) or 0 end
local function inRect(x,z,r)
  return x>=math.min(r.x1,r.x2) and x<=math.max(r.x1,r.x2) and z>=math.min(r.z1,r.z2) and z<=math.max(r.z1,r.z2)
end
local function war(sx,sz)
  local s=data.sector_size
  for _,r in ipairs(data.areas) do if inRect((sx+.5)*s,(sz+.5)*s,r) then return true end end
  return false
end
local function tile(sx,sz)
  local key=sx..','..sz
  local c=control(sx,sz)
  local terrain=data.terrain[key]
  local symbol=terrain and ({water='~',river='=',mountain='^',forest='*',land='.'})[terrain.terrain] or '?'
  local bg=war(sx,sz) and colors.green or colors.gray
  if c>0 then
    bg=colors.red
    if control(sx+1,sz)==0 or control(sx-1,sz)==0 or control(sx,sz+1)==0 or control(sx,sz-1)==0 then bg=colors.orange end
  end
  local s=data.sector_size
  -- Safe-zone overlap is indicated even if it only occupies part of a sector.
  for _,r in ipairs(data.safe_zones or {}) do
    if sx*s<=math.max(r.x1,r.x2) and (sx+1)*s>math.min(r.x1,r.x2) and
      sz*s<=math.max(r.z1,r.z2) and (sz+1)*s>math.min(r.z1,r.z2) then bg=colors.cyan; symbol='B' end
  end
  if data.garrisons[key] then symbol='G' end
  for _,o in ipairs(data.origins or {}) do
    if math.floor(o.x/s)==sx and math.floor(o.z/s)==sz then symbol='O' end
  end
  return symbol, terrain and (terrain.water_fraction or 0)>0 and colors.lightBlue or colors.white, bg
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
  line(2,'Area '..areaIndex..' | '..data.sector_size..' blocks/sector | zoom '..zoom)
  for row=1,h-5 do
    local text,fgs,bgs={},{},{}
    for col=1,w do
      local sx,sz=left+(col-1)*zoom,top+(row-1)*zoom
      local char,fg,bg=tile(sx,sz)
      local bestControl=control(sx,sz)
      -- Zoomed cells show the highest-control sample rather than hiding a front.
      for dx=0,zoom-1 do for dz=0,zoom-1 do
        if control(sx+dx,sz+dz)>bestControl then
          bestControl=control(sx+dx,sz+dz)
          char,fg,bg=tile(sx+dx,sz+dz)
        end
      end end
      for _,p in ipairs(points) do
        local psx,psz=math.floor(p.x/data.sector_size),math.floor(p.z/data.sector_size)
        if psx>=sx and psx<sx+zoom and psz>=sz and psz<sz+zoom then char=p.kind or 'M'; fg=colors.yellow end
      end
      if selected and selected.sx>=sx and selected.sx<sx+zoom and selected.sz>=sz and selected.sz<sz+zoom then fg=colors.black; bg=colors.white end
      text[col]=char; fgs[col]=colors.toBlit(fg); bgs[col]=colors.toBlit(bg)
    end
    screen.setCursorPos(1,row+2); screen.blit(table.concat(text),table.concat(fgs),table.concat(bgs))
  end
  if selected then
    local key=selected.sx..','..selected.sz
    local terrain=data.terrain[key]
    local s=data.sector_size
    line(h-2,'Sector '..key..' X/Z '..math.floor((selected.sx+.5)*s)..' '..math.floor((selected.sz+.5)*s)..' C:'..control(selected.sx,selected.sz)..'%')
    line(h-1,terrain and (terrain.terrain..' water '..math.floor(terrain.water_fraction*100)..'% probes '..terrain.known..'/5') or 'Unknown terrain: explore these chunks first.')
    for _,p in ipairs(points) do
      if math.floor(p.x/s)==selected.sx and math.floor(p.z/s)==selected.sz then line(h-1,(p.kind or 'N')..': '..tostring(p.label or 'Point'),colors.yellow) end
    end
  else
    line(h-2,'~ water  = river  ^ mountains  * forest  G troops  O origin')
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
  print('Type: B base, T target, R route, N note'); local kind=read():upper():sub(1,1)
  if not ({B=true,T=true,R=true,N=true})[kind] then kind='N' end
  local s=data.sector_size
  points[#points+1]={id=tostring(os.epoch('utc')),label=name:sub(1,48),kind=kind,x=math.floor((selected.sx+.5)*s),z=math.floor((selected.sz+.5)*s)}
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
      if b and c and b>=1 and b<=w and c>=3 and c<=h-3 then selected={sx=left+(b-1)*zoom,sz=top+(c-3)*zoom} end
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
term.redirect(original); term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1)
if not ok then print(err) end
