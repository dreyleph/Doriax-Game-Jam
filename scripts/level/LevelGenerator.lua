-- LevelGenerator.lua
-- Gera o mapa da corrida: cada tela (trecho de 1280 px) e montada com modulos
-- de 320 px sorteados de level/Chunks.lua. Mantem trechos gerados a frente da
-- camera e remove os que ficaram para tras.
--
-- Regras de variedade:
--   * nunca o mesmo modulo duas vezes seguidas
--   * no maximo 1 modulo "plano" por tela
--   * modulos mais dificeis so a partir do nivel minimo (nivel = telas geradas / 2)
--   * numero minimo garantido de inimigos por tela, crescendo com a distancia;
--     os demais pontos de inimigo aparecem por chance (tambem crescente)
--
-- Chao, blocos e plataformas sao criados por codigo (retangulos provisorios);
-- os inimigos usam o bundle "bundles/Inimigo" (arte/hitbox editaveis no editor).

local Chunks = require("level.Chunks")
local Combat = require("game.Combat")
local Run = require("game.Run")

local LevelGenerator = {
    properties = {
        { name = "seed",            displayName = "Semente (0 = aleatoria)",            type = "int",   default = 0 },
        { name = "chunkWidth",      displayName = "Largura da tela/trecho (px)",        type = "float", default = 1280.0 },
        { name = "chunksAhead",     displayName = "Trechos gerados a frente da tela",   type = "int",   default = 2 },
        { name = "enemyChance",     displayName = "Chance extra de inimigo (0 a 1)",    type = "float", default = 0.5 },
        { name = "enemyChanceRamp", displayName = "Aumento da chance por tela",         type = "float", default = 0.03 },
        { name = "minEnemies",      displayName = "Inimigos garantidos por tela",       type = "int",   default = 2 },
        { name = "minEnemiesEvery", displayName = "+1 inimigo garantido a cada N telas", type = "int",   default = 3 },
        { name = "minEnemiesMax",   displayName = "Maximo de inimigos garantidos",      type = "int",   default = 6 },
        { name = "terrainLayer",    displayName = "Camada do terreno (entidade pai)",   type = "Object" },
        { name = "groundDepth",     displayName = "Espessura do chao (px)",             type = "float", default = 600.0 },
    }
}

-- Cores provisorias (ate chegar a arte do cenario). Escuras para contrastar
-- com o fundo (ceu azul e casario bege/ocre); a "borda" clara no topo marca
-- onde da para pisar.
local COLOR_GROUND   = { 0.157, 0.122, 0.102 }
local COLOR_BLOCK    = { 0.250, 0.200, 0.170 }
local COLOR_PLATFORM = { 0.149, 0.118, 0.102 }
local COLOR_LIP      = { 0.910, 0.667, 0.235 }   -- ocre
local LIP_HEIGHT = 5
local PLATFORM_THICKNESS = 32

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
    self.nextX = 0          -- onde comeca o proximo trecho
    self.generated = 0      -- quantos trechos (telas) ja foram gerados
    self.lastModule = nil

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
    self:removeBehind()
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
-- Retangulo so visual (sem colisao); (x0, y0) = canto inferior esquerdo
function LevelGenerator:makeDecor(x0, y0, w, h, color)
    local sprite = Sprite(self.scene)
    sprite.entityOwned = false
    sprite:setSize(w, h)
    sprite.color = Vector4(color[1], color[2], color[3], 1)
    sprite.position = Vector3(x0, y0, 0)
    if self.terrainLayer then
        self.terrainLayer:addChild(sprite)
    else
        sprite:moveToBottom()
    end
    return sprite.entity
end

