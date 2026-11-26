-- GameState.lua
-- Estado da partida (vidas, pontos e distancia), compartilhado entre a fase e o HUD
-- via require("game.GameState"). Como o modulo vive enquanto o jogo roda,
-- os valores continuam ao trocar de fase; so um "novo jogo" os zera.

local GameState = {
    -- Regras (o Player sobrescreve com as propriedades do Inspector ao iniciar)
    startLives = 3,

    -- Distancia: 1 metro = PIXELS_PER_METER px andados para a direita desde o
    -- inicio da corrida; cada metro vale POINTS_PER_METER pontos
    PIXELS_PER_METER = 32,
    POINTS_PER_METER = 10,

    lives = 3,
    score = 0,                 -- pontos dos abates
    distance = 0,              -- metros (o mais longe que chegou nesta corrida)
    originX = nil,             -- x onde a corrida comecou
    gameOver = false,
    needsNewGame = true,       -- true no primeiro inicio e depois de um game over
    gameOverMenu = false,      -- true quando a cena tem a tela de GAME OVER com botoes
                               -- (ui/GameOverMenu.lua): ai o jogo espera o jogador escolher
}

function GameState.newGame()
    GameState.lives = GameState.startLives
    GameState.score = 0
    GameState.distance = 0
    GameState.originX = nil
    GameState.gameOver = false
    GameState.needsNewGame = false
end

function GameState.addScore(points)
    if GameState.gameOver then return end
    GameState.score = GameState.score + math.floor(points)
end

-- Jogador chegou na posicao x: guarda a maior distancia da corrida
function GameState.updateDistance(x)
    if GameState.gameOver then return end
    if not GameState.originX then GameState.originX = x end
    local m = math.floor((x - GameState.originX) / GameState.PIXELS_PER_METER)
    if m > GameState.distance then GameState.distance = m end
end

function GameState.distancePoints()
    return GameState.distance * GameState.POINTS_PER_METER
end

-- Pontuacao final = abates + distancia (a distancia so e somada no fim da
-- corrida: o HUD mostra os abates durante o jogo e o total no GAME OVER)
function GameState.total()
    return GameState.score + GameState.distancePoints()
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
