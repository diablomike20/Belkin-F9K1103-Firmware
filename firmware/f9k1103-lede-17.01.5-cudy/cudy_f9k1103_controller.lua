module("luci.controller.cudy_f9k1103", package.seeall)

function index()
    local root = entry({"admin", "cudy"}, alias("admin", "cudy", "status"), "Cudy", 1)
    root.index = true
    root.dependent = false

    local status = entry({"admin", "cudy", "status"}, template("cudy/status"), "System Status", 10)
    status.leaf = true

    local setup = entry({"admin", "cudy", "setup"}, template("cudy/setup"), "Quick Setup", 20)
    setup.leaf = true

    local general = entry({"admin", "cudy", "general"}, template("cudy/general"), "General Settings", 30)
    general.leaf = true

    entry({"admin", "cudy", "advanced"}, alias("admin", "system", "system"), "Advanced Settings", 40)
    entry({"admin", "cudy", "diagnostics"}, alias("admin", "network", "diagnostics"), "Diagnostic Tools", 50)
end
