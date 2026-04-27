local storage = require("server.modules.storage")
local fronts = require("server.modules.fronts")

local map = {}

local ROOT = "data/map"
local SECTORS = ROOT .. "/sectors"
local META = ROOT .. "/meta.lua"

local function normalizeMeta(meta)
  meta = meta or {}
  meta.sector_size = tonumber(meta.sector_size) or 32
  meta.default_view = tonumber(meta.default_view) or 3
  return meta
end

local function sectorPath(sx, sz)
  return SECTORS .. "/" .. tostring(sx) .. "_" .. tostring(sz) .. ".lua"
end

function map.getMeta()
  return normalizeMeta(storage.load(META, { sector_size = 32, default_view = 3 }))
end

function map.saveMeta(meta)
  meta = normalizeMeta(meta)
  return storage.save(META, meta)
end

function map.worldToSectorCoord(n, sectorSize)
  return math.floor(tonumber(n) / sectorSize)
end

function map.sectorKey(sx, sz)
  return tostring(sx) .. "_" .. tostring(sz)
end

function map.getSector(sx, sz)
  return storage.load(sectorPath(sx, sz), nil)
end

function map.saveSector(sector)
  assert(type(sector) == "table", "sector must be a table")
  assert(sector.x ~= nil and sector.z ~= nil, "sector.x and sector.z are required")
  sector.markers = sector.markers or {}
  sector.terrain = sector.terrain or "unknown"
  sector.discovered = not not sector.discovered
  return storage.save(sectorPath(sector.x, sector.z), sector)
end

function map.ensureSector(sx, sz)
  local existing = map.getSector(sx, sz)
  if existing then return existing end

  local sector = {
    x = sx,
    z = sz,
    discovered = false,
    terrain = "unknown",
    markers = {}
  }
  map.saveSector(sector)
  return sector
end

function map.getFrontSnapshot(frontId)
  local front = fronts.get(frontId)
  if not front then
    return nil, "front not found"
  end

  local meta = map.getMeta()
  local size = meta.sector_size

  local snapshot = {
    front = front,
    sector_size = size,
    sectors = {}
  }

  if front.bounds then
    local x1 = tonumber(front.bounds.x1) or 0
    local z1 = tonumber(front.bounds.z1) or 0
    local x2 = tonumber(front.bounds.x2) or 0
    local z2 = tonumber(front.bounds.z2) or 0

    local minSx = map.worldToSectorCoord(math.min(x1, x2), size)
    local maxSx = map.worldToSectorCoord(math.max(x1, x2), size)
    local minSz = map.worldToSectorCoord(math.min(z1, z2), size)
    local maxSz = map.worldToSectorCoord(math.max(z1, z2), size)

    for sx = minSx, maxSx do
      for sz = minSz, maxSz do
        local sector = map.getSector(sx, sz)
        if sector then
          snapshot.sectors[#snapshot.sectors + 1] = sector
        end
      end
    end
  end

  return snapshot
end

function map.addMarkerToSector(sx, sz, marker)
  local sector = map.ensureSector(sx, sz)
  marker = marker or {}
  marker.id = marker.id or ("m_" .. tostring(os.epoch("utc")))
  marker.type = marker.type or "note"
  marker.label = marker.label or ""
  marker.x = tonumber(marker.x) or 0
  marker.z = tonumber(marker.z) or 0

  sector.markers[#sector.markers + 1] = marker
  map.saveSector(sector)
  return true, sector
end

return map