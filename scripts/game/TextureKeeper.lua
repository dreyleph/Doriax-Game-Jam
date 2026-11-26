-- TextureKeeper.lua
-- Segura na memoria as texturas que aparecem e somem durante a partida
-- (require("game.TextureKeeper")).
--
-- A engine libera uma textura assim que o ultimo sprite que a usa e destruido
-- (TexturePool: sem ninguem usando, a imagem sai da memoria). O proximo sprite
-- com a mesma imagem faz a engine ler o arquivo do disco de novo, e o jogo
-- "engasga" naquele frame. Acontecia:
--   * a cada item que caia de um inimigo (quase nunca ha outro item no chao);
--   * quando surgia um atirador sem outro atirador vivo (atlas do Enemy2);
--   * quando surgia um soldado sem outro soldado vivo (atlas do Enemy1).
-- Solucao: um sprite escondido por imagem, criado no inicio da fase e que fica
-- ate a cena acabar (o mesmo truque do Player:prepareSlashFx). Escondido ele
-- nao aparece, mas a engine carrega a textura do mesmo jeito.
--
-- Ligacao: Player:init -> TextureKeeper.keepGameplayTextures(scene)

local Itens = require("itens.Itens")
local EnemyAnimations = require("enemy.EnemyAnimations")
local EnemyAnimations2 = require("enemy.EnemyAnimations2")

local TextureKeeper = {}

-- Mesmo filtro "nearest" que Itens/Enemy usam: a engine guarda a textura
-- por caminho + filtro, entao o sprite guardiao tem que usar o mesmo
local function setNearest(sprite)
    pcall(function()
        local mat = sprite.material
        local t = mat.baseColorTexture
        t.minFilter = TextureFilter.NEAREST
        t.magFilter = TextureFilter.NEAREST
        mat.baseColorTexture = t
        sprite.material = mat
    end)
end

function TextureKeeper.keep(scene, path)
    local ok, err = pcall(function()
        local sprite = Sprite(scene)
        sprite.entityOwned = false   -- fica ate a cena acabar (sai junto com ela)
        sprite:setSize(1, 1)
        setNearest(sprite)
        sprite:setTexture(path)
        sprite.visible = false
    end)
    if not ok then
        Log.print("TextureKeeper: nao foi possivel segurar " .. tostring(path) .. " (" .. tostring(err) .. ")")
    end
    return ok
end

-- Caminhos de textura de uma tabela de animacoes (Animator)
local function addAnimationTextures(paths, animations)
    for _, def in pairs(animations) do
        if type(def) == "table" and def.texture then paths[def.texture] = true end
    end
end

function TextureKeeper.keepGameplayTextures(scene)
    if not scene then return end
    local paths = {}
    for _, t in ipairs(Itens.TYPES) do
        if t.sprite and t.sprite.path then paths[t.sprite.path] = true end
    end
    addAnimationTextures(paths, EnemyAnimations)
    addAnimationTextures(paths, EnemyAnimations2)
    for path in pairs(paths) do
        TextureKeeper.keep(scene, path)
    end
end

return TextureKeeper