-- Bloco/plataforma com a borda clara no topo; devolve as entidades criadas
function LevelGenerator:makeSurface(list, x0, y0, w, h, color, isPlatform)
    list[#list + 1] = self:makeBlock(x0, y0, w, h, color, isPlatform)
    list[#list + 1] = self:makeDecor(x0, y0 + h - LIP_HEIGHT, w, LIP_HEIGHT, COLOR_LIP)
end

-- Retangulo estatico com colisao; (x0, y0) = canto inferior esquerdo
function LevelGenerator:makeBlock(x0, y0, w, h, color, isPlatform)
    local sprite = Sprite(self.scene)
    -- Sprite(scene) e "dono" da entidade: quando o coletor de lixo do Lua
    -- recolhe o objeto, a entidade seria destruida junto (o terreno sumia).
    -- Quem destroi os blocos e o gerador, em destroyChunk.
    sprite.entityOwned = false

    sprite:setSize(w, h)
    sprite.color = Vector4(color[1], color[2], color[3], 1)
    sprite.position = Vector3(x0, y0, 0)
    -- Ordem de desenho segue a hierarquia: os blocos ficam dentro da camada
    -- "Terreno" (antes do Jogador na cena) -> atras do jogador, na frente do fundo
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

function LevelGenerator:guaranteedEnemies()
    local extra = 0
    if self.minEnemiesEvery > 0 then
        extra = math.floor(self.generated / self.minEnemiesEvery)
    end
    return math.min(self.minEnemiesMax, self.minEnemies + extra)
end

function LevelGenerator:spawnChunk(modules, isStart)
    local x = self.nextX
    local mw = self.chunkWidth / #modules
    local top = Chunks.GROUND_TOP
    local chunk = { x = x, names = {}, blocks = {}, enemies = {} }

    local groundRanges, candidates = {}, {}
    for i, m in ipairs(modules) do
        local mx = x + (i - 1) * mw
        chunk.names[i] = m.name

        for _, g in ipairs(m.ground or {}) do
            groundRanges[#groundRanges + 1] = { mx + g[1], mx + g[2] }
        end
        for _, b in ipairs(m.blocks or {}) do
            self:makeSurface(chunk.blocks, mx + b[1], b[2], b[3], b[4], COLOR_BLOCK, false)
        end
        for _, p in ipairs(m.platforms or {}) do
            self:makeSurface(chunk.blocks, mx + p[1], p[2] - PLATFORM_THICKNESS, p[3], PLATFORM_THICKNESS, COLOR_PLATFORM, true)
        end
        for _, e in ipairs(m.enemies or {}) do
            candidates[#candidates + 1] = { mx + e[1], e[2], e[3] }
        end
    end

    for _, g in ipairs(mergeRanges(groundRanges)) do
        self:makeSurface(chunk.blocks, g[1], top - self.groundDepth, g[2] - g[1], self.groundDepth, COLOR_GROUND, false)
    end

    -- Inimigos: embaralha os pontos; os primeiros "garantidos" sempre aparecem,
    -- os demais por chance
    if not isStart then
        for i = #candidates, 2, -1 do
            local j = math.random(i)
            candidates[i], candidates[j] = candidates[j], candidates[i]
        end
        local guaranteed = self:guaranteedEnemies()
        local chance = math.min(1, self.enemyChance + self.generated * self.enemyChanceRamp)
        for i, e in ipairs(candidates) do
            if i <= guaranteed or math.random() < chance then
                chunk.enemies[#chunk.enemies + 1] =
                    Combat.spawnEnemy(self.scene, e[1], e[2], { patrolDistance = e[3] })
            end
        end
    end

    self.chunks[#self.chunks + 1] = chunk
    self.nextX = x + self.chunkWidth
    self.generated = self.generated + 1
end

function LevelGenerator:destroyChunk(chunk)
    for _, root in ipairs(chunk.enemies) do
        BundleManager.destroyBundle(self.scene, root)
    end
    for _, entity in ipairs(chunk.blocks) do
        if self.scene:isEntityCreated(entity) then
            self.scene:destroyEntity(entity)
        end
    end
end

return LevelGenerator
