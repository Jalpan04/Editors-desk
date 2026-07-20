local config = require("src/config")
local sound_manager = require("src/engine/sound_manager")
local StateMachine = require("src/engine/state_machine").StateMachine
local ui = require("src/engine/ui")
local RunManager = require("src/gameplay/run_manager")

local MenuState = require("src/states/menu_state")
local AssignmentSelectState = require("src/states/assignment_select_state")
local GameState = require("src/states/game_state")
local ScoringState = require("src/states/scoring_state")
local ShopState = require("src/states/shop_state")
local GameOverState = require("src/states/game_over_state")

local canvas
local run_manager
local state_machine
local scale_rect

function love.load()
    -- Enable linear filtering for smooth scaling
    love.graphics.setDefaultFilter("linear", "linear")
    
    -- Setup virtual drawing canvas (16:9 ratio)
    canvas = love.graphics.newCanvas(config.SCREEN_WIDTH, config.SCREEN_HEIGHT)
    
    -- Initialize sound manager
    sound_manager.init("assets/audio")
    
    -- Initialize Run Manager
    run_manager = RunManager.new("data")
    
    -- Initialize State Machine
    state_machine = StateMachine.new()
    state_machine:add_state("menu", MenuState.new(state_machine, run_manager))
    state_machine:add_state("assignment_select", AssignmentSelectState.new(state_machine, run_manager))
    state_machine:add_state("game", GameState.new(state_machine, run_manager))
    state_machine:add_state("scoring", ScoringState.new(state_machine, run_manager))
    state_machine:add_state("shop", ShopState.new(state_machine, run_manager))
    state_machine:add_state("game_over", GameOverState.new(state_machine, run_manager))
    
    state_machine:change_state("menu")
    
    -- Trigger initial scale calculation
    love.resize(love.graphics.getWidth(), love.graphics.getHeight())
end

function love.resize(w, h)
    scale_rect = ui.get_scale_rect(w, h, 16 / 9)
end

function love.update(dt)
    -- Cap dt to prevent physics/animation spikes
    dt = math.min(0.1, dt)
    
    -- Map mouse coordinates to virtual resolution (1280x720)
    local mx, my = love.mouse.getPosition()
    local rx, ry = ui.window_to_game_coords(mx, my, scale_rect)
    config.mx = rx
    config.my = ry
    
    state_machine:update(dt)
end

function love.draw()
    -- Render game logic to virtual canvas
    love.graphics.setCanvas(canvas)
    love.graphics.clear(config.COLOR_DESK)
    state_machine:draw()
    love.graphics.setCanvas()
    
    -- Render letterbox padding (dark background)
    love.graphics.clear(15/255, 16/255, 22/255)
    
    -- Blit scaled virtual canvas to active screen
    love.graphics.setColor(1.0, 1.0, 1.0, 1.0)
    local sx = scale_rect.w / config.SCREEN_WIDTH
    local sy = scale_rect.h / config.SCREEN_HEIGHT
    love.graphics.draw(canvas, scale_rect.x, scale_rect.y, 0, sx, sy)
end

function love.keypressed(key, scancode, isrepeat)
    state_machine:keypressed(key, scancode, isrepeat)
end

function love.textinput(text)
    state_machine:textinput(text)
end

function love.mousepressed(x, y, button, istouch, presses)
    state_machine:mousepressed(x, y, button, istouch, presses)
end
