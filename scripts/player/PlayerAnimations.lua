-- PlayerAnimations.lua
-- Animacoes do jogador (sheets em assets/John Drinkwater/, quadros de 128x128,
-- personagem virado para a DIREITA; a esquerda e espelhada).
--
-- Estilo unico: so as sheets novas (IdleShooting, Running, Running&Shooting).
--
-- IMPORTANTE: todas as animacoes usam a MESMA imagem, o atlas
-- "Jogador-Atlas.png" (1024x384, 8 colunas, uma animacao por linha), montado
-- a partir das sheets por tools/montar_atlas_jogador.py. Trocar de textura em
-- jogo (setTexture) faz a engine descartar a imagem e recarregar do disco, e o
-- personagem sumia/"bugava" por alguns quadros a cada troca de animacao.
--   linha 0 (first = 0)  : IdleShooting (5 quadros)
--   linha 1 (first = 8)  : Running (8)
--   linha 2 (first = 16) : Running&Shooting (8)
-- Arte nova: rode o script do atlas e use first = linha * 8.

-- Nomes que o Player.lua pede:
--   idle         parado no chao                 idle_shoot   parado atirando
--   run          andando no chao                run_shoot    andando atirando
--   jump         no ar                          jump_shoot   no ar atirando
--   respawn      reaparecendo depois de morrer (jogador parado, sem controle)
-- Animacao sem "texture" ainda nao tem arte: usa a do "fallback".
--
-- offsetY: ajuste de altura (px) para os pes ficarem no chao (referencia: pes
-- na linha 120 do quadro). Parado: pes na 119 -> -1; correndo: ~122 -> 2.
-- offsetX: ajuste horizontal (px, olhando para a direita) para o corpo ficar
-- centrado na hitbox: nestas sheets o corpo esta ~8 px a esquerda -> 8.

local ATLAS = "John Drinkwater/Jogador-Atlas.png"

return {
    default = "idle",

    -- Parado: primeiro quadro da IdleShooting (linha 0) (pose de repouso, sem disparo).
    -- A Idle-Sheet antiga (estilo realista) nao e mais usada.
    idle = {
        texture = ATLAS,
        sheetW = 1024, sheetH = 384, frameW = 128, frameH = 128,
        first = 0, count = 1, fps = 1, loop = true,
        offsetX = 8, offsetY = -1,
    },

    idle_shoot = {
        texture = ATLAS,
        sheetW = 1024, sheetH = 384, frameW = 128, frameH = 128,
        first = 0, count = 5, fps = 15, loop = true,
        offsetX = 8, offsetY = -1,
        fallback = "idle",
    },

    run = {
        texture = ATLAS,
        sheetW = 1024, sheetH = 384, frameW = 128, frameH = 128,
        first = 8, count = 8, fps = 12, loop = true,
        offsetX = 8, offsetY = 2,
        sync = "corrida",
        fallback = "idle",
    },

    run_shoot = {
        texture = ATLAS,
        sheetW = 1024, sheetH = 384, frameW = 128, frameH = 128,
        first = 16, count = 8, fps = 12, loop = true,
        offsetX = 8, offsetY = 2,
        sync = "corrida",          -- mesmas pernas da "run": troca sem tropecar
        fallback = "run",
    },

    -- ainda sem arte (usam a reserva):
    jump       = { fallback = "idle" },
    jump_shoot = { fallback = "idle_shoot" },
    respawn    = { fallback = "idle" },
}
