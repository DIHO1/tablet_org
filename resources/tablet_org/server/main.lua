local ESX = exports['es_extended']:getSharedObject()
local oxmysql = exports.oxmysql

local RESOURCE_NAME = GetCurrentResourceName()
local tableName = Config.DatabaseTable or 'tablet_organizations'

local organization = {
  id = nil,
  name = nil,
  owner = nil,
  motto = nil,
  recruitment = nil,
  funds = 0,
  note = nil,
  createdAt = nil,
  updatedAt = nil,
  dailyPlan = {},
}

local function cloneOrganization()
  local planCopy = {}
  if type(organization.dailyPlan) == 'table' then
    for index, entry in ipairs(organization.dailyPlan) do
      planCopy[index] = {
        time = entry.time,
        label = entry.label,
      }
    end
  end

  return {
    name = organization.name,
    owner = organization.owner,
    motto = organization.motto,
    recruitment = organization.recruitment,
    funds = organization.funds or 0,
    note = organization.note,
    createdAt = organization.createdAt,
    updatedAt = organization.updatedAt,
    dailyPlan = planCopy,
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

local function ensureColumn(column, definition)
  local existing = dbSingle(([[
    SHOW COLUMNS FROM `%s` LIKE ?
  ]]):format(tableName), { column })

  if existing then
    return
  end

  dbExecute(([[
    ALTER TABLE `%s` ADD COLUMN `%s` %s
  ]]):format(tableName, column, definition))
end

local function ensureSchema()
  local query = ([[
    CREATE TABLE IF NOT EXISTS `%s` (
      `id` INT NOT NULL AUTO_INCREMENT,
      `name` VARCHAR(128) NOT NULL,
      `owner` VARCHAR(64) NOT NULL,
      `motto` TEXT NULL,
      `recruitment_message` TEXT NULL,
      `funds` INT NOT NULL DEFAULT 0,
      `note` TEXT NULL,
      `daily_plan` LONGTEXT NULL,
      `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      `updated_at` DATETIME NULL,
      PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  ]]):format(tableName)

  dbExecute(query)

  ensureColumn('motto', 'TEXT NULL')
  ensureColumn('recruitment_message', 'TEXT NULL')
  ensureColumn('funds', 'INT NOT NULL DEFAULT 0')
  ensureColumn('note', 'TEXT NULL')
  ensureColumn('updated_at', 'DATETIME NULL')
  ensureColumn('daily_plan', 'LONGTEXT NULL')
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
    SELECT `id`, `name`, `owner`, `motto`, `recruitment_message`, `funds`, `note`, `daily_plan`, `created_at`, `updated_at`
    FROM `%s`
    ORDER BY `id`
    LIMIT 1
  ]]):format(tableName))

  if not row then
    organization.id = nil
    organization.name = nil
    organization.owner = nil
    organization.motto = nil
    organization.recruitment = nil
    organization.funds = 0
    organization.note = nil
    organization.createdAt = nil
    organization.updatedAt = nil
    organization.dailyPlan = {}
    return
  end

  organization.id = row.id
  organization.name = row.name
  organization.owner = row.owner
  organization.motto = row.motto
  organization.recruitment = row.recruitment_message
  organization.funds = row.funds or 0
  organization.note = row.note
  if row.daily_plan and row.daily_plan ~= '' and json and type(json.decode) == 'function' then
    local ok, decoded = pcall(json.decode, row.daily_plan)
    if ok and type(decoded) == 'table' then
      organization.dailyPlan = sanitizePlanEntries(decoded)
    else
      organization.dailyPlan = {}
    end
  else
    organization.dailyPlan = {}
  end
  organization.createdAt = dbToIso(row.created_at)
  organization.updatedAt = dbToIso(row.updated_at)
end

local function persistOrganization()
  if not organization.name or not organization.owner then
    return
  end

  local createdAtForDb = isoToDb(organization.createdAt) or os.date('!%Y-%m-%d %H:%M:%S')
  local updatedAtForDb = isoToDb(organization.updatedAt)
  local planEncoder = json and json.encode
  local planJson = planEncoder and planEncoder(organization.dailyPlan or {}) or '[]'

  if organization.id then
    dbExecute(([[
      UPDATE `%s`
      SET `name` = ?, `owner` = ?, `motto` = ?, `recruitment_message` = ?, `funds` = ?, `note` = ?, `daily_plan` = ?, `created_at` = ?, `updated_at` = ?
      WHERE `id` = ?
    ]]):format(tableName), {
      organization.name,
      organization.owner,
      organization.motto,
      organization.recruitment,
      organization.funds or 0,
      organization.note,
      planJson,
      createdAtForDb,
      updatedAtForDb,
      organization.id,
    })

    return
  end

  local insertedId = dbInsert(([[
    INSERT INTO `%s` (`name`, `owner`, `motto`, `recruitment_message`, `funds`, `note`, `daily_plan`, `created_at`, `updated_at`)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
  ]]):format(tableName), {
    organization.name,
    organization.owner,
    organization.motto,
    organization.recruitment,
    organization.funds or 0,
    organization.note,
    planJson,
    createdAtForDb,
    updatedAtForDb,
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

local function sanitizePlanEntries(entries)
  local sanitized = {}

  if type(entries) ~= 'table' then
    return sanitized
  end

  local maxEntries = Config.MaxPlanEntries or 8
  local maxLabelLength = Config.MaxPlanLabelLength or 64

  for _, entry in ipairs(entries) do
    if #sanitized >= maxEntries then
      break
    end

    if type(entry) == 'table' then
      local label = sanitizeValue(entry.label, maxLabelLength) or sanitizeValue(entry.task, maxLabelLength)
      local time = ''

      if type(entry.time) == 'string' then
        local trimmedTime = sanitizeValue(entry.time, 5)
        if trimmedTime then
          local hour, minute = trimmedTime:match('^(%d%d):(%d%d)$')
          local hourNumber = tonumber(hour)
          local minuteNumber = tonumber(minute)
          if hourNumber and minuteNumber and hourNumber >= 0 and hourNumber < 24 and minuteNumber >= 0 and minuteNumber < 60 then
            time = ('%02d:%02d'):format(hourNumber, minuteNumber)
          end
        end
      end

      if label or time ~= '' then
        sanitized[#sanitized + 1] = {
          time = time,
          label = label,
        }
      end
    end
  end

  return sanitized
end

local function handleOrganizationSave(src, payload)
  local name = sanitizeValue(payload.name, 128)
  local owner = sanitizeValue(payload.owner, 64)
  local motto = sanitizeValue(payload.motto, Config.MaxMottoLength or 280)
  local recruitment = sanitizeValue(payload.recruitment, Config.MaxRecruitmentLength or 320)

  if not name or not owner then
    sendClientUpdate(src, { error = 'Wypełnij wszystkie pola formularza.', context = 'setup' })
    return
  end

  local isNew = organization.name == nil
  local nameChanged = organization.name and organization.name:lower() ~= name:lower()

  organization.name = name
  organization.owner = owner
  organization.motto = motto
  organization.recruitment = recruitment

  if isNew or nameChanged or not organization.createdAt then
    organization.createdAt = os.date('!%Y-%m-%dT%H:%M:%SZ')
  end

  organization.updatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ')
  organization.funds = organization.funds or 0

  persistOrganization()

  sendClientUpdate(src, {
    data = cloneOrganization(),
    message = isNew and 'Organizacja została utworzona.' or 'Dane organizacji zapisane.',
    context = 'setup',
  })
end

local function ensureOrganizationReady(src, context)
  if not organization.name then
    sendClientUpdate(src, {
      error = 'Musisz utworzyć organizację, zanim skorzystasz z tej funkcji.',
      context = context or 'setup',
    })
    return false
  end

  return true
end

local function handleNoteUpdate(src, payload)
  if not ensureOrganizationReady(src, 'note') then
    return
  end

  local note = sanitizeValue(payload.note, Config.MaxNoteLength or 480)

  organization.note = note
  organization.updatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ')

  persistOrganization()

  sendClientUpdate(src, {
    data = cloneOrganization(),
    message = 'Notatka została zaktualizowana.',
    context = 'note',
  })
end

local function handleFundsAdjust(src, payload)
  if not ensureOrganizationReady(src, 'funds') then
    return
  end

  if type(payload) ~= 'table' then
    sendClientUpdate(src, { error = 'Nieprawidłowa operacja finansowa.', context = 'funds' })
    return
  end

  local direction = payload.direction == 'withdraw' and 'withdraw' or 'deposit'
  local amount = tonumber(payload.amount)

  if not amount or amount <= 0 then
    sendClientUpdate(src, { error = 'Podaj dodatnią kwotę.', context = 'funds' })
    return
  end

  local maxAmount = Config.MaxFundsAdjustment or 500000
  if amount > maxAmount then
    sendClientUpdate(src, { error = ('Maksymalna operacja to %d.'):format(maxAmount), context = 'funds' })
    return
  end

  organization.funds = organization.funds or 0

  if direction == 'withdraw' and amount > organization.funds then
    sendClientUpdate(src, { error = 'Brak wystarczających środków w skarbcu.', context = 'funds' })
    return
  end

  if direction == 'withdraw' then
    organization.funds = organization.funds - amount
  else
    local maxFunds = Config.MaxStoredFunds or 2000000
    if organization.funds + amount > maxFunds then
      sendClientUpdate(src, {
        error = ('Limit środków to %d.'):format(maxFunds),
        context = 'funds',
      })
      return
    end

    organization.funds = organization.funds + amount
  end

  organization.updatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ')

  persistOrganization()

  local message = direction == 'withdraw' and 'Wypłacono środki ze skarbca.' or 'Dodano środki do skarbca.'

  sendClientUpdate(src, {
    data = cloneOrganization(),
    message = message,
    context = 'funds',
  })
end

local function handlePlanUpdate(src, payload)
  if not ensureOrganizationReady(src, 'plan') then
    return
  end

  if type(payload) ~= 'table' then
    sendClientUpdate(src, { error = 'Nieprawidłowy plan dnia.', context = 'plan' })
    return
  end

  local entries = sanitizePlanEntries(payload.entries)
  organization.dailyPlan = entries
  organization.updatedAt = os.date('!%Y-%m-%dT%H:%M:%SZ')

  persistOrganization()

  local message = (#entries > 0) and 'Plan dnia zapisany.' or 'Plan dnia został wyczyszczony.'

  sendClientUpdate(src, {
    data = cloneOrganization(),
    message = message,
    context = 'plan',
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
    sendClientUpdate(src, { error = 'Nieprawidłowe dane formularza.', context = 'setup' })
    return
  end

  handleOrganizationSave(src, payload)
end)

RegisterNetEvent('tablet_org:updateNote', function(payload)
  local src = source
  handleNoteUpdate(src, type(payload) == 'table' and payload or {})
end)

RegisterNetEvent('tablet_org:adjustFunds', function(payload)
  local src = source
  handleFundsAdjust(src, type(payload) == 'table' and payload or {})
end)

RegisterNetEvent('tablet_org:updatePlan', function(payload)
  local src = source
  handlePlanUpdate(src, type(payload) == 'table' and payload or {})
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
