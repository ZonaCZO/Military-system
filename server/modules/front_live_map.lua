-- Invoked ONLY after the central core validates user token and sender computer.
local auth=require('server.modules.auth')
local map={}
local function load(path)
 if not fs.exists(path) then return {} end
 local f=assert(fs.open(path,'r'));local raw=f.readAll();f.close()
 local ok,value=pcall(textutils.unserialiseJSON,raw)
 return ok and type(value)=='table' and value or {}
end
local function save(path,value)
 fs.makeDir('data/front_map')
 local temp=path..'.new'
 local f=assert(fs.open(temp,'w'));f.write(textutils.serialiseJSON(value));f.close()
 local backup=path..'.previous'
 if fs.exists(backup) then fs.delete(backup) end
 if fs.exists(path) then fs.move(path,backup) end
 fs.move(temp,path)
end
local points=load('data/front_map/points.json')
local cached=load('data/front_map/snapshot.json')
function map.handle(msg,profile)
 local response={type='FRONT_LIVE_MAP',request=msg.request,ok=false}
 if not profile then response.error='Account not found';return response end
 local groups=load('data/front_map/groups.json')
 local group=groups[profile.id]
 if type(group)~='string' or not group:match('^[%w_-]+$') then response.error='No state group assigned';return response end
 points[group]=points[group] or {}
 if msg.action=='read' then
  local port=peripheral.find('front_map')
  if port then
   local ok,raw=pcall(port.getMapJSON)
   if ok and type(raw)=='string' and raw~='' then
    if cached.raw~=raw then cached={raw=raw};save('data/front_map/snapshot.json',cached) end
    response.map=raw;response.points=points[group];response.ok=true
   end
  end
  if not response.ok and cached.raw then response.map=cached.raw;response.points=points[group];response.ok=true;response.stale=true end
  if not response.ok then response.error='KubeJS map unavailable: attach lectern to central server' end
 elseif not auth.hasAccess(profile,'commander') then response.error='Commander role required to edit points'
 elseif msg.action=='add' and #points[group]<256 and type(msg.x)=='number' and type(msg.z)=='number' and
   msg.x==msg.x and msg.z==msg.z and math.abs(msg.x)<=30000000 and math.abs(msg.z)<=30000000 and
   type(msg.label)=='string' and type(msg.kind)=='string' and msg.kind:match('^[A-Z0-9]$') then
  points[group][#points[group]+1]={id=tostring(os.epoch('utc'))..'_'..profile.id,label=msg.label:sub(1,48),kind=msg.kind,
   x=math.floor(msg.x),z=math.floor(msg.z),author=profile.id}
  save('data/front_map/points.json',points);response.ok=true
 elseif msg.action=='delete' and type(msg.id)=='string' then
  for i=#points[group],1,-1 do if points[group][i].id==msg.id then table.remove(points[group],i);response.ok=true end end
  if response.ok then save('data/front_map/points.json',points) end
 end
 if not response.ok and not response.error then response.error='Invalid map request or point limit' end
 return response
end
return map
