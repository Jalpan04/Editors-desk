from src.engine import event_bus
from src.gameplay.scoring import LETTER_CHIPS

class Trope:
    def __init__(self, name, description, debuff_desc, price=5):
        self.name = name
        self.description = description
        self.debuff_desc = debuff_desc
        self.price = price
        self.is_debuff_active = True  # Can be disabled by White-Out

    def on_equip(self, run_manager):
        """Called when item is bought or equipped. Registers event listeners."""
        pass

    def on_unequip(self, run_manager):
        """Called when item is sold or replaced. Unregisters event listeners."""
        pass


class PlotTwistTrope(Trope):
    def __init__(self):
        super().__init__(
            name="The Plot Twist",
            description="Guessing exactly 1 Green and 4 Greys gives an x15 Multiplier.",
            debuff_desc="You can no longer play words containing the letter 'E'.",
            price=6
        )

    def on_equip(self, run_manager):
        event_bus.bus.subscribe('ON_SCORE_CALCULATED', self.apply_bonus)

    def on_unequip(self, run_manager):
        event_bus.bus.unsubscribe('ON_SCORE_CALCULATED', self.apply_bonus)

    def apply_bonus(self, score_manager, guess, clues, pattern_name):
        if pattern_name == "Shot in the Dark":
            score_manager.add_x_mult(15.0)


class PurpleProseTrope(Trope):
    def __init__(self):
        super().__init__(
            name="Purple Prose",
            description="Rare letters (Z, X, Q, J) trigger their score twice.",
            debuff_desc="You must use at least two vowels in every guess.",
            price=5
        )

    def on_equip(self, run_manager):
        event_bus.bus.subscribe('ON_LETTER_SCORED', self.apply_double_rare)

    def on_unequip(self, run_manager):
        event_bus.bus.unsubscribe('ON_LETTER_SCORED', self.apply_double_rare)

    def apply_double_rare(self, letter, index, clue, score_manager):
        if letter in ['z', 'x', 'q', 'j']:
            # Re-trigger scoring for this letter (Green=5, Yellow=1, Grey=0)
            if clue == 'green':
                score_manager.add_chips(5)
            elif clue == 'yellow':
                score_manager.add_chips(1)


class RedPenTrope(Trope):
    def __init__(self):
        super().__init__(
            name="The Red Pen",
            description="Grey letters trigger permanent Green letter bonus of +10 chips.",
            debuff_desc="You lose 1 Submission per round; grey letters are removed from keyboard.",
            price=7
        )

    # Handled natively inside RunManager checking the name,
    # but we can subscribe to reset logic or custom event hooks if needed.
    def on_equip(self, run_manager):
        pass

    def on_unequip(self, run_manager):
        # Restore removed keys when unequipped
        for char in run_manager.keyboard_mods:
            run_manager.keyboard_mods[char]["removed"] = False


class GhostwriterTrope(Trope):
    def __init__(self):
        super().__init__(
            name="The Ghostwriter",
            description="Blank spaces '*' act as wildcards (matching the correct target letter).",
            debuff_desc="The Target Score increases by 1.5x.",
            price=6
        )

    def on_equip(self, run_manager):
        # Recalculate target score if equipped mid-round
        run_manager.update_target_score()

    def on_unequip(self, run_manager):
        run_manager.update_target_score()


# Additional Tropes for content depth
class InkRibbonTrope(Trope):
    def __init__(self):
        super().__init__(
            name="Ink Ribbon",
            description="Each Green letter in your word adds +2 Multiplier.",
            debuff_desc="None.",
            price=4
        )
        self.is_debuff_active = False

    def on_equip(self, run_manager):
        event_bus.bus.subscribe('ON_SCORE_CALCULATED', self.apply_bonus)

    def on_unequip(self, run_manager):
        event_bus.bus.unsubscribe('ON_SCORE_CALCULATED', self.apply_bonus)

    def apply_bonus(self, score_manager, guess, clues, pattern_name):
        green_count = clues.count('green')
        if green_count > 0:
            score_manager.add_mult(green_count * 2.0)


class DeadlineTrope(Trope):
    def __init__(self):
        super().__init__(
            name="The Deadline",
            description="If this is your final Submission, gain +100 Chips and +10 Multiplier.",
            debuff_desc="None.",
            price=4
        )
        self.is_debuff_active = False
        self.rm = None

    def on_equip(self, run_manager):
        self.rm = run_manager
        event_bus.bus.subscribe('ON_SCORE_CALCULATED', self.apply_bonus)

    def on_unequip(self, run_manager):
        event_bus.bus.unsubscribe('ON_SCORE_CALCULATED', self.apply_bonus)

    def apply_bonus(self, score_manager, guess, clues, pattern_name):
        if self.rm and self.rm.submissions_left <= 0:  # Since submissions_left is decremented before scoring
            score_manager.add_chips(100)
            score_manager.add_mult(10.0)


class FirstEditionTrope(Trope):
    def __init__(self):
        super().__init__(
            name="First Edition",
            description="The first Submission of every round scores x2.0 Multiplier.",
            debuff_desc="None.",
            price=5
        )
        self.is_debuff_active = False
        self.rm = None

    def on_equip(self, run_manager):
        self.rm = run_manager
        event_bus.bus.subscribe('ON_SCORE_CALCULATED', self.apply_bonus)

    def on_unequip(self, run_manager):
        event_bus.bus.unsubscribe('ON_SCORE_CALCULATED', self.apply_bonus)

    def apply_bonus(self, score_manager, guess, clues, pattern_name):
        if self.rm and len(self.rm.round_history) == 1:  # Only includes current guess in history
            score_manager.add_x_mult(2.0)


def create_all_tropes():
    return [
        PlotTwistTrope(),
        PurpleProseTrope(),
        RedPenTrope(),
        GhostwriterTrope(),
        InkRibbonTrope(),
        DeadlineTrope(),
        FirstEditionTrope()
    ]
