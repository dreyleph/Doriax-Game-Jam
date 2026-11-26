-- HUD.lua
-- HUD da partida (cena de UI "HUD", anexada como cena filha das fases).
-- Le vidas, pontos e distancia do GameState (e a municao dos Itens) e so
-- reescreve um texto/icone quando o valor muda.
--
--   * PONTOS = pontos dos abates durante a corrida; a distancia (metros) fica no
--     canto superior direito e so entra na pontuacao no fim (GAME OVER), quando
--     PONTOS passa a mostrar o total
--   * vidas: uma garrafa de Tipu por vida (assets/HUD/vida_tipu.png)
--   * municao da Escopeta: um cartucho por disparo (assets/HUD/municao_slug.png)
--   * GAME OVER: mostra o resumo (abates + distancia = total) sobre o fundo
--     preto da tela de game over (ui/GameOverMenu.lua, com os botoes) e
--     esconde o que fica por cima dele (metros, cartuchos)
-- Os icones e os textos novos sao criados aqui (Image/Text da engine); se nao
-- der para criar, volta aos textos simples. Todos os textos usam a fonte
-- pixelada "Fonte do HUD". Icones gerados por tools/montar_icones_hud.py.

local GameState = require("game.GameState")
local Itens = require("itens.Itens")

local HUD = {
    properties = {
        { name = "scoreText",    displayName = "Texto dos pontos",    type = "Text" },
        { name = "livesText",    displayName = "Texto das vidas",     type = "Text" },
        { name = "gameOverText", displayName = "Texto de game over",  type = "Text" },
        { name = "ammoText",     displayName = "Texto da municao",    type = "Text" },
        { name = "scoreDigits",  displayName = "Digitos da pontuacao", type = "int", default = 6 },
        { name = "fontPath",     displayName = "Fonte do HUD (caminho em assets/)", type = "string", default = "Fonte/BoldPixels.ttf" },
        { name = "lifeIcon",     displayName = "Icone de vida (caminho em assets/, vazio = texto)", type = "string", default = "HUD/vida_tipu.png" },
        { name = "lifeIconWidth",  displayName = "Icone de vida: largura (px)",  type = "float", default = 22.0 },
        { name = "lifeIconHeight", displayName = "Icone de vida: altura (px)",   type = "float", default = 44.0 },
        { name = "lifeIconX",      displayName = "Icone de vida: x do primeiro (px)", type = "float", default = 32.0 },
        { name = "lifeIconY",      displayName = "Icone de vida: y a partir do topo (px)", type = "float", default = 60.0 },
        { name = "lifeIconGap",    displayName = "Icone de vida: espaco entre eles (px)", type = "float", default = 8.0 },
        { name = "ammoIcon",       displayName = "Icone de municao da Escopeta (vazio = texto)", type = "string", default = "HUD/municao_slug.png" },
        { name = "ammoIconWidth",  displayName = "Icone de municao: largura (px)", type = "float", default = 14.0 },
        { name = "ammoIconHeight", displayName = "Icone de municao: altura (px)",  type = "float", default = 22.0 },
        { name = "ammoIconX",      displayName = "Icone de municao: x do primeiro (px)", type = "float", default = 32.0 },
        { name = "ammoIconY",      displayName = "Icone de municao: y a partir do topo (px)", type = "float", default = 140.0 },
        { name = "ammoIconGap",    displayName = "Icone de municao: espaco entre eles (px)", type = "float", default = 4.0 },
    }
}

function HUD:init()
    -- propriedades novas ainda nao gravadas na cena chegam como nil
    for _, p in ipairs(HUD.properties) do
        if self[p.name] == nil and p.default ~= nil then self[p.name] = p.default end
    end
    self.hasFont = self.fontPath and self.fontPath ~= ""
    for _, t in ipairs({ self.scoreText, self.livesText, self.gameOverText, self.ammoText }) do
        self:useFont(t)
    end

    self.lifeIcons, self.ammoIcons = {}, {}
    self.useLifeIcons = self.lifeIcon ~= nil and self.lifeIcon ~= ""
    self.useAmmoIcons = self.ammoIcon ~= nil and self.ammoIcon ~= ""

    -- distancia (canto superior direito) e resumo do game over (centro)
    self.distanceText = self:makeText("TOP_RIGHT", -32, 24, 32, { 1, 0.85, 0.25, 1 })
    self.summaryText = self:makeText("CENTER", 0, -40, 28, { 1, 1, 1, 1 })
    if self.summaryText then self.summaryText.visible = false end

    self.shown = {}
    RegisterEngineEvent(self, "onUpdate")
    self:refresh()
end

