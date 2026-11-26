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
-- O gerador registra cada faixa onde da para ficar em pe: { x0, x1, top, platform }
-- (platform = true: plataforma atravessavel, da para descer por ela).
-- So valem na cena que as registrou (sceneId), para uma cena sem gerador
-- (ex.: Fase Teste) nao usar as da corrida anterior.

Run.surfaces = {}
Run.surfacesSceneId = nil

-- Muda sempre que a lista de superficies muda: invalida o cache dos trechos
-- emendados (Run.surfaceSpan), que a IA dos inimigos consulta muitas vezes
-- por passo de fisica
Run.surfacesVersion = 0

function Run.clearSurfaces(sceneId)
    Run.surfaces = {}
    Run.surfacesSceneId = sceneId
    Run.surfacesVersion = Run.surfacesVersion + 1
end

function Run.addSurface(x0, x1, top, owner, platform)
    if x1 - x0 <= 0 then return end
    Run.surfaces[#Run.surfaces + 1] = { x0 = x0, x1 = x1, top = top, owner = owner, platform = platform == true }
    Run.surfacesVersion = Run.surfacesVersion + 1
end

function Run.removeSurfaces(owner)
    local removed = false
    for i = #Run.surfaces, 1, -1 do
        if Run.surfaces[i].owner == owner then
            table.remove(Run.surfaces, i)
            removed = true
        end
    end
    if removed then Run.surfacesVersion = Run.surfacesVersion + 1 end
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

-- Trecho continuo de apoio onde esta o ponto (x, pe): a superficie que contem
-- x com o topo perto da altura do pe, emendada com as vizinhas de mesmo topo
-- (o chao de dois trechos do gerador vira um so). Retorna x0, x1, topo,
-- plataforma (true se for atravessavel) ou nil.
function Run.surfaceSpan(x, feetY, tolerance)
    tolerance = tolerance or 12
    local found
    for _, s in ipairs(Run.surfaces) do
        if x >= s.x0 - 1 and x <= s.x1 + 1 and math.abs(s.top - feetY) <= tolerance then
            found = s
            break
        end
    end
    if not found then return nil end
    -- o trecho emendado so depende da superficie achada: guarda ate a lista mudar
    if found.spanVersion == Run.surfacesVersion then
        return found.spanX0, found.spanX1, found.top, found.platform
    end
    local x0, x1, top = found.x0, found.x1, found.top
    local grew = true
    while grew do
        grew = false
        for _, s in ipairs(Run.surfaces) do
            if math.abs(s.top - top) < 0.5 then
                if s.x1 >= x0 - 0.5 and s.x0 < x0 then x0 = s.x0; grew = true end
                if s.x0 <= x1 + 0.5 and s.x1 > x1 then x1 = s.x1; grew = true end
            end
        end
    end
    found.spanX0, found.spanX1, found.spanVersion = x0, x1, Run.surfacesVersion
    return x0, x1, top, found.platform
end

-- Superficie mais alta embaixo do ponto (x, y), pelo menos "minDrop" abaixo.
-- Retorna o trecho continuo dela (x0, x1, topo, plataforma) ou nil (buraco).
function Run.surfaceBelow(x, y, minDrop)
    local best
    for _, s in ipairs(Run.surfaces) do
        if x >= s.x0 and x <= s.x1 and s.top <= y - (minDrop or 0) and (not best or s.top > best.top) then
            best = s
        end
    end
    if not best then return nil end
    return Run.surfaceSpan(x, best.top, 0.5)
end

return Run
