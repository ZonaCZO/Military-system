local storage = {}

local function ensureDir(path)
  if path == "" or fs.exists(path) then return end
  local parent = fs.getDir(path)
  if parent and parent ~= "" and not fs.exists(parent) then
    ensureDir(parent)
  end
  fs.makeDir(path)
end

function storage.load(path, defaultValue)
  if not fs.exists(path) then
    return defaultValue
  end

  local fn, err = loadfile(path)
  if not fn then
    return defaultValue, err
  end

  local ok, result = pcall(fn)
  if not ok then
    return defaultValue, result
  end

  if result == nil then
    return defaultValue
  end

  return result
end

function storage.save(path, value)
  local dir = fs.getDir(path)
  if dir and dir ~= "" then
    ensureDir(dir)
  end

  local file = fs.open(path, "w")
  if not file then
    return false, "cannot open file for write: " .. path
  end

  file.write("return " .. textutils.serialize(value))
  file.close()
  return true
end

function storage.listLua(dir)
  if not fs.exists(dir) then return {} end

  local out = {}
  for _, name in ipairs(fs.list(dir)) do
    if name:sub(-4) == ".lua" then
      out[#out + 1] = name:sub(1, -5)
    end
  end
  table.sort(out)
  return out
end

function storage.ensureDir(path)
  ensureDir(path)
end

return storage