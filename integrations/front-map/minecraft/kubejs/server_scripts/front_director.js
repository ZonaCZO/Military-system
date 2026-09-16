// Front Director v3 — KubeJS 2001.6.5 / Forge 1.20.1
// Dynamic sector front. CaptureZone is not used.

var FD_BlockPos = Java.loadClass('net.minecraft.core.BlockPos')
var FD_Heightmap = Java.loadClass('net.minecraft.world.level.levelgen.Heightmap$Types')
var FD_LostCities = Java.loadClass('mcjty.lostcities.LostCities')

var FD_CONFIG = 'kubejs/config/front_director_v3.json'
var FD_CHECK_TICKS = 400 // 20 seconds; low-CPU profile

var fdConfig = null
var fdState = {}
var fdTick = 0
var fdExpansionClock = 0
var fdDirty = false
var fdInitialized = false
var fdCityCache = {}
var fdCombatTick = 0
var fdSharedIntel = null
var fdTrackedRobots = []
var fdTrackedSem = []
var fdEntityScanTick = -999999
var fdCombatCursor = 0
var fdTerrainCache = {}
var fdSupplyCache = {}
var fdOps = { liberated: {}, protection: {}, garrisons: {}, alerts: {} }
var fdOpsDirty = false

var FD_AI_INTERVAL = 80 // 4 seconds; low-CPU combat network
var FD_ENTITY_SCAN_INTERVAL = 400 // full world scan only every 20 seconds
var FD_AI_BATCH = 8 // spread robot AI work across multiple checks
var FD_INTEL_TTL = 20 * 30 // 30 seconds
var FD_SEM_DETECTION_RANGE_SQ = 16 * 16
var FD_INTEL_GRID = 32 // reported coordinates are deliberately approximate

function fdCmd(server, command) {
  try { return server.runCommandSilent(command) } catch (ignored) { return 0 }
}

