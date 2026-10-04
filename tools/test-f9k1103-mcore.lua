-- Unit smoke for firmware/f9k1103-lede-17.01.5/cudy-port/mcore.lua
local adapter = assert(arg[1], "mcore adapter path required")

local real_open = io.open
local fixtures = {
  ["/proc/uptime"] = "1000.00 500.00\n",
  ["/tmp/dhcp.leases"] =
    "9999 aa:bb:cc:dd:ee:01 192.168.1.20 DHCPPhone *\n" ..
    "9999 11:22:33:44:55:66 192.168.1.30 WiredHost *\n",
  ["/proc/net/arp"] =
    "IP address       HW type     Flags       HW address            Mask     Device\n" ..
    "192.168.1.20     0x1         0x2         aa:bb:cc:dd:ee:01     *        br-lan\n" ..
    "192.168.1.30     0x1         0x2         11:22:33:44:55:66     *        br-lan\n"
}

local function string_file(s)
  local pos = 1
  local obj = {}
  function obj:read(mode)
    if mode == "*l" then
      if pos > #s then return nil end
      local n = s:find("\n", pos, true)
      local line
      if n then line, pos = s:sub(pos, n - 1), n + 1
      else line, pos = s:sub(pos), #s + 1 end
      return line
    elseif mode == "*a" then
      local r=s:sub(pos); pos=#s+1; return r
    end
  end
  function obj:lines()
    return function()
      return obj:read("*l")
    end
  end
  function obj:close() end
  return obj
end

io.open = function(path, mode)
  if (not mode or mode:sub(1,1) == "r") and fixtures[path] then
    return string_file(fixtures[path])
  end
  return real_open(path, mode)
end

package.preload["luci.model.uci"] = function()
  local M = {}
  function M.cursor()
    local c = {}
    function c:foreach(config, stype, cb)
      assert(config == "luci" and stype == "devname")
      cb({
        macaddr="aa-bb-cc-dd-ee-01",
        hostname="ManualPhone",
        devtype="phone",
        brand="FixtureBrand"
      })
    end
    return c
  end
  return M
end

package.preload["luci.util"] = function()
  local M = {}
  function M.shellquote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
  end
  function M.exec(cmd)
    if cmd == "iwinfo 2>/dev/null" then
      return 'wlan0     ESSID: "Five"\nwlan1     ESSID: "Two"\n'
    elseif cmd:match("^iwinfo 'wlan0' info") then
      return "Channel: 36 (5.180 GHz)\n"
    elseif cmd:match("^iwinfo 'wlan1' info") then
      return "Channel: 6 (2.437 GHz)\n"
    elseif cmd:match("^iwinfo 'wlan0' assoclist") then
      return ""
    elseif cmd:match("^iwinfo 'wlan1' assoclist") then
      return "AA:BB:CC:DD:EE:01  -42 dBm / -95 dBm (SNR 53)  100 ms ago\n"
    end
    error("unexpected exec: " .. cmd)
  end
  return M
end

package.preload["nixio.fs"] = function() return {} end

os.remove("/tmp/f9k1103-mcore-seen-AABBCCDDEE01")
os.remove("/tmp/f9k1103-mcore-seen-112233445566")

assert(loadfile(adapter))()
local m = assert(package.loaded["mcore"])

local list = assert(m.devlist())
assert(#list == 2, "expected 2 clients, got " .. tostring(#list))

local bymac = {}
for _, d in ipairs(list) do bymac[d.macaddr] = d end

local wifi = assert(bymac["AA:BB:CC:DD:EE:01"], "wifi client missing")
assert(wifi.ipaddr == "192.168.1.20")
assert(wifi.hostname == "ManualPhone", "luci.devname must override DHCP hostname")
assert(wifi.devtype == "phone")
assert(wifi.brand == "FixtureBrand")
assert(wifi.interface == "wlan1")
assert(wifi.iface == "wlan00", "2.4 GHz must map to Cudy wlan00")
assert(wifi.inactive == 0)
assert(wifi.upspeed == 0 and wifi.downspeed == 0)
assert(wifi.inbytes == 0 and wifi.outbytes == 0)
assert(type(wifi.online) == "string")

local wired = assert(bymac["11:22:33:44:55:66"], "wired client missing")
assert(wired.hostname == "WiredHost")
assert(wired.interface == "br-lan")
assert(wired.iface == "eth")
assert(wired.inactive == 0)

assert(type(m.devlist6()) == "table" and #m.devlist6() == 0)
assert(type(m.get_backhaul()) == "table")

print("F9K1103 mcore compatibility unit smoke: PASS")
