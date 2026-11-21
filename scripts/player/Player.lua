-- Player.lua
-- Controle do jogador (estilo Metal Slug).
--
-- Controles:
--   A / D ou Setas esquerda/direita -> andar
--   Espaco ou K                     -> pular
--   S / Seta para baixo + pulo      -> descer da plataforma (fora do chao principal)
--   J                               -> atirar
--   W / Seta para cima (segurando)  -> mirar para cima (+ andando = diagonal)
--   S / Seta para baixo no ar       -> mirar para baixo (+ andando = diagonal)

local Combat = require("game.Combat")

local Player = {
    properties = {
        { name = "moveSpeed",     displayName = "Velocidade (px/s)",            type = "float", default = 320.0 },
        { name = "jumpSpeed",     displayName = "Velocidade do pulo (px/s)",    type = "float", default = 860.0 },
        { name = "gravityScale",  displayName = "Escala da gravidade",          type = "float", default = 3.0 },
        { name = "maxFallSpeed",  displayName = "Queda maxima (px/s)",          type = "float", default = 1400.0 },
        { name = "respawnY",      displayName = "Y de respawn (caiu do mapa)",  type = "float", default = -400.0 },
        { name = "fireCooldown",  displayName = "Intervalo entre tiros (s)",    type = "float", default = 0.15 },
        { name = "autoFire",      displayName = "Tiro automatico (segurar J)",  type = "bool",  default = false },
        { name = "dropTime",      displayName = "Tempo atravessando (s)",       type = "float", default = 0.35 },
        { name = "allowDiagonal", displayName = "Permitir tiro na diagonal",    type = "bool",  default = true },
    }
}

local GROUND_NORMAL_MIN = 0.6   -- contato conta como chao
local LAND_NORMAL_MIN   = 0.7   -- pouso valido em plataforma atravessavel
local HALF_W, HALF_H    = 24, 40

local function anyKey(...)
    for i = 1, select("#", ...) do
        if Input.isKeyPressed(select(i, ...)) then
            return true
        end
    end
    return false
end

function Player:init()
    Combat.resetLevelState()

    self.object = Object(self.scene, self.entity)
    self.body = Body2D(self.scene, self.entity)

    self.body.fixedRotation = true
    self.body.enableSleep = false
    self.body.gravityScale = self.gravityScale

    local p = self.object.position
    self.spawn = Vector2(p.x, p.y)

    self.facing = 1              -- 1 = direita, -1 = esquerda
    self.grounded = false
    self.groundIsPlatform = false
    self.groundEntity = nil
    self.dropEntity = nil        -- plataforma que estamos atravessando
    self.dropTimer = 0
    self.fireTimer = 0
    self.jumpWasDown = false
    self.fireWasDown = false

    local physics = self.scene:getPhysicsSystem()
    -- unico filtro de preSolve do jogo: com varios inscritos so o primeiro decide
    RegisterEvent(self, physics.preSolve2D, "onPreSolve")
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
        return true   -- contato que nao envolve o jogador (ex.: inimigo na plataforma)
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
function Player:shoot(aimUp, aimDown, moving)
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
    Combat.spawnProjectile(self.scene, x, y, dx, dy)
end

function Player:respawn()
    self.body.position = self.spawn
    self.body.linearVelocity = Vector2(0, 0)
end

function Player:onFixedUpdate()
    local dt = Engine.updateTime
    if self.dropTimer > 0 then self.dropTimer = self.dropTimer - dt end
    if self.fireTimer > 0 then self.fireTimer = self.fireTimer - dt end

    self.grounded, self.groundEntity, self.groundIsPlatform = self:checkGround()

    -- Entrada
    local left   = anyKey(Input.KEY_A, Input.KEY_LEFT)
    local right  = anyKey(Input.KEY_D, Input.KEY_RIGHT)
    local up     = anyKey(Input.KEY_W, Input.KEY_UP)
    local down   = anyKey(Input.KEY_S, Input.KEY_DOWN)
    local jump   = anyKey(Input.KEY_SPACE, Input.KEY_K)
    local fire   = anyKey(Input.KEY_J)

    local jumpPressed = jump and not self.jumpWasDown
    local firePressed = fire and not self.fireWasDown
    self.jumpWasDown = jump
    self.fireWasDown = fire

    local dir = 0
    if left  then dir = dir - 1 end
    if right then dir = dir + 1 end
    if dir ~= 0 then self.facing = dir end

    local vx = dir * self.moveSpeed
    local vy = self.body.linearVelocity.y

    -- Pulo / descer da plataforma
    if jumpPressed and self.grounded then
        if down and self.groundIsPlatform then
            self.dropEntity = self.groundEntity
            self.dropTimer = self.dropTime
            vy = -150
        else
            vy = self.jumpSpeed
        end
        self.grounded = false
    end

    if vy < -self.maxFallSpeed then vy = -self.maxFallSpeed end
    self.body.linearVelocity = Vector2(vx, vy)

    -- Tiro
    local wantsFire = firePressed or (self.autoFire and fire)
    if wantsFire and self.fireTimer <= 0 then
        self.fireTimer = self.fireCooldown
        self:shoot(up, down, dir ~= 0)
    end

    -- Caiu para fora do mapa
    if self.body.position.y < self.respawnY then
        self:respawn()
    end
end

return Player
