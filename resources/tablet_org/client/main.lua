local isOpen = false

local function openTablet(data)
  if isOpen then
    return
  end

  isOpen = true
  if SetNuiFocusKeepInput then
    SetNuiFocusKeepInput(false)
  end
  SetNuiFocus(true, true)
  SendNUIMessage({
    action = 'open',
    data = data or {},
  })
end

local function closeTablet()
  if not isOpen then
    return
  end

  isOpen = false
  if SetNuiFocusKeepInput then
    SetNuiFocusKeepInput(false)
  end
  SetNuiFocus(false, false)
  SendNUIMessage({ action = 'close' })
end

RegisterCommand(Config.OpenCommand, function()
  if isOpen then
    closeTablet()
    return
  end

  TriggerServerEvent('tablet_org:requestOpen')
end, false)

if Config.DefaultKey and Config.DefaultKey ~= '' then
  RegisterKeyMapping(Config.OpenCommand, 'Otwórz tablet organizacji', 'keyboard', Config.DefaultKey)
end

RegisterNetEvent('tablet_org:clientUpdate', function(payload)
  if type(payload) ~= 'table' then
    return
  end

  if payload.action == 'open' then
    openTablet(payload.data)
    return
  end

  if payload.action == 'close' then
    closeTablet()
    return
  end

  if payload.data then
    SendNUIMessage({ action = 'update', data = payload.data })
  end

  if payload.message then
    SendNUIMessage({ action = 'notify', type = 'success', message = payload.message, context = payload.context })
  end

  if payload.error then
    SendNUIMessage({ action = 'notify', type = 'error', message = payload.error, context = payload.context })
  end
end)

RegisterNetEvent('esx:playerDropped', function()
  closeTablet()
end)

AddEventHandler('onResourceStop', function(resource)
  if resource ~= GetCurrentResourceName() then
    return
  end

  closeTablet()
end)

RegisterNUICallback('ready', function(_, cb)
  TriggerServerEvent('tablet_org:requestData')
  cb({})
end)

RegisterNUICallback('close', function(_, cb)
  closeTablet()
  cb({})
end)

RegisterNUICallback('create', function(data, cb)
  TriggerServerEvent('tablet_org:createOrganization', data)
  cb({})
end)

RegisterNUICallback('adjustFunds', function(data, cb)
  TriggerServerEvent('tablet_org:adjustFunds', data)
  cb({})
end)

RegisterNUICallback('updateNote', function(data, cb)
  TriggerServerEvent('tablet_org:updateNote', data)
  cb({})
end)
