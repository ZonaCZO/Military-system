-- ==========================================
-- === CYRILLIC KEYBOARD DRIVER V2.0 ===
-- ==========================================
-- Модульный cyrillic драйвер для RU/UA/BY
-- Использование: local cyrdrv = require("system.cyrillic_driver")
--                cyrdrv.start("RU")  -- или "UA", "BY"

local cyrdrv = {}

-- Локальные константы для читаемости кода
local KEYCODE_SHIFT = 340
local KEYCODE_LSHIFT = 340

-- Klaviatura mappings
local LOCALE_MAPS = {
  RU = {
    normal = {
      [ 93 ] = string.char(0xFA), [ 90 ] = string.char(0xFF), [ 75 ] = string.char(0xEB), [ 65 ] = string.char(0xF4),
      [ 66 ] = string.char(0xE8), [ 67 ] = string.char(0xF1), [ 68 ] = string.char(0xE2), [ 69 ] = string.char(0xF3),
      [ 39 ] = string.char(0xFD), [ 71 ] = string.char(0xEF), [ 72 ] = string.char(0xF0), [ 73 ] = string.char(0xF8),
      [ 74 ] = string.char(0xEE), [ 44 ] = string.char(0xE1), [ 76 ] = string.char(0xE4), [ 77 ] = string.char(0xFC),
      [ 78 ] = string.char(0xF2), [ 79 ] = string.char(0xF9), [ 80 ] = string.char(0xE7), [ 81 ] = string.char(0xE9),
      [ 82 ] = string.char(0xEA), [ 83 ] = string.char(0xFB), [ 84 ] = string.char(0xE5), [ 85 ] = string.char(0xE3),
      [ 86 ] = string.char(0xEC), [ 87 ] = string.char(0xF6), [ 88 ] = string.char(0xF7), [ 89 ] = string.char(0xED),
      [ 59 ] = string.char(0xE6), [ 91 ] = string.char(0xF5), [ 70 ] = string.char(0xE0), [ 46 ] = string.char(0xFE)
    },
    shifted = {
      [ 93 ] = string.char(0xDA), [ 90 ] = string.char(0xDF), [ 75 ] = string.char(0xCB), [ 65 ] = string.char(0xD4),
      [ 66 ] = string.char(0xC8), [ 67 ] = string.char(0xD1), [ 68 ] = string.char(0xC2), [ 69 ] = string.char(0xD3),
      [ 39 ] = string.char(0xDD), [ 71 ] = string.char(0xCF), [ 72 ] = string.char(0xD0), [ 73 ] = string.char(0xD8),
      [ 74 ] = string.char(0xCE), [ 44 ] = string.char(0xC1), [ 76 ] = string.char(0xC4), [ 77 ] = string.char(0xDC),
      [ 78 ] = string.char(0xD2), [ 79 ] = string.char(0xD9), [ 80 ] = string.char(0xC7), [ 81 ] = string.char(0xC9),
      [ 82 ] = string.char(0xCA), [ 83 ] = string.char(0xDB), [ 84 ] = string.char(0xC5), [ 85 ] = string.char(0xC3),
      [ 86 ] = string.char(0xCC), [ 87 ] = string.char(0xD6), [ 88 ] = string.char(0xD7), [ 89 ] = string.char(0xCD),
      [ 59 ] = string.char(0xC6), [ 91 ] = string.char(0xD5), [ 70 ] = string.char(0xC0), [ 46 ] = string.char(0xDE)
    }
  },
  UA = {
    normal = {
      [ 93 ] = string.char(0xBF), [ 90 ] = string.char(0xFF), [ 75 ] = string.char(0xEB), [ 65 ] = string.char(0xF4),
      [ 66 ] = string.char(0xE8), [ 67 ] = string.char(0xF1), [ 68 ] = string.char(0xE2), [ 69 ] = string.char(0xF3),
      [ 39 ] = string.char(0xBA), [ 71 ] = string.char(0xEF), [ 72 ] = string.char(0xF0), [ 73 ] = string.char(0xF8),
      [ 74 ] = string.char(0xEE), [ 44 ] = string.char(0xE1), [ 76 ] = string.char(0xE4), [ 77 ] = string.char(0xFC),
      [ 78 ] = string.char(0xF2), [ 79 ] = string.char(0xF9), [ 80 ] = string.char(0xE7), [ 81 ] = string.char(0xE9),
      [ 82 ] = string.char(0xEA), [ 83 ] = string.char(0xFB), [ 84 ] = string.char(0xE5), [ 85 ] = string.char(0xE3),
      [ 86 ] = string.char(0xEC), [ 87 ] = string.char(0xF6), [ 88 ] = string.char(0xF7), [ 89 ] = string.char(0xED),
      [ 59 ] = string.char(0xE6), [ 91 ] = string.char(0xF5), [ 70 ] = string.char(0xE0), [ 46 ] = string.char(0xFE),
      [ 31 ] = string.char(0xB3), [ 43 ] = string.char(0xB4)
    },
    shifted = {
      [ 93 ] = string.char(0xAF), [ 90 ] = string.char(0xDF), [ 75 ] = string.char(0xCB), [ 65 ] = string.char(0xD4),
      [ 66 ] = string.char(0xC8), [ 67 ] = string.char(0xD1), [ 68 ] = string.char(0xC2), [ 69 ] = string.char(0xD3),
      [ 39 ] = string.char(0xAA), [ 71 ] = string.char(0xCF), [ 72 ] = string.char(0xD0), [ 73 ] = string.char(0xD8),
      [ 74 ] = string.char(0xCE), [ 44 ] = string.char(0xC1), [ 76 ] = string.char(0xC4), [ 77 ] = string.char(0xDC),
      [ 78 ] = string.char(0xD2), [ 79 ] = string.char(0xD9), [ 80 ] = string.char(0xC7), [ 81 ] = string.char(0xC9),
      [ 82 ] = string.char(0xCA), [ 83 ] = string.char(0xDB), [ 84 ] = string.char(0xC5), [ 85 ] = string.char(0xC3),
      [ 86 ] = string.char(0xCC), [ 87 ] = string.char(0xD6), [ 88 ] = string.char(0xD7), [ 89 ] = string.char(0xCD),
      [ 59 ] = string.char(0xC6), [ 91 ] = string.char(0xD5), [ 70 ] = string.char(0xC0), [ 46 ] = string.char(0xDE),
      [ 31 ] = string.char(0xB2), [ 43 ] = string.char(0xA5)
    }
  },
  BY = {
    normal = {
      [ 93 ] = "'", [ 90 ] = string.char(0xFF), [ 75 ] = string.char(0xEB), [ 65 ] = string.char(0xF4),
      [ 66 ] = string.char(0xE8), [ 67 ] = string.char(0xF1), [ 68 ] = string.char(0xE2), [ 69 ] = string.char(0xF3),
      [ 39 ] = string.char(0xFD), [ 71 ] = string.char(0xEF), [ 72 ] = string.char(0xF0), [ 73 ] = string.char(0xF8),
      [ 74 ] = string.char(0xEE), [ 44 ] = string.char(0xE1), [ 76 ] = string.char(0xE4), [ 77 ] = string.char(0xFC),
      [ 78 ] = string.char(0xF2), [ 79 ] = string.char(0xF9), [ 80 ] = string.char(0xE7), [ 81 ] = string.char(0xE9),
      [ 82 ] = string.char(0xEA), [ 83 ] = string.char(0xFB), [ 84 ] = string.char(0xE5), [ 85 ] = string.char(0xE3),
      [ 86 ] = string.char(0xEC), [ 87 ] = string.char(0xF6), [ 88 ] = string.char(0xF7), [ 89 ] = string.char(0xED),
      [ 59 ] = string.char(0xE6), [ 91 ] = string.char(0xF5), [ 70 ] = string.char(0xE0), [ 46 ] = string.char(0xFE),
      [ 31 ] = string.char(0xB3), [ 24 ] = string.char(0xA2)
    },
    shifted = {
      [ 93 ] = "'", [ 90 ] = string.char(0xDF), [ 75 ] = string.char(0xCB), [ 65 ] = string.char(0xD4),
      [ 66 ] = string.char(0xC8), [ 67 ] = string.char(0xD1), [ 68 ] = string.char(0xC2), [ 69 ] = string.char(0xD3),
      [ 39 ] = string.char(0xDD), [ 71 ] = string.char(0xCF), [ 72 ] = string.char(0xD0), [ 73 ] = string.char(0xD8),
      [ 74 ] = string.char(0xCE), [ 44 ] = string.char(0xC1), [ 76 ] = string.char(0xC4), [ 77 ] = string.char(0xDC),
      [ 78 ] = string.char(0xD2), [ 79 ] = string.char(0xD9), [ 80 ] = string.char(0xC7), [ 81 ] = string.char(0xC9),
      [ 82 ] = string.char(0xCA), [ 83 ] = string.char(0xDB), [ 84 ] = string.char(0xC5), [ 85 ] = string.char(0xC3),
      [ 86 ] = string.char(0xCC), [ 87 ] = string.char(0xD6), [ 88 ] = string.char(0xD7), [ 89 ] = string.char(0xCD),
      [ 59 ] = string.char(0xC6), [ 91 ] = string.char(0xD5), [ 70 ] = string.char(0xC0), [ 46 ] = string.char(0xDE),
      [ 31 ] = string.char(0xB2), [ 24 ] = string.char(0xA1)
    }
  }
}

