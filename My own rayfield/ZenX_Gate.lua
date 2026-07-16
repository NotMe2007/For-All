--[[
=====================================================================================
	ZenX Studio - Version Gate / Kill-Switch / Auto-Updater  (reusable, per-script)
	-------------------------------------------------------------------------------
	Each script keeps its OWN integer BUILD number and its OWN manifest URL, so one
	shared module gates every script independently.

	Returns a single function. Call it as the FIRST thing your script does, and STOP
	if it returns true:

		local gate = loadstring(game:HttpGet(
		    "https://raw.githubusercontent.com/NotMe2007/For-All/main/My%20own%20rayfield/ZenX_Gate.lua"
		))()

		if gate({
		    Build    = 47,                                   -- bump +1 EVERY release
		    Manifest = "https://raw.githubusercontent.com/NotMe2007/For-All/main/manifests/RIVALS.json",
		    -- LatestUrl is optional here; the manifest's latestUrl is preferred.
		}) then return end     -- <-- if the gate handled it (blocked / hot-swapped), stop the old build

		-- ...key check, UI, everything else runs only on an allowed build...

	WHY AN INTEGER BUILD (not your V-label): "V0.1.0" < "V9" as strings is nonsense.
	Keep BUILD as a plain integer for comparisons; keep your cosmetic ZENX_VERSION
	label separate for display.

	MANIFEST (one small JSON file per script, hosted on GitHub raw):
		{
		    "minBuild":     45,                     // anything below this is forced to update
		    "latestBuild":  47,                     // optional: for the soft "update available" hint
		    "killedBuilds": [42, 43],               // specific builds to nuke even if >= minBuild
		    "latestUrl":    "https://raw.githubusercontent.com/NotMe2007/For-All/main/My%20own%20rayfield/SeneX.lua",
		    "message":      "A security fix landed in a newer build - updating you now..."
		}

	YOUR KEY-SYSTEM SCENARIO: put this gate first, your key check second. An old
	keyless-bypass build gets force-migrated onto the latest (which has the key
	system); the key check then reads the SAVED key off the device, so anyone who
	already has a valid key sails through untouched, and only bypassers hit the prompt.

	HONEST LIMITS (client-side is best-effort):
	  * It protects every build that CONTAINS this gate, going forward.
	  * It cannot reach a copy that predates the gate (that old file never fetches
	    the manifest). Kill those by rotating a remote/asset/endpoint they depend on,
	    or - the only unstrippable lock - have your backend reject old BUILDs in the
	    key/auth request (pass Build along to your key check).
	  * A determined user can delete this gate from a gated build too. This stops
	    casual/accidental old-version use and auto-migrates honest users; the backend
	    BUILD check is what actually enforces against tampering.

	CONFIG FIELDS:
	  Build             (number)  this script's build. Required for a real check.
	  Manifest          (string)  raw URL of this script's version JSON. Required.
	  LatestUrl         (string)  fallback newest-build URL if the manifest omits latestUrl.
	  AutoReload        (bool)    default true: hot-swap into the latest build on outdated.
	  FailClosed        (bool)    default false: if the manifest can't be fetched, false =
	                              keep running (don't lock users out on a GitHub outage);
	                              true = refuse to run (safer for an active vuln).
	  Heartbeat         (bool|number) re-check every N sec (default 60) to kill sessions
	                              that were already open when you flip the switch.
	  Message           (string)  fallback message if the manifest has none.
	  OnOutdated        (fn)(msg, manifest)   show your own toast/GUI before the swap.
	  OnUpdateAvailable (fn)(manifest)        soft "update available" (not blocking).
	  OnKilled          (fn)(manifest)        heartbeat fired mid-session: tear down GUI/loops.

	Returns TRUE when the caller should STOP (blocked or hot-swapped), FALSE to continue.
=====================================================================================
]]

local HttpService = game:GetService("HttpService")

-- Fetch with a cache-buster: raw.githubusercontent.com is CDN-cached ~5 min, so the
-- ?cb= query forces a fresh copy and kills/updates propagate near-instantly.
local function fetch(url)
	local ok, res = pcall(function()
		local sep = string.find(url, "?", 1, true) and "&" or "?"
		return game:HttpGet(url .. sep .. "cb=" .. tostring(os.time()), true)
	end)
	if ok and type(res) == "string" and #res > 0 then
		return res
	end
	return nil
end

local function decode(raw)
	local ok, m = pcall(function() return HttpService:JSONDecode(raw) end)
	if ok and type(m) == "table" then return m end
	return nil
end

local function isBlocked(build, m)
	if type(m.minBuild) == "number" and build < m.minBuild then return true end
	if type(m.killedBuilds) == "table" then
		for _, b in ipairs(m.killedBuilds) do
			if b == build then return true end
		end
	end
	return false
end

return function(cfg)
	if type(cfg) ~= "table" then return false end
	local BUILD = tonumber(cfg.Build) or 0
	local manifestUrl = cfg.Manifest
	if type(manifestUrl) ~= "string" then return false end -- no manifest → nothing to gate

	local raw = fetch(manifestUrl)
	if not raw then
		-- Manifest unreachable → fail policy.
		if cfg.FailClosed then
			if cfg.OnOutdated then
				pcall(cfg.OnOutdated, cfg.Message or "Version check unavailable - please try again later.", nil)
			else
				warn("[ZenX Gate] Version check unavailable - refusing to run (fail-closed).")
			end
			return true
		end
		return false -- fail-open: let them run
	end

	local m = decode(raw)
	if not m then return false end -- unreadable manifest → don't punish the user

	if isBlocked(BUILD, m) then
		local msg = m.message or cfg.Message or "Outdated build - updating you to the latest version..."
		if cfg.OnOutdated then pcall(cfg.OnOutdated, msg, m) else warn("[ZenX Gate] " .. msg) end

		if cfg.AutoReload ~= false then
			local latestUrl = m.latestUrl or cfg.LatestUrl
			if type(latestUrl) == "string" then
				local newer = fetch(latestUrl)
				if newer then
					local fn = (loadstring or load)(newer)
					if fn then
						pcall(fn) -- run the latest build; the old one stops below
					end
				end
			end
		end
		return true -- STOP the old build no matter what
	end

	-- Soft "update available" (allowed build, but not the newest).
	if type(m.latestBuild) == "number" and BUILD < m.latestBuild and cfg.OnUpdateAvailable then
		pcall(cfg.OnUpdateAvailable, m)
	end

	-- Heartbeat: catch sessions already open when you flip the switch mid-session.
	if cfg.Heartbeat then
		local interval = (type(cfg.Heartbeat) == "number" and cfg.Heartbeat) or 60
		task.spawn(function()
			while task.wait(interval) do
				local r = fetch(manifestUrl)
				local mm = r and decode(r)
				if mm and isBlocked(BUILD, mm) then
					if cfg.OnKilled then pcall(cfg.OnKilled, mm) end
					break
				end
			end
		end)
	end

	return false -- allowed → continue
end
