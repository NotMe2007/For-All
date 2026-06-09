-- run_prometheus.lua
-- Thin wrapper around Prometheus' CLI so it works under Lua 5.4.
-- Prometheus' cli.lua was written for Lua 5.1 and uses loadstring()/setfenv(),
-- which were removed in 5.2+. This shim restores them, then hands off to the CLI.
--
-- Invoked as:  lua run_prometheus.lua <prometheus_dir> <...normal cli args...>

-- Polyfill loadstring (5.2+ merged it into load).
if not loadstring then
	loadstring = load
end

-- Polyfill setfenv using the debug library (5.2+ replaced env with the _ENV upvalue).
if not setfenv then
	setfenv = function(fn, env)
		local i = 1
		while true do
			local name = debug.getupvalue(fn, i)
			if name == "_ENV" then
				debug.upvaluejoin(fn, i, function() return env end, 1)
				break
			elseif not name then
				break
			end
			i = i + 1
		end
		return fn
	end
end

-- First argument is the Prometheus directory; remove it so the remaining `arg`
-- looks exactly like a normal Prometheus CLI invocation.
local prometheusDir = table.remove(arg, 1)
assert(prometheusDir, "usage: lua run_prometheus.lua <prometheus_dir> <cli args...>")

-- Make src.* requireable, then run the CLI.
package.path = prometheusDir .. "/?.lua;" .. package.path
require("src.cli")
