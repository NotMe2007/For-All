-- senex_strings.config.lua
-- EncryptStrings only (plus a closure wrap). This hides every string literal -
-- URLs, asset ids, UI text - while running as plain Lua. It drops ConstantArray,
-- which is the step that corrupts this library on Luau executors.
-- NOTE: loaded in a sandbox with no globals - must be a plain table literal.
return {
    LuaVersion = "LuaU",
    VarNamePrefix = "",
    NameGenerator = "MangledShuffled",
    PrettyPrint = false,
    Seed = 0,
    Steps = {
        {
            Name = "EncryptStrings",
            Settings = {},
        },
        {
            Name = "WrapInFunction",
            Settings = {},
        },
    },
}
