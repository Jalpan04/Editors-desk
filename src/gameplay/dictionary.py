import os
import random

class Dictionary:
    def __init__(self, data_dir="data"):
        self.target_words = []
        self.allowed_guesses = set()
        self.load_dictionaries(data_dir)

    def load_dictionaries(self, data_dir):
        target_path = os.path.join(data_dir, "target_words.txt")
        guess_path = os.path.join(data_dir, "allowed_guesses.txt")

        # Load target answers list
        if os.path.exists(target_path):
            with open(target_path, "r", encoding="utf-8") as f:
                self.target_words = [line.strip().lower() for line in f if len(line.strip()) == 5]
        
        # Load allowed guesses list
        if os.path.exists(guess_path):
            with open(guess_path, "r", encoding="utf-8") as f:
                self.allowed_guesses = {line.strip().lower() for line in f if len(line.strip()) == 5}
        
        # Merge target words into allowed guesses to ensure all targets are valid guesses
        self.allowed_guesses.update(self.target_words)

        # Fail-safe defaults if dictionaries are empty
        if not self.target_words:
            self.target_words = ["write", "draft", "story", "novel", "print", "press", "paper", "pages"]
            self.allowed_guesses.update(self.target_words)

    def is_valid_guess(self, word):
        """Checks if a 5-letter word is in the dictionary."""
        return word.strip().lower() in self.allowed_guesses

    def get_random_target(self):
        """Selects a random 5-letter target word."""
        return random.choice(self.target_words)
