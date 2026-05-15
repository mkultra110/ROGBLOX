--[[
    ThemeManager addon.

    Bundle of named theme presets. Apply() swaps the UI library's THEME
    table values and pushes accent updates to any active window. Full
    re-tint of every existing instance happens via UI's own
    UpdateColorsUsingRegistry() pipeline once that's wired (see todo
    for UI v3); for now Apply lights up new components in the new
    colors and updates the accent strip live on existing windows.
]]

local M = {}

M.Themes = {
    Default = {
        Background   = Color3.fromRGB(16,  16,  22),
        Panel        = Color3.fromRGB(22,  22,  30),
        Panel2       = Color3.fromRGB(28,  28,  38),
        Element      = Color3.fromRGB(36,  36,  48),
        ElementHover = Color3.fromRGB(48,  48,  62),
        Accent       = Color3.fromRGB(140, 100, 255),
        AccentDim    = Color3.fromRGB( 90,  60, 180),
        AccentSoft   = Color3.fromRGB(180, 150, 255),
        Text         = Color3.fromRGB(235, 235, 245),
        SubText      = Color3.fromRGB(150, 150, 165),
        DimText      = Color3.fromRGB(110, 110, 125),
        Stroke       = Color3.fromRGB(50,   50,  62),
        Good         = Color3.fromRGB( 90, 220, 140),
        Warn         = Color3.fromRGB(255, 200,  80),
        Bad          = Color3.fromRGB(235,  90, 100),
    },
    Ocean = {
        Background   = Color3.fromRGB(8,   16,  28),
        Panel        = Color3.fromRGB(14,  24,  40),
        Panel2       = Color3.fromRGB(20,  32,  54),
        Element      = Color3.fromRGB(26,  42,  68),
        ElementHover = Color3.fromRGB(36,  54,  86),
        Accent       = Color3.fromRGB(74,  202, 255),
        AccentDim    = Color3.fromRGB(40,  130, 200),
        AccentSoft   = Color3.fromRGB(150, 220, 255),
        Text         = Color3.fromRGB(232, 240, 250),
        SubText      = Color3.fromRGB(140, 160, 185),
        DimText      = Color3.fromRGB(100, 120, 145),
        Stroke       = Color3.fromRGB(40,  60,  90),
        Good         = Color3.fromRGB(110, 220, 180),
        Warn         = Color3.fromRGB(255, 200,  80),
        Bad          = Color3.fromRGB(255,  90, 130),
    },
    Amber = {
        Background   = Color3.fromRGB(20,  16,  10),
        Panel        = Color3.fromRGB(28,  22,  14),
        Panel2       = Color3.fromRGB(36,  28,  16),
        Element      = Color3.fromRGB(44,  34,  20),
        ElementHover = Color3.fromRGB(54,  42,  24),
        Accent       = Color3.fromRGB(255, 170,  60),
        AccentDim    = Color3.fromRGB(200, 120,  30),
        AccentSoft   = Color3.fromRGB(255, 220, 130),
        Text         = Color3.fromRGB(248, 240, 220),
        SubText      = Color3.fromRGB(180, 160, 130),
        DimText      = Color3.fromRGB(120, 105,  80),
        Stroke       = Color3.fromRGB(80,   60,  35),
        Good         = Color3.fromRGB(180, 220, 130),
        Warn         = Color3.fromRGB(255, 200,  80),
        Bad          = Color3.fromRGB(255, 100,  90),
    },
    Mint = {
        Background   = Color3.fromRGB(10,  22,  18),
        Panel        = Color3.fromRGB(16,  30,  26),
        Panel2       = Color3.fromRGB(22,  40,  34),
        Element      = Color3.fromRGB(30,  50,  42),
        ElementHover = Color3.fromRGB(40,  64,  54),
        Accent       = Color3.fromRGB(80,  240, 180),
        AccentDim    = Color3.fromRGB(40,  170, 120),
        AccentSoft   = Color3.fromRGB(160, 250, 215),
        Text         = Color3.fromRGB(230, 245, 240),
        SubText      = Color3.fromRGB(140, 175, 165),
        DimText      = Color3.fromRGB(100, 130, 120),
        Stroke       = Color3.fromRGB(40,  70,  60),
        Good         = Color3.fromRGB(100, 240, 170),
        Warn         = Color3.fromRGB(255, 200,  80),
        Bad          = Color3.fromRGB(255,  90, 120),
    },
    Rose = {
        Background   = Color3.fromRGB(22,  12,  18),
        Panel        = Color3.fromRGB(32,  18,  26),
        Panel2       = Color3.fromRGB(42,  24,  34),
        Element      = Color3.fromRGB(52,  30,  42),
        ElementHover = Color3.fromRGB(64,  38,  52),
        Accent       = Color3.fromRGB(255, 110, 170),
        AccentDim    = Color3.fromRGB(200, 70,  130),
        AccentSoft   = Color3.fromRGB(255, 170, 210),
        Text         = Color3.fromRGB(248, 232, 240),
        SubText      = Color3.fromRGB(190, 150, 175),
        DimText      = Color3.fromRGB(130, 100, 120),
        Stroke       = Color3.fromRGB(85,  50,  70),
        Good         = Color3.fromRGB(140, 230, 170),
        Warn         = Color3.fromRGB(255, 210,  90),
        Bad          = Color3.fromRGB(255, 100, 120),
    },
    LightMode = {
        Background   = Color3.fromRGB(242, 242, 248),
        Panel        = Color3.fromRGB(230, 230, 238),
        Panel2       = Color3.fromRGB(220, 220, 232),
        Element      = Color3.fromRGB(208, 208, 222),
        ElementHover = Color3.fromRGB(196, 196, 212),
        Accent       = Color3.fromRGB(110,  85, 220),
        AccentDim    = Color3.fromRGB( 80,  60, 180),
        AccentSoft   = Color3.fromRGB(170, 145, 255),
        Text         = Color3.fromRGB( 30,  30,  40),
        SubText      = Color3.fromRGB( 90,  90, 110),
        DimText      = Color3.fromRGB(140, 140, 160),
        Stroke       = Color3.fromRGB(180, 180, 195),
        Good         = Color3.fromRGB( 60, 180, 110),
        Warn         = Color3.fromRGB(220, 160,  40),
        Bad          = Color3.fromRGB(220,  80,  80),
    },
    Cyber = {
        Background   = Color3.fromRGB( 6,  10,  22),
        Panel        = Color3.fromRGB(12,  18,  36),
        Panel2       = Color3.fromRGB(18,  26,  52),
        Element      = Color3.fromRGB(26,  36,  68),
        ElementHover = Color3.fromRGB(36,  48,  88),
        Accent       = Color3.fromRGB(255,  60, 180),
        AccentDim    = Color3.fromRGB(180,  30, 130),
        AccentSoft   = Color3.fromRGB(255, 130, 210),
        Text         = Color3.fromRGB(220, 240, 255),
        SubText      = Color3.fromRGB(140, 170, 200),
        DimText      = Color3.fromRGB( 90, 120, 150),
        Stroke       = Color3.fromRGB( 50,  72, 110),
        Good         = Color3.fromRGB( 60, 230, 200),
        Warn         = Color3.fromRGB(255, 230,  60),
        Bad          = Color3.fromRGB(255,  70, 120),
    },
    Sunset = {
        Background   = Color3.fromRGB(22,  12,   8),
        Panel        = Color3.fromRGB(32,  18,  12),
        Panel2       = Color3.fromRGB(42,  24,  16),
        Element      = Color3.fromRGB(54,  30,  20),
        ElementHover = Color3.fromRGB(68,  38,  24),
        Accent       = Color3.fromRGB(255, 120,  60),
        AccentDim    = Color3.fromRGB(200,  80,  30),
        AccentSoft   = Color3.fromRGB(255, 180, 130),
        Text         = Color3.fromRGB(250, 235, 220),
        SubText      = Color3.fromRGB(190, 160, 140),
        DimText      = Color3.fromRGB(130, 105,  85),
        Stroke       = Color3.fromRGB( 85,  50,  35),
        Good         = Color3.fromRGB(190, 220, 130),
        Warn         = Color3.fromRGB(255, 210,  80),
        Bad          = Color3.fromRGB(255,  90,  90),
    },
    Forest = {
        Background   = Color3.fromRGB( 8,  20,  14),
        Panel        = Color3.fromRGB(14,  28,  20),
        Panel2       = Color3.fromRGB(20,  36,  28),
        Element      = Color3.fromRGB(28,  46,  34),
        ElementHover = Color3.fromRGB(38,  58,  44),
        Accent       = Color3.fromRGB(120, 200, 100),
        AccentDim    = Color3.fromRGB( 80, 150,  60),
        AccentSoft   = Color3.fromRGB(180, 230, 150),
        Text         = Color3.fromRGB(230, 245, 230),
        SubText      = Color3.fromRGB(150, 175, 150),
        DimText      = Color3.fromRGB(105, 130, 105),
        Stroke       = Color3.fromRGB( 45,  68,  50),
        Good         = Color3.fromRGB(120, 220, 140),
        Warn         = Color3.fromRGB(255, 200,  80),
        Bad          = Color3.fromRGB(255, 110, 110),
    },
    Mono = {
        -- Pure monochrome - tasteful, neutral. The single accent is
        -- desaturated so it works with any user color preference.
        Background   = Color3.fromRGB(14,  14,  16),
        Panel        = Color3.fromRGB(22,  22,  25),
        Panel2       = Color3.fromRGB(30,  30,  34),
        Element      = Color3.fromRGB(40,  40,  44),
        ElementHover = Color3.fromRGB(52,  52,  58),
        Accent       = Color3.fromRGB(220, 220, 230),
        AccentDim    = Color3.fromRGB(160, 160, 170),
        AccentSoft   = Color3.fromRGB(245, 245, 250),
        Text         = Color3.fromRGB(245, 245, 250),
        SubText      = Color3.fromRGB(170, 170, 180),
        DimText      = Color3.fromRGB(110, 110, 120),
        Stroke       = Color3.fromRGB( 60,  60,  68),
        Good         = Color3.fromRGB(200, 200, 210),
        Warn         = Color3.fromRGB(230, 230, 200),
        Bad          = Color3.fromRGB(230, 180, 180),
    },
}

function M.Names()
    local out = {}
    for k in pairs(M.Themes) do table.insert(out, k) end
    table.sort(out)
    return out
end

function M.Apply(UI, Window, themeName)
    local t = M.Themes[themeName]
    if not (t and UI and UI.Theme) then return false end
    for k, v in pairs(t) do
        UI.Theme[k] = v
    end
    if Window and Window.SetAccent then Window:SetAccent(t.Accent) end
    -- If UI exposes a registry-based recolor in the future, call it
    -- here too. For now, accent updates live on existing window; new
    -- components inherit the swapped THEME table.
    if UI.UpdateColorsUsingRegistry then pcall(UI.UpdateColorsUsingRegistry, UI) end
    return true
end

return M
