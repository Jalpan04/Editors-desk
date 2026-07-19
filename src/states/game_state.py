import pygame
from src import config
from src.engine.state_machine import State
from src.engine.ui import Button, ParticleSystem, ScreenShake
from src.content.authors import Author
from src.content.edits import create_all_edits

class GameState(State):
    def __init__(self, state_machine, run_manager):
        super().__init__(state_machine, run_manager)
        
        # State UI variables
        self.current_input = ""
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
        
        # Keyboard QWERTY rows
        self.kbd_rows = [
            ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
            ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
            ['z', 'x', 'c', 'v', 'b', 'n', 'm']
        ]
        
        # Key status tracking for this round (highest clue state discovered)
        # letter -> "green", "yellow", "grey", "empty"
        self.key_discoveries = {}
        
        # Error message popups
        self.error_message = ""
        self.error_timer = 0.0
        
        # Tooltip display state
        self.hovered_tooltip = None

        # Setup side buttons
        self.setup_buttons()

    def setup_buttons(self):
        self.buttons.clear()
        
        # Draft and Submit buttons placed next to manuscript
        self.buttons.append(Button(
            x=880, y=140, width=160, height=45,
            text="Draft Word",
            callback=self.press_draft,
            color=(230, 180, 30) # Yellowish
        ))
        self.buttons.append(Button(
            x=880, y=200, width=160, height=45,
            text="Submit Word",
            callback=self.press_submit,
            color=(46, 180, 110) # Greenish
        ))

    def enter(self, **kwargs):
        self.current_input = ""
        self.key_discoveries = self.run_manager.key_discoveries
        self.error_message = ""
        self.error_timer = 0.0
        self.hovered_tooltip = None
        self.setup_buttons()

    def press_draft(self):
        self.process_guess(is_draft=True)

    def press_submit(self):
        self.process_guess(is_draft=False)

    def process_guess(self, is_draft):
        if is_draft and self.run_manager.drafts_left <= 0:
            self.trigger_error("No Drafts remaining!")
            return
        if not is_draft and self.run_manager.submissions_left <= 0:
            self.trigger_error("No Submissions remaining!")
            return

        expected_len = 4 if self.run_manager.boss_blind == "Minimalist" else 5
        if len(self.current_input) != expected_len:
            self.trigger_error(f"Must type a {expected_len}-letter word!")
            return

        # Perform guess logic in RunManager
        result = self.run_manager.submit_word(self.current_input, is_draft=is_draft)
        
        if "error" in result:
            self.trigger_error(result["error"])
            return

        # Play typing carriage return or stamp
        config.sounds.play("carriage")
        
        # Update keyboard key discovery colors based on clues
        # (Only if not redacted by Coffee ring)
        clues = result["clues"]
        for idx, char in enumerate(self.current_input):
            clue = clues[idx]
            if clue != "redacted" and char.isalpha():
                curr_state = self.key_discoveries.get(char, "empty")
                # Priority: green > yellow > grey > empty
                prio = {"green": 3, "yellow": 2, "grey": 1, "empty": 0}
                if prio.get(clue, 0) > prio.get(curr_state, 0):
                    self.key_discoveries[char] = clue

        # Clear active entry
        typed_word = self.current_input
        self.current_input = ""
        
        # If it was a submission, trigger scoring state transition
        if not is_draft:
            self.state_machine.change_state("scoring", result=result, guess=typed_word)
        else:
            # For draft, verify if round is in continue state
            # (Drafts can't win the round since score is 0, but could run out)
            pass

    def trigger_error(self, msg):
        self.error_message = msg
        self.error_timer = 2.0
        config.sounds.play("error")
        self.shake.trigger(intensity=8, duration=0.25)

    def handle_events(self, events):
        mpos = pygame.mouse.get_pos()
        
        # Hover checks
        for btn in self.buttons:
            btn.check_hover(mpos)
            
        # Tooltip checks (Tropes and Edits slots)
        self.check_tooltips(mpos)
        
        for event in events:
            # Buttons click
            for btn in self.buttons:
                if btn.handle_event(event, mpos):
                    break
                    
            # Click active edits
            if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                self.click_edit_slot(mpos)
                
            # Keyboard typing
            if event.type == pygame.KEYDOWN:
                config.sounds.play_clack()
                
                expected_len = 4 if self.run_manager.boss_blind == "Minimalist" else 5
                
                if event.key == pygame.K_BACKSPACE:
                    if len(self.current_input) > 0:
                        self.current_input = self.current_input[:-1]
                elif event.key == pygame.K_RETURN:
                    self.press_submit()
                elif event.key == pygame.K_SPACE:
                    self.press_draft()
                else:
                    char = event.unicode.lower()
                    
                    # Handle Ghostwriter wildcard input
                    is_ghostwriter_active = any(t.name == "The Ghostwriter" for t in self.run_manager.tropes)
                    if (char.isalpha() or (is_ghostwriter_active and char in ['*', ' ', '_'])) and len(self.current_input) < expected_len:
                        if char in [' ', '_']:
                            char = '*'
                        self.current_input += char

    def click_edit_slot(self, mpos):
        # Coordinates for the 2 Edits slots:
        # Slot 1: x=40, y=580, w=130, h=70
        # Slot 2: x=190, y=580, w=130, h=70
        slot1_rect = pygame.Rect(40, 580, 130, 70)
        slot2_rect = pygame.Rect(190, 580, 130, 70)
        
        clicked_idx = -1
        if slot1_rect.collidepoint(mpos):
            clicked_idx = 0
        elif slot2_rect.collidepoint(mpos):
            clicked_idx = 1
            
        if clicked_idx >= 0 and clicked_idx < len(self.run_manager.edits):
            edit_item = self.run_manager.edits[clicked_idx]
            
            # White-out requires selecting a trope, so handle it
            if edit_item.name == "The White-Out":
                # Find a trope with active debuff
                target_tropes = [t for t in self.run_manager.tropes if t.is_debuff_active]
                if target_tropes:
                    msg = edit_item.use(self.run_manager, target_trope=target_tropes[0])
                    self.run_manager.edits.pop(clicked_idx)
                    self.trigger_particles_at(100, 615, config.COLOR_HIGHLIGHTER)
                    self.trigger_error(msg)  # display as notice
                else:
                    self.trigger_error("No Tropes have active debuffs!")
            else:
                msg = edit_item.use(self.run_manager)
                self.run_manager.edits.pop(clicked_idx)
                
                # Visual feed back
                self.trigger_particles_at(40 + clicked_idx * 150 + 65, 615, config.COLOR_ROYALTIES)
                self.trigger_error(msg) # display as notice

    def check_tooltips(self, mpos):
        self.hovered_tooltip = None
        
        # Check active Tropes (up to 5)
        # Slot start: x=40, y=420. Each w=60, h=60, gap=8
        for idx, trope in enumerate(self.run_manager.tropes):
            rect = pygame.Rect(40 + idx * 68, 420, 60, 60)
            if rect.collidepoint(mpos):
                debuff_text = f"Debuff: {trope.debuff_desc}" if trope.is_debuff_active else "Debuff: Cleaned (White-Out)"
                self.hovered_tooltip = {
                    "title": trope.name,
                    "desc": trope.description,
                    "debuff": debuff_text,
                    "pos": mpos
                }
                return
                
        # Check active Edits (up to 2)
        # Slot 1: x=40, y=580. w=130, h=70.
        for idx, edit in enumerate(self.run_manager.edits):
            rect = pygame.Rect(40 + idx * 150, 580, 130, 70)
            if rect.collidepoint(mpos):
                self.hovered_tooltip = {
                    "title": edit.name,
                    "desc": edit.description,
                    "debuff": "Click to consume immediately.",
                    "pos": mpos
                }
                return

    def trigger_particles_at(self, x, y, color):
        self.particles.spawn(x, y, color, count=15)

    def update(self, dt):
        self.particles.update(dt)
        self.shake.update(dt)
        
        if self.error_timer > 0:
            self.error_timer -= dt
            
        for btn in self.buttons:
            btn.update(dt)
            
        # Check if stage was won/lost and transition
        round_status = self.run_manager.check_round_end()
        if round_status == "win":
            # Transition to blind select (or next loop)
            # But wait, in Balatro, winning a blind moves you to the Shop first!
            self.run_manager.advance_blind()
            self.state_machine.change_state("shop")
        elif round_status == "lose":
            self.state_machine.change_state("game_over", result="fired")

    def draw(self, surface):
        surface.fill(config.COLOR_DESK)
        
        # Apply Screen Shake Offset
        offset_x, offset_y = self.shake.get_offset()
        
        # Render gameplay layout relative to screen (adding shake offsets)
        game_surf = pygame.Surface((config.SCREEN_WIDTH, config.SCREEN_HEIGHT), pygame.SRCALPHA)
        self.draw_gameplay(game_surf)
        
        # Blit main game graphics with shake
        surface.blit(game_surf, (offset_x, offset_y))
        
        # Draw particles (unaffected by screenshake for visual depth)
        self.particles.draw(surface)
        
        # Draw Tooltip overlay at very top layer
        if self.hovered_tooltip:
            self.draw_tooltip(surface, self.hovered_tooltip)

    def draw_gameplay(self, surface):
        # 1. Draw Left Panel - Hype Meter & Inventory
        # Hype Meter Panel
        hype_rect = pygame.Rect(40, 80, 310, 220)
        pygame.draw.rect(surface, config.COLOR_PANEL, hype_rect, border_radius=10)
        pygame.draw.rect(surface, config.COLOR_TEXT_MUTED, hype_rect, width=2, border_radius=10)
        
        # Hype text labels
        hype_lbl = self.ui_font.render("CURRENT HYPE SCORE", True, config.COLOR_TEXT_MUTED)
        surface.blit(hype_lbl, (60, 100))
        
        score_str = f"{self.run_manager.round_score:,}"
        score_surf = self.score_font.render(score_str, True, config.COLOR_TEXT_LIGHT)
        surface.blit(score_surf, (60, 125))
        
        target_lbl = self.ui_font.render(f"Target: {self.run_manager.target_score:,}", True, config.COLOR_TEXT_LIGHT)
        surface.blit(target_lbl, (60, 175))
        
        # Progress Bar
        pct = min(1.0, self.run_manager.round_score / max(1, self.run_manager.target_score))
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
        
        # Desk inventory Tropes (max 5)
        tropes_lbl = self.ui_bold.render("THE EDITOR'S TROPES (PASSIVES)", True, config.COLOR_TEXT_LIGHT)
        surface.blit(tropes_lbl, (40, 408))
        
        for idx in range(5):
            x = 40 + idx * 68
            y = 435
            slot_rect = pygame.Rect(x, y, 60, 60)
            pygame.draw.rect(surface, (20, 22, 30), slot_rect, border_radius=6)
            pygame.draw.rect(surface, config.COLOR_TEXT_MUTED, slot_rect, width=1, border_radius=6)
            
            if idx < len(self.run_manager.tropes):
                trope = self.run_manager.tropes[idx]
                # Draw trope item icon/text abbreviation
                initials = "".join([w[0] for w in trope.name.split() if w[0].isupper()])[:3]
                ini_surf = self.typewriter_font.render(initials, True, config.COLOR_ACCENT if trope.is_debuff_active else config.COLOR_CLUE_GREEN)
                ini_rect = ini_surf.get_rect(center=slot_rect.center)
                surface.blit(ini_surf, ini_rect)
                
        # Desk inventory Edits (max 2)
        edits_lbl = self.ui_bold.render("EDITS (CONSUMABLES)", True, config.COLOR_TEXT_LIGHT)
        surface.blit(edits_lbl, (40, 560))
        
        for idx in range(2):
            x = 40 + idx * 150
            y = 590
            slot_rect = pygame.Rect(x, y, 130, 70)
            pygame.draw.rect(surface, (20, 22, 30), slot_rect, border_radius=6)
            pygame.draw.rect(surface, config.COLOR_TEXT_MUTED, slot_rect, width=1, border_radius=6)
            
            if idx < len(self.run_manager.edits):
                edit = self.run_manager.edits[idx]
                edit_name_surf = self.ui_font.render(edit.name.replace("The ", ""), True, config.COLOR_TEXT_LIGHT)
                edit_rect = edit_name_surf.get_rect(center=(slot_rect.centerx, slot_rect.centery - 10))
                surface.blit(edit_name_surf, edit_rect)
                
                use_surf = self.tooltip_font.render("Click to use", True, config.COLOR_TEXT_MUTED)
                use_rect = use_surf.get_rect(center=(slot_rect.centerx, slot_rect.centery + 15))
                surface.blit(use_surf, use_rect)
                
        # 2. Draw Center Panel - Manuscript Paper
        paper_rect = pygame.Rect(400, 80, 440, 360)
        pygame.draw.rect(surface, (20, 20, 25), paper_rect.inflate(6, 6), border_radius=8)
        pygame.draw.rect(surface, config.COLOR_PAPER, paper_rect, border_radius=6)
        
        # Draw target word helper for testing/debugging or when Magnifying Glass reveals it
        # Let's render a faint typewriter label "Target" if debugging, but for gameplay it remains hidden.
        
        # Render manuscript history rows
        # History is list of dicts: {"word": str, "clues": list, "score": int, "is_draft": bool}
        # Render up to 5 rows of history
        row_y = 100
        for i, entry in enumerate(self.run_manager.round_history[-5:]):
            word = entry["word"]
            clues = entry["clues"]
            is_draft = entry["is_draft"]
            score = entry["score"]
            
            # Center coordinates for letters
            box_w = 40
            box_gap = 8
            word_len = len(word)
            total_w = word_len * box_w + (word_len - 1) * box_gap
            start_x = paper_rect.centerx - total_w // 2
            
            for l_idx, char in enumerate(word):
                clue = clues[l_idx]
                box_x = start_x + l_idx * (box_w + box_gap)
                box_rect = pygame.Rect(box_x, row_y, box_w, box_w)
                
                # Check colors
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
                
                # Letter (Contrast check)
                let_color = config.COLOR_TEXT_LIGHT if col != config.COLOR_CLUE_EMPTY else config.COLOR_TEXT_DARK
                let_surf = self.typewriter_font.render(char.upper(), True, let_color)
                let_rect = let_surf.get_rect(center=box_rect.center)
                surface.blit(let_surf, let_rect)
                
            # Score or draft text next to row
            if entry.get("is_plagiarized"):
                lbl_color = (231, 76, 60)
                lbl_str = "PLAGIARIZED"
            else:
                lbl_color = config.COLOR_ROYALTIES if not is_draft else config.COLOR_CLUE_YELLOW
                lbl_str = f"+{score:,}" if not is_draft else "DRAFT"
            lbl_surf = self.ui_font.render(lbl_str, True, lbl_color)
            surface.blit(lbl_surf, (start_x + total_w + 12, row_y + 10))
            
            row_y += 50
            
        # Draw Active Typed Input Boxes
        input_len = 4 if self.run_manager.boss_blind == "Minimalist" else 5
        box_w = 48
        box_gap = 10
        total_w = input_len * box_w + (input_len - 1) * box_gap
        start_x = paper_rect.centerx - total_w // 2
        input_y = 350
        
        for l_idx in range(input_len):
            box_x = start_x + l_idx * (box_w + box_gap)
            box_rect = pygame.Rect(box_x, input_y, box_w, box_w)
            
            # Render empty box
            pygame.draw.rect(surface, (230, 225, 215), box_rect, border_radius=4)
            pygame.draw.rect(surface, config.COLOR_TEXT_DARK, box_rect, width=2, border_radius=4)
            
            # Letter if typed
            if l_idx < len(self.current_input):
                char = self.current_input[l_idx]
                # If coffee ring is active on this letter, color the background of active entry slightly brown!
                bg_mods = self.run_manager.keyboard_mods.get(char, {})
                if bg_mods.get("coffee_ring", False):
                    pygame.draw.rect(surface, config.COLOR_CLUE_REDACTED, box_rect, border_radius=4)
                    
                let_surf = self.typewriter_lg.render(char.upper(), True, config.COLOR_TEXT_DARK)
                let_rect = let_surf.get_rect(center=box_rect.center)
                surface.blit(let_surf, let_rect)
                
        # 3. Draw Typewriter Keyboard at bottom
        kbd_x = 400
        kbd_y = 480
        key_size = 45
        key_gap = 8
        
        for r_idx, row in enumerate(self.kbd_rows):
            # Calculate staggered row offsets
            offset = 0
            if r_idx == 1:
                offset = 20
            elif r_idx == 2:
                offset = 40
                
            for k_idx, char in enumerate(row):
                key_x = kbd_x + offset + k_idx * (key_size + key_gap)
                key_y = kbd_y + r_idx * (key_size + key_gap)
                key_rect = pygame.Rect(key_x, key_y, key_size, key_size)
                
                # Check modifications
                mods = self.run_manager.keyboard_mods.get(char, {})
                is_highlighter = mods.get("highlighter", False)
                is_coffee_ring = mods.get("coffee_ring", False)
                is_stapler = mods.get("stapler", False)
                is_removed = mods.get("removed", False)
                
                clue_state = self.key_discoveries.get(char, "empty")
                
                # Determine body color
                if is_removed:
                    bg_color = (20, 20, 25)
                    border_color = (40, 42, 50)
                else:
                    if clue_state == "green":
                        bg_color = config.COLOR_CLUE_GREEN
                    elif clue_state == "yellow":
                        bg_color = config.COLOR_CLUE_YELLOW
                    elif clue_state == "grey":
                        bg_color = config.COLOR_CLUE_GREY
                    else:
                        bg_color = config.COLOR_PANEL
                    border_color = config.COLOR_TEXT_LIGHT
                    
                # Render key body
                pygame.draw.rect(surface, bg_color, key_rect, border_radius=5)
                
                # Render stickers
                if is_highlighter and not is_removed:
                    # Highlighter yellow aura
                    pygame.draw.rect(surface, config.COLOR_HIGHLIGHTER, key_rect, width=3, border_radius=5)
                if is_coffee_ring and not is_removed:
                    # Coffee ring stain outline inside
                    pygame.draw.circle(surface, config.COLOR_CLUE_REDACTED, key_rect.center, 12, width=3)
                if is_stapler and not is_removed:
                    # Draw staple lines across the key top and bottom
                    pygame.draw.line(surface, (180, 180, 190), (key_rect.x + 8, key_rect.y + 6), (key_rect.right - 8, key_rect.y + 6), 2)
                    pygame.draw.line(surface, (180, 180, 190), (key_rect.x + 8, key_rect.bottom - 6), (key_rect.right - 8, key_rect.bottom - 6), 2)
                    
                pygame.draw.rect(surface, border_color, key_rect, width=1, border_radius=5)
                
                # Draw character
                if not is_removed:
                    text_color = config.COLOR_TEXT_LIGHT if clue_state == "empty" else config.COLOR_TEXT_LIGHT
                    let_surf = self.ui_font.render(char.upper(), True, text_color)
                    let_rect = let_surf.get_rect(center=key_rect.center)
                    surface.blit(let_surf, let_rect)
                else:
                    # Draw an X inside key to show it is permanently gone
                    pygame.draw.line(surface, config.COLOR_ACCENT, (key_rect.x + 8, key_rect.y + 8), (key_rect.right - 8, key_rect.bottom - 8), 2)
                    pygame.draw.line(surface, config.COLOR_ACCENT, (key_rect.right - 8, key_rect.y + 8), (key_rect.x + 8, key_rect.bottom - 8), 2)

        # 4. Draw error messages / warnings
        if self.error_timer > 0 and self.error_message:
            err_box = pygame.Rect(400, 20, 440, 45)
            pygame.draw.rect(surface, (30, 20, 20), err_box, border_radius=6)
            pygame.draw.rect(surface, config.COLOR_ACCENT, err_box, width=2, border_radius=6)
            
            err_surf = self.ui_bold.render(self.error_message, True, config.COLOR_TEXT_LIGHT)
            err_rect = err_surf.get_rect(center=err_box.center)
            surface.blit(err_surf, err_rect)

        # 5. Draw buttons
        for btn in self.buttons:
            btn.draw(surface)

    def draw_tooltip(self, surface, tooltip):
        title = tooltip["title"]
        desc = tooltip["desc"]
        debuff = tooltip["debuff"]
        mx, my = tooltip["pos"]
        
        # Position tooltip rect near cursor
        w, h = 300, 110
        tx = min(config.SCREEN_WIDTH - w - 20, max(20, mx + 15))
        ty = min(config.SCREEN_HEIGHT - h - 20, max(20, my + 15))
        
        tooltip_rect = pygame.Rect(tx, ty, w, h)
        pygame.draw.rect(surface, (20, 22, 30), tooltip_rect, border_radius=8)
        pygame.draw.rect(surface, config.COLOR_TEXT_MUTED, tooltip_rect, width=2, border_radius=8)
        
        # Render text
        t_surf = self.ui_bold.render(title, True, config.COLOR_TEXT_LIGHT)
        surface.blit(t_surf, (tx + 12, ty + 10))
        
        # Word wrap description
        desc_words = desc.split()
        lines = []
        curr_line = ""
        for word in desc_words:
            if len(curr_line + " " + word) < 36:
                curr_line += (" " if curr_line else "") + word
            else:
                lines.append(curr_line)
                curr_line = word
        if curr_line:
            lines.append(curr_line)
            
        y_off = ty + 35
        for line in lines[:2]:
            l_surf = self.tooltip_font.render(line, True, config.COLOR_TEXT_LIGHT)
            surface.blit(l_surf, (tx + 12, y_off))
            y_off += 16
            
        d_surf = self.tooltip_font.render(debuff, True, config.COLOR_ACCENT)
        surface.blit(d_surf, (tx + 12, ty + 85))
