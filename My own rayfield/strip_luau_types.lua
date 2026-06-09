-- strip_luau_types.lua
-- Prometheus' tokenizer cannot handle Luau type annotations ("x: number?",
-- ":: any" casts, return types, etc.). This preprocessor removes the small,
-- known set of annotations used by the SeneX source so the file can be fed
-- through Prometheus. It uses LITERAL (plain) find/replace so it never touches
-- code or strings it shouldn't.
--
-- Usage:  lua strip_luau_types.lua <input.lua> <output.lua>

local inPath, outPath = arg[1], arg[2]
assert(inPath and outPath, "usage: lua strip_luau_types.lua <in> <out>")

local f = assert(io.open(inPath, "rb"))
local src = f:read("*a")
f:close()

-- Literal (non-pattern) replace-all.
local function literalReplace(s, find, repl)
	local out, pos = {}, 1
	while true do
		local a, b = string.find(s, find, pos, true)
		if not a then
			out[#out + 1] = string.sub(s, pos)
			break
		end
		out[#out + 1] = string.sub(s, pos, a - 1)
		out[#out + 1] = repl
		pos = b + 1
	end
	return table.concat(out)
end

-- Each pair = { exact substring to remove/replace, replacement }.
-- Keep the more specific entries before the generic ones.
local replacements = {
	{ "loadWithTimeout(url: string, timeout: number?): ...any", "loadWithTimeout(url, timeout)" },
	{ "local overriddenSettings: { [string]: any } = {}", "local overriddenSettings = {}" },
	{ "overrideSetting(category: string, name: string, value: any)", "overrideSetting(category, name, value)" },
	{ "getSetting(category: string, name: string): any", "getSetting(category, name)" },
	{ "(game :: any)", "(game)" },
	{ "(loadstring(fetchResult) :: any)", "(loadstring(fetchResult))" },
	{ "getIcon(name : string): {id: number, imageRectSize: Vector2, imageRectOffset: Vector2}", "getIcon(name)" },
	{ " :: string", "" },
	{ "getAssetUri(id: any): string", "getAssetUri(id)" },
	{ "Hide(notify: boolean?)", "Hide(notify)" },
	{ "updateSetting(category: string, setting: string, value: any)", "updateSetting(category, setting, value)" },
	{ "CreateLabel(LabelText : string, Icon: number, Color : Color3, IgnoreTheme : boolean)", "CreateLabel(LabelText, Icon, Color, IgnoreTheme)" },
	{ "setVisibility(visibility: boolean, notify: boolean?)", "setVisibility(visibility, notify)" },
	{ "SetVisibility(visibility: boolean)", "SetVisibility(visibility)" },
	{ "IsVisible(): boolean", "IsVisible()" },
	{ "Refresh(optionsTable: table)", "Refresh(optionsTable)" },

	-- Luau "if-expressions" and compound assignments crash Prometheus' AST
	-- visitor (it leaves a child expression nil). Rewrite them as vanilla Lua.
	{ "return if cloneref then cloneref(service) else service", "if cloneref then return cloneref(service) else return service end" },
	{ "return if success then result else nil", "if success then return result else return nil end" },
	{ "offset += getService('GuiService'):GetGuiInset()", "offset = offset + getService('GuiService'):GetGuiInset()" },
}

for _, r in ipairs(replacements) do
	src = literalReplace(src, r[1], r[2])
end

local o = assert(io.open(outPath, "wb"))
o:write(src)
o:close()
print("Stripped Luau type annotations -> " .. outPath)
