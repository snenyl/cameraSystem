-- @author: 4c65736975, All Rights Reserved
-- @contributor: snenyl, 24|09|2025
-- @version: 1.0.0.0, 09|08|2023
-- @filename: CameraSystemEnterable.lua

CameraSystemEnterable = {
  MOD_DIRECTORY = g_currentModDirectory
}

CameraSystemEnterable.STATE = {
  OFF = 0,
  ON = 1
}

source(CameraSystemEnterable.MOD_DIRECTORY .. "src/gui/hud/CameraSystemHUDExtension.lua")

local function getCameraSystemCameraCount(vehicle)
  if vehicle ~= nil and vehicle.spec_cameraSystem ~= nil and vehicle.spec_cameraSystem.cameras ~= nil and vehicle.getNumOfCameraSystemCameras ~= nil then
    return vehicle:getNumOfCameraSystemCameras()
  end

  return 0
end

if VehicleHUDExtension ~= nil and VehicleHUDExtension.registerHUDExtension ~= nil then
  VehicleHUDExtension.registerHUDExtension(CameraSystemEnterable, CameraSystemHUDExtension)
else
  Logging.warning("CameraSystemEnterable: VehicleHUDExtension API unavailable - disabling HUD overlay registration.")
end

function CameraSystemEnterable.prerequisitesPresent(specializations)
  return SpecializationUtil.hasSpecialization(Enterable, specializations) and SpecializationUtil.hasSpecialization(CameraSystem, specializations)
end

function CameraSystemEnterable.registerFunctions(vehicleType)
  SpecializationUtil.registerFunction(vehicleType, "addToolCameraSystemCameras", CameraSystemEnterable.addToolCameraSystemCameras)
  SpecializationUtil.registerFunction(vehicleType, "removeToolCameraSystemCameras", CameraSystemEnterable.removeToolCameraSystemCameras)
  SpecializationUtil.registerFunction(vehicleType, "setCameraSystemState", CameraSystemEnterable.setCameraSystemState)
  SpecializationUtil.registerFunction(vehicleType, "setActiveCameraSystemCameraIndex", CameraSystemEnterable.setActiveCameraSystemCameraIndex)
  SpecializationUtil.registerFunction(vehicleType, "getCameraSystemActiveCameraIndex", CameraSystemEnterable.getCameraSystemActiveCameraIndex)
  SpecializationUtil.registerFunction(vehicleType, "getCameraSystemActiveCamera", CameraSystemEnterable.getCameraSystemActiveCamera)
  SpecializationUtil.registerFunction(vehicleType, "getIsCameraSystemActive", CameraSystemEnterable.getIsCameraSystemActive)
  SpecializationUtil.registerFunction(vehicleType, "getHasCameraSystem", CameraSystemEnterable.getHasCameraSystem)
end

function CameraSystemEnterable.registerEventListeners(vehicleType)
  SpecializationUtil.registerEventListener(vehicleType, "onLoad", CameraSystemEnterable)
  SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", CameraSystemEnterable)
  SpecializationUtil.registerEventListener(vehicleType, "onEnterVehicle", CameraSystemEnterable)
  SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", CameraSystemEnterable)
end

function CameraSystemEnterable:onPostLoad(savegame)
  local spec = self.spec_cameraSystemEnterable

  if spec ~= nil then
    spec.hasCameras = getCameraSystemCameraCount(self) > 0

    if spec.hasCameras and spec.activeCamera == nil then
      self:setActiveCameraSystemCameraIndex(spec.camIndex)
    end
  end
end

function CameraSystemEnterable:onLoad(savegame)
  self.spec_cameraSystemEnterable = {}
  local spec = self.spec_cameraSystemEnterable

  spec.actionEvents = {}
  spec.texts = {
    inputToggleCameraSystemOn = g_i18n:getText("action_cameraSystem_on", self.customEnvironment),
    inputToggleCameraSystemOff = g_i18n:getText("action_cameraSystem_off", self.customEnvironment),
    inputToggleCameraSystemSwitchCamera = g_i18n:getText("action_cameraSystem_switchCamera", self.customEnvironment),
  }
  spec.camIndex = 1
  spec.hasCameras = getCameraSystemCameraCount(self) > 0
  spec.currentCameraSystemState = CameraSystemEnterable.STATE.OFF
  spec.isDirty = true

  if spec.hasCameras then
    self:setActiveCameraSystemCameraIndex(spec.camIndex)
  else
    spec.activeCamera = nil
  end
end

function CameraSystemEnterable:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
  if self.isClient then
    local spec = self.spec_cameraSystemEnterable

    self:clearActionEventsTable(spec.actionEvents)

    if isActiveForInputIgnoreSelection and spec.hasCameras then
      local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_CAMERA_SYSTEM, self, CameraSystemEnterable.actionEventCameraSystemState, false, true, false, true, nil)

      g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)

      if getCameraSystemCameraCount(self) > 1 then
        _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.TOGGLE_CAMERA_SYSTEM_CAMERA, self, CameraSystemEnterable.actionEventCameraSystemCameraSwitch, false, true, false, true, nil)

        g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
        g_inputBinding:setActionEventText(actionEventId, spec.texts.inputToggleCameraSystemSwitchCamera)
      end

      CameraSystemEnterable.updateActionEvents(self)
    end
  end
end

function CameraSystemEnterable:actionEventCameraSystemState(actionName, inputValue, callbackState, isAnalog)
  Logging.info(string.format("CameraSystemEnterable: received '%s' (default key: Z) with value %.3f.",
  tostring(actionName), value))

  self:setCameraSystemState()
