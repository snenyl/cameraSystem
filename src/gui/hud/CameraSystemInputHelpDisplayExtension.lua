-- @author: 4c65736975, All Rights Reserved
-- @contributor: snenyl, 24|09|2025
-- @version: 1.0.0.0, 03|03|2023
-- @filename: CameraSystemInputHelpDisplayExtension.lua

CameraSystemInputHelpDisplayExtension = {}

-- HelpType shim for FS22/FS25 compatibility (ASCII only)
-- If non-ASCII is found in API names, they are replaced: [REMOVED: U+NNNN]
local HelpType = nil
if _G.InputHelpDisplayElement ~= nil and InputHelpDisplayElement.TYPE ~= nil then
  HelpType = InputHelpDisplayElement.TYPE
elseif _G.InputHelpDisplay ~= nil and InputHelpDisplay.TYPE ~= nil then
  HelpType = InputHelpDisplay.TYPE
else
  HelpType = { HEADER = 1, ACTION = 2, GROUP = 3 }
end

local CameraSystemInputHelpDisplayExtension_mt = Class(CameraSystemInputHelpDisplayExtension)

function CameraSystemInputHelpDisplayExtension.new(customMt)
  local self = setmetatable({}, customMt or CameraSystemInputHelpDisplayExtension_mt)

  Logging.info("DEBUG: Running CameraSystemInputHelpDisplayExtension")

  self.isActive = false

  self.labelText = g_i18n:getText("ui_cameraSystem_header"):upper()
  -- In FS25, InputHelpDisplay.SIZE.HEADER may not exist. Defer width calculation to runtime.
  self.inputHelpWidth = 0

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
  local controlsLabelColor = {1, 1, 1, 1}
  if InputHelpDisplay ~= nil and InputHelpDisplay.COLOR ~= nil and InputHelpDisplay.COLOR.CONTROLS_LABEL ~= nil then
    controlsLabelColor = InputHelpDisplay.COLOR.CONTROLS_LABEL
  end
  setTextColor(unpack(controlsLabelColor))
  setTextAlignment(RenderText.ALIGN_LEFT)

  local baseX, baseY = self:getInputHelpBasePosition(inputHelpDisplay)
  local frameX = baseX + inputHelpDisplay.frameOffsetX
  local frameTopY = baseY + inputHelpDisplay.frameOffsetY
  local posX = frameX + inputHelpDisplay.controlsLabelOffsetX
  local posY = frameTopY + inputHelpDisplay.controlsLabelOffsetY

  renderText(posX, posY, inputHelpDisplay.controlsLabelTextSize, self.labelText)
end

function CameraSystemInputHelpDisplayExtension:drawVehicleHUDExtensionss(inputHelpDisplay)
  if inputHelpDisplay.extensionsHeight > 0 then
    local leftPosX, posY = self:getInputHelpBasePosition(inputHelpDisplay)
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

function CameraSystemInputHelpDisplayExtension:getInputHelpBasePosition(inputHelpDisplay)
  local vehicleSchema = g_currentMission.hud.vehicleSchema
  local alpha = 1

  if vehicleSchema ~= nil and vehicleSchema.animation ~= nil and not vehicleSchema.animation:getFinished() then
    alpha = math.min(vehicleSchema.animation.elapsedTime / vehicleSchema.animation.totalDuration, 1)
  elseif vehicleSchema ~= nil and vehicleSchema.isDocked ~= nil and not vehicleSchema.isDocked then
    alpha = 0
  end

  -- Determine current input help width robustly across FS versions
  local width = 0
  if inputHelpDisplay ~= nil then
    if inputHelpDisplay.getWidth ~= nil then
      width = inputHelpDisplay:getWidth()
    elseif inputHelpDisplay.width ~= nil then
      width = inputHelpDisplay.width
    end
  end
  if width == 0 then
    local uiScale = (g_gameSettings ~= nil and g_gameSettings.getValue ~= nil) and (g_gameSettings:getValue("uiScale") or 1) or 1
    local normalizedWidth, _ = getNormalizedScreenValues(620 * uiScale, 0) -- fallback estimate
    width = normalizedWidth
  end
  self.inputHelpWidth = width

  local xOffset = (1 - alpha) * self.inputHelpWidth

  local posX, posY = 0, 0
  if InputHelpDisplay ~= nil and InputHelpDisplay.getBackgroundPosition ~= nil then
    posX, posY = InputHelpDisplay.getBackgroundPosition()
  elseif InputHelpDisplayElement ~= nil and InputHelpDisplayElement.getBackgroundPosition ~= nil then
    posX, posY = InputHelpDisplayElement.getBackgroundPosition()
  else
    -- Fallback near bottom-left if API changed
    posX, posY = 0, 0
  end

  return posX - xOffset, posY
end
