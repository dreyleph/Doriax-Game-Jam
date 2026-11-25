-- HUD.lua
-- HUD da partida (cena de UI "HUD", anexada como cena filha das fases).
-- Le vidas e pontos do GameState (e a municao dos Itens) e so reescreve um
-- texto quando o valor muda.

local GameState = require("game.GameState")
local Itens = require("itens.Itens")

local HUD = {
    properties = {
        { name = "scoreText",    displayName = "Texto dos pontos",    type = "Text" },
        { name = "livesText",    displayName = "Texto das vidas",     type = "Text" },
        { name = "gameOverText", displayName = "Texto de game over",  type = "Text" },
        { name = "ammoText",     displayName = "Texto da municao",    type = "Text" },
        { name = "scoreDigits",  displayName = "Digitos da pontuacao", type = "int", default = 6 },
    }
}

function HUD:init()
    self.shownScore = nil
    self.shownLives = nil
    self.shownGameOver = nil
    self.shownAmmo = nil
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

    if self.ammoText then
        -- pistola: municao infinita; escopeta: balas restantes (so aparece se tiver)
        local ammo = "PISTOLA INF"
        if Itens.secondaryWeapon == "escopeta" then
            ammo = ammo .. "   ESCOPETA x" .. Itens.secondaryAmmo
        end
        if ammo ~= self.shownAmmo then
            self.shownAmmo = ammo
            self.ammoText.text = ammo
        end
    end

    if self.gameOverText and GameState.gameOver ~= self.shownGameOver then
        self.shownGameOver = GameState.gameOver
        self.gameOverText.visible = GameState.gameOver
    end
end

function HUD:onUpdate()
    self:refresh()
end

return HUD