end

function CameraSystemEnterable:setCameraSystemState()
  local spec = self.spec_cameraSystemEnterable
  local state = nil

  Logging.info("CameraSystemEnterable: Camera system state is now %s", (newState == CameraSystemEnterable.STATE.ON and
   "ON" or "OFF"))


  if spec.currentCameraSystemState == CameraSystemEnterable.STATE.OFF then
    state = CameraSystemEnterable.STATE.ON
  else
    state = CameraSystemEnterable.STATE.OFF
  end

  if spec.currentCameraSystemState ~= state then
    spec.currentCameraSystemState = state

    if self.isClient then
      CameraSystemEnterable.updateActionEvents(self)
    end
  end
end

function CameraSystemEnterable:actionEventCameraSystemCameraSwitch(actionName, inputValue, callbackState, isAnalog)
  local spec = self.spec_cameraSystemEnterable

  Logging.info(string.format("CameraSystemEnterable: received '%s' via %s (value %.3f, current index %d).", tostring(actionName), comboName, value, spec.camIndex))

  self:setActiveCameraSystemCameraIndex(spec.camIndex + MathUtil.sign(inputValue))
end

function CameraSystemEnterable:setActiveCameraSystemCameraIndex(index)
  local spec = self.spec_cameraSystemEnterable
  local numCameras = getCameraSystemCameraCount(self)

  spec.camIndex = index

  if numCameras == 0 then
    spec.camIndex = 1
    spec.activeCamera = nil

    return
  end

  if spec.camIndex <= 0 then
    spec.camIndex = numCameras
  end

  if numCameras < spec.camIndex then
    spec.camIndex = 1
  end

  local cameraSystemSpec = self.spec_cameraSystem

  if cameraSystemSpec ~= nil and cameraSystemSpec.cameras ~= nil then
    spec.activeCamera = cameraSystemSpec.cameras[spec.camIndex]
  else
    spec.activeCamera = nil
  end

  if oldIndex ~= spec.camIndex then
    Logging.info(string.format("CameraSystemEnterable: Active camera index changed %d -> %d (total %d)", oldIndex, spec.camIndex, numCameras))
  end

end

function CameraSystemEnterable:addToolCameraSystemCameras(cameras)
  local spec = self.spec_cameraSystemEnterable
  local cameraSystemSpec = self.spec_cameraSystem

  if cameraSystemSpec == nil or cameraSystemSpec.cameras == nil then
    return
  end

  for _, toolCamera in pairs(cameras) do
    table.insert(cameraSystemSpec.cameras, toolCamera)
  end

  cameraSystemSpec.numCameras = #cameraSystemSpec.cameras

  spec.hasCameras = getCameraSystemCameraCount(self) > 0

  if spec.hasCameras then
    self:setActiveCameraSystemCameraIndex(spec.camIndex)
  end
  -- we have to hard request actions update because some of implements have delay in function execution
  self:requestActionEventUpdate()
end

function CameraSystemEnterable:removeToolCameraSystemCameras(cameras)
  local spec = self.spec_cameraSystemEnterable
  local cameraSystemSpec = self.spec_cameraSystem
  local isToolCameraActive = false

  if cameraSystemSpec == nil or cameraSystemSpec.cameras == nil then
    return
  end

  for i = #cameraSystemSpec.cameras, 1, -1 do
    local camera = cameraSystemSpec.cameras[i]

    for _, toolCamera in pairs(cameras) do
      if camera == toolCamera then
        table.remove(cameraSystemSpec.cameras, i)

        if spec.camIndex == i then
          isToolCameraActive = true
        end

        break
      end
    end
  end

  cameraSystemSpec.numCameras = #cameraSystemSpec.cameras

  spec.hasCameras = getCameraSystemCameraCount(self) > 0

  if isToolCameraActive then
    spec.camIndex = 1

    self:setActiveCameraSystemCameraIndex(spec.camIndex)
  end
end

function CameraSystemEnterable.updateActionEvents(self)
  local spec = self.spec_cameraSystemEnterable
  local actionEvent = spec.actionEvents[InputAction.TOGGLE_CAMERA_SYSTEM]
  local isActive = false

  if actionEvent ~= nil then
    if spec.currentCameraSystemState == CameraSystemEnterable.STATE.OFF then
      g_inputBinding:setActionEventText(actionEvent.actionEventId, spec.texts.inputToggleCameraSystemOff)
    else
      isActive = true

      g_inputBinding:setActionEventText(actionEvent.actionEventId, spec.texts.inputToggleCameraSystemOn)
    end
  end

  actionEvent = spec.actionEvents[InputAction.TOGGLE_CAMERA_SYSTEM_CAMERA]

  if actionEvent ~= nil then
    g_inputBinding:setActionEventActive(actionEvent.actionEventId, isActive)
  end
end

function CameraSystemEnterable:onEnterVehicle(isControlling)
  self.spec_cameraSystemEnterable.isDirty = true
end

function CameraSystemEnterable:getCameraSystemActiveCameraIndex()
  return self.spec_cameraSystemEnterable.camIndex
end

function CameraSystemEnterable:getCameraSystemActiveCamera()
  return self.spec_cameraSystemEnterable.activeCamera
end

function CameraSystemEnterable:getIsCameraSystemActive()
  return self.spec_cameraSystemEnterable.currentCameraSystemState ~= CameraSystemEnterable.STATE.OFF
end

function CameraSystemEnterable:getHasCameraSystem()
  return self.spec_cameraSystemEnterable.hasCameras
end
