-- HUD.lua
-- HUD da partida (cena de UI "HUD", anexada como cena filha das fases).
-- Le vidas e pontos do GameState e so reescreve um texto quando o valor muda.

local GameState = require("game.GameState")
local Pause = require("game.Pause")

local HUD = {
    properties = {
        { name = "scoreText",    displayName = "Texto dos pontos",    type = "Text" },
        { name = "livesText",    displayName = "Texto das vidas",     type = "Text" },
        { name = "gameOverText", displayName = "Texto de game over",  type = "Text" },
        { name = "pausedText",   displayName = "Texto de pausa",      type = "Text" },
        { name = "scoreDigits",  displayName = "Digitos da pontuacao", type = "int", default = 6 },
    }
}

function HUD:init()
    self.shownScore = nil
    self.shownLives = nil
    self.shownGameOver = nil
    self.shownPaused = nil
    self.pauseKeyWasDown = false
    RegisterEngineEvent(self, "onUpdate")
    self:refresh()
end

function HUD:refresh()
    if self.scoreText and GameState.score ~= self.shownScore then
        self.shownScore = GameState.score
        self.scoreText.text = string.format("PONTOS %0" .. self.scoreDigits .. "d", GameState.score)
    end

    if self.livesText and GameState.lives ~= self.shownLives then
        self.shownLives = GameState.lives
        self.livesText.text = "VIDAS x" .. GameState.lives
    end

    if self.gameOverText and GameState.gameOver ~= self.shownGameOver then
        self.shownGameOver = GameState.gameOver
        self.gameOverText.visible = GameState.gameOver
    end

    if self.pausedText and Pause.paused ~= self.shownPaused then
        self.shownPaused = Pause.paused
        self.pausedText.visible = Pause.paused
    end
end

function HUD:onUpdate()
    local pauseKeyDown = Input.isKeyPressed(Input.KEY_TAB) or Input.isKeyPressed(Input.KEY_ENTER)
    if pauseKeyDown and not self.pauseKeyWasDown then
        Pause.toggle()
    end
    self.pauseKeyWasDown = pauseKeyDown

    self:refresh()
end

return HUD
