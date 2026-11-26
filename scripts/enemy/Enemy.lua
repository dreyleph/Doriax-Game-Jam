-- Enemy.lua
-- Inimigo comum (soldado). Dois jeitos de andar:
--   * a toa: anda devagar pela plataforma/chao onde esta, vira nas beiradas
--     (nao cai) e de vez em quando para um pouco;
--   * perseguindo: quando o jogador entra na "visao" (na frente, perto e mais
--     ou menos na mesma altura) ele para um instante (susto), vira para o
--     jogador e corre atras dele, mais rapido e com a animacao mais rapida.
--     Para alcancar o jogador ele muda de nivel: pula para plataformas/blocos
--     mais altos, desce por plataformas atravessaveis, desce de beiradas quando
--     ha chao embaixo e pula buracos que da para atravessar. So nao se joga
--     em buraco sem fundo: ai espera na beirada olhando para o jogador.
--     Desiste se o jogador fugir para longe por um tempo.
-- Encostar no jogador tira uma vida dele; tiros/faca o eliminam (conforme
-- "Vida") e somam "Pontos ao abater" a pontuacao.
--
-- Variantes ("Tipo"):
--   soldado  : persegue e machuca encostando. 2 de vida (2 tiros; a faca mata).
--   atirador : ao ver o jogador para, mira e atira (game/EnemyShots.lua) de
--              tempos em tempos; nao persegue, so se aproxima devagar se o
--              jogador sair da visao. 1 de vida. Arte do Enemy2.
-- O gerador escolhe o tipo e deixa os inimigos mais rapidos/agressivos com a
-- distancia (overrides em Combat.spawnEnemy).
--
-- Onde pode andar: no modo corrida usa as superficies registradas pelo gerador
-- (Run.surfaceSpan: o trecho continuo de chao/bloco/plataforma sob os pes).
-- Numa cena sem gerador (ex.: Fase Teste) usa a faixa "Patrulha sem gerador"
-- em volta do ponto inicial (e nao muda de nivel).
--
-- Desenho: sprite filho criado aqui. Soldado: atlas assets/Enemy1/Inimigo-Atlas.png
-- (EnemyAnimations.lua); atirador: assets/Enemy2/Inimigo2-Atlas.png
-- (EnemyAnimations2.lua, com mira e disparo). O retangulo do proprio bundle fica
-- transparente: no editor ele mostra o tamanho da hitbox.
--
-- Shapes esperados no Body2D do inimigo (bundles/Inimigo.bundle):
--   0 = corpo 40x104 (categoria ENEMY): colide com chao/plataformas e recebe tiros
--   1 = area de dano (sensor, categoria ENEMY_HURTBOX): detecta o jogador

local Combat = require("game.Combat")
local GameState = require("game.GameState")
local Itens = require("itens.Itens")
local Run = require("game.Run")
local Animator = require("game.Animator")
local EnemyAnimations = require("enemy.EnemyAnimations")
local EnemyAnimations2 = require("enemy.EnemyAnimations2")
local EnemyShots = require("game.EnemyShots")

