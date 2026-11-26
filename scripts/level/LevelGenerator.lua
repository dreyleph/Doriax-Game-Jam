-- LevelGenerator.lua
-- Gera o mapa da corrida: cada tela (trecho de 1280 px) e montada com modulos
-- de 320 px sorteados de level/Chunks.lua. Mantem trechos gerados a frente da
-- camera e remove os que ficaram para tras.
--
-- Regras de variedade:
--   * nunca o mesmo modulo duas vezes seguidas
--   * no maximo 1 modulo "plano" por tela
--   * modulos mais dificeis so a partir do nivel minimo (nivel = telas geradas / 2)
--
-- Progressao (estilo Vampire Survivors / Risk of Rain): a dificuldade sobe com
-- a distancia, tela a tela (LevelGenerator:difficultyAt), ate ficar impossivel:
--   * inimigos por tela: comeca com "Inimigos na 1a tela" e cresce
--     "Inimigos a mais por tela" ate o maximo; se os pontos de inimigo dos
--     modulos nao bastam, os extras surgem em lugares sorteados do trecho
--   * atiradores: a partir de uma tela, numa proporcao crescente
--   * todos ficam mais rapidos/agressivos (velocidade, susto menor, atiram
--     mais rapido) ate um limite
--
-- Chao, blocos e plataformas sao criados por codigo: um corpo de colisao
-- invisivel + o desenho por cima, recortado das texturas de assets/Terreno/
-- (geradas por tools/montar_texturas_terreno.py a partir de assets/AssetsPlataforms).
-- Chao e blocos = pedras com terra; plataformas = andaime (escada deitada).
-- Os inimigos usam o bundle "bundles/Inimigo" (arte/hitbox editaveis no editor).

local Chunks = require("level.Chunks")
local Combat = require("game.Combat")
local Run = require("game.Run")

local LevelGenerator = {
    properties = {
        { name = "seed",            displayName = "Semente (0 = aleatoria)",            type = "int",   default = 0 },
        { name = "chunkWidth",      displayName = "Largura da tela/trecho (px)",        type = "float", default = 1280.0 },
        { name = "chunksAhead",     displayName = "Trechos gerados a frente da tela",   type = "int",   default = 2 },
        { name = "startEnemies",    displayName = "Progressao: inimigos na 1a tela",          type = "float", default = 1.0 },
        { name = "enemiesPerScreen", displayName = "Progressao: inimigos a mais por tela",    type = "float", default = 0.5 },
        { name = "maxEnemiesPerScreen", displayName = "Progressao: maximo de inimigos por tela", type = "int", default = 12 },
        { name = "maxAliveEnemies", displayName = "Progressao: maximo de inimigos vivos",     type = "int",   default = 30 },
        { name = "shooterFromScreen", displayName = "Progressao: atiradores a partir da tela", type = "int", default = 3 },
        { name = "shooterStartRatio", displayName = "Progressao: proporcao inicial de atiradores", type = "float", default = 0.2 },
        { name = "shooterRatioPerScreen", displayName = "Progressao: atiradores a mais por tela", type = "float", default = 0.03 },
        { name = "shooterMaxRatio", displayName = "Progressao: proporcao maxima de atiradores", type = "float", default = 0.5 },
        { name = "speedPerScreen",  displayName = "Progressao: velocidade a mais por tela (0.04 = 4%)", type = "float", default = 0.04 },
        { name = "maxSpeedMult",    displayName = "Progressao: velocidade maxima (x)",        type = "float", default = 1.8 },
        { name = "terrainLayer",    displayName = "Camada do terreno (entidade pai)",   type = "Object" },
        { name = "groundDepth",     displayName = "Espessura do chao (px)",             type = "float", default = 600.0 },
        { name = "enemyBehindMargin", displayName = "Inimigo some quando fica atras da tela (px)", type = "float", default = 150.0 },
    }
}

-- Texturas do terreno (caminhos dentro de assets/). Todas as pecas com a mesma
-- imagem compartilham a textura carregada (carrega uma vez so).
local TEX = {
    middle   = { path = "Terreno/terreno_meio.png", w = 128, h = 640 },  -- topo com musgo + terra
    left     = { path = "Terreno/terreno_esq.png",  w = 32,  h = 640 },  -- borda esquerda
    right    = { path = "Terreno/terreno_dir.png",  w = 32,  h = 640 },  -- borda direita
    scaffold = { path = "Terreno/andaime.png",      w = 251, h = 64  },  -- piso de andaime
}
-- Inimigos de um trecho novo nascem aos poucos (no maximo isso por frame):
-- criar 10+ bundles no mesmo frame dava um engasgo. O trecho e gerado bem a
-- frente da tela, entao da tempo de sobra.
local ENEMY_SPAWNS_PER_FRAME = 2
local EDGE_WIDTH = 32
local PLATFORM_THICKNESS = 32
-- o desenho do andaime e mais alto que a colisao: o topo coincide (onde se
-- pisa) e o resto fica pendurado embaixo, so visual
local SCAFFOLD_HEIGHT = 64

