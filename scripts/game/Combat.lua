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
Combat.ENEMY_BUNDLE = "bundles/Inimigo"

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

-- Ataque corpo a corpo: acerta todo alvo cuja caixa encosta na area
-- (centro cx, cy; meia largura/altura). Retorna quantos alvos foram eliminados.
-- Alvos sem "halfWidth"/"halfHeight" usam o tamanho do inimigo comum (48 x 64).
-- alreadyHit (opcional): tabela entity -> true; quem estiver nela e ignorado e
-- quem for acertado entra nela (golpe que dura varios passos acerta 1 vez cada)
function Combat.hitArea(scene, cx, cy, halfW, halfH, damage, alreadyHit)
    local targets = {}
    for entity, target in pairs(hittables) do
        targets[#targets + 1] = { entity = entity, target = target }
    end

    local kills = 0
    for _, t in ipairs(targets) do
        local target = t.target
        local ok, p = false, nil
        -- o gerador destroi inimigos sem tirar do registro: ignora (e limpa) esses
        if scene:isEntityCreated(t.entity) and target.body then
            ok, p = pcall(function() return target.body.position end)
        end
        if not ok or not p then
            hittables[t.entity] = nil
        elseif not target.dead
            and not (alreadyHit and alreadyHit[t.entity])
            and math.abs(p.x - cx) <= halfW + (target.halfWidth or 24)
            and math.abs(p.y - cy) <= halfH + (target.halfHeight or 32) then
            if alreadyHit then alreadyHit[t.entity] = true end
            target:takeHit(damage or 1)
            if target.dead then kills = kills + 1 end
        end
    end
    return kills
end

-- Disparo ---------------------------------------------------------------

-- Parâmetros lidos pelo Projectile:init(), que roda dentro do createBundle
Combat.pendingShot = nil

-- lifetime (opcional) substitui o tempo de vida do projetil (alcance mais curto)
function Combat.spawnProjectile(scene, x, y, dirX, dirY, lifetime)
    Combat.pendingShot = { x = x, y = y, dirX = dirX, dirY = dirY, lifetime = lifetime }
    local root = BundleManager.createBundle(Combat.PROJECTILE_BUNDLE, scene)
    Combat.pendingShot = nil
    return root
end

-- Inimigos gerados -----------------------------------------------------

-- Parametros lidos pelo Enemy:init() (x, y = pe do inimigo; overrides = propriedades).
-- O Enemy:init() devolve a propria instancia no bilhete (campo "instance").
Combat.pendingEnemy = nil

-- Retorna a entidade raiz do bundle e a instancia do script Enemy
function Combat.spawnEnemy(scene, x, y, overrides)
    local ticket = { x = x, y = y, overrides = overrides }
    Combat.pendingEnemy = ticket
    local root = BundleManager.createBundle(Combat.ENEMY_BUNDLE, scene)
    Combat.pendingEnemy = nil
    return root, ticket.instance
end

-- Plataformas atravessaveis para outros corpos alem do jogador ----------
-- O filtro de preSolve e um so no jogo (Player:onPreSolve; com varios
-- inscritos so o primeiro decide). Para contatos que nao envolvem o jogador
-- ele pergunta aqui. Quem se registra (ex.: inimigo) precisa ter "body" e
-- "dropTimer" (> 0 = descendo pela plataforma, atravessa).
local oneWayUsers = {}

function Combat.registerOneWay(entity, instance) oneWayUsers[entity] = instance end
function Combat.unregisterOneWay(entity) oneWayUsers[entity] = nil end

function Combat.oneWayFilter(bodyA, shapeA, bodyB, shapeB, manifold)
    local user, other, otherShape, sign
    if oneWayUsers[bodyA.entity] then
        user, other, otherShape, sign = oneWayUsers[bodyA.entity], bodyB, shapeB, -1
    elseif oneWayUsers[bodyB.entity] then
        user, other, otherShape, sign = oneWayUsers[bodyB.entity], bodyA, shapeA, 1
    else
        return true
    end
    if not other:isShapePreSolveEvents(otherShape) then return true end
    if (user.dropTimer or 0) > 0 then return false end
    -- so apoia caindo/parado por cima (normal apontando da plataforma para ele)
    if sign * manifold:getNormal().y < 0.7 then return false end
    if user.body.linearVelocity.y > 20 then return false end
    return true
end

-- Jogador ---------------------------------------------------------------

local player = nil   -- instancia do script Player (registrada no Player:init)

function Combat.registerPlayer(instance)
    player = instance
end

-- Jogador atual (ou nil). Usado pelos inimigos para enxergar/perseguir.
function Combat.getPlayer()
    return player
end

-- Chamado pelo Player:init a cada (re)inicio da cena
-- (o registro de inimigos nao e limpo aqui: os inimigos podem iniciar antes
-- do jogador, e cada um se registra de novo com o id da sua entidade)
function Combat.resetLevelState()
    restarting = false
end

-- Inimigo (ou outra fonte de dano) acertou o jogador.
-- O Player decide se a morte conta (ignora se ja estiver morto ou invencivel).
function Combat.playerHit()
    if player and player.hurt then
        player:hurt()
    end
end

-- Recarrega a fase atual (usado no game over)
function Combat.restartLevel()
    if restarting then return end
    restarting = true
    SceneManager.loadScene(SceneManager.currentSceneId)
end

return Combat
