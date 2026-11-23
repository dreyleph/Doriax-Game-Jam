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
--
-- Vidas (estilo arcade): ao morrer perde 1 vida e parte dos pontos, renasce
-- no ultimo chao seguro com invencibilidade temporaria (piscando).
-- Sem vidas: GAME OVER e a fase recomeca do zero.

local Combat = require("game.Combat")
local GameState = require("game.GameState")
local Pause = require("game.Pause")
local Run = require("game.Run")
local Itens = require("itens.Itens")
local Animator = require("game.Animator")
local PlayerAnimations = require("player.PlayerAnimations")

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
        { name = "autoFire",      displayName = "Tiro automatico (segurar J)",  type = "bool",  default = false },
        { name = "dropTime",      displayName = "Tempo atravessando (s)",       type = "float", default = 0.35 },
        { name = "allowDiagonal", displayName = "Permitir tiro na diagonal",    type = "bool",  default = true },
        { name = "startLives",        displayName = "Vidas iniciais",                     type = "int",   default = 3 },
        { name = "deathScorePenalty", displayName = "Pontos perdidos ao morrer (0 a 1)",  type = "float", default = 0.5 },
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
    Pause.setGameScene(self.scene)
    Itens.reset()

    GameState.startLives = self.startLives
    GameState.deathScorePenalty = self.deathScorePenalty
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

    self.state = "alive"         -- "alive" | "dead" (esperando renascer) | "gameover"
    self.stateTimer = 0
    self.invincibleTimer = 0

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

    -- Desenho do personagem: entidade filha com a sprite sheet. O corpo fisico
    -- fica no Jogador; o filho so e espelhado e animado (nao afeta a fisica).
    self.visualFacing = nil
    if self.visual then
        self.animator = Animator.new(self.visual, PlayerAnimations)
        self:updateVisual(0, false)
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

-- Visual ------------------------------------------------------------------
function Player:updateVisual(dt, moving)
    if not self.visual then return end

    local f = self.facing
    if f ~= self.visualFacing then
        -- espelha o desenho e o deslocamento (a arte olha para a direita)
        self.visual.scale = Vector3(f, 1, 1)
        self.visual.position = Vector3(self.visualOffsetX * f, self.visualOffsetY, 0)
        self.visualFacing = f
    end

    local anim = "idle"
    if not self.grounded then
        anim = "jump"
    elseif moving then
        anim = "run"
    end
    self.animator:play(anim)
    self.animator:update(dt)
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
    local hasLivesLeft = GameState.loseLife()
    Log.print(string.format("Jogador morreu. Vidas: %d  Pontos: %d", GameState.lives, GameState.score))

    -- "congela" e esconde o jogador enquanto espera
    self.body.gravityScale = 0
    self.body.linearVelocity = Vector2(0, 0)
    self.object.visible = false
    self.invincibleTimer = 0

    if hasLivesLeft then
        self.state = "dead"
        self.stateTimer = self.respawnDelay
    else
        self.state = "gameover"
        self.stateTimer = self.gameOverDelay
        Log.print("GAME OVER")
    end
end

function Player:respawn()
    self.state = "alive"
    self.body.position = Vector2(self.lastSafe.x, self.lastSafe.y + 4)
    self.body.linearVelocity = Vector2(0, 0)
    self.body.gravityScale = self.gravityScale
    self.object.visible = true
    self.invincibleTimer = self.invincibleTime
    self.dropTimer = 0
end

-- Retorna true se o jogador esta fora de jogo (morto / game over) neste passo
function Player:updateLifeState(dt)
    if self.state == "alive" then
        if self.invincibleTimer > 0 then
            self.invincibleTimer = self.invincibleTimer - dt
            if self.invincibleTimer <= 0 then
                self.object.visible = true
            else
                -- pisca 10 vezes por segundo
                self.object.visible = math.floor(self.invincibleTimer * 10) % 2 == 0
            end
        end
        return false
    end

    self.body.linearVelocity = Vector2(0, 0)
    self.stateTimer = self.stateTimer - dt
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
    if Pause.paused then return end
    local dt = Engine.updateTime
    if self:updateLifeState(dt) then return end

    if self.dropTimer > 0 then self.dropTimer = self.dropTimer - dt end
    if self.fireTimer > 0 then self.fireTimer = self.fireTimer - dt end

    self.grounded, self.groundEntity, self.groundIsPlatform = self:checkGround()
    if self.grounded then
        local pos = self.body.position
        self.lastSafe = Vector2(pos.x, pos.y)
    end

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

    -- Itens: efeitos temporarios e coleta
    local pos = self.body.position
    Itens.update(self, dt, pos.x, pos.y, HALF_W, HALF_H)

    self:updateVisual(dt, dir ~= 0)

    -- Caiu para fora do mapa: perde vida mesmo se estiver invencivel
    if self.body.position.y < self.respawnY then
        self:hurt(true)
    end
end

return Player
