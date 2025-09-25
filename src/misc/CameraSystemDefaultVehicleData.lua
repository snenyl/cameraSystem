-- @author: 4c65736975, All Rights Reserved
-- @contributor: snenyl, 2024|09|24
-- @version: 1.0.0.1, 12|08|2023
-- @filename: CameraSystemDefaultVehicleData.lua

-- Changelog (1.0.0.1):
-- added option to add cameras to mod/internalMod/dlc vehicles

CameraSystemDefaultVehicleData = {
  MOD_NAME = g_currentModName,
  MOD_DIRECTORY = g_currentModDirectory,
  CONFIG_XML_KEY = "cameraSystemDefaultVehicleData.vehicles.vehicle(?).cameras.camera(?)",
  XML_SCHEMA = nil
}

CameraSystemDefaultVehicleData.CONFIG_XML_FILE = Utils.getFilename("data/CameraSystemDefaultVehicleData.xml", CameraSystemDefaultVehicleData.MOD_DIRECTORY)

local CameraSystemDefaultVehicleData_mt = Class(CameraSystemDefaultVehicleData)

function CameraSystemDefaultVehicleData.new(customMt)
  local self = setmetatable({}, customMt or CameraSystemDefaultVehicleData_mt)

  self.cameraData = {}
  self.isLoaded = false
  self.legacyFallbackWarningShown = false

  CameraSystemDefaultVehicleData.XML_SCHEMA = XMLSchema.new("cameraSystemDefaultVehicleData")

  self:registerXMLPaths(CameraSystemDefaultVehicleData.XML_SCHEMA)

  return self
end

function CameraSystemDefaultVehicleData:loadFromXMLFile()
  if not self.isLoaded then
    self:loadDefualtVehicleCameraSystemData()
  end
end

function CameraSystemDefaultVehicleData:loadDefualtVehicleCameraSystemData()
  local xmlFile = XMLFile.load("CameraSystemDefaultVehicleDataXML", CameraSystemDefaultVehicleData.CONFIG_XML_FILE, CameraSystemDefaultVehicleData.XML_SCHEMA)

  if xmlFile ~= nil then
    self.cameraData = {}

    xmlFile:iterate("cameraSystemDefaultVehicleData.vehicles.vehicle", function (_, key)
      local vehicle = {
        xmlFilename = self:getVehicleXmlFilenamePath(xmlFile:getValue(key .. "#xmlFilename")),
        price = xmlFile:getValue(key .. "#price", 500)
      }

      if vehicle.xmlFilename == nil or vehicle.xmlFilename == "" then
        Logging.xmlWarning(xmlFile, "Missing or invalid 'xmlFilename' for vehicle entry '%s' - skipping.", key)

        return
      end

      vehicle.cameras = {}

      xmlFile:iterate(key .. ".cameras.camera", function (_, cameraKey)
        local camera = {}

        camera.nodeName = xmlFile:getValue(cameraKey .. "#nodeName")

        if camera.nodeName == nil or camera.nodeName == "" then
          Logging.xmlWarning(xmlFile, "Missing 'nodeName' for camera '%s' - entry ignored.", cameraKey)
        else
          local visibilityNodeName = xmlFile:getValue(cameraKey .. "#visibilityNodeName")

          if visibilityNodeName and visibilityNodeName ~= "" then
            camera.visibilityNodeName = visibilityNodeName
          end

          camera.name = xmlFile:getValue(cameraKey .. "#name", "ui_cameraSystem_nameDefault", CameraSystemDefaultVehicleData.MOD_NAME)
          camera.translation = xmlFile:getValue(cameraKey .. "#translation", "0 0 0", true)
          camera.rotation = xmlFile:getValue(cameraKey .. "#rotation", "0 0 0", true)
          camera.fov = xmlFile:getValue(cameraKey .. "#fov", 60)
          camera.nearClip = xmlFile:getValue(cameraKey .. "#nearClip", 0.01)
          camera.farClip = xmlFile:getValue(cameraKey .. "#farClip", 10000)
          camera.activeFunc = xmlFile:getValue(cameraKey .. "#activeFunc")

          table.insert(vehicle.cameras, camera)
        end
      end)

      if #vehicle.cameras == 0 then
        Logging.xmlWarning(xmlFile, "Vehicle '%s' does not define any valid cameras - skipping.", vehicle.xmlFilename)

        return
      end

      vehicle.basename = vehicle.xmlFilename:match("([^/\\]+)$")

      table.insert(self.cameraData, vehicle)
    end)

    xmlFile:delete()
  end

  self.isLoaded = true
