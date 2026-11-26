-- PlayerAnimations.lua
-- Animacoes do jogador (quadros de 128x128, personagem virado para a DIREITA;
-- a esquerda e espelhada).
--
-- IMPORTANTE: todas as animacoes usam a MESMA imagem, o atlas
-- "Jogador-Atlas.png" (1024x640, 8 colunas, uma animacao por linha), montado
-- a partir das sheets de assets/John Drinkwater/ por tools/montar_atlas_jogador.py.
-- Trocar de textura em jogo (setTexture) faz a engine descartar a imagem e
-- recarregar do disco, e o personagem sumia/"bugava" a cada troca de animacao.
--   linha 0 (first = 0)  : IdleShooting (5 quadros)   parado atirando
--   linha 1 (first = 8)  : Running (8)                correndo
--   linha 2 (first = 16) : Running&Shooting (8)       correndo atirando
--   linha 3 (first = 24) : Idle-Sheet (7)             parado: repouso + gole d'agua (Joao Bebe Agua)
--   linha 4 (first = 32) : Jumping (3)                pulo
-- Arte nova: rode o script do atlas e use first = linha * 8.
--
-- Nomes que o Player.lua pede:
--   idle         parado no chao                 idle_shoot   parado atirando
--   run          andando no chao                run_shoot    andando atirando
--   jump         no ar                          jump_shoot   no ar atirando
--   hurt         levou dano (sem arte ainda: o jogador some na hora, como antes)
--   respawn      reaparecendo depois de morrer (jogador parado, sem controle)
-- Animacao sem "texture" ainda nao tem arte: usa a do "fallback".
--
-- offsetY: ajuste de altura (px) para os pes ficarem no chao (referencia: pes
-- na linha 120 do quadro). Parado: pes na 119 -> -1; correndo/pulando: ~122 -> 2.
-- offsetX: ajuste horizontal (px, olhando para a direita) para o corpo ficar
-- centrado na hitbox: nestas sheets o corpo esta ~8 px a esquerda -> 8.

local ATLAS = "John Drinkwater/Jogador-Atlas.png"
local W, H = 1024, 640

local function anim(first, count, fps, loop, offsetY, extra)
    local def = {
        texture = ATLAS, sheetW = W, sheetH = H, frameW = 128, frameH = 128,
        first = first, count = count, fps = fps, loop = loop,
        offsetX = 8, offsetY = offsetY,
    }
    for k, v in pairs(extra or {}) do def[k] = v end
    return def
end

return {
    default = "idle",

    -- Parado: Idle-Sheet inteira em loop continuo (a cabeca nao para de
    -- mexer), comecando assim que ele para. Para segurar o repouso antes de
    -- cada gole, troque por: durations = { 2.5, 0.12, 0.12, 0.14, 0.16, 0.16, 0.18 }
    idle       = anim(24, 7, 8, true, -1),
    idle_shoot = anim(0, 5, 15, true, -1, { fallback = "idle" }),

    run       = anim(8, 8, 12, true, 2, { sync = "corrida", fallback = "idle" }),
    run_shoot = anim(16, 8, 12, true, 2, { sync = "corrida", fallback = "run" }),  -- mesmas pernas: troca sem tropecar

    -- Pulo: os 3 quadros tocam uma vez ao sair do chao e o ultimo fica ate pousar
    jump       = anim(32, 3, 10, false, 2, { fallback = "idle" }),
    jump_shoot = { fallback = "jump" },   -- ainda sem arte: usa o pulo

    -- Dano: ainda sem arte. Quando chegar a sheet, entra como nova linha do
    -- atlas e fica assim (toca uma vez, depois o jogador some e renasce):
    --   hurt = anim(40, N, 10, false, -1),
    hurt = {},

    -- ainda sem arte (usa a reserva):
    respawn = { fallback = "idle" },
}
