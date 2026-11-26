-- Player.lua
-- Controle do jogador (estilo Metal Slug).
--
-- Controles:
--   A / D ou Setas esquerda/direita -> andar
--   Espaco                          -> pular
--   S / Seta para baixo + pulo      -> descer da plataforma (fora do chao principal)
--   J                               -> atirar
--   K                               -> arma secundaria (so se tiver pego, ex.: Escopeta)
--   L                               -> faca (corpo a corpo, mesma mira dos tiros)
--   E                               -> dash na direcao segurada (sem direcao = para frente)
--   W / Seta para cima (segurando)  -> mirar para cima (+ andando = diagonal)
--   S / Seta para baixo no ar       -> mirar para baixo (+ andando = diagonal)
--
-- Faca + dash: eliminar um inimigo com a faca zera a espera do dash e, se
-- estiver no ar, libera um pulo extra (ate encostar no chao).
--
-- Vidas (estilo arcade): ao levar dano toca a animacao de dano, perde 1 vida
-- (os pontos ficam) e renasce na superficie segura mais proxima, com
-- invencibilidade temporaria (piscando).
-- Sem vidas: GAME OVER e a fase recomeca do zero.

local Combat = require("game.Combat")
local GameState = require("game.GameState")
local Run = require("game.Run")
local Itens = require("itens.Itens")
local EnemyShots = require("game.EnemyShots")
local Animator = require("game.Animator")
local PlayerAnimations = require("player.PlayerAnimations")
local TextureKeeper = require("game.TextureKeeper")

local Player = {
    properties = {
        { name = "visual",        displayName = "Sprite do personagem (filho)", type = "Sprite" },
        { name = "visualOffsetX", displayName = "Desenho: deslocamento X (px)", type = "float", default = -9.0 },
        { name = "visualOffsetY", displayName = "Desenho: deslocamento Y (px)", type = "float", default = 4.0 },
        { name = "moveSpeed",     displayName = "Velocidade (px/s)",            type = "float", default = 320.0 },
        { name = "jumpSpeed",     displayName = "Velocidade do pulo (px/s)",    type = "float", default = 860.0 },
        { name = "gravityScale",  displayName = "Escala da gravidade",          type = "float", default = 3.0 },
        { name = "maxFallSpeed",  displayName = "Queda maxima (px/s)",          type = "float", default = 1400.0 },
        { name = "respawnY",      displayName = "Y limite (abaixo disso morre)", type = "float", default = -400.0 },
        { name = "fireCooldown",  displayName = "Intervalo entre tiros (s)",    type = "float", default = 0.15 },
        { name = "shotgunCooldown", displayName = "Escopeta: intervalo entre tiros (s)", type = "float", default = 0.6 },
        { name = "shotgunPellets",  displayName = "Escopeta: projeteis por tiro",        type = "int",   default = 5 },
        { name = "shotgunSpread",   displayName = "Escopeta: abertura total (graus)",    type = "float", default = 40.0 },
        { name = "shotgunLifetime", displayName = "Escopeta: tempo de vida do projetil (s)", type = "float", default = 0.35 },
        { name = "autoFire",      displayName = "Tiro automatico (segurar J)",  type = "bool",  default = false },
        { name = "dropTime",      displayName = "Tempo atravessando (s)",       type = "float", default = 0.35 },
        { name = "dashSpeed",     displayName = "Dash: velocidade (px/s)",      type = "float", default = 1300.0 },
        { name = "dashTime",      displayName = "Dash: duracao do impulso (s)", type = "float", default = 0.15 },
        { name = "dashCooldown",  displayName = "Dash: espera entre dashes (s)", type = "float", default = 1.0 },
        { name = "dashCarryKeep", displayName = "Dash: embalo horizontal mantido ao fim (0-1)", type = "float", default = 0.7 },
        { name = "dashCarryDrag", displayName = "Dash: quanto o embalo freia no chao", type = "float", default = 10.0 },
        { name = "dashAirDrag",   displayName = "Dash: quanto o embalo freia no ar",   type = "float", default = 0.8 },
        { name = "dashUpKeep",    displayName = "Dash: velocidade vertical mantida ao subir (0-1)", type = "float", default = 0.5 },
        { name = "knifeCooldown", displayName = "Faca: intervalo entre golpes (s)", type = "float", default = 0.25 },
        { name = "knifeTime",     displayName = "Faca: duracao do golpe (s)",   type = "float", default = 0.5 },
        { name = "knifePower",    displayName = "Faca: dano (2 = mata qualquer inimigo)", type = "int", default = 2 },
        -- "knifeArea" substitui "knifeSize" (o valor 44 ficou gravado na cena)
        { name = "knifeArea",     displayName = "Faca: tamanho de cada bloco de acerto (px)", type = "float", default = 56.0 },
        { name = "knifeDeflect",  displayName = "Faca: rebate tiros inimigos", type = "bool", default = true },
        { name = "deflectSpeed",  displayName = "Faca: velocidade do tiro rebatido (x)", type = "float", default = 1.5 },
        { name = "allowDiagonal", displayName = "Permitir tiro na diagonal",    type = "bool",  default = true },
        { name = "startLives",        displayName = "Vidas iniciais",                     type = "int",   default = 3 },
        { name = "respawnFreezeTime", displayName = "Animacao de reviver, parado (s)",  type = "float", default = 1.0 },
        { name = "shootAnimTime",     displayName = "Pose de tiro apos atirar (s)",     type = "float", default = 0.3 },
        { name = "respawnDelay",      displayName = "Tempo ate renascer (s)",             type = "float", default = 0.8 },
        { name = "invincibleTime",    displayName = "Invencibilidade ao renascer (s)",    type = "float", default = 2.0 },
        { name = "gameOverDelay",     displayName = "Tempo na tela de game over (s)",     type = "float", default = 3.0 },
    }
}

