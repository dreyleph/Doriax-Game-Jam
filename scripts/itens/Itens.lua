-- Itens.lua
-- Itens que caem dos inimigos (require("itens.Itens")).
-- Desenho: arte do Edu (assets/Itens/, gerada por tools/montar_sprites_itens.py
-- a partir dos originais em assets/). Item sem arte ainda e um quadrado
-- colorido (campo "color").
--
--   Pisa Macio       (amarelo)   10%  -> recupera 1 vida (ate o maximo de vidas iniciais)
--   Charuto          (preto)      5%  -> tiro automatico e mais rapido ao segurar J (por um tempo)
--   Caranguejo       (laranja) 0.67%  -> imortalidade e dano dos tiros dobrado (por 15s)
--   Escopeta         (azul, 2 quadrados) 3% -> arma secundaria na tecla K (5 projeteis, alcance curto),
--                    10 disparos; pegar outra recarrega; sem balas a arma some
--
-- Cada inimigo abatido sorteia no maximo 1 item. O jogador pega o item encostando nele.
-- Os efeitos temporarios acabam ao morrer; a arma secundaria fica ate acabar a municao.
--
-- Ligacoes com os outros scripts:
--   Enemy:die        -> Itens.tryDrop(scene, x, yDoPe)
--   Player:init      -> Itens.reset()
--   Player:hurt      -> Itens.clearEffects()
--   Player:onFixedUpdate -> Itens.update(player, dt) e Itens.fireModifiers(...)
--   Player (tecla K) -> Itens.secondaryWeapon ("escopeta" ou nil) e Itens.useSecondaryAmmo()
--   Projectile       -> dano * Itens.damageMultiplier()

local GameState = require("game.GameState")
local Run = require("game.Run")

local Itens = {
    SIZE = 28,              -- lado do quadrado (px)
    LIFETIME = 10.0,        -- tempo ate o item sumir do chao (s)
    BLINK_TIME = 2.0,       -- pisca nos ultimos segundos antes de sumir

    CIGAR_DURATION = 10.0,  -- duracao do Charuto (s)
    CIGAR_COOLDOWN = 0.14,  -- intervalo entre tiros com o Charuto (s)

    CRAB_DURATION = 15.0,   -- duracao da imortalidade e do dano dobrado do Caranguejo (s)
    CRAB_DAMAGE_MULT = 2,

    SHOTGUN_AMMO = 10,      -- disparos da Escopeta por item pego

    BLOCK_GAP = 4,          -- espaco entre os quadrados de um item com varios blocos (px)
}

-- Ordem = prioridade do sorteio (o mais raro primeiro). chance = 0 a 1.
Itens.TYPES = {
    {
        id = "caranguejo", name = "Caranguejo", chance = 0.0067,
        color = { 1.00, 0.50, 0.00 },
        sprite = { path = "Itens/caranguejo.png", w = 52, h = 46 },
        apply = function(player)
            Itens.crabTimer = Itens.CRAB_DURATION
            -- usa a invencibilidade do Player (pisca); cair no buraco ainda mata
            player.invincibleTimer = math.max(player.invincibleTimer, Itens.CRAB_DURATION)
        end,
    },
    {
        id = "escopeta", name = "Escopeta", chance = 0.03,
        color = { 0.15, 0.40, 1.00 },
        blocks = 2,   -- sem arte: dois quadrados lado a lado
        sprite = { path = "Itens/escopeta.png", w = 72, h = 38 },   -- arte: mosquete
        apply = function(player)
            Itens.secondaryWeapon = "escopeta"
            Itens.secondaryAmmo = Itens.SHOTGUN_AMMO   -- pegar outra recarrega
        end,
    },
    {
        id = "charuto", name = "Charuto", chance = 0.05,
        color = { 0.05, 0.05, 0.05 },
        sprite = { path = "Itens/charuto.png", w = 39, h = 48 },
        apply = function(player)
            Itens.cigarTimer = Itens.CIGAR_DURATION
        end,
    },
    {
        id = "pisa_macio", name = "Pisa Macio", chance = 0.10,
        color = { 1.00, 0.90, 0.10 },
        sprite = { path = "Itens/pisa_macio.png", w = 38, h = 48 },
        apply = function(player)
            GameState.lives = math.min(GameState.lives + 1, GameState.startLives)
        end,
    },
}

local drops = {}         -- itens no chao: { sprites, entities, type, x, y, halfW, timeLeft }
Itens.cigarTimer = 0
Itens.crabTimer = 0
Itens.secondaryWeapon = nil   -- slot de arma secundaria (nil = vazio)
Itens.secondaryAmmo = 0

-- Estado -------------------------------------------------------------------

