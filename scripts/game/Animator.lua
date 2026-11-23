-- Animator.lua
-- Animador de sprite por sprite sheets (uma sheet por animacao).
-- Nao usa a lista de quadros da engine (limite de 32 por sprite): calcula a
-- regiao da textura de cada quadro e aplica com setTextureRect.
--
-- Definicao de uma animacao:
--   { texture = "Idle/Idle-Sheet.png",   -- caminho dentro de assets/
--     sheetW = 768, sheetH = 128,        -- tamanho da imagem inteira
--     frameW = 128, frameH = 128,        -- tamanho de cada quadro
--     first = 0, count = 6,              -- primeiro quadro e quantidade (lidos da esquerda p/ direita, de cima p/ baixo)
--     fps = 8, loop = true }

local Animator = {}
Animator.__index = Animator

-- sprite: objeto Sprite; animations: tabela nome -> definicao (+ campo "default")
function Animator.new(sprite, animations)
    local self = setmetatable({
        sprite = sprite,
        animations = animations,
        name = nil, current = nil,
        time = 0, frame = -1,
        texture = nil,
    }, Animator)
    self:play(animations.default or "idle")
    return self
end

function Animator:has(name)
    return type(self.animations[name]) == "table"
end

-- Toca a animacao; se nao existir (ainda nao feita pela arte), usa a padrao
function Animator:play(name, restart)
    if not self:has(name) then name = self.animations.default or "idle" end
    local def = self.animations[name]
    if not def then return end
    if self.name == name and not restart then return end

    self.name, self.current = name, def
    self.time, self.frame = 0, -1
    if def.texture and def.texture ~= self.texture then
        self.sprite:setTexture(def.texture)
        self.texture = def.texture
    end
    self:update(0)
end

-- Quadro (0 = primeiro) para um tempo decorrido
function Animator.frameAt(def, time)
    local count = def.count or 1
    if count <= 1 then return 0 end
    -- tolerancia: somar 1/60 varias vezes da 0.4999... em vez de 0.5
    local f = math.floor(time * (def.fps or 8) + 1e-6)
    if def.loop == false then
        return math.min(f, count - 1)
    end
    return f % count
end

function Animator:update(dt)
    local def = self.current
    if not def then return end
    self.time = self.time + dt
    local f = Animator.frameAt(def, self.time)
    if f ~= self.frame then
        self.frame = f
        self:apply()
    end
end

-- Terminou? (so faz sentido para animacoes sem loop)
function Animator:finished()
    local def = self.current
    return def ~= nil and def.loop == false and self.frame >= (def.count or 1) - 1
end

-- Regiao normalizada (0 a 1) do quadro atual dentro da sheet
function Animator.frameRect(def, frame)
    local cols = math.max(1, math.floor(def.sheetW / def.frameW))
    local index = (def.first or 0) + frame
    local col, row = index % cols, math.floor(index / cols)
    return col * def.frameW / def.sheetW, row * def.frameH / def.sheetH,
           def.frameW / def.sheetW, def.frameH / def.sheetH
end

function Animator:apply()
    local x, y, w, h = Animator.frameRect(self.current, self.frame)
    self.sprite:setTextureRect(x, y, w, h)
end

return Animator
