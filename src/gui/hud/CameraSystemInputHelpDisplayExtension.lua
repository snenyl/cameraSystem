-- @author: 4c65736975, All Rights Reserved
-- @contributor: snenyl, 24|09|2025
-- @version: 1.0.0.0, 03|03|2023
-- @filename: CameraSystemInputHelpDisplayExtension.lua

CameraSystemInputHelpDisplayExtension = {}

local CameraSystemInputHelpDisplayExtension_mt = Class(CameraSystemInputHelpDisplayExtension)

function CameraSystemInputHelpDisplayExtension.new(customMt)
  local self = setmetatable({}, customMt or CameraSystemInputHelpDisplayExtension_mt)

  self.isActive = false

  self.labelText = g_i18n:getText("ui_cameraSystem_header"):upper()
  local uiScale = 1

  if g_gameSettings ~= nil and g_gameSettings.getValue ~= nil then
    uiScale = g_gameSettings:getValue("uiScale") or uiScale
  end

  local headerWidth = nil

  if InputHelpDisplay ~= nil and InputHelpDisplay.SIZE ~= nil and InputHelpDisplay.SIZE.HEADER ~= nil then
    headerWidth = InputHelpDisplay.SIZE.HEADER[1]
  elseif InputHelpDisplay ~= nil and InputHelpDisplay.WIDTH ~= nil then
    headerWidth = InputHelpDisplay.WIDTH
  end

  headerWidth = headerWidth or 512

  self.inputHelpWidth, _ = getNormalizedScreenValues(headerWidth * uiScale, 0)

  return self
end

function CameraSystemInputHelpDisplayExtension:overwriteGameFunctions(cameraSystem)
  cameraSystem:overwriteGameFunction(InputHelpDisplay, "update", function (superFunc, self, dt)
    superFunc(self, dt)

    local vehicleHudExtensions = self.vehicleHudExtensions or self.vehicleHUDExtensions

    if vehicleHudExtensions == nil then
      return
    end

    for _, extension in pairs(vehicleHudExtensions) do
      if extension:isa(CameraSystemHUDExtension) then
        if extension:canDraw() then
          extension:update(dt)
        end
      end
    end
  end)

  cameraSystem:overwriteGameFunction(InputHelpDisplay, "draw", function (superFunc, inputHelpDisplay)
    if not inputHelpDisplay:getVisible() then
      local vehicleSchema = g_currentMission.hud.vehicleSchema

      self.isActive = false

      inputHelpDisplay.currentAvailableHeight = inputHelpDisplay:getAvailableHeight()

      if inputHelpDisplay.updateHUDExtensions ~= nil then
        inputHelpDisplay:updateHUDExtensions()
      end

      if self:drawVehicleHUDExtensionss(inputHelpDisplay) then
        self:drawControlsLabels(inputHelpDisplay)

        self.isActive = true

        if not vehicleSchema.isDocked and vehicleSchema.animation:getFinished() then
          vehicleSchema:setDocked(true, true)
        end
      end

      if not self.isActive and vehicleSchema.isDocked and vehicleSchema.animation:getFinished() and not g_cameraSystem:getIsPrecisionFarming() then
        vehicleSchema:setDocked(false, true)
      end
    end

    if inputHelpDisplay:getVisible() or not self.isActive then
      superFunc(inputHelpDisplay)
    end
  end)
end

function CameraSystemInputHelpDisplayExtension:drawControlsLabels(inputHelpDisplay)
  setTextBold(true)
  local controlsColor = {1, 1, 1, 1}

  if InputHelpDisplay ~= nil and InputHelpDisplay.COLOR ~= nil and InputHelpDisplay.COLOR.CONTROLS_LABEL ~= nil then
    controlsColor = InputHelpDisplay.COLOR.CONTROLS_LABEL
  end

  setTextColor(unpack(controlsColor))
  setTextAlignment(RenderText.ALIGN_LEFT)

  local baseX, baseY = self:getInputHelpBasePosition()
  local frameX = baseX + inputHelpDisplay.frameOffsetX
  local frameTopY = baseY + inputHelpDisplay.frameOffsetY
  local posX = frameX + inputHelpDisplay.controlsLabelOffsetX
  local posY = frameTopY + inputHelpDisplay.controlsLabelOffsetY

  renderText(posX, posY, inputHelpDisplay.controlsLabelTextSize, self.labelText)
end

function CameraSystemInputHelpDisplayExtension:drawVehicleHUDExtensionss(inputHelpDisplay)
  if inputHelpDisplay.extensionsHeight > 0 then
    local leftPosX, posY = self:getInputHelpBasePosition()
    local width = inputHelpDisplay:getWidth()

    posY = posY + inputHelpDisplay.frameOffsetY
    local usedHeight = 0

    local vehicleHudExtensions = inputHelpDisplay.vehicleHudExtensions or inputHelpDisplay.vehicleHUDExtensions

    if vehicleHudExtensions == nil then
      return false
    end

    for _, extension in pairs(vehicleHudExtensions) do
      if extension:isa(CameraSystemHUDExtension) then
        local extHeight = extension:getDisplayHeight()

        if extension:canDraw() and usedHeight + extHeight <= inputHelpDisplay.extensionsHeight then
          posY = posY - extHeight - inputHelpDisplay.entryOffsetY

          if inputHelpDisplay.extensionBg ~= nil then
            inputHelpDisplay.extensionBg:setPosition(leftPosX, posY)
            inputHelpDisplay.extensionBg:setDimension(width, extHeight)
            inputHelpDisplay.extensionBg:render()
          end

          extension:draw(leftPosX + inputHelpDisplay.extraTextOffsetX, leftPosX + width + inputHelpDisplay.helpTextOffsetX, posY)

          usedHeight = usedHeight + extHeight
        end
      end
    end

    return usedHeight ~= 0
  end

  return false
end

function CameraSystemInputHelpDisplayExtension:getInputHelpBasePosition()
  local vehicleSchema = g_currentMission.hud.vehicleSchema
  local alpha = 1

  if not vehicleSchema.animation:getFinished() then
    alpha = math.min(vehicleSchema.animation.elapsedTime / vehicleSchema.animation.totalDuration, 1)
  elseif not vehicleSchema.isDocked then
    alpha = 0
  end

  local xOffset = (1 - alpha) * self.inputHelpWidth
  local posX, posY = 0, 0

  if InputHelpDisplay ~= nil and InputHelpDisplay.getBackgroundPosition ~= nil then
    posX, posY = InputHelpDisplay.getBackgroundPosition()
  end

  return posX - xOffset, posY
end
