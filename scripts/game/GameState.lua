-- GameState.lua
-- Estado da partida (vidas e pontuacao), compartilhado entre a fase e o HUD
-- via require("game.GameState"). Como o modulo vive enquanto o jogo roda,
-- os valores continuam ao trocar de fase; so um "novo jogo" os zera.

local GameState = {
    -- Regras (o Player sobrescreve com as propriedades do Inspector ao iniciar)
    startLives = 3,

    lives = 3,
    score = 0,
    gameOver = false,
    needsNewGame = true,       -- true no primeiro inicio e depois de um game over
}

function GameState.newGame()
    GameState.lives = GameState.startLives
    GameState.score = 0
    GameState.gameOver = false
    GameState.needsNewGame = false
end

function GameState.addScore(points)
    if GameState.gameOver then return end
    GameState.score = GameState.score + math.floor(points)
end

-- Perde uma vida. Os pontos sao mantidos (arcade: vale o quanto se foi longe).
-- Retorna true se ainda restam vidas, false se foi game over.
function GameState.loseLife()
    GameState.lives = math.max(GameState.lives - 1, 0)
    if GameState.lives <= 0 then
        GameState.gameOver = true
        GameState.needsNewGame = true
        return false
    end
    return true
end

return GameState
