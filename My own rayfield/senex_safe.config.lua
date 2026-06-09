-- senex_safe.config.lua
-- The MOST Luau-executor-compatible Prometheus config. It drops every step that
-- relies on emulating Lua 5.1 semantics (Vmify) or probing the runtime
-- (AntiTamper / AntiDeobfuscator) - those break Rayfield-style UIs on Luau.
--
-- What it KEEPS is the protection that actually matters and runs as plain Lua:
--   * EncryptStrings - hides every string literal (URLs, asset ids, UI text).
--   * ConstantArray  - moves those strings into a shuffled/rotated array.
--   * WrapInFunction - wraps the whole thing in an opaque closure.
-- Combined with the default variable renaming, the source is unreadable while
-- still executing natively. Used by:  .\build.ps1 -Safe
--
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
            Name = "ConstantArray",
            Settings = {
                Treshold = 1,
                StringsOnly = true,
                Shuffle = true,
                Rotate = true,
                LocalWrapperTreshold = 0,
            },
        },
        {
            Name = "WrapInFunction",
            Settings = {},
        },
    },
}