local Enemy = {
    properties = {
        { name = "wanderSpeed",    displayName = "Velocidade andando a toa (px/s)",   type = "float", default = 60.0 },
        { name = "chaseSpeed",     displayName = "Velocidade perseguindo (px/s)",     type = "float", default = 190.0 },
        { name = "visionRange",    displayName = "Visao: alcance a frente (px)",      type = "float", default = 420.0 },
        { name = "senseRange",     displayName = "Visao: percebe atras ate (px)",     type = "float", default = 110.0 },
        { name = "visionHeight",   displayName = "Visao: diferenca de altura (px)",   type = "float", default = 150.0 },
        { name = "loseRange",      displayName = "Desiste se o jogador passar de (px)", type = "float", default = 650.0 },
        { name = "loseTime",       displayName = "Desiste depois de (s) sem ver",     type = "float", default = 1.5 },
        { name = "alertTime",      displayName = "Susto ao ver o jogador (s)",        type = "float", default = 0.35 },
        { name = "pauseTime",      displayName = "Pausa ao virar (s)",                type = "float", default = 0.8 },
        { name = "canChangeLevel", displayName = "Perseguindo: pula e desce niveis",  type = "bool",  default = true },
        { name = "jumpSpeed",      displayName = "Velocidade do pulo (px/s)",         type = "float", default = 860.0 },
        { name = "jumpForwardSpeed", displayName = "Velocidade para frente no pulo (px/s)", type = "float", default = 300.0 },
        { name = "variant",        displayName = "Tipo (soldado ou atirador)",        type = "string", default = "soldado" },
        { name = "fireInterval",   displayName = "Atirador: intervalo entre tiros (s)", type = "float", default = 1.6 },
        { name = "shotSpeed",      displayName = "Atirador: velocidade do tiro (px/s)", type = "float", default = 380.0 },
        { name = "shotMaxAngle",   displayName = "Atirador: mira ate (graus da horizontal)", type = "float", default = 35.0 },
        { name = "patrolDistance", displayName = "Patrulha sem gerador (px)",         type = "float", default = 160.0 },
        { name = "startDirection", displayName = "Direcao inicial (-1 ou 1)",         type = "int",   default = -1 },
        { name = "health",         displayName = "Vida (tiros para eliminar)",        type = "int",   default = 2 },
        { name = "gravityScale",   displayName = "Escala da gravidade",               type = "float", default = 3.0 },
        { name = "scoreValue",     displayName = "Pontos ao abater",                  type = "int",   default = 500 },
        { name = "fallLimitY",     displayName = "Y limite (abaixo disso some)",      type = "float", default = -400.0 },
    }
}

-- Metade da hitbox (shape 0 do bundle: 32x96 + cantos de 4 px = 40x104).
-- Se mudar a hitbox no editor, atualize aqui.
local HALF_W, HALF_H = 20, 52
local PLAYER_HALF_H = 52       -- metade da altura do jogador (pe = centro - isso)
local EDGE_MARGIN = 6          -- distancia minima da beirada (px)
local STUCK_TIME = 0.3         -- parado contra uma parede por isso -> vira
local DROP_TIME = 0.35         -- atravessando a plataforma para descer (s)
-- Gravidade da engine por unidade de "Escala da gravidade" (px/s^2). Medido
-- pelo pulo do jogador: 860 px/s com escala 3 sobe ~196 px.
local BASE_GRAVITY = 629
local SAFETY = 0.85            -- so tenta pulos com folga (altura e distancia)

local function sign(v) if v < 0 then return -1 end return 1 end
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end

function Enemy:init()
    -- propriedades novas ainda nao gravadas no bundle/cena chegam como nil
    for _, p in ipairs(Enemy.properties) do
        if self[p.name] == nil and p.default ~= nil then self[p.name] = p.default end
    end

    self.object = Object(self.scene, self.entity)
    self.body = Body2D(self.scene, self.entity)
    self.body.fixedRotation = true
    self.body.gravityScale = self.gravityScale
    self.halfWidth, self.halfHeight = HALF_W, HALF_H   -- usados pela faca (Combat.hitArea) e pelos itens

    -- Criado pelo gerador: aplica posicao e propriedades do trecho
    local spawn = Combat.pendingEnemy
    if spawn then
        for k, v in pairs(spawn.overrides or {}) do self[k] = v end
        self.body.position = Vector2(spawn.x, spawn.y + HALF_H)
        self.startX = spawn.x
        spawn.instance = self   -- o gerador guarda a instancia (limpeza de quem fica para tras)
    else
        self.startX = self.object.position.x
    end
    self.isShooter = self.variant == "atirador"
    self.facing = (self.startDirection >= 0) and 1 or -1
    self.hp = self.health
    self.fireTimer = 0
    self.shootAnimTimer = 0   -- > 0: tocando a animacao de disparo
    self.flashTimer = 0       -- > 0: piscando porque levou um tiro
    self.dead = false
    self.touchingPlayer = 0   -- contatos ativos entre a area de dano e o jogador

    self.state = "wander"     -- "wander" | "pause" | "alert" | "chase"
    self.stateTimer = 0
    self.walkTimer = self:nextWalkTime()
    self.lostTimer = 0
    self.stuckTimer = 0
    self.lastX = nil
    self.dropTimer = 0        -- > 0: descendo por uma plataforma atravessavel
    self.air = nil            -- no ar por pulo/queda: { vx, targetX, x0, x1, top }

    self:createVisual()

    Combat.registerHittable(self.entity, self)
    Combat.registerOneWay(self.entity, self)

    local physics = self.scene:getPhysicsSystem()
    RegisterEvent(self, physics.beginSensorContact2D, "onSensorBegin")
    RegisterEvent(self, physics.endSensorContact2D, "onSensorEnd")
    RegisterEngineEvent(self, "onFixedUpdate")
