-- EnemyShots.lua
-- Tiros dos inimigos atiradores (require("game.EnemyShots")).
-- Sao simples: um quadradinho que anda em linha reta, sem fisica. A cada passo
-- confere se encostou no jogador (Combat.playerHit, que respeita a
-- invencibilidade), se entrou no chao/bloco (superficies do Run, menos as
-- plataformas atravessaveis: o tiro passa por elas) ou se saiu da tela.
--
-- Ligacoes:
--   Enemy (atirador)     -> EnemyShots.spawn(scene, x, y, dirX, dirY, velocidade)
--   Player:init          -> EnemyShots.reset()
--   Player:onFixedUpdate -> EnemyShots.update(dt, jogador)

local Combat = require("game.Combat")
local Run = require("game.Run")

local EnemyShots = {
    SIZE = 10,              -- lado do tiro (px)
    LIFETIME = 3.0,         -- some depois disso (s)
    COLOR = { 1.0, 0.35, 0.1 },
    PLAYER_HALF_W = 20,     -- metade da hitbox do jogador (40x104)
    PLAYER_HALF_H = 52,
}

local shots = {}

-- Nova cena: as entidades antigas ja foram destruidas com a cena
function EnemyShots.reset()
    shots = {}
end

function EnemyShots.count()
    return #shots
end

function EnemyShots.spawn(scene, x, y, dirX, dirY, speed)
    local len = math.sqrt(dirX * dirX + dirY * dirY)
    if len < 1e-6 then return end
    local s = EnemyShots.SIZE
    local sprite = Sprite(scene)
    sprite.entityOwned = false   -- destruido por este modulo
    sprite:setSize(s, s)
    local c = EnemyShots.COLOR
    sprite.color = Vector4(c[1], c[2], c[3], 1)
    sprite.position = Vector3(x - s / 2, y - s / 2, 0)
    shots[#shots + 1] = {
        scene = scene, sprite = sprite, entity = sprite.entity,
        x = x, y = y, vx = dirX / len * speed, vy = dirY / len * speed,
        timeLeft = EnemyShots.LIFETIME,
    }
end

local function remove(i)
    local shot = shots[i]
    if shot.scene:isEntityCreated(shot.entity) then
        shot.scene:destroyEntity(shot.entity)
    end
    table.remove(shots, i)
end

local function insideTerrain(x, y)
    for _, s in ipairs(Run.surfaces) do
        if not s.platform and x >= s.x0 and x <= s.x1 and y < s.top then
            return true
        end
    end
    return false
end

-- player: instancia do Player (ou nil)
function EnemyShots.update(dt, player)
    local half = EnemyShots.SIZE / 2
    local px, py, alive
    if player and player.body then
        local p = player.body.position
        px, py = p.x, p.y
        alive = player.state == "alive"
    end
    for i = #shots, 1, -1 do
        local shot = shots[i]
        shot.x = shot.x + shot.vx * dt
        shot.y = shot.y + shot.vy * dt
        shot.timeLeft = shot.timeLeft - dt
        shot.sprite.position = Vector3(shot.x - half, shot.y - half, 0)

        local hitPlayer = alive and math.abs(shot.x - px) <= EnemyShots.PLAYER_HALF_W + half
            and math.abs(shot.y - py) <= EnemyShots.PLAYER_HALF_H + half
        local offScreen = Run.cameraLeft and (shot.x < Run.cameraLeft - 100 or shot.x > Run.cameraLeft + Run.viewWidth + 300)
        if hitPlayer then
            Combat.playerHit()
            remove(i)
        elseif shot.timeLeft <= 0 or offScreen or insideTerrain(shot.x, shot.y) then
            remove(i)
        end
    end
end

return EnemyShots
