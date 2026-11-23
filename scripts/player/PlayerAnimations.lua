-- PlayerAnimations.lua
-- Animacoes do jogador. Para adicionar uma animacao nova (ex.: correr),
-- coloque a sheet em assets/ e acrescente uma entrada aqui. Animacoes que
-- ainda nao existem usam a "default" automaticamente.
--
-- Nomes que o Player.lua ja pede:
--   idle  = parado no chao
--   run   = andando no chao
--   jump  = no ar (subindo ou caindo)
--
-- A arte desenha o personagem virado para a DIREITA; a esquerda e espelhada.

return {
    default = "idle",

    idle = {
        texture = "Idle/Idle-Sheet.png",
        sheetW = 768, sheetH = 128,
        frameW = 128, frameH = 128,
        first = 0, count = 6,
        fps = 5, loop = true,    -- quadros por segundo: menor = mais lenta (5 -> ciclo de 1,2 s)
    },

    -- run = {
    --     texture = "Run/Run-Sheet.png",
    --     sheetW = 1024, sheetH = 128, frameW = 128, frameH = 128,
    --     first = 0, count = 8, fps = 12, loop = true,
    -- },
}
