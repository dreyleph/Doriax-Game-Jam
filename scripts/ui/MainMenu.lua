-- MainMenu.lua
-- Menu inicial (cena "Menu", a primeira do jogo). O titulo ("BATALHA PELA
-- CAPITAL") e um texto da cena: pode trocar o texto ou colocar uma imagem.
-- O nome do jogo tambem vai para a barra da janela (GAME_TITLE).
--   JOGAR -> comeca uma corrida nova (cena "Corrida")
--   SOM   -> liga/desliga o som (ui/SoundToggle.lua, no proprio botao)
--   SAIR  -> fecha o jogo

local GameState = require("game.GameState")
local Combat = require("game.Combat")

local GAME_TITLE = "Batalha Pela Capital"

local MainMenu = {
    properties = {
        { name = "playButton", displayName = "Botao Jogar", type = "Button" },
        { name = "quitButton", displayName = "Botao Sair",  type = "Button" },
    }
}

function MainMenu:init()
    pcall(function() System.setWindowTitle(GAME_TITLE) end)
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
