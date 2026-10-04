module("luci.f9k1103_adapter", package.seeall)

local uci  = require "luci.model.uci".cursor()
local util = require "luci.util"

local function first_ipv4(st)
    local a = st and st["ipv4-address"]
    if type(a) == "table" and type(a[1]) == "table" then
        return a[1].address, a[1].mask
    end
end

local function first_route(st)
    local r = st and st.route
    if type(r) == "table" then
        for _, v in ipairs(r) do
            if type(v) == "table" and v.target == "0.0.0.0" then
                return v.nexthop
            end
        end
    end
end

function board()
    local b = util.ubus("system", "board") or {}
    return {
        hostname = b.hostname or uci:get("system", "@system[0]", "hostname") or "LEDE",
        model = b.model or "Belkin F9K1103 Version 1.0",
        system = b.system or "Ralink RT3883",
        release = (b.release and b.release.description) or "LEDE 17.01.5",
        kernel = b.kernel or "4.4.140"
    }
end

function netif(name)
    local st = util.ubus("network.interface." .. name, "status") or {}
    local ip, mask = first_ipv4(st)
    return {
        name = name,
        up = st.up == true,
        pending = st.pending == true,
        proto = st.proto or uci:get("network", name, "proto") or "-",
        device = st.device or st.l3_device or uci:get("network", name, "ifname") or "-",
        ipaddr = ip or uci:get("network", name, "ipaddr") or "-",
        netmask = mask or uci:get("network", name, "netmask") or "-",
        gateway = first_route(st) or uci:get("network", name, "gateway") or "-"
    }
end

local function radio_band(dev)
    local hw = (uci:get("wireless", dev, "hwmode") or ""):lower()
    if hw:find("11a", 1, true) or hw == "a" then
        return "5 GHz"
    end
    if hw:find("11g", 1, true) or hw:find("11b", 1, true) then
        return "2.4 GHz"
    end
    local ch = tonumber(uci:get("wireless", dev, "channel") or "")
    if ch and ch > 14 then return "5 GHz" end
    if ch and ch > 0 then return "2.4 GHz" end
    return "Wi-Fi"
end

local function ssid_for_device(dev)
    local ssid
    local disabled = false
    uci:foreach("wireless", "wifi-iface", function(s)
        if not ssid and s.device == dev then
            ssid = s.ssid
            disabled = tostring(s.disabled or "0") == "1"
        end
    end)
    return ssid or "-", disabled
end

function radios()
    local out = {}
    uci:foreach("wireless", "wifi-device", function(s)
        local ssid, iface_disabled = ssid_for_device(s[".name"])
        local dev_disabled = tostring(s.disabled or "0") == "1"
        out[#out + 1] = {
            name = s[".name"],
            band = radio_band(s[".name"]),
            ssid = ssid,
            channel = s.channel or "auto",
            hwmode = s.hwmode or "-",
            enabled = not dev_disabled and not iface_disabled
        }
    end)
    table.sort(out, function(a, b)
        if a.band == b.band then return a.name < b.name end
        return a.band < b.band
    end)
    return out
end

function capabilities()
    return {
        router = true,
        ethernet = true,
        wireless_24 = true,
        wireless_5 = true,
        usb = true,
        cellular = false,
        sms = false,
        sim = false,
        tr069 = false
    }
end

function snapshot()
    return {
        board = board(),
        wan = netif("wan"),
        lan = netif("lan"),
        radios = radios(),
        capabilities = capabilities()
    }
end
