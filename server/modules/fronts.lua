local storage = require("server.modules.storage")

local fronts = {}

local ROOT = "data/map/fronts"

local function path(id)
  return ROOT .. "/" .. tostring(id) .. ".lua"
end

local function normalizeFront(front)
  front = front or {}
  front.id = tostring(front.id or "")
  front.name = front.name or front.id
  front.type = front.type or "active"
  front.description = front.description or ""
  front.bounds = front.bounds or { x1 = 0, z1 = 0, x2 = 0, z2 = 0 }
  front.markers = front.markers or {}
  front.plans = front.plans or {}
  front.tags = front.tags or {}
  return front
end

function fronts.list()
  local ids = storage.listLua(ROOT)
  local out = {}
  for _, id in ipairs(ids) do
    local front = storage.load(path(id), nil)
    if front then
      out[#out + 1] = {
        id = front.id,
        name = front.name,
        type = front.type,
        description = front.description or "",
        bounds = front.bounds or {},
        plans = front.plans or {},
        markers = front.markers or {}
      }
    end
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

function fronts.get(id)
  local front = storage.load(path(id), nil)
  if not front then return nil end
  return normalizeFront(front)
end

function fronts.save(front)
  front = normalizeFront(front)
  assert(front.id ~= "", "front.id is required")
  return storage.save(path(front.id), front)
end

function fronts.addMarker(frontId, marker)
  local front = fronts.get(frontId)
  if not front then
    return false, "front not found"
  end

  marker = marker or {}
  marker.id = marker.id or ("m_" .. tostring(os.epoch("utc")))
  marker.type = marker.type or "note"
  marker.label = marker.label or ""
  marker.x = tonumber(marker.x) or 0
  marker.z = tonumber(marker.z) or 0

  front.markers[#front.markers + 1] = marker
  fronts.save(front)
  return true, front
end

function fronts.attachPlan(frontId, planId)
  local front = fronts.get(frontId)
  if not front then
    return false, "front not found"
  end

  planId = tostring(planId)
  for _, id in ipairs(front.plans) do
    if id == planId then
      return true, front
    end
  end

  front.plans[#front.plans + 1] = planId
  fronts.save(front)
  return true, front
end

return fronts