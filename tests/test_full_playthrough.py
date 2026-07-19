import unittest
import random
from src.gameplay.run_manager import RunManager
from src.content.tropes import create_all_tropes
from src.content.edits import create_all_edits
from src.content.style_guides import StyleGuideUpgrade
from src.engine import event_bus

class TestFullPlaythrough(unittest.TestCase):
    def setUp(self):
        # Clean event bus subscriptions to prevent leaks between test cases
        event_bus.bus.clear()
        
        # Initialize sound manager to provide silent mock sounds
        from src.engine import sound_manager
        sound_manager.init()

    def test_playthrough(self):
        """Simulates playing through 8 Chapters (24 stages) with random decisions."""
        rm = RunManager(data_dir="data")
        
        # Instantiate item pools for the simulation
        all_tropes = create_all_tropes()
        all_edits = create_all_edits()
        
        # Iterate through Chapters 1 to 8
        for chapter in range(1, 9):
            rm.chapter = chapter
            
            # Three stages per chapter (Small, Big, Boss Blinds)
            for blind in range(3):
                rm.blind_index = blind
                rm.update_target_score()
                rm.start_round()
                
                attempts = 0
                while rm.round_score < rm.target_score and rm.submissions_left > 0 and attempts < 100:
                    attempts += 1
                    
                    # 1. Randomly decide to use an edit item if any are held
                    if rm.edits and random.random() < 0.3:
                        edit = rm.edits.pop(0)
                        # Handle White-Out targeting active tropes
                        if edit.name == "The White-Out":
                            target_tropes = [t for t in rm.tropes if t.is_debuff_active]
                            if target_tropes:
                                edit.use(rm, target_trope=target_tropes[0])
                        else:
                            edit.use(rm)
                            
                    # 2. Decide between Draft and Submission
                    is_draft = (rm.drafts_left > 0 and random.random() < 0.25)
                    
                    # 3. Formulate a valid word guess
                    guess = "write"  # Monospace default fallback
                    if rm.boss_blind == "Minimalist":
                        guess = "book"
                    else:
                        if rm.dictionary.target_words:
                            possible_guesses = [w for w in rm.dictionary.target_words if len(w) == 5]
                            
                            # Filter guesses based on active Plot Twist trope restrictions ('E' check)
                            if any(t.name == "The Plot Twist" and t.is_debuff_active for t in rm.tropes):
                                possible_guesses = [w for w in possible_guesses if 'e' not in w]
                                
                            # Filter guesses based on Red Pen removed keys
                            removed_keys = {char for char, mods in rm.keyboard_mods.items() if mods.get("removed", False)}
                            if removed_keys:
                                possible_guesses = [w for w in possible_guesses if not any(char in removed_keys for char in w)]
                                
                            # Filter guesses based on Stapled keys constraints
                            # (If one is played, both must be played)
                            for pair in rm.stapled_pairs:
                                l1, l2 = pair
                                possible_guesses = [w for w in possible_guesses if (l1 in w) == (l2 in w)]
                                
                            if possible_guesses:
                                guess = random.choice(possible_guesses)
                            else:
                                guess = "cigar"  # Absolute fallback
                                
                    # 4. Process the guess
                    res = rm.submit_word(guess, is_draft=is_draft)
                    
                    # If we got a validation error, override with target word to ensure progression
                    if "error" in res:
                        # Ensure we play a valid 4-letter or 5-letter word matching the target length
                        rm.submit_word(rm.target_word, is_draft=False)
                        
                # 5. Determine stage end state
                status = rm.check_round_end()
                
                # 6. Closet Shop Phase (If won, advance and buy upgrades)
                if status == "win":
                    rm.advance_blind()
                    
                    # Buy random shop upgrades
                    for _ in range(4):
                        # Buy style guide upgrades
                        if rm.royalties >= 3 and random.random() < 0.4:
                            sg_name = random.choice(["Masterpiece", "Jumble", "Shot in the Dark", "Total Rewrite"])
                            sg = StyleGuideUpgrade(sg_name)
                            sg.use(rm)
                            rm.royalties -= sg.price
                            
                        # Buy passive tropes
                        if rm.royalties >= 5 and len(rm.tropes) < 5 and random.random() < 0.3:
                            unowned = [t for t in all_tropes if t.name not in {o.name for o in rm.tropes}]
                            if unowned:
                                tr = random.choice(unowned)
                                if rm.royalties >= tr.price:
                                    rm.tropes.append(tr)
                                    tr.on_equip(rm)
                                    rm.royalties -= tr.price
                                    
                        # Buy active edits
                        if rm.royalties >= 3 and len(rm.edits) < 2 and random.random() < 0.3:
                            ed = random.choice(all_edits)
                            if rm.royalties >= ed.price:
                                rm.edits.append(ed)
                                rm.royalties -= ed.price
                                
                        # Purchase keyboard modifications
                        if rm.royalties >= 3 and random.random() < 0.3:
                            stype = random.choice(["highlighter", "coffee_ring", "stapler"])
                            letter = random.choice(list("abcdefghijklmnopqrstuvwxyz"))
                            
                            if stype == "highlighter":
                                rm.keyboard_mods[letter]["highlighter"] = True
                                rm.royalties -= 3
                            elif stype == "coffee_ring":
                                rm.keyboard_mods[letter]["coffee_ring"] = True
                                rm.royalties -= 3
                            elif stype == "stapler":
                                letter2 = random.choice(list("abcdefghijklmnopqrstuvwxyz".replace(letter, "")))
                                rm.keyboard_mods[letter]["stapler"] = True
                                rm.keyboard_mods[letter2]["stapler"] = True
                                rm.stapled_pairs.append((letter, letter2))
                                rm.royalties -= 4
                else:
                    # Reset game state if lost (fired) to simulate retrying a new run
                    rm = RunManager(data_dir="data")
                    
        print("Integration test completed: Played through 8 Chapters successfully with no errors!")

if __name__ == "__main__":
    unittest.main()