local GROUND_NORMAL_MIN = 0.6   -- contato conta como chao
local LAND_NORMAL_MIN   = 0.7   -- pouso valido em plataforma atravessavel
-- Metade da hitbox (Body2D do Jogador): 40 x 104 px, so o corpo, sem o casaco.
-- Se mudar a hitbox no editor, atualize aqui (usado na origem dos tiros e no limite da tela).
local HALF_W, HALF_H    = 20, 52
local RESPAWN_EDGE_MARGIN = 24  -- renasce a pelo menos HALF_W + isso da borda da superficie
local HURT_HOLD_TIME = 0.15     -- depois da animacao de dano, ultimo quadro fica isso antes de sumir

local function anyKey(...)
    for i = 1, select("#", ...) do
        if Input.isKeyPressed(select(i, ...)) then
            return true
        end
    end
    return false
end

function Player:init()
    -- propriedades novas ainda nao gravadas na cena chegam como nil
    for _, p in ipairs(Player.properties) do
        if self[p.name] == nil and p.default ~= nil then self[p.name] = p.default end
    end

    Combat.resetLevelState()
    Combat.registerPlayer(self)
    Itens.reset()
    EnemyShots.reset()

    GameState.startLives = self.startLives
    if GameState.needsNewGame then
        GameState.newGame()
    end

    self.object = Object(self.scene, self.entity)
    self.body = Body2D(self.scene, self.entity)

    self.body.fixedRotation = true
    self.body.enableSleep = false
    self.body.gravityScale = self.gravityScale

    local p = self.object.position
    self.spawn = Vector2(p.x, p.y)
    self.lastSafe = Vector2(p.x, p.y)   -- ultimo ponto em que estava no chao

    self.state = "alive"         -- "alive" | "dead" (animacao de dano, depois escondido) | "respawning" (reaparecendo, parado) | "gameover"
    self.stateTimer = 0
    self.invincibleTimer = 0

    self.facing = 1              -- 1 = direita, -1 = esquerda
    self.grounded = false
    self.groundIsPlatform = false
    self.groundEntity = nil
    self.dropEntity = nil        -- plataforma que estamos atravessando
    self.dropTimer = 0
    self.fireTimer = 0
    self.secondaryTimer = 0
    self.knifeTimer = 0
    self.dashTimer = 0           -- > 0: no meio do impulso do dash
    self.dashCooldownTimer = 0   -- > 0: dash ainda indisponivel
    self.dashVX, self.dashVY = 0, 0
    self.dashCarry = 0           -- embalo horizontal que sobra depois do dash
    self.airJumpAvailable = false -- pulo extra ganho ao eliminar com a faca no ar
    self.slash = nil             -- golpe da faca ativo (acompanha o jogador)
    self.shootAnimTimer = 0      -- > 0: mostra a pose de tiro
    self.visualOffsetApplied = nil
    self.jumpWasDown = false
    self.fireWasDown = false
    self.secondaryWasDown = false
    self.knifeWasDown = false
    self.dashWasDown = false

    local physics = self.scene:getPhysicsSystem()
    -- unico filtro de preSolve do jogo: com varios inscritos so o primeiro decide
    RegisterEvent(self, physics.preSolve2D, "onPreSolve")

    -- Desenho do personagem: entidade filha com a sprite sheet. O corpo fisico
    -- fica no Jogador; o filho so e espelhado e animado (nao afeta a fisica).
    self.visualFacing = nil
    if self.visual then
        self.animator = Animator.new(self.visual, PlayerAnimations)
        self:updateVisual(0, false)
    end
    -- efeito da faca: sprites criados ja no inicio (ver prepareSlashFx)
    if self.scene then
        if not pcall(function() self:prepareSlashFx() end) then self.slashFxSprites = nil end
        -- itens e inimigos aparecem/somem o tempo todo: deixa as imagens
        -- deles carregadas para nao ler do disco no meio da partida
        TextureKeeper.keepGameplayTextures(self.scene)
    end
    RegisterEngineEvent(self, "onFixedUpdate")
