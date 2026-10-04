module("luci.controller.cudy_f9k1103", package.seeall)

function index()
    local root = entry({"admin", "cudy"}, alias("admin", "cudy", "status"), "Cudy", 1)
    root.index = true
    root.dependent = false

    local status = entry({"admin", "cudy", "status"}, template("cudy/status"), "System Status", 10)
    status.leaf = true
end