end

function CameraSystemDefaultVehicleData:overwriteGameFunctions(cameraSystem)
  local defaultVehicleData = self

  if ConfigurationUtil ~= nil then
    cameraSystem:overwriteGameFunction(ConfigurationUtil, "getConfigurationsFromXML", function (superFunc, manager, xmlFile, key, baseDir, customEnvironment, isMod, storeItem)
      local configurations, defaultConfigurationIds = superFunc(manager, xmlFile, key, baseDir, customEnvironment, isMod, storeItem)
      local vehicleManager = g_vehicleConfigurationManager
      local useLegacyFallback = vehicleManager == nil and g_configurationManager ~= nil
      local handlesVehicleConfigs = (vehicleManager ~= nil and manager == vehicleManager) or (useLegacyFallback and manager == g_configurationManager)

      if useLegacyFallback and handlesVehicleConfigs and not defaultVehicleData.legacyFallbackWarningShown then
        Logging.warning("CameraSystem: g_vehicleConfigurationManager missing - using legacy configuration manager fallback (intended for FS22 compatibility).")
        defaultVehicleData.legacyFallbackWarningShown = true
      end

      if handlesVehicleConfigs then
        if not defaultVehicleData.isLoaded then
          defaultVehicleData:loadDefualtVehicleCameraSystemData()
        end

        local xmlFilename = nil

        if type(xmlFile) == "table" then
          xmlFilename = xmlFile.filename
        elseif type(xmlFile) == "string" then
          xmlFilename = xmlFile
        end

        if xmlFilename ~= nil then
          local vehicleData = defaultVehicleData:getCameraSystemDefaultData(xmlFilename)

          if vehicleData ~= nil then
            configurations = configurations or {}
            defaultConfigurationIds = defaultConfigurationIds or {}

            local cameraConfigurations = configurations.camera

            if cameraConfigurations == nil or #cameraConfigurations == 0 then
              cameraConfigurations = {
                {
                  isDefault = true,
                  saveId = "1",
                  isSelectable = true,
                  index = 1,
                  dailyUpkeep = 0,
                  price = 0,
                  name = g_i18n:getText("configuration_valueNo"),
                  nameCompareParams = {}
                },
                {
                  isDefault = false,
                  saveId = "2",
                  isSelectable = true,
                  index = 2,
                  dailyUpkeep = 0,
                  name = g_i18n:getText("configuration_valueYes"),
                  price = vehicleData.price,
                  nameCompareParams = {}
                }
              }
            end

            configurations.camera = cameraConfigurations
            defaultConfigurationIds.camera = defaultConfigurationIds.camera or 1
          end
        end
      end

      return configurations, defaultConfigurationIds
    end)
  else
    Logging.warning("CameraSystem: ConfigurationUtil not available - default camera configuration will not be injected.")
  end
  cameraSystem:overwriteGameFunction(FSBaseMission, "consoleCommandReloadVehicle", function (superFunc, mission, resetVehicle, radius)
    self:loadDefualtVehicleCameraSystemData()

    return superFunc(mission, resetVehicle, radius)
  end)
end

