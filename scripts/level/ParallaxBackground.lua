-- ParallaxBackground.lua
-- Fundo com efeito parallax: vai na entidade "Fundo", filha da Camera.
-- Como filho da camera, o fundo acompanha a tela; o script aplica um
-- deslocamento lento por cima (fator < 1 = mais devagar que o chao = longe).
--
-- O fundo e uma fileira infinita de "vagas" (k = ..., 0, 1, 2, ...), cada uma
-- com a largura de uma copia. A copia que ocupa a vaga k e sempre a de numero
-- (k mod N): com 4 copias, cada copia fica presa a uma posicao do ciclo e nunca
-- precisa trocar de imagem. Sequencia atual (montada na cena):
--   vaga par   -> copias 1 e 3: Background1 (com o Cruzeiro)
--   vaga impar -> copias 2 e 4: Background_sem_cruz1, espelhada (mirrorAlternate)
-- Espelhar as vagas impares faz cada emenda juntar bordas equivalentes
-- (direita com direita, esquerda com esquerda), sem corte.

local Run = require("game.Run")

local ParallaxBackground = {
    properties = {
        { name = "tileA", displayName = "Copia 1 do fundo (vaga par)",   type = "Sprite" },
        { name = "tileB", displayName = "Copia 2 do fundo (vaga impar)", type = "Sprite" },
        { name = "tileC", displayName = "Copia 3 do fundo (vaga par)",   type = "Sprite" },
        { name = "tileD", displayName = "Copia 4 do fundo (vaga impar)", type = "Sprite" },
        { name = "factor",     displayName = "Parallax (0 = parado na tela, 1 = anda como o chao)", type = "float", default = 0.2 },
        { name = "tileWidth",  displayName = "Largura de cada copia (px)",  type = "float", default = 960.0 },
        { name = "tileHeight", displayName = "Altura de cada copia (px)",   type = "float", default = 720.0 },
        { name = "offsetY",    displayName = "Altura da base do fundo (px)", type = "float", default = 80.0 },
        { name = "mirrorAlternate", displayName = "Espelhar copias das vagas impares", type = "bool", default = true },
    }
}

function ParallaxBackground:init()
    for _, p in ipairs(ParallaxBackground.properties) do
        if self[p.name] == nil and p.default ~= nil then self[p.name] = p.default end
    end
    self.tiles = {}
    for _, t in ipairs({ self.tileA, self.tileB, self.tileC, self.tileD }) do
        if t then self.tiles[#self.tiles + 1] = t end
    end
    if #self.tiles % 2 ~= 0 then
        Log.warn("Fundo: use um numero par de copias para a alternancia com/sem cruz ficar fixa")
    end
    self.lastShift = nil
    RegisterEngineEvent(self, "onUpdate")
end

-- Posicao LOCAL (relativa a camera) do centro da vaga k, para a camera em "left"
function ParallaxBackground.slotX(left, factor, width, k)
    local shift = left * factor                   -- quanto o fundo ja "andou" dentro da tela
    return k * width - shift + width / 2
end

function ParallaxBackground:layout()
    local n = #self.tiles
    if n == 0 then return end
    local left = Run.cameraLeft or 0
    local shift = left * self.factor
    if shift == self.lastShift then return end    -- camera parada: nada a fazer
    self.lastShift = shift

    local w = self.tileWidth
    local kStart = math.floor(shift / w)          -- primeira vaga que aparece na tela
    local y = self.offsetY + self.tileHeight / 2
    for k = kStart, kStart + n - 1 do
        local tile = self.tiles[(k % n) + 1]      -- cada copia sempre na mesma posicao do ciclo
        tile.position = Vector3(ParallaxBackground.slotX(left, self.factor, w, k), y, -1)
        local mirrored = self.mirrorAlternate and (k % 2 ~= 0)
        tile.scale = Vector3(mirrored and -1 or 1, 1, 1)
    end
end

function ParallaxBackground:onUpdate()
    self:layout()
end

return ParallaxBackground