end

-- Desenho ----------------------------------------------------------------
function Enemy:createVisual()
    -- o retangulo do bundle fica invisivel (mostra a hitbox so no editor)
    local root = Sprite(self.scene, self.entity)
    root.color = Vector4(1, 1, 1, 0)

    local sprite = Sprite(self.scene)
    sprite.entityOwned = false   -- filho do inimigo: some junto com o bundle
    sprite:setSize(128, 128)
    pcall(function()             -- pixel art: filtro "nearest"
        local mat = sprite.material
        local t = mat.baseColorTexture
        t.minFilter = TextureFilter.NEAREST
        t.magFilter = TextureFilter.NEAREST
        mat.baseColorTexture = t
        sprite.material = mat
    end)
    self.object:addChild(sprite)
    self.visual = sprite
    self.baseColor = { 1, 1, 1 }
    self:applyColor(1)
    self.visualKey = nil
    -- cada tipo tem a sua arte: soldado = Enemy1, atirador = Enemy2
    self.animator = Animator.new(sprite, self.isShooter and EnemyAnimations2 or EnemyAnimations)
    self:updateVisual(0, "idle")
end

function Enemy:applyColor(alpha)
    if not self.visual then return end
    local c = self.baseColor or { 1, 1, 1 }
    self.visual.color = Vector4(c[1], c[2], c[3], alpha)
end

-- O sprite tem o pivo no canto inferior esquerdo: para centralizar e espelhar
-- em volta do centro do inimigo, a posicao leva o lado em conta
function Enemy:updateVisual(dt, animName)
    if not self.animator then return end
    self.animator:play(animName)
    self.animator:update(dt)
    local def = self.animator.current or {}
    local f = self.facing
    local ox, oy = def.offsetX or 0, def.offsetY or 0
    local key = f * 100000 + ox * 100 + oy
    if key ~= self.visualKey then
        self.visual.scale = Vector3(f, 1, 1)
        self.visual.position = Vector3(f * (ox - 64), oy - 64, 0)
        self.visualKey = key
    end
end

-- Onde pode andar ----------------------------------------------------------
local function usesSurfaces()
    return Run.surfacesSceneId == SceneManager.currentSceneId and #Run.surfaces > 0
end

-- Apoio atual: limites do centro (lo, hi) e o trecho (x0, x1, topo, plataforma).
-- nil se nao ha apoio sob os pes.
function Enemy:walkLimits(x, y)
    local x0, x1, top, platform
    if usesSurfaces() then
        x0, x1, top, platform = Run.surfaceSpan(x, y - HALF_H)
        if not x0 then return nil end
    else
        x0 = self.startX - self.patrolDistance - HALF_W - EDGE_MARGIN
        x1 = self.startX + self.patrolDistance + HALF_W + EDGE_MARGIN
        top = y - HALF_H
    end
    local lo, hi = x0 + HALF_W + EDGE_MARGIN, x1 - HALF_W - EDGE_MARGIN
    if lo > hi then lo = (x0 + x1) / 2; hi = lo end
    return lo, hi, { x0 = x0, x1 = x1, top = top, platform = platform }
