local storage = require("server.modules.storage")

local archive = {}

local ROOT = "data/archive"
local PLANS = ROOT .. "/plans"
local LOGS = ROOT .. "/logs"

local function planPath(id)
  return PLANS .. "/" .. tostring(id) .. ".lua"
end

local function logPath(channel)
  return LOGS .. "/" .. tostring(channel) .. ".lua"
end

local function normalizePlan(plan)
  plan = plan or {}
  plan.id = tostring(plan.id or "")
  plan.title = plan.title or plan.id
  plan.author = plan.author or "unknown"
  plan.created_at = plan.created_at or os.epoch("utc")
  plan.updated_at = plan.updated_at or plan.created_at
  plan.status = plan.status or "active"
  plan.front_id = plan.front_id or nil
  plan.access = plan.access or {
    read = { "commander", "general" },
    write = { "general" }
  }
  plan.stages = plan.stages or {}
  plan.notes = plan.notes or {}
  return plan
end

function archive.listPlans()
  local ids = storage.listLua(PLANS)
  local out = {}
  for _, id in ipairs(ids) do
    local plan = storage.load(planPath(id), nil)
    if plan then
      out[#out + 1] = {
        id = plan.id,
        title = plan.title,
        status = plan.status,
        front_id = plan.front_id,
        created_at = plan.created_at,
        updated_at = plan.updated_at
      }
    end
  end
  table.sort(out, function(a, b) return a.title < b.title end)
  return out
end

function archive.getPlan(id)
  local plan = storage.load(planPath(id), nil)
  if not plan then return nil end
  return normalizePlan(plan)
end

function archive.savePlan(plan)
  plan = normalizePlan(plan)
  assert(plan.id ~= "", "plan.id is required")
  plan.updated_at = os.epoch("utc")
  return storage.save(planPath(plan.id), plan)
end

function archive.createPlan(data)
  data = data or {}
  data.id = data.id or ("plan_" .. tostring(os.epoch("utc")))
  return archive.savePlan(data)
end

function archive.setStageDone(planId, stageId, done, changedBy)
  local plan = archive.getPlan(planId)
  if not plan then
    return false, "plan not found"
  end

  stageId = tonumber(stageId)
  if not stageId then
    return false, "invalid stage id"
  end

  for _, stage in ipairs(plan.stages) do
    if tonumber(stage.id) == stageId then
      stage.done = not not done
      stage.updated_by = changedBy or stage.updated_by
      stage.updated_at = os.epoch("utc")
      archive.savePlan(plan)
      return true, plan
    end
  end

  return false, "stage not found"
end

function archive.getLog(channel)
  local data = storage.load(logPath(channel), nil)
  if not data then
    return {
      channel = tostring(channel),
      messages = {}
    }
  end
  data.channel = data.channel or tostring(channel)
  data.messages = data.messages or {}
  return data
end

function archive.appendLog(channel, entry)
  local log = archive.getLog(channel)
  entry = entry or {}
  entry.time = entry.time or os.epoch("utc")
  entry.from = entry.from or "unknown"
  entry.text = entry.text or ""

  log.messages[#log.messages + 1] = entry
  while #log.messages > 200 do
    table.remove(log.messages, 1)
  end

  return storage.save(logPath(channel), log)
end

return archive