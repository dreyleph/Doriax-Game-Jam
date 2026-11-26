-- PauseMenu.lua
-- Menu de pausa (dentro do HUD). Esc ou P abre e fecha.
-- Vai na entidade raiz do menu: mostrar/esconder ela mostra/esconde tudo.
-- Botoes: CONTINUAR, SOM (ui/SoundToggle.lua, no proprio botao), MENU, SAIR.

local Pause = require("game.Pause")
local Combat = require("game.Combat")

local PauseMenu = {
    properties = {
        { name = "continueButton", displayName = "Botao Continuar", type = "Button" },
        { name = "menuButton",     displayName = "Botao Menu",      type = "Button" },
        { name = "quitButton",     displayName = "Botao Sair",      type = "Button" },
    }
}

function PauseMenu:init()
    self.object = Object(self.scene, self.entity)
    self.shownPaused = nil
    self.pauseKeyWasDown = false

    RegisterEvent(self, self.continueButton:getButtonComponent().onRelease, "onContinue")
    RegisterEvent(self, self.menuButton:getButtonComponent().onRelease, "onMenu")
    RegisterEvent(self, self.quitButton:getButtonComponent().onRelease, "onQuit")
    RegisterEngineEvent(self, "onUpdate")
end

function PauseMenu:onUpdate()
    local pauseKeyDown = Input.isKeyPressed(Input.KEY_ESCAPE) or Input.isKeyPressed(Input.KEY_P)
    if pauseKeyDown and not self.pauseKeyWasDown then
        Pause.toggle()
    end
    self.pauseKeyWasDown = pauseKeyDown

    if Pause.paused ~= self.shownPaused then
        self.shownPaused = Pause.paused
        self.object.visible = Pause.paused
    end
end

function PauseMenu:onContinue()
    if Pause.paused then Pause.toggle() end
end

function PauseMenu:onMenu()
    if self.leaving then return end
    self.leaving = true
    -- sem limpar, inimigos da cena que vai ser destruida ficam no registro e
    -- derrubam o jogo na proxima corrida (ver Combat.clearRegistries)
    Combat.clearRegistries()
    Pause.leave()
    SceneManager.loadScene("Menu")
end

function PauseMenu:onQuit()
    System.quit()
end

return PauseMenu
