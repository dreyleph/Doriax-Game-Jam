-- Projectile.lua
-- Projétil do jogador. É criado pelo bundle "bundles/Projetil" através de
-- Combat.spawnProjectile(); a posição e a direção chegam em Combat.pendingShot.
-- Some ao acertar um inimigo, ao bater no chão/parede ou ao fim do tempo de vida.

local Combat = require("game.Combat")

local Projectile = {
    properties = {
        { name = "speed",    displayName = "Velocidade (px/s)",  type = "float", default = 950.0 },
        { name = "lifetime", displayName = "Tempo de vida (s)",  type = "float", default = 1.0 },
        { name = "damage",   displayName = "Dano",               type = "int",   default = 1 },
    }
}

function Projectile:init()
    self.object = Object(self.scene, self.entity)
    self.body = Body2D(self.scene, self.entity)
    self.root = self.scene:findOldestParent(self.entity)   -- raiz da instância do bundle
    self.timeLeft = self.lifetime
    self.dead = false
    self.removed = false

    local shot = Combat.pendingShot
    if shot then
        -- normaliza a direcao (diagonal nao fica mais rapida que reta)
        local len = math.sqrt(shot.dirX * shot.dirX + shot.dirY * shot.dirY)
        local dx, dy = shot.dirX / len, shot.dirY / len
        self.body.position = Vector2(shot.x, shot.y)
        self.body.linearVelocity = Vector2(dx * self.speed, dy * self.speed)
        -- o angulo do Body2D e em graus (Engine usa graus por padrao)
        self.body.angle = math.deg(math.atan(dy, dx))
    else
        Log.warn("Projectile criado sem Combat.spawnProjectile; removendo")
        self.dead = true
    end

    local physics = self.scene:getPhysicsSystem()
    RegisterEvent(self, physics.beginSensorContact2D, "onSensorBegin")
    RegisterEngineEvent(self, "onFixedUpdate")
end

function Projectile:onSensorBegin(sensorBody, sensorShape, visitorBody, visitorShape)
    if self.dead or sensorBody.entity ~= self.entity then return end

    if Combat.hasCategory(visitorBody, visitorShape, Combat.CAT.ENEMY) then
        Combat.hit(visitorBody.entity, self.damage)
        self:kill()
    elseif Combat.hasCategory(visitorBody, visitorShape, Combat.CAT.WORLD) then
        self:kill()
    end
end

function Projectile:kill()
    self.dead = true
    self.object.visible = false
end

function Projectile:onFixedUpdate()
    if self.removed then return end

    self.timeLeft = self.timeLeft - Engine.updateTime
    if self.timeLeft <= 0 then
        self.dead = true
    end

    -- A remoção fica para o passo seguinte, fora dos callbacks de colisão
    if self.dead then
        self.removed = true
        BundleManager.destroyBundle(self.scene, self.root)
    end
end

return Projectile
