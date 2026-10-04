-- F9K1103 Cudy compatibility layer
-- Replaces Cudy's Linux-4.4 mcore.ko + /proc/net/mcore API with
-- target-native LEDE sources.  This module intentionally does not invent
-- per-client traffic semantics that Firmware-Unlock RE could not prove.

module("mcore", package.seeall)

local uci  = require("luci.model.uci").cursor()
local util = require "luci.util"
local fs   = require "nixio.fs"

local function norm_mac(mac)
    if not mac then return nil end
    mac = mac:gsub("-", ":"):upper()
    if mac:match("^[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]:[0-9A-F][0-9A-F]$") then
        return mac
    end
    return nil
end

local function uptime_now()
    local f = io.open("/proc/uptime", "r")
    if not f then return 0 end
    local s = f:read("*l") or "0"
    f:close()
    return tonumber(s:match("^([%d%.]+)")) or 0
end

local function session_seconds(mac, active, now)
    if not active or not mac then return "0" end
    local key = mac:gsub(":", "")
    local path = "/tmp/f9k1103-mcore-seen-" .. key
    local first, last
    local f = io.open(path, "r")
    if f then
        local s = f:read("*l") or ""
        f:close()
        first, last = s:match("^([%d%.]+)%s+([%d%.]+)$")
        first, last = tonumber(first), tonumber(last)
    end
    if not first or not last or now < last or (now - last) > 30 then
        first = now
    end
    f = io.open(path, "w")
    if f then
        f:write(string.format("%.3f %.3f\n", first, now))
        f:close()
    end
    return tostring(math.max(0, math.floor(now - first)))
end

local function devname_overrides()
    local out = {}
    uci:foreach("luci", "devname", function(s)
        local mac = norm_mac(s.macaddr)
        if mac then
            out[mac] = {
                hostname = s.hostname,
                devtype  = s.devtype,
                brand    = s.brand
            }
        end
    end)
    return out
end

local function dhcp_leases()
    local out = {}
    local f = io.open("/tmp/dhcp.leases", "r")
    if not f then return out end
    for line in f:lines() do
        local exp, mac0, ip, host = line:match("^(%d+)%s+(%S+)%s+(%S+)%s+(%S+)")
        local mac = norm_mac(mac0)
        if mac then
            out[mac] = {
                ipaddr = ip or "",
                hostname = (host and host ~= "*") and host or "",
                expiry = tonumber(exp) or 0
            }
        end
    end
    f:close()
    return out
end

local function wireless_interfaces()
    local list, seen = {}, {}
    local text = util.exec("iwinfo 2>/dev/null") or ""
    for line in text:gmatch("[^\n]+") do
        local ifn = line:match("^([%w%._%-]+)%s+ESSID:")
        if ifn and not seen[ifn] then
            seen[ifn] = true
            local info = util.exec("iwinfo " .. util.shellquote(ifn) .. " info 2>/dev/null") or ""
            local freq = tonumber(info:match("(%d+%.%d+)%s+GHz"))
            local cudy_iface
            if freq then
                cudy_iface = (freq < 4) and "wlan00" or "wlan10"
            else
                cudy_iface = (#list == 0) and "wlan00" or "wlan10"
            end
            list[#list + 1] = { ifname = ifn, iface = cudy_iface }
        end
    end
    return list
end

local function wifi_stations()
    local out = {}
    for _, w in ipairs(wireless_interfaces()) do
        local text = util.exec("iwinfo " .. util.shellquote(w.ifname) .. " assoclist 2>/dev/null") or ""
        for line in text:gmatch("[^\n]+") do
            local mac0, sig = line:match("^([0-9A-Fa-f:]+)%s+([%-0-9]+)%s+dBm")
            local mac = norm_mac(mac0)
            if mac then
                out[mac] = {
                    interface = w.ifname,
                    iface = w.iface,
                    signal = tonumber(sig)
                }
            end
        end
    end
    return out
end

local function arp_entries()
    local out = {}
    local f = io.open("/proc/net/arp", "r")
    if not f then return out end
    f:read("*l")
    for line in f:lines() do
        local ip, _, flags, mac0, _, dev =
            line:match("^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")
        local mac = norm_mac(mac0)
        if mac and mac ~= "00:00:00:00:00:00" then
            local fl = tonumber(flags) or tonumber((flags or ""):gsub("^0x", ""), 16) or 0
            out[mac] = {
                ipaddr = ip or "",
                interface = dev or "",
                active = fl ~= 0
            }
        end
    end
    f:close()
    return out
end

local function base_record(mac, lease, arp, wifi, ov, now)
    lease = lease or {}
    arp   = arp   or {}
    wifi  = wifi  or {}
    ov    = ov    or {}

    local active = (wifi.interface ~= nil) or (arp.active == true)
    local iface = wifi.iface
    if not iface and arp.interface and arp.interface:match("^wlan") then
        iface = arp.interface
    elseif not iface and arp.interface and arp.interface ~= "" then
        iface = "eth"
    end

    -- Fields and zero defaults follow the donor object names.  Per-client
    -- traffic values are zero until a target-native producer is implemented;
    -- inbytes/outbytes direction is deliberately not guessed.
    return {
        macaddr   = mac,
        ipaddr    = (arp.ipaddr and arp.ipaddr ~= "") and arp.ipaddr or (lease.ipaddr or ""),
        hostname  = (ov.hostname and ov.hostname ~= "") and ov.hostname or (lease.hostname or ""),
        devtype   = ov.devtype or "",
        brand     = ov.brand or "",
        online    = session_seconds(mac, active, now),
        inactive  = active and 0 or 1,
        upspeed   = 0,
        upbytes   = 0,
        downspeed = 0,
        downbytes = 0,
        inbytes   = 0,
        outbytes  = 0,
        interface = wifi.interface or arp.interface or "",
        iface     = iface or ""
    }
end

function get_backhaul()
    -- No Cudy mesh/cloud backhaul exists on this target.
    return {}
end

function devlist()
    local leases = dhcp_leases()
    local arp = arp_entries()
    local wifi = wifi_stations()
    local overrides = devname_overrides()
    local macs = {}

    for mac in pairs(leases) do macs[mac] = true end
    for mac in pairs(arp) do macs[mac] = true end
    for mac in pairs(wifi) do macs[mac] = true end
    for mac in pairs(overrides) do
        -- Persistent metadata alone must not invent a runtime client row.
        if leases[mac] or arp[mac] or wifi[mac] then macs[mac] = true end
    end

    local keys = {}
    for mac in pairs(macs) do keys[#keys + 1] = mac end
    table.sort(keys)

    local now = uptime_now()
    local out = {}
    for _, mac in ipairs(keys) do
        out[#out + 1] = base_record(mac, leases[mac], arp[mac], wifi[mac], overrides[mac], now)
    end
    return out
end

function devlist6()
    -- IPv6 client identity can be added from ip -6 neigh once target output
    -- is validated.  Empty list is preferable to fabricated donor semantics.
    return {}
end
