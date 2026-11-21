-- Enemy.lua
-- Inimigo comum: patrulha de um lado para o outro em volta do ponto inicial.
-- Encostar no jogador reinicia a fase; um tiro (ou mais, conforme "Vida") o elimina.
--
-- Shapes esperados no Body2D do inimigo:
--   0 = corpo (categoria ENEMY): colide com chão/plataformas e recebe tiros
--   1 = área de dano (sensor, categoria ENEMY_HURTBOX): detecta o jogador

local Combat = require("game.Combat")

local Enemy = {
    properties = {
        { name = "speed",          displayName = "Velocidade (px/s)",             type = "float", default = 90.0 },
        { name = "patrolDistance", displayName = "Distancia da patrulha (px)",    type = "float", default = 160.0 },
        { name = "startDirection", displayName = "Direcao inicial (-1 ou 1)",     type = "int",   default = -1 },
        { name = "health",         displayName = "Vida (tiros para eliminar)",    type = "int",   default = 1 },
        { name = "gravityScale",   displayName = "Escala da gravidade",           type = "float", default = 3.0 },
    }
}

function Enemy:init()
    self.object = Object(self.scene, self.entity)
    self.body = Body2D(self.scene, self.entity)
    self.body.fixedRotation = true
    self.body.gravityScale = self.gravityScale

    self.startX = self.object.position.x
    self.dir = (self.startDirection >= 0) and 1 or -1
    self.hp = self.health
    self.dead = false

    Combat.registerHittable(self.entity, self)

    local physics = self.scene:getPhysicsSystem()
    RegisterEvent(self, physics.beginSensorContact2D, "onSensorBegin")
    RegisterEngineEvent(self, "onFixedUpdate")
end

function Enemy:onFixedUpdate()
    if self.dead then return end

    local x = self.body.position.x
    if x <= self.startX - self.patrolDistance then
        self.dir = 1
    elseif x >= self.startX + self.patrolDistance then
        self.dir = -1
    end

    local vy = self.body.linearVelocity.y
    self.body.linearVelocity = Vector2(self.dir * self.speed, vy)
end

-- Sensor de dano encostou em algo
function Enemy:onSensorBegin(sensorBody, sensorShape, visitorBody, visitorShape)
    if self.dead or sensorBody.entity ~= self.entity then return end
    if Combat.hasCategory(visitorBody, visitorShape, Combat.CAT.PLAYER) then
        Combat.playerHit()
    end
end

-- Chamado pelo projétil (via Combat.hit)
function Enemy:takeHit(damage)
    if self.dead then return end
    self.hp = self.hp - damage
    if self.hp <= 0 then
        self:die()
    end
end

function Enemy:die()
    self.dead = true
    Combat.unregisterHittable(self.entity)
    -- Desativar em vez de destruir: seguro dentro de callbacks de física
    -- e permite reaproveitar o inimigo no futuro (respawn, animação de morte etc.)
    self.body.enabled = false
    self.object.visible = false
    Log.print("Inimigo eliminado: " .. self.object.name)
end

return Enemy
