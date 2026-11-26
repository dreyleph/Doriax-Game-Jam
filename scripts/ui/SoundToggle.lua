-- SoundToggle.lua
-- Botao de som: vai na propria entidade do botao (Button). Cada clique liga ou
-- desliga o som do jogo todo (game/Settings.lua) e troca o texto do botao
-- ("SOM: LIGADO" / "SOM: DESLIGADO").

local Settings = require("game.Settings")

local SoundToggle = {
    properties = {}
}

function SoundToggle:init()
    self.button = Button(self.scene, self.entity)
    RegisterEvent(self, self.button:getButtonComponent().onRelease, "onToggle")
    -- aplica o estado atual (vale para a cena que acabou de abrir)
    Settings.setSound(Settings.soundOn)
    self:refresh()
end

function SoundToggle:refresh()
    self.button.label = Settings.soundLabel()
end

function SoundToggle:onToggle()
    Settings.toggleSound()
    self:refresh()
end

return SoundToggle