end

-- Plataformas atravessaveis -------------------------------------------------
-- Toda plataforma com "preSolveEvents" ligado no shape e tratada como one-way:
-- o jogador passa por baixo e pelos lados, e so apoia quando cai por cima.
function Player:onPreSolve(bodyA, shapeA, bodyB, shapeB, manifold)
    local other, otherShape, sign
    if bodyA.entity == self.entity then
        other, otherShape, sign = bodyB, shapeB, -1
    elseif bodyB.entity == self.entity then
        other, otherShape, sign = bodyA, shapeA, 1
    else
        -- contato que nao envolve o jogador: inimigos tambem atravessam
        -- plataformas por baixo e descem por elas (Combat.oneWayFilter)
        return Combat.oneWayFilter(bodyA, shapeA, bodyB, shapeB, manifold)
    end

    if not other:isShapePreSolveEvents(otherShape) then
        return true
    end

    if self.dropTimer > 0 and other.entity == self.dropEntity then
        return false
    end

    -- normal vai de A para B; "upY" e a normal apontando da plataforma para o jogador
    local upY = sign * manifold:getNormal().y
    if upY < LAND_NORMAL_MIN then
        return false
    end
    -- subindo atraves da plataforma: nao prende no meio do pulo
    if self.body.linearVelocity.y > 20 then
        return false
    end
    return true
end

-- Chao ------------------------------------------------------------------
function Player:checkGround()
    local contacts = self.body:getBodyContacts()
    for _, contact in ipairs(contacts) do
        local manifold = contact:getManifold()
        if manifold:getPointCount() > 0 then
            local n = manifold:getNormal()
            local otherBody, otherShape, upY
            if contact:getBodyEntityA() == self.entity then
                upY = -n.y
                otherBody, otherShape = contact:getBodyB(), contact:getShapeIndexB()
            else
                upY = n.y
                otherBody, otherShape = contact:getBodyA(), contact:getShapeIndexA()
            end
            if upY > GROUND_NORMAL_MIN then
                return true, otherBody.entity, otherBody:isShapePreSolveEvents(otherShape)
            end
        end
    end
    return false, nil, false
end

-- Tiro ------------------------------------------------------------------
-- Direcoes: frente, cima, baixo (so no ar) e, com "allowDiagonal",
-- diagonal para cima (cima + andando) e diagonal para baixo (baixo + andando, no ar).
-- Retorna origem (x, y) e direcao (dx, dy) do tiro conforme a mira
function Player:aim(aimUp, aimDown, moving)
    local pos = self.body.position
    local f = self.facing
    local x, y, dx, dy
    local diagonal = self.allowDiagonal and moving
    local canAimDown = aimDown and not self.grounded

    if aimUp and diagonal then
        x, y, dx, dy = pos.x + f * (HALF_W + 8), pos.y + HALF_H, f, 1
    elseif aimUp then
        x, y, dx, dy = pos.x, pos.y + HALF_H + 12, 0, 1
    elseif canAimDown and diagonal then
        x, y, dx, dy = pos.x + f * (HALF_W + 8), pos.y - HALF_H, f, -1
    elseif canAimDown then
        x, y, dx, dy = pos.x, pos.y - HALF_H - 12, 0, -1
    else
        x, y, dx, dy = pos.x + f * (HALF_W + 14), pos.y + 10, f, 0
    end
    return x, y, dx, dy
end

function Player:shoot(aimUp, aimDown, moving)
    local x, y, dx, dy = self:aim(aimUp, aimDown, moving)
    Combat.spawnProjectile(self.scene, x, y, dx, dy)
    self.shootAnimTimer = self.shootAnimTime
end

-- Escopeta: varios projeteis em leque na direcao da mira, com alcance curto
function Player:shootShotgun(aimUp, aimDown, moving)
    local x, y, dx, dy = self:aim(aimUp, aimDown, moving)
    local base = math.atan(dy, dx)
    local n = math.max(self.shotgunPellets, 1)
    local spread = math.rad(self.shotgunSpread)
    for i = 0, n - 1 do
        local a = base
        if n > 1 then a = base - spread / 2 + spread * i / (n - 1) end
        Combat.spawnProjectile(self.scene, x, y, math.cos(a), math.sin(a), self.shotgunLifetime)
    end
    self.shootAnimTimer = self.shootAnimTime
