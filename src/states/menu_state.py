import sys
import pygame
from src import config
from src.engine.state_machine import State
from src.engine.ui import Button

class MenuState(State):
    def __init__(self, state_machine, run_manager):
        super().__init__(state_machine, run_manager)
        self.buttons = []
        self.title_font = config.get_font("typewriter", 64)
        self.subtitle_font = config.get_font("sans", 24)
        self.desc_font = config.get_font("sans", 18)
        
        self.blinking_timer = 0
        self.show_cursor = True
        
        # Setup buttons
        start_btn = Button(
            x=config.SCREEN_WIDTH // 2 - 120,
            y=400,
            width=240,
            height=50,
            text="Start Assignment",
            callback=self.start_game,
            color=(52, 152, 219) # Vibrant blue
        )
        exit_btn = Button(
            x=config.SCREEN_WIDTH // 2 - 120,
            y=480,
            width=240,
            height=50,
            text="Resign (Exit)",
            callback=self.exit_game,
            color=(231, 76, 60) # Vibrant red
        )
        self.buttons = [start_btn, exit_btn]

    def enter(self, **kwargs):
        pass

    def start_game(self):
        self.state_machine.change_state("blind_select")

    def exit_game(self):
        pygame.quit()
        sys.exit()

    def handle_events(self, events):
        # We need to map mouse coords
        mpos = pygame.mouse.get_pos()
        # Note: If letterboxing is active, coordinate mapping is handled in main.py, 
        # so self.handle_events receives mapped coordinates.
        
        for btn in self.buttons:
            btn.check_hover(mpos)
            
        for event in events:
            for btn in self.buttons:
                if btn.handle_event(event, mpos):
                    break

    def update(self, dt):
        self.blinking_timer += dt
        if self.blinking_timer >= 0.5:
            self.show_cursor = not self.show_cursor
            self.blinking_timer = 0.0
            
        for btn in self.buttons:
            btn.update(dt)

    def draw(self, surface):
        # Fill background (Desk)
        surface.fill(config.COLOR_DESK)
        
        # Draw elegant desk grid or paper texture
        # Draw paper in center
        paper_rect = pygame.Rect(config.SCREEN_WIDTH // 2 - 350, 50, 700, 620)
        pygame.draw.rect(surface, (20, 20, 25), paper_rect.inflate(8, 8), border_radius=8)
        pygame.draw.rect(surface, config.COLOR_PAPER, paper_rect, border_radius=6)
        
        # Draw header text on paper
        title_str = "The Editor's Desk"
        if self.show_cursor:
            title_str += "_"
        title_surf = self.title_font.render(title_str, True, config.COLOR_TEXT_DARK)
        title_rect = title_surf.get_rect(center=(config.SCREEN_WIDTH // 2, 160))
        surface.blit(title_surf, title_rect)
        
        subtitle_surf = self.subtitle_font.render("A Roguelike Word-Building Adventure", True, config.COLOR_TEXT_MUTED)
        subtitle_rect = subtitle_surf.get_rect(center=(config.SCREEN_WIDTH // 2, 230))
        surface.blit(subtitle_surf, subtitle_rect)
        
        # Description text
        desc_lines = [
            "Your desk is cluttered with manuscripts.",
            "Choose your words carefully to beat target Hype scores.",
            "Draft without scoring to find letter placements.",
            "Purchase Style Guides, passive Tropes, and keyboard enhancements",
            "to survive 8 Chapters and edit the most chaotic Authors."
        ]
        
        y_off = 280
        for line in desc_lines:
            line_surf = self.desc_font.render(line, True, config.COLOR_TEXT_DARK)
            line_rect = line_surf.get_rect(center=(config.SCREEN_WIDTH // 2, y_off))
            surface.blit(line_surf, line_rect)
            y_off += 22

        # Draw buttons (which render relative to the screen coordinates)
        for btn in self.buttons:
            btn.draw(surface)
