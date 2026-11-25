-- Run.lua
-- Estado da corrida atual (modo procedural), compartilhado entre camera,
-- jogador e gerador via require("game.Run").

local Run = {
    viewWidth = 960,      -- largura da tela em pixels (o CameraFollow atualiza com Engine.canvasWidth)
    cameraLeft = nil,     -- borda esquerda da camera; nil = sem limite (cena sem CameraFollow travada)
    lockBackwards = false -- true: a camera nao volta e o jogador nao sai pela esquerda
}

-- Quem escreve aqui e o CameraFollow (no init e a cada frame). Nao leia
-- cameraLeft dentro de um init: a ordem de inicializacao entre scripts nao e
-- garantida e o valor pode ser da corrida anterior.

-- Superficies de apoio (para renascer) -------------------------------------
-- O gerador registra cada faixa onde da para ficar em pe: { x0, x1, top }.
-- So valem na cena que as registrou (sceneId), para uma cena sem gerador
-- (ex.: Fase Teste) nao usar as da corrida anterior.

Run.surfaces = {}
Run.surfacesSceneId = nil

function Run.clearSurfaces(sceneId)
    Run.surfaces = {}
    Run.surfacesSceneId = sceneId
end

function Run.addSurface(x0, x1, top, owner)
    if x1 - x0 <= 0 then return end
    Run.surfaces[#Run.surfaces + 1] = { x0 = x0, x1 = x1, top = top, owner = owner }
end

function Run.removeSurfaces(owner)
    for i = #Run.surfaces, 1, -1 do
        if Run.surfaces[i].owner == owner then table.remove(Run.surfaces, i) end
    end
end

-- Ponto mais proximo de x em cima de uma superficie, a pelo menos "margin" px
-- de cada borda e com o x entre minX e maxX (parte visivel da tela).
-- Retorna x, topo  (ou nil se nao houver nenhum).
function Run.findSafeSpot(x, margin, minX, maxX)
    local bestX, bestTop, bestDist
    for _, s in ipairs(Run.surfaces) do
        local lo, hi = s.x0 + margin, s.x1 - margin
        if minX and lo < minX then lo = minX end
        if maxX and hi > maxX then hi = maxX end
        if lo <= hi then
            local px = math.min(math.max(x, lo), hi)
            local d = math.abs(px - x)
            -- empate: prefere a superficie mais baixa (o chao)
            if not bestDist or d < bestDist - 1e-6 or (math.abs(d - bestDist) <= 1e-6 and s.top < bestTop) then
                bestX, bestTop, bestDist = px, s.top, d
            end
        end
    end
    return bestX, bestTop
end

return Run
