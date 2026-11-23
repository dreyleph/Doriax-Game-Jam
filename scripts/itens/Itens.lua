-- Itens.lua
-- Itens que caem dos inimigos (require("itens.Itens")).
-- Graficos provisorios: quadrados coloridos.
--
--   Pisa Macio       (amarelo)   5%  -> recupera 1 vida (ate o maximo de vidas iniciais)
--   Charuto          (preto)     1%  -> tiro automatico e mais rapido ao segurar J (por um tempo)
--   Caranguejo       (laranja) 0.1%  -> recupera todas as vidas e dobra o dano dos tiros (por um tempo)
--
-- Cada inimigo abatido sorteia no maximo 1 item. O jogador pega o item encostando nele.
-- Os efeitos temporarios acabam ao morrer (como perder a arma no Metal Slug).
--
-- Ligacoes com os outros scripts:
--   Enemy:die        -> Itens.tryDrop(scene, x, yDoPe)
--   Player:init      -> Itens.reset()
--   Player:hurt      -> Itens.clearEffects()
--   Player:onFixedUpdate -> Itens.update(player, dt) e Itens.fireModifiers(...)
--   Projectile       -> dano * Itens.damageMultiplier()

local GameState = require("game.GameState")
local Run = require("game.Run")

local Itens = {
    SIZE = 28,              -- lado do quadrado (px)
    LIFETIME = 10.0,        -- tempo ate o item sumir do chao (s)
    BLINK_TIME = 2.0,       -- pisca nos ultimos segundos antes de sumir

    CIGAR_DURATION = 10.0,  -- duracao do Charuto (s)
    CIGAR_COOLDOWN = 0.14,  -- intervalo entre tiros com o Charuto (s)

    CRAB_DURATION = 10.0,   -- duracao do dano dobrado do Caranguejo (s)
    CRAB_DAMAGE_MULT = 2,
}

-- Ordem = prioridade do sorteio (o mais raro primeiro). chance = 0 a 1.
Itens.TYPES = {
    {
        id = "caranguejo", name = "Caranguejo", chance = 0.001,
        color = { 1.00, 0.50, 0.00 },
        apply = function(player)
            GameState.lives = GameState.startLives
            Itens.crabTimer = Itens.CRAB_DURATION
        end,
    },
    {
        id = "charuto", name = "Charuto", chance = 0.01,
        color = { 0.05, 0.05, 0.05 },
        apply = function(player)
            Itens.cigarTimer = Itens.CIGAR_DURATION
        end,
    },
    {
        id = "pisa_macio", name = "Pisa Macio", chance = 0.05,
        color = { 1.00, 0.90, 0.10 },
        apply = function(player)
            GameState.lives = math.min(GameState.lives + 1, GameState.startLives)
        end,
    },
}

local drops = {}         -- itens no chao: { sprite, entity, type, x, y, timeLeft }
Itens.cigarTimer = 0
Itens.crabTimer = 0

-- Estado -------------------------------------------------------------------

-- Chamado a cada (re)inicio da fase: a cena antiga ja destruiu as entidades
function Itens.reset()
    drops = {}
    Itens.clearEffects()
end

function Itens.clearEffects()
    Itens.cigarTimer = 0
    Itens.crabTimer = 0
end

-- Drop ------------------------------------------------------------------------

-- Sorteia um unico numero: 0-0.1% caranguejo, 0.1-1.1% charuto, 1.1-6.1% pisa macio
function Itens.rollType()
    local r = math.random()
    local acc = 0
    for _, t in ipairs(Itens.TYPES) do
        acc = acc + t.chance
        if r < acc then return t end
    end
    return nil
end

-- x = centro, y = pe de quem dropou
function Itens.spawn(scene, itemType, x, y)
    local s = Itens.SIZE
    local sprite = Sprite(scene)
    -- a entidade e destruida por este modulo, nao pelo coletor de lixo do Lua
    sprite.entityOwned = false
    sprite:setSize(s, s)
    local c = itemType.color
    sprite.color = Vector4(c[1], c[2], c[3], 1)
    sprite.position = Vector3(x - s / 2, y, 0)   -- posicao = canto inferior esquerdo

    drops[#drops + 1] = {
        scene = scene, sprite = sprite, entity = sprite.entity, type = itemType,
        x = x, y = y, timeLeft = Itens.LIFETIME,
    }
end

function Itens.tryDrop(scene, x, y)
    local t = Itens.rollType()
    if t then Itens.spawn(scene, t, x, y) end
end

local function removeDrop(i)
    local d = drops[i]
    if d.scene:isEntityCreated(d.entity) then
        d.scene:destroyEntity(d.entity)
    end
    table.remove(drops, i)
end

-- Efeitos -------------------------------------------------------------------

-- Retorna (tiroAutomatico, intervalo) considerando o Charuto
function Itens.fireModifiers(autoFire, cooldown)
    if Itens.cigarTimer > 0 then
        return true, math.min(cooldown, Itens.CIGAR_COOLDOWN)
    end
    return autoFire, cooldown
end

function Itens.damageMultiplier()
    if Itens.crabTimer > 0 then return Itens.CRAB_DAMAGE_MULT end
    return 1
end

-- Atualizacao (chamada pelo Player a cada passo fisico) ---------------------

-- halfW/halfH = metade da caixa do jogador
function Itens.update(player, dt, px, py, halfW, halfH)
    if Itens.cigarTimer > 0 then Itens.cigarTimer = math.max(Itens.cigarTimer - dt, 0) end
    if Itens.crabTimer > 0 then Itens.crabTimer = math.max(Itens.crabTimer - dt, 0) end

    local half = Itens.SIZE / 2
    for i = #drops, 1, -1 do
        local d = drops[i]
        d.timeLeft = d.timeLeft - dt

        -- centro do item
        local cx, cy = d.x, d.y + half
        local touching = player
            and math.abs(px - cx) <= halfW + half
            and math.abs(py - cy) <= halfH + half
        local behindCamera = Run.lockBackwards and Run.cameraLeft and cx < Run.cameraLeft - Itens.SIZE

        if touching then
            d.type.apply(player)
            Log.print("Pegou item: " .. d.type.name)
            removeDrop(i)
        elseif d.timeLeft <= 0 or behindCamera then
            removeDrop(i)
        elseif d.timeLeft < Itens.BLINK_TIME then
            d.sprite.visible = math.floor(d.timeLeft * 10) % 2 == 0
        end
    end
end

return Itens
