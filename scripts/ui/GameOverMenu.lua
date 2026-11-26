-- GameOverMenu.lua
-- Tela de GAME OVER (dentro do HUD): fundo preto cobrindo a fase, com o
-- texto "GAME OVER" e o resumo da pontuacao (feitos pelo HUD.lua) e dois botoes:
--   REINICIAR -> corrida nova na mesma fase
--   MENU      -> volta ao menu inicial
-- Vai na entidade raiz da tela (a imagem preta): mostrar/esconder ela
-- mostra/esconde os botoes junto.
-- Com esta tela na cena, o Player nao reinicia sozinho no game over
-- (GameState.gameOverMenu); ele espera um dos botoes.

local GameState = require("game.GameState")
local Combat = require("game.Combat")
local Pause = require("game.Pause")

local GameOverMenu = {
    properties = {
        { name = "restartButton", displayName = "Botao Reiniciar", type = "Button" },
        { name = "menuButton",    displayName = "Botao Menu",      type = "Button" },
    }
}

function GameOverMenu:init()
    self.object = Object(self.scene, self.entity)
    self.shown = nil
    self.leaving = false
    GameState.gameOverMenu = true
    RegisterEvent(self, self.restartButton:getButtonComponent().onRelease, "onRestart")
    RegisterEvent(self, self.menuButton:getButtonComponent().onRelease, "onMenu")
    RegisterEngineEvent(self, "onUpdate")
    self:onUpdate()
end

function GameOverMenu:onUpdate()
    local show = GameState.gameOver
    if show ~= self.shown then
        self.shown = show
        self.object.visible = show
    end
end

function GameOverMenu:onRestart()
    if not GameState.gameOver or self.leaving then return end
    self.leaving = true
    Combat.restartLevel()   -- limpa os registros e recarrega a fase
end

function GameOverMenu:onMenu()
    if not GameState.gameOver or self.leaving then return end
    self.leaving = true
    Combat.clearRegistries()
    Pause.leave()
    SceneManager.loadScene("Menu")
end

return GameOverMenu
