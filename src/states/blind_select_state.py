import pygame
from src import config
from src.engine.state_machine import State
from src.engine.ui import Button
from src.content.authors import Author

class BlindSelectState(State):
    def __init__(self, state_machine, run_manager):
        super().__init__(state_machine, run_manager)
        self.buttons = []
        self.title_font = config.get_font("typewriter", 36)
        self.label_font = config.get_font("sans", 20)
        self.desc_font = config.get_font("sans", 16)
        self.stat_font = config.get_font("sans", 24)

    def enter(self, **kwargs):
        # Refresh buttons
        self.buttons.clear()
        
        # We need a start button for the current active blind
        # Coordinates of the cards:
        # Card 1: x=140, Card 2: x=500, Card 3: x=860
        # Card size: w=280, h=380
        
        active_idx = self.run_manager.blind_index
        
        if active_idx == 0:
            self.buttons.append(Button(
                x=140 + 60, y=490, width=160, height=45,
                text="Begin Draft",
                callback=self.start_active_blind,
                color=(46, 204, 113) # Green
            ))
        elif active_idx == 1:
            self.buttons.append(Button(
                x=500 + 60, y=490, width=160, height=45,
                text="Begin Proof",
                callback=self.start_active_blind,
                color=(46, 204, 113) # Green
            ))
        elif active_idx == 2:
            self.buttons.append(Button(
                x=860 + 60, y=490, width=160, height=45,
                text="Begin Boss",
                callback=self.start_active_blind,
                color=(231, 76, 60) # Red accent
            ))

    def start_active_blind(self):
        self.run_manager.start_round()
        self.state_machine.change_state("game")

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
        
        # 1. Draw top status bar
        pygame.draw.rect(surface, config.COLOR_PANEL, (0, 0, config.SCREEN_WIDTH, 60))
        pygame.draw.line(surface, config.COLOR_TEXT_MUTED, (0, 60), (config.SCREEN_WIDTH, 60), 2)
        
        # Royalties
        roy_surf = self.stat_font.render(f"Royalties: ${self.run_manager.royalties}", True, config.COLOR_ROYALTIES)
        surface.blit(roy_surf, (30, 15))
        
        # Chapter progress
        chap_surf = self.stat_font.render(f"Chapter: {self.run_manager.chapter} / 8", True, config.COLOR_TEXT_LIGHT)
        surface.blit(chap_surf, (config.SCREEN_WIDTH // 2 - 80, 15))
        
        # Active items status
        items_str = f"Tropes: {len(self.run_manager.tropes)}/5 | Edits: {len(self.run_manager.edits)}/2"
        items_surf = self.stat_font.render(items_str, True, config.COLOR_TEXT_MUTED)
        surface.blit(items_surf, (config.SCREEN_WIDTH - 300, 15))
        
        # 2. Draw Chapter Header
        header_surf = self.title_font.render(f"Chapter {self.run_manager.chapter} Assignments", True, config.COLOR_TEXT_LIGHT)
        header_rect = header_surf.get_rect(center=(config.SCREEN_WIDTH // 2, 110))
        surface.blit(header_surf, header_rect)
        
        # 3. Draw the three Blind Cards
        card_w, card_h = 280, 380
        card_y = 170
        
        # Card 1: Small Blind
        self.draw_blind_card(
            surface, x=140, y=card_y, w=card_w, h=card_h,
            title="Draft Manuscript",
            subtitle="Small Blind",
            target=self.get_blind_target_score(0),
            reward="$3 base + submission bonuses",
            state=0,  # index
            active_idx=self.run_manager.blind_index
        )
        
        # Card 2: Big Blind
        self.draw_blind_card(
            surface, x=500, y=card_y, w=card_w, h=card_h,
            title="Proofread Manuscript",
            subtitle="Big Blind",
            target=self.get_blind_target_score(1),
            reward="$4 base + submission bonuses",
            state=1,  # index
            active_idx=self.run_manager.blind_index
        )
        
        # Card 3: Boss Blind (Author)
        boss_name = self.run_manager.selected_boss
        author = Author(boss_name)
        self.draw_blind_card(
            surface, x=860, y=card_y, w=card_w, h=card_h,
            title=author.display_name,
            subtitle="Bestselling Author",
            target=self.get_blind_target_score(2),
            reward="$5 base + submission bonuses",
            state=2,  # index
            active_idx=self.run_manager.blind_index,
            description=author.description
        )
        
        # 4. Draw buttons
        for btn in self.buttons:
            btn.draw(surface)

    def get_blind_target_score(self, idx):
        """Helper to compute targets for select screen display."""
        chapter_bases = [0, 1000, 3000, 8000, 20000, 50000, 120000, 300000, 800000]
        base = chapter_bases[min(self.run_manager.chapter, 8)]
        
        target = 0
        if idx == 0:
            target = base
        elif idx == 1:
            target = int(base * 1.6)
        else:
            target = int(base * 2.4)

        if any(t.name == "The Ghostwriter" for t in self.run_manager.tropes):
            target = int(target * 1.5)
        return target

    def draw_blind_card(self, surface, x, y, w, h, title, subtitle, target, reward, state, active_idx, description=None):
        rect = pygame.Rect(x, y, w, h)
        
        # Colors depending on state
        if state < active_idx:
            # Completed
            bg_color = (40, 42, 50)
            border_color = config.COLOR_TEXT_MUTED
            text_color = config.COLOR_TEXT_MUTED
            status_text = "COMPLETED"
        elif state == active_idx:
            # Active
            bg_color = config.COLOR_PANEL
            border_color = config.COLOR_CLUE_GREEN if state < 2 else config.COLOR_ACCENT
            text_color = config.COLOR_TEXT_LIGHT
            status_text = "ASSIGNED"
        else:
            # Locked
            bg_color = (24, 26, 32)
            border_color = (50, 52, 60)
            text_color = config.COLOR_TEXT_MUTED
            status_text = "LOCKED"
            
        # Draw background and border
        pygame.draw.rect(surface, bg_color, rect, border_radius=10)
        pygame.draw.rect(surface, border_color, rect, width=3, border_radius=10)
        
        # Subtitle (Small Blind / Big Blind / Bestselling Author)
        sub_surf = self.desc_font.render(subtitle.upper(), True, border_color)
        sub_rect = sub_surf.get_rect(center=(rect.centerx, rect.y + 30))
        surface.blit(sub_surf, sub_rect)
        
        # Title
        title_surf = self.label_font.render(title, True, text_color)
        title_rect = title_surf.get_rect(center=(rect.centerx, rect.y + 65))
        surface.blit(title_surf, title_rect)
        
        pygame.draw.line(surface, border_color, (rect.x + 30, rect.y + 95), (rect.right - 30, rect.y + 95), 1)
        
        # Target score
        score_label = self.desc_font.render("TARGET HYPE SCORE:", True, config.COLOR_TEXT_MUTED)
        surface.blit(score_label, (rect.x + 30, rect.y + 115))
        
        score_val = self.label_font.render(f"{target:,}", True, text_color)
        surface.blit(score_val, (rect.x + 30, rect.y + 135))
        
        # Reward
        reward_label = self.desc_font.render("ESTIMATED ROYALTIES:", True, config.COLOR_TEXT_MUTED)
        surface.blit(reward_label, (rect.x + 30, rect.y + 175))
        
        reward_val = self.desc_font.render(reward, True, text_color)
        surface.blit(reward_val, (rect.x + 30, rect.y + 195))
        
        # Custom description for Boss Blind
        if description:
            desc_y = rect.y + 240
            desc_words = description.split()
            lines = []
            curr_line = ""
            for word in desc_words:
                if len(curr_line + " " + word) < 26:
                    curr_line += (" " if curr_line else "") + word
                else:
                    lines.append(curr_line)
                    curr_line = word
            if curr_line:
                lines.append(curr_line)
                
            for line in lines[:4]:
                line_surf = self.desc_font.render(line, True, config.COLOR_ACCENT if state == active_idx else config.COLOR_TEXT_MUTED)
                surface.blit(line_surf, (rect.x + 30, desc_y))
                desc_y += 18
                
        # Status Label at bottom
        status_surf = self.label_font.render(status_text, True, border_color)
        status_rect = status_surf.get_rect(center=(rect.centerx, rect.bottom - 40))
        
        # Only draw status if it's not the active blind (since active blind has a button instead)
        if state != active_idx:
            surface.blit(status_surf, status_rect)
