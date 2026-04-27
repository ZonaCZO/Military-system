local PROTOCOL = "military_net"

local modem = peripheral.find("modem")
if not modem then error("No modem attached") end
rednet.open(peripheral.getName(modem))

local function ask(msg, timeout)
  rednet.broadcast(msg, PROTOCOL)
  local timer = os.startTimer(timeout or 3)
  while true do
    local event, p1, p2, p3 = os.pullEvent()
    if event == "rednet_message" and p3 == PROTOCOL then
      return p1, p2
    elseif event == "timer" and p1 == timer then
      return nil, "timeout"
    end
  end
end

local function linesClear()
  term.setBackgroundColor(colors.black)
  term.clear()
  term.setCursorPos(1, 1)
end

local function drawList(title, items, selected, offset)
  local w, h = term.getSize()
  linesClear()
  term.setTextColor(colors.cyan)
  print(title)
  term.setTextColor(colors.white)

  local y = 3
  for i = offset, math.min(#items, offset + h - 5) do
    local item = items[i]
    term.setCursorPos(1, y)
    if i == selected then
      term.setTextColor(colors.yellow)
      write("> " .. item.name .. " [" .. tostring(item.id) .. "]")
    else
      term.setTextColor(colors.white)
      write("  " .. item.name .. " [" .. tostring(item.id) .. "]")
    end
    y = y + 1
  end
end

local function showFront(front)
  linesClear()
  term.setTextColor(colors.cyan)
  print(front.name)
  term.setTextColor(colors.white)
  print("ID: " .. front.id)
  print("Type: " .. tostring(front.type))
  print("Desc: " .. tostring(front.description or ""))
  print("Plans: " .. tostring(#(front.plans or {})))
  print("")
  print("Press any key...")
  os.pullEvent("key")
end

while true do
  local _, resp = ask({ type = "FRONT_LIST" }, 3)
  if not resp or not resp.ok then
    linesClear()
    print("No response from core.")
    sleep(2)
  else
    local fronts = resp.fronts or {}
    local selected = 1
    local offset = 1

    while true do
      drawList("[FRONTS] Enter=open, R=reload, Q=quit", fronts, selected, offset)
      local e, key = os.pullEvent("key")

      if key == keys.q then
        return
      elseif key == keys.r then
        break
      elseif key == keys.up then
        selected = math.max(1, selected - 1)
        if selected < offset then offset = selected end
      elseif key == keys.down then
        selected = math.min(#fronts, selected + 1)
        local _, h = term.getSize()
        if selected > offset + (h - 5) then
          offset = selected - (h - 5)
        end
      elseif key == keys.enter and fronts[selected] then
        local _, data = ask({ type = "FRONT_GET", id = fronts[selected].id }, 3)
        if data and data.ok and data.front then
          showFront(data.front)
          local _, plansResp = ask({ type = "ARCHIVE_LIST" }, 3)
          if plansResp and plansResp.ok then
            linesClear()
            print("Front: " .. data.front.name)
            print("Plans linked in archive:")
            for _, p in ipairs(plansResp.plans or {}) do
              if p.front_id == data.front.id then
                print(" - " .. p.id .. " | " .. p.title .. " | " .. p.status)
              end
            end
            print("")
            print("Press any key...")
            os.pullEvent("key")
          end
        end
      end
    end
  end
end