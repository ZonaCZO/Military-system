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

  local file = fs.open(path, 'r')
  if not file then return defaultValue, 'cannot read: ' .. path end
  local content = file.readAll(); file.close()
  -- Legacy files contain "return <serialized table>". Parse data, never execute it.
  content = content:gsub('^%s*return%s+', '')
  local ok, result = pcall(textutils.unserialize, content)
  if not ok or result == nil then return defaultValue, 'invalid data: ' .. path end

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

  local temporary = path .. '.msos-new'
  local file = fs.open(temporary, "w")
  if not file then
    return false, "cannot open file for write: " .. path
  end

  file.write("return " .. textutils.serialize(value))
  file.close()
  local backup = path .. '.msos-backup'
  if fs.exists(path) then
    if fs.exists(backup) then fs.delete(backup) end
    fs.move(path, backup)
  end
  fs.move(temporary, path)
  return true
end

function storage.listLua(dir)
  if not fs.exists(dir) then return {} end

  local out = {}
  for _, name in ipairs(fs.list(dir)) do
    if name:sub(-4) == ".lua" and not fs.isDir(fs.combine(dir,name)) then
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
