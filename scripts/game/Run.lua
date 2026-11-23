-- Run.lua
-- Estado da corrida atual (modo procedural), compartilhado entre camera,
-- jogador e gerador via require("game.Run").

local Run = {
    viewWidth = 1280,     -- largura da tela em pixels (canvas do projeto)
    cameraLeft = nil,     -- borda esquerda da camera; nil = sem limite (cena sem CameraFollow travada)
    lockBackwards = false -- true: a camera nao volta e o jogador nao sai pela esquerda
}

-- Quem escreve aqui e o CameraFollow (no init e a cada frame). Nao leia
-- cameraLeft dentro de um init: a ordem de inicializacao entre scripts nao e
-- garantida e o valor pode ser da corrida anterior.

return Run
