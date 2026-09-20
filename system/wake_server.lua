-- Optional Wake Node setup utility for a Central Server computer.
local args={...}
local node=peripheral.find('wake_node') or peripheral.find('wake_node_advanced')
local function fail(text)
  term.setTextColor(colors.red);print(text);term.setTextColor(colors.white)
end
if not node then
  fail('Wake Node unavailable. CC Wake Nodes is optional; the server will continue normally.')
  print('Install the mod and attach a Wake Node directly to this computer to use remote wake.')
  return
end
local function call(method,...)
  local fn=node[method]
  if type(fn)~='function' then return false,'Unsupported Wake Node API: '..method end
  local result=table.pack(pcall(fn,...))
  if not result[1] then return false,tostring(result[2]) end
  return true,table.unpack(result,2,result.n)
end
local function status()
  local ok,info=call('getInfo')
  if ok then print(textutils.serialize(info)) else fail(info) end
  local pok,permissions=call('getPermissions')
  if pok then print('Permissions: '..textutils.serialize(permissions)) else fail(permissions) end
end
local command=(args[1] or 'status'):lower()
if command=='setup' then
  local id=args[2] or 'central_server'
  local ok,result=call('setId',id)
  if ok then print('Wake Node registered as '..id) else fail(result) end
  status()
elseif command=='grant' or command=='revoke' then
  local id=tonumber(args[2])
  if not id or id<1 or id%1~=0 then fail('Provide a positive controller computer ID.');return end
  local method=command=='grant' and 'grantController' or 'revokeController'
  local ok,result=call(method,id)
  if ok then print((command=='grant' and 'Granted ' or 'Revoked ')..id) else fail(result) end
  status()
elseif command=='status' then
  status()
elseif command=='help' then
  print('wake setup [node_name]  - register this server')
  print('wake grant <HQ_ID>      - authorize HQ controller')
  print('wake revoke <HQ_ID>     - revoke HQ controller')
  print('wake status             - show node and ACL')
else
  fail('Unknown command. Run: wake help')
end
