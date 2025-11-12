local ESX = exports['es_extended']:getSharedObject()
local oxmysql = exports.oxmysql

local RESOURCE_NAME = GetCurrentResourceName()
local tableName = Config.DatabaseTable or 'tablet_organizations'

local organization = {
  id = nil,
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

local function dbExecute(query, params)
  local p = promise.new()

  oxmysql:execute(query, params or {}, function(result)
    p:resolve(result)
  end)

  return Citizen.Await(p)
end

local function dbInsert(query, params)
  local p = promise.new()

  oxmysql:insert(query, params or {}, function(result)
    p:resolve(result)
  end)

  return Citizen.Await(p)
end

local function dbSingle(query, params)
  local p = promise.new()

  oxmysql:single(query, params or {}, function(result)
    p:resolve(result)
  end)

  return Citizen.Await(p)
end

local function ensureSchema()
  local query = ([[
    CREATE TABLE IF NOT EXISTS `%s` (
      `id` INT NOT NULL AUTO_INCREMENT,
      `name` VARCHAR(128) NOT NULL,
      `owner` VARCHAR(64) NOT NULL,
      `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  ]]):format(tableName)

  dbExecute(query)
end

local function dbToIso(datetime)
  if type(datetime) ~= 'string' or datetime == '' then
    return nil
  end

  local datePart, timePart = datetime:match('^(%d%d%d%d%-%d%d%-%d%d) (%d%d:%d%d:%d%d)$')
  if not datePart then
    return datetime
  end

  return ('%sT%sZ'):format(datePart, timePart)
end

local function isoToDb(iso)
  if type(iso) ~= 'string' or iso == '' then
    return nil
  end

  local datePart, timePart = iso:match('^(%d%d%d%d%-%d%d%-%d%d)T(%d%d:%d%d:%d%d)Z$')
  if not datePart then
    return iso
  end

  return ('%s %s'):format(datePart, timePart)
end

local function loadOrganization()
  local row = dbSingle(([[
    SELECT `id`, `name`, `owner`, `created_at`
    FROM `%s`
    ORDER BY `id`
    LIMIT 1
  ]]):format(tableName))

  if not row then
    organization.id = nil
    organization.name = nil
    organization.owner = nil
    organization.createdAt = nil
    return
  end

  organization.id = row.id
  organization.name = row.name
  organization.owner = row.owner
  organization.createdAt = dbToIso(row.created_at)
end

local function persistOrganization()
  if not organization.name or not organization.owner then
    return
  end

  local createdAtForDb = isoToDb(organization.createdAt) or os.date('!%Y-%m-%d %H:%M:%S')

  if organization.id then
    dbExecute(([[
      UPDATE `%s`
      SET `name` = ?, `owner` = ?, `created_at` = ?
      WHERE `id` = ?
    ]]):format(tableName), {
      organization.name,
      organization.owner,
      createdAtForDb,
      organization.id,
    })

    return
  end

  local insertedId = dbInsert(([[
    INSERT INTO `%s` (`name`, `owner`, `created_at`)
    VALUES (?, ?, ?)
  ]]):format(tableName), {
    organization.name,
    organization.owner,
    createdAtForDb,
  })

  organization.id = insertedId
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

local function sanitizeValue(value, maxLength)
  if not value then
    return nil
  end

  local trimmed = value:gsub('^%s+', ''):gsub('%s+$', '')
  if trimmed == '' then
    return nil
  end

  if maxLength and #trimmed > maxLength then
    trimmed = trimmed:sub(1, maxLength)
  end

  return trimmed
end

local function handleOrganizationSave(src, payload)
  local name = sanitizeValue(payload.name, 128)
  local owner = sanitizeValue(payload.owner, 64)

  if not name or not owner then
    sendClientUpdate(src, { error = 'Wypełnij wszystkie pola formularza.' })
    return
  end

  local isNew = organization.name == nil
  local nameChanged = organization.name and organization.name:lower() ~= name:lower()

  organization.name = name
  organization.owner = owner

  if isNew or nameChanged or not organization.createdAt then
    organization.createdAt = os.date('!%Y-%m-%dT%H:%M:%SZ')
  end

  persistOrganization()

  sendClientUpdate(src, {
    data = cloneOrganization(),
    message = isNew and 'Organizacja została utworzona.' or 'Dane organizacji zapisane.',
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

  handleOrganizationSave(src, payload)
end)

AddEventHandler('playerDropped', function(_reason)
  -- Placeholder for potential cleanup or saving hooks.
end)

AddEventHandler('onResourceStart', function(resource)
  if resource ~= RESOURCE_NAME then
    return
  end

  ensureSchema()
  loadOrganization()
  print('^2[tablet_org]^7 Resource ready.')
end)

AddEventHandler('onResourceStop', function(resource)
  if resource ~= RESOURCE_NAME then
    return
  end

  if organization.name and organization.owner then
    persistOrganization()
  end
end)