function fdTell(server, text, color) {
  var safe = String(text).replace(/\\/g, '\\\\').replace(/"/g, '\\"')
  fdCmd(server, `tellraw @a {"text":"[Фронт] ${safe}","color":"${color || 'gold'}"}`)
}

function fdLoadConfig() {
  fdConfig = JsonIO.read(FD_CONFIG)
  if (!fdConfig) throw new Error(`Не найден ${FD_CONFIG}`)
}

function fdWorld(server) {
  return server.overworld()
}

function fdKey(sx, sz) { return sx + ',' + sz }
function fdSX(x) { return Math.floor(x / Number(fdConfig.sectorSize)) }
function fdSZ(z) { return Math.floor(z / Number(fdConfig.sectorSize)) }
function fdOptionNumber(name, fallback) {
  return fdConfig[name] == null ? fallback : Number(fdConfig[name])
}

function fdGameTime(server) {
  try { return Number(fdWorld(server).getGameTime()) } catch (ignored) { return 0 }
}

function fdOpsLoad(server) {
  try {
    fdOps = server.persistentData.contains('front_director_v6_ops')
      ? JSON.parse(String(server.persistentData.getString('front_director_v6_ops')))
      : { liberated: {}, protection: {}, garrisons: {}, alerts: {} }
  } catch (error) {
    console.error('[Front Director v6] operations state reset: ' + error)
    fdOps = { liberated: {}, protection: {}, garrisons: {}, alerts: {} }
  }
  if (!fdOps.liberated) fdOps.liberated = {}
  if (!fdOps.protection) fdOps.protection = {}
  if (!fdOps.garrisons) fdOps.garrisons = {}
  if (!fdOps.alerts) fdOps.alerts = {}
}

function fdOpsSave(server) {
  if (!fdOpsDirty) return
  server.persistentData.putString('front_director_v6_ops', JSON.stringify(fdOps))
  fdOpsDirty = false
}

function fdRandomFrom(list, fallback) {
  if (list == null || list.length === 0) return fallback
  return String(list[Math.floor(Math.random() * list.length)])
}

function fdInfantryType() {
  return fdRandomFrom(fdConfig.infantryEntities, fdRandomFrom([
    'crusty_chunks:striker',
    'crusty_chunks:striker',
    'crusty_chunks:rifler',
    'crusty_chunks:rifler',
    'crusty_chunks:worker',
    'crusty_chunks:breacher',
    'crusty_chunks:scout',
    'crusty_chunks:assassin'
  ], 'crusty_chunks:striker'))
}

function fdSupportType() {
  return fdRandomFrom(fdConfig.supportEntities, fdRandomFrom([
    'crusty_chunks:breacher',
    'crusty_chunks:scout',
    'crusty_chunks:assassin',
    'crusty_chunks:commander'
  ], 'crusty_chunks:breacher'))
}

function fdIsAircraftType(type) {
  var aircraft = fdConfig.aircraftEntities || ['crusty_chunks:hunter']
  for (var i = 0; i < aircraft.length; i++) {
    if (String(aircraft[i]) === String(type)) return true
  }
  return false
}

function fdSectorCenter(sx, sz) {
  var size = Number(fdConfig.sectorSize)
  return { x: sx * size + Math.floor(size / 2), z: sz * size + Math.floor(size / 2) }
}

function fdInRect(x, z, rect) {
  return x >= Math.min(rect.x1, rect.x2) && x <= Math.max(rect.x1, rect.x2) &&
    z >= Math.min(rect.z1, rect.z2) && z <= Math.max(rect.z1, rect.z2)
}

function fdInWarArea(x, z) {
  for (var i = 0; i < fdConfig.warAreas.length; i++) {
    if (fdInRect(x, z, fdConfig.warAreas[i])) return true
  }
  return false
}

function fdInSafeZone(x, z) {
  for (var i = 0; i < fdConfig.safeZones.length; i++) {
    if (fdInRect(x, z, fdConfig.safeZones[i])) return true
  }
  return false
}

function fdAllowedSector(sx, sz) {
  var c = fdSectorCenter(sx, sz)
  return fdInWarArea(c.x, c.z) && !fdInSafeZone(c.x, c.z)
}

function fdBiomeIdAtLoaded(level, x, z) {
  if (!level.getChunkSource().hasChunk(x >> 4, z >> 4)) return ''
  try {
    var y = level.getHeight(FD_Heightmap.MOTION_BLOCKING_NO_LEAVES, x, z)
    var holder = level.getBiome(new FD_BlockPos(x, y, z))
    var key = holder.unwrapKey()
    if (key.isPresent()) return String(key.get().location())
  } catch (ignored) {}
  return ''
}

function fdSectorTerrain(level, sx, sz) {
  var key = fdKey(sx, sz)
  if (fdTerrainCache[key] != null) return fdTerrainCache[key]
  var size = Number(fdConfig.sectorSize)
  var startX = sx * size
  var startZ = sz * size
  var points = [[0.5,0.5],[0.25,0.25],[0.75,0.25],[0.25,0.75],[0.75,0.75]]
  var peaks = 0
  var rivers = 0
  var known = 0
  for (var i = 0; i < points.length; i++) {
    var id = fdBiomeIdAtLoaded(level,
      Math.floor(startX + size * points[i][0]),
      Math.floor(startZ + size * points[i][1]))
    if (!id) continue
    known++
    if (id.indexOf('peak') >= 0 || id.indexOf('mountain') >= 0) peaks++
    if (id.indexOf('river') >= 0) rivers++
  }
  // Unknown/unloaded terrain never forces chunk generation on the server thread.
  var result = { name: 'обычная местность', factor: 1.0 }
  if (rivers > 0) result = { name: 'река', factor: fdOptionNumber('riverExpansionFactor', 0.20) }
  else if (peaks > 0) result = { name: 'горы', factor: fdOptionNumber('peakExpansionFactor', 0.35) }
  if (known > 0) fdTerrainCache[key] = result
  return result
}

function fdControl(sx, sz) {
  var v = fdState[fdKey(sx, sz)]
  return v == null ? 0 : Number(v)
}

function fdSetControl(sx, sz, value) {
  var key = fdKey(sx, sz)
  var old = fdControl(sx, sz)
  var next = Math.max(0, Math.min(100, Math.round(value)))
  if (old === next) return
  if (next === 0) delete fdState[key]
  else fdState[key] = next
  fdDirty = true
}

function fdSave(server) {
  if (!fdDirty) return
  server.persistentData.putString('front_director_v3_state', JSON.stringify(fdState))
  fdDirty = false
}

function fdLoadState(server) {
  try {
    fdState = server.persistentData.contains('front_director_v3_state')
      ? JSON.parse(String(server.persistentData.getString('front_director_v3_state')))
      : {}
  } catch (error) {
    console.error('[Front Director v3] state reset: ' + error)
    fdState = {}
  }

  for (var i = 0; i < fdConfig.origins.length; i++) {
    fdSetControl(
      fdSX(fdConfig.origins[i].x),
      fdSZ(fdConfig.origins[i].z),
      100
    )
  }
  fdSave(server)
}

function fdNearestOriginDistance(sx, sz) {
  var c = fdSectorCenter(sx, sz)
  var best = 999999999
  for (var i = 0; i < fdConfig.origins.length; i++) {
    var dx = c.x - Number(fdConfig.origins[i].x)
    var dz = c.z - Number(fdConfig.origins[i].z)
    best = Math.min(best, Math.sqrt(dx * dx + dz * dz))
  }
  return best
}

function fdStrength(sx, sz) {
  var distance = fdNearestOriginDistance(sx, sz)
  var falloff = Math.max(0.20, 1.0 - distance / Number(fdConfig.fullSafetyDistance))
  return falloff
}

function fdNeighborHasControl(sx, sz, minimum) {
  return fdControl(sx + 1, sz) >= minimum || fdControl(sx - 1, sz) >= minimum ||
    fdControl(sx, sz + 1) >= minimum || fdControl(sx, sz - 1) >= minimum
}

function fdIsFrontier(sx, sz) {
  var control = fdControl(sx, sz)
  if (control > 0 && control < 100) return true
  if (control === 0) return fdNeighborHasControl(sx, sz, Number(fdConfig.expansionSourceControl))
  return fdControl(sx + 1, sz) < 50 || fdControl(sx - 1, sz) < 50 ||
    fdControl(sx, sz + 1) < 50 || fdControl(sx, sz - 1) < 50
}

function fdRebuildSupply() {
  var supplied = {}
  var queue = []
  var minimum = fdOptionNumber('supplyControlMinimum', 50)
  for (var i = 0; i < fdConfig.origins.length; i++) {
    var sx = fdSX(fdConfig.origins[i].x)
    var sz = fdSZ(fdConfig.origins[i].z)
    var key = fdKey(sx, sz)
    supplied[key] = true
    queue.push({sx: sx, sz: sz})
  }
  var dirs = [[1,0],[-1,0],[0,1],[0,-1]]
  while (queue.length > 0) {
    var current = queue.shift()
    for (var d = 0; d < dirs.length; d++) {
      var nx = current.sx + dirs[d][0]
      var nz = current.sz + dirs[d][1]
      var nk = fdKey(nx, nz)
      if (supplied[nk] || fdControl(nx, nz) < minimum) continue
      supplied[nk] = true
      queue.push({sx: nx, sz: nz})
    }
  }
  fdSupplyCache = supplied
}

function fdIsSupplied(sx, sz) {
  return fdSupplyCache[fdKey(sx, sz)] === true
}

function fdApplyIsolation(server) {
  fdRebuildSupply()
  var decay = fdOptionNumber('isolatedControlLossPerCycle', 8)
  Object.keys(fdState).forEach(key => {
    if (fdSupplyCache[key]) return
    var pair = key.split(',')
    fdSetControl(Number(pair[0]), Number(pair[1]), Number(fdState[key]) - decay)
  })
}

function fdStrategicExpansion(server) {
  var level = fdWorld(server)
  fdApplyIsolation(server)
  var candidates = []
  var seen = {}
  var dirs = [[1,0],[-1,0],[0,1],[0,-1]]

  Object.keys(fdState).forEach(key => {
    var pair = key.split(',')
    var sx = Number(pair[0])
    var sz = Number(pair[1])
    if (fdControl(sx, sz) < Number(fdConfig.expansionSourceControl)) return

    for (var d = 0; d < dirs.length; d++) {
      var nx = sx + dirs[d][0]
      var nz = sz + dirs[d][1]
      var nk = fdKey(nx, nz)
      if (seen[nk] || !fdAllowedSector(nx, nz) || fdControl(nx, nz) >= 100) continue
      if (Number(fdOps.protection[nk] || 0) > fdGameTime(server)) continue
      seen[nk] = true
      candidates.push({ sx: nx, sz: nz })
    }
  })

  if (candidates.length === 0) return
  candidates.sort((a, b) => fdNearestOriginDistance(a.sx, a.sz) - fdNearestOriginDistance(b.sx, b.sz))
  var limit = Math.min(Number(fdConfig.sectorsAdvancedPerCycle), candidates.length)

  for (var i = 0; i < limit; i++) {
    var terrain = fdSectorTerrain(level, candidates[i].sx, candidates[i].sz)
    var strategicGain = Math.max(1, Math.round(Number(fdConfig.expansionControlGain) *
      fdStrength(candidates[i].sx, candidates[i].sz) * terrain.factor))
    var candidateKey = fdKey(candidates[i].sx, candidates[i].sz)
    var garrison = fdOps.garrisons[candidateKey]
    if (garrison && Number(garrison.strength) > 0) {
      strategicGain -= Number(garrison.strength) * fdOptionNumber('garrisonDefensePerSoldier', 3)
      fdOps.alerts[candidateKey] = Math.min(4, Number(fdOps.alerts[candidateKey] || 0) + 1)
      fdOpsDirty = true
      if (strategicGain <= 0) continue
    }
    fdSetControl(candidates[i].sx, candidates[i].sz,
      fdControl(candidates[i].sx, candidates[i].sz) + strategicGain)
  }
  fdSave(server)
  fdOpsSave(server)
}

function fdCount(server, selector) {
  fdCmd(server, 'scoreboard players set #fdscan fd_tmp 0')
  fdCmd(server, `execute as ${selector} run scoreboard players add #fdscan fd_tmp 1`)
  return fdCmd(server, 'scoreboard players get #fdscan fd_tmp')
}

function fdSectorBox(sx, sz) {
  var size = Number(fdConfig.sectorSize)
  return `x=${sx * size},y=-64,z=${sz * size},dx=${size - 1},dy=384,dz=${size - 1}`
}

function fdRobotSelector(sx, sz) {
  return `@e[tag=fd_robot,${fdSectorBox(sx, sz)}]`
}

function fdLiberateSector(server, sx, sz, liberator) {
  // Only Front Director robots are removed. Players, SEM/PMC soldiers,
  // villagers and map-maker entities are deliberately untouched.
  fdCmd(server, `kill ${fdRobotSelector(sx, sz)}`)
  fdTrackedRobots = fdTrackedRobots.filter(robot => {
    if (!robot || !robot.isAlive()) return false
    return fdSX(robot.x) !== sx || fdSZ(robot.z) !== sz
  })
  var who = liberator == null ? 'игроком' : String(liberator.username)
  var key = fdKey(sx, sz)
  fdOps.liberated[key] = true
  fdOps.protection[key] = fdGameTime(server) + fdOptionNumber('liberationProtectionMinutes', 15) * 60 * 20
  fdOps.alerts[key] = 0
  fdOpsDirty = true
  if (liberator != null) fdScoreAdd(server, liberator, 'front_sectors', 1)
  fdTell(server, `Сектор ${sx},${sz} освобождён (${who}). Остатки сил ${fdEnemyName(server)} уничтожены.`, 'green')
}

function fdDefenderCount(server, sx, sz) {
  var box = fdSectorBox(sx, sz)
  var total = fdCount(server, `@a[${box}]`)
  for (var i = 0; i < fdConfig.alliedEntities.length; i++) {
    total += fdCount(server, `@e[type=${fdConfig.alliedEntities[i]},${box}]`)
  }
  return total
}

function fdIsRobot(entity) {
  var id = String(entity.type)
  for (var i = 0; i < fdConfig.robotEntities.length; i++) {
    if (id === String(fdConfig.robotEntities[i])) return true
  }
  var rare = fdConfig.rareSupportEntities || []
  for (var r = 0; r < rare.length; r++) {
    if (id === String(rare[r])) return true
  }
  return entity.tags && entity.tags.contains && entity.tags.contains('fd_robot')
}

function fdEntityId(entity) {
  try { return String(entity.type.arch$registryName()) } catch (ignored) {}
  try { return String(entity.type) } catch (ignored) {}
  return ''
}

function fdIsDefenderEntity(entity) {
  try { if (entity.isPlayer()) return true } catch (ignored) {}
  var id = fdEntityId(entity)
  for (var i = 0; i < fdConfig.alliedEntities.length; i++) {
    if (id === String(fdConfig.alliedEntities[i])) return true
  }
  // All three Simple Enemy Mod armies are valid Warium targets.
  return id.indexOf('simpleenemymod:') === 0
}

function fdDistanceSq(a, b) {
  var dx = a.x - b.x
  var dy = a.y - b.y
  var dz = a.z - b.z
  return dx * dx + dy * dy + dz * dz
}

function fdHasLineOfSight(observer, target) {
  try { return observer.getSensing().hasLineOfSight(target) } catch (ignored) {}
  try { return observer.hasLineOfSight(target) } catch (ignored) {}
  return false
}

function fdRememberTarget(target) {
  fdSharedIntel = {
    x: Math.round(target.x / FD_INTEL_GRID) * FD_INTEL_GRID,
    y: Math.round(target.y),
    z: Math.round(target.z / FD_INTEL_GRID) * FD_INTEL_GRID,
    expires: fdCombatTick + FD_INTEL_TTL,
    target: target
  }
}

function fdAdvanceDestination(level, robot) {
  var sx = fdSX(robot.x)
  var sz = fdSZ(robot.z)
  var currentControl = fdControl(sx, sz)
  if (currentControl <= 0) return null

  var dirs = [[1,0],[-1,0],[0,1],[0,-1]]
  var best = null
  var bestScore = -999999
  for (var i = 0; i < dirs.length; i++) {
    var nx = sx + dirs[i][0]
    var nz = sz + dirs[i][1]
    if (!fdAllowedSector(nx, nz)) continue
    var neighborControl = fdControl(nx, nz)
    if (neighborControl >= currentControl && neighborControl >= 70) continue
    var terrain = fdSectorTerrain(level, nx, nz)
    var score = (currentControl - neighborControl) * 10 + fdNearestOriginDistance(nx, nz) / 256
    score -= (1.0 - terrain.factor) * fdOptionNumber('terrainPathPenalty', 500)
    if (score > bestScore) {
      bestScore = score
      best = fdSectorCenter(nx, nz)
    }
  }
  if (best == null) return null
  if (!level.getChunkSource().hasChunk(best.x >> 4, best.z >> 4)) return null
  best.y = level.getHeight(FD_Heightmap.MOTION_BLOCKING_NO_LEAVES, best.x, best.z)
  return best
}

function fdCombatNetwork(server) {
  var level = fdWorld(server)
  if (fdCombatTick - fdEntityScanTick >= FD_ENTITY_SCAN_INTERVAL) {
    fdTrackedRobots = []
    fdTrackedSem = []
    var iterator = level.getAllEntities().iterator()
    while (iterator.hasNext()) {
      var scannedEntity = iterator.next()
      if (!scannedEntity.isAlive()) continue
      if (fdIsRobot(scannedEntity) && scannedEntity.getTags().contains('fd_robot')) fdTrackedRobots.push(scannedEntity)
      else if (fdEntityId(scannedEntity).indexOf('simpleenemymod:') === 0) fdTrackedSem.push(scannedEntity)
    }
    fdEntityScanTick = fdCombatTick
    if (fdCombatCursor >= fdTrackedRobots.length) fdCombatCursor = 0
  }

  var robots = fdTrackedRobots
  var semSoldiers = fdTrackedSem
  if (robots.length === 0) return
  var batch = Math.min(FD_AI_BATCH, robots.length)

  // Player detection belongs entirely to Stealth. We only relay a target that
  // Warium's own AI has already acquired. This preserves light, crouching,
  // movement, grass, FOV, vibration and TaCZ-Stealth bridge behavior.
  for (var r = 0; r < batch; r++) {
    var robot = robots[(fdCombatCursor + r) % robots.length]
    if (!robot || !robot.isAlive()) continue
    var acquiredTarget = null
    try { acquiredTarget = robot.getTarget() } catch (ignored) {}
    if (acquiredTarget != null && acquiredTarget.isAlive() && fdIsDefenderEntity(acquiredTarget)) {
      fdRememberTarget(acquiredTarget)
      continue
    }

    // SEM units are not players, so Stealth does not expose a player-visibility
    // value for them. Require close range and a real line of sight.
    var nearestSem = null
    var nearestSemDistance = FD_SEM_DETECTION_RANGE_SQ
    for (var d = 0; d < semSoldiers.length; d++) {
      var semDistance = fdDistanceSq(robot, semSoldiers[d])
      if (semDistance < nearestSemDistance && fdHasLineOfSight(robot, semSoldiers[d])) {
        nearestSemDistance = semDistance
        nearestSem = semSoldiers[d]
      }
    }
    if (nearestSem != null) {
      try { robot.setTarget(nearestSem) } catch (ignored) {}
      fdRememberTarget(nearestSem)
    }
  }

  if (fdSharedIntel != null && fdSharedIntel.expires < fdCombatTick) fdSharedIntel = null

  // Unengaged robots respond to shared intel, otherwise they advance one sector.
  for (var a = 0; a < batch; a++) {
    var movingRobot = robots[(fdCombatCursor + a) % robots.length]
    if (!movingRobot || !movingRobot.isAlive()) continue
    var currentTarget = null
    try { currentTarget = movingRobot.getTarget() } catch (ignored) {}
    if (currentTarget != null && currentTarget.isAlive()) continue

    if (fdSharedIntel != null) {
      try {
        // Radio only supplies an approximate search area. Each robot must then
        // acquire the player through its own AI, where Stealth remains active.
        movingRobot.getNavigation().moveTo(fdSharedIntel.x, fdSharedIntel.y, fdSharedIntel.z, 1.15)
      } catch (ignored) {}
      continue
    }

    var destination = fdAdvanceDestination(level, movingRobot)
    if (destination != null) {
      try { movingRobot.getNavigation().moveTo(destination.x, destination.y, destination.z, 1.0) } catch (ignored) {}
    }
  }
  fdCombatCursor = (fdCombatCursor + batch) % robots.length
}

function fdLoadedSurface(level, x, z) {
  var probe = new FD_BlockPos(x, 64, z)
  if (!level.getChunkSource().hasChunk(x >> 4, z >> 4)) return null

  var y = level.getHeight(FD_Heightmap.MOTION_BLOCKING_NO_LEAVES, x, z)
  if (y <= Number(fdConfig.minimumSurfaceY) || y >= Number(fdConfig.maximumSurfaceY)) return null

  var floorPos = new FD_BlockPos(x, y - 1, z)
  var feetPos = new FD_BlockPos(x, y, z)
  var headPos = new FD_BlockPos(x, y + 1, z)

  // No invasion spawns inside caves, dungeons, bunkers or covered rooms.
  if (!level.canSeeSky(feetPos)) return null

  var floor = level.getBlockState(floorPos)
  var feet = level.getBlockState(feetPos)
  var head = level.getBlockState(headPos)

  if (!floor.getFluidState().isEmpty()) return null
  if (!feet.isAir() || !head.isAir()) return null
  var floorId = String(floor.block.id)
  if (floorId.indexOf('leaves') >= 0 || floorId.indexOf('ice') >= 0) return null
  return y
}

function fdIsCitySector(level, sx, sz) {
  var key = fdKey(sx, sz)
  if (fdCityCache[key] != null) return fdCityCache[key]

  try {
    var citySectorSize = Number(fdConfig.sectorSize)
    var startX = sx * citySectorSize
    var startZ = sz * citySectorSize
    var samples = [
      [startX + citySectorSize / 2, startZ + citySectorSize / 2],
      [startX + citySectorSize / 4, startZ + citySectorSize / 4],
      [startX + citySectorSize * 3 / 4, startZ + citySectorSize / 4],
      [startX + citySectorSize / 4, startZ + citySectorSize * 3 / 4],
      [startX + citySectorSize * 3 / 4, startZ + citySectorSize * 3 / 4]
    ]
    var info = FD_LostCities.lostCitiesImp.getLostInfo(level)
    var cityHits = 0
    for (var i = 0; i < samples.length; i++) {
      var cx = Math.floor(samples[i][0]) >> 4
      var cz = Math.floor(samples[i][1]) >> 4
      if (!level.getChunkSource().hasChunk(cx, cz)) continue
      if (info.getChunkInfo(cx, cz).isCity()) cityHits++
    }
    fdCityCache[key] = cityHits >= fdOptionNumber('citySamplesRequired', 2)
  } catch (error) {
    console.warn('[Front Director v3.3] Lost Cities check failed for ' + key + ': ' + error)
    fdCityCache[key] = false
  }
  return fdCityCache[key]
}

function fdSpawnRobot(server, level, sx, sz, anchor, forcedType) {
  var size = Number(fdConfig.sectorSize)
  var margin = 20
  for (var attempt = 0; attempt < Number(fdConfig.surfaceAttempts); attempt++) {
    var x
    var z
    if (anchor) {
      var radius = fdOptionNumber('squadRadius', 10)
      x = anchor.x + Math.floor(Math.random() * (radius * 2 + 1)) - radius
      z = anchor.z + Math.floor(Math.random() * (radius * 2 + 1)) - radius
      x = Math.max(sx * size + margin, Math.min((sx + 1) * size - margin - 1, x))
      z = Math.max(sz * size + margin, Math.min((sz + 1) * size - margin - 1, z))
    } else {
      x = sx * size + margin + Math.floor(Math.random() * (size - margin * 2))
      z = sz * size + margin + Math.floor(Math.random() * (size - margin * 2))
    }
    if (fdInSafeZone(x, z)) continue
    var y = fdLoadedSurface(level, x, z)
    if (y == null) continue

    var types = fdConfig.robotEntities
    var type = forcedType || String(types[Math.floor(Math.random() * types.length)])
    var spawnY = fdIsAircraftType(type) ? y + fdOptionNumber('aircraftSpawnHeight', 28) : y
    fdCmd(server, `execute in minecraft:overworld run summon ${type} ${x} ${spawnY} ${z} {Tags:["fd_robot","fd_front_unit"],PersistenceRequired:1b}`)
    return { x: x, z: z }
  }
  return null
}

function fdActiveSectors(server, level) {
  var active = {}
  var radius = Number(fdConfig.activeRadiusSectors)
  var players = level.players

  for (var p = 0; p < players.size(); p++) {
    var player = players.get(p)
    var psx = fdSX(player.x)
    var psz = fdSZ(player.z)
    for (var dx = -radius; dx <= radius; dx++) {
      for (var dz = -radius; dz <= radius; dz++) {
        var sx = psx + dx
        var sz = psz + dz
        if (fdAllowedSector(sx, sz)) active[fdKey(sx, sz)] = { sx: sx, sz: sz }
      }
    }
  }
  return active
}

function fdShowPlayerStatus(server, player) {
  var sx = fdSX(player.x)
  var sz = fdSZ(player.z)
  var control = fdControl(sx, sz)
  var terrain = fdSectorTerrain(fdWorld(server), sx, sz)
  var supplied = control > 0 ? fdIsSupplied(sx, sz) : false
  var garrison = fdOps.garrisons[fdKey(sx, sz)]
  var label = 'мирная территория'
  var color = 'green'

  if (fdInSafeZone(player.x, player.z)) {
    label = 'безопасная зона'
    color = 'aqua'
  } else if (!fdInWarArea(player.x, player.z)) {
    label = 'вне театра войны'
    color = 'gray'
  } else if (fdIsFrontier(sx, sz)) {
    label = 'ЛИНИЯ ФРОНТА'
    color = 'gold'
  } else if (control >= 100) {
    label = 'тыл ' + fdEnemyName(server)
    color = 'red'
  } else if (control > 0) {
    label = 'спорная территория'
    color = 'yellow'
  }

  var name = String(player.username)
  var message = JSON.stringify({
    text: '[Фронт] ' + label + ' | сектор ' + sx + ',' + sz + ' | контроль ' + control +
      '% | ' + terrain.name + (control > 0 ? (supplied ? ' | снабжение есть' : ' | ОКРУЖЁН') : '') +
      (garrison ? ' | ТрО ' + garrison.strength + '/' + garrison.maxStrength : ''),
    color: color
  })
  fdCmd(server, 'tellraw ' + name + ' ' + message)
}

function fdStatusCommand(context) {
  var source = context.source
  var player = source.player
  if (player == null) return 0
  if (!fdInitialized && !fdInitialize(source.server)) return 0
  fdShowPlayerStatus(source.server, player)
  return 1
}

function fdTellPlayer(server, player, text, color) {
  var message = JSON.stringify({text: '[Фронт] ' + text, color: color || 'gold'})
  fdCmd(server, 'tellraw ' + String(player.username) + ' ' + message)
}

function fdEnemyName(server) {
  var name = String(server.persistentData.getString('front_enemy_name'))
  return name.length >= 3 ? name : 'Legion'
}

// Read-only bridge for the CC tactical map. No war-management authority is exposed.
global.frontMapBuild = function(server) {
  if (!fdInitialized && !fdInitialize(server)) return null
  function rectangles(source) {
    var result = []
    for (var i=0;i<source.length;i++) result.push({name:String(source[i].name || ''),
      x1:Number(source[i].x1),z1:Number(source[i].z1),x2:Number(source[i].x2),z2:Number(source[i].z2)})
    return result
  }
  var origins=[]
  for(var i=0;i<fdConfig.origins.length;i++) origins.push({name:String(fdConfig.origins[i].name || ''),
    x:Number(fdConfig.origins[i].x),z:Number(fdConfig.origins[i].z)})
  return JSON.stringify({version: 1, sector_size: Number(fdConfig.sectorSize),
    enemy: fdEnemyName(server), areas: rectangles(fdConfig.warAreas), safe_zones: rectangles(fdConfig.safeZones),
    origins: origins, controls: fdState, garrisons: fdOps.garrisons})
}

function fdStateName(player) {
  try {
    var saved = String(player.persistentData.getString('front_state_name'))
    if (saved.length >= 3) return saved
  } catch (ignored) {}
  return String(fdConfig.defaultStateName || 'Новое государство')
}

function fdSetStateName(player, rawName) {
  var name = String(rawName || '').replace(/[\x00-\x1F\x7F§]/g, '').trim()
  if (name.length < 3 || name.length > 32) return false
  player.persistentData.putString('front_state_name', name)
  return true
}

function fdScoreAdd(server, player, objective, amount) {
  fdCmd(server, 'scoreboard players add ' + String(player.username) + ' ' + objective + ' ' + Math.max(0, Math.floor(Number(amount))))
}

function fdCostItemCount(cost, wantedItem) {
  var result = 0
  try {
    var iterator = cost.entrySet().iterator()
    while (iterator.hasNext()) {
      var entry = iterator.next()
      if (String(entry.getKey()) === wantedItem) result += Number(entry.getValue())
    }
  } catch (ignored) {
    try { result = Number(cost[wantedItem] || 0) } catch (ignoredAgain) {}
  }
  return result
}

function fdMapGet(map, key) {
  if (map == null) return null
  try { return map.get(String(key)) } catch (ignored) {}
  try { return map[String(key)] } catch (ignored) {}
  return null
}

function fdCostFor(kind, level) {
  var table = fdConfig.economy ? fdMapGet(fdConfig.economy, kind) : null
  var configured = fdMapGet(table, String(level))
  if (configured != null) return configured
  if (kind === 'garrison') {
    if (level === 1) return {'minecraft:emerald': 8, 'minecraft:iron_ingot': 16}
    if (level === 2) return {'minecraft:emerald': 12, 'minecraft:iron_ingot': 24}
    return {'minecraft:emerald': 16, 'minecraft:iron_ingot': 32}
  }
  return {'minecraft:emerald': 16, 'minecraft:iron_ingot': 24}
}

function fdPay(server, player, cost) {
  var name = String(player.username)
  var entries = []
  try {
    var iterator = cost.entrySet().iterator()
    while (iterator.hasNext()) {
      var entry = iterator.next()
      entries.push({item: String(entry.getKey()), count: Number(entry.getValue())})
    }
  } catch (ignored) {
    var keys = Object.keys(cost)
    for (var k = 0; k < keys.length; k++) entries.push({item: keys[k], count: Number(cost[keys[k]])})
  }
  for (var i = 0; i < entries.length; i++) {
    if (fdCmd(server, 'clear ' + name + ' ' + entries[i].item + ' 0') < entries[i].count) return false
  }
  for (var j = 0; j < entries.length; j++) {
    fdCmd(server, 'clear ' + name + ' ' + entries[j].item + ' ' + entries[j].count)
  }
  return true
}

function fdSpawnFriendlySquad(server, player, type, count, tag) {
  var offsets = [[2,0],[-2,0],[0,2],[0,-2],[3,3],[-3,-3]]
  for (var i = 0; i < count; i++) {
    var off = offsets[i % offsets.length]
    fdCmd(server, `execute at ${String(player.username)} run summon ${type} ~${off[0]} ~ ~${off[1]} {Tags:["${tag}"],PersistenceRequired:1b}`)
  }
}

function fdGarrisonCommand(context, mode) {
  var source = context.source
  var player = source.player
  if (player == null) return 0
  var server = source.server
  if (!fdInitialized && !fdInitialize(server)) return 0
  var sx = fdSX(player.x)
  var sz = fdSZ(player.z)
  var key = fdKey(sx, sz)
  var existing = fdOps.garrisons[key]

  if (mode === 'status') {
    if (!existing) fdTellPlayer(server, player, 'В секторе нет ТрО.', 'gray')
    else fdTellPlayer(server, player, 'ТрО сектора ' + key + ': уровень ' + existing.level + ', бойцов ' + existing.strength + '/' + existing.maxStrength + '.', 'blue')
    return 1
  }
  if (!fdInWarArea(player.x, player.z) || fdInSafeZone(player.x, player.z) || fdControl(sx, sz) > 0) {
    fdTellPlayer(server, player, 'ТрО можно разместить только в свободном секторе театра войны.', 'red')
    return 0
  }
  var newLevel = existing ? Number(existing.level) + 1 : 1
  if (mode === 'deploy' && existing) {
    fdTellPlayer(server, player, 'ТрО уже размещена. Используй /front garrison upgrade.', 'yellow')
    return 0
  }
  if (mode === 'upgrade' && !existing) {
    fdTellPlayer(server, player, 'Сначала используй /front garrison.', 'yellow')
    return 0
  }
  if (newLevel > 3) {
    fdTellPlayer(server, player, 'ТрО уже максимального уровня.', 'yellow')
    return 0
  }
  if (!fdPay(server, player, fdCostFor('garrison', newLevel))) {
    fdTellPlayer(server, player, 'Недостаточно ресурсов для уровня ' + newLevel + '.', 'red')
    return 0
  }
  var targetSize = newLevel === 1 ? 3 : (newLevel === 2 ? 4 : 5)
  var oldSize = existing ? Number(existing.strength) : 0
  var add = Math.max(0, targetSize - oldSize)
  var sectorTag = 'fd_garrison_' + sx + '_' + sz
  fdSpawnFriendlySquad(server, player, fdConfig.garrisonEntity || 'simpleenemymod:usunit', add, sectorTag)
  fdOps.garrisons[key] = {level: newLevel, strength: targetSize, maxStrength: targetSize, stateName: fdStateName(player)}
  fdOpsDirty = true
  fdOpsSave(server)
  fdScoreAdd(server, player, 'front_garrison', 1)
  fdScoreAdd(server, player, 'front_supplies', fdCostItemCount(fdCostFor('garrison', newLevel), 'kubejs:military_supply_crate'))
  fdTellPlayer(server, player, 'ТрО государства «' + fdStateName(player) + '» развёрнута: уровень ' + newLevel + ', бойцов ' + targetSize + '.', 'blue')
  return 1
}

function fdCommandoCommand(context) {
  var source = context.source
  var player = source.player
  if (player == null) return 0
  var server = source.server
  var ownerTag = 'fd_commando_' + String(player.username)
  if (fdCount(server, `@e[tag=${ownerTag}]`) > 0) {
    fdTellPlayer(server, player, 'Твой отряд коммандос уже находится в мире.', 'yellow')
    return 0
  }
  if (!fdPay(server, player, fdCostFor('commando', 1))) {
    fdTellPlayer(server, player, 'Недостаточно ресурсов для отряда коммандос.', 'red')
    return 0
  }
  var size = fdOptionNumber('commandoSize', 4)
  fdSpawnFriendlySquad(server, player, fdConfig.commandoEntity || 'simpleenemymod:pmcunit', size, ownerTag)
  fdScoreAdd(server, player, 'front_commandos', 1)
  fdScoreAdd(server, player, 'front_supplies', fdCostItemCount(fdCostFor('commando', 1), 'kubejs:military_supply_crate'))
  fdTellPlayer(server, player, 'Отряд коммандос из ' + size + ' бойцов прибыл.', 'green')
  return 1
}

function fdHqPayload(server, player) {
  var sx = fdSX(player.x)
  var sz = fdSZ(player.z)
  var control = fdControl(sx, sz)
  var key = fdKey(sx, sz)
  var terrain = fdSectorTerrain(fdWorld(server), sx, sz)
  var garrison = fdOps.garrisons[key]
  var zone = !fdInWarArea(player.x, player.z) ? 'Вне театра войны' :
    (fdInSafeZone(player.x, player.z) ? 'Безопасная зона' :
      (fdIsFrontier(sx, sz) ? 'Линия фронта' : (control > 0 ? 'Территория Warium' : 'Свободный сектор')))
  return {
    enemyName: fdEnemyName(server), language: String(player.persistentData.getString('front_language') || 'ru'),
    canEdit: player.hasPermissions(2),
    zoneCode: !fdInWarArea(player.x, player.z) ? 'outside' : (fdInSafeZone(player.x, player.z) ? 'safe' : (fdIsFrontier(sx, sz) ? 'front' : (control > 0 ? 'enemy' : 'free'))),
    stateName: fdStateName(player), sector: key, control: Math.round(control), zone: zone,
    terrain: terrain.name, supplied: control > 0 ? fdIsSupplied(sx, sz) : true,
    garrisonLevel: garrison ? Number(garrison.level) : 0,
    garrisonStrength: garrison ? Number(garrison.strength) : 0,
    garrisonMax: garrison ? Number(garrison.maxStrength) : 0
  }
}

function fdOpenHq(server, player) {
  if (!fdInitialized && !fdInitialize(server)) return 0
  player.sendData('front:hq_data', fdHqPayload(server, player))
  return 1
}

function fdXaeroWaypoint(server, player, name, symbol, x, y, z, color) {
  // Xaero's client recognises this shared-waypoint payload and adds its own
  // clickable [Add] control. TMP marks operational points that may become stale.
  var safeName = String(name).replace(/[:\r\n]/g, '_').replace(/ /g, '_')
  var payload = 'xaero-waypoint:' + safeName + ':' + symbol + ':' +
    Math.floor(x) + ':' + Math.floor(y) + ':' + Math.floor(z) + ':' +
    Math.floor(color) + ':false:0:Internal-overworld-waypoints'
  fdCmd(server, 'tellraw ' + String(player.username) + ' ' + JSON.stringify({text: payload}))
}

function fdFrontMapCommand(context) {
  var player = context.source.player
  if (player == null) return 0
  var server = context.source.server
  if (!fdInitialized && !fdInitialize(server)) return 0

  var candidates = []
  Object.keys(fdState).forEach(key => {
    var pair = key.split(',')
    var sx = Number(pair[0])
    var sz = Number(pair[1])
    if (!fdIsFrontier(sx, sz)) return
    var center = fdSectorCenter(sx, sz)
    var dx = center.x - player.x
    var dz = center.z - player.z
    candidates.push({
      sx: sx, sz: sz, x: center.x, z: center.z,
      distanceSq: dx * dx + dz * dz,
      supplied: fdIsSupplied(sx, sz)
    })
  })
  candidates.sort((a, b) => a.distanceSq - b.distanceSq)

  if (candidates.length === 0) {
    fdTellPlayer(server, player, 'Активная линия фронта пока не обнаружена.', 'gray')
    return 0
  }

  var amount = Math.min(5, candidates.length)
  fdTellPlayer(server, player, 'Ближайшие участки фронта: ' + amount + '. Нажми [Add] в сообщениях Xaero. Метки TMP временные.', 'gold')
  for (var i = 0; i < amount; i++) {
    var point = candidates[i]
    var distance = Math.round(Math.sqrt(point.distanceSq))
    var color = point.supplied ? 6 : 5 // gold / dark purple
    var label = point.supplied ? 'TMP_FRONT' : 'TMP_ENCIRCLED'
    fdXaeroWaypoint(server, player,
      label + '_' + point.sx + '_' + point.sz + '_' + distance + 'm',
      point.supplied ? 'F' : 'O', point.x, 90, point.z, color)
  }

  // Strategic reference points use stable colours: red enemy origin,
  // green nearest garrison, aqua nearest configured safe base.
  if (fdConfig.origins && fdConfig.origins.length > 0) {
    var origin = fdConfig.origins[0]
    fdXaeroWaypoint(server, player, 'TMP_' + fdEnemyName(server) + '_ORIGIN', 'W', origin.x, 90, origin.z, 4)
  }

  var nearestGarrison = null
  Object.keys(fdOps.garrisons).forEach(key => {
    var pair = key.split(',')
    var center = fdSectorCenter(Number(pair[0]), Number(pair[1]))
    var dx = center.x - player.x
    var dz = center.z - player.z
    var distanceSq = dx * dx + dz * dz
    if (nearestGarrison == null || distanceSq < nearestGarrison.distanceSq) {
      nearestGarrison = {x: center.x, z: center.z, distanceSq: distanceSq}
    }
  })
  if (nearestGarrison != null) {
    fdXaeroWaypoint(server, player, 'TMP_NEAREST_GARRISON', 'G', nearestGarrison.x, 90, nearestGarrison.z, 10)
  }

  var nearestBase = null
  for (var b = 0; b < fdConfig.safeZones.length; b++) {
    var rect = fdConfig.safeZones[b]
    var bx = Math.floor((Number(rect.x1) + Number(rect.x2)) / 2)
    var bz = Math.floor((Number(rect.z1) + Number(rect.z2)) / 2)
    var bdx = bx - player.x
    var bdz = bz - player.z
    var baseDistanceSq = bdx * bdx + bdz * bdz
    if (nearestBase == null || baseDistanceSq < nearestBase.distanceSq) {
      nearestBase = {x: bx, z: bz, distanceSq: baseDistanceSq}
    }
  }
  if (nearestBase != null) fdXaeroWaypoint(server, player, 'TMP_SAFE_BASE', 'B', nearestBase.x, 90, nearestBase.z, 11)
  return amount
}

NetworkEvents.dataReceived('front:hq_request', event => {
  var player = event.player
  var server = player.server
  if (!fdInitialized && !fdInitialize(server)) return
  var action = String(event.data.action || 'refresh')
  if (action === 'enemy_name' && player.hasPermissions(2)) {
    var enemyName = String(event.data.name || '').replace(/[\x00-\x1F\x7F§:]/g, '').trim()
    if (enemyName.length >= 3 && enemyName.length <= 32) server.persistentData.putString('front_enemy_name', enemyName)
  }
  if (action === 'language') {
    var selectedLanguage = String(event.data.language)
    if (selectedLanguage === 'ru' || selectedLanguage === 'uk' || selectedLanguage === 'en') player.persistentData.putString('front_language', selectedLanguage)
  }
  if (action === 'map') fdFrontMapCommand({source: {player: player, server: server}})
  if (action === 'garrison') fdCmd(server, 'execute as ' + String(player.username) + ' run front garrison')
  else if (action === 'upgrade') fdCmd(server, 'execute as ' + String(player.username) + ' run front garrison upgrade')
  else if (action === 'commando') fdCmd(server, 'execute as ' + String(player.username) + ' run front squad commando')
  else if (action === 'state_name') {
    if (fdSetStateName(player, event.data.name)) fdTellPlayer(server, player, 'Название государства изменено на «' + fdStateName(player) + '».', 'green')
    else fdTellPlayer(server, player, 'Название должно содержать от 3 до 32 символов.', 'red')
  }
  fdOpenHq(server, player)
})

function fdPurgeCommand(context) {
  var source = context.source
  var removed = fdCmd(source.server, 'kill @e[tag=fd_robot]')
  fdTrackedRobots = []
  if (source.player != null) fdTellPlayer(source.server, source.player, 'Удалено фронтовых роботов: ' + removed + '. Контроль территорий сохранён.', 'green')
  return 1
}

function fdHasWarServiceTag(entity) {
  try {
    var iterator = entity.getTags().iterator()
    while (iterator.hasNext()) {
      var tag = String(iterator.next())
      if (tag === 'fd_robot' || tag.indexOf('fd_garrison_') === 0 || tag.indexOf('fd_commando_') === 0) return true
    }
  } catch (ignored) {}
  return false
}

function fdResetWar(context) {
  var source = context.source
  var server = source.server
  if (!fdInitialized && !fdInitialize(server)) return 0
  var level = fdWorld(server)
  var removed = 0
  var iterator = level.getAllEntities().iterator()
  while (iterator.hasNext()) {
    var entity = iterator.next()
    if (!fdIsRobot(entity) && !fdHasWarServiceTag(entity)) continue
    try {
      entity.discard()
      removed++
    } catch (error) {
      try {
        entity.remove('discarded')
        removed++
      } catch (ignored) {}
    }
  }

  fdState = {}
  fdDirty = true
  for (var i = 0; i < fdConfig.origins.length; i++) {
    fdSetControl(fdSX(fdConfig.origins[i].x), fdSZ(fdConfig.origins[i].z), 100)
  }
  fdOps = { liberated: {}, protection: {}, garrisons: {}, alerts: {} }
  fdOpsDirty = true
  fdTrackedRobots = []
  fdTrackedSem = []
  fdCombatCursor = 0
  fdEntityScanTick = fdCombatTick
  fdSharedIntel = null
  fdTerrainCache = {}
  fdCityCache = {}
  fdExpansionClock = Number(fdConfig.expansionIntervalMinutes) * 60 * 20
  fdRebuildSupply()
  fdSave(server)
  fdOpsSave(server)

  fdTell(server, 'Война полностью сброшена. Убрано сущностей: ' + removed + '. Экспансия снова начинается от исходного очага.', 'yellow')
  return 1
}

function fdResetWarning(context) {
  if (context.source.player != null) {
    fdTellPlayer(context.source.server, context.source.player,
      'Полный сброс удалит роботов, ТрО и коммандос, а также очистит контроль секторов. Для подтверждения: /front reset confirm', 'red')
  }
  return 1
}

ServerEvents.commandRegistry(event => {
  var Commands = event.commands
  event.register(
    Commands.literal('front')
      .executes(context => fdStatusCommand(context))
      .then(Commands.literal('status').executes(context => fdStatusCommand(context)))
      .then(Commands.literal('hq').executes(context => {
        return context.source.player == null ? 0 : fdOpenHq(context.source.server, context.source.player)
      }))
      .then(Commands.literal('map').executes(context => fdFrontMapCommand(context)))
      .then(Commands.literal('garrison')
        .executes(context => fdGarrisonCommand(context, 'deploy'))
        .then(Commands.literal('upgrade').executes(context => fdGarrisonCommand(context, 'upgrade')))
        .then(Commands.literal('status').executes(context => fdGarrisonCommand(context, 'status'))))
      .then(Commands.literal('squad')
        .then(Commands.literal('commando').executes(context => fdCommandoCommand(context))))
      .then(Commands.literal('purge')
        .requires(source => source.hasPermission(2))
        .executes(context => fdPurgeCommand(context)))
      .then(Commands.literal('reset')
        .requires(source => source.hasPermission(2))
        .executes(context => fdResetWarning(context))
        .then(Commands.literal('confirm').executes(context => fdResetWar(context))))
  )
})

function fdUpdateLocalFront(server) {
  var level = fdWorld(server)
  var active = fdActiveSectors(server, level)

  Object.keys(active).forEach(key => {
    var activeSector = active[key]
    var control = fdControl(activeSector.sx, activeSector.sz)
    var frontSector = fdIsFrontier(activeSector.sx, activeSector.sz)
    if (!frontSector && control < Number(fdConfig.spawnControlMinimum)) return

    var robots = fdCount(server, fdRobotSelector(activeSector.sx, activeSector.sz))
    var defenders = fdDefenderCount(server, activeSector.sx, activeSector.sz)

    if (defenders > 0 && robots === 0 && control > 0) {
      var recovery = Number(fdConfig.defenderRecoveryPerCheck) * Math.min(defenders, Number(fdConfig.resistanceCap))
      fdSetControl(activeSector.sx, activeSector.sz, control - recovery)
    } else if (defenders === 0 && control > 0 && fdNeighborHasControl(activeSector.sx, activeSector.sz, Number(fdConfig.expansionSourceControl))) {
      fdSetControl(activeSector.sx, activeSector.sz, control + Number(fdConfig.unopposedGainPerCheck))
    }

    var updated = fdControl(activeSector.sx, activeSector.sz)
    if (updated < Number(fdConfig.spawnControlMinimum)) return

    var strength = fdStrength(activeSector.sx, activeSector.sz)
    var citySector = fdIsCitySector(level, activeSector.sx, activeSector.sz)
    var cityMultiplier = citySector ? fdOptionNumber('cityRobotMultiplier', 1.8) : 1.0
    var resistanceBonus = Math.min(Number(fdConfig.resistanceCap), defenders) * Number(fdConfig.extraRobotsPerDefender)
    var frontBaseCap = fdOptionNumber('frontRobotCapPerSector', fdConfig.baseRobotCapPerSector)
    var rearBaseCap = fdOptionNumber('rearGarrisonCapPerSector', 8)
    var selectedBaseCap = frontSector ? frontBaseCap : rearBaseCap
    var cap = Math.min(Number(fdConfig.absoluteRobotCapPerSector),
      Math.round(selectedBaseCap * strength * cityMultiplier + (frontSector ? resistanceBonus : 0)))

    if (robots >= cap) return
    var selectedBatch = frontSector ? fdOptionNumber('frontSpawnBatch', fdConfig.spawnBatch) : fdOptionNumber('rearSpawnBatch', 2)
    var wave = Math.min(selectedBatch, cap - robots)
    var squadAnchor = null
    var rarePresent = fdCount(server, `@e[tag=fd_rare_support,${fdSectorBox(activeSector.sx, activeSector.sz)}]`) > 0
    for (var i = 0; i < wave; i++) {
      var forcedType = fdInfantryType()
      var rareSupport = false
      if (i === 0 && wave >= fdOptionNumber('squadLeaderMinimumSize', 5) &&
          Math.random() < fdOptionNumber('squadLeaderChance', 0.35)) {
        var leaders = fdConfig.squadLeaderEntities || ['crusty_chunks:commander', 'crusty_chunks:scout']
        forcedType = String(leaders[Math.floor(Math.random() * leaders.length)])
      } else if (!rarePresent && Math.random() < fdOptionNumber('rareSupportChancePerUnit', 0.02)) {
        forcedType = fdRandomFrom(fdConfig.rareSupportEntities, 'crusty_chunks:hunter')
        rareSupport = true
        rarePresent = true
      } else if (Math.random() < fdOptionNumber('mortarChancePerUnit', 0.025)) {
        forcedType = 'crusty_chunks:mortarer'
      } else if (Math.random() < fdOptionNumber('supportChancePerUnit', 0.18)) {
        forcedType = fdSupportType()
      }
      var spawnedAt = fdSpawnRobot(server, level, activeSector.sx, activeSector.sz, squadAnchor, forcedType)
      if (rareSupport && spawnedAt) {
        fdCmd(server, `tag @e[type=${forcedType},tag=fd_robot,sort=nearest,limit=1,x=${spawnedAt.x},z=${spawnedAt.z},distance=..24] add fd_rare_support`)
      }
      if (!squadAnchor && spawnedAt) squadAnchor = spawnedAt
    }
  })
  fdSave(server)
}

function fdInitialize(server) {
  if (fdInitialized) return true
  try {
    fdLoadConfig()
    if (!fdConfig.enabled) return false
    fdCmd(server, 'scoreboard objectives add fd_tmp dummy')
    fdCmd(server, 'scoreboard objectives add front_sectors dummy')
    fdCmd(server, 'scoreboard objectives add front_garrison dummy')
    fdCmd(server, 'scoreboard objectives add front_commandos dummy')
    fdCmd(server, 'scoreboard objectives add front_supplies dummy')
    fdLoadState(server)
    fdOpsLoad(server)
    fdRebuildSupply()
    fdExpansionClock = Number(fdConfig.expansionIntervalMinutes) * 60 * 20
    fdInitialized = true
    fdTell(server, `Секторный фронт загружен. Размер сектора: ${fdConfig.sectorSize} блоков.`, 'yellow')
    console.info('[Front Director v3.2] initialized successfully')
    return true
  } catch (error) {
    console.error('[Front Director v3.2] initialization failed: ' + error)
    fdConfig = null
    fdInitialized = false
    return false
  }
}

ServerEvents.loaded(event => {
  fdInitialize(event.server)
})

ServerEvents.tick(event => {
  // Also initializes after /reload, because ServerEvents.loaded is not fired by /reload.
  if (!fdInitialized && !fdInitialize(event.server)) return
  if (!fdConfig || !fdConfig.enabled) return
  fdTick++
  fdCombatTick++
  if (fdCombatTick % FD_AI_INTERVAL === 0) fdCombatNetwork(event.server)
  if (fdTick % FD_CHECK_TICKS !== 0) return

  var server = event.server
  fdExpansionClock -= FD_CHECK_TICKS
  if (fdExpansionClock <= 0) {
    fdStrategicExpansion(server)
    fdExpansionClock = Number(fdConfig.expansionIntervalMinutes) * 60 * 20
  }
  fdUpdateLocalFront(server)
})

EntityEvents.death(event => {
  if (!fdConfig || !fdConfig.enabled || !fdIsRobot(event.entity)) return
  var entity = event.entity
  var sx = fdSX(entity.x)
  var sz = fdSZ(entity.z)
  if (!fdAllowedSector(sx, sz)) return

  var player = event.source && event.source.player ? event.source.player : null
  var loss = Number(fdConfig.controlLossPerRobotKill)
  if (player != null) loss *= Number(fdConfig.playerKillMultiplier)
  var oldControl = fdControl(sx, sz)
  fdSetControl(sx, sz, oldControl - loss)

  // Player liberation is intentionally asymmetric: Warium capturing a sector
  // never deletes players, allied soldiers or civilians.
  if (player != null && oldControl > 0 && fdControl(sx, sz) === 0) {
    fdLiberateSector(event.server, sx, sz, player)
    fdSave(event.server)
    fdOpsSave(event.server)
  }
})

// Warium has its own spawning mechanisms which do not know about the front map.
// Only units marked by fdSpawnRobot are allowed to join through this director.
EntityEvents.spawned(event => {
  if (!fdConfig || !fdConfig.enabled) return
  var entity = event.entity
  var id = fdEntityId(entity)
  if (id.indexOf('simpleenemymod:') === 0) {
    fdTrackedSem.push(entity)
    return
  }
  if (!fdIsRobot(entity)) return
  if (!entity.getTags().contains('fd_robot')) {
    event.cancel()
    return
  }
  fdTrackedRobots.push(entity)
})
