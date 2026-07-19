import os
import random
import pygame

class DummySound:
    def play(self, *args, **kwargs):
        return None
    def set_volume(self, vol):
        pass
    def stop(self):
        pass

class SoundManager:
    def __init__(self, audio_dir="assets/audio"):
        self.audio_dir = audio_dir
        self.sounds = {}
        self.volume = 0.5
        
        # Initialize pygame mixer if not already done
        if not pygame.mixer.get_init():
            try:
                pygame.mixer.init()
            except pygame.error as e:
                print(f"Mixer initialization failed: {e}")
                
        self.load_sounds()

    def load_sounds(self):
        sound_files = {
            "clack1": "clack1.wav",
            "clack2": "clack2.wav",
            "clack3": "clack3.wav",
            "bell": "bell.wav",
            "carriage": "carriage.wav",
            "shred": "shred.wav",
            "stamp": "stamp.wav",
            "error": "error.wav",
            "buy": "buy.wav"
        }
        
        for name, filename in sound_files.items():
            path = os.path.join(self.audio_dir, filename)
            if os.path.exists(path):
                try:
                    sound = pygame.mixer.Sound(path)
                    sound.set_volume(self.volume)
                    self.sounds[name] = sound
                except pygame.error as e:
                    print(f"Failed to load sound {filename}: {e}")
                    self.sounds[name] = DummySound()
            else:
                self.sounds[name] = DummySound()

    def play(self, name, pitch_shift=False):
        """Plays the sound. Optionally shifts pitch (if pygame supports it or by selecting variations)."""
        sound = self.sounds.get(name)
        if sound:
            # We can vary volume slightly for mechanical clacks to make them feel organic
            if name.startswith("clack"):
                vol = self.volume * random.uniform(0.8, 1.1)
                sound.set_volume(vol)
            sound.play()

    def play_clack(self):
        """Helper to play a random typewriter clack."""
        clack_name = random.choice(["clack1", "clack2", "clack3"])
        self.play(clack_name)

    def set_volume(self, volume):
        self.volume = max(0.0, min(1.0, volume))
        for sound in self.sounds.values():
            sound.set_volume(self.volume)


# Global Sound Manager instance
# Will be initialized in main.py after pygame setup
sounds = None

def init(audio_dir="assets/audio"):
    global sounds
    sounds = SoundManager(audio_dir)
    from src import config
    config.sounds = sounds