end

-- Faca ------------------------------------------------------------------
-- Golpe corpo a corpo na mesma direcao da mira dos tiros. A area de acerto e
-- feita de blocos quadrados de "Faca: tamanho" px, encostados no jogador.
-- Dano 2: mata qualquer inimigo com um golpe.
-- Blocos em volta do jogador, em unidades
-- de "um bloco para o lado / para cima": (-1, 1) = diagonal superior esquerda.
--   cima (reto ou diagonal)  -> os 3 de cima
--   baixo (reto ou diagonal) -> os 3 de baixo
--   frente (esquerda/direita) -> so o bloco da frente
-- Efeito visual do golpe (assets/VFX/, gerado por tools/montar_vfx_faca.py a
-- partir do pacote "SLASH VFX"): 6 quadros tocados uma vez durante o golpe,
-- no tamanho da area de acerto. A arte da frente e um arco aberto para a
-- direita; a de cima/baixo, um arco fino com a barriga para baixo (para cima
-- ela e espelhada na vertical).
-- O desenho tem o tamanho da area de acerto (a da frente um pouco mais larga,
-- "widen", porque o arco e mais largo que alto).
local SLASH_FX = {
    front = { texture = "VFX/faca_frente.png", sheetW = 720, sheetH = 88, frameW = 120, frameH = 88, widen = 1.35 },
    vertical = { texture = "VFX/faca_cima.png", sheetW = 1536, sheetH = 88, frameW = 256, frameH = 88, widen = 1.0 },
}

local function slashBlocks(dx, dy)
    if dy > 0 then return { { -1, 1 }, { 0, 1 }, { 1, 1 } } end
    if dy < 0 then return { { -1, -1 }, { 0, -1 }, { 1, -1 } } end
    local f = dx >= 0 and 1 or -1
    return { { f, 0 } }
end