end

function Enemy:nextWalkTime()
    return 2.5 + math.random() * 3.0
end

-- Pulo ---------------------------------------------------------------------
function Enemy:gravity()
    return BASE_GRAVITY * self.gravityScale
end

function Enemy:maxRise()
    return self.jumpSpeed * self.jumpSpeed / (2 * self:gravity()) * SAFETY
end

-- Distancia horizontal que alcanca num pulo que pousa "rise" px acima (ou abaixo)
function Enemy:jumpReach(rise)
    local g, v = self:gravity(), self.jumpSpeed
    local disc = v * v - 2 * g * rise
    if disc < 0 then return -1 end
    local t = (v + math.sqrt(disc)) / g
    return self.jumpForwardSpeed * t * SAFETY
end

-- Ponto de pouso num trecho: o mais perto de "x", longe das bordas
local function landingX(span, x)
    local lo, hi = span.x0 + HALF_W + EDGE_MARGIN, span.x1 - HALF_W - EDGE_MARGIN
    if lo > hi then return (span.x0 + span.x1) / 2 end
    return clamp(x, lo, hi)
end

function Enemy:startJump(target, x)
    self.air = { targetX = landingX(target, x), x0 = target.x0, x1 = target.x1, top = target.top }
    self.facing = sign(self.air.targetX - x)
    return 0, self.jumpSpeed
end

-- Movimento no ar: vai para o ponto de pouso sem bater de lado no apoio
-- (enquanto os pes estao abaixo do topo, para junto da borda)
function Enemy:airVelocity(x, feet, dt)
    local air = self.air
    if not air or not air.targetX then return air and air.vx or 0 end
    local tx = air.targetX
    if feet < air.top + 2 and (x < air.x0 - HALF_W or x > air.x1 + HALF_W) then
        local edge = (x < air.x0) and (air.x0 - HALF_W - 2) or (air.x1 + HALF_W + 2)
        tx = edge
    end
    local vx = (tx - x) / dt
    return clamp(vx, -self.jumpForwardSpeed, self.jumpForwardSpeed)
end

-- Visao ------------------------------------------------------------------
-- Jogador vivo na frente (ate visionRange) ou bem perto atras (senseRange),
-- com diferenca de altura ate visionHeight
function Enemy:seesPlayer(x, y)
    local p = Combat.getPlayer()
    if not p or p.state ~= "alive" or not p.body then return false end
    local pp = p.body.position
    local dx, dy = pp.x - x, pp.y - y
    if math.abs(dy) > self.visionHeight then return false end
    local ahead = dx * self.facing >= 0
    return (ahead and math.abs(dx) <= self.visionRange) or math.abs(dx) <= self.senseRange
end

-- Jogador ainda "a vista" durante a perseguicao (mais tolerante que ver)
function Enemy:keepsTrack(x, y)
    local p = Combat.getPlayer()
    if not p or p.state ~= "alive" or not p.body then return false, 0 end
    local pp = p.body.position
    local dx, dy = pp.x - x, pp.y - y
    return math.abs(dx) <= self.loseRange and math.abs(dy) <= self.visionHeight * 2, dx
end

-- Comportamento -------------------------------------------------------------
function Enemy:setState(state, time)
    self.state = state
    self.stateTimer = time or 0
end

-- Velocidade para andar na direcao "dir" sem passar dos limites
local function stepTowards(x, dir, speed, lo, hi, dt)
    if dir < 0 and x <= lo + 0.5 then return 0, true end
    if dir > 0 and x >= hi - 0.5 then return 0, true end
    local vx = dir * speed
    local nx = x + vx * dt
    if nx < lo then vx = (lo - x) / dt elseif nx > hi then vx = (hi - x) / dt end
    return vx, false