function HUD:useFont(t)
    if t and self.hasFont then t.font = self.fontPath end
end

-- Texto criado por script, ancorado na tela (y para baixo a partir da ancora)
function HUD:makeText(anchor, x, y, size, color)
    local ok, t = pcall(function()
        local t = Text(self.scene)
        t.entityOwned = false   -- fica ate a cena acabar
        t.text = " "
        t.fontSize = size
        t.color = Vector4(color[1], color[2], color[3], color[4])
        t.anchorPreset = AnchorPreset[anchor]
        t.usingAnchors = true
        t.positionOffset = Vector2(x, y)
        return t
    end)
    if not ok then
        Log.print("HUD: nao foi possivel criar texto (" .. tostring(t) .. ")")
        return nil
    end
    self:useFont(t)
    return t
end

-- Fileira de icones (um por unidade): cria os que faltarem e esconde os que
-- sobram. Retorna false se nao conseguiu criar (ai o HUD usa texto).
function HUD:showIcons(list, count, path, w, h, x0, y, gap)
    for i = #list + 1, count do
        local ok, icon = pcall(function()
            local img = Image(self.scene)
            img.entityOwned = false   -- fica ate a cena acabar
            img:setTexture(path)
            img.anchorPreset = AnchorPreset.TOP_LEFT
            img.usingAnchors = true
            img:setSize(math.floor(w + 0.5), math.floor(h + 0.5))   -- so aceita inteiros
            img.positionOffset = Vector2(x0 + (i - 1) * (w + gap), y)
            return img
        end)
        if not ok then
            Log.print("HUD: nao foi possivel criar o icone " .. path .. " (" .. tostring(icon) .. "); usando texto")
            for _, img in ipairs(list) do img.visible = false end
            return false
        end
        list[i] = icon
    end
    for i, img in ipairs(list) do
        img.visible = i <= count
    end
    return true
end

function HUD:changed(key, value)
    if self.shown[key] == value then return false end
    self.shown[key] = value
    return true
end

function HUD:refresh()
    local total = GameState.total()
    -- durante a corrida so os abates; no GAME OVER a distancia e somada
    local points = GameState.gameOver and total or GameState.score
    if self.scoreText and self:changed("points", points) then
        local text = string.format("PONTOS %0" .. self.scoreDigits .. "d", points)
        if not self.distanceText then text = text .. string.format("   %d m", GameState.distance) end
        self.scoreText.text = text
    end
    if self.distanceText and self:changed("distanceShown", not GameState.gameOver) then
        self.distanceText.visible = not GameState.gameOver
    end
    if self.distanceText and self:changed("distance", GameState.distance) then
        self.distanceText.text = string.format("%d m", GameState.distance)
    end

    if self:changed("lives", GameState.lives) then
        local lives = GameState.lives
        if self.useLifeIcons and self:showIcons(self.lifeIcons, lives, self.lifeIcon, self.lifeIconWidth,
                self.lifeIconHeight, self.lifeIconX, self.lifeIconY, self.lifeIconGap) then
            if self.livesText then self.livesText.visible = false end
        else
            self.useLifeIcons = false
            if self.livesText then
                self.livesText.visible = true
                self.livesText.text = "VIDAS x" .. lives
            end
        end
    end

    -- municao: pistola infinita; Escopeta = cartuchos (ou texto, sem icone)
    local shells = (Itens.secondaryWeapon == "escopeta") and Itens.secondaryAmmo or 0
    if GameState.gameOver then shells = 0 end   -- cartuchos ficariam por cima do fundo preto
    if self:changed("shells", shells) then
        local ammo = "PISTOLA INF"
        if self.useAmmoIcons and self:showIcons(self.ammoIcons, shells, self.ammoIcon, self.ammoIconWidth,
                self.ammoIconHeight, self.ammoIconX, self.ammoIconY, self.ammoIconGap) then
            if shells > 0 then ammo = ammo .. "   ESCOPETA" end
        else
            self.useAmmoIcons = false
            if shells > 0 then ammo = ammo .. "   ESCOPETA x" .. shells end
        end
        if self.ammoText then self.ammoText.text = ammo end
    end

    if self:changed("gameOver", GameState.gameOver) then
        if self.gameOverText then self.gameOverText.visible = GameState.gameOver end
        if self.summaryText then
            self.summaryText.visible = GameState.gameOver
            if GameState.gameOver then
                self.summaryText.text = string.format("ABATES %d  +  %d m (%d)  =  %d",
                    GameState.score, GameState.distance, GameState.distancePoints(), total)
            end
        end
    end
end

function HUD:onUpdate()
    self:refresh()
end

return HUD
