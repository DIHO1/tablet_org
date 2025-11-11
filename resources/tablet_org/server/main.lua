local ESX = exports['es_extended']:getSharedObject()

local RESOURCE_NAME = GetCurrentResourceName()
local storagePath = Config.StorageFile or 'data/organization.json'

local organization = {
  name = nil,
  owner = nil,
  createdAt = nil,
}

local function cloneOrganization()
  return {
    name = organization.name,
    owner = organization.owner,
    createdAt = organization.createdAt,
  }
end

local function persistOrganization()
  local payload = json.encode(cloneOrganization())
  SaveResourceFile(RESOURCE_NAME, storagePath, payload or '{}', -1)
end

local function loadOrganization()
  local raw = LoadResourceFile(RESOURCE_NAME, storagePath)

  if not raw or raw == '' then
    persistOrganization()
    return
  end

  local ok, data = pcall(json.decode, raw)
  if not ok or type(data) ~= 'table' then
    print(('^3[tablet_org]^7 Failed to decode organization data, starting fresh. Error: %s'):format(data))
    persistOrganization()
    return
  end

  organization.name = data.name
  organization.owner = data.owner
  organization.createdAt = data.createdAt
end

local function isJobAllowed(jobName)
  if not jobName or jobName == '' then
    return next(Config.AllowedJobs) == nil
  end

  if next(Config.AllowedJobs) == nil then
    return true
  end

  return Config.AllowedJobs[jobName] == true
end

local function sendClientUpdate(target, payload)
  TriggerClientEvent('tablet_org:clientUpdate', target, payload)
end

local function sanitizeName(value)
  if not value then
    return nil
  end
  local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')
  if trimmed == '' then
    return nil
  end
  return trimmed
end

local function handleOrganizationCreation(src, payload)
  local name = sanitizeName(payload.name)
  local owner = sanitizeName(payload.owner)

  if not name or not owner then
    sendClientUpdate(src, { error = 'Wypełnij wszystkie pola formularza.' })
    return
  end

  if name:lower() ~= 'best' then
    sendClientUpdate(src, { error = 'Panel pozwala utworzyć wyłącznie organizację „Best”.' })
    return
  end

  if #owner > 64 then
    owner = owner:sub(1, 64)
  end

  organization.name = 'Best'
  organization.owner = owner
  organization.createdAt = os.date('!%Y-%m-%dT%H:%M:%SZ')

  persistOrganization()
  sendClientUpdate(src, {
    data = cloneOrganization(),
    message = 'Organizacja została zapisana.',
  })
end

RegisterNetEvent('tablet_org:requestOpen', function()
  local src = source
  local xPlayer = ESX.GetPlayerFromId(src)

  if not xPlayer then
    return
  end

  local job = xPlayer.getJob()
  local jobName = job and job.name or nil

  if not isJobAllowed(jobName) then
    TriggerClientEvent('esx:showNotification', src, 'Nie masz dostępu do tabletu organizacji.')
    return
  end

  sendClientUpdate(src, {
    action = 'open',
    data = cloneOrganization(),
  })
end)

RegisterNetEvent('tablet_org:requestData', function()
  local src = source
  sendClientUpdate(src, {
    data = cloneOrganization(),
  })
end)

RegisterNetEvent('tablet_org:createOrganization', function(payload)
  local src = source

  if type(payload) ~= 'table' then
    sendClientUpdate(src, { error = 'Nieprawidłowe dane formularza.' })
    return
  end

  handleOrganizationCreation(src, payload)
end)

AddEventHandler('playerDropped', function(_reason)
  -- Placeholder for potential cleanup or saving hooks.
end)

AddEventHandler('onResourceStart', function(resource)
  if resource ~= RESOURCE_NAME then
    return
  end

  loadOrganization()
  print('^2[tablet_org]^7 Resource ready.')
end)

AddEventHandler('onResourceStop', function(resource)
  if resource ~= RESOURCE_NAME then
    return
  end

  persistOrganization()
end)
