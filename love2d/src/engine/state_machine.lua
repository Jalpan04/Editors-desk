local State = {}
State.__index = State

function State.new(state_machine, run_manager)
    local self = setmetatable({}, State)
    self.state_machine = state_machine
    self.run_manager = run_manager
    return self
end

function State:enter(kwargs) end
function State:exit() end
function State:update(dt) end
function State:draw() end
function State:keypressed(key, scancode, isrepeat) end
function State:textinput(text) end
function State:mousepressed(x, y, button, istouch, presses) end

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new()
    local self = setmetatable({}, StateMachine)
    self.states = {}
    self.current_state = nil
    return self
end

function StateMachine:add_state(name, state)
    self.states[name] = state
end

function StateMachine:change_state(name, kwargs)
    if self.current_state then
        self.current_state:exit()
    end
    self.current_state = self.states[name]
    if self.current_state then
        self.current_state:enter(kwargs or {})
    end
end

function StateMachine:update(dt)
    if self.current_state then
        self.current_state:update(dt)
    end
end

function StateMachine:draw()
    if self.current_state then
        self.current_state:draw()
    end
end

function StateMachine:keypressed(key, scancode, isrepeat)
    if self.current_state then
        self.current_state:keypressed(key, scancode, isrepeat)
    end
end

function StateMachine:textinput(text)
    if self.current_state then
        self.current_state:textinput(text)
    end
end

function StateMachine:mousepressed(x, y, button, istouch, presses)
    if self.current_state then
        self.current_state:mousepressed(x, y, button, istouch, presses)
    end
end

return {
    State = State,
    StateMachine = StateMachine
}
