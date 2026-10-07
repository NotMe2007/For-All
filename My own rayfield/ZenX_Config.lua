--[[
=====================================================================================
	ZenX Studio - Config System (reusable)
	-------------------------------------------------------------------------------
	Drop-in named-config manager for any ZenX/SeneX (Rayfield-API) script.

	Saves under:
	  ZenX_Studio/<GameName>/Accounts/<UserId>/<configName>.json   this account (default)
	  ZenX_Studio/<GameName>/<configName>.json                      global (all accounts)
	Autoload pointers:
	  ZenX_Studio/<GameName>/Accounts/<UserId>/autoload.txt   this account (wins)
	  ZenX_Studio/<GameName>/autoload.txt                      all accounts (fallback)

	The "Save as Global (all accounts)" toggle picks where Create/Overwrite and Set
	Autoload write. Global configs show in the list as "[Global] name"; picking one
	flips the toggle to match (flip it back after picking to copy a config across).
	Configs + autoload.txt from before per-account saving sit in the game folder, so
	they simply count as global and keep working on every account.
	Accounts are keyed on the Roblox UserId read at runtime - never a hardcoded name.
	If the UserId can't be read, everything falls back to global (the old behaviour).

	It builds a whole "Configuration" tab (config list + name input, Create/Load/
	Delete/Refresh, Global toggle, Autoload set/clear + status, and optional Unload +
	Discord buttons), and auto-loads the saved autoload config on launch.

	-------------------------------------------------------------------------------
	PER-GAME SETUP - this is the ONLY thing you change per script:
	-------------------------------------------------------------------------------
	You give it two functions:
	  GetData()        -> returns a plain table of everything you want saved.
	  ApplyData(data)  -> receives that table back and applies it to your state.

	Keep the SAME keys in both. Only put JSON-safe values (booleans, numbers,
	strings, and tables/arrays of those) - NOT Instances, Color3, functions, etc.
	(For a Color3, save {r,g,b}; rebuild it in ApplyData.)

	USAGE:
	-------------------------------------------------------------------------------
	local SeneX = loadstring(game:HttpGet(".../SeneX.lua"))()
	local Window = SeneX:CreateWindow({ Name = "ZenX | Fisch" })
	-- ... build your tabs/toggles/sliders, keeping their state in your own tables ...

	local ZenXConfig = loadstring(game:HttpGet(
	    "https://raw.githubusercontent.com/NotMe2007/For-All/main/My%20own%20rayfield/ZenX_Config.lua"
	))()

	ZenXConfig.Setup({
	    Window   = Window,
	    Library  = SeneX,          -- optional: enables notifications + the Unload button
	    GameName = "Fisch",        -- becomes the subfolder under ZenX_Studio
	    Discord  = "https://discord.gg/yourinvite",   -- optional

	    GetData = function()
	        return {
	            Settings   = Settings,        -- your own tables
	            Toggles    = Toggles,
	            WalkSpeed  = Character.WalkSpeed,
	            Fly_Speed  = Character.Fly_Speed,
	            -- ...whatever this game needs...
	        }
	    end,

	    -- ApplyData receives (data, apply). Wrap each field in apply("Label", fn):
	    -- every apply() runs in isolation, so if the script CHANGED and a setting/UI
	    -- element no longer exists, only THAT line is skipped - the rest still load,
	    -- and the user gets a "Script Updated" popup instead of a broken config.
	    ApplyData = function(data, apply)
	        apply("Settings",  function() if data.Settings  then Settings  = data.Settings  end end)
	        apply("Toggles",   function() if data.Toggles   then Toggles   = data.Toggles   end end)
	        apply("WalkSpeed", function()
	            if data.WalkSpeed then
	                Character.WalkSpeed = data.WalkSpeed
	                if D.WalkSpeedSlider then D.WalkSpeedSlider:Set(data.WalkSpeed) end -- keep UI in sync
	            end
	        end)
	        apply("Fly Speed", function() if data.Fly_Speed then Character.Fly_Speed = data.Fly_Speed end end)
	        -- (A plain monolithic ApplyData without `apply` still works - it just loads
	        --  up to the first error instead of skipping only the dead field.)
	    end,

	    OnUnload = function()   -- optional: your own cleanup for the Unload button
	        -- for _, t in ipairs(getgenv().MyLoops or {}) do task.cancel(t) end
	        -- for _, c in ipairs(getgenv().MyConns or {}) do c:Disconnect() end
	    end,

	    OnPartialLoad = function(skipped)  -- optional: fires when a load skipped removed
	        -- settings (skipped = list of labels). e.g. trigger your ZenX_Gate update here.
	    end,
	})

	Returns a handle if you want to drive it from code too:
	  Save(name, global)   global = true/false, nil = the toggle (or a "[Global] " prefix)
	  Load(name, scope)    scope  = "account" / "global", nil = this account first, then global
	  Delete(name, scope)  scope nil = the "[Global] " prefix, else the toggle (never falls back)
	  List()               the dropdown list ("name" = this account, "[Global] name" = global)
	  Refresh()            re-read the list + autoload status
	  Autoload()           -> name, "account"/"global" (where the config lives), or nil
	  Tab                  the Configuration tab
	  Folder               the GLOBAL game folder (ZenX_Studio/<GameName>) - unchanged
	  AccountFolder        this account's folder, or nil when the UserId couldn't be read
=====================================================================================
]]