-- Chamado a cada (re)inicio da fase: a cena antiga ja destruiu as entidades
function Itens.reset()
    drops = {}
    Itens.clearEffects()
    Itens.secondaryWeapon = nil
    Itens.secondaryAmmo = 0
end

-- Ao morrer: so os efeitos temporarios (a arma secundaria continua)
function Itens.clearEffects()
    Itens.cigarTimer = 0
    Itens.crabTimer = 0
end

-- Drop ------------------------------------------------------------------------

-- Sorteia um unico numero: 0-0.67% caranguejo, 0.67-3.67% escopeta,
-- 3.67-8.67% charuto, 8.67-18.67% pisa macio
function Itens.rollType()
    local r = math.random()
    local acc = 0
    for _, t in ipairs(Itens.TYPES) do
        acc = acc + t.chance
        if r < acc then return t end
    end
    return nil
end

-- Sprite com a arte do item, no tamanho da imagem (1 pixel da imagem = 1 px
-- no mundo) e com filtro "nearest" (pixels nitidos)
local function artSprite(scene, art)
    local sprite = Sprite(scene)
    sprite.entityOwned = false   -- destruido por este modulo
    sprite:setSize(art.w, art.h)
    pcall(function()
        local mat = sprite.material
        local t = mat.baseColorTexture
        t.minFilter = TextureFilter.NEAREST
        t.magFilter = TextureFilter.NEAREST
        mat.baseColorTexture = t
        sprite.material = mat
    end)
    sprite:setTexture(art.path)
    return sprite
end

-- x = centro, y = pe de quem dropou
function Itens.spawn(scene, itemType, x, y)
    local art = itemType.sprite
    if art then
        local sprite = artSprite(scene, art)
        sprite.position = Vector3(x - art.w / 2, y, 0)   -- canto inferior esquerdo, apoiado no chao
        drops[#drops + 1] = {
            scene = scene, sprites = { sprite }, entities = { sprite.entity }, type = itemType,
            x = x, y = y, halfW = art.w / 2, halfH = art.h / 2, timeLeft = Itens.LIFETIME,
        }
        return
    end

    local s = Itens.SIZE
    local n = itemType.blocks or 1
    local width = n * s + (n - 1) * Itens.BLOCK_GAP
    local c = itemType.color
    local sprites, entities = {}, {}
    for i = 0, n - 1 do
        local sprite = Sprite(scene)
        -- a entidade e destruida por este modulo, nao pelo coletor de lixo do Lua
        sprite.entityOwned = false
        sprite:setSize(s, s)
        sprite.color = Vector4(c[1], c[2], c[3], 1)
        -- posicao = canto inferior esquerdo
        sprite.position = Vector3(x - width / 2 + i * (s + Itens.BLOCK_GAP), y, 0)
        sprites[#sprites + 1] = sprite
        entities[#entities + 1] = sprite.entity
    end

    drops[#drops + 1] = {
        scene = scene, sprites = sprites, entities = entities, type = itemType,
        x = x, y = y, halfW = width / 2, halfH = s / 2, timeLeft = Itens.LIFETIME,
    }
end

function Itens.tryDrop(scene, x, y)
    local t = Itens.rollType()
    if t then Itens.spawn(scene, t, x, y) end
end

local function removeDrop(i)
    local d = drops[i]
    for _, e in ipairs(d.entities) do
        if d.scene:isEntityCreated(e) then
            d.scene:destroyEntity(e)
        end
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

-- Gasta 1 disparo da arma secundaria; sem balas, esvazia o slot
function Itens.useSecondaryAmmo()
    Itens.secondaryAmmo = math.max(Itens.secondaryAmmo - 1, 0)
    if Itens.secondaryAmmo == 0 then
        Itens.secondaryWeapon = nil
        Log.print("Escopeta sem balas")
    end
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

    for i = #drops, 1, -1 do
        local d = drops[i]
        d.timeLeft = d.timeLeft - dt

        -- centro do item
        local half = d.halfH or Itens.SIZE / 2
        local cx, cy = d.x, d.y + half
        local touching = player
            and math.abs(px - cx) <= halfW + d.halfW
            and math.abs(py - cy) <= halfH + half
        local behindCamera = Run.lockBackwards and Run.cameraLeft and cx + d.halfW < Run.cameraLeft

        if touching then
            d.type.apply(player)
            Log.print("Pegou item: " .. d.type.name)
            removeDrop(i)
        elseif d.timeLeft <= 0 or behindCamera then
            removeDrop(i)
        elseif d.timeLeft < Itens.BLINK_TIME then
            local visible = math.floor(d.timeLeft * 10) % 2 == 0
            for _, sprite in ipairs(d.sprites) do sprite.visible = visible end
        end
    end
end

return Itens
