-- Combat.lua
-- Módulo compartilhado entre os scripts de gameplay (require("game.Combat")).
-- Guarda as categorias de colisão, o registro de quem pode levar dano
-- e as funções de disparo e de "morte" do jogador.

local Combat = {}

-- Categorias de colisão (categoryBits / maskBits dos shapes 2D).
-- Os mesmos valores estão nos arquivos .scene e .bundle.
Combat.CAT = {
    WORLD         = 1,   -- chão principal e paredes (sólido, para tiros)
    PLATFORM      = 2,   -- plataformas atravessáveis (one-way)
    PLAYER        = 4,   -- corpo do jogador
    ENEMY         = 8,   -- corpo dos inimigos (recebe tiros)
    PLAYER_BULLET = 16,  -- projéteis do jogador (sensor)
    ENEMY_HURTBOX = 32,  -- área de dano dos inimigos (sensor)
}

Combat.PROJECTILE_BUNDLE = "bundles/Projetil"

local hittables = {}     -- entity -> instância de script com :takeHit(dano)
local restarting = false

function Combat.hasCategory(body, shapeIndex, category)
    return (body:getCategoryBitsFilter(shapeIndex) & category) ~= 0
end

-- Registro de alvos -----------------------------------------------------

function Combat.registerHittable(entity, instance)
    hittables[entity] = instance
end

function Combat.unregisterHittable(entity)
    hittables[entity] = nil
end

-- Retorna true se o alvo existia e recebeu o dano
function Combat.hit(entity, damage)
    local target = hittables[entity]
    if target and target.takeHit then
        target:takeHit(damage or 1)
        return true
    end
    return false
end

-- Disparo ---------------------------------------------------------------

-- Parâmetros lidos pelo Projectile:init(), que roda dentro do createBundle
Combat.pendingShot = nil

function Combat.spawnProjectile(scene, x, y, dirX, dirY)
    Combat.pendingShot = { x = x, y = y, dirX = dirX, dirY = dirY }
    local root = BundleManager.createBundle(Combat.PROJECTILE_BUNDLE, scene)
    Combat.pendingShot = nil
    return root
end

-- Jogador ---------------------------------------------------------------

-- Chamado pelo Player:init a cada (re)início da cena
-- (o registro de inimigos não é limpo aqui: os inimigos podem iniciar antes
-- do jogador, e cada um se registra de novo com o id da sua entidade)
function Combat.resetLevelState()
    restarting = false
end

-- Sem sistema de vida por enquanto: qualquer dano reinicia a fase
function Combat.playerHit()
    if restarting then return end
    restarting = true
    Log.print("Jogador atingido! Reiniciando a fase...")
    SceneManager.loadScene(SceneManager.currentSceneId)
end

return Combat