end

-- Trecho onde o jogador esta (ou o que esta embaixo dele, se estiver no ar)
local function playerSpan(px, pfeet)
    local x0, x1, top, platform = Run.surfaceSpan(px, pfeet, 16)
    if not x0 then x0, x1, top, platform = Run.surfaceBelow(px, pfeet + 1, 0) end
    if not x0 then return nil end
    return { x0 = x0, x1 = x1, top = top, platform = platform }
end

local function sameSpan(a, b)
    return math.abs(a.top - b.top) < 1 and a.x0 <= b.x1 + 1 and a.x1 >= b.x0 - 1
end

-- Perseguindo em outro nivel: decide entre pular, descer ou andar ate a
-- beirada. Retorna vx, vy (nil = manter) e a animacao.
-- Alvo alto demais para um pulo so: procura um degrau no meio do caminho
-- (plataforma/bloco alcancavel a partir do apoio atual, perto do jogador)
function Enemy:stepUpTowards(here, lo, hi, px, maxRise)
    local best, bestD
    for _, s in ipairs(Run.surfaces) do
        local r = s.top - here.top
        if r > 30 and r <= maxRise then
            local x0, x1, top, platform = Run.surfaceSpan((s.x0 + s.x1) / 2, s.top, 0.5)
            local span = { x0 = x0, x1 = x1, top = top, platform = platform }
            local lx = landingX(span, px)
            local from = clamp(lx, lo, hi)   -- melhor ponto de onde pular
            if math.abs(lx - from) <= self:jumpReach(r) then
                local d = math.abs(lx - px)
                if not bestD or d < bestD then best, bestD = span, d end
            end
        end
    end
    return best
end

function Enemy:chaseLevels(x, lo, hi, here, target, px, dt)
    local maxRise = self:maxRise()
    if target.top - here.top > maxRise then
        target = self:stepUpTowards(here, lo, hi, px, maxRise) or target
    end
    local rise = target.top - here.top

    -- 1) jogador embaixo, numa plataforma atravessavel: desce por ela
    if here.platform and rise < -30 and x >= target.x0 and x <= target.x1 then
        self.dropTimer = DROP_TIME
        self.air = { vx = 0 }
        return 0, -150, "chase"
    end

    -- 2) da para pular direto para onde o jogador esta
    if rise <= maxRise then
        local tx = landingX(target, x)
        local need = math.abs(tx - x)
        if need <= self:jumpReach(rise) and (rise > 30 or not (tx >= lo and tx <= hi)) then
            local vx, vy = self:startJump(target, x)
            return vx, vy, "chase"
        end
        -- longe ainda: anda na direcao do pouso (dentro do apoio)
        local dir = sign(tx - x)
        local vx, stopped = stepTowards(x, dir, self.chaseSpeed, lo, hi, dt)
        self.facing = dir
        if not stopped then return vx, nil, "chase" end
    end

    -- 3) na beirada (ou o alvo e alto demais): o que tem depois da borda?
    local dir = sign(px - x)
    self.facing = dir
    local atEdge = (dir > 0 and x >= hi - 0.5) or (dir < 0 and x <= lo + 0.5)
    if not atEdge then
        local vx = stepTowards(x, dir, self.chaseSpeed, lo, hi, dt)
        return vx, nil, "chase"
    end
    local edgeX = dir > 0 and here.x1 or here.x0

    -- 3a) degrau/plataforma mais alta logo depois da borda: sobe
    local best, bestD
    for _, s in ipairs(Run.surfaces) do
        local r = s.top - here.top
        if r > 10 and r <= maxRise then
            local near = dir > 0 and s.x0 or s.x1
            local d = (near - edgeX) * dir
            if d >= -HALF_W and d <= HALF_W * 2 + 60 and (not bestD or d < bestD) then
                best, bestD = s, d
            end
        end
    end
    if best then
        local sx0, sx1, stop, splat = Run.surfaceSpan((best.x0 + best.x1) / 2, best.top, 0.5)
        local vx, vy = self:startJump({ x0 = sx0, x1 = sx1, top = stop, platform = splat }, x)
        return vx, vy, "chase"
    end

    -- 3b) chao embaixo, depois da borda: desce andando
    local probe = edgeX + dir * (HALF_W + 12)
    local bx0, bx1, btop, bplat = Run.surfaceBelow(probe, here.top, 20)
    if bx0 then
        -- mira um ponto seguro do chao de baixo (pode ser estreito, com buraco do lado)
        local below = { x0 = bx0, x1 = bx1, top = btop, platform = bplat }
        self.air = { targetX = landingX(below, probe), x0 = bx0, x1 = bx1, top = btop }
        return dir * self.chaseSpeed, nil, "chase"
    end

    -- 3c) buraco: pula para a superficie depois dele mais perto do jogador
    local jump, jumpD
    for _, s in ipairs(Run.surfaces) do
        local r = s.top - here.top
        local near = dir > 0 and s.x0 or s.x1
        local gap = (near - edgeX) * dir
        local land = dir > 0 and (near + HALF_W + EDGE_MARGIN) or (near - HALF_W - EDGE_MARGIN)
        if gap > 0 and r <= maxRise and math.abs(land - x) <= self:jumpReach(r) then
            local d = math.abs(clamp(px, s.x0, s.x1) - px) + gap * 0.1
            if not jumpD or d < jumpD then jump, jumpD = s, d end
        end
    end
    if jump then
        local sx0, sx1, stop, splat = Run.surfaceSpan(dir > 0 and jump.x0 + 1 or jump.x1 - 1, jump.top, 0.5)
        local vx, vy = self:startJump({ x0 = sx0, x1 = sx1, top = stop, platform = splat }, x)
        return vx, vy, "chase"
    end

    -- 3d) sem caminho: espera na beirada olhando para o jogador
    return 0, nil, "idle"
