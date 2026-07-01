--[[
=====================================================================================
	ZenX Studio - Config System (reusable)
	-------------------------------------------------------------------------------
	Drop-in named-config manager for any ZenX/SeneX (Rayfield-API) script.

	Saves everything under:   ZenX_Studio/<GameName>/<configName>.json
	Autoload pointer:         ZenX_Studio/<GameName>/autoload.txt

	It builds a whole "Configuration" tab (config list + name input, Create/Load/
	Delete/Refresh, Autoload set/clear, and optional Unload + Discord buttons), and
	auto-loads the saved autoload config on launch.

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

	    ApplyData = function(data)
	        if data.Settings  then Settings  = data.Settings  end
	        if data.Toggles   then Toggles   = data.Toggles   end
	        if data.WalkSpeed then Character.WalkSpeed = data.WalkSpeed end
	        if data.Fly_Speed then Character.Fly_Speed = data.Fly_Speed end
	        -- IMPORTANT: also push values back into the UI elements, e.g.
	        --   if data.WalkSpeed and D.WalkSpeedSlider then D.WalkSpeedSlider:Set(data.WalkSpeed) end
	        -- so toggles/sliders visually match the loaded config.
	    end,

	    OnUnload = function()   -- optional: your own cleanup for the Unload button
	        -- for _, t in ipairs(getgenv().MyLoops or {}) do task.cancel(t) end
	        -- for _, c in ipairs(getgenv().MyConns or {}) do c:Disconnect() end
	    end,
	})

	Returns a handle: { Save, Load, Delete, List, Refresh, Tab, Folder } if you want
	to drive it from code too.
=====================================================================================
]]

local HttpService = game:GetService("HttpService")

local ZenXConfig = {}
local ROOT = "ZenX_Studio"

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

	local function notify(title, content)
		if opts.Notify then
			pcall(opts.Notify, title, content)
		elseif Library and Library.Notify then
			pcall(function() Library:Notify({ Title = title, Content = content, Duration = 4 }) end)
		end
	end

	local fs = fsReady()
	if fs then
		-- create ZenX_Studio and the per-game subfolder (nested - make each level)
		pcall(function()
			if not isfolder(ROOT) then makefolder(ROOT) end
			if not isfolder(gameFolder) then makefolder(gameFolder) end
		end)
	else
		notify("Config", "This executor is missing filesystem functions - configs can't be saved here.")
	end

	-- List saved config names in this game's folder (without extension, skipping autoload.txt).
	local function listConfigs()
		local names = {}
		if not fs then return names end
		local ok, files = pcall(listfiles, gameFolder)
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

	local function saveConfig(name)
		if not fs then notify("Config", "Saving unavailable on this executor."); return false end
		if not name or name == "" then notify("Config", "Enter a config name first."); return false end
		local ok, encoded = pcall(function() return HttpService:JSONEncode(GetData()) end)
		if not ok then notify("Config", "Couldn't encode config (non-JSON value in GetData?)."); return false end
		local wok = pcall(writefile, gameFolder .. "/" .. name .. ext, encoded)
		if wok then notify("Config", "Saved '" .. name .. "'."); return true end
		notify("Config", "Failed to write config file.")
		return false
	end

	local function loadConfig(name)
		if not fs then return false end
		if not name or name == "" then notify("Config", "Pick or name a config first."); return false end
		local path = gameFolder .. "/" .. name .. ext
		if not isfile(path) then notify("Config", "Config '" .. name .. "' not found."); return false end
		local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
		if not ok or type(data) ~= "table" then notify("Config", "Config '" .. name .. "' is corrupt."); return false end
		local aok, err = pcall(ApplyData, data)
		if aok then notify("Config", "Loaded '" .. name .. "'."); return true end
		notify("Config", "Error applying config: " .. tostring(err))
		return false
	end

	local function deleteConfig(name)
		if not fs or not name or name == "" then return false end
		local path = gameFolder .. "/" .. name .. ext
		if isfile(path) and type(delfile) == "function" then
			pcall(delfile, path)
			notify("Config", "Deleted '" .. name .. "'.")
			return true
		end
		return false
	end

	-- ── Build the Configuration tab ─────────────────────────────────────────────
	local Tab = Window:CreateTab(opts.TabName or "Configuration", opts.TabIcon or 4483362458)
	local ConfigName = ""

	Tab:CreateSection("Configs (" .. GameName .. ")")

	local dropdown = Tab:CreateDropdown({
		Name = "Config List",
		Options = listConfigs(),
		CurrentOption = {},
		MultipleOptions = false,
		Search = true,
		Callback = function(v)
			ConfigName = (type(v) == "table" and v[1]) or v or ""
		end,
	})

	Tab:CreateInput({
		Name = "Config Name",
		PlaceholderText = "Enter a name...",
		RemoveTextAfterFocusLost = false,
		Callback = function(t) if t and t ~= "" then ConfigName = t end end,
	})

	local function refresh()
		pcall(function() dropdown:Refresh(listConfigs()) end)
	end

	Tab:CreateButton({ Name = "Create / Overwrite Config", Callback = function()
		if saveConfig(ConfigName) then refresh() end
	end })
	Tab:CreateButton({ Name = "Load Config", Callback = function()
		loadConfig(ConfigName)
	end })
	Tab:CreateButton({ Name = "Delete Config", Callback = function()
		if deleteConfig(ConfigName) then refresh() end
	end })
	Tab:CreateButton({ Name = "Refresh List", Callback = refresh })

	Tab:CreateSection("Autoload")
	Tab:CreateButton({ Name = "Set Current as Autoload", Callback = function()
		if not fs then return end
		if ConfigName == "" then notify("Config", "Pick or name a config first."); return end
		pcall(writefile, gameFolder .. "/" .. autoloadFile, ConfigName)
		notify("Config", "'" .. ConfigName .. "' will auto-load next launch.")
	end })
	Tab:CreateButton({ Name = "Clear Autoload", Callback = function()
		if fs and isfile(gameFolder .. "/" .. autoloadFile) and type(delfile) == "function" then
			pcall(delfile, gameFolder .. "/" .. autoloadFile)
			notify("Config", "Autoload cleared.")
		end
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
		local apath = gameFolder .. "/" .. autoloadFile
		if isfile(apath) then
			local ok, autoName = pcall(readfile, apath)
			if ok and autoName and autoName ~= "" then
				autoName = tostring(autoName):gsub("%s+$", "")
				task.spawn(function()
					task.wait(0.5) -- let the UI finish building first
					loadConfig(autoName)
				end)
			end
		end
	end

	return {
		Save = saveConfig,
		Load = loadConfig,
		Delete = deleteConfig,
		List = listConfigs,
		Refresh = refresh,
		Tab = Tab,
		Folder = gameFolder,
	}
end

return ZenXConfig