function Player:stab(aimUp, aimDown, moving)
    local _, _, dx, dy = self:aim(aimUp, aimDown, moving)
    local half = self.knifeArea / 2
    self:clearSlash()

    -- o golpe guarda o deslocamento de cada bloco de acerto em relacao ao
    -- jogador e o acompanha; o desenho e um efeito so, sobre a area toda
    local blocks = {}
    local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
    for _, b in ipairs(slashBlocks(dx, dy)) do
        local ox, oy = b[1] * (HALF_W + half), b[2] * (HALF_H + half)
        blocks[#blocks + 1] = { offsetX = ox, offsetY = oy }
        minX, maxX = math.min(minX, ox - half), math.max(maxX, ox + half)
        minY, maxY = math.min(minY, oy - half), math.max(maxY, oy + half)
    end

    self.slash = {
        blocks = blocks, half = half,
        timeLeft = self.knifeTime,
        hit = {},   -- inimigos ja acertados por este golpe (cada um so leva 1 vez)
        fx = self:createSlashFx(dx, dy, (minX + maxX) / 2, (minY + maxY) / 2, maxX - minX, maxY - minY),
    }
    self.shootAnimTimer = self.shootAnimTime
    self:updateSlash(0)
end

-- Sprite do efeito: centro (cx, cy) relativo ao jogador; espelhado conforme
-- o lado/direcao do golpe
-- Os dois sprites do efeito (frente e cima/baixo) sao criados UMA vez, no
-- init, e so aparecem/somem a cada golpe. Criar o sprite e chamar setTexture
-- a cada golpe fazia a engine recarregar a imagem do disco (a ultima copia
-- tinha sido destruida no golpe anterior) e o jogo "engasgava" por um instante.
function Player:prepareSlashFx()
    self.slashFxSprites = {}
    for kind, def in pairs(SLASH_FX) do
        local sprite = Sprite(self.scene)
        sprite.entityOwned = false   -- fica ate a cena acabar
        sprite:setSize(math.floor(def.frameW / 2 + 0.5), math.floor(def.frameH / 2 + 0.5))
        local animator = Animator.new(sprite, {
            default = "slash",
            slash = {
                texture = def.texture, sheetW = def.sheetW, sheetH = def.sheetH,
                frameW = def.frameW, frameH = def.frameH, first = 0, count = 6,
                fps = 6 / math.max(self.knifeTime, 0.05), loop = false,
            },
        })
        sprite.visible = false
        self.slashFxSprites[kind] = { sprite = sprite, animator = animator }
    end
end

-- Mostra o efeito do golpe: centro (cx, cy) relativo ao jogador; espelhado
-- conforme o lado/direcao do golpe
function Player:createSlashFx(dx, dy, cx, cy, areaW, areaH)
    if not self.slashFxSprites then self:prepareSlashFx() end
    local kind = (dy == 0) and "front" or "vertical"
    local def = SLASH_FX[kind]
    local fxs = self.slashFxSprites[kind]
    -- esconde o outro (golpe novo antes do anterior acabar)
    for k, other in pairs(self.slashFxSprites) do
        if k ~= kind then other.sprite.visible = false end
    end
    -- setSize so aceita inteiros (numero quebrado da erro e o golpe nao sai)
    local w, h = math.floor(areaW * def.widen + 0.5), math.floor(areaH + 0.5)
    local sprite = fxs.sprite
    sprite:setSize(w, h)
    local sx = (dy == 0) and ((dx >= 0) and 1 or -1) or self.facing
    local sy = (dy > 0) and -1 or 1
    sprite.scale = Vector3(sx, sy, 1)
    fxs.animator:play("slash", true)   -- recomeca do primeiro quadro
    sprite.visible = true
    return { sprite = sprite, animator = fxs.animator,
             cx = cx, cy = cy, sx = sx, sy = sy, w = w, h = h }
end

-- Areas do golpe ativo (centro e meia-largura), usadas pelo EnemyShots para
-- rebater tiros. nil quando nao ha golpe ou a opcao esta desligada.
function Player:deflectZones()
    local slash = self.slash
    if not slash or not self.knifeDeflect or self.state ~= "alive" then return nil end
    local pos = self.body.position
    local zones = {}
    for _, b in ipairs(slash.blocks) do
        zones[#zones + 1] = { x = pos.x + b.offsetX, y = pos.y + b.offsetY, half = slash.half }
    end
    return zones
end

-- Dano e velocidade do tiro rebatido
function Player:deflectInfo()
    return self.knifePower * Itens.damageMultiplier(), self.deflectSpeed
end

function Player:clearSlash()
    if not self.slash then return end
    local fx = self.slash.fx
    if fx then fx.sprite.visible = false end
    self.slash = nil
end

-- Golpe ativo: segue o jogador e acerta quem encostar enquanto durar
function Player:updateSlash(dt)
    local slash = self.slash
    if not slash then return end
    slash.timeLeft = slash.timeLeft - dt
    if slash.timeLeft <= 0 then
        self:clearSlash()
        return
    end

    local pos = self.body.position
    local half = slash.half
    local damage = self.knifePower * Itens.damageMultiplier()
    local kills = 0
    for _, b in ipairs(slash.blocks) do
        local cx, cy = pos.x + b.offsetX, pos.y + b.offsetY
        kills = kills + Combat.hitArea(self.scene, cx, cy, half, half, damage, slash.hit)
    end
    -- efeito: acompanha o jogador (pivo no canto inferior esquerdo, entao a
    -- posicao leva o espelhamento em conta para ficar centrado na area)
    local fx = slash.fx
    if fx then
        fx.animator:update(dt)
        local x, y = pos.x + fx.cx, pos.y + fx.cy
        fx.sprite.position = Vector3(x - fx.sx * fx.w / 2, y - fx.sy * fx.h / 2, 0)
    end
    if kills > 0 then
        self.dashCooldownTimer = 0   -- matou com a faca: dash liberado de novo
        if not self.grounded then self.airJumpAvailable = true end
    end
end

-- Dash ------------------------------------------------------------------
-- Impulso na direcao segurada: por "dashTime" o jogador vai reto nessa direcao
-- (sem gravidade); depois a gravidade volta e ele segue o embalo, como num
-- pulo: na horizontal/diagonal faz uma parabola, para cima continua subindo.
function Player:startDash(dirX, aimUp, aimDown)
    local dx, dy = dirX, 0
    if aimUp then
        dy = 1
    elseif aimDown and not self.grounded then
        dy = -1
    end
    if dx == 0 and dy == 0 then dx = self.facing end
    -- no ar sem segurar cima/baixo: vai na diagonal para cima (para frente)
    if dy == 0 and not self.grounded then dy = 1 end
    local len = math.sqrt(dx * dx + dy * dy)
    self.dashVX = dx / len * self.dashSpeed
    self.dashVY = dy / len * self.dashSpeed
    self.dashTimer = self.dashTime
    self.dashCooldownTimer = self.dashCooldown
    self.dashCarry = 0
    self.body.gravityScale = 0
    if dy > 0 then self.grounded = false end
end

-- Fim do impulso (ou cancelado por um pulo). Retorna a velocidade vertical que fica.
function Player:endDash()
    self.dashTimer = 0
    self.body.gravityScale = self.gravityScale
    self.dashCarry = self.dashVX * self.dashCarryKeep
    if self.dashVY > 0 then return self.dashVY * self.dashUpKeep end
    return self.dashVY
end

function Player:cancelDash()
    if self.dashTimer > 0 then self:endDash() end
    self.dashCarry = 0
end

-- Visual ------------------------------------------------------------------
-- Qual animacao mostrar agora (as que ainda nao tem arte usam a reserva,
-- ver PlayerAnimations.lua)
function Player:chooseAnimation(moving)
    if self.state == "respawning" then return "respawn" end
    if self.state == "dead" or self.state == "gameover" then return "hurt" end
    local shooting = self.shootAnimTimer > 0
    if not self.grounded then
        return shooting and "jump_shoot" or "jump"
    elseif moving then
        return shooting and "run_shoot" or "run"
    end
    return shooting and "idle_shoot" or "idle"
end

function Player:updateVisual(dt, moving)
    if not self.visual then return end

    self.animator:play(self:chooseAnimation(moving))
    self.animator:update(dt)

    -- espelha o desenho (a arte olha para a direita) e aplica o deslocamento
    -- que alinha o desenho a hitbox + o ajuste de altura da animacao atual
    local f = self.facing
    local def = self.animator.current or {}
    local ox = self.visualOffsetX + (def.offsetX or 0)
    local oy = self.visualOffsetY + (def.offsetY or 0)
    local key = ox * 10000 + oy
    if f ~= self.visualFacing or key ~= self.visualOffsetApplied then
        self.visual.scale = Vector3(f, 1, 1)
        self.visual.position = Vector3(ox * f, oy, 0)
        self.visualFacing = f
        self.visualOffsetApplied = key
    end
end

function Player:hasHurtAnimation()
    return self.animator ~= nil and self.animator:has("hurt")
end

function Player:setVisualAlpha(a)
    if self.visual then self.visual.color = Vector4(1, 1, 1, a) end
end

-- Vidas -----------------------------------------------------------------

function Player:isInvincible()
    return self.invincibleTimer > 0
end

-- Dano recebido. "force" ignora a invencibilidade (ex.: cair no buraco).
function Player:hurt(force)
    if self.state ~= "alive" then return end
    if self:isInvincible() and not force then return end

    Itens.clearEffects()
    self:clearSlash()
    self.deathX = self.body.position.x   -- referencia para achar onde renascer
    local hasLivesLeft = GameState.loseLife()
    Log.print(string.format("Jogador morreu. Vidas: %d  Pontos: %d", GameState.lives, GameState.score))

    -- "congela" o jogador no lugar; a animacao de dano toca uma vez e depois
    -- ele some ate renascer (ver updateLifeState)
    self:cancelDash()
    self.body.gravityScale = 0
    self.body.linearVelocity = Vector2(0, 0)
    self.invincibleTimer = 0
    self.shootAnimTimer = 0
    self.crabFading = false
    self.hurtHold = 0
    -- com arte de dano: fica visivel tocando a animacao; sem arte: some na hora
    self.object.visible = self:hasHurtAnimation()
    self:setVisualAlpha(1)

    if hasLivesLeft then
        self.state = "dead"
        self.stateTimer = self.respawnDelay
    else
        self.state = "gameover"
        self.stateTimer = self.gameOverDelay
        Log.print("GAME OVER")
    end
    self:updateVisual(0, false)   -- comeca a animacao "hurt" do primeiro quadro
end

-- Onde renascer: na superficie (chao, bloco ou plataforma) mais proxima de
-- onde morreu, longe da borda e dentro da tela. Sem superficies registradas
-- (cena sem gerador, ex.: Fase Teste) usa o ultimo ponto em que estava no chao.
function Player:findRespawnPoint()
    local deathX = self.deathX or self.body.position.x
    if Run.surfacesSceneId == SceneManager.currentSceneId and #Run.surfaces > 0 then
        local margin = HALF_W + RESPAWN_EDGE_MARGIN
        local minX, maxX
        if Run.cameraLeft then
            minX = Run.cameraLeft + HALF_W + 16
            maxX = Run.cameraLeft + Run.viewWidth - HALF_W - 120
        end
        local x, top = Run.findSafeSpot(deathX, margin, minX, maxX)
        if not x then x, top = Run.findSafeSpot(deathX, margin) end   -- nada visivel: o mais proximo
        if x then
            return Vector2(x, top + HALF_H + 1)
        end
    end
    return Vector2(self.lastSafe.x, self.lastSafe.y + 4)
end

-- Reaparece parado: toca a animacao de reviver por "respawnFreezeTime" sem
-- aceitar comandos; depois volta ao controle ainda invencivel por um tempo
function Player:respawn()
    self.state = "respawning"
    self.stateTimer = self.respawnFreezeTime
    self.body.position = self:findRespawnPoint()
    self.body.linearVelocity = Vector2(0, 0)
    self.body.gravityScale = self.gravityScale
    self.object.visible = true
    self.invincibleTimer = self.respawnFreezeTime + self.invincibleTime
    self.dropTimer = 0
    self.shootAnimTimer = 0
    self.jumpWasDown, self.fireWasDown = true, true   -- botao segurado nao dispara ao voltar
    self.secondaryWasDown = true
    self.knifeWasDown, self.dashWasDown = true, true
    self:cancelDash()
    self.airJumpAvailable = false
    self:setVisualAlpha(0)
end

-- Retorna true se o jogador esta fora de controle (morto, revivendo, game over)
function Player:updateLifeState(dt)
    if self.invincibleTimer > 0 then
        self.invincibleTimer = self.invincibleTimer - dt
    end

    if self.state == "alive" then
        if Itens.crabTimer > 0 then
            -- Caranguejo ativo: fade suave entre 30% e 100% (1.5 ciclos por segundo)
            local wave = 0.5 + 0.5 * math.cos(Itens.crabTimer * math.pi * 3)
            self:setVisualAlpha(0.3 + 0.7 * wave)
            self.object.visible = true
            self.crabFading = true
            return false
        end
        if self.crabFading then
            self.crabFading = false
            self:setVisualAlpha(1)
        end
        if self.invincibleTimer > 0 then
            -- pisca 10 vezes por segundo
            self.object.visible = math.floor(self.invincibleTimer * 10) % 2 == 0
        else
            self.object.visible = true
        end
        return false
    end

    self.stateTimer = self.stateTimer - dt

    if self.state == "respawning" then
        -- parado no lugar (a gravidade continua, para assentar no chao)
        local vy = self.body.linearVelocity.y
        self.body.linearVelocity = Vector2(0, vy)
        -- aparece aos poucos, piscando rapido no comeco
        local t = 1 - math.max(self.stateTimer, 0) / math.max(self.respawnFreezeTime, 0.001)
        self:setVisualAlpha(math.min(1, t * 1.5))
        self.object.visible = t > 0.5 or math.floor(t * 40) % 2 == 0
        self.grounded = true
        self:updateVisual(dt, false)
        if self.stateTimer <= 0 then
            self.state = "alive"
            self:setVisualAlpha(1)
            self.object.visible = true
        end
        return true
    end

    self.body.linearVelocity = Vector2(0, 0)
    -- animacao de dano: toca uma vez, segura o ultimo quadro um instante e some
    if self.object.visible then
        if self:hasHurtAnimation() then
            self:updateVisual(dt, false)
            if self.animator:finished() then
                self.hurtHold = (self.hurtHold or 0) + dt
                if self.hurtHold >= HURT_HOLD_TIME then self.object.visible = false end
            end
        else
            self.object.visible = false
        end
    end
    if self.stateTimer <= 0 then
        if self.state == "dead" then
            self:respawn()
        elseif self.state == "gameover" then
            Combat.restartLevel()
        end
    end
    return true
end

function Player:onFixedUpdate()
    local dt = Engine.updateTime
    EnemyShots.update(dt, self)   -- tiros dos inimigos andam mesmo com o jogador morto/revivendo
    if self:updateLifeState(dt) then return end

    if self.dropTimer > 0 then self.dropTimer = self.dropTimer - dt end
    if self.fireTimer > 0 then self.fireTimer = self.fireTimer - dt end
    if self.secondaryTimer > 0 then self.secondaryTimer = self.secondaryTimer - dt end
    if self.knifeTimer > 0 then self.knifeTimer = self.knifeTimer - dt end
    if self.dashCooldownTimer > 0 then self.dashCooldownTimer = self.dashCooldownTimer - dt end
    self:updateSlash(dt)
    if self.shootAnimTimer > 0 then self.shootAnimTimer = self.shootAnimTimer - dt end

    self.grounded, self.groundEntity, self.groundIsPlatform = self:checkGround()
    if self.grounded then
        local pos = self.body.position
        self.lastSafe = Vector2(pos.x, pos.y)
        self.airJumpAvailable = false
    end

    -- Entrada
    local left   = anyKey(Input.KEY_A, Input.KEY_LEFT)
    local right  = anyKey(Input.KEY_D, Input.KEY_RIGHT)
    local up     = anyKey(Input.KEY_W, Input.KEY_UP)
    local down   = anyKey(Input.KEY_S, Input.KEY_DOWN)
    local jump   = anyKey(Input.KEY_SPACE)
    local fire   = anyKey(Input.KEY_J)
    local secondary = anyKey(Input.KEY_K)
    local knife  = anyKey(Input.KEY_L)
    local dash   = anyKey(Input.KEY_E)

    local jumpPressed = jump and not self.jumpWasDown
    local firePressed = fire and not self.fireWasDown
    self.jumpWasDown = jump
    self.fireWasDown = fire
    local secondaryPressed = secondary and not self.secondaryWasDown
    self.secondaryWasDown = secondary
    local knifePressed = knife and not self.knifeWasDown
    self.knifeWasDown = knife
    local dashPressed = dash and not self.dashWasDown
    self.dashWasDown = dash

    local dir = 0
    if left  then dir = dir - 1 end
    if right then dir = dir + 1 end
    if dir ~= 0 then self.facing = dir end

    local vx = dir * self.moveSpeed
    local vy = self.body.linearVelocity.y

    -- Dash (E)
    if dashPressed and self.dashCooldownTimer <= 0 then
        self:startDash(dir, up, down)
    end
    if self.dashTimer > 0 then
        vx, vy = self.dashVX, self.dashVY
        self.dashTimer = self.dashTimer - dt
        if self.dashTimer <= 0 then vy = self:endDash() end
    elseif self.dashCarry ~= 0 then
        -- embalo do dash: freia aos poucos; andar a favor mantem o mais rapido,
        -- andar contra freia mais
        local carry = self.dashCarry
        if dir == 0 or (dir > 0) == (carry > 0) then
            if math.abs(carry) > math.abs(vx) then vx = carry end
        else
            vx = vx + carry
        end
        -- no ar o embalo quase nao freia (faz a parabola); no chao acaba rapido
        local drag = self.grounded and self.dashCarryDrag or self.dashAirDrag
        carry = carry * math.exp(-drag * dt)
        if self.grounded and math.abs(carry) < self.moveSpeed * 0.25 then carry = 0 end
        if math.abs(carry) < 1 then carry = 0 end
        self.dashCarry = carry
    end

    -- Pulo / descer da plataforma / pulo extra da faca (no ar)
    if jumpPressed and self.grounded then
        self:cancelDash()
        vx = dir * self.moveSpeed
        if down and self.groundIsPlatform then
            self.dropEntity = self.groundEntity
            self.dropTimer = self.dropTime
            vy = -150
        else
            vy = self.jumpSpeed
        end
        self.grounded = false
    elseif jumpPressed and self.airJumpAvailable then
        -- quica: o embalo horizontal do dash continua (dash + pulo combinados)
        if self.dashTimer > 0 then self:endDash() end
        vy = self.jumpSpeed
        self.airJumpAvailable = false
    end

    if vy < -self.maxFallSpeed then vy = -self.maxFallSpeed end

    -- Modo corrida: a camera nao volta, entao o jogador nao sai pela esquerda
    if Run.lockBackwards and Run.cameraLeft then
        local minX = Run.cameraLeft + HALF_W
        local pos = self.body.position
        if pos.x < minX then
            self.body.position = Vector2(minX, pos.y)
        end
        -- encostado na borda: nao deixa andar para a esquerda (evita tremer)
        if pos.x <= minX + 0.5 and vx < 0 then vx = 0 end
    end

    self.body.linearVelocity = Vector2(vx, vy)

    -- Tiro (o Charuto deixa automatico e mais rapido)
    local autoFire, cooldown = Itens.fireModifiers(self.autoFire, self.fireCooldown)
    local wantsFire = firePressed or (autoFire and fire)
    if wantsFire and self.fireTimer <= 0 then
        self.fireTimer = cooldown
        self:shoot(up, down, dir ~= 0)
    end

    -- Arma secundaria (K): sem arma no slot, nao faz nada
    if secondaryPressed and Itens.secondaryWeapon == "escopeta" and self.secondaryTimer <= 0 then
        self.secondaryTimer = self.shotgunCooldown
        self:shootShotgun(up, down, dir ~= 0)
        Itens.useSecondaryAmmo()
    end

    -- Faca (L): sempre disponivel
    if knifePressed and self.knifeTimer <= 0 then
        self.knifeTimer = self.knifeCooldown
        self:stab(up, down, dir ~= 0)
    end

    -- Itens: efeitos temporarios e coleta
    local pos = self.body.position
    Itens.update(self, dt, pos.x, pos.y, HALF_W, HALF_H)
    GameState.updateDistance(pos.x)

    self:updateVisual(dt, dir ~= 0)

    -- Caiu para fora do mapa: perde vida mesmo se estiver invencivel
    if self.body.position.y < self.respawnY then
        self:hurt(true)
    end
end

return Player
