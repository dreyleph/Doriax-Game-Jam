-- Settings.lua
-- Opcoes do jogador que valem para todas as cenas (por enquanto, so o volume).

local Settings = {
    volume = 1.0,
}

function Settings.setVolume(value)
    value = math.min(math.max(value, 0), 1)
    Settings.volume = math.floor(value * 100 + 0.5) / 100
    AudioSystem.globalVolume = Settings.volume
end

return Settings
