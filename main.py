import pygame
import sys
from src import config
from src.engine import sound_manager
from src.engine.state_machine import StateMachine
from src.engine.ui import get_scale_rect, window_to_game_coords
from src.gameplay.run_manager import RunManager

# States
from src.states.menu_state import MenuState
from src.states.blind_select_state import BlindSelectState
from src.states.game_state import GameState
from src.states.scoring_state import ScoringState
from src.states.shop_state import ShopState
from src.states.game_over_state import GameOverState

def main():
    # Initialize pygame
    pygame.init()
    pygame.mixer.init()
    
    # Setup window (resizable)
    window_w = config.SCREEN_WIDTH
    window_h = config.SCREEN_HEIGHT
    window = pygame.display.set_mode((window_w, window_h), pygame.RESIZABLE | pygame.DOUBLEBUF | pygame.HWSURFACE)
    pygame.display.set_caption("The Editor's Desk")
    
    # Setup clock
    clock = pygame.time.Clock()
    
    # Initialize sound manager
    sound_manager.init()
    
    # Set up virtual game surface (all drawing calculations happen here)
    game_surface = pygame.Surface((config.SCREEN_WIDTH, config.SCREEN_HEIGHT))
    
    # Scaling geometry
    scale_rect = get_scale_rect(window_w, window_h)
    
    # Initialize Run Manager
    run_manager = RunManager()
    
    # Initialize State Machine
    state_machine = StateMachine()
    
    # Add states
    state_machine.add_state("menu", MenuState(state_machine, run_manager))
    state_machine.add_state("blind_select", BlindSelectState(state_machine, run_manager))
    state_machine.add_state("game", GameState(state_machine, run_manager))
    state_machine.add_state("scoring", ScoringState(state_machine, run_manager))
    state_machine.add_state("shop", ShopState(state_machine, run_manager))
    state_machine.add_state("game_over", GameOverState(state_machine, run_manager))
    
    # Set starting state
    state_machine.change_state("menu")
    
    # Game Loop
    running = True
    while running:
        # Delta Time (in seconds)
        dt = clock.tick(config.FPS) / 1000.0
        # Prevent huge dt spikes when dragging window
        dt = min(0.1, dt)
        
        # Events handling
        raw_events = pygame.event.get()
        mapped_events = []
        
        for event in raw_events:
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.VIDEORESIZE:
                window_w, window_h = event.w, event.h
                window = pygame.display.set_mode((window_w, window_h), pygame.RESIZABLE | pygame.DOUBLEBUF | pygame.HWSURFACE)
                scale_rect = get_scale_rect(window_w, window_h)
            else:
                # Coordinate remapping for mouse events
                if hasattr(event, "pos"):
                    event_dict = event.__dict__.copy()
                    event_dict["pos"] = window_to_game_coords(event.pos, scale_rect)
                    event = pygame.event.Event(event.type, event_dict)
                mapped_events.append(event)
                
        # Update active state logic
        state_machine.handle_events(mapped_events)
        state_machine.update(dt)
        
        # Draw game frame
        game_surface.fill(config.COLOR_DESK)
        state_machine.draw(game_surface)
        
        # Draw background window borders (letterbox fill)
        window.fill((15, 16, 22))
        
        # Smoothly scale the game surface to fit the window aspect-ratio
        scaled_game = pygame.transform.smoothscale(game_surface, (scale_rect.w, scale_rect.h))
        window.blit(scaled_game, (scale_rect.x, scale_rect.y))
        
        pygame.display.flip()

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()
