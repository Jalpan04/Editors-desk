local SoundManager = {}
SoundManager.__index = SoundManager

function SoundManager.new(audio_dir)
    local self = setmetatable({}, SoundManager)
    self.audio_dir = audio_dir or "assets/audio"
    self.sounds = {}
    self.volume = 0.5
    self:load_sounds()
    return self
end

function SoundManager:load_sounds()
    local sound_files = {
        clack1 = "clack1.wav",
        clack2 = "clack2.wav",
        clack3 = "clack3.wav",
        bell = "bell.wav",
        carriage = "carriage.wav",
        shred = "shred.wav",
        stamp = "stamp.wav",
        error = "error.wav",
        buy = "buy.wav"
    }

    for name, filename in pairs(sound_files) do
        local path = self.audio_dir .. "/" .. filename
        if love.filesystem.getInfo(path) then
            local source = love.audio.newSource(path, "static")
            source:setVolume(self.volume)
            self.sounds[name] = source
        else
            self.sounds[name] = {
                play = function() end,
                setVolume = function() end,
                setPitch = function() end,
                stop = function() end,
                clone = function(s) return s end
            }
        end
    end
end

function SoundManager:play(name, pitch_shift)
    local source = self.sounds[name]
    if source then
        local instance = source:clone()
        local vol = self.volume
        if name:match("^clack") then
            vol = self.volume * (0.8 + love.math.random() * 0.3)
        end
        instance:setVolume(vol)
        
        if pitch_shift then
            instance:setPitch(0.9 + love.math.random() * 0.2)
        end
        
        instance:play()
    end
end

function SoundManager:play_clack()
    local clacks = {"clack1", "clack2", "clack3"}
    local chosen = clacks[love.math.random(1, 3)]
    self:play(chosen, true)
end

function SoundManager:set_volume(volume)
    self.volume = math.max(0.0, math.min(1.0, volume))
    for _, source in pairs(self.sounds) do
        source:setVolume(self.volume)
    end
end

local sounds = nil

local function init(audio_dir)
    sounds = SoundManager.new(audio_dir)
    local config = require("src/config")
    config.sounds = sounds
    return sounds
end

return {
    SoundManager = SoundManager,
    init = init,
    get_sounds = function() return sounds end
}
