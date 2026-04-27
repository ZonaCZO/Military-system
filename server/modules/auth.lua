local storage = require("server.modules.storage")

local auth = {}

local ROOT = "data/users"

local ROLE_POWER = {
  soldier = 1,
  commander = 2,
  general = 3
}

local function normalizeRole(role)
  role = tostring(role or "soldier"):lower()
  if ROLE_POWER[role] then return role end
  return "soldier"
end

function auth.rolePower(role)
  return ROLE_POWER[normalizeRole(role)] or 1
end

function auth.hasAccess(profile, minRole)
  if not profile then return false end
  return auth.rolePower(profile.role) >= auth.rolePower(minRole)
end

function auth.get(userId)
  if not userId then return nil end
  return storage.load(ROOT .. "/" .. tostring(userId) .. ".lua", nil)
end

function auth.save(profile)
  assert(type(profile) == "table", "profile must be a table")
  assert(profile.id, "profile.id is required")
  profile.role = normalizeRole(profile.role)
  return storage.save(ROOT .. "/" .. tostring(profile.id) .. ".lua", profile)
end

function auth.login(userId, password, requestedRole)
  local profile = auth.get(userId)
  if not profile then
    return false, nil, "unknown user"
  end

  if profile.password ~= password then
    return false, nil, "wrong password"
  end

  local role = normalizeRole(requestedRole or profile.role)
  if auth.rolePower(profile.role) < auth.rolePower(role) then
    return false, nil, "insufficient role"
  end

  return true, profile, nil
end

function auth.list()
  return storage.listLua(ROOT)
end

return auth