function CameraSystemDefaultVehicleData:getVehicleXmlFilenamePath(xmlFilename)
  if xmlFilename == nil then
    return nil
  end

  if xmlFilename:sub(1, 3) == "mod" and g_modsDirectory ~= nil then
    xmlFilename = g_modsDirectory .. xmlFilename:sub(5)
  end

  if xmlFilename:sub(1, 3) == "dlc" then
    xmlFilename = getAppBasePath() .. "pdlc/" .. xmlFilename:sub(5)
  end

  if xmlFilename:sub(1, 8) == "internal" then
    local internalModsDirectory = g_internalModsDirectory

    if internalModsDirectory == nil and g_modManager ~= nil and g_modManager.getInternalModsDirectory ~= nil then
      internalModsDirectory = g_modManager:getInternalModsDirectory()
    end

    if internalModsDirectory ~= nil then
      xmlFilename = internalModsDirectory .. xmlFilename:sub(10)
    end
  end

  return xmlFilename
end

function CameraSystemDefaultVehicleData:getCameraSystemDefaultData(configFilename)
  if configFilename == nil or configFilename == "" then
    return nil
  end

  local targetBase = configFilename:match("([^/\\]+)$")

  for i = 1, #self.cameraData do
    local vehicleData = self.cameraData[i]

    if vehicleData.xmlFilename ~= nil and vehicleData.xmlFilename ~= "" then
      if vehicleData.basename ~= nil and targetBase ~= nil and vehicleData.basename == targetBase then
        return vehicleData
      end

      if StringUtil ~= nil and StringUtil.endsWith ~= nil then
        if StringUtil.endsWith(configFilename, vehicleData.xmlFilename) then
          return vehicleData
        end
      elseif configFilename.endsWith ~= nil then
        if configFilename:endsWith(vehicleData.xmlFilename) then
          return vehicleData
        end
      else
        local length = vehicleData.xmlFilename:len()

        if length == 0 or configFilename:sub(-length) == vehicleData.xmlFilename then
          return vehicleData
        end
      end
    end
  end
end

function CameraSystemDefaultVehicleData:delete()
  self.cameraData = {}
end

function CameraSystemDefaultVehicleData:registerXMLPaths(schema)
  schema:register(XMLValueType.STRING, "cameraSystemDefaultVehicleData.vehicles.vehicle(?)#xmlFilename", "Vehicle filename")
  schema:register(XMLValueType.STRING, "cameraSystemDefaultVehicleData.vehicles.vehicle(?)#price", "Vehicle configuration price")

  schema:register(XMLValueType.L10N_STRING, CameraSystemDefaultVehicleData.CONFIG_XML_KEY .. "#name", "Camera name")
  schema:register(XMLValueType.STRING, CameraSystemDefaultVehicleData.CONFIG_XML_KEY .. "#nodeName", "Target node name")
  schema:register(XMLValueType.STRING, CameraSystemDefaultVehicleData.CONFIG_XML_KEY .. "#visibilityNodeName", "Target node name that visibility is needed")
  schema:register(XMLValueType.VECTOR_TRANS, CameraSystemDefaultVehicleData.CONFIG_XML_KEY .. "#translation", "Camera position")
  schema:register(XMLValueType.VECTOR_ROT, CameraSystemDefaultVehicleData.CONFIG_XML_KEY .. "#rotation", "Camera rotation")
  schema:register(XMLValueType.FLOAT, CameraSystemDefaultVehicleData.CONFIG_XML_KEY .. "#fov", "Camera field of view")
  schema:register(XMLValueType.FLOAT, CameraSystemDefaultVehicleData.CONFIG_XML_KEY .. "#nearClip", "Camera near clip")
  schema:register(XMLValueType.FLOAT, CameraSystemDefaultVehicleData.CONFIG_XML_KEY .. "#farClip", "Camera far clip")
  schema:register(XMLValueType.STRING, CameraSystemDefaultVehicleData.CONFIG_XML_KEY .. "#activeFunc", "Camera activation function")
end
