-- VolumeControl.lua
-- Barra de volume com botoes - e +. Vai na entidade da barra (Progressbar).

local Settings = require("game.Settings")

local VolumeControl = {
    properties = {
        { name = "downButton", displayName = "Botao -",       type = "Button" },
        { name = "upButton",   displayName = "Botao +",       type = "Button" },
        { name = "step",       displayName = "Passo (0 a 1)", type = "float", default = 0.1 },
    }
}

function VolumeControl:init()
    self.bar = Progressbar(self.scene, self.entity)
    self.bar.fillColor = Vector4(0.91, 0.667, 0.235, 1)
    self.bar.value = Settings.volume

    RegisterEvent(self, self.downButton:getButtonComponent().onRelease, "onDown")
    RegisterEvent(self, self.upButton:getButtonComponent().onRelease, "onUp")
end

function VolumeControl:onDown()
    Settings.setVolume(Settings.volume - self.step)
    self.bar.value = Settings.volume
end

function VolumeControl:onUp()
    Settings.setVolume(Settings.volume + self.step)
    self.bar.value = Settings.volume
end

return VolumeControl