end

function Enemy:onFixedUpdate()
    if self.dead then return end
    local dt = Engine.updateTime

    -- Dano continuo: se o jogador continuar encostado quando a invencibilidade
    -- acabar, ele leva dano de novo (o Player ignora enquanto esta invencivel)
    if self.touchingPlayer > 0 then
        Combat.playerHit()
    end
    if self.dropTimer > 0 then self.dropTimer = self.dropTimer - dt end
    if self.flashTimer > 0 then
        self.flashTimer = self.flashTimer - dt
        self:applyColor((self.flashTimer > 0 and math.floor(self.flashTimer * 30) % 2 == 0) and 0.35 or 1)
    end

    local pos = self.body.position
    if pos.y < self.fallLimitY then
        self:die(false, "caiu do mapa")   -- some sem dar pontos
        return
    end

    local x, y = pos.x, pos.y
    local vy = self.body.linearVelocity.y
    local lo, hi, here = self:walkLimits(x, y)
    local grounded = lo ~= nil and vy <= 5 and self.dropTimer <= 0
    if not grounded then
        -- no ar (pulando, descendo ou caindo): segue o plano do pulo/queda
        local vx = self:airVelocity(x, y - HALF_H, dt)
        if vx ~= 0 then self.facing = sign(vx) end
        self.body.linearVelocity = Vector2(vx, vy)
        self:updateVisual(dt, self.state == "chase" and "chase" or "idle")
        return
    end
    self.air = nil

    -- preso contra uma parede/bloco: conta como beirada
    local blocked = false
    if self.lastX and self.movingDir and self.movingDir ~= 0 and math.abs(x - self.lastX) < 0.2 then
        self.stuckTimer = self.stuckTimer + dt
        blocked = self.stuckTimer >= STUCK_TIME
    else
        self.stuckTimer = 0
    end
    self.lastX = x

    local vx, newVY, anim = 0, nil, "idle"
    self.stateTimer = self.stateTimer - dt

    -- percebeu o jogador: susto e depois perseguicao
    if (self.state == "wander" or self.state == "pause") and self:seesPlayer(x, y) then
        local p = Combat.getPlayer()
        self.facing = sign(p.body.position.x - x)
        self:setState("alert", self.alertTime)
        self.lostTimer = 0
    end

    if self.state == "alert" then
        if self.stateTimer <= 0 then
            if self.isShooter then
                self:setState("shoot")
                self.fireTimer = 0.15   -- primeiro tiro logo depois do susto
            else
                self:setState("chase")
            end
        end

    elseif self.state == "shoot" then
        vx, anim = self:shootStep(x, y, lo, hi, dt)

    elseif self.state == "chase" then
        local tracking, dx = self:keepsTrack(x, y)
        if tracking and self:seesPlayer(x, y) then
            self.lostTimer = 0
        else
            self.lostTimer = self.lostTimer + dt
        end
        if not tracking and self.lostTimer >= self.loseTime then
            self:setState("pause", self.pauseTime)   -- desistiu: para e volta a andar a toa
        else
            local p = Combat.getPlayer()
            local target
            if self.canChangeLevel and usesSurfaces() and p and p.body then
                local pp = p.body.position
                target = playerSpan(pp.x, pp.y - PLAYER_HALF_H)
                if target and sameSpan(target, here) then target = nil end
            end
            if target then
                vx, newVY, anim = self:chaseLevels(x, lo, hi, here, target, x + dx, dt)
                if blocked and newVY == nil then vx, anim = 0, "idle" end
            elseif math.abs(dx) > 6 then
                self.facing = sign(dx)
                local stopped
                vx, stopped = stepTowards(x, self.facing, self.chaseSpeed, lo, hi, dt)
                if blocked then vx, stopped = 0, true end
                anim = stopped and "idle" or "chase"   -- na beirada: espera olhando para o jogador
            end
        end

    elseif self.state == "pause" then
        if self.stateTimer <= 0 then
            self:setState("wander")
            self.walkTimer = self:nextWalkTime()
        end

    else -- wander
        local stopped
        vx, stopped = stepTowards(x, self.facing, self.wanderSpeed, lo, hi, dt)
        self.walkTimer = self.walkTimer - dt
        if stopped or blocked then
            -- beirada ou parede: para um pouco e volta
            vx = 0
            self.facing = -self.facing
            self.stuckTimer = 0
            self:setState("pause", self.pauseTime)
        elseif self.walkTimer <= 0 then
            -- de vez em quando para; as vezes vira para o outro lado
            if math.random() < 0.5 then self.facing = -self.facing end
            vx = 0
            self:setState("pause", self.pauseTime * (0.6 + math.random() * 0.8))
        else
            anim = "walk"
        end
    end

    self.movingDir = (math.abs(vx) > 1 and newVY == nil) and sign(vx) or 0
    self.body.linearVelocity = Vector2(vx, newVY or vy)
    self:updateVisual(dt, anim)
