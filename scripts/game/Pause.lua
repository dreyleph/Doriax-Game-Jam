-- Pause.lua
-- Pausa da partida: congela a fisica da fase e avisa os scripts de gameplay.

local GameState = require("game.GameState")

local Pause = {
    paused = false,
}

local gameScene = nil

-- Chamado pelo Player:init a cada (re)inicio da cena
function Pause.setGameScene(scene)
    gameScene = scene
    Pause.paused = false
end

function Pause.toggle()
    if GameState.gameOver or not gameScene then return end
    Pause.paused = not Pause.paused
    gameScene:getPhysicsSystem().paused = Pause.paused
end

-- Saindo da fase (ex.: voltar ao menu): a cena vai ser destruida
function Pause.leave()
    gameScene = nil
    Pause.paused = false
end

return Pause
