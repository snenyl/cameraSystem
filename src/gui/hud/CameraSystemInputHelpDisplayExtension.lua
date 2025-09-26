-- @author: 4c65736975, All Rights Reserved
-- @contributor: snenyl, 24|09|2025
-- @version: 1.0.0.0, 03|03|2023
-- @filename: CameraSystemInputHelpDisplayExtension.lua

CameraSystemInputHelpDisplayExtension = {}

local CameraSystemInputHelpDisplayExtension_mt = Class(CameraSystemInputHelpDisplayExtension)

function CameraSystemInputHelpDisplayExtension.new(customMt)
  local self = setmetatable({}, customMt or CameraSystemInputHelpDisplayExtension_mt)

  self.isActive = false

  local headerLabel = g_i18n:getText("ui_cameraSystem_header")

  if type(headerLabel) ~= "string" then
    headerLabel = "Camera System"
  end

  self.labelText = headerLabel:upper()
  local uiScale = 1

  if g_gameSettings ~= nil and g_gameSettings.getValue ~= nil then
    uiScale = g_gameSettings:getValue("uiScale") or uiScale
  end

  local headerWidth = nil

  if InputHelpDisplay ~= nil and type(InputHelpDisplay.SIZE) == "table" then
    local size = InputHelpDisplay.SIZE

    if type(size.HEADER) == "table" then
      headerWidth = size.HEADER[1]
    elseif type(size.HEADER_WIDTH) == "number" then
      headerWidth = size.HEADER_WIDTH
    end

    if headerWidth == nil then
      local widthFallback = InputHelpDisplay.WIDTH
        or InputHelpDisplay.DEFAULT_WIDTH
        or InputHelpDisplay.MAX_WIDTH

      if type(widthFallback) == "number" then
        headerWidth = widthFallback
      end
    end
  end

  headerWidth = headerWidth or 512

  self.inputHelpWidth, _ = getNormalizedScreenValues(headerWidth * uiScale, 0)

  -- Optional one-time debug of InputHelpDisplay structure for FS25 vs FS22
  if g_modIsLoaded == nil or self.__debugDumpDone ~= true then
    if InputHelpDisplay ~= nil then
      if table ~= nil and table.keys ~= nil then
        local ok, keys = pcall(table.keys, InputHelpDisplay)
        if ok and type(keys) == "table" and #keys > 0 then
          Logging.info("DEBUG: InputHelpDisplay keys = %s", table.concat(keys, ", "))
        end
      else
        -- Minimal fallback: iterate keys without ordering
        local list = {}
        for k, _ in pairs(InputHelpDisplay) do
          table.insert(list, tostring(k))
        end
        if #list > 0 then
          Logging.info("DEBUG: InputHelpDisplay keys = %s", table.concat(list, ", "))
        end
      end

      if type(InputHelpDisplay.SIZE) == "table" then
        for k, v in pairs(InputHelpDisplay.SIZE) do
          Logging.info("DEBUG: InputHelpDisplay.SIZE[%s] = %s", tostring(k), tostring(v))
        end
      end
    end

    self.__debugDumpDone = true
  end

  return self
end

function CameraSystemInputHelpDisplayExtension:overwriteGameFunctions(cameraSystem)
  -- Shim: safe getter for available height across FS22/FS25
  local function getAvailableHeightSafe(hud)
    if hud ~= nil and type(hud.getAvailableHeight) == "function" then
      local ok, h = pcall(hud.getAvailableHeight, hud)
      if ok and type(h) == "number" then
        return h
      end
    end
    if hud ~= nil and type(hud.extensionsHeight) == "number" then
      return hud.extensionsHeight
    end
    if hud ~= nil and type(hud.availableHeight) == "number" then
      return hud.availableHeight
    end
    return 0
  end
  cameraSystem:overwriteGameFunction(InputHelpDisplay, "update", function (superFunc, self, dt)
    superFunc(self, dt)

    -- Normalize FS22/FS25 field name once and reuse
    if self.vehicleHudExtensionsRef == nil then
      local ref = nil

      if self.vehicleHudExtensions ~= nil then
        ref = self.vehicleHudExtensions
      elseif self.vehicleHUDExtensions ~= nil then
        ref = self.vehicleHUDExtensions
      end

      -- One-time dump to help identify the correct field
      if self.__vehHudExtDumpDone ~= true then
        Logging.info("DEBUG: InputHelpDisplay vehicle HUD extensions field chosen = %s",
          (self.vehicleHudExtensions ~= nil and "vehicleHudExtensions")
            or (self.vehicleHUDExtensions ~= nil and "vehicleHUDExtensions")
            or "<none>")
        self.__vehHudExtDumpDone = true
      end

      self.vehicleHudExtensionsRef = ref
    end

    local vehicleHudExtensions = self.vehicleHudExtensionsRef

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
      local vehicleSchema = (g_currentMission ~= nil and g_currentMission.hud ~= nil) and g_currentMission.hud.vehicleSchema or nil

      self.isActive = false

    -- Cross-version safe available height
    inputHelpDisplay.currentAvailableHeight = getAvailableHeightSafe(inputHelpDisplay)

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

      if vehicleSchema ~= nil and not self.isActive and vehicleSchema.isDocked and vehicleSchema.animation:getFinished() and not g_cameraSystem:getIsPrecisionFarming() then
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
      local width
      if type(inputHelpDisplay.getWidth) == "function" then
        local ok, w = pcall(inputHelpDisplay.getWidth, inputHelpDisplay)
        if ok and type(w) == "number" then width = w end
      end
      if type(width) ~= "number" then
        if InputHelpDisplay and InputHelpDisplay.SIZE and type(InputHelpDisplay.SIZE.HEADER) == "table" then
          width = InputHelpDisplay.SIZE.HEADER[1]
        elseif InputHelpDisplay and type(InputHelpDisplay.WIDTH) == "number" then
          width = InputHelpDisplay.WIDTH
        elseif InputHelpDisplay and type(InputHelpDisplay.DEFAULT_WIDTH) == "number" then
          width = InputHelpDisplay.DEFAULT_WIDTH
        else
          width = 512
        end
      end

    posY = posY + inputHelpDisplay.frameOffsetY
    local usedHeight = 0

    -- Normalize field name on inputHelpDisplay once and reuse
    if inputHelpDisplay.vehicleHudExtensionsRef == nil then
      local ref = nil

      if inputHelpDisplay.vehicleHudExtensions ~= nil then
        ref = inputHelpDisplay.vehicleHudExtensions
      elseif inputHelpDisplay.vehicleHUDExtensions ~= nil then
        ref = inputHelpDisplay.vehicleHUDExtensions
      end

      if inputHelpDisplay.__vehHudExtDumpDone ~= true then
        Logging.info("DEBUG: inputHelpDisplay HUD extensions field chosen = %s",
          (inputHelpDisplay.vehicleHudExtensions ~= nil and "vehicleHudExtensions")
            or (inputHelpDisplay.vehicleHUDExtensions ~= nil and "vehicleHUDExtensions")
            or "<none>")
        inputHelpDisplay.__vehHudExtDumpDone = true
      end

      inputHelpDisplay.vehicleHudExtensionsRef = ref
    end

    local vehicleHudExtensions = inputHelpDisplay.vehicleHudExtensionsRef

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
