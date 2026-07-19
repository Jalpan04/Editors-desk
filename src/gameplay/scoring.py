import os
from src.engine import event_bus

# Base chip values for each letter
LETTER_CHIPS = {
    'e': 1, 't': 1, 'a': 1, 'o': 1, 'i': 1, 'n': 1, 's': 1,
    'h': 2, 'r': 2, 'd': 2, 'l': 2,
    'c': 3, 'u': 3, 'm': 3, 'w': 3, 'f': 3, 'g': 3, 'y': 3,
    'p': 4, 'b': 4, 'v': 4, 'k': 4,
    'j': 8, 'x': 8, 'q': 10, 'z': 10
}

def check_word(guess, target):
    """
    Wordle comparison algorithm that correctly handles duplicate letters.
    Returns a list of clues: 'green', 'yellow', or 'grey'.
    """
    guess = guess.lower()
    target = target.lower()
    length = len(guess)
    clues = ['grey'] * length
    
    target_matched = [False] * length
    guess_matched = [False] * length
    
    # First pass: find exact matches (green)
    for i in range(length):
        if guess[i] == target[i]:
            clues[i] = 'green'
            target_matched[i] = True
            guess_matched[i] = True
            
    # Second pass: find partial matches (yellow)
    for i in range(length):
        if not guess_matched[i]:
            for j in range(length):
                if not target_matched[j] and guess[i] == target[j]:
                    clues[i] = 'yellow'
                    target_matched[j] = True
                    break
                    
    return clues

def identify_pattern(clues, guess, target):
    """
    Identifies the feedback pattern category of the submission.
    """
    green_count = clues.count('green')
    yellow_count = clues.count('yellow')
    grey_count = clues.count('grey')

    if green_count == 5:
        return "Masterpiece"
    elif yellow_count == 5:
        return "Jumble"
    elif green_count == 1 and grey_count == 4:
        return "Shot in the Dark"
    elif grey_count == 5:
        return "Total Rewrite"
    else:
        return "Standard Submission"

class ScoreManager:
    def __init__(self):
        self.chips = 0
        self.mult = 0.0
        self.x_mults = []  # List of multiplicative multipliers (e.g. x1.5, x3.0)

    def add_chips(self, amount):
        self.chips += amount

    def add_mult(self, amount):
        self.mult += amount

    def add_x_mult(self, multiplier):
        self.x_mults.append(multiplier)

    def calculate_total(self):
        """Calculates final score: Chips * (Mult * Product of x_mults)"""
        total_mult = self.mult
        for xm in self.x_mults:
            total_mult *= xm
        # Multiplier cannot fall below 1
        total_mult = max(1.0, total_mult)
        return int(self.chips * total_mult)

def calculate_word_score(guess, target, style_guides_levels, keyboard_mods, boss_blind=None):
    """
    Calculates the detailed score for a word.
    
    style_guides_levels: dict of {"PatternName": level_int}
    keyboard_mods: dict of {"letter": {"highlighter": bool, "coffee_ring": bool, "stapler": bool}}
    """
    guess = guess.lower()
    target = target.lower()
    clues = check_word(guess, target)
    pattern_name = identify_pattern(clues, guess, target)
    
    # Plagiarist Boss Blind Jumble exploit prevention
    if boss_blind == "Plagiarist" and pattern_name == "Jumble":
        pattern_name = "Standard Submission"
        
    score_mgr = ScoreManager()
    
    # 1. Base Score from Style Guide / Pattern Level
    pattern_bases = {
        "Masterpiece": {"chips": 250, "mult": 8.0, "level_chips": 80, "level_mult": 6.0},
        "Jumble": {"chips": 100, "mult": 4.0, "level_chips": 40, "level_mult": 4.0},
        "Shot in the Dark": {"chips": 20, "mult": 2.0, "level_chips": 15, "level_mult": 2.0},
        "Total Rewrite": {"chips": 50, "mult": 1.0, "level_chips": 30, "level_mult": 3.0},
        "Standard Submission": {"chips": 10, "mult": 1.0, "level_chips": 10, "level_mult": 1.0}
    }
    
    base_info = pattern_bases[pattern_name]
    level = style_guides_levels.get(pattern_name, 1)
    
    # Base = Starting Value + (Level - 1) * Level Increment
    base_chips = base_info["chips"] + (level - 1) * base_info["level_chips"]
    base_mult = base_info["mult"] + (level - 1) * base_info["level_mult"]
    
    score_mgr.add_chips(base_chips)
    score_mgr.add_mult(base_mult)
    
    # 2. Score Individual Letters
    for i, letter in enumerate(guess):
        clue = clues[i]
        
        # Check keyboard mods for this letter
        mods = keyboard_mods.get(letter, {})
        is_highlighted = mods.get("highlighter", False)
        is_coffee_ring = mods.get("coffee_ring", False)
        is_stapled = mods.get("stapler", False)
        
        # Stapler causes the letter's scoring to trigger twice
        repeat_count = 2 if is_stapled else 1
        
        for _ in range(repeat_count):
            # Letter base points: equal for all characters, decided only by clue color:
            # green=5, yellow=1, grey=0
            if clue == 'green':
                let_chips = 5
            elif clue == 'yellow':
                let_chips = 1
            else:
                let_chips = 0
                
            # Add mods bonuses
            if is_highlighted:
                score_mgr.add_mult(15.0)
            if is_coffee_ring:
                score_mgr.add_chips(50)
                
            # Add letter chips
            score_mgr.add_chips(let_chips)
                
        # Fire event for letter-level custom adjustments (e.g. from Tropes)
        event_bus.bus.publish('ON_LETTER_SCORED', letter, i, clue, score_mgr)
        
    # 3. Fire event for overall word-level adjustments (e.g. Plot Twist, Red Pen)
    event_bus.bus.publish('ON_SCORE_CALCULATED', score_mgr, guess, clues, pattern_name)
    
    final_score = score_mgr.calculate_total()
    return {
        "score": final_score,
        "chips": score_mgr.chips,
        "mult": score_mgr.mult,
        "x_mults": score_mgr.x_mults,
        "clues": clues,
        "pattern": pattern_name
    }
