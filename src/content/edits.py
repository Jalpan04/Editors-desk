import random

class Edit:
    def __init__(self, name, description, price=3):
        self.name = name
        self.description = description
        self.price = price

    def use(self, run_manager, **kwargs):
        """
        Executes the immediate effect of the Edit.
        Returns a string status message or True/False.
        """
        pass


class MagnifyingGlassEdit(Edit):
    def __init__(self):
        super().__init__(
            name="The Magnifying Glass",
            description="Reveals the position of one Green letter in the target word.",
            price=3
        )

    def use(self, run_manager, **kwargs):
        target = run_manager.target_word
        
        # Track which indices are not already known green
        known_indices = []
        for entry in run_manager.round_history:
            if not entry.get("is_draft", False):
                clues = entry["clues"]
                word = entry["word"]
                for i, clue in enumerate(clues):
                    if clue == "green" and word[i] == target[i]:
                        known_indices.append(i)
                        
        unknown_indices = [i for i in range(len(target)) if i not in known_indices]
        
        if not unknown_indices:
            # If all are already green, just pick a random index
            reveal_idx = random.randint(0, len(target) - 1)
        else:
            reveal_idx = random.choice(unknown_indices)
            
        letter = target[reveal_idx].upper()
        return f"Clue: Index {reveal_idx + 1} is '{letter}'!"


class EspressoShotEdit(Edit):
    def __init__(self):
        super().__init__(
            name="The Espresso Shot",
            description="Restores 1 Submission for the current round.",
            price=2
        )

    def use(self, run_manager, **kwargs):
        if run_manager.submissions_left >= run_manager.submissions_max:
            return "Submissions already at maximum!"
        run_manager.submissions_left += 1
        return "Gained +1 Submission!"


class ShredderEdit(Edit):
    def __init__(self):
        super().__init__(
            name="The Shredder",
            description="Resets round score, clears the grid, picks a new word, and restores submissions/drafts.",
            price=5
        )

    def use(self, run_manager, **kwargs):
        # Reset current round score, grid, and resources
        run_manager.round_score = 0
        run_manager.round_history = []
        run_manager.submissions_left = run_manager.submissions_max
        run_manager.drafts_left = run_manager.drafts_max
        
        # Pick new word
        if run_manager.boss_blind == "Minimalist":
            run_manager.target_word = run_manager.get_4_letter_target()
        else:
            run_manager.target_word = run_manager.dictionary.get_random_target()
            
        return "Board shredded! New target word loaded and score reset."


class WhiteOutEdit(Edit):
    def __init__(self):
        super().__init__(
            name="The White-Out",
            description="Removes the debuff from one of your active Tropes.",
            price=8
        )

    def use(self, run_manager, **kwargs):
        # Find active tropes with active debuffs
        target_tropes = [t for t in run_manager.tropes if t.is_debuff_active]
        if not target_tropes:
            return "No active Tropes have debuffs to remove!"
            
        # Target first or specific trope
        target_trope = kwargs.get("target_trope", None)
        if not target_trope:
            target_trope = target_tropes[0]
            
        target_trope.is_debuff_active = False
        
        # Re-apply any triggers that depend on debuff status (e.g. Red Pen or Ghostwriter)
        if target_trope.name == "The Ghostwriter":
            run_manager.update_target_score()
        elif target_trope.name == "The Red Pen":
            run_manager.submissions_max = 4
            run_manager.submissions_left = min(run_manager.submissions_left + 1, 4)
            
        return f"Debuff removed from '{target_trope.name}'!"


def create_all_edits():
    return [
        MagnifyingGlassEdit(),
        EspressoShotEdit(),
        ShredderEdit(),
        WhiteOutEdit()
    ]
