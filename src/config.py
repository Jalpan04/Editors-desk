import os
import pygame

# Screen settings
SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720
FPS = 60

# Palette - HSL-tailored colors
COLOR_DESK = (28, 30, 38)          # Dark slate desk surface
COLOR_PANEL = (39, 42, 54)         # Elevated panel color
COLOR_PAPER = (248, 245, 237)       # Warm off-white manuscript paper
COLOR_TEXT_DARK = (44, 44, 44)      # Ink black text
COLOR_TEXT_LIGHT = (240, 240, 240)  # Bright text for UI on dark backgrounds
COLOR_TEXT_MUTED = (120, 125, 140)  # Secondary text

# Color Clues (Wordle)
COLOR_CLUE_GREEN = (46, 180, 110)   # Vibrant emerald
COLOR_CLUE_YELLOW = (220, 165, 30)  # Amber gold
COLOR_CLUE_GREY = (140, 145, 155)   # Typewriter carbon grey
COLOR_CLUE_REDACTED = (130, 85, 45) # Coffee ring brown
COLOR_CLUE_EMPTY = (210, 205, 195)  # Empty letter box on paper

# Accent Colors
COLOR_ACCENT = (230, 90, 90)        # Electric red pen red
COLOR_ROYALTIES = (50, 200, 140)    # Green currency color
COLOR_HIGHLIGHTER = (250, 230, 50)  # Translucent highlighter yellow

# Path configuration
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS_DIR = os.path.join(BASE_DIR, "assets", "fonts")
AUDIO_DIR = os.path.join(BASE_DIR, "assets", "audio")

# Fonts Initialization helper
def get_font(name, size):
    """
    Returns a pygame Font object.
    Tries to load local asset, falls back to system font.
    """
    if name == "typewriter":
        font_path = os.path.join(FONTS_DIR, "SpecialElite.ttf")
        if os.path.exists(font_path):
            return pygame.font.Font(font_path, size)
        else:
            # Fallback to standard monospace if Special Elite is missing
            return pygame.font.SysFont("Courier New", size, bold=True)
    else:  # "sans"
        font_path = os.path.join(FONTS_DIR, "Roboto-Regular.ttf")
        if os.path.exists(font_path):
            return pygame.font.Font(font_path, size)
        else:
            # Fallback to Segoe UI, Arial, or Helvetica
            for system_name in ["segoeui", "arial", "helvetica", "sans-serif"]:
                try:
                    # check if font exists
                    font = pygame.font.SysFont(system_name, size)
                    if font:
                        return font
                except:
                    continue
            return pygame.font.Font(None, size)

def get_font_bold(size):
    font_path = os.path.join(FONTS_DIR, "Roboto-Bold.ttf")
    if os.path.exists(font_path):
        return pygame.font.Font(font_path, size)
    else:
        for system_name in ["segoeui", "arial", "helvetica"]:
            try:
                font = pygame.font.SysFont(system_name, size, bold=True)
                if font:
                    return font
            except:
                continue
        return pygame.font.Font(None, size)

# Global sound manager reference (will be linked at startup by sound_manager.init)
sounds = None
