-- MainMenu.lua
-- Menu inicial (cena "Menu", a primeira do jogo). O titulo e uma entidade
-- qualquer da cena: pode trocar o texto ou colocar uma imagem.
--   JOGAR -> comeca uma corrida nova (cena "Corrida")
--   SOM   -> liga/desliga o som (ui/SoundToggle.lua, no proprio botao)
--   SAIR  -> fecha o jogo

local GameState = require("game.GameState")
local Combat = require("game.Combat")

local MainMenu = {
    properties = {
        { name = "playButton", displayName = "Botao Jogar", type = "Button" },
        { name = "quitButton", displayName = "Botao Sair",  type = "Button" },
    }
}

function MainMenu:init()
    RegisterEvent(self, self.playButton:getButtonComponent().onRelease, "onPlay")
    RegisterEvent(self, self.quitButton:getButtonComponent().onRelease, "onQuit")
end

function MainMenu:onPlay()
    if self.starting then return end
    self.starting = true
    Combat.clearRegistries()      -- nada da corrida anterior sobra no registro
    GameState.needsNewGame = true -- vidas, pontos e distancia zerados
    SceneManager.loadScene("Corrida")
end

function MainMenu:onQuit()
    System.quit()
end

return MainMenu