local HttpService = game:GetService("HttpService")

local ZenXConfig = {}
local ROOT = "ZenX_Studio"
local GLOBAL_TAG = "[Global] "   -- list prefix for configs shared by every account
-- Account autoload pointer values. sanitize() strips < > and :, so no saved config can
-- be named "<off>" or start with "global:" - the markers can't collide with a name.
local AUTOLOAD_OFF = "<off>"     -- this account skips the global autoload
local GLOBAL_PTR = "global:"     -- "global:farm" = this account autoloads [Global] farm

-- Are the executor filesystem functions present? (weak UNC executors may lack them)
local function fsReady()
	return type(isfolder) == "function" and type(makefolder) == "function"
		and type(isfile) == "function" and type(readfile) == "function"
		and type(writefile) == "function" and type(listfiles) == "function"
end

-- Strip characters that aren't valid in a folder/file name.
local function sanitize(name)
	name = tostring(name or "Unknown")
	name = name:gsub('[<>:"/\\|%?%*%c]', "_")
	name = name:gsub("%s+$", "")
	if name == "" then name = "Unknown" end
	return name
end

local function trim(s)
	s = tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
	return s
end

-- This account's folder name = its Roblox UserId, or nil (then everything is global).
-- Keyed on the id, never the name: names change, and hubs run on every account.
local function accountId()
	local ok, id = pcall(function() return game:GetService("Players").LocalPlayer.UserId end)
	id = ok and tonumber(id) or nil
	if id and id > 0 then return tostring(math.floor(id)) end
	return nil
end

