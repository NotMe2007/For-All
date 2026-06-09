-- senex_safe.config.lua
-- A Roblox-safe Prometheus config: the Medium pipeline MINUS the two steps that
-- most often break scripts on executors (AntiDeobfuscator + AntiTamper).
-- It still encrypts strings, runs the code through the VM, builds a constant
-- array and obscures numbers - strong protection that is much more likely to
-- actually run in-game. Used by:  .\build.ps1 -Safe
--
-- NOTE: this file is loaded in a sandbox with no globals, so it must be a plain
-- table literal with no function calls.
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
            Name = "Vmify",
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
            Name = "NumbersToExpressions",
            Settings = {},
        },
        {
            Name = "WrapInFunction",
            Settings = {},
        },
    },
}
