import pygame
import random
from src import config
from src.engine.state_machine import State
from src.engine.ui import Button, ParticleSystem
from src.content.style_guides import StyleGuideUpgrade, STYLE_GUIDES_DATA
from src.content.tropes import create_all_tropes
from src.content.edits import create_all_edits

class ShopState(State):
    def __init__(self, state_machine, run_manager):
        super().__init__(state_machine, run_manager)
        
        self.buttons = []
        self.particles = ParticleSystem()
        
        self.title_font = config.get_font("typewriter", 36)
        self.label_font = config.get_font("sans", 20)
        self.desc_font = config.get_font("sans", 14)
        self.stat_font = config.get_font("sans", 24)
        self.prompt_font = config.get_font("typewriter", 22)
        
        # Shop items (list of dicts: {"type": str, "item_obj": obj, "price": int, "sold": bool})
        self.shop_items = []
        
        # Keyboard modification flow state
        # "none", "highlighter", "coffee_ring", "stapler_1", "stapler_2"
        self.pending_sticker = "none"
        self.stapler_first_key = None
        
        # QWERTY keys layout for rendering & clicking
        self.kbd_rows = [
            ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
            ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
            ['z', 'x', 'c', 'v', 'b', 'n', 'm']
        ]

    def enter(self, **kwargs):
        self.pending_sticker = "none"
        self.stapler_first_key = None
        self.buttons.clear()
        
        # Roll Shop Inventory
        self.roll_shop()
        
        # Add Next Blind button at top right
        self.buttons.append(Button(
            x=config.SCREEN_WIDTH - 220,
            y=15,
            width=190,
            height=40,
            text="Next Assignment",
            callback=self.next_assignment,
            color=(46, 180, 110) # Green
        ))

    def next_assignment(self):
        # Proceed back to blind select screen
        self.state_machine.change_state("blind_select")

    def roll_shop(self):
        self.shop_items.clear()
        
        # 1. Card 1: Style Guide upgrade
        patterns = list(STYLE_GUIDES_DATA.keys())
        pat = random.choice(patterns)
        self.shop_items.append({
            "type": "style_guide",
            "item_obj": StyleGuideUpgrade(pat),
            "price": STYLE_GUIDES_DATA[pat]["price"],
            "sold": False
        })
        
        # 2. Card 2: Trope (random)
        tropes = create_all_tropes()
        # Filter out already owned tropes
        owned_names = {t.name for t in self.run_manager.tropes}
        available_tropes = [t for t in tropes if t.name not in owned_names]
        
        if available_tropes:
            trope = random.choice(available_tropes)
        else:
            trope = tropes[0] # Fallback
        self.shop_items.append({
            "type": "trope",
            "item_obj": trope,
            "price": trope.price,
            "sold": False
        })
        
        # 3. Card 3: Edit consumable
        edits = create_all_edits()
        edit = random.choice(edits)
        self.shop_items.append({
            "type": "edit",
            "item_obj": edit,
            "price": edit.price,
            "sold": False
        })
        
        # 4. Card 4: Keyboard sticker mod
        stickers = [
            {"name": "Yellow Highlighter", "desc": "Played key gives permanent +15 Mult.", "type": "highlighter", "price": 3},
            {"name": "Coffee Mug Ring", "desc": "Played key gives +50 chips. clue color redacted.", "type": "coffee_ring", "price": 3},
            {"name": "The Stapler", "desc": "Staples two keys. They score twice, but must be played together.", "type": "stapler", "price": 4}
        ]
        sticker = random.choice(stickers)
        self.shop_items.append({
            "type": "sticker",
            "item_obj": sticker,
            "price": sticker["price"],
            "sold": False
        })

    def buy_item(self, idx):
        if self.pending_sticker != "none":
            return # Block buying during sticker placement
            
        item_data = self.shop_items[idx]
        if item_data["sold"]:
            return
            
        if self.run_manager.royalties < item_data["price"]:
            config.sounds.play("error")
            return
            
        # Execute purchases
        itype = item_data["type"]
        obj = item_data["item_obj"]
        
        if itype == "style_guide":
            # Apply upgrade
            msg = obj.use(self.run_manager)
            self.run_manager.royalties -= item_data["price"]
            item_data["sold"] = True
            config.sounds.play("buy")
            self.particles.spawn(220 + idx * 260, 280, config.COLOR_ROYALTIES, 15)
            
        elif itype == "trope":
            # Add to active tropes
            if len(self.run_manager.tropes) >= 5:
                config.sounds.play("error")
                return # Inventory full
            self.run_manager.tropes.append(obj)
            obj.on_equip(self.run_manager)
            self.run_manager.royalties -= item_data["price"]
            item_data["sold"] = True
            config.sounds.play("buy")
            self.particles.spawn(220 + idx * 260, 280, config.COLOR_ACCENT, 15)
            
        elif itype == "edit":
            # Add to active edits
            if len(self.run_manager.edits) >= 2:
                config.sounds.play("error")
                return # Inventory full
            self.run_manager.edits.append(obj)
            self.run_manager.royalties -= item_data["price"]
            item_data["sold"] = True
            config.sounds.play("buy")
            self.particles.spawn(220 + idx * 260, 280, config.COLOR_ROYALTIES, 15)
            
        elif itype == "sticker":
            # Enter keyboard modification mode
            stype = obj["type"]
            self.pending_sticker = stype
            self.run_manager.royalties -= item_data["price"]
            item_data["sold"] = True
            config.sounds.play("buy")

    def handle_events(self, events):
        mpos = pygame.mouse.get_pos()
        for btn in self.buttons:
            btn.check_hover(mpos)
            
        for event in events:
            # Handle Next Assignment click
            for btn in self.buttons:
                if btn.handle_event(event, mpos):
                    break
                    
            # Handle Item Card purchase clicks
            if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                # Coordinate bounds for the 4 item cards
                # x positions: Card 0: 60, Card 1: 340, Card 2: 620, Card 3: 900
                # w=240, h=280. Button on card at bottom
                for idx in range(4):
                    card_x = 60 + idx * 280
                    card_y = 100
                    buy_rect = pygame.Rect(card_x + 30, card_y + 220, 180, 40)
                    if buy_rect.collidepoint(mpos):
                        self.buy_item(idx)
                        break
                        
                # Handle typewriter key clicks for sticker placement
                if self.pending_sticker != "none":
                    self.click_typewriter_key(mpos)

    def click_typewriter_key(self, mpos):
        # Keyboard position coordinates in shop screen (centered at bottom)
        kbd_x = 400
        kbd_y = 440
        key_size = 42
        key_gap = 8
        
        for r_idx, row in enumerate(self.kbd_rows):
            offset = 0
            if r_idx == 1:
                offset = 18
            elif r_idx == 2:
                offset = 36
                
            for k_idx, char in enumerate(row):
                key_x = kbd_x + offset + k_idx * (key_size + key_gap)
                key_y = kbd_y + r_idx * (key_size + key_gap)
                key_rect = pygame.Rect(key_x, key_y, key_size, key_size)
                
                if key_rect.collidepoint(mpos):
                    # Clicked key!
                    config.sounds.play("stamp")
                    
                    if self.pending_sticker == "highlighter":
                        self.run_manager.keyboard_mods[char]["highlighter"] = True
                        self.pending_sticker = "none"
                        self.particles.spawn(key_rect.centerx, key_rect.centery, config.COLOR_HIGHLIGHTER, 12)
                    elif self.pending_sticker == "coffee_ring":
                        self.run_manager.keyboard_mods[char]["coffee_ring"] = True
                        self.pending_sticker = "none"
                        self.particles.spawn(key_rect.centerx, key_rect.centery, config.COLOR_CLUE_REDACTED, 12)
                    elif self.pending_sticker == "stapler":
                        self.stapler_first_key = char
                        self.pending_sticker = "stapler_second"
                    elif self.pending_sticker == "stapler_second":
                        if char == self.stapler_first_key:
                            config.sounds.play("error")
                            return # Cannot staple a key to itself!
                        # Add staple binding
                        self.run_manager.keyboard_mods[self.stapler_first_key]["stapler"] = True
                        self.run_manager.keyboard_mods[char]["stapler"] = True
                        self.run_manager.stapled_pairs.append((self.stapler_first_key, char))
                        
                        self.pending_sticker = "none"
                        self.stapler_first_key = None
                        self.particles.spawn(key_rect.centerx, key_rect.centery, (160, 160, 180), 12)
                    break

    def update(self, dt):
        self.particles.update(dt)
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
        
        # Header title
        shop_surf = self.title_font.render("The Supply Closet", True, config.COLOR_TEXT_LIGHT)
        shop_rect = shop_surf.get_rect(center=(config.SCREEN_WIDTH // 2, 30))
        surface.blit(shop_surf, shop_rect)
        
        # Draw next blind button
        for btn in self.buttons:
            btn.draw(surface)
            
        # 2. Draw 4 Shop Cards
        for idx, item in enumerate(self.shop_items):
            card_x = 60 + idx * 280
            card_y = 100
            w, h = 260, 280
            
            rect = pygame.Rect(card_x, card_y, w, h)
            pygame.draw.rect(surface, config.COLOR_PANEL, rect, border_radius=10)
            
            if item["sold"]:
                # Draw SOLD visual overlay
                pygame.draw.rect(surface, (20, 20, 25), rect, border_radius=10)
                pygame.draw.rect(surface, config.COLOR_TEXT_MUTED, rect, width=2, border_radius=10)
                sold_surf = self.title_font.render("SOLD", True, config.COLOR_TEXT_MUTED)
                sold_rect = sold_surf.get_rect(center=rect.center)
                surface.blit(sold_surf, sold_rect)
                continue
                
            # Card contents
            obj = item["item_obj"]
            price = item["price"]
            
            # Title & details based on card type
            if item["type"] == "style_guide":
                title_text = obj.name.replace("Style Guide: ", "")
                type_lbl = "STYLE GUIDE"
                desc_text = obj.description.replace("Permanently levels up ", "Levels up ")
                col_accent = config.COLOR_CLUE_GREEN
            elif item["type"] == "trope":
                title_text = obj.name
                type_lbl = "TROPE (PASSIVE)"
                desc_text = obj.description
                col_accent = config.COLOR_ACCENT
            elif item["type"] == "edit":
                title_text = obj.name.replace("The ", "")
                type_lbl = "EDIT (CONSUMABLE)"
                desc_text = obj.description
                col_accent = config.COLOR_ROYALTIES
            else:  # sticker
                title_text = obj["name"]
                type_lbl = "KEYBOARD MOD"
                desc_text = obj["desc"]
                col_accent = config.COLOR_HIGHLIGHTER
                
            pygame.draw.rect(surface, col_accent, rect, width=2, border_radius=10)
            
            # Label
            type_surf = self.desc_font.render(type_lbl, True, col_accent)
            surface.blit(type_surf, (card_x + 20, card_y + 15))
            
            # Title
            title_surf = self.label_font.render(title_text, True, config.COLOR_TEXT_LIGHT)
            surface.blit(title_surf, (card_x + 20, card_y + 35))
            
            pygame.draw.line(surface, config.COLOR_TEXT_MUTED, (card_x + 20, card_y + 70), (card_x + w - 20, card_y + 70), 1)
            
            # Wrap description words
            words = desc_text.split()
            lines = []
            curr_line = ""
            for word in words:
                if len(curr_line + " " + word) < 28:
                    curr_line += (" " if curr_line else "") + word
                else:
                    lines.append(curr_line)
                    curr_line = word
            if curr_line:
                lines.append(curr_line)
                
            y_d = card_y + 90
            for line in lines[:5]:
                line_surf = self.desc_font.render(line, True, config.COLOR_TEXT_LIGHT)
                surface.blit(line_surf, (card_x + 20, y_d))
                y_d += 18
                
            # Draw Buy Button
            buy_btn_rect = pygame.Rect(card_x + 30, card_y + 220, 180, 40)
            # Check hover to color buy button
            mpos = pygame.mouse.get_pos()
            is_hover = buy_btn_rect.collidepoint(mpos)
            
            btn_col = col_accent if is_hover else (30, 32, 40)
            pygame.draw.rect(surface, btn_col, buy_btn_rect, border_radius=6)
            pygame.draw.rect(surface, col_accent, buy_btn_rect, width=2, border_radius=6)
            
            buy_str = f"Buy - ${price}"
            buy_surf = self.label_font.render(buy_str, True, config.COLOR_TEXT_LIGHT if is_hover else config.COLOR_TEXT_LIGHT)
            buy_rect = buy_surf.get_rect(center=buy_btn_rect.center)
            surface.blit(buy_surf, buy_rect)

        # 3. Draw Typewriter Keyboard at bottom (for applying stickers or review)
        kbd_x = 400
        kbd_y = 450
        key_size = 42
        key_gap = 8
        
        # If sticker pending, display typewriter keyboard to let the user select a key
        if self.pending_sticker != "none":
            # Display prompt overlay text
            if self.pending_sticker == "stapler_second":
                prompt_str = f"Click second key to staple to '{self.stapler_first_key.upper()}'!"
            else:
                prompt_str = "Click a key on the keyboard below to apply the sticker!"
                
            prompt_surf = self.prompt_font.render(prompt_str, True, config.COLOR_HIGHLIGHTER)
            prompt_rect = prompt_surf.get_rect(center=(config.SCREEN_WIDTH // 2, 415))
            surface.blit(prompt_surf, prompt_rect)
            
        else:
            review_surf = self.prompt_font.render("Your Typewriter Keyboard stickers:", True, config.COLOR_TEXT_MUTED)
            review_rect = review_surf.get_rect(center=(config.SCREEN_WIDTH // 2, 415))
            surface.blit(review_surf, review_rect)

        for r_idx, row in enumerate(self.kbd_rows):
            offset = 0
            if r_idx == 1:
                offset = 18
            elif r_idx == 2:
                offset = 36
                
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
                
                # Render key
                pygame.draw.rect(surface, bg_color, key_rect, border_radius=4)
                
                # Highlight when modifying
                if self.pending_sticker != "none":
                    mpos = pygame.mouse.get_pos()
                    if key_rect.collidepoint(mpos):
                        border_color = config.COLOR_HIGHLIGHTER
                        
                # Draw stickers
                if is_highlighter and not is_removed:
                    pygame.draw.rect(surface, config.COLOR_HIGHLIGHTER, key_rect, width=2, border_radius=4)
                if is_coffee_ring and not is_removed:
                    pygame.draw.circle(surface, config.COLOR_CLUE_REDACTED, key_rect.center, 10, width=2)
                if is_stapler and not is_removed:
                    pygame.draw.line(surface, (180, 180, 190), (key_rect.x + 6, key_rect.y + 4), (key_rect.right - 6, key_rect.y + 4), 2)
                    pygame.draw.line(surface, (180, 180, 190), (key_rect.x + 6, key_rect.bottom - 4), (key_rect.right - 6, key_rect.bottom - 4), 2)
                    
                pygame.draw.rect(surface, border_color, key_rect, width=1, border_radius=4)
                
                if not is_removed:
                    let_surf = self.desc_font.render(char.upper(), True, config.COLOR_TEXT_LIGHT)
                    let_rect = let_surf.get_rect(center=key_rect.center)
                    surface.blit(let_surf, let_rect)
                else:
                    # Removed
                    pygame.draw.line(surface, config.COLOR_ACCENT, (key_rect.x + 6, key_rect.y + 6), (key_rect.right - 6, key_rect.bottom - 6), 2)
                    pygame.draw.line(surface, config.COLOR_ACCENT, (key_rect.right - 6, key_rect.y + 6), (key_rect.x + 6, key_rect.bottom - 6), 2)

        # Draw particles
        self.particles.draw(surface)