function ZenXConfig.Setup(opts)
	assert(type(opts) == "table", "ZenXConfig.Setup expects an options table")
	local Window = assert(opts.Window, "ZenXConfig: Window is required")
	local Library = opts.Library
	local GameName = sanitize(opts.GameName or "Unknown")
	local GetData = opts.GetData or function() return {} end
	local ApplyData = opts.ApplyData or function() end
	local ext = ".json"
	local autoloadFile = "autoload.txt"
	local gameFolder = ROOT .. "/" .. GameName
	local uid = accountId()
	local accountFolder = uid and (gameFolder .. "/Accounts/" .. uid) or nil
	local globalAutoload = gameFolder .. "/" .. autoloadFile
	local accountAutoload = accountFolder and (accountFolder .. "/" .. autoloadFile) or nil
	local saveGlobal = false -- the "Save as Global (all accounts)" toggle

	local function notify(title, content)
		if opts.Notify then
			pcall(opts.Notify, title, content)
		elseif Library and Library.Notify then
			pcall(function() Library:Notify({ Title = title, Content = content, Duration = 4 }) end)
		end
	end

	-- Create the folders a scope writes into (nested - make each level).
	local function ensureFolders(scope)
		pcall(function()
			if not isfolder(ROOT) then makefolder(ROOT) end
			if not isfolder(gameFolder) then makefolder(gameFolder) end
			if scope == "account" and accountFolder then
				if not isfolder(gameFolder .. "/Accounts") then makefolder(gameFolder .. "/Accounts") end
				if not isfolder(accountFolder) then makefolder(accountFolder) end
			end
		end)
	end

	local fs = fsReady()
	if fs then
		-- the global game folder up front; an account folder only once it's written to
		ensureFolders("global")
	else
		notify("Config", "This executor is missing filesystem functions - configs can't be saved here.")
	end

	local function folderOf(scope)
		if scope == "account" and accountFolder then return accountFolder end
		return gameFolder
	end
	local function pathOf(name, scope)
		return folderOf(scope) .. "/" .. name .. ext
	end
	local function exists(path)
		local ok, has = pcall(isfile, path)
		return ok and has == true
	end
	-- What new saves default to: the toggle, or global when there is no account folder.
	local function defaultScope()
		if saveGlobal or not accountFolder then return "global" end
		return "account"
	end
	-- How a config shows in the list / notifications.
	local function shown(name, scope)
		if scope == "global" and accountFolder then return GLOBAL_TAG .. name end
		return name
	end

	-- Saved config names in one folder (without extension, skipping autoload.txt).
	local function namesIn(folder)
		local names = {}
		if not fs then return names end
		local ok, files = pcall(listfiles, folder)
		if ok and type(files) == "table" then
			for _, file in ipairs(files) do
				file = tostring(file)
				if not file:find(autoloadFile, 1, true) then
					local name = file:match("([^\\/]+)%" .. ext .. "$")
					if name then table.insert(names, name) end
				end
			end
		end
		table.sort(names)
		return names
	end

	-- The dropdown list: this account's configs by plain name, then "[Global] name".
	local function listConfigs()
		local list = {}
		if accountFolder then
			for _, name in ipairs(namesIn(accountFolder)) do list[#list + 1] = name end
		end
		for _, name in ipairs(namesIn(gameFolder)) do list[#list + 1] = shown(name, "global") end
		return list
	end

	-- "[Global] farm" -> "farm", "global"   |   "farm" -> "farm", nil (scope not chosen)
	-- No trimming: list entries are exact file names, and an old config saved as
	-- "farm .json" must still be found. Typed names are trimmed by the input box.
	local function parseEntry(entry)
		entry = tostring(entry or "")
		if entry:sub(1, #GLOBAL_TAG) == GLOBAL_TAG then
			return entry:sub(#GLOBAL_TAG + 1), "global"
		end
		return entry, nil
	end
	local function blank(name) return not name:find("%S") end

	-- The file name a config sits under in one scope: the exact name if that file
	-- exists (older saves kept odd names), else the sanitized name Save writes, so a
	-- typed "pvp: fast" finds "pvp_ fast". -> name, found
	local function locate(name, scope)
		if exists(pathOf(name, scope)) then return name, true end
		local clean = sanitize(name)
		if clean ~= name and exists(pathOf(clean, scope)) then return clean, true end
		return name, false
	end

	-- Find an existing config -> name, scope, found. An explicit scope is the only
	-- place looked; nil = this account first, then global (a legacy/global config of
	-- the same name is still found).
	local function find(name, scope)
		if not accountFolder then scope = "global" end
		if scope then
			local located, found = locate(name, scope)
			return located, scope, found
		end
		local located, found = locate(name, "account")
		if found then return located, "account", true end
		located, found = locate(name, "global")
		return located, "global", found
	end

	-- "not found" + where a copy of that name DOES exist (picking it from the list
	-- flips the toggle to match).
	local function notFound(name, scope, text)
		local msg = text or ("Config '" .. shown(name, scope) .. "' not found.")
		if accountFolder then
			local other = scope == "global" and "account" or "global"
			local located, found = locate(name, other)
			if found then msg = msg .. " There is a '" .. shown(located, other) .. "' - pick it from the list." end
		end
		notify("Config", msg)
	end

	-- global: true / false, or nil = a "[Global] " prefix on the name, else the toggle.
	-- -> true, scope, saved name   |   false
	local function saveConfig(entry, global)
		if not fs then notify("Config", "Saving unavailable on this executor."); return false end
		local name, tagScope = parseEntry(entry)
		if blank(name) then notify("Config", "Enter a config name first."); return false end
		name = sanitize(name)
		local scope
		if global == nil then
			scope = tagScope or defaultScope()
		else
			scope = global and "global" or "account"
		end
		if not accountFolder then scope = "global" end
		local ok, encoded = pcall(function() return HttpService:JSONEncode(GetData()) end)
		if not ok then notify("Config", "Couldn't encode config (non-JSON value in GetData?)."); return false end
		ensureFolders(scope)
		local wok = pcall(writefile, pathOf(name, scope), encoded)
		if wok then
			local where = (scope == "global" and accountFolder) and " for all accounts" or ""
			notify("Config", "Saved '" .. shown(name, scope) .. "'" .. where .. ".")
			return true, scope, name
		end
		notify("Config", "Failed to write config file.")
		return false
	end

	local function loadConfig(entry, scope)
		if not fs then return false end
		local name, tagScope = parseEntry(entry)
		if blank(name) then notify("Config", "Pick or name a config first."); return false end
		local found
		name, scope, found = find(name, scope or tagScope)
		if not found then notFound(name, scope); return false end
		local label = shown(name, scope)
		local path = pathOf(name, scope)
		local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
		if not ok or type(data) ~= "table" then notify("Config", "Config '" .. label .. "' is corrupt."); return false end

		-- Graceful / partial load: if the script updated and a saved setting no longer
		-- exists, we skip just that field instead of dropping the whole config. Each
		-- apply() call is isolated so one dead field can't abort the rest.
		local skipped = {}
		local function apply(labelOrFn, maybeFn)
			local fieldLabel, fn
			if type(labelOrFn) == "function" then
				fn, fieldLabel = labelOrFn, "a setting"
			else
				fieldLabel, fn = tostring(labelOrFn), maybeFn
			end
			if type(fn) ~= "function" then return end
			local aok = pcall(fn)
			if not aok then table.insert(skipped, fieldLabel) end
		end

		local runOk = pcall(ApplyData, data, apply)
		if not runOk then
			-- Monolithic ApplyData (no `apply` wrapping) that errored partway: it loaded
			-- whatever ran before the error. Treat as a graceful partial, not a failure.
			table.insert(skipped, "one or more removed settings")
		end

		if #skipped > 0 then
			local list = table.concat(skipped, ", ")
			notify("Script Updated", "Loaded '" .. label .. "', but " .. #skipped ..
				" saved setting(s) no longer exist and were skipped (" .. list ..
				"). Please update to the latest version.")
			if opts.OnPartialLoad then pcall(opts.OnPartialLoad, skipped) end
			return true
		end

		notify("Config", "Loaded '" .. label .. "'.")
		return true
	end

	-- Remove a file; without delfile, empty it (an empty pointer reads as unset).
	local function removeFile(path)
		if not (fs and path and exists(path)) then return false end
		if type(delfile) == "function" and pcall(delfile, path) then return true end
		return (pcall(writefile, path, ""))
	end

	-- Deletes ONLY in the scope asked for (else the "[Global] " prefix, else the toggle),
	-- never falling back: pressing Delete twice on "farm" must not then take the
	-- "[Global] farm" every account uses.
	local function deleteConfig(entry, scope)
		if not fs then return false end
		local name, tagScope = parseEntry(entry)
		if blank(name) then notify("Config", "Pick or name a config first."); return false end
		local found
		name, scope, found = find(name, scope or tagScope or defaultScope())
		if not found then notFound(name, scope); return false end
		if type(delfile) ~= "function" then notify("Config", "Deleting unavailable on this executor."); return false end
		if not pcall(delfile, pathOf(name, scope)) then notify("Config", "Failed to delete '" .. shown(name, scope) .. "'."); return false end
		notify("Config", "Deleted '" .. shown(name, scope) .. "'.")
		return true
	end

	-- ── Autoload pointers ───────────────────────────────────────────────────────
	local function readPointer(path)
		if not (fs and path) then return nil end
		local ok, text = pcall(function() if isfile(path) then return readfile(path) end end)
		if not ok or type(text) ~= "string" then return nil end
		-- trailing whitespace only (the newline), like the old autoload reader: a
		-- config name can start with a space
		text = text:gsub("%s+$", "")
		if text == "" then return nil end
		return text
	end

	-- What loads on launch here -> name, configScope, pointerScope. The account pointer
	-- wins; then the global one. (nil, nil, "account") = this account opted out.
	local function currentAutoload()
		local p = readPointer(accountAutoload)
		if p == AUTOLOAD_OFF then return nil, nil, "account" end
		if p then
			if p:sub(1, #GLOBAL_PTR) == GLOBAL_PTR then return p:sub(#GLOBAL_PTR + 1), "global", "account" end
			return p, "account", "account"
		end
		-- legacy autoload.txt (plain name) = a config in the game folder = global
		p = readPointer(globalAutoload)
		if p then return p, "global", "global" end
		return nil
	end

	local function autoloadStatus()
		if not fs then return "Autoload: unavailable on this executor" end
		local name, scope, from = currentAutoload()
		if not name then
			if from == "account" then return "Autoload: off for this account" end
			return "Autoload: none"
		end
		if not accountFolder then return "Autoload: " .. name end
		return "Autoload: " .. shown(name, scope) .. (from == "global" and "  (all accounts)" or "  (this account)")
	end

	-- ── Build the Configuration tab ─────────────────────────────────────────────
	local Tab = Window:CreateTab(opts.TabName or "Configuration", opts.TabIcon or 4483362458)
	local ConfigName = ""
	local scopeToggle, statusLabel

	Tab:CreateSection("Configs (" .. GameName .. ")")

	local dropdown = Tab:CreateDropdown({
		Name = "Config List",
		Options = listConfigs(),
		CurrentOption = {},
		MultipleOptions = false,
		Search = true,
		Callback = function(v)
			ConfigName = (type(v) == "table" and v[1]) or v or ""
			-- the toggle follows the picked config, so Overwrite / Set Autoload hit THAT one
			if scopeToggle then
				local _, tagScope = parseEntry(ConfigName)
				local wantGlobal = tagScope == "global"
				if wantGlobal ~= saveGlobal then scopeToggle:Set(wantGlobal) end
			end
		end,
	})

	Tab:CreateInput({
		Name = "Config Name",
		PlaceholderText = "Enter a name...",
		RemoveTextAfterFocusLost = false,
		Callback = function(t)
			t = trim(t)
			if t ~= "" then ConfigName = t end
		end,
	})

	if accountFolder then
		scopeToggle = Tab:CreateToggle({
			Name = "Save as Global (all accounts)",
			CurrentValue = false,
			Ext = true,
			Callback = function(v) saveGlobal = v and true or false end,
		})
	end

	local function refresh()
		pcall(function() dropdown:Refresh(listConfigs()) end)
		if statusLabel then pcall(function() statusLabel:Set(autoloadStatus()) end) end
	end

	Tab:CreateButton({ Name = "Create / Overwrite Config", Callback = function()
		local ok, scope, name = saveConfig(ConfigName, saveGlobal)
		if ok then
			-- point at what was written (sanitized name + scope) for Load / Set Autoload
			ConfigName = shown(name, scope)
			refresh()
		end
	end })
	Tab:CreateButton({ Name = "Load Config", Callback = function()
		-- the "[Global] " tag, else the toggle; with the toggle off a name that only
		-- exists globally (e.g. a config from before per-account saving) still loads
		local _, tagScope = parseEntry(ConfigName)
		loadConfig(ConfigName, tagScope or (saveGlobal and "global") or nil)
	end })
	Tab:CreateButton({ Name = "Delete Config", Callback = function()
		if deleteConfig(ConfigName) then refresh() end
	end })
	Tab:CreateButton({ Name = "Refresh List", Callback = refresh })

	Tab:CreateSection("Autoload")
	statusLabel = Tab:CreateLabel(autoloadStatus())
	Tab:CreateButton({ Name = "Set Current as Autoload", Callback = function()
		if not fs then return end
		local name, tagScope = parseEntry(ConfigName)
		if blank(name) then notify("Config", "Pick or name a config first."); return end
		-- the "[Global] " tag, else the toggle - no fallback, so the pointer always
		-- names the config the user meant
		local scope, found
		name, scope, found = find(name, tagScope or defaultScope())
		if not found then
			notFound(name, scope, "Save '" .. shown(name, scope) .. "' first, then set it as autoload.")
			return
		end
		if scope == "global" and (saveGlobal or not accountFolder) then
			-- every account; this account follows it too, so drop its own pointer
			ensureFolders("global")
			if not pcall(writefile, globalAutoload, name) then notify("Config", "Failed to write autoload."); return end
			removeFile(accountAutoload)
			notify("Config", "'" .. shown(name, scope) .. "' will auto-load on every account (unless one sets its own).")
		else
			ensureFolders("account")
			local pointer = scope == "global" and (GLOBAL_PTR .. name) or name
			if not pcall(writefile, accountAutoload, pointer) then notify("Config", "Failed to write autoload."); return end
			notify("Config", "'" .. shown(name, scope) .. "' will auto-load on this account.")
		end
		refresh()
	end })
	Tab:CreateButton({ Name = "Clear Autoload", Callback = function()
		if not fs then return end
		if saveGlobal or not accountFolder then
			local had = removeFile(globalAutoload)
			-- an opt-out marker means nothing once the global pointer is gone
			if readPointer(accountAutoload) == AUTOLOAD_OFF then removeFile(accountAutoload) end
			notify("Config", had and "Global autoload cleared (accounts with their own keep theirs)." or "No global autoload set.")
		else
			-- this account only. With a global autoload around, leave an opt-out marker,
			-- otherwise the global one would just kick in here instead.
			if readPointer(globalAutoload) then
				ensureFolders("account")
				pcall(writefile, accountAutoload, AUTOLOAD_OFF)
			else
				removeFile(accountAutoload)
			end
			notify("Config", "Autoload off for this account.")
		end
		refresh()
	end })

	if opts.OnUnload or Library or opts.Discord then
		Tab:CreateSection("System")
		if opts.OnUnload or Library then
			Tab:CreateButton({ Name = "Unload Script", Callback = function()
				if opts.OnUnload then pcall(opts.OnUnload) end
				if Library and Library.Destroy then pcall(function() Library:Destroy() end) end
			end })
		end
		if opts.Discord then
			Tab:CreateButton({ Name = "Copy Discord Link", Callback = function()
				if setclipboard then pcall(setclipboard, opts.Discord) end
				notify("Discord", "Invite copied to clipboard.")
			end })
		end
	end

	-- ── Autoload on launch ──────────────────────────────────────────────────────
	if opts.AutoLoad ~= false and fs then
		local autoName, autoScope = currentAutoload()
		if autoName then
			task.spawn(function()
				task.wait(0.5) -- let the UI finish building first
				loadConfig(autoName, autoScope)
			end)
		end
	end

	return {
		Save = saveConfig,
		Load = loadConfig,
		Delete = deleteConfig,
		List = listConfigs,
		Refresh = refresh,
		Autoload = function()
			local name, scope = currentAutoload()
			return name, scope
		end,
		Tab = Tab,
		Folder = gameFolder,
		AccountFolder = accountFolder,
	}
end

return ZenXConfig
