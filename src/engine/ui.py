import pygame
import random
import math
from src import config

def get_scale_rect(window_w, window_h, target_aspect=16/9):
    """Computes the destination rect to scale the virtual surface in the window."""
    window_aspect = window_w / window_h
    if window_aspect > target_aspect:
        h = window_h
        w = int(h * target_aspect)
        x = (window_w - w) // 2
        y = 0
    else:
        w = window_w
        h = int(w / target_aspect)
        x = 0
        y = (window_h - h) // 2
    return pygame.Rect(x, y, w, h)

def window_to_game_coords(win_pos, rect):
    """Maps mouse coordinates from the scaled window back to virtual coordinates (1280x720)."""
    rx, ry = win_pos
    rx -= rect.x
    ry -= rect.y
    # Prevent divide by zero
    rw = max(1, rect.w)
    rh = max(1, rect.h)
    game_x = int(rx * config.SCREEN_WIDTH / rw)
    game_y = int(ry * config.SCREEN_HEIGHT / rh)
    return game_x, game_y


class ScreenShake:
    def __init__(self):
        self.intensity = 0
        self.duration = 0.0
        self.timer = 0.0

    def trigger(self, intensity, duration):
        self.intensity = intensity
        self.duration = duration
        self.timer = duration

    def update(self, dt):
        if self.timer > 0:
            self.timer -= dt
            if self.timer <= 0:
                self.intensity = 0
                self.timer = 0.0

    def get_offset(self):
        if self.timer > 0:
            # Linear decay
            pct = self.timer / self.duration
            current_int = self.intensity * pct
            if current_int >= 1:
                dx = random.randint(-int(current_int), int(current_int))
                dy = random.randint(-int(current_int), int(current_int))
                return dx, dy
        return 0, 0


class Particle:
    def __init__(self, x, y, color, size=None):
        self.x = x
        self.y = y
        self.color = color
        self.size = size if size else random.randint(3, 6)
        self.vx = random.uniform(-150, 150)
        self.vy = random.uniform(-300, -50)  # Launch upwards
        self.gravity = 500  # pixels/s^2
        self.life = random.uniform(0.5, 1.0)
        self.max_life = self.life

    def update(self, dt):
        self.vy += self.gravity * dt
        self.x += self.vx * dt
        self.y += self.vy * dt
        self.life -= dt

    def draw(self, surface):
        if self.life > 0:
            alpha = int(255 * (self.life / self.max_life))
            # Handle alpha color in Pygame
            s = pygame.Surface((self.size * 2, self.size * 2), pygame.SRCALPHA)
            pygame.draw.circle(s, (*self.color, alpha), (self.size, self.size), self.size)
            surface.blit(s, (int(self.x - self.size), int(self.y - self.size)))


class ParticleSystem:
    def __init__(self):
        self.particles = []

    def spawn(self, x, y, color, count=10):
        for _ in range(count):
            self.particles.append(Particle(x, y, color))

    def update(self, dt):
        for p in self.particles:
            p.update(dt)
        self.particles = [p for p in self.particles if p.life > 0]

    def draw(self, surface):
        for p in self.particles:
            p.draw(surface)


class Button:
    def __init__(self, x, y, width, height, text, callback, color=config.COLOR_PANEL, text_color=config.COLOR_TEXT_LIGHT, font_type="sans", font_size=24):
        self.rect = pygame.Rect(x, y, width, height)
        self.text = text
        self.callback = callback
        self.base_color = color
        self.hover_color = tuple(min(255, c + 25) for c in color)
        self.text_color = text_color
        self.font = config.get_font(font_type, font_size)
        self.is_hovered = False
        self.hover_progress = 0.0  # For smooth transitions

    def check_hover(self, mouse_pos):
        self.is_hovered = self.rect.collidepoint(mouse_pos)

    def handle_event(self, event, mouse_pos):
        if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
            if self.rect.collidepoint(mouse_pos):
                config.sounds.play("buy")
                self.callback()
                return True
        return False

    def update(self, dt):
        # Smoothly transition hover state
        if self.is_hovered:
            self.hover_progress = min(1.0, self.hover_progress + dt * 8)
        else:
            self.hover_progress = max(0.0, self.hover_progress - dt * 8)

    def draw(self, surface):
        # Interpolate color based on hover progress
        r = int(self.base_color[0] + (self.hover_color[0] - self.base_color[0]) * self.hover_progress)
        g = int(self.base_color[1] + (self.hover_color[1] - self.base_color[1]) * self.hover_progress)
        b = int(self.base_color[2] + (self.hover_color[2] - self.base_color[2]) * self.hover_progress)
        
        # Render shadow
        shadow_rect = self.rect.copy()
        shadow_rect.y += 4
        pygame.draw.rect(surface, (15, 15, 20), shadow_rect, border_radius=6)
        
        # Render main body (slightly shifted up if hovered for bounce look)
        body_rect = self.rect.copy()
        body_rect.y -= int(self.hover_progress * 2)
        pygame.draw.rect(surface, (r, g, b), body_rect, border_radius=6)
        
        # Draw border
        border_color = tuple(min(255, c + 40) for c in self.base_color) if not self.is_hovered else config.COLOR_HIGHLIGHTER
        pygame.draw.rect(surface, border_color, body_rect, width=2, border_radius=6)
        
        # Draw text
        text_surf = self.font.render(self.text, True, self.text_color)
        text_rect = text_surf.get_rect(center=body_rect.center)
        surface.blit(text_surf, text_rect)