function LevelGenerator:init()
    -- propriedades novas ainda nao gravadas na cena chegam como nil
    for _, p in ipairs(LevelGenerator.properties) do
        if self[p.name] == nil then self[p.name] = p.default end
    end

    local seed = self.seed
    if seed == 0 then
        seed = (os.time() + math.floor(os.clock() * 1000)) % 1000000
    end
    math.randomseed(seed)
    Log.print("Corrida gerada com semente " .. seed .. " (use em 'Semente' para repetir)")

    self.modulesPerChunk = math.max(1, math.floor(self.chunkWidth / Chunks.MODULE_WIDTH + 0.5))
    self.chunks = {}        -- trechos ativos: { x, names, blocks = {entity...}, enemies = {root...} }
    self.enemies = {}       -- inimigos vivos/mortos ainda na cena: { root, inst } (sao do gerador, nao do trecho:
                            -- perseguindo, um inimigo pode sair do trecho onde nasceu)
    self.nextX = 0          -- onde comeca o proximo trecho
    self.generated = 0      -- quantos trechos (telas) ja foram gerados
    self.lastModule = nil
    self.spawnQueue = {}    -- inimigos sorteados esperando para nascer (ver spawnQueued)
    -- superficies de apoio para o jogador renascer (so desta cena)
    Run.clearSurfaces(SceneManager.currentSceneId)

    -- primeiros trechos ja na inicializacao (a camera pode ainda nao ter iniciado)
    self:spawnChunk(Chunks.start, true)
    self:fillAhead(0)

    RegisterEngineEvent(self, "onUpdate")
end

-- Visao atual ---------------------------------------------------------------
function LevelGenerator:viewLeft()
    return Run.cameraLeft or 0
end

function LevelGenerator:fillAhead(viewLeft)
    local limit = (viewLeft or self:viewLeft()) + Run.viewWidth + self.chunksAhead * self.chunkWidth
    while self.nextX < limit do
        self:spawnChunk(self:pickModules(), false)
    end
end

function LevelGenerator:removeBehind()
    local left = self:viewLeft()
    while #self.chunks > 0 do
        local c = self.chunks[1]
        if c.x + self.chunkWidth >= left - self.chunkWidth * 0.5 then break end
        self:destroyChunk(c)
        table.remove(self.chunks, 1)
    end
end

function LevelGenerator:onUpdate()
    self:fillAhead()
    self:spawnQueued()
    self:removeBehind()
    self:cleanupEnemies()
end

