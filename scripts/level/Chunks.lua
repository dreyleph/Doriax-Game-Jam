-- Chunks.lua
-- Modulos do mapa procedural. Cada tela (1280 px) e montada com 4 modulos de
-- 320 px sorteados; cada modulo tem coordenadas LOCAIS: x de 0 a 320 a partir
-- do inicio do modulo, y absoluto (topo do chao principal = 80).
--
--   ground    = { {x0, x1}, ... }          faixas de chao. Espaco sem chao = buraco
--   blocks    = { {x, y, largura, altura} } blocos solidos (degraus, caixas); x,y = canto inferior esquerdo
--   platforms = { {x, y, largura}, ... }   plataformas atravessaveis (x = borda esquerda, y = topo)
--   enemies   = { {x, y, patrulha}, ... }  pontos onde pode surgir inimigo (y = pe do inimigo)
--   weight    = chance relativa de ser sorteado
--   minLevel  = so aparece a partir deste nivel de dificuldade
--   flat      = true para modulos "vazios" (no maximo 1 por tela)
--
-- Regras para um modulo novo ser sempre jogavel (o teste automatico confere):
--   * comecar e terminar com chao (x=0 e x=320), para encaixar com qualquer vizinho
--   * buraco sem plataforma: ate ~240 px; plataforma: ate ~165 px acima de onde se pula
--   * patrulha do inimigo (x +- patrulha +- 24) dentro do chao/plataforma/bloco dele
-- Referencias do jogador: pulo alcanca ~196 px de altura e ~292 px de distancia.

local G = 80   -- topo do chao principal

local Chunks = {
    GROUND_TOP = G,
    MODULE_WIDTH = 320,

    -- primeira tela de toda corrida: plana e sem inimigos
    start = {
        { name = "inicio", ground = { {0, 320} } },
        { name = "inicio", ground = { {0, 320} } },
        { name = "inicio", ground = { {0, 320} } },
        { name = "inicio", ground = { {0, 320} } },
    },

    modules = {
        { name = "plano", weight = 2, flat = true,
          ground = { {0, 320} },
          enemies = { {160, G, 110} } },

        { name = "grupo", weight = 2,
          ground = { {0, 320} },
          enemies = { {80, G, 40}, {240, G, 40} } },

        { name = "buraco", weight = 3,
          ground = { {0, 70}, {250, 320} } },                       -- 180 px

        { name = "buraco_largo", weight = 2, minLevel = 1,
          ground = { {0, 40}, {280, 320} } },                       -- 240 px

        { name = "ponte", weight = 2, minLevel = 1,
          ground = { {0, 30}, {290, 320} },                         -- 260 px com plataforma no meio
          platforms = { {100, 170, 120} } },

        { name = "plataforma", weight = 3,
          ground = { {0, 320} },
          platforms = { {40, 230, 240} },
          enemies = { {160, 230, 60}, {160, G, 100} } },

        { name = "dois_andares", weight = 2, minLevel = 1,
          ground = { {0, 320} },
          platforms = { {10, 220, 150}, {160, 370, 150} },
          enemies = { {235, 370, 40}, {85, 220, 40} } },

        { name = "degrau", weight = 3,
          ground = { {0, 320} },
          blocks = { {100, G, 140, 90} },                           -- topo em 170
          enemies = { {170, 170, 40} } },

        { name = "caixas", weight = 2,
          ground = { {0, 320} },
          blocks = { {40, G, 80, 70}, {200, G, 80, 140} },          -- topos 150 e 220
          enemies = { {240, 220, 10} } },

        { name = "ninho", weight = 2, minLevel = 2,
          ground = { {0, 320} },
          platforms = { {0, 240, 320} },
          enemies = { {90, G, 60}, {230, G, 60}, {160, 240, 110} } },

        { name = "buraco_vigiado", weight = 2, minLevel = 2,
          ground = { {0, 110}, {280, 320} },                        -- 170 px
          platforms = { {170, 240, 150} },
          enemies = { {245, 240, 45} } },
    },
}

return Chunks
