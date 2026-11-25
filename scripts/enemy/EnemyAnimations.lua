-- EnemyAnimations.lua
-- Animacoes do inimigo comum (assets/Enemy1/), quadros de 128x128, virado
-- para a DIREITA (a esquerda e espelhada). Tudo no atlas "Inimigo-Atlas.png"
-- (1024x256, 8 colunas), montado por tools/montar_atlas_inimigo.py:
--   linha 0 (first = 0) : Runing-Sheet (8 quadros)
--   linha 1 (first = 8) : Idle-Sheet (1 quadro)
--
-- "walk" e "chase" usam os mesmos quadros; so muda a velocidade da animacao
-- (o "sync" igual faz a troca continuar do mesmo passo, sem tropecar).
-- offsetX/offsetY: ajuste do desenho em relacao ao centro da hitbox (40x104):
-- o corpo fica ~5 px a direita do centro do quadro e os pes na linha ~120.

local ATLAS = "Enemy1/Inimigo-Atlas.png"

local function anim(first, count, fps, offsetY, extra)
    local def = {
        texture = ATLAS, sheetW = 1024, sheetH = 256, frameW = 128, frameH = 128,
        first = first, count = count, fps = fps, loop = true,
        offsetX = -5, offsetY = offsetY,
    }
    for k, v in pairs(extra or {}) do def[k] = v end
    return def
end

return {
    default = "idle",
    idle  = anim(8, 1, 1, 3),
    walk  = anim(0, 8, 8, 5, { sync = "passos" }),    -- andando a toa (devagar)
    chase = anim(0, 8, 18, 5, { sync = "passos" }),   -- perseguindo o jogador (rapido)
}