-- Cria alguns dos inimigos que estao na fila (os primeiros sorteados primeiro)
function LevelGenerator:spawnQueued()
    local made = 0
    while made < ENEMY_SPAWNS_PER_FRAME and #self.spawnQueue > 0 do
        local q = table.remove(self.spawnQueue, 1)
        if not q.chunk.removed and #self.enemies < self.maxAliveEnemies then
            local root, inst = Combat.spawnEnemy(self.scene, q.x, q.y, q.overrides)
            q.chunk.enemies[#q.chunk.enemies + 1] = root
            self.enemies[#self.enemies + 1] = { root = root, inst = inst }
            made = made + 1
        end
    end
end

-- Libera da cena os inimigos abatidos e elimina (sem dar pontos) os que
-- ficaram para tras da tela: a camera nao volta, entao nao fazem mais falta
function LevelGenerator:cleanupEnemies()
    local limit = Run.cameraLeft and (Run.cameraLeft - self.enemyBehindMargin)
    for i = #self.enemies, 1, -1 do
        local en = self.enemies[i]
        local inst = en.inst
        local remove = (inst == nil) or inst.dead
        if not remove and limit then
            local ok, pos = pcall(function() return inst.body.position end)
            if not ok or not pos or pos.x < limit then
                inst:die(false, "ficou para tras da tela")
                remove = true
            end
        end
        if remove then
            BundleManager.destroyBundle(self.scene, en.root)
            table.remove(self.enemies, i)
        end
    end
end

-- Sorteio ---------------------------------------------------------------------
function LevelGenerator:difficulty()
    return math.floor(self.generated / 2)
end

function LevelGenerator:pickModule(flatUsed)
    local level = self:difficulty()
    local options, total = {}, 0
    for _, m in ipairs(Chunks.modules) do
        local allowed = (m.minLevel or 0) <= level
            and m.name ~= self.lastModule
            and not (m.flat and flatUsed)
        if allowed then
            options[#options + 1] = m
            total = total + (m.weight or 1)
        end
    end
    if #options == 0 then return Chunks.modules[1] end

    local r = math.random() * total
    for _, m in ipairs(options) do
        r = r - (m.weight or 1)
        if r <= 0 then return m end
    end
    return options[#options]
end

function LevelGenerator:pickModules()
    local list, flatUsed = {}, false
    for i = 1, self.modulesPerChunk do
        local m = self:pickModule(flatUsed)
        if m.flat then flatUsed = true end
        self.lastModule = m.name
        list[i] = m
    end
    return list
end

-- Construcao --------------------------------------------------------------------
-- Pedaco de desenho (sem colisao): retangulo (x0, y0) = canto inferior esquerdo,
-- mostrando a regiao (u, v, uw, vh) da textura (0 a 1; v = 0 e o topo da imagem)
function LevelGenerator:makePiece(list, tex, x0, y0, w, h, u, uw, vh)
    local sprite = Sprite(self.scene)
    sprite.entityOwned = false
    sprite:setSize(math.floor(w + 0.5), math.floor(h + 0.5))   -- setSize so aceita inteiros
    -- pixel art: filtro "nearest" (pixels nitidos) antes de escolher a imagem
    if not self.filterFailed then
        local ok = pcall(function()
            local mat = sprite.material
            local t = mat.baseColorTexture
            t.minFilter = TextureFilter.NEAREST
            t.magFilter = TextureFilter.NEAREST
            mat.baseColorTexture = t
            sprite.material = mat
        end)
        if not ok then
            self.filterFailed = true
            Log.print("Aviso: nao foi possivel usar filtro nearest nas texturas do terreno")
        end
    end
    sprite:setTexture(tex.path)
    sprite:setTextureRect(u, 0, uw, vh)
    sprite.position = Vector3(x0, y0, 0)
    if self.terrainLayer then
        self.terrainLayer:addChild(sprite)
    else
        sprite:moveToBottom()
    end
    list[#list + 1] = sprite.entity
end

-- Desenho de pedra com terra para um retangulo (chao ou bloco). A textura do
-- meio e alinhada ao mundo (x), entao trechos vizinhos emendam sem costura.
-- edgeLeft/edgeRight: desenhar a borda lateral (falso onde o chao continua no
-- proximo trecho).
function LevelGenerator:drawEarth(list, x0, y0, w, h, edgeLeft, edgeRight)
    local vh = math.min(1, h / TEX.middle.h)
    local x, x1 = x0, x0 + w
    local lw = edgeLeft and math.min(EDGE_WIDTH, w) or 0
    local rw = edgeRight and math.min(EDGE_WIDTH, w - lw) or 0
    if lw > 0 then
        self:makePiece(list, TEX.left, x, y0, lw, h, 0, lw / TEX.left.w, vh)
        x = x + lw
    end
    local mEnd = x1 - rw
    local tw = TEX.middle.w
    while mEnd - x > 0.01 do
        local off = x % tw
        local pw = math.min(tw - off, mEnd - x)
        self:makePiece(list, TEX.middle, x, y0, pw, h, off / tw, pw / tw, vh)
        x = x + pw
    end
    if rw > 0 then
        self:makePiece(list, TEX.right, mEnd, y0, rw, h, (TEX.right.w - rw) / TEX.right.w, rw / TEX.right.w, vh)
    end
end

-- Piso de andaime (plataforma): madeira repetida na horizontal
function LevelGenerator:drawScaffold(list, x0, y0, w, h)
    local tw = TEX.scaffold.w
    local x, x1 = x0, x0 + w
    while x1 - x > 0.01 do
        local off = (x - x0) % tw
        local pw = math.min(tw - off, x1 - x)
        self:makePiece(list, TEX.scaffold, x, y0, pw, h, off / tw, pw / tw, 1)
        x = x + pw
    end
end

-- Corpo de colisao estatico e invisivel; (x0, y0) = canto inferior esquerdo
function LevelGenerator:makeBlock(x0, y0, w, h, isPlatform)
    local sprite = Sprite(self.scene)
    -- Sprite(scene) e "dono" da entidade: quando o coletor de lixo do Lua
    -- recolhe o objeto, a entidade seria destruida junto (o terreno sumia).
    -- Quem destroi os blocos e o gerador, em destroyChunk.
    sprite.entityOwned = false

    sprite:setSize(math.floor(w + 0.5), math.floor(h + 0.5))   -- setSize so aceita inteiros
    sprite.visible = false      -- o desenho e feito pelas pecas texturizadas
    sprite.position = Vector3(x0, y0, 0)
    if self.terrainLayer then
        self.terrainLayer:addChild(sprite)
    else
        sprite:moveToBottom()
    end

    local body = sprite:getBody2D()   -- estatico por padrao
    body:createCenteredBoxShape(w, h, Vector2(w / 2, h / 2), 0)
    body:setShapeFriction(0, 0.6)
    if isPlatform then
        body:setBitsFilter(0, Combat.CAT.PLATFORM, 0xFFFF)
        body:setShapePreSolveEvents(0, true)     -- plataforma atravessavel
    else
        body:setBitsFilter(0, Combat.CAT.WORLD, 0xFFFF)
        body:setShapeSensorEvents(0, true)       -- tiros batem
    end
    return sprite.entity
end

-- Tira de cada faixa os trechos cobertos por "cortes" ({x0, x1}); devolve as sobras
local function subtractRanges(ranges, cuts)
    local out = {}
    for _, r in ipairs(ranges) do
        local pieces = { { r[1], r[2] } }
        for _, c in ipairs(cuts) do
            local nextPieces = {}
            for _, p in ipairs(pieces) do
                if c[2] <= p[1] or c[1] >= p[2] then
                    nextPieces[#nextPieces + 1] = p
                else
                    if c[1] > p[1] then nextPieces[#nextPieces + 1] = { p[1], c[1] } end
                    if c[2] < p[2] then nextPieces[#nextPieces + 1] = { c[2], p[2] } end
                end
            end
            pieces = nextPieces
        end
        for _, p in ipairs(pieces) do out[#out + 1] = p end
    end
    return out
end

-- Junta faixas de chao que se encostam (menos corpos e menos emendas)
local function mergeRanges(ranges)
    table.sort(ranges, function(a, b) return a[1] < b[1] end)
    local out = {}
    for _, r in ipairs(ranges) do
        local last = out[#out]
        if last and r[1] <= last[2] then
            if r[2] > last[2] then last[2] = r[2] end
        else
            out[#out + 1] = { r[1], r[2] }
        end
    end
    return out
end

-- Dificuldade da tela "screen" (1 = primeira tela com inimigos, logo depois
-- da tela inicial). Retorna quantos inimigos, proporcao de atiradores e o
-- multiplicador de velocidade/agressividade.
function LevelGenerator:difficultyAt(screen)
    local n = math.floor(self.startEnemies + (screen - 1) * self.enemiesPerScreen + 1e-6)
    n = math.max(0, math.min(self.maxEnemiesPerScreen, n))
    local shooters = 0
    if screen >= self.shooterFromScreen then
        shooters = math.min(self.shooterMaxRatio,
            self.shooterStartRatio + (screen - self.shooterFromScreen) * self.shooterRatioPerScreen)
    end
    local speed = math.min(self.maxSpeedMult, 1 + (screen - 1) * self.speedPerScreen)
    return n, shooters, speed
end

-- Propriedades de um inimigo novo conforme a dificuldade
local function enemyOverrides(patrol, shooter, speed)
    local o = {
        patrolDistance = patrol,
        variant = shooter and "atirador" or "soldado",
        health = shooter and 1 or 2,
        wanderSpeed = 60 * speed,
        chaseSpeed = 190 * speed,
        jumpForwardSpeed = 300 * math.min(speed, 1.3),
        alertTime = 0.35 / speed,
        visionRange = 420 + 120 * (speed - 1),
        loseTime = 1.5 * speed,
    }
    if shooter then
        o.fireInterval = math.max(0.7, 1.6 / speed)
        o.shotSpeed = 380 * math.min(speed, 1.4)
    end
    return o
end

-- Pontos extras de inimigo (quando os dos modulos nao bastam): lugares
-- sorteados nas superficies do trecho, longe das bordas
function LevelGenerator:randomSpawnPoint(chunk)
    local options = {}
    for _, s in ipairs(Run.surfaces) do
        if s.owner == chunk and s.x1 - s.x0 >= 90 then options[#options + 1] = s end
    end
    if #options == 0 then return nil end
    local s = options[math.random(#options)]
    return s.x0 + 35 + math.random() * (s.x1 - s.x0 - 70), s.top
end

function LevelGenerator:spawnChunk(modules, isStart)
    local x = self.nextX
    local mw = self.chunkWidth / #modules
    local top = Chunks.GROUND_TOP
    local chunk = { x = x, names = {}, blocks = {}, enemies = {} }

    local groundRanges, candidates = {}, {}
    local blockedGround = {}   -- faixas do chao ocupadas por blocos (nao da para renascer ali)
    for i, m in ipairs(modules) do
        local mx = x + (i - 1) * mw
        chunk.names[i] = m.name

        for _, g in ipairs(m.ground or {}) do
            groundRanges[#groundRanges + 1] = { mx + g[1], mx + g[2] }
        end
        for _, b in ipairs(m.blocks or {}) do
            chunk.blocks[#chunk.blocks + 1] = self:makeBlock(mx + b[1], b[2], b[3], b[4], false)
            self:drawEarth(chunk.blocks, mx + b[1], b[2], b[3], b[4], true, true)
            Run.addSurface(mx + b[1], mx + b[1] + b[3], b[2] + b[4], chunk)
            if b[2] <= top then blockedGround[#blockedGround + 1] = { mx + b[1], mx + b[1] + b[3] } end
        end
        for _, p in ipairs(m.platforms or {}) do
            chunk.blocks[#chunk.blocks + 1] = self:makeBlock(mx + p[1], p[2] - PLATFORM_THICKNESS, p[3], PLATFORM_THICKNESS, true)
            self:drawScaffold(chunk.blocks, mx + p[1], p[2] - SCAFFOLD_HEIGHT, p[3], SCAFFOLD_HEIGHT)
            Run.addSurface(mx + p[1], mx + p[1] + p[3], p[2], chunk, true)
        end
        for _, e in ipairs(m.enemies or {}) do
            candidates[#candidates + 1] = { mx + e[1], e[2], e[3] }
        end
    end

    local merged = mergeRanges(groundRanges)
    for _, g in ipairs(merged) do
        chunk.blocks[#chunk.blocks + 1] = self:makeBlock(g[1], top - self.groundDepth, g[2] - g[1], self.groundDepth, false)
        -- sem borda onde o chao continua no trecho vizinho (modulos sempre
        -- comecam e terminam com chao)
        local edgeLeft = g[1] > x + 0.5 or x == 0
        local edgeRight = g[2] < x + self.chunkWidth - 0.5
        self:drawEarth(chunk.blocks, g[1], top - self.groundDepth, g[2] - g[1], self.groundDepth, edgeLeft, edgeRight)
    end
    for _, g in ipairs(subtractRanges(merged, blockedGround)) do
        Run.addSurface(g[1], g[2], top, chunk)
    end

    -- Inimigos conforme a dificuldade desta tela: primeiro nos pontos dos
    -- modulos (embaralhados); se faltar, em pontos sorteados do trecho
    if not isStart then
        for i = #candidates, 2, -1 do
            local j = math.random(i)
            candidates[i], candidates[j] = candidates[j], candidates[i]
        end
        local count, shooterRatio, speed = self:difficultyAt(self.generated)
        chunk.difficulty = { enemies = count, shooters = shooterRatio, speed = speed }
        local made, tries = 0, 0
        while made < count and tries < count * 3 and #self.enemies + #self.spawnQueue < self.maxAliveEnemies do
            tries = tries + 1
            local ex, ey, patrol
            local e = candidates[made + 1]
            if e then
                ex, ey, patrol = e[1], e[2], e[3]
            else
                ex, ey = self:randomSpawnPoint(chunk)
                patrol = 60
            end
            if ex then
                local shooter = math.random() < shooterRatio
                -- nasce nos proximos frames (spawnQueued), nao todos de uma vez
                self.spawnQueue[#self.spawnQueue + 1] = {
                    chunk = chunk, x = ex, y = ey, overrides = enemyOverrides(patrol, shooter, speed),
                }
                made = made + 1
            end
        end
    end

    self.chunks[#self.chunks + 1] = chunk
    self.nextX = x + self.chunkWidth
    self.generated = self.generated + 1
end

function LevelGenerator:destroyChunk(chunk)
    chunk.removed = true   -- inimigos ainda na fila deste trecho nao nascem mais
    Run.removeSurfaces(chunk)
    -- os inimigos nao sao destruidos aqui: cleanupEnemies cuida deles
    -- (quem ficou para tras ja foi eliminado; quem esta perseguindo continua)
    for _, entity in ipairs(chunk.blocks) do
        if self.scene:isEntityCreated(entity) then
            self.scene:destroyEntity(entity)
        end
    end
end

return LevelGenerator
