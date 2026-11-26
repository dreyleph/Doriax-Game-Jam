-- EnemyAnimations2.lua
-- Animacoes do inimigo atirador (assets/Enemy2/), quadros de 128x128, virado
-- para a DIREITA (a esquerda e espelhada). Tudo no atlas "Inimigo2-Atlas.png"
-- (1024x384, 8 colunas), montado por tools/montar_atlas_inimigo.py:
--   linha 0 (first = 0)  : Runnig-Sheet2 (8 quadros)
--   linha 1 (first = 8)  : Idle-Sheet2 (1 quadro)
--   linha 2 (first = 16) : Shooting (4 quadros)
--
-- Mesmo formato e mesmos ajustes do EnemyAnimations.lua (o desenho do Enemy2
-- esta alinhado igual ao do Enemy1). Extras do atirador:
--   aim   : parado mirando (primeiro quadro do Shooting, segurando a arma)
--   shoot : disparo, tocado do inicio a cada tiro (Enemy:fireAt)

local ATLAS = "Enemy2/Inimigo2-Atlas.png"

local function anim(first, count, fps, offsetY, extra)
    local def = {
        texture = ATLAS, sheetW = 1024, sheetH = 384, frameW = 128, frameH = 128,
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
    chase = anim(0, 8, 18, 5, { sync = "passos" }),   -- correndo
    aim   = anim(16, 1, 1, 3),                        -- mirando no jogador
    shoot = anim(16, 4, 12, 3, { loop = false }),     -- disparo
}
