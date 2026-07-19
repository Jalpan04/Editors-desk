import pygame
import random
from src import config
from src.engine.state_machine import State
from src.engine.ui import Button, ParticleSystem, ScreenShake

class ScoringState(State):
    def __init__(self, state_machine, run_manager):
        super().__init__(state_machine, run_manager)
        self.buttons = []
        self.particles = ParticleSystem()
        self.shake = ScreenShake()
        
        # Fonts
        self.typewriter_font = config.get_font("typewriter", 28)
        self.typewriter_lg = config.get_font("typewriter", 40)
        self.ui_font = config.get_font("sans", 20)
        self.ui_bold = config.get_font_bold(22)
        self.score_font = config.get_font("sans", 32)
        self.tooltip_font = config.get_font("sans", 14)
        
        self.title_font = config.get_font("typewriter", 32)
        self.math_font = config.get_font("sans", 30)
        self.math_lbl = config.get_font("sans", 14)
        self.letter_font = config.get_font("typewriter", 36)
        self.sub_font = config.get_font("sans", 22)
        
        # QWERTY keys layout for background keyboard
        self.kbd_rows = [
            ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
            ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
            ['z', 'x', 'c', 'v', 'b', 'n', 'm']
        ]

        # Scoring data passing
        self.result = {}
        self.guess = ""
        self.score_ticker = 0
        self.auto_continue_timer = 0.0
        
        # Animation states: "init", "letters", "final_calc", "done"
        self.anim_stage = "init"
        self.letter_idx = 0
        self.timer = 0.0
        
        # Ticking numbers
        self.displayed_chips = 0
        self.displayed_mult = 1.0
        self.displayed_x_mults = []
        self.target_chips = 0
        self.target_mult = 1.0
        self.target_x_mults = []
        
        # Floating animations
        self.floats = []

    def enter(self, **kwargs):
        self.result = kwargs.get("result", {})
        self.guess = kwargs.get("guess", "").lower()
        self.score_ticker = self.run_manager.round_score - self.result.get("score", 0)
        self.auto_continue_timer = 0.0
        
        self.buttons.clear()
        
        if self.result.get("pattern") == "Plagiarized":
            self.anim_stage = "done"
            self.letter_idx = len(self.guess)
            self.timer = 0.0
            self.displayed_chips = 0
            self.displayed_mult = 1.0
            self.displayed_x_mults = []
            self.target_chips = 0
            self.target_mult = 1.0
            self.target_x_mults = []
            config.sounds.play("error")
            return
            
        self.anim_stage = "init"
        self.letter_idx = 0
        self.timer = 0.0
        
        # Reset visual targets
        self.displayed_chips = 0
        self.displayed_mult = 1.0
        self.displayed_x_mults = []
        
        # Gather base chips and base mult based on pattern
        pattern_name = self.result["pattern"]
        pattern_bases = {
            "Masterpiece": {"chips": 250, "mult": 8.0, "level_chips": 80, "level_mult": 6.0},
            "Jumble": {"chips": 100, "mult": 4.0, "level_chips": 40, "level_mult": 4.0},
            "Shot in the Dark": {"chips": 20, "mult": 2.0, "level_chips": 15, "level_mult": 2.0},
            "Standard Submission": {"chips": 10, "mult": 1.0, "level_chips": 10, "level_mult": 1.0},
            "Total Rewrite": {"chips": 5, "mult": 1.0, "level_chips": 5, "level_mult": 1.0}
        }
        
        level = self.run_manager.style_guides.get(pattern_name, 1)
        base_info = pattern_bases[pattern_name]
        
        # Starting anim values
        self.displayed_chips = base_info["chips"] + (level - 1) * base_info["level_chips"]
        self.displayed_mult = base_info["mult"] + (level - 1) * base_info["level_mult"]
        self.displayed_x_mults = []
        
        # Final target values
        self.target_chips = self.result["chips"]
        self.target_mult = self.result["mult"]
        self.target_x_mults = list(self.result["x_mults"])
        
        config.sounds.play("stamp")
        
        # Spawn float directly on the paper
        self.spawn_float(f"{pattern_name}!", config.SCREEN_WIDTH // 2, 120, config.COLOR_CLUE_GREEN)

    def spawn_float(self, text, start_x, start_y, color):
        target_x = config.SCREEN_WIDTH // 2
        target_y = 370
        life = 0.5
        self.floats.append({
            "text": text,
            "x": start_x,
            "y": start_y,
            "vx": (target_x - start_x) / life,
            "vy": (target_y - start_y) / life,
            "color": color,
            "life": life
        })

    def handle_events(self, events):
        mpos = pygame.mouse.get_pos()
        for btn in self.buttons:
            btn.check_hover(mpos)
            
        for event in events:
            # Skip animation or advance on left click
            if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                if self.anim_stage != "done":
                    # Instant complete
                    self.displayed_chips = self.target_chips
                    self.displayed_mult = self.target_mult
                    self.displayed_x_mults = list(self.target_x_mults)
                    self.anim_stage = "done"
                    config.sounds.play("bell")
                else:
                    self.press_continue()
            # Skip animation or advance on Return/Space press
            elif event.type == pygame.KEYDOWN:
                if event.key in [pygame.K_RETURN, pygame.K_SPACE]:
                    if self.anim_stage != "done":
                        # Instant complete
                        self.displayed_chips = self.target_chips
                        self.displayed_mult = self.target_mult
                        self.displayed_x_mults = list(self.target_x_mults)
                        self.anim_stage = "done"
                        config.sounds.play("bell")
                    else:
                        self.press_continue()

    def press_continue(self):
        self.state_machine.change_state("game")

    def update(self, dt):
        self.particles.update(dt)
        self.shake.update(dt)
        
        # Update float animations
        for f in self.floats:
            f["x"] += f["vx"] * dt
            f["y"] += f["vy"] * dt
            f["life"] -= dt
        self.floats = [f for f in self.floats if f["life"] > 0]
        
        for btn in self.buttons:
            btn.update(dt)
            
        # Count up score ticker if stage is done
        if self.anim_stage == "done":
            target_score = self.run_manager.round_score
            if self.score_ticker < target_score:
                diff = target_score - self.score_ticker
                speed = max(1, int(diff * 8.0 * dt))
                self.score_ticker = min(target_score, self.score_ticker + speed)
            else:
                self.auto_continue_timer += dt
                if self.auto_continue_timer >= 1.0:
                    self.press_continue()
                
        # Animation sequence
        self.timer += dt
        
        if self.anim_stage == "init":
            # Wait before starting letter reveals
            if self.timer >= 0.6:
                self.anim_stage = "letters"
                self.letter_idx = 0
                self.timer = 0.0
                
        elif self.anim_stage == "letters":
            if self.timer >= 0.4:
                self.timer = 0.0
                if self.letter_idx < len(self.guess):
                    char = self.guess[self.letter_idx]
                    clue = self.result["clues"][self.letter_idx]
                    from src.gameplay.scoring import LETTER_CHIPS
                    let_chips = LETTER_CHIPS.get(char, 1)
                    
                    config.sounds.play_clack()
                    
                    # Compute layout coordinate of the active scoring letter to shoot scores
                    paper_rect = pygame.Rect(400, 80, 440, 360)
                    box_w = 40
                    box_gap = 8
                    word_len = len(self.guess)
                    total_w = word_len * box_w + (word_len - 1) * box_gap
                    start_x = paper_rect.centerx - total_w // 2
                    visible_rows = len(self.run_manager.round_history[-5:])
                    row_y = 100 + (visible_rows - 1) * 50
                    
                    letter_center_x = start_x + self.letter_idx * (box_w + box_gap) + box_w // 2
                    letter_center_y = row_y + box_w // 2
                    
                    # Determine color-coordinated particles
                    if clue == "green":
                        p_color = config.COLOR_CLUE_GREEN
                    elif clue == "yellow":
                        p_color = config.COLOR_CLUE_YELLOW
                    elif clue == "grey":
                        p_color = config.COLOR_CLUE_GREY
                    elif clue == "redacted":
                        p_color = config.COLOR_CLUE_REDACTED
                    else:
                        p_color = config.COLOR_TEXT_LIGHT
                        
                    # Spawn typewriter puff particles
                    self.particles.spawn(letter_center_x, letter_center_y, p_color, count=8)
                    
                    mods = self.run_manager.keyboard_mods.get(char, {})
                    repeat = 2 if mods.get("stapler", False) else 1
                    
                    for _ in range(repeat):
                        added_chips = 0
                        added_mult = 0.0
                        added_x = 1.0
                        
                        if mods.get("highlighter", False):
                            added_mult += 15.0
                        if mods.get("coffee_ring", False):
                            added_chips += 50
                            
                        if clue == 'green':
                            added_chips += 5
                        elif clue == 'yellow':
                            added_chips += 1
                        else:
                            added_chips += 0
                            
                        self.displayed_chips += added_chips
                        self.displayed_mult += added_mult
                        if added_x > 1.0:
                            self.displayed_x_mults.append(added_x)
                            
                        # Float from the letter directly down to the placard
                        if added_chips > 0:
                            self.spawn_float(f"+{added_chips} Chips", letter_center_x, letter_center_y, config.COLOR_CLUE_GREEN)
                        if added_mult > 0:
                            self.spawn_float(f"+{added_mult} Mult", letter_center_x, letter_center_y, config.COLOR_CLUE_YELLOW)
                        if added_x > 1.0:
                            self.spawn_float(f"x{added_x} Mult", letter_center_x, letter_center_y, config.COLOR_HIGHLIGHTER)
                            
                    self.letter_idx += 1
                else:
                    self.anim_stage = "final_calc"
                    self.timer = 0.0
                    
        elif self.anim_stage == "final_calc":
            if self.timer >= 0.4:
                # Sync final math targets
                self.displayed_chips = self.target_chips
                self.displayed_mult = self.target_mult
                self.displayed_x_mults = list(self.target_x_mults)
                
                config.sounds.play("bell")
                self.shake.trigger(intensity=8, duration=0.3)
                
                # Spawn gold particles on the placard
                self.particles.spawn(config.SCREEN_WIDTH // 2, 350, config.COLOR_ROYALTIES, count=25)
                self.spawn_float(f"+{self.result['score']:,} Hype!", config.SCREEN_WIDTH // 2, 320, config.COLOR_ROYALTIES)
                
                self.anim_stage = "done"

    def draw(self, surface):
        # Draw base desk background
        surface.fill(config.COLOR_DESK)
        
        # Apply Screen Shake Offset
        offset_x, offset_y = self.shake.get_offset()
        
        game_surf = pygame.Surface((config.SCREEN_WIDTH, config.SCREEN_HEIGHT), pygame.SRCALPHA)
        self.draw_desk_elements(game_surf)
        
        # Plagiarism Red Ink Stamp (affected by Screen Shake)
        if self.result.get("pattern") == "Plagiarized":
            paper_rect = pygame.Rect(400, 80, 440, 360)
            stamp_font = config.get_font("typewriter", 36)
            stamp_surf = stamp_font.render("PLAGIARIZED", True, (231, 76, 60))
            
            # Sub-surface for stamp box border
            box_w, box_h = stamp_surf.get_width() + 24, stamp_surf.get_height() + 14
            stamp_box = pygame.Surface((box_w, box_h), pygame.SRCALPHA)
            pygame.draw.rect(stamp_box, (231, 76, 60), (0, 0, box_w, box_h), width=4, border_radius=6)
            stamp_box.blit(stamp_surf, (12, 7))
            
            # Angle and Center
            rotated_stamp = pygame.transform.rotate(stamp_box, 15)
            rotated_rect = rotated_stamp.get_rect(center=paper_rect.center)
            game_surf.blit(rotated_stamp, rotated_rect)
            
        surface.blit(game_surf, (offset_x, offset_y))
        
        # Draw float indicators and particles
        for f in self.floats:
            f_surf = self.ui_bold.render(f["text"], True, f["color"])
            f_rect = f_surf.get_rect(center=(f["x"], f["y"]))
            surface.blit(f_surf, f_rect)
            
        self.particles.draw(surface)
        
        # Draw next button
        for btn in self.buttons:
            btn.draw(surface)

    def draw_desk_elements(self, surface):
        # 1. Left Panel - Hype Meter
        hype_rect = pygame.Rect(40, 80, 310, 220)
        pygame.draw.rect(surface, config.COLOR_PANEL, hype_rect, border_radius=10)
        pygame.draw.rect(surface, config.COLOR_TEXT_MUTED, hype_rect, width=2, border_radius=10)
        
        hype_lbl = self.ui_font.render("CURRENT HYPE SCORE", True, config.COLOR_TEXT_MUTED)
        surface.blit(hype_lbl, (60, 100))
        
        # Show round score increasing dynamically
        # Tally score is added to round score when done
        display_score = int(self.score_ticker)
            
        score_str = f"{display_score:,}"
        score_surf = self.score_font.render(score_str, True, config.COLOR_TEXT_LIGHT)
        surface.blit(score_surf, (60, 125))
        
        target_lbl = self.ui_font.render(f"Target: {self.run_manager.target_score:,}", True, config.COLOR_TEXT_LIGHT)
        surface.blit(target_lbl, (60, 175))
        
        # Progress Bar
        pct = min(1.0, display_score / max(1, self.run_manager.target_score))
        bar_rect = pygame.Rect(60, 210, 270, 20)
        pygame.draw.rect(surface, (20, 20, 25), bar_rect, border_radius=4)
        if pct > 0:
            fill_rect = pygame.Rect(60, 210, int(270 * pct), 20)
            pygame.draw.rect(surface, config.COLOR_CLUE_GREEN, fill_rect, border_radius=4)
            
        stage_name = self.run_manager.get_blind_name()
        stage_surf = self.ui_bold.render(stage_name, True, config.COLOR_ACCENT if self.run_manager.boss_blind else config.COLOR_TEXT_LIGHT)
        surface.blit(stage_surf, (60, 250))
        
        # Resources left
        res_rect = pygame.Rect(40, 315, 310, 80)
        pygame.draw.rect(surface, config.COLOR_PANEL, res_rect, border_radius=10)
        
        sub_lbl = self.ui_font.render(f"Submissions: {self.run_manager.submissions_left}/{self.run_manager.submissions_max}", True, config.COLOR_TEXT_LIGHT)
        surface.blit(sub_lbl, (60, 330))
        
        draft_lbl = self.ui_font.render(f"Drafts: {self.run_manager.drafts_left}/{self.run_manager.drafts_max}", True, config.COLOR_CLUE_YELLOW)
        surface.blit(draft_lbl, (60, 360))
        
        # Desk Tropes
        tropes_lbl = self.ui_bold.render("THE EDITOR'S TROPES (PASSIVES)", True, config.COLOR_TEXT_LIGHT)
        surface.blit(tropes_lbl, (40, 408))
        for idx in range(5):
            x = 40 + idx * 68
            slot_rect = pygame.Rect(x, 435, 60, 60)
            pygame.draw.rect(surface, (20, 22, 30), slot_rect, border_radius=6)
            pygame.draw.rect(surface, config.COLOR_TEXT_MUTED, slot_rect, width=1, border_radius=6)
            
            if idx < len(self.run_manager.tropes):
                trope = self.run_manager.tropes[idx]
                initials = "".join([w[0] for w in trope.name.split() if w[0].isupper()])[:3]
                ini_surf = self.typewriter_font.render(initials, True, config.COLOR_ACCENT if trope.is_debuff_active else config.COLOR_CLUE_GREEN)
                ini_rect = ini_surf.get_rect(center=slot_rect.center)
                surface.blit(ini_surf, ini_rect)
                
        # Desk Edits
        edits_lbl = self.ui_bold.render("EDITS (CONSUMABLES)", True, config.COLOR_TEXT_LIGHT)
        surface.blit(edits_lbl, (40, 560))
        for idx in range(2):
            slot_rect = pygame.Rect(40 + idx * 150, 590, 130, 70)
            pygame.draw.rect(surface, (20, 22, 30), slot_rect, border_radius=6)
            pygame.draw.rect(surface, config.COLOR_TEXT_MUTED, slot_rect, width=1, border_radius=6)
            
            if idx < len(self.run_manager.edits):
                edit = self.run_manager.edits[idx]
                edit_name_surf = self.ui_font.render(edit.name.replace("The ", ""), True, config.COLOR_TEXT_LIGHT)
                edit_rect = edit_name_surf.get_rect(center=(slot_rect.centerx, slot_rect.centery - 10))
                surface.blit(edit_name_surf, edit_rect)
                
                use_surf = self.tooltip_font.render("Locked (scoring)", True, config.COLOR_TEXT_MUTED)
                use_rect = use_surf.get_rect(center=(slot_rect.centerx, slot_rect.centery + 15))
                surface.blit(use_surf, use_rect)

        # 2. Center Panel - Manuscript Paper
        paper_rect = pygame.Rect(400, 80, 440, 360)
        pygame.draw.rect(surface, (20, 20, 25), paper_rect.inflate(6, 6), border_radius=8)
        pygame.draw.rect(surface, config.COLOR_PAPER, paper_rect, border_radius=6)
        
        # Draw history rows (excluding the last one since we draw it below)
        visible_history = self.run_manager.round_history[-5:]
        visible_count = len(visible_history)
        
        # Center coords
        box_w = 40
        box_gap = 8
        word_len = len(self.guess)
        total_w = word_len * box_w + (word_len - 1) * box_gap
        start_x = paper_rect.centerx - total_w // 2
        
        # Draw previous completed entries
        row_y = 100
        for idx, entry in enumerate(visible_history[:-1]):
            w_str = entry["word"]
            w_clues = entry["clues"]
            is_draft = entry["is_draft"]
            w_score = entry["score"]
            
            for l_idx, char in enumerate(w_str):
                clue = w_clues[l_idx]
                box_rect = pygame.Rect(start_x + l_idx * (box_w + box_gap), row_y, box_w, box_w)
                
                if clue == "green":
                    col = config.COLOR_CLUE_GREEN
                elif clue == "yellow":
                    col = config.COLOR_CLUE_YELLOW
                elif clue == "grey":
                    col = config.COLOR_CLUE_GREY
                elif clue == "redacted":
                    col = config.COLOR_CLUE_REDACTED
                else:
                    col = config.COLOR_CLUE_EMPTY
                    
                pygame.draw.rect(surface, col, box_rect, border_radius=4)
                let_color = config.COLOR_TEXT_LIGHT if col != config.COLOR_CLUE_EMPTY else config.COLOR_TEXT_DARK
                let_surf = self.typewriter_font.render(char.upper(), True, let_color)
                let_rect = let_surf.get_rect(center=box_rect.center)
                surface.blit(let_surf, let_rect)
                
            if entry.get("is_plagiarized"):
                lbl_color = (231, 76, 60)
                lbl_str = "PLAGIARIZED"
            else:
                lbl_color = config.COLOR_ROYALTIES if not is_draft else config.COLOR_CLUE_YELLOW
                lbl_str = f"+{w_score:,}" if not is_draft else "DRAFT"
            lbl_surf = self.ui_font.render(lbl_str, True, lbl_color)
            surface.blit(lbl_surf, (start_x + total_w + 12, row_y + 10))
            
            row_y += 50
            
        # Draw active scoring row at its correct y position
        # Reveal letters progressively based on self.letter_idx
        clues = self.result["clues"]
        
        # Highlight active row outline
        active_row_rect = pygame.Rect(start_x - 4, row_y - 4, total_w + 8, box_w + 8)
        pygame.draw.rect(surface, config.COLOR_HIGHLIGHTER, active_row_rect, width=2, border_radius=6)
        
        for l_idx, char in enumerate(self.guess):
            box_rect = pygame.Rect(start_x + l_idx * (box_w + box_gap), row_y, box_w, box_w)
            
            # Colorize all boxes immediately so clues are visible from the start
            clue = clues[l_idx]
            if clue == "green":
                col = config.COLOR_CLUE_GREEN
            elif clue == "yellow":
                col = config.COLOR_CLUE_YELLOW
            elif clue == "grey":
                col = config.COLOR_CLUE_GREY
            elif clue == "redacted":
                col = config.COLOR_CLUE_REDACTED
            else:
                col = config.COLOR_CLUE_EMPTY
                
            pygame.draw.rect(surface, col, box_rect, border_radius=4)
            
            # Highlight border for the active letter currently being calculated for points
            if l_idx == self.letter_idx and self.anim_stage == "letters":
                pygame.draw.rect(surface, config.COLOR_HIGHLIGHTER, box_rect, width=2, border_radius=4)
            
            let_color = config.COLOR_TEXT_LIGHT if col != config.COLOR_CLUE_EMPTY else config.COLOR_TEXT_DARK
            let_surf = self.typewriter_font.render(char.upper(), True, let_color)
            let_rect = let_surf.get_rect(center=box_rect.center)
            surface.blit(let_surf, let_rect)
            
        # 3. Draw Scoring Math Ticker Placard directly at the bottom of the paper
        # Takes the place of the active typewriter input
        placard_rect = pygame.Rect(paper_rect.centerx - 190, 345, 380, 50)
        
        # Display the active Combo Pattern prominently right above the placard
        pattern_str = self.result.get("pattern", "Standard Submission")
        pattern_surf = self.ui_bold.render(pattern_str.upper(), True, config.COLOR_CLUE_YELLOW)
        pattern_rect = pattern_surf.get_rect(center=(paper_rect.centerx, placard_rect.y - 15))
        surface.blit(pattern_surf, pattern_rect)

        pygame.draw.rect(surface, (18, 19, 24), placard_rect, border_radius=8)
        pygame.draw.rect(surface, config.COLOR_TEXT_MUTED if self.anim_stage != "done" else config.COLOR_HIGHLIGHTER, placard_rect, width=2, border_radius=8)
        
        # Draw Chips
        chips_str = f"{int(self.displayed_chips)}"
        chips_surf = self.math_font.render(chips_str, True, config.COLOR_CLUE_GREEN)
        surface.blit(chips_surf, (placard_rect.x + 15, placard_rect.y + 10))
        
        # Times
        times_surf = self.math_font.render("x", True, config.COLOR_TEXT_MUTED)
        surface.blit(times_surf, (placard_rect.x + 130, placard_rect.y + 10))
        
        # Draw Mult
        curr_mult = self.displayed_mult
        for xm in self.displayed_x_mults:
            curr_mult *= xm
        mult_str = f"{curr_mult:.1f}"
        mult_surf = self.math_font.render(mult_str, True, config.COLOR_CLUE_YELLOW)
        surface.blit(mult_surf, (placard_rect.x + 165, placard_rect.y + 10))
        
        # Equals
        if self.anim_stage == "done":
            eq_surf = self.math_font.render("=", True, config.COLOR_ROYALTIES)
            surface.blit(eq_surf, (placard_rect.x + 245, placard_rect.y + 10))
            
            total_str = f"{self.result['score']}"
            tot_surf = self.math_font.render(total_str, True, config.COLOR_ROYALTIES)
            surface.blit(tot_surf, (placard_rect.x + 280, placard_rect.y + 10))

        # 4. Keyboard (rendered statically in background)
        kbd_x = 400
        kbd_y = 480
        key_size = 45
        key_gap = 8
        for r_idx, row in enumerate(self.kbd_rows):
            offset = 0
            if r_idx == 1:
                offset = 20
            elif r_idx == 2:
                offset = 40
            for k_idx, char in enumerate(row):
                key_x = kbd_x + offset + k_idx * (key_size + key_gap)
                key_y = kbd_y + r_idx * (key_size + key_gap)
                key_rect = pygame.Rect(key_x, key_y, key_size, key_size)
                
                # Check mods
                mods = self.run_manager.keyboard_mods.get(char, {})
                is_highlighter = mods.get("highlighter", False)
                is_coffee_ring = mods.get("coffee_ring", False)
                is_stapler = mods.get("stapler", False)
                is_removed = mods.get("removed", False)
                
                bg_color = config.COLOR_PANEL
                border_color = config.COLOR_TEXT_MUTED
                
                pygame.draw.rect(surface, bg_color, key_rect, border_radius=5)
                
                if is_highlighter and not is_removed:
                    pygame.draw.rect(surface, config.COLOR_HIGHLIGHTER, key_rect, width=2, border_radius=5)
                if is_coffee_ring and not is_removed:
                    pygame.draw.circle(surface, config.COLOR_CLUE_REDACTED, key_rect.center, 12, width=2)
                if is_stapler and not is_removed:
                    pygame.draw.line(surface, (180, 180, 190), (key_rect.x + 8, key_rect.y + 6), (key_rect.right - 8, key_rect.y + 6), 2)
                    pygame.draw.line(surface, (180, 180, 190), (key_rect.x + 8, key_rect.bottom - 6), (key_rect.right - 8, key_rect.bottom - 6), 2)
                    
                pygame.draw.rect(surface, border_color, key_rect, width=1, border_radius=5)
                
                if not is_removed:
                    let_surf = self.ui_font.render(char.upper(), True, config.COLOR_TEXT_LIGHT)
                    let_rect = let_surf.get_rect(center=key_rect.center)
                    surface.blit(let_surf, let_rect)
                else:
                    pygame.draw.line(surface, config.COLOR_ACCENT, (key_rect.x + 8, key_rect.y + 8), (key_rect.right - 8, key_rect.bottom - 8), 2)
                    pygame.draw.line(surface, config.COLOR_ACCENT, (key_rect.right - 8, key_rect.y + 8), (key_rect.x + 8, key_rect.bottom - 8), 2)
