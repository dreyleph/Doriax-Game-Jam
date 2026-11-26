-- Settings.lua
-- Opcoes do jogador que valem para todas as cenas (o modulo vive enquanto o
-- jogo roda, entao a escolha continua ao trocar de cena).
--
-- Som: so liga/desliga (volume geral da engine em 1 ou 0).
-- Botao que troca: ui/SoundToggle.lua (no menu inicial e no menu de pausa).

local Settings = {
    soundOn = true,
}

function Settings.setSound(on)
    Settings.soundOn = on and true or false
    pcall(function() AudioSystem.globalVolume = Settings.soundOn and 1.0 or 0.0 end)
end

function Settings.toggleSound()
    Settings.setSound(not Settings.soundOn)
end

function Settings.soundLabel()
    return Settings.soundOn and "SOM: LIGADO" or "SOM: DESLIGADO"
end

return Settings