end

-- Atirador: parado mirando enquanto ve o jogador; perdeu de vista, anda
-- devagar na direcao dele; sumiu por loseTime, desiste. Retorna vx, animacao.
function Enemy:shootStep(x, y, lo, hi, dt)
    local tracking, dx = self:keepsTrack(x, y)
    if math.abs(dx) > 1 then self.facing = sign(dx) end
    local sees = self:seesPlayer(x, y)
    if tracking and sees then self.lostTimer = 0 else self.lostTimer = self.lostTimer + dt end
    if not tracking and self.lostTimer >= self.loseTime then
        self:setState("pause", self.pauseTime)
        return 0, "idle"
    end
    self.fireTimer = self.fireTimer - dt
    if self.shootAnimTimer > 0 then self.shootAnimTimer = self.shootAnimTimer - dt end
    if sees then
        if self.fireTimer <= 0 then
            self:fireAt(Combat.getPlayer(), x, y)
            self.fireTimer = self.fireInterval
        end
        -- disparo logo depois do tiro; no resto do tempo fica mirando
        return 0, self.shootAnimTimer > 0 and "shoot" or "aim"
    end
    local vx, stopped = stepTowards(x, self.facing, self.wanderSpeed * 1.5, lo, hi, dt)
    return vx, stopped and "idle" or "walk"
