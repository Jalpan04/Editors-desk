local config = require("src/config")

local ui = {}

function ui.get_scale_rect(window_w, window_h, target_aspect)
    target_aspect = target_aspect or (16 / 9)
    local window_aspect = window_w / window_h
    local x, y, w, h
    if window_aspect > target_aspect then
        h = window_h
        w = math.floor(h * target_aspect)
        x = math.floor((window_w - w) / 2)
        y = 0
    else
        w = window_w
        h = math.floor(w / target_aspect)
        x = 0
        y = math.floor((window_h - h) / 2)
    end
    return {x = x, y = y, w = w, h = h}
end

function ui.window_to_game_coords(win_x, win_y, rect)
    local rx = win_x - rect.x
    local ry = win_y - rect.y
    local rw = math.max(1, rect.w)
    local rh = math.max(1, rect.h)
    local game_x = math.floor(rx * config.SCREEN_WIDTH / rw)
    local game_y = math.floor(ry * config.SCREEN_HEIGHT / rh)
    return game_x, game_y
end

local ScreenShake = {}
ScreenShake.__index = ScreenShake

function ScreenShake.new()
    local self = setmetatable({}, ScreenShake)
    self.intensity = 0
    self.duration = 0.0
    self.timer = 0.0
    return self
end

function ScreenShake:trigger(intensity, duration)
    self.intensity = intensity
    self.duration = duration
    self.timer = duration
end

function ScreenShake:update(dt)
    if self.timer > 0 then
        self.timer = self.timer - dt
        if self.timer <= 0 then
            self.intensity = 0
            self.timer = 0.0
        end
    end
end

function ScreenShake:get_offset()
    if self.timer > 0 then
        local pct = self.timer / self.duration
        local current_int = self.intensity * pct
        if current_int >= 1 then
            local dx = love.math.random(-math.floor(current_int), math.floor(current_int))
            local dy = love.math.random(-math.floor(current_int), math.floor(current_int))
            return dx, dy
        end
    end
    return 0, 0
end

ui.ScreenShake = ScreenShake

local Particle = {}
Particle.__index = Particle

function Particle.new(x, y, color, size)
    local self = setmetatable({}, Particle)
    self.x = x
    self.y = y
    self.color = color
    self.size = size or love.math.random(3, 6)
    self.vx = love.math.random(-150, 150)
    self.vy = love.math.random(-300, -50)
    self.gravity = 500
    self.life = love.math.random() * 0.5 + 0.5
    self.max_life = self.life
    return self
end

function Particle:update(dt)
    self.vy = self.vy + self.gravity * dt
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    self.life = self.life - dt
end

function Particle:draw()
    if self.life > 0 then
        local alpha = self.life / self.max_life
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], alpha)
        love.graphics.circle("fill", self.x, self.y, self.size)
    end
end

local ParticleSystem = {}
ParticleSystem.__index = ParticleSystem

function ParticleSystem.new()
    local self = setmetatable({}, ParticleSystem)
    self.particles = {}
    return self
end

function ParticleSystem:spawn(x, y, color, count)
    count = count or 10
    for i = 1, count do
        table.insert(self.particles, Particle.new(x, y, color))
    end
end

function ParticleSystem:update(dt)
    local active = {}
    for _, p in ipairs(self.particles) do
        p:update(dt)
        if p.life > 0 then
            table.insert(active, p)
        end
    end
    self.particles = active
end

function ParticleSystem:draw()
    for _, p in ipairs(self.particles) do
        p:draw()
    end
end

ui.ParticleSystem = ParticleSystem

local Button = {}
Button.__index = Button

function Button.new(x, y, width, height, text, callback, color, text_color, font_type, font_size)
    local self = setmetatable({}, Button)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.text = text
    self.callback = callback
    
    self.base_color = color or config.COLOR_PANEL
    self.hover_color = {}
    for i = 1, 3 do
        self.hover_color[i] = math.min(1.0, self.base_color[i] + 0.1)
    end
    self.text_color = text_color or config.COLOR_TEXT_LIGHT
    
    self.font_type = font_type or "sans"
    self.font_size = font_size or 20
    self.font = config.get_font(self.font_type, self.font_size)
    
    self.is_hovered = false
    self.hover_progress = 0.0
    return self
end

function Button:check_hover(mouse_x, mouse_y)
    self.is_hovered = (mouse_x >= self.x and mouse_x <= self.x + self.width and
                       mouse_y >= self.y and mouse_y <= self.y + self.height)
end

function Button:handle_event(event_type, mouse_x, mouse_y, button)
    if event_type == "mousepressed" and button == 1 then
        if mouse_x >= self.x and mouse_x <= self.x + self.width and
           mouse_y >= self.y and mouse_y <= self.y + self.height then
            if config.sounds then
                config.sounds:play("buy")
            end
            self.callback()
            return true
        end
    end
    return false
end

function Button:update(dt)
    if self.is_hovered then
        self.hover_progress = math.min(1.0, self.hover_progress + dt * 8)
    else
        self.hover_progress = math.max(0.0, self.hover_progress - dt * 8)
    end
end

function Button:draw()
    local r = self.base_color[1] + (self.hover_color[1] - self.base_color[1]) * self.hover_progress
    local g = self.base_color[2] + (self.hover_color[2] - self.base_color[2]) * self.hover_progress
    local b = self.base_color[3] + (self.hover_color[3] - self.base_color[3]) * self.hover_progress
    
    love.graphics.setColor(15/255, 15/255, 20/255, 1.0)
    love.graphics.rectangle("fill", self.x, self.y + 4, self.width, self.height, 6, 6)
    
    local offset_y = math.floor(self.hover_progress * 2)
    love.graphics.setColor(r, g, b, 1.0)
    love.graphics.rectangle("fill", self.x, self.y - offset_y, self.width, self.height, 6, 6)
    
    local border_color = {}
    if self.is_hovered then
        border_color = config.COLOR_HIGHLIGHTER
    else
        for i = 1, 3 do
            border_color[i] = math.min(1.0, self.base_color[i] + 0.15)
        end
    end
    love.graphics.setColor(border_color[1], border_color[2], border_color[3], 1.0)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", self.x, self.y - offset_y, self.width, self.height, 6, 6)
    
    love.graphics.setColor(self.text_color[1], self.text_color[2], self.text_color[3], 1.0)
    love.graphics.setFont(self.font)
    
    local text_w = self.font:getWidth(self.text)
    local text_h = self.font:getHeight()
    local max_w = self.width - 16
    local scale = 1.0
    if text_w > max_w then
        scale = max_w / text_w
    end
    
    local cx = self.x + self.width / 2
    local cy = self.y - offset_y + self.height / 2
    local visual_offset_y = 1
    
    love.graphics.print(self.text, cx, cy - visual_offset_y, 0, scale, scale, text_w / 2, text_h / 2)
end

ui.Button = Button

return ui
