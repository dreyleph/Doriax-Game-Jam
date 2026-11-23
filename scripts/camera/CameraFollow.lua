-- CameraFollow.lua
-- Câmera lateral que acompanha o alvo no eixo X (como em Metal Slug).
-- O alvo fica a "offsetX" pixels da borda esquerda da tela.

local Run = require("game.Run")

local CameraFollow = {
    properties = {
        { name = "target",    displayName = "Alvo",                               type = "Object" },
        { name = "offsetX",   displayName = "Distancia do alvo a borda esquerda", type = "float", default = 420.0 },
        { name = "smoothing", displayName = "Suavizacao",                         type = "float", default = 8.0 },
        { name = "minX",      displayName = "X minimo da camera",                 type = "float", default = 0.0 },
        { name = "maxX",      displayName = "X maximo da camera",                 type = "float", default = 1920.0 },
        { name = "lockBackwards", displayName = "Nao voltar (modo corrida)",      type = "bool",  default = false },
    }
}

function CameraFollow:init()
    self.camera = Camera(self.scene, self.entity)
    Run.lockBackwards = self.lockBackwards
    Run.cameraLeft = self.camera.position.x
    RegisterEngineEvent(self, "onUpdate")
    if not self.target then
        Log.warn("CameraFollow: nenhum alvo definido")
    end
end

function CameraFollow:onUpdate()
    if not self.target then return end

    local targetPos = self.target.position
    local camPos = self.camera.position

    local desiredX = targetPos.x - self.offsetX
    if desiredX < self.minX then desiredX = self.minX end
    if desiredX > self.maxX then desiredX = self.maxX end
    if self.lockBackwards and desiredX < camPos.x then desiredX = camPos.x end

    -- Suavização independente do FPS
    local t = 1 - math.exp(-self.smoothing * Engine.deltatime)
    local x = camPos.x + (desiredX - camPos.x) * t

    self.camera.position = Vector3(x, camPos.y, camPos.z)
    Run.cameraLeft = x
end

return CameraFollow
