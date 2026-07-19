class EventBus:
    def __init__(self):
        self._listeners = {}

    def subscribe(self, event_type, callback, priority=0):
        """
        Subscribe a callback to an event.
        Higher priority callbacks will run first.
        """
        if event_type not in self._listeners:
            self._listeners[event_type] = []
        self._listeners[event_type].append((priority, callback))
        # Sort in descending order of priority
        self._listeners[event_type].sort(key=lambda x: x[0], reverse=True)

    def unsubscribe(self, event_type, callback):
        """Unsubscribe a callback from an event."""
        if event_type in self._listeners:
            self._listeners[event_type] = [
                item for item in self._listeners[event_type] if item[1] != callback
            ]

    def publish(self, event_type, *args, **kwargs):
        """Publish an event, calling all registered callbacks in order of priority."""
        if event_type in self._listeners:
            # Create a copy of the list in case listeners mutate subscriptions during callback execution
            for _, callback in list(self._listeners[event_type]):
                callback(*args, **kwargs)

    def clear(self):
        """Clear all registered event listeners."""
        self._listeners.clear()


# Global Event Bus instance
bus = EventBus()
