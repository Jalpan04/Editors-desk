import pygame
from src import config
from src.engine.state_machine import State
from src.engine.ui import Button
from src.gameplay.run_manager import RunManager

class GameOverState(State):
    def __init__(self, state_machine, run_manager):
        super().__init__(state_machine, run_manager)
        self.buttons = []
        self.title_font = config.get_font("typewriter", 56)
        self.lbl_font = config.get_font("sans", 24)
        self.desc_font = config.get_font("sans", 18)
        self.stat_font = config.get_font("sans", 22)
        
        # Result type: "fired" (lose) or "published" (win)
        self.result = "fired"

    def enter(self, **kwargs):
        self.result = kwargs.get("result", "fired")
        self.buttons.clear()
        
        # Action buttons
        self.buttons.append(Button(
            x=config.SCREEN_WIDTH // 2 - 220,
            y=460,
            width=200,
            height=50,
            text="Try Again",
            callback=self.retry_run,
            color=(46, 180, 110) # Green
        ))
        self.buttons.append(Button(
            x=config.SCREEN_WIDTH // 2 + 20,
            y=460,
            width=200,
            height=50,
            text="Main Menu",
            callback=self.goto_menu,
            color=(52, 152, 219) # Blue
        ))

    def retry_run(self):
        # Reset run manager to brand new state
        # (Re-instantiating RunManager is the easiest way to reset the whole state)
        new_rm = RunManager()
        self.state_machine.run_manager = new_rm
        
        # Re-link states to new run manager
        for s in self.state_machine.states.values():
            s.run_manager = new_rm
            
        self.state_machine.change_state("blind_select")

    def goto_menu(self):
        self.state_machine.change_state("menu")

    def handle_events(self, events):
        mpos = pygame.mouse.get_pos()
        for btn in self.buttons:
            btn.check_hover(mpos)
            
        for event in events:
            for btn in self.buttons:
                if btn.handle_event(event, mpos):
                    break

    def update(self, dt):
        for btn in self.buttons:
            btn.update(dt)

    def draw(self, surface):
        surface.fill(config.COLOR_DESK)
        
        # Draw paper background
        paper_rect = pygame.Rect(config.SCREEN_WIDTH // 2 - 320, 60, 640, 600)
        pygame.draw.rect(surface, (15, 15, 20), paper_rect.inflate(8, 8), border_radius=8)
        pygame.draw.rect(surface, config.COLOR_PAPER, paper_rect, border_radius=6)
        
        # Draw stamp header
        if self.result == "published":
            title_text = "PUBLISHED!"
            accent_col = config.COLOR_CLUE_GREEN
            desc_text = "Congratulations! Your manuscript has become a national bestseller."
        else:
            title_text = "YOU ARE FIRED"
            accent_col = config.COLOR_ACCENT
            desc_text = "You ran out of submissions before meeting the Hype requirements."
            
        title_surf = self.title_font.render(title_text, True, accent_col)
        title_rect = title_surf.get_rect(center=(config.SCREEN_WIDTH // 2, 140))
        surface.blit(title_surf, title_rect)
        
        # Subtitle
        desc_surf = self.desc_font.render(desc_text, True, config.COLOR_TEXT_DARK)
        desc_rect = desc_surf.get_rect(center=(config.SCREEN_WIDTH // 2, 210))
        surface.blit(desc_surf, desc_rect)
        
        pygame.draw.line(surface, config.COLOR_TEXT_MUTED, (config.SCREEN_WIDTH // 2 - 250, 240), (config.SCREEN_WIDTH // 2 + 250, 240), 1)
        
        # Draw stats list
        stats = [
            f"Chapters Completed: {self.run_manager.chapter - 1} / 8",
            f"Final Royalties Earned: ${self.run_manager.royalties}",
            f"Active Tropes Equipped: {len(self.run_manager.tropes)}",
        ]
        
        y_off = 265
        for stat in stats:
            s_surf = self.stat_font.render(stat, True, config.COLOR_TEXT_DARK)
            s_rect = s_surf.get_rect(center=(config.SCREEN_WIDTH // 2, y_off))
            surface.blit(s_surf, s_rect)
            y_off += 30
            
        # Draw Tropes final inventory
        tropes_lbl = self.lbl_font.render("Your Desk Tropes:", True, config.COLOR_TEXT_DARK)
        surface.blit(tropes_lbl, (config.SCREEN_WIDTH // 2 - 240, 360))
        
        if not self.run_manager.tropes:
            none_surf = self.desc_font.render("None (No modifiers equipped)", True, config.COLOR_TEXT_MUTED)
            surface.blit(none_surf, (config.SCREEN_WIDTH // 2 - 240, 395))
        else:
            y_t = 395
            for trope in self.run_manager.tropes[:3]: # draw up to 3 tropes
                t_surf = self.desc_font.render(f"- {trope.name}: {trope.description[:55]}...", True, config.COLOR_TEXT_DARK)
                surface.blit(t_surf, (config.SCREEN_WIDTH // 2 - 240, y_t))
                y_t += 22

        # Draw buttons
        for btn in self.buttons:
            btn.draw(surface)
