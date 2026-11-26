-- MainMenu.lua
-- Menu inicial (cena "Menu"). O titulo e uma entidade qualquer da cena:
-- pode trocar o texto ou colocar uma imagem, o script nao mexe nele.

local GameState = require("game.GameState")

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
    GameState.needsNewGame = true
    SceneManager.loadScene("Corrida")
end

function MainMenu:onQuit()
    System.quit()
end

return MainMenu
