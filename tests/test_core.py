import unittest
import os
from src.engine import event_bus
from src.gameplay.dictionary import Dictionary
from src.gameplay.scoring import check_word, identify_pattern, ScoreManager, calculate_word_score
from src.gameplay.run_manager import RunManager

class TestEventBus(unittest.TestCase):
    def setUp(self):
        event_bus.bus.clear()

    def test_subscribe_publish(self):
        called = []
        def listener(val):
            called.append(val)
            
        event_bus.bus.subscribe('TEST_EVENT', listener)
        event_bus.bus.publish('TEST_EVENT', 42)
        self.assertEqual(called, [42])

    def test_priority(self):
        called = []
        event_bus.bus.subscribe('PRIO_EVENT', lambda: called.append(2), priority=2)
        event_bus.bus.subscribe('PRIO_EVENT', lambda: called.append(1), priority=1)
        event_bus.bus.subscribe('PRIO_EVENT', lambda: called.append(3), priority=3)
        event_bus.bus.publish('PRIO_EVENT')
        self.assertEqual(called, [3, 2, 1])


class TestWordleMatching(unittest.TestCase):
    def test_basic_match(self):
        clues = check_word("crane", "crane")
        self.assertEqual(clues, ["green"] * 5)

    def test_duplicate_letters(self):
        # Target: APPLE, Guess: PUPPY
        # P at index 2 matches P in APPLE (Green)
        # First P at index 0 matches first unmatched P in APPLE (Yellow)
        # Other P's should be Grey
        clues = check_word("puppy", "apple")
        self.assertEqual(clues, ["yellow", "grey", "green", "grey", "grey"])

    def test_no_matches(self):
        clues = check_word("xxxxx", "apple")
        self.assertEqual(clues, ["grey"] * 5)


class TestScoring(unittest.TestCase):
    def test_identify_patterns(self):
        self.assertEqual(identify_pattern(["green"] * 5, "crane", "crane"), "Masterpiece")
        self.assertEqual(identify_pattern(["grey"] * 5, "crane", "board"), "Total Rewrite")
        self.assertEqual(identify_pattern(["green", "grey", "grey", "grey", "grey"], "crane", "clogs"), "Shot in the Dark")
        self.assertEqual(identify_pattern(["yellow"] * 5, "crane", "nacer"), "Jumble")
        self.assertEqual(identify_pattern(["green", "yellow", "grey", "grey", "grey"], "crane", "clogs"), "Standard Submission")

    def test_score_calculation(self):
        # Test standard score calculation
        # Guess: CRANE, Target: CRANE (Level 1 Masterpiece)
        # Base: 250 Chips, 8.0 Mult
        # Each letter adds: letter_chips + 50 chips, and x3 Mult
        # 'c': 3, 'r': 2, 'a': 1, 'n': 1, 'e': 1 -> Sum = 8 chips
        # Total green chips = 8 + 50*5 = 258 chips
        # Total base chips = 250 + 258 = 508
        # Mult = 8.0
        # x_mults = [3.0] * 5 = 243.0
        # Score = 508 * 8.0 * 243.0
        res = calculate_word_score("crane", "crane", {"Masterpiece": 1}, {})
        self.assertEqual(res["pattern"], "Masterpiece")
        self.assertEqual(res["clues"], ["green"] * 5)
        self.assertGreater(res["score"], 0)


class TestRunManager(unittest.TestCase):
    def test_run_init(self):
        # We can construct RunManager with data_dir pointing to a temp or empty directory (which triggers fallbacks)
        rm = RunManager(data_dir="nonexistent_directory")
        self.assertEqual(rm.royalties, 4)
        self.assertEqual(rm.chapter, 1)
        self.assertEqual(rm.blind_index, 0)
        self.assertEqual(rm.submissions_left, 4)

    def test_round_flow(self):
        rm = RunManager(data_dir="data")
        rm.start_round()
        rm.target_word = "apple"
        self.assertEqual(rm.submissions_left, 4)
        self.assertEqual(rm.drafts_left, 2)
        
        # Test draft guess
        res_draft = rm.submit_word("crane", is_draft=True)
        self.assertEqual(rm.drafts_left, 1)
        self.assertEqual(rm.submissions_left, 4)
        self.assertEqual(res_draft["score"], 0)
        
        # Test submit guess
        res_submit = rm.submit_word("apple", is_draft=False)
        self.assertEqual(rm.submissions_left, 3)
        self.assertGreater(res_submit["score"], 0)
        self.assertEqual(rm.round_score, res_submit["score"])


class TestBalanceAndExploits(unittest.TestCase):
    def setUp(self):
        event_bus.bus.clear()

    def test_ghostwriter_wildcard_cap(self):
        from src.content.tropes import GhostwriterTrope
        rm = RunManager(data_dir="data")
        rm.start_round()
        rm.target_word = "apple"
        
        # Equip Ghostwriter
        gw = GhostwriterTrope()
        rm.tropes.append(gw)
        gw.on_equip(rm)
        
        # Submit with 3 wildcards -> should fail
        res = rm.submit_word("ap***")
        self.assertIn("error", res)
        self.assertIn("Max 2 wildcards", res["error"])
        
        # Submit with 2 wildcards -> should succeed
        res2 = rm.submit_word("app**")
        self.assertNotIn("error", res2)

    def test_purple_prose_vowels(self):
        from src.content.tropes import PurpleProseTrope
        rm = RunManager(data_dir="data")
        rm.start_round()
        rm.target_word = "apple"
        
        # Equip Purple Prose
        pp = PurpleProseTrope()
        rm.tropes.append(pp)
        pp.on_equip(rm)
        
        # Guess with 1 vowel
        res = rm.submit_word("tryst")
        self.assertIn("error", res)
        self.assertIn("Must use at least 2 vowels", res["error"])
        
        # Guess with 2 vowels
        res2 = rm.submit_word("crane")
        self.assertNotIn("error", res2)

    def test_shredder_score_reset(self):
        from src.content.edits import ShredderEdit
        rm = RunManager(data_dir="data")
        rm.start_round()
        rm.target_word = "apple"
        
        # Score some points
        res = rm.submit_word("apple")
        self.assertGreater(rm.round_score, 0)
        
        # Use shredder
        shredder = ShredderEdit()
        shredder.use(rm)
        
        # Score should be reset to 0
        self.assertEqual(rm.round_score, 0)
        self.assertEqual(len(rm.round_history), 0)

    def test_plagiarist_jumble_demotion(self):
        # Guess "crane", Target: "nacer" (anagram -> Jumble pattern)
        res = calculate_word_score("crane", "nacer", {}, {}, boss_blind="Plagiarist")
        # Pattern should be demoted to Standard Submission
        self.assertEqual(res["pattern"], "Standard Submission")


    def test_plagiarism_penalty(self):
        rm = RunManager(data_dir="data")
        rm.start_round()
        rm.target_word = "apple"
        
        # First submission is fine
        res1 = rm.submit_word("write")
        self.assertNotIn("error", res1)
        self.assertGreater(res1["score"], 0)
        self.assertEqual(rm.submissions_left, 3)
        
        # Second submission of same word should trigger plagiarism: 0 score, costs 1 submission
        res2 = rm.submit_word("write")
        self.assertNotIn("error", res2)
        self.assertEqual(res2["score"], 0)
        self.assertEqual(res2["pattern"], "Plagiarized")
        self.assertEqual(rm.submissions_left, 2)


if __name__ == "__main__":
    unittest.main()
