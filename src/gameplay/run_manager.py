import os
import random
from src.engine import event_bus
from src.gameplay.dictionary import Dictionary
from src.gameplay.scoring import check_word, calculate_word_score

class RunManager:
    def __init__(self, data_dir="data"):
        self.dictionary = Dictionary(data_dir)
        
        # Persistent Run State
        self.royalties = 4          # Starting money ($4)
        self.chapter = 1            # Starting Ante (Chapter 1)
        self.blind_index = 0        # 0: Small Blind, 1: Big Blind, 2: Boss Blind
        self.blind_type = "small"   # "small", "big", "boss"
        self.target_score = 500     # Score needed to win current blind
        
        self.tropes = []            # Active Tropes (max 5)
        self.edits = []             # Active consumable Edits (max 2)
        
        # Keyboard modifiers
        # For each letter 'a'-'z', tracks active mods: {"highlighter": bool, "coffee_ring": bool, "stapler": bool}
        self.keyboard_mods = {chr(c): {"highlighter": False, "coffee_ring": False, "stapler": False} for c in range(97, 123)}
        self.stapled_pairs = []     # List of sets/tuples of stapled keys, e.g., [('t', 'h')]
        
        # Style Guide Upgrade levels (default level 1)
        self.style_guides = {
            "Masterpiece": 1,
            "Jumble": 1,
            "Shot in the Dark": 1,
            "Total Rewrite": 1,
            "Standard Submission": 1
        }
        
        # Key status tracking for the current round (highest clue state discovered)
        # letter -> "green", "yellow", "grey", "empty"
        self.key_discoveries = {chr(c): "empty" for c in range(97, 123)}
        
        # Current Round State
        self.round_score = 0
        self.submissions_max = 4
        self.submissions_left = 4
        self.drafts_max = 2
        self.drafts_left = 2
        self.target_word = ""
        self.round_history = []     # List of dicts: {"word": str, "clues": list, "score": int, "is_draft": bool}
        
        # Boss Blind state
        self.boss_blind = None      # Current Boss Blind name: "Minimalist", "Plagiarist", "Ghostwriter", or None
        self.boss_pool = ["Minimalist", "Plagiarist", "Ghostwriter"]
        self.selected_boss = "Minimalist"  # The boss chosen for the current Chapter's end
        
        # Red Pen modifications
        self.red_pen_green_bonus = 0  # Permanent green letter chip bonus added by Red Pen
        
        # Choose initial boss blind for Chapter 1
        self.roll_boss_blind()

    def roll_boss_blind(self):
        """Rolls a random boss blind for the current chapter."""
        self.selected_boss = random.choice(self.boss_pool)

    def get_blind_name(self):
        if self.blind_index == 0:
            return "Small Blind"
        elif self.blind_index == 1:
            return "Big Blind"
        else:
            return f"Boss: {self.selected_boss}"

    def update_target_score(self):
        
        chapter_bases = [0, 500, 1500, 4000, 10000, 25000, 60000, 120000, 250000]
        base = chapter_bases[min(self.chapter, 8)]
        
        if self.blind_index == 0:
            self.target_score = base
            self.blind_type = "small"
            self.boss_blind = None
        elif self.blind_index == 1:
            self.target_score = int(base * 1.6)
            self.blind_type = "big"
            self.boss_blind = None
        else:
            self.target_score = int(base * 2.4)
            self.blind_type = "boss"
            self.boss_blind = self.selected_boss

        # Debuff from Ghostwriter Trope: Target Score increases by 1.5x
        if any(t.name == "The Ghostwriter" and t.is_debuff_active for t in self.tropes):
            self.target_score = int(self.target_score * 1.5)

    def start_round(self):
        """Initializes a new round, resetting submissions, drafts, and picking a target word."""
        self.round_score = 0
        self.round_history = []
        self.key_discoveries = {chr(c): "empty" for c in range(97, 123)}
        
        # Enforce Red Pen limits: lose 1 submission
        self.submissions_max = 4
        if any(t.name == "The Red Pen" and t.is_debuff_active for t in self.tropes):
            self.submissions_max = 3
            
        self.submissions_left = self.submissions_max
        self.drafts_left = self.drafts_max
        
        # Select target word
        # If boss is Minimalist, target word must be 4 letters long!
        if self.boss_blind == "Minimalist":
            # Generate a 4-letter word from target_words (truncate or select 4-letter)
            # Since standard wordlist contains 5-letter words, let's filter for 4-letter words or select a 4-letter target
            self.target_word = self.get_4_letter_target()
        else:
            self.target_word = self.dictionary.get_random_target()
            
        event_bus.bus.publish('ON_ROUND_START')

    def get_4_letter_target(self):
        """Generates or selects a 4-letter target word for the Minimalist Boss Blind."""
        # Let's extract 4-letter words from standard word list or create a pool
        words_4 = ["book", "page", "edit", "plot", "word", "desk", "read", "type", "inked", "bind"]
        # Strip to 4 letters to be safe
        words_4 = [w[:4].lower() for w in words_4]
        return random.choice(words_4)

    def submit_word(self, guess, is_draft=False):
        """
        Processes a guess, updates history, scores it (if not draft), and consumes resources.
        Returns a dict with clue results and score details.
        """
        guess = guess.lower().strip()
        
        # Validity checks
        if self.boss_blind == "Minimalist":
            if len(guess) != 4:
                return {"error": "Must submit a 4-letter word!"}
        else:
            if len(guess) != 5:
                return {"error": "Must submit a 5-letter word!"}
                
        # Plagiarism check (Hard Ban)
        # Checking if word was already submitted in this round as a real submission
        previous_submissions = {entry["word"] for entry in self.round_history if not entry.get("is_draft", False)}
        if not is_draft and guess in previous_submissions:
            # Plagiarized! Consumes a submission, awards 0 points, records in history.
            self.submissions_left -= 1
            clues = check_word(guess, self.target_word)
            result = {
                "score": 0,
                "chips": 0,
                "mult": 1.0,
                "x_mults": [],
                "clues": clues,
                "pattern": "Plagiarized"
            }
            self.round_history.append({
                "word": guess,
                "clues": clues,
                "is_draft": False,
                "score": 0,
                "is_plagiarized": True
            })
            return result
                
        # Wildcard check (Ghostwriter Trope)
        is_ghostwriter_active = any(t.name == "The Ghostwriter" for t in self.tropes)
        if is_ghostwriter_active:
            wildcard_count = guess.count('*')
            if wildcard_count > 2:
                return {"error": "Ghostwriter exploit! Max 2 wildcards allowed per submission."}
        
        # Validate against dictionary (if no wildcards or if we check letters)
        if not is_ghostwriter_active or "*" not in guess:
            # For Minimalist, we accept common 4 letter words or allow any guess for flexibility
            if self.boss_blind == "Minimalist":
                pass # Accept 4-letter guess
            elif not self.dictionary.is_valid_guess(guess):
                return {"error": "Not in word list!"}

        # Check stapled keys debuff
        # If one stapled key is played, the other MUST be played in the same word
        for pair in self.stapled_pairs:
            letter1, letter2 = pair
            has1 = letter1 in guess
            has2 = letter2 in guess
            if (has1 and not has2) or (has2 and not has1):
                return {"error": f"Stapled keys! Must play '{letter1.upper()}' and '{letter2.upper()}' together."}

        # Check Plot Twist trope debuff
        if any(t.name == "The Plot Twist" and t.is_debuff_active for t in self.tropes):
            if 'e' in guess:
                return {"error": "Plot Twist debuff! Cannot play words containing 'E'."}

        # Check Purple Prose trope debuff
        if any(t.name == "Purple Prose" and t.is_debuff_active for t in self.tropes):
            vowels = sum(1 for char in guess if char in "aeiou")
            if vowels < 2:
                return {"error": "Purple Prose debuff! Must use at least 2 vowels."}

        # Check Red Pen trope debuff
        # Grey letters are permanently removed from the keyboard
        if any(t.name == "The Red Pen" and t.is_debuff_active for t in self.tropes):
            # Find which letters were previously marked grey in this round/run
            # We can check if the guess contains any letter that was marked grey
            # Let's track removed letters in self.keyboard_mods or run state.
            for char in guess:
                if self.keyboard_mods.get(char, {}).get("removed", False):
                    return {"error": f"Red Pen debuff! Letter '{char.upper()}' has been removed."}

        # Handle Boss Blind: The Plagiarist
        # Target word is guaranteed to be an anagram of the very first word submitted.
        if self.boss_blind == "Plagiarist" and len(self.round_history) == 0 and not is_draft:
            # We set the target word to an anagram of the first guess!
            self.target_word = self.get_plagiarist_anagram(guess)

        # Run scoring/comparison
        # For wildcard matches, replace '*' in guess with matching letter in target
        eval_guess = list(guess)
        if is_ghostwriter_active:
            for idx in range(len(guess)):
                if idx < len(self.target_word) and guess[idx] == '*':
                    eval_guess[idx] = self.target_word[idx]
        eval_guess_str = "".join(eval_guess)

        clues = check_word(eval_guess_str, self.target_word)
        
        # Apply Red Pen: grey letters turn removed, and trigger permanent green value boost
        is_red_pen_active = any(t.name == "The Red Pen" for t in self.tropes)
        if is_red_pen_active and not is_draft:
            for idx, clue in enumerate(clues):
                char = guess[idx]
                if clue == 'grey' and char.isalpha():
                    if not self.keyboard_mods[char].get("removed", False):
                        self.keyboard_mods[char]["removed"] = True
                        self.red_pen_green_bonus += 10

        # Calculate scores
        if is_draft:
            self.drafts_left -= 1
            result = {
                "score": 0,
                "chips": 0,
                "mult": 1.0,
                "x_mults": [],
                "clues": clues,
                "pattern": "Drafted"
            }
        else:
            self.submissions_left -= 1
            
            # Temporary hook for Red Pen green bonus
            # We can register Red Pen listener to ON_LETTER_SCORED, or apply it here:
            result = calculate_word_score(eval_guess_str, self.target_word, self.style_guides, self.keyboard_mods, boss_blind=self.boss_blind)
            
            # Apply Red Pen green letter boost if green
            if self.red_pen_green_bonus > 0:
                for idx, clue in enumerate(clues):
                    if clue == 'green':
                        result["chips"] += self.red_pen_green_bonus
                        # Re-calculate score total
                        total_mult = result["mult"]
                        for xm in result["x_mults"]:
                            total_mult *= xm
                        result["score"] = int(result["chips"] * total_mult)
            
            self.round_score += result["score"]
            
        # Redact colors if Coffee Ring is active on a letter
        final_clues = list(clues)
        for idx, char in enumerate(guess):
            if self.keyboard_mods.get(char, {}).get("coffee_ring", False):
                final_clues[idx] = "redacted" # clue is hidden

        history_entry = {
            "word": guess,
            "clues": final_clues,
            "score": result["score"],
            "is_draft": is_draft
        }
        self.round_history.append(history_entry)
        
        # Publish submission events
        if is_draft:
            event_bus.bus.publish('ON_WORD_DRAFTED', guess, final_clues)
        else:
            event_bus.bus.publish('ON_WORD_SUBMITTED', guess, final_clues, result["score"])
            
        return result

    def get_plagiarist_anagram(self, first_guess):
        """Returns a valid anagram of the first guess to act as the new target word."""
        # Find all words in dictionary targets that are anagrams of first_guess
        sorted_guess = sorted(first_guess)
        candidates = [w for w in self.dictionary.target_words if sorted(w) == sorted_guess and w != first_guess]
        if not candidates:
            # Check guess list
            candidates = [w for w in self.dictionary.allowed_guesses if sorted(w) == sorted_guess and w != first_guess]
        
        if candidates:
            return random.choice(candidates)
        else:
            # Fallback: shuffle the first guess to create an anagram
            chars = list(first_guess)
            random.shuffle(chars)
            return "".join(chars)

    def check_round_end(self):
        """Checks if the round is over. Returns 'win', 'lose', or 'continue'."""
        if self.round_score >= self.target_score:
            # Won round! Gain royalties: base $3 + $1 per remaining submission
            reward = 3 + self.submissions_left
            self.royalties += reward
            event_bus.bus.publish('ON_STAGE_WON', reward)
            return "win"
        elif self.submissions_left <= 0:
            # Lost round! Fired!
            event_bus.bus.publish('ON_STAGE_LOST')
            return "lose"
        return "continue"

    def advance_blind(self):
        """Advances to the next blind. If chapter boss is beaten, moves to next chapter."""
        self.blind_index += 1
        if self.blind_index > 2:
            self.chapter += 1
            self.blind_index = 0
            # Reset any temporary debuffs like Red Pen removed keys for the new chapter
            for char in self.keyboard_mods:
                self.keyboard_mods[char]["removed"] = False
            self.roll_boss_blind()
            
        self.update_target_score()