end

-- Tiro na direcao do jogador, com o angulo limitado (atira "para a frente")
function Enemy:fireAt(player, x, y)
    if not player or not player.body then return end
    local mx, my = x + self.facing * (HALF_W + 6), y + 14
    local pp = player.body.position
    local dx, dy = math.abs(pp.x - mx), pp.y - my
    local maxA = math.rad(self.shotMaxAngle)
    local a = math.max(-maxA, math.min(maxA, math.atan(dy, math.max(dx, 1))))
    EnemyShots.spawn(self.scene, mx, my, self.facing * math.cos(a), math.sin(a), self.shotSpeed)
    -- animacao de disparo do comeco a cada tiro
    if self.animator then
        self.animator:play("shoot", true)
        local def = self.animator.current or {}
        self.shootAnimTimer = (def.count or 1) / (def.fps or 12)
    end
end

-- Area de dano encostou / deixou de encostar em algo
function Enemy:onSensorBegin(sensorBody, sensorShape, visitorBody, visitorShape)
    if self.dead or sensorBody.entity ~= self.entity then return end
    if Combat.hasCategory(visitorBody, visitorShape, Combat.CAT.PLAYER) then
        self.touchingPlayer = self.touchingPlayer + 1
        Combat.playerHit()
    end
end

function Enemy:onSensorEnd(sensorBody, sensorShape, visitorBody, visitorShape)
    if sensorBody.entity ~= self.entity then return end
    if Combat.hasCategory(visitorBody, visitorShape, Combat.CAT.PLAYER) then
        self.touchingPlayer = math.max(self.touchingPlayer - 1, 0)
    end
end

-- Chamado pelo projetil (via Combat.hit) e pela faca (Combat.hitArea)
function Enemy:takeHit(damage)
    if self.dead then return end
    self.hp = self.hp - damage
    if self.hp <= 0 then
        self:die()
    else
        self.flashTimer = 0.2   -- pisca: levou o tiro mas continua
        -- levou tiro sem estar alerta: vira para o jogador e reage
        if self.state == "wander" or self.state == "pause" then
            local p = Combat.getPlayer()
            local pos = self.body.position
            if p and p.body then self.facing = sign(p.body.position.x - pos.x) end
            self:setState("alert", self.alertTime)
            self.lostTimer = 0
        end
    end
end

-- givePoints = false: sumiu sem ser abatido pelo jogador (caiu, ficou para
-- tras da tela): sem pontos e sem item
function Enemy:die(givePoints, reason)
    if self.dead then return end
    self.dead = true
    self.touchingPlayer = 0
    Combat.unregisterHittable(self.entity)
    Combat.unregisterOneWay(self.entity)
    if givePoints ~= false then
        GameState.addScore(self.scoreValue)
        -- sorteia um item no pe do inimigo
        local pos = self.body.position
        Itens.tryDrop(self.scene, pos.x, pos.y - HALF_H)
    end
    -- Desativar em vez de destruir: seguro dentro de callbacks de fisica
    -- e permite reaproveitar o inimigo no futuro (respawn, animacao de morte etc.)
    self.body.enabled = false
    self.object.visible = false   -- esconde tambem o desenho (filho)
    if givePoints ~= false then
        Log.print("Inimigo eliminado: " .. self.object.name)
    else
        Log.print("Inimigo removido (" .. (reason or "sem pontos") .. "): " .. self.object.name)
    end
end

return Enemy