local function handle_keypress()
  local evt, key
  repeat
    repeat evt, key = os.pullEvent() until evt == "key" or evt == "key_up"
    if evt == "key_up" then return -key end
    os.queueEvent("placeholder")
    local char_queued = false
    parallel.waitForAny(
      function()
        os.pullEvent("char")
        char_queued = true
      end,
      function()
        os.pullEvent("placeholder")
      end
    )
  until not char_queued
  return key
end

local function cyrrun(locale)
  local locale_map = LOCALE_MAPS[locale].normal
  local locale_map_shifted = LOCALE_MAPS[locale].shifted
  local shift_pressed = false
  
  while true do
    local key_pressed = handle_keypress()
    if key_pressed == KEYCODE_SHIFT then shift_pressed = true end
    if key_pressed == -KEYCODE_SHIFT then shift_pressed = false end
    
    if locale_map[key_pressed] then
      if shift_pressed then
        os.queueEvent('char', locale_map_shifted[key_pressed])
      else
        os.queueEvent('char', locale_map[key_pressed])
      end
    end
  end
end

-- Background execution powered by RedRun
local redrun = {}
local coroutines = {}

function redrun.init()
  local env = getfenv(rednet.run)
  if env.__redrun_coroutines then
    coroutines = env.__redrun_coroutines
  else
    env.os = setmetatable({
      pullEventRaw = function()
        local ev = table.pack(coroutine.yield())
        local delete = {}
        for k, v in pairs(coroutines) do
          if v.terminate or v.filter == nil or v.filter == ev[1] or ev[1] == "terminate" then
            local ok
            if v.terminate then
              ok, v.filter = coroutine.resume(v.coro, "terminate")
            else
              ok, v.filter = coroutine.resume(v.coro, table.unpack(ev, 1, ev.n))
            end
            if not ok or coroutine.status(v.coro) ~= "suspended" or v.terminate then
              delete[#delete + 1] = k
            end
          end
        end
        for _, v in ipairs(delete) do coroutines[v] = nil end
        return table.unpack(ev, 1, ev.n)
      end
    }, { __index = os, __isredrun = true })
    env.__redrun_coroutines = coroutines
  end
end

function redrun.start(func, name)
  local id = #coroutines + 1
  coroutines[id] = { coro = coroutine.create(func), name = name }
  return id
end

-- Инициализация cyrillic драйвера
function cyrdrv.start(locale)
  locale = (locale or "RU"):upper()
  if not LOCALE_MAPS[locale] then
    locale = "RU"
  end
  
  redrun.init()
  redrun.start(function() cyrrun(locale) end, "cyrillic_driver")
end

return cyrdrv
