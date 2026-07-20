local config = {}

-- Screen settings
config.SCREEN_WIDTH = 1280
config.SCREEN_HEIGHT = 720
config.FPS = 60

-- Palette - HSL-tailored colors (0-1 range for love.graphics)
config.COLOR_DESK = {28/255, 30/255, 38/255}
config.COLOR_PANEL = {39/255, 42/255, 54/255}
config.COLOR_PAPER = {248/255, 245/255, 237/255}
config.COLOR_TEXT_DARK = {44/255, 44/255, 44/255}
config.COLOR_TEXT_LIGHT = {240/255, 240/255, 240/255}
config.COLOR_TEXT_MUTED = {120/255, 125/255, 140/255}

-- Color Clues (Wordle)
config.COLOR_CLUE_GREEN = {46/255, 180/255, 110/255}
config.COLOR_CLUE_YELLOW = {220/255, 165/255, 30/255}
config.COLOR_CLUE_GREY = {140/255, 145/255, 155/255}
config.COLOR_CLUE_REDACTED = {130/255, 85/255, 45/255}
config.COLOR_CLUE_EMPTY = {210/255, 205/255, 195/255}

-- Accent Colors
config.COLOR_ACCENT = {230/255, 90/255, 90/255}
config.COLOR_ROYALTIES = {50/255, 200/255, 140/255}
config.COLOR_HIGHLIGHTER = {250/255, 230/255, 50/255}

-- Fonts Initialization helper
local fonts_cache = {}

function config.get_font(name, size)
    local cache_key = name .. "_" .. size
    if fonts_cache[cache_key] then
        return fonts_cache[cache_key]
    end

    local font
    if name == "typewriter" then
        local font_path = "assets/fonts/SpecialElite.ttf"
        if love.filesystem.getInfo(font_path) then
            font = love.graphics.newFont(font_path, size)
        else
            font = love.graphics.newFont(size)
        end
    else -- "sans"
        local font_path = "assets/fonts/Roboto-Regular.ttf"
        if love.filesystem.getInfo(font_path) then
            font = love.graphics.newFont(font_path, size)
        else
            font = love.graphics.newFont(size)
        end
    end
    
    fonts_cache[cache_key] = font
    return font
end

function config.get_font_bold(size)
    local cache_key = "sans_bold_" .. size
    if fonts_cache[cache_key] then
        return fonts_cache[cache_key]
    end

    local font
    local font_path = "assets/fonts/Roboto-Bold.ttf"
    if love.filesystem.getInfo(font_path) then
        font = love.graphics.newFont(font_path, size)
    else
        font = love.graphics.newFont(size)
    end

    fonts_cache[cache_key] = font
    return font
end

config.sounds = nil

config.images = {}
function config.load_images()
    local image_files = {
        bg_desk = "assets/bg_desk.png",
        bg_sidebar = "assets/bg_sidebar.png",
        fx_stamp_impact = "assets/fx_stamp_impact.png",
        overlay_paper = "assets/overlay_paper.png",
        stain_ink = "assets/stain_ink_1.png",
        tile_empty = "assets/tile_empty.png",
        tile_green = "assets/tile_green.png",
        tile_grey = "assets/tile_grey.png",
        tile_yellow = "assets/tile_yellow.png"
    }
    for name, path in pairs(image_files) do
        if love.filesystem.getInfo(path) then
            config.images[name] = love.graphics.newImage(path)
        end
    end
end

return config
