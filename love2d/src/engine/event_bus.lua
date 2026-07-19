local EventBus = {}
EventBus.__index = EventBus

function EventBus.new()
    local self = setmetatable({}, EventBus)
    self._listeners = {}
    return self
end

function EventBus:subscribe(event_type, callback, priority)
    priority = priority or 0
    if not self._listeners[event_type] then
        self._listeners[event_type] = {}
    end
    table.insert(self._listeners[event_type], {callback = callback, priority = priority})
    -- Sort in descending order of priority
    table.sort(self._listeners[event_type], function(a, b)
        return a.priority > b.priority
    end)
end

function EventBus:unsubscribe(event_type, callback)
    if not self._listeners[event_type] then return end
    local newList = {}
    for _, item in ipairs(self._listeners[event_type]) do
        if item.callback ~= callback then
            table.insert(newList, item)
        end
    end
    self._listeners[event_type] = newList
end

function EventBus:publish(event_type, ...)
    if not self._listeners[event_type] then return end
    local listCopy = {}
    for _, item in ipairs(self._listeners[event_type]) do
        table.insert(listCopy, item.callback)
    end
    
    for _, callback in ipairs(listCopy) do
        callback(...)
    end
end

function EventBus:clear()
    self._listeners = {}
end

local bus = EventBus.new()

return {
    EventBus = EventBus,
    bus = bus
}
