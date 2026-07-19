import pygame

class State:
    def __init__(self, state_machine, run_manager):
        self.state_machine = state_machine
        self.run_manager = run_manager

    def enter(self, **kwargs):
        """Called when transitioning into this state."""
        pass

    def exit(self):
        """Called when transitioning out of this state."""
        pass

    def handle_events(self, events):
        """Handles pygame events."""
        pass

    def update(self, dt):
        """Updates state logic. dt is in seconds."""
        pass

    def draw(self, surface):
        """Renders the state graphics to the surface."""
        pass


class StateMachine:
    def __init__(self):
        self.states = {}
        self.current_state = None

    def add_state(self, name, state):
        self.states[name] = state

    def change_state(self, name, **kwargs):
        """Cleanly transition from current state to the specified state."""
        if self.current_state:
            self.current_state.exit()
        
        self.current_state = self.states[name]
        self.current_state.enter(**kwargs)

    def handle_events(self, events):
        if self.current_state:
            self.current_state.handle_events(events)

    def update(self, dt):
        if self.current_state:
            self.current_state.update(dt)

    def draw(self, surface):
        if self.current_state:
            self.current_state.draw(surface)
