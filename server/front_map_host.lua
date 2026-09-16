-- Run on a DEDICATED CC server with the Military-system server/modules tree.
-- Uses existing users and roles. Wired network ONLY: no radio passwords.
package.path='/?.lua;/?/init.lua;'..package.path
local auth=require('server.modules.auth')
local protocol='military_front_map_v9'
local sessions, points = {}, {}
local function load(path)
 if not fs.exists(path) then return {} end
 local f=assert(fs.open(path,'r'));local raw=f.readAll();f.close()
 local ok,v=pcall(textutils.unserialiseJSON,raw);return ok and type(v)=='table' and v or {}
end
local function save(path,value)
 fs.makeDir('data/front_map')
 local f=assert(fs.open(path,'w'));f.write(textutils.serialiseJSON(value));f.close()
end
local groups=load('data/front_map/groups.json')
local cached=load('data/front_map/snapshot.json')
points=load('data/front_map/points.json')
local open=false
for _,name in ipairs(peripheral.getNames()) do
 if peripheral.hasType(name,'modem') and not peripheral.call(name,'isWireless') then rednet.open(name);open=true end
end
assert(open,'Attach a wired modem. Wireless connections are not supported.')
print('Front map host ID: '..os.getComputerID())
print('Accounts: existing Military-system users; groups: data/front_map/groups.json')
while true do
 local sender,msg=rednet.receive(protocol)
 if type(msg)=='table' and type(msg.request)=='string' then
  local response={request=msg.request,ok=false}
  local now=os.epoch('utc')
  local session=sessions[sender]
  if msg.action=='login' then
   local ok,profile=auth.login(tostring(msg.user or ''),tostring(msg.password or ''))
   local group=ok and groups[profile.id]
   if ok and type(group)=='string' and group:match('^[%w_-]+$') then
    session={profile=profile,group=group,expires=now+1800000};sessions[sender]=session;response.ok=true
   else sessions[sender]=nil;response.error='Login failed or no state group assigned' end
  elseif session and session.expires>now then
   local group=session.group
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
    if not response.ok then response.error='KubeJS map unavailable' end
   elseif auth.hasAccess(session.profile,'commander') then
    if msg.action=='add' and #points[group]<256 and type(msg.x)=='number' and type(msg.z)=='number' and
       msg.x==msg.x and msg.z==msg.z and math.abs(msg.x)<=30000000 and math.abs(msg.z)<=30000000 and
       type(msg.label)=='string' and type(msg.kind)=='string' and msg.kind:match('^[A-Z0-9]$') then
     points[group][#points[group]+1]={id=tostring(now)..'_'..sender,label=msg.label:sub(1,48),kind=msg.kind,
       x=math.floor(msg.x),z=math.floor(msg.z),author=session.profile.id}
     save('data/front_map/points.json',points);response.ok=true
    elseif msg.action=='delete' and type(msg.id)=='string' then
     for i=#points[group],1,-1 do if points[group][i].id==msg.id then table.remove(points[group],i);response.ok=true end end
     if response.ok then save('data/front_map/points.json',points) end
    end
   else response.error='Commander role required to edit points' end
  else response.error='Session expired: restart map and log in again' end
  rednet.send(sender,response,protocol)
 end
end